## Unreleased

### The Square-1

`package:mochi_cube/square1.dart`: `Square1Cube`, `Square1Search` and
`randomSquare1Scramble`, a port of Chen Shuang's sq12phase two-phase search, in
WCA `(x,y) /` notation. Scrambles are random states as TNoodle draws them, about
24 moves; turns are checked against TNoodle's own puzzle model. `Square1Scrambler`
is filed as `sq1`, and the command line scrambles, solves and shows it.

**Breaking.** `Layout` has a third kind, `Square1Layout`, since a Square-1's
stickers move with the state; a `switch` over layouts needs a case for it.
`MoveSet.tokensOf` is new, so a puzzle can say how its notation splits into
moves.

### The Skewb

`package:mochi_cube/skewb.dart`: `SkewbCube`, `SkewbSearch` and
`randomSkewbScramble`, in WCA notation with the up-front-right corner held still.
One breadth-first search covers all 3,149,280 states, so every solution is
optimal; the distance histogram matches the published one. `SkewbScrambler` is
filed as `skewb` in `puzzleScramblers`, `skewbLayout` draws it on the cube's
cross, and the command line scrambles, solves and shows it. The table is cached
as `skewb.bin`, 1.5 MB.

### `Layout` is sealed

**Breaking.** `Layout` was an `abstract mixin class`; it is now `sealed`, so a
`switch` over `PuzzleLayout` and `ClockLayout` is exhaustive and needs no default
branch. Code that mixed `Layout` in from outside the package no longer compiles —
nothing in the package did, and a caller draws with a layout rather than defining
one.

The three types moved to `lib/layout.dart`, since a sealed type's subtypes must
share its library. Imports do not change: `cube/layout.dart` and
`clock/layout.dart` re-export the types they use, and the instances
(`cubeLayout`, `pocketLayout`, `pyraminxLayout`, `clockLayout`) stay where they
were.

### `Scrambler.next` is a future

**Breaking.** `next` returns `Future<Scramble>`, so an app can show a progress
indicator instead of freezing on the first tap. The first scramble of a session
builds the puzzle's tables and is much slower than the rest — under dart2js,
1780ms against 24ms for the 3x3x3, 1003ms against 0.1ms for the 2x2x2.

It does not move the work off the thread; the web has none to move it to.
Awaiting yields once, which is enough for the indicator to be painted, and then
holds the thread until the tables are built. Animating through the build would
mean building the tables a step at a time, which is not done here.

`CliPuzzle.scramble` follows, and `yieldToEventLoop` in `table_storage.dart` is
the one-line helper — a `Duration.zero` timer rather than a microtask, since
Flutter paints from the timer queue and a microtask never lets a frame out.

Also fixed in `test/web_test.dart`: node defines no `self`, which dart2js
reaches for to schedule a timer, so the compiled program used to print nothing
at all rather than fail. It gets the shim now, and the comparison against the VM
covers asynchronous code again.

### Works on the web

The package did not compile for dart2js at all, so a Flutter app could not build
for web against it.

- min2phase's permutation coordinates kept the values still to be placed in a
  64-bit register, four bits each. On the web a Dart `int` is a double with 53
  bits of mantissa and the bitwise operators truncate to 32, so
  `0xFEDCBA9876543210` is neither representable nor shiftable. It is a small
  reused list now. `test/nperm_test.dart` says the numbering did not change with
  it: both directions against min2phase's original register arithmetic, over all
  40320 orderings of eight and a sample of the 479001600 of twelve.
- The table cache is behind a conditional import. `dart:io` and `app_dirs` live
  in `cache/table_store_io.dart`, and `cache/table_store.dart` is the version
  for platforms with no filesystem, which keeps nothing and fails at nothing.
  The tables are then built in memory at each start, about 600ms once per
  session.
- `tableDirectory` is `String?` — null where there is nowhere to cache.

`test/web_test.dart` is the guard: it compiles the package with dart2js and,
where there is a JavaScript engine to hand, runs it and compares every answer
against the VM's, seeded. Neither of these bugs showed up in any other test,
because every other test runs on the VM.

### Drawing

Sticker geometry, so a front end does not have to work a net out again. Which
sticker is next to which is puzzle knowledge; colours and line widths are not,
and are still left out.

- `PuzzleLayout` — one polygon per sticker, index-matched to `toFacelets()` —
  with `cubeLayout`, `pocketLayout` and `pyraminxLayout`
- `ClockLayout` and `clockLayout` for the eighteen dials and eight pins, which
  are circles rather than polygons
- `fitInto`, the scale and offset that centre a layout in a box
- `cubeNetPosition`, the usual cross; read that way no face needs turning or
  reflecting, since a face's first sticker is the top left of its square

The Pyraminx net is derived, not drawn by hand. A tetrahedron's six net points
are its three edge midpoints, each shared by three faces, and three outer
corners which are all the same vertex seen three times; vertex `v` is on every
face but `v`, so the vertex the middle face lacks is the one outside, and that
places all four faces at once. The tests then check the folds: the two stickers
of one edge piece share a full side, and the tips of a vertex meet at a point.

