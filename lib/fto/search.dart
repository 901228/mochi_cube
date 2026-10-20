import "dart:math";

import "../cube/algorithm.dart";
import "cube.dart";
import "cubie.dart";
import "facelets.dart";
import "tables.dart";

/// Levi Gibson's fto3phase, the solver the official scramble program uses for
/// the FTO.
///
/// Phase 1 places the D triangles and edges so that F, BR and BL are no longer
/// needed; phase 2 finishes the R, L, B and D half and pairs each corner with
/// the triangles of the U, F, BR and BL half that go with it, so that U is not
/// needed either; phase 3 solves what is left. The best of the first 500 or so
/// phase 1 solutions is kept for phase 2, so the answer is short but not the
/// shortest.
abstract final class FtoSearch {
  static const int _minG1Candidates = 500;

  /// fto3phase's moves that solve [cube].
  static List<int> solveCubie(FtoCubie cube) {
    FtoTables.init();
    final candidates = _g1Iterate(cube);
    final g1AndG2 = _g2Iterate(cube, candidates);
    final g2 = FtoCubie();
    cube.applyMovesInto(g1AndG2, g2);
    return [...g1AndG2, ..._g3Iterate(g2)];
  }

  /// Moves that solve [cube], not the fewest.
  ///
  /// Throws [FormatException] if the stickers are not those of an FTO.
  static Algorithm solve(Fto cube) => _algorithm(solveCubie(ftoCubieFromFacelets(cube.facelets)));

  static Algorithm _algorithm(List<int> moves) => Algorithm([
    for (final m in moves) ftoMoves.parse(FtoCubie.moveNames[m ~/ 2] + (m.isOdd ? "'" : "")),
  ], moveSet: ftoMoves);

  /// Whether [move] is worth making after [lastMove]: not the same face, and
  /// not one that commutes with it and comes before it in the order.
  static bool _isValidMove(int lastMove, int move) =>
      ((_invalidMoves[lastMove ~/ 2] >> (move ~/ 2)) & 1) != 1;

  static final List<int> _invalidMoves = () {
    final invalid = List.filled(8, 0);
    for (var a1 = 0; a1 < 8; a1++) {
      invalid[a1] = 1 << a1;
      for (var a2 = 0; a2 < a1; a2++) {
        final one = FtoCubie()
          ..turn(a1 * 2)
          ..turn(a2 * 2);
        final two = FtoCubie()
          ..turn(a2 * 2)
          ..turn(a1 * 2);
        if (one == two) invalid[a1] |= 1 << a2;
      }
    }
    return invalid;
  }();

  static List<List<int>> _g1Iterate(FtoCubie cubie) {
    final candidates = <List<int>>[];
    final moves = <int>[];
    final edge = cubie.g1PackEdges();
    final tri = cubie.g1PackTriangles();
    for (var depth = 0; candidates.length < _minG1Candidates; depth++) {
      _g1Search(depth, edge, tri, candidates, moves);
    }
    return candidates;
  }

  static void _g1Search(int depth, int edge, int tri, List<List<int>> candidates, List<int> moves) {
    final prun = FtoTables.g1Bound(edge, tri);
    if (depth < prun) return;
    if (prun == 0 && depth == 0) {
      candidates.add([...moves]);
      return;
    }
    if (depth <= 0) return;
    for (final move in FtoTables.g1Moveset) {
      if (moves.isNotEmpty && !_isValidMove(moves.last, move)) continue;
      moves.add(move);
      _g1Search(
        depth - 1,
        FtoTables.g1EdgeMoves[edge * 16 + move],
        FtoTables.g1TriangleMoves[tri * 16 + move],
        candidates,
        moves,
      );
      moves.removeLast();
    }
  }

  static List<int> _g2Iterate(FtoCubie cubie, List<List<int>> candidates) {
    final states = [
      for (final moves in candidates)
        () {
          final c = FtoCubie();
          cubie.applyMovesInto(moves, c);
          return [
            c.g2PackEdges(),
            c.g2PackTriangles(),
            for (var color = 0; color < 4; color++) c.g2PackTriples(color),
          ];
        }(),
    ];
    final moves = <int>[];
    for (var depth = 0; ; depth++) {
      for (var c = 0; c < states.length; c++) {
        final searchDepth = depth - candidates[c].length;
        if (searchDepth < 0) continue;
        final s = states[c];
        if (_g2Search(searchDepth, s[0], s[1], s[2], s[3], s[4], s[5], moves)) {
          return [...candidates[c], ...moves];
        }
      }
    }
  }

  /// Redundant moves are only looked for within the phase, as fto3phase does.
  static bool _g2Search(int depth, int edge, int tri, int t0, int t1, int t2, int t3, List<int> moves) {
    final p = FtoTables.g2TriplePrun;
    final triplePrun = max(max(p[t0], p[t1]), max(p[t2], p[t3]));
    if (depth < triplePrun) return false;
    final txePrun = FtoTables.g2TxEBound(edge, tri);
    if (depth < txePrun) return false;
    if (triplePrun == 0 && txePrun == 0) return true;
    if (depth == 0) return false;

    final m = FtoTables.g2TripleMoves;
    for (final move in FtoTables.g2Moveset) {
      if (moves.isNotEmpty && !_isValidMove(moves.last, move)) continue;
      moves.add(move);
      if (_g2Search(
        depth - 1,
        FtoTables.g2EdgeMoves[edge * 10 + move],
        FtoTables.g2TriangleMoves[tri * 10 + move],
        m[t0 * 10 + move],
        m[t1 * 10 + move],
        m[t2 * 10 + move],
        m[t3 * 10 + move],
        moves,
      )) {
        return true;
      }
      moves.removeLast();
    }
    return false;
  }

  static List<int> _g3Iterate(FtoCubie cubie) {
    final edges = cubie.g3PackEdges();
    final corners = cubie.g3PackCorners();
    final moves = <int>[];
    for (var depth = 0; ; depth++) {
      if (_g3Search(depth, edges, corners, moves)) return moves;
    }
  }

  static bool _g3Search(int depth, int edges, int corners, List<int> moves) {
    if (depth < FtoTables.g3CornerPrun[corners]) return false;
    if (corners == FtoTables.solvedG3Corners && edges == FtoTables.solvedG3Edges) return true;
    if (depth == 0) return false;
    for (final move in FtoTables.g3Moveset) {
      if (moves.isNotEmpty && !_isValidMove(moves.last, move)) continue;
      moves.add(move);
      if (_g3Search(
        depth - 1,
        FtoTables.g3EdgeMoves[edges * 10 + move],
        FtoTables.g3CornerMoves[corners * 10 + move],
        moves,
      )) {
        return true;
      }
      moves.removeLast();
    }
    return false;
  }

  /// A scramble from a state drawn evenly from every state of the FTO, as the
  /// WCA defines it: the solution, written backwards.
  static Algorithm scrambleFor(FtoCubie cube) => _algorithm(solveCubie(cube)).inverse;
}

/// An FTO drawn evenly from all its states.
FtoCubie randomFtoCubie({Random? random}) => FtoCubie.random(random ?? Random.secure());

/// A scramble drawn evenly from every state of the FTO, as the official
/// program makes them.
///
/// [random] defaults to [Random.secure]; pass a seeded [Random] to reproduce a
/// scramble.
// shortcut: no check for a scramble shorter than regulation 4b3's minimum of
// two moves, as TNoodle's Puzzle base class would do: a random state that near
// solved is about one in 10^28. Add one if a scramble ever must be proven long
// enough.
Algorithm randomFtoScramble({Random? random}) => FtoSearch.scrambleFor(randomFtoCubie(random: random));
