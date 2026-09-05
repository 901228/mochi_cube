import "../layout.dart";

export "../layout.dart" show Layout, Point, PuzzleLayout;

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
