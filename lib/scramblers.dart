/// One way to ask any of the puzzles for a scramble.
///
/// The puzzles are kept apart everywhere else on purpose — different cube
/// models, and the Clock has no cube at all — so their scramble functions have
/// different names, different arguments and, for the Clock, a different return
/// type. That is right for code that knows which puzzle it wants. It is wrong
/// for a screen with a puzzle picker on it, which wants a list.
///
/// ```dart
/// final scrambler = puzzleScramblers["333"]!;
/// final scramble = await scrambler.next();
///
/// Text(scramble.notation);                       // R U2 F' …
/// CustomPaint(painter: MyPainter(scrambler.layout, scramble.state));
/// ```
///
/// Importing this pulls in every puzzle. Code that only wants one should
/// import that puzzle's own library and call its function directly.
library;

import "dart:math";

import "clock.dart";
import "cube/layout.dart";
import "fourbyfour.dart" show randomFourByFourScramble;
import "megaminx.dart"
    show Megaminx, megaminxLayout, megaminxMoves, megaminxNotation, nMegaminxFacelets, randomMegaminxScramble;
import "mochi_cube.dart";
import "nxn.dart" show NxNCube, nxnMoves, randomNxNScramble;
import "pocket.dart";
import "pyraminx.dart";
import "skewb.dart";
import "square1.dart";
import "table_storage.dart" show TableFiles, loadTables;

// Algorithm and MoveSet are part of this library's own surface: a Scramble
// carries one, and stateOf takes one.
export "cube/algorithm.dart" show Algorithm, MoveSet;
// Shipping the tables prebuilt is a scrambler-level decision: it is [next] that
// would otherwise build them.
export "table_storage.dart" show TableBytesLoader, TableFiles, useTableBytesLoader;
export "clock/layout.dart" show ClockLayout;
export "cube/layout.dart" show Layout, Point, PuzzleLayout;
export "square1/layout.dart" show Square1Layout;

/// A source of scrambles for one puzzle.
///
/// Deliberately narrow. It scrambles and it says how to draw the result; it
/// does not solve, since only two of the puzzles have a [Solver]: the rest
/// either do not need one or, from the 5x5x5 up, are scrambled without.
abstract interface class Scrambler {
  /// A short name, and the key this is filed under.
  ///
  /// The puzzles use their WCA event id — `333`, `222`, `444`, `555`, `666`,
  /// `777`, `minx`, `pyram`, `skewb`, `sq1` and `clock` — rather than a spelling of our own,
  /// since those are what the rest of the speedcubing world writes and what the
  /// official scrambler is asked for. The drills, which the WCA has no id for, are `pll`, `oll` and
  /// `f2l`.
  ///
  /// It names the puzzle or the drill, not the settings: a [CubeScrambler] is
  /// `333` whether or not it is turning random faces.
  String get id;

  /// What to show in a picker: the puzzle, or the drill.
  String get name;

  /// The event id of the puzzle this scrambles. The drills all say `333`.
  String get puzzleId;

  /// Where the pieces of that puzzle are drawn.
  ///
  /// A [PuzzleLayout] for the puzzles whose stickers stay where they are, a
  /// [Square1Layout] for the Square-1, whose do not, and a [ClockLayout] for the
  /// Clock, whose dials are circles rather than polygons.
  Layout get layout;

  /// How many numbers a state has, and so how many pieces [layout] holds.
  int get stateLength;

  /// The state of the solved puzzle, for drawing one that has not been
  /// scrambled yet.
  List<int> get solvedState;

  /// The state [algorithm] leaves the puzzle in, starting from solved.
  ///
  /// A prefix of a scramble gives the state part way through it, which is what
  /// a viewer stepping along a scramble asks for. [Algorithm.empty] gives
  /// [solvedState].
  ///
  /// Throws [UnsupportedError] on the Clock, whose scramble is a set of dial
  /// positions rather than a sequence of turns — the same reason its
  /// [Scramble.algorithm] is null.
  List<int> stateOf(Algorithm algorithm);

  /// The notation broken into the steps a viewer can stop at.
  ///
  /// One entry per token of [Scramble.notation], so a picker can lay the two
  /// out together. Scramble-level rather than [Algorithm]-level because the
  /// Clock has no algorithm and still has steps: its notation is fourteen dial
  /// turns and the `y2` that separates the two sides.
  List<String> stepsOf(Scramble scramble);

  /// The state after the first [steps] of [stepsOf], starting from solved.
  ///
  /// `stateAfter(scramble, 0)` is [solvedState] and passing the whole length
  /// gives [Scramble.state] back. This is what a viewer walking a scramble
  /// asks for.
  List<int> stateAfter(Scramble scramble, int steps);

