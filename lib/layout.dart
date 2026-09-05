/// What every layout can say about itself: how big it is, and how to fit it in.
///
/// The puzzles do not all draw the same way — a cube is polygons and a Clock is
/// circles — so this is the part they share, and all a caller needs to size the
/// box it is going to draw into.
///
/// It is `sealed` so that a caller's switch over the kinds is exhaustive: adding
/// a layout that is neither polygons nor circles should break the drawing code
/// rather than fall quietly into a default branch. That is also why the three
/// types live here together rather than beside the puzzles they describe — a
/// sealed type's subtypes must share its library.
sealed class Layout {
  const Layout();

  /// The width of the drawing, in the same units as the points.
  double get width;

  /// The height of the drawing, in the same units as the points.
  double get height;

  /// How to fit this layout into a box of [boxWidth] by [boxHeight].
  ///
  /// Multiply a point by [scale] and then add [dx] and [dy]: the result is the
  /// layout as large as it will go, centred.
  ({double scale, double dx, double dy}) fitInto(double boxWidth, double boxHeight) {
    final scale = boxWidth / width < boxHeight / height ? boxWidth / width : boxHeight / height;
    return (scale: scale, dx: (boxWidth - width * scale) / 2, dy: (boxHeight - height * scale) / 2);
  }
}

/// A point in a [PuzzleLayout]. `x` runs right and `y` runs down, as on a screen.
typedef Point = (double x, double y);

/// Where a puzzle's stickers sit when it is drawn flat.
///
/// Geometry and nothing else. There are no colours here, no line widths and no
/// gaps between stickers, for the same reason the rest of the package has none:
/// a caller draws with whatever scheme it likes, and insetting a polygon to
/// leave a gap is one line of its own code.
///
/// What is here is the part that is puzzle knowledge rather than drawing
/// preference — which sticker is next to which, and how a face folds out — so
/// that a front end does not have to work the net out again.
///
/// The polygons are index-matched to the facelets, so `stickers[i]` is where
/// `toFacelets()[i]` goes.
class PuzzleLayout extends Layout {
  @override
  final double width;

  @override
  final double height;

  /// One polygon per sticker, in the facelet order of the puzzle it belongs to.
  ///
  /// Wound the same way round for every sticker, so a caller can tell an
  /// outline from a hole if it wants to.
  final List<List<Point>> stickers;

  const PuzzleLayout({required this.width, required this.height, required this.stickers});

  /// How many stickers there are.
  int get length => stickers.length;

  /// The polygon of one sticker.
  List<Point> operator [](int facelet) => stickers[facelet];
}

/// Where a Rubik's Clock's dials sit when it is drawn flat.
///
/// The two sides side by side, front on the left, each a three by three grid of
/// dials with the four pins at the middles of its four corner blocks. Nothing
/// here is a polygon, so unlike the other puzzles this is circles rather than a
/// [PuzzleLayout].
///
/// Geometry only, as everywhere else: no colours, no hands, no dial faces.
class ClockLayout extends Layout {
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
  /// In the order `clockCorners` gives, so pin `i` is the one that drives the
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
