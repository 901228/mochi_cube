import "dart:io";
import "dart:math";

import "package:args/command_runner.dart";
import "package:path/path.dart" as path;

import "cli/puzzles.dart";

export "cli/puzzles.dart" show CliPuzzle;
import "mochi_cube.dart";
import "fourbyfour.dart" show FourByFourTables;
import "pocket.dart" show PocketTables;
import "pyraminx.dart" show PyraminxTables;
import "scramblers.dart";
import "fto.dart" show FtoTables;
import "skewb.dart" show SkewbTables;
import "table_storage.dart" show TableFiles, tableDirectory;

/// The `mochi_cube` command line tool.
///
/// A thin front for the same library a Dart program would call: it scrambles,
/// solves, draws a state and builds the tables. Nothing here knows anything the
/// library does not, which is the point — if a scramble is wrong on the command
/// line it is wrong in the package too.
///
/// [emit] is where output goes, so a test can read it back; it defaults to
/// standard output.
Future<void> runCli(List<String> arguments, {void Function(String) emit = print}) {
  final runner = CommandRunner<void>("mochi_cube", "Scramble, solve and draw twisty puzzles.")
    ..addCommand(_ScrambleCommand(emit))
    ..addCommand(_SolveCommand(emit))
    ..addCommand(_ShowCommand(emit))
    ..addCommand(_PracticeCommand(emit))
    ..addCommand(_PatternCommand(emit))
    ..addCommand(_TablesCommand(emit));
  return runner.run(arguments);
}

/// The puzzle names, for a `--help` that lists them.
final String _puzzleNames = CliPuzzle.values.map((puzzle) => puzzle.name).join(", ");

abstract class _Command extends Command<void> {
  _Command(this.emit);

  final void Function(String) emit;

  /// The random source, seeded when asked so a run can be repeated.
  Random get random {
    final seed = argResults!.option("seed");
    return seed == null ? Random.secure() : Random(int.parse(seed));
  }

  /// Add `--seed`, which every command that draws something wants.
  void addSeed() => argParser.addOption("seed", help: "Draw from a seeded generator, so the run repeats.");
}

class _ScrambleCommand extends _Command {
  _ScrambleCommand(super.emit) {
    argParser
      ..addOption("count", abbr: "n", defaultsTo: "1", help: "How many scrambles.")
      ..addFlag("show", help: "Draw the state each scramble leaves.")
      ..addFlag("state", help: "Print the state as well, as stickers or dials.")
      ..addFlag(
        "random-moves",
        help:
            "Turn random faces instead of solving a random state. Cheap, but not "
            "how a competition scrambles.",
      )
      ..addOption("moves", defaultsTo: "20", help: "Turns, with --random-moves.");
    addSeed();
  }

  @override
  String get name => "scramble";

  @override
  String get description => "Print a scramble. Puzzles: $_puzzleNames.";

  @override
  String get invocation => "mochi_cube scramble [puzzle]";

  @override
  Future<void> run() async {
    final puzzle = CliPuzzle.byName(argResults!.rest.firstOrNull ?? CliPuzzle.cube.name);
    final rng = random;

    for (var i = 0; i < int.parse(argResults!.option("count")!); i++) {
      final scramble = await puzzle.scramble(
        random: rng,
        randomMoves: argResults!.flag("random-moves"),
        moves: int.parse(argResults!.option("moves")!),
      );
      emit(scramble);
      if (argResults!.flag("state")) {
        emit(puzzle.stateOf(scramble));
      }
      if (argResults!.flag("show")) {
        emit(puzzle.render(scramble));
      }
    }
  }
}

class _SolveCommand extends _Command {
  _SolveCommand(super.emit) {
    argParser
      ..addOption("max-length", help: "Give up rather than return a longer 3x3x3 solution.")
      ..addFlag("show", help: "Draw the state first.");
  }

  @override
  String get name => "solve";

  @override
  String get description => "Solve a state. Which puzzle it is comes from the state itself.";

  @override
  String get invocation => "mochi_cube solve <state>";

  @override
  void run() {
    final state = argResults!.rest.join(" ");
    if (state.isEmpty) {
      usageException("Nothing to solve. Give a sticker string or a clock scramble.");
    }

    final puzzle = CliPuzzle.of(state);
    if (argResults!.flag("show")) {
      emit(puzzle.show(state));
    }

    final maxLength = argResults!.option("max-length");
    emit(puzzle.solve(state, maxLength: maxLength == null ? null : int.parse(maxLength)));
  }
}

class _ShowCommand extends _Command {
  _ShowCommand(super.emit);

  @override
  String get name => "show";

  @override
  String get description => "Draw a state as a net of letters.";

  @override
  String get invocation => "mochi_cube show <state>";

  @override
  void run() {
    final state = argResults!.rest.join(" ");
    if (state.isEmpty) {
      usageException("Nothing to draw. Give a sticker string or a clock scramble.");
    }
    emit(CliPuzzle.of(state).show(state));
  }
}

