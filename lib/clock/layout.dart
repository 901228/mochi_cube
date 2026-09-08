import "../layout.dart";
import "dials.dart";

export "../layout.dart" show ClockLayout;

/// The eighteen dials and eight pins of a Rubik's Clock.
final ClockLayout clockLayout = _build();

/// How far apart the two sides are drawn.
const double _gap = 0.6;

/// One side is three dials across, so the second one along starts here.
const double _backOrigin = 3 + _gap;

ClockLayout _build() {
  /// The back on the left and the front on the right, which is how cstimer and
  /// twisty timer draw a clock.
  ///
  /// A scramble turns the front nine first and the back five after the `y2`, so
  /// the back is the side you are looking at when you put the puzzle down. That
  /// is the one worth reading first, and readers coming from those timers
  /// expect to find it on the left.
  Point centreOf(int dial) {
    final side = dial ~/ 9;
    final slot = dial % 9;
    return ((1 - side) * _backOrigin + slot % 3 + 0.5, slot ~/ 3 + 0.5);
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
