import "dart:typed_data";

import "cache/table_store.dart" if (dart.library.io) "cache/table_store_io.dart";
import "logger.dart";

export "cache/table_store.dart"
    if (dart.library.io) "cache/table_store_io.dart"
    show readTableBytes, tableDirectory, tablePath, writeTableBytes;

/// A `rows * columns` grid of small non-negative integers, stored flat.
///
/// Indexed by a record, `table[(row, column)]`, so that a lookup never
/// allocates the intermediate row a chained `[][]` would need.
///
/// [illegal] stands in for -1, which the phase 2 move tables use to mark turns
/// that leave the subgroup.
class MovingTable {
  static const int illegal = 0xFFFF;

  final Uint16List data;
  final int rows;
  final int columns;

  MovingTable(this.data, this.rows, this.columns);

  MovingTable.filled(this.rows, this.columns) : data = Uint16List(rows * columns);

  int operator []((int, int) x) {
    final v = data[x.$1 * columns + x.$2];
    return v == illegal ? -1 : v;
  }

  void operator []=((int, int) x, int value) {
    data[x.$1 * columns + x.$2] = value < 0 ? illegal : value;
  }

  int get lengthInBytes => data.lengthInBytes;
}

/// A lower bound on the number of moves to a goal state, one nibble per entry.
///
/// Every table in this package tops out well below 15, so a depth fits in 4
/// bits and [unvisited] is free as the "not filled in yet" marker.
class PruningTable {
  static const int unvisited = 0xF;

  final Uint8List data;
  final int stride;
  final int length;

  PruningTable(this.data, this.stride, this.length);

  /// A table of [length] entries, every one marked [unvisited].
  PruningTable.filled(this.length, this.stride)
    : data = Uint8List((length + 1) ~/ 2)..fillRange(0, (length + 1) ~/ 2, 0xFF);

  /// Read by flat index. Used while building the table.
  int at(int index) {
    final b = data[index >> 1];
    return (index & 1) == 0 ? b & 0xF : b >> 4;
  }

  /// Write by flat index. [value] must fit in 4 bits.
  void setAt(int index, int value) {
    assert(value >= 0 && value <= 0xF);
    final byteIndex = index >> 1;
    final b = data[byteIndex];
    data[byteIndex] = (index & 1) == 0 ? (b & 0xF0) | value : (b & 0x0F) | (value << 4);
  }

  /// Read by coordinate pair.
  int operator []((int, int) x) => at(x.$1 * stride + x.$2);

  int get lengthInBytes => data.lengthInBytes;
}

/// Breadth-first fill of a pruning table.
///
/// [successor] maps a flat index and a move to the flat index it leads to, or
/// to a negative number when that move is not allowed.
///
/// [aliases] lists the other indices that describe the same state as the given
/// one. A symmetry-reduced table needs it: a class whose representative is
/// fixed by some symmetry occupies several indices, and reaching one of them
/// through the move graph does not reach the others. Filling them together is
/// what keeps the table equal to the true distances rather than merely an
/// upper bound on them.
PruningTable fillPruningTable({
  required int length,
  required int stride,
  required int moveCount,
  required int Function(int index, int move) successor,
  Iterable<int> Function(int index)? aliases,
  int root = 0,
}) {
  final prune = PruningTable.filled(length, stride);
  var count = 0;
  var depth = 0;

  void assign(int index, int value) {
    if (prune.at(index) != PruningTable.unvisited) {
      return;
    }
    prune.setAt(index, value);
    count++;
    if (aliases == null) {
      return;
    }
    for (final alias in aliases(index)) {
      if (prune.at(alias) == PruningTable.unvisited) {
        prune.setAt(alias, value);
        count++;
      }
    }
  }

  assign(root, 0);

  while (count < length) {
    if (depth + 1 >= PruningTable.unvisited) {
      throw StateError("Pruning depth ${depth + 1} does not fit in 4 bits");
    }
    for (var i = 0; i < length; i++) {
      if (prune.at(i) != depth) {
        continue;
      }
      for (var m = 0; m < moveCount; m++) {
        final next = successor(i, m);
        if (next < 0) {
          continue;
        }
        assign(next, depth + 1);
      }
    }
    depth++;
  }

  return prune;
}

