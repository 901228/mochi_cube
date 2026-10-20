import "dart:math";

import "util.dart";

/// The FTO as pieces, ported from Levi Gibson's fto3phase, which is what the
/// official scramble program solves it with.
///
/// Six corners, each either way round; twelve edges, which cannot flip; and
/// twenty-four triangles in two orbits of twelve, one for each half of the
/// faces — U, F, BR and BL, whose triangles never leave them, and R, L, B and D
/// likewise. Triangles of a colour are alike, so each orbit is a colour per
/// place rather than a permutation.
///
/// The packing functions number the parts of the state each phase of the
/// search looks at; see [FtoCoord].
class FtoCubie {
  final List<int> cornerPerm = [0, 1, 2, 3, 4, 5];
  final List<int> cornerOri = List.filled(6, 0);
  final List<int> edges = List.generate(12, (i) => i);
  final List<int> trianglesUFBrBl = List.generate(12, (i) => i ~/ 3);
  final List<int> trianglesRLBD = List.generate(12, (i) => i ~/ 3);

  FtoCubie();

  FtoCubie.from(FtoCubie other) {
    other.copyInto(this);
  }

  // The moves, as fto3phase numbers them: each face and then its inverse.
  static const int r = 0, rp = 1, l = 2, lp = 3, b = 4, bp = 5, u = 6, up = 7;
  static const int d = 8, dp = 9, f = 10, fp = 11, br = 12, brp = 13, bl = 14, blp = 15;

  /// What each move's name is, in fto3phase's order.
  static const List<String> moveNames = ["R", "L", "B", "U", "D", "F", "BR", "BL"];

  // Triangle colours: the faces of each orbit.
  static const int tou = 0, tof = 1, tobr = 2, tobl = 3;
  static const int tor = 0, tol = 1, tob = 2, tod = 3;

  // Edges, each named by the two faces it joins.
  static const int eub = 0, eur = 1, eul = 2, efl = 3, efr = 4, erbr = 5;
  static const int ebrb = 6, eblb = 7, elbl = 8, edf = 9, edbr = 10, edbl = 11;

  // Corners, each named by two of the faces round it.
  static const int cuf = 0, cubr = 1, cubl = 2, cdl = 3, cdr = 4, cdb = 5;

  /// Any state of the puzzle, each equally likely.
  static FtoCubie random(Random rng) {
    final fto = FtoCubie();
    fto.setAllEdges(rng.nextInt(FtoCoord.allEdgesSize));
    fto.setAllCornerOrientation(rng.nextInt(FtoCoord.allCornerOrientationSize));
    fto.setAllCornerPermutation(rng.nextInt(FtoCoord.allCornerPermutationSize));
    fto.setAllTriangles(rng.nextInt(FtoCoord.allTriangleSize), 0);
    fto.setAllTriangles(rng.nextInt(FtoCoord.allTriangleSize), 1);
    return fto;
  }

  void copyInto(FtoCubie c) {
    c.cornerPerm.setAll(0, cornerPerm);
    c.cornerOri.setAll(0, cornerOri);
    c.edges.setAll(0, edges);
    c.trianglesUFBrBl.setAll(0, trianglesUFBrBl);
    c.trianglesRLBD.setAll(0, trianglesRLBD);
  }

  void turn(int move) {
    final out = FtoCubie();
    turnInto(move, out);
    out.copyInto(this);
  }

  void turnInto(int move, FtoCubie out) {
    final cycles = _moveEffects[move];
    for (var i = 0; i < 6; i++) {
      out.cornerPerm[i] = cornerPerm[cycles.cp[i]];
      out.cornerOri[i] = cornerOri[cycles.cp[i]] ^ cycles.co[i];
    }
    for (var i = 0; i < 12; i++) {
      out.edges[i] = edges[cycles.ep[i]];
      out.trianglesUFBrBl[i] = trianglesUFBrBl[cycles.tpU[i]];
      out.trianglesRLBD[i] = trianglesRLBD[cycles.tpR[i]];
    }
  }

  void applyMovesInto(List<int> moves, FtoCubie out) {
    copyInto(out);
    for (final move in moves) {
      out.turn(move);
    }
  }

  // ------- Whole state -------

  int packAllEdges() => packPerm(edges, true);

  void setAllEdges(int idx) => unpackPerm(edges, idx, true);

  int packAllCornerPermutation() => packPerm(cornerPerm, true);

