import "package:args/command_runner.dart";
import "package:mochi_cube/cli.dart";
import "package:mochi_cube/clock.dart";
import "package:mochi_cube/mochi_cube.dart";
import "package:mochi_cube/pocket.dart" show PocketFacelets;
import "package:mochi_cube/nxn.dart" show NxNCube, nxnMoves;
import "package:mochi_cube/pyraminx.dart";
import "package:mochi_cube/scramblers.dart" show puzzleScramblers;
import "package:mochi_cube/skewb.dart" show SkewbCube, skewbMoves;
import "package:mochi_cube/square1.dart" show Square1Cube, square1Moves;
import "package:test/test.dart";

/// Run the tool and collect what it printed, one entry per line.
Future<List<String>> run(List<String> arguments) async {
  final printed = <String>[];
  await runCli(arguments, emit: (line) => printed.addAll(line.split("\n")));
  return printed;
}

void main() {
  group("scramble", () {
    test("prints one scramble a puzzle by default", () async {
      for (final puzzle in CliPuzzle.values) {
        // A Megaminx scramble is written in seven rows, as a competition writes it.
        final lines = puzzle == CliPuzzle.megaminx ? 7 : 1;
        expect(await run(["scramble", puzzle.name]), hasLength(lines), reason: puzzle.name);
      }
    });

    test("prints as many as asked for", () async {
      expect(await run(["scramble", "-n", "3", "--random-moves"]), hasLength(3));
    });

    test("a seed makes the run repeat", () async {
      // Not the 3x3x3, whose scramble draws from Random.secure inside the
      // solver's own tie breaking; the others are drawn and nothing else.
      for (final puzzle in [
        CliPuzzle.pocket,
        CliPuzzle.cube4,
        CliPuzzle.cube5,
        CliPuzzle.megaminx,
        CliPuzzle.pyraminx,
        CliPuzzle.skewb,
        CliPuzzle.square1,
        CliPuzzle.clock,
      ]) {
        final once = await run(["scramble", puzzle.name, "--seed", "42"]);
        final again = await run(["scramble", puzzle.name, "--seed", "42"]);
        expect(once, again, reason: puzzle.name);
      }
    });

    test("--state prints something solve accepts", () async {
      for (final puzzle in CliPuzzle.values) {
        if (puzzle == CliPuzzle.clock) continue; // its state is its scramble
        final lines = await run(["scramble", puzzle.name, "--state"]);
        expect(CliPuzzle.of(lines.last), puzzle);
      }
    });
  });

  group("solve", () {
    test("undoes a scramble, for every puzzle", () async {
      expect(_solvesCube(await run(["scramble"])), isTrue);
      expect(_solvesPocket(await run(["scramble", "2x2"])), isTrue);
      expect(_solvesPyraminx(await run(["scramble", "pyraminx"])), isTrue);
      expect(_solvesFourByFour(await run(["scramble", "4x4"])), isTrue);
      expect(_solvesSkewb(await run(["scramble", "skewb"])), isTrue);
      expect(_solvesSquare1(await run(["scramble", "sq1"])), isTrue);
      expect(_solvesClock(await run(["scramble", "clock"])), isTrue);
    });

    test("refuses the big cubes, which nothing solves", () async {
      for (final puzzle in ["5x5", "megaminx"]) {
        final state = (await run(["scramble", puzzle, "--state"])).last;
        expect(() => run(["solve", state]), throwsFormatException, reason: puzzle);
      }
    });

    test("says which puzzle it cannot tell", () async {
      expect(() => run(["solve", "nonsense"]), throwsFormatException);
    });

    test("wants something to solve", () async {
      expect(() => run(["solve"]), throwsA(isA<UsageException>()));
    });
  });

  group("show", () {
    test("draws a solved cube with its centres in the middle", () async {
      final net = (await run(["show", CubieCube().toFaceletString()])).join("\n");
      expect(net, contains("U U U"));
      expect(net, contains("L L L F F F R R R B B B"));
    });

    test("draws a solved clock as eighteen noons", () async {
      final lines = await run(["show", ClockState.solved().toString()]);
      expect(lines.skip(1).join(" ").split(RegExp(r"\s+")).where((t) => t == "0"), hasLength(18));
    });

    test("draws a solved Skewb as an X on every face", () async {
      final net = (await run(["show", SkewbCube().toFaceletString()])).join("\n");
      expect(net, contains("L   L F   F R   R B   B"));
      expect(net, contains("  L     F     R     B"));
    });

    test("draws a 4x4x4 as the same net", () async {
      final net = await run(["show", NxNCube(4).toFaceletString()]);
      expect(net, hasLength(12));
      expect(net[5], "L L L L F F F F R R R R B B B B");
    });

    test("draws a big cube as the same net, a letter a sticker", () async {
      final net = await run(["show", NxNCube(5).toFaceletString()]);
      expect(net, hasLength(15));
      expect(net[7], "L L L L L F F F F F R R R R R B B B B B");
    });

    test("draws a solved Square-1 as its two layers", () async {
      final drawn = await run(["show", Square1Cube().toString()]);
      expect(drawn, [
        "top     UB UBL UL ULF | UF UFR UR URB",
        "middle  square",
        "bottom  DBR DR DRF DF | DFL DL DLB DB",
      ]);
    });

    test("draws a Pyraminx as four named faces", () async {
      final drawn = (await run(["scramble", "pyraminx", "--show"])).join("\n");
      for (final face in pyraminxFaceNames) {
        expect(drawn, contains("face $face"));
      }
    });
  });

  group("practice", () {
    test("gives a scramble for each kind", () async {
      for (final kind in ["pll", "oll", "f2l"]) {
        expect(await run(["practice", kind]), hasLength(1), reason: kind);
      }
    });

    test("takes an even spread over the cases", () async {
      expect(await run(["practice", "pll", "--spread", "cases", "-n", "2"]), hasLength(2));
    });

    test("wants to know which drill", () async {
      expect(() => run(["practice"]), throwsA(isA<UsageException>()));
    });
  });

  group("pattern", () {
    test("lists every pattern", () async {
      expect(await run(["pattern", "--list"]), Patterns.all.keys.toList());
    });

    test("prints the moves of one, and what it looks like", () async {
      final lines = await run(["pattern", "checkerboard"]);
      expect(lines.first, Patterns.checkerboard.toString());
      expect(lines.length, greaterThan(1));
    });

    test("rejects a name it does not know", () async {
      expect(() => run(["pattern", "nonesuch"]), throwsA(isA<UsageException>()));
    });
  });

  group("puzzle names", () {
    test("every puzzle answers to its id and its aliases", () {
      for (final puzzle in CliPuzzle.values) {
        for (final name in [puzzle.name, puzzle.id, ...puzzle.aliases]) {
          expect(CliPuzzle.byName(name.toUpperCase()), puzzle);
        }
      }
      expect(() => CliPuzzle.byName("fto"), throwsFormatException);
    });

    // The tool and the library have to agree on what a puzzle is called, or a
    // setting saved by one would not be understood by the other.
    test("the ids are the library's", () {
      expect(CliPuzzle.values.map((puzzle) => puzzle.id), puzzleScramblers.keys);
      for (final puzzle in CliPuzzle.values) {
        expect(puzzle.scrambler().id, puzzle.id);
      }
    });

    test("--random-moves is refused by the puzzles that have no such thing", () {
      expect(CliPuzzle.cube.scrambler(randomMoves: true).name, contains("random moves"));
      for (final puzzle in CliPuzzle.values.where((p) => p != CliPuzzle.cube)) {
        expect(() => puzzle.scrambler(randomMoves: true), throwsFormatException);
      }
    });
  });
}

