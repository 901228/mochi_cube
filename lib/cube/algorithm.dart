import "dart:collection";

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
  /// The moves, as `axis * amounts + amount` indices.
  final List<int> moves;

  /// What those indices are called. A 3x3x3's, unless said otherwise.
  final MoveSet moveSet;

  const Algorithm(this.moves, {this.moveSet = MoveSet.cube});

  static const Algorithm empty = Algorithm([]);

  /// Parse standard notation, e.g. `"R U R' U2"`.
  ///
  /// Whitespace between moves is ignored; an empty string gives [empty].
  factory Algorithm.parse(String notation, {MoveSet moveSet = MoveSet.cube}) {
    return Algorithm([
      for (final token in moveSet.tokensOf(notation)) moveSet.parse(token),
    ], moveSet: moveSet);
  }

  /// The moves that undo this algorithm: reversed, each one inverted.
  Algorithm get inverse => Algorithm(moves.reversed.map(moveSet.invert).toList(), moveSet: moveSet);

  /// This algorithm followed by [other].
  ///
  /// Throws [ArgumentError] if the two are not about the same puzzle.
  Algorithm operator +(Algorithm other) {
    if (other.isNotEmpty && other.moveSet != moveSet && isNotEmpty) {
      throw ArgumentError("Cannot join algorithms for different puzzles");
    }
    return Algorithm([...moves, ...other.moves], moveSet: moveSet);
  }

  /// This algorithm repeated [count] times.
  Algorithm operator *(int count) {
    if (count < 0) {
      throw ArgumentError.value(count, "count", "must not be negative");
    }
    return Algorithm([for (var i = 0; i < count; i++) ...moves], moveSet: moveSet);
  }

  int operator [](int index) => moves[index];

  @override
  Iterator<int> get iterator => moves.iterator;

  @override
  int get length => moves.length;

  @override
  String toString() => moves.map(moveSet.render).join(" ");

  @override
  bool operator ==(Object other) {
    if (other is! Algorithm || other.moves.length != moves.length) {
      return false;
    }
    if (moves.isNotEmpty && other.moveSet != moveSet) {
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

/// What a puzzle's turns are called, and how they compose.
///
/// A move is `axis * amounts.length + amount`, so the numbering is dense and a
/// table can be indexed by it directly. Puzzles differ in both parts: a 3x3x3
/// turns six faces by three amounts, a Pyraminx turns four vertices and four
/// tips by two.
///
/// This is deliberately only about naming. Which moves a puzzle allows, and
/// what they do, belong to that puzzle.
class MoveSet {
  /// What each axis is called: `U`, `R`, `F` and so on.
  final List<String> axes;

  /// What each amount is written as, in order. The first is the empty string,
  /// since one turn clockwise is written with no suffix.
  final List<String> amounts;

  const MoveSet({required this.axes, required this.amounts});

  /// Six faces turned clockwise, twice, or anticlockwise.
  static const MoveSet cube = MoveSet(axes: ["U", "R", "F", "D", "L", "B"], amounts: ["", "2", "'"]);

  int get count => axes.length * amounts.length;

  int axisOf(int move) => move ~/ amounts.length;

  int amountOf(int move) => move % amounts.length;

  /// Split [notation] into the tokens [parse] reads, one per move.
  ///
  /// Whitespace between moves, which is how every puzzle here writes them but
  /// the Square-1, whose `(1,0)/` runs two moves together.
  Iterable<String> tokensOf(String notation) =>
      notation.split(RegExp(r"\s+")).where((token) => token.isNotEmpty);

  /// Parse one move, e.g. `"R'"`.
  int parse(String token) {
    for (var axis = 0; axis < axes.length; axis++) {
      final name = axes[axis];
      if (!token.startsWith(name)) {
        continue;
      }
      final suffix = token.substring(name.length);
      final amount = amounts.indexOf(suffix);
      if (amount >= 0) {
        return axis * amounts.length + amount;
      }
    }
    throw FormatException("Invalid move: $token");
  }

  /// Render a move index.
  String render(int move) => axes[axisOf(move)] + amounts[amountOf(move)];

  @override
  bool operator ==(Object other) =>
      other is MoveSet &&
      other.axes.length == axes.length &&
      other.amounts.length == amounts.length &&
      Iterable.generate(axes.length).every((i) => other.axes[i] == axes[i]) &&
      Iterable.generate(amounts.length).every((i) => other.amounts[i] == amounts[i]);

  @override
  int get hashCode => Object.hash(Object.hashAll(axes), Object.hashAll(amounts));

  /// The move that undoes [move].
  ///
  /// The amounts run from one turn upwards and stop one short of coming back to
  /// the start, so the first and last undo each other, the second and second
  /// last, and a middle one undoes itself. On a 3x3x3 that is `U` against `U'`
  /// with `U2` its own inverse; on a Pyraminx, `U` against `U'`.
  int invert(int move) => axisOf(move) * amounts.length + (amounts.length - 1 - amountOf(move));
}

/// The number of face turns of a 3x3x3: six faces, three amounts each.
const int moveCount = 18;

/// Parse one move of a 3x3x3 in standard notation into a move index.
int parseMove(String token) => MoveSet.cube.parse(token);

/// Render a 3x3x3 move index back into standard notation.
String moveToString(int move) => MoveSet.cube.render(move);

/// The inverse of a 3x3x3 move index: a quarter turn reverses, a half turn does not.
int invertMove(int move) => MoveSet.cube.invert(move);
