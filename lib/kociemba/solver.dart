import "dart:math";

import "cube/coord_cube.dart";
import "cube/cubie_cube.dart";
import "cube/enums.dart";
import "cube/face_cube.dart";
import "../cube/algorithm.dart";
import "../solver.dart";
import "tables.dart";

enum SolverStatus {
  foundSolution,
  exceededMaxLength, // maxTime exceeded, no solution found
  exceededMaxTime, // no solution found, try increasing maxLength
}

typedef SolverResult = ({SolverStatus status, String solution});

class SolveManager {
  final String _facelets;
  final FaceCube _faceCube;
  late final CoordCube _coordCube;

  SolveManager(String facelets)
    : assert(facelets.replaceAll(" ", "").length == FaceCube.stateLength),
      _facelets = facelets.toUpperCase(),
      _faceCube = FaceCube.fromString(facelets) {
    final cubieCube = CubieCube.fromFaceCube(_faceCube);
    _coordCube = CoordCube.fromCubieCube(cubieCube);
    final status = cubieCube.validate();
    if (status != CubeVerification.solvable) {
      throw FormatException("Invalid facelets: $facelets");
    }
  }

  SolveManager.fromFaceCube(FaceCube faceCube) : _faceCube = faceCube, _facelets = faceCube.toString() {
    final cubieCube = CubieCube.fromFaceCube(faceCube);
    _coordCube = CoordCube.fromCubieCube(cubieCube);
    final status = cubieCube.validate();
    if (status != CubeVerification.solvable) {
      throw FormatException("Invalid facelets: $_facelets");
    }
  }

  SolveManager.fromCubieCube(CubieCube cubieCube)
    : _faceCube = FaceCube.fromCubieCube(cubieCube),
      _facelets = FaceCube.fromCubieCube(cubieCube).toString() {
    _coordCube = CoordCube.fromCubieCube(cubieCube);
    final status = cubieCube.validate();
    if (status != CubeVerification.solvable) {
      throw FormatException("Invalid facelets: $_facelets");
    }
  }

  /// Current time in seconds
  double get _currentTime => DateTime.now().millisecondsSinceEpoch / 1000;

  int _allowedLength = 25;
  double _timeout = double.infinity;

  /// Solve the cube with the given [maxLength] and [maxTime] (seconds)
  ///
  /// Solver will ensure the length of the solution is less than or equal to [maxLength]
  /// and will stop searching when the time limit [maxTime] is reached
  ///
  /// Returns a [SolverResult] with the solution and status
  SolverResult solve({int maxLength = 25, double maxTime = double.infinity}) {
    // prepare for phase 1
    _allowedLength = maxLength;
    _timeout = _currentTime + maxTime;

    _phase1Initialise(maxLength);

    // solve
    for (int depth = 0; depth < _allowedLength; depth++) {
      SolverResult n = _phase1Search(0, depth, _allowedLength);
      if (n.status == SolverStatus.foundSolution) {
        return n;
      } else if (n.status == SolverStatus.exceededMaxTime) {
        return (status: SolverStatus.exceededMaxTime, solution: "");
      }
    }

    return (status: SolverStatus.exceededMaxLength, solution: "");
  }

  late List<int> _axis;
  late List<int> _power;
  late List<int> _twist;
  late List<int> _flip;
  late List<int> _udslice;
  late List<int> _minDist1;
  void _phase1Initialise(int maxLength) {
    // The lists `axis` and `power` will store the n-th move
    // (index of face being turned stored in axis, number of clockwise quarter turns stored in power)
    // The n-th move is stored in position n - 1
    _axis = List.filled(maxLength, 0);
    _power = List.filled(maxLength, 0);

    // The lists twist, flip and udslice store the phase 1 coordinates after n moves
    // Position 0 stores the inital states, the coordinates after n moves are stored in position n
    _twist = List.filled(maxLength, 0);
    _flip = List.filled(maxLength, 0);
    _udslice = List.filled(maxLength, 0);

    // The following array store minimum number of moves required to reach phase 2 after n moves
    // These estimates come from the pruning tables and are used to exclude branches in the search tree
    _minDist1 = List.filled(maxLength, 0);

    // Initialise the arrays from the input
    _twist[0] = _coordCube.twist;
    _flip[0] = _coordCube.flip;
    _udslice[0] = _coordCube.udslice;
    _minDist1[0] = _phase1Cost(0);
  }

