import "clock.dart";

/// The eighteen dials you can see on a Rubik's Clock.
///
/// Nine on the front and nine on the back, each side read as a 3x3 grid in
/// reading order, the back stored after the front:
///
/// ```
///   front        back
///   0 1 2      9  10 11
///   3 4 5      12 13 14
///   6 7 8      15 16 17
/// ```
///
/// The back is what you see having turned the puzzle over about its vertical
/// axis, so front position `(r, c)` is behind back position `(r, 2 - c)`.
///
/// These are a picture of the state rather than the state itself. A
/// [ClockState] is fourteen numbers, and the eighteen are a linear image of
/// them — which is why the puzzle has 12^14 positions and not 12^18.
const int nClockDials = 18;

/// Where a front dial sits when the puzzle is turned over.
int mirroredDial(int front) => (front ~/ 3) * 3 + (2 - front % 3);

/// The corners of a 3x3 grid, as `UL`, `UR`, `DL`, `DR`.
const List<int> clockCorners = [0, 2, 6, 8];

/// How far each of the fourteen moves turns each of the eighteen dials.
///
/// Worked out from the mechanism rather than written down. Each corner carries
/// a pin, and the pin says which side that corner's wheel drives: turning it
/// takes the 2x2 block of dials at that corner round on the chosen side. The
/// corner dials themselves are single pieces showing through both sides, so
/// they come round on the other side too.
///
/// Three things fall out of that, and all three are checked in the tests. The
/// fourteen rows are independent over Z12, so the moves really do reach 12^14
/// states. Exactly four dials always move together with their opposite number,
/// and they are exactly the four corners. And 18 - 4 leaves the 14 the puzzle
/// is known to have.
final List<List<int>> clockMoveEffect = _buildEffect();

/// The 2x2 block of dials at [corner] of a 3x3 grid.
List<int> dialBlock(int corner) {
  final rows = corner ~/ 3 == 0 ? [0, 1] : [1, 2];
  final columns = corner % 3 == 0 ? [0, 1] : [1, 2];
  return [
    for (final r in rows)
      for (final c in columns) r * 3 + c,
  ];
}

/// Which corners each move drives, and from which side.
///
/// The names after `y2` are read with the puzzle turned over, so the back's top
/// two corners are the front's `UR` and `UL`.
const List<(bool fromFront, List<int> corners)> _moveCorners = [
  (true, [2]), // UR
  (true, [8]), // DR
  (true, [6]), // DL
  (true, [0]), // UL
  (true, [0, 2]), // U
  (true, [2, 8]), // R
  (true, [6, 8]), // D
  (true, [0, 6]), // L
  (true, [0, 2, 6, 8]), // ALL
  (false, [0, 2]), // y2 U
  (false, [0, 6]), // y2 R
  (false, [6, 8]), // y2 D
  (false, [2, 8]), // y2 L
  (false, [0, 2, 6, 8]), // y2 ALL
];

List<List<int>> _buildEffect() {
  return [
    for (final (fromFront, corners) in _moveCorners)
      () {
        final effect = List.filled(nClockDials, 0);
        for (final corner in corners) {
          if (fromFront) {
            for (final dial in dialBlock(corner)) {
              effect[dial] = 1;
            }
            // The corner is one piece, so it shows through the back as well.
            effect[9 + mirroredDial(corner)] = 1;
          } else {
            for (final dial in dialBlock(mirroredDial(corner))) {
              effect[9 + dial] = 1;
            }
            effect[corner] = 1;
          }
        }
        return effect;
      }(),
  ];
}

extension ClockDials on ClockState {
  /// The eighteen dials, each 0 to 11, in the order [nClockDials] describes.
  List<int> toDials() {
    final shown = List.filled(nClockDials, 0);
    for (var move = 0; move < ClockState.dialCount; move++) {
      final amount = dials[move];
      if (amount == 0) {
        continue;
      }
      final effect = clockMoveEffect[move];
      for (var dial = 0; dial < nClockDials; dial++) {
        if (effect[dial] != 0) {
          shown[dial] = (shown[dial] + amount) % ClockState.positions;
        }
      }
    }
    return shown;
  }

