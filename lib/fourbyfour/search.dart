import "dart:math";

import "../puzzle/search.dart" as min2phase;
import "../solver.dart" show SolveStatus;
import "center1.dart";
import "center2.dart";
import "center3.dart";
import "cubies.dart";
import "edge3.dart";
import "moves.dart";
import "tables.dart";

/// Shuang Chen's three phase reduction solver for the 4x4x4, as the official
/// scramble program uses it.
///
/// Phase 1 puts the centres of one colour class on two opposite faces, phase 2
/// sorts the rest of the centres, and phase 3 finishes them while pairing the
/// wings, leaving a 3x3x3 that the package's own min2phase solves. None of the
/// phases is optimal and the answer is about 44 moves, but a search takes
/// milliseconds; the best of many cheap phase 1 and phase 2 endings is kept
/// for the phase after.
class ThreePhaseSearch {
  static const int _phase1Solutions = 10000;
  static const int _phase2Attempts = 500;
  static const int _phase2Solutions = 100;
  static const int _phase3Attempts = 100;

  /// Write the moves of a scramble, which leaves a cube like the one given,
  /// rather than the moves of a solution.
  final bool inverse;

  ThreePhaseSearch({this.inverse = true});

  /// The best phase 1 endings found, at most [_phase2Attempts] of them; once it
  /// is full a better one replaces the worst.
  final List<FullCube> _p1sols = [];

  final List<int> _move1 = List.filled(40, 0);
  final List<int> _move2 = List.filled(40, 0);
  final List<int> _move3 = List.filled(40, 0);
  int _length1 = 0;
  int _length2 = 0;
  bool _add1 = false;

  late FullCube _c;
  final FullCube _c1 = FullCube();
  final FullCube _c2 = FullCube();
  final Center2 _ct2 = Center2();
  final Center3 _ct3 = Center3();
  final Edge3 _e12 = Edge3();
  final List<Edge3> _tempe = List.generate(40, (_) => Edge3());

  int _p1SolsCnt = 0;
  final List<FullCube?> _arr2 = List.filled(_phase2Solutions, null);
  int _arr2idx = 0;

  /// The moves of the last search, as indices of the 36.
  List<int> solution = const [];

  /// The moves for a state drawn at random from all the puzzle has.
  List<int> randomState(Random r) => search(FullCube.random(r));

  /// The moves for [cube].
  List<int> search(FullCube cube) {
    _c = cube;
    _doSearch();
    return solution;
  }

  /// [list] sorted by [FullCube.value] and, among equals, in the order it was
  /// in: the search ranks its candidates by this, and a sort that shuffled
  /// equals would make a seed give different scrambles on different runs.
  static void _sortStable(List<FullCube> list) {
    final order = {for (var i = 0; i < list.length; i++) list[i]: i};
    list.sort((a, b) => a.value != b.value ? a.value - b.value : order[a]! - order[b]!);
  }

