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
Algorithm parseFtoNotation(String notation) => Algorithm([
  for (final step in ftoNotationSteps(notation))
    ...switch (step) {
      FtoTurn(:final face, :final thirds, :final wide) => _moves(wide ? _opposite(face) : face, thirds),
      // The middle layer is the whole puzzle turned, and the outer two turn
      // on from there.
      FtoLayers(:final face, layers: (final a, final b, final c)) => [
        ..._moves(face, a - b),
        ..._moves(_opposite(face), b - c),
      ],
      FtoRotation() => const <int>[],
    },
], moveSet: ftoMoves);

/// [face] turned [thirds] clockwise, as moves of [ftoMoves]: none for a whole
/// turn.
List<int> _moves(int face, int thirds) => switch (thirds % 3) {
  0 => const [],
  final t => [face * 2 + t - 1],
};

/// One step of FTO notation, as [ftoNotationSteps] reads it: on the puzzle's
/// own faces, the ones [Fto] names, wherever the puzzle is turned to.
sealed class FtoStep {
  const FtoStep();
}

/// [face] of the puzzle turned [thirds] of a turn clockwise as seen from
/// outside it, as written: `R2'` is -2, not 1. A [wide] turn turns the middle
/// layer with it, which is the same as the opposite face turned the same way
/// and the whole puzzle turned about [face] as well.
final class FtoTurn extends FtoStep {
  const FtoTurn(this.face, this.thirds, {this.wide = false});
  final int face;
  final int thirds;
  final bool wide;

  @override
  bool operator ==(Object other) =>
      other is FtoTurn && other.face == face && other.thirds == thirds && other.wide == wide;

  @override
  int get hashCode => Object.hash(face, thirds, wide);

  @override
  String toString() => "FtoTurn($face, $thirds${wide ? ", wide" : ""})";
}

/// The whole puzzle turned to bring its face [up] to the top and [front] to
/// the front: a corner in front when they share one, an edge when they share
/// an edge.
final class FtoRotation extends FtoStep {
  const FtoRotation(this.up, this.front);
  final int up;
  final int front;

  @override
  bool operator ==(Object other) => other is FtoRotation && other.up == up && other.front == front;

  @override
  int get hashCode => Object.hash(up, front);

  @override
  String toString() => "FtoRotation($up, $front)";
}

/// Turns of one axis made at once, as `(r R')` writes them: [layers] says how
/// far each of the three layers of [face]'s axis turns, in thirds clockwise as
/// seen from [face] — the one at [face], the middle one, then the one at the
/// face opposite.
final class FtoLayers extends FtoStep {
  const FtoLayers(this.face, this.layers);
  final int face;
  final (int, int, int) layers;

  @override
  bool operator ==(Object other) => other is FtoLayers && other.face == face && other.layers == layers;

  @override
  int get hashCode => Object.hash(face, layers);

  @override
  String toString() => "FtoLayers($face, $layers)";
}

/// Read [notation] as [parseFtoNotation] does, but step by step and with the
/// turns of the whole puzzle kept: each is on the puzzle's own faces, as it is
/// turned by then.
List<FtoStep> ftoNotationSteps(String notation) {
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

  final steps = <FtoStep>[];

  void rotate(String token) {
    final names = token
        .substring(1, token.length - 1)
        .split(",")
        .map((name) => ftoFaceNames.indexOf(name.trim()))
        .toList();
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
    steps.add(FtoRotation(held[up], held[front]));
    turnWhole(found.$1);
    hold = found.$2;
  }

  void read(String token) {
    if (token.startsWith("{")) return rotate(token);
    final (face, thirds, wide) = _turnOf(token);
    final place = hold[face];
    steps.add(FtoTurn(held[place], thirds, wide: wide));
    if (wide) {
      for (var t = 0; t < thirds % 3; t++) {
        turnWhole(_wholeTurns[place]);
      }
    }
  }

  final token = RegExp(r"\{[^}]*\}|[^\s()]+");
  for (final match in RegExp(r"\(([^()]*)\)|\{[^}]*\}|[^\s()]+").allMatches(notation)) {
    final group = match[1];
    if (group == null) {
      read(match[0]!);
      continue;
    }
    final tokens = [for (final m in token.allMatches(group)) m[0]!];
    final turns = tokens.any((t) => t.startsWith("{")) ? null : [for (final t in tokens) _turnOf(t)];
    final axis = turns == null || turns.length < 2 ? null : hold[turns.first.$1];
    if (axis == null || !turns!.every((t) => hold[t.$1] == axis || hold[t.$1] == _opposite(axis))) {
      // Only a grouping, of turns made one after another.
      tokens.forEach(read);
      continue;
    }
    // Turns of one axis, made at once: how far each of its three layers turns
    // about it.
    final layers = [0, 0, 0];
    for (final (face, thirds, wide) in turns) {
      final sign = hold[face] == axis ? 1 : -1;
      layers[sign == 1 ? 0 : 2] += sign * thirds;
      if (wide) layers[1] += sign * thirds;
    }
    steps.add(FtoLayers(held[axis], (layers[0], layers[1], layers[2])));
    for (var t = 0; t < layers[1] % 3; t++) {
      turnWhole(_wholeTurns[axis]);
    }
  }
  return steps;
}

/// The face, thirds of a turn as written, and whether it is wide, of [token].
(int, int, bool) _turnOf(String token) {
  final turn = RegExp(r"^([A-Za-z]+)(2'?|')?$").firstMatch(token);
  final name = turn?[1] ?? "";
  final face = ftoFaceNames.indexOf(name.toUpperCase());
  final wide = name == name.toLowerCase();
  if (face < 0 || (!wide && name != name.toUpperCase())) {
    throw FormatException("Invalid move: $token");
  }
  final thirds = switch (turn![2]) {
    "2" => 2,
    "2'" => -2,
    "'" => -1,
    _ => 1,
  };
  return (face, thirds, wide);
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
