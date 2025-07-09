enum EFace { up, right, front, down, left, back }

abstract class CFace {
  static EFace faceFromLetter(String letter) {
    switch (letter) {
      case "U":
        return EFace.up;
      case "R":
        return EFace.right;
      case "F":
        return EFace.front;
      case "D":
        return EFace.down;
      case "L":
        return EFace.left;
      case "B":
        return EFace.back;
      default:
        throw FormatException("Invalid face: $letter");
    }
  }

  static final faceToString = ["U", "R", "F", "D", "L", "B"];
}

enum EFacelet {
  u0,
  u1,
  u2,
  u3,
  u4,
  u5,
  u6,
  u7,
  u8,
  r0,
  r1,
  r2,
  r3,
  r4,
  r5,
  r6,
  r7,
  r8,
  f0,
  f1,
  f2,
  f3,
  f4,
  f5,
  f6,
  f7,
  f8,
  d0,
  d1,
  d2,
  d3,
  d4,
  d5,
  d6,
  d7,
  d8,
  l0,
  l1,
  l2,
  l3,
  l4,
  l5,
  l6,
  l7,
  l8,
  b0,
  b1,
  b2,
  b3,
  b4,
  b5,
  b6,
  b7,
  b8,
}

enum ECorner {
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
class CCorner {
  ECorner permutation;
  int orientation;
  CCorner(this.permutation, this.orientation) : assert(orientation >= 0 && orientation <= 2);

  static final cornerToFacelet = [
    [EFacelet.u8, EFacelet.r0, EFacelet.f2],
    [EFacelet.u6, EFacelet.f0, EFacelet.l2],
    [EFacelet.u0, EFacelet.l0, EFacelet.b2],
    [EFacelet.u2, EFacelet.b0, EFacelet.r2],
    [EFacelet.d2, EFacelet.f8, EFacelet.r6],
    [EFacelet.d0, EFacelet.l8, EFacelet.f6],
    [EFacelet.d6, EFacelet.b8, EFacelet.l6],
    [EFacelet.d8, EFacelet.r8, EFacelet.b6],
  ];

  static final cornerToFace = [
    [EFace.up, EFace.right, EFace.front],
    [EFace.up, EFace.front, EFace.left],
    [EFace.up, EFace.left, EFace.back],
    [EFace.up, EFace.back, EFace.right],
    [EFace.down, EFace.front, EFace.right],
    [EFace.down, EFace.left, EFace.front],
    [EFace.down, EFace.back, EFace.left],
    [EFace.down, EFace.right, EFace.back],
  ];

  static final permutationToString = ["URF", "UFL", "ULB", "UBR", "DFR", "DLF", "DBL", "DRB"];

  List<EFacelet> toFacelet() {
    return List.generate(
      3,
      (index) => cornerToFacelet[permutation.index][(index + orientation) % 3],
      growable: false,
    );
  }

  List<EFace> toFace() {
    return List.generate(3, (index) => cornerToFace[permutation.index][index], growable: false);
  }

  @override
  String toString() {
    String str = permutationToString[permutation.index];
    return "${str[orientation]}${str[(orientation + 1) % 3]}${str[(orientation + 2) % 3]}";
  }
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

enum EEdge {
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

class CEdge {
  EEdge permutation;
  int orientation;
  CEdge(this.permutation, this.orientation) : assert(orientation == 0 || orientation == 1);

  static final edgeToFacelet = [
    [EFacelet.u5, EFacelet.r1],
    [EFacelet.u7, EFacelet.f1],
    [EFacelet.u3, EFacelet.l1],
    [EFacelet.u1, EFacelet.b1],
    [EFacelet.d5, EFacelet.r7],
    [EFacelet.d1, EFacelet.f7],
    [EFacelet.d3, EFacelet.l7],
    [EFacelet.d7, EFacelet.b7],
    [EFacelet.f5, EFacelet.r3],
    [EFacelet.f3, EFacelet.l5],
    [EFacelet.b5, EFacelet.l3],
    [EFacelet.b3, EFacelet.r5],
  ];

  static final edgeToFace = [
    [EFace.up, EFace.right],
    [EFace.up, EFace.front],
    [EFace.up, EFace.left],
    [EFace.up, EFace.back],
    [EFace.down, EFace.right],
    [EFace.down, EFace.front],
    [EFace.down, EFace.left],
    [EFace.down, EFace.back],
    [EFace.front, EFace.right],
    [EFace.front, EFace.left],
    [EFace.back, EFace.left],
    [EFace.back, EFace.right],
  ];

  static final permutationToString = ["UR", "UF", "UL", "UB", "DR", "DF", "DL", "DB", "FR", "FL", "BL", "BR"];

  List<EFacelet> toFacelet() {
    return List.generate(
      2,
      (index) => edgeToFacelet[permutation.index][(index + orientation) % 2],
      growable: false,
    );
  }

  List<EFace> toFace() {
    return List.generate(2, (index) => edgeToFace[permutation.index][index], growable: false);
  }

  @override
  String toString() {
    String str = permutationToString[permutation.index];
    if (orientation == 1) {
      String str1 = str[0];
      str = str[1] + str1;
    }
    return str;
  }
}

enum ERotation { up, right, front, down, left, back }

class CRotation {
  ERotation notation;
  int amount;
  CRotation(this.notation, this.amount) : assert(amount >= 1 && amount <= 3);

  static final notationToString = ["U", "R", "F", "D", "L", "B"];
  static final stringToNotation = {
    "U": ERotation.up,
    "R": ERotation.right,
    "F": ERotation.front,
    "D": ERotation.down,
    "L": ERotation.left,
    "B": ERotation.back,
  };

  @override
  String toString() {
    String str = notationToString[notation.index];
    if (amount == 2) {
      str += "2";
    } else if (amount == 3) {
      str += "'";
    }

    return str;
  }

  factory CRotation.fromString(String str) {
    assert(str.length == 1 || str.length == 2);

    ERotation? notation = stringToNotation[str[0]];
    if (notation == null) {
      throw FormatException("Invalid rotation notation: ${str[0]}");
    }

    int amount;
    if (str.length == 1) {
      amount = 1;
    } else if (str[1] == "2") {
      amount = 2;
    } else if (str[1] == "'") {
      amount = 3;
    } else {
      throw FormatException("Invalid rotation amount: ${str[1]}");
    }

    return CRotation(notation, amount);
  }
}

enum CubeVerification {
  solvable,
  colorDuplicated, // each colour should appear exactly 9 times
  edgeDuplicated, // not all 12 edges exist exactly once
  cornerDuplicated, // not all 8 corners exist exactly once
  flipError, // one edge should be flipped
  twistError, // one corner must be twisted
  parityError, // two corners or edges have to be exchanged
}
