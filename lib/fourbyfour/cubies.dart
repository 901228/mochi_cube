import "dart:math";
import "dart:typed_data";

import "center1.dart";
import "moves.dart";

/// The 4x4x4 as threephase holds it: its twenty-four centres, twenty-four wings
/// and eight corners, each kept apart because each is solved in a phase of its
/// own.
///
/// Positions are numbered as in the diagram of threephase's `FullCube`, and the
/// 96 stickers by `face * 16 + row * 4 + column`, faces U R F D L B — which is
/// also how [NxNCube] numbers them, so the two can be compared directly.

/// The sticker of each centre position, in the order U, D, F, B, R, L.
const List<int> centerFacelet = [
  0x05, 0x06, 0x0a, 0x09, 0x35, 0x36, 0x3a, 0x39, 0x25, 0x26, 0x2a, 0x29, //
  0x55, 0x56, 0x5a, 0x59, 0x15, 0x16, 0x1a, 0x19, 0x45, 0x46, 0x4a, 0x49,
];

/// The two stickers of each wing position. Position `i + 12` is the same two
/// faces as `i`, the other way round.
const List<List<int>> edgeFacelet = [
  [0x0d, 0x21], [0x04, 0x41], [0x02, 0x51], [0x0b, 0x11], [0x3d, 0x5e], [0x34, 0x4e], //
  [0x32, 0x2e], [0x3b, 0x1e], [0x4b, 0x28], [0x44, 0x57], [0x1b, 0x58], [0x14, 0x27],
  [0x22, 0x0e], [0x42, 0x08], [0x52, 0x01], [0x12, 0x07], [0x5d, 0x3e], [0x4d, 0x38], //
  [0x2d, 0x31], [0x1d, 0x37], [0x24, 0x47], [0x5b, 0x48], [0x54, 0x17], [0x2b, 0x18],
];

/// The three stickers of each corner position, the one on U or D first.
const List<List<int>> cornerFacelet = [
  [0x0f, 0x10, 0x23], [0x0c, 0x20, 0x43], [0x00, 0x40, 0x53], [0x03, 0x50, 0x13], //
  [0x33, 0x2f, 0x1c], [0x30, 0x4f, 0x2c], [0x3c, 0x5f, 0x4c], [0x3f, 0x1f, 0x5c],
];

/// The colour of each of the 24 centre stickers: 0 to 5 for U R F D L B.
class CenterCube {
  final Uint8List ct = Uint8List(24);

  CenterCube() {
    for (var i = 0; i < 24; i++) {
      ct[i] = centerFacelet[i] >> 4;
    }
  }

  CenterCube.from(CenterCube c) {
    copy(c);
  }

  /// The centres shuffled at random, every arrangement of the colours equally
  /// likely.
  CenterCube.random(Random r) {
    for (var i = 0; i < 24; i++) {
      ct[i] = centerFacelet[i] >> 4;
    }
    for (var i = 0; i < 23; i++) {
      final t = i + r.nextInt(24 - i);
      if (ct[t] != ct[i]) {
        final m = ct[i];
        ct[i] = ct[t];
        ct[t] = m;
      }
    }
  }

  void copy(CenterCube c) {
    ct.setAll(0, c.ct);
  }

  /// Write the centres into a 3x3x3's facelets, which must be solved.
  void fill333Facelet(List<int> facelet) {
    // The centre of face i of the 3x3x3 is the group of four starting here.
    const map = [0, 4, 2, 1, 5, 3];
    for (var i = 0; i < 6; i++) {
      final idx = map[i] << 2;
      if (ct[idx] != ct[idx + 1] || ct[idx + 1] != ct[idx + 2] || ct[idx + 2] != ct[idx + 3]) {
        throw StateError("Unsolved Center");
      }
      facelet[4 + i * 9] = ct[idx];
    }
  }

