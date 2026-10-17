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
