import "dart:typed_data";

import "cubies.dart";

/// Phase 3's wings: once the 24 wings are paired the cube has twelve edges to
/// place, in 12!/2 = 239500800 arrangements, which is too many to number every
/// state but few enough that a pruning table over a symmetry-reduced slice of
/// them is worth building.
///
/// An arrangement of the edges is split into the first four (11880 ways, of
/// which 1538 are different once the 8 symmetries of the phase are taken) and
/// the other eight, 20160 ways. The table holds, for each of
/// 1538 * 20160 = 31006080 reduced states, how many moves it is from solved,
/// but only the number modulo 3 and only as far as [maxDepth]: two bits each,
/// 7.75 MB. A state that is deeper reads as [maxDepth].
final class Edge3 {
  static const int nSym = 1538;
  static const int nRaw = 20160;
  static const int nEprun = nSym * nRaw;
  static const int maxDepth = 10;

  /// How many entries the table holds at each depth or less, as the original
  /// counts them; the first [maxDepth] are what is built. The test compares.
  static const List<int> prunValues = [
    1, 4, 16, 55, 324, 1922, 12275, 77640, 485359, 2778197, 11742425, //
    27492416, 31002941, 31006080,
  ];

  /// The table: 2 bits a state, four to a byte, `3` for not reached.
  static final Uint8List eprun = Uint8List(nEprun ~/ 4);

  static final Int32List sym2raw = Int32List(nSym);
  static final Uint16List symstate = Uint16List(nSym);
  static final Int32List raw2sym = Int32List(11880);

  static const List<int> syminv = [0, 1, 6, 3, 4, 5, 2, 7];

  /// Where each edge goes under each of the 20 moves held 8 ways: `[move * 8 +
  /// rotation]`, twelve entries each. [mvrot] names the position an edge has
  /// come from, [mvroto] which edge it is once the rotation is undone.
  static final Uint8List mvrot = Uint8List(20 * 8 * 12);
  static final Uint8List mvroto = Uint8List(20 * 8 * 12);

  /// 12!/2 divided down to what is left after the first `i` edges are placed.
  static const List<int> _factX = [
    1, 1, 2 ~/ 2, 6 ~/ 2, 24 ~/ 2, 120 ~/ 2, 720 ~/ 2, 5040 ~/ 2, 40320 ~/ 2, 362880 ~/ 2, 3628800 ~/ 2, //
    39916800 ~/ 2, 479001600 ~/ 2,
  ];

  /// The count of bits set in each number below 4096: how many of the first
  /// edges already placed are smaller than the one being placed.
  static final Uint8List _bits = _bitCounts();

  static Uint8List _bitCounts() {
    final out = Uint8List(4096);
    for (var i = 1; i < 4096; i++) {
      out[i] = out[i >> 1] + (i & 1);
    }
    return out;
  }

  /// How many entries of the table have been filled in; the build reports it.
  static int done = 0;

  final List<int> edge = List.filled(12, 0);
  final List<int> edgeo = List.filled(12, 0);
  final List<int> temp = List.filled(12, 0);
  final List<int> _remaining = List.filled(12, 0);
  bool isStd = true;

  Edge3() {
    for (var i = 0; i < 12; i++) {
      edgeo[i] = i;
    }
  }

  static void initMvrot() {
    final e = Edge3();
    for (var m = 0; m < 20; m++) {
      for (var r = 0; r < 8; r++) {
        e.setIndex(0);
        e.move(m);
        e.rotate(r);
        for (var i = 0; i < 12; i++) {
          mvrot[(m << 3 | r) * 12 + i] = e.edge[i];
        }
        e.std();
        for (var i = 0; i < 12; i++) {
          mvroto[(m << 3 | r) * 12 + i] = e.temp[i];
        }
      }
    }
  }

  static void initRaw2Sym() {
    final e = Edge3();
    final occ = Uint8List(11880 ~/ 8);
    var count = 0;
    for (var i = 0; i < 11880; i++) {
      if ((occ[i >> 3] & (1 << (i & 7))) == 0) {
        e.setIndex(i * _factX[8]);
        for (var j = 0; j < 8; j++) {
          final idx = e.get(4);
          if (idx == i) {
            symstate[count] |= 1 << j;
          }
          occ[idx >> 3] |= 1 << (idx & 7);
          raw2sym[idx] = count << 3 | syminv[j];
          e.rot(0);
          if (j % 2 == 1) {
            e.rot(1);
            e.rot(2);
          }
        }
        sym2raw[count++] = i;
      }
    }
    assert(count == nSym);
  }