  /// The scramble [notation] writes, as if this scrambler had made it.
  ///
  /// For a scramble that was stored as text, such as a record's, and has to be
  /// drawn or stepped along again. Needs no tables: it replays the notation
  /// rather than searching for anything.
  ///
  /// [Scramble.notation] comes back in this puzzle's own spelling, so extra
  /// whitespace is gone and [stepsOf] splits it the way it splits one from
  /// [next]. Throws [FormatException] when [notation] is not this puzzle's.
  Scramble parse(String notation);

  /// The table files this puzzle's scrambler needs, for a host that ships them
  /// prebuilt rather than letting the first scramble build them.
  ///
  /// Empty for the Clock, which has no tables. See [useTableBytesLoader].
  List<String> get tables;

  /// A scramble, drawn evenly from every state of the puzzle.
  ///
  /// [random] defaults to [Random.secure]; pass a seeded [Random] to reproduce
  /// one.
  ///
  /// A future so a caller can put a progress indicator up, because the first
  /// call is far slower than the rest: it builds the puzzle's tables. On the
  /// web, where there is no cache to load them from, that is about 1.8s for the
  /// 3x3x3, 1.0s for the 2x2x2 and 0.3s for the Pyraminx, against 24ms and
  /// well under a millisecond afterwards.
  ///
  /// **It does not make the work happen elsewhere.** Dart has no threads on the
  /// web, so awaiting this yields once — long enough for the indicator to be
  /// painted — and then holds the thread until the tables are built. The
  /// indicator appears rather than the tap seeming to do nothing, but it will
  /// not animate through the build.
  ///
  /// Which is why a host that cannot afford that pause should ship the tables
  /// prebuilt: [useTableBytesLoader] with the files [tables] names, and this
  /// awaits the bytes instead of building them. That is the web answer, since
  /// awaiting a download does leave the frame free.
  Future<Scramble> next({Random? random});
}

/// One scramble: how it is written, and the state it leaves.
class Scramble {
  /// The scramble in the notation a competition uses.
  final String notation;

  /// What the puzzle then looks like, one number per piece of the layout.
  ///
  /// For the four with a [PuzzleLayout] these are face indices, so `state[i]`
  /// is which colour to paint `layout[i]`. For the Square-1 they are the piece
  /// in each slot and then the middle, which [Square1Layout.stickers] turns
  /// into polygons and faces. For the Clock they are hours, 0 to 11, one per
  /// dial — a number to draw a hand at, not a colour.
  final List<int> state;

  /// The moves, for every puzzle that turns.
  ///
  /// Null for the Clock, whose scramble is a set of dial positions rather than
  /// a sequence of anything.
  final Algorithm? algorithm;

  const Scramble({required this.notation, required this.state, this.algorithm});

  @override
  String toString() => notation;
}

/// Stepping along a scramble that is a sequence of moves.
///
/// Every puzzle here works this way apart from the Clock, whose scramble is a
/// set of dial positions instead. They differ only in how a state is read off
/// a cube, which is [Scrambler.stateOf]; the walking is the same.
mixin _AlgorithmSteps implements Scrambler {
  /// The moves of a scramble this scrambler could have made.
  ///
  /// Throws [ArgumentError] rather than a null check failure when handed
  /// another puzzle's scramble, which is the shape a stale one arrives in.
  Algorithm _movesOf(Scramble scramble) =>
      scramble.algorithm ??
      (throw ArgumentError.value(scramble, "scramble", "has no moves, so it is not $name's"));

  /// What this puzzle's moves are called. A 3x3x3's, unless it says otherwise.
  MoveSet get _moveSet => MoveSet.cube;

  @override
  Scramble parse(String notation) {
    final algorithm = Algorithm.parse(notation, moveSet: _moveSet);
    return Scramble(notation: algorithm.toString(), state: stateOf(algorithm), algorithm: algorithm);
  }

  @override
  List<String> stepsOf(Scramble scramble) {
    final algorithm = _movesOf(scramble);
    return [for (final move in algorithm.moves) algorithm.moveSet.render(move)];
  }

  @override
  List<int> stateAfter(Scramble scramble, int steps) {
    final algorithm = _movesOf(scramble);
    return stateOf(Algorithm(algorithm.moves.sublist(0, steps), moveSet: algorithm.moveSet));
  }
}

