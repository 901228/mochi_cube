import "dart:math";

import "package:mochi_cube/pyraminx.dart";
import "package:test/test.dart";

void main() {
  late PyraminxTables tables;
  setUpAll(() => tables = PyraminxTables());

  group("the puzzle", () {
    test("every turn has order three", () {
      for (var vertex = 0; vertex < PyraminxCube.vertexCount; vertex++) {
        final cube = PyraminxCube();
        cube.turn(vertex);
        expect(cube.isSolved, isFalse, reason: "one turn did nothing");
        cube.turn(vertex);
        expect(cube.isSolved, isFalse, reason: "two turns solved it");
        cube.turn(vertex);
        expect(cube.isSolved, isTrue, reason: "three turns did not come back");
      }
    });

    test("a turn moves three edges and twists one vertex", () {
      for (var vertex = 0; vertex < PyraminxCube.vertexCount; vertex++) {
        final cube = PyraminxCube();
        cube.turn(vertex);

        final movedEdges = [
          for (var i = 0; i < PyraminxCube.edgeCount; i++)
            if (cube.edges[i] != i) i,
        ];
        expect(movedEdges, hasLength(3), reason: "vertex $vertex");

        // The three that moved are exactly the ones not touching face `vertex`.
        for (final edge in movedEdges) {
          expect(PyraminxCube.edgeFaces[edge], isNot(contains(vertex)));
        }

        expect(cube.vertices[vertex], 1);
        for (var other = 0; other < PyraminxCube.vertexCount; other++) {
          if (other != vertex) expect(cube.vertices[other], 0);
        }
      }
    });

    test("tip moves turn the tips and nothing else", () {
      final cube = PyraminxCube();
      cube.apply(Algorithm.parse("u l' r b'", moveSet: pyraminxMoves));

      expect(cube.areLayersSolved, isTrue, reason: "a tip turn moved a layer");
      expect(cube.areTipsSolved, isFalse);
      expect(cube.isSolved, isFalse);
      expect(cube.tips, [2, 2, 2, 2]);
    });

    test("a layer turn carries its tip with it", () {
      for (var vertex = 0; vertex < PyraminxCube.vertexCount; vertex++) {
        final cube = PyraminxCube()..turn(vertex);
        expect(cube.tips[vertex], 1, reason: "vertex $vertex");
        expect(cube.vertices[vertex], 1);
      }
    });
  });

  group("distance table", () {
    test("covers the 933120 states and reaches eleven at the deepest", () {
      // Both numbers are published results for the puzzle, so this compares
      // against something worked out independently of this code.
      const expected = [1, 8, 48, 288, 1728, 9896, 51808, 220111, 480467, 166276, 2457, 32];

      final histogram = List.filled(16, 0);
      for (var i = 0; i < PyraminxTables.nStates; i++) {
        histogram[tables.distance.at(i)]++;
      }

      expect(histogram.sublist(0, expected.length), expected);
      expect(histogram.skip(expected.length), everyElement(0));
      expect(histogram.reduce((a, b) => a + b), 933120);
    });

    test("only even permutations and even flips are reachable", () {
      // Which is why the state count is 81 * 360 * 32 and not 81 * 720 * 64.
      expect(PyraminxTables.nEdgePerms, 360);
      expect(PyraminxTables.nEdgeFlips, 32);
      expect(PyraminxTables.evenPermutations, hasLength(360));

      for (var trial = 0; trial < 300; trial++) {
        final cube = randomPyraminxCube(random: Random(trial));
        expect(cube.flips.reduce((a, b) => a + b).isEven, isTrue);
      }
    });

    test("the state index follows the puzzle move for move", () {
      final random = Random(3);
      for (var trial = 0; trial < 500; trial++) {
        final cube = PyraminxCube();
        var index = tables.stateOf(cube);
        for (var step = 0; step < 15; step++) {
          final move = random.nextInt(layerMoveCount);
          cube.applyMove(move);
          index = tables.successor(index, move);
          expect(tables.stateOf(cube), index, reason: "diverged after $step turns");
        }
      }
    });

    test("neighbours are one step apart and no state is a dead end", () {
      for (var i = 0; i < PyraminxTables.nStates; i += 11) {
        final d = tables.distance.at(i);
        final neighbours = [
          for (var m = 0; m < layerMoveCount; m++) tables.distance.at(tables.successor(i, m)),
        ];
        for (final n in neighbours) {
          expect((n - d).abs(), lessThanOrEqualTo(1), reason: "state $i");
        }
        if (d > 0) {
          expect(neighbours, contains(d - 1), reason: "dead end at $i");
        }
      }
    });
  });

  group("solver", () {
    test("the layer solution is optimal and solves the layers", () {
      for (var seed = 0; seed < 500; seed++) {
        final cube = randomPyraminxCube(random: Random(seed));
        final solution = PyraminxSearch.solveLayers(cube);

        expect(solution.length, PyraminxSearch.distanceOf(cube), reason: "seed $seed");
        expect(solution.length, lessThanOrEqualTo(11));
        expect(solution.moveSet, pyraminxMoves);

        final check = PyraminxCube.from(cube)..apply(solution);
        expect(check.areLayersSolved, isTrue, reason: "seed $seed: $solution");
      }
    });

    test("solve finishes the tips as well", () {
      final random = Random(8);
      for (var seed = 0; seed < 200; seed++) {
        final cube = randomPyraminxCube(random: Random(seed));
        for (var tip = 0; tip < PyraminxCube.vertexCount; tip++) {
          cube.turnTip(tip, random.nextInt(3));
        }

        final solution = PyraminxSearch.solve(cube);
        final check = PyraminxCube.from(cube)..apply(solution);
        expect(check.isSolved, isTrue, reason: "seed $seed: $solution");

        // The layer part is still optimal, and each tip costs at most one more.
        final layers = solution.moves.where((m) => pyraminxMoves.axisOf(m) < PyraminxCube.vertexCount).length;
        expect(layers, PyraminxSearch.distanceOf(cube), reason: "seed $seed");
        expect(solution.length - layers, lessThanOrEqualTo(PyraminxCube.vertexCount));
      }
    });

    test("a solved puzzle needs no turns", () {
      expect(PyraminxSearch.solve(PyraminxCube()).isEmpty, isTrue);
      expect(PyraminxSearch.solveLayers(PyraminxCube()).isEmpty, isTrue);
      expect(PyraminxSearch.distanceOf(PyraminxCube()), 0);
    });
  });

  group("scrambles", () {
    test("are as far from solved as they are long, and their inverse undoes them", () {
      for (var seed = 0; seed < 100; seed++) {
        final scramble = randomPyraminxScramble(random: Random(seed));
        final layers = scramble.moves.where((m) => pyraminxMoves.axisOf(m) < PyraminxCube.vertexCount).length;
        expect(layers, greaterThanOrEqualTo(6), reason: "seed $seed is too easy");

        final cube = PyraminxCube()..apply(scramble);
        expect(PyraminxSearch.distanceOf(cube), layers, reason: "seed $seed");

        cube.apply(scramble.inverse);
        expect(cube.isSolved, isTrue, reason: "seed $seed");
        expect(cube.areTipsSolved, isTrue, reason: "the scramble's tips were not undone");
      }
    });

    test("the tips come last, as a scramble is written", () {
      for (var seed = 0; seed < 50; seed++) {
        final scramble = randomPyraminxScramble(random: Random(seed));
        var seenTip = false;
        for (final move in scramble.moves) {
          final isTip = pyraminxMoves.axisOf(move) >= PyraminxCube.vertexCount;
          if (isTip) seenTip = true;
          expect(isTip || !seenTip, isTrue, reason: "a layer turn came after a tip");
        }
      }
    });

    test("can be asked to leave the tips alone", () {
      final scramble = randomPyraminxScramble(random: Random(1), tips: false);
      expect(scramble.moves.every((m) => pyraminxMoves.axisOf(m) < PyraminxCube.vertexCount), isTrue);
    });

    test("respects a raised minimum", () {
      final scramble = randomPyraminxScramble(random: Random(2), minimumMoves: 10, tips: false);
      expect(scramble.length, greaterThanOrEqualTo(10));
    });

    test("random puzzles cover the state space evenly", () {
      const draws = 4000;
      final states = <int>{};
      for (var i = 0; i < draws; i++) {
        states.add(tables.stateOf(randomPyraminxCube(random: Random(i))));
      }
      // Nearly every draw should be new out of 933120.
      final expected = PyraminxTables.nStates * (1 - exp(-draws / PyraminxTables.nStates));
      expect(states.length, greaterThan(expected * 0.98));
    });
  });

  group("MoveSet", () {
    test("reads and writes Pyraminx notation", () {
      expect(pyraminxMoves.count, 16);
      for (var move = 0; move < pyraminxMoves.count; move++) {
        expect(pyraminxMoves.parse(pyraminxMoves.render(move)), move);
        expect(pyraminxMoves.invert(pyraminxMoves.invert(move)), move);
      }
      expect(pyraminxMoves.render(pyraminxMoves.parse("U'")), "U'");
      expect(pyraminxMoves.render(pyraminxMoves.invert(pyraminxMoves.parse("U"))), "U'");
      expect(pyraminxMoves.render(pyraminxMoves.parse("b")), "b");
      expect(() => pyraminxMoves.parse("U2"), throwsFormatException);
      expect(() => pyraminxMoves.parse("F"), throwsFormatException);
    });

    test("still reads and writes a 3x3x3's", () {
      expect(MoveSet.cube.count, 18);
      for (var move = 0; move < MoveSet.cube.count; move++) {
        expect(MoveSet.cube.parse(MoveSet.cube.render(move)), move);
        expect(MoveSet.cube.invert(MoveSet.cube.invert(move)), move);
      }
      // A half turn is its own inverse; a quarter turn is not.
      expect(MoveSet.cube.render(MoveSet.cube.invert(MoveSet.cube.parse("U2"))), "U2");
      expect(MoveSet.cube.render(MoveSet.cube.invert(MoveSet.cube.parse("U"))), "U'");
    });

    test("an algorithm keeps track of which puzzle it is for", () {
      final pyraminx = Algorithm.parse("U L' r", moveSet: pyraminxMoves);
      expect(pyraminx.toString(), "U L' r");
      expect(pyraminx.moveSet, pyraminxMoves);
      // The same move numbers, but about a different puzzle, are not the same
      // algorithm. Compared with `==` rather than through the matcher: an
      // Algorithm is an Iterable, so `expect(a, b)` walks the elements and
      // never asks either of them whether they are equal.
      final asCube = Algorithm(pyraminx.moves);
      expect(pyraminx == asCube, isFalse);
      expect(asCube.toString(), isNot(pyraminx.toString()));
      expect(() => pyraminx + Algorithm.parse("R U"), throwsArgumentError);
    });
  });

  group("facelets", () {
    test("a solved puzzle is nine of each colour, one per face", () {
      expect(
        PyraminxCube().toFaceletString(),
        "AAAAAAAAA"
        "BBBBBBBBB"
        "CCCCCCCCC"
        "DDDDDDDDD",
      );
      expect(nPyraminxFacelets, 36);
    });

    test("a layer turn moves twelve stickers and leaves its far face alone", () {
      // Three faces meet at a vertex, and on each the turn carries a tip, a
      // vertex piece and two edges. The fourth face is not part of the layer.
      for (var vertex = 0; vertex < PyraminxCube.vertexCount; vertex++) {
        final before = PyraminxCube().toFacelets();
        final after = (PyraminxCube()..turn(vertex)).toFacelets();

        final moved = [
          for (var i = 0; i < nPyraminxFacelets; i++)
            if (before[i] != after[i]) i,
        ];
        expect(moved, hasLength(12), reason: "vertex $vertex");
        expect(
          moved.map((i) => i ~/ 9),
          isNot(contains(vertex)),
          reason: "the turn touched the face opposite it",
        );
      }
    });

    test("a tip turn moves three stickers", () {
      for (var vertex = 0; vertex < PyraminxCube.vertexCount; vertex++) {
        final before = PyraminxCube().toFacelets();
        final after = (PyraminxCube()..turnTip(vertex)).toFacelets();
        expect(
          [
            for (var i = 0; i < nPyraminxFacelets; i++)
              if (before[i] != after[i]) i,
          ],
          hasLength(3),
          reason: "vertex $vertex",
        );
      }
    });

    test("there are always nine of each colour", () {
      final random = Random(7);
      for (var trial = 0; trial < 500; trial++) {
        final cube = PyraminxCube();
        for (var i = 0; i < 20; i++) {
          cube.applyMove(random.nextInt(pyraminxMoves.count));
        }

        final counts = List.filled(PyraminxCube.vertexCount, 0);
        for (final face in cube.toFacelets()) {
          counts[face]++;
        }
        expect(counts, everyElement(9), reason: "trial $trial");
      }
    });

    test("round-trip, tips included", () {
      final random = Random(11);
      for (var trial = 0; trial < 500; trial++) {
        final cube = randomPyraminxCube(random: random);
        for (var tip = 0; tip < PyraminxCube.vertexCount; tip++) {
          cube.turnTip(tip, random.nextInt(3));
        }

        final text = cube.toFaceletString();
        final back = PyraminxFacelet.fromFaceletString(text);
        expect(back.toFaceletString(), text, reason: "trial $trial");
        expect(back.toString(), cube.toString(), reason: "trial $trial");
      }
    });

    test("reads any four letters, with no centres to name the faces", () {
      // The vertex pieces settle it: one never leaves its corner, and the
      // colour it never shows is the face it does not touch.
      const scheme = {"A": "R", "B": "G", "C": "B", "D": "Y"};
      for (var trial = 0; trial < 200; trial++) {
        final cube = randomPyraminxCube(random: Random(trial));
        final recoloured = cube.toFaceletString().split("").map((c) => scheme[c]!).join();
        expect(PyraminxFacelet.fromFaceletString(recoloured).toString(), cube.toString());
      }
    });

    test("solves straight from a sticker string", () {
      final cube = randomPyraminxCube(random: Random(42))..turnTip(1, 2);
      final text = cube.toFaceletString();

      final solution = PyraminxSearch.solve(PyraminxFacelet.fromFaceletString(text));
      final check = PyraminxFacelet.fromFaceletString(text)..apply(solution);
      expect(check.isSolved, isTrue);
    });

    test("ignores whitespace", () {
      expect(PyraminxFacelet.fromFaceletString("AAAAAAAAA BBBBBBBBB CCCCCCCCC DDDDDDDDD").isSolved, isTrue);
    });

    test("rejects strings that are not a Pyraminx", () {
      expect(() => PyraminxFacelet.fromFaceletString("AAA"), throwsFormatException);
      // Five colours.
      expect(
        () => PyraminxFacelet.fromFaceletString(
          "AAAAAAAAE"
          "BBBBBBBBB"
          "CCCCCCCCC"
          "DDDDDDDDD",
        ),
        throwsFormatException,
      );
      // Ten of one colour, eight of another.
      expect(
        () => PyraminxFacelet.fromFaceletString(
          "AAAAAAAAA"
          "BBBBBBBBA"
          "CCCCCCCCC"
          "DDDDDDDDD",
        ),
        throwsFormatException,
      );
      // Four colours, nine each, but not arranged as a puzzle.
      expect(
        () => PyraminxFacelet.fromFaceletString(
          "ABCDABCDA"
          "BCDABCDAB"
          "CDABCDABC"
          "DABCDABCD",
        ),
        throwsFormatException,
      );
    });
  });
}
