import "dart:collection";

import "enums.dart";

/// A sequence of face turns, in standard notation.
///
/// This is the currency the rest of the package deals in: a scramble, a
/// pattern, and the moves of a solution are all the same kind of thing, so they
/// are all this type. A move is an index `3 * face + power`, with `power` 0, 1
/// and 2 meaning a clockwise quarter turn, a half turn and an anticlockwise
/// quarter turn — the same numbering the solvers' tables use.
///
/// It is an [Iterable] of those indices, so `for (final move in algorithm)`
/// works and so do `map`, `where` and the rest.
///
/// Deliberately free of any cube state, so both solvers can speak it. The
/// operations that need a cube live in `package:mochi_cube/mochi_cube.dart`.
class Algorithm extends IterableBase<int> {
  /// The moves, as `3 * face + power` indices.
  final List<int> moves;

  const Algorithm(this.moves);

  static const Algorithm empty = Algorithm([]);

  /// Parse standard notation, e.g. `"R U R' U2"`.
  ///
  /// Whitespace between moves is ignored; an empty string gives [empty].
  factory Algorithm.parse(String notation) {
    final tokens = notation.split(RegExp(r"\s+")).where((token) => token.isNotEmpty);
    return Algorithm([for (final token in tokens) parseMove(token)]);
  }

  /// The moves that undo this algorithm: reversed, each one inverted.
  Algorithm get inverse => Algorithm(moves.reversed.map(invertMove).toList());

  /// This algorithm followed by [other].
  Algorithm operator +(Algorithm other) => Algorithm([...moves, ...other.moves]);

  /// This algorithm repeated [count] times.
  Algorithm operator *(int count) {
    if (count < 0) {
      throw ArgumentError.value(count, "count", "must not be negative");
    }
    return Algorithm([for (var i = 0; i < count; i++) ...moves]);
  }

  int operator [](int index) => moves[index];

  @override
  Iterator<int> get iterator => moves.iterator;

  @override
  int get length => moves.length;

  @override
  String toString() => moves.map(moveToString).join(" ");

  @override
  bool operator ==(Object other) {
    if (other is! Algorithm || other.moves.length != moves.length) {
      return false;
    }
    for (var i = 0; i < moves.length; i++) {
      if (other.moves[i] != moves[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(moves);
}

/// The number of face turns: six faces, three amounts each.
const int moveCount = 18;

/// Parse one move in standard notation into a move index.
int parseMove(String token) {
  if (token.isEmpty || token.length > 2) {
    throw FormatException("Invalid move: $token");
  }

  final face = FaceExtension.faceToString.indexOf(token[0]);
  if (face < 0) {
    throw FormatException("Invalid face: ${token[0]}");
  }

  final int power;
  if (token.length == 1) {
    power = 0;
  } else if (token[1] == "2") {
    power = 1;
  } else if (token[1] == "'") {
    power = 2;
  } else {
    throw FormatException("Invalid move amount: ${token[1]}");
  }

  return 3 * face + power;
}

/// Render a move index back into standard notation.
String moveToString(int move) =>
    FaceExtension.faceToString[move ~/ 3] + const ["", "2", "'"][move % 3];

/// The inverse of a move index: a quarter turn reverses, a half turn does not.
int invertMove(int move) => 3 * (move ~/ 3) + const [2, 1, 0][move % 3];
