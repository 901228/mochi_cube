import "dart:typed_data";

import "cube.dart";

/// The tables behind the Square-1's two-phase search, after Chen Shuang's
/// sq12phase.
///
/// Phase 1 brings the puzzle back to a cube, phase 2 solves it as a cube, and
/// each has its own coordinate:
///
/// - **Shape**: which slots hold a corner, for the 3678 shapes in which no
///   corner straddles the cut, together with the parity of the pieces read in
///   slot order. Phase 2 cannot change that parity, which is why it has to be
///   part of what phase 1 aims for.
/// - **Square**: once it is a cube, the corners and the edges each sit in eight
///   places and turn as two separate permutations, plus the middle layer.
///
/// All of it together is under 400 KB and builds in about 0.2s, so unlike
/// the other puzzles' it is not cached.
class Square1Tables {
  factory Square1Tables() => _instance;
  static final Square1Tables _instance = Square1Tables._();

  static const int nShapes = 3678;

  /// Shapes counted with their parity.
  static const int nShapeStates = nShapes * 2;

  /// The arrangements of eight pieces.
  static const int nPerms = 40320;

  /// Every shape, as 24 bits: bit `23 - slot` set where a corner is.
  final List<int> shapes = _shapes();

  late final Map<int, int> _shapeIndex = {for (var i = 0; i < shapes.length; i++) shapes[i]: i};

  /// What `/` does to a shape state.
  final Uint16List twistMove = Uint16List(nShapeStates);

  /// The shape state after the smallest turn of the top that leaves `/`
  /// turnable, and in [topAmount] how far that turn was.
  final Uint16List topMove = Uint16List(nShapeStates);
  final Uint8List topAmount = Uint8List(nShapeStates);

  /// The same for the bottom.
  final Uint16List bottomMove = Uint16List(nShapeStates);
  final Uint8List bottomAmount = Uint8List(nShapeStates);

  /// Turns to a cube of the right parity, a turn of either layer or a `/`
  /// counting one each. Exact, so an admissible bound for phase 1.
  final Uint8List shapePrune = Uint8List(nShapeStates);

  /// What `/`, a quarter turn of the top and a quarter turn of the bottom do to
  /// the eight corners, or the eight edges, of a cube.
  final Uint16List squareTwist = Uint16List(nPerms);
  final Uint16List squareTop = Uint16List(nPerms);
  final Uint16List squareBottom = Uint16List(nPerms);

  /// Moves to solve one permutation and the middle together, indexed
  /// `perm * 2 + middle`. Exact for that pair, and so a bound for both.
  final Uint8List squarePrune = Uint8List(nPerms * 2);

  /// The shape states phase 1 aims for: the four ways to stand as a cube with
  /// a parity phase 2 can finish, from sq12phase. Solved is the last.
  static const List<int> cubeShapes = [0x0db66db, 0x1db6db6, 0x16db6db, 0x06dbdb6];

  Square1Tables._() {
    _buildShapes();
    _buildSquares();
  }

  /// The shape state of [cube], or null when a corner straddles the cut.
  int? shapeOf(Square1Cube cube) {
    var bits = 0;
    for (var slot = 0; slot < 24; slot++) {
      if (Square1Cube.isCorner(cube.pieces[slot])) bits |= 1 << (23 - slot);
    }
    final index = _shapeIndex[bits];
    return index == null ? null : index * 2 + parityOf(cube);
  }

  /// The parity of the sixteen pieces, read in slot order.
  static int parityOf(Square1Cube cube) {
    final order = <int>[];
    for (final piece in cube.pieces) {
      if (order.isEmpty || order.last != piece) order.add(piece);
    }
    var parity = 0;
    for (var a = 0; a < order.length; a++) {
      for (var b = a + 1; b < order.length; b++) {
        if (order[a] > order[b]) parity ^= 1;
      }
    }
    return parity;
  }

  /// A cube with shape state [state]: the pieces in order, two edges swapped
  /// if that is what the parity needs. The moves on shapes are worked out on
  /// it, which is fair because what a move does to the shape and the parity
  /// does not depend on which pieces are where.
  Square1Cube representative(int state) {
    final bits = shapes[state ~/ 2];
    final cube = Square1Cube();
    var corner = 1;
    var edge = 0;
    for (var slot = 0; slot < 24; slot++) {
      if ((bits >> (23 - slot)) & 1 == 0) {
        cube.pieces[slot] = edge;
        edge += 2;
      } else {
        cube.pieces[slot] = cube.pieces[slot + 1] = corner;
        corner += 2;
        slot++;
      }
    }
    if (parityOf(cube) != state % 2) {
      final a = cube.pieces.indexOf(0);
      final b = cube.pieces.indexOf(2);
      cube.pieces[a] = 2;
      cube.pieces[b] = 0;
    }
    return cube;
  }

