import "dart:math";

import "../clock.dart";
import "../mochi_cube.dart";
import "../pocket.dart";
import "../pyraminx.dart";
import "../scramblers.dart";
import "render.dart";

/// One puzzle, as the command line deals with it.
///
/// The library keeps the four puzzles apart on purpose — they have different
/// cube models and, in the Clock's case, no cube at all — so this is where the
/// command line puts them back together, and the only place that has to know
/// all four.
enum CliPuzzle {
  cube("3x3", "333", ["3x3x3", "cube"]),
  pocket("2x2", "222", ["2x2x2", "pocket"]),
  pyraminx("pyraminx", "pyram", ["pyra", "pyramid"]),
  clock("clock", "clock", []);

  const CliPuzzle(this.name, this.id, this.aliases);

  /// What to write on the command line: the friendlier of the two spellings.
  final String name;

  /// The WCA event id, and the key this has in [puzzleScramblers].
  final String id;

  /// Other spellings that mean the same puzzle.
  final List<String> aliases;

  static CliPuzzle byName(String name) {
    final wanted = name.toLowerCase();
    for (final puzzle in values) {
      if (puzzle.name == wanted || puzzle.id == wanted || puzzle.aliases.contains(wanted)) {
        return puzzle;
      }
    }
    throw FormatException("Unknown puzzle '$name'. Try ${values.map((p) => p.name).join(", ")}.");
  }

  /// Which puzzle a state describes, worked out from the state itself.
  ///
  /// The three sticker strings are different lengths and a clock's is not
  /// stickers at all, so there is nothing to ask the user.
  static CliPuzzle of(String state) {
    final stickers = state.replaceAll(RegExp(r"\s"), "");
    return switch (stickers.length) {
      54 => cube,
      nPocketFacelets => pocket,
      nPyraminxFacelets => pyraminx,
      _ when state.contains("y2") => clock,
      _ => throw FormatException(
        "Cannot tell what '$state' is: expected 54, $nPocketFacelets or "
        "$nPyraminxFacelets stickers, or a clock scramble",
      ),
    };
  }

  /// Where this puzzle's scrambles come from.
  ///
  /// The command line does not draw its own from each puzzle's function; it
  /// looks the puzzle up in [puzzleScramblers] by the same event id, so the two
  /// cannot end up scrambling differently.
  ///
  /// [randomMoves] and [moves] mean something only to the 3x3x3. Asking for
  /// them anywhere else throws, rather than quietly handing back a cube.
  Scrambler scrambler({bool randomMoves = false, int moves = 20}) {
    if (!randomMoves) {
      return puzzleScramblers[id]!;
    }
    if (this != cube) {
      throw FormatException("--random-moves is only for the 3x3, not the $name");
    }
    return CubeScrambler(randomMoves: true, moves: moves);
  }

  /// A scramble drawn evenly from every state of this puzzle.
  Future<String> scramble({Random? random, bool randomMoves = false, int moves = 20}) async =>
      (await scrambler(randomMoves: randomMoves, moves: moves).next(random: random)).notation;

  /// The state a scramble leaves, drawn the way this puzzle is drawn.
  String render(String scramble) => switch (this) {
    cube => Ascii.cubeNet(Algorithm.parse(scramble).cube.toFaceletString()),
    pocket => Ascii.cubeNet(Algorithm.parse(scramble).cube.toPocketFaceletString()),
    pyraminx => Ascii.pyraminxFaces(
      (PyraminxCube()..apply(Algorithm.parse(scramble, moveSet: pyraminxMoves))).toFaceletString(),
    ),
    clock => Ascii.clockDials(ClockState.parse(scramble)),
  };

  /// The state itself, from a scramble: stickers, or a clock's dials.
  String stateOf(String scramble) => switch (this) {
    cube => Algorithm.parse(scramble).cube.toFaceletString(),
    pocket => Algorithm.parse(scramble).cube.toPocketFaceletString(),
    pyraminx => (PyraminxCube()..apply(Algorithm.parse(scramble, moveSet: pyraminxMoves))).toFaceletString(),
    clock => ClockState.parse(scramble).toDials().join(" "),
  };

  /// Draw the state described by [state], whatever kind of description it is.
  String show(String state) {
    final stickers = state.replaceAll(RegExp(r"\s"), "");
    return switch (this) {
      cube => Ascii.cubeNet(CubieCube.fromFaceletString(stickers).toFaceletString()),
      pocket => Ascii.cubeNet(PocketCube.fromFaceletString(stickers).toPocketFaceletString()),
      pyraminx => Ascii.pyraminxFaces(PyraminxFacelet.fromFaceletString(stickers).toFaceletString()),
      clock => Ascii.clockDials(ClockState.parse(state)),
    };
  }

  /// The moves that solve the state described by [state].
  ///
  /// Optimal for the 2x2x2, the Pyraminx and the Clock, since all three know
  /// the exact distance; near optimal for the 3x3x3, which searches.
  String solve(String state, {int? maxLength}) {
    final stickers = state.replaceAll(RegExp(r"\s"), "");
    switch (this) {
      case cube:
        final result = min2phase.solve(stickers, maxLength: maxLength ?? min2phase.defaultMaxLength);
        if (result.status != SolveStatus.foundSolution) {
          throw FormatException("Could not solve it: ${result.status.name}${_because(result)}");
        }
        return result.solution!.algorithm.toString();
      case pocket:
        return PocketSearch.solve(PocketCube.fromFaceletString(stickers)).toString();
      case pyraminx:
        return PyraminxSearch.solve(PyraminxFacelet.fromFaceletString(stickers)).toString();
      case clock:
        return ClockState.parse(state).inverse.toString();
    }
  }
}

String _because(SolveResult result) => result.error == null ? "" : " (${result.error})";
