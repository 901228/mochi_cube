import "dart:typed_data";

import "../cube/algorithm.dart";
import "../solver.dart";
import "algorithm.dart";
import "coord_tables.dart";
import "cube/cubie_cube.dart";
import "cube/moves.dart";
import "cube/sym_coord.dart";
import "cube/symmetry.dart";
import "phase2_tables.dart";

/// Two moves may follow one another only if they are on different faces, and
/// opposite faces are forced into index order because they commute.
bool _allowed(int previous, int move) {
  final a = previous ~/ 3;
  final b = move ~/ 3;
  return a != b && a != b + 3;
}

/// `_symMoveP2[s * nMoves + i]` is the phase 2 move index that symmetry `s`
/// turns phase 2 move `i` into. The subgroup is closed under the symmetries, so
/// this is always defined.
///
/// Flat rather than nested, and likewise [_symMultFlat]: both are read twice per
/// node of the phase 2 search, which is the hottest loop in the solver.
final Uint8List _symMoveP2 = Uint8List(symCount * Phase2Tables.nMoves)
  ..setAll(0, [
    for (var s = 0; s < symCount; s++)
      for (var i = 0; i < Phase2Tables.nMoves; i++)
        Phase2Tables.moves.indexOf(symMove[s][Phase2Tables.moves[i]]),
  ]);

/// `symMult` flattened to `a * 16 + b`.
final Uint8List _symMultFlat = Uint8List(symCount * symCount)
  ..setAll(0, [
    for (var a = 0; a < symCount; a++)
      for (var b = 0; b < symCount; b++) symMult[a][b],
  ]);

/// `symInv` as a flat typed list.
final Uint8List _symInvFlat = Uint8List.fromList(symInv);

/// Two phase solver.
///
/// Phase 1 drives the cube into the subgroup where only U, D and half turns of
/// R, F, L and B are needed; phase 2 finishes inside it. Neither phase alone
/// gives the shortest solution, so the search keeps enumerating longer phase 1
/// endings, each of which may allow a shorter phase 2, and returns the best it
/// found within its budget.
///
/// The cube is solved from six starting points at once — the three axis
/// rotations of [urfConjugate], each also inverted — and the best result wins.
/// A cube that is awkward to get into the subgroup one way round is usually
/// much easier another way, and this is most of what makes the search quick.
class Search {
  static const int defaultMaxLength = 21;
  static const int defaultProbeLimit = 200000;

  /// Solve the cube described by a 54 character facelet string.
  static SolveResult solution(
    String facelets, {
    int maxLength = defaultMaxLength,
    int probeLimit = defaultProbeLimit,
    Duration? maxTime,
  }) {
    final CubieCube cube;
    try {
      cube = CubieCube.fromFaceletString(facelets);
    } on FormatException catch (e) {
      return (status: SolveStatus.invalidCube, solution: null, error: e);
    }

    return solveCube(cube, maxLength: maxLength, probeLimit: probeLimit, maxTime: maxTime);
  }

  /// Solve a cube already in cubie form.
  static SolveResult solveCube(
    CubieCube cube, {
    int maxLength = defaultMaxLength,
    int probeLimit = defaultProbeLimit,
    Duration? maxTime,
  }) {
    final check = cube.verify();
    if (check != CubeVerificationStatus.solvable) {
      return (status: SolveStatus.invalidCube, solution: null, error: check);
    }

    final clock = Stopwatch()..start();
    final session = _Session(cube, maxLength, probeLimit, clock, maxTime, stopAtFirst: true);

    List<int>? best;
    for (var depth = 0; depth <= maxLength && best == null; depth++) {
      best = session.step(depth) ?? best;
    }

    clock.stop();

    if (best == null) {
      final ranOut = maxTime != null && clock.elapsed >= maxTime;
      return (
        status: ranOut ? SolveStatus.exceededMaxTime : SolveStatus.exceededMaxLength,
        solution: null,
        error: null,
      );
    }
    return (
      status: SolveStatus.foundSolution,
      solution: Solution.fromMoves(best, elapsedTime: clock.elapsed),
      error: null,
    );
  }

