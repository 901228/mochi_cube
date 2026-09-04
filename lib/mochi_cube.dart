/// A Rubik's Cube solver.
///
/// The solver is a Dart port of Chen Shuang's min2phase: a two phase search
/// whose coordinate tables are reduced by the cube's own symmetries, so they
/// stay around a megabyte rather than the several a plain two phase solver
/// needs.
///
/// ```dart
/// final result = Search.solution("DLBFUBRFL DDLRRDBRR FUBBFULDU ULRRDBLUF RDUULLDFF UFBRBBDLF");
/// if (result.status == SearchStatus.foundSolution) {
///   print(result.solution); // R F D2 B U2 ...
/// }
/// ```
///
/// The first solve builds the tables, which takes about 600ms and is then
/// cached to disk; later runs load them in under 100ms.
/// [Phase1Tables.useTwistFlipPrune] trades the largest table for search speed.
///
/// The older, plainer Kociemba solver this was developed against lives in
/// `package:mochi_cube/kociemba.dart`. It is slower and its solutions are
/// longer, but it is much simpler code and it is what the min2phase tables are
/// verified against.
library;

export "puzzle/coord_tables.dart" show Phase1Tables;
export "puzzle/cube/cubie_cube.dart"
    show CoordinatesExtension, CubeVerificationStatus, CubieCube;
export "cube/enums.dart" show Corner, Edge, Face, FaceExtension, Facelet;
export "cube/enums.dart" show cornerFace, cornerFacelet, edgeFace, edgeFacelet;
export "cube/layout.dart"
    show Point, PuzzleLayout, cubeLayout, cubeNetLayout, cubeNetPosition;
export "puzzle/cube/moves.dart" show MoveExtension, moveCube;
export "puzzle/patterns.dart" show Patterns, randomScramble, randomStateScramble;
export "puzzle/practice.dart"
    show
        crossEdges,
        f2lPairs,
        PracticeSpread,
        f2lPracticeScramble,
        isCrossSolved,
        isF2lSolved,
        isLastLayerOriented,
        lastLayerCorners,
        lastLayerEdges,
        ollCases,
        ollPracticeScramble,
        pllCases,
        pllPracticeScramble,
        randomStateWith;
export "puzzle/cube/rotation.dart"
    show Axis, Rotation, RotationAlgorithmExtension, RotationExtension;
export "puzzle/phase2_tables.dart" show Phase2Tables;
export "cube/algorithm.dart"
    show Algorithm, invertMove, moveCount, moveToString, parseMove;
export "puzzle/algorithm.dart" show AlgorithmCubeExtension, AlgorithmExtension;
export "puzzle/search.dart" show Min2PhaseSolver, Search, min2phase;
export "solver.dart" show SolveResult, SolveStatus, Solution, Solver;
