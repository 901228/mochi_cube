import "dart:typed_data";

import "cubies.dart";
import "moves.dart";

/// The 48 rotations and reflections of the cube, as threephase numbers them:
/// `symmult[a * 48 + b]` is a followed by b, [syminv] undoes one, and
/// `symmove[s * 36 + m]` is the move that move `m` becomes when the cube is
/// held as symmetry `s`. Filled in by [Center1.initSym].
final Uint8List symmult = Uint8List(48 * 48);
final Uint8List symmove = Uint8List(48 * 36);
final Uint8List syminv = Uint8List(48);

/// Phase 1 of the 4x4x4: put the eight centre stickers of one colour class —
/// the colours of two opposite faces — onto two opposite faces.
///
/// A centre state is which 8 of the 24 centre positions hold the class: 735471
/// of them, which the 48 symmetries of the cube fold into 15582. Each of the
/// three classes (U and D, R and L, F and B) is searched in turn, and whichever
/// is quickest wins.
final class Center1 {
  static const int nRaw = 735471;
  static const int nSym = 15582;

  /// Where each move takes each of the [nSym] classes, `[class * 36 + move]`,
  /// as `newClass * 64 + the symmetry that took it there`.
  static final Int32List ctsmv = Int32List(nSym * 36);

  /// The smallest raw state in each class.
  static final Int32List sym2raw = Int32List(nSym);

  /// Moves to the solved class, for each class. 255 until it is filled in.
  static final Uint8List csprun = Uint8List(nSym);

  /// Which state each of the 48 symmetries leaves the solved class in.
  static final Int32List finish = Int32List(48);

  /// Raw state to `class * 64 + symmetry`, kept only while the move table is
  /// being built.
  static Int32List? raw2sym;

  /// Which 8 of the 24 positions hold the class: 1 there, 0 elsewhere.
  final Uint8List ct = Uint8List(24);

  Center1() {
    for (var i = 0; i < 8; i++) {
      ct[i] = 1;
    }
  }

  Center1.fromCt(Uint8List other) {
    ct.setAll(0, other);
  }

  /// The positions of [c] holding a colour of class [urf]: 0 for U and D, 1 for
  /// R and L, 2 for F and B.
  Center1.fromCenter(CenterCube c, int urf) {
    for (var i = 0; i < 24; i++) {
      ct[i] = (c.ct[i] % 3 == urf) ? 1 : 0;
    }
  }

  static void initSym2Raw() {
    final c = Center1();
    final occ = Int32List(nRaw ~/ 32 + 1);
    var count = 0;
    for (var i = 0; i < nRaw; i++) {
      if ((occ[i >> 5] & (1 << (i & 0x1f))) == 0) {
        c.setIndex(i);
        for (var j = 0; j < 48; j++) {
          final idx = c.index;
          occ[idx >> 5] |= 1 << (idx & 0x1f);
          raw2sym?[idx] = count << 6 | syminv[j];
          c.rot(0);
          if (j % 2 == 1) c.rot(1);
          if (j % 8 == 7) c.rot(2);
          if (j % 16 == 15) c.rot(3);
        }
        sym2raw[count++] = i;
      }
    }
    assert(count == nSym);
  }

  static void createPrun() {
    csprun.fillRange(0, nSym, 255);
    csprun[0] = 0;
    var depth = 0;
    var done = 1;

    while (done != nSym) {
      final inv = depth > 4;
      final select = inv ? 255 : depth;
      final check = inv ? depth : 255;
      depth++;
      for (var i = 0; i < nSym; i++) {
        if (csprun[i] != select) continue;
        for (var m = 0; m < 27; m++) {
          final idx = ctsmv[i * 36 + m] >> 6;
          if (csprun[idx] != check) continue;
          done++;
          if (inv) {
            csprun[i] = depth;
            break;
          } else {
            csprun[idx] = depth;
          }
        }
      }
    }
  }

