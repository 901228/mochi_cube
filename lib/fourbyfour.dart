/// The 4x4x4.
///
/// Scrambled the way the WCA scrambles it, from a random state: a state drawn
/// evenly from all 7.4 * 10^45 of them, solved by Shuang Chen's three phase
/// reduction solver, and the solution written backwards. It is the one puzzle
/// here whose scramble costs a real search — about 44 moves in tens of
/// milliseconds once the tables are built, and a few seconds to build them.
///
/// ```dart
/// final scramble = randomFourByFourScramble();
/// // Rw2 U' Fw L2 …
///
/// final cube = NxNCube(4)..apply(scramble);
/// FourByFourSearch.solve(cube); // about 44 moves, not the shortest
/// ```
library;

export "cube/algorithm.dart" show Algorithm, MoveSet;
export "cube/layout.dart" show Point, PuzzleLayout, cubeNetLayout;
export "fourbyfour/api.dart" show FourByFourSearch, randomFourByFourScramble;
export "fourbyfour/tables.dart" show FourByFourTables;
export "nxn/cube.dart" show NxNCube, nxnMoves;
