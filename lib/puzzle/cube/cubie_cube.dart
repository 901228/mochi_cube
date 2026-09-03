import "dart:math";

import "enums.dart";

enum CubeVerificationStatus {
  solvable,

  /// each color should appear exactly 9 times
  colorDuplicated,

  /// color is not valid
  colorCannotBeFound,

  /// not all 12 edges exist exactly once
  edgeDuplicated,

  /// not all 8 corners exist exactly once
  cornerDuplicated,

  /// one edge should be flipped
  flipError,

  /// one corner must be twisted
  twistError,

  /// two corners or edges have to be exchanged
  parityError,
}

class CubieCube {
  static const int cornerLength = 8;
  static List<int> get defaultCornerState => [0, 1, 2, 3, 4, 5, 6, 7];
  final List<int> cornerState;

  static const int edgeLength = 12;
  static List<int> get defaultEdgeState => [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22];
  final List<int> edgeState;

  CubieCube({List<int>? cornerState, List<int>? edgeState})
    : assert(cornerState == null || cornerState.length == cornerLength),
      assert(edgeState == null || edgeState.length == edgeLength),
      cornerState = cornerState ?? defaultCornerState,
      edgeState = edgeState ?? defaultEdgeState;

  /// Build a cube from its four raw coordinates.
  ///
  /// [eperm] is the permutation index of all 12 edges (`[0, 12!)`), not the
  /// 8-edge phase 2 coordinate that [CoordinatesExtension.eperm] returns.
  ///
  /// The order matters: the permutation setters preserve the orientation bits
  /// and the orientation setters preserve the permutation bits, so permutations
  /// have to be written first.
  CubieCube.fromCoordinates({int cperm = 0, int twist = 0, int eperm = 0, int flip = 0})
    : cornerState = defaultCornerState,
      edgeState = defaultEdgeState {
    // `this.` is required: the bare names resolve to the constructor
    // parameters, not to the coordinate setters.
    this.cperm = cperm;
    this.twist = twist;
    eperm12 = eperm;
    this.flip = flip;
  }

  CubieCube.fromFacelets(List<int> f)
    : assert(f.length == 54),
      cornerState = List.filled(cornerLength, 0),
      edgeState = List.filled(edgeLength, 0) {
    int ori, col1, col2;
    for (int i = 0; i < 8; i++) {
      // get the colors of the cubie at corner i, starting with U/D
      for (ori = 0; ori < 3; ori++) {
        if (f[cornerFacelet[i][ori].index] == Face.up.index ||
            f[cornerFacelet[i][ori].index] == Face.down.index) {
          break;
        }
      }
      col1 = f[cornerFacelet[i][(ori + 1) % 3].index];
      col2 = f[cornerFacelet[i][(ori + 2) % 3].index];

      for (int j = 0; j < 8; j++) {
        if (col1 == cornerFacelet[j][1].index ~/ 9 && col2 == cornerFacelet[j][2].index ~/ 9) {
          // in cornerposition i we have cornercubie j
          cornerState[i] = (ori % 3 << 3 | j);
          break;
        }
      }
    }
    for (int i = 0; i < 12; i++) {
      for (int j = 0; j < 12; j++) {
        if (f[edgeFacelet[i][0].index] == edgeFacelet[j][0].index ~/ 9 &&
            f[edgeFacelet[i][1].index] == edgeFacelet[j][1].index ~/ 9) {
          edgeState[i] = (j << 1);
          break;
        }
        if (f[edgeFacelet[i][0].index] == edgeFacelet[j][1].index ~/ 9 &&
            f[edgeFacelet[i][1].index] == edgeFacelet[j][0].index ~/ 9) {
          edgeState[i] = (j << 1 | 1);
          break;
        }
      }
    }
  }

  /// A cube drawn evenly from all 43252003274489856000 solvable states.
  ///
  /// Every state is equally likely, which is what a scramble is supposed to
  /// mean. Picking random *moves* instead does not give this: short sequences
  /// leave the cube near solved, and even long ones favour some states.
  ///
  /// The two permutations must have the same parity — a single swap is not
  /// reachable — so the corner permutation is drawn again until it matches the
  /// edges. That rejects half the draws and is the simplest way to stay even.
  ///
  /// [random] defaults to [Random.secure]; pass a seeded [Random] to reproduce
  /// a cube.
  factory CubieCube.random({Random? random}) {
    final rng = random ?? Random.secure();
    final cube = CubieCube();

    // Permutations first: the orientation setters keep the permutation bits,
    // but not the other way round.
    cube.eperm12 = rng.nextInt(_factorial(edgeLength)); // 12!
    final parity = cube.edgeParityBit;
    do {
      cube.cperm = rng.nextInt(_factorial(cornerLength)); // 8!
    } while (cube.cornerParityBit != parity);

    cube.twist = rng.nextInt(2187); // 3^7
    cube.flip = rng.nextInt(2048); // 2^11

    return cube;
  }