  /// The eighteen dials as two lines of nine, front then back.
  String toDialString() {
    final shown = toDials();
    String side(int from) => [
      for (var row = 0; row < 3; row++)
        [for (var col = 0; col < 3; col++) shown[from + row * 3 + col]].join(" "),
    ].join("  ");
    return "front ${side(0)} | back ${side(9)}";
  }
}

/// Reading a clock back from the dials you can see.
abstract final class ClockDialReading {
  /// The state showing these eighteen dials.
  ///
  /// Only 12^14 of the 12^18 ways to set eighteen dials are a real clock: the
  /// four corner dials are single pieces, so each has to read the same through
  /// both sides. Anything else is rejected.
  ///
  /// Throws [FormatException] if there are not eighteen numbers, if one is out
  /// of range, or if a corner disagrees with itself.
  static ClockState fromDials(List<int> shown) {
    if (shown.length != nClockDials) {
      throw FormatException("Expected $nClockDials dials, got ${shown.length}");
    }
    for (final dial in shown) {
      if (dial < 0 || dial >= ClockState.positions) {
        throw FormatException("Dial out of range: $dial");
      }
    }
    for (final corner in clockCorners) {
      final behind = shown[9 + mirroredDial(corner)];
      if (shown[corner] != behind) {
        throw FormatException(
          "Corner $corner reads ${shown[corner]} at the front and $behind at the back, "
          "but it is one piece",
        );
      }
    }

    // Fourteen of the dials are enough to pin the state down; solve for the
    // moves that produce them.
    final rows = [
      for (final dial in _pivots)
        [for (var move = 0; move < ClockState.dialCount; move++) clockMoveEffect[move][dial]],
    ];
    final targets = [for (final dial in _pivots) shown[dial]];
    final state = ClockState(_solveMod12(rows, targets));

    // The other four dials have to agree, or these were not a clock's.
    final rebuilt = state.toDials();
    for (var dial = 0; dial < nClockDials; dial++) {
      if (rebuilt[dial] != shown[dial]) {
        throw FormatException("These dials are not a position the puzzle can reach");
      }
    }
    return state;
  }

  /// Dials whose rows can be reduced without dividing: enough to solve by.
  static const List<int> _pivots = [0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 13, 14, 16];
}

/// Solve `rows * x = targets` over Z12 by elimination.
///
/// Only pivots that are odd and not a multiple of three can be divided by, and
/// [ClockDialReading._pivots] is chosen so that some always is.
List<int> _solveMod12(List<List<int>> rows, List<int> targets) {
  const m = ClockState.positions;
  final n = ClockState.dialCount;
  final a = [
    for (var i = 0; i < n; i++) [...rows[i], targets[i]],
  ];

  for (var column = 0; column < n; column++) {
    var pivot = -1;
    for (var row = column; row < n; row++) {
      if (_isUnitMod12(a[row][column])) {
        pivot = row;
        break;
      }
    }
    if (pivot < 0) {
      throw StateError("The dial equations cannot be solved; the effect table is wrong");
    }

    final swap = a[column];
    a[column] = a[pivot];
    a[pivot] = swap;

    final inverse = _inverseMod12(a[column][column]);
    for (var k = 0; k <= n; k++) {
      a[column][k] = (a[column][k] * inverse) % m;
    }
    for (var row = 0; row < n; row++) {
      if (row == column || a[row][column] == 0) {
        continue;
      }
      final factor = a[row][column];
      for (var k = 0; k <= n; k++) {
        a[row][k] = (a[row][k] - factor * a[column][k]) % m;
        if (a[row][k] < 0) a[row][k] += m;
      }
    }
  }

  return [for (var i = 0; i < n; i++) a[i][n]];
}

bool _isUnitMod12(int value) {
  final v = value % ClockState.positions;
  return v.isOdd && v % 3 != 0;
}

int _inverseMod12(int value) {
  final v = value % ClockState.positions;
  for (var candidate = 1; candidate < ClockState.positions; candidate++) {
    if (v * candidate % ClockState.positions == 1) return candidate;
  }
  throw ArgumentError("$value has no inverse mod ${ClockState.positions}");
}
