import "dart:math";

import "enums.dart";
import "face_cube.dart";
import "moves.dart";

class CubieCube {
  List<CCorner> cornerState;
  static const int cornerLength = 8;
  List<CEdge> edgeState;
  static const int edgeLength = 12;

  static List<CCorner> initCornerState() {
    return [
      CCorner(ECorner.upRightFront, 0),
      CCorner(ECorner.upFrontLeft, 0),
      CCorner(ECorner.upLeftBack, 0),
      CCorner(ECorner.upBackRight, 0),
      CCorner(ECorner.downFrontRight, 0),
      CCorner(ECorner.downLeftFront, 0),
      CCorner(ECorner.downBackLeft, 0),
      CCorner(ECorner.downRightBack, 0),
    ];
  }

  @override
  String toString() {
    String cornerStr = "";
    for (final corner in cornerState) {
      cornerStr += "$corner ";
    }

    String edgeStr = "";
    for (final edge in edgeState) {
      edgeStr += "$edge ";
    }

    return {
      "cornerState": cornerStr.substring(0, cornerStr.length - 1),
      "edgeState": edgeStr.substring(0, edgeStr.length - 1),
    }.toString();
  }

  static List<CEdge> initEdgeState() {
    return [
      CEdge(EEdge.upRight, 0),
      CEdge(EEdge.upFront, 0),
      CEdge(EEdge.upLeft, 0),
      CEdge(EEdge.upBack, 0),
      CEdge(EEdge.downRight, 0),
      CEdge(EEdge.downFront, 0),
      CEdge(EEdge.downLeft, 0),
      CEdge(EEdge.downBack, 0),
      CEdge(EEdge.frontRight, 0),
      CEdge(EEdge.frontLeft, 0),
      CEdge(EEdge.backLeft, 0),
      CEdge(EEdge.backRight, 0),
    ];
  }

  CubieCube({List<CCorner>? cornerState, List<CEdge>? edgeState})
    : assert(cornerState == null || cornerState.length == cornerLength),
      assert(edgeState == null || edgeState.length == edgeLength),
      cornerState = cornerState ?? initCornerState(),
      edgeState = edgeState ?? initEdgeState();

  /// Generate a random cube
  ///
  /// The probability is the same for all possible states
  CubieCube.randomize([int? seed]) : cornerState = initCornerState(), edgeState = initEdgeState() {
    final random = Random(seed);

    // set edge permutation
    edge = random.nextInt(_factorial(edgeLength)); // 12!

    // set corner permutation
    final ep = edgeParity;
    while (true) {
      corner = random.nextInt(_factorial(cornerLength)); // 8!
      if (ep == cornerParity) {
        break;
      }
    }

    // set orientations
    twist = random.nextInt(pow(3, cornerLength - 1).toInt()); // 3^7
    flip = random.nextInt(pow(2, edgeLength - 1).toInt()); // 2^11
  }

  factory CubieCube.fromFaceCube(FaceCube cube) {
    List<CCorner?> cornerState = List.filled(cornerLength, null);
    List<CEdge?> edgeState = List.filled(edgeLength, null);

    for (var i = 0; i < cornerLength; i++) {
      // find orientation:
      //    because all the corner permutations start with U or D,
      //    allow us to find the orientation by checking where is the U and D
      int ori = 0;
      for (ori = 0; ori < 3; ori++) {
        if ([EFace.up, EFace.down].contains(cube.state[CCorner.cornerToFacelet[i][ori].index])) {
          break;
        }
      }

      // find permutation
      final color1 = cube.state[CCorner.cornerToFacelet[i][(ori + 1) % 3].index];
      final color2 = cube.state[CCorner.cornerToFacelet[i][(ori + 2) % 3].index];
      for (var j = 0; j < cornerLength; j++) {
        if (CCorner.cornerToFace[j][1] == color1 && CCorner.cornerToFace[j][2] == color2) {
          cornerState[i] = CCorner(ECorner.values[j], ori);
        }
      }
    }

    for (var i = 0; i < edgeLength; i++) {
      for (var j = 0; j < edgeLength; j++) {
        if (cube.state[CEdge.edgeToFacelet[i][0].index] == CEdge.edgeToFace[j][0] &&
            cube.state[CEdge.edgeToFacelet[i][1].index] == CEdge.edgeToFace[j][1]) {
          edgeState[i] = CEdge(EEdge.values[j], 0);
        } else if (cube.state[CEdge.edgeToFacelet[i][0].index] == CEdge.edgeToFace[j][1] &&
            cube.state[CEdge.edgeToFacelet[i][1].index] == CEdge.edgeToFace[j][0]) {
          edgeState[i] = CEdge(EEdge.values[j], 1);
        }
      }
    }

    return CubieCube(cornerState: List<CCorner>.from(cornerState), edgeState: List<CEdge>.from(edgeState));
  }

