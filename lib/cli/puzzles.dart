import "dart:math";

import "../clock.dart";
import "../megaminx.dart" show Megaminx, megaminxMoves, nMegaminxFacelets;
import "../mochi_cube.dart";
import "../fourbyfour.dart" show FourByFourSearch;
import "../fto.dart" show Fto, FtoSearch, ftoFromFaceletString, ftoMoves;
import "../nxn.dart" show NxNCube, nxnMoves;
import "../pocket.dart";
import "../pyraminx.dart";
import "../scramblers.dart";
import "../skewb.dart";
import "../square1.dart";
import "render.dart";

/// One puzzle, as the command line deals with it.
///
/// The library keeps the puzzles apart on purpose — they have different cube
/// models and, in the Clock's case, no cube at all — so this is where the
/// command line puts them back together, and the only place that has to know
/// all of them.
enum CliPuzzle {
  cube("3x3", "333", ["3x3x3", "cube"]),
  pocket("2x2", "222", ["2x2x2", "pocket"]),
  cube4("4x4", "444", ["4x4x4"]),
  cube5("5x5", "555", ["5x5x5"]),
  cube6("6x6", "666", ["6x6x6"]),
  cube7("7x7", "777", ["7x7x7"]),
  megaminx("megaminx", "minx", ["mega"]),
  fto("fto", "fto", ["octahedron"]),
  pyraminx("pyraminx", "pyram", ["pyra", "pyramid"]),
  skewb("skewb", "skewb", []),
  square1("sq1", "sq1", ["square1", "square-1"]),
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
  /// The sticker strings are all different lengths, a Square-1's is 25 hex
  /// digits and a clock's is not stickers at all, so there is nothing to ask
  /// the user.
  static CliPuzzle of(String state) {
    final stickers = state.replaceAll(RegExp(r"\s"), "");
    return switch (stickers.length) {
      54 => cube,
      nPocketFacelets => pocket,
      96 => cube4,
      150 => cube5,
      216 => cube6,
      294 => cube7,
      nMegaminxFacelets => megaminx,
      72 => fto,
      nPyraminxFacelets => pyraminx,
      nSkewbFacelets => skewb,
      25 => square1,
      _ when state.contains("y2") => clock,
      _ => throw FormatException(
        "Cannot tell what '$state' is: expected 54, $nPocketFacelets, 96, 150, 216, 294, $nMegaminxFacelets, "
        "$nPyraminxFacelets or $nSkewbFacelets stickers, a Square-1's 25 digits or a clock scramble",
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
    cube4 || cube5 || cube6 || cube7 => Ascii.cubeNet(_nxnAfter(scramble).toFaceletString()),
    megaminx => Ascii.megaminxFaces(_megaminxAfter(scramble)),
    fto => Ascii.ftoFaces(_ftoAfter(scramble).toFaceletString()),
    skewb => Ascii.skewbNet(_skewbAfter(scramble).toFaceletString()),
    square1 => Ascii.square1Layers(_square1After(scramble)),
    clock => Ascii.clockDials(ClockState.parse(scramble)),
  };

  /// The state itself, from a scramble: stickers, or a clock's dials.
  String stateOf(String scramble) => switch (this) {
    cube => Algorithm.parse(scramble).cube.toFaceletString(),
    pocket => Algorithm.parse(scramble).cube.toPocketFaceletString(),
    pyraminx => (PyraminxCube()..apply(Algorithm.parse(scramble, moveSet: pyraminxMoves))).toFaceletString(),
    cube4 || cube5 || cube6 || cube7 => _nxnAfter(scramble).toFaceletString(),
    megaminx => _megaminxAfter(scramble).toFaceletString(),
    fto => _ftoAfter(scramble).toFaceletString(),
    skewb => _skewbAfter(scramble).toFaceletString(),
    square1 => _square1After(scramble).toString(),
    clock => ClockState.parse(scramble).toDials().join(" "),
  };

  /// Draw the state described by [state], whatever kind of description it is.
  String show(String state) {
    final stickers = state.replaceAll(RegExp(r"\s"), "");
    return switch (this) {
      cube => Ascii.cubeNet(CubieCube.fromFaceletString(stickers).toFaceletString()),
      pocket => Ascii.cubeNet(PocketCube.fromFaceletString(stickers).toPocketFaceletString()),
      pyraminx => Ascii.pyraminxFaces(PyraminxFacelet.fromFaceletString(stickers).toFaceletString()),
      cube4 ||
      cube5 ||
      cube6 ||
      cube7 => Ascii.cubeNet(NxNCube.fromFaceletString(_size, stickers).toFaceletString()),
      megaminx => Ascii.megaminxFaces(Megaminx.fromFaceletString(stickers)),
      fto => Ascii.ftoFaces(ftoFromFaceletString(stickers).toFaceletString()),
      skewb => Ascii.skewbNet(SkewbFacelet.fromFaceletString(stickers).toFaceletString()),
      square1 => Ascii.square1Layers(Square1Cube.parse(stickers)),
      clock => Ascii.clockDials(ClockState.parse(state)),
    };
  }

  /// The moves that solve the state described by [state].
  ///
  /// Optimal for the 2x2x2, the Pyraminx, the Skewb and the Clock, since all four know
  /// the exact distance; near optimal for the 3x3x3, which searches, and not
  /// for the Square-1 and the 4x4x4, whose searches go by way of a smaller puzzle.
  /// The 4x4x4's solution may leave the cube a rotation away from where it
  /// began. Nothing solves the 5x5x5 and up or the Megaminx, which throw.
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
      case fto:
        return FtoSearch.solve(ftoFromFaceletString(stickers)).toString();
      case cube4:
        return FourByFourSearch.solve(NxNCube.fromFaceletString(4, stickers)).toString();
      case cube5 || cube6 || cube7 || megaminx:
        throw FormatException("Nothing solves the $name: it is scrambled by random turns, not from a state");
      case skewb:
        return SkewbSearch.solve(SkewbFacelet.fromFaceletString(stickers)).toString();
      case square1:
        return Square1Search.solve(Square1Cube.parse(stickers)).toString();
      case clock:
        return ClockState.parse(state).inverse.toString();
    }
  }

  /// How many stickers along a side, for the cubes from 5x5x5 up.
  int get _size => switch (this) {
    cube4 => 4,
    cube5 => 5,
    cube6 => 6,
    cube7 => 7,
    _ => throw StateError("The $name is not one of the big cubes"),
  };

  NxNCube _nxnAfter(String scramble) =>
      NxNCube(_size)..apply(Algorithm.parse(scramble, moveSet: nxnMoves(_size)));
}

Fto _ftoAfter(String scramble) => Fto()..apply(Algorithm.parse(scramble, moveSet: ftoMoves));

Megaminx _megaminxAfter(String scramble) =>
    Megaminx()..apply(Algorithm.parse(scramble, moveSet: megaminxMoves));

SkewbCube _skewbAfter(String scramble) => SkewbCube()..apply(Algorithm.parse(scramble, moveSet: skewbMoves));

Square1Cube _square1After(String scramble) =>
    Square1Cube()..apply(Algorithm.parse(scramble, moveSet: square1Moves));

String _because(SolveResult result) => result.error == null ? "" : " (${result.error})";
