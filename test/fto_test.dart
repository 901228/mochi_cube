import "dart:math";

import "package:mochi_cube/fto/cube.dart";
import "package:mochi_cube/mochi_cube.dart" show Algorithm;
import "package:test/test.dart";

/// TNoodle's own FTO, the official scramble program's: every turn written out
/// by hand as nine three-cycles of stickers, `(face, slot)` to `(face, slot)` to
/// `(face, slot)` and back. Ours are worked out from where the stickers are in
/// space, so agreeing with these says the geometry and the official notation
/// are the same puzzle.
const List<List<List<int>>> tnoodleCycles = [
  // face 0
  [
    [0, 0, 0, 5, 0, 2],
    [0, 6, 0, 7, 0, 3],
    [0, 1, 0, 8, 0, 4],
    [2, 1, 5, 8, 7, 4],
    [1, 1, 3, 4, 4, 8],
    [1, 8, 3, 1, 4, 4],
    [1, 6, 3, 3, 4, 7],
    [1, 0, 3, 2, 4, 5],
    [1, 5, 3, 0, 4, 2],
  ],
  // face 1
  [
    [1, 0, 1, 5, 1, 2],
    [1, 3, 1, 6, 1, 7],
    [1, 1, 1, 8, 1, 4],
    [2, 6, 0, 3, 7, 7],
    [2, 1, 0, 4, 7, 8],
    [0, 1, 7, 4, 2, 8],
    [0, 0, 7, 2, 2, 5],
    [2, 0, 0, 2, 7, 5],
    [3, 1, 4, 8, 6, 4],
  ],
  // face 2
  [
    [2, 2, 2, 0, 2, 5],
    [2, 3, 2, 6, 2, 7],
    [2, 1, 2, 8, 2, 4],
    [3, 6, 1, 3, 6, 7],
    [3, 0, 1, 2, 6, 5],
    [3, 1, 1, 4, 6, 8],
    [3, 5, 1, 0, 6, 2],
    [3, 8, 1, 1, 6, 4],
    [0, 1, 7, 8, 5, 4],
  ],
  // face 3
  [
    [3, 3, 3, 6, 3, 7],
    [3, 2, 3, 0, 3, 5],
    [3, 4, 3, 1, 3, 8],
    [0, 6, 2, 3, 5, 7],
    [0, 8, 2, 1, 5, 4],
    [0, 1, 2, 4, 5, 8],
    [1, 1, 6, 8, 4, 4],
    [0, 5, 2, 0, 5, 2],
    [0, 0, 2, 2, 5, 5],
  ],
  // face 4
  [
    [4, 0, 4, 5, 4, 2],
    [4, 6, 4, 7, 4, 3],
    [4, 1, 4, 8, 4, 4],
    [5, 6, 7, 3, 0, 7],
    [5, 5, 7, 0, 0, 2],
    [5, 8, 7, 1, 0, 4],
    [5, 0, 7, 2, 0, 5],
    [5, 1, 7, 4, 0, 8],
    [6, 1, 1, 8, 3, 4],
  ],
  // face 5
  [
    [5, 0, 5, 5, 5, 2],
    [5, 6, 5, 7, 5, 3],
    [5, 1, 5, 8, 5, 4],
    [6, 6, 4, 3, 3, 7],
    [6, 5, 4, 0, 3, 2],
    [6, 8, 4, 1, 3, 4],
    [6, 0, 4, 2, 3, 5],
    [6, 1, 4, 4, 3, 8],
    [7, 1, 0, 8, 2, 4],
  ],
  // face 6
  [
    [6, 0, 6, 5, 6, 2],
    [6, 3, 6, 6, 6, 7],
    [6, 1, 6, 8, 6, 4],
    [7, 6, 5, 3, 2, 7],
    [7, 0, 5, 2, 2, 5],
    [7, 1, 5, 4, 2, 8],
    [7, 5, 5, 0, 2, 2],
    [7, 8, 5, 1, 2, 4],
    [1, 4, 4, 1, 3, 8],
  ],
  // face 7
  [
    [7, 2, 7, 0, 7, 5],
    [7, 3, 7, 6, 7, 7],
    [7, 4, 7, 1, 7, 8],
    [4, 6, 6, 3, 1, 7],
    [4, 5, 6, 0, 1, 2],
    [4, 8, 6, 1, 1, 4],
    [1, 5, 4, 0, 6, 2],
    [1, 8, 4, 1, 6, 4],
    [2, 8, 0, 4, 5, 1],
  ],
];

