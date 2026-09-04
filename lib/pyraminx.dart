/// The Pyraminx solver.
///
/// A tetrahedron with 933120 states once the tips are set aside, which is few
/// enough to hold the exact number of turns to solve for every one of them. So
/// there is no search, and every solution is optimal. God's number is 11.
///
/// ```dart
/// final scramble = randomPyraminxScramble();
/// // L R' B U L' R B' u l' b
///
/// final cube = PyraminxCube()..apply(scramble);
/// print(PyraminxSearch.solve(cube)); // the shortest way back
/// ```
///
/// The tips are left out of the puzzle: each is one turn on its own and cannot
/// be got wrong, so they are added to a scramble rather than solved.
library;

export "cube/algorithm.dart" show Algorithm, MoveSet;
export "cube/layout.dart" show Point, PuzzleLayout;
export "pyraminx/layout.dart" show pyraminxLayout;
export "pyraminx/cube.dart" show PyraminxCube, layerMoveCount, pyraminxMoves, tipMoveCount;
export "pyraminx/facelets.dart"
    show
        PyraminxFacelet,
        PyraminxFacelets,
        cornersOfFace,
        edgeBetween,
        edgeSlots,
        nPyraminxFacelets,
        pyraminxFaceNames,
        tipSlots,
        vertexSlots;
export "pyraminx/search.dart" show PyraminxSearch, randomPyraminxCube, randomPyraminxScramble;
export "pyraminx/tables.dart" show PyraminxTables;
