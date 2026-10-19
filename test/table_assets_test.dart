import "dart:typed_data";

import "package:mochi_cube/pyraminx.dart";
import "package:mochi_cube/scramblers.dart";
import "package:mochi_cube/table_storage.dart";
import "package:test/test.dart";

/// Shipping the tables prebuilt is the web's only way out of a second or more
/// with the thread blocked, so the handover has to hold: the supplied bytes are
/// what gets loaded, and bytes that do not match are rebuilt rather than
/// trusted.
void main() {
  tearDown(() => useTableBytesLoader(null));

  test("a scrambler names the files it needs", () {
    expect(puzzleScramblers["333"]!.tables, [TableFiles.phase1, TableFiles.phase2]);
    expect(puzzleScramblers["222"]!.tables, [TableFiles.pocket]);
    expect(puzzleScramblers["pyram"]!.tables, [TableFiles.pyraminx]);
    expect(puzzleScramblers["skewb"]!.tables, [TableFiles.skewb]);
    expect(puzzleScramblers["444"]!.tables, [TableFiles.fourByFour]);
    for (final id in ["555", "666", "777", "minx"]) {
      expect(puzzleScramblers[id]!.tables, isEmpty, reason: "random turns need no tables");
    }
    expect(puzzleScramblers["sq1"]!.tables, isEmpty, reason: "the Square-1's are not cached");
    expect(puzzleScramblers["clock"]!.tables, isEmpty, reason: "the Clock has no tables");
  });

  test("supplied bytes beat the platform's own cache, and are handed over once", () async {
    final supplied = Uint8List(8);
    useTableBytesLoader((name) async => name == TableFiles.pocket ? supplied : null);

    await loadTables([TableFiles.pocket]);
    expect(cachedTableBytes(TableFiles.pocket), same(supplied));

    // Handed over rather than kept: holding the bytes as well as the tables
    // unpacked from them would double what a table costs.
    expect(cachedTableBytes(TableFiles.pocket), isNot(same(supplied)));
  });

  test("a loader is asked only for what it has not already given", () async {
    final asked = <String>[];
    useTableBytesLoader((name) async {
      asked.add(name);
      return Uint8List(8);
    });

    await loadTables([TableFiles.pyraminx]);
    await loadTables([TableFiles.pyraminx]);
    expect(asked, [TableFiles.pyraminx]);

    cachedTableBytes(TableFiles.pyraminx);
  });

  test("a file that does not match is rebuilt rather than trusted", () async {
    // The right name, the wrong contents: the length check rejects it.
    useTableBytesLoader((_) async => Uint8List(16));

    await loadTables([TableFiles.pyraminx]);
    final scramble = randomPyraminxScramble();
    expect(scramble.moves, isNotEmpty);
  });
}
