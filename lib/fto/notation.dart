import "../cube/algorithm.dart";
import "cube.dart";

/// Read [notation] in Nautilus' FTO notation (nautilusfto.com/Notation) into
/// turns of [ftoMoves].
///
/// On top of the WCA's turns it has:
/// - a lowercase face, `r` or `br`, which turns the middle layer with the face;
/// - `2`, which turns a face two thirds of the way, so `R2` is `R'` and `R2'`
///   is `R`;
/// - `{X, Y}`, which turns the whole puzzle to bring layer X up and layer Y to
///   the front. When X and Y share a corner, the puzzle is held with a corner
///   in front, and its faces have the WCA's names. When they share an edge, it
///   is held with an edge in front, U and F sharing it, and its faces have
///   the WCA's names moved one face round the six about U: F is where R was
///   held with a corner in front, R where BR was and so on;
/// - brackets, which only group turns and are left out.
///
/// The puzzle being turned as a whole, alone or with a wide turn, is kept as
/// the way it is held. So the turns that come back are of a puzzle that stays
/// where it is, as a scramble's are.
Algorithm parseFtoNotation(String notation) {
  // Which face each name is at in the hold, as the face of the WCA's names
  // there.
  var hold = _cornerInFront;
  // Which face of the puzzle is at each place the WCA's names give.
  var held = [for (var f = 0; f < 8; f++) f];
  void turnWhole(List<int> to) {
    final turned = List<int>.filled(8, 0);
    for (var f = 0; f < 8; f++) {
      turned[to[f]] = held[f];
    }
    held = turned;
  }

  final moves = <int>[];
  for (final match in RegExp(r"\{([^}]*)\}|[^\s()]+").allMatches(notation)) {
    final token = match[0]!;
    if (match[1] case final layers?) {
      final names = layers.split(",").map((name) => ftoFaceNames.indexOf(name.trim())).toList();
      if (names.length != 2 || names.contains(-1)) {
        throw FormatException("Invalid rotation: $token");
      }
      final (up, front) = (hold[names[0]], hold[names[1]]);
      // Up goes to where U is and front to where F is, in whichever hold has
      // them meet as they do.
      final found = [
        for (final next in [_cornerInFront, _edgeInFront])
          for (final to in _rotations)
            if (to[up] == next[0] && to[front] == next[2]) (to, next),
      ].firstOrNull;
      if (found == null) {
        throw FormatException("Layers that do not meet: $token");
      }
      turnWhole(found.$1);
      hold = found.$2;
      continue;
    }
    final turn = RegExp(r"^([A-Za-z]+)(2'?|')?$").firstMatch(token);
    final name = turn?[1] ?? "";
    final face = ftoFaceNames.indexOf(name.toUpperCase());
    final wide = name == name.toLowerCase();
    if (face < 0 || (!wide && name != name.toUpperCase())) {
      throw FormatException("Invalid move: $token");
    }
    // Thirds of a turn clockwise.
    final thirds = turn![2] == "2" || turn[2] == "'" ? 2 : 1;
    final place = hold[face];
    if (!wide) {
      moves.add(held[place] * 2 + thirds - 1);
      continue;
    }
    // A wide turn is the opposite face turned the same way, and the whole
    // puzzle turned with it.
    moves.add(held[_opposite(place)] * 2 + thirds - 1);
    for (var t = 0; t < thirds; t++) {
      turnWhole(_wholeTurns[place]);
    }
  }
  return Algorithm(moves, moveSet: ftoMoves);
}

/// The faces' names held with a corner in front, as the WCA's are: the face
/// at each place by its name.
const List<int> _cornerInFront = [0, 1, 2, 3, 4, 5, 6, 7];

/// The faces' names held with an edge in front.
const List<int> _edgeInFront = [0, 7, 1, 2, 5, 3, 6, 4];

int _faceFacing((int, int, int) normal) => ftoFaceNormal.indexOf(normal);

int _opposite(int face) {
  final (x, y, z) = ftoFaceNormal[face];
  return _faceFacing((-x, -y, -z));
}

/// Where each face goes when the whole puzzle turns a third of the way
/// clockwise about each face, worked out as the turns of a face are.
final List<List<int>> _wholeTurns = [
  for (var face = 0; face < 8; face++)
    [for (final normal in ftoFaceNormal) _faceFacing(ftoTurned(face, normal))],
];

/// The puzzle's 24 rotations, as where each face goes: the axes swapped
/// round and their signs changed, all but the ways that are reflections.
final List<List<int>> _rotations = [
  for (final (axes, even) in const [
    ([0, 1, 2], true),
    ([1, 2, 0], true),
    ([2, 0, 1], true),
    ([0, 2, 1], false),
    ([1, 0, 2], false),
    ([2, 1, 0], false),
  ])
    for (final (sx, sy, sz) in const [
      (1, 1, 1), (1, -1, -1), (-1, 1, -1), (-1, -1, 1), //
      (-1, -1, -1), (-1, 1, 1), (1, -1, 1), (1, 1, -1),
    ])
      if ((sx * sy * sz == 1) == even)
        [
          for (final (x, y, z) in ftoFaceNormal)
            () {
              final v = [x, y, z];
              return _faceFacing((sx * v[axes[0]], sy * v[axes[1]], sz * v[axes[2]]));
            }(),
        ],
];
