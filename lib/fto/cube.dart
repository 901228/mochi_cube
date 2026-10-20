import "../cube/algorithm.dart";

/// The eight faces, in TNoodle's order: the four round one corner of the
/// octahedron, then the four round the opposite corner.
const List<String> ftoFaceNames = ["U", "R", "F", "L", "B", "BL", "D", "BR"];

/// How many stickers there are: nine on each of the eight faces.
const int nFtoFacelets = 72;

/// The Face Turning Octahedron, held as its stickers.
///
/// Sticker `face * 9 + slot`, the slots in the order TNoodle draws a face: each
/// face is a triangle cut into nine, read in three rows from its outer side
/// towards the corner it shares with three other faces. [ftoFaceletPosition]
/// says where each is in space, and every turn is worked out from that, as for
/// the Skewb: nothing about the turns is written by hand.
class Fto {
  /// The stickers, as face indices.
  final List<int> facelets;

  Fto() : facelets = [for (var i = 0; i < nFtoFacelets; i++) i ~/ 9];

  Fto.from(Fto other) : facelets = [...other.facelets];

  /// A puzzle showing [facelets], which are taken as they are.
  Fto.fromFacelets(List<int> facelets) : facelets = [...facelets];

  /// Where each sticker goes under a third of a turn clockwise of each face.
  static final List<List<int>> _turns = [for (var face = 0; face < 8; face++) _turnPermutation(face)];

  /// Turn [face] a third of the way round clockwise, as seen from outside it,
  /// [times] times.
  void turn(int face, [int times = 1]) {
    final to = _turns[face];
    for (var t = 0; t < times % 3; t++) {
      final moved = List<int>.filled(nFtoFacelets, 0);
      for (var i = 0; i < nFtoFacelets; i++) {
        moved[to[i]] = facelets[i];
      }
      facelets.setAll(0, moved);
    }
  }

  /// Apply one move index of [ftoMoves].
  void applyMove(int move) => turn(ftoMoves.axisOf(move), ftoMoves.amountOf(move) + 1);

  /// Apply an algorithm written in [ftoMoves].
  void apply(Algorithm algorithm) {
    for (final move in algorithm.moves) {
      applyMove(move);
    }
  }

  bool get isSolved {
    for (var i = 0; i < nFtoFacelets; i++) {
      if (facelets[i] != i ~/ 9) return false;
    }
    return true;
  }

  List<int> toFacelets() => [...facelets];

  /// The stickers as a string of [ftoFaceLetters].
  String toFaceletString() => facelets.map((face) => ftoFaceLetters[face]).join();

  @override
  String toString() => toFaceletString();
}

/// What each face is written as in a sticker string, one letter each since
/// two of the names are not: `A` for U, `B` for R and so on in [ftoFaceNames]
/// order.
const String ftoFaceLetters = "ABCDEFGH";

/// FTO notation, WCA regulation 12j: each face turned a third of the way
/// clockwise, or with a prime anticlockwise.
const MoveSet ftoMoves = MoveSet(axes: ftoFaceNames, amounts: ["", "'"]);

/// Which way each face looks: the signs of x, y and z on it.
///
/// The octahedron is `|x| + |y| + |z| = 1`, with y up. U, R, F and L meet at
/// the top corner and are the ones TNoodle draws on the left, B, BL, D and BR
/// meet at the bottom one; each face is opposite the one whose signs are all
/// the other way, which is U to D, F to B, R to BL and L to BR.
const List<(int, int, int)> ftoFaceNormal = [
  (-1, 1, -1), // U
  (1, 1, -1), // R
  (1, 1, 1), // F
  (-1, 1, 1), // L
  (-1, -1, -1), // B
  (-1, -1, 1), // BL
  (1, -1, 1), // D
  (1, -1, -1), // BR
];

/// The three corners of each face as TNoodle draws it: the corner the face
/// shares with the other three of its half first, then its outer side from
/// left to right as drawn.
List<(int, int, int)> ftoFaceCorners(int face) {
  // Each half is drawn as a square seen from outside, the shared corner in
  // the middle and the square's corners in clockwise order from top left; the
  // faces go round it a quarter turn apart.
  const top = [(-1, 0, 0), (0, 0, -1), (1, 0, 0), (0, 0, 1)];
  const bottom = [(0, 0, -1), (-1, 0, 0), (0, 0, 1), (1, 0, 0)];
  final half = face < 4 ? top : bottom;
  final r = face % 4;
  return [(0, face < 4 ? 1 : -1, 0), half[r], half[(r + 1) % 4]];
}

/// The slots of a face, each as the three lattice points of its triangle:
/// `(i, j)` is `i` thirds of the way towards the second corner and `j`
/// towards the third.
const List<List<(int, int)>> _slotTriangles = [
  [(1, 0), (0, 1), (1, 1)],
  [(0, 0), (1, 0), (0, 1)],
  [(1, 1), (0, 2), (1, 2)],
  [(0, 1), (1, 1), (0, 2)],
  [(0, 2), (1, 2), (0, 3)],
  [(2, 0), (1, 1), (2, 1)],
  [(1, 0), (2, 0), (1, 1)],
  [(1, 1), (2, 1), (1, 2)],
  [(2, 0), (3, 0), (2, 1)],
];

/// Where sticker [facelet] is in space: nine times its centre, so that every
/// coordinate is a whole number.
(int, int, int) ftoFaceletPosition(int facelet) {
  final [a, b, c] = ftoFaceCorners(facelet ~/ 9);
  var (x, y, z) = (0, 0, 0);
  for (final (i, j) in _slotTriangles[facelet % 9]) {
    // Three times the lattice point, summed over the triangle's three corners.
    x += 3 * a.$1 + i * (b.$1 - a.$1) + j * (c.$1 - a.$1);
    y += 3 * a.$2 + i * (b.$2 - a.$2) + j * (c.$2 - a.$2);
    z += 3 * a.$3 + i * (b.$3 - a.$3) + j * (c.$3 - a.$3);
  }
  return (x, y, z);
}

/// Where each sticker goes under a clockwise third of a turn of [face].
///
/// The layer that turns is everything more than a third of the way out
/// towards the face, which is where the puzzle is cut. Clockwise as seen from
/// outside is -120 degrees about the face's normal: about (1, 1, 1) that takes
/// (x, y, z) to (y, z, x), and the other faces are that with the signs changed.
/// Changing an odd number of signs is a reflection, which turns a rotation the
/// other way, so those faces take the inverse, (z, x, y), instead.
List<int> _turnPermutation(int face) {
  final (s1, s2, s3) = ftoFaceNormal[face];
  final positions = [for (var i = 0; i < nFtoFacelets; i++) ftoFaceletPosition(i)];
  final index = {for (var i = 0; i < nFtoFacelets; i++) positions[i]: i};
  return [
    for (final (x, y, z) in positions)
      () {
        // Nine times a third, on the scale positions are kept at.
        if (s1 * x + s2 * y + s3 * z <= 3) return index[(x, y, z)]!;
        final turned = s1 * s2 * s3 == 1
            ? (s1 * s2 * y, s2 * s3 * z, s3 * s1 * x)
            : (s1 * s3 * z, s2 * s1 * x, s3 * s2 * y);
        return index[turned] ?? (throw StateError("A turn of face $face leaves the puzzle at $turned"));
      }(),
  ];
}
