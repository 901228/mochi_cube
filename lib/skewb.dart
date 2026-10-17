/// The Skewb.
///
/// A cube that turns about its corners, with 3149280 states once the corner
/// held towards you is kept still, which is few enough to hold the exact number
/// of turns to solve for every one of them. So there is no search, and every
/// solution is optimal. God's number is 11.
///
/// ```dart
/// final scramble = randomSkewbScramble();
/// // R U' B L' R B' U L
///
/// final cube = SkewbCube()..apply(scramble);
/// print(SkewbSearch.solve(cube)); // the shortest way back
/// ```
library;

export "cube/algorithm.dart" show Algorithm, MoveSet;
export "skewb/coordinates.dart" show SkewbPart;
export "skewb/layout.dart" show Point, PuzzleLayout, skewbLayout;
export "skewb/cube.dart"
    show
        SkewbCube,
        centreSlot,
        nSkewbFacelets,
        skewbCornerOf,
        skewbFaceNames,
        skewbFaceletPosition,
        skewbMoves;
export "skewb/facelets.dart" show SkewbFacelet;
export "skewb/search.dart" show SkewbSearch, randomSkewbCube, randomSkewbScramble;
export "skewb/tables.dart" show SkewbTables;
