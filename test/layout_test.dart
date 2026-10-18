import "dart:math";

import "package:mochi_cube/clock.dart";
import "package:mochi_cube/mochi_cube.dart";
import "package:mochi_cube/pocket.dart" show pocketLayout;
import "package:mochi_cube/pyraminx.dart";
import "package:mochi_cube/skewb.dart" show nSkewbFacelets, skewbCornerOf, skewbLayout;
import "package:mochi_cube/square1.dart" show Square1Cube, randomSquare1Cube, square1Layout;
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

/// Whether [point] is inside the convex [polygon], wound clockwise on screen.
bool _inside(Point point, List<Point> polygon) {
  for (var i = 0; i < polygon.length; i++) {
    final (x1, y1) = polygon[i];
    final (x2, y2) = polygon[(i + 1) % polygon.length];
    if ((x2 - x1) * (point.$2 - y1) - (y2 - y1) * (point.$1 - x1) < 0) return false;
  }
  return true;
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

  group("skewb net", () {
    test("has one polygon per facelet, covering six faces exactly", () {
      expect(skewbLayout.length, nSkewbFacelets);
      _staysInsideTheBox(skewbLayout);
      expect(skewbLayout.stickers.map(_area).reduce((a, b) => a + b), closeTo(6, 1e-9));
    });

    test("each sticker covers the 3x3x3 tile it stands for", () {
      for (var facelet = 0; facelet < nSkewbFacelets; facelet++) {
        final tile = cubeLayout[(facelet ~/ 5) * 9 + const [0, 2, 4, 6, 8][facelet % 5]];
        final centre = (
          tile.map((p) => p.$1).reduce((a, b) => a + b) / 4,
          tile.map((p) => p.$2).reduce((a, b) => a + b) / 4,
        );
        expect(_inside(centre, skewbLayout[facelet]), isTrue, reason: "facelet $facelet");
      }
    });

    // As for the cube: a corner whose faces are side by side in the net must be
    // drawn in one piece. Five face boundaries are joined, two corners each. Two
    // faces meeting only at a corner of the cross touch at a point, which is
    // the one share that is neither apart nor joined.
    test("corners that are not split by the net are drawn joined", () {
      var joined = 0;
      for (var a = 0; a < nSkewbFacelets; a++) {
        for (var b = a + 1; b < nSkewbFacelets; b++) {
          if (skewbCornerOf(a) == null || skewbCornerOf(a) != skewbCornerOf(b)) continue;
          final shared = _sharedCorners(skewbLayout[a], skewbLayout[b]);
          expect(shared, anyOf(0, 1, 2), reason: "stickers $a and $b share $shared corners");
          if (shared == 2) joined++;
        }
      }
      expect(joined, 10);
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
      const middle = pyraminxMiddleFace;
      for (var face = 0; face < PyraminxCube.vertexCount; face++) {
        if (face == middle) continue;
        final edge = PyraminxCube.edgeIndexOf(middle, face);
        final here = pyraminxLayout[middle * 9 + _edgeSlotOn(middle, edge)];
        final there = pyraminxLayout[face * 9 + _edgeSlotOn(face, edge)];
        expect(_sharedCorners(here, there), 2, reason: "edge $edge between faces $middle and $face");
      }
    });

    test("the tips of a vertex meet at the point they share", () {
      const middle = pyraminxMiddleFace;
      for (var face = 0; face < PyraminxCube.vertexCount; face++) {
        if (face == middle) continue;
        for (final vertex in cornersOfFace(middle)) {
          if (!cornersOfFace(face).contains(vertex)) continue;
          final here = pyraminxLayout[middle * 9 + tipSlots[cornersOfFace(middle).indexOf(vertex)]];
          final there = pyraminxLayout[face * 9 + tipSlots[cornersOfFace(face).indexOf(vertex)]];
          expect(_sharedCorners(here, there), greaterThanOrEqualTo(1));
        }
      }
    });
  });

  // The notation is clockwise at every vertex. U, L and R sit on a straight
  // stretch of the net, where that is clockwise on the screen too (y points down).
  test("pyraminx turns go the same way round on the net", () {
    for (final (vertex, name) in [(0, "U"), (1, "L"), (2, "R")]) {
      final stickers = (PyraminxCube()..apply(Algorithm.parse(name, moveSet: pyraminxMoves))).toFacelets();
      final faces = [
        for (var face = 0; face < PyraminxCube.vertexCount; face++)
          if (face != vertex) face,
      ];
      Point at(int face) {
        final polygon = pyraminxLayout[face * 9 + vertexSlots[cornersOfFace(face).indexOf(vertex)]];
        return (
          polygon.map((p) => p.$1).reduce((a, b) => a + b) / 3,
          polygon.map((p) => p.$2).reduce((a, b) => a + b) / 3,
        );
      }

      final centre = (
        faces.map((f) => at(f).$1).reduce((a, b) => a + b) / 3,
        faces.map((f) => at(f).$2).reduce((a, b) => a + b) / 3,
      );
      var turning = 0.0;
      for (final face in faces) {
        // The sticker now on `face` came from the face whose colour it shows.
        final from = at(stickers[face * 9 + vertexSlots[cornersOfFace(face).indexOf(vertex)]]);
        final to = at(face);
        turning += (from.$1 - centre.$1) * (to.$2 - centre.$2) - (from.$2 - centre.$2) * (to.$1 - centre.$1);
      }
      expect(turning, greaterThan(0), reason: "$name is not clockwise");
    }
  });

  group("square-1", () {
    List<int> stateOf(Square1Cube cube) => [...cube.pieces, cube.middle];
    Point centroid(List<Point> polygon) => (
      polygon.map((p) => p.$1).reduce((a, b) => a + b) / polygon.length,
      polygon.map((p) => p.$2).reduce((a, b) => a + b) / polygon.length,
    );
    // A layer's middle is the one corner its wedges all share.
    Point middleOf(int first) => square1Layout.edges[first][0].firstWhere(
      (point) => square1Layout.edges[first + 6][0].any((other) => _same(point, other)),
    );
    final topCentre = middleOf(0);
    final bottomCentre = middleOf(12);

    test("draws every piece once, inside the box, wound the same way", () {
      final random = Random(1);
      for (var trial = 0; trial < 100; trial++) {
        final cube = randomSquare1Cube(random: random)..turnTop(random.nextInt(12));
        final stickers = square1Layout.stickers(stateOf(cube));
        // Eight edges of two stickers, eight corners of three, two of middle.
        expect(stickers, hasLength(42));
        for (final (polygon, _) in stickers) {
          expect(_area(polygon), greaterThan(0));
          for (final (x, y) in polygon) {
            expect(x, inInclusiveRange(-_epsilon, square1Layout.width + _epsilon));
            expect(y, inInclusiveRange(-_epsilon, square1Layout.height + _epsilon));
          }
        }
      }
    });

    test("solved, each layer is a square of side two", () {
      // Everything but the two middle stickers, which come last.
      final stickers = square1Layout.stickers(stateOf(Square1Cube()));
      final layers = stickers.take(stickers.length - 2).map((sticker) => _area(sticker.$1));
      expect(layers.reduce((a, b) => a + b), closeTo(8, 1e-9));
    });

    // The colours are the part that is puzzle knowledge. Solved, a side sticker
    // must be on the side of its own face: the top is drawn from above with the
    // back up, the bottom from below with the front up, right on the right.
    test("solved, every side sticker faces its own face", () {
      const up = {5: (0.0, -1.0), 2: (0.0, 1.0), 1: (1.0, 0.0), 4: (-1.0, 0.0)};
      const down = {2: (0.0, -1.0), 5: (0.0, 1.0), 1: (1.0, 0.0), 4: (-1.0, 0.0)};
      final stickers = square1Layout.stickers(stateOf(Square1Cube()));
      for (final (polygon, face) in stickers.take(stickers.length - 2)) {
        final (x, y) = centroid(polygon);
        final onTop = y < square1Layout.middle[0][0].$2;
        if (face == 0 || face == 3) {
          expect(face, onTop ? 0 : 3);
          continue;
        }
        final (cx, cy) = onTop ? topCentre : bottomCentre;
        final (dx, dy) = (onTop ? up : down)[face]!;
        // Within 45 degrees of that face's direction.
        final cosine = ((x - cx) * dx + (y - cy) * dy) / sqrt(pow(x - cx, 2) + pow(y - cy, 2));
        expect(cosine, greaterThanOrEqualTo(sqrt1_2 - 1e-9), reason: "face $face at ${(x, y)}");
      }
    });

    test("the middle shows the front, or the back of its right half once turned over", () {
      final square = square1Layout.stickers(stateOf(Square1Cube())).skip(40).map((s) => s.$2);
      final turned = square1Layout.stickers(stateOf(Square1Cube()..slash())).skip(40).map((s) => s.$2);
      expect(square, [2, 2]);
      expect(turned, [2, 5]);
    });

    test("turning a layer is clockwise on the page, the way it is seen", () {
      for (final (first, turn, centre) in [
        (0, (Square1Cube cube) => cube.turnTop(1), topCentre),
        (12, (Square1Cube cube) => cube.turnBottom(1), bottomCentre),
      ]) {
        final cube = Square1Cube();
        turn(cube);
        for (var slot = first; slot < first + 12; slot++) {
          final to = first + (slot - first + 11) % 12;
          expect(cube.pieces[to], Square1Cube.solvedPieces[slot], reason: "slot $slot");
          final (ax, ay) = centroid(square1Layout.edges[slot][0]);
          final (bx, by) = centroid(square1Layout.edges[to][0]);
          final (cx, cy) = centre;
          expect((ax - cx) * (by - cy) - (ay - cy) * (bx - cx), greaterThan(0), reason: "slot $slot");
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
