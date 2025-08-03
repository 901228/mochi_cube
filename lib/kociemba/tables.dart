import "dart:convert";
import "dart:io";

import "package:app_dirs/app_dirs.dart";
import "package:cube_solver/logger.dart";
import "package:json_annotation/json_annotation.dart";
import "package:path/path.dart" as path;

import "cube/cubie_cube.dart";
import "cube/moves.dart";

part "tables.g.dart";

@JsonSerializable()
class MovingTable {
  final List<List<int>> table;

  MovingTable(this.table);

  operator [](int index) => table[index];

  factory MovingTable.fromJson(Map<String, dynamic> json) => _$MovingTableFromJson(json);
  Map<String, dynamic> toJson() => _$MovingTableToJson(this);
}

@JsonSerializable()
class PruningTable {
  final List<int> table;
  final int stride;

  PruningTable(this.table, this.stride);

  int operator []((int, int) x) => table[x.$1 * stride + x.$2];

  factory PruningTable.fromJson(Map<String, dynamic> json) => _$PruningTableFromJson(json);
  Map<String, dynamic> toJson() => _$PruningTableToJson(this);
}

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
  void _load() {
    final appDirectory = getAppDirs(application: "cube_solver").data;
    final tablePath = path.join(appDirectory, "tables.json");
    final tableFile = File(tablePath);

    if (tableFile.existsSync()) {
      Logging().info("Found the tables file at $tablePath");

      // read tables from file
      final rawData = tableFile.readAsStringSync();
      final jsonData = jsonDecode(rawData);

      twistMove = MovingTable.fromJson(jsonData["twistMove"]);
      flipMove = MovingTable.fromJson(jsonData["flipMove"]);
      udsliceMove = MovingTable.fromJson(jsonData["udsliceMove"]);

      udsliceTwistPrune = PruningTable.fromJson(jsonData["udsliceTwistPrune"]);
      udsliceFlipPrune = PruningTable.fromJson(jsonData["udsliceFlipPrune"]);

      edge4Move = MovingTable.fromJson(jsonData["edge4Move"]);
      edge8Move = MovingTable.fromJson(jsonData["edge8Move"]);
      cornerMove = MovingTable.fromJson(jsonData["cornerMove"]);

      edge4Edge8Prune = PruningTable.fromJson(jsonData["edge4Edge8Prune"]);
      edge4CornerPrune = PruningTable.fromJson(jsonData["edge4CornerPrune"]);
    } else {
      Logging().info("Cannot find the tables file at $tablePath");

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

      final parentDirectory = tableFile.parent;
      if (!parentDirectory.existsSync()) {
        parentDirectory.createSync(recursive: true);
      }

      // store tables in file
      final jsonData = {
        "twistMove": twistMove,
        "flipMove": flipMove,
        "udsliceMove": udsliceMove,
        "udsliceTwistPrune": udsliceTwistPrune,
        "udsliceFlipPrune": udsliceFlipPrune,
        "edge4Move": edge4Move,
        "edge8Move": edge8Move,
        "cornerMove": cornerMove,
        "edge4Edge8Prune": edge4Edge8Prune,
        "edge4CornerPrune": edge4CornerPrune,
      };
      final rawData = jsonEncode(jsonData);
      tableFile.writeAsStringSync(rawData, mode: FileMode.writeOnly);

      Logging().info("Write the tables into $tablePath");
    }
  }

  // ==========================
  // Phase 1 moving tables
  // ==========================
  MovingTable _makeTwistTable() {
    final twistMoves = List.generate(nTwist, (_) => List.filled(nMoves, 0), growable: false);
    final a = CubieCube();
    for (var i = 0; i < nTwist; i++) {
      // apply the current state
      a.twist = i;

      for (var j = 0; j < 6; j++) {
        // iterate the clockwise, 180 and counter-clockwise moves
        for (var k = 0; k < 3; k++) {
          a.cornerMultiply(moveCube[j]);
          twistMoves[i][3 * j + k] = a.twist;
        }

        // recover the cube state (by turning the last 90 degrees)
        a.cornerMultiply(moveCube[j]);
      }
    }

    return MovingTable(twistMoves);
  }

  MovingTable _makeFlipTable() {
    final flipMoves = List.generate(nFlip, (_) => List.filled(nMoves, 0), growable: false);
    final a = CubieCube();
    for (var i = 0; i < nFlip; i++) {
      // apply the current state
      a.flip = i;

      for (var j = 0; j < 6; j++) {
        // iterate the clockwise, 180 and counter-clockwise moves
        for (var k = 0; k < 3; k++) {
          a.edgeMultiply(moveCube[j]);
          flipMoves[i][3 * j + k] = a.flip;
        }

        // recover the cube state (by turning the last 90 degrees)
        a.edgeMultiply(moveCube[j]);
      }
    }

    return MovingTable(flipMoves);
  }

  MovingTable _makeUdsliceTable() {
    final udsliceMoves = List.generate(nUdslice, (_) => List.filled(nMoves, 0), growable: false);
    final a = CubieCube();
    for (var i = 0; i < nUdslice; i++) {
      // apply the current state
      a.udslice = i;

      for (var j = 0; j < 6; j++) {
        // iterate the clockwise, 180 and counter-clockwise moves
        for (var k = 0; k < 3; k++) {
          a.edgeMultiply(moveCube[j]);
          udsliceMoves[i][3 * j + k] = a.udslice;
        }

        // recover the cube state (by turning the last 90 degrees)
        a.edgeMultiply(moveCube[j]);
      }
    }

    return MovingTable(udsliceMoves);
  }

  // ==========================
  // Phase 1 pruning tables
  // ==========================
  PruningTable _makeUdsliceTwistPrune() {
    const int tableSize = nUdslice * nTwist;
    final udsliceTwistPrune = List.filled(tableSize, -1);
    udsliceTwistPrune[0] = 0;
    int count = 1;
    int depth = 0;

    while (count < tableSize) {
      for (var i = 0; i < tableSize; i++) {
        if (udsliceTwistPrune[i] == depth) {
          for (var j = 0; j < nMoves; j++) {
            final int x = udsliceMove[i ~/ nTwist][j] * nTwist + twistMove[i % nTwist][j];
            if (udsliceTwistPrune[x] == -1) {
              count++;
              udsliceTwistPrune[x] = depth + 1;
            }
          }
        }
      }

      depth++;
    }

    return PruningTable(udsliceTwistPrune, nTwist);
  }

  PruningTable _makeUdsliceFlipPrune() {
    const int tableSize = nUdslice * nFlip;
    final udsliceFlipPrune = List.filled(tableSize, -1);
    udsliceFlipPrune[0] = 0;
    int count = 1;
    int depth = 0;

    while (count < tableSize) {
      for (var i = 0; i < tableSize; i++) {
        if (udsliceFlipPrune[i] == depth) {
          final m = List.generate(nMoves, (j) => udsliceMove[i ~/ nFlip][j] * nFlip + flipMove[i % nFlip][j]);
          for (final x in m) {
            if (udsliceFlipPrune[x] == -1) {
              count++;
              udsliceFlipPrune[x] = depth + 1;
            }
          }
        }
      }

      depth++;
    }

    return PruningTable(udsliceFlipPrune, nFlip);
  }

  // ==========================
  // Phase 2 moving tables
  // ==========================
  MovingTable _makeEdge4Table() {
    final edge4Moves = List.generate(nEdge4, (_) => List.filled(nMoves, 0), growable: false);
    final a = CubieCube();
    for (var i = 0; i < nEdge4; i++) {
      // apply the current state
      a.edge4 = i;

      for (var j = 0; j < 6; j++) {
        // iterate the clockwise, 180 and counter-clockwise moves
        for (var k = 0; k < 3; k++) {
          a.edgeMultiply(moveCube[j]);

          edge4Moves[i][3 * j + k] = (k % 2 == 0 && j % 3 != 0) ? -1 : a.edge4;
        }

        // recover the cube state (by turning the last 90 degrees)
        a.edgeMultiply(moveCube[j]);
      }
    }

    return MovingTable(edge4Moves);
  }

  MovingTable _makeEdge8Table() {
    final edge8Moves = List.generate(nEdge8, (_) => List.filled(nMoves, 0), growable: false);
    final a = CubieCube();
    for (var i = 0; i < nEdge8; i++) {
      // apply the current state
      a.edge8 = i;

      for (var j = 0; j < 6; j++) {
        // iterate the clockwise, 180 and counter-clockwise moves
        for (var k = 0; k < 3; k++) {
          a.edgeMultiply(moveCube[j]);

          edge8Moves[i][3 * j + k] = (k % 2 == 0 && j % 3 != 0) ? -1 : a.edge8;
        }

        // recover the cube state (by turning the last 90 degrees)
        a.edgeMultiply(moveCube[j]);
      }
    }

    return MovingTable(edge8Moves);
  }

  MovingTable _makeCornerTable() {
    final cornerMoves = List.generate(nCorner, (_) => List.filled(nMoves, 0), growable: false);
    final a = CubieCube();
    for (var i = 0; i < nCorner; i++) {
      // apply the current state
      a.corner = i;

      for (var j = 0; j < 6; j++) {
        // iterate the clockwise, 180 and counter-clockwise moves
        for (var k = 0; k < 3; k++) {
          a.cornerMultiply(moveCube[j]);

          cornerMoves[i][3 * j + k] = (k % 2 == 0 && j % 3 != 0) ? -1 : a.corner;
        }

        // recover the cube state (by turning the last 90 degrees)
        a.cornerMultiply(moveCube[j]);
      }
    }

    return MovingTable(cornerMoves);
  }

  // ==========================
  // Phase 2 pruning tables
  // ==========================
  PruningTable _makeEdge4Edge8Prune() {
    const int tableSize = nEdge4 * nEdge8;
    final edge4Edge8Prune = List.filled(tableSize, -1);
    edge4Edge8Prune[0] = 0;
    int count = 1;
    int depth = 0;

    while (count < tableSize) {
      for (var i = 0; i < tableSize; i++) {
        if (edge4Edge8Prune[i] == depth) {
          for (var j = 0; j < nMoves; j++) {
            int x = edge4Move[i ~/ nEdge8][j] * nEdge8 + edge8Move[i % nEdge8][j];
            if (x < 0) {
              x += tableSize;
            }
            if (edge4Edge8Prune[x] == -1) {
              count++;
              edge4Edge8Prune[x] = depth + 1;
            }
          }
        }
      }

      depth++;
    }

    return PruningTable(edge4Edge8Prune, nEdge8);
  }

  PruningTable _makeEdge4CornerPrune() {
    const int tableSize = nEdge4 * nCorner;
    final edge4CornerPrune = List.filled(tableSize, -1);
    edge4CornerPrune[0] = 0;
    int count = 1;
    int depth = 0;

    while (count < tableSize) {
      for (var i = 0; i < tableSize; i++) {
        if (edge4CornerPrune[i] == depth) {
          for (var j = 0; j < nMoves; j++) {
            int x = edge4Move[i ~/ nCorner][j] * nCorner + cornerMove[i % nCorner][j];
            if (x < 0) {
              x += tableSize;
            }
            if (edge4CornerPrune[x] == -1) {
              count++;
              edge4CornerPrune[x] = depth + 1;
            }
          }
        }
      }

      depth++;
    }

    return PruningTable(edge4CornerPrune, nCorner);
  }
}
