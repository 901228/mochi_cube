import "../cube/algorithm.dart";
import "cube.dart";

/// Read [notation] for a cube of [size] into turns of [nxnMoves].
///
/// On top of the WCA's turns (`R`, `Rw`, `3Rw`) it reads:
/// - rotations, `x`, `y` and `z`;
/// - slices, `M`, `E` and `S`: the middle layer of an odd cube, every inner
///   layer of an even one;
/// - a lowercase face, `r`, which is `Rw`;
/// - a depth without a `w`, `2R`, which turns that one layer alone;
/// - brackets, which only group turns and are left out.
///
/// The cube being turned as a whole, by a rotation or by a turn deeper than
/// half the cube, is kept as the way it is held, so the turns that come back
/// are of a cube that stays where it is. An even cube has no centres to tell
/// how it is held, so it is turned back at the end, as its two halves.
Algorithm parseCubeNotation(String notation, {int size = 3}) {
  final moveSet = nxnMoves(size);
  // The face of the cube as first held that each face as now held is.
  final held = [for (var f = 0; f < 6; f++) f];
  final moves = <int>[];

  void rotate(int face, int quarters) {
    final cycle = _cycles[face];
    for (var i = 0; i < quarters % 4; i++) {
      final before = [...held];
      for (var j = 0; j < 4; j++) {
        held[cycle[(j + 1) % 4]] = before[cycle[j]];
      }
    }
  }

  void block(int face, int width, int quarters) {
    if (quarters % 4 != 0) moves.add(((width - 1) * 6 + face) * 3 + quarters % 4 - 1);
  }

  // Layers lo to hi of [face], counted from it, turned [quarters] clockwise as
  // seen from it.
  void layers(int face, int lo, int hi, int quarters) {
    if (lo == 1 && hi == size) return rotate(face, quarters);
    if (hi == size) return layers(_opposite(face), 1, size - lo + 1, -quarters);
    if (lo > 1) {
      layers(face, 1, hi, quarters);
      return layers(face, 1, lo - 1, -quarters);
    }
    if (hi <= size ~/ 2) return block(held[face], hi, quarters);
    // Deeper than the notation turns: the whole cube, less the rest from the
    // other side.
    rotate(face, quarters);
    block(held[_opposite(face)], size - hi, quarters);
  }

  for (final token in notation.split(RegExp(r"[\s()\[\]]+"))) {
    if (token.isEmpty) continue;
    final m = _token.firstMatch(token);
    if (m == null) throw FormatException("Invalid move: $token");
    final quarters = switch (m[4]) {
      null => 1,
      "'" => 3,
      _ => 2,
    };
    final name = m[2]!;
    final depth = m[1] == null ? null : int.parse(m[1]!);
    final plain = depth == null && m[3]!.isEmpty;
    switch (name) {
      case "x" || "y" || "z":
        if (!plain) throw FormatException("Invalid move: $token");
        rotate(nxnFaceNames.indexOf(const {"x": "R", "y": "U", "z": "F"}[name]!), quarters);
      case "M" || "E" || "S":
        if (!plain || size < 3) throw FormatException("Invalid move: $token");
        final (lo, hi) = size.isEven ? (2, size - 1) : ((size + 1) ~/ 2, (size + 1) ~/ 2);
        layers(nxnFaceNames.indexOf(const {"M": "L", "E": "D", "S": "F"}[name]!), lo, hi, quarters);
      default:
        final face = name.toUpperCase();
        final wide = m[3]!.isNotEmpty || name != face;
        final (lo, hi) = wide ? (1, depth ?? 2) : (depth ?? 1, depth ?? 1);
        if (hi < 1 || hi > size || (wide && name != face && depth != null)) {
          throw FormatException("Invalid move: $token");
        }
        layers(nxnFaceNames.indexOf(face), lo, hi, quarters);
    }
  }
  if (size.isEven) {
    for (final (face, quarters) in _turnsBack(held).reversed) {
      block(face, size ~/ 2, 4 - quarters);
      block(_opposite(face), size ~/ 2, quarters);
    }
  }
  return Algorithm(moves, moveSet: moveSet);
}

final _token = RegExp(r"^(\d+)?([URFDLBurfdlbMESxyz])(w?)(2'?|')?$");

int _opposite(int face) => (face + 3) % 6;

/// Where each face goes on a clockwise quarter turn of the whole cube about
/// each face, in [nxnFaceNames] order: about U, F goes to L, L to B and so on.
const List<List<int>> _cycles = [
  [2, 4, 5, 1], // U: F L B R
  [0, 5, 3, 2], // R: U B D F
  [0, 1, 3, 4], // F: U R D L
  [2, 1, 5, 4], // D: F R B L
  [0, 2, 3, 5], // L: U F D B
  [0, 4, 3, 1], // B: U L D R
];

/// Quarter turns of the whole cube about R, U and F, at most two, that take
/// it from as first held to [held]: undone, they turn it back.
List<(int, int)> _turnsBack(List<int> held) {
  final start = [for (var f = 0; f < 6; f++) f];
  final queue = [(start, <(int, int)>[])];
  for (var i = 0; i < queue.length; i++) {
    final (faces, path) = queue[i];
    if (Iterable.generate(6).every((f) => faces[f] == held[f])) return path;
    if (path.length == 2) continue;
    for (final axis in const [1, 0, 2]) {
      for (var q = 1; q < 4; q++) {
        final cycle = _cycles[axis];
        int next(int f) => cycle.contains(f) ? cycle[(cycle.indexOf(f) + q) % 4] : f;
        queue.add(([for (final f in faces) next(f)], [...path, (axis, q)]));
      }
    }
  }
  throw StateError("No turn of the cube gives $held");
}
