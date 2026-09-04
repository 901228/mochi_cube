/// The 2x2x2 solver.
///
/// Small enough to hold the exact distance to solved for every one of its
/// 3674160 states, so solving is a walk downhill rather than a search and every
/// solution is optimal. God's number for the puzzle is 11.
///
/// ```dart
/// final scramble = randomPocketScramble();
/// final result = pocket.solve(scramble.cube.toPocketFaceletString());
/// ```
///
/// It shares the 3x3x3's cube model, since a 2x2x2 is the corners of one, and
/// the same `Algorithm` and notation, since U, R and F mean the same thing.
library;

export "cube/algorithm.dart" show Algorithm, invertMove, moveToString, parseMove;
export "cube/enums.dart" show Corner, Face, FaceExtension;
export "cube/layout.dart"
    show Point, PuzzleLayout, cubeNetLayout, cubeNetPosition, pocketLayout;
export "pocket/coordinates.dart"
    show PocketCoordinates, fixedCorner, nCperm7, nStates, nTwist6, pocketMoves;
export "pocket/facelets.dart" show PocketCube, PocketFacelets, nPocketFacelets;
export "pocket/search.dart"
    show PocketSearch, PocketSolver, pocket, randomPocketCube, randomPocketScramble;
export "pocket/tables.dart" show PocketTables;
export "puzzle/cube/cubie_cube.dart" show CubieCube;
export "puzzle/algorithm.dart" show AlgorithmCubeExtension, AlgorithmExtension;
export "puzzle/cube/moves.dart" show MoveExtension;
export "solver.dart" show SolveResult, SolveStatus, Solution, Solver;