  void move(int m) {
    final key = m % 3;
    switch (m ~/ 3) {
      case 0: // U
        swap4(ct, 0, 1, 2, 3, key);
      case 1: // R
        swap4(ct, 16, 17, 18, 19, key);
      case 2: // F
        swap4(ct, 8, 9, 10, 11, key);
      case 3: // D
        swap4(ct, 4, 5, 6, 7, key);
      case 4: // L
        swap4(ct, 20, 21, 22, 23, key);
      case 5: // B
        swap4(ct, 12, 13, 14, 15, key);
      case 6: // u
        swap4(ct, 0, 1, 2, 3, key);
        swap4(ct, 8, 20, 12, 16, key);
        swap4(ct, 9, 21, 13, 17, key);
      case 7: // r
        swap4(ct, 16, 17, 18, 19, key);
        swap4(ct, 1, 15, 5, 9, key);
        swap4(ct, 2, 12, 6, 10, key);
      case 8: // f
        swap4(ct, 8, 9, 10, 11, key);
        swap4(ct, 2, 19, 4, 21, key);
        swap4(ct, 3, 16, 5, 22, key);
      case 9: // d
        swap4(ct, 4, 5, 6, 7, key);
        swap4(ct, 10, 18, 14, 22, key);
        swap4(ct, 11, 19, 15, 23, key);
      case 10: // l
        swap4(ct, 20, 21, 22, 23, key);
        swap4(ct, 0, 8, 4, 14, key);
        swap4(ct, 3, 11, 7, 13, key);
      case 11: // b
        swap4(ct, 12, 13, 14, 15, key);
        swap4(ct, 1, 20, 7, 18, key);
        swap4(ct, 0, 23, 6, 17, key);
    }
  }
}

/// Which wing sits at each of the 24 wing positions.
class EdgeCube {
  static const List<List<int>> _edgeColor = [
    [2, 0], [4, 0], [5, 0], [1, 0], [5, 3], [4, 3], [2, 3], [1, 3], [2, 4], [5, 4], [5, 1], [2, 1], //
  ];

  /// The 3x3x3 facelet of each wing position, once the wings are paired.
  static const List<int> _edgeMap = [
    19, 37, 46, 10, 52, 43, 25, 16, 21, 50, 48, 23, 7, 3, 1, 5, 34, 30, 28, 32, 41, 39, 14, 12, //
  ];

  final Uint8List ep = Uint8List(24);

  EdgeCube() {
    for (var i = 0; i < 24; i++) {
      ep[i] = i;
    }
  }

  EdgeCube.from(EdgeCube c) {
    copy(c);
  }

  /// The wings in any of the 24! orders, each equally likely.
  EdgeCube.random(Random r) {
    for (var i = 0; i < 24; i++) {
      ep[i] = i;
    }
    for (var i = 0; i < 23; i++) {
      final t = i + r.nextInt(24 - i);
      if (t != i) {
        final m = ep[i];
        ep[i] = ep[t];
        ep[t] = m;
      }
    }
  }

  int get parity => permutationParity(ep);

  void copy(EdgeCube c) {
    ep.setAll(0, c.ep);
  }

  void fill333Facelet(List<int> facelet) {
    for (var i = 0; i < 24; i++) {
      facelet[_edgeMap[i]] = _edgeColor[ep[i] % 12][ep[i] ~/ 12];
    }
  }

  /// Whether the wings are paired up: the first twelve positions hold one wing
  /// of each edge, with an even number of them the other way round.
  bool checkEdge() {
    var ck = 0;
    var parity = false;
    for (var i = 0; i < 12; i++) {
      ck |= 1 << ep[i];
      parity = parity != (ep[i] >= 12);
    }
    ck &= ck >> 12;
    return ck == 0 && !parity;
  }

  void move(int m) {
    final key = m % 3;
    switch (m ~/ 3) {
      case 0: // U
        swap4(ep, 0, 1, 2, 3, key);
        swap4(ep, 12, 13, 14, 15, key);
      case 1: // R
        swap4(ep, 11, 15, 10, 19, key);
        swap4(ep, 23, 3, 22, 7, key);
      case 2: // F
        swap4(ep, 0, 11, 6, 8, key);
        swap4(ep, 12, 23, 18, 20, key);
      case 3: // D
        swap4(ep, 4, 5, 6, 7, key);
        swap4(ep, 16, 17, 18, 19, key);
      case 4: // L
        swap4(ep, 1, 20, 5, 21, key);
        swap4(ep, 13, 8, 17, 9, key);
      case 5: // B
        swap4(ep, 2, 9, 4, 10, key);
        swap4(ep, 14, 21, 16, 22, key);
      case 6: // u
        swap4(ep, 0, 1, 2, 3, key);
        swap4(ep, 12, 13, 14, 15, key);
        swap4(ep, 9, 22, 11, 20, key);
      case 7: // r
        swap4(ep, 11, 15, 10, 19, key);
        swap4(ep, 23, 3, 22, 7, key);
        swap4(ep, 2, 16, 6, 12, key);
      case 8: // f
        swap4(ep, 0, 11, 6, 8, key);
        swap4(ep, 12, 23, 18, 20, key);
        swap4(ep, 3, 19, 5, 13, key);
      case 9: // d
        swap4(ep, 4, 5, 6, 7, key);
        swap4(ep, 16, 17, 18, 19, key);
        swap4(ep, 8, 23, 10, 21, key);
      case 10: // l
        swap4(ep, 1, 20, 5, 21, key);
        swap4(ep, 13, 8, 17, 9, key);
        swap4(ep, 14, 0, 18, 4, key);
      case 11: // b
        swap4(ep, 2, 9, 4, 10, key);
        swap4(ep, 14, 21, 16, 22, key);
        swap4(ep, 7, 15, 1, 17, key);
    }
  }
}

