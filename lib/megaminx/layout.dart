import "dart:math";

import "../cube/layout.dart";

export "../cube/layout.dart" show Point, PuzzleLayout;

/// The net of a Megaminx: 132 polygons, in the order `toFacelets()` gives them.
///
/// TNoodle's drawing, the one on official scramble sheets: two flowers of six
/// pentagons, U and the five round it on the left as seen from above, and D
/// and the five round it on the right. Each pentagon is cut into five corners,
/// five edges and the centre. Within a flower, a piece that spans the middle
/// face and a petal is drawn joined.
final PuzzleLayout megaminxLayout = _build();

PuzzleLayout _build() {
  // TNoodle's own construction, with a pentagon's corners one unit from its
  // middle and the gap scaled to match.
  const radius = 1.0;
  const gap = 2 / 30;
  final x = radius * sqrt(2 * (1 - cos(.6 * pi)));
  final a = radius * cos(.1 * pi);
  final b = x * cos(.1 * pi);
  final c = x * cos(.3 * pi);
  final d = x * sin(.1 * pi);
  final e = x * sin(.3 * pi);
  final leftX = gap + a + b + d / 2;
  final leftY = gap + x + radius - d;
  final shift = leftX + d * 0.6 + radius * (cos(.1 * pi) + cos(.2 * pi));

  // Where each face's pentagon is, and whether it points up.
  final centres = <(double, double, bool)>[
    (leftX, leftY, true), // U
    (leftX - c, leftY - e, false), // BL
    (leftX + c, leftY - e, false), // BR
    (leftX + b, leftY + d, false), // R
    (leftX, leftY + x, false), // F
    (leftX - b, leftY + d, false), // L
    (shift + gap + a + b, gap + x + radius, false), // D
    (shift + gap + a + b - c, gap + x + e + radius, true), // DR
    (shift + gap + a, gap + x - d + radius, true), // DBR
    (shift + gap + a + b, gap + radius, true), // B
    (shift + gap + a + 2 * b, gap + x - d + radius, true), // DBL
    (shift + gap + a + b + c, gap + x + e + radius, true), // DL
  ];

  final stickers = <List<Point>>[];
  for (var face = 0; face < 12; face++) {
    final (cx, cy, up) = centres[face];
    final corners = [
      for (final turn in [1.3, 1.7, .1, .5, .9])
        (cx + radius * cos((turn - (up ? .2 : 0)) * pi), cy + radius * sin((turn - (up ? .2 : 0)) * pi)),
    ];
    // TNoodle draws U as it is and turns the rest so their slot 0 lines up
    // with the flower's: the others by one corner on the left, two on the
    // right.
    final rotate = face == 0
        ? 0
        : face <= 5
        ? 1
        : 2;
    final drawn = _pentagon(corners);
    for (var slot = 0; slot < 10; slot++) {
      stickers.add(drawn[(slot - 2 * rotate) % 10]);
    }
    stickers.add(drawn[10]);
  }

  // TNoodle's sizes are rounded down, so measure the drawing instead.
  final xs = [
    for (final sticker in stickers)
      for (final p in sticker) p.$1,
  ];
  final ys = [
    for (final sticker in stickers)
      for (final p in sticker) p.$2,
  ];
  final left = xs.reduce(min) - gap;
  final top = ys.reduce(min) - gap;
  return PuzzleLayout(
    width: xs.reduce(max) - left + gap,
    height: ys.reduce(max) - top + gap,
    stickers: [
      for (final sticker in stickers) _clockwise([for (final (px, py) in sticker) (px - left, py - top)]),
    ],
  );
}

/// A pentagon's eleven stickers, TNoodle's way: 2i the corner at corner i,
/// 2i + 1 the edge after it, 10 the middle.
List<List<Point>> _pentagon(List<Point> corners) {
  Point mix(Point p, Point q, double t) => (p.$1 + (q.$1 - p.$1) * t, p.$2 + (q.$2 - p.$2) * t);
  // Two points along each side, 0.4 and 0.6 of the way.
  final near = [for (var i = 0; i < 5; i++) mix(corners[i], corners[(i + 1) % 5], .4)];
  final far = [for (var i = 0; i < 5; i++) mix(corners[i], corners[(i + 1) % 5], .6)];
  // The middle pentagon's corners, where the cuts from neighbouring sides cross.
  final inner = [
    for (var i = 0; i < 5; i++) _intersection(near[i], far[(3 + i) % 5], near[(i + 1) % 5], far[(4 + i) % 5]),
  ];
  return [
    for (var i = 0; i < 5; i++) ...[
      [corners[i], near[i], inner[i], far[(4 + i) % 5]],
      [near[i], far[i], inner[(i + 1) % 5], inner[i]],
    ],
    inner,
  ];
}

/// Where the line through [p1] and [p2] meets the one through [p3] and [p4].
Point _intersection(Point p1, Point p2, Point p3, Point p4) {
  double det(double a, double b, double c, double d) => a * d - b * c;
  final (x1, y1) = p1;
  final (x2, y2) = p2;
  final (x3, y3) = p3;
  final (x4, y4) = p4;
  final denominator = det(x1 - x2, y1 - y2, x3 - x4, y3 - y4);
  return (
    det(det(x1, y1, x2, y2), x1 - x2, det(x3, y3, x4, y4), x3 - x4) / denominator,
    det(det(x1, y1, x2, y2), y1 - y2, det(x3, y3, x4, y4), y3 - y4) / denominator,
  );
}

/// The polygon, wound clockwise on the page as the other layouts' are.
List<Point> _clockwise(List<Point> polygon) {
  var area = 0.0;
  for (var i = 0; i < polygon.length; i++) {
    final (x1, y1) = polygon[i];
    final (x2, y2) = polygon[(i + 1) % polygon.length];
    area += x1 * y2 - x2 * y1;
  }
  return area > 0 ? polygon : polygon.reversed.toList();
}
