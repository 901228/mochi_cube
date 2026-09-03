import "../cube/enums.dart";
import "../puzzle/cube/cubie_cube.dart";

/// The 2x2x2 as coordinates.
///
/// A 2x2x2 is the corners of a 3x3x3 and nothing else, so the cube model and
/// the move cubes are reused rather than written again — those are already
/// checked against the kociemba solver, and a second copy of corner composition
/// would not be.
///
/// The puzzle has no centres, so nothing fixes its orientation and every state
/// would otherwise be counted 24 times over. Holding one corner still settles
/// it: [fixedCorner] never moves under U, R and F, which is why those three
/// faces are all a 2x2x2 needs.
///
/// That leaves 7 corners to permute and 6 orientations to choose, the seventh
/// being forced because the total must be divisible by three:
///
///     7! * 3^6 = 5040 * 729 = 3674160
///
/// Small enough to hold the exact distance to solved for every one of them.
extension PocketCoordinates on CubieCube {
  /// Permutation of the seven corners that move. `[0, 5040)`
  int get cperm7 {
    final ranks = _ranks();
    var index = 0;
    for (var i = 0; i < movingCorners.length - 1; i++) {
      var smaller = 0;
      for (var j = i + 1; j < movingCorners.length; j++) {
        if (ranks[j] < ranks[i]) {
          smaller++;
        }
      }
      index = index * (movingCorners.length - i) + smaller;
    }
    return index;
  }

  set cperm7(int index) {
    final remaining = [for (var i = 0; i < movingCorners.length; i++) i];
    final ranks = List.filled(movingCorners.length, 0);

    // Read the factorial digits back off, most significant first.
    for (var i = 0; i < movingCorners.length - 1; i++) {
      final radix = movingCorners.length - i;
      var divisor = 1;
      for (var f = 2; f < radix; f++) {
        divisor *= f;
      }
      ranks[i] = remaining.removeAt(index ~/ divisor);
      index %= divisor;
    }
    ranks[movingCorners.length - 1] = remaining.single;

    for (var i = 0; i < movingCorners.length; i++) {
      final position = movingCorners[i];
      cornerState[position] = (cornerState[position] & 0xF8) | movingCorners[ranks[i]];
    }
  }

  /// Orientation of the moving corners. `[0, 729)`
  ///
  /// Six digits are stored; the seventh follows from the total having to be
  /// divisible by three, and the corner that is held still is always untwisted.
  int get twist6 {
    var index = 0;
    for (var i = 0; i < movingCorners.length - 1; i++) {
      index = index * 3 + (cornerState[movingCorners[i]] >> 3) % 3;
    }
    return index;
  }

  set twist6(int index) {
    var total = 0;
    for (var i = movingCorners.length - 2; i >= 0; i--) {
      final twist = index % 3;
      index ~/= 3;
      total += twist;
      final position = movingCorners[i];
      cornerState[position] = (cornerState[position] & 0x7) | (twist << 3);
    }

    final last = movingCorners[movingCorners.length - 1];
    cornerState[last] = (cornerState[last] & 0x7) | (((3 - total % 3) % 3) << 3);
  }

  /// Where each moving corner sits in [movingCorners].
  List<int> _ranks() => [
    for (final position in movingCorners) movingCorners.indexOf(cornerState[position] & 0x7),
  ];
}

/// The corner held still, so that the puzzle has a fixed orientation.
///
/// U, R and F leave it alone, which is what makes three faces enough.
const Corner fixedCorner = Corner.downBackLeft;

/// The seven corner positions that move, in ascending order.
const List<int> movingCorners = [0, 1, 2, 3, 4, 5, 7];

/// Permutations of the seven moving corners.
const int nCperm7 = 5040;

/// Orientations of the moving corners, the seventh being forced.
const int nTwist6 = 729;

/// Every state of the puzzle.
const int nStates = nCperm7 * nTwist6;

/// The nine turns a 2x2x2 needs, as indices into the 3x3x3 move cubes.
///
/// U, R and F with their half and anticlockwise turns — which happen to be the
/// first nine, so the notation and the move numbering are the 3x3x3's.
const List<int> pocketMoves = [0, 1, 2, 3, 4, 5, 6, 7, 8];

const int nPocketMoves = 9;