  /// Solutions of decreasing length, yielded as they are found.
  ///
  /// [solveCube] stops at the first phase 1 length that yields anything, which
  /// is quick but can be several moves off. This keeps going, lowering its own
  /// budget each time, so each solution is shorter than the one before.
  ///
  /// It gets slower with every improvement — the search space at a given phase
  /// 1 depth grows fast, and the last few moves are the expensive ones — so it
  /// is a stream: take what is good enough and stop, or bound it with
  /// [maxTime]. Nothing is computed until the stream is listened to, and
  /// abandoning it abandons the search.
  static Stream<Solution> solveDeeply(
    CubieCube cube, {
    int maxLength = defaultMaxLength,
    int probeLimit = defaultProbeLimit,
    Duration? maxTime,
  }) async* {
    if (cube.verify() != CubeVerificationStatus.solvable) {
      return;
    }

    final clock = Stopwatch()..start();
    final session = _Session(cube, maxLength, probeLimit, clock, maxTime, stopAtFirst: false);

    for (var depth = 0; depth <= maxLength; depth++) {
      final improved = session.step(depth);
      if (improved != null) {
        yield Solution.fromMoves(improved, elapsedTime: clock.elapsed);
      }
    }
  }

  /// Solve [from] into [to] rather than into a solved cube.
  ///
  /// Both are cube states; the moves returned turn the first into the second.
  /// Solving is the special case where [to] is solved.
  ///
  /// The trick is that `from * X = to` means `X = from⁻¹ * to`, so the whole
  /// thing reduces to solving one cube — the one that is the difference between
  /// the two.
  static SolveResult patternize(
    CubieCube from,
    CubieCube to, {
    int maxLength = defaultMaxLength,
    int probeLimit = defaultProbeLimit,
    Duration? maxTime,
  }) {
    for (final cube in [from, to]) {
      final check = cube.verify();
      if (check != CubeVerificationStatus.solvable) {
        return (status: SolveStatus.invalidCube, solution: null, error: check);
      }
    }

    // The solver returns the moves that take a cube to solved, so hand it the
    // difference the other way round: `to⁻¹ * from` solved by X gives
    // `to⁻¹ * from * X = I`, that is `from * X = to`.
    final difference = to.inverse();
    difference.multiply(from);

    return solveCube(difference, maxLength: maxLength, probeLimit: probeLimit, maxTime: maxTime);
  }
}

/// The six views of one cube, advanced together.
///
/// They move in lockstep, one phase 1 length at a time, rather than one view
/// being run to exhaustion before the next is tried. A view with no short
/// solution would otherwise search its whole tree down to the maximum length
/// before giving up, which costs orders of magnitude more than the answer is
/// worth.
class _Session {
  _Session(
    CubieCube cube,
    this._maxLength,
    int probeLimit,
    this._clock,
    this._maxTime, {
    required bool stopAtFirst,
  }) {
    // Three axis rotations, each also inverted.
    for (var direction = 0; direction < 6; direction++) {
      final rotations = direction ~/ 2;
      final inverted = direction.isOdd;

      var view = CubieCube.from(cube);
      for (var i = 0; i < rotations; i++) {
        view = urfConjugate(view);
      }
      if (inverted) {
        view = view.inverse();
      }

      _views.add(_Solver(view, _maxLength, probeLimit, _clock, _maxTime, stopAtFirst));
      _rotations.add(rotations);
      _inverted.add(inverted);
    }
  }

  final int _maxLength;
  final Stopwatch _clock;
  final Duration? _maxTime;

  final List<_Solver> _views = [];
  final List<int> _rotations = [];
  final List<bool> _inverted = [];

  int _bestLength = 1 << 30;

  /// Give every view the same phase 1 length, and return the best solution
  /// found at it, if that beats everything so far.
  List<int>? step(int depth) {
    if (_maxTime != null && _clock.elapsed >= _maxTime) {
      return null;
    }

    List<int>? improved;
    for (var i = 0; i < _views.length; i++) {
      final found = _views[i].searchDepth(depth);
      if (found == null) {
        continue;
      }

      // Map the solution back onto the cube as it was handed in. Inverting
      // undoes the inverse view; conjugating by S_URF the other way round —
      // twice, since it has order 3 — undoes each axis rotation.
      var moves = found;
      if (_inverted[i]) {
        moves = moves.reversed.map(invertMove).toList();
      }
      for (var r = 0; r < _rotations[i]; r++) {
        moves = moves.map((m) => urfMove[urfMove[m]]).toList();
      }

      if (moves.length < _bestLength) {
        _bestLength = moves.length;
        improved = moves;
        // Every view now only has to beat this.
        for (final view in _views) {
          view.lowerLimit(moves.length - 1);
        }
      }
    }

    return improved;
  }
}

