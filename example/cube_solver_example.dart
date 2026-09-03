import "package:mochi_cube/mochi_cube.dart";

void main() {
  const String facelets = "DLBFUBRFL DDLRRDBRR FUBBFULDU ULRRDBLUF RDUULLDFF UFBRBBDLF";

  final result = min2phase.solve(facelets);
  switch (result.status) {
    case SolveStatus.foundSolution:
      final solution = result.solution!;
      print("${solution.length} moves in ${solution.elapsedTime.inMilliseconds}ms: $solution");
    case SolveStatus.invalidCube:
      print("Not a solvable cube: ${result.error}");
    case SolveStatus.exceededMaxLength:
      print("No solution within the requested length");
    case SolveStatus.exceededMaxTime:
      print("Ran out of time");
  }
}
