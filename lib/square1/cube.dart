import "../cube/algorithm.dart";

/// The Square-1.
///
/// Each layer is twelve slots of 30 degrees, numbered as Chen Shuang's
/// sq12phase numbers them, which is also how csTimer and the official TNoodle
/// scrambler see the puzzle: slots 0 to 11 are the top layer counterclockwise
/// as seen from above, and 12 to 23 the bottom layer clockwise as seen from
/// above. The cut that `/` turns along runs between slots 5 and 6 at the front
/// and 11 and 0 at the back, on top, and between 17 and 18 and 23 and 12 below;
/// slots 6 to 11 and 12 to 17 are the right half, the one that turns.
///
/// The pieces are numbered 0 to 15: even ones are edges and fill one slot, odd
/// ones are corners and fill two, and 8 upwards started on the bottom. Solved,
/// the top reads `0 1 1 2 3 3 4 5 5 6 7 7` and the bottom
/// `9 9 8 11 11 10 13 13 12 15 15 14`.
///
/// Nothing stops a corner straddling the cut, and then `/` cannot be turned.
/// That is a real state of the puzzle, reached by turning a layer part way, so
/// it is held here rather than refused.
class Square1Cube {
  /// The piece in each of the 24 slots.
  final List<int> pieces;

  /// Whether the middle layer is turned over: 0 when it is square, 1 when not.
  int middle;

  Square1Cube() : pieces = [...solvedPieces], middle = 0;

  Square1Cube.from(Square1Cube other) : pieces = [...other.pieces], middle = other.middle;

  static const List<int> solvedPieces = [
    0, 1, 1, 2, 3, 3, 4, 5, 5, 6, 7, 7, //
    9, 9, 8, 11, 11, 10, 13, 13, 12, 15, 15, 14,
  ];

  /// Whether [piece] is a corner, filling two slots.
  static bool isCorner(int piece) => piece.isOdd;

  /// Turn the top layer [amount] slots clockwise, as seen from above.
  void turnTop(int amount) => _rotate(0, amount);

  /// Turn the bottom layer [amount] slots clockwise, as seen from below.
  void turnBottom(int amount) => _rotate(12, amount);

  /// The slot a piece moves from is [amount] further on: clockwise from above
  /// is down the numbering on top, and clockwise from below down it underneath.
  void _rotate(int first, int amount) {
    final layer = pieces.sublist(first, first + 12);
    for (var i = 0; i < 12; i++) {
      pieces[first + i] = layer[(i + amount) % 12];
    }
  }

  /// Whether `/` can be turned: no corner straddles the cut, top or bottom.
  bool get canSlash =>
      pieces[11] != pieces[0] &&
      pieces[5] != pieces[6] &&
      pieces[23] != pieces[12] &&
      pieces[17] != pieces[18];

  /// Turn the right half over.
  ///
  /// The top's right half and the bottom's trade places slot for slot, the
  /// turn being half a revolution about the axis through the right face.
  void slash() {
    if (!canSlash) {
      throw StateError("A corner straddles the cut, so / cannot be turned");
    }
    for (var i = 6; i < 12; i++) {
      final top = pieces[i];
      pieces[i] = pieces[i + 6];
      pieces[i + 6] = top;
    }
    middle ^= 1;
  }

  /// Apply one move index of [square1Moves].
  void applyMove(int move) {
    if (move == Square1MoveSet.slashMove) {
      slash();
      return;
    }
    turnTop(move ~/ 12);
    turnBottom(move % 12);
  }

  /// Apply an algorithm written in [square1Moves].
  void apply(Algorithm algorithm) {
    for (final move in algorithm.moves) {
      applyMove(move);
    }
  }

  bool get isSolved {
    for (var i = 0; i < pieces.length; i++) {
      if (pieces[i] != solvedPieces[i]) return false;
    }
    return middle == 0;
  }

  /// The pieces as 24 hex digits, top then bottom, and the middle as 0 or 1.
  ///
  /// Solved, `011233455677998bbaddcffe0`. [parse] reads it back.
  @override
  String toString() => "${pieces.map((piece) => piece.toRadixString(16)).join()}$middle";

