import "dart:typed_data";

import "../logger.dart";
import "../table_storage.dart";
import "cube/cubie_cube.dart";
import "cube/moves.dart";
import "cube/sym_coord.dart";
import "cube/symmetry.dart";

/// Phase 1 coordinate tables for the min2phase search.
///
/// Phase 1 drives corner orientation, edge flip and the UD slice to zero. Two
/// pruning tables bound the distance to that goal: one over
/// (corner orientation, slice) and one over (edge flip, slice). Both are
/// reduced by symmetry, which is where the size saving comes from — the raw
/// product spaces have around a million entries each, the reduced ones under
/// two hundred thousand.
///
/// The orientation coordinate is reduced, the slice coordinate is not. A state
/// is located by taking the symmetry that maps the orientation onto its class
/// representative and applying that same symmetry to the slice coordinate.
class Phase1Tables {
  static const int nMoves = 18;
  static const int nUdslice = 495;
  static const int nTwist = 2187;
  static const int nFlip = 2048;

  /// Whether to build [twistFlipPrune].
  ///
  /// It is the largest table in the solver by a wide margin — 358 KB against
  /// the 122 KB of the other two phase 1 tables put together — and buys about a
  /// 40% faster search for that, plus 210ms of build time. Turning it off costs
  /// speed only; solutions stay the same length and stay correct.
  ///
  /// Setting this discards any tables already built, so set it before the first
  /// solve rather than between two of them.
  static bool get useTwistFlipPrune => _useTwistFlipPrune;
  static bool _useTwistFlipPrune = true;
  static set useTwistFlipPrune(bool value) {
    if (value == _useTwistFlipPrune) {
      return;
    }
    _useTwistFlipPrune = value;
    _instance = null;
  }

  factory Phase1Tables() => _instance ??= Phase1Tables._internal();
  static Phase1Tables? _instance;

  /// The cache file. Bump the version whenever a builder below changes.
  static TableFile get _cache => TableFile(
    name: "min2phase-phase1.bin",
    magic: const [0x4D, 0x32, 0x50, 0x31], // "M2P1"
    version: 1,
    variant: _useTwistFlipPrune ? 1 : 0,
  );

  List<int> get _sectionLengths => [
    nTwist * nMoves * 2,
    nFlip * nMoves * 2,
    nUdslice * nMoves * 2,
    nUdslice * symCount * 2,
    nTwist * symCount * 2,
    (twistSym.classCount * nUdslice + 1) ~/ 2,
    (flipSym.classCount * nUdslice + 1) ~/ 2,
    if (_useTwistFlipPrune) (flipSym.classCount * nTwist + 1) ~/ 2,
  ];

  Phase1Tables._internal() {
    // The symmetry reductions are cheap to redo — about 50ms for all four —
    // so only the tables the breadth first searches produce are cached.
    final cached = _cache.read(_sectionLengths);
    if (cached != null) {
      var i = 0;
      twistMove = movingTableFromBytes(cached[i++], nTwist, nMoves);
      flipMove = movingTableFromBytes(cached[i++], nFlip, nMoves);
      udsliceMove = movingTableFromBytes(cached[i++], nUdslice, nMoves);
      udsliceConj = movingTableFromBytes(cached[i++], nUdslice, symCount);
      twistConj = movingTableFromBytes(cached[i++], nTwist, symCount);
      twistPrune = PruningTable(cached[i++], nUdslice, twistSym.classCount * nUdslice);
      flipPrune = PruningTable(cached[i++], nUdslice, flipSym.classCount * nUdslice);
      twistFlipPrune = _useTwistFlipPrune
          ? PruningTable(cached[i++], nTwist, flipSym.classCount * nTwist)
          : null;
      Logging().info("Loaded the phase 1 tables from ${_cache.location}");
      return;
    }

    twistMove = _rawMoveTable(nTwist, (c, v) => c.twist = v, (c) => c.twist);
    flipMove = _rawMoveTable(nFlip, (c, v) => c.flip = v, (c) => c.flip);
    udsliceMove = _rawMoveTable(nUdslice, (c, v) => c.udslice = v, (c) => c.udslice);
    udsliceConj = _conjTable(nUdslice, (c, v) => c.udslice = v, (c) => c.udslice);
    twistConj = _conjTable(nTwist, (c, v) => c.twist = v, (c) => c.twist);

    twistPrune = _buildPrune(twistSym, twistMove, udsliceMove, udsliceConj, nUdslice);
    flipPrune = _buildPrune(flipSym, flipMove, udsliceMove, udsliceConj, nUdslice);
    twistFlipPrune = _useTwistFlipPrune ? _buildPrune(flipSym, flipMove, twistMove, twistConj, nTwist) : null;

    _cache.write([
      movingTableBytes(twistMove),
      movingTableBytes(flipMove),
      movingTableBytes(udsliceMove),
      movingTableBytes(udsliceConj),
      movingTableBytes(twistConj),
      twistPrune.data,
      flipPrune.data,
      if (twistFlipPrune != null) twistFlipPrune!.data,
    ]);
  }

  /// Raw move tables: coordinate after each of the 18 face turns.
  late final MovingTable twistMove;
  late final MovingTable flipMove;
  late final MovingTable udsliceMove;

  /// `udsliceConj[(u, s)]` is the slice coordinate after conjugating by
  /// symmetry `s`. Needed because the slice has to follow whatever symmetry
  /// the orientation coordinate was reduced by.
  late final MovingTable udsliceConj;

  /// Corner orientation after conjugating by each of the 16 symmetries.
  late final MovingTable twistConj;

  /// Distance to phase 2, indexed by `twistClass * 495 + conjugated slice`.
  late final PruningTable twistPrune;