  static int _factorial(int n) {
    var result = 1;
    for (var i = 2; i <= n; i++) {
      result *= i;
    }
    return result;
  }

  /// Parse a 54 character facelet string, as [toFaceletString] writes it.
  ///
  /// The centres name the colours, so any six distinct letters will do.
  ///
  /// Throws [FormatException] if the string is the wrong length or does not use
  /// six colours nine times each. A string that describes a cube which cannot
  /// be solved is accepted here — use [verify] for that.
  factory CubieCube.fromFaceletString(String facelets) {
    final cleaned = facelets.replaceAll(RegExp(r"\s"), "");
    if (cleaned.length != Facelet.values.length) {
      throw FormatException("Expected ${Facelet.values.length} facelets, got ${cleaned.length}");
    }

    final centres = [for (var face = 0; face < 6; face++) cleaned[face * 9 + 4]];
    if (centres.toSet().length != 6) {
      throw FormatException("The six centres must be six different colours: $centres");
    }

    final counts = List.filled(6, 0);
    final colours = List.filled(Facelet.values.length, 0);
    for (var i = 0; i < cleaned.length; i++) {
      final face = centres.indexOf(cleaned[i]);
      if (face < 0) {
        throw FormatException("Facelet $i is '${cleaned[i]}', which is not one of $centres");
      }
      colours[i] = face;
      counts[face]++;
    }
    if (counts.any((c) => c != 9)) {
      throw FormatException("Each colour must appear nine times, got $counts");
    }

    return CubieCube.fromFacelets(colours);
  }

  CubieCube.from(CubieCube c)
    : cornerState = List.generate(cornerLength, (i) => c.cornerState[i]),
      edgeState = List.generate(edgeLength, (i) => c.edgeState[i]);

  CubieCube inverse() {
    final CubieCube cube = CubieCube();
    for (int corn = 0; corn < cornerLength; corn++) {
      cube.cornerState[cornerState[corn] & 0x7] = (corn | 0x20 >> (cornerState[corn] >> 3) & 0x18);
    }
    for (int edge = 0; edge < edgeLength; edge++) {
      cube.edgeState[edgeState[edge] >> 1] = (edge << 1 | edgeState[edge] & 1);
    }
    return cube;
  }

  /// Corner part of `this * b`, written into a new cube.
  ///
  /// Permutation composes as `prod.perm[i] = this.perm[b.perm[i]]`.
  ///
  /// Orientation is an element of Z3 plus a mirror flag: values `0..2` are
  /// plain twists, values `3..5` are a mirror plus twist `ori - 3`. A mirrored
  /// piece negates the twist it is composed with, which is why the second term
  /// is `6 - oriB` on that branch, and the result is mirrored exactly when
  /// exactly one of the two operands is. Only the 16 symmetry cubes use the
  /// mirrored range; for ordinary cubes this reduces to `(oriA + oriB) % 3`.
  void cornerMultiply(CubieCube b) {
    final result = List.filled(cornerLength, 0);
    for (int corn = 0; corn < cornerLength; corn++) {
      final a = cornerState[b.cornerState[corn] & 0x7];
      final oriA = a >> 3;
      final oriB = b.cornerState[corn] >> 3;
      int ori = oriA + (oriA < 3 ? oriB : 6 - oriB);
      ori = ori % 3 + ((oriA < 3) == (oriB < 3) ? 0 : 3);
      result[corn] = (a & 0x7) | (ori << 3);
    }
    cornerState.setAll(0, result);
  }

  /// Edge part of `this * b`, written into a new cube.
  ///
  /// The low bit is the flip, so composing permutation and orientation at once
  /// is a lookup plus an xor.
  void edgeMultiply(CubieCube b) {
    final result = List.filled(edgeLength, 0);
    for (int ed = 0; ed < edgeLength; ed++) {
      result[ed] = edgeState[b.edgeState[ed] >> 1] ^ (b.edgeState[ed] & 1);
    }
    edgeState.setAll(0, result);
  }

  /// Apply the permutation represented by [b] to this cube.
  void multiply(CubieCube b) {
    cornerMultiply(b);
    edgeMultiply(b);
  }