/// The 3x3x3.
class CubeScrambler with _AlgorithmSteps implements Scrambler {
  /// Turn random faces instead of solving a random state.
  ///
  /// Cheap, but not how a competition scrambles: the states it reaches are not
  /// evenly distributed and a short one can leave the cube nearly solved.
  final bool randomMoves;

  /// How many turns, when [randomMoves] is set.
  final int moves;

  const CubeScrambler({this.randomMoves = false, this.moves = 20});

  @override
  String get id => "333";

  @override
  String get name => randomMoves ? "3x3x3, random moves" : "3x3x3";

  @override
  String get puzzleId => id;

  @override
  Layout get layout => cubeLayout;

  @override
  int get stateLength => 54;

  @override
  List<int> get solvedState => CubieCube().toFacelets();

  @override
  List<int> stateOf(Algorithm algorithm) => algorithm.cube.toFacelets();

  @override
  List<String> get tables => const [TableFiles.phase1, TableFiles.phase2];

  @override
  Future<Scramble> next({Random? random}) async {
    await loadTables(tables);
    final algorithm = randomMoves
        ? randomScramble(moves: moves, random: random)
        : randomStateScramble(random: random);
    return Scramble(notation: algorithm.toString(), state: stateOf(algorithm), algorithm: algorithm);
  }
}

/// The 2x2x2.
class PocketScrambler with _AlgorithmSteps implements Scrambler {
  const PocketScrambler();

  @override
  String get id => "222";

  @override
  String get name => "2x2x2";

  @override
  String get puzzleId => id;

  @override
  Layout get layout => pocketLayout;

  @override
  int get stateLength => nPocketFacelets;

  @override
  List<int> get solvedState => CubieCube().toPocketFacelets();

  @override
  List<int> stateOf(Algorithm algorithm) => algorithm.cube.toPocketFacelets();

  @override
  List<String> get tables => const [TableFiles.pocket];

  @override
  Future<Scramble> next({Random? random}) async {
    await loadTables(tables);
    final algorithm = randomPocketScramble(random: random);
    return Scramble(notation: algorithm.toString(), state: stateOf(algorithm), algorithm: algorithm);
  }
}

/// The 4x4x4, scrambled from a random state as the WCA does.
///
/// The one cube of the big ones that needs tables: a three phase solver finds
/// the scramble, and its first search builds them.
class FourByFourScrambler with _AlgorithmSteps implements Scrambler {
  const FourByFourScrambler();

  @override
  String get id => "444";

  @override
  String get name => "4x4x4";

  @override
  String get puzzleId => id;

  @override
  Layout get layout => cubeNetLayout(4);

  @override
  int get stateLength => 96;

  @override
  List<int> get solvedState => NxNCube(4).toFacelets();

  @override
  List<int> stateOf(Algorithm algorithm) => (NxNCube(4)..apply(algorithm)).toFacelets();

  @override
  MoveSet get _moveSet => nxnMoves(4);

  @override
  List<String> get tables => const [TableFiles.fourByFour];

  @override
  Future<Scramble> next({Random? random}) async {
    await loadTables(tables);
    final algorithm = randomFourByFourScramble(random: random);
    return Scramble(notation: algorithm.toString(), state: stateOf(algorithm), algorithm: algorithm);
  }
}

/// The 5x5x5, 6x6x6 and 7x7x7, scrambled by random turns as the WCA does.
class NxNScrambler with _AlgorithmSteps implements Scrambler {
  /// How many stickers along a side: 5, 6 or 7.
  final int size;

  const NxNScrambler(this.size);

  @override
  String get id => "$size$size$size";

  @override
  String get name => "${size}x${size}x$size";

  @override
  String get puzzleId => id;

  @override
  Layout get layout => cubeNetLayout(size);

  @override
  int get stateLength => 6 * size * size;

  @override
  List<int> get solvedState => NxNCube(size).toFacelets();

  @override
  List<int> stateOf(Algorithm algorithm) => (NxNCube(size)..apply(algorithm)).toFacelets();

  @override
  MoveSet get _moveSet => nxnMoves(size);

  /// None: random turns need no tables.
  @override
  List<String> get tables => const [];

  @override
  Future<Scramble> next({Random? random}) async {
    await loadTables(tables);
    final algorithm = randomNxNScramble(size, random: random);
    return Scramble(notation: algorithm.toString(), state: stateOf(algorithm), algorithm: algorithm);
  }
}

/// The Megaminx, scrambled by Pochmann's random turns as the WCA does.
///
/// Its notation comes in seven rows, as a competition writes it.
class MegaminxScrambler with _AlgorithmSteps implements Scrambler {
  const MegaminxScrambler();

  @override
  String get id => "minx";

