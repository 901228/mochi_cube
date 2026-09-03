import "dart:math";

import "../cube/algorithm.dart";
import "cube.dart";
import "tables.dart";

/// The Pyraminx solver.
///
/// As with the 2x2x2 there is no search: the distance to solved is known for
/// every state, so solving takes any move that leaves the puzzle one step
/// nearer and repeats. Every solution is therefore **optimal**.
///
/// Tips are not part of this. Each is one turn on its own and cannot be got
/// wrong, so they are added to a scramble rather than solved.
abstract final class PyraminxSearch {
  /// The fewest layer turns that solve [cube].
  static Algorithm solve(PyraminxCube cube) {
    final tables = PyraminxTables();
    var index = tables.stateOf(cube);
    var remaining = tables.distance.at(index);

    final moves = <int>[];
    while (remaining > 0) {
      var stepped = false;
      for (var move = 0; move < layerMoveCount && !stepped; move++) {
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

    return Algorithm(moves, moveSet: pyraminxMoves);
  }

  /// How many layer turns [cube] is from solved. Exact, not a bound.
  static int distanceOf(PyraminxCube cube) => PyraminxTables().distanceOf(cube);
}

/// A Pyraminx drawn evenly from all 933120 states, tips aside.
///
/// [random] defaults to [Random.secure]; pass a seeded [Random] to reproduce a
/// puzzle.
PyraminxCube randomPyraminxCube({Random? random}) {
  final rng = random ?? Random.secure();
  final cube = PyraminxCube();

  var vertices = rng.nextInt(PyraminxTables.nVertices);
  for (var i = 0; i < PyraminxCube.vertexCount; i++) {
    cube.vertices[i] = vertices % 3;
    vertices ~/= 3;
  }

  cube.edges.setAll(
    0,
    PyraminxTables.evenPermutations[rng.nextInt(PyraminxTables.nEdgePerms)],
  );

  var flips = rng.nextInt(PyraminxTables.nEdgeFlips);
  var total = 0;
  for (var i = 0; i < PyraminxCube.edgeCount - 1; i++) {
    cube.flips[i] = flips % 2;
    total ^= cube.flips[i];
    flips ~/= 2;
  }
  cube.flips[PyraminxCube.edgeCount - 1] = total;

  return cube;
}

/// A scramble drawn evenly from every state of the Pyraminx.
///
/// A uniformly random state, solved and reversed, then the tips set at random.
/// Tips come last, which is how a scramble is written.
///
/// [minimumMoves] is checked against the layer turns only, so it is stricter
/// than WCA regulation 4b3, which asks a Pyraminx scramble to be at least six
/// moves from solved and counts the tips among them.
///
/// Set [tips] to false to leave them out.
Algorithm randomPyraminxScramble({
  Random? random,
  int minimumMoves = 6,
  bool tips = true,
}) {
  final rng = random ?? Random.secure();

  while (true) {
    final cube = randomPyraminxCube(random: rng);
    final solution = PyraminxSearch.solve(cube);
    if (solution.length < minimumMoves) {
      continue;
    }

    final moves = [...solution.inverse.moves];
    if (tips) {
      for (var tip = 0; tip < PyraminxCube.vertexCount; tip++) {
        final amount = rng.nextInt(3);
        if (amount == 0) {
          continue; // this tip is already where it should be
        }
        moves.add((PyraminxCube.vertexCount + tip) * pyraminxMoves.amounts.length + amount - 1);
      }
    }

    return Algorithm(moves, moveSet: pyraminxMoves);
  }
}