  /// This cube as JSON.
  ///
  /// The facelet string is the wire format rather than the internal bit-packed
  /// arrays: it is the same 54 characters the solver takes, it is readable, and
  /// it does not tie a stored cube to how the state happens to be packed today.
  Map<String, dynamic> toJson() => {"facelets": toFaceletString()};

  /// Rebuild a cube from [toJson].
  ///
  /// Throws [FormatException] if the JSON does not hold a 54 character facelet
  /// string, and [ArgumentError] if that string is not a cube.
  factory CubieCube.fromJson(Map<String, dynamic> json) {
    final facelets = json["facelets"];
    if (facelets is! String) {
      throw FormatException("Expected a \"facelets\" string, got ${json["facelets"]}");
    }
    return CubieCube.fromFaceletString(facelets);
  }

  /// The 54 stickers of this cube, as face indices.
  ///
  /// The inverse of [CubieCube.fromFacelets]. A piece twisted by `ori` shows
  /// its colours `ori` positions round from where an untwisted one would, which
  /// is the shift in the sticker index.
  List<int> toFacelets() {
    final facelets = List.filled(Facelet.values.length, 0);

    // The centres name the colours and never move.
    for (var face = 0; face < Face.values.length; face++) {
      facelets[face * 9 + 4] = face;
    }

    for (var i = 0; i < cornerLength; i++) {
      final piece = cornerState[i] & 0x7;
      final ori = (cornerState[i] >> 3) % 3;
      for (var k = 0; k < 3; k++) {
        facelets[cornerFacelet[i][(k + ori) % 3].index] = cornerFace[piece][k].index;
      }
    }

    for (var i = 0; i < edgeLength; i++) {
      final piece = edgeState[i] >> 1;
      final ori = edgeState[i] & 1;
      for (var k = 0; k < 2; k++) {
        facelets[edgeFacelet[i][(k + ori) % 2].index] = edgeFace[piece][k].index;
      }
    }

    return facelets;
  }

  /// The 54 stickers as a string of face letters, the form [Search.solution]
  /// takes.
  String toFaceletString() =>
      toFacelets().map((f) => FaceExtension.faceToString[f]).join();

  /// Check a cubiecube for solvability
  ///
  /// Return the error code [CubeVerificationStatus]
  CubeVerificationStatus verify() {
    int sum = 0;
    int edgeMask = 0;
    for (int e = 0; e < edgeLength; e++) {
      edgeMask |= 1 << (edgeState[e] >> 1);
      sum ^= edgeState[e] & 1;
    }

    if (edgeMask != 0xfff) {
      return CubeVerificationStatus.edgeDuplicated; // missing edges
    }
    if (sum != 0) {
      return CubeVerificationStatus.flipError;
    }

    int cornMask = 0;
    sum = 0;

    for (int c = 0; c < 8; c++) {
      cornMask |= 1 << (cornerState[c] & 7);
      sum += cornerState[c] >> 3;
    }

    if (cornMask != 0xff) {
      return CubeVerificationStatus.cornerDuplicated; // missing corners
    }

    if (sum % 3 != 0) {
      return CubeVerificationStatus.twistError; // twisted corner
    }

    if ((edgeParityBit ^ cornerParityBit) != 0) {
      return CubeVerificationStatus.parityError; // parity error
    }

    return CubeVerificationStatus.solvable; // cube ok
  }
}

extension CoordinatesExtension on CubieCube {
  static int _getNParity(int idx, int n) {
    int p = 0;
    for (int i = n - 2; i >= 0; i--) {
      p ^= idx % (n - i);
      idx ~/= (n - i);
    }
    return p & 1;
  }

  // ============================================================
  // ========================== Parity ==========================
  // ============================================================
  int get edgeParityBit => _getNParity(_getNPerm(edgeState, 12, true), 12);
  int get cornerParityBit => _getNParity(cperm, 8);

  // XSym : Symmetry Coordnate of X. MUST be called after initialization of ClassIndexToRepresentantArrays.

  // ============================================================
  // ==================== Phase 1 Coordnates ====================
  // ============================================================

  /// Flip : Orientation of 12 Edges. Raw[0, 2048) Sym[0, 336 * 8)
  int get flip {
    int idx = 0;
    for (int i = 0; i < CubieCube.edgeLength - 1; i++) {
      idx = (idx << 1) | (edgeState[i] & 1);
    }
    return idx;
  }

