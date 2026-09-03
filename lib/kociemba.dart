/// The plain Kociemba two phase solver.
///
/// Slower than the min2phase solver in `package:mochi_cube/mochi_cube.dart` and
/// its solutions are a couple of moves longer, but the code is far simpler. It
/// is also the reference the min2phase tables are checked against, so it is
/// kept rather than replaced.
library;

export "kociemba/cube/cubie_cube.dart" show CubieCube;
export "kociemba/cube/enums.dart";
export "kociemba/cube/face_cube.dart" show FaceCube;
export "cube/algorithm.dart" show Algorithm;
export "kociemba/solver.dart" show KociembaSolver, SolveManager, SolverResult, SolverStatus, kociemba;
export "solver.dart" show SolveResult, SolveStatus, Solution, Solver;