/// Whether the scramble on the first line, then its solution, leaves it solved.
bool _solvesCube(List<String> scramble) {
  final solution = CliPuzzle.cube.solve(CliPuzzle.cube.stateOf(scramble.first));
  return Algorithm.parse("${scramble.first} $solution").cube.toFaceletString() ==
      CubieCube().toFaceletString();
}

bool _solvesPocket(List<String> scramble) {
  final solution = CliPuzzle.pocket.solve(CliPuzzle.pocket.stateOf(scramble.first));
  return Algorithm.parse("${scramble.first} $solution").cube.toPocketFaceletString() ==
      CubieCube().toPocketFaceletString();
}

bool _solvesPyraminx(List<String> scramble) {
  final solution = CliPuzzle.pyraminx.solve(CliPuzzle.pyraminx.stateOf(scramble.first));
  final cube = PyraminxCube()..apply(Algorithm.parse("${scramble.first} $solution", moveSet: pyraminxMoves));
  return cube.toFaceletString() == PyraminxCube().toFaceletString();
}

bool _solvesFourByFour(List<String> scramble) {
  // Solved the way a 4x4x4 can be: every face one colour, whichever way up.
  final solution = CliPuzzle.cube4.solve(CliPuzzle.cube4.stateOf(scramble.first));
  final cube = NxNCube(4)..apply(Algorithm.parse("${scramble.first} $solution", moveSet: nxnMoves(4)));
  return [
    for (var face = 0; face < 6; face++) cube.facelets.sublist(face * 16, face * 16 + 16).toSet().length,
  ].every((colours) => colours == 1);
}

bool _solvesSkewb(List<String> scramble) {
  final solution = CliPuzzle.skewb.solve(CliPuzzle.skewb.stateOf(scramble.first));
  return (SkewbCube()..apply(Algorithm.parse("${scramble.first} $solution", moveSet: skewbMoves))).isSolved;
}

bool _solvesSquare1(List<String> scramble) {
  final solution = CliPuzzle.square1.solve(CliPuzzle.square1.stateOf(scramble.first));
  return (Square1Cube()..apply(Algorithm.parse("${scramble.first} $solution", moveSet: square1Moves)))
      .isSolved;
}

bool _solvesClock(List<String> scramble) {
  final solution = CliPuzzle.clock.solve(scramble.first);
  return (ClockState.parse(scramble.first) + ClockState.parse(solution)).isSolved;
}
