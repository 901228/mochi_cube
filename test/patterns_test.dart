import "dart:math";

import "package:mochi_cube/mochi_cube.dart";
import "package:test/test.dart";

void main() {
  final solved = CubieCube().toFaceletString();

  group("patterns", () {
    test("every pattern is a real, solvable, non-solved cube", () {
      expect(Patterns.all, isNotEmpty);
      for (final entry in Patterns.all.entries) {
        final cube = entry.value.cube;
        expect(cube.verify(), CubeVerificationStatus.solvable, reason: entry.key);
        expect(cube.toFaceletString(), isNot(solved), reason: "${entry.key} does nothing");

        final counts = List.filled(6, 0);
        for (final face in cube.toFacelets()) {
          counts[face]++;
        }
        expect(counts, everyElement(9), reason: entry.key);
      }
    });

    test("every pattern is undone by its own inverse", () {
      for (final entry in Patterns.all.entries) {
        final cube = entry.value.cube;
        cube.apply(entry.value.inverse);
        expect(cube.toFaceletString(), solved, reason: entry.key);
      }
    });

    test("the solver solves every pattern", () {
      for (final entry in Patterns.all.entries) {
        final cube = entry.value.cube;
        final result = min2phase.solve(cube.toFaceletString());
        expect(result.status, SolveStatus.foundSolution, reason: entry.key);

        cube.apply(result.solution!.algorithm);
        expect(cube.toFaceletString(), solved, reason: entry.key);
      }
    }, timeout: Timeout(Duration(minutes: 2)));

    test("the patterns are distinct from each other", () {
      final states = Patterns.all.values.map((a) => a.cube.toFaceletString()).toSet();
      expect(states, hasLength(Patterns.all.length));
    });
  });

  group("randomScramble", () {
    test("has the requested length and never repeats a face", () {
      final random = Random(7);
      for (var trial = 0; trial < 50; trial++) {
        final scramble = randomScramble(moves: 20, random: random);
        expect(scramble.length, 20);
        for (var i = 1; i < scramble.length; i++) {
          expect(scramble[i] ~/ 3, isNot(scramble[i - 1] ~/ 3),
              reason: "two turns of the same face in a row: $scramble");
        }
      }
    });

    test("produces solvable cubes the solver can solve", () {
      final random = Random(11);
      for (var trial = 0; trial < 10; trial++) {
        final scramble = randomScramble(random: random);
        final cube = scramble.cube;
        expect(cube.verify(), CubeVerificationStatus.solvable);

        final result = min2phase.solve(cube.toFaceletString());
        expect(result.status, SolveStatus.foundSolution);
        cube.apply(result.solution!.algorithm);
        expect(cube.toFaceletString(), solved);
      }
    }, timeout: Timeout(Duration(minutes: 2)));

    test("the scramble's own inverse solves it", () {
      final scramble = randomScramble(random: Random(3));
      final cube = scramble.cube;
      cube.apply(scramble.inverse);
      expect(cube.toFaceletString(), solved);
    });

    test("is reproducible from a seed, and varies without one", () {
      expect(randomScramble(random: Random(5)), randomScramble(random: Random(5)));
      final many = List.generate(20, (_) => randomScramble().toString()).toSet();
      expect(many.length, greaterThan(1));
    });

    test("a zero move scramble is empty", () {
      expect(randomScramble(moves: 0).isEmpty, isTrue);
      expect(randomScramble(moves: 0).cube.toFaceletString(), solved);
    });
  });

  group("patternize", () {
    test("turns one cube into another", () {
      for (final entry in Patterns.all.entries) {
        final from = randomScramble(moves: 15, random: Random(entry.key.length)).cube;
        final to = entry.value.cube;

        final result = Search.patternize(from, to);
        expect(result.status, SolveStatus.foundSolution, reason: entry.key);

        final cube = CubieCube.from(from);
        cube.apply(result.solution!.algorithm);
        expect(cube.toFaceletString(), to.toFaceletString(), reason: entry.key);
      }
    }, timeout: Timeout(Duration(minutes: 2)));

    test("patternizing to a solved cube is just solving", () {
      final cube = randomScramble(random: Random(21)).cube;
      expect(Search.patternize(cube, CubieCube()).solution!.algorithm,
          Search.solveCube(cube).solution!.algorithm);
    });

    test("patternizing a cube to itself needs no moves", () {
      final cube = randomScramble(random: Random(22)).cube;
      expect(Search.patternize(cube, cube).solution!.isEmpty, isTrue);
    });

    test("goes both ways", () {
      final from = Patterns.checkerboard.cube;
      final to = Patterns.tetris.cube;

      final there = Search.patternize(from, to).solution!;
      final back = Search.patternize(to, from).solution!;

      final cube = CubieCube.from(from);
      cube.apply(there.algorithm);
      cube.apply(back.algorithm);
      expect(cube.toFaceletString(), from.toFaceletString());
    });

    test("rejects an unsolvable endpoint", () {
      final broken = CubieCube();
      broken.edgeState[0] ^= 1;
      expect(Search.patternize(broken, CubieCube()).status, SolveStatus.invalidCube);
      expect(Search.patternize(CubieCube(), broken).status, SolveStatus.invalidCube);
    });
  });

  group("CubieCube.random", () {
    test("only produces solvable cubes", () {
      for (var seed = 0; seed < 300; seed++) {
        expect(CubieCube.random(random: Random(seed)).verify(),
            CubeVerificationStatus.solvable, reason: "seed $seed");
      }
    });

    test("is reproducible from a seed, and varies without one", () {
      expect(CubieCube.random(random: Random(9)).toFaceletString(),
          CubieCube.random(random: Random(9)).toFaceletString());
      final many = List.generate(20, (_) => CubieCube.random().toFaceletString()).toSet();
      expect(many, hasLength(20));
    });

    test("covers each coordinate the way an even draw would", () {
      // Coupon collector: n draws into b bins should hit about
      // b * (1 - e^(-n/b)) of them. A generator stuck in a corner of the state
      // space, or one that repeats, would come out well below this.
      const draws = 5000;
      final twists = <int>{};
      final flips = <int>{};
      final cperms = <int>{};
      for (var i = 0; i < draws; i++) {
        final cube = CubieCube.random(random: Random(i));
        twists.add(cube.twist);
        flips.add(cube.flip);
        cperms.add(cube.cperm);
      }

      void expectEvenSpread(String name, Set<int> seen, int bins) {
        final expected = bins * (1 - exp(-draws / bins));
        expect(seen.length, greaterThan(expected * 0.9), reason: "$name saw too few values");
        expect(seen.length, lessThan(expected * 1.1), reason: "$name saw too many values");
      }

      expectEvenSpread("twist", twists, 2187);
      expectEvenSpread("flip", flips, 2048);
      expectEvenSpread("cperm", cperms, 40320);
    });

    test("both permutations always have the same parity", () {
      for (var seed = 0; seed < 300; seed++) {
        final cube = CubieCube.random(random: Random(seed));
        expect(cube.edgeParityBit, cube.cornerParityBit, reason: "seed $seed");
      }
    });
  });

  group("randomStateScramble", () {
    test("produces a solvable cube its own inverse undoes", () {
      for (var i = 0; i < 5; i++) {
        final scramble = randomStateScramble(random: Random(i));
        final cube = scramble.cube;
        expect(cube.verify(), CubeVerificationStatus.solvable);

        cube.apply(scramble.inverse);
        expect(cube.toFaceletString(), solved);
      }
    }, timeout: Timeout(Duration(minutes: 1)));

    test("is at least the WCA minimum away from solved", () {
      for (var i = 0; i < 5; i++) {
        final scramble = randomStateScramble(random: Random(i + 100));
        expect(scramble.length, greaterThanOrEqualTo(2));

        // And it really is that far: solving it back takes at least as many.
        final again = Search.solveCube(scramble.cube).solution!;
        expect(again.length, greaterThanOrEqualTo(2));
      }
    }, timeout: Timeout(Duration(minutes: 1)));

    test("respects a raised minimum", () {
      final scramble = randomStateScramble(random: Random(3), minimumMoves: 18);
      expect(scramble.length, greaterThanOrEqualTo(18));
    }, timeout: Timeout(Duration(minutes: 1)));

    test("is about as short as the official scrambler's", () {
      // TNoodle's 3x3 scrambles run about 19 to 20 moves; the same method here
      // lands in the same place. Random moves would need 20-odd turns to be
      // sure the cube is mixed at all.
      var total = 0;
      for (var i = 0; i < 10; i++) {
        total += randomStateScramble(random: Random(i + 200)).length;
      }
      expect(total / 10, inInclusiveRange(17, 22));
    }, timeout: Timeout(Duration(minutes: 1)));
  });
}