  void applyScramble(String scramble) {
    scramble.split(" ").forEach((e) {
      final rotation = CRotation.fromString(e);
      for (var i = 0; i < rotation.amount; i++) {
        move(rotation.notation);
      }
    });
  }

  factory CubieCube.fromScramble(String scramble) {
    final CubieCube cube = CubieCube();
    cube.applyScramble(scramble);
    return cube;
  }

  /// Compute permutation and orientation of corners after applying permutation represented by b to current cube
  ///
  /// NOTE:
  /// We use "is replaced by" notation for the permutations. So b.cp[URF] gives the index of the piece that replaces URF when applying b.
  /// To explain the rules we use the example of first applying F then applying R.
  ///
  /// Under F we have URF (position) <- UFL (block), and under R we have UBR <- URF.
  /// Hence we have UBR (position) <- UFL (block), leading to the rule: (F*R).cp[UBR] = F.cp[R.cp[UBR]].
  ///
  /// The corner orientation arrays tell us the change in orientation of a piece (based on where it ends up) due to that move.
  /// So for example F.co[URF] = 1, which means that as UFL moves to URF under the F move, its orientation increases by 1.
  /// To get the total change in orientation of the piece that moves to UBR under FR we use the rule: (F*R).co[UBR] = F.co[R.cp[UBR]] + R.co[UBR].
  void cornerMultiply(CubieCube b) {
    final newCornerState = [
      for (var i = 0; i < cornerLength; i++)
        CCorner(
          cornerState[b.cornerState[i].permutation.index].permutation,
          (cornerState[b.cornerState[i].permutation.index].orientation + b.cornerState[i].orientation) % 3,
        ),
    ];
    cornerState = newCornerState;
  }

  /// Compute permutation and orientation of edges after applying permutation represented by b to current cube
  ///
  /// NOTE: See docstring of cornerMultiply (which operates analogously to this method) for a description of how the update rules are derived
  void edgeMultiply(CubieCube b) {
    final newEdgeState = [
      for (var i = 0; i < edgeLength; i++)
        CEdge(
          edgeState[b.edgeState[i].permutation.index].permutation,
          (edgeState[b.edgeState[i].permutation.index].orientation + b.edgeState[i].orientation) % 2,
        ),
    ];
    edgeState = newEdgeState;
  }

  /// Compute permutation and orientation of edges and corners after applying permutation represented by b to the current cube
  void multiply(CubieCube b) {
    cornerMultiply(b);
    edgeMultiply(b);
  }

  /// move the cube by the given rotation
  void move(ERotation rotation) {
    multiply(moveCube[rotation.index]);
  }

  /// Corner parity of the CubieCube. Cube is solveable if and only if this matches the edge parity.
  bool get cornerParity {
    int s = 0;
    for (var i = cornerLength - 1; i >= 1; i--) {
      for (var j = i - 1; j >= 0; j--) {
        if (cornerState[j].permutation.index > cornerState[i].permutation.index) {
          s += 1;
        }
      }
    }

    return s % 2 == 1;
  }

