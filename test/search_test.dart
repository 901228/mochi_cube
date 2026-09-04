import "package:mochi_cube/kociemba/cube/cubie_cube.dart" as k;
import "package:mochi_cube/kociemba/cube/enums.dart" as k;
import "package:mochi_cube/kociemba/cube/face_cube.dart" as k;
import "package:mochi_cube/puzzle/cube/cubie_cube.dart";
import "package:mochi_cube/puzzle/cube/moves.dart";
import "package:mochi_cube/puzzle/algorithm.dart";
import "package:mochi_cube/solver.dart";
import "package:mochi_cube/kociemba/solver.dart" show kociemba;
import "package:mochi_cube/puzzle/search.dart";
import "package:test/test.dart";

const String solved =
    "UUUUUUUUU"
    "RRRRRRRRR"
    "FFFFFFFFF"
    "DDDDDDDDD"
    "LLLLLLLLL"
    "BBBBBBBBB";

/// The kociemba code is verified end to end, so it renders the facelets here.
List<int> _colours(k.CubieCube c) => k.FaceCube.fromCubieCube(c).state.map((e) => e.index).toList();

CubieCube randomCube(int seed) => CubieCube.fromFacelets(_colours(k.CubieCube.randomize(seed)));

String render(CubieCube c) => k.FaceCube.fromCubieCube(
  k.CubieCube(
    cornerState: List.generate(
      8,
      (i) => k.CCorner(k.Corner.values[c.cornerState[i] & 7], (c.cornerState[i] >> 3) % 3),
    ),
    edgeState: List.generate(12, (i) => k.CEdge(k.Edge.values[c.edgeState[i] >> 1], c.edgeState[i] & 1)),
  ),
).toString();

void main() {
  group("search", () {
    test("returns nothing to do for a solved cube", () {
      final r = Search.solveCube(CubieCube());
      expect(r.status, SolveStatus.foundSolution);
      expect(r.solution!.length, 0);
      expect(r.solution.toString(), "");
    });

    test("solves random cubes, and every solution restores its cube", () {
      var total = 0;
      var worst = 0;
      for (var seed = 0; seed < 30; seed++) {
        final r = Search.solveCube(randomCube(seed));
        expect(r.status, SolveStatus.foundSolution, reason: "seed $seed");

        final solution = r.solution!;
        expect(solution.length, lessThanOrEqualTo(Search.defaultMaxLength), reason: "seed $seed");

        final cube = randomCube(seed);
        for (final m in solution.moves) {
          cube.moveIndex(m);
        }
        expect(render(cube), solved, reason: "seed $seed: $solution does not solve the cube");

        total += solution.length;
        if (solution.length > worst) worst = solution.length;
      }
      // The kociemba solver averages 23 moves on the same cubes.
      expect(total / 30, lessThan(22));
      expect(worst, lessThanOrEqualTo(Search.defaultMaxLength));
    }, timeout: Timeout(Duration(minutes: 3)));

    test("solves from a facelet string", () {
      const facelets = "DLBFUBRFL DDLRRDBRR FUBBFULDU ULRRDBLUF RDUULLDFF UFBRBBDLF";
      final r = Search.solution(facelets);
      expect(r.status, SolveStatus.foundSolution);

      final cube = CubieCube.fromFacelets(k.FaceCube.fromString(facelets).state.map((e) => e.index).toList());
      for (final m in r.solution!.moves) {
        cube.moveIndex(m);
      }
      expect(render(cube), solved);
    });

    test("a solution and its inverse cancel", () {
      final r = Search.solveCube(randomCube(3));
      final cube = randomCube(3);
      for (final m in r.solution!.moves) {
        cube.moveIndex(m);
      }
      for (final m in r.solution!.inverse.moves) {
        cube.moveIndex(m);
      }
      expect(render(cube), render(randomCube(3)));
    });

    test("rejects a well formed but unsolvable cube", () {
      final cube = CubieCube();
      cube.edgeState[0] ^= 1; // one flipped edge
      final r = Search.solveCube(cube);
      expect(r.status, SolveStatus.invalidCube);
      expect(r.error, CubeVerificationStatus.flipError);
    });

    test("rejects facelets that are not a cube", () {
      // A bad string is a result, not an exception: solve() reports through its
      // status either way, and the reason comes back in `error`.
      const bad =
          "UUUUUUUUU"
          "RRRRRRRRU"
          "FFFFFFFFF"
          "DDDDDDDDD"
          "LLLLLLLLL"
          "BBBBBBBBB";
      expect(Search.solution(bad).status, SolveStatus.invalidCube);

      final short = Search.solution("UUU");
      expect(short.status, SolveStatus.invalidCube);
      expect(short.error, isA<FormatException>());
      expect(short.solution, isNull);
    });

    test("invertMove reverses quarter turns and leaves half turns alone", () {
      expect(moveToString(invertMove(parseMove("U"))), "U'");
      expect(moveToString(invertMove(parseMove("U'"))), "U");
      expect(moveToString(invertMove(parseMove("U2"))), "U2");
      for (var m = 0; m < 18; m++) {
        expect(invertMove(invertMove(m)), m);
      }
    });
  });

  _algorithmTests();
}

