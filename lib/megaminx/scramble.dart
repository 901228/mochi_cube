import "dart:math";

import "../cube/algorithm.dart";
import "cube.dart";

/// A Megaminx scramble as the WCA makes them: seven rows of ten turns, `R` and
/// `D` by turns each `++` or `--` at random, and every row closed with `U`
/// turned the way the row's last `D` went.
///
/// That is TNoodle's construction, Stefan Pochmann's, move for move; the
/// state is not drawn at random, there being far too many and no solver.
///
/// [random] defaults to [Random.secure]; pass a seeded [Random] to reproduce a
/// scramble.
Algorithm randomMegaminxScramble({Random? random}) {
  final rng = random ?? Random.secure();
  final moves = <int>[];
  for (var row = 0; row < 7; row++) {
    var anticlockwise = 0;
    for (var turn = 0; turn < 10; turn++) {
      anticlockwise = rng.nextInt(2);
      // R++ R-- D++ D-- are moves 0 to 3.
      moves.add((turn.isEven ? 0 : 2) + anticlockwise);
    }
    moves.add(4 + anticlockwise);
  }
  return Algorithm(moves, moveSet: megaminxMoves);
}

/// [algorithm] in rows, as a Megaminx scramble is written: a line break after
/// each `U`.
String megaminxNotation(Algorithm algorithm) {
  final out = StringBuffer();
  for (var i = 0; i < algorithm.length; i++) {
    final move = algorithm[i];
    out.write(megaminxMoves.render(move));
    if (i < algorithm.length - 1) out.write(move >= 4 ? "\n" : " ");
  }
  return out.toString();
}