  void setAllCornerPermutation(int idx) => unpackPerm(cornerPerm, idx, true);

  int packAllCornerOrientation() {
    var index = 0;
    for (var i = 0; i < 5; i++) {
      index |= cornerOri[i] << i;
    }
    return index;
  }

  void setAllCornerOrientation(int idx) {
    var total = 0;
    for (var i = 0; i < 5; i++) {
      cornerOri[i] = (idx >> i) & 1;
      total += cornerOri[i];
    }
    cornerOri[5] = total % 2;
  }

  static final List<int> _allTrianglesCoefficients = [nCr(9, 3) * nCr(6, 3), nCr(6, 3), 1];

  int packAllTriangles(int orbit) {
    final triangles = orbit == 1 ? trianglesRLBD : trianglesUFBrBl;
    final used = List.filled(12, false);
    final loc = [for (var i = 0; i < 3; i++) List.filled(3, 0)];
    for (var xo = 0; xo < 3; xo++) {
      var found = 0;
      var passed = 0;
      for (var i = 0; i < 12; i++) {
        if (triangles[i] == xo) {
          loc[xo][found++] = passed;
          used[i] = true;
          passed++;
        } else if (!used[i]) {
          passed++;
        }
      }
      if (found != 3) throw StateError("Expected three triangles of colour $xo, found $found");
    }
    return packSubset(loc[0]) * _allTrianglesCoefficients[0] +
        packSubset(loc[1]) * _allTrianglesCoefficients[1] +
        packSubset(loc[2]) * _allTrianglesCoefficients[2];
  }

  void setAllTriangles(int idx, int orbit) {
    final triangles = orbit == 1 ? trianglesRLBD : trianglesUFBrBl;
    final loc = [for (var i = 0; i < 3; i++) List.filled(3, 0)];
    var remaining = idx;
    for (var color = 0; color < 3; color++) {
      final coefficient = _allTrianglesCoefficients[color];
      final digit = remaining ~/ coefficient;
      unpackSubset(loc[color], digit);
      remaining -= coefficient * digit;
    }
    triangles.fillRange(0, 12, 3);
    for (var color = 0; color < 3; color++) {
      var nz = 0;
      var li = 0;
      for (var i = 0; i < 12; i++) {
        if (triangles[i] < color) continue;
        if (li < 3 && nz == loc[color][li]) {
          triangles[i] = color;
          li++;
        }
        nz++;
      }
    }
  }

  // ------- Phase 1: the D triangles and the D edges -------

  int g1PackEdges() {
    final loc = List.filled(3, 0);
    final perm = List.filled(3, 0);
    var count = 0;
    for (var i = 0; i < 12; i++) {
      if (edges[i] >= edf) {
        loc[count] = i;
        perm[count] = edges[i] - edf;
        count++;
      }
    }
    if (count != 3) throw StateError("Expected 3 D-face edges");
    return packSubset(loc) * 2 + (isParity(perm) ? 1 : 0);
  }

  void g1SetEdges(int idx) {
    final loc = List.filled(3, 0);
    final perm = [edf, edbr, edbl];
    if (idx % 2 == 1) swap(perm, 1, 2);
    unpackSubset(loc, idx ~/ 2);
    edges.fillRange(0, 12, -1);
    for (var i = 0; i < 3; i++) {
      edges[loc[i]] = perm[i];
    }
  }

  int g1PackTriangles() {
    final idx = List.filled(3, 0);
    var count = 0;
    for (var i = 0; i < 12; i++) {
      if (trianglesRLBD[i] == tod) idx[count++] = i;
    }
    if (count != 3) throw StateError("Expected 3 D triangles");
    return packSubset(idx);
  }

  void g1SetTriangles(int idx) {
    final loc = List.filled(3, 0);
    unpackSubset(loc, idx);
    trianglesRLBD.fillRange(0, 12, -1);
    for (var i = 0; i < 3; i++) {
      trianglesRLBD[loc[i]] = tod;
    }
  }

  // ------- Phase 2: the rest of the R, L, B and D half, and the triples -------

  static const List<int> _g2EdgeColors = [tob, tor, tol, tol, tor, tor, tob, tob, tol];
  static const List<int> _g2EdgeNorm = [0, 0, 0, 1, 1, 2, 1, 2, 2];
  static const List<List<int>> _g2EdgeNormInv = [
    [eur, efr, erbr],
    [eul, efl, elbl],
    [eub, ebrb, eblb],
  ];