  set flip(int idx) {
    int parity = 0;
    for (int i = CubieCube.edgeLength - 2; i >= 0; i--) {
      int val = idx & 1;
      parity ^= val;
      edgeState[i] = (edgeState[i] & 0xfe) | val;
      idx >>= 1;
    }
    edgeState[CubieCube.edgeLength - 1] = (edgeState[CubieCube.edgeLength - 1] & 0xfe) | parity;
  }

  // TODO: getFlipSym
  // 	int getFlipSym() {
  // 		return FlipR2S[getFlip()];
  // 	}

  /// Twist : Orientation of 8 Corners. Raw[0, 2187) Sym[0, 324 * 8)
  int get twist {
    int idx = 0;
    for (int i = 0; i < CubieCube.cornerLength - 1; i++) {
      idx += (idx << 1) + (cornerState[i] >> 3);
    }
    return idx;
  }

  set twist(int idx) {
    int twst = 15; // (CubieCube.cornerLength - 1) * 2 + 1 => 7 * 2 + 1 = 15
    for (int i = CubieCube.cornerLength - 2; i >= 0; i--) {
      int val = idx % 3;
      twst -= val;
      cornerState[i] = (cornerState[i] & 0x7 | val << 3);
      idx ~/= 3;
    }
    cornerState[CubieCube.cornerLength - 1] =
        (cornerState[CubieCube.cornerLength - 1] & 0x7 | (twst % 3) << 3);
  }

  // TODO: getTwistSym
  // 	int getTwistSym() {
  // 		return TwistR2S[getTwist()];
  // 	}

  static final List<List<int>> _cnk = initCnk();
  static List<List<int>> initCnk() {
    final cnk = List.generate(13, (_) => List.filled(13, 0));
    for (int i = 0; i < 13; i++) {
      cnk[i][0] = cnk[i][i] = 1;
      for (int j = 1; j < i; j++) {
        cnk[i][j] = cnk[i - 1][j - 1] + cnk[i - 1][j];
      }
    }
    return cnk;
  }

  static int _getVal(int val0, bool isEdge) {
    return isEdge ? val0 >> 1 : val0 & 7;
  }

  static int _setVal(int val0, int val, bool isEdge) {
    return (isEdge ? (val << 1 | val0 & 1) : (val | val0 & 0xf8));
  }

  static int _getComb(List<int> arr, int mask, bool isEdge) {
    int end = arr.length - 1;
    int idxC = 0, r = 4;
    for (int i = end; i >= 0; i--) {
      int perm = _getVal(arr[i], isEdge);
      if ((perm & 0xc) == mask) {
        idxC += _cnk[i][r--];
      }
    }
    return idxC;
  }

  static void _setComb(List<int> arr, int idxC, int mask, bool isEdge) {
    int end = arr.length - 1;
    int r = 4, fill = end;
    for (int i = end; i >= 0; i--) {
      if (idxC >= _cnk[i][r]) {
        idxC -= _cnk[i][r--];
        arr[i] = _setVal(arr[i], r | mask, isEdge);
      } else {
        if ((fill & 0xc) == mask) {
          fill -= 4;
        }
        arr[i] = _setVal(arr[i], fill--, isEdge);
      }
    }
  }

  /// UDSlice : Positions of the 4 UDSlice edges, the order is ignored. [0, 495)
  int get udslice => 494 - _getComb(edgeState, 8, true);
  set udslice(int idx) => _setComb(edgeState, 494 - idx, 8, true);

  // ============================================================
  // ==================== Phase 2 Coordnates ====================
  // ============================================================

  static int _getNPerm(List<int> arr, int n, bool isEdge) {
    int idx = 0;
    int val = 0xFEDCBA9876543210;
    for (int i = 0; i < n - 1; i++) {
      int v = _getVal(arr[i], isEdge) << 2;
      idx = (n - i) * idx + (val >> v & 0xf);
      val -= 0x1111111111111110 << v;
    }
    return idx;
  }

  static void _setNPerm(List<int> arr, int idx, int n, bool isEdge) {
    int val = 0xFEDCBA9876543210;
    int extract = 0;
    for (int p = 2; p <= n; p++) {
      extract = extract << 4 | idx % p;
      idx ~/= p;
    }
    for (int i = 0; i < n - 1; i++) {
      int v = (extract & 0xf) << 2;
      extract >>= 4;
      arr[i] = _setVal(arr[i], (val >> v & 0xf), isEdge);
      int m = (1 << v) - 1;
      val = val & m | val >> 4 & ~m;
    }
    arr[n - 1] = _setVal(arr[n - 1], (val & 0xf), isEdge);
  }

