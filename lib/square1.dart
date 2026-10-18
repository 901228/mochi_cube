/// The Square-1.
///
/// A puzzle that changes shape as it turns, with far too many states to hold
/// the distance to solved for each, so it is solved by a two-phase search
/// rather than looked up: back to a cube, then solved as one.
///
/// ```dart
/// final scramble = randomSquare1Scramble();
/// // (1,0) / (-1,2) / (0,-3) / ...
///
/// final cube = Square1Cube()..apply(scramble);
/// print(Square1Search.solve(cube));
/// ```
library;

export "cube/algorithm.dart" show Algorithm, MoveSet;
export "square1/cube.dart" show Square1Cube, Square1MoveSet, square1Moves;
export "square1/layout.dart" show Point, Square1Layout, square1Layout;
export "square1/search.dart" show Square1Search, randomSquare1Cube, randomSquare1Scramble;
export "square1/tables.dart" show Square1Tables;
