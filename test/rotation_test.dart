import "package:mochi_cube/mochi_cube.dart";
import "package:test/test.dart";

String state(CubieCube c) => "${c.cornerState}|${c.edgeState}";

int _rng = 4242;
int _next(int n) {
  _rng = (_rng * 1103515245 + 12345) & 0x7FFFFFFF;
  return _rng % n;
}

CubieCube scrambled(int moves) {
  final c = CubieCube();
  for (var i = 0; i < moves; i++) {
    c.moveIndex(_next(18));
  }
  return c;
}

void main() {
  setUp(() => _rng = 4242);

  group("Rotation", () {
    test("normalises the number of quarter turns", () {
      expect(Rotation.x(5), Rotation.x(1));
      expect(Rotation.y(4), Rotation.none);
      expect(Rotation(Axis.z, n: -1), Rotation.z(3));
      expect(Rotation.none.isNone, isTrue);
      expect(Rotation.x(0), Rotation.y(0), reason: "no rotation has no axis");
    });

    test("prints standard notation", () {
      expect(Rotation.x().toString(), "x");
      expect(Rotation.y(2).toString(), "y2");
      expect(Rotation.z(3).toString(), "z'");
      expect(Rotation.none.toString(), "");
    });

    test("inverse undoes it", () {
      for (final axis in Axis.values) {
        for (var n = 0; n < 4; n++) {
          final r = Rotation(axis, n: n);
          final cube = scrambled(12);
          expect(state(cube.rotated(r).rotated(r.inverse)), state(cube),
              reason: "$r then ${r.inverse}");
        }
      }
    });

    test("four quarter turns about any axis is the identity", () {
      for (final axis in Axis.values) {
        var cube = scrambled(12);
        final start = state(cube);
        for (var i = 0; i < 4; i++) {
          cube = cube.rotated(Rotation(axis));
        }
        expect(state(cube), start, reason: "${axis.name}4");
      }
    });

    test("leaves a solved cube solved and keeps a cube solvable", () {
      for (final axis in Axis.values) {
        for (var n = 0; n < 4; n++) {
          final r = Rotation(axis, n: n);
          expect(state(CubieCube().rotated(r)), state(CubieCube()), reason: "$r");
          expect(scrambled(12).rotated(r).verify(), CubeVerificationStatus.solvable);
        }
      }
    });

    test("turns the cube the way the matching face move turns its layer", () {
      // x like R, y like U, z like F.
      expect(moveToString(Rotation.x().moveMap[parseMove("F")]), "U");
      expect(moveToString(Rotation.x().moveMap[parseMove("R")]), "R");
      expect(moveToString(Rotation.y().moveMap[parseMove("F")]), "L");
      expect(moveToString(Rotation.y().moveMap[parseMove("U")]), "U");
      expect(moveToString(Rotation.z().moveMap[parseMove("U")]), "R");
      expect(moveToString(Rotation.z().moveMap[parseMove("F")]), "F");
    });

    test("moveMap is a permutation that keeps the turn amount", () {
      for (final axis in Axis.values) {
        for (var n = 0; n < 4; n++) {
          final map = Rotation(axis, n: n).moveMap;
          expect(map.toSet(), hasLength(18), reason: "$axis $n");
          for (var m = 0; m < 18; m++) {
            expect(map[m] % 3, m % 3, reason: "a rotation is not a mirror");
          }
        }
      }
      expect(Rotation.none.moveMap, List.generate(18, (m) => m));
    });

    test("rotating commutes with turning", () {
      for (var trial = 0; trial < 200; trial++) {
        final r = Rotation(Axis.values[_next(3)], n: _next(4));
        final algorithm = Algorithm([for (var i = 0; i < 8; i++) _next(18)]);

        final direct = scrambled(6);
        final viaRotation = direct.rotated(r);
        direct.apply(algorithm);
        viaRotation.apply(algorithm.rotated(r));

        expect(state(direct.rotated(r)), state(viaRotation), reason: "$r, $algorithm");
      }
    });

    test("a solution rotates with the cube", () {
      // The point of the whole thing: a cube entered in a different
      // orientation is solved by the same moves, renamed.
      for (var trial = 0; trial < 10; trial++) {
        final cube = scrambled(15);
        final solution = Search.solveCube(cube).solution!;

        for (final axis in Axis.values) {
          for (var n = 1; n < 4; n++) {
            final r = Rotation(axis, n: n);
            final rotated = cube.rotated(r);
            rotated.apply(solution.algorithm.rotated(r));
            expect(rotated.toFaceletString(), CubieCube().toFaceletString(),
                reason: "$r did not carry the solution over");
          }
        }
      }
    }, timeout: Timeout(Duration(minutes: 2)));

    test("a rotated cube solves to about the same length", () {
      // Rotating cannot change the *optimal* length, but the two phase search
      // does not find optimal solutions: its six views are defined around the
      // U/D axis, so turning the cube changes which ones it looks at and the
      // answer can come out a move or two longer or shorter.
      for (var trial = 0; trial < 5; trial++) {
        final cube = scrambled(15);
        final direct = Search.solveCube(cube).solution!.length;
        for (final axis in Axis.values) {
          final rotated = cube.rotated(Rotation(axis));
          final solution = Search.solveCube(rotated).solution!;
          expect((solution.length - direct).abs(), lessThanOrEqualTo(3),
              reason: "$axis: $direct vs ${solution.length}");

          rotated.apply(solution.algorithm);
          expect(rotated.toFaceletString(), CubieCube().toFaceletString());
        }
      }
    }, timeout: Timeout(Duration(minutes: 2)));

    test("a rotated cube still renders as a real cube", () {
      final rotated = scrambled(15).rotated(Rotation.x(2));
      expect(rotated.verify(), CubeVerificationStatus.solvable);
      // Nine of each colour, checked through the independent kociemba renderer.
      final counts = List.filled(6, 0);
      for (final face in rotated.toFacelets()) {
        counts[face]++;
      }
      expect(counts, everyElement(9));
    });
  });
}