  int g2PackEdges() {
    for (var i = 0; i < 9; i++) {
      if (edges[i] > 8) throw StateError("Edges not in phase 1");
    }
    final used = List.filled(9, false);
    final loc = [List.filled(3, 0), List.filled(3, 0)];
    final perm = [List.filled(3, 0), List.filled(3, 0)];
    for (var xo = 0; xo < 2; xo++) {
      var found = 0;
      var passed = 0;
      for (var i = 0; i < 9; i++) {
        if (_g2EdgeColors[edges[i]] == xo) {
          perm[xo][found] = _g2EdgeNorm[edges[i]];
          loc[xo][found++] = passed;
          used[i] = true;
          passed++;
        } else if (!used[i]) {
          passed++;
        }
      }
      if (found != 3) throw StateError("Expected three edges of colour $xo");
    }
    final subsetIndex = packSubset(loc[1]) + packSubset(loc[0]) * nCr(6, 3);
    final parityIndex = (isParity(perm[1]) ? 2 : 0) + (isParity(perm[0]) ? 1 : 0);
    return subsetIndex * 4 + parityIndex;
  }

  void g2SetEdges(int idx) {
    final subsetIndex = idx ~/ 4;
    final parityIndex = idx % 4;
    final loc = [List.filled(3, 0), List.filled(3, 0)];
    final parity = [parityIndex & 1, (parityIndex >> 1) & 1];
    unpackSubset(loc[0], subsetIndex ~/ nCr(6, 3));
    unpackSubset(loc[1], subsetIndex % nCr(6, 3));
    final perm = [
      for (var i = 0; i < 2; i++) [..._g2EdgeNormInv[i]],
    ];
    for (var i = 0; i < 2; i++) {
      if (parity[i] == 1) swap(perm[i], 1, 2);
    }

    edges.fillRange(0, 12, -1);
    edges[edf] = edf;
    edges[edbl] = edbl;
    edges[edbr] = edbr;
    for (var i = 0; i < 3; i++) {
      edges[loc[0][i]] = perm[0][i];
    }
    var nz = 0;
    var li = 0;
    for (var i = 0; i < 9; i++) {
      if (edges[i] != -1) continue;
      if (li < 3 && nz == loc[1][li]) {
        edges[i] = perm[1][li];
        li++;
      }
      nz++;
    }
    final bloc = List.filled(3, 0);
    li = 0;
    for (var i = 0; i < 9; i++) {
      if (edges[i] == -1) {
        bloc[li] = i;
        edges[i] = _g2EdgeNormInv[2][li++];
      }
    }
    if (isParity(edges)) swap(edges, bloc[0], bloc[1]);
  }

  int g2PackTriangles() {
    for (var i = 9; i < 12; i++) {
      if (trianglesRLBD[i] != tod) throw StateError("Triangles not in phase 1");
    }
    final used = List.filled(9, false);
    final loc = [List.filled(3, 0), List.filled(3, 0)];
    for (var xo = 0; xo < 2; xo++) {
      var found = 0;
      var passed = 0;
      for (var i = 0; i < 9; i++) {
        if (trianglesRLBD[i] == xo) {
          loc[xo][found++] = passed;
          used[i] = true;
          passed++;
        } else if (!used[i]) {
          passed++;
        }
      }
      if (found != 3) throw StateError("Expected three triangles of colour $xo");
    }
    return packSubset(loc[1]) + packSubset(loc[0]) * nCr(6, 3);
  }

  void g2SetTriangles(int idx) {
    final loc0 = List.filled(3, 0);
    final loc1 = List.filled(3, 0);
    unpackSubset(loc0, idx ~/ nCr(6, 3));
    unpackSubset(loc1, idx % nCr(6, 3));
    trianglesRLBD.fillRange(0, 9, 2);
    for (final v in loc0) {
      trianglesRLBD[v] = 0;
    }
    var nz = 0;
    var li = 0;
    for (var i = 0; i < 9; i++) {
      if (trianglesRLBD[i] == 0) continue;
      if (li < 3 && nz == loc1[li]) {
        trianglesRLBD[i] = 1;
        li++;
      }
      nz++;
    }
    for (var i = 9; i < 12; i++) {
      trianglesRLBD[i] = tod;
    }
  }

