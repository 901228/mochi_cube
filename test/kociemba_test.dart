import "package:mochi_cube/kociemba.dart";
import "package:test/test.dart";

const String solved =
    "UUUUUUUUU" "RRRRRRRRR" "FFFFFFFFF" "DDDDDDDDD" "LLLLLLLLL" "BBBBBBBBB";
const String knownFacelets = "DLBFUBRFL DDLRRDBRR FUBBFULDU ULRRDBLUF RDUULLDFF UFBRBBDLF";

String faceletsOf(CubieCube c) => FaceCube.fromCubieCube(c).toString();

void main() {
  group("coordinates", () {
    test("round-trip through their setters", () {
      final c = CubieCube();
      for (final v in [0, 1, 42, 1000, 2186]) {
        c.twist = v;
        expect(c.twist, v, reason: "twist $v");
      }
      for (final v in [0, 1, 42, 1000, 2047]) {
        c.flip = v;
        expect(c.flip, v, reason: "flip $v");
      }
      for (var v = 0; v < 495; v++) {
        c.udslice = v;
        expect(c.udslice, v, reason: "udslice $v");
      }
      for (var v = 0; v < 24; v++) {
        c.edge4 = v;
        expect(c.edge4, v, reason: "edge4 $v");
      }
      for (final v in [0, 1, 5039, 40319]) {
        c.edge8 = v;
        expect(c.edge8, v, reason: "edge8 $v");
        c.corner = v;
        expect(c.corner, v, reason: "corner $v");
      }
      for (final v in [0, 1, 123456, 479001599]) {
        c.edge = v;
        expect(c.edge, v, reason: "edge $v");
      }
    });

    test("are all zero for a solved cube", () {
      final c = CubieCube();
      expect([c.twist, c.flip, c.udslice, c.edge4, c.edge8, c.corner], everyElement(0));
    });
  });

  group("moves", () {
    test("a solved cube renders as the solved facelet string", () {
      expect(faceletsOf(CubieCube()), solved);
      expect(CubieCube().validate(), CubeVerification.solvable);
    });

    test("four quarter turns of any face is the identity", () {
      for (final r in Face.values) {
        final c = CubieCube();
        for (var i = 0; i < 4; i++) {
          c.move(r);
        }
        expect(faceletsOf(c), solved, reason: "${FaceExtension.faceToString[r.index]}4");
      }
    });

    test("(R U R' U') has order 6", () {
      final c = CubieCube();
      for (var i = 0; i < 6; i++) {
        c.applyScramble("R U R' U'");
      }
      expect(faceletsOf(c), solved);
    });

    test("superflip has every edge flipped and no corner moved", () {
      final c = CubieCube.fromScramble("U R2 F B R B2 R U2 L B2 R U' D' R2 F R' L B2 U2 F2");
      expect(c.validate(), CubeVerification.solvable);
      expect(c.flip, 2047);
      expect(c.twist, 0);
      expect(c.corner, 0);
    });

    test("facelet and cubie representations round-trip", () {
      final c = CubieCube.fromScramble("B2 R2 F' L2 F2 L2 F L2 B D2 U2 R2 U B' F2 R' B2 D2 L2 F' R");
      final facelets = faceletsOf(c);
      expect(faceletsOf(CubieCube.fromFaceCube(FaceCube.fromString(facelets))), facelets);
    });

    test("equal FaceCubes compare equal", () {
      final a = FaceCube.fromString(knownFacelets);
      final b = FaceCube.fromString(knownFacelets);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(FaceCube()));
    });
  });

  group("randomize", () {
    test("only produces solvable cubes", () {
      for (var seed = 0; seed < 200; seed++) {
        expect(CubieCube.randomize(seed).validate(), CubeVerification.solvable, reason: "seed $seed");
      }
    });
  });

  group("solver", () {
    test("inverseSolution undoes a scramble", () {
      const scramble = "B2 R2 F' L2 F2 L2 F L2 B D2 U2 R2 U B' F2 R' B2 D2 L2 F' R";
      final c = CubieCube.fromScramble(scramble);
      c.applyScramble(SolveManager.inverseSolution(scramble));
      expect(faceletsOf(c), solved);
    });

    test("rejects a well formed but unsolvable cube", () {
      // A single flipped edge keeps every colour count right but cannot be solved.
      final c = CubieCube();
      c.edgeState[0].orientation = 1;
      expect(c.validate(), CubeVerification.flipError);
      expect(() => SolveManager(faceletsOf(c)), throwsFormatException);
    });

    test("rejects facelets that do not describe a cube", () {
      // Ten U stickers and eight R stickers: no such corner or edge exists.
      const bad = "UUUUUUUUU" "RRRRRRRRU" "FFFFFFFFF" "DDDDDDDDD" "LLLLLLLLL" "BBBBBBBBB";
      expect(() => SolveManager(bad), throwsFormatException);
    });

    test("solves a known cube and the solution restores it", () {
      final result = SolveManager(knownFacelets).solve(maxLength: 25, maxTime: 60);
      expect(result.status, SolverStatus.foundSolution);

      final c = CubieCube.fromFaceCube(FaceCube.fromString(knownFacelets));
      c.applyScramble(result.solution);
      expect(faceletsOf(c), solved);
    });

    test("solves random cubes and every solution restores its cube", () {
      for (var seed = 0; seed < 25; seed++) {
        final result =
            SolveManager.fromCubieCube(CubieCube.randomize(seed)).solve(maxLength: 25, maxTime: 60);
        expect(result.status, SolverStatus.foundSolution, reason: "seed $seed");

        final c = CubieCube.randomize(seed);
        c.applyScramble(result.solution);
        expect(faceletsOf(c), solved, reason: "seed $seed solution does not solve the cube");
      }
    }, timeout: Timeout(Duration(minutes: 2)));
  });

  group("the kociemba library entry point", () {
    test("solves through the public API", () {
      // Nothing inside the package imports lib/kociemba.dart, so without this
      // a broken export would only show up for whoever depends on it.
      final result = kociemba.solve(knownFacelets);
      expect(result.status, SolveStatus.foundSolution);

      final cube = CubieCube.fromFaceCube(FaceCube.fromString(knownFacelets));
      cube.applyScramble(result.solution!.toString());
      expect(faceletsOf(cube), solved);
    });
  });
}
