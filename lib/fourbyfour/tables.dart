import "dart:typed_data";

import "../logger.dart";
import "../table_storage.dart";
import "center1.dart";
import "center2.dart";
import "center3.dart";
import "edge3.dart";

/// The tables behind the 4x4x4 solver.
///
/// Four of the five are small and quick to work out. The two that are not —
/// phase 1's move table and phase 3's wing table, 2.2 MB and 7.75 MB — are what
/// the cache file holds, and building them is most of the several seconds a
/// first solve takes on a machine with a filesystem. Where there is none, as on
/// the web, they are built again each session unless the host ships the file;
/// see `useTableBytesLoader`.
abstract final class FourByFourTables {
  static bool _ready = false;

  /// The cache file. Bump the version whenever a builder changes: the file is
  /// indexed by the symmetry numbering of [Center1] and [Edge3] and checks
  /// neither.
  static const TableFile _cache = TableFile(
    name: TableFiles.fourByFour,
    magic: [0x34, 0x58, 0x34, 0x54], // "4X4T"
    version: 1,
  );

  /// Build or load everything. Does nothing after the first time.
  static void init() {
    if (_ready) return;

    Center1.initSym();

    final cached = _cache.read([Center1.ctsmv.lengthInBytes, Edge3.eprun.lengthInBytes]);
    if (cached != null) {
      Center1.initSym2Raw();
      Uint8List.sublistView(Center1.ctsmv).setAll(0, cached[0]);
      Center1.createPrun();
      Center2.init();
      Center3.init();
      Edge3.initMvrot();
      Edge3.initRaw2Sym();
      Edge3.eprun.setAll(0, cached[1]);
      Edge3.done = Edge3.nEprun;
      Logging().info("Loaded the 4x4x4 tables from ${_cache.location}");
    } else {
      Logging().info("Building the 4x4x4 tables");
      Center1.raw2sym = Int32List(Center1.nRaw);
      Center1.initSym2Raw();
      Center1.createMoveTable();
      Center1.raw2sym = null;
      Center1.createPrun();
      Center2.init();
      Center3.init();
      Edge3.initMvrot();
      Edge3.initRaw2Sym();
      Edge3.createPrun();
      _cache.write([Uint8List.sublistView(Center1.ctsmv), Edge3.eprun]);
    }
    _ready = true;
  }

  /// How big the tables are in memory.
  static int get lengthInBytes {
    init();
    return Center1.ctsmv.lengthInBytes +
        Center1.csprun.lengthInBytes +
        Center2.ctmv.lengthInBytes +
        Center2.ctprun.lengthInBytes +
        Center3.ctmove.lengthInBytes +
        Edge3.eprun.lengthInBytes;
  }
}