/// Which corner sits at each corner position, and how it is twisted.
class CornerCube {
  /// The 3x3x3 facelets of each corner position.
  static const List<List<int>> _cornerFacelet333 = [
    [8, 9, 20], [6, 18, 38], [0, 36, 47], [2, 45, 11], //
    [29, 26, 15], [27, 44, 24], [33, 53, 42], [35, 17, 51],
  ];

  /// The six face turns, the first of each three; the half turn and the turn
  /// back are worked out from it.
  static final List<CornerCube> _moveCube = _initMove();

  final Uint8List cp = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7]);
  final Uint8List co = Uint8List(8);

  CornerCube();

  CornerCube.from(CornerCube c) {
    copy(c);
  }

  /// The corners in order [cperm], 0 to 40319, and twisted as [twist], 0 to 2186.
  CornerCube.indexed(int cperm, int twist) {
    set8Perm(cp, cperm);
    var total = 0;
    var idx = twist;
    for (var i = 6; i >= 0; i--) {
      co[i] = idx % 3;
      total += co[i];
      idx ~/= 3;
    }
    co[7] = (15 - total) % 3;
  }

  /// Any of the 8! * 3^7 corner states, each equally likely.
  CornerCube.random(Random r) : this.indexed(r.nextInt(40320), r.nextInt(2187));

  void copy(CornerCube c) {
    cp.setAll(0, c.cp);
    co.setAll(0, c.co);
  }

  int get parity => permutationParity(cp);

  void fill333Facelet(List<int> facelet) {
    for (var corn = 0; corn < 8; corn++) {
      final j = cp[corn];
      final ori = co[corn];
      for (var n = 0; n < 3; n++) {
        facelet[_cornerFacelet333[corn][(n + ori) % 3]] = _cornerFacelet333[j][n] ~/ 9;
      }
    }
  }

  /// `a * b` for corners only, written into [prod].
  static void cornMult(CornerCube a, CornerCube b, CornerCube prod) {
    for (var corn = 0; corn < 8; corn++) {
      prod.cp[corn] = a.cp[b.cp[corn]];
      final oriA = a.co[b.cp[corn]];
      final oriB = b.co[corn];
      var ori = oriA;
      ori += (oriA < 3) ? oriB : 6 - oriB;
      ori %= 3;
      if ((oriA >= 3) != (oriB >= 3)) {
        ori += 3;
      }
      prod.co[corn] = ori;
    }
  }

  void move(int idx) {
    final temp = CornerCube();
    cornMult(this, _moveCube[idx], temp);
    copy(temp);
  }

  static List<CornerCube> _initMove() {
    final cubes = List<CornerCube>.generate(18, (_) => CornerCube());
    cubes[0] = CornerCube.indexed(15120, 0);
    cubes[3] = CornerCube.indexed(21021, 1494);
    cubes[6] = CornerCube.indexed(8064, 1236);
    cubes[9] = CornerCube.indexed(9, 0);
    cubes[12] = CornerCube.indexed(1230, 412);
    cubes[15] = CornerCube.indexed(224, 137);
    for (var a = 0; a < 18; a += 3) {
      for (var p = 0; p < 2; p++) {
        cornMult(cubes[a + p], cubes[a], cubes[a + p + 1]);
      }
    }
    return cubes;
  }
}