  /// Cperm : Permutations of 8 Corners. Raw[0, 40320) Sym[0, 2187 * 16)
  int get cperm => _getNPerm(cornerState, 8, false);
  set cperm(int idx) => _setNPerm(cornerState, idx, 8, false);

  // TODO: getCPermSym
  // 	int getCPermSym() {
  // 		return ESym2CSym(EPermR2S[getCPerm()]);
  // 	}

  /// EPerm : Permutations of 8 UD Edges. Raw[0, 40320) Sym[0, 2187 * 16)
  int get eperm => _getNPerm(edgeState, 8, true);
  set eperm(int idx) => _setNPerm(edgeState, idx, 8, true);

  // TODO: getEPermSym
  // 	int getEPermSym() {
  // 		return EPermR2S[getEPerm()];
  // 	}

  /// MPerm : Permutations of 4 UDSlice Edges. [0, 24)
  int get mperm => _getNPerm(edgeState, 12, true) % 24;
  set mperm(int idx) => _setNPerm(edgeState, idx, 12, true);

  /// Permutation of all 12 edges. Raw[0, 12!)
  ///
  /// Used to describe move and symmetry cubes, which are not restricted to the
  /// phase 2 subgroup that [eperm] and [mperm] assume.
  int get eperm12 => _getNPerm(edgeState, 12, true);
  set eperm12(int idx) => _setNPerm(edgeState, idx, 12, true);

  int get ccombo => _getComb(cornerState, 0, false);
  set ccombo(int idx) => _setComb(cornerState, idx, 0, false);
}

// public class CubieCube {

// 	/**
// 	 * 16 symmetries generated by S_F2, S_U4 and S_LR2
// 	 */
// 	static CubieCube[] CubeSym = new CubieCube[16];

// 	/**
// 	 * 18 move cubes
// 	 */
// 	static CubieCube[] moveCube = new CubieCube[18];

// 	static long[] moveCubeSym = new long[18];
// 	static int[] firstMoveSym = new int[48];

// 	static int[][] SymMult = new int[16][16];
// 	static int[][] SymMultInv = new int[16][16];
// 	static int[][] SymMove = new int[16][18];
// 	static int[] Sym8Move = new int[8 * 18];
// 	static int[][] SymMoveUD = new int[16][18];

// 	/**
// 	 * ClassIndexToRepresentantArrays
// 	 */
// 	static char[] FlipS2R = new char[CoordCube.N_FLIP_SYM];
// 	static char[] TwistS2R = new char[CoordCube.N_TWIST_SYM];
// 	static char[] EPermS2R = new char[CoordCube.N_PERM_SYM];
// 	static byte[] Perm2CombP = new byte[CoordCube.N_PERM_SYM];
// 	static char[] PermInvEdgeSym = new char[CoordCube.N_PERM_SYM];
// 	static byte[] MPermInv = new byte[CoordCube.N_MPERM];

// 	/**
// 	 * Notice that Edge Perm Coordnate and Corner Perm Coordnate are the same symmetry structure.
// 	 * So their ClassIndexToRepresentantArray are the same.
// 	 * And when x is RawEdgePermCoordnate, y*16+k is SymEdgePermCoordnate, y*16+(k^e2c[k]) will
// 	 * be the SymCornerPermCoordnate of the State whose RawCornerPermCoordnate is x.
// 	 */
// 	// static byte[] e2c = {0, 0, 0, 0, 1, 3, 1, 3, 1, 3, 1, 3, 0, 0, 0, 0};
// 	static final int SYM_E2C_MAGIC = 0x00DDDD00;
// 	static int ESym2CSym(int idx) {
// 		return idx ^ (SYM_E2C_MAGIC >> ((idx & 0xf) << 1) & 3);
// 	}

// 	/**
// 	 * Raw-Coordnate to Sym-Coordnate, only for speeding up initializaion.
// 	 */
// 	static char[] FlipR2S = new char[CoordCube.N_FLIP];
// 	static char[] TwistR2S = new char[CoordCube.N_TWIST];
// 	static char[] EPermR2S = new char[CoordCube.N_PERM];
// 	static char[] FlipS2RF = Search.USE_TWIST_FLIP_PRUN ? new char[CoordCube.N_FLIP_SYM * 8] : null;

// 	/**
// 	 *
// 	 */
// 	static char[] SymStateTwist;// = new char[CoordCube.N_TWIST_SYM];
// 	static char[] SymStateFlip;// = new char[CoordCube.N_FLIP_SYM];
// 	static char[] SymStatePerm;// = new char[CoordCube.N_PERM_SYM];

