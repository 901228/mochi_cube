import "../logger.dart";
import "../puzzle/cube/cubie_cube.dart";
import "../puzzle/cube/moves.dart";
import "../table_storage.dart";
import "coordinates.dart";

/// Move and distance tables for the 2x2x2.
///
/// The 3x3x3 needs a two-phase search because its state space is far too large
/// to enumerate. A 2x2x2 has 3674160 states, so one breadth-first search holds
/// the exact number of moves to solve **every** one of them. That makes the
/// solver a walk downhill rather than a search, and every solution it returns
/// is optimal.
///
/// The table is a nibble per state, 1.75 MB. God's number for the 2x2x2 is 11
/// in the half-turn metric, so a distance always fits.
class PocketTables {
  factory PocketTables() => _instance;
  static final PocketTables _instance = PocketTables._internal();

  /// The cache file. Bump the version whenever a builder below changes.
  static TableFile get _cache => const TableFile(
    name: "pocket.bin",
    magic: [0x50, 0x4B, 0x54, 0x32], // "PKT2"
    version: 1,
  );

  static List<int> get _sectionLengths => [
    nCperm7 * nPocketMoves * 2,
    nTwist6 * nPocketMoves * 2,
    (nStates + 1) ~/ 2,
  ];

  PocketTables._internal() {
    final cached = _cache.read(_sectionLengths);
    if (cached != null) {
      cpermMove = movingTableFromBytes(cached[0], nCperm7, nPocketMoves);
      twistMove = movingTableFromBytes(cached[1], nTwist6, nPocketMoves);
      distance = PruningTable(cached[2], nTwist6, nStates);
      Logging().info("Loaded the pocket cube tables from ${_cache.location}");
      return;
    }

    cpermMove = _moveTable(nCperm7, (c, v) => c.cperm7 = v, (c) => c.cperm7);
    twistMove = _moveTable(nTwist6, (c, v) => c.twist6 = v, (c) => c.twist6);
    distance = fillPruningTable(
      length: nStates,
      stride: nTwist6,
      moveCount: nPocketMoves,
      successor: (index, move) =>
          cpermMove[(index ~/ nTwist6, move)] * nTwist6 + twistMove[(index % nTwist6, move)],
    );

    _cache.write([movingTableBytes(cpermMove), movingTableBytes(twistMove), distance.data]);
  }

  /// Coordinate after each of the nine turns.
  late final MovingTable cpermMove;
  late final MovingTable twistMove;

  /// Moves needed to solve, for every state. Indexed `cperm7 * 729 + twist6`.
  late final PruningTable distance;

  /// The flat index of a state.
  int indexOf(int cperm7, int twist6) => cperm7 * nTwist6 + twist6;

  /// Moves needed to solve this state. Exact, not a bound.
  int distanceOf(int cperm7, int twist6) => distance.at(indexOf(cperm7, twist6));

  /// The state reached from [index] by [move].
  int successor(int index, int move) =>
      cpermMove[(index ~/ nTwist6, move)] * nTwist6 + twistMove[(index % nTwist6, move)];

  int get lengthInBytes => cpermMove.lengthInBytes + twistMove.lengthInBytes + distance.lengthInBytes;
}

MovingTable _moveTable(
  int rawCount,
  void Function(CubieCube cube, int value) write,
  int Function(CubieCube cube) read,
) {
  final table = MovingTable.filled(rawCount, nPocketMoves);
  for (var raw = 0; raw < rawCount; raw++) {
    for (var i = 0; i < nPocketMoves; i++) {
      final cube = CubieCube();
      write(cube, raw);
      cube.moveIndex(pocketMoves[i]);
      table[(raw, i)] = read(cube);
    }
  }
  return table;
}
