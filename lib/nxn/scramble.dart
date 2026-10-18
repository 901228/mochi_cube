import "dart:math";

import "../cube/algorithm.dart";
import "cube.dart";

/// How many turns TNoodle, the official scramble program, gives a random turn
/// scramble of each size.
const Map<int, int> randomTurnCounts = {2: 25, 3: 25, 4: 40, 5: 60, 6: 80, 7: 100};

/// The turns a random turn scramble of a cube of [size] draws from, and which
/// of them would be wasted after which, as TNoodle has it.
///
/// The turns are every face one layer deep and then wider, up to half the cube.
/// On an even cube a half is the same as the opposite half turned the other way
/// with the whole cube, so `3Lw` and the like are left out and `3Rw` stands for
/// both.
///
/// A turn is wasted when it cancels or merges with one already made: with the
/// last one, or with any earlier one still separated from it only by turns of
/// the same axis, since those commute. Merging is counted up to a rotation of
/// the whole cube, so `R` then `Lw'` on a 3x3x3 would be the single turn `Rw`
/// on a cube held differently, and `Rw Lw'` on a 4x4x4 nothing at all.
///
/// TNoodle works that out by comparing whole states. Here it is worked out on
/// the turn amounts of the layers of one axis, which is the same question:
/// turns of one axis only ever move those layers, and a rotation about that
/// axis adds the same amount to every one of them.
// shortcut: two states can also agree up to a rotation about a different axis
// when the cube is symmetric enough, which TNoodle would count and this does
// not. The test compares the two from solved and from a scrambled state and
// they agree; compare whole states, as TNoodle does, if one ever differs.
class NxNTurns {
  final int size;

  /// Every turn a scramble may make, as indices of [nxnMoves].
  late final List<int> candidates = [
    for (var width = 1; width <= size ~/ 2 || width == 1; width++)
      for (var face = 0; face < 6; face++)
        // The second half of an even cube: the first half, held differently.
        if (!(size.isEven && width == size ~/ 2 && face >= 3))
          for (var amount = 0; amount < 3; amount++) ((width - 1) * 6 + face) * 3 + amount,
  ];

  /// The turns of one axis that are a single turn, in the form [_key] gives.
  late final Set<int> _single = {for (final move in candidates) _key(_layers(move))};

  NxNTurns(this.size);

  /// Which of the three axes [move] turns about: U and D, R and L, F and B.
  int axisOf(int move) => nxnMoves(size).axisOf(move) % 3;

  /// Whether [next] would be wasted straight after [previous].
  bool wastes(int previous, int next) {
    if (axisOf(previous) != axisOf(next)) return false;
    final a = _layers(previous);
    final b = _layers(next);
    final key = _key([for (var i = 0; i < size; i++) a[i] + b[i]]);
    return key == 0 || _single.contains(key);
  }

  /// Whether [next] would be wasted after [moves].
  bool wastedAfter(List<int> moves, int next) {
    for (var i = moves.length - 1; i >= 0 && axisOf(moves[i]) == axisOf(next); i--) {
      if (wastes(moves[i], next)) return true;
    }
    return false;
  }

  /// How far [move] turns each layer of its axis, counted in quarter turns
  /// clockwise as seen from U, R or F, layer 0 being the one on that face.
  List<int> _layers(int move) {
    final moves = nxnMoves(size);
    final face = moves.axisOf(move) % 6;
    final width = moves.axisOf(move) ~/ 6 + 1;
    final quarters = moves.amountOf(move) + 1;
    final layers = List.filled(size, 0);
    for (var i = 0; i < width; i++) {
      // From the far face, the same turn is the other way round.
      if (face < 3) {
        layers[i] = quarters;
      } else {
        layers[size - 1 - i] = 4 - quarters;
      }
    }
    return layers;
  }

  /// The layers' turns with a rotation taken off so the last one does not
  /// turn, as one number. Zero when they come to a rotation, or nothing.
  int _key(List<int> layers) {
    var key = 0;
    for (var i = 0; i < size - 1; i++) {
      key = key * 4 + (layers[i] - layers[size - 1]) % 4;
    }
    return key;
  }
}

/// A random turn scramble of a cube of [size], as the WCA scrambles the cubes
/// from 5x5x5 up.
///
/// Each turn is drawn evenly from those of [NxNTurns] that would not be wasted,
/// which is what TNoodle does, [length] of them: by default 60 for a 5x5x5, 80
/// for a 6x6x6 and 100 for a 7x7x7.
///
/// [random] defaults to [Random.secure]; pass a seeded [Random] to reproduce a
/// scramble.
// shortcut: TNoodle also redraws a scramble that can be solved in one turn, per
// regulation 4b3. Sixty turns with none wasted do not come to that in practice,
// and checking it needs a solver; add one if a much shorter [length] is used.
Algorithm randomNxNScramble(int size, {Random? random, int? length}) {
  final rng = random ?? Random.secure();
  final turns = NxNTurns(size);
  final total =
      length ?? randomTurnCounts[size] ?? (throw ArgumentError.value(size, "size", "has no default length"));

  final moves = <int>[];
  while (moves.length < total) {
    final allowed = [
      for (final move in turns.candidates)
        if (!turns.wastedAfter(moves, move)) move,
    ];
    moves.add(allowed[rng.nextInt(allowed.length)]);
  }
  return Algorithm(moves, moveSet: nxnMoves(size));
}