// 	static CubieCube urf1 = new CubieCube(2531, 1373, 67026819, 1367);
// 	static CubieCube urf2 = new CubieCube(2089, 1906, 322752913, 2040);
// 	static byte[][] urfMove = new byte[][] {
// 		{0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17},
// 		{6, 7, 8, 0, 1, 2, 3, 4, 5, 15, 16, 17, 9, 10, 11, 12, 13, 14},
// 		{3, 4, 5, 6, 7, 8, 0, 1, 2, 12, 13, 14, 15, 16, 17, 9, 10, 11},
// 		{2, 1, 0, 5, 4, 3, 8, 7, 6, 11, 10, 9, 14, 13, 12, 17, 16, 15},
// 		{8, 7, 6, 2, 1, 0, 5, 4, 3, 17, 16, 15, 11, 10, 9, 14, 13, 12},
// 		{5, 4, 3, 8, 7, 6, 2, 1, 0, 14, 13, 12, 17, 16, 15, 11, 10, 9}
// 	};

// 	/**
// 	 * prod = a * b, Corner Only.
// 	 */
// 	static void CornMult(CubieCube a, CubieCube b, CubieCube prod) {
// 		for (int corn = 0; corn < 8; corn++) {
// 			int oriA = a.ca[b.ca[corn] & 7] >> 3;
// 			int oriB = b.ca[corn] >> 3;
// 			prod.ca[corn] = (byte) (a.ca[b.ca[corn] & 7] & 7 | (oriA + oriB) % 3 << 3);
// 		}
// 	}

// 	/**
// 	 * prod = a * b, Corner Only. With mirrored cases considered
// 	 */
// 	static void CornMultFull(CubieCube a, CubieCube b, CubieCube prod) {
// 		for (int corn = 0; corn < 8; corn++) {
// 			int oriA = a.ca[b.ca[corn] & 7] >> 3;
// 			int oriB = b.ca[corn] >> 3;
// 			int ori = oriA + ((oriA < 3) ? oriB : 6 - oriB);
// 			ori = ori % 3 + ((oriA < 3) == (oriB < 3) ? 0 : 3);
// 			prod.ca[corn] = (byte) (a.ca[b.ca[corn] & 7] & 7 | ori << 3);
// 		}
// 	}

// 	/**
// 	 * prod = a * b, Edge Only.
// 	 */
// 	static void EdgeMult(CubieCube a, CubieCube b, CubieCube prod) {
// 		for (int ed = 0; ed < 12; ed++) {
// 			prod.ea[ed] = (byte) (a.ea[b.ea[ed] >> 1] ^ (b.ea[ed] & 1));
// 		}
// 	}

// 	/**
// 	 * b = S_idx^-1 * a * S_idx, Corner Only.
// 	 */
// 	static void CornConjugate(CubieCube a, int idx, CubieCube b) {
// 		CubieCube sinv = CubeSym[SymMultInv[0][idx]];
// 		CubieCube s = CubeSym[idx];
// 		for (int corn = 0; corn < 8; corn++) {
// 			int oriA = sinv.ca[a.ca[s.ca[corn] & 7] & 7] >> 3;
// 			int oriB = a.ca[s.ca[corn] & 7] >> 3;
// 			int ori = (oriA < 3) ? oriB : (3 - oriB) % 3;
// 			b.ca[corn] = (byte) (sinv.ca[a.ca[s.ca[corn] & 7] & 7] & 7 | ori << 3);
// 		}
// 	}

// 	/**
// 	 * b = S_idx^-1 * a * S_idx, Edge Only.
// 	 */
// 	static void EdgeConjugate(CubieCube a, int idx, CubieCube b) {
// 		CubieCube sinv = CubeSym[SymMultInv[0][idx]];
// 		CubieCube s = CubeSym[idx];
// 		for (int ed = 0; ed < 12; ed++) {
// 			b.ea[ed] = (byte) (sinv.ea[a.ea[s.ea[ed] >> 1] >> 1] ^ (a.ea[s.ea[ed] >> 1] & 1) ^ (s.ea[ed] & 1));
// 		}
// 	}

// 	static int getPermSymInv(int idx, int sym, boolean isCorner) {
// 		int idxi = PermInvEdgeSym[idx];
// 		if (isCorner) {
// 			idxi = ESym2CSym(idxi);
// 		}
// 		return idxi & 0xfff0 | SymMult[idxi & 0xf][sym];
// 	}