  /// Distance to phase 2, indexed by `flipClass * 495 + conjugated slice`.
  late final PruningTable flipPrune;

  /// Distance to phase 2 over both orientations at once, indexed by
  /// `flipClass * 2187 + conjugated corner orientation`.
  ///
  /// The other two tables each pair one orientation with the slice; this one
  /// pairs the two orientations with each other and ignores the slice, so it
  /// bounds states that both of the others are optimistic about. It is much the
  /// largest of the three, and [useTwistFlipPrune] turns it off.
  late final PruningTable? twistFlipPrune;

  /// `class << 4 | symmetry` per raw coordinate, and `symInv`, as flat typed
  /// lists.
  ///
  /// [phase1Cost] runs once per node of the phase 1 search, which is by far the
  /// hottest loop in the solver, so it reads these directly instead of going
  /// through [SymCoord.split] — that returns a record, and allocating two per
  /// node costs more than the lookups themselves.
  late final Uint16List _twistRaw2Sym = Uint16List.fromList(twistSym.raw2sym);
  late final Uint16List _flipRaw2Sym = Uint16List.fromList(flipSym.raw2sym);
  static final Uint8List _symInv = Uint8List.fromList(symInv);

  /// Flat index of the (orientation, slice) pair in a reduced pruning table.
  ///
  /// [raw] is the orientation coordinate. The symmetry that carries the class
  /// representative onto [raw] is read off [SymCoord.raw2sym], and its inverse
  /// is applied to the slice so both coordinates describe the same cube.
  int indexOf(SymCoord coord, int raw, int udslice) {
    final (cls, s) = SymCoord.split(coord.raw2sym[raw]);
    return cls * nUdslice + udsliceConj[(udslice, symInv[s])];
  }

  /// Lower bound on the moves needed to reach phase 2.
  int phase1Cost(int twist, int flip, int udslice) {
    final te = _twistRaw2Sym[twist];
    var best = twistPrune.at((te >> 4) * nUdslice + udsliceConj[(udslice, _symInv[te & 0xF])]);

    final fe = _flipRaw2Sym[flip];
    final fCls = fe >> 4;
    final fInv = _symInv[fe & 0xF];

    final b = flipPrune.at(fCls * nUdslice + udsliceConj[(udslice, fInv)]);
    if (b > best) best = b;

    final tf = twistFlipPrune;
    if (tf == null) {
      return best;
    }
    final c = tf.at(fCls * nTwist + twistConj[(twist, fInv)]);
    return c > best ? c : best;
  }

  int get lengthInBytes =>
      twistMove.lengthInBytes +
      flipMove.lengthInBytes +
      udsliceMove.lengthInBytes +
      udsliceConj.lengthInBytes +
      twistConj.lengthInBytes +
      twistPrune.lengthInBytes +
      flipPrune.lengthInBytes +
      (twistFlipPrune?.lengthInBytes ?? 0);
}

/// Coordinate after each of the 18 face turns, for a coordinate that a cube can
/// be built from directly.
MovingTable _rawMoveTable(
  int rawCount,
  void Function(CubieCube cube, int value) write,
  int Function(CubieCube cube) read,
) {
  final table = MovingTable.filled(rawCount, Phase1Tables.nMoves);
  final cube = CubieCube();

  for (var raw = 0; raw < rawCount; raw++) {
    write(cube, raw);

    for (var face = 0; face < 6; face++) {
      // Three successive quarter turns give the clockwise, half and
      // anticlockwise entries; a fourth restores the starting state.
      for (var power = 0; power < 3; power++) {
        cube.multiply(moveCube[3 * face]);
        table[(raw, 3 * face + power)] = read(cube);
      }
      cube.multiply(moveCube[3 * face]);
    }
  }

  return table;
}

/// Coordinate after conjugating by each of the 16 symmetries.
MovingTable _conjTable(
  int rawCount,
  void Function(CubieCube cube, int value) write,
  int Function(CubieCube cube) read,
) {
  final table = MovingTable.filled(rawCount, symCount);
  for (var raw = 0; raw < rawCount; raw++) {
    final cube = CubieCube();
    write(cube, raw);
    for (var s = 0; s < symCount; s++) {
      table[(raw, s)] = read(conjugate(cube, s));
    }
  }
  return table;
}

/// Breadth-first search over the reduced (orientation, slice) space.
///
/// A reduced state is expanded by putting its class representative back into
/// raw coordinates, applying the move there, and reducing the result again.
/// Symmetries relabel the moves but map the move set onto itself, so exploring
/// all 18 from the representative reaches exactly the same successors as
/// exploring them from any other member of the class.
PruningTable _buildPrune(
  SymCoord coord,
  MovingTable coordMove,
  MovingTable otherMove,
  MovingTable conj,
  int width,
) {
  return fillPruningTable(
    length: coord.classCount * width,
    stride: width,
    moveCount: Phase1Tables.nMoves,
    // A representative fixed by symmetry t puts the same state at more than one
    // index; the move graph does not join them, so they are filled together.
    aliases: (index) sync* {
      final cls = index ~/ width;
      final other = index % width;
      final stabiliser = coord.symState[cls];
      for (var t = 1; t < symCount; t++) {
        if (stabiliser & (1 << t) != 0) {
          yield cls * width + conj[(other, t)];
        }
      }
    },
    successor: (index, move) {
      final cls = index ~/ width;
      final other = index % width;

      final nextRaw = coordMove[(coord.sym2raw[cls], move)];
      final nextOther = otherMove[(other, move)];

      final (nextClass, s) = SymCoord.split(coord.raw2sym[nextRaw]);
      return nextClass * width + conj[(nextOther, symInv[s])];
    },
  );
}
