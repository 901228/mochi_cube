import "dart:io";
import "dart:typed_data";

import "package:app_dirs/app_dirs.dart";
import "package:path/path.dart" as path;

import "../logger.dart";
import "../table_storage.dart";
import "cube/cubie_cube.dart";
import "cube/moves.dart";

class Table {
  // 3^7 possible corner orientations
  static const int nTwist = 2187;
  // 2^11 possible edge flips
  static const int nFlip = 2048;
  // C(12, 4) possible positions of FR, FL, BL, BR
  static const int nUdslice = 495;
  // possible moves: 6(U, R, F, D, L, B) * 3(clockwise, 180, counter-clockwise)
  static const int nMoves = 18;

  // 4! possible permutations of FR, FL, BL, BR
  static const int nEdge4 = 24;
  // 8! possible permutations of UR, UF, UL, UB, DR, DF, DL, DB in phase2
  static const int nEdge8 = 40320;
  // 8! possible permutations of the corners
  static const int nCorner = 40320;

  /// Cache file header: magic, format version, byte-order marker.
  ///
  /// The tables are written as raw host-endian bytes, so the marker rejects a
  /// file produced on a machine with the opposite byte order. Bump [_version]
  /// whenever a table builder changes, so stale caches are rebuilt instead of
  /// being loaded and silently trusted.
  static const List<int> _magic = [0x4D, 0x43, 0x54, 0x42]; // "MCTB"
  static const int _version = 1;
  static const int _byteOrderMark = 0x01020304;
  static const int _headerBytes = 16; // magic(4) + version(4) + bom(4) + reserved(4)

  factory Table() => _instance;
  static final Table _instance = Table._internal();
  Table._internal() {
    _load();
  }

  late MovingTable twistMove;
  late MovingTable flipMove;
  late MovingTable udsliceMove;
  late PruningTable udsliceTwistPrune;
  late PruningTable udsliceFlipPrune;
  late MovingTable edge4Move;
  late MovingTable edge8Move;
  late MovingTable cornerMove;
  late PruningTable edge4Edge8Prune;
  late PruningTable edge4CornerPrune;

  /// Every table in the order they are laid out in the cache file.
  List<int> get _sectionLengths => [
    nTwist * nMoves * 2,
    nFlip * nMoves * 2,
    nUdslice * nMoves * 2,
    nEdge4 * nMoves * 2,
    nEdge8 * nMoves * 2,
    nCorner * nMoves * 2,
    (nUdslice * nTwist + 1) ~/ 2,
    (nUdslice * nFlip + 1) ~/ 2,
    (nEdge4 * nEdge8 + 1) ~/ 2,
    (nEdge4 * nCorner + 1) ~/ 2,
  ];

  int get _expectedBytes => _headerBytes + _sectionLengths.reduce((a, b) => a + b);

  void _load() {
    final appDirectory = getAppDirs(application: "cube_solver").data;
    final tablePath = path.join(appDirectory, "tables.bin");
    final tableFile = File(tablePath);

    if (tableFile.existsSync() && _tryRead(tableFile)) {
      Logging().info("Loaded the tables from $tablePath");
      return;
    }

    Logging().info("Building the tables (no usable cache at $tablePath)");
    _build();

    final parentDirectory = tableFile.parent;
    if (!parentDirectory.existsSync()) {
      parentDirectory.createSync(recursive: true);
    }
    tableFile.writeAsBytesSync(_serialise(), flush: true);
    Logging().info("Wrote the tables into $tablePath (${_expectedBytes ~/ 1024} KB)");
  }

  void _build() {
    // Phase 1 move tables
    twistMove = _makeTwistTable();
    flipMove = _makeFlipTable();
    udsliceMove = _makeUdsliceTable();

    // Phase 1 pruning tables
    udsliceTwistPrune = _makeUdsliceTwistPrune();
    udsliceFlipPrune = _makeUdsliceFlipPrune();

    // Phase 2 move tables
    edge4Move = _makeEdge4Table();
    edge8Move = _makeEdge8Table();
    cornerMove = _makeCornerTable();

    // Phase 2 pruning tables
    edge4Edge8Prune = _makeEdge4Edge8Prune();
    edge4CornerPrune = _makeEdge4CornerPrune();
  }