  @override
  String get name => "Megaminx";

  @override
  String get puzzleId => id;

  @override
  Layout get layout => megaminxLayout;

  @override
  int get stateLength => nMegaminxFacelets;

  @override
  List<int> get solvedState => Megaminx().toFacelets();

  @override
  List<int> stateOf(Algorithm algorithm) => (Megaminx()..apply(algorithm)).toFacelets();

  @override
  MoveSet get _moveSet => megaminxMoves;

  @override
  Scramble parse(String notation) {
    final algorithm = Algorithm.parse(notation, moveSet: megaminxMoves);
    return Scramble(notation: megaminxNotation(algorithm), state: stateOf(algorithm), algorithm: algorithm);
  }

  /// None: random turns need no tables.
  @override
  List<String> get tables => const [];

  @override
  Future<Scramble> next({Random? random}) async {
    await loadTables(tables);
    final algorithm = randomMegaminxScramble(random: random);
    return Scramble(notation: megaminxNotation(algorithm), state: stateOf(algorithm), algorithm: algorithm);
  }
}

/// The Pyraminx.
class PyraminxScrambler with _AlgorithmSteps implements Scrambler {
  /// Whether to set the four tips as well.
  final bool tips;

  const PyraminxScrambler({this.tips = true});

  @override
  String get id => "pyram";

  @override
  String get name => "Pyraminx";

  @override
  String get puzzleId => id;

  @override
  Layout get layout => pyraminxLayout;

  @override
  int get stateLength => nPyraminxFacelets;

  @override
  List<int> get solvedState => PyraminxCube().toFacelets();

  @override
  List<int> stateOf(Algorithm algorithm) => (PyraminxCube()..apply(algorithm)).toFacelets();

  @override
  MoveSet get _moveSet => pyraminxMoves;

  @override
  List<String> get tables => const [TableFiles.pyraminx];

  @override
  Future<Scramble> next({Random? random}) async {
    await loadTables(tables);
    final algorithm = randomPyraminxScramble(random: random, tips: tips);
    return Scramble(notation: algorithm.toString(), state: stateOf(algorithm), algorithm: algorithm);
  }
}

/// The Skewb.
class SkewbScrambler with _AlgorithmSteps implements Scrambler {
  const SkewbScrambler();

  @override
  String get id => "skewb";

  @override
  String get name => "Skewb";

  @override
  String get puzzleId => id;

  @override
  Layout get layout => skewbLayout;

  @override
  int get stateLength => nSkewbFacelets;

  @override
  List<int> get solvedState => SkewbCube().toFacelets();

  @override
  List<int> stateOf(Algorithm algorithm) => (SkewbCube()..apply(algorithm)).toFacelets();

  @override
  MoveSet get _moveSet => skewbMoves;

  @override
  List<String> get tables => const [TableFiles.skewb];

  @override
  Future<Scramble> next({Random? random}) async {
    await loadTables(tables);
    final algorithm = randomSkewbScramble(random: random);
    return Scramble(notation: algorithm.toString(), state: stateOf(algorithm), algorithm: algorithm);
  }
}

/// The Square-1.
///
/// Its state is not stickers: the piece in each of the 24 slots and then the
/// middle, since which slots make up a piece changes as it turns.
/// [Square1Layout.stickers] turns one into polygons and faces.
class Square1Scrambler with _AlgorithmSteps implements Scrambler {
  const Square1Scrambler();

  @override
  String get id => "sq1";

  @override
  String get name => "Square-1";

  @override
  String get puzzleId => id;

  @override
  Layout get layout => square1Layout;

  @override
  int get stateLength => square1Layout.length;

  @override
  List<int> get solvedState => _stateOf(Square1Cube());

  @override
  List<int> stateOf(Algorithm algorithm) => _stateOf(Square1Cube()..apply(algorithm));

  static List<int> _stateOf(Square1Cube cube) => [...cube.pieces, cube.middle];

  @override
  MoveSet get _moveSet => square1Moves;

  /// None: they build in about 0.2s, so they are not cached.
  @override
  List<String> get tables => const [];

  @override
  Future<Scramble> next({Random? random}) async {
    await loadTables(tables);
    final algorithm = randomSquare1Scramble(random: random);
    return Scramble(notation: algorithm.toString(), state: stateOf(algorithm), algorithm: algorithm);
  }
}

/// The Rubik's Clock.
class ClockScrambler implements Scrambler {
  const ClockScrambler();

  @override
  String get id => "clock";

  @override
  String get name => "Clock";

  @override
  String get puzzleId => id;

