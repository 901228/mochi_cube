import "dart:math";

import "../cube/layout.dart";
import "cube.dart";

export "../cube/layout.dart" show Point, PuzzleLayout;

/// The net of a Skewb: 30 polygons, in the order `toFacelets()` gives them.
///
/// The cube's cross from [cubeNetPosition], each face a square cut into a
/// diamond and four corner triangles. The slots are the 3x3x3's tiles 0, 2, 4,
/// 6 and 8, so each polygon sits where that tile would.
final PuzzleLayout skewbLayout = PuzzleLayout(
  width: 4,
  height: 3,
  stickers: [for (var facelet = 0; facelet < nSkewbFacelets; facelet++) _sticker(facelet)],
);

List<Point> _sticker(int facelet) {
  final (column, row) = cubeNetPosition[facelet ~/ 5];
  final x = column.toDouble();
  final y = row.toDouble();
  // Clockwise on screen, like the cube's squares.
  return switch (facelet % 5) {
    0 => [(x, y), (x + 0.5, y), (x, y + 0.5)],
    1 => [(x + 0.5, y), (x + 1, y), (x + 1, y + 0.5)],
    centreSlot => [(x + 0.5, y), (x + 1, y + 0.5), (x + 0.5, y + 1), (x, y + 0.5)],
    3 => [(x, y + 0.5), (x + 0.5, y + 1), (x, y + 1)],
    _ => [(x + 1, y + 0.5), (x + 1, y + 1), (x + 0.5, y + 1)],
  };
}

/// The Skewb as csTimer and Twisty Timer draw it: the cube seen from a corner, with U on top and F and
/// R below it, and the other three faces unfolded beside them: L left of F, D under F and B right of R.
///
/// The same 30 polygons in the same order as [skewbLayout], each face's five cut from the same square
/// but sheared into a rhombus, so a face is a diamond centre and four corner triangles still. U is a
/// diamond; F, D and L lean down to the right and R and B up, in the isometric angle of 30 degrees.
final PuzzleLayout skewbIsometricLayout = _isometric();

/// How far a face's side runs across the picture: its cosine of 30 degrees.
final double _across = cos(pi / 6);

PuzzleLayout _isometric() {
  // Where each face's top left corner goes, and how its top edge leans: down, up or, for U, round.
  final h = _across;
  // U, R, F, D, L, B.
  final origins = <(double, double)>[(2 * h, 0), (2 * h, 1), (h, 0.5), (h, 1.5), (0, 0), (3 * h, 0.5)];

  Point place(int face, Point p) {
    final (x, y) = p;
    final (ox, oy) = origins[face];
    return switch (face) {
      // The square's corners go to the diamond's: top left to the top, top right to the right.
      0 => (ox + h * (x - y), oy + 0.5 * (x + y)),
      1 || 5 => (ox + h * x, oy - 0.5 * x + y),
      _ => (ox + h * x, oy + 0.5 * x + y),
    };
  }

  // The flat layout's squares are on the cross: bring each to the origin of its face first.
  return PuzzleLayout(
    width: 4 * h,
    height: 3,
    stickers: [
      for (var facelet = 0; facelet < nSkewbFacelets; facelet++)
        [
          for (final (x, y) in skewbLayout[facelet])
            place(facelet ~/ 5, (x - cubeNetPosition[facelet ~/ 5].$1, y - cubeNetPosition[facelet ~/ 5].$2)),
        ],
    ],
  );
}