  bool get edgeParity {
    var s = 0;
    for (var i = edgeLength - 1; i >= 0; i--) {
      for (var j = i - 1; j >= 0; j--) {
        if (edgeState[j].permutation.index > edgeState[i].permutation.index) {
          s += 1;
        }
      }
    }

    return s % 2 == 1;
  }

  CubeVerification validate() {
    final faceCube = FaceCube.fromCubieCube(this);
    final faceCounts = List.filled(6, 0);
    for (final s in faceCube.state) {
      faceCounts[s.index] += 1;
    }
    for (var i = 0; i < 6; i++) {
      if (faceCounts[i] != 9) {
        return CubeVerification.colorDuplicated;
      }
    }

    List cornerCount = List.filled(cornerLength, 0);
    for (var corner in cornerState) {
      cornerCount[corner.permutation.index] += 1;
    }
    for (var i = 0; i < cornerLength; i++) {
      if (cornerCount[i] != 1) {
        return CubeVerification.cornerDuplicated;
      }
    }

    List edgeCount = List.filled(edgeLength, 0);
    for (var edge in edgeState) {
      edgeCount[edge.permutation.index] += 1;
    }
    for (var i = 0; i < edgeLength; i++) {
      if (edgeCount[i] != 1) {
        return CubeVerification.edgeDuplicated;
      }
    }

    int flipCount = 0;
    for (var edge in edgeState) {
      flipCount += edge.orientation;
    }
    if (flipCount % 2 != 0) {
      return CubeVerification.flipError;
    }

    int twistCount = 0;
    for (var corner in cornerState) {
      twistCount += corner.orientation;
    }
    if (twistCount % 3 != 0) {
      return CubeVerification.twistError;
    }

    if (edgeParity != cornerParity) {
      return CubeVerification.parityError;
    }

    return CubeVerification.solvable;
  }

  // ==========================
  // Phase 1 coordinates
  // ==========================

  /// Encode the twist of the corner into a int
  int get twist {
    return cornerState
        .sublist(0, cornerLength - 1)
        .map((e) => e.orientation)
        .reduce((value, element) => 3 * value + element);
  }

  /// Decode the twist of the corner from a int
  set twist(int value) {
    assert(0 <= value && value < pow(3, cornerLength - 1));

    int total = 0;
    for (var i = 0; i < cornerLength - 1; i++) {
      int x = value % 3;
      cornerState[cornerLength - 2 - i].orientation = x;
      total += x;
      value ~/= 3;
    }
    cornerState[cornerLength - 1].orientation = (-total) % 3;
  }

  /// Encode the flip of the edge into a int
  int get flip {
    return edgeState
        .sublist(0, edgeLength - 1)
        .map((e) => e.orientation)
        .reduce((value, element) => 2 * value + element);
  }

  /// Decode the flip of the edge from a int
  set flip(int value) {
    assert(0 <= value && value < pow(2, edgeLength - 1));

    int total = 0;
    for (var i = 0; i < edgeLength - 1; i++) {
      int x = value % 2;
      edgeState[edgeLength - 2 - i].orientation = x;
      total += x;
      value ~/= 2;
    }
    edgeState[edgeLength - 1].orientation = (-total) % 2;
  }

  /// Calculate binomial coefficient [Combination(n, k)]
  int _choose(int n, int k) {
    if (n < k || k < 0) {
      return 0;
    }

    if (k > n ~/ 2) {
      k = n - k;
    }

    int s = 1;
    int i = n;
    int j = 1;
    while (i != n - k) {
      s *= i;
      s ~/= j;
      i--;
      j++;
    }

    return s;
  }

  /// Encode the center layer edge position into a int
  ///
  /// Since there are 12 possible positions and we care only about those 4 edges, udslice takes values in the range 0, ..., 12C4 - 1
  ///
  /// If they are in the middle layer, udslice will have the value 0
  int get udslice {
    int udslice = 0;
    int seen = 0;

    for (var i = 0; i < edgeLength; i++) {
      if (8 <= edgeState[i].permutation.index && edgeState[i].permutation.index < 12) {
        seen++;
      } else if (seen >= 1) {
        udslice += _choose(i, seen - 1);
      }
    }

    return udslice;
  }

