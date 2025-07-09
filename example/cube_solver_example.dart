import "package:cube_solver/cube_solver.dart";

void main() {
  const String facelets = "DLBFUBRFL DDLRRDBRR FUBBFULDU ULRRDBLUF RDUULLDFF UFBRBBDLF";
  final SolveManager solveManager = SolveManager(facelets);

  print(solveManager.solve());
}