void _algorithmTests() {
  group("Algorithm", () {
    test("parses and prints standard notation", () {
      expect(Algorithm.parse("R U R' U2").toString(), "R U R' U2");
      expect(Algorithm.parse("  R   U  ").toString(), "R U");
      expect(Algorithm.parse("").isEmpty, isTrue);
      expect(Algorithm.empty.toString(), "");
      expect(() => Algorithm.parse("X"), throwsFormatException);
    });

    test("is an iterable of move indices", () {
      final a = Algorithm.parse("R U F");
      expect(a.length, 3);
      expect(a.toList(), [parseMove("R"), parseMove("U"), parseMove("F")]);
      expect(a[0], parseMove("R"));
      expect(a.map(moveToString).join("-"), "R-U-F");
    });

    test("concatenates and repeats", () {
      final rur = Algorithm.parse("R U R' U'");
      expect((rur + Algorithm.parse("F")).toString(), "R U R' U' F");
      expect((rur * 2).toString(), "R U R' U' R U R' U'");
      expect((rur * 0).isEmpty, isTrue);
      expect(() => rur * -1, throwsArgumentError);
    });

    test("an algorithm and its inverse cancel", () {
      final a = Algorithm.parse("R U R' U' F2 L D B'");
      final cube = CubieCube();
      cube.apply(a);
      cube.apply(a.inverse);
      expect(cube.toFaceletString(), CubieCube().toFaceletString());
    });

    test("cube applies the moves to a solved cube", () {
      expect((Algorithm.parse("R U R' U'") * 6).cube.toFaceletString(), CubieCube().toFaceletString());
      expect(Algorithm.empty.cube.toFaceletString(), CubieCube().toFaceletString());
    });

    test("equality is by move sequence", () {
      expect(Algorithm.parse("R U"), Algorithm.parse("R U"));
      expect(Algorithm.parse("R U").hashCode, Algorithm.parse("R U").hashCode);
      expect(Algorithm.parse("R U"), isNot(Algorithm.parse("U R")));
      expect(Algorithm.parse("R U"), isNot(Algorithm.parse("R")));
    });

    test("Solution is an Algorithm with the search's answer", () {
      final r = Search.solveCube(randomCube(5));
      final solution = r.solution!;
      expect(solution.algorithm.length, solution.length);
      expect(solution.moves, solution.algorithm.moves);
      expect(solution.toString(), solution.algorithm.toString());

      final cube = randomCube(5);
      cube.apply(solution.algorithm);
      expect(render(cube), solved);
    });
  });

  group("Solver interface", () {
    test("both solvers solve the same cube through the same interface", () {
      final facelets = randomCube(11).toFaceletString();
      for (final solver in [min2phase, kociemba]) {
        final r = solver.solve(facelets);
        expect(r.status, SolveStatus.foundSolution, reason: solver.name);
        expect(r.solution!.length, lessThanOrEqualTo(solver.defaultMaxLength), reason: solver.name);
        expect(r.solution!.elapsedTime, greaterThan(Duration.zero), reason: solver.name);

        final cube = randomCube(11);
        cube.apply(r.solution!.algorithm);
        expect(render(cube), solved, reason: "${solver.name} solution does not solve the cube");
      }
    });

    test("both reject an unsolvable cube", () {
      final cube = CubieCube();
      cube.edgeState[0] ^= 1; // one flipped edge
      final facelets = cube.toFaceletString();
      for (final solver in [min2phase, kociemba]) {
        expect(solver.solve(facelets).status, SolveStatus.invalidCube, reason: solver.name);
      }
    });

    test("a time limit ends the search rather than running on", () {
      // Far too short to find anything, so it has to give up.
      final r = min2phase.solve(randomCube(12).toFaceletString(), maxLength: 21, maxTime: Duration.zero);
      expect(r.status, SolveStatus.exceededMaxTime);
      expect(r.solution, isNull);
    });

    test("Solution carries the time it took", () {
      final r = Search.solveCube(randomCube(13));
      expect(r.solution!.elapsedTime, greaterThan(Duration.zero));
      expect(r.solution!.inverse.elapsedTime, r.solution!.elapsedTime);
      expect(Solution.empty.isEmpty, isTrue);
      expect(Solution.empty.elapsedTime, Duration.zero);
    });
  });

  group("solveDeeply", () {
    test("yields strictly shorter solutions, each of which solves the cube", () async {
      for (var seed = 0; seed < 4; seed++) {
        final cube = randomCube(seed);
        var previous = 1 << 30;
        var count = 0;

        await for (final solution in Search.solveDeeply(cube, maxTime: Duration(seconds: 2))) {
          expect(solution.length, lessThan(previous), reason: "seed $seed did not improve");
          previous = solution.length;
          count++;

          final check = CubieCube.from(cube);
          check.apply(solution.algorithm);
          expect(render(check), solved, reason: "seed $seed: $solution does not solve the cube");
        }

        expect(count, greaterThan(0), reason: "seed $seed produced nothing");
      }
    }, timeout: Timeout(Duration(minutes: 2)));

    test("does no worse than the one-shot search", () async {
      for (var seed = 4; seed < 8; seed++) {
        final cube = randomCube(seed);
        final quick = Search.solveCube(cube).solution!.length;

        var best = 1 << 30;
        await for (final solution in Search.solveDeeply(cube, maxTime: Duration(seconds: 2))) {
          best = solution.length;
        }
        expect(best, lessThanOrEqualTo(quick), reason: "seed $seed");
      }
    }, timeout: Timeout(Duration(minutes: 2)));

    test("yields nothing for an unsolvable cube", () async {
      final broken = CubieCube();
      broken.edgeState[0] ^= 1;
      expect(await Search.solveDeeply(broken).isEmpty, isTrue);
    });

    test("a solved cube needs no moves", () async {
      final first = await Search.solveDeeply(CubieCube()).first;
      expect(first.isEmpty, isTrue);
    });

    test(
      "computes nothing until it is listened to, and stops when abandoned",
      () async {
        final stream = Search.solveDeeply(randomCube(9));

        // Taking one solution must not run the search to exhaustion.
        final clock = Stopwatch()..start();
        final first = await stream.first;
        clock.stop();

        expect(first.length, lessThanOrEqualTo(Search.defaultMaxLength));
        expect(clock.elapsed, lessThan(Duration(seconds: 10)));
      },
      timeout: Timeout(Duration(minutes: 1)),
    );

    test("carries the elapsed time, growing with each improvement", () async {
      final times = <Duration>[];
      await for (final solution in Search.solveDeeply(randomCube(10), maxTime: Duration(seconds: 2))) {
        times.add(solution.elapsedTime);
      }
      expect(times, isNotEmpty);
      for (var i = 1; i < times.length; i++) {
        expect(times[i], greaterThanOrEqualTo(times[i - 1]));
      }
    }, timeout: Timeout(Duration(minutes: 1)));
  });
}