  late List<int> _edge4;
  late List<int> _edge8;
  late List<int> _corner;
  late List<int> _minDist2;
  void _phase2Initialise(int n, int maxLength) {
    // Similarly to above, these lists store the phase 2 coordinates after n moves
    _edge4 = List.filled(maxLength, 0);
    _edge8 = List.filled(maxLength, 0);
    _corner = List.filled(maxLength, 0);

    // The following two arrays store minimum number of moves required to reach phase 2 or a solution respectively after n moves
    // These estimates come from the pruning tables and are used to exclude branches in the search tree
    _minDist2 = List.filled(maxLength, 0);

    // Initialise the arrays from the input
    _corner[0] = _coordCube.corner;
    _edge4[0] = _coordCube.edge4;
    _edge8[0] = _coordCube.edge8;

    // Initialise phase 2 search from the phase 1 solution
    final cc = CubieCube.fromFaceCube(_faceCube);
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < _power[i]; j++) {
        cc.move(Face.values[_axis[i]]);
      }
    }
    _edge4[n] = cc.edge4;
    _edge8[n] = cc.edge8;
    _corner[n] = cc.corner;
    _minDist2[n] = _phase2Cost(n);
  }

  /// Cost of current position for use in phase 1
  /// Returns a lower bound on the number of moves requires to get to phase 2
  int _phase1Cost(int n) {
    return max(
      Table().udsliceTwistPrune[(_udslice[n], _twist[n])],
      Table().udsliceFlipPrune[(_udslice[n], _flip[n])],
    );
  }

  /// Cost of current position for use in phase 2
  /// Returns a lower bound on the number of moves required to get to a solved cube.
  int _phase2Cost(int n) {
    return max(
      Table().edge4Edge8Prune[(_edge4[n], _edge8[n])],
      Table().edge4CornerPrune[(_edge4[n], _corner[n])],
    );
  }

  /// Solve the cube to the G1 group using DFS
  /// twist = 0, flip = 0, udslice = 0
  SolverResult _phase1Search(int n, int depth, int maxLength) {
    if (_currentTime > _timeout) {
      return (status: SolverStatus.exceededMaxTime, solution: "");
    } else if (_minDist1[n] == 0) {
      _phase2Initialise(n, maxLength);

      for (var d = 0; d < maxLength - n; d++) {
        final m = _phase2Search(n, d);
        if (m.status == SolverStatus.foundSolution) {
          return m;
        }
      }
      return (status: SolverStatus.exceededMaxLength, solution: "");
    } else if (_minDist1[n] <= depth) {
      for (var i = 0; i < Face.values.length; i++) {
        // don't turn the same face on consecutive moves
        // also for opposite faces, e.g. U and D, UD = DU, so we can impose that the lower index happens first
        if (n > 0 && (_axis[n - 1] == i || _axis[n - 1] == i + 3)) {
          continue;
        }

        for (var j = 1; j < 4; j++) {
          _axis[n] = i;
          _power[n] = j;
          final int mv = 3 * i + j - 1;

          // update coordnates
          _twist[n + 1] = Table().twistMove[(_twist[n], mv)];
          _flip[n + 1] = Table().flipMove[(_flip[n], mv)];
          _udslice[n + 1] = Table().udsliceMove[(_udslice[n], mv)];
          _minDist1[n + 1] = _phase1Cost(n + 1);

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
    if (_currentTime > _timeout) {
      return (status: SolverStatus.exceededMaxTime, solution: "");
    } else if (_minDist2[n] == 0) {
      return (status: SolverStatus.foundSolution, solution: _solutionToString(n));
    } else if (_minDist2[n] <= depth) {
      for (var i = 0; i < Face.values.length; i++) {
        if (n > 0 && (_axis[n - 1] == i || _axis[n - 1] == i + 3)) {
          continue;
        }

        for (var j = 1; j < 4; j++) {
          // in phase 2 we only allow half turns of right, front, left, back
          if ((Face.values[i] == Face.right ||
                  Face.values[i] == Face.front ||
                  Face.values[i] == Face.left ||
                  Face.values[i] == Face.back) &&
              j != 2) {
            continue;
          }
          _axis[n] = i;
          _power[n] = j;
          final mv = 3 * i + j - 1;

          // update coordinates
          _edge4[n + 1] = Table().edge4Move[(_edge4[n], mv)];
          _edge8[n + 1] = Table().edge8Move[(_edge8[n], mv)];
          _corner[n + 1] = Table().cornerMove[(_corner[n], mv)];
          _minDist2[n + 1] = _phase2Cost(n + 1);

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
      for (var i = 0; i < length; i++) CRotation(Face.values[_axis[i]], _power[i]).toString(),
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

/// [SolveManager] behind the common [Solver] interface.
///
/// Slower than [Min2PhaseSolver] and its solutions are a couple of moves
/// longer, but it is the reference the other one's tables are verified against.
class KociembaSolver implements Solver {
  const KociembaSolver();

  @override
  String get name => "kociemba";

  @override
  int get defaultMaxLength => 25;

  @override
  SolveResult solve(String facelets, {int maxLength = 25, Duration? maxTime}) {
    final SolveManager manager;
    try {
      manager = SolveManager(facelets);
    } on FormatException catch (e) {
      return (status: SolveStatus.invalidCube, solution: null, error: e);
    }

    final clock = Stopwatch()..start();
    final result = manager.solve(
      maxLength: maxLength,
      maxTime: maxTime == null ? double.infinity : maxTime.inMicroseconds / 1e6,
    );
    clock.stop();

    return switch (result.status) {
      SolverStatus.foundSolution => (
        status: SolveStatus.foundSolution,
        solution: Solution(Algorithm.parse(result.solution), elapsedTime: clock.elapsed),
        error: null,
      ),
      SolverStatus.exceededMaxTime => (
        status: SolveStatus.exceededMaxTime,
        solution: null,
        error: null,
      ),
      SolverStatus.exceededMaxLength => (
        status: SolveStatus.exceededMaxLength,
        solution: null,
        error: null,
      ),
    };
  }
}

/// The default [KociembaSolver].
const Solver kociemba = KociembaSolver();
