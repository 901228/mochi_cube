import "../cube/algorithm.dart";
import "cube/cubie_cube.dart";
import "cube/moves.dart";

export "../cube/algorithm.dart";

extension AlgorithmExtension on CubieCube {
  /// Apply every move of [algorithm] in order.
  void apply(Algorithm algorithm) {
    for (final move in algorithm.moves) {
      moveIndex(move);
    }
  }
}

extension AlgorithmCubeExtension on Algorithm {
  /// The cube reached by applying this algorithm to a solved one.
  CubieCube get cube {
    final result = CubieCube();
    result.apply(this);
    return result;
  }
}