  void _doSearch() {
    FourByFourTables.init();
    solution = const [];
    final ud = Center1.fromCenter(_c.getCenter(), 0).getsym();
    final fb = Center1.fromCenter(_c.getCenter(), 1).getsym();
    final rl = Center1.fromCenter(_c.getCenter(), 2).getsym();
    final udprun = Center1.csprun[ud >> 6];
    final fbprun = Center1.csprun[fb >> 6];
    final rlprun = Center1.csprun[rl >> 6];

    _p1SolsCnt = 0;
    _arr2idx = 0;
    _p1sols.clear();

    for (_length1 = min(min(udprun, fbprun), rlprun); _length1 < 100; _length1++) {
      if ((rlprun <= _length1 && _search1(rl >> 6, rl & 0x3f, _length1, -1, 0)) ||
          (udprun <= _length1 && _search1(ud >> 6, ud & 0x3f, _length1, -1, 0)) ||
          (fbprun <= _length1 && _search1(fb >> 6, fb & 0x3f, _length1, -1, 0))) {
        break;
      }
    }

    final p1SolsArr = [..._p1sols];
    _sortStable(p1SolsArr);

    var maxLength2 = 9;
    int length12;
    do {
      phase2:
      for (length12 = p1SolsArr[0].value; length12 < 100; length12++) {
        for (var i = 0; i < p1SolsArr.length; i++) {
          if (p1SolsArr[i].value > length12) break;
          if (length12 - p1SolsArr[i].length1 > maxLength2) continue;
          _c1.copy(p1SolsArr[i]);
          _ct2.set(_c1.getCenter(), _c1.getEdge().parity);
          final s2ct = _ct2.getct();
          final s2rl = _ct2.getrl();
          _length1 = p1SolsArr[i].length1;
          _length2 = length12 - p1SolsArr[i].length1;

          if (_search2(s2ct, s2rl, _length2, 28, 0)) break phase2;
        }
      }
      maxLength2++;
    } while (length12 == 100);

    final arr2 = <FullCube>[for (var i = 0; i < _arr2idx; i++) _arr2[i]!];
    _sortStable(arr2);

    var maxLength3 = 13;
    int length123;
    var index = 0;
    do {
      phase3:
      for (length123 = arr2[0].value; length123 < 100; length123++) {
        for (var i = 0; i < min(arr2.length, _phase3Attempts); i++) {
          if (arr2[i].value > length123) break;
          if (length123 - arr2[i].length1 - arr2[i].length2 > maxLength3) continue;
          final eparity = _e12.setCube(arr2[i].getEdge());
          _ct3.set(arr2[i].getCenter(), eparity ^ arr2[i].getCorner().parity);
          final ct = _ct3.getct();
          final edge = _e12.get(10);
          final prun = Edge3.getprun(_e12.getsym());

          if (prun <= length123 - arr2[i].length1 - arr2[i].length2 &&
              _search3(edge, ct, prun, length123 - arr2[i].length1 - arr2[i].length2, 20, 0)) {
            index = i;
            break phase3;
          }
        }
      }
      maxLength3++;
    } while (length123 == 100);

    final solcube = FullCube.from(arr2[index]);
    _length1 = solcube.length1;
    _length2 = solcube.length2;
    final length = length123 - _length1 - _length2;

    for (var i = 0; i < length; i++) {
      solcube.move(move3std[_move3[i]]);
    }

    // What is left is a 3x3x3 with its centres in some orientation, which
    // min2phase reads off the centres themselves.
    final facelet = String.fromCharCodes([for (final f in solcube.to333Facelet()) "URFDLB".codeUnitAt(f)]);
    final result = min2phase.Search.solution(facelet);
    if (result.status != SolveStatus.foundSolution) {
      throw StateError("The reduced 3x3x3 would not solve: ${result.status.name} ${result.error ?? ""}");
    }
    for (final move in result.solution!.algorithm.moves) {
      solcube.move(move);
    }

    solution = solcube.solutionMoves(inverse: inverse);
  }

  bool _search1(int ct, int sym, int maxl, int lm, int depth) {
    if (ct == 0 && maxl < 5) {
      return maxl == 0 && _init2(sym, lm);
    }
    for (var axis = 0; axis < 27; axis += 3) {
      if (axis == lm || axis == lm - 9 || axis == lm - 18) continue;
      for (var power = 0; power < 3; power++) {
        final m = axis + power;
        var ctx = Center1.ctsmv[ct * 36 + symmove[sym * 36 + m]];
        final prun = Center1.csprun[ctx >> 6];
        if (prun >= maxl) {
          if (prun > maxl) break;
          continue;
        }
        final symx = symmult[sym * 48 + (ctx & 0x3f)];
        ctx >>= 6;
        _move1[depth] = m;
        if (_search1(ctx, symx, maxl - 1, axis, depth + 1)) return true;
      }
    }
    return false;
  }

