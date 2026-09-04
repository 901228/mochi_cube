import "package:args/command_runner.dart";
import "package:mochi_cube/cli.dart";
import "package:mochi_cube/clock.dart";
import "package:mochi_cube/mochi_cube.dart";
import "package:mochi_cube/pocket.dart" show PocketFacelets;
import "package:mochi_cube/pyraminx.dart";
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
        expect(await run(["scramble", puzzle.name]), hasLength(1), reason: puzzle.name);
      }
    });

    test("prints as many as asked for", () async {
      expect(await run(["scramble", "-n", "3", "--random-moves"]), hasLength(3));
    });

    test("a seed makes the run repeat", () async {
      // Not the 3x3x3, whose scramble draws from Random.secure inside the
      // solver's own tie breaking; the other three are drawn and nothing else.
      for (final puzzle in [CliPuzzle.pocket, CliPuzzle.pyraminx, CliPuzzle.clock]) {
        final once = await run(["scramble", puzzle.name, "--seed", "42"]);
        final again = await run(["scramble", puzzle.name, "--seed", "42"]);
        expect(once, again, reason: puzzle.name);
      }
    });

    test("--state prints something solve accepts", () async {
      for (final puzzle in CliPuzzle.values) {
        if (puzzle == CliPuzzle.clock) continue; // its state is its scramble
        final lines = await run(["scramble", puzzle.name, "--state"]);
        expect(CliPuzzle.of(lines[1]), puzzle);
      }
    });
  });

  group("solve", () {
    test("undoes a scramble, for every puzzle", () async {
      expect(_solvesCube(await run(["scramble"])), isTrue);
      expect(_solvesPocket(await run(["scramble", "2x2"])), isTrue);
      expect(_solvesPyraminx(await run(["scramble", "pyraminx"])), isTrue);
      expect(_solvesClock(await run(["scramble", "clock"])), isTrue);
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

  test("every puzzle answers to its aliases", () {
    for (final puzzle in CliPuzzle.values) {
      for (final name in [puzzle.name, ...puzzle.aliases]) {
        expect(CliPuzzle.byName(name.toUpperCase()), puzzle);
      }
    }
    expect(() => CliPuzzle.byName("megaminx"), throwsFormatException);
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

bool _solvesClock(List<String> scramble) {
  final solution = CliPuzzle.clock.solve(scramble.first);
  return (ClockState.parse(scramble.first) + ClockState.parse(solution)).isSolved;
}