class _PracticeCommand extends _Command {
  _PracticeCommand(super.emit) {
    argParser
      ..addOption("count", abbr: "n", defaultsTo: "1", help: "How many scrambles.")
      ..addOption(
        "spread",
        allowed: ["states", "cases"],
        defaultsTo: "states",
        help:
            "Draw evenly from the states, as they really turn up, or from the "
            "cases, so each gets the same practice.",
      )
      ..addOption("pairs", defaultsTo: "0", help: "F2L pairs already solved, 0 to 3.")
      ..addFlag("show", help: "Draw the state each scramble leaves.");
    addSeed();
  }

  @override
  String get name => "practice";

  @override
  String get description => "Print a 3x3x3 practice scramble: pll, oll or f2l.";

  @override
  String get invocation => "mochi_cube practice <pll|oll|f2l>";

  @override
  Future<void> run() async {
    final kind = argResults!.rest.firstOrNull?.toLowerCase();
    final rng = random;
    final spread = argResults!.option("spread") == "cases" ? PracticeSpread.cases : PracticeSpread.states;

    final drill = switch (kind) {
      "pll" => PracticeDrill.pll,
      "oll" => PracticeDrill.oll,
      "f2l" => PracticeDrill.f2l,
      _ => usageException("Practice what? One of pll, oll or f2l."),
    };
    final scrambler = PracticeScrambler(
      drill,
      spread: spread,
      solvedPairs: int.parse(argResults!.option("pairs")!),
    );

    for (var i = 0; i < int.parse(argResults!.option("count")!); i++) {
      final scramble = await scrambler.next(random: rng);
      emit(scramble.notation);
      if (argResults!.flag("show")) {
        emit(CliPuzzle.cube.render(scramble.notation));
      }
    }
  }
}

class _PatternCommand extends _Command {
  _PatternCommand(super.emit) {
    argParser
      ..addFlag("list", help: "Name every pattern instead of showing one.")
      ..addFlag("show", defaultsTo: true, help: "Draw the pattern.");
  }

  @override
  String get name => "pattern";

  @override
  String get description => "Print the moves that make a known 3x3x3 pattern.";

  @override
  String get invocation => "mochi_cube pattern <name>";

  @override
  void run() {
    if (argResults!.flag("list")) {
      Patterns.all.keys.forEach(emit);
      return;
    }

    final wanted = argResults!.rest.firstOrNull;
    final pattern = wanted == null ? null : Patterns.all[wanted];
    if (pattern == null) {
      usageException("Unknown pattern. Try --list.");
    }

    emit(pattern.toString());
    if (argResults!.flag("show")) {
      emit(CliPuzzle.cube.render(pattern.toString()));
    }
  }
}

class _TablesCommand extends _Command {
  _TablesCommand(super.emit) {
    argParser
      ..addFlag("rebuild", help: "Delete the cached tables first.")
      ..addOption("out", help: "Also copy the built tables into this directory, for shipping them prebuilt.");
  }

  @override
  String get name => "tables";

  @override
  String get description => "Build the solvers' tables and say where they are cached.";

  @override
  void run() {
    // Always a real directory here: the tool only runs where dart:io does.
    final where = tableDirectory;
    if (argResults!.flag("rebuild") && where != null) {
      final directory = Directory(where);
      if (directory.existsSync()) {
        for (final file in directory.listSync().whereType<File>()) {
          if (file.path.endsWith(".bin")) {
            file.deleteSync();
          }
        }
      }
    }

    final builders = <String, int Function()>{
      "min2phase phase 1": () => Phase1Tables().lengthInBytes,
      "min2phase phase 2": () => Phase2Tables().lengthInBytes,
      "2x2x2": () => PocketTables().lengthInBytes,
      "4x4x4": () => FourByFourTables.lengthInBytes,
      "pyraminx": () => PyraminxTables().lengthInBytes,
      "skewb": () => SkewbTables().lengthInBytes,
      "fto": () => FtoTables.lengthInBytes(),
    };

    for (final MapEntry(key: what, value: build) in builders.entries) {
      final clock = Stopwatch()..start();
      final bytes = build();
      emit("${what.padRight(20)} ${_kilobytes(bytes).padLeft(9)}  ${clock.elapsedMilliseconds}ms");
    }
    emit("cached in ${where ?? "nowhere; this platform has no filesystem"}");

    // The copy is what a host bundles as an asset. Host endian and versioned,
    // so a table built by a different tool or a stale one is rejected on load
    // and rebuilt rather than trusted.
    if (argResults!.option("out") case final out? when where != null) {
      Directory(out).createSync(recursive: true);
      for (final name in TableFiles.all) {
        final source = File(path.join(where, name));
        if (source.existsSync()) {
          source.copySync(path.join(out, name));
          emit("copied $name to $out");
        }
      }
    }
  }
}

String _kilobytes(int bytes) => "${(bytes / 1024).toStringAsFixed(0)} KB";
