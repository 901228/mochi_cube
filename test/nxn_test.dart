import "dart:math";

import "package:mochi_cube/mochi_cube.dart" show AlgorithmCubeExtension;
import "package:mochi_cube/nxn.dart";
import "package:mochi_cube/pocket.dart" show PocketFacelets;
import "package:test/test.dart";

/// The 24 ways to hold a cube of [size], as permutations of its stickers:
/// `rotated[i] = cube[permutation[i]]`.
List<List<int>> rotations(int size) {
  final identity = NxNCube.fromFacelets(size, List.generate(6 * size * size, (i) => i));
  final seen = <String, List<int>>{identity.facelets.join(","): identity.facelets};
  final frontier = [identity];
  while (frontier.isNotEmpty) {
    final cube = frontier.removeLast();
    for (final face in [0, 1]) {
      final turned = NxNCube.from(cube)..turn(face, size);
      if (seen.putIfAbsent(turned.facelets.join(","), () => turned.facelets) == turned.facelets) {
        frontier.add(turned);
      }
    }
  }
  return seen.values.toList();
}

String key(List<int> facelets) => facelets.join(",");

void main() {
  group("against the 3x3x3 and the 2x2x2", () {
    // Their turns are checked end to end by their solvers, so they are an
    // independent account of the same geometry.
    test("a 3x3x3's notation is the 3x3x3's", () {
      expect(nxnMoves(3), MoveSet.cube);
      expect(nxnMoves(2), MoveSet.cube);
    });

    test("turns a 3x3x3 as the 3x3x3 does", () {
      final random = Random(1);
      for (var trial = 0; trial < 100; trial++) {
        final algorithm = Algorithm([for (var i = 0; i < 20; i++) random.nextInt(18)]);
        expect(
          (NxNCube(3)..apply(algorithm)).toFacelets(),
          algorithm.cube.toFacelets(),
          reason: "$algorithm",
        );
      }
    });

    test("turns a 2x2x2 as the 2x2x2 does", () {
      final random = Random(2);
      for (var trial = 0; trial < 100; trial++) {
        final algorithm = Algorithm([for (var i = 0; i < 20; i++) random.nextInt(18)]);
        expect((NxNCube(2)..apply(algorithm)).toFacelets(), algorithm.cube.toPocketFacelets());
      }
    });
  });

  group("turns", () {
    test("every turn has order four", () {
      for (final size in [4, 5, 6, 7]) {
        for (var face = 0; face < 6; face++) {
          for (var width = 1; width <= size; width++) {
            final cube = NxNCube(size)..turn(face, width);
            if (width < size) expect(cube.isSolved, isFalse);
            cube.turn(face, width, 3);
            expect(cube.isSolved, isTrue, reason: "size $size, face $face, width $width");
          }
        }
      }
    });

    test("a turn of every layer is a rotation, and there are 24", () {
      for (final size in [2, 5, 6]) {
        expect(rotations(size), hasLength(24));
      }
    });

    test("the two halves of a cube, turned opposite ways, are a rotation", () {
      // Rw and then the other three layers from L, anticlockwise: all five
      // layers of a 5x5x5 the same way.
      final cube = NxNCube(5)
        ..apply(Algorithm.parse("Rw", moveSet: nxnMoves(5)))
        ..turn(4, 3, 3);
      final rotated = NxNCube(5)..turn(1, 5);
      expect(cube.facelets, rotated.facelets);
    });

    test("notation round trips", () {
      final algorithm = Algorithm.parse("3Rw2 Uw' F 3Bw D2", moveSet: nxnMoves(7));
      expect(algorithm.toString(), "3Rw2 Uw' F 3Bw D2");
      final cube = NxNCube(7)
        ..apply(algorithm)
        ..apply(algorithm.inverse);
      expect(cube.isSolved, isTrue);
      expect(() => Algorithm.parse("3Rw", moveSet: nxnMoves(5)), throwsFormatException);
    });
  });

  group("random turns", () {
    test("TNoodle's turns: up to half the cube, the even cube's second half left out", () {
      expect(NxNTurns(5).candidates, hasLength(36));
      expect(NxNTurns(6).candidates, hasLength(45));
      expect(NxNTurns(7).candidates, hasLength(54));
      final names = NxNTurns(6).candidates.map(nxnMoves(6).render).toSet();
      expect(names, containsAll(["3Rw", "3Uw'", "3Fw2"]));
      expect(names.intersection({"3Lw", "3Dw", "3Bw"}), isEmpty);
    });

    // TNoodle's definition, on whole states: a turn is wasted after another
    // when the two together come to no turn or one turn, the cube held any way
    // round. This is the claim that the layer arithmetic asks the same thing.
    test("wasted means what it means on whole states", () {
      for (final size in [5, 6, 7]) {
        final turns = NxNTurns(size);
        final rotated = rotations(size);
        for (final start in [
          NxNCube(size),
          NxNCube(size)..apply(randomNxNScramble(size, random: Random(3))),
        ]) {
          final reachable = <String>{};
          for (final cube in [
            start,
            for (final move in turns.candidates) NxNCube.from(start)..applyMove(move),
          ]) {
            for (final permutation in rotated) {
              reachable.add(key([for (final i in permutation) cube.facelets[i]]));
            }
          }
          for (final previous in turns.candidates) {
            for (final next in turns.candidates) {
              if (turns.axisOf(previous) != turns.axisOf(next)) continue;
              final both = NxNCube.from(start)
                ..applyMove(previous)
                ..applyMove(next);
              final render = nxnMoves(size).render;
              expect(
                turns.wastes(previous, next),
                reachable.contains(key(both.facelets)),
                reason: "size $size: ${render(previous)} ${render(next)}",
              );
            }
          }
        }
      }
    });

    test("a scramble is TNoodle's length, its turns, none of them wasted", () {
      for (final size in [5, 6, 7]) {
        final turns = NxNTurns(size);
        for (var seed = 0; seed < 5; seed++) {
          final scramble = randomNxNScramble(size, random: Random(seed));
          expect(scramble, hasLength(randomTurnCounts[size]));
          expect(scramble.moveSet, nxnMoves(size));
          for (var i = 0; i < scramble.length; i++) {
            expect(turns.candidates, contains(scramble[i]));
            expect(
              turns.wastedAfter(scramble.moves.sublist(0, i), scramble[i]),
              isFalse,
              reason: "turn $i of $scramble",
            );
          }
        }
      }
    });

    test("a seed repeats the scramble", () {
      expect(randomNxNScramble(5, random: Random(4)), randomNxNScramble(5, random: Random(4)));
    });
  });

  group("stickers", () {
    test("read back as themselves", () {
      for (final size in [5, 6, 7]) {
        final cube = NxNCube(size)..apply(randomNxNScramble(size, random: Random(5)));
        expect(NxNCube.fromFaceletString(size, cube.toFaceletString()).facelets, cube.facelets);
      }
    });

    test("an odd cube takes any six letters, from its centres", () {
      final cube = NxNCube(5)..apply(randomNxNScramble(5, random: Random(6)));
      final recoloured = cube.toFaceletString().split("").map((c) => "WRGYOB"["URFDLB".indexOf(c)]).join();
      expect(NxNCube.fromFaceletString(5, recoloured).facelets, cube.facelets);
    });

    test("an even cube needs the face letters, and the wrong counts are refused", () {
      final solved = NxNCube(6).toFaceletString();
      expect(
        () => NxNCube.fromFaceletString(6, solved.split("").map((c) => "WRGYOB"["URFDLB".indexOf(c)]).join()),
        throwsFormatException,
      );
      expect(() => NxNCube.fromFaceletString(6, solved.substring(1)), throwsFormatException);
      expect(() => NxNCube.fromFaceletString(6, "R${solved.substring(1)}"), throwsFormatException);
    });
  });
}
