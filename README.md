# mochi_cube

Twisty puzzle solvers and scramble generators in pure Dart, no Flutter
dependency. The 3x3x3, the 2x2x2, the Pyraminx and the Clock so far.

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
published one. The tips are left out of the puzzle — each is one turn on its own
and cannot be got wrong — so they are added to a scramble rather than solved.

This is where the notation finally had to become the puzzle's business rather
than the library's. A Pyraminx turns four vertices and four tips by two amounts
where a 3x3x3 turns six faces by three, so `MoveSet` now says what the axes and
amounts are called, and an `Algorithm` carries the one it is written in. The
2x2x2 needed none of that, because its turns are the 3x3x3's.

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

The eighteen dials you can see are not modelled — they are a linear image of
these fourteen, and belong to whatever draws the puzzle, the same as sticker
colours do.

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

## Colours and rendering

Neither is built in, on purpose.

`CubieCube.fromFaceletString` reads the six centres to name the colours, so any
six distinct letters work — `"UUU…RRR…"`, `"WWW…RRR…"`, `"111…222…"` all parse
to the same cube. Pick whatever scheme suits your UI.

`toFacelets()` returns the 54 stickers as face indices, which is everything a
renderer needs. Drawing them is left to the caller.

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

194 tests, `dart test`.

## Roadmap

The 3x3x3, the 2x2x2, the Pyraminx and the Clock are implemented. Everything
below is wanted but not written.

### Other puzzles

Scrambling divides on one question: can the puzzle be solved fast enough to use
a random state? Where it can, the scramble is a uniformly random state solved
and reversed, as above. Where it cannot, it is random turns.

| Puzzle       | Method       | What it needs                                    |
| ------------ | ------------ | ------------------------------------------------ |
| 2x2x2        | random state | **done**                                         |
| 3x3x3        | random state | **done**                                         |
| 4x4x4        | random state | a staged reduction solver — much the largest job |
| 5x5x5        | random turns | 60 turns                                         |
| 6x6x6        | random turns | 80 turns                                         |
| 7x7x7        | random turns | 100 turns                                        |
| Pyraminx     | random state | **done**                                         |
| Megaminx     | random turns | 70 turns, in the fixed `R++ D--` pattern         |
| Skewb        | random state | one breadth-first search over 3,149,280 states   |
| Square-1     | random state | a two-phase search, shape then permutation       |
| Clock        | random state | **done**                                         |
| FTO          | random state | its own solver                                   |

Skewb should go the way the 2x2x2 and the Pyraminx did: its state space is small
enough to hold the exact distance to solved for every state, so no two-phase
search is needed and `fillPruningTable` already does the work. 5x5x5 and up are
the *easiest* to scramble, since random turns need no solver at all; it is
solving them that is out of reach.

Each has its own minimum, per WCA regulation 4b3: 2x2x2 four moves, Pyraminx
six, Skewb seven, Square-1 eleven, the rest two. Both scramble generators take
that as a parameter.

The notation is no longer the 3x3x3's alone: `MoveSet` says what a puzzle's axes
and amounts are called, and covers anything that turns some number of axes by
some number of amounts — Skewb and FTO included. Megaminx does not fit as
neatly, and Square-1 and Clock are not face turns at all, so those will want
something of their own rather than a `MoveSet` bent to fit.

### Named cases

The practice scrambles can draw a case evenly, but they cannot yet be asked for
a *particular* one — "give me a T-perm", "drill this OLL". The groupings exist
as `pllCases` and `ollCases`; what is missing is the names and the recognition
patterns to go with them, which is data entry rather than algorithm.