/// TNoodle's turn of [face], clockwise, on stickers [image].
void tnoodleTurn(List<int> image, int face) {
  for (final [f1, s1, f2, s2, f3, s3] in tnoodleCycles[face]) {
    final temp = image[f3 * 9 + s3];
    image[f3 * 9 + s3] = image[f2 * 9 + s2];
    image[f2 * 9 + s2] = image[f1 * 9 + s1];
    image[f1 * 9 + s1] = temp;
  }
}

/// The stickers, labelled so each one can be followed.
Fto labelled() => Fto.fromFacelets(List.generate(nFtoFacelets, (i) => i));

void main() {
  group("geometry", () {
    test("every sticker has a place of its own, on its own face", () {
      final positions = {for (var i = 0; i < nFtoFacelets; i++) ftoFaceletPosition(i)};
      expect(positions, hasLength(nFtoFacelets));
      for (var i = 0; i < nFtoFacelets; i++) {
        final (x, y, z) = ftoFaceletPosition(i);
        final (s1, s2, s3) = ftoFaceNormal[i ~/ 9];
        expect(s1 * x + s2 * y + s3 * z, 9, reason: "sticker $i is not on its face's plane");
      }
    });

    test("opposite faces are U and D, F and B, R and BL, L and BR", () {
      int opposite(String name) {
        final (a, b, c) = ftoFaceNormal[ftoFaceNames.indexOf(name)];
        return ftoFaceNormal.indexOf((-a, -b, -c));
      }

      expect(ftoFaceNames[opposite("U")], "D");
      expect(ftoFaceNames[opposite("F")], "B");
      expect(ftoFaceNames[opposite("R")], "BL");
      expect(ftoFaceNames[opposite("L")], "BR");
    });
  });

  group("turns", () {
    test("are TNoodle's, sticker for sticker", () {
      for (var face = 0; face < 8; face++) {
        final ours = labelled()..turn(face);
        final theirs = List.generate(nFtoFacelets, (i) => i);
        tnoodleTurn(theirs, face);
        expect(ours.facelets, theirs, reason: "face ${ftoFaceNames[face]}");
      }
    });

    test("and stay so over long sequences", () {
      final random = Random(1);
      for (var trial = 0; trial < 50; trial++) {
        final ours = labelled();
        final theirs = List.generate(nFtoFacelets, (i) => i);
        for (var step = 0; step < 40; step++) {
          final face = random.nextInt(8);
          ours.turn(face);
          tnoodleTurn(theirs, face);
        }
        expect(ours.facelets, theirs, reason: "trial $trial");
      }
    });

    test("each has order three and moves 27 stickers", () {
      for (var face = 0; face < 8; face++) {
        final moved = labelled()..turn(face);
        final count = [for (var i = 0; i < nFtoFacelets; i++) moved.facelets[i] != i].where((m) => m).length;
        expect(count, 27, reason: "face ${ftoFaceNames[face]}");
        final cube = Fto()..turn(face, 3);
        expect(cube.isSolved, isTrue);
      }
    });

    test("notation round trips, and a prime undoes a turn", () {
      final algorithm = Algorithm.parse("U R' BL F BR' D L B'", moveSet: ftoMoves);
      expect(algorithm.toString(), "U R' BL F BR' D L B'");
      final cube = Fto()
        ..apply(algorithm)
        ..apply(algorithm.inverse);
      expect(cube.isSolved, isTrue);
    });
  });
}