// 	static int getSkipMoves(long ssym) {
// 		int ret = 0;
// 		for (int i = 1; (ssym >>= 1) != 0; i++) {
// 			if ((ssym & 1) == 1) {
// 				ret |= firstMoveSym[i];
// 			}
// 		}
// 		return ret;
// 	}

// 	/**
// 	 * this = S_urf^-1 * this * S_urf.
// 	 */
// 	void URFConjugate() {
// 		if (temps == null) {
// 			temps = new CubieCube();
// 		}
// 		CornMult(urf2, this, temps);
// 		CornMult(temps, urf1, this);
// 		EdgeMult(urf2, this, temps);
// 		EdgeMult(temps, urf1, this);
// 	}

// 	long selfSymmetry() {
// 		CubieCube c = new CubieCube(this);
// 		CubieCube d = new CubieCube();
// 		long sym = 0L;
// 		for (int i = 0; i < 96; i++) {
// 			CornConjugate(c, SymMultInv[0][i % 16], d);
// 			if (Arrays.equals(d.ca, ca)) {
// 				EdgeConjugate(c, SymMultInv[0][i % 16], d);
// 				if (Arrays.equals(d.ea, ea)) {
// 					sym |= 1L << Math.min(i, 48);
// 				}
// 			}
// 			if (i % 16 == 15) {
// 				c.URFConjugate();
// 			}
// 			if (i % 48 == 47) {
// 				c.invCubieCube();
// 			}
// 		}
// 		return sym;
// 	}

// 	// ********************************************* Initialization functions *********************************************

// 	static void initMove() {
// 		moveCube[0] = new CubieCube(15120, 0, 119750400, 0);
// 		moveCube[3] = new CubieCube(21021, 1494, 323403417, 0);
// 		moveCube[6] = new CubieCube(8064, 1236, 29441808, 550);
// 		moveCube[9] = new CubieCube(9, 0, 5880, 0);
// 		moveCube[12] = new CubieCube(1230, 412, 2949660, 0);
// 		moveCube[15] = new CubieCube(224, 137, 328552, 137);
// 		for (int a = 0; a < 18; a += 3) {
// 			for (int p = 0; p < 2; p++) {
// 				moveCube[a + p + 1] = new CubieCube();
// 				EdgeMult(moveCube[a + p], moveCube[a], moveCube[a + p + 1]);
// 				CornMult(moveCube[a + p], moveCube[a], moveCube[a + p + 1]);
// 			}
// 		}
// 	}

// 	public String toString() {
// 		StringBuffer sb = new StringBuffer();
// 		for (int i = 0; i < 8; i++) {
// 			sb.append("|" + (ca[i] & 7) + " " + (ca[i] >> 3));
// 		}
// 		sb.append("\n");
// 		for (int i = 0; i < 12; i++) {
// 			sb.append("|" + (ea[i] >> 1) + " " + (ea[i] & 1));
// 		}
// 		return sb.toString();
// 	}

// 	static void initSym() {
// 		CubieCube c = new CubieCube();
// 		CubieCube d = new CubieCube();
// 		CubieCube t;

// 		CubieCube f2 = new CubieCube(28783, 0, 259268407, 0);
// 		CubieCube u4 = new CubieCube(15138, 0, 119765538, 7);
// 		CubieCube lr2 = new CubieCube(5167, 0, 83473207, 0);
// 		for (int i = 0; i < 8; i++) {
// 			lr2.ca[i] |= 3 << 3;
// 		}

// 		for (int i = 0; i < 16; i++) {
// 			CubeSym[i] = new CubieCube(c);
// 			CornMultFull(c, u4, d);
// 			EdgeMult(c, u4, d);
// 			t = d;  d = c;  c = t;
// 			if (i % 4 == 3) {
// 				CornMultFull(c, lr2, d);
// 				EdgeMult(c, lr2, d);
// 				t = d;  d = c;  c = t;
// 			}
// 			if (i % 8 == 7) {
// 				CornMultFull(c, f2, d);
// 				EdgeMult(c, f2, d);
// 				t = d;  d = c;  c = t;
// 			}
// 		}
// 		for (int i = 0; i < 16; i++) {
// 			for (int j = 0; j < 16; j++) {
// 				CornMultFull(CubeSym[i], CubeSym[j], c);
// 				for (int k = 0; k < 16; k++) {
// 					if (Arrays.equals(CubeSym[k].ca, c.ca)) {
// 						SymMult[i][j] = k; // SymMult[i][j] = (k ^ i ^ j ^ (0x14ab4 >> j & i << 1 & 2)));
// 						SymMultInv[k][j] = i; // i * j = k => k * j^-1 = i
// 						break;
// 					}
// 				}
// 			}
// 		}
// 		for (int j = 0; j < 18; j++) {
// 			for (int s = 0; s < 16; s++) {
// 				CornConjugate(moveCube[j], SymMultInv[0][s], c);
// 				for (int m = 0; m < 18; m++) {
// 					if (Arrays.equals(moveCube[m].ca, c.ca)) {
// 						SymMove[s][j] = m;
// 						SymMoveUD[s][Util.std2ud[j]] = Util.std2ud[m];
// 						break;
// 					}
// 				}
// 				if (s % 2 == 0) {
// 					Sym8Move[j << 3 | s >> 1] = SymMove[s][j];
// 				}
// 			}
// 		}

