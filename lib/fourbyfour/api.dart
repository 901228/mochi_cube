import "dart:math";
import "dart:typed_data";

import "../cube/algorithm.dart";
import "../nxn/cube.dart";
import "cubies.dart";
import "search.dart";

/// The 4x4x4 solver.
abstract final class FourByFourSearch {
  /// Moves that solve [cube], up to turning the whole cube.
  ///
  /// There are no fixed centres on a 4x4x4, so a solved cube is one with every
  /// face a single colour in any orientation; the moves reach one of the 24, not
  /// necessarily the one the cube started in.
  ///
  /// About 44 moves and never the shortest. [cube] must use the letters
  /// `URFDLB` for its faces; its colours are read from where the pieces are, so
  /// two cubes that differ only by a whole-cube rotation are different states.
  ///
  /// Throws [FormatException] if the stickers are not those of a 4x4x4.
  static Algorithm solve(NxNCube cube) {
    if (cube.size != 4) {
      throw ArgumentError.value(cube.size, "cube", "is not a 4x4x4");
    }
    final state = FullCube.fromFacelets(Uint8List.fromList(cube.facelets));
    return Algorithm(ThreePhaseSearch(inverse: false).search(state), moveSet: nxnMoves(4));
  }
}

/// A scramble drawn from every state of the 4x4x4, as the WCA defines it: a
/// random state, solved, and the solution reversed.
///
/// Leaves a cube that is the random one up to turning the whole cube, which is
/// all a scramble can ask. Only `Uw`, `Rw` and `Fw` are used for the wide turns,
/// the rest being the same turns with the cube held differently.
///
/// [random] defaults to [Random.secure]; pass a seeded [Random] to reproduce a
/// scramble.
// shortcut: moves are written as the search finds them, where TNoodle also
// merges neighbouring turns of one axis, so "R Rw" would be one turn there and
// two here. Rare, and the scramble is the same state either way; merge them if
// the notation ever has to match TNoodle's character for character.
Algorithm randomFourByFourScramble({Random? random}) =>
    Algorithm(ThreePhaseSearch().randomState(random ?? Random.secure()), moveSet: nxnMoves(4));
