/// The Skewb.
///
/// A cube that turns about its corners, with 3149280 states once the corner
/// held towards you is kept still.
library;

export "cube/algorithm.dart" show Algorithm, MoveSet;
export "skewb/coordinates.dart" show SkewbPart;
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