Also exported for drawing: `cornerFacelet`, `edgeFacelet`, `cornerFace` and
`edgeFace` for the 3x3x3; `tipSlots`, `vertexSlots`, `edgeSlots`,
`cornersOfFace` and `edgeBetween` for the Pyraminx; `dialBlock` for the Clock.

### One interface for all four puzzles

`package:mochi_cube/scramblers.dart`. The puzzles stay apart everywhere else,
but a screen with a puzzle picker on it wants a list, not four function names
with different signatures.

- `Scrambler` — `id`, `name`, `puzzleId`, `layout`, `stateLength`,
  `solvedState` and `next({random})` — with `CubeScrambler`, `PocketScrambler`,
  `PyraminxScrambler`, `ClockScrambler` and `PracticeScrambler`
- `Scramble` — the `notation`, the `state` it leaves, and the `algorithm`,
  which is null for the Clock since its scramble is not a sequence of turns
- `puzzleScramblers`, `practiceScramblers` and `allScramblers`: maps, keyed by
  the WCA event ids `333`, `222`, `pyram` and `clock`, and by `pll`, `oll` and
  `f2l` for the drills. A saved setting can name a puzzle without depending on
  declaration order, and `.values` is still a picker's order
- `Layout`, now a supertype of both `PuzzleLayout` and `ClockLayout`, so a
  scrambler can name where its pieces are drawn without saying which shape

Narrow on purpose: it scrambles and says how to draw the result, and does not
solve. Only two of the four puzzles have a `Solver` and the other two do not
need one.

The notation and the state have to agree, or an app would show a scramble that
does not match the picture beside it, so that is what the test checks: it
re-derives the state from the notation through the puzzle itself and compares.
The command line now goes through these too rather than calling each puzzle's
function, so the tool and an app cannot scramble differently.

### Command line

`dart pub global activate mochi_cube`, then `mochi_cube`. Six commands —
`scramble`, `solve`, `show`, `practice`, `pattern` and `tables` — over the same
library a program would call, so the tool cannot drift from it.

- `solve` and `show` work out which puzzle a state is from the state itself:
  the three sticker strings are different lengths and a clock's is not stickers
- `--seed` repeats a run, `-n` asks for several, `--state` prints stickers that
  pipe straight back into `solve`
- `--show` draws the state as a net of letters
- `runCli` takes its output sink, so the tests read back what it printed rather
  than shelling out

`tableDirectory` is now public: where every solver caches its tables.

### The Clock

`package:mochi_cube/clock.dart`. No search, and no table either: fourteen dials
of twelve positions and fourteen moves that each turn one of them, so the puzzle
is the group `(Z12)^14` and its notation is its state.

- `ClockState`, with `parse`, `inverse`, `+`, `movesToSolve` and `isSolved`
- `randomClockScramble`, which draws fourteen numbers and writes them down
- `toDials` and `ClockDialReading.fromDials` for the eighteen dials you can see

Every state is reachable, so nothing can be invalid, and the fewest moves to
solve is exactly how many dials are off zero.

The eighteen dials are a linear image of the fourteen, worked out from the
mechanism: a pin says which side its corner's wheel drives, and the corner dials
are single pieces showing through both. That last part is why eighteen dials are
only fourteen numbers, and it comes out of the table rather than being asserted
in it.

### The Pyraminx

`package:mochi_cube/pyraminx.dart`. 933120 states once the tips are set aside,
so as with the 2x2x2 one breadth-first search holds the exact number of turns to
solve for every one of them and every solution is optimal — 1.3μs, 7.8 turns on
average, 11 at worst, which is God's number for the puzzle.

- `PyraminxCube`, `PyraminxSearch.solve`, `solveLayers` and `distanceOf`
- `randomPyraminxCube` and `randomPyraminxScramble`, the scramble ending with
  the tips as one is written
- `toFacelets` and `toFaceletString` for the 36 stickers, and
  `PyraminxFacelet.fromFaceletString` to read them back

The tips are kept on the puzzle, since they are part of what it looks like, but
left out of the tables: each is one turn on its own. `solveLayers` is the
optimal part and `solve` finishes the tips afterwards.

Reading stickers needs no centres, which a Pyraminx has not got. A vertex piece
never leaves its corner and touches every face but one, so the colour it never
shows names that face, and any four letters work.

### Move sets

`MoveSet` says what a puzzle's turns are called — its axes and its amounts — and
an `Algorithm` now carries the one it is written in. The 3x3x3's is
`MoveSet.cube` and stays the default, so nothing that was written against it
changes.

This is what the Pyraminx needed and the 2x2x2 did not: four vertices and four
tips by two amounts, against six faces by three.

### Practice scrambles

Scrambles that leave one step of a CFOP solve to do, for drilling it:
`pllPracticeScramble`, `ollPracticeScramble` and `f2lPracticeScramble`, the last
taking a `solvedPairs` count so `solvedPairs: 3` drills the last pair.