  void _buildShapes() {
    for (var state = 0; state < nShapeStates; state++) {
      twistMove[state] = shapeOf(representative(state)..slash())!;

      final top = representative(state);
      var amount = 0;
      do {
        top.turnTop(1);
        amount++;
      } while (!top.canSlash);
      topMove[state] = shapeOf(top)!;
      topAmount[state] = amount;

      final bottom = representative(state);
      amount = 0;
      do {
        bottom.turnBottom(1);
        amount++;
      } while (!bottom.canSlash);
      bottomMove[state] = shapeOf(bottom)!;
      bottomAmount[state] = amount;
    }

    shapePrune.fillRange(0, nShapeStates, 0xFF);
    var frontier = [for (final shape in cubeShapes) _shapeIndex[shape & 0xFFFFFF]! * 2 + (shape >> 24)];
    for (final state in frontier) {
      shapePrune[state] = 0;
    }
    for (var depth = 1; frontier.isNotEmpty; depth++) {
      final next = <int>[];
      void visit(int state) {
        if (shapePrune[state] == 0xFF) {
          shapePrune[state] = depth;
          next.add(state);
        }
      }

      for (final state in frontier) {
        visit(twistMove[state]);
        for (final (move, amount) in [(topMove, topAmount), (bottomMove, bottomAmount)]) {
          var turned = state;
          for (var total = amount[turned]; total < 12; total += amount[turned]) {
            turned = move[turned];
            visit(turned);
          }
        }
      }
      frontier = next;
    }
  }

  void _buildSquares() {
    for (var perm = 0; perm < nPerms; perm++) {
      final p = permFromIndex(perm);
      squareTwist[perm] = permIndex([p[0], p[1], p[4], p[5], p[2], p[3], p[6], p[7]]);
      squareTop[perm] = permIndex([p[1], p[2], p[3], p[0], p[4], p[5], p[6], p[7]]);
      squareBottom[perm] = permIndex([p[0], p[1], p[2], p[3], p[5], p[6], p[7], p[4]]);
    }

    squarePrune.fillRange(0, nPerms * 2, 0xFF);
    squarePrune[0] = 0;
    var frontier = [0];
    for (var depth = 1; frontier.isNotEmpty; depth++) {
      final next = <int>[];
      void visit(int index) {
        if (squarePrune[index] == 0xFF) {
          squarePrune[index] = depth;
          next.add(index);
        }
      }

      for (final index in frontier) {
        final perm = index >> 1;
        final middle = index & 1;
        visit(squareTwist[perm] << 1 | (1 - middle));
        for (final move in [squareTop, squareBottom]) {
          var turned = perm;
          for (var i = 0; i < 3; i++) {
            turned = move[turned];
            visit(turned << 1 | middle);
          }
        }
      }
      frontier = next;
    }
  }

  /// The position of an arrangement of 0 to 7 in lexicographic order, so the
  /// identity is 0.
  static int permIndex(List<int> perm) {
    var index = 0;
    for (var i = 0; i < 8; i++) {
      var smaller = 0;
      for (var j = i + 1; j < 8; j++) {
        if (perm[j] < perm[i]) smaller++;
      }
      index = index * (8 - i) + smaller;
    }
    return index;
  }

  static List<int> permFromIndex(int index) {
    final digits = List.filled(8, 0);
    for (var i = 7; i >= 0; i--) {
      digits[i] = index % (8 - i);
      index ~/= 8 - i;
    }
    final left = [0, 1, 2, 3, 4, 5, 6, 7];
    return [for (final digit in digits) left.removeAt(digit)];
  }
}

/// The 3678 shapes in which no corner straddles the cut, in increasing order.
///
/// Each half layer is six slots, and the thirteen ways to fill one with whole
/// pieces are listed once; a shape is four of them holding the eight corners.
List<int> _shapes() {
  const halves = [0x00, 0x03, 0x06, 0x0c, 0x0f, 0x18, 0x1b, 0x1e, 0x30, 0x33, 0x36, 0x3c, 0x3f];
  return [
    for (final a in halves)
      for (final b in halves)
        for (final c in halves)
          for (final d in halves)
            if (_bitCount(a << 18 | b << 12 | c << 6 | d) == 16) a << 18 | b << 12 | c << 6 | d,
  ];
}

int _bitCount(int value) {
  var count = 0;
  for (; value != 0; value &= value - 1) {
    count++;
  }
  return count;
}
