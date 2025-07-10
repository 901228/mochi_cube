import "package:cube_solver/cube_solver.dart";
import "package:test/test.dart";

void main() {
  group("A group of tests", () {
    const String scramble = "B2 R2 F' L2 F2 L2 F L2 B D2 U2 R2 U B' F2 R' B2 D2 L2 F' R";
    const String facelets = "DLBFUBRFL DDLRRDBRR FUBBFULDU ULRRDBLUF RDUULLDFF UFBRBBDLF";
    late FaceCube faceCube;
    late CubieCube cubieCube;
    late SolveManager solveManager;

    setUp(() {
      faceCube = FaceCube.fromString(facelets);
      cubieCube = CubieCube.fromFaceCube(faceCube);
      solveManager = SolveManager(facelets);
    });

    test("Validation Test", () {
      expect(cubieCube.validate(), same(CubeVerification.solvable));
    });

    test("Solver Test", () {
      expect(solveManager.solve().status, same(SolverStatus.foundSolution));
    });

    test("Random Test", () {
      final randomCube = CubieCube.randomize();
      expect(randomCube.validate(), same(CubeVerification.solvable));

      final solution = solveManager.solve();
      expect(solution.status, same(SolverStatus.foundSolution));
      print("scramble: ${SolveManager.inverseSolution(solution.solution)}");
      print("solution: ${solution.solution}");
    });
  });
}