  /// For each colour of the U, F, BR and BL half, which side of each corner it
  /// is on, or -1 for a corner that does not carry it.
  static const List<List<int>> cornerTripleColorLookup = [
    [0, 0, 0, -1, -1, -1],
    [1, -1, -1, 0, 1, -1],
    [-1, 1, -1, -1, 0, 1],
    [-1, -1, 1, 1, -1, 0],
  ];

  static final int _g2TripleCornerSize = nCr(6, 3) * 8;

  /// The three corners and three triangles of one colour of the U, F, BR and
  /// BL half, which must end up together.
  int g2PackTriples(int color) =>
      _g2TripleCornerSize * _g2PackTripleTris(color) + _g2PackTripleCorners(color);

  void g2SetTriples(int idx, int color) {
    _g2SetTripleTris(idx ~/ _g2TripleCornerSize, color);
    _g2SetTripleCorners(idx % _g2TripleCornerSize, color);
  }

  int _g2PackTripleCorners(int color) {
    final idx = List.filled(3, 0);
    var orientation = 0;
    var found = 0;
    for (var i = 0; i < 6; i++) {
      final corner = cornerPerm[i];
      if (corner == -1) continue;
      final parity = cornerTripleColorLookup[color][corner];
      if (parity != -1) {
        orientation |= (parity ^ cornerOri[i]) << found;
        idx[found++] = i;
      }
    }
    if (found != 3) throw StateError("Expected 3 matching corners");
    return packSubset(idx) * 8 + orientation;
  }

  int _g2PackTripleTris(int color) {
    final idx = List.filled(3, 0);
    var found = 0;
    for (var i = 0; i < 12; i++) {
      if (trianglesUFBrBl[i] == color) idx[found++] = i;
    }
    return packSubset(idx);
  }

  void _g2SetTripleTris(int idx, int color) {
    final loc = List.filled(3, 0);
    unpackSubset(loc, idx);
    trianglesUFBrBl.fillRange(0, 12, -1);
    for (var i = 0; i < 3; i++) {
      trianglesUFBrBl[loc[i]] = color;
    }
  }

  void _g2SetTripleCorners(int idx, int color) {
    final loc = List.filled(3, 0);
    unpackSubset(loc, idx ~/ 8);
    final orientation = idx % 8;
    final relevant = [
      for (var i = 0; i < 6; i++)
        if (cornerTripleColorLookup[color][i] != -1) i,
    ];
    cornerPerm.fillRange(0, 6, -1);
    cornerOri.fillRange(0, 6, -1);
    for (var i = 0; i < 3; i++) {
      cornerPerm[loc[i]] = relevant[i];
      cornerOri[loc[i]] = ((orientation >> i) & 1) ^ cornerTripleColorLookup[color][relevant[i]];
    }
  }

  // ------- Phase 3: the corners, and the edges within their faces -------

  static const List<List<int>> _g3Edges = [
    [eub, ebrb, eblb],
    [eur, efr, erbr],
    [eul, elbl, efl],
    [edf, edbr, edbl],
  ];

  int g3PackCorners() =>
      packAllCornerPermutation() * FtoCoord.allCornerOrientationSize + packAllCornerOrientation();

  void g3SetCorners(int idx) {
    setAllCornerPermutation(idx ~/ FtoCoord.allCornerOrientationSize);
    setAllCornerOrientation(idx % FtoCoord.allCornerOrientationSize);
  }

  int g3PackEdges() {
    final loc = List.filled(4, -1);
    for (var axis = 0; axis < 4; axis++) {
      for (var i = 0; i < 3; i++) {
        if (_g3Edges[axis][i] == edges[_g3Edges[axis][0]]) loc[axis] = i;
      }
    }
    if (loc.contains(-1)) throw StateError("Could not find G3 edges");
    return 27 * loc[0] + 9 * loc[1] + 3 * loc[2] + loc[3];
  }

