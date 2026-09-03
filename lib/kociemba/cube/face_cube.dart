import "cubie_cube.dart";
import "enums.dart";

class FaceCube {
  List<Face> state;
  static const int stateLength = 54; // 6 face * 9 tiles
  static List<Face> initState() {
    return [
      ...List.generate(9, (_) => Face.up, growable: false),
      ...List.generate(9, (_) => Face.right, growable: false),
      ...List.generate(9, (_) => Face.front, growable: false),
      ...List.generate(9, (_) => Face.down, growable: false),
      ...List.generate(9, (_) => Face.left, growable: false),
      ...List.generate(9, (_) => Face.back, growable: false),
    ];
  }
  /*
             +--------+
             |U0 U1 U2|
             |U3 U4 U5|
             |U6 U7 U8|
    +--------+--------+--------+--------+
    |L0 L1 L2|F0 F1 F2|R0 R1 R2|B0 B1 B2|
    |L3 L4 L5|F3 F4 F5|R3 R4 R5|B3 B4 B5|
    |L6 L7 L8|F6 F7 F8|R6 R7 R8|B6 B7 B8|
    +--------+--------+--------+--------+
             |D0 D1 D2|
             |D3 D4 D5|
             |D6 D7 D8|
             +--------+

    index = face_index * 9 + tile_index
   */

  FaceCube([List<Face>? state])
    : assert(state == null || state.length == stateLength),
      state = state ?? initState();

  @override
  String toString() {
    String str = "";
    for (final face in state) {
      str += FaceExtension.faceToString[face.index];
    }
    return str;
  }

  factory FaceCube.fromString(String facelets) {
    facelets = facelets.replaceAll(" ", "");
    assert(facelets.length == stateLength);

    List<Face> state = [];
    for (int i = 0; i < facelets.length; i++) {
      Face face = FaceExtension.fromLetter(facelets[i]);
      state.add(face);
    }

    return FaceCube(state);
  }

  factory FaceCube.fromCubieCube(CubieCube cube) {
    List<Face?> state = List.filled(stateLength, null);

    // assign centers
    for (var i = 0; i < 6; i++) {
      state[i * 9 + 4] = Face.values[i];
    }

    // assign corners
    for (var i = 0; i < 8; i++) {
      var permutation = cube.cornerState[i].permutation.index;
      var orientation = cube.cornerState[i].orientation;
      for (var k = 0; k < 3; k++) {
        final index = cornerFacelet[i][(k + orientation) % 3].index;
        state[index] = cornerFace[permutation][k];
      }
    }

    // assign edges
    for (var i = 0; i < 12; i++) {
      var permutation = cube.edgeState[i].permutation.index;
      var orientation = cube.edgeState[i].orientation;
      for (var k = 0; k < 2; k++) {
        final index = edgeFacelet[i][(k + orientation) % 2].index;
        state[index] = edgeFace[permutation][k];
      }
    }

    return FaceCube(List<Face>.from(state));
  }

  @override
  int get hashCode => toString().hashCode;

  @override
  bool operator ==(Object other) {
    return other is FaceCube && toString() == other.toString();
  }
}
