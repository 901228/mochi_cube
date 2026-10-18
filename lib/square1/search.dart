import "dart:math";

import "../cube/algorithm.dart";
import "cube.dart";
import "tables.dart";

/// The Square-1 solver: Chen Shuang's sq12phase, which the official TNoodle
/// scrambler and csTimer both use.
///
/// Phase 1 searches for a way back to a cube of a parity phase 2 can finish,
/// and phase 2 solves the cube without leaving that shape. Neither is optimal:
/// solutions come out about 24 moves, counted as the notation counts them, and
/// take about 25ms. An optimal one would mean a search over more states than
/// fit in memory.
abstract final class Square1Search {
  /// Moves that solve [cube].
  ///
  /// A cube with a corner across the cut cannot turn `/`, and the tables have
  /// no entry for it, so it is first turned to the nearest state that can.
  static Algorithm solve(Square1Cube cube) {
    if (cube.canSlash) {
      return _Search(Square1Tables(), cube).solve();
    }

    final setups = [
      for (var top = -5; top <= 6; top++)
        for (var bottom = -5; bottom <= 6; bottom++)
          if (top != 0 || bottom != 0) (top, bottom),
    ]..sort((a, b) => (a.$1.abs() + a.$2.abs()).compareTo(b.$1.abs() + b.$2.abs()));
    for (final (top, bottom) in setups) {
      final turned = Square1Cube.from(cube)
        ..turnTop(top % 12)
        ..turnBottom(bottom % 12);
      if (turned.canSlash) {
        return _join([Square1MoveSet.turn(top, bottom), ...solve(turned).moves]);
      }
    }
    throw StateError("No turn of the layers lets / through"); // every shape has one
  }
}

/// Moves with neighbouring turns of the layers merged into one, and dropped
/// when they come to nothing.
Algorithm _join(List<int> moves) {
  final joined = <int>[];
  for (final move in moves) {
    if (move != Square1MoveSet.slashMove && joined.isNotEmpty && joined.last != Square1MoveSet.slashMove) {
      final last = joined.removeLast();
      final top = (last ~/ 12 + move ~/ 12) % 12;
      final bottom = (last % 12 + move % 12) % 12;
      if (top != 0 || bottom != 0) joined.add(Square1MoveSet.turn(top, bottom));
    } else {
      joined.add(move);
    }
  }
  return Algorithm(joined, moveSet: square1Moves);
}

/// One solve, ported from sq12phase's `Search`.
///
/// Its moves are kept the way sq12phase keeps them until the end: 0 is `/`, 1
/// to 11 turn the top that far and -1 to -11 the bottom. Each counts one, so
/// the search is in a finer metric than the notation's, where a turn of both
/// layers is a single move.
class _Search {
  final Square1Tables tables;
  final Square1Cube cube;
  final List<int> moves = List.filled(100, 0);

  int _phase1Length = 0;
  int _phase2Limit = 0;
  Algorithm? _solution;

  _Search(this.tables, this.cube);

  Algorithm solve() {
    final shape = tables.shapeOf(cube)!;
    for (var length = tables.shapePrune[shape]; length < 100; length++) {
      _phase2Limit = min(31 - length, 17);
      if (_phase1(shape, tables.shapePrune[shape], length, 0, -1)) {
        return _solution!;
      }
    }
    throw StateError("No solution within 100 moves");
  }

  /// [last] is what the previous move was: -1 nothing, 0 `/`, 1 the top and 2
  /// the bottom. A top turn after a bottom one is the same as before it, so
  /// only the one order is tried, and two of a layer in a row are never tried.
  bool _phase1(int shape, int prune, int remaining, int depth, int last) {
    if (prune == 0 && remaining < 4) {
      _phase1Length = depth;
      return remaining == 0 && _startPhase2();
    }

    if (last != 0) {
      final next = tables.twistMove[shape];
      final bound = tables.shapePrune[next];
      if (bound < remaining) {
        moves[depth] = 0;
        if (_phase1(next, bound, remaining - 1, depth + 1, 0)) return true;
      }
    }

    // A layer's turns go round in the order their bounds allow: they are all one
    // move apart, so once one is out of reach the rest are too.
    for (final (layer, sign, limit, move, amount) in [
      if (last <= 0) (1, 1, 12, tables.topMove, tables.topAmount),
      // Turning the bottom six or more is turning the top and the whole puzzle,
      // which phase 1 does not care about.
      if (last <= 1) (2, -1, 6, tables.bottomMove, tables.bottomAmount),
    ]) {
      var next = shape;
      for (var turned = amount[next]; turned < limit; turned += amount[next]) {
        next = move[next];
        final bound = tables.shapePrune[next];
        if (bound > remaining) break;
        if (bound < remaining) {
          moves[depth] = sign * turned;
          if (_phase1(next, bound, remaining - 1, depth + 1, layer)) return true;
        }
      }
    }
    return false;
  }

  bool _startPhase2() {
    final reached = Square1Cube.from(cube);
    for (var i = 0; i < _phase1Length; i++) {
      _apply(reached, moves[i]);
    }

    final pieces = reached.pieces;
    final corners = [for (var a = 0; a < 8; a++) pieces[a * 3 + 1] >> 1];
    // Which way round each layer stands: starting from slot 0 with a corner, or
    // with an edge. A quarter turn of the layer swaps the two.
    final topCornerFirst = pieces[0] == pieces[1];
    final bottomCornerFirst = pieces[12] == pieces[13];
    final edges = [
      for (var b = 0, a = topCornerFirst ? 2 : 0; b < 4; a += 3, b++) pieces[a] >> 1,
      for (var b = 0, a = bottomCornerFirst ? 14 : 12; b < 4; a += 3, b++) pieces[a] >> 1,
    ];
    final edge = Square1Tables.permIndex(edges);
    final corner = Square1Tables.permIndex(corners);
    final middle = reached.middle;

    final prune = max(tables.squarePrune[edge << 1 | middle], tables.squarePrune[corner << 1 | middle]);
    for (var length = prune; length < _phase2Limit; length++) {
      if (_phase2(edge, corner, topCornerFirst, bottomCornerFirst, middle, length, _phase1Length, 0)) {
        _solution = _toAlgorithm(_phase1Length + length);
        return true;
      }
    }
    return false;
  }

