import "cubie_cube.dart";
import "enums.dart";

/// The 18 face turns, as cube states reached from a solved cube.
///
/// Index `3 * face + power`, with `face` in U, R, F, D, L, B order and `power`
/// 0, 1, 2 meaning a clockwise quarter turn, a half turn and an anticlockwise
/// quarter turn. This matches the move numbering the coordinate tables use.
///
/// Only the six quarter turns carry data; each is written as its four raw
/// coordinates, and the half and anticlockwise turns are generated from it.
final List<CubieCube> moveCube = _initMoveCube();

/// Raw `(cperm, twist, eperm, flip)` coordinates of the six clockwise quarter
/// turns. `eperm` is the permutation index of all 12 edges.
const List<(int, int, int, int)> _quarterTurns = [
  (15120, 0, 119750400, 0), // U
  (21021, 1494, 323403417, 0), // R
  (8064, 1236, 29441808, 550), // F
  (9, 0, 5880, 0), // D
  (1230, 412, 2949660, 0), // L
  (224, 137, 328552, 137), // B
];

List<CubieCube> _initMoveCube() {
  final cubes = List<CubieCube>.generate(18, (_) => CubieCube());

  for (var face = 0; face < 6; face++) {
    final (cperm, twist, eperm, flip) = _quarterTurns[face];
    final quarter = CubieCube.fromCoordinates(cperm: cperm, twist: twist, eperm: eperm, flip: flip);
    cubes[3 * face] = quarter;

    // X2 = X * X and X' = X2 * X.
    for (var power = 1; power < 3; power++) {
      final next = CubieCube.from(cubes[3 * face + power - 1]);
      next.multiply(quarter);
      cubes[3 * face + power] = next;
    }
  }

  return cubes;
}

extension MoveExtension on CubieCube {
  /// Apply a single clockwise quarter turn of [face].
  void move(Face face) => multiply(moveCube[3 * face.index]);

  /// Apply one of the 18 face turns, indexed as `3 * face + power`.
  void moveIndex(int index) => multiply(moveCube[index]);
}
