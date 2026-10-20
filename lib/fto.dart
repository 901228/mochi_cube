/// The Face Turning Octahedron.
///
/// Scrambled the way the WCA scrambles it, from a random state: Levi Gibson's
/// three phase solver, which the official program uses, solves a state drawn
/// evenly from all of them and the solution is written backwards. About 28
/// moves in a little over a tenth of a second once the tables are built.
///
/// ```dart
/// final scramble = randomFtoScramble();
/// // B' R D' L' R B R L U L B' …
///
/// final puzzle = Fto()..apply(scramble);
/// puzzle.toFacelets(); // 72 stickers, drawn by ftoLayout
/// ```
library;

export "cube/algorithm.dart" show Algorithm, MoveSet;
export "fto/cube.dart" show Fto, ftoFaceLetters, ftoFaceNames, ftoMoves, nFtoFacelets;
export "fto/facelets.dart" show ftoFromFaceletString;
export "fto/search.dart" show FtoSearch, randomFtoScramble;
export "fto/tables.dart" show FtoTables;
