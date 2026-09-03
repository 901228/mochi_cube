import "dart:math";

import "package:mochi_cube/mochi_cube.dart";
import "package:test/test.dart";

/// Parity of a permutation, by counting inversions.
bool _isOdd(List<int> permutation) {
  var inversions = 0;
  for (var i = 0; i < permutation.length; i++) {
    for (var j = i + 1; j < permutation.length; j++) {
      if (permutation[i] > permutation[j]) inversions++;
    }
  }
  return inversions.isOdd;
}

List<List<int>> _permutations(List<int> of) {
  if (of.length <= 1) return [of];
  return [
    for (var i = 0; i < of.length; i++)
      for (final rest in _permutations([...of]..removeAt(i))) [of[i], ...rest],
  ];
}

void main() {
  final solved = CubieCube().toFaceletString();

  group("randomStateWith", () {
    test("holds the given pieces solved and still makes a real cube", () {
      final random = Random(1);
      for (var trial = 0; trial < 200; trial++) {
        final cube = randomStateWith(
          solvedCorners: const [4, 5, 6, 7],
          solvedEdges: const [4, 5, 6, 7, 8, 9, 10, 11],
          random: random,
        );
        expect(cube.verify(), CubeVerificationStatus.solvable);
        for (final corner in const [4, 5, 6, 7]) {
          expect(cube.cornerState[corner], corner);
        }
      }
    });

    test("orients what it is told to", () {
      final random = Random(2);
      for (var trial = 0; trial < 100; trial++) {
        final cube = randomStateWith(
          solvedCorners: const [4, 5, 6, 7],
          solvedEdges: const [4, 5, 6, 7, 8, 9, 10, 11],
          orientedCorners: true,
          orientedEdges: true,
          random: random,
        );
        expect(isLastLayerOriented(cube), isTrue);
      }
    });

    test("scrambling nothing gives a solved cube", () {
      final cube = randomStateWith(
        solvedCorners: const [0, 1, 2, 3, 4, 5, 6, 7],
        solvedEdges: const [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
        random: Random(3),
      );
      expect(cube.toFaceletString(), solved);
    });

    test("a single free piece of each kind is still a cube", () {
      // One free position can only hold its own piece, so both permutations are
      // the identity and the parities cannot disagree.
      final cube = randomStateWith(
        solvedCorners: const [0, 1, 2, 3, 4, 5, 6],
        solvedEdges: const [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
        random: Random(4),
      );
      expect(cube.verify(), CubeVerificationStatus.solvable);
      expect(cube.cornerState[7] & 0x7, 7);
      expect(cube.edgeState[11] >> 1, 11);
    });

    test("only the free pieces ever twist", () {
      final cube = randomStateWith(
        solvedCorners: const [0, 1, 2, 3],
        solvedEdges: const [0, 1, 2, 3],
        random: Random(5),
      );
      for (final corner in const [0, 1, 2, 3]) {
        expect(cube.cornerState[corner], corner);
      }
      for (final edge in const [0, 1, 2, 3]) {
        expect(cube.edgeState[edge], edge << 1);
      }
      expect(cube.verify(), CubeVerificationStatus.solvable);
    });
  });

  group("PLL", () {
    test("leaves the bottom two layers solved and the top oriented", () {
      for (var seed = 0; seed < 40; seed++) {
        final cube = pllPracticeScramble(random: Random(seed)).cube;
        expect(cube.verify(), CubeVerificationStatus.solvable, reason: "seed $seed");
        expect(isF2lSolved(cube), isTrue, reason: "seed $seed broke F2L");
        expect(isLastLayerOriented(cube), isTrue, reason: "seed $seed broke the orientation");
        expect(cube.toFaceletString(), isNot(solved), reason: "seed $seed was already solved");
      }
    }, timeout: Timeout(Duration(minutes: 2)));

    test("there are exactly 288 such states, and it reaches all but the solved one", () {
      // The two permutations must have the same parity, so half of the 24 by 24
      // pairs are cubes that exist.
      final permutations = _permutations([0, 1, 2, 3]);
      var possible = 0;
      for (final corners in permutations) {
        for (final edges in permutations) {
          if (_isOdd(corners) == _isOdd(edges)) possible++;
        }
      }
      expect(possible, 288);

      final seen = <String>{};
      for (var seed = 0; seed < 4000; seed++) {
        seen.add(pllPracticeScramble(random: Random(seed)).cube.toFaceletString());
      }
      expect(seen, hasLength(possible - 1), reason: "the solved state is excluded");
    }, timeout: Timeout(Duration(minutes: 3)));
  });

  group("OLL", () {
    test("leaves the bottom two layers solved and something to orient", () {
      for (var seed = 0; seed < 40; seed++) {
        final cube = ollPracticeScramble(random: Random(seed)).cube;
        expect(cube.verify(), CubeVerificationStatus.solvable, reason: "seed $seed");
        expect(isF2lSolved(cube), isTrue, reason: "seed $seed broke F2L");
        expect(isLastLayerOriented(cube), isFalse,
            reason: "seed $seed had nothing to orient");
      }
    }, timeout: Timeout(Duration(minutes: 2)));
  });

  group("F2L", () {
    test("leaves the cross solved and the slots to fill", () {
      for (var seed = 0; seed < 40; seed++) {
        final cube = f2lPracticeScramble(random: Random(seed)).cube;
        expect(cube.verify(), CubeVerificationStatus.solvable, reason: "seed $seed");
        expect(isCrossSolved(cube), isTrue, reason: "seed $seed broke the cross");
        expect(cube.toFaceletString(), isNot(solved));
      }
    }, timeout: Timeout(Duration(minutes: 2)));

    test("solvedPairs finishes that many slots", () {
      for (var pairs = 0; pairs <= 4; pairs++) {
        for (var seed = 0; seed < 8; seed++) {
          final cube = f2lPracticeScramble(solvedPairs: pairs, random: Random(seed)).cube;
          expect(isCrossSolved(cube), isTrue);

          final done = f2lPairs
              .where((pair) =>
                  cube.cornerState[pair.$1] == pair.$1 &&
                  cube.edgeState[pair.$2] == pair.$2 << 1)
              .length;
          expect(done, greaterThanOrEqualTo(pairs), reason: "asked for $pairs, got $done");
        }
      }
    }, timeout: Timeout(Duration(minutes: 3)));

    test("all four pairs solved leaves only the last layer", () {
      final cube = f2lPracticeScramble(solvedPairs: 4, random: Random(9)).cube;
      expect(isF2lSolved(cube), isTrue);
    }, timeout: Timeout(Duration(minutes: 1)));

    test("rejects a pair count outside the four slots", () {
      expect(() => f2lPracticeScramble(solvedPairs: -1), throwsRangeError);
      expect(() => f2lPracticeScramble(solvedPairs: 5), throwsRangeError);
    });
  });

  group("every practice scramble", () {
    test("is undone by its own inverse", () {
      for (final make in [
        () => pllPracticeScramble(random: Random(11)),
        () => ollPracticeScramble(random: Random(11)),
        () => f2lPracticeScramble(random: Random(11)),
      ]) {
        final scramble = make();
        final cube = scramble.cube;
        cube.apply(scramble.inverse);
        expect(cube.toFaceletString(), solved);
      }
    }, timeout: Timeout(Duration(minutes: 1)));

    test("is solved by the solver like any other", () {
      for (final make in [
        () => pllPracticeScramble(random: Random(12)),
        () => ollPracticeScramble(random: Random(12)),
        () => f2lPracticeScramble(random: Random(12)),
      ]) {
        final cube = make().cube;
        final result = min2phase.solve(cube.toFaceletString());
        expect(result.status, SolveStatus.foundSolution);

        cube.apply(result.solution!.algorithm);
        expect(cube.toFaceletString(), solved);
      }
    }, timeout: Timeout(Duration(minutes: 1)));
  });

  group("cases", () {
    String stateKey(CubieCube c) => "${c.cornerState}|${c.edgeState}";
    String orientationKey(CubieCube c) =>
        "${lastLayerCorners.map((i) => c.cornerState[i] >> 3).join()}"
        "-${lastLayerEdges.map((i) => c.edgeState[i] & 1).join()}";

    test("there are the 21 PLLs and the 57 OLLs", () {
      expect(pllCases, hasLength(21));
      expect(ollCases, hasLength(57));

      // Every state but the four that are solved up to a U turn, and every
      // orientation but the one that is already oriented.
      expect(pllCases.fold<int>(0, (a, g) => a + g.length), 288 - 4);
      expect(ollCases.fold<int>(0, (a, g) => a + g.length), 216 - 1);
    });

    test("the groups do not overlap", () {
      final pll = pllCases.expand((g) => g).map(stateKey).toList();
      expect(pll.toSet(), hasLength(pll.length));

      final oll = ollCases.expand((g) => g).map(orientationKey).toList();
      expect(oll.toSet(), hasLength(oll.length));
    });

    test("a group is exactly what a turn of U reaches", () {
      // Which is what makes it one case: the same algorithm solves all of it,
      // with the U face adjusted before and after.
      final u = moveCube[parseMove("U")];
      for (final group in pllCases) {
        final reached = <String>{};
        for (var before = 0; before < 4; before++) {
          for (var after = 0; after < 4; after++) {
            final cube = CubieCube();
            for (var i = 0; i < before; i++) {
              cube.multiply(u);
            }
            cube.multiply(group.first);
            for (var i = 0; i < after; i++) {
              cube.multiply(u);
            }
            reached.add(stateKey(cube));
          }
        }
        expect(reached, group.map(stateKey).toSet());
      }
    });

    test("the groups are of unequal size, which is why the choice exists", () {
      expect(pllCases.map((g) => g.length).toSet(), {4, 8, 16});
      expect(ollCases.map((g) => g.length).toSet(), {1, 2, 4});
    });
  });

  group("PracticeSpread", () {
    int caseOf(List<List<CubieCube>> cases, String id, String Function(CubieCube) key) {
      for (var i = 0; i < cases.length; i++) {
        if (cases[i].any((c) => key(c) == id)) return i;
      }
      return -1;
    }

    String stateKey(CubieCube c) => "${c.cornerState}|${c.edgeState}";
    String orientationKey(CubieCube c) =>
        "${lastLayerCorners.map((i) => c.cornerState[i] >> 3).join()}"
        "-${lastLayerEdges.map((i) => c.edgeState[i] & 1).join()}";

    test("cases gives every PLL a fair share", () {
      final counts = List.filled(pllCases.length, 0);
      const draws = 1500;
      for (var seed = 0; seed < draws; seed++) {
        final cube = pllPracticeScramble(
          random: Random(seed),
          spread: PracticeSpread.cases,
        ).cube;
        final index = caseOf(pllCases, stateKey(cube), stateKey);
        expect(index, greaterThanOrEqualTo(0), reason: "drew a state that is not a case");
        counts[index]++;
      }

      // Every case turns up, and none is far off the average.
      final average = draws / pllCases.length;
      expect(counts, everyElement(greaterThan(average * 0.5)));
      expect(counts, everyElement(lessThan(average * 1.6)));
    }, timeout: Timeout(Duration(minutes: 3)));

    test("states gives a case a share of its size", () {
      final counts = List.filled(pllCases.length, 0);
      var skips = 0;
      const draws = 1500;
      for (var seed = 0; seed < draws; seed++) {
        final cube = pllPracticeScramble(random: Random(seed)).cube;
        final index = caseOf(pllCases, stateKey(cube), stateKey);
        if (index < 0) {
          skips++; // solved but for a U turn: a PLL skip, not one of the 21
          continue;
        }
        counts[index]++;
      }

      // A case covering 16 states should come up about four times as often as
      // one covering 4.
      var big = 0.0;
      var bigCount = 0;
      var small = 0.0;
      var smallCount = 0;
      for (var i = 0; i < pllCases.length; i++) {
        if (pllCases[i].length == 16) {
          big += counts[i];
          bigCount++;
        } else if (pllCases[i].length == 4) {
          small += counts[i];
          smallCount++;
        }
      }
      expect(bigCount, greaterThan(0));
      expect(smallCount, greaterThan(0));
      expect((big / bigCount) / (small / smallCount), inInclusiveRange(2.5, 6.0));

      // And a PLL skip happens about one time in 72.
      expect(skips / draws, inInclusiveRange(0.002, 0.035));
    }, timeout: Timeout(Duration(minutes: 3)));

    test("cases gives every OLL a fair share", () {
      final counts = List.filled(ollCases.length, 0);
      const draws = 2500;
      for (var seed = 0; seed < draws; seed++) {
        final cube = ollPracticeScramble(
          random: Random(seed),
          spread: PracticeSpread.cases,
        ).cube;
        final index = caseOf(ollCases, orientationKey(cube), orientationKey);
        expect(index, greaterThanOrEqualTo(0));
        counts[index]++;
      }
      expect(counts, everyElement(greaterThan(0)), reason: "an OLL never came up");

      final average = draws / ollCases.length;
      expect(counts, everyElement(greaterThan(average * 0.4)));
      expect(counts, everyElement(lessThan(average * 2.0)));
    }, timeout: Timeout(Duration(minutes: 4)));

    test("both spreads still leave a real cube to solve", () {
      for (final spread in PracticeSpread.values) {
        for (var seed = 0; seed < 15; seed++) {
          final pll = pllPracticeScramble(random: Random(seed), spread: spread).cube;
          expect(pll.verify(), CubeVerificationStatus.solvable);
          expect(isF2lSolved(pll), isTrue);
          expect(isLastLayerOriented(pll), isTrue);

          final oll = ollPracticeScramble(random: Random(seed), spread: spread).cube;
          expect(oll.verify(), CubeVerificationStatus.solvable);
          expect(isF2lSolved(oll), isTrue);
          expect(isLastLayerOriented(oll), isFalse);
        }
      }
    }, timeout: Timeout(Duration(minutes: 3)));
  });
}