// 		for (int i = 0; i < 18; i++) {
// 			moveCubeSym[i] = moveCube[i].selfSymmetry();
// 			int j = i;
// 			for (int s = 0; s < 48; s++) {
// 				if (SymMove[s % 16][j] < i) {
// 					firstMoveSym[s] |= 1 << i;
// 				}
// 				if (s % 16 == 15) {
// 					j = urfMove[2][j];
// 				}
// 			}
// 		}
// 	}

// 	static int initSym2Raw(final int N_RAW, char[] Sym2Raw, char[] Raw2Sym, char[] SymState, int coord) {
// 		final int N_RAW_HALF = (N_RAW + 1) / 2;
// 		CubieCube c = new CubieCube();
// 		CubieCube d = new CubieCube();
// 		int count = 0, idx = 0;
// 		int sym_inc = coord >= 2 ? 1 : 2;
// 		boolean isEdge = coord != 1;

// 		for (int i = 0; i < N_RAW; i++) {
// 			if (Raw2Sym[i] != 0) {
// 				continue;
// 			}
// 			switch (coord) {
// 			case 0: c.setFlip(i); break;
// 			case 1: c.setTwist(i); break;
// 			case 2: c.setEPerm(i); break;
// 			}
// 			for (int s = 0; s < 16; s += sym_inc) {
// 				if (isEdge) {
// 					EdgeConjugate(c, s, d);
// 				} else {
// 					CornConjugate(c, s, d);
// 				}
// 				switch (coord) {
// 				case 0: idx = d.getFlip();
// 					break;
// 				case 1: idx = d.getTwist();
// 					break;
// 				case 2: idx = d.getEPerm();
// 					break;
// 				}
// 				if (coord == 0 && Search.USE_TWIST_FLIP_PRUN) {
// 					FlipS2RF[count << 3 | s >> 1] = (char) idx;
// 				}
// 				if (idx == i) {
// 					SymState[count] |= 1 << (s / sym_inc);
// 				}
// 				int symIdx = (count << 4 | s) / sym_inc;
// 				Raw2Sym[idx] = (char) symIdx;
// 			}
// 			Sym2Raw[count++] = (char) i;
// 		}
// 		return count;
// 	}

// 	static void initFlipSym2Raw() {
// 		initSym2Raw(CoordCube.N_FLIP, FlipS2R, FlipR2S,
// 		            SymStateFlip = new char[CoordCube.N_FLIP_SYM], 0);
// 	}

// 	static void initTwistSym2Raw() {
// 		initSym2Raw(CoordCube.N_TWIST, TwistS2R, TwistR2S,
// 		            SymStateTwist = new char[CoordCube.N_TWIST_SYM], 1);
// 	}

// 	static void initPermSym2Raw() {
// 		initSym2Raw(CoordCube.N_PERM, EPermS2R, EPermR2S,
// 		            SymStatePerm = new char[CoordCube.N_PERM_SYM], 2);
// 		CubieCube cc = new CubieCube();
// 		for (int i = 0; i < CoordCube.N_PERM_SYM; i++) {
// 			cc.setEPerm(EPermS2R[i]);
// 			Perm2CombP[i] = (byte) (Util.getComb(cc.ea, 0, true) + (Search.USE_COMBP_PRUN ? Util.getNParity(EPermS2R[i], 8) * 70 : 0));
// 			cc.invCubieCube();
// 			PermInvEdgeSym[i] = (char) cc.getEPermSym();
// 		}
// 		for (int i = 0; i < CoordCube.N_MPERM; i++) {
// 			cc.setMPerm(i);
// 			cc.invCubieCube();
// 			MPermInv[i] = (byte) cc.getMPerm();
// 		}
// 	}

// 	static {
// 		CubieCube.initMove();
// 		CubieCube.initSym();
// 	}
// }
