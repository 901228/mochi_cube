/// One way to ask any of the puzzles for a scramble.
///
/// The four puzzles are kept apart everywhere else on purpose — different cube
/// models, and the Clock has no cube at all — so their scramble functions have
/// different names, different arguments and, for the Clock, a different return
/// type. That is right for code that knows which puzzle it wants. It is wrong
/// for a screen with a puzzle picker on it, which wants a list.
///
/// ```dart
/// final scrambler = puzzleScramblers["333"]!;
/// final scramble = scrambler.next();
///
/// Text(scramble.notation);                       // R U2 F' …
/// CustomPaint(painter: MyPainter(scrambler.layout, scramble.state));
/// ```
///
/// Importing this pulls in all four puzzles. Code that only wants one should
/// import that puzzle's own library and call its function directly.
library;

import "dart:math";

import "clock.dart";
import "cube/layout.dart";
import "mochi_cube.dart";
import "pocket.dart";
import "pyraminx.dart";

export "clock/layout.dart" show ClockLayout;
export "cube/layout.dart" show Layout, Point, PuzzleLayout;

/// A source of scrambles for one puzzle.
///
/// Deliberately narrow. It scrambles and it says how to draw the result; it
/// does not solve, since only two of the four puzzles have a [Solver] and the
/// other two do not need one.
abstract interface class Scrambler {
  /// A short name, and the key this is filed under.
  ///
  /// The four puzzles use their WCA event id — `333`, `222`, `pyram`, `clock` —
  /// rather than a spelling of our own, since those are what the rest of the
  /// speedcubing world writes and what the official scrambler is asked for. The
  /// drills, which the WCA has no id for, are `pll`, `oll` and `f2l`.
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
  /// A [PuzzleLayout] for the three that are stickers, and a [ClockLayout] for
  /// the Clock, whose dials are circles rather than polygons.
  Layout get layout;

  /// How many numbers a state has, and so how many pieces [layout] holds.
  int get stateLength;

  /// The state of the solved puzzle, for drawing one that has not been
  /// scrambled yet.
  List<int> get solvedState;

  /// A scramble, drawn evenly from every state of the puzzle.
  ///
  /// [random] defaults to [Random.secure]; pass a seeded [Random] to reproduce
  /// one.
  Scramble next({Random? random});
}

/// One scramble: how it is written, and the state it leaves.
class Scramble {
  /// The scramble in the notation a competition uses.
  final String notation;

  /// What the puzzle then looks like, one number per piece of the layout.
  ///
  /// For the three that have stickers these are face indices, so
  /// `state[i]` is which colour to paint `layout[i]`. For the Clock they are
  /// hours, 0 to 11, one per dial — a number to draw a hand at, not a colour.
  final List<int> state;

  /// The moves, for the three puzzles that turn.
  ///
  /// Null for the Clock, whose scramble is a set of dial positions rather than
  /// a sequence of anything.
  final Algorithm? algorithm;

  const Scramble({required this.notation, required this.state, this.algorithm});

  @override
  String toString() => notation;
}

/// The 3x3x3.
class CubeScrambler implements Scrambler {
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
  Scramble next({Random? random}) {
    final algorithm = randomMoves
        ? randomScramble(moves: moves, random: random)
        : randomStateScramble(random: random);
    return Scramble(notation: algorithm.toString(), state: algorithm.cube.toFacelets(), algorithm: algorithm);
  }
}

/// The 2x2x2.
class PocketScrambler implements Scrambler {
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
  Scramble next({Random? random}) {
    final algorithm = randomPocketScramble(random: random);
    return Scramble(
      notation: algorithm.toString(),
      state: algorithm.cube.toPocketFacelets(),
      algorithm: algorithm,
    );
  }
}

/// The Pyraminx.
class PyraminxScrambler implements Scrambler {
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
  Scramble next({Random? random}) {
    final algorithm = randomPyraminxScramble(random: random, tips: tips);
    return Scramble(
      notation: algorithm.toString(),
      state: (PyraminxCube()..apply(algorithm)).toFacelets(),
      algorithm: algorithm,
    );
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
  Scramble next({Random? random}) {
    final state = randomClockScramble(random: random);
    // No algorithm: a clock's scramble is where its dials end up, not a
    // sequence of turns that got them there.
    return Scramble(notation: state.toString(), state: state.toDials());
  }
}

/// Which part of a solve a drill leaves to do.
enum PracticeDrill { pll, oll, f2l }

/// A 3x3x3 drill: the same puzzle, scrambled only part of the way.
class PracticeScrambler implements Scrambler {
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
  Scramble next({Random? random}) {
    final algorithm = switch (drill) {
      PracticeDrill.pll => pllPracticeScramble(random: random, spread: spread),
      PracticeDrill.oll => ollPracticeScramble(random: random, spread: spread),
      PracticeDrill.f2l => f2lPracticeScramble(random: random, solvedPairs: solvedPairs),
    };
    return Scramble(notation: algorithm.toString(), state: algorithm.cube.toFacelets(), algorithm: algorithm);
  }
}

/// The four puzzles, by WCA event id.
///
/// A map so a saved setting can name a puzzle without depending on the order
/// they happen to be declared in. Dart maps keep their insertion order, so
/// `.values` is still the order a picker would list them in.
const Map<String, Scrambler> puzzleScramblers = {
  "333": CubeScrambler(),
  "222": PocketScrambler(),
  "pyram": PyraminxScrambler(),
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
