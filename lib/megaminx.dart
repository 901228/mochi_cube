/// The Megaminx.
///
/// Scrambled the way the WCA scrambles it, by Pochmann's random turns rather
/// than a random state, so nothing here solves it.
///
/// ```dart
/// final scramble = randomMegaminxScramble();
/// print(megaminxNotation(scramble)); // seven rows of R++ D-- … U'
///
/// final puzzle = Megaminx()..apply(scramble);
/// puzzle.toFacelets(); // 132 stickers, drawn by megaminxLayout
/// ```
library;

export "cube/algorithm.dart" show Algorithm, MoveSet;
export "megaminx/cube.dart"
    show Megaminx, MegaminxMoveSet, megaminxFaceLetters, megaminxFaceNames, megaminxMoves, nMegaminxFacelets;
export "megaminx/scramble.dart" show megaminxNotation, randomMegaminxScramble;
export "megaminx/layout.dart" show Point, PuzzleLayout, megaminxLayout;