  void g3SetEdges(int idx) {
    for (var i = 0; i < 12; i++) {
      edges[i] = i;
    }
    var remaining = idx;
    for (var axis = 0; axis < 4; axis++) {
      final coefficient = pow(3, 3 - axis) as int;
      final digit = remaining ~/ coefficient;
      for (var iteration = 0; iteration < 3; iteration++) {
        if (edges[_g3Edges[axis][0]] == _g3Edges[axis][digit]) break;
        for (var i = 0; i < 2; i++) {
          swap(edges, _g3Edges[axis][0], _g3Edges[axis][i + 1]);
        }
      }
      remaining -= coefficient * digit;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is FtoCubie &&
      _same(other.edges, edges) &&
      _same(other.trianglesUFBrBl, trianglesUFBrBl) &&
      _same(other.trianglesRLBD, trianglesRLBD) &&
      _same(other.cornerOri, cornerOri) &&
      _same(other.cornerPerm, cornerPerm);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(edges),
    Object.hashAll(trianglesUFBrBl),
    Object.hashAll(trianglesRLBD),
    Object.hashAll(cornerOri),
    Object.hashAll(cornerPerm),
  );

  static bool _same(List<int> a, List<int> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static final List<_MoveEffect> _moveEffects = _buildMoveEffects();
}

class _MoveEffect {
  List<int> co = const [];
  List<int> cp = const [];
  List<int> tpU = const [];
  List<int> tpR = const [];
  List<int> ep = const [];
}

/// fto3phase's own table of what each move does, the clockwise ones written
/// out and the anticlockwise ones their inverses.
List<_MoveEffect> _buildMoveEffects() {
  // Triangle positions: on a face, by the face of the same half whose corner
  // it sits in.
  const tiubl = 0, tiubr = 1, tiuf = 2, tifu = 3, tifbr = 4, tifbl = 5;
  const tibru = 6, tibrbl = 7, tibrf = 8, tiblu = 9, tiblf = 10, tiblbr = 11;
  const tirl = 0, tirb = 1, tird = 2, tilb = 3, tilr = 4, tild = 5;
  const tibr = 6, tibl = 7, tibd = 8, tidr = 9, tidl = 10, tidb = 11;
  const c = FtoCubie.cuf, cubr = FtoCubie.cubr, cubl = FtoCubie.cubl;
  const cdl = FtoCubie.cdl, cdr = FtoCubie.cdr, cdb = FtoCubie.cdb;
  const eub = FtoCubie.eub, eur = FtoCubie.eur, eul = FtoCubie.eul, efl = FtoCubie.efl;
  const efr = FtoCubie.efr, erbr = FtoCubie.erbr, ebrb = FtoCubie.ebrb, eblb = FtoCubie.eblb;
  const elbl = FtoCubie.elbl, edf = FtoCubie.edf, edbr = FtoCubie.edbr, edbl = FtoCubie.edbl;

  final effects = List.generate(16, (_) => _MoveEffect());
  void set(int move, List<int> cp, List<int> co, List<int> ep, List<int> tpU, List<int> tpR) {
    effects[move]
      ..cp = cp
      ..co = co
      ..ep = ep
      ..tpU = tpU
      ..tpR = tpR;
  }

  set(
    FtoCubie.r,
    [cdr, c, cubl, cdl, cubr, cdb],
    [1, 1, 0, 0, 0, 0],
    [eub, efr, eul, efl, erbr, eur, ebrb, eblb, elbl, edf, edbr, edbl],
    [tiubl, tifu, tifbr, tibrf, tibru, tifbl, tiuf, tibrbl, tiubr, tiblu, tiblf, tiblbr],
    [tird, tirl, tirb, tilb, tilr, tild, tibr, tibl, tibd, tidr, tidl, tidb],
  );
  set(
    FtoCubie.l,
    [cubl, cubr, cdl, c, cdr, cdb],
    [1, 0, 1, 0, 0, 0],
    [eub, eur, elbl, eul, efr, erbr, ebrb, eblb, efl, edf, edbr, edbl],
    [tiblf, tiubr, tiblu, tiubl, tifbr, tiuf, tibru, tibrbl, tibrf, tifbl, tifu, tiblbr],
    [tirl, tirb, tird, tild, tilb, tilr, tibr, tibl, tibd, tidr, tidl, tidb],
  );
  set(
    FtoCubie.b,
    [c, cdb, cubr, cdl, cdr, cubl],
    [0, 1, 1, 0, 0, 0],
    [ebrb, eur, eul, efl, efr, erbr, eblb, eub, elbl, edf, edbr, edbl],
    [tibru, tibrbl, tiuf, tifu, tifbr, tifbl, tiblbr, tiblu, tibrf, tiubr, tiblf, tiubl],
    [tirl, tirb, tird, tilb, tilr, tild, tibd, tibr, tibl, tidr, tidl, tidb],
  );
  set(
    FtoCubie.d,
    [c, cubr, cubl, cdb, cdl, cdr],
    [0, 0, 0, 0, 0, 0],
    [eub, eur, eul, efl, efr, erbr, ebrb, eblb, elbl, edbl, edf, edbr],
    [tiubl, tiubr, tiuf, tifu, tiblf, tiblbr, tibru, tifbr, tifbl, tiblu, tibrbl, tibrf],
    [tirl, tirb, tird, tilb, tilr, tild, tibr, tibl, tibd, tidl, tidb, tidr],
  );
  set(
    FtoCubie.u,
    [cubr, cubl, c, cdl, cdr, cdb],
    [0, 0, 0, 0, 0, 0],
    [eul, eub, eur, efl, efr, erbr, ebrb, eblb, elbl, edf, edbr, edbl],
    [tiuf, tiubl, tiubr, tifu, tifbr, tifbl, tibru, tibrbl, tibrf, tiblu, tiblf, tiblbr],
    [tibr, tibl, tird, tirl, tirb, tild, tilb, tilr, tibd, tidr, tidl, tidb],
  );
  set(
    FtoCubie.f,
    [cdl, cubr, cubl, cdr, c, cdb],
    [1, 0, 0, 1, 0, 0],
    [eub, eur, eul, edf, efl, erbr, ebrb, eblb, elbl, efr, edbr, edbl],
    [tiubl, tiubr, tiuf, tifbl, tifu, tifbr, tibru, tibrbl, tibrf, tiblu, tiblf, tiblbr],
    [tild, tirb, tilr, tilb, tidl, tidr, tibr, tibl, tibd, tirl, tird, tidb],
  );
  set(
    FtoCubie.br,
    [c, cdr, cubl, cdl, cdb, cubr],
    [0, 1, 0, 0, 1, 0],
    [eub, eur, eul, efl, efr, edbr, erbr, eblb, elbl, edf, ebrb, edbl],
    [tiubl, tiubr, tiuf, tifu, tifbr, tifbl, tibrf, tibru, tibrbl, tiblu, tiblf, tiblbr],
    [tirl, tidr, tidb, tilb, tilr, tild, tird, tibl, tirb, tibd, tidl, tibr],
  );
  set(
    FtoCubie.bl,
    [c, cubr, cdb, cubl, cdr, cdl],
    [0, 0, 1, 0, 0, 1],
    [eub, eur, eul, efl, efr, erbr, ebrb, edbl, eblb, edf, edbr, elbl],
    [tiubl, tiubr, tiuf, tifu, tifbr, tifbl, tibru, tibrbl, tibrf, tiblbr, tiblu, tiblf],
    [tirl, tirb, tird, tibd, tilr, tibl, tibr, tidb, tidl, tidr, tilb, tild],
  );

  for (var move = 1; move < 16; move += 2) {
    final normal = effects[move - 1];
    final inverse = effects[move]
      ..cp = List.filled(6, 0)
      ..co = List.filled(6, 0)
      ..ep = List.filled(12, 0)
      ..tpU = List.filled(12, 0)
      ..tpR = List.filled(12, 0);
    for (var i = 0; i < 6; i++) {
      inverse.cp[normal.cp[i]] = i;
    }
    for (var i = 0; i < 6; i++) {
      inverse.co[i] = normal.co[inverse.cp[i]];
    }
    for (var i = 0; i < 12; i++) {
      inverse.ep[normal.ep[i]] = i;
      inverse.tpU[normal.tpU[i]] = i;
      inverse.tpR[normal.tpR[i]] = i;
    }
  }
  return effects;
}

/// The sizes of the numberings, as fto3phase names them.
abstract final class FtoCoord {
  static final int allEdgesSize = fact(12) ~/ 2;
  static final int allCornerPermutationSize = fact(6) ~/ 2;
  static const int allCornerOrientationSize = 32;
  static final int allTriangleSize = nCr(12, 3) * nCr(9, 3) * nCr(6, 3);
  static final int g1TrianglesSize = nCr(12, 3);
  static final int g1EdgesSize = nCr(12, 3) * 2;
  static final int g2TrianglesSize = nCr(9, 3) * nCr(6, 3);
  static final int g2EdgesSize = nCr(9, 3) * nCr(6, 3) * 4;
  static final int g2TripleCornerSize = nCr(6, 3) * 8;
  static final int g2TripleTriangleSize = nCr(12, 3);
  static final int g2TripleSize = g2TripleCornerSize * g2TripleTriangleSize;
  static final int g3CornersSize = (fact(6) ~/ 2) * 32;
  static const int g3EdgeSize = 81;
}
