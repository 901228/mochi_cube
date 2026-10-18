import "dart:math";

import "../layout.dart";

export "../layout.dart" show Point, Square1Layout;

/// The Square-1 drawn as csTimer and the official scrambler draw it: the top
/// layer as seen from above, the middle layer's front, and the bottom layer as
/// seen from below.
///
/// The top has the back at the top of the picture and the bottom has the front
/// there, as if the puzzle were tipped towards you to look underneath, so right
/// is on the right in both. Each layer is a cube of side 2 when it is square,
/// edges being 30 degree wedges and corners 60 degree kites from its middle,
/// and the side stickers are the outer band of each piece.
///
/// Slot `i` of the top covers the angles `30i - 15` to `30i + 15`, counted
/// anticlockwise on the page from straight up, which puts slot 0, the back
/// edge, at the top and the cut between it and slot 11 just right of it. The
/// bottom runs the same way round from just right of straight down, where its
/// back is.
final Square1Layout square1Layout = _build();

/// How far in a piece's top sticker stops, leaving the rest for its sides.
const double _inner = 0.7;

/// How far out a corner's tip is: the corner of a square of side 2.
final double _tip = sqrt(2);

/// How far out the edge of a wedge is.
final double _rim = 1 / cos(pi / 12);

/// The middle layer's height, and the gap either side of it.
const double _middleHeight = 0.35;
const double _gap = 0.15;

Square1Layout _build() {
  final top = (_tip, _tip);
  final bottom = (_tip, 3 * _tip + _middleHeight + 2 * _gap);

  /// Where the slot boundary [step] thirtieths round from [start] is, [radius]
  /// out from [centre].
  Point at(Point centre, double start, int step, double radius) {
    final angle = (start + 30 * step) * pi / 180;
    return (centre.$1 - radius * sin(angle), centre.$2 - radius * cos(angle));
  }

  Point shrink(Point centre, Point p) =>
      (centre.$1 + (p.$1 - centre.$1) * _inner, centre.$2 + (p.$2 - centre.$2) * _inner);

  List<Point> side(Point centre, Point a, Point b) => [a, b, shrink(centre, b), shrink(centre, a)];

  final edges = <List<List<Point>>>[];
  final corners = <List<List<Point>>>[];
  for (var slot = 0; slot < 24; slot++) {
    final centre = slot < 12 ? top : bottom;
    final start = slot < 12 ? -15.0 : 195.0;
    final step = slot % 12;

    final a = at(centre, start, step, _rim);
    final b = at(centre, start, step + 1, _rim);
    edges.add([
      _clockwise([centre, shrink(centre, a), shrink(centre, b)]),
      _clockwise(side(centre, a, b)),
    ]);

    // A kite's far point is its tip, half way round, as far out as a corner of
    // the square.
    final tip = at(centre, start, step + 1, _tip);
    final c = at(centre, start, step + 2, _rim);
    corners.add([
      _clockwise([centre, shrink(centre, a), shrink(centre, tip), shrink(centre, c)]),
      _clockwise(side(centre, a, tip)),
      _clockwise(side(centre, tip, c)),
    ]);
  }

  // The cut crosses the front a wedge's half width left of the middle. Turned
  // over, the right piece shows its back, which the cut crosses as far right of
  // the middle, so it is that much narrower.
  final y = 2 * _tip + _gap;
  final cut = _tip - tan(pi / 12);
  final right = _tip + 1;
  List<Point> bar(double from, double to) =>
      _clockwise([(from, y), (to, y), (to, y + _middleHeight), (from, y + _middleHeight)]);

  return Square1Layout(
    width: 2 * _tip,
    height: 4 * _tip + _middleHeight + 2 * _gap,
    edges: edges,
    corners: corners,
    middle: [bar(_tip - 1, cut), bar(cut, right), bar(cut, cut + 1 - tan(pi / 12))],
    pieceFaces: _pieceFaces,
    middleFaces: const [_f, _f, _b],
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

const int _u = 0, _r = 1, _f = 2, _d = 3, _l = 4, _b = 5;

/// The faces each piece shows: its top or bottom, then its sides in slot
/// order. Solved, slot 0 is the back edge and the slots run anticlockwise from
/// above on top and from below underneath, which is what fixes these.
const List<List<int>> _pieceFaces = [
  [_u, _b], [_u, _b, _l], [_u, _l], [_u, _l, _f], [_u, _f], [_u, _f, _r], [_u, _r], [_u, _r, _b], //
  [_d, _r], [_d, _b, _r], [_d, _f], [_d, _r, _f], [_d, _l], [_d, _f, _l], [_d, _b], [_d, _l, _b],
];
