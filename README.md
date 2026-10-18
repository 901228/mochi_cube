# mochi_cube

Twisty puzzle solvers and scramble generators in pure Dart, no Flutter
dependency. The 2x2x2 to the 7x7x7 bar the 4x4x4, the Pyraminx, the Skewb, the
Square-1 and the Clock so far, as a library and as a [command line tool](#command-line).

For the 3x3x3 there are two solvers. The one you want is a port of Chen Shuang's
[min2phase](https://github.com/cs0x7f/min2phase); the other is a plainer
implementation of Herbert Kociemba's two-phase algorithm, kept because it is the
independent reference every table in the first one is checked against.

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

Measured over the same 100 random cubes, after the tables are built:

|              | min2phase | kociemba |
| ------------ | --------- | -------- |
| solve        | 13.4ms    | 24.8ms   |
| moves        | 20.6      | 22.9     |
| tables       | 1.0 MB    | 4.9 MB   |
| first build  | ~600ms    | ~1.1s    |
| cached load  | ~90ms     | ~30ms    |

The difference is symmetry reduction. Two cube states related by one of the 16
symmetries are the same distance from solved, so min2phase's tables store one
entry per equivalence class rather than one per state — 2768 classes where there
are 40320 edge permutations, and so on. Same pruning power, a tenth of the
memory.

Both are behind one interface:

```dart
SolveResult solve(String facelets, {int maxLength, Duration? maxTime});
```

`min2phase` and `kociemba` are ready-made instances. Import
`package:mochi_cube/mochi_cube.dart` for the first, `package:mochi_cube/kociemba.dart`
for the second. They are separate libraries because both define a `CubieCube`
with different internals, so neither can be exported alongside the other.

Tables are built on first use and cached under the platform's app-data
directory. `Phase1Tables.useTwistFlipPrune = false` trades the largest table for
speed: 644 KB and 21.5ms instead of 1.0 MB and 13.4ms, with no change to
solution length.

## The 2x2x2

`package:mochi_cube/pocket.dart`, and a different problem entirely. Where the
3x3x3 has 4.3 × 10^19 states and needs a two-phase search, the 2x2x2 has
3,674,160 — few enough to hold the exact distance to solved for every one of
them. So there is no search: solving is a walk downhill, taking any move that
leaves you one step nearer.

```dart
import "package:mochi_cube/pocket.dart";

final scramble = randomPocketScramble();
final result = pocket.solve(scramble.cube.toPocketFaceletString());
// always the shortest solution that exists
```

| | |
| ---------- | ------------------------------------- |
| solve      | 1.2μs, and always optimal             |
| moves      | 8.8 average, 11 at worst              |
| table      | 1.9 MB, built in ~570ms, loaded in ~25ms |

11 is God's number for the puzzle. The table's distance histogram matches the
published one exactly, down to the 2,644 states that need all eleven — which is
a stronger check on it than anything the 3x3x3 tables get.

A 2x2x2 has no centres, so nothing announces which colour is which face.
`PocketCube.fromFaceletString` works it out: the corner held still names three
faces by definition, and each remaining colour is opposite whichever of those it
never shares a corner with. Any six letters in any scheme parse, same as the
3x3x3.

## Scrambles

Two generators, and they are not interchangeable.

```dart
randomStateScramble()          // what the WCA means by a scramble
randomScramble(moves: 20)      // random turns
```

`randomStateScramble` draws evenly from all 43,252,003,274,489,856,000 states,
solves it, and reverses the solution — which is how the WCA's own scrambler
works. It costs one solve and comes out around 20 moves. It also honours WCA
regulation 4b3, which asks a scramble to be at least two moves from solved.

`randomScramble` just turns random faces. Cheap, but the states it reaches are
not evenly distributed and a short one can leave the cube nearly solved. Use it
where the distribution does not matter.

## The Pyraminx

`package:mochi_cube/pyraminx.dart`. Like the 2x2x2, small enough to hold the
exact distance for every state, so solving is a walk downhill and the answer is
always optimal.

```dart
import "package:mochi_cube/pyraminx.dart";

final scramble = randomPyraminxScramble();
// B' L' U R U L U L' l b'

final cube = PyraminxCube()..apply(scramble);
print(PyraminxSearch.solve(cube)); // the shortest way back
```

| | |
| ---------- | --------------------------------------- |
| solve      | 1.3μs, and always optimal               |
| turns      | 7.8 average, 11 at worst                |
| table      | 463 KB, built in ~180ms, loaded in ~25ms |

933,120 states, God's number 11, and the distance histogram matches the
published one. The tips are left out of the *tables* — each is one turn on its
own — so `solveLayers` is the optimal part and `solve` finishes them off.

`toFaceletString` renders the 36 stickers, four faces of nine. Reading them back
needs no centres, which a Pyraminx has not got: a vertex piece never leaves its
corner and touches every face but one, so the colour it never shows names that
face.

This is where the notation finally had to become the puzzle's business rather
than the library's. A Pyraminx turns four vertices and four tips by two amounts
where a 3x3x3 turns six faces by three, so `MoveSet` now says what the axes and
amounts are called, and an `Algorithm` carries the one it is written in. The
2x2x2 needed none of that, because its turns are the 3x3x3's.

## The Skewb

`package:mochi_cube/skewb.dart`. The third puzzle small enough to hold the exact
distance for every state, so again solving is a walk downhill and the answer is
always optimal.

```dart
import "package:mochi_cube/skewb.dart";

final scramble = randomSkewbScramble();
// R U' B L' R B' U L

final cube = SkewbCube()..apply(scramble);
print(SkewbSearch.solve(cube)); // the shortest way back
```

| | |
| ---------- | ----------------------------------------- |
| solve      | 2.4μs, and always optimal                 |
| turns      | 8.4 average, 11 at worst                  |
| table      | 1.5 MB, built in ~600ms, loaded in ~100ms |

3,149,280 states, God's number 11, and the distance histogram matches the
published one. The notation is WCA regulation 12h: `R`, `U`, `L` and `B` turn
the corners down-back-right, up-back-left, down-front-left and down-back-left,
so the up-front-right corner never moves and holds the puzzle still.

The cube is kept as its 30 stickers, and each turn is worked out from where the
stickers are in space rather than written down. The corners and the centres are
then numbered by walking every turn from solved, so there is no parity or twist
rule to get wrong: 8748 corner states and 360 centre states, which multiply to
the published count. Reading stickers back takes the colours from the corner
that never moves, as the 2x2x2 does.

## The Square-1

`package:mochi_cube/square1.dart`, a port of Chen Shuang's
[sq12phase](https://github.com/cs0x7f/sq12phase), which the official TNoodle
scrambler and csTimer both use. Far too many states for a table of distances,
so it is a two-phase search: back to a cube of a parity phase 2 can finish, then
solved as a cube.

```dart
import "package:mochi_cube/square1.dart";

final scramble = randomSquare1Scramble();
// (1,0) / (-1,2) / (0,-3) / …

final cube = Square1Cube()..apply(scramble);
print(Square1Search.solve(cube));
```

| | |
| ---------- | --------------------------------------------- |
| solve      | about 25ms, not optimal                       |
| moves      | 24 average, 29 at worst, counted as 12c4 does |
| tables     | under 400 KB, built in ~0.2s, not cached      |

The notation is WCA regulation 12d's: `(x,y)` turns the top and bottom, `/` the
right half, and each is one move, so `Algorithm.length` is the WCA move count.
That is not faces and amounts, so `square1Moves` is a `MoveSet` that overrides
how a move is read and written; `MoveSet.tokensOf` is the one hook that needed,
since `(1,0)/` runs two moves together. Every turn is checked against TNoodle's
own model of the puzzle, ported into the test as the reference.

A state is the piece in each of the 24 slots and the middle, written as 24 hex
digits and a 0 or 1 by `toString` and read back by `Square1Cube.parse`. A corner
across the cut is held rather than refused, since turning a layer part way gets
there; the solver turns it back into line first.

A scramble is drawn as TNoodle draws one, evenly from every state `/` can be
turned in, and must be at least eleven moves (4b3). That is checked against the
solution found rather than an optimal one, so it is an upper bound — see the
`shortcut:` on `randomSquare1Scramble`.

## The 5x5x5, 6x6x6 and 7x7x7

`package:mochi_cube/nxn.dart`. These the WCA scrambles by random turns rather
than a random state, so nothing here solves them: the scramble needs the turns
and nothing else.

```dart
import "package:mochi_cube/nxn.dart";

final scramble = randomNxNScramble(6);
// 3Uw2 R' Fw R2 3Rw2 D' Bw Rw Dw2 3Uw …

final cube = NxNCube(6)..apply(scramble);
cube.toFacelets(); // 216 stickers, drawn by cubeNetLayout(6)
```

The turns are TNoodle's: every face one layer deep and wider up to half the
cube, `Rw` for two layers and `3Rw` for three, 60 of them for a 5x5x5, 80 for a
6x6x6 and 100 for a 7x7x7. An even cube's second half is left out, since `3Lw`
is `3Rw'` with the cube held differently. Each turn is drawn evenly from those
that would not cancel or merge with one already made — the last, or an earlier
one with only turns of the same axis between.

TNoodle decides that by comparing whole states up to rotation; here it is
worked out on how far each layer of the axis turns, which is the same question
and is checked against the whole-state comparison in the test. `NxNCube` keeps
its stickers and works its turns out from where they are in space, as the Skewb
does, and is checked against the 3x3x3 and the 2x2x2 at those sizes. A scramble
takes 2 to 4ms.

## The Clock

`package:mochi_cube/clock.dart`, and the odd one out: no search, and no table
either.

```dart
import "package:mochi_cube/clock.dart";

final scramble = randomClockScramble();
// UR2- DR5- DL0+ UL1+ U2+ R0+ D3+ L5- ALL5- y2 U4- R3- D1+ L2- ALL3+

scramble.movesToSolve;  // however many dials are off twelve o'clock
scramble.inverse;       // the moves that put it back
```

Fourteen dials of twelve positions, and fourteen moves that each turn exactly
one of them. The moves commute and none undoes another, so the puzzle is the
group `(Z12)^14`: composing states adds them and solving negates them. Its
notation *is* its state, which is why a scramble is fourteen numbers written
down and nothing more.

Two things fall out that every other puzzle needs work for. Every state is
reachable, so there is no such thing as an invalid one; and the fewest moves to
solve is exactly how many dials are off zero, since one move fixes one dial by
any amount.

`toDials()` gives the eighteen dials you can see, nine a side, and
`ClockDialReading.fromDials` reads them back. They are a linear image of the
fourteen: four of them are corner pieces showing through both sides, which is
exactly why eighteen dials are only fourteen numbers.

That mapping was worked out from the mechanism rather than written down, and
then checked three ways — the fourteen moves come out independent over Z12, so
they really do reach 12^14; exactly four dials turn out locked to their opposite
number; and those four are exactly the corners. None of that is asserted in the
table, it falls out of it.

## Practice scrambles

Scrambles that leave one step of a solve to do, for drilling it:

```dart
pllPracticeScramble();               // bottom two layers solved, top oriented
ollPracticeScramble();               // bottom two layers solved, top misoriented
f2lPracticeScramble();               // cross solved
f2lPracticeScramble(solvedPairs: 3); // and three slots filled: last pair drills
```

Each is a uniformly random state of the kind that step starts from, solved and
reversed — the same construction as a full scramble, with part of the cube held
still. `randomStateWith` is the general form if you want a different split.

By default these draw evenly from the **states**, so cases turn up as often as
they really do — a T-perm four times as often as an H-perm, and a PLL skip about
one time in 72. That is what you want to rehearse solving.

To learn a set you want the opposite, or the symmetric cases get a quarter of
the practice:

```dart
pllPracticeScramble(spread: PracticeSpread.cases);
ollPracticeScramble(spread: PracticeSpread.cases);
```

The difference is real. A PLL case covers 16 of the 288 states if it has no
symmetry, but H, Z, E and N cover 8 or 4, and 51 of the 57 OLLs cover 4
orientations where two cover only one. `pllCases` and `ollCases` are the
groupings themselves, 21 and 57 of them.

## One interface for all of them

The puzzles are kept apart everywhere else on purpose, so their scramble
functions have different names, different arguments and — for the Clock, whose
scramble is a set of dial positions rather than a sequence of turns — a
different return type. That is right for code that knows which puzzle it wants,
and wrong for a screen with a puzzle picker on it.

```dart
import "package:mochi_cube/scramblers.dart";

puzzleScramblers;                     // {333: …, 222: …, 555: …, …, sq1: …, clock: …}

final scrambler = puzzleScramblers[saved]!;
final scramble = await scrambler.next();

scramble.notation;   // "R U2 F' …", or "UR4+ DR0+ … ALL6+"
scramble.state;      // one number per piece of scrambler.layout
scramble.algorithm;  // the moves, or null for the Clock
```

The keys are the WCA event ids — `333`, `222`, `555`, `666`, `777`, `pyram`,
`skewb`, `sq1`, `clock` — rather
than a spelling of our own, since those are what the rest of the speedcubing world
writes and what the official scrambler is asked for. A saved setting can then
name a puzzle without depending on the order they happen to be declared in, and
`.values` is still the order a picker would list them in, since Dart maps keep
theirs.

`practiceScramblers` is the same three drills behind the same interface, keyed
`pll`, `oll` and `f2l`, so a drill picker is one more map. `allScramblers` is
both together.

### Why `next` is a future

The first scramble of a session is far slower than the rest, because it builds
the puzzle's tables:

| | first | then |
| --- | --- | --- |
| `333` | 1780ms | 24ms |
| `222` | 1003ms | 0.1ms |
| `pyram` | 333ms | 0.1ms |
| `skewb` | 593ms | 0.1ms |
| `sq1` | 120ms | 29ms |
| `555` | 19ms | 2ms |
| `777` | 6ms | 3.4ms |
| `clock` | 1ms | 0ms |

Measured under dart2js, where there is no cache to load them from; on a platform
with a filesystem only the very first run pays it. A future means a caller can
put a progress indicator up rather than freezing on a tap.

It does **not** move the work elsewhere. Dart has no threads on the web, so
awaiting yields once — long enough for the indicator to be painted — and then
holds the thread until the tables are built. The indicator appears; it will not
animate through the build. Making it animate would mean building the tables a
step at a time, which is a larger change and is not done here.

`scrambler.layout` and `scrambler.solvedState` are there so a picker can draw
each puzzle before anything has been scrambled. `stateLength` is both the length
of a state and the number of pieces in the layout, which is checked.

It scrambles and it says how to draw the result; it does not solve. Only two of
the puzzles have a `Solver`; the rest either do not need one or, from the 5x5x5
up, are scrambled without one.

## Command line

```bash
dart pub global activate mochi_cube
```

```
mochi_cube scramble <puzzle>                             a scramble: 3x3, 2x2, 5x5 … 7x7, pyraminx, skewb, sq1, clock
mochi_cube solve <state>                                 the moves back; the state says which puzzle (not 5x5 and up)
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

`--seed` repeats a run, `-n` asks for several, `--state` prints the stickers so
they can be piped back into `solve`. The tool calls the same library a program
would, so a scramble that is wrong on the command line is wrong in the package.

## The web

It runs there, and a test keeps it that way: the package is compiled with
dart2js and its answers compared against the VM's, seeded so that the two have
something to disagree about.

Two things had to give. min2phase keeps a permutation's remaining values in a
64-bit register, four bits each, and on the web a Dart `int` is a double with 53
bits of mantissa whose bitwise operators truncate to 32 — so that register is a
small reused list here instead. And there is no filesystem, so the table cache
is behind a conditional import: `tableDirectory` is `String?` and comes back
null, and the tables are built in memory at each start rather than kept. That
costs about 600ms on the first solve of a session and nothing after it.

Neither shows up in any other test, because every other test runs on the VM.

## Colours, and drawing it

Colours are not built in, on purpose.

`CubieCube.fromFaceletString` reads the six centres to name the colours, so any
six distinct letters work — `"UUU…RRR…"`, `"WWW…RRR…"`, `"111…222…"` all parse
to the same cube. Pick whatever scheme suits your UI.

What *is* built in is the geometry, because which sticker is next to which is
puzzle knowledge rather than a drawing preference — and for a Pyraminx, working
the net out again is real work. `toFacelets()` gives the stickers and a layout
gives the polygons, index for index:

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
| 3x3x3    | `cubeLayout`      | 54 squares, the usual cross net |
| 2x2x2    | `pocketLayout`    | 24 squares, the same net        |
| NxNxN    | `cubeNetLayout(n)` | `6 * n * n` squares, the same net |
| Pyraminx | `pyraminxLayout`  | 36 triangles, the tetrahedron net |
| Skewb    | `skewbLayout`     | 30 pieces, the cube's cross net  |
| Square-1 | `square1Layout`   | kites and wedges, picked by the state |
| Clock    | `clockLayout`     | 18 dials and 8 pins, as circles |

The Square-1's stickers do not stay where they are: a slot holds an edge or half
a corner depending on the state. So `Square1Layout` holds the polygons a piece
would have in each slot, and `stickers(state)` gives the ones a state uses, each
with its face — a kite per corner, as csTimer and TNoodle draw it.

`Layout` is sealed, so a switch over the three kinds needs no default branch and
the compiler will tell you if a fourth kind ever appears:

```dart
Widget paint(Scrambler scrambler, List<int> state) => switch (scrambler.layout) {
  final PuzzleLayout layout => CustomPaint(painter: StickerPainter(layout, state)),
  final Square1Layout layout => CustomPaint(painter: PiecePainter(layout.stickers(state))),
  final ClockLayout layout => CustomPaint(painter: DialPainter(layout, state)),
};
```

No colours, no line widths and no gaps between stickers: a gap is one inset of
your own, and a colour scheme is yours to choose. The same points also do
hit testing, so tapping a sticker to enter a state is the polygon you already
drew.

The Pyraminx net is checked rather than eyeballed. A tetrahedron unfolds into
one triangle of four, and its six net points are the three edge midpoints —
each shared by three faces — and three outer corners which are all the same
vertex seen three times; vertex `v` is on every face but `v`, so the vertex the
middle face lacks is the one on the outside, and that pins all four faces down
at once. The test then asks that each fold be drawn joined: the two stickers of
one edge piece share a full side.

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

`Algorithm` is the currency throughout: scrambles, patterns and solutions are
all one type, with `parse`, `inverse`, `+`, `*` and `cube`.

## How it is checked

The solvers are not tested against themselves. A claim is checked against
something independent, or against a structural invariant:

- a solution is applied back to the cube and compared with the solved facelet
  string, so a wrong table fails a test rather than returning a plausible but
  wrong answer
- the min2phase tables are compared **exhaustively** with the kociemba
  distances: all 2,096,325 phase 1 pairs and both 967,680-pair phase 2 tables
- the one table with no kociemba counterpart is compared with a raw
  breadth-first search over its whole 2,822,400-state space
- where no reference exists, an invariant stands in — group closure for the
  symmetries, orbit-stabiliser for the reductions, the coupon collector estimate
  for the random state generator

That is how the reduction bugs were caught. Reducing edge flip over all 16
symmetries puts states of different distance in the same class 256,424 times, so
it has to use an 8-element subgroup; and a breadth-first search that ignores
`symState` leaves 2.8% of cells too high, which makes the heuristic
inadmissible and lets the search miss solutions. Neither shows up without an
exhaustive comparison.

339 tests, `dart test`.

## Roadmap

The 2x2x2, 3x3x3, 5x5x5, 6x6x6, 7x7x7, Pyraminx, Skewb, Square-1 and Clock are
implemented. Everything below is wanted but not written.

### Other puzzles

Scrambling divides on one question: can the puzzle be solved fast enough to use
a random state? Where it can, the scramble is a uniformly random state solved
and reversed, as above. Where it cannot, it is random turns.

| Puzzle       | Method       | What it needs                                    |
| ------------ | ------------ | ------------------------------------------------ |
| 2x2x2        | random state | **done**                                         |
| 3x3x3        | random state | **done**                                         |
| 4x4x4        | random state | a staged reduction solver — much the largest job |
| 5x5x5        | random turns | **done**                                         |
| 6x6x6        | random turns | **done**                                         |
| 7x7x7        | random turns | **done**                                         |
| Pyraminx     | random state | **done**                                         |
| Megaminx     | random turns | 70 turns, in the fixed `R++ D--` pattern         |
| Skewb        | random state | **done**                                         |
| Square-1     | random state | **done**                                         |
| Clock        | random state | **done**                                         |
| FTO          | random state | its own solver                                   |

Each has its own minimum, per WCA regulation 4b3: 2x2x2 four moves, Pyraminx
six, Skewb seven, Square-1 eleven, the rest two. Both scramble generators take
that as a parameter.

The notation is no longer the 3x3x3's alone: `MoveSet` says what a puzzle's axes
and amounts are called, and covers anything that turns some number of axes by
some number of amounts — Skewb and FTO included. The Square-1 overrides how a
move is read and written, and the Clock is not a sequence of turns at all.
Megaminx does not fit as neatly either.

### Named cases

The practice scrambles can draw a case evenly, but they cannot yet be asked for
a *particular* one — "give me a T-perm", "drill this OLL". The groupings exist
as `pllCases` and `ollCases`; what is missing is the names and the recognition
patterns to go with them, which is data entry rather than algorithm.
