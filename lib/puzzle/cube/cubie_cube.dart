import "dart:math";
import "dart:typed_data";

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
  String toFaceletString() => toFacelets().map((f) => FaceExtension.faceToString[f]).join();

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

  // The symmetry-reduced form of each coordinate lives in cube/sym_coord.dart,
  // as twistSym, flipSym, cpermSym and epermSym.

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

  /// The values still to be placed, and the factorial digits that place them.
  ///
  /// min2phase keeps both in a single 64 bit register, four bits per entry, and
  /// that cannot be ported as it stands: on the web a Dart `int` is a double
  /// with 53 bits of mantissa, and the bitwise operators truncate to 32, so
  /// `0xFEDCBA9876543210` is neither representable nor shiftable. They are
  /// small lists here instead.
  ///
  /// Reused rather than allocated per call, because [cperm] and [eperm] are
  /// read once per node of the search. Static fields are per isolate and
  /// neither method calls anything that could re-enter, so sharing them is
  /// safe. The two must be different lists: [_setNPerm] uses both at once.
  static final Uint8List _values = Uint8List(16);
  static final Uint8List _digits = Uint8List(16);

  /// Which of the `n!` orderings [arr] holds, as a factorial number.
  static int _getNPerm(List<int> arr, int n, bool isEdge) {
    for (var i = 0; i < n; i++) {
      _values[i] = i;
    }

    var idx = 0;
    for (var i = 0; i < n - 1; i++) {
      final piece = _getVal(arr[i], isEdge);
      // How far down the values left over this one is.
      idx = (n - i) * idx + _values[piece];
      // Taking it out moves everything above it down a place.
      for (var above = piece + 1; above < n; above++) {
        _values[above]--;
      }
    }
    return idx;
  }

  /// Put [arr] into the ordering [idx] names.
  static void _setNPerm(List<int> arr, int idx, int n, bool isEdge) {
    for (var i = 0; i < n; i++) {
      _values[i] = i;
    }

    // The digits of idx in the factorial number system, largest radix first,
    // which is the order they are used in.
    var rest = idx;
    for (var radix = 2; radix <= n; radix++) {
      _digits[n - radix] = rest % radix;
      rest ~/= radix;
    }

    var left = n;
    for (var i = 0; i < n - 1; i++) {
      final digit = _digits[i];
      arr[i] = _setVal(arr[i], _values[digit], isEdge);
      for (var j = digit; j < left - 1; j++) {
        _values[j] = _values[j + 1];
      }
      left--;
    }
    arr[n - 1] = _setVal(arr[n - 1], _values[0], isEdge);
  }

  /// Cperm : Permutations of 8 Corners. Raw[0, 40320) Sym[0, 2187 * 16)
  int get cperm => _getNPerm(cornerState, 8, false);
  set cperm(int idx) => _setNPerm(cornerState, idx, 8, false);

  /// EPerm : Permutations of 8 UD Edges. Raw[0, 40320) Sym[0, 2187 * 16)
  int get eperm => _getNPerm(edgeState, 8, true);
  set eperm(int idx) => _setNPerm(edgeState, idx, 8, true);

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
