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
/// - a count after the turn, `R3`, `U'2`, `F2'`: that many quarter turns, the way written;
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

  for (final turn in cubeLayerTurns(notation, size: size)) {
    layers(turn.face, turn.lo, turn.hi, turn.quarters);
  }
  if (size.isEven) {
    for (final (face, quarters) in _turnsBack(held).reversed) {
      block(face, size ~/ 2, 4 - quarters);
      block(_opposite(face), size ~/ 2, quarters);
    }
  }
  return Algorithm(moves, moveSet: moveSet);
}

/// A turn of layers [lo] to [hi] of a cube, counted from [face] in [nxnFaceNames] order, a [quarters]
/// quarter turns clockwise as seen from it, anticlockwise when negative and as many as written: `R3` is 3,
/// `R'` is -1, `U'2` is -2. A rotation turns every layer.
typedef CubeLayerTurn = ({int face, int lo, int hi, int quarters});

/// The layers each move of [notation] turns on a cube of [size], one turn a move, in the notation
/// [parseCubeNotation] reads: what the moves do to a cube in the hand, which a rotation turns as a
/// whole and the next moves find held that way.
List<CubeLayerTurn> cubeLayerTurns(String notation, {int size = 3}) => [
  for (final token in notation.split(RegExp(r"[\s()\[\]]+")))
    if (token.isNotEmpty) _layerTurn(token, size),
];

CubeLayerTurn _layerTurn(String token, int size) {
  final m = _token.firstMatch(token);
  if (m == null) throw FormatException("Invalid move: $token");
  // `R3` and `R'3` count turns in the direction written, `R2'` a half turn counter-clockwise.
  final count = int.tryParse(m[4]! + m[6]!) ?? 1;
  if (m[4]!.isNotEmpty && m[6]!.isNotEmpty || count < 1) throw FormatException("Invalid move: $token");
  final quarters = m[5] == "'" ? -count : count;
  final name = m[2]!;
  final depth = m[1] == null ? null : int.parse(m[1]!);
  final plain = depth == null && m[3]!.isEmpty;
  switch (name) {
    case "x" || "y" || "z":
      if (!plain) throw FormatException("Invalid move: $token");
      final face = nxnFaceNames.indexOf(const {"x": "R", "y": "U", "z": "F"}[name]!);
      return (face: face, lo: 1, hi: size, quarters: quarters);
    case "M" || "E" || "S":
      if (!plain || size < 3) throw FormatException("Invalid move: $token");
      final (lo, hi) = size.isEven ? (2, size - 1) : ((size + 1) ~/ 2, (size + 1) ~/ 2);
      final face = nxnFaceNames.indexOf(const {"M": "L", "E": "D", "S": "F"}[name]!);
      return (face: face, lo: lo, hi: hi, quarters: quarters);
    default:
      final face = name.toUpperCase();
      final wide = m[3]!.isNotEmpty || name != face;
      final (lo, hi) = wide ? (1, depth ?? 2) : (depth ?? 1, depth ?? 1);
      if (hi < 1 || hi > size || (wide && name != face && depth != null)) {
        throw FormatException("Invalid move: $token");
      }
      return (face: nxnFaceNames.indexOf(face), lo: lo, hi: hi, quarters: quarters);
  }
}

final _token = RegExp(r"^(\d+)?([URFDLBurfdlbMESxyz])(w?)(\d*)('?)(\d*)$");

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