  @override
  Layout get layout => clockLayout;

  @override
  int get stateLength => nClockDials;

  @override
  List<int> get solvedState => ClockState.solved().toDials();

  @override
  List<int> stateOf(Algorithm algorithm) =>
      throw UnsupportedError("A Clock scramble is a set of dial positions, not a sequence of turns");

  @override
  Scramble parse(String notation) {
    final state = ClockState.parse(notation);
    return Scramble(notation: state.toString(), state: state.toDials());
  }

  @override
  List<String> stepsOf(Scramble scramble) => scramble.notation.split(" ");

  @override
  List<int> stateAfter(Scramble scramble, int steps) {
    // Parsing is the documented inverse of ClockState.toString, and the
    // notation is the only place the fourteen dials survive: Scramble.state
    // holds the eighteen that get drawn, which are an image of them.
    final scrambled = ClockState.parse(scramble.notation);

    // The y2 sits between the ninth dial and the tenth. It flips the puzzle
    // rather than turning anything, so stopping on it is stopping after the
    // ninth dial.
    final turned = steps <= ClockState.frontDials ? steps : steps - 1;

    return ClockState([
      for (var dial = 0; dial < ClockState.dialCount; dial++) dial < turned ? scrambled.dials[dial] : 0,
    ]).toDials();
  }

  @override
  List<String> get tables => const [];

  @override
  Future<Scramble> next({Random? random}) async {
    await loadTables(tables);
    final state = randomClockScramble(random: random);
    // No algorithm: a clock's scramble is where its dials end up, not a
    // sequence of turns that got them there.
    return Scramble(notation: state.toString(), state: state.toDials());
  }
}

/// Which part of a solve a drill leaves to do.
enum PracticeDrill { pll, oll, f2l }

/// A 3x3x3 drill: the same puzzle, scrambled only part of the way.
class PracticeScrambler with _AlgorithmSteps implements Scrambler {
  /// What is left to do.
  final PracticeDrill drill;

  /// Whether to draw evenly from the states or from the cases.
  ///
  /// Ignored by [PracticeDrill.f2l], which has no case list.
  final PracticeSpread spread;

  /// How many F2L pairs are already solved, 0 to 3.
  ///
  /// Only [PracticeDrill.f2l] reads it.
  final int solvedPairs;

  const PracticeScrambler(this.drill, {this.spread = PracticeSpread.states, this.solvedPairs = 0});

  @override
  String get id => drill.name;

  @override
  String get name => drill.name.toUpperCase();

  @override
  String get puzzleId => "333";

  @override
  Layout get layout => cubeLayout;

  @override
  int get stateLength => 54;

  @override
  List<int> get solvedState => CubieCube().toFacelets();

  @override
  List<int> stateOf(Algorithm algorithm) => algorithm.cube.toFacelets();

  @override
  List<String> get tables => const [TableFiles.phase1, TableFiles.phase2];

  @override
  Future<Scramble> next({Random? random}) async {
    await loadTables(tables);
    final algorithm = switch (drill) {
      PracticeDrill.pll => pllPracticeScramble(random: random, spread: spread),
      PracticeDrill.oll => ollPracticeScramble(random: random, spread: spread),
      PracticeDrill.f2l => f2lPracticeScramble(random: random, solvedPairs: solvedPairs),
    };
    return Scramble(notation: algorithm.toString(), state: stateOf(algorithm), algorithm: algorithm);
  }
}

/// The puzzles, by WCA event id.
///
/// A map so a saved setting can name a puzzle without depending on the order
/// they happen to be declared in. Dart maps keep their insertion order, so
/// `.values` is still the order a picker would list them in.
const Map<String, Scrambler> puzzleScramblers = {
  "333": CubeScrambler(),
  "222": PocketScrambler(),
  "444": FourByFourScrambler(),
  "555": NxNScrambler(5),
  "666": NxNScrambler(6),
  "777": NxNScrambler(7),
  "minx": MegaminxScrambler(),
  "pyram": PyraminxScrambler(),
  "skewb": SkewbScrambler(),
  "sq1": Square1Scrambler(),
  "clock": ClockScrambler(),
};

/// The three 3x3x3 drills, by name.
const Map<String, Scrambler> practiceScramblers = {
  "pll": PracticeScrambler(PracticeDrill.pll),
  "oll": PracticeScrambler(PracticeDrill.oll),
  "f2l": PracticeScrambler(PracticeDrill.f2l),
};

/// Every scrambler there is: the puzzles, then the drills.
const Map<String, Scrambler> allScramblers = {...puzzleScramblers, ...practiceScramblers};