  bool _init2(int sym, int lm) {
    _c1.copy(_c);
    for (var i = 0; i < _length1; i++) {
      _c1.move(_move1[i]);
    }

    switch (Center1.finish[sym]) {
      case 0:
        _c1.move(fw1);
        _c1.move(bw3);
        _move1[_length1] = fw1;
        _move1[_length1 + 1] = bw3;
        _add1 = true;
        sym = 19;
      case 12869:
        _c1.move(uw1);
        _c1.move(dw3);
        _move1[_length1] = uw1;
        _move1[_length1 + 1] = dw3;
        _add1 = true;
        sym = 34;
      case 735470:
        _add1 = false;
        sym = 0;
    }
    _ct2.set(_c1.getCenter(), _c1.getEdge().parity);
    final s2ct = _ct2.getct();
    final s2rl = _ct2.getrl();
    final ctp = Center2.ctprun[s2ct * 70 + s2rl];

    _c1.value = ctp + _length1;
    _c1.length1 = _length1;
    _c1.add1 = _add1;
    _c1.sym = sym;
    _p1SolsCnt++;

    if (_p1sols.length < _phase2Attempts) {
      _p1sols.add(FullCube.from(_c1));
    } else {
      var worst = 0;
      for (var i = 1; i < _p1sols.length; i++) {
        if (_p1sols[i].value > _p1sols[worst].value) worst = i;
      }
      if (_p1sols[worst].value > _c1.value) {
        _p1sols[worst].copy(_c1);
      }
    }

    return _p1SolsCnt == _phase1Solutions;
  }

  bool _search2(int ct, int rl, int maxl, int lm, int depth) {
    if (ct == 0 && Center2.ctprun[rl] == 0 && maxl == 0) {
      return _init3();
    }
    for (var m = 0; m < 23; m++) {
      if (ckmv2[lm * 28 + m] != 0) {
        m = skipAxis2[m];
        continue;
      }
      final ctx = Center2.ctmv[ct * 28 + m];
      final rlx = Center2.rlmv[rl * 28 + m];

      final prun = Center2.ctprun[ctx * 70 + rlx];
      if (prun >= maxl) {
        if (prun > maxl) {
          m = skipAxis2[m];
        }
        continue;
      }

      _move2[depth] = move2std[m];
      if (_search2(ctx, rlx, maxl - 1, m, depth + 1)) return true;
    }
    return false;
  }

  bool _init3() {
    _c2.copy(_c1);
    for (var i = 0; i < _length2; i++) {
      _c2.move(_move2[i]);
    }
    if (!_c2.checkEdge()) return false;
    final eparity = _e12.setCube(_c2.getEdge());
    _ct3.set(_c2.getCenter(), eparity ^ _c2.getCorner().parity);
    final ct = _ct3.getct();
    final prun = Edge3.getprun(_e12.getsym());

    final slot = _arr2[_arr2idx] ??= FullCube();
    slot.copy(_c2);
    slot.value = _length1 + _length2 + max(prun, Center3.prun[ct]);
    slot.length2 = _length2;
    _arr2idx++;

    return _arr2idx == _arr2.length;
  }

  bool _search3(int edge, int ct, int prun, int maxl, int lm, int depth) {
    if (maxl == 0) {
      return edge == 0 && ct == 0;
    }
    _tempe[depth].setIndex(edge);
    for (var m = 0; m < 17; m++) {
      if (ckmv3[lm * 20 + m] != 0) {
        m = skipAxis3[m];
        continue;
      }
      final ctx = Center3.ctmove[ct * 20 + m];
      final prun1 = Center3.prun[ctx];
      if (prun1 >= maxl) {
        if (prun1 > maxl && m < 14) {
          m = skipAxis3[m];
        }
        continue;
      }
      final edgex = Edge3.getmvrot(_tempe[depth].edge, m << 3, 10);

      final cord1x = edgex ~/ Edge3.nRaw;
      var symcord1x = Edge3.raw2sym[cord1x];
      final symx = symcord1x & 7;
      symcord1x >>= 3;
      final cord2x = Edge3.getmvrot(_tempe[depth].edge, m << 3 | symx, 10) % Edge3.nRaw;

      final prunx = Edge3.getprunFrom(symcord1x * Edge3.nRaw + cord2x, prun);
      if (prunx >= maxl) {
        if (prunx > maxl && m < 14) {
          m = skipAxis3[m];
        }
        continue;
      }

      if (_search3(edgex, ctx, prunx, maxl - 1, m, depth + 1)) {
        _move3[depth] = m;
        return true;
      }
    }
    return false;
  }
}
