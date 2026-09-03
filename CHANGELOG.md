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
