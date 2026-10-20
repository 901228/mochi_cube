import "dart:typed_data";

import "../logger.dart";
import "../table_storage.dart";
import "cubie.dart";

/// The tables behind the FTO solver, from fto3phase's `FtoCoord`.
///
/// Every move table is small and quick to work out. Of the pruning tables, the
/// one phase 2 has for its edges and triangles together covers 11289600
/// states and is the one worth caching: 11 MB at a byte each, since it runs
/// deeper than a nibble holds.
abstract final class FtoTables {
  /// The moves of each phase, as fto3phase numbers them. Each phase gives up
  /// some, as Kociemba's algorithm does: F, BR and BL after phase 1, U after
  /// phase 2.
  static const List<int> g1Moveset = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
  static const List<int> g2Moveset = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
  static const List<int> g3Moveset = [0, 1, 2, 3, 4, 5, 8, 9];

  static late final Uint16List g1EdgeMoves;
  static late final Uint16List g1TriangleMoves;
  static late final Uint16List g2TriangleMoves;
  static late final Uint16List g2EdgeMoves;
  static late final Uint16List g2TripleMoves;
  static late final Uint16List g3EdgeMoves;
  static late final Uint16List g3CornerMoves;

  static late final Uint8List g1Prun;
  static late final Uint8List g2TriplePrun;
  static late final Uint8List g2TxEPrun;
  static late final Uint8List g3CornerPrun;

  static late final int solvedG3Edges;
  static late final int solvedG3Corners;

  static bool _ready = false;

  /// The cache file. Bump the version whenever a builder or a numbering in
  /// [FtoCubie] changes: the file is indexed by them and checks neither.
  static const TableFile _cache = TableFile(
    name: TableFiles.fto,
    magic: [0x46, 0x54, 0x4F, 0x54], // "FTOT"
    version: 1,
  );

  static int get _txeLength => FtoCoord.g2EdgesSize * FtoCoord.g2TrianglesSize;

  static void init() {
    if (_ready) return;

    g1EdgeMoves = _moveTable(
      FtoCoord.g1EdgesSize,
      16,
      g1Moveset,
      (c, i) => c.g1SetEdges(i),
      (c) => c.g1PackEdges(),
    );
    g1TriangleMoves = _moveTable(
      FtoCoord.g1TrianglesSize,
      16,
      g1Moveset,
      (c, i) => c.g1SetTriangles(i),
      (c) => c.g1PackTriangles(),
    );
    g1Prun = _bfs(FtoCoord.g1EdgesSize * FtoCoord.g1TrianglesSize, g1Moveset, [
      FtoCubie().g1PackEdges() * FtoCoord.g1TrianglesSize + FtoCubie().g1PackTriangles(),
    ], _turnG1);

    g2TriangleMoves = _moveTable(
      FtoCoord.g2TrianglesSize,
      10,
      g2Moveset,
      (c, i) => c.g2SetTriangles(i),
      (c) => c.g2PackTriangles(),
    );
    g2EdgeMoves = _moveTable(
      FtoCoord.g2EdgesSize,
      10,
      g2Moveset,
      (c, i) => c.g2SetEdges(i),
      (c) => c.g2PackEdges(),
    );
    g2TripleMoves = _moveTable(
      FtoCoord.g2TripleSize,
      10,
      g2Moveset,
      (c, i) => c.g2SetTriples(i, 0),
      (c) => c.g2PackTriples(0),
    );
    g2TriplePrun = _bfs(
      FtoCoord.g2TripleSize,
      g2Moveset,
      _solvedTriples(),
      (i, m) => g2TripleMoves[i * 10 + m],
    );

    g3EdgeMoves = _moveTable(
      FtoCoord.g3EdgeSize,
      10,
      g3Moveset,
      (c, i) => c.g3SetEdges(i),
      (c) => c.g3PackEdges(),
    );
    g3CornerMoves = _moveTable(
      FtoCoord.g3CornersSize,
      10,
      g3Moveset,
      (c, i) => c.g3SetCorners(i),
      (c) => c.g3PackCorners(),
    );
    solvedG3Edges = FtoCubie().g3PackEdges();
    solvedG3Corners = FtoCubie().g3PackCorners();
    g3CornerPrun = _bfs(FtoCoord.g3CornersSize, g3Moveset, [
      solvedG3Corners,
    ], (i, m) => g3CornerMoves[i * 10 + m]);

    final cached = _cache.read([_txeLength]);
    if (cached != null) {
      g2TxEPrun = cached[0];
      Logging().info("Loaded the FTO tables from ${_cache.location}");
    } else {
      g2TxEPrun = _buildTxE();
      _cache.write([g2TxEPrun]);
    }
    _ready = true;
  }

