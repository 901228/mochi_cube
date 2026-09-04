import "dart:math";

import "package:mochi_cube/pocket.dart";
import "package:test/test.dart";

void main() {
  final solved = CubieCube().toPocketFaceletString();
  late PocketTables tables;
  setUpAll(() => tables = PocketTables());

  group("coordinates", () {
    test("round-trip over their whole range", () {
      final cube = CubieCube();
      for (var v = 0; v < nCperm7; v++) {
        cube.cperm7 = v;
        expect(cube.cperm7, v, reason: "cperm7 $v");
      }
      for (var v = 0; v < nTwist6; v++) {
        cube.twist6 = v;
        expect(cube.twist6, v, reason: "twist6 $v");
      }
    });

    test("a solved cube is state zero", () {
      expect(CubieCube().cperm7, 0);
      expect(CubieCube().twist6, 0);
    });

    test("the held corner never moves under U, R and F", () {
      final random = Random(5);
      for (var trial = 0; trial < 200; trial++) {
        final cube = CubieCube();
        for (var i = 0; i < 20; i++) {
          cube.moveIndex(pocketMoves[random.nextInt(pocketMoves.length)]);
        }
        expect(
          cube.cornerState[fixedCorner.index],
          fixedCorner.index,
          reason: "the fixed corner was disturbed",
        );
      }
    });

    test("each coordinate moves as a function of itself alone", () {
      // Without this the state could not be the product of the two.
      for (var m = 0; m < pocketMoves.length; m++) {
        for (var v = 0; v < 120; v++) {
          final a = CubieCube()
            ..cperm7 = v
            ..twist6 = 17;
          final b = CubieCube()
            ..cperm7 = v
            ..twist6 = 400;
          a.moveIndex(pocketMoves[m]);
          b.moveIndex(pocketMoves[m]);
          expect(a.cperm7, b.cperm7, reason: "cperm7 depended on twist6");

          final c = CubieCube()
            ..cperm7 = 11
            ..twist6 = v % nTwist6;
          final d = CubieCube()
            ..cperm7 = 900
            ..twist6 = v % nTwist6;
          c.moveIndex(pocketMoves[m]);
          d.moveIndex(pocketMoves[m]);
          expect(c.twist6, d.twist6, reason: "twist6 depended on cperm7");
        }
      }
    });
  });

  group("distance table", () {
    test("matches the published distribution for the 2x2x2", () {
      // The number of states at each distance, half-turn metric, one corner
      // held still. God's number is 11 and exactly 2644 states need it.
      const expected = [1, 9, 54, 321, 1847, 9992, 50136, 227536, 870072, 1887748, 623800, 2644];

      final histogram = List.filled(16, 0);
      for (var i = 0; i < nStates; i++) {
        histogram[tables.distance.at(i)]++;
      }

      expect(histogram.sublist(0, expected.length), expected);
      expect(histogram.skip(expected.length), everyElement(0));
      expect(histogram.reduce((a, b) => a + b), nStates);
    });

    test("neighbours are never more than one step apart", () {
      for (var i = 0; i < nStates; i += 7) {
        final d = tables.distance.at(i);
        for (var m = 0; m < pocketMoves.length; m++) {
          expect(
            (tables.distance.at(tables.successor(i, m)) - d).abs(),
            lessThanOrEqualTo(1),
            reason: "state $i",
          );
        }
      }
    });

    test("every unsolved state has a neighbour one step nearer", () {
      // What makes the downhill walk always terminate.
      for (var i = 0; i < nStates; i += 7) {
        final d = tables.distance.at(i);
        if (d == 0) continue;
        final nearer = [
          for (var m = 0; m < pocketMoves.length; m++) tables.distance.at(tables.successor(i, m)),
        ];
        expect(nearer, contains(d - 1), reason: "dead end at state $i");
      }
    });
  });

  group("solver", () {
    test("every solution is optimal and actually solves", () {
      for (var seed = 0; seed < 500; seed++) {
        final cube = randomPocketCube(random: Random(seed));
        final solution = PocketSearch.solve(cube);

        expect(solution.length, PocketSearch.distanceOf(cube), reason: "seed $seed is not optimal");
        expect(solution.length, lessThanOrEqualTo(11));

        final check = CubieCube.from(cube);
        check.apply(solution);
        expect(check.toPocketFaceletString(), solved, reason: "seed $seed: $solution");
      }
    });

    test("a solved cube needs no moves", () {
      expect(PocketSearch.solve(CubieCube()).isEmpty, isTrue);
      expect(PocketSearch.distanceOf(CubieCube()), 0);
    });

    test("solves through the Solver interface", () {
      final cube = randomPocketCube(random: Random(42));
      final result = pocket.solve(cube.toPocketFaceletString());

      expect(result.status, SolveStatus.foundSolution);
      expect(result.solution!.length, PocketSearch.distanceOf(cube));
      expect(pocket.defaultMaxLength, 11);

      cube.apply(result.solution!.algorithm);
      expect(cube.toPocketFaceletString(), solved);
    });

    test("reports a solution that is longer than asked for", () {
      // Only reachable by asking for less than the puzzle needs.
      final deep = CubieCube();
      var index = 0;
      while (tables.distance.at(index) != 11) {
        index++;
      }
      deep
        ..cperm7 = index ~/ nTwist6
        ..twist6 = index % nTwist6;

      expect(pocket.solve(deep.toPocketFaceletString(), maxLength: 10).status, SolveStatus.exceededMaxLength);
      expect(pocket.solve(deep.toPocketFaceletString()).status, SolveStatus.foundSolution);
    });
  });

  group("facelets", () {
    test("round-trip", () {
      for (var seed = 0; seed < 500; seed++) {
        final cube = randomPocketCube(random: Random(seed));
        final text = cube.toPocketFaceletString();
        final back = PocketCube.fromFaceletString(text);
        expect(back.toPocketFaceletString(), text);
        expect(back.cperm7, cube.cperm7);
        expect(back.twist6, cube.twist6);
      }
    });

    test("read any colour scheme, with no centres to name the faces", () {
      const scheme = {"U": "W", "R": "R", "F": "G", "D": "Y", "L": "O", "B": "B"};
      for (var seed = 0; seed < 200; seed++) {
        final cube = randomPocketCube(random: Random(seed));
        final recoloured = cube.toPocketFaceletString().split("").map((c) => scheme[c]!).join();
        expect(
          PocketCube.fromFaceletString(recoloured).toPocketFaceletString(),
          cube.toPocketFaceletString(),
        );
      }
    });

    test("the solved cube reads as four of each", () {
      expect(solved, "UUUURRRRFFFFDDDDLLLLBBBB");
    });

    test("ignores whitespace", () {
      expect(PocketCube.fromFaceletString("UUUU RRRR FFFF DDDD LLLL BBBB").toPocketFaceletString(), solved);
    });

    test("rejects strings that are not a cube", () {
      expect(() => PocketCube.fromFaceletString("UU"), throwsFormatException);
      // Seven colours.
      expect(() => PocketCube.fromFaceletString("UUUWRRRRFFFFDDDDLLLLBBBB"), throwsFormatException);
      // Five of one colour, three of another.
      expect(() => PocketCube.fromFaceletString("UUUUURRRFFFFDDDDLLLLBBBB"), throwsFormatException);
      // Six colours, four each, but not arranged as a cube.
      expect(() => PocketCube.fromFaceletString("URFDLBURFDLBURFDLBURFDLB"), throwsFormatException);
    });
  });

  group("scrambles", () {
    test("are undone by their own inverse and meet the WCA minimum", () {
      for (var seed = 0; seed < 100; seed++) {
        final scramble = randomPocketScramble(random: Random(seed));
        expect(scramble.length, greaterThanOrEqualTo(4));

        final cube = scramble.cube;
        expect(
          PocketSearch.distanceOf(cube),
          scramble.length,
          reason: "the scramble is not as far from solved as it is long",
        );

        cube.apply(scramble.inverse);
        expect(cube.toPocketFaceletString(), solved);
      }
    });

    test("respects a raised minimum", () {
      final scramble = randomPocketScramble(random: Random(1), minimumMoves: 10);
      expect(scramble.length, greaterThanOrEqualTo(10));
    });

    test("random cubes cover the state space evenly", () {
      // Coupon collector, as for the 3x3x3.
      const draws = 5000;
      final perms = <int>{};
      final twists = <int>{};
      for (var i = 0; i < draws; i++) {
        final cube = randomPocketCube(random: Random(i));
        perms.add(cube.cperm7);
        twists.add(cube.twist6);
      }

      void expectEvenSpread(String name, Set<int> seen, int bins) {
        final expected = bins * (1 - exp(-draws / bins));
        expect(seen.length, greaterThan(expected * 0.9), reason: name);
        expect(seen.length, lessThan(expected * 1.1), reason: name);
      }

      expectEvenSpread("cperm7", perms, nCperm7);
      expectEvenSpread("twist6", twists, nTwist6);
    });
  });
}
