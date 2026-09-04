import "dart:math";

import "../cube/algorithm.dart";
import "../solver.dart";
import "../puzzle/cube/cubie_cube.dart";
import "coordinates.dart";
import "facelets.dart";
import "tables.dart";

/// The 2x2x2 solver.
///
/// There is no search here. The distance to solved is known for every state, so
/// solving is a walk downhill: take any move that leaves you one step nearer,
/// and repeat. Every solution it returns is therefore **optimal**, which the
/// 3x3x3 solvers cannot promise.
abstract final class PocketSearch {
  /// The fewest moves that solve [cube], as a 2x2x2.
  ///
  /// Only the corners are read; anything else about the cube is ignored, so a
  /// 3x3x3 whose corners happen to be solved returns an empty algorithm.
  static Algorithm solve(CubieCube cube) {
    final tables = PocketTables();
    var index = tables.indexOf(cube.cperm7, cube.twist6);
    var remaining = tables.distance.at(index);

    final moves = <int>[];
    while (remaining > 0) {
      var stepped = false;
      for (var i = 0; i < nPocketMoves && !stepped; i++) {
        final next = tables.successor(index, i);
        if (tables.distance.at(next) == remaining - 1) {
          moves.add(pocketMoves[i]);
          index = next;
          remaining--;
          stepped = true;
        }
      }
      if (!stepped) {
        // Only reachable if the table were wrong; every state that is not
        // solved has a neighbour one step nearer.
        throw StateError("No move gets nearer from state $index");
      }
    }

    return Algorithm(moves);
  }

  /// How many moves [cube] is from solved, as a 2x2x2. Exact, not a bound.
  static int distanceOf(CubieCube cube) => PocketTables().distanceOf(cube.cperm7, cube.twist6);
}

/// A 2x2x2 drawn evenly from all 3674160 states.
///
/// [random] defaults to [Random.secure]; pass a seeded [Random] to reproduce a
/// cube.
CubieCube randomPocketCube({Random? random}) {
  final rng = random ?? Random.secure();
  final cube = CubieCube();
  cube.cperm7 = rng.nextInt(nCperm7);
  cube.twist6 = rng.nextInt(nTwist6);
  return cube;
}

/// A scramble drawn evenly from every state of the 2x2x2.
///
/// A uniformly random state, solved and reversed, as the WCA defines it. Since
/// the solutions are optimal the scramble is as short as it can be, which is
/// why [minimumMoves] can be trusted exactly rather than as an upper bound:
/// regulation 4b3 asks a 2x2x2 scramble to be at least four moves from solved.
Algorithm randomPocketScramble({Random? random, int minimumMoves = 4}) {
  while (true) {
    final cube = randomPocketCube(random: random);
    final solution = PocketSearch.solve(cube);
    if (solution.length >= minimumMoves) {
      return solution.inverse;
    }
  }
}

/// The 2x2x2 behind the common [Solver] interface.
///
/// Unlike the 3x3x3 solvers this one is exact: [defaultMaxLength] is God's
/// number for the puzzle, so a solve never fails for want of length, and
/// [maxTime] never runs out because there is no search to cut short.
class PocketSolver implements Solver {
  const PocketSolver();

  @override
  String get name => "pocket";

  /// God's number for the 2x2x2 in the half-turn metric.
  @override
  int get defaultMaxLength => 11;

  @override
  SolveResult solve(String facelets, {int maxLength = 11, Duration? maxTime}) {
    final CubieCube cube;
    try {
      cube = PocketCube.fromFaceletString(facelets);
    } on FormatException catch (e) {
      return (status: SolveStatus.invalidCube, solution: null, error: e);
    }

    final clock = Stopwatch()..start();
    final solution = PocketSearch.solve(cube);
    clock.stop();

    if (solution.length > maxLength) {
      return (status: SolveStatus.exceededMaxLength, solution: null, error: null);
    }
    return (
      status: SolveStatus.foundSolution,
      solution: Solution(solution, elapsedTime: clock.elapsed),
      error: null,
    );
  }
}

/// The default [PocketSolver].
const Solver pocket = PocketSolver();
