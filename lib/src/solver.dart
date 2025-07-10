import "dart:math";

import "cube/coord_cube.dart";
import "cube/cubie_cube.dart";
import "cube/enums.dart";
import "cube/face_cube.dart";
import "tables.dart";

enum SolverStatus {
  foundSolution,
  exceededMaxLength, // maxTime exceeded, no solution found
  exceededMaxTime, // no solution found, try increasing maxLength
}

typedef SolverResult = ({SolverStatus status, String solution});

class SolveManager {
  final String facelets;
  final FaceCube faceCube;
  late final CoordCube coordCube;

  SolveManager(String facelets)
    : assert(facelets.replaceAll(" ", "").length == FaceCube.stateLength),
      facelets = facelets.toUpperCase(),
      faceCube = FaceCube.fromString(facelets) {
    final cubieCube = CubieCube.fromFaceCube(faceCube);
    coordCube = CoordCube.fromCubieCube(cubieCube);
    final status = cubieCube.validate();
    if (status != CubeVerification.solvable) {
      throw FormatException("Invalid facelets: $facelets");
    }
  }

  /// Current time in seconds
  double get currentTime => DateTime.now().millisecondsSinceEpoch / 1000;

  int allowedLength = 25;
  double timeout = double.infinity;
  late List<CRotation?> rotations;

  /// Solve the cube with the given [maxLength] and [maxTime] (seconds)
  ///
  /// Solver will ensure the length of the solution is less than or equal to [maxLength]
  /// and will stop searching when the time limit [maxTime] is reached
  ///
  /// Returns a [SolverResult] with the solution and status
  SolverResult solve({int maxLength = 25, double maxTime = double.infinity}) {
    // prepare for phase 1
    allowedLength = maxLength;
    timeout = currentTime + maxTime;

    // Store the moves (the n-th move is stored in position n - 1)
    rotations = List.generate(maxLength, (_) => null, growable: false);

    _phase1Initialise(maxLength);

    // solve
    for (int depth = 0; depth < allowedLength; depth++) {
      SolverResult n = _phase1Search(0, depth, allowedLength);
      if (n.status == SolverStatus.foundSolution) {
        return n;
      } else if (n.status == SolverStatus.exceededMaxTime) {
        return (status: SolverStatus.exceededMaxTime, solution: "");
      }
    }

    return (status: SolverStatus.exceededMaxLength, solution: "");
  }

  List<String> solveAll({int maxLength = 25, double maxTime = double.infinity}) {
    final List<String> solutions = [];

    while (true) {
      final solution = solve(maxLength: maxLength, maxTime: maxTime);
      print(solution);

      if (solution.status == SolverStatus.foundSolution) {
        solutions.add(solution.solution);
      } else {
        // timeout or no more solutions
        break;
      }
    }

    return solutions;
  }

  late List<int> axis;
  late List<int> power;
  late List<int> twist;
  late List<int> flip;
  late List<int> udslice;
  late List<int> minDist1;
  void _phase1Initialise(int maxLength) {
    // The lists `axis` and `power` will store the n-th move
    // (index of face being turned stored in axis, number of clockwise quarter turns stored in power)
    // The n-th move is stored in position n - 1
    axis = List.filled(maxLength, 0);
    power = List.filled(maxLength, 0);

    // The lists twist, flip and udslice store the phase 1 coordinates after n moves
    // Position 0 stores the inital states, the coordinates after n moves are stored in position n
    twist = List.filled(maxLength, 0);
    flip = List.filled(maxLength, 0);
    udslice = List.filled(maxLength, 0);

    // The following array store minimum number of moves required to reach phase 2 after n moves
    // These estimates come from the pruning tables and are used to exclude branches in the search tree
    minDist1 = List.filled(maxLength, 0);

    // Initialise the arrays from the input
    twist[0] = coordCube.twist;
    flip[0] = coordCube.flip;
    udslice[0] = coordCube.udslice;
    minDist1[0] = _phase1Cost(0);
  }

