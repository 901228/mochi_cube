# mochi_cube

<p align="center"><a href="README.md">English</a> · 繁體中文</p>

以純 Dart 撰寫的扭轉類魔術方塊解算器與打亂產生器，不依賴 Flutter。目前涵蓋 2x2x2 到
7x7x7、Megaminx、Pyraminx、Skewb、Square-1 與 Clock，可當作函式庫使用，也有
[命令列工具](#command-line)。

3x3x3 有兩個解算器。你該用的是 Chen Shuang 的
[min2phase](https://github.com/cs0x7f/min2phase) 移植版；另一個是 Herbert Kociemba
雙階段演算法較為樸素的實作，保留它是因為前者的每一張表格都以它作為獨立的參照來檢驗。

```dart
import "package:mochi_cube/mochi_cube.dart";

void main() {
  final scramble = randomStateScramble();
  print(scramble); // R2 F' R2 B2 F R2 F2 R2 D2 F L2 U2 L2 R' B' U L B D B' L'

  final result = min2phase.solve(scramble.cube.toFaceletString());
  if (result.status == SolveStatus.foundSolution) {
    final solution = result.solution!;
    print("${solution.length} moves in ${solution.elapsedTime.inMilliseconds}ms: $solution");
  }
}
```

## The two solvers

以同樣的 100 個隨機方塊量測，表格已建立完成之後：

|              | min2phase | kociemba |
| ------------ | --------- | -------- |
| solve        | 13.4ms    | 24.8ms   |
| moves        | 20.6      | 22.9     |
| tables       | 1.0 MB    | 4.9 MB   |
| first build  | ~600ms    | ~1.1s    |
| cached load  | ~90ms     | ~30ms    |

差別在於對稱縮減。彼此相差 16 種對稱之一的兩個方塊狀態，距離還原的步數相同，所以
min2phase 的表格是每個等價類別存一筆，而不是每個狀態存一筆——40320 種邊塊排列只剩
2768 個類別，其餘依此類推。剪枝能力相同，記憶體只要十分之一。

兩者共用同一個介面：

```dart
SolveResult solve(String facelets, {int maxLength, Duration? maxTime});
```

`min2phase` 與 `kociemba` 是現成的實例。前者匯入
`package:mochi_cube/mochi_cube.dart`，後者匯入 `package:mochi_cube/kociemba.dart`。
兩者是各自獨立的函式庫，因為它們都定義了內部實作不同的 `CubieCube`，所以不能把其中一個
和另一個一起匯出。

表格在第一次使用時建立，並快取在平台的應用程式資料目錄下。
`Phase1Tables.useTwistFlipPrune = false` 以最大的那張表換取速度：644 KB 與 21.5ms，
取代 1.0 MB 與 13.4ms，解的長度不變。

## The 2x2x2

`package:mochi_cube/pocket.dart`，而且是完全不同的問題。3x3x3 有 4.3 × 10^19 種狀態，
需要雙階段搜尋；2x2x2 只有 3,674,160 種，少到可以把每一個狀態到還原的精確距離都存起來。
所以這裡沒有搜尋：解題就是一路下坡，任選一個能讓你更靠近一步的轉動即可。

```dart
import "package:mochi_cube/pocket.dart";

final scramble = randomPocketScramble();
final result = pocket.solve(scramble.cube.toPocketFaceletString());
// always the shortest solution that exists
```

| | |
| ---------- | ------------------------------------- |
| solve      | 1.2μs，且必定最佳                       |
| moves      | 平均 8.8，最多 11                       |
| table      | 1.9 MB，建立約 ~570ms，載入約 ~25ms     |

11 就是這個魔術方塊的 God's number。表格的距離直方圖與已發表的結果完全吻合，連需要整整十一步的
2,644 個狀態也一致——這比 3x3x3 的表格所能得到的任何檢驗都更有說服力。

2x2x2 沒有中心塊，所以沒有任何東西告訴你哪個顏色是哪一面。`PocketCube.fromFaceletString`
會自己推算：固定不動的那個角塊依定義指出三個面，其餘每種顏色則與「從未和它同屬一個角塊」的那個面相對。
任意六個字母、任何配色方案都能解析，和 3x3x3 相同。

## Scrambles

兩種產生器，兩者不能互換。

```dart
randomStateScramble()          // what the WCA means by a scramble
randomScramble(moves: 20)      // random turns
```

`randomStateScramble` 從全部 43,252,003,274,489,856,000 種狀態中均勻抽取，解開它，
再把解法反過來——WCA 自己的打亂產生器就是這樣運作的。它要花一次解題的成本，產生的打亂約 20 步。
它也遵守 WCA 規則 4b3，要求打亂離還原狀態至少兩步。

`randomScramble` 只是隨機轉動各個面。成本低，但它能到達的狀態分布並不均勻，
很短的打亂可能讓方塊幾乎還是還原狀態。請用在分布不重要的地方。

## The Pyraminx

`package:mochi_cube/pyraminx.dart`。和 2x2x2 一樣，小到可以存下每個狀態的精確距離，
所以解題就是一路下坡，答案必定是最佳解。

```dart
import "package:mochi_cube/pyraminx.dart";

final scramble = randomPyraminxScramble();

// B' L' U R U L U L' l b'

final cube = PyraminxCube()..apply(scramble);
print(PyraminxSearch.solve(cube)); // the shortest way back
```

| | |
| ---------- | --------------------------------------- |
| solve      | 1.3μs，且必定最佳                        |
| turns      | 平均 7.8，最多 11                        |
| table      | 463 KB，建立約 ~180ms，載入約 ~25ms      |

933,120 個狀態，God's number 為 11，距離直方圖與已發表的結果吻合。頂點小塊（tips）不放進*表格*裡——
每一個各自只是一次轉動——所以 `solveLayers` 是最佳解的部分，`solve` 再把它們補完。

`toFaceletString` 會輸出 36 個貼紙，四個面各九個。讀回來時不需要中心塊，而 Pyraminx 本來就沒有：
頂點塊永遠不會離開它的角，並且碰到除了一個面以外的所有面，所以它從未出現的那個顏色就指出那個面。

記法在這裡終於必須成為各個魔術方塊自己的事，而不再是函式庫共用的事。Pyraminx 是以兩種幅度轉動四個頂點和
四個頂點小塊，而 3x3x3 是以三種幅度轉動六個面，所以 `MoveSet` 現在會說明各軸與各幅度叫什麼名字，
而 `Algorithm` 帶著它所書寫的那一套。2x2x2 完全不需要這些，因為它的轉動就是 3x3x3 的轉動。

## The Skewb

`package:mochi_cube/skewb.dart`。第三個小到可以存下每個狀態精確距離的魔術方塊，
所以同樣地，解題就是一路下坡，答案必定是最佳解。

```dart
import "package:mochi_cube/skewb.dart";

final scramble = randomSkewbScramble();
// R U' B L' R B' U L

final cube = SkewbCube()..apply(scramble);
print(SkewbSearch.solve(cube)); // the shortest way back
```

| | |
| ---------- | ----------------------------------------- |
| solve      | 2.4μs，且必定最佳                          |
| turns      | 平均 8.4，最多 11                          |
| table      | 1.5 MB，建立約 ~600ms，載入約 ~100ms       |

3,149,280 個狀態，God's number 為 11，距離直方圖與已發表的結果吻合。記法採用 WCA 規則 12h：
`R`、`U`、`L`、`B` 分別轉動下後右、上後左、下前左、下後左的角塊，所以上前右角塊永遠不動，
並用來固定整個魔術方塊。

方塊以它的 30 個貼紙來保存，每一個轉動都是從貼紙在空間中的位置算出來的，而不是手寫。
角塊與中心塊再藉由從還原狀態出發走遍每一個轉動來編號，所以沒有任何奇偶或扭轉規則可能出錯：
8748 個角塊狀態與 360 個中心塊狀態，相乘正好是已發表的總數。讀回貼紙時，顏色取自永不移動的那個角塊，
和 2x2x2 一樣。

## The Square-1

`package:mochi_cube/square1.dart`，是 Chen Shuang 的
[sq12phase](https://github.com/cs0x7f/sq12phase) 的移植版，官方 TNoodle 打亂程式與 csTimer 都使用它。
狀態數多到無法建立距離表，所以採用雙階段搜尋：先回到第二階段能完成的奇偶性的方塊，
再當作立方體解完。

```dart
import "package:mochi_cube/square1.dart";

final scramble = randomSquare1Scramble();
// (1,0) / (-1,2) / (0,-3) / …

final cube = Square1Cube()..apply(scramble);
print(Square1Search.solve(cube));
```

| | |
| ---------- | --------------------------------------------- |
| solve      | 約 25ms，非最佳解                              |
| moves      | 平均 24，最多 29，依 12c4 的算法計數           |
| tables     | 不到 400 KB，建立約 ~0.2s，不快取              |

記法採用 WCA 規則 12d：`(x,y)` 轉動上層與下層，`/` 轉動右半邊，每一個都算一步，
所以 `Algorithm.length` 就是 WCA 的步數。這不是「面與幅度」的形式，所以 `square1Moves` 是一個
`MoveSet`，它覆寫了讀取與書寫一步的方式；`MoveSet.tokensOf` 是唯一需要的掛鉤，
因為 `(1,0)/` 把兩步連在一起。每一個轉動都以 TNoodle 自己的魔術方塊模型來檢驗，
該模型已移植到測試中作為參照。

狀態是 24 個槽位與中間層各自放著哪一塊，由 `toString` 寫成 24 個十六進位數字加上一個 0 或 1，
再由 `Square1Cube.parse` 讀回。橫跨切縫的角塊會被保留而不是拒絕，因為把某一層只轉到一半就會出現這種情況；
解算器會先把它轉回對齊。

打亂的產生方式與 TNoodle 相同，從 `/` 能轉動的每一個狀態中均勻抽取，且至少要有十一步（4b3）。
這是拿找到的解法而不是最佳解來檢查的，所以只是上界——見 `randomSquare1Scramble` 上的 `shortcut:`。

## The 4x4x4

`package:mochi_cube/fourbyfour.dart`，本套件中最大的一塊：Shuang Chen 的三階段降階解算器的移植版，
也是官方打亂程式所使用的。4x4x4 的狀態數太多，用隨機轉動來打亂無法確定已經充分打散，
可抽取的狀態有 7.4 * 10^45 種，所以它依 WCA 的定義來打亂——隨機一個狀態，解開，再把解法反過來。

```dart
import "package:mochi_cube/fourbyfour.dart";

final scramble = randomFourByFourScramble();
// Rw2 U' Fw L2 …

final cube = NxNCube(4)..apply(scramble);
FourByFourSearch.solve(cube); // about 44 moves, not the shortest
```

| | |
| ---------- | ------------------------------------------------------------ |
| scramble   | 在 VM 上 375ms，約 45 步（最多 48）                           |
| tables     | 快取 10 MB，建立約 ~1.7s；網頁上第一次 3.5s，之後 0.7s        |

第一階段把同一個顏色類別的中心塊放到兩個相對的面上，第二階段整理其餘部分，第三階段在配對 wings 的同時完成中心塊，
留下一個由本套件自己的 min2phase 解開的 3x3x3。每個階段都是疊代加深搜尋，並各有自己的表格：
中心塊以方塊的 48 種對稱折疊，wings 的表格是一張 2 位元、含三千一百萬個縮減狀態的表，
只記錄深度除以 3 的餘數，且最多只到九步。

36 個轉動就是 `nxnMoves(4)`，編號完全相同，所以打亂就是一般的 `Algorithm`，`NxNCube(4)` 可以直接照著轉。
解法做完之後，方塊會與起點相差一個整體旋轉，因為 4x4x4 沒有固定的中心塊；打亂的寬層轉動只用 `Uw`、`Rw` 與 `Fw` 書寫，
和官方的一樣。

整個過程都對照 `NxNCube(4)` 檢驗，而 `NxNCube(4)` 又先後以 3x3x3 與 2x2x2 檢驗過：
解算器自己各個部件的每一個轉動、一個打亂對照它所來自的隨機方塊（至多差一個旋轉）、一個解法對照它所針對的方塊。
表格則用獨立的搜尋檢驗——中心塊是對全部 735471 個原始狀態搜尋到深度 5，wings 是對真實的方塊搜尋，
其中每個步數以內所到達的類別數，與原版發表的 1, 4, 16, 55, 324, 1922 完全相同。

## The 5x5x5, 6x6x6 and 7x7x7

`package:mochi_cube/nxn.dart`。WCA 對這幾個魔術方塊是用隨機轉動而非隨機狀態來打亂，所以這裡沒有任何東西去解它們：
打亂只需要轉動，不需要別的。上面的 4x4x4 用的是同一個方塊。

```dart
import "package:mochi_cube/nxn.dart";

final scramble = randomNxNScramble(6);
// 3Uw2 R' Fw R2 3Rw2 D' Bw Rw Dw2 3Uw …

final cube = NxNCube(6)..apply(scramble);
cube.toFacelets(); // 216 stickers, drawn by cubeNetLayout(6)
```

轉動採用 TNoodle 的：每個面轉一層深，並加寬到方塊的一半，`Rw` 為兩層、`3Rw` 為三層，
5x5x5 有 60 種、6x6x6 有 80 種、7x7x7 有 100 種。偶數階方塊的後半部分省略，
因為 `3Lw` 就是換個握法的 `3Rw'`。每一個轉動都從不會與已做過的轉動抵消或合併的轉動中均勻抽取——
這裡的「已做過的」指上一個，或是中間只隔著同一個軸的轉動的更早一個。

TNoodle 是比較整個狀態（至多差一個旋轉）來判斷；這裡則是計算該軸的每一層轉了多少，這是同一個問題，
並在測試中對照整個狀態的比較來檢驗。`NxNCube` 保存它的貼紙，並從貼紙在空間中的位置算出各個轉動，
和 Skewb 一樣，並在這些尺寸下對照 3x3x3 與 2x2x2 檢驗。一次打亂需要 2 到 4ms。

## The Megaminx

`package:mochi_cube/megaminx.dart`。同樣用隨機轉動來打亂，採用 Stefan Pochmann 的方式，與 WCA 相同：
七行、每行十個轉動，`R` 與 `D` 隨機地各轉 `++` 或 `--`，每一行以 `U` 或 `U'` 收尾，視其最後一個 `D` 的方向而定。

```dart
import "package:mochi_cube/megaminx.dart";

final scramble = randomMegaminxScramble();
print(megaminxNotation(scramble));
// R-- D-- R++ D++ R++ D-- R++ D-- R++ D++ U
// R++ D++ R++ D++ R++ D++ R-- D++ R++ D++ U
// …

final puzzle = Megaminx()..apply(scramble);
puzzle.toFacelets(); // 132 stickers, drawn by megaminxLayout
```

貼紙與轉動都是 TNoodle 自己的，逐個循環移植，因為對隨機轉動而言，重要的是轉得和官方程式完全一樣。
測試是拿它們對照魔術方塊的形狀，而不是對照它們自己：每個面的轉動，加上對面朝另一個方向的大轉動，
必須合成整個魔術方塊的一個旋轉，而這些旋轉必須構成正十二面體所擁有的那 60 個；貼紙必須分成 20 個角塊、
30 個邊塊與 12 個中心塊，且每個轉動都讓它們保持完整。`megaminxLayout` 是 TNoodle 的兩朵五邊形花，
測試會檢查每個面在畫面上都是順時針轉動，且同一朵花內的每一塊都是連在一起畫的。

狀態字串每個面用一個字母，依 TNoodle 的面順序從 `A` 到 `L`（`megaminxFaceLetters`），因為各面的名稱不是單一字母。

## The Face Turning Octahedron

`package:mochi_cube/fto.dart`。Levi Gibson 的 fto3phase 的移植版，也是官方打亂程式所使用的解算器。
打亂是隨機狀態，解開再反過來，約 28 步。

```dart
import "package:mochi_cube/fto.dart";

final scramble = randomFtoScramble();
final puzzle = Fto()..apply(scramble);
puzzle.toFacelets(); // 72 stickers, drawn by ftoLayout
```

八個面是 `U R F L B BL D BR`，轉動如 `U R' BL …`，寫法與 WCA 相同。轉動逐個貼紙對照 TNoodle
自己手寫的轉動表來檢驗，解算器的各個部件則對照貼紙檢驗。11 MB 的第二階段表格快取為 `fto.bin`，建立約需 3 秒。

`parseFtoNotation` 也能讀 [Nautilus 的記法](https://nautilusfto.com/Notation)，它超出了 WCA 的範圍：

- 小寫的面，`r` 或 `br`，會連同該面一起轉動中間層；
- 次數照寫的取值，所以 `R2` 把一個面轉三分之二圈，等同 `R'`；
- `{X,Y}` 轉動整個魔術方塊，把 X 層轉到上面、Y 層轉到前面。兩層共用一個角時，
  魔術方塊是以角朝前的方式持握；共用一條邊時，則以邊朝前的方式持握；
- 括號內同一個軸上的轉動，`(r R')` 或 `(R BL')`，算作一步，`ftoNotationSteps` 會把它回傳成一個
  `FtoLayers`；其他的括號只做分組。

## The Clock

`package:mochi_cube/clock.dart`，是其中的異類：沒有搜尋，也沒有表格。

```dart
import "package:mochi_cube/clock.dart";

final scramble = randomClockScramble();
// UR2- DR5- DL0+ UL1+ U2+ R0+ D3+ L5- ALL5- y2 U4- R3- D1+ L2- ALL3+

scramble.movesToSolve;  // however many dials are off twelve o'clock
scramble.inverse;       // the moves that put it back
```

十四個各有十二個位置的轉盤，以及十四個各自剛好轉動其中一個轉盤的轉動。這些轉動彼此可交換，
也沒有任何一個能抵消另一個，所以這個魔術方塊就是群 `(Z12)^14`：合成狀態就是相加，解開就是取負。
它的記法*就是*它的狀態，所以一個打亂就是寫下來的十四個數字，僅此而已。

由此得到兩件別的魔術方塊都得費工夫才能得到的事。每個狀態都能到達，所以不存在無效的狀態；
而解開所需的最少步數，恰好就是不在零的轉盤個數，因為一步可以把一個轉盤修正任意的量。

`toDials()` 給出你看得見的十八個轉盤，每面九個，`ClockDialReading.fromDials` 再把它們讀回來。
它們是那十四個的線性映射：其中四個是兩面都看得到的角塊，這正是十八個轉盤只有十四個數字的原因。

這個映射是從機構推導出來的，而不是直接寫下，然後用三種方式檢驗——十四個轉動在 Z12 上互相獨立，
所以確實能到達 12^14；恰好有四個轉盤被鎖定與它對面的數字相同；而這四個恰好就是角塊。
這些都不是在表中斷言的，而是從表中自然得出。

## Practice scrambles

留下解題中某一步待做的打亂，用來針對該步驟練習：

```dart
pllPracticeScramble();               // bottom two layers solved, top oriented
ollPracticeScramble();               // bottom two layers solved, top misoriented
f2lPracticeScramble();               // cross solved
f2lPracticeScramble(solvedPairs: 3); // and three slots filled: last pair drills
```

每一個都是該步驟起始時那一類狀態中的均勻隨機狀態，解開再反過來——與完整打亂的做法相同，
只是方塊的一部分被固定不動。若想要不同的切分，`randomStateWith` 是通用的形式。

預設情況下，這些是從**狀態**中均勻抽取，所以各種情形出現的頻率與實際相同——T-perm 的出現次數是 H-perm 的四倍，
PLL 跳過約為七十二次一次。這正是你練習解題時想要的。

要學習一整組情形時，你要的正好相反，否則對稱的情形只會分到四分之一的練習量：

```dart
pllPracticeScramble(spread: PracticeSpread.cases);
ollPracticeScramble(spread: PracticeSpread.cases);
```

差異是真實存在的。一個沒有對稱的 PLL 情形涵蓋 288 個狀態中的 16 個，但 H、Z、E 與 N 只涵蓋 8 或 4 個，
而 57 個 OLL 中有 51 個涵蓋 4 種方向，有兩個只涵蓋一種。`pllCases` 與 `ollCases` 就是這些分組本身，
分別有 21 與 57 個。

## One interface for all of them

其他地方刻意讓各個魔術方塊彼此分開，所以它們的打亂函式有不同的名稱、不同的參數，而且——對於 Clock，
其打亂是一組轉盤位置而不是一串轉動——有不同的回傳型別。對於知道自己要哪一種魔術方塊的程式碼，這是對的；
對於有魔術方塊選單的畫面，這就不對了。

```dart
import "package:mochi_cube/scramblers.dart";

puzzleScramblers;                     // {333: …, 222: …, 555: …, …, minx: …, …, clock: …}

final scrambler = puzzleScramblers[saved]!;
final scramble = await scrambler.next();

scramble.notation;   // "R U2 F' …", or "UR4+ DR0+ … ALL6+"
scramble.state;      // one number per piece of scrambler.layout
scramble.algorithm;  // the moves, or null for the Clock
```

`next` 在建立某個魔術方塊的表格並搜尋時會佔住呼叫的執行緒，這對需要繪製畫面的應用程式是負擔不起的。
`scrambler.nextInBackground()` 是同一個打亂，但在保有表格的工作 isolate 上產生；在沒有 isolate 的網頁上，
它就是 `next`。使用它的程式要在結束前呼叫 `closeBackgroundScrambling()`，否則工作 isolate 會讓程式一直不結束。

鍵值是 WCA 的項目代號——`333`、`222`、`555`、`666`、`777`、`minx`、`pyram`、`skewb`、`sq1`、`clock`——
而不是我們自己取的拼法，因為這些是速解界其他地方所使用的寫法，也是向官方打亂程式索取打亂時所用的名稱。
這樣一來，儲存的設定可以指名某個魔術方塊，而不必依賴它們碰巧宣告的順序，
而 `.values` 仍然是選單會列出的順序，因為 Dart 的 map 會保留順序。

`practiceScramblers` 是同一個介面背後的那三種練習，鍵值為 `pll`、`oll` 與 `f2l`，所以練習選單只是多一個 map。
`allScramblers` 則是兩者合併。

### Why `next` is a future

一次工作階段中的第一個打亂比其餘慢得多，因為它要建立該魔術方塊的表格：

| | first | then |
| --- | --- | --- |
| `333` | 1780ms | 24ms |
| `222` | 1003ms | 0.1ms |
| `444` | 3542ms | 738ms |
| `pyram` | 333ms | 0.1ms |
| `skewb` | 593ms | 0.1ms |
| `sq1` | 120ms | 29ms |
| `555` | 19ms | 2ms |
| `777` | 6ms | 3.4ms |
| `minx` | 14ms | 1.7ms |
| `clock` | 1ms | 0ms |

這是在 dart2js 下量測的，那裡沒有快取可以載入；在有檔案系統的平台上，只有最初的第一次執行要付出這個代價。
回傳 future 表示呼叫端可以顯示進度指示，而不是在一次點擊後整個凍結。

它**不會**把工作移到別處。Dart 在網頁上沒有執行緒，所以 await 只會讓出一次——時間剛好夠把指示畫出來——
然後就佔住執行緒直到表格建完。指示會出現，但不會在建立期間動起來。要讓它動起來，就得一次建立一小步表格，
那是更大的改動，這裡沒有做。

`scrambler.layout` 與 `scrambler.solvedState` 的存在，是為了讓選單能在還沒打亂任何東西之前就畫出每個魔術方塊。
`stateLength` 既是狀態的長度，也是佈局中的塊數，這一點有經過檢查。

它負責打亂，並說明如何畫出結果；它不負責解題。只有兩種魔術方塊有 `Solver`；其餘的不是用不上，
就是從 5x5x5 起，打亂時本來就不需要解算器。

## Command line

```bash
dart pub global activate mochi_cube
```

```
mochi_cube scramble <puzzle>                             a scramble: 3x3, 2x2, 4x4 … 7x7, megaminx, pyraminx, skewb, sq1, clock
mochi_cube solve <state>                                 the moves back; the state says which puzzle (not 5x5 and up, nor megaminx)
mochi_cube show <state>                                  draw it as a net of letters
mochi_cube practice <pll|oll|f2l>                        a drill scramble
mochi_cube pattern <name>                                the moves that make a known pattern
mochi_cube tables                                        build the caches, and say where they went
```

```console
$ mochi_cube scramble --show
R F' U2 F2 U B' R2 F' D2 B D2 F2 R D2 L2 F2 D2 R' B2 L' B2
      U U D
      R U B
      D R U
F D F L U B L R L B F L
U L L D F L U R D F B B
D F D R R R F L B R B R
      B F U
      L D B
      F D U
```

`--seed` 可重複一次執行，`-n` 可要求多個，`--state` 會印出貼紙，好讓它們能透過管線接回 `solve`。
這個工具呼叫的是程式本身會呼叫的同一個函式庫，所以命令列上的打亂若是錯的，套件裡的也是錯的。

## The web

它能在網頁上執行，並且有測試確保這一點：套件會以 dart2js 編譯，並把答案與 VM 的比對，
且使用固定的種子，好讓兩邊有東西可以不一致。

有兩件事不得不讓步。min2phase 把一個排列剩餘的值放在 64 位元的暫存器裡，每個值四位元，
而在網頁上 Dart 的 `int` 是一個有 53 位元尾數的 double，其位元運算子會截斷成 32 位元——
所以這個暫存器在這裡改為一個重複使用的小清單。另外也沒有檔案系統，所以表格快取放在條件式匯入之後：
`tableDirectory` 是 `String?` 並回傳 null，表格在每次啟動時於記憶體中建立，而不是保存起來。
這在一次工作階段的第一次解題時約花費 600ms，之後則不花任何時間。

這兩件事在其他任何測試中都看不出來，因為其他所有測試都是在 VM 上執行。

## Colours, and drawing it

顏色刻意不內建。

`CubieCube.fromFaceletString` 會讀六個中心塊來為顏色命名，所以任何六個不同的字母都行——
`"UUU…RRR…"`、`"WWW…RRR…"`、`"111…222…"` 都會解析成同一個魔術方塊。請挑選適合你介面的配色。

*有*內建的是幾何，因為哪個貼紙貼在哪個旁邊是魔術方塊本身的知識，而不是繪圖偏好——
而對 Pyraminx 來說，重新推導展開圖是真正的工作。`toFacelets()` 給出貼紙，layout 給出多邊形，
兩者逐個索引對應：

```dart
final facelets = cube.toFacelets();
final fit = cubeLayout.fitInto(size.width, size.height);

for (var i = 0; i < facelets.length; i++) {
  final path = Path()..addPolygon([
    for (final (x, y) in cubeLayout[i])
      Offset(x * fit.scale + fit.dx, y * fit.scale + fit.dy),
  ], true);
  canvas.drawPath(path, Paint()..color = myColours[facelets[i]]);
}
```

| puzzle   | layout            | shape                          |
| -------- | ----------------- | ------------------------------ |
| 3x3x3    | `cubeLayout`      | 54 個正方形，常見的十字展開圖     |
| 2x2x2    | `pocketLayout`    | 24 個正方形，同樣的展開圖        |
| NxNxN    | `cubeNetLayout(n)` | `6 * n * n` 個正方形，同樣的展開圖；4x4x4 也是 |
| Megaminx | `megaminxLayout`  | 132 塊，TNoodle 的兩朵花        |
| Pyraminx | `pyraminxLayout`  | 36 個三角形，正四面體展開圖      |
| Skewb    | `skewbLayout`     | 30 塊，方塊的十字展開圖          |
| Square-1 | `square1Layout`   | 風箏形與楔形，依狀態挑選          |
| Clock    | `clockLayout`     | 18 個轉盤與 8 根針，以圓形表示    |

Square-1 的貼紙不會留在原位：一個槽位依狀態而放著一個邊塊或半個角塊。所以 `Square1Layout` 保存的是
一塊在每個槽位中會有的多邊形，`stickers(state)` 則給出某個狀態所用到的那些，每個都附上它的面——
每個角塊一個風箏形，和 csTimer 與 TNoodle 的畫法相同。

`Layout` 是 sealed，所以對這三種的 switch 不需要預設分支，若將來出現第四種，編譯器會告訴你：

```dart
Widget paint(Scrambler scrambler, List<int> state) => switch (scrambler.layout) {
  final PuzzleLayout layout => CustomPaint(painter: StickerPainter(layout, state)),
  final Square1Layout layout => CustomPaint(painter: PiecePainter(layout.stickers(state))),
  final ClockLayout layout => CustomPaint(painter: DialPainter(layout, state)),
};
```

沒有顏色、沒有線寬，貼紙之間也沒有間隙：間隙是你自己的一次內縮，配色則由你選擇。
同樣的點也用來做點擊測試，所以點選貼紙來輸入狀態，用的就是你已經畫好的那個多邊形。

Pyraminx 的展開圖是經過檢驗的，而不是用眼睛看。正四面體展開成一個由四個三角形組成的大三角形，
它的六個展開點是三個邊的中點——每個由三個面共用——以及三個外側的角，這三個角其實是同一個頂點被看了三次；
頂點 `v` 位於除了 `v` 以外的每一個面上，所以中間那個面所缺少的頂點就是在外側的那個，
這一點同時就把四個面都固定了。測試接著要求每一道摺線都畫成連在一起：同一個邊塊的兩個貼紙共用一整條邊。

## The rest of it

```dart
// Turn the whole cube, and carry a solution over with it.
final rotated = cube.rotated(Rotation.y());
final moves = solution.algorithm.rotated(Rotation.y());

// Solve one cube into another rather than into a solved one.
Search.patternize(cube, Patterns.checkerboard.cube);

// Progressively shorter solutions, as they are found.
await for (final solution in Search.solveDeeply(cube, maxTime: Duration(seconds: 2))) {
  print(solution); // 21 moves, then 19, then …
}

// Fifteen well known patterns, as algorithms.
Patterns.checkerboard;  // U2 D2 F2 B2 L2 R2
Patterns.all;           // by name

// Store and reload a cube.
CubieCube.fromJson(cube.toJson());
```

`Algorithm` 是貫穿全局的通用單位：打亂、花樣與解法都是同一種型別，具備 `parse`、`inverse`、`+`、`*` 與 `cube`。

## How it is checked

解算器不是拿自己來測試自己。每個主張都要對照獨立的東西，或是對照結構上的不變量來檢驗：

- 把解法套回方塊，與還原後的 facelet 字串比對，所以錯誤的表格會讓測試失敗，
  而不是回傳看似合理卻錯誤的答案
- min2phase 的表格與 kociemba 的距離做**窮舉**比對：全部 2,096,325 個第一階段配對，
  以及兩張各 967,680 個配對的第二階段表格
- 唯一沒有 kociemba 對應物的那張表，則與涵蓋其整個 2,822,400 個狀態空間的原始廣度優先搜尋比對
- 沒有參照物的地方，以不變量代替——對稱用群的封閉性，縮減用軌道—穩定子（orbit-stabiliser），
  隨機狀態產生器用 coupon collector 估計

縮減上的錯誤就是這樣被抓到的。把邊塊翻轉依全部 16 種對稱做縮減，會有 256,424 次把距離不同的狀態放進同一個類別，
所以它必須使用 8 個元素的子群；而忽略 `symState` 的廣度優先搜尋，會讓 2.8% 的格子偏高，
這使啟發式函數不可採納（inadmissible），並讓搜尋錯過解法。沒有窮舉比對，這兩者都看不出來。

371 個測試，`dart test`。

## License

GPLv3，見 [LICENSE](LICENSE)。這不是輕率的選擇：本套件有很大一部分是 GPLv3 程式碼的移植，
所以只能以相同的條款散布。

- 3x3x3 解算器是 Shuang Chen 的 [min2phase](https://github.com/cs0x7f/min2phase) 的移植版。
- Square-1 解算器是他的 sq12phase 的移植版，4x4x4 解算器是他的 threephase 的移植版，
  兩者都採用 [tnoodle-lib](https://github.com/thewca/tnoodle-lib) 中所附的版本。
- Megaminx 的轉動、測試中的 Square-1 參照模型，以及隨機轉動打亂的規則，都來自 WCA 官方的打亂程式 TNoodle，
  所以這裡的打亂就是官方程式會產生的那種。

## Roadmap

2x2x2 到 7x7x7、Megaminx、Pyraminx、Skewb、Square-1 與 Clock 都已實作。
以下所列的都是想要但尚未寫的。

### Other puzzles

打亂取決於一個問題：這個魔術方塊能否快到足以使用隨機狀態？可以的話，打亂就是均勻隨機抽取的狀態，解開再反過來，如上所述。
不行的話，就是隨機轉動。

| Puzzle       | Method       | What it needs                                    |
| ------------ | ------------ | ------------------------------------------------ |
| 2x2x2        | 隨機狀態      | **done**                                         |
| 3x3x3        | 隨機狀態      | **done**                                         |
| 4x4x4        | 隨機狀態      | **done**                                         |
| 5x5x5        | 隨機轉動      | **done**                                         |
| 6x6x6        | 隨機轉動      | **done**                                         |
| 7x7x7        | 隨機轉動      | **done**                                         |
| Pyraminx     | 隨機狀態      | **done**                                         |
| Megaminx     | 隨機轉動      | **done**                                         |
| Skewb        | 隨機狀態      | **done**                                         |
| Square-1     | 隨機狀態      | **done**                                         |
| Clock        | 隨機狀態      | **done**                                         |
| FTO          | 隨機狀態      | **done**                                         |

依 WCA 規則 4b3，各自有自己的最少步數：2x2x2 為四步，Pyraminx 六步，Skewb 七步，Square-1 十一步，
其餘為兩步。兩種打亂產生器都把它當作參數。

記法不再只屬於 3x3x3：`MoveSet` 說明一個魔術方塊的各軸與各幅度叫什麼，並涵蓋任何以若干種幅度轉動若干個軸的方塊——
包含 Skewb 與 FTO。Square-1 覆寫了一步的讀取與書寫方式，而 Clock 根本不是一串轉動。
Megaminx 也沒有那麼貼合。

### Named cases

練習用的打亂可以均勻抽取各種情形，但還不能指定要某一個*特定*的——「給我一個 T-perm」、「練這個 OLL」。
分組已經以 `pllCases` 與 `ollCases` 存在；缺少的是配套的名稱與辨識圖樣，那是資料輸入而不是演算法。
