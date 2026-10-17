import "dart:math";

import "package:mochi_cube/mochi_cube.dart" show cornerFacelet;
import "package:mochi_cube/skewb.dart";
import "package:test/test.dart";

/// The 3x3x3 facelet a Skewb sticker sits on: same face, same corner.
int cubeFacelet(int skewb) => (skewb ~/ 5) * 9 + const [0, 2, 4, 6, 8][skewb % 5];

/// The Skewb stickers of a 3x3x3 corner, in the 3x3x3's clockwise order.
List<int> skewbCorner(int corner) => [
  for (final facelet in cornerFacelet[corner])
    (facelet.index ~/ 9) * 5 + const {0: 0, 2: 1, 6: 3, 8: 4}[facelet.index % 9]!,
];

void main() {
  group("geometry", () {
    test("every sticker has a place of its own on the surface", () {
      final positions = {for (var i = 0; i < nSkewbFacelets; i++) skewbFaceletPosition(i)};
      expect(positions, hasLength(nSkewbFacelets));
      for (final (x, y, z) in positions) {
        expect([x.abs(), y.abs(), z.abs()], contains(3));
      }
    });

    test("agrees with the 3x3x3 about which stickers make up a corner", () {
      // The 3x3x3's corner table is written out by hand and checked by its own
      // solver, so it is an independent account of the same geometry.
      for (var corner = 0; corner < cornerFacelet.length; corner++) {
        final stickers = skewbCorner(corner);
        expect(stickers.map(skewbCornerOf).toSet(), hasLength(1), reason: "corner $corner");
        for (final sticker in stickers) {
          expect(cubeFacelet(sticker), cornerFacelet[corner][stickers.indexOf(sticker)].index);
        }
      }
    });

    test("the fixed corner's stickers are on U, R and F", () {
      expect(SkewbCube.fixedCornerFacelets.map(skewbCornerOf).toSet(), {SkewbCube.fixedCorner});
      expect(SkewbCube.fixedCornerFacelets.map((f) => f ~/ 5), [0, 1, 2]);
    });
  });

  group("turns", () {
    test("every turn has order three, and a prime undoes it", () {
      for (var axis = 0; axis < SkewbCube.axisCorners.length; axis++) {
        final cube = SkewbCube()..turn(axis);
        expect(cube.isSolved, isFalse);
        cube.turn(axis);
        expect(cube.isSolved, isFalse);
        cube.turn(axis);
        expect(cube.isSolved, isTrue, reason: "axis $axis");

        final move = axis * skewbMoves.amounts.length;
        final undone = SkewbCube()
          ..applyMove(move)
          ..applyMove(skewbMoves.invert(move));
        expect(undone.isSolved, isTrue);
      }
    });

    test("a turn moves half the stickers and never the fixed corner", () {
      for (var axis = 0; axis < SkewbCube.axisCorners.length; axis++) {
        // Number the stickers so that every one of them can be followed.
        final cube = SkewbCube.fromFacelets(List.generate(nSkewbFacelets, (i) => i))..turn(axis);
        final moved = [
          for (var i = 0; i < nSkewbFacelets; i++)
            if (cube.facelets[i] != i) i,
        ];
        expect(moved, hasLength(15), reason: "axis $axis");
        expect(moved.where((i) => i % 5 == centreSlot), hasLength(3));
        for (final facelet in SkewbCube.fixedCornerFacelets) {
          expect(moved, isNot(contains(facelet)));
        }
      }
    });

    test("turns clockwise as seen from the corner", () {
      // The 3x3x3 lists a corner's stickers clockwise, so a clockwise turn takes
      // each one to the next.
      for (var axis = 0; axis < SkewbCube.axisCorners.length; axis++) {
        final corner = Iterable.generate(
          8,
        ).firstWhere((c) => skewbCornerOf(skewbCorner(c).first) == SkewbCube.axisCorners[axis]);
        final stickers = skewbCorner(corner);
        final cube = SkewbCube.fromFacelets(List.generate(nSkewbFacelets, (i) => i))..turn(axis);
        for (var k = 0; k < 3; k++) {
          expect(cube.facelets[stickers[(k + 1) % 3]], stickers[k], reason: "axis $axis");
        }
      }
    });

    test("notation round trips", () {
      final algorithm = Algorithm.parse("R U' L B' R'", moveSet: skewbMoves);
      expect(algorithm.toString(), "R U' L B' R'");
      final cube = SkewbCube()
        ..apply(algorithm)
        ..apply(algorithm.inverse);
      expect(cube.isSolved, isTrue);
    });
  });

  group("parts", () {
    test("the corners have 8748 states and the centres 360", () {
      // 3149280 together, the published count for the puzzle.
      expect(SkewbPart.corners.length, 8748);
      expect(SkewbPart.centres.length, 360);
      expect(SkewbPart.corners.length * SkewbPart.centres.length, 3149280);
    });

    test("the move tables follow the puzzle", () {
      final random = Random(1);
      for (var trial = 0; trial < 200; trial++) {
        final cube = SkewbCube();
        var corners = 0;
        var centres = 0;
        for (var step = 0; step < 20; step++) {
          final move = random.nextInt(skewbMoves.count);
          cube.applyMove(move);
          corners = SkewbPart.corners.move[(corners, move)];
          centres = SkewbPart.centres.move[(centres, move)];
          expect(SkewbPart.corners.indexOf(cube.facelets), corners);
          expect(SkewbPart.centres.indexOf(cube.facelets), centres);
        }
      }
    });
  });

  group("stickers", () {
    test("a turned cube reads back as itself", () {
      final random = Random(2);
      for (var trial = 0; trial < 100; trial++) {
        final cube = SkewbCube();
        for (var step = 0; step < 15; step++) {
          cube.applyMove(random.nextInt(skewbMoves.count));
        }
        expect(SkewbFacelet.fromFaceletString(cube.toFaceletString()).facelets, cube.facelets);
      }
    });

    test("any six letters will do", () {
      final cube = SkewbCube()..apply(Algorithm.parse("R U L B R'", moveSet: skewbMoves));
      final recoloured = cube.toFaceletString().split("").map((c) => "WRGYOB"["URFDLB".indexOf(c)]).join();
      expect(SkewbFacelet.fromFaceletString(recoloured).facelets, cube.facelets);
    });

    test("rejects what is not a Skewb", () {
      final solved = SkewbCube().toFaceletString();
      expect(() => SkewbFacelet.fromFaceletString(solved.substring(1)), throwsFormatException);
      expect(() => SkewbFacelet.fromFaceletString("U${solved.substring(1, 29)}UU"), throwsFormatException);

      // Two centres swapped: an odd permutation, which no turn makes.
      final swapped = solved.split("");
      swapped[centreSlot] = "R";
      swapped[5 + centreSlot] = "U";
      expect(() => SkewbFacelet.fromFaceletString(swapped.join()), throwsFormatException);

      // One corner twisted in place.
      final twisted = solved.split("");
      final corner = skewbCorner(4); // down-front-right
      final colours = [for (final f in corner) twisted[f]];
      for (var k = 0; k < 3; k++) {
        twisted[corner[k]] = colours[(k + 1) % 3];
      }
      expect(() => SkewbFacelet.fromFaceletString(twisted.join()), throwsFormatException);
    });
  });
}