  // ==========================
  // Cache file
  // ==========================
  Uint8List _serialise() {
    final bytes = Uint8List(_expectedBytes);
    final header = ByteData.sublistView(bytes, 0, _headerBytes);
    for (var i = 0; i < _magic.length; i++) {
      header.setUint8(i, _magic[i]);
    }
    header.setUint32(4, _version, Endian.host);
    header.setUint32(8, _byteOrderMark, Endian.host);

    var offset = _headerBytes;
    void put(Uint8List section) {
      bytes.setRange(offset, offset + section.length, section);
      offset += section.length;
    }

    Uint8List viewOf(TypedData d) => Uint8List.sublistView(d);

    for (final t in [twistMove, flipMove, udsliceMove, edge4Move, edge8Move, cornerMove]) {
      put(viewOf(t.data));
    }
    for (final t in [udsliceTwistPrune, udsliceFlipPrune, edge4Edge8Prune, edge4CornerPrune]) {
      put(t.data);
    }

    assert(offset == _expectedBytes);
    return bytes;
  }

  /// Returns true when the file was a cache this build can use.
  bool _tryRead(File file) {
    final Uint8List bytes;
    try {
      bytes = file.readAsBytesSync();
    } on FileSystemException catch (e) {
      Logging().warning("Cannot read the tables file: $e");
      return false;
    }

    if (bytes.length != _expectedBytes) {
      Logging().warning("Tables file has the wrong size, rebuilding");
      return false;
    }
    final header = ByteData.sublistView(bytes, 0, _headerBytes);
    for (var i = 0; i < _magic.length; i++) {
      if (header.getUint8(i) != _magic[i]) {
        Logging().warning("Tables file has a bad magic number, rebuilding");
        return false;
      }
    }
    if (header.getUint32(4, Endian.host) != _version) {
      Logging().warning("Tables file has an outdated version, rebuilding");
      return false;
    }
    if (header.getUint32(8, Endian.host) != _byteOrderMark) {
      Logging().warning("Tables file has a different byte order, rebuilding");
      return false;
    }

    var offset = _headerBytes;
    final lengths = _sectionLengths;
    var section = 0;

    // A Uint16List view needs its own copy: `bytes` is not guaranteed to be
    // aligned to a two-byte boundary once offset by the header.
    MovingTable readMove(int rows) {
      final length = lengths[section++];
      final u16 = Uint16List(rows * nMoves);
      Uint8List.sublistView(u16).setRange(0, length, bytes, offset);
      offset += length;
      return MovingTable(u16, rows, nMoves);
    }

    PruningTable readPrune(int entries, int stride) {
      final length = lengths[section++];
      final u8 = Uint8List(length);
      u8.setRange(0, length, bytes, offset);
      offset += length;
      return PruningTable(u8, stride, entries);
    }

    twistMove = readMove(nTwist);
    flipMove = readMove(nFlip);
    udsliceMove = readMove(nUdslice);
    edge4Move = readMove(nEdge4);
    edge8Move = readMove(nEdge8);
    cornerMove = readMove(nCorner);

    udsliceTwistPrune = readPrune(nUdslice * nTwist, nTwist);
    udsliceFlipPrune = readPrune(nUdslice * nFlip, nFlip);
    edge4Edge8Prune = readPrune(nEdge4 * nEdge8, nEdge8);
    edge4CornerPrune = readPrune(nEdge4 * nCorner, nCorner);

    return true;
  }

  // ==========================
  // Phase 1 moving tables
  // ==========================
  MovingTable _makeTwistTable() {
    final twistMoves = MovingTable.filled(nTwist, nMoves);
    final a = CubieCube();
    for (var i = 0; i < nTwist; i++) {
      // apply the current state
      a.twist = i;

      for (var j = 0; j < 6; j++) {
        // iterate the clockwise, 180 and counter-clockwise moves
        for (var k = 0; k < 3; k++) {
          a.cornerMultiply(moveCube[j]);
          twistMoves[(i, 3 * j + k)] = a.twist;
        }

        // recover the cube state (by turning the last 90 degrees)
        a.cornerMultiply(moveCube[j]);
      }
    }

    return twistMoves;
  }

  MovingTable _makeFlipTable() {
    final flipMoves = MovingTable.filled(nFlip, nMoves);
    final a = CubieCube();
    for (var i = 0; i < nFlip; i++) {
      // apply the current state
      a.flip = i;

      for (var j = 0; j < 6; j++) {
        // iterate the clockwise, 180 and counter-clockwise moves
        for (var k = 0; k < 3; k++) {
          a.edgeMultiply(moveCube[j]);
          flipMoves[(i, 3 * j + k)] = a.flip;
        }

        // recover the cube state (by turning the last 90 degrees)
        a.edgeMultiply(moveCube[j]);
      }
    }

    return flipMoves;
  }