  static void createMoveTable() {
    final c = Center1();
    final d = Center1();
    for (var i = 0; i < nSym; i++) {
      d.setIndex(sym2raw[i]);
      for (var m = 0; m < 36; m++) {
        c.setFrom(d);
        c.move(m);
        ctsmv[i * 36 + m] = c.getsym();
      }
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

  /// Number the state: the positions of its ones, as a combination of 24
  /// choose 8.
  int get index {
    var idx = 0;
    var r = 8;
    for (var i = 23; i >= 0; i--) {
      if (ct[i] == 1) {
        idx += cnk[i][r--];
      }
    }
    return idx;
  }

  void setIndex(int idx) {
    var r = 8;
    for (var i = 23; i >= 0; i--) {
      ct[i] = 0;
      if (idx >= cnk[i][r]) {
        idx -= cnk[i][r--];
        ct[i] = 1;
      }
    }
  }

  void setFrom(Center1 c) {
    ct.setAll(0, c.ct);
  }

  /// The class this state is in and the symmetry that takes it to that class's
  /// representative: `class * 64 + symmetry`.
  int getsym() {
    final table = raw2sym;
    if (table != null) {
      return table[index];
    }
    for (var j = 0; j < 48; j++) {
      final cord = _classOf(index);
      if (cord != -1) return cord * 64 + j;
      rot(0);
      if (j % 2 == 1) rot(1);
      if (j % 8 == 7) rot(2);
      if (j % 16 == 15) rot(3);
    }
    throw StateError("A centre state is in no class");
  }

  static int _classOf(int n) {
    var lo = 0;
    var hi = nSym - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final v = sym2raw[mid];
      if (v == n) return mid;
      if (v < n) {
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return -1;
  }

  /// One of the four generators of the 48 symmetries.
  void rot(int r) {
    switch (r) {
      case 0:
        move(uw2);
        move(dw2);
      case 1:
        move(rw1);
        move(lw3);
      case 2:
        swap4(ct, 0, 3, 1, 2, 1);
        swap4(ct, 8, 11, 9, 10, 1);
        swap4(ct, 4, 7, 5, 6, 1);
        swap4(ct, 12, 15, 13, 14, 1);
        swap4(ct, 16, 19, 21, 22, 1);
        swap4(ct, 17, 18, 20, 23, 1);
      case 3:
        move(uw1);
        move(dw3);
        move(fw1);
        move(bw3);
    }
  }

  /// Symmetry number [r] of the 48, applied.
  void rotate(int r) {
    for (var j = 0; j < r; j++) {
      rot(0);
      if (j % 2 == 1) rot(1);
      if (j % 8 == 7) rot(2);
      if (j % 16 == 15) rot(3);
    }
  }

  /// The symmetry that holds a cube with centres [cube] in the solved one.
  static int getSolvedSym(CenterCube cube) {
    final c = Center1.fromCt(cube.ct);
    for (var j = 0; j < 48; j++) {
      var check = true;
      for (var i = 0; i < 24; i++) {
        if (c.ct[i] != centerFacelet[i] >> 4) {
          check = false;
          break;
        }
      }
      if (check) return j;
      c.rot(0);
      if (j % 2 == 1) c.rot(1);
      if (j % 8 == 7) c.rot(2);
      if (j % 16 == 15) c.rot(3);
    }
    return -1;
  }

  bool equals(Center1 c) {
    for (var i = 0; i < 24; i++) {
      if (ct[i] != c.ct[i]) return false;
    }
    return true;
  }

  /// Work out [symmult], [syminv], [symmove] and [finish].
  static void initSym() {
    final c = Center1();
    for (var i = 0; i < 24; i++) {
      c.ct[i] = i;
    }
    final d = Center1.fromCt(c.ct);
    final e = Center1.fromCt(c.ct);
    final f = Center1.fromCt(c.ct);

    for (var i = 0; i < 48; i++) {
      for (var j = 0; j < 48; j++) {
        for (var k = 0; k < 48; k++) {
          if (c.equals(d)) {
            symmult[i * 48 + j] = k;
            if (k == 0) syminv[i] = j;
          }
          d.rot(0);
          if (k % 2 == 1) d.rot(1);
          if (k % 8 == 7) d.rot(2);
          if (k % 16 == 15) d.rot(3);
        }
        c.rot(0);
        if (j % 2 == 1) c.rot(1);
        if (j % 8 == 7) c.rot(2);
        if (j % 16 == 15) c.rot(3);
      }
      c.rot(0);
      if (i % 2 == 1) c.rot(1);
      if (i % 8 == 7) c.rot(2);
      if (i % 16 == 15) c.rot(3);
    }

    for (var i = 0; i < 48; i++) {
      c.setFrom(e);
      c.rotate(syminv[i]);
      for (var j = 0; j < 36; j++) {
        d.setFrom(c);
        d.move(j);
        d.rotate(i);
        for (var k = 0; k < 36; k++) {
          f.setFrom(e);
          f.move(k);
          if (f.equals(d)) {
            symmove[i * 36 + j] = k;
            break;
          }
        }
      }
    }

    c.setIndex(0);
    for (var i = 0; i < 48; i++) {
      finish[syminv[i]] = c.index;
      c.rot(0);
      if (i % 2 == 1) c.rot(1);
      if (i % 8 == 7) c.rot(2);
      if (i % 16 == 15) c.rot(3);
    }
  }
}
