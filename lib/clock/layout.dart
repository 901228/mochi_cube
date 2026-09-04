import "../cube/layout.dart";
import "dials.dart";

/// Where a Rubik's Clock's dials sit when it is drawn flat.
///
/// The two sides side by side, front on the left, each a three by three grid of
/// dials with the four pins at the middles of its four corner blocks. Nothing
/// here is a polygon, so unlike the other puzzles this is circles rather than a
/// [PuzzleLayout].
///
/// Geometry only, as everywhere else: no colours, no hands, no dial faces.
class ClockLayout with Layout {
  @override
  final double width;

  @override
  final double height;

  /// The middle of each of the eighteen dials, in the order `toDials()` gives.
  final List<Point> dials;

  /// How big a dial is.
  final double dialRadius;

  /// The middle of each pin: the four of the front, then the four of the back.
  ///
  /// In the order [clockCorners] gives, so pin `i` is the one that drives the
  /// block of dials at corner `clockCorners[i]`. Which way a pin is pushed is
  /// not part of a clock's state and so is not here; these are only where they
  /// are.
  final List<Point> pins;

  /// How big a pin is.
  final double pinRadius;

  const ClockLayout({
    required this.width,
    required this.height,
    required this.dials,
    required this.dialRadius,
    required this.pins,
    required this.pinRadius,
  });
}

/// The eighteen dials and eight pins of a Rubik's Clock.
final ClockLayout clockLayout = _build();

/// How far apart the two sides are drawn.
const double _gap = 0.4;

/// One side is three dials across, so the far side starts here.
const double _backOrigin = 3 + _gap;

ClockLayout _build() {
  Point centreOf(int dial) {
    final side = dial ~/ 9;
    final slot = dial % 9;
    return (side * _backOrigin + slot % 3 + 0.5, slot ~/ 3 + 0.5);
  }

  return ClockLayout(
    width: 2 * 3 + _gap,
    height: 3,
    dials: [for (var dial = 0; dial < nClockDials; dial++) centreOf(dial)],
    dialRadius: 0.45,
    // A pin turns a two by two block of dials, and sits in the middle of it.
    pins: [
      for (var side = 0; side < 2; side++)
        for (final corner in clockCorners)
          () {
            final block = dialBlock(corner).map((slot) => centreOf(side * 9 + slot));
            return (
              block.map((point) => point.$1).reduce((a, b) => a + b) / block.length,
              block.map((point) => point.$2).reduce((a, b) => a + b) / block.length,
            );
          }(),
    ],
    pinRadius: 0.18,
  );
}
