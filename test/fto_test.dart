import "dart:math";

import "package:mochi_cube/fto/cube.dart";
import "package:mochi_cube/fto/cubie.dart";
import "package:mochi_cube/fto/facelets.dart";
import "package:mochi_cube/fto/search.dart";
import "package:mochi_cube/fto/tables.dart";
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

  // fto3phase's pieces are a separate model, its moves a hand-written table of
  // which piece goes where. Turning them and turning the stickers have to agree
  // for every move, once each piece is placed by the faces it is named after.
  group("fto3phase's pieces", () {
    /// Our move for fto3phase's move [m].
    int ours(int m) => ftoMoves.parse(FtoCubie.moveNames[m ~/ 2] + (m.isOdd ? "'" : ""));

    test("are named after faces that really meet there", () {
      for (final faces in cornerFaces) {
        // Two of each half, going round alternately.
        expect(ufbrblFaces.contains(faces[0]), isTrue);
        expect(rlbdFaces.contains(faces[1]), isTrue);
        expect(ufbrblFaces.contains(faces[2]), isTrue);
        expect(rlbdFaces.contains(faces[3]), isTrue);
      }
      // CDL is round the corner of D and L, CDR of D and R, CDB of D and B.
      expect(cornerFaces[FtoCubie.cdl], containsAll([6, 3]));
      expect(cornerFaces[FtoCubie.cdr], containsAll([6, 1]));
      expect(cornerFaces[FtoCubie.cdb], containsAll([6, 4]));
    });

    test("cover every sticker once, solved as solved", () {
      expect(FtoCubie().toFacelets(), Fto().facelets);
    });

    test("turn as the stickers do, move for move", () {
      for (var m = 0; m < 16; m++) {
        final cubie = FtoCubie()..turn(m);
        final stickers = Fto()..applyMove(ours(m));
        expect(cubie.toFacelets(), stickers.facelets, reason: "move ${ftoMoves.render(ours(m))}");
      }
      final random = Random(2);
      for (var trial = 0; trial < 100; trial++) {
        final cubie = FtoCubie();
        final stickers = Fto();
        for (var step = 0; step < 30; step++) {
          final m = random.nextInt(16);
          cubie.turn(m);
          stickers.applyMove(ours(m));
        }
        expect(cubie.toFacelets(), stickers.facelets, reason: "trial $trial");
      }
    });

    test("read back from their stickers, and a random state is a real one", () {
      for (var seed = 0; seed < 100; seed++) {
        final cubie = FtoCubie.random(Random(seed));
        expect(ftoCubieFromFacelets(cubie.toFacelets()), cubie, reason: "seed $seed");
      }
    });

    test("stickers that are not an FTO are refused", () {
      final solved = Fto().facelets;
      final swapped = [...solved];
      // Two edges traded: an odd permutation.
      final (a1, a2) = edgeFacelets[0];
      final (b1, b2) = edgeFacelets[1];
      swapped[a1] = solved[b1];
      swapped[a2] = solved[b2];
      swapped[b1] = solved[a1];
      swapped[b2] = solved[a2];
      expect(() => ftoCubieFromFacelets(swapped), throwsFormatException);

      final misplaced = [...solved];
      misplaced[ufbrblTriangleFacelets[0]] = rlbdFaces[0];
      expect(() => ftoCubieFromFacelets(misplaced), throwsFormatException);
    });
  });

  group("tables", () {
    setUpAll(FtoTables.init);

    test("every state of every phase can be solved", () {
      expect(FtoTables.g1Prun, isNot(contains(255)));
      expect(FtoTables.g2TriplePrun, isNot(contains(255)));
      expect(FtoTables.g2TxEPrun, isNot(contains(255)));
      expect(FtoTables.g3CornerPrun, isNot(contains(255)));
    });

    // The move tables are built through the packing functions, so check them
    // against the pieces themselves, turned as the stickers turn.
    test("the move tables follow the pieces", () {
      final random = Random(3);
      for (var trial = 0; trial < 200; trial++) {
        final cubie = FtoCubie();
        for (var i = 0; i < 20; i++) {
          cubie.turn(random.nextInt(16));
        }
        final m = random.nextInt(16);
        final turned = FtoCubie.from(cubie)..turn(m);
        expect(FtoTables.g1EdgeMoves[cubie.g1PackEdges() * 16 + m], turned.g1PackEdges());
        expect(FtoTables.g1TriangleMoves[cubie.g1PackTriangles() * 16 + m], turned.g1PackTriangles());
      }
    });
  });

  group("solver", () {
    test("a scramble leaves the random state it was drawn for", () {
      for (var seed = 0; seed < 30; seed++) {
        final cubie = randomFtoCubie(random: Random(seed));
        final scramble = FtoSearch.scrambleFor(cubie);
        expect((Fto()..apply(scramble)).facelets, cubie.toFacelets(), reason: "seed $seed: $scramble");
        expect(scramble.length, lessThanOrEqualTo(40));
      }
    });

    test("solves stickers, and solved needs nothing", () {
      final random = Random(4);
      for (var trial = 0; trial < 10; trial++) {
        final cube = Fto();
        for (var i = 0; i < 40; i++) {
          cube.applyMove(random.nextInt(16));
        }
        expect((Fto.from(cube)..apply(FtoSearch.solve(cube))).isSolved, isTrue, reason: "trial $trial");
      }
      expect(FtoSearch.solve(Fto()), isEmpty);
    });

    test("a seed repeats the scramble, and it uses the official names", () {
      final once = randomFtoScramble(random: Random(5));
      expect(randomFtoScramble(random: Random(5)), once);
      expect(once.moveSet, ftoMoves);
      expect(Algorithm.parse(once.toString(), moveSet: ftoMoves), once);
    });
  });
}