/// The search over one of the six views of the cube.
class _Solver {
  _Solver(this._start, this._maxLength, this._probeLimit, this._clock, this._maxTime, this._stopAtFirst)
    : _limit = _maxLength,
      _reported = _maxLength + 1;

  final CubieCube _start;
  final int _maxLength;
  final int _probeLimit;
  final Stopwatch _clock;
  final Duration? _maxTime;

  /// Whether to stop as soon as anything is found, or keep improving.
  final bool _stopAtFirst;

  /// The longest total solution still worth finding. It drops as better ones
  /// turn up, in this view or in any of the other five.
  int _limit;

  /// The length already handed back, so an unchanged best is not reported twice.
  int _reported;

  /// Whether the search has run out of time.
  ///
  /// Checked once per phase 2 probe rather than per node: reading the clock is
  /// far more expensive than a table lookup, and probes are frequent enough to
  /// keep the overshoot small.
  bool get _outOfTime {
    final limit = _maxTime;
    return limit != null && _clock.elapsed >= limit;
  }

  final Phase1Tables _t1 = Phase1Tables();
  final Phase2Tables _t2 = Phase2Tables();

  /// Enough room for the longest solution the caller can ask for.
  static const int _capacity = 32;

  final List<int> _moves = List.filled(_capacity, 0);
  final List<int> _twist = List.filled(_capacity, 0);
  final List<int> _flip = List.filled(_capacity, 0);
  final List<int> _udslice = List.filled(_capacity, 0);

  final List<int> _cpermClass = List.filled(_capacity, 0);
  final List<int> _cpermSymIdx = List.filled(_capacity, 0);
  final List<int> _epermClass = List.filled(_capacity, 0);
  final List<int> _epermSymIdx = List.filled(_capacity, 0);
  final List<int> _mperm = List.filled(_capacity, 0);
  final List<int> _ccombo = List.filled(_capacity, 0);

  int _probes = 0;
  List<int>? _best;

  /// Depth first search, so the recursion has to be told to unwind rather than
  /// simply returning a value.
  bool _done = false;

  bool _started = false;

  /// Look for a solution whose phase 1 part is exactly [depth] moves long.
  ///
  /// Returns the solution the first time one is found, and null afterwards, so
  /// the caller can drive several views forward together.
  /// Only solutions shorter than [length] are worth finding from now on.
  void lowerLimit(int length) {
    if (length < _limit) {
      _limit = length;
    }
  }

  List<int>? searchDepth(int depth) {
    if (_done || depth > _limit || _maxLength >= _capacity || _probes >= _probeLimit) {
      return null;
    }

    if (!_started) {
      _twist[0] = _start.twist;
      _flip[0] = _start.flip;
      _udslice[0] = _start.udslice;
      _started = true;
    }

    _phase1(0, depth);

    final best = _best;
    if (best == null || best.length >= _reported) {
      return null;
    }
    _reported = best.length;
    return best;
  }

  void _phase1(int n, int depth) {
    if (_done || _probes >= _probeLimit) {
      return;
    }

    if (depth == 0) {
      if (_twist[n] == 0 && _flip[n] == 0 && _udslice[n] == 0) {
        _enterPhase2(n);
      }
      return;
    }

    if (_t1.phase1Cost(_twist[n], _flip[n], _udslice[n]) > depth) {
      return;
    }

    for (var m = 0; m < 18; m++) {
      if (n > 0 && !_allowed(_moves[n - 1], m)) {
        continue;
      }

      _moves[n] = m;
      _twist[n + 1] = _t1.twistMove[(_twist[n], m)];
      _flip[n + 1] = _t1.flipMove[(_flip[n], m)];
      _udslice[n + 1] = _t1.udsliceMove[(_udslice[n], m)];

      _phase1(n + 1, depth - 1);

      if (_done || _probes >= _probeLimit) {
        return;
      }
    }
  }