  static void setPruning(Uint8List table, int index, int value) {
    table[index >> 2] ^= (3 ^ value) << ((index & 3) << 1);
  }

  static int getPruning(Uint8List table, int index) => (table[index >> 2] >> ((index & 3) << 1)) & 3;

  /// The depth of [edge], given that it is no nearer than [prun] says.
  static int getprunFrom(int edge, int prun) {
    final depm3 = getPruning(eprun, edge);
    if (depm3 == 3) return maxDepth;
    return (depm3 - prun + 16) % 3 + prun - 1;
  }

  /// The depth of [edge], found by walking down the table to the solved state.
  static int getprun(int edge) {
    final e = Edge3();
    var depth = 0;
    var depm3 = getPruning(eprun, edge);
    if (depm3 == 3) return maxDepth;
    while (edge != 0) {
      depm3 = depm3 == 0 ? 2 : depm3 - 1;

      final cord1 = sym2raw[edge ~/ nRaw];
      final cord2 = edge % nRaw;
      e.setIndex(cord1 * nRaw + cord2);

      for (var m = 0; m < 17; m++) {
        final cord1x = getmvrot(e.edge, m << 3, 4);
        var symcord1x = raw2sym[cord1x];
        final symx = symcord1x & 7;
        symcord1x >>= 3;
        final cord2x = getmvrot(e.edge, m << 3 | symx, 10) % nRaw;
        final idx = symcord1x * nRaw + cord2x;
        if (getPruning(eprun, idx) == depm3) {
          depth++;
          edge = idx;
          break;
        }
      }
    }
    return depth;
  }

  static void createPrun() {
    final e = Edge3();
    final f = Edge3();
    final g = Edge3();

    eprun.fillRange(0, eprun.length, 0xFF);
    var depth = 0;
    done = 1;
    setPruning(eprun, 0, 0);

    while (done != nEprun) {
      final inv = depth > 9;
      final depm3 = depth % 3;
      final dep1m3 = (depth + 1) % 3;
      final find = inv ? 3 : depm3;
      final chk = inv ? depm3 : 3;

      if (depth >= maxDepth - 1) break;

      for (var b = 0; b < eprun.length; b++) {
        var val = eprun[b];
        if (!inv && val == 0xFF) continue;
        for (var k = 0; k < 4; k++, val >>= 2) {
          if ((val & 3) != find) continue;
          final i = b * 4 + k;
          final symcord1 = i ~/ nRaw;
          final cord1 = sym2raw[symcord1];
          final cord2 = i % nRaw;
          e.setIndex(cord1 * nRaw + cord2);

          for (var m = 0; m < 17; m++) {
            final cord1x = getmvrot(e.edge, m << 3, 4);
            var symcord1x = raw2sym[cord1x];
            final symx = symcord1x & 7;
            symcord1x >>= 3;
            final cord2x = getmvrot(e.edge, m << 3 | symx, 10) % nRaw;
            final idx = symcord1x * nRaw + cord2x;
            if (getPruning(eprun, idx) != chk) continue;
            setPruning(eprun, inv ? i : idx, dep1m3);
            done++;
            if (inv) break;
            var symState = symstate[symcord1x];
            if (symState == 1) continue;
            f.setFrom(e);
            f.move(m);
            f.rotate(symx);
            for (var j = 1; (symState >>= 1) != 0; j++) {
              if ((symState & 1) != 1) continue;
              g.setFrom(f);
              g.rotate(j);
              final idxx = symcord1x * nRaw + g.get(10) % nRaw;
              if (getPruning(eprun, idxx) == chk) {
                setPruning(eprun, idxx, dep1m3);
                done++;
              }
            }
          }
        }
      }
      depth++;
    }
  }

  static const List<int> _fullEdgeMap = [0, 2, 4, 6, 1, 3, 7, 5, 8, 9, 10, 11];

