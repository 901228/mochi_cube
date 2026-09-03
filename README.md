# mochi_cube

Rubik's Cube solvers in pure Dart, no Flutter dependency.

Two of them. The one you want is a port of Chen Shuang's
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

121 tests, `dart test`.

## Roadmap

Only the 3x3x3 is implemented. Everything below is wanted but not written.

### Other puzzles

Scrambling divides on one question: can the puzzle be solved fast enough to use
a random state? Where it can, the scramble is a uniformly random state solved
and reversed, as above. Where it cannot, it is random turns.

| Puzzle       | Method       | What it needs                                    |
| ------------ | ------------ | ------------------------------------------------ |
| 2x2x2        | random state | one breadth-first search over all 3,674,160 states |
| 3x3x3        | random state | **done**                                         |
| 4x4x4        | random state | a staged reduction solver — much the largest job |
| 5x5x5        | random turns | 60 turns                                         |
| 6x6x6        | random turns | 80 turns                                         |
| 7x7x7        | random turns | 100 turns                                        |
| Pyraminx     | random state | one breadth-first search over 933,120 states     |
| Megaminx     | random turns | 70 turns, in the fixed `R++ D--` pattern         |
| Skewb        | random state | one breadth-first search over 3,149,280 states   |
| Square-1     | random state | a two-phase search, shape then permutation       |
| Clock        | random state | no search at all: the notation *is* the state    |
| FTO          | random state | its own solver                                   |

2x2x2, Pyraminx and Skewb are the easy ones: their state spaces are small enough
to hold the exact distance to solved for every state, so no two-phase search is
needed and `fillPruningTable` already does the work. Clock needs nothing —
every state is reachable and the notation encodes it directly. 5x5x5 and up are
the *easiest* to scramble, since random turns need no solver at all; it is
solving them that is out of reach.

Each has its own minimum, per WCA regulation 4b3: 2x2x2 four moves, Pyraminx
six, Skewb seven, Square-1 eleven, the rest two. `randomStateScramble` already
takes that as a parameter.

This will force one design change first: `Algorithm` and the notation assume the
3x3x3's eighteen turns. Supporting another puzzle means making the move set
something a puzzle supplies rather than something the library hard-codes.

### Practice scrambles

Scrambles that leave one step of a solve to do, for drilling it:

- **F2L** — cross solved, the four slots random
- **OLL** — F2L solved, last layer misoriented
- **PLL** — everything solved but the last layer's permutation

The mechanism is the same for all three and reuses what is already here: build a
cube with the finished part solved and the rest randomised, solve it with the
existing search, and reverse the solution. The work is in generating the
constrained state, which is a matter of setting the coordinates that are already
exposed, plus a way to ask for a specific case rather than a random one.
