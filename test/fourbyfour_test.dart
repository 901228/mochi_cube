import "dart:math";
import "dart:typed_data";

import "package:mochi_cube/fourbyfour/center1.dart";
import "package:mochi_cube/fourbyfour/cubies.dart";
import "package:mochi_cube/nxn.dart";
import "package:test/test.dart";

/// The stickers of [cube] as the NxN model writes them.
List<int> stickers(FullCube cube) {
  final f = Uint8List(96);
  cube.toFacelet(f);
  return f;
}

/// The 24 ways to hold a 4x4x4, as permutations of its stickers:
/// `rotated[i] = cube[permutation[i]]`.
List<List<int>> rotations() {
  final identity = NxNCube.fromFacelets(4, List.generate(96, (i) => i));
  final seen = <String, List<int>>{identity.facelets.join(","): identity.facelets};
  final frontier = [identity];
  while (frontier.isNotEmpty) {
    final cube = frontier.removeLast();
    for (final face in [0, 1]) {
      final turned = NxNCube.from(cube)..turn(face, 4);
      if (seen.putIfAbsent(turned.facelets.join(","), () => turned.facelets) == turned.facelets) {
        frontier.add(turned);
      }
    }
  }
  return seen.values.toList();
}

/// Whether every face of [cube] is one colour and no two faces share one: a
/// solved 4x4x4 in whatever orientation.
bool isSolvedAnyWayUp(NxNCube cube) {
  final colours = <int>{};
  for (var face = 0; face < 6; face++) {
    final stickersOfFace = cube.facelets.sublist(face * 16, face * 16 + 16).toSet();
    if (stickersOfFace.length != 1) return false;
    colours.add(stickersOfFace.single);
  }
  return colours.length == 6;
}

void main() {
  setUpAll(Center1.initSym);

  // threephase is a port of the official program's solver, so what a move does
  // to it is checked against the package's own model of the puzzle, which was
  // itself checked against the 3x3x3 and 2x2x2 and built from 3D positions.
  group("the cube", () {
    test("starts solved, in the same sticker order as NxNCube", () {
      expect(stickers(FullCube()), NxNCube(4).toFacelets());
    });

    test("turns exactly as NxNCube(4) does, move for move", () {
      final random = Random(1);
      for (var trial = 0; trial < 100; trial++) {
        final cube = FullCube();
        final model = NxNCube(4);
        for (var step = 0; step < 40; step++) {
          final move = random.nextInt(36);
          cube.doMove(move);
          model.applyMove(move);
          expect(stickers(cube), model.toFacelets(), reason: "trial $trial, step $step, move $move");
        }
      }
    });

    test("queued moves are applied when a part is asked for", () {
      final random = Random(2);
      final eager = FullCube();
      final lazy = FullCube();
      for (var i = 0; i < 30; i++) {
        final move = random.nextInt(36);
        eager.doMove(move);
        lazy.move(move);
      }
      expect(stickers(lazy), stickers(eager));
    });

    test("a random state reads back from its own stickers", () {
      for (var seed = 0; seed < 100; seed++) {
        final cube = FullCube.random(Random(seed));
        final f = Uint8List.fromList(stickers(cube));
        expect(stickers(FullCube.fromFacelets(f)), f, reason: "seed $seed");
      }
    });

    test("a state reached by turning reads back from its own stickers", () {
      final random = Random(3);
      for (var trial = 0; trial < 50; trial++) {
        final model = NxNCube(4);
        for (var i = 0; i < 40; i++) {
          model.applyMove(random.nextInt(36));
        }
        final f = Uint8List.fromList(model.toFacelets());
        expect(stickers(FullCube.fromFacelets(f)), f);
      }
    });

    test("rejects stickers that are not a 4x4x4", () {
      final solved = Uint8List.fromList(NxNCube(4).toFacelets());

      // Two stickers of one corner traded: a corner twisted on its own.
      final twisted = Uint8List.fromList(solved);
      twisted[0x0f] = solved[0x10];
      twisted[0x10] = solved[0x0f];
      expect(() => FullCube.fromFacelets(twisted), throwsFormatException);

      // A wing's stickers traded for a colour pair no wing has.
      final badWing = Uint8List.fromList(solved);
      badWing[0x0d] = badWing[0x21] = 0;
      expect(() => FullCube.fromFacelets(badWing), throwsFormatException);

      // Two centres traded between colours.
      final badCentre = Uint8List.fromList(solved);
      badCentre[0x05] = 1;
      expect(() => FullCube.fromFacelets(badCentre), throwsFormatException);
    });

    test("the corners and wings of a random state need no parity of their own", () {
      // The 4x4x4 has no fixed centres, so any permutation of the pieces is a
      // state — which is what lets the generator draw them independently.
      var even = 0;
      for (var seed = 0; seed < 200; seed++) {
        final cube = FullCube.random(Random(seed));
        if (cube.getEdge().parity == cube.getCorner().parity) even++;
      }
      expect(even, inInclusiveRange(60, 140));
    });
  });

  group("the symmetries", () {
    test("form a group of 48: every row of the product is a permutation", () {
      for (var a = 0; a < 48; a++) {
        final row = {for (var b = 0; b < 48; b++) symmult[a * 48 + b]};
        expect(row, hasLength(48), reason: "row $a");
        expect(symmult[a * 48 + syminv[a]], 0, reason: "inverse of $a");
        expect(symmult[a * 48], a, reason: "identity on the right of $a");
      }
    });

    test("move conjugation is a permutation of the 36 moves", () {
      for (var s = 0; s < 48; s++) {
        final row = {for (var m = 0; m < 36; m++) symmove[s * 36 + m]};
        expect(row, hasLength(36), reason: "symmetry $s");
      }
      for (var m = 0; m < 36; m++) {
        expect(symmove[m], m, reason: "the identity leaves move $m alone");
      }
    });
  });
}