/// A 4x4x4 and the search state that goes with it.
///
/// Moves are queued and only applied to a part of the cube when it is asked
/// for, since each phase looks at some parts and not others.
class FullCube implements Comparable<FullCube> {
  final EdgeCube _edge;
  final CenterCube _center;
  final CornerCube _corner;

  /// What a search ranks this by: the moves made so far and a bound on the rest.
  int value = 0;
  bool add1 = false;
  int length1 = 0;
  int length2 = 0;
  int length3 = 0;

  /// The symmetry phase 1 finished in, which later moves are expressed through.
  int sym = 0;

  final Uint8List moveBuffer = Uint8List(100);
  int _moveLength = 0;
  int _edgeAvail = 0;
  int _centerAvail = 0;
  int _cornerAvail = 0;

  FullCube() : _edge = EdgeCube(), _center = CenterCube(), _corner = CornerCube();

  FullCube.from(FullCube c) : _edge = EdgeCube(), _center = CenterCube(), _corner = CornerCube() {
    copy(c);
  }

  /// Any state of the puzzle, each equally likely.
  FullCube.random(Random r)
    : _edge = EdgeCube.random(r),
      _center = CenterCube.random(r),
      _corner = CornerCube.random(r);

  /// The cube whose 96 stickers are [f], as faces 0 to 5 in the order of the
  /// diagram above.
  ///
  /// Throws [FormatException] if they are not the stickers of a 4x4x4 that
  /// could be reached by turning.
  FullCube.fromFacelets(Uint8List f) : _edge = EdgeCube(), _center = CenterCube(), _corner = CornerCube() {
    for (var i = 0; i < 24; i++) {
      _center.ct[i] = f[centerFacelet[i]];
    }
    for (var i = 0; i < 24; i++) {
      var found = false;
      for (var j = 0; j < 24; j++) {
        if (f[edgeFacelet[i][0]] == edgeFacelet[j][0] >> 4 &&
            f[edgeFacelet[i][1]] == edgeFacelet[j][1] >> 4) {
          _edge.ep[i] = j;
          found = true;
        }
      }
      if (!found) throw FormatException("Wing $i shows a pair of colours no wing has");
    }
    for (var i = 0; i < 8; i++) {
      // Which of the three stickers is on U or D, then the other two in order.
      var ori = 0;
      while (ori < 3 && f[cornerFacelet[i][ori]] != 0 && f[cornerFacelet[i][ori]] != 3) {
        ori++;
      }
      if (ori == 3) throw FormatException("Corner $i has no U or D sticker");
      final col1 = f[cornerFacelet[i][(ori + 1) % 3]];
      final col2 = f[cornerFacelet[i][(ori + 2) % 3]];
      var found = false;
      for (var j = 0; j < 8; j++) {
        if (col1 == cornerFacelet[j][1] >> 4 && col2 == cornerFacelet[j][2] >> 4) {
          _corner.cp[i] = j;
          _corner.co[i] = ori % 3;
          found = true;
          break;
        }
      }
      if (!found) throw FormatException("Corner $i shows colours no corner has");
    }

    // Everything above guesses at a piece for every position, so the guesses
    // have to hold together: no piece twice, the corners twisted a whole number
    // of turns in all, and the stickers the pieces come to the stickers given.
    if (_edge.ep.toSet().length != 24 || _corner.cp.toSet().length != 8) {
      throw const FormatException("A piece appears twice");
    }
    if (_corner.co.fold<int>(0, (a, b) => a + b) % 3 != 0) {
      throw const FormatException("A corner is twisted on its own");
    }
    final centreCounts = List.filled(6, 0);
    for (final colour in _center.ct) {
      centreCounts[colour]++;
    }
    if (centreCounts.any((count) => count != 4)) {
      throw const FormatException("The centres are not four of each colour");
    }
    final again = Uint8List(96);
    toFacelet(again);
    for (var i = 0; i < 96; i++) {
      if (again[i] != f[i]) throw const FormatException("The stickers are not those of a 4x4x4");
    }
  }