/// A cache file holding the raw bytes of a set of tables.
///
/// The tables are written host-endian, so the header carries a byte order mark
/// as well as a magic number and a format version; anything that does not match
/// causes a rebuild rather than a bad load. [variant] distinguishes builds that
/// differ in content rather than format, such as one with an optional table
/// left out.
///
/// **Bump [version] whenever a table builder changes**, or a stale file will be
/// loaded and silently trusted.
class TableFile {
  static const int _headerBytes = 16; // magic(4) + version(4) + bom(4) + variant(4)
  static const int _byteOrderMark = 0x01020304;

  final String name;
  final List<int> magic;
  final int version;
  final int variant;

  const TableFile({required this.name, required this.magic, required this.version, this.variant = 0});

  /// Where this cache is kept, for logging.
  String get location => tablePath(name);

  /// The sections of a usable cache file, or null if there is not one.
  ///
  /// [sectionLengths] must describe exactly what [write] was given.
  List<Uint8List>? read(List<int> sectionLengths) {
    final bytes = readTableBytes(name);
    if (bytes == null) {
      return null;
    }

    final total = _headerBytes + sectionLengths.fold<int>(0, (a, b) => a + b);
    if (bytes.length != total) {
      Logging().warning("$name has the wrong size, rebuilding");
      return null;
    }

    final header = ByteData.sublistView(bytes, 0, _headerBytes);
    for (var i = 0; i < magic.length; i++) {
      if (header.getUint8(i) != magic[i]) {
        Logging().warning("$name has a bad magic number, rebuilding");
        return null;
      }
    }
    if (header.getUint32(4, Endian.host) != version) {
      Logging().warning("$name is an outdated version, rebuilding");
      return null;
    }
    if (header.getUint32(8, Endian.host) != _byteOrderMark) {
      Logging().warning("$name has a different byte order, rebuilding");
      return null;
    }
    if (header.getUint32(12, Endian.host) != variant) {
      Logging().warning("$name was built with different options, rebuilding");
      return null;
    }

    final sections = <Uint8List>[];
    var offset = _headerBytes;
    for (final length in sectionLengths) {
      final section = Uint8List(length);
      section.setRange(0, length, bytes, offset);
      sections.add(section);
      offset += length;
    }
    return sections;
  }

  void write(List<Uint8List> sections) {
    final total = _headerBytes + sections.fold<int>(0, (a, b) => a + b.length);
    final bytes = Uint8List(total);

    final header = ByteData.sublistView(bytes, 0, _headerBytes);
    for (var i = 0; i < magic.length; i++) {
      header.setUint8(i, magic[i]);
    }
    header.setUint32(4, version, Endian.host);
    header.setUint32(8, _byteOrderMark, Endian.host);
    header.setUint32(12, variant, Endian.host);

    var offset = _headerBytes;
    for (final section in sections) {
      bytes.setRange(offset, offset + section.length, section);
      offset += section.length;
    }

    writeTableBytes(name, bytes);
    Logging().info("Wrote ${total ~/ 1024} KB of $name to ${tableDirectory ?? "nowhere"}");
  }
}

/// A [MovingTable] rebuilt from cached bytes.
///
/// The bytes are copied rather than viewed: the source is not guaranteed to sit
/// on a two byte boundary once the header has offset it.
MovingTable movingTableFromBytes(Uint8List bytes, int rows, int columns) {
  final data = Uint16List(rows * columns);
  Uint8List.sublistView(data).setAll(0, bytes);
  return MovingTable(data, rows, columns);
}

/// The raw bytes of a [MovingTable], for [TableFile.write].
Uint8List movingTableBytes(MovingTable table) => Uint8List.sublistView(table.data);
