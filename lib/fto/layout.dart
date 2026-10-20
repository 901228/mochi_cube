import "../cube/layout.dart";

export "../cube/layout.dart" show Point, PuzzleLayout;

/// The FTO drawn as TNoodle draws it on official scramble sheets: two squares,
/// each the four faces round one corner seen from outside, U, R, F and L on
/// the left and B, BL, D and BR on the right. 72 triangles, in the order
/// `toFacelets()` gives them.
final PuzzleLayout ftoLayout = _build();

/// The gap between the two squares, in stickers.
const double _gap = 0.4;

PuzzleLayout _build() {
  // A face is drawn with its shared corner in the middle of its square and its
  // outer side along the top, then turned a quarter at a time into place.
  Point rotate(Point p) => (1.5 - (p.$2 - 1.5), 1.5 + (p.$1 - 1.5));

  final stickers = <List<Point>>[];
  for (var face = 0; face < 8; face++) {
    var a = (1.5, 1.5);
    var b = (0.0, 0.0);
    var c = (3.0, 0.0);
    for (var i = 0; i < face % 4; i++) {
      a = rotate(a);
      b = rotate(b);
      c = rotate(c);
    }
    final shift = face < 4 ? 0.0 : 3 + _gap;
    Point at(int i, int j) => (
      shift + a.$1 + (b.$1 - a.$1) * i / 3 + (c.$1 - a.$1) * j / 3,
      a.$2 + (b.$2 - a.$2) * i / 3 + (c.$2 - a.$2) * j / 3,
    );
    for (final triangle in _slotTriangles) {
      stickers.add(_clockwise([for (final (i, j) in triangle) at(i, j)]));
    }
  }
  return PuzzleLayout(width: 6 + _gap, height: 3, stickers: stickers);
}

/// The lattice points of each slot's triangle, as in `cube.dart`.
const List<List<(int, int)>> _slotTriangles = [
  [(1, 0), (0, 1), (1, 1)],
  [(0, 0), (1, 0), (0, 1)],
  [(1, 1), (0, 2), (1, 2)],
  [(0, 1), (1, 1), (0, 2)],
  [(0, 2), (1, 2), (0, 3)],
  [(2, 0), (1, 1), (2, 1)],
  [(1, 0), (2, 0), (1, 1)],
  [(1, 1), (2, 1), (1, 2)],
  [(2, 0), (3, 0), (2, 1)],
];

List<Point> _clockwise(List<Point> polygon) {
  var area = 0.0;
  for (var i = 0; i < polygon.length; i++) {
    final (x1, y1) = polygon[i];
    final (x2, y2) = polygon[(i + 1) % polygon.length];
    area += x1 * y2 - x2 * y1;
  }
  return area > 0 ? polygon : polygon.reversed.toList();
}
