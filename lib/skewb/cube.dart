import "../cube/algorithm.dart";

/// The 30 stickers of a Skewb, indexed `face * 5 + slot`.
///
/// Faces are in the usual U, R, F, D, L, B order. Each face is a square with a
/// diamond in the middle and a triangle in each corner, and the slots read like
/// the 3x3x3's tiles with the edges left out:
///
/// ```
///   0   1
///     2
///   3   4
/// ```
///
/// So slot 2 is the centre, and slots 0, 1, 3 and 4 are the 3x3x3's tiles 0, 2,
/// 6 and 8 — the same corner of the same face, which is what lets the geometry
/// below be checked against the 3x3x3's own corner table.
const int nSkewbFacelets = 30;

/// The slot of each face that shows its centre.
const int centreSlot = 2;

/// The Skewb, held as its stickers.
///
/// Four of the eight corners have a turn of their own in the notation — R, U, L
/// and B — and each turns half the puzzle a third of the way round that corner:
/// the corner, its three neighbours, and the three centres touching it. The
/// corner none of the four halves contains is up-front-right, which so never
/// moves; that is what holds the puzzle still while it is scrambled, and the
/// reason the state count is 3149280 rather than 24 times that.
///
/// Kept as stickers rather than pieces because that is all the turns need: each
/// is a permutation of the 30 stickers, worked out once from where they are in
/// space. Nothing here is written down by hand that could be got wrong.
class SkewbCube {
  /// The 30 stickers, as face indices.
  final List<int> facelets;

  SkewbCube() : facelets = [for (var i = 0; i < nSkewbFacelets; i++) i ~/ 5];

  SkewbCube.from(SkewbCube other) : facelets = [...other.facelets];

  /// A cube showing [facelets], which are taken as they are.
  SkewbCube.fromFacelets(List<int> facelets) : facelets = [...facelets];

  /// The corner each axis of [skewbMoves] turns around, as a sign per axis of
  /// x (right), y (up) and z (front).
  ///
  /// As WCA regulation 12h has them, holding the puzzle with up-front-right
  /// towards you: R the farthest visible bottom right corner, U the farthest
  /// visible upper one, L the farthest visible bottom left one, and B the one
  /// hidden at the back.
  static const List<(int, int, int)> axisCorners = [
    (1, -1, -1), // R: down-back-right
    (-1, 1, -1), // U: up-back-left
    (-1, -1, 1), // L: down-front-left
    (-1, -1, -1), // B: down-back-left
  ];

  /// The corner that never moves.
  static const (int, int, int) fixedCorner = (1, 1, 1);

  /// The stickers of [fixedCorner], on the U, R and F faces in that order.
  static const List<int> fixedCornerFacelets = [4, 5, 11];

  /// Where each sticker goes under one clockwise turn of each axis.
  static final List<List<int>> _turns = [for (final corner in axisCorners) _turnPermutation(corner)];

  /// Turn the half around axis [axis] clockwise, [times] thirds of the way.
  void turn(int axis, [int times = 1]) {
    final to = _turns[axis];
    for (var t = 0; t < times % 3; t++) {
      final moved = List<int>.filled(nSkewbFacelets, 0);
      for (var i = 0; i < nSkewbFacelets; i++) {
        moved[to[i]] = facelets[i];
      }
      facelets.setAll(0, moved);
    }
  }

  /// Apply an algorithm written in [skewbMoves].
  void apply(Algorithm algorithm) {
    for (final move in algorithm.moves) {
      applyMove(move);
    }
  }

  /// Apply one move index of [skewbMoves].
  void applyMove(int move) => turn(skewbMoves.axisOf(move), skewbMoves.amountOf(move) + 1);

  /// Whether every face shows one colour, its own.
  bool get isSolved {
    for (var i = 0; i < nSkewbFacelets; i++) {
      if (facelets[i] != i ~/ 5) return false;
    }
    return true;
  }

  /// The 30 stickers, as face indices.
  List<int> toFacelets() => [...facelets];

  /// The 30 stickers as a string of face letters, `URFDLB`.
  String toFaceletString() => facelets.map((face) => skewbFaceNames[face]).join();

  @override
  String toString() => toFaceletString();
}

/// Skewb notation, WCA regulation 12h: four corners, each turned a third of
/// the way clockwise or, with a prime, anticlockwise.
const MoveSet skewbMoves = MoveSet(axes: ["R", "U", "L", "B"], amounts: ["", "'"]);

/// What the six faces are called in a sticker string.
const List<String> skewbFaceNames = ["U", "R", "F", "D", "L", "B"];

/// Where sticker [facelet] is in space, on a cube from -3 to 3.
///
/// x runs right, y up and z to the front. Each face is laid out the way the
/// 3x3x3 net draws it, so `right` and `down` are the directions its first row
/// and first column run in.
(int, int, int) skewbFaceletPosition(int facelet) {
  const normal = [(0, 1, 0), (1, 0, 0), (0, 0, 1), (0, -1, 0), (-1, 0, 0), (0, 0, -1)];
  const right = [(1, 0, 0), (0, 0, -1), (1, 0, 0), (1, 0, 0), (0, 0, 1), (-1, 0, 0)];
  const down = [(0, 0, 1), (0, -1, 0), (0, -1, 0), (0, 0, -1), (0, -1, 0), (0, -1, 0)];

  final face = facelet ~/ 5;
  final tile = const [0, 2, 4, 6, 8][facelet % 5];
  final across = 2 * (tile % 3 - 1);
  final along = 2 * (tile ~/ 3 - 1);
  final (nx, ny, nz) = normal[face];
  final (rx, ry, rz) = right[face];
  final (dx, dy, dz) = down[face];
  return (
    3 * nx + across * rx + along * dx,
    3 * ny + across * ry + along * dy,
    3 * nz + across * rz + along * dz,
  );
}

/// The corner a sticker belongs to, as a sign per axis, or null for a centre.
(int, int, int)? skewbCornerOf(int facelet) {
  if (facelet % 5 == centreSlot) return null;
  final (x, y, z) = skewbFaceletPosition(facelet);
  return (x.sign, y.sign, z.sign);
}

/// Where each sticker goes under one clockwise turn around [corner].
///
/// The cut is the plane through the middle square to that corner's diagonal,
/// and no sticker lies on it, so the half that turns is every sticker on the
/// corner's side. Clockwise is as seen looking at the corner from outside, which
/// is a rotation of -120 degrees about the diagonal. Rodrigues' formula for that
/// angle about `c / sqrt(3)` comes out in whole numbers:
/// `(c (c . p) - p - c x p) / 2`.
List<int> _turnPermutation((int, int, int) corner) {
  final (cx, cy, cz) = corner;
  final positions = [for (var i = 0; i < nSkewbFacelets; i++) skewbFaceletPosition(i)];

  return [
    for (final (x, y, z) in positions)
      () {
        final dot = cx * x + cy * y + cz * z;
        if (dot < 0) return positions.indexOf((x, y, z));
        final turned = (
          (cx * dot - x - (cy * z - cz * y)) ~/ 2,
          (cy * dot - y - (cz * x - cx * z)) ~/ 2,
          (cz * dot - z - (cx * y - cy * x)) ~/ 2,
        );
        final to = positions.indexOf(turned);
        if (to < 0) throw StateError("A turn about $corner leaves the puzzle at $turned");
        return to;
      }(),
  ];
}
