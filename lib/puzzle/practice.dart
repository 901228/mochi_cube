/// Scrambles that leave one step of a solve to do, for drilling it.
///
/// Each is a uniformly random state of the kind that step starts from, solved
/// and reversed — the same construction [randomStateScramble] uses, with part
/// of the cube held solved.
///
/// The pieces, in CFOP order:
///
/// - the **cross** is the four D edges
/// - **F2L** adds the four D corners and the four middle edges, so the bottom
///   two layers are finished
/// - **OLL** orients what is left, the four U corners and four U edges
/// - **PLL** permutes them
library;

import "dart:math";

import "../cube/algorithm.dart";
import "algorithm.dart";
import "cube/cubie_cube.dart";
import "search.dart";

/// The four corners of the last layer.
const List<int> lastLayerCorners = [0, 1, 2, 3]; // URF UFL ULB UBR

/// The four edges of the last layer.
const List<int> lastLayerEdges = [0, 1, 2, 3]; // UR UF UL UB

/// The four D edges: the cross.
const List<int> crossEdges = [4, 5, 6, 7]; // DR DF DL DB

/// The four corner-and-edge pairs that F2L slots in, as `(corner, edge)`.
const List<(int, int)> f2lPairs = [
  (4, 8), // DFR with FR
  (5, 9), // DLF with FL
  (6, 10), // DBL with BL
  (7, 11), // DRB with BR
];

/// A cube with the given pieces solved and everything else drawn evenly.
///
/// A position that is not free holds its own piece, untwisted; the free ones
/// are permuted and, unless the matching `oriented` flag is set, twisted at
/// random.
///
/// Three things have to hold for a cube to exist at all, and each is settled
/// after the draw rather than by rejecting: corner twists must sum to a
/// multiple of three, edge flips to an even number, and the two permutations
/// must have the same parity. The first two are fixed by the last free piece,
/// the third by swapping two free pieces — which is a bijection, so the result
/// is still even across the states that are reachable.
///
/// Holding everything solved is allowed and gives back a solved cube.
CubieCube randomStateWith({
  List<int> solvedCorners = const [],
  List<int> solvedEdges = const [],
  bool orientedCorners = false,
  bool orientedEdges = false,
  Random? random,
}) {
  final rng = random ?? Random.secure();
  final cube = CubieCube();

  final freeCorners = [
    for (var i = 0; i < CubieCube.cornerLength; i++)
      if (!solvedCorners.contains(i)) i,
  ];
  final freeEdges = [
    for (var i = 0; i < CubieCube.edgeLength; i++)
      if (!solvedEdges.contains(i)) i,
  ];
  final cornerPieces = [...freeCorners]..shuffle(rng);
  for (var i = 0; i < freeCorners.length; i++) {
    cube.cornerState[freeCorners[i]] = cornerPieces[i];
  }

  final edgePieces = [...freeEdges]..shuffle(rng);
  for (var i = 0; i < freeEdges.length; i++) {
    cube.edgeState[freeEdges[i]] = edgePieces[i] << 1;
  }

  if (!orientedCorners && freeCorners.isNotEmpty) {
    var total = 0;
    for (var i = 0; i < freeCorners.length - 1; i++) {
      final twist = rng.nextInt(3);
      total += twist;
      cube.cornerState[freeCorners[i]] |= twist << 3;
    }
    cube.cornerState[freeCorners.last] |= ((3 - total % 3) % 3) << 3;
  }

  if (!orientedEdges && freeEdges.isNotEmpty) {
    var flipped = 0;
    for (var i = 0; i < freeEdges.length - 1; i++) {
      final flip = rng.nextInt(2);
      flipped ^= flip;
      cube.edgeState[freeEdges[i]] |= flip;
    }
    cube.edgeState[freeEdges.last] |= flipped;
  }

  // Only one of the two permutations can be odd here, and an odd permutation
  // needs at least two free pieces to be one, so there is always a pair to
  // swap.
  if (cube.cornerParityBit != cube.edgeParityBit) {
    if (freeCorners.length >= 2) {
      final a = freeCorners[0];
      final b = freeCorners[1];
      final piece = cube.cornerState[a] & 0x7;
      cube.cornerState[a] = (cube.cornerState[a] & 0xF8) | (cube.cornerState[b] & 0x7);
      cube.cornerState[b] = (cube.cornerState[b] & 0xF8) | piece;
    } else {
      final a = freeEdges[0];
      final b = freeEdges[1];
      final piece = cube.edgeState[a] >> 1;
      cube.edgeState[a] = ((cube.edgeState[b] >> 1) << 1) | (cube.edgeState[a] & 1);
      cube.edgeState[b] = (piece << 1) | (cube.edgeState[b] & 1);
    }
  }

  return cube;
}