  /// The state of this as a table index, turning it to the symmetry that
  /// reduces it.
  int getsym() {
    final cord1x = get(4);
    var symcord1x = raw2sym[cord1x];
    final symx = symcord1x & 7;
    symcord1x >>= 3;
    rotate(symx);
    final cord2x = get(10) % nRaw;
    return symcord1x * nRaw + cord2x;
  }

  /// Read the wings of [c] as twelve edges, returning the parity of the
  /// permutation that took.
  int setCube(EdgeCube c) {
    isStd = true;
    for (var i = 0; i < 12; i++) {
      edgeo[i] = i;
      temp[i] = i;
      edge[i] = c.ep[_fullEdgeMap[i] + 12] % 12;
    }
    var parity = 1; // because of _fullEdgeMap
    for (var i = 0; i < 12; i++) {
      while (edge[i] != i) {
        final t = edge[i];
        edge[i] = edge[t];
        edge[t] = t;
        final s = temp[i];
        temp[i] = temp[t];
        temp[t] = s;
        parity ^= 1;
      }
    }
    for (var i = 0; i < 12; i++) {
      edge[i] = temp[c.ep[_fullEdgeMap[i]] % 12];
    }
    return parity;
  }

  void setFrom(Edge3 e) {
    for (var i = 0; i < 12; i++) {
      edge[i] = e.edge[i];
      edgeo[i] = e.edgeo[i];
    }
    isStd = e.isStd;
  }

  /// The number, up to [end] edges long, of the arrangement [ep] after move
  /// row [mrIdx]: the position of each edge among those not yet placed.
  static int getmvrot(List<int> ep, int mrIdx, int end) {
    final base = mrIdx * 12;
    var idx = 0;
    var used = 0;
    for (var i = 0; i < end; i++) {
      final v = mvroto[base + ep[mvrot[base + i]]];
      idx = idx * (12 - i) + v - _bits[used & ((1 << v) - 1)];
      used |= 1 << v;
    }
    return idx;
  }

  void std() {
    for (var i = 0; i < 12; i++) {
      temp[edgeo[i]] = i;
    }
    for (var i = 0; i < 12; i++) {
      edge[i] = temp[edge[i]];
      edgeo[i] = i;
    }
    isStd = true;
  }

  /// The number of the first [end] edges: each one's place among those left.
  int get(int end) {
    if (!isStd) std();
    var idx = 0;
    var used = 0;
    for (var i = 0; i < end; i++) {
      final v = edge[i];
      idx = idx * (12 - i) + v - _bits[used & ((1 << v) - 1)];
      used |= 1 << v;
    }
    return idx;
  }

  /// Arrange the edges as number [idx] of the 12!/2 even arrangements.
  void setIndex(int idx) {
    // The edges not yet placed, in order; each digit picks one and closes the gap.
    for (var i = 0; i < 12; i++) {
      _remaining[i] = i;
    }
    var parity = 0;
    for (var i = 0; i < 11; i++) {
      final p = _factX[11 - i];
      final v = idx ~/ p;
      idx %= p;
      parity ^= v;
      edge[i] = _remaining[v];
      for (var k = v; k < 11 - i; k++) {
        _remaining[k] = _remaining[k + 1];
      }
    }
    if ((parity & 1) == 0) {
      edge[11] = _remaining[0];
    } else {
      edge[11] = edge[10];
      edge[10] = _remaining[0];
    }
    for (var i = 0; i < 12; i++) {
      edgeo[i] = i;
    }
    isStd = true;
  }