  /// Decode the edge of the center layer from a int
  ///
  /// Each of the values 0, ..., 12C4 - 1 determines a distinct set of 4 positions for the edges FR, FL, BL, BR to occupy
  ///
  /// Note that it does not determine the order of these edges
  set udslice(int value) {
    assert(0 <= value && value < 12 * _choose(12, 4));

    final udsliceEdge = [EEdge.frontRight, EEdge.frontLeft, EEdge.backLeft, EEdge.backRight];
    final otherEdge = [
      EEdge.upRight,
      EEdge.upFront,
      EEdge.upLeft,
      EEdge.upBack,
      EEdge.downRight,
      EEdge.downFront,
      EEdge.downLeft,
      EEdge.downBack,
    ];

    List<EEdge?> newPermutation = List.filled(edgeLength, null);

    // put the slice edges
    int seen = 3;
    for (var i = edgeLength - 1; i >= 0; i--) {
      final choose = _choose(i, seen);
      if (value - choose < 0) {
        newPermutation[i] = udsliceEdge[seen];
        seen--;
      } else {
        value -= choose;
      }
    }

    // put the remaining edges
    int x = 0;
    for (var i = 0; i < edgeLength; i++) {
      if (newPermutation[i] == null) {
        newPermutation[i] = otherEdge[x];
        x++;
      }
    }

    // set new permutation
    for (var i = 0; i < edgeLength; i++) {
      edgeState[i].permutation = newPermutation[i]!;
    }
  }

  // ==========================
  // Phase 2 coordinates
  // ==========================

  /// Encode the order of the 4 edges in the middle slice (FR, FL, BL, FR)
  ///
  /// This assumes that the cube is in phase 2 position, so in particular the 4 edges are correctly placed,
  /// just perhaps not correctly ordered, edge4 takes values in the range 0, ..., 4! - 1 = 23
  int get edge4 {
    int ret = 0;

    for (var i = 3; i > 0; i--) {
      int s = 0;
      for (var j = 0; j < i; j++) {
        if (edgeState[j + 8].permutation.index > edgeState[i + 8].permutation.index) {
          s++;
        }
      }
      ret = i * (ret + s);
    }

    return ret;
  }

  /// Decode the order of the 4 edges in the middle slice (FR, FL, BL, FR)
  ///
  /// 0 <= [value] < 4!
  set edge4(int value) {
    assert(0 <= value && value < 24); // 4! = 24

    final slideEdge = [EEdge.frontRight, EEdge.frontLeft, EEdge.backLeft, EEdge.backRight];

    final coefficients = List.filled(3, 0);
    for (var i = 1; i < 4; i++) {
      coefficients[i - 1] = value % (i + 1);
      value ~/= i + 1;
    }

    final permutations = List<EEdge?>.filled(4, null);
    for (var i = 2; i >= 0; i--) {
      permutations[i + 1] = slideEdge.removeAt(i + 1 - coefficients[i]);
    }
    permutations[0] = slideEdge[0];

    permutations.asMap().forEach(
      (index, edge) => edgeState[index + 8] = CEdge(edge!, edgeState[index + 8].orientation),
    );
  }

  /// Encode the permutation of the 8 edges in the top and bottom slices (UR, UF, UL, UB, DR, DF, DL, DB)
  ///
  /// In phase 2 these edges will all be in the U and D slices
  ///
  /// There are 8 possible positions for the 8 edges, so edge8 takes values in the range 0, ..., 8! - 1
  int get edge8 {
    var ret = 0;

    for (var i = 7; i > 0; i--) {
      int s = 0;
      for (var j = 0; j < i; j++) {
        if (edgeState[j].permutation.index > edgeState[i].permutation.index) {
          s++;
        }
      }
      ret = i * (ret + s);
    }

    return ret;
  }