  /// Write the 96 stickers into [f].
  void toFacelet(Uint8List f) {
    final edge = getEdge();
    final center = getCenter();
    final corner = getCorner();
    for (var i = 0; i < 24; i++) {
      f[centerFacelet[i]] = center.ct[i];
    }
    for (var i = 0; i < 24; i++) {
      f[edgeFacelet[i][0]] = edgeFacelet[edge.ep[i]][0] >> 4;
      f[edgeFacelet[i][1]] = edgeFacelet[edge.ep[i]][1] >> 4;
    }
    for (var c = 0; c < 8; c++) {
      final j = corner.cp[c];
      final ori = corner.co[c];
      for (var n = 0; n < 3; n++) {
        f[cornerFacelet[c][(n + ori) % 3]] = cornerFacelet[j][n] >> 4;
      }
    }
  }

  /// Turn the whole thing, now, rather than when asked: only for building a
  /// cube from moves.
  void doMove(int m) {
    getEdge().move(m);
    getCenter().move(m);
    getCorner().move(m % 18);
  }

  @override
  int compareTo(FullCube c) => value - c.value;

  void copy(FullCube c) {
    _edge.copy(c._edge);
    _center.copy(c._center);
    _corner.copy(c._corner);

    value = c.value;
    add1 = c.add1;
    length1 = c.length1;
    length2 = c.length2;
    length3 = c.length3;
    sym = c.sym;

    moveBuffer.setAll(0, c.moveBuffer);
    _moveLength = c._moveLength;
    _edgeAvail = c._edgeAvail;
    _centerAvail = c._centerAvail;
    _cornerAvail = c._cornerAvail;
  }

  bool checkEdge() => getEdge().checkEdge();

  /// Queue move [m] without applying it yet.
  void move(int m) {
    moveBuffer[_moveLength++] = m;
  }

  EdgeCube getEdge() {
    while (_edgeAvail < _moveLength) {
      _edge.move(moveBuffer[_edgeAvail++]);
    }
    return _edge;
  }

  CenterCube getCenter() {
    while (_centerAvail < _moveLength) {
      _center.move(moveBuffer[_centerAvail++]);
    }
    return _center;
  }

  CornerCube getCorner() {
    while (_cornerAvail < _moveLength) {
      _corner.move(moveBuffer[_cornerAvail++] % 18);
    }
    return _corner;
  }

  /// The 54 facelets of the 3x3x3 this has become, as faces 0 to 5.
  ///
  /// Only for a cube whose centres are solved and wings paired.
  List<int> to333Facelet() {
    final ret = List.filled(54, 0);
    getEdge().fill333Facelet(ret);
    getCenter().fill333Facelet(ret);
    getCorner().fill333Facelet(ret);
    return ret;
  }

  /// The moves queued so far, as the solution the search found, written the way
  /// the WCA writes a scramble: only `Uw`, `Rw` and `Fw` wide, the rest turned
  /// into those by holding the cube differently.
  ///
  /// The search works in a frame that has been turned several times over, and
  /// this carries every move back out of it. With [inverse] they come out
  /// reversed and undone, which is a scramble that leaves the cube this one
  /// started as; without, a solution. Either way the cube is left a whole-cube
  /// rotation away from where a person would hold it.
  List<int> solutionMoves({required bool inverse}) {
    final fixed = <int>[for (var i = 0; i < length1; i++) moveBuffer[i]];
    var s = sym;
    for (var i = length1 + (add1 ? 2 : 0); i < _moveLength; i++) {
      final mapped = symmove[s * 36 + moveBuffer[i]];
      if (mapped >= dw1) {
        fixed.add(mapped - 9);
        s = symmult[s * 48 + _move2rot[mapped - dw1]];
      } else {
        fixed.add(mapped);
      }
    }
    final finishSym = symmult[syminv[s] * 48 + Center1.getSolvedSym(getCenter())];

    final out = <int>[];
    s = finishSym;
    if (inverse) {
      for (var i = fixed.length - 1; i >= 0; i--) {
        final m = fixed[i] ~/ 3 * 3 + (2 - fixed[i] % 3);
        final mapped = symmove[s * 36 + m];
        if (mapped >= dw1) {
          out.add(mapped - 9);
          s = symmult[s * 48 + _move2rot[mapped - dw1]];
        } else {
          out.add(mapped);
        }
      }
    } else {
      out.addAll(fixed);
    }
    return out;
  }

  /// The rotation that holds each of the three wide turns of a face on the
  /// other side — D, L, B — as the same turn of U, R, F.
  static const List<int> _move2rot = [35, 1, 34, 2, 4, 6, 22, 5, 19];
}