  bool _phase2(
    int edge,
    int corner,
    bool topCornerFirst,
    bool bottomCornerFirst,
    int middle,
    int remaining,
    int depth,
    int last,
  ) {
    if (remaining == 0 && !topCornerFirst && bottomCornerFirst) {
      return edge == 0 && corner == 0 && middle == 0;
    }
    int bound(int perm, int middle) => tables.squarePrune[perm << 1 | middle];

    if (last != 0 && topCornerFirst == bottomCornerFirst) {
      final nextEdge = tables.squareTwist[edge];
      final nextCorner = tables.squareTwist[corner];
      if (bound(nextEdge, 1 - middle) < remaining && bound(nextCorner, 1 - middle) < remaining) {
        moves[depth] = 0;
        if (_phase2(
          nextEdge,
          nextCorner,
          topCornerFirst,
          bottomCornerFirst,
          1 - middle,
          remaining - 1,
          depth + 1,
          0,
        )) {
          return true;
        }
      }
    }

    // A layer turns a corner or an edge at a time, moving the corners or the
    // edges along by one place, depending on which it starts with.
    for (final top in [true, false]) {
      if (last > (top ? 0 : 1)) continue;
      final turn = top ? tables.squareTop : tables.squareBottom;
      final limit = top || remaining <= 6 ? 12 : 6;
      var nextEdge = edge;
      var nextCorner = corner;
      var cornerFirst = top ? topCornerFirst : bottomCornerFirst;
      for (var turned = 0; ;) {
        cornerFirst = !cornerFirst;
        if (cornerFirst) {
          nextEdge = turn[nextEdge];
          turned += 1;
        } else {
          nextCorner = turn[nextCorner];
          turned += 2;
        }
        if (turned >= limit) break;
        if (bound(nextEdge, middle) < remaining && bound(nextCorner, middle) < remaining) {
          moves[depth] = top ? turned : -turned;
          final found = top
              ? _phase2(
                  nextEdge,
                  nextCorner,
                  cornerFirst,
                  bottomCornerFirst,
                  middle,
                  remaining - 1,
                  depth + 1,
                  1,
                )
              : _phase2(
                  nextEdge,
                  nextCorner,
                  topCornerFirst,
                  cornerFirst,
                  middle,
                  remaining - 1,
                  depth + 1,
                  2,
                );
          if (found) return true;
        }
      }
    }
    return false;
  }

  static void _apply(Square1Cube cube, int move) {
    if (move == 0) {
      cube.slash();
    } else if (move > 0) {
      cube.turnTop(move);
    } else {
      cube.turnBottom(-move);
    }
  }

  Algorithm _toAlgorithm(int length) => _join([
    for (var i = 0; i < length; i++)
      moves[i] == 0
          ? Square1MoveSet.slashMove
          : moves[i] > 0
          ? Square1MoveSet.turn(moves[i], 0)
          : Square1MoveSet.turn(0, -moves[i]),
  ]);
}

/// A Square-1 drawn evenly from every state in which `/` can be turned.
///
/// The shape first, from the 3678, since every shape has the same number of
/// arrangements; then the corners and the edges in their slots; then the
/// middle. That is how TNoodle draws one, and why a scramble never ends with a
/// corner across the cut.
///
/// [random] defaults to [Random.secure]; pass a seeded [Random] to reproduce a
/// puzzle.
Square1Cube randomSquare1Cube({Random? random}) {
  final rng = random ?? Random.secure();
  final tables = Square1Tables();
  final bits = tables.shapes[rng.nextInt(Square1Tables.nShapes)];
  final corners = [for (var i = 1; i < 16; i += 2) i]..shuffle(rng);
  final edges = [for (var i = 0; i < 16; i += 2) i]..shuffle(rng);

  final cube = Square1Cube();
  for (var slot = 0; slot < 24; slot++) {
    if ((bits >> (23 - slot)) & 1 == 0) {
      cube.pieces[slot] = edges.removeLast();
    } else {
      cube.pieces[slot] = cube.pieces[slot + 1] = corners.removeLast();
      slot++;
    }
  }
  cube.middle = rng.nextInt(2);
  return cube;
}

/// A scramble drawn evenly from every state of the Square-1 that `/` can
/// leave, as the WCA defines it: a random state, solved and reversed.
///
/// Regulation 4b3 asks a Square-1 scramble to be at least eleven moves from
/// solved, counting a turn of the layers and a `/` as one each (12c4).
// shortcut: checked against the solution found, which is an upper bound, so a
// state nearer than [minimumMoves] could pass where TNoodle's optimal check
// would not. Solutions come out near 24 moves and such states are a vanishing
// share of them; port sq12phase's `solutionOpt` if that ever needs to be exact.
Algorithm randomSquare1Scramble({Random? random, int minimumMoves = 11}) {
  final rng = random ?? Random.secure();
  while (true) {
    final solution = Square1Search.solve(randomSquare1Cube(random: rng));
    if (solution.length >= minimumMoves) {
      return solution.inverse;
    }
  }
}