/// A scramble that leaves the last layer's permutation to do.
///
/// The bottom two layers are solved and the last layer is oriented, so every
/// sticker on top already faces up. There are 288 such states — the 24
/// permutations of the four corners and of the four edges, halved because the
/// two must have the same parity — and this draws evenly from the 287 that are
/// not already solved.
///
/// Some of those are a U turn from solved. That is a real PLL case, not a bad
/// draw, so it is kept.
Algorithm pllPracticeScramble({Random? random}) => _practiceScramble(
  random: random,
  solvedCorners: [for (final pair in f2lPairs) pair.$1],
  solvedEdges: [...crossEdges, for (final pair in f2lPairs) pair.$2],
  orientedCorners: true,
  orientedEdges: true,
  accept: (cube) => cube.cperm != 0 || cube.eperm != 0,
);

/// A scramble that leaves the last layer's orientation to do.
///
/// The bottom two layers are solved; the last layer is both misoriented and
/// permuted at random, which is what an OLL drill wants — recognise the case,
/// then execute it. Whatever permutation is left afterwards is a PLL.
///
/// States where the last layer already happens to be oriented are drawn again:
/// there would be no OLL to do.
Algorithm ollPracticeScramble({Random? random}) => _practiceScramble(
  random: random,
  solvedCorners: [for (final pair in f2lPairs) pair.$1],
  solvedEdges: [...crossEdges, for (final pair in f2lPairs) pair.$2],
  accept: (cube) =>
      lastLayerCorners.any((i) => cube.cornerState[i] >> 3 != 0) ||
      lastLayerEdges.any((i) => cube.edgeState[i] & 1 != 0),
);

/// A scramble that leaves F2L to do.
///
/// The cross is solved and nothing else is. [solvedPairs] also finishes that
/// many of the four slots, chosen at random, so `solvedPairs: 3` drills the
/// last pair.
///
/// Throws [RangeError] if [solvedPairs] is outside 0 to 4.
Algorithm f2lPracticeScramble({int solvedPairs = 0, Random? random}) {
  RangeError.checkValueInInterval(solvedPairs, 0, f2lPairs.length, "solvedPairs");
  final rng = random ?? Random.secure();

  final chosen = ([...f2lPairs]..shuffle(rng)).take(solvedPairs).toList();
  return _practiceScramble(
    random: rng,
    solvedCorners: [for (final pair in chosen) pair.$1],
    solvedEdges: [...crossEdges, for (final pair in chosen) pair.$2],
    accept: (cube) => cube.toFaceletString() != _solvedFacelets,
  );
}

final String _solvedFacelets = CubieCube().toFaceletString();

Algorithm _practiceScramble({
  required List<int> solvedCorners,
  required List<int> solvedEdges,
  required bool Function(CubieCube cube) accept,
  bool orientedCorners = false,
  bool orientedEdges = false,
  Random? random,
}) {
  while (true) {
    final cube = randomStateWith(
      solvedCorners: solvedCorners,
      solvedEdges: solvedEdges,
      orientedCorners: orientedCorners,
      orientedEdges: orientedEdges,
      random: random,
    );
    if (!accept(cube)) {
      continue;
    }

    final result = Search.solveCube(cube);
    final solution = result.solution;
    if (solution == null) {
      continue;
    }
    return solution.algorithm.inverse;
  }
}

/// Whether the bottom two layers of [cube] are solved.
bool isF2lSolved(CubieCube cube) {
  for (final pair in f2lPairs) {
    if (cube.cornerState[pair.$1] != pair.$1) return false;
    if (cube.edgeState[pair.$2] != pair.$2 << 1) return false;
  }
  return isCrossSolved(cube);
}

/// Whether the cross is solved.
bool isCrossSolved(CubieCube cube) =>
    crossEdges.every((edge) => cube.edgeState[edge] == edge << 1);

/// Whether every sticker of the last layer faces up.
bool isLastLayerOriented(CubieCube cube) =>
    lastLayerCorners.every((corner) => cube.cornerState[corner] >> 3 == 0) &&
    lastLayerEdges.every((edge) => cube.edgeState[edge] & 1 == 0);