  static int lengthInBytes() {
    init();
    return g1EdgeMoves.lengthInBytes +
        g1TriangleMoves.lengthInBytes +
        g2TriangleMoves.lengthInBytes +
        g2EdgeMoves.lengthInBytes +
        g2TripleMoves.lengthInBytes +
        g3EdgeMoves.lengthInBytes +
        g3CornerMoves.lengthInBytes +
        g1Prun.lengthInBytes +
        g2TriplePrun.lengthInBytes +
        g2TxEPrun.lengthInBytes +
        g3CornerPrun.lengthInBytes;
  }

  /// Phase 2's table for the edges and triangles, a byte each: it runs 16
  /// deep, past what the shared nibble tables hold. Built by frontier, as
  /// fto3phase builds it.
  static Uint8List _buildTxE() {
    final solved = FtoCubie();
    final table = Uint8List(_txeLength)..fillRange(0, _txeLength, 255);
    var frontier = Int32List(1)
      ..[0] = solved.g2PackEdges() * FtoCoord.g2TrianglesSize + solved.g2PackTriangles();
    var size = 1;
    table[frontier[0]] = 0;
    for (var depth = 0; size > 0; depth++) {
      var next = Int32List(1024);
      var nextSize = 0;
      for (var i = 0; i < size; i++) {
        final idx = frontier[i];
        for (final move in g2Moveset) {
          final turned = _turnTxE(idx, move);
          if (table[turned] == 255) {
            table[turned] = depth + 1;
            if (nextSize == next.length) next = Int32List(next.length * 2)..setAll(0, next);
            next[nextSize++] = turned;
          }
        }
      }
      frontier = next;
      size = nextSize;
    }
    return table;
  }

  static int _turnG1(int idx, int move) {
    final edge = idx ~/ FtoCoord.g1TrianglesSize;
    final tri = idx % FtoCoord.g1TrianglesSize;
    return g1EdgeMoves[edge * 16 + move] * FtoCoord.g1TrianglesSize + g1TriangleMoves[tri * 16 + move];
  }

  static int _turnTxE(int idx, int move) {
    final edge = idx ~/ FtoCoord.g2TrianglesSize;
    final tri = idx % FtoCoord.g2TrianglesSize;
    return g2EdgeMoves[edge * 10 + move] * FtoCoord.g2TrianglesSize + g2TriangleMoves[tri * 10 + move];
  }

  /// Phase 1's bound for a state.
  static int g1Bound(int edge, int tris) => g1Prun[edge * FtoCoord.g1TrianglesSize + tris];

  /// Phase 2's bound for the edges and triangles.
  static int g2TxEBound(int edge, int tris) => g2TxEPrun[edge * FtoCoord.g2TrianglesSize + tris];

  /// The states of one colour's triples that count as solved: any its three
  /// corners and triangles reach with the moves phase 3 keeps, since those
  /// never part them.
  static List<int> _solvedTriples() {
    final seen = <int>{FtoCubie().g2PackTriples(0)};
    var frontier = [...seen];
    while (frontier.isNotEmpty) {
      final next = <int>[];
      for (final idx in frontier) {
        for (final move in g3Moveset) {
          final turned = g2TripleMoves[idx * 10 + move];
          if (seen.add(turned)) next.add(turned);
        }
      }
      frontier = next;
    }
    return [...seen];
  }

  static Uint16List _moveTable(
    int size,
    int columns,
    List<int> moveset,
    void Function(FtoCubie, int) set,
    int Function(FtoCubie) pack,
  ) {
    final table = Uint16List(size * columns);
    final fto = FtoCubie();
    final turned = FtoCubie();
    for (var idx = 0; idx < size; idx++) {
      set(fto, idx);
      for (final move in moveset) {
        fto.turnInto(move, turned);
        table[idx * columns + move] = pack(turned);
      }
    }
    return table;
  }

  /// Distances from [roots] under [moveset], one byte each.
  static Uint8List _bfs(int size, List<int> moveset, List<int> roots, int Function(int, int) turn) {
    final prun = Uint8List(size)..fillRange(0, size, 255);
    var frontier = roots;
    for (final root in roots) {
      prun[root] = 0;
    }
    var depth = 0;
    while (frontier.isNotEmpty) {
      final next = <int>[];
      for (final idx in frontier) {
        for (final move in moveset) {
          final turned = turn(idx, move);
          if (prun[turned] == 255) {
            prun[turned] = depth + 1;
            next.add(turned);
          }
        }
      }
      frontier = next;
      depth++;
    }
    return prun;
  }
}