  late List<int> edge4;
  late List<int> edge8;
  late List<int> corner;
  late List<int> minDist2;
  void _phase2Initialise(int n, int maxLength) {
    // Similarly to above, these lists store the phase 2 coordinates after n moves
    edge4 = List.filled(maxLength, 0);
    edge8 = List.filled(maxLength, 0);
    corner = List.filled(maxLength, 0);

    // The following two arrays store minimum number of moves required to reach phase 2 or a solution respectively after n moves
    // These estimates come from the pruning tables and are used to exclude branches in the search tree
    minDist2 = List.filled(maxLength, 0);

    // Initialise the arrays from the input
    corner[0] = coordCube.corner;
    edge4[0] = coordCube.edge4;
    edge8[0] = coordCube.edge8;

    // Initialise phase 2 search from the phase 1 solution
    final cc = CubieCube.fromFaceCube(faceCube);
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < power[i]; j++) {
        cc.move(ERotation.values[axis[i]]);
      }
    }
    edge4[n] = cc.edge4;
    edge8[n] = cc.edge8;
    corner[n] = cc.corner;
    minDist2[n] = _phase2Cost(n);
  }

  /// Cost of current position for use in phase 1
  /// Returns a lower bound on the number of moves requires to get to phase 2
  int _phase1Cost(int n) {
    return max(
      Table().udsliceTwistPrune[(udslice[n], twist[n])],
      Table().udsliceFlipPrune[(udslice[n], flip[n])],
    );
  }

  /// Cost of current position for use in phase 2
  /// Returns a lower bound on the number of moves required to get to a solved cube.
  int _phase2Cost(int n) {
    return max(
      Table().edge4Edge8Prune[(edge4[n], edge8[n])],
      Table().edge4CornerPrune[(edge4[n], corner[n])],
    );
  }

  /// Solve the cube to the G1 group using DFS
  /// twist = 0, flip = 0, udslice = 0
  SolverResult _phase1Search(int n, int depth, int maxLength) {
    if (currentTime > timeout) {
      return (status: SolverStatus.exceededMaxTime, solution: "");
    } else if (minDist1[n] == 0) {
      _phase2Initialise(n, maxLength);

      for (var d = 0; d < maxLength - n; d++) {
        final m = _phase2Search(n, d);
        if (m.status == SolverStatus.foundSolution) {
          return m;
        }
      }
      return (status: SolverStatus.exceededMaxLength, solution: "");
    } else if (minDist1[n] <= depth) {
      for (var i = 0; i < ERotation.values.length; i++) {
        // don't turn the same face on consecutive moves
        // also for opposite faces, e.g. U and D, UD = DU, so we can impose that the lower index happens first
        if (n > 0 && (axis[n - 1] == i || axis[n - 1] == i + 3)) {
          continue;
        }

        for (var j = 1; j < 4; j++) {
          axis[n] = i;
          power[n] = j;
          final int mv = 3 * i + j - 1;

          // update coordnates
          twist[n + 1] = Table().twistMove[twist[n]][mv];
          flip[n + 1] = Table().flipMove[flip[n]][mv];
          udslice[n + 1] = Table().udsliceMove[udslice[n]][mv];
          minDist1[n + 1] = _phase1Cost(n + 1);

          // start search from next node
          final m = _phase1Search(n + 1, depth - 1, maxLength);
          if (m.status != SolverStatus.exceededMaxLength) {
            return m;
          }
        }
      }
    }

    return (status: SolverStatus.exceededMaxLength, solution: "");
  }

  SolverResult _phase2Search(int n, int depth) {
    if (currentTime > timeout) {
      return (status: SolverStatus.exceededMaxTime, solution: "");
    } else if (minDist2[n] == 0) {
      return (status: SolverStatus.foundSolution, solution: _solutionToString(n));
    } else if (minDist2[n] <= depth) {
      for (var i = 0; i < ERotation.values.length; i++) {
        if (n > 0 && (axis[n - 1] == i || axis[n - 1] == i + 3)) {
          continue;
        }

        for (var j = 1; j < 4; j++) {
          // in phase 2 we only allow half turns of right, front, left, back
          if ((ERotation.values[i] == ERotation.right ||
                  ERotation.values[i] == ERotation.front ||
                  ERotation.values[i] == ERotation.left ||
                  ERotation.values[i] == ERotation.back) &&
              j != 2) {
            continue;
          }
          axis[n] = i;
          power[n] = j;
          final mv = 3 * i + j - 1;

          // update coordinates
          edge4[n + 1] = Table().edge4Move[edge4[n]][mv];
          edge8[n + 1] = Table().edge8Move[edge8[n]][mv];
          corner[n + 1] = Table().cornerMove[corner[n]][mv];
          minDist2[n + 1] = _phase2Cost(n + 1);

          // start search from new node
          final m = _phase2Search(n + 1, depth - 1);
          if (m.status == SolverStatus.foundSolution) {
            return m;
          }
        }
      }
    }

    // if no moves lead to a tree with a solution or min_dist_2 > depth,
    // then we return `SolverStatus.exceededMaxLength` to signify lack of solution
    return (status: SolverStatus.exceededMaxLength, solution: "");
  }

  /// Generate solution string
  ///
  /// Uses standard cube notation:
  ///   F means clockwise quarter turn of the F face,
  ///   U' means a counter clockwise quarter turn of the U face,
  ///   R2 means a half turn of the R face etc.
  String _solutionToString(int length) {
    final solution = [
      for (var i = 0; i < length; i++) CRotation(ERotation.values[axis[i]], power[i]).toString(),
    ];

    return solution.join(" ");
  }

  static String inverseSolution(String solution) {
    final solutionList = solution.split(" ");

    final scramble = solutionList.reversed.map((move) {
      final rotation = CRotation.fromString(move);
      rotation.invert();
      return rotation.toString();
    });

    return scramble.join(" ");
  }
}