Each is a uniformly random state of the kind that step starts from, solved and
reversed. `randomStateWith` is the general form — hold any set of pieces solved
and draw the rest evenly — along with `isCrossSolved`, `isF2lSolved` and
`isLastLayerOriented`.

By default they draw evenly from the **states**, so cases turn up as often as
they really do — a T-perm four times as often as an H-perm, and a PLL skip about
one time in 72. `PracticeSpread.cases` draws evenly from the **cases** instead,
which is what learning a set wants: otherwise the symmetric cases get a quarter
of the practice.

The two are genuinely different. A PLL case covers 16 of the 288 states when it
has no symmetry, but H, Z, E and N cover 8 or 4. `pllCases` and `ollCases` are
the groupings, 21 and 57 of them, worked out by asking which states a turn of U
before or after the algorithm reaches.

### The 2x2x2

`package:mochi_cube/pocket.dart`. A different problem from the 3x3x3: with
3,674,160 states, one breadth-first search holds the exact distance to solved
for every one of them, so there is no search. Solving walks downhill and every
solution is optimal — 1.2μs, 8.8 moves on average, 11 at worst, which is God's
number for the puzzle.

- `PocketSearch.solve` and `PocketSearch.distanceOf`
- `pocket`, a `Solver` like the other two
- `randomPocketCube` and `randomPocketScramble`, the latter honouring WCA
  regulation 4b3's four-move minimum — and exactly, not as a bound, since the
  solutions are optimal
- `PocketCube.fromFaceletString` and `toPocketFaceletString` for the 24 stickers

A 2x2x2 has no centres, so nothing says which colour is which face. The parser
works it out from two facts: the corner held still names three faces by
definition, and no corner carries two opposite colours.

It reuses the 3x3x3's cube model, move cubes, notation and `Algorithm`. A 2x2x2
is the corners of a 3x3x3, and U, R and F mean the same thing on both.

The distance histogram matches the published one for the puzzle exactly, down to
the 2,644 states that need all eleven moves.

## 1.0.0

First working version. The package solves a 3x3x3 and scrambles one.

### Solvers

- **min2phase**, a port of Chen Shuang's algorithm. Averages 13.4ms and 20.6
  moves over 100 random cubes. Its tables come to 1.0 MB, built in ~600ms and
  loaded from cache in ~90ms.
- **kociemba**, a plainer two-phase solver. 24.8ms and 22.9 moves on the same
  cubes, with 4.9 MB of tables. Kept as the independent reference the other
  one's tables are checked against.
- `Solver` is the interface both implement, with `min2phase` and `kociemba` as
  ready-made instances. `Solution` carries the moves and the time they took.
- Both take a `maxLength` and a `maxTime`.

What makes min2phase small is symmetry reduction: states related by one of the
16 symmetries are the same distance from solved, so a table holds one entry per
equivalence class rather than one per state. Same pruning power as the kociemba
tables, a tenth of the memory.

`Phase1Tables.useTwistFlipPrune` trades the largest table for speed — 644 KB and
21.5ms rather than 1.0 MB and 13.4ms, with no change to solution length.

### Scrambles

- `randomStateScramble` — a uniformly random state, solved and reversed, which
  is what the WCA means by a scramble. Honours regulation 4b3's minimum.
- `randomScramble` — random turns. Cheap, unevenly distributed.
- `CubieCube.random` draws evenly from all 43,252,003,274,489,856,000 states,
  from `Random.secure` by default.

### Cube

- `CubieCube` with `fromFaceletString`, `toFacelets`, `toFaceletString`,
  `toJson` and `fromJson`. The six centres name the colours, so any six
  distinct letters parse.
- `Algorithm`: a move sequence with `parse`, `inverse`, `+`, `*` and `cube`.
  Scrambles, patterns and solutions are all this one type.
- `Rotation` turns the whole cube about the x, y or z axis, and carries a
  solution over with it — for a cube entered in the wrong orientation.
- `Patterns`: fifteen well known ones, as algorithms.

### Search

- `Search.solveCube` and `Search.solution` for a facelet string.
- `Search.patternize` solves one cube into another rather than into a solved
  one.
- `Search.solveDeeply` streams progressively shorter solutions. Nothing runs
  until it is listened to.

### Verified

121 tests. The solvers are not checked against themselves: a solution is applied
back to the cube, the min2phase tables are compared exhaustively with the
kociemba distances — all 2,096,325 phase 1 pairs and both 967,680-pair phase 2
tables — and where no reference exists an invariant stands in, such as group
closure for the symmetries or orbit-stabiliser for the reductions.

That is what caught the two reduction bugs: edge flip cannot be reduced over all
16 symmetries, and a breadth-first search that ignores `symState` produces an
upper bound rather than a distance, which makes the heuristic inadmissible.

### Not here yet

Only the 3x3x3. The README's roadmap lists the other WCA puzzles and FTO, and
F2L, OLL and PLL practice scrambles.