  /// Read a state written as [toString] writes it.
  ///
  /// Throws [FormatException] unless it is 16 pieces filling the 24 slots — a
  /// corner in two neighbouring slots of one layer, an edge in one — and a
  /// middle that is 0 or 1.
  static Square1Cube parse(String state) {
    final cleaned = state.replaceAll(RegExp(r"\s"), "").toLowerCase();
    if (!RegExp(r"^[0-9a-f]{24}[01]$").hasMatch(cleaned)) {
      throw FormatException("Expected 24 hex digits and a 0 or 1, got '$state'");
    }

    final cube = Square1Cube();
    for (var i = 0; i < 24; i++) {
      cube.pieces[i] = int.parse(cleaned[i], radix: 16);
    }
    cube.middle = int.parse(cleaned[24]);

    for (var piece = 0; piece < 16; piece++) {
      final slots = [
        for (var i = 0; i < 24; i++)
          if (cube.pieces[i] == piece) i,
      ];
      if (slots.length != (isCorner(piece) ? 2 : 1)) {
        throw FormatException("Piece ${piece.toRadixString(16)} is in ${slots.length} slots");
      }
      // Two slots of one layer, one after the other, the twelfth wrapping round.
      if (isCorner(piece) && (slots[0] ~/ 12 != slots[1] ~/ 12 || !{1, 11}.contains(slots[1] - slots[0]))) {
        throw FormatException(
          "Corner ${piece.toRadixString(16)} is split between slots ${slots.join(" and ")}",
        );
      }
    }
    return cube;
  }
}

/// Square-1 notation, WCA regulation 12d: `(x,y)` turns the top `x` and the
/// bottom `y` twelfths of a revolution clockwise, and `/` turns the right half.
///
/// Not faces and amounts, so this overrides how [MoveSet] reads and writes a
/// move. A move is `x * 12 + y` with both counted 0 to 11, which leaves 0 free
/// for `/` since `(0,0)` is no move at all. Each is one move, as regulation 12c4
/// counts them, so [Algorithm.length] is the WCA move count.
class Square1MoveSet extends MoveSet {
  const Square1MoveSet._() : super(axes: const ["/"], amounts: const [""]);

  /// The index of `/`.
  static const int slashMove = 0;

  /// The index of `(top,bottom)`, either negative or not.
  static int turn(int top, int bottom) {
    final move = top % 12 * 12 + bottom % 12;
    if (move == slashMove) throw ArgumentError("(0,0) is not a move");
    return move;
  }

  @override
  int get count => 144;

  @override
  Iterable<String> tokensOf(String notation) {
    final tokens = RegExp(r"\(\s*(-?\d+)\s*,\s*(-?\d+)\s*\)|/");
    final leftover = notation.replaceAll(tokens, "").trim();
    if (leftover.isNotEmpty) {
      throw FormatException("Not Square-1 notation: '$leftover'");
    }
    return tokens.allMatches(notation).map((match) => match[0]!.replaceAll(RegExp(r"\s"), ""));
  }

  @override
  int parse(String token) {
    if (token == "/") return slashMove;
    final match = RegExp(r"^\((-?\d+),(-?\d+)\)$").firstMatch(token);
    if (match == null) throw FormatException("Invalid move: $token");
    final top = int.parse(match[1]!);
    final bottom = int.parse(match[2]!);
    if (top % 12 == 0 && bottom % 12 == 0) throw FormatException("Invalid move: $token turns nothing");
    return turn(top, bottom);
  }

  /// `(x,y)` with each between -5 and 6, as TNoodle writes them.
  @override
  String render(int move) {
    if (move == slashMove) return "/";
    int signed(int amount) => amount > 6 ? amount - 12 : amount;
    return "(${signed(move ~/ 12)},${signed(move % 12)})";
  }

  @override
  int invert(int move) => move == slashMove ? slashMove : turn(-(move ~/ 12), -(move % 12));

  @override
  bool operator ==(Object other) => other is Square1MoveSet;

  @override
  int get hashCode => (Square1MoveSet).hashCode;
}

const Square1MoveSet square1Moves = Square1MoveSet._();
