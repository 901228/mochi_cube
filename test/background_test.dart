import "dart:math";

import "package:mochi_cube/scramblers.dart";
import "package:test/test.dart";

void main() {
  tearDown(() async {
    await closeBackgroundScrambling();
    useTableBytesLoader(null);
  });

  test("a scramble made in the background reads back as the puzzle's own", () async {
    for (final id in ["pyram", "555", "sq1", "clock"]) {
      final scrambler = puzzleScramblers[id]!;
      final scramble = await scrambler.nextInBackground();

      expect(scramble.state, hasLength(scrambler.stateLength), reason: id);
      expect(scrambler.parse(scramble.notation).state, scramble.state, reason: id);
    }
  });

  test("the worker asks the host's loader for the tables it needs, once", () async {
    final asked = <String>[];
    useTableBytesLoader((name) async {
      asked.add(name);
      return null;
    });

    final scrambler = puzzleScramblers["pyram"]!;
    await scrambler.nextInBackground();
    await scrambler.nextInBackground();

    expect(asked, [TableFiles.pyraminx]);
  });

  test("a seeded scramble is made where it is asked, and is the same", () async {
    final scrambler = puzzleScramblers["pyram"]!;

    final background = await scrambler.nextInBackground(random: Random(7));
    final here = await scrambler.next(random: Random(7));

    expect(background.notation, here.notation);
  });

  test("closing the worker lets the next scramble start another", () async {
    final scrambler = puzzleScramblers["pyram"]!;
    await scrambler.nextInBackground();

    await closeBackgroundScrambling();

    expect((await scrambler.nextInBackground()).notation, isNotEmpty);
  });
}
