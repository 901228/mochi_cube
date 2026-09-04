import "dart:math";

import "../clock.dart";
import "../mochi_cube.dart";
import "../pocket.dart";
import "../pyraminx.dart";
import "render.dart";

/// One puzzle, as the command line deals with it.
///
/// The library keeps the four puzzles apart on purpose — they have different
/// cube models and, in the Clock's case, no cube at all — so this is where the
/// command line puts them back together, and the only place that has to know
/// all four.
enum CliPuzzle {
  cube("3x3", ["3x3x3", "333", "cube"]),
  pocket("2x2", ["2x2x2", "222", "pocket"]),
  pyraminx("pyraminx", ["pyra", "pyramid"]),
  clock("clock", []);

  const CliPuzzle(this.name, this.aliases);

  /// What to write on the command line.
  final String name;

  /// Other spellings that mean the same puzzle.
  final List<String> aliases;

  static CliPuzzle byName(String name) {
    final wanted = name.toLowerCase();
    for (final puzzle in values) {
      if (puzzle.name == wanted || puzzle.aliases.contains(wanted)) {
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

  /// A scramble drawn evenly from every state of this puzzle.
  String scramble({Random? random, bool randomMoves = false, int moves = 20}) => switch (this) {
    cube =>
      randomMoves
          ? randomScramble(moves: moves, random: random).toString()
          : randomStateScramble(random: random).toString(),
    pocket => randomPocketScramble(random: random).toString(),
    pyraminx => randomPyraminxScramble(random: random).toString(),
    clock => randomClockScramble(random: random).toString(),
  };

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