  /// Set up the phase 2 coordinates for the position after [n] moves, then run
  /// phase 2 within whatever length is left.
  void _enterPhase2(int n) {
    _probes++;
    if (_outOfTime) {
      _done = true;
      return;
    }

    final cube = CubieCube.from(_start);
    for (var i = 0; i < n; i++) {
      cube.moveIndex(_moves[i]);
    }

    final (cCls, cSym) = SymCoord.split(cpermSym.raw2sym[cube.cperm]);
    final (eCls, eSym) = SymCoord.split(epermSym.raw2sym[cube.eperm]);
    _cpermClass[n] = cCls;
    _cpermSymIdx[n] = cSym;
    _epermClass[n] = eCls;
    _epermSymIdx[n] = eSym;
    _mperm[n] = cube.mperm;
    _ccombo[n] = cube.ccombo;

    for (var depth = _cost2(n); n + depth <= _limit; depth++) {
      if (_phase2(n, depth)) {
        _best = _moves.sublist(0, n + depth);
        _limit = n + depth - 1;
        if (_stopAtFirst) {
          _done = true;
        }
        return;
      }
    }
  }

  int _cost2(int n) {
    final eInv = _symInvFlat[_epermSymIdx[n]];
    final cIndex =
        _cpermClass[n] * Phase2Tables.nMperm + _t2.mpermConj[(_mperm[n], _symInvFlat[_cpermSymIdx[n]])];
    final eIndex = _epermClass[n] * Phase2Tables.nMperm + _t2.mpermConj[(_mperm[n], eInv)];
    final kIndex = _epermClass[n] * Phase2Tables.nCcombo + _t2.ccomboConj[(_ccombo[n], eInv)];

    var best = _t2.cpermPrune.at(cIndex);
    final b = _t2.epermPrune.at(eIndex);
    if (b > best) best = b;
    final c = _t2.ccomboPrune.at(kIndex);
    return c > best ? c : best;
  }

  bool _phase2(int n, int depth) {
    if (depth == 0) {
      return _mperm[n] == 0 && _cpermClass[n] == 0 && _epermClass[n] == 0;
    }
    if (_cost2(n) > depth) {
      return false;
    }

    for (var i = 0; i < Phase2Tables.nMoves; i++) {
      final m = Phase2Tables.moves[i];
      if (n > 0 && !_allowed(_moves[n - 1], m)) {
        continue;
      }
      _moves[n] = m;

      // Corner and edge permutations live in the reduced space, so the move has
      // to be relabelled by the state's own symmetry before the class table is
      // read, and the symmetry it returns composed back on. The entries are
      // unpacked by hand rather than through SymCoord.split, which would
      // allocate a record per lookup.
      final cs = _cpermSymIdx[n];
      final cEntry = _t2.cpermClassMove[(_cpermClass[n], _symMoveP2[cs * Phase2Tables.nMoves + i])];
      _cpermClass[n + 1] = cEntry >> 4;
      _cpermSymIdx[n + 1] = _symMultFlat[(cEntry & 0xF) * symCount + cs];

      final es = _epermSymIdx[n];
      final eEntry = _t2.epermClassMove[(_epermClass[n], _symMoveP2[es * Phase2Tables.nMoves + i])];
      _epermClass[n + 1] = eEntry >> 4;
      _epermSymIdx[n + 1] = _symMultFlat[(eEntry & 0xF) * symCount + es];

      _mperm[n + 1] = _t2.mpermMove[(_mperm[n], i)];
      _ccombo[n + 1] = _t2.ccomboMove[(_ccombo[n], i)];

      if (_phase2(n + 1, depth - 1)) {
        return true;
      }
    }

    return false;
  }
}

/// [Search] behind the common [Solver] interface.
class Min2PhaseSolver implements Solver {
  const Min2PhaseSolver();

  @override
  String get name => "min2phase";

  @override
  int get defaultMaxLength => Search.defaultMaxLength;

  @override
  SolveResult solve(String facelets, {int maxLength = Search.defaultMaxLength, Duration? maxTime}) =>
      Search.solution(facelets, maxLength: maxLength, maxTime: maxTime);
}

/// The default [Min2PhaseSolver].
const Solver min2phase = Min2PhaseSolver();
