import "cube/algorithm.dart";

/// How a solve ended.
enum SolveStatus {
  foundSolution,

  /// The facelets do not describe a cube that can be solved.
  invalidCube,

  /// No solution exists within the requested length.
  exceededMaxLength,

  /// The time limit ran out before a solution was found.
  exceededMaxTime,
}

/// The moves that solve a cube, and how long they took to find.
class Solution {
  /// The moves themselves.
  final Algorithm algorithm;

  /// How long the search ran for.
  final Duration elapsedTime;

  const Solution(this.algorithm, {this.elapsedTime = Duration.zero});

  Solution.fromMoves(List<int> moves, {Duration elapsedTime = Duration.zero})
    : this(Algorithm(moves), elapsedTime: elapsedTime);

  static const Solution empty = Solution(Algorithm.empty);

  /// The moves as indices, a shorthand for `algorithm.moves`.
  List<int> get moves => algorithm.moves;

  int get length => algorithm.length;

  bool get isEmpty => algorithm.isEmpty;

  bool get isNotEmpty => algorithm.isNotEmpty;

  /// The moves that undo this solution.
  Solution get inverse => Solution(algorithm.inverse, elapsedTime: elapsedTime);

  @override
  String toString() => algorithm.toString();

  @override
  bool operator ==(Object other) => other is Solution && other.algorithm == algorithm;

  @override
  int get hashCode => algorithm.hashCode;
}

/// The outcome of a solve.
///
/// [solution] is set exactly when [status] is [SolveStatus.foundSolution], and
/// [error] describes why the cube was rejected when it is
/// [SolveStatus.invalidCube].
typedef SolveResult = ({SolveStatus status, Solution? solution, Object? error});

/// A cube solving algorithm.
///
/// Two implement this: the min2phase search in
/// `package:mochi_cube/mochi_cube.dart` and the plainer Kociemba solver in
/// `package:mochi_cube/kociemba.dart`. They differ in speed, in how long their
/// solutions are and in how much memory their tables take, but not in what they
/// are asked to do, so code that only wants a solution can take a [Solver] and
/// let the caller pick.
abstract interface class Solver {
  /// A short name, for logging and for telling two solvers apart.
  String get name;

  /// The longest solution this solver will return by default.
  int get defaultMaxLength;

  /// Solve the cube described by a 54 character facelet string.
  ///
  /// The centres name the colours, so any six distinct letters will do; they do
  /// not have to be U, R, F, D, L and B.
  ///
  /// [maxLength] caps the number of moves. [maxTime], when given, stops the
  /// search once it has run that long, which may end with
  /// [SolveStatus.exceededMaxTime] and no solution.
  SolveResult solve(String facelets, {int maxLength, Duration? maxTime});
}
