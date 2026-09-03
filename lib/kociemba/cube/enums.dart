import "../../cube/enums.dart";

export "../../cube/enums.dart";

/// A corner in a position, as a piece plus how far it is twisted.
///
/// The min2phase side packs the same thing into one int; this solver keeps it
/// as an object, which is why the two `CubieCube` implementations cannot share
/// a representation.
class CCorner {
  Corner permutation;
  int orientation;

  CCorner(this.permutation, this.orientation) : assert(orientation >= 0 && orientation <= 2);

  List<Facelet> toFacelet() => List.generate(
    3,
    (index) => cornerFacelet[permutation.index][(index + orientation) % 3],
    growable: false,
  );

  List<Face> toFace() =>
      List.generate(3, (index) => cornerFace[permutation.index][index], growable: false);

  @override
  String toString() {
    final str = cornerToString[permutation.index];
    return "${str[orientation]}${str[(orientation + 1) % 3]}${str[(orientation + 2) % 3]}";
  }
}

/// An edge in a position, as a piece plus whether it is flipped.
class CEdge {
  Edge permutation;
  int orientation;

  CEdge(this.permutation, this.orientation) : assert(orientation == 0 || orientation == 1);

  List<Facelet> toFacelet() => List.generate(
    2,
    (index) => edgeFacelet[permutation.index][(index + orientation) % 2],
    growable: false,
  );

  List<Face> toFace() =>
      List.generate(2, (index) => edgeFace[permutation.index][index], growable: false);

  @override
  String toString() {
    final str = edgeToString[permutation.index];
    return orientation == 1 ? str[1] + str[0] : str;
  }
}

/// A face turn, as the face and the number of clockwise quarter turns.
class CRotation {
  Face notation;
  int amount;

  CRotation(this.notation, this.amount) : assert(amount >= 1 && amount <= 3);

  @override
  String toString() {
    final str = FaceExtension.faceToString[notation.index];
    if (amount == 2) {
      return "${str}2";
    } else if (amount == 3) {
      return "$str'";
    }
    return str;
  }

  factory CRotation.fromString(String str) {
    assert(str.length == 1 || str.length == 2);

    final notation = FaceExtension.fromLetter(str[0]);

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

  void invert() {
    if (amount == 1) {
      amount = 3;
    } else if (amount == 3) {
      amount = 1;
    }
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
