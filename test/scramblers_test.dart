import "dart:math";

import "package:mochi_cube/clock.dart";
import "package:mochi_cube/mochi_cube.dart";
import "package:mochi_cube/pocket.dart" show PocketFacelets;
import "package:mochi_cube/pyraminx.dart";
import "package:mochi_cube/scramblers.dart";
import "package:test/test.dart";

/// Every scrambler there is, drills included.
final List<Scrambler> all = allScramblers.values.toList();

/// How many pieces a layout has, whichever kind it is.
int piecesOf(Layout layout) => switch (layout) {
  PuzzleLayout() => layout.length,
  ClockLayout() => layout.dials.length,
  _ => throw StateError("Unknown layout ${layout.runtimeType}"),
};

/// The state the notation of [scramble] actually leaves, worked out from the
/// puzzle rather than from the scrambler that produced it.
List<int> stateFromNotation(Scrambler scrambler, Scramble scramble) => switch (scrambler.puzzleId) {
  "333" => Algorithm.parse(scramble.notation).cube.toFacelets(),
  "222" => Algorithm.parse(scramble.notation).cube.toPocketFacelets(),
  "pyram" => (PyraminxCube()..apply(Algorithm.parse(scramble.notation, moveSet: pyraminxMoves))).toFacelets(),
  "clock" => ClockState.parse(scramble.notation).toDials(),
  _ => throw StateError("Unknown puzzle ${scrambler.puzzleId}"),
};

void main() {
  test("a state is as long as its layout has pieces", () {
    for (final scrambler in all) {
      expect(piecesOf(scrambler.layout), scrambler.stateLength, reason: scrambler.name);
      expect(scrambler.solvedState, hasLength(scrambler.stateLength), reason: scrambler.name);
      expect(scrambler.next().state, hasLength(scrambler.stateLength), reason: scrambler.name);
    }
  });

  // The point of the interface is that the notation and the state agree. If a
  // scrambler ever built one from a different cube than the other, an app would
  // show a scramble that does not match the picture beside it.
  test("the state is what the notation leaves", () {
    for (final scrambler in all) {
      for (var i = 0; i < 5; i++) {
        final scramble = scrambler.next();
        expect(scramble.state, stateFromNotation(scrambler, scramble), reason: scrambler.name);
      }
    }
  });

  test("a scramble leaves something to do", () {
    for (final scrambler in all) {
      expect(scrambler.next().state, isNot(scrambler.solvedState), reason: scrambler.name);
    }
  });

  test("only the Clock has no algorithm, since it has no moves", () {
    for (final scrambler in all) {
      expect(scrambler.next().algorithm == null, scrambler.puzzleId == "clock", reason: scrambler.name);
    }
  });

  test("a seed repeats the run", () {
    // Not the 3x3x3 ones: their scramble is a solve, and the search draws on
    // Random.secure of its own.
    for (final scrambler in [const PocketScrambler(), const PyraminxScrambler(), const ClockScrambler()]) {
      expect(
        scrambler.next(random: Random(42)).notation,
        scrambler.next(random: Random(42)).notation,
        reason: scrambler.name,
      );
    }
  });

  test("a scrambler is filed under its own id", () {
    allScramblers.forEach((key, scrambler) => expect(scrambler.id, key));
    expect(puzzleScramblers.keys, ["333", "222", "pyram", "clock"]);
    expect(practiceScramblers.keys, ["pll", "oll", "f2l"]);
    expect(allScramblers, hasLength(puzzleScramblers.length + practiceScramblers.length));
  });

  test("every scrambler is named, and named differently", () {
    expect(all.map((scrambler) => scrambler.name).toSet(), hasLength(all.length));
    expect(all.map((scrambler) => scrambler.puzzleId).toSet(), puzzleScramblers.keys.toSet());
  });

  test("a drill scrambles the puzzle it says it does", () {
    for (final scrambler in practiceScramblers.values) {
      expect(scrambler.puzzleId, "333", reason: scrambler.name);
      expect(scrambler.layout, same(puzzleScramblers["333"]!.layout), reason: scrambler.name);
    }
  });

  test("a drill leaves less to do than a whole scramble", () {
    // Every drill keeps the cross solved, which a full scramble does not.
    for (final scrambler in practiceScramblers.values) {
      final cube = Algorithm.parse(scrambler.next().notation).cube;
      expect(isCrossSolved(cube), isTrue, reason: scrambler.name);
    }
  });

  test("the options are wired through", () {
    expect(const CubeScrambler(randomMoves: true, moves: 12).next().algorithm, hasLength(12));
    expect(
      const PyraminxScrambler(
        tips: false,
      ).next().algorithm!.every((move) => pyraminxMoves.axisOf(move) < PyraminxCube.vertexCount),
      isTrue,
    );
    expect(
      const PracticeScrambler(PracticeDrill.pll, spread: PracticeSpread.cases).next().state,
      hasLength(54),
    );
  });
}
