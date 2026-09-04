import "dart:math";

import "package:mochi_cube/clock.dart";
import "package:mochi_cube/mochi_cube.dart";
import "package:mochi_cube/pocket.dart" show pocketLayout;
import "package:mochi_cube/pyraminx.dart";
import "package:test/test.dart";

/// How close two points have to be to count as the same corner.
const double _epsilon = 1e-9;

bool _same(Point a, Point b) => (a.$1 - b.$1).abs() < _epsilon && (a.$2 - b.$2).abs() < _epsilon;

/// How many corners two polygons have in common.
int _sharedCorners(List<Point> a, List<Point> b) =>
    a.where((point) => b.any((other) => _same(point, other))).length;

/// The area of a polygon, by the shoelace formula.
double _area(List<Point> polygon) {
  var total = 0.0;
  for (var i = 0; i < polygon.length; i++) {
    final (x1, y1) = polygon[i];
    final (x2, y2) = polygon[(i + 1) % polygon.length];
    total += x1 * y2 - x2 * y1;
  }
  return total.abs() / 2;
}

void _staysInsideTheBox(PuzzleLayout layout) {
  for (final sticker in layout.stickers) {
    for (final (x, y) in sticker) {
      expect(x, inInclusiveRange(-_epsilon, layout.width + _epsilon));
      expect(y, inInclusiveRange(-_epsilon, layout.height + _epsilon));
    }
  }
}

void main() {
  group("cube net", () {
    test("has one square per facelet", () {
      expect(cubeLayout.length, 54);
      expect(pocketLayout.length, 24);
      for (final sticker in cubeLayout.stickers) {
        expect(sticker.length, 4);
      }
    });

    test("stays inside its box", () {
      _staysInsideTheBox(cubeLayout);
      _staysInsideTheBox(pocketLayout);
    });

    test("covers six faces exactly", () {
      for (final layout in [cubeLayout, pocketLayout]) {
        final total = layout.stickers.map(_area).reduce((a, b) => a + b);
        expect(total, closeTo(6, 1e-9));
      }
    });

    test("no two stickers sit in the same place", () {
      final seen = <String>{};
      for (final sticker in cubeLayout.stickers) {
        expect(seen.add(sticker.first.toString()), isTrue);
      }
    });

    // The net is only a net if a piece that spans two faces is drawn in one
    // piece. Five of the twelve edges have both their faces side by side here;
    // each of those must be two squares sharing a full side.
    test("edges that are not split by the net are drawn joined", () {
      var joined = 0;
      for (final edge in edgeFacelet) {
        final a = cubeLayout[edge[0].index];
        final b = cubeLayout[edge[1].index];
        final shared = _sharedCorners(a, b);
        expect(shared, anyOf(0, 2), reason: "edge $edge shares $shared corners");
        if (shared == 2) joined++;
      }
      expect(joined, 5); // UF, FL, FR, BR and DF
    });

    test("fits into a box, centred", () {
      final fit = cubeLayout.fitInto(400, 400);
      expect(fit.scale, closeTo(100, 1e-9)); // 400 / 4 is tighter than 400 / 3
      expect(fit.dx, closeTo(0, 1e-9));
      expect(fit.dy, closeTo(50, 1e-9));
    });
  });

  group("pyraminx net", () {
    test("has one triangle per facelet", () {
      expect(pyraminxLayout.length, nPyraminxFacelets);
      for (final sticker in pyraminxLayout.stickers) {
        expect(sticker.length, 3);
      }
    });

    test("stays inside its box", () => _staysInsideTheBox(pyraminxLayout));

    test("covers the big triangle exactly, in equal pieces", () {
      final total = pyraminxLayout.stickers.map(_area).reduce((a, b) => a + b);
      expect(total, closeTo(sqrt(3), 1e-9)); // a triangle of side two
      for (final sticker in pyraminxLayout.stickers) {
        expect(_area(sticker), closeTo(sqrt(3) / 36, 1e-9));
      }
    });

    // The middle face touches all three others, and the piece along each of
    // those folds is one edge showing two of its stickers.
    test("the folds of the net are drawn joined", () {
      for (var face = 1; face < PyraminxCube.vertexCount; face++) {
        final edge = PyraminxCube.edgeIndexOf(0, face);
        final here = pyraminxLayout[0 * 9 + _edgeSlotOn(0, edge)];
        final there = pyraminxLayout[face * 9 + _edgeSlotOn(face, edge)];
        expect(_sharedCorners(here, there), 2, reason: "edge $edge between faces 0 and $face");
      }
    });

    test("the tips of a vertex meet at the point they share", () {
      for (var face = 1; face < PyraminxCube.vertexCount; face++) {
        for (final vertex in cornersOfFace(0)) {
          if (!cornersOfFace(face).contains(vertex)) continue;
          final here = pyraminxLayout[0 * 9 + tipSlots[cornersOfFace(0).indexOf(vertex)]];
          final there = pyraminxLayout[face * 9 + tipSlots[cornersOfFace(face).indexOf(vertex)]];
          expect(_sharedCorners(here, there), greaterThanOrEqualTo(1));
        }
      }
    });
  });

  group("clock layout", () {
    test("has one circle per dial", () {
      expect(clockLayout.dials.length, nClockDials);
      expect(clockLayout.pins.length, clockCorners.length * 2);
    });

    test("dials do not overlap", () {
      for (var a = 0; a < nClockDials; a++) {
        for (var b = a + 1; b < nClockDials; b++) {
          final (ax, ay) = clockLayout.dials[a];
          final (bx, by) = clockLayout.dials[b];
          final gap = sqrt(pow(ax - bx, 2) + pow(ay - by, 2));
          expect(gap, greaterThanOrEqualTo(2 * clockLayout.dialRadius - _epsilon));
        }
      }
    });

    test("everything is inside the box", () {
      for (final (x, y) in [...clockLayout.dials, ...clockLayout.pins]) {
        expect(x, inInclusiveRange(0, clockLayout.width));
        expect(y, inInclusiveRange(0, clockLayout.height));
      }
    });

    test("a pin sits between the four dials it turns", () {
      for (var side = 0; side < 2; side++) {
        for (var i = 0; i < clockCorners.length; i++) {
          final pin = clockLayout.pins[side * clockCorners.length + i];
          for (final slot in dialBlock(clockCorners[i])) {
            final (dx, dy) = clockLayout.dials[side * 9 + slot];
            expect(sqrt(pow(pin.$1 - dx, 2) + pow(pin.$2 - dy, 2)), closeTo(sqrt(0.5), 1e-9));
          }
        }
      }
    });
  });
}

/// Which slot of [face] shows the edge at [position]; the drawing's own copy of
/// what the facelets work out, so a change to one has to agree with the other.
int _edgeSlotOn(int face, int position) {
  final corners = cornersOfFace(face);
  const pairs = [
    [0, 1],
    [0, 2],
    [1, 2],
  ];
  for (var i = 0; i < pairs.length; i++) {
    if (edgeBetween(corners[pairs[i][0]], corners[pairs[i][1]]) == position) {
      return edgeSlots[i];
    }
  }
  throw ArgumentError("Edge $position is not on face $face");
}
