import "dart:math";

import "../cube/algorithm.dart";
import "algorithm.dart";
import "cube/cubie_cube.dart";
import "search.dart";

/// Well known cube patterns, as the algorithm that makes each one.
///
/// They are stored as algorithms rather than as cube states so that they read
/// as something you could turn on a real cube, and so `pattern.cube` and
/// `pattern.inverse` both come for free.
abstract final class Patterns {
  static final Algorithm checkerboard = Algorithm.parse("U2 D2 F2 B2 L2 R2");
  static final Algorithm cubeInCube = Algorithm.parse("F L F U' R U F2 L2 U' L' B D' B' L2 U");
  static final Algorithm cubeInCubeInCube = Algorithm.parse("U' L' U' F' R2 B' R F U B2 U B' L U' F U R F'");
  static final Algorithm anaconda = Algorithm.parse("L U B' U' R L' B R' F B' D R D' F'");
  static final Algorithm python = Algorithm.parse("F2 R' B' U R' L F' L F' B D' R B L2");
  static final Algorithm crossOne = Algorithm.parse("R2 L' D F2 R' D' R' L U' D R D B2 R' U D2");
  static final Algorithm crossTwo = Algorithm.parse("R2 L' D F2 R' D' R' L U' D R D B2 R' U D2 F2");
  static final Algorithm fourSpots = Algorithm.parse("F2 B2 U D' R2 L2 U D'");
  static final Algorithm sixSpots = Algorithm.parse("U D' R L' F B' U D'");
  static final Algorithm sixTs = Algorithm.parse("F2 R2 U2 F' B D2 L2 F B");
  static final Algorithm spiral = Algorithm.parse("L' B' D U R U' R' D2 R2 D L D' L' R' F U");
  static final Algorithm stripes = Algorithm.parse("F U F R L2 B D' R D2 L D' B R2 L F U F");
  static final Algorithm tetris = Algorithm.parse("L R F B U' D' L' R'");
  static final Algorithm twister = Algorithm.parse("F R' U L F' L' F U' R U L' U' L F'");
  static final Algorithm wire = Algorithm.parse("F B' L R' U D' F B'");

  /// Every pattern, by name.
  static final Map<String, Algorithm> all = {
    "checkerboard": checkerboard,
    "cubeInCube": cubeInCube,
    "cubeInCubeInCube": cubeInCubeInCube,
    "anaconda": anaconda,
    "python": python,
    "crossOne": crossOne,
    "crossTwo": crossTwo,
    "fourSpots": fourSpots,
    "sixSpots": sixSpots,
    "sixTs": sixTs,
    "spiral": spiral,
    "stripes": stripes,
    "tetris": tetris,
    "twister": twister,
    "wire": wire,
  };
}

/// A scramble drawn evenly from every state of the cube.
///
/// This is how the WCA defines a scramble, and how its official scrambler
/// works: take a uniformly random state, solve it, and write the solution
/// backwards. Every state is then equally likely, and the scramble comes out
/// around 20 moves rather than needing 20-odd random turns to be sure the cube
/// is well mixed.
///
/// [minimumMoves] rejects states that are too nearly solved; WCA regulation
/// 4b3 asks for at least two moves for the 3x3x3. The check uses the length of
/// the solution found, which is an upper bound on the true distance, so it can
/// only ever be looser than the rule: it may let a too-near state through, but
/// it never rejects a state the rule accepts.
///
/// [random] defaults to [Random.secure]; pass a seeded [Random] to reproduce a
/// scramble.
///
/// This costs a solve — around 12ms once the tables are built — where
/// [randomScramble] costs nothing. Use that one where the distribution does not
/// matter.
Algorithm randomStateScramble({
  Random? random,
  int minimumMoves = 2,
  int maxLength = Search.defaultMaxLength,
}) {
  while (true) {
    final cube = CubieCube.random(random: random);
    final result = Search.solveCube(cube, maxLength: maxLength);

    final solution = result.solution;
    if (solution == null || solution.length < minimumMoves) {
      // Either too easy, or too long for the requested limit. Both are rare
      // enough that drawing again is the simplest answer.
      continue;
    }

    // The scramble is the solution run backwards.
    return solution.algorithm.inverse;
  }
}

/// A random scramble of [moves] turns.
///
/// Cheap, but **not** how a competition scrambles: the states it produces are
/// not evenly distributed, and a short one can leave the cube close to solved.
/// [randomStateScramble] is the one to use when that matters.
///
/// Never turns the same face twice in a row. Returning the algorithm rather
/// than a cube means it can be shown, undone, or turned into a cube with
/// `.cube`.
Algorithm randomScramble({int moves = 20, Random? random}) {
  final rng = random ?? Random();
  final chosen = <int>[];

  var previous = -1;
  for (var i = 0; i < moves; i++) {
    int move;
    do {
      move = rng.nextInt(moveCount);
      // Two turns of the same face in a row would just be one turn.
    } while (previous >= 0 && move ~/ 3 == previous ~/ 3);

    chosen.add(move);
    previous = move;
  }

  return Algorithm(chosen);
}
