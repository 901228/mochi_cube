/// Names and lookup tables shared by both solvers.
///
/// The two `CubieCube` implementations store their state differently and their
/// permutation coordinates are numbered differently, but they agree exactly on
/// how a cube is labelled: the same face order, the same facelet indices and
/// the same corner and edge numbering. That agreement lives here so it cannot
/// drift apart.
library;

/// Faces in the order every index in this package uses.
enum Face { up, right, front, down, left, back }

extension FaceExtension on Face {
  /// Standard notation letter for the face.
  String get letter => faceToString[index];

  static Face fromLetter(String letter) {
    final index = faceToString.indexOf(letter);
    if (index < 0) {
      throw FormatException("Invalid face: $letter");
    }
    return Face.values[index];
  }

  static const List<String> faceToString = ["U", "R", "F", "D", "L", "B"];
}

/// The 54 stickers, indexed `face * 9 + tile`.
///
/// ```
///          +--------+
///          |U1 U2 U3|
///          |U4 U5 U6|
///          |U7 U8 U9|
/// +--------+--------+--------+--------+
/// |L1 L2 L3|F1 F2 F3|R1 R2 R3|B1 B2 B3|
/// |L4 L5 L6|F4 F5 F6|R4 R5 R6|B4 B5 B6|
/// |L7 L8 L9|F7 F8 F9|R7 R8 R9|B7 B8 B9|
/// +--------+--------+--------+--------+
///          |D1 D2 D3|
///          |D4 D5 D6|
///          |D7 D8 D9|
///          +--------+
/// ```
enum Facelet {
  u1,
  u2,
  u3,
  u4,
  u5,
  u6,
  u7,
  u8,
  u9, //
  r1,
  r2,
  r3,
  r4,
  r5,
  r6,
  r7,
  r8,
  r9, //
  f1,
  f2,
  f3,
  f4,
  f5,
  f6,
  f7,
  f8,
  f9, //
  d1,
  d2,
  d3,
  d4,
  d5,
  d6,
  d7,
  d8,
  d9, //
  l1,
  l2,
  l3,
  l4,
  l5,
  l6,
  l7,
  l8,
  l9, //
  b1,
  b2,
  b3,
  b4,
  b5,
  b6,
  b7,
  b8,
  b9,
}

/*
       *------------*
      /ULB2    3UBR/|
     /            / |
    /UFL1    0URF/  |
   *------------*   |
   |   |        |   |
   |   *--------|---*
   |  /DBL6    7DRB/
   | /          | /
   |/DLF5   4DFR|/
   *------------*
 */
enum Corner {
  upRightFront,
  upFrontLeft,
  upLeftBack,
  upBackRight,
  downFrontRight,
  downLeftFront,
  downBackLeft,
  downRightBack,
}

/*
          *------------*
         /    3UB     /|
        /UL2      0UR/ |
       /     1UF    /  |BR11
      *------------*   |
  BL10|   |        |   |
      |FL9*--------|FR8*
      |  /    7DB  |  /
      | /DL6      4DR/
      |/     5DF   |/
      *------------*
 */
enum Edge {
  upRight,
  upFront,
  upLeft,
  upBack,
  downRight,
  downFront,
  downLeft,
  downBack,
  frontRight,
  frontLeft,
  backLeft,
  backRight,
}

/// The three stickers of each corner position, starting with the U or D one.
const List<List<Facelet>> cornerFacelet = [
  [Facelet.u9, Facelet.r1, Facelet.f3],
  [Facelet.u7, Facelet.f1, Facelet.l3],
  [Facelet.u1, Facelet.l1, Facelet.b3],
  [Facelet.u3, Facelet.b1, Facelet.r3],
  [Facelet.d3, Facelet.f9, Facelet.r7],
  [Facelet.d1, Facelet.l9, Facelet.f7],
  [Facelet.d7, Facelet.b9, Facelet.l7],
  [Facelet.d9, Facelet.r9, Facelet.b7],
];

/// The two stickers of each edge position.
const List<List<Facelet>> edgeFacelet = [
  [Facelet.u6, Facelet.r2],
  [Facelet.u8, Facelet.f2],
  [Facelet.u4, Facelet.l2],
  [Facelet.u2, Facelet.b2],
  [Facelet.d6, Facelet.r8],
  [Facelet.d2, Facelet.f8],
  [Facelet.d4, Facelet.l8],
  [Facelet.d8, Facelet.b8],
  [Facelet.f6, Facelet.r4],
  [Facelet.f4, Facelet.l6],
  [Facelet.b6, Facelet.l4],
  [Facelet.b4, Facelet.r6],
];

/// The colours of each corner piece, in the same order as [cornerFacelet].
const List<List<Face>> cornerFace = [
  [Face.up, Face.right, Face.front],
  [Face.up, Face.front, Face.left],
  [Face.up, Face.left, Face.back],
  [Face.up, Face.back, Face.right],
  [Face.down, Face.front, Face.right],
  [Face.down, Face.left, Face.front],
  [Face.down, Face.back, Face.left],
  [Face.down, Face.right, Face.back],
];

/// The colours of each edge piece, in the same order as [edgeFacelet].
const List<List<Face>> edgeFace = [
  [Face.up, Face.right],
  [Face.up, Face.front],
  [Face.up, Face.left],
  [Face.up, Face.back],
  [Face.down, Face.right],
  [Face.down, Face.front],
  [Face.down, Face.left],
  [Face.down, Face.back],
  [Face.front, Face.right],
  [Face.front, Face.left],
  [Face.back, Face.left],
  [Face.back, Face.right],
];

/// Short names used when printing a cube's pieces.
const List<String> cornerToString = ["URF", "UFL", "ULB", "UBR", "DFR", "DLF", "DBL", "DRB"];
const List<String> edgeToString = ["UR", "UF", "UL", "UB", "DR", "DF", "DL", "DB", "FR", "FL", "BL", "BR"];
