/// What every layout can say about itself: how big it is, and how to fit it in.
///
/// The puzzles do not all draw the same way — a cube is polygons and a Clock is
/// circles — so this is the part they share, and all a caller needs to size the
/// box it is going to draw into.
abstract mixin class Layout {
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
class PuzzleLayout with Layout {
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

/// A point in a [PuzzleLayout]. `x` runs right and `y` runs down, as on a screen.
typedef Point = (double x, double y);

/// Where each face sits in the net, in face-sized units.
///
/// The usual cross, with the faces in the package's U, R, F, D, L, B order:
///
/// ```
///     U
///   L F R B
///     D
/// ```
///
/// Read that way no face needs turning or reflecting: a face's first sticker is
/// the top left one of the square it is drawn in, which is exactly how the
/// facelet indices are numbered.
const List<(int column, int row)> cubeNetPosition = [
  (1, 0), // U
  (2, 1), // R
  (1, 1), // F
  (1, 2), // D
  (0, 1), // L
  (3, 1), // B
];

/// The net of an `n` by `n` cube, as `6 * n * n` squares.
///
/// One face is one unit across, so the whole net is 4 by 3 whatever `n` is.
PuzzleLayout cubeNetLayout(int n) {
  final size = 1 / n;
  return PuzzleLayout(
    width: 4,
    height: 3,
    stickers: [
      for (var face = 0; face < cubeNetPosition.length; face++)
        for (var tile = 0; tile < n * n; tile++)
          () {
            final (column, row) = cubeNetPosition[face];
            final x = column + (tile % n) * size;
            final y = row + (tile ~/ n) * size;
            return <Point>[(x, y), (x + size, y), (x + size, y + size), (x, y + size)];
          }(),
    ],
  );
}

/// The net of a 3x3x3: 54 squares, in the order `toFacelets()` gives them.
final PuzzleLayout cubeLayout = cubeNetLayout(3);

/// The net of a 2x2x2: 24 squares, in the order `toPocketFacelets()` gives them.
final PuzzleLayout pocketLayout = cubeNetLayout(2);