  MovingTable _makeUdsliceTable() {
    final udsliceMoves = MovingTable.filled(nUdslice, nMoves);
    final a = CubieCube();
    for (var i = 0; i < nUdslice; i++) {
      // apply the current state
      a.udslice = i;

      for (var j = 0; j < 6; j++) {
        // iterate the clockwise, 180 and counter-clockwise moves
        for (var k = 0; k < 3; k++) {
          a.edgeMultiply(moveCube[j]);
          udsliceMoves[(i, 3 * j + k)] = a.udslice;
        }

        // recover the cube state (by turning the last 90 degrees)
        a.edgeMultiply(moveCube[j]);
      }
    }

    return udsliceMoves;
  }

  // ==========================
  // Phase 1 pruning tables
  // ==========================

  PruningTable _makeUdsliceTwistPrune() => fillPruningTable(
    length: nUdslice * nTwist,
    stride: nTwist,
    moveCount: nMoves,
    successor: (i, j) => udsliceMove[(i ~/ nTwist, j)] * nTwist + twistMove[(i % nTwist, j)],
  );

  PruningTable _makeUdsliceFlipPrune() => fillPruningTable(
    length: nUdslice * nFlip,
    stride: nFlip,
    moveCount: nMoves,
    successor: (i, j) => udsliceMove[(i ~/ nFlip, j)] * nFlip + flipMove[(i % nFlip, j)],
  );

  // ==========================
  // Phase 2 moving tables
  // ==========================

  /// Half turns of R, F, L and B leave the phase 2 subgroup, so quarter turns of
  /// those four faces are marked as illegal.
  static bool _illegalInPhase2(int face, int power) => power % 2 == 0 && face % 3 != 0;

  MovingTable _makeEdge4Table() {
    final edge4Moves = MovingTable.filled(nEdge4, nMoves);
    final a = CubieCube();
    for (var i = 0; i < nEdge4; i++) {
      // apply the current state
      a.edge4 = i;

      for (var j = 0; j < 6; j++) {
        // iterate the clockwise, 180 and counter-clockwise moves
        for (var k = 0; k < 3; k++) {
          a.edgeMultiply(moveCube[j]);
          edge4Moves[(i, 3 * j + k)] = _illegalInPhase2(j, k) ? -1 : a.edge4;
        }

        // recover the cube state (by turning the last 90 degrees)
        a.edgeMultiply(moveCube[j]);
      }
    }

    return edge4Moves;
  }

  MovingTable _makeEdge8Table() {
    final edge8Moves = MovingTable.filled(nEdge8, nMoves);
    final a = CubieCube();
    for (var i = 0; i < nEdge8; i++) {
      // apply the current state
      a.edge8 = i;

      for (var j = 0; j < 6; j++) {
        // iterate the clockwise, 180 and counter-clockwise moves
        for (var k = 0; k < 3; k++) {
          a.edgeMultiply(moveCube[j]);
          edge8Moves[(i, 3 * j + k)] = _illegalInPhase2(j, k) ? -1 : a.edge8;
        }

        // recover the cube state (by turning the last 90 degrees)
        a.edgeMultiply(moveCube[j]);
      }
    }

    return edge8Moves;
  }

  MovingTable _makeCornerTable() {
    final cornerMoves = MovingTable.filled(nCorner, nMoves);
    final a = CubieCube();
    for (var i = 0; i < nCorner; i++) {
      // apply the current state
      a.corner = i;

      for (var j = 0; j < 6; j++) {
        // iterate the clockwise, 180 and counter-clockwise moves
        for (var k = 0; k < 3; k++) {
          a.cornerMultiply(moveCube[j]);
          cornerMoves[(i, 3 * j + k)] = _illegalInPhase2(j, k) ? -1 : a.corner;
        }

        // recover the cube state (by turning the last 90 degrees)
        a.cornerMultiply(moveCube[j]);
      }
    }

    return cornerMoves;
  }

  // ==========================
  // Phase 2 pruning tables
  // ==========================
  PruningTable _makeEdge4Edge8Prune() => fillPruningTable(
    length: nEdge4 * nEdge8,
    stride: nEdge8,
    moveCount: nMoves,
    successor: (i, j) {
      final e4 = edge4Move[(i ~/ nEdge8, j)];
      final e8 = edge8Move[(i % nEdge8, j)];
      return (e4 < 0 || e8 < 0) ? -1 : e4 * nEdge8 + e8;
    },
  );

  PruningTable _makeEdge4CornerPrune() => fillPruningTable(
    length: nEdge4 * nCorner,
    stride: nCorner,
    moveCount: nMoves,
    successor: (i, j) {
      final e4 = edge4Move[(i ~/ nCorner, j)];
      final c = cornerMove[(i % nCorner, j)];
      return (e4 < 0 || c < 0) ? -1 : e4 * nCorner + c;
    },
  );
}