  void move(int i) {
    isStd = false;
    switch (i) {
      case 0: // U
        _circle(edge, 0, 4, 1, 5);
        _circle(edgeo, 0, 4, 1, 5);
      case 1: // U2
        _swap(edge, 0, 4, 1, 5);
        _swap(edgeo, 0, 4, 1, 5);
      case 2: // U'
        _circle(edge, 0, 5, 1, 4);
        _circle(edgeo, 0, 5, 1, 4);
      case 3: // R2
        _swap(edge, 5, 10, 6, 11);
        _swap(edgeo, 5, 10, 6, 11);
      case 4: // F
        _circle(edge, 0, 11, 3, 8);
        _circle(edgeo, 0, 11, 3, 8);
      case 5: // F2
        _swap(edge, 0, 11, 3, 8);
        _swap(edgeo, 0, 11, 3, 8);
      case 6: // F'
        _circle(edge, 0, 8, 3, 11);
        _circle(edgeo, 0, 8, 3, 11);
      case 7: // D
        _circle(edge, 2, 7, 3, 6);
        _circle(edgeo, 2, 7, 3, 6);
      case 8: // D2
        _swap(edge, 2, 7, 3, 6);
        _swap(edgeo, 2, 7, 3, 6);
      case 9: // D'
        _circle(edge, 2, 6, 3, 7);
        _circle(edgeo, 2, 6, 3, 7);
      case 10: // L2
        _swap(edge, 4, 8, 7, 9);
        _swap(edgeo, 4, 8, 7, 9);
      case 11: // B
        _circle(edge, 1, 9, 2, 10);
        _circle(edgeo, 1, 9, 2, 10);
      case 12: // B2
        _swap(edge, 1, 9, 2, 10);
        _swap(edgeo, 1, 9, 2, 10);
      case 13: // B'
        _circle(edge, 1, 10, 2, 9);
        _circle(edgeo, 1, 10, 2, 9);
      case 14: // u2
        _swap(edge, 0, 4, 1, 5);
        _swap(edgeo, 0, 4, 1, 5);
        _swap2(edge, 9, 11);
        _swap2(edgeo, 8, 10);
      case 15: // r2
        _swap(edge, 5, 10, 6, 11);
        _swap(edgeo, 5, 10, 6, 11);
        _swap2(edge, 1, 3);
        _swap2(edgeo, 0, 2);
      case 16: // f2
        _swap(edge, 0, 11, 3, 8);
        _swap(edgeo, 0, 11, 3, 8);
        _swap2(edge, 5, 7);
        _swap2(edgeo, 4, 6);
      case 17: // d2
        _swap(edge, 2, 7, 3, 6);
        _swap(edgeo, 2, 7, 3, 6);
        _swap2(edge, 8, 10);
        _swap2(edgeo, 9, 11);
      case 18: // l2
        _swap(edge, 4, 8, 7, 9);
        _swap(edgeo, 4, 8, 7, 9);
        _swap2(edge, 0, 2);
        _swap2(edgeo, 1, 3);
      case 19: // b2
        _swap(edge, 1, 9, 2, 10);
        _swap(edgeo, 1, 9, 2, 10);
        _swap2(edge, 4, 6);
        _swap2(edgeo, 5, 7);
    }
  }

  void rot(int r) {
    isStd = false;
    switch (r) {
      case 0:
        move(14);
        move(17);
      case 1:
        _circlex(11, 5, 10, 6); // r
        _circlex(5, 10, 6, 11);
        _circlex(1, 2, 3, 0);
        _circlex(4, 9, 7, 8); // l'
        _circlex(8, 4, 9, 7);
        _circlex(0, 1, 2, 3);
      case 2:
        _swapx(4, 5);
        _swapx(5, 4);
        _swapx(11, 8);
        _swapx(8, 11);
        _swapx(7, 6);
        _swapx(6, 7);
        _swapx(9, 10);
        _swapx(10, 9);
        _swapx(1, 1);
        _swapx(0, 0);
        _swapx(3, 3);
        _swapx(2, 2);
    }
  }

  void rotate(int r) {
    while (r >= 2) {
      r -= 2;
      rot(1);
      rot(2);
    }
    if (r != 0) {
      rot(0);
    }
  }

  static void _circle(List<int> arr, int a, int b, int c, int d) {
    final temp = arr[d];
    arr[d] = arr[c];
    arr[c] = arr[b];
    arr[b] = arr[a];
    arr[a] = temp;
  }

  static void _swap(List<int> arr, int a, int b, int c, int d) {
    var temp = arr[a];
    arr[a] = arr[c];
    arr[c] = temp;
    temp = arr[b];
    arr[b] = arr[d];
    arr[d] = temp;
  }

  static void _swap2(List<int> arr, int x, int y) {
    final temp = arr[x];
    arr[x] = arr[y];
    arr[y] = temp;
  }

  void _swapx(int x, int y) {
    final temp = edge[x];
    edge[x] = edgeo[y];
    edgeo[y] = temp;
  }

  void _circlex(int a, int b, int c, int d) {
    final temp = edgeo[d];
    edgeo[d] = edge[c];
    edge[c] = edgeo[b];
    edgeo[b] = edge[a];
    edge[a] = temp;
  }
}
