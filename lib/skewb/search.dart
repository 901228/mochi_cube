import "dart:math";

import "../cube/algorithm.dart";
import "coordinates.dart";
import "cube.dart";
import "tables.dart";

/// The Skewb solver.
///
/// As with the 2x2x2 and the Pyraminx there is no search: the distance to
/// solved is known for every state, so solving takes any move that leaves the
/// puzzle one step nearer and repeats. Every solution is therefore **optimal**.
abstract final class SkewbSearch {
  /// The fewest turns that solve [cube].
  static Algorithm solve(SkewbCube cube) {
    final tables = SkewbTables();
    var index = tables.stateOf(cube);
    var remaining = tables.distance.at(index);

    final moves = <int>[];
    while (remaining > 0) {
      var stepped = false;
      for (var move = 0; move < skewbMoves.count && !stepped; move++) {
        final next = tables.successor(index, move);
        if (tables.distance.at(next) == remaining - 1) {
          moves.add(move);
          index = next;
          remaining--;
          stepped = true;
        }
      }
      if (!stepped) {
        throw StateError("No move gets nearer from state $index");
      }
    }

    return Algorithm(moves, moveSet: skewbMoves);
  }

  /// How many turns [cube] is from solved. Exact, not a bound.
  static int distanceOf(SkewbCube cube) => SkewbTables().distanceOf(cube);
}

/// A Skewb drawn evenly from all 3149280 states.
///
/// [random] defaults to [Random.secure]; pass a seeded [Random] to reproduce a
/// puzzle.
SkewbCube randomSkewbCube({Random? random}) {
  final rng = random ?? Random.secure();
  final cube = SkewbCube();
  SkewbPart.corners.write(cube.facelets, rng.nextInt(SkewbPart.corners.length));
  SkewbPart.centres.write(cube.facelets, rng.nextInt(SkewbPart.centres.length));
  return cube;
}

/// A scramble drawn evenly from every state of the Skewb.
///
/// A uniformly random state, solved and reversed, as the WCA defines it. The
/// solutions are optimal, so [minimumMoves] holds exactly: regulation 4b3 asks
/// a Skewb scramble to be at least seven moves from solved.
Algorithm randomSkewbScramble({Random? random, int minimumMoves = 7}) {
  final rng = random ?? Random.secure();
  while (true) {
    final solution = SkewbSearch.solve(randomSkewbCube(random: rng));
    if (solution.length >= minimumMoves) {
      return solution.inverse;
    }
  }
}