  int _factorial(int k) {
    // TODO: Faster algorithm
    if (k < 0) {
      throw ArgumentError.value(k);
    }

    if (k == 0) {
      return 1;
    }

    var result = k;
    k--;
    while (k > 1) {
      result *= k;
      k--;
    }

    return result;
  }

  /// Decode the permutation of the 8 edges in the top and bottom slices (UR, UF, UL, UB, DR, DF, DL, DB)
  ///
  /// 0 <= [value] < 8!
  set edge8(int value) {
    assert(0 <= value && value < _factorial(8));

    final edges = EEdge.values.sublist(0, 8);

    final coefficients = List.filled(7, 0);
    for (var i = 1; i < 8; i++) {
      coefficients[i - 1] = value % (i + 1);
      value ~/= i + 1;
    }

    final permutations = List<EEdge?>.filled(8, null);
    for (var i = 6; i >= 0; i--) {
      permutations[i + 1] = edges.removeAt(i + 1 - coefficients[i]);
    }
    permutations[0] = edges[0];

    permutations.asMap().forEach(
      (index, edge) => edgeState[index] = CEdge(edge!, edgeState[index].orientation),
    );
  }

  /// Encode the permutation of the 8 corners
  ///
  /// There are 8 possible positions for the 8 corners, so corner takes values in the range 0, ..., 8! - 1
  int get corner {
    int ret = 0;
    for (var i = cornerLength - 1; i > 0; i--) {
      int s = 0;
      for (var j = 0; j < i; j++) {
        if (cornerState[j].permutation.index > cornerState[i].permutation.index) {
          s++;
        }
      }
      ret = i * (ret + s);
    }

    return ret;
  }

  /// Decode the permutation of the 8 corners
  ///
  /// 0 <= [value] < 8!
  set corner(int value) {
    assert(0 <= value && value < _factorial(cornerLength));

    final corners = List.from(ECorner.values);

    final coefficients = List.filled(cornerLength - 1, 0);
    for (var i = 1; i < cornerLength; i++) {
      coefficients[i - 1] = value % (i + 1);
      value ~/= i + 1;
    }

    final permutations = List<ECorner?>.filled(cornerLength, null);
    for (var i = cornerLength - 2; i >= 0; i--) {
      permutations[i + 1] = corners.removeAt(i + 1 - coefficients[i]);
    }
    permutations[0] = corners[0];

    permutations.asMap().forEach(
      (index, corner) => cornerState[index] = CCorner(corner!, cornerState[index].orientation),
    );
  }

  // ==========================
  // Misc. coordinates
  // ==========================

  /// Encode the permutation of the 12 edges
  ///
  /// There are 12 possible positions for the 12 corners, so corner takes values in the range 0, ..., 12! - 1
  int get edge {
    int ret = 0;
    for (var i = edgeLength - 1; i > 0; i--) {
      int s = 0;
      for (var j = 0; j < i; j++) {
        if (edgeState[j].permutation.index > edgeState[i].permutation.index) {
          s++;
        }
      }
      ret = i * (ret + s);
    }

    return ret;
  }

  /// Decode the permutation of the 12 edges
  ///
  /// 0 <= [value] < 12!
  set edge(int value) {
    assert(0 <= value && value < _factorial(edgeLength));

    final edges = List.from(EEdge.values);

    final coefficients = List.filled(edgeLength - 1, 0);
    for (var i = 1; i < edgeLength; i++) {
      coefficients[i - 1] = value % (i + 1);
      value ~/= i + 1;
    }

    final permutations = List<EEdge?>.filled(edgeLength, null);
    for (var i = edgeLength - 2; i >= 0; i--) {
      permutations[i + 1] = edges.removeAt(i + 1 - coefficients[i]);
    }
    permutations[0] = edges[0];

    permutations.asMap().forEach(
      (index, edge) => edgeState[index] = CEdge(edge!, edgeState[index].orientation),
    );
  }
}
