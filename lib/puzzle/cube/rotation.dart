import "../../cube/algorithm.dart";
import "cubie_cube.dart";
import "moves.dart";
import "symmetry.dart";

/// The axis a whole-cube rotation turns about.
///
/// [x] runs through the R and L faces, [y] through U and D, [z] through F and
/// B. Each rotation turns the whole cube the same way the corresponding face
/// move turns its layer: `x` like `R`, `y` like `U`, `z` like `F`.
enum Axis { x, y, z }

/// A rotation of the whole cube, rather than of one layer.
///
/// Turning the cube in your hands does not change how far it is from solved; it
/// changes which face you call U. So a rotation leaves a solved cube solved,
/// and turns a solution into the same solution with its moves renamed — see
/// [RotationAlgorithmExtension.rotated].
///
/// This is what to use when a cube was scanned or entered in an orientation
/// other than the one the solver expects.
class Rotation {
  /// The axis turned about.
  final Axis axis;

  /// Quarter turns clockwise, 0 to 3.
  final int n;

  const Rotation._(this.axis, this.n);

  factory Rotation(Axis axis, {int n = 1}) => Rotation._(axis, n % 4);

  factory Rotation.x([int n = 1]) => Rotation(Axis.x, n: n);
  factory Rotation.y([int n = 1]) => Rotation(Axis.y, n: n);
  factory Rotation.z([int n = 1]) => Rotation(Axis.z, n: n);

  /// The rotation that does nothing.
  static const Rotation none = Rotation._(Axis.y, 0);

  bool get isNone => n == 0;

  /// The rotation that undoes this one.
  Rotation get inverse => Rotation(axis, n: 4 - n);

  /// How this rotation renames the 18 face turns.
  ///
  /// `moveMap[m]` is the move that does to the rotated cube what `m` did to the
  /// cube before it was rotated.
  List<int> get moveMap => _moveMaps[axis.index][n];

  @override
  String toString() {
    if (isNone) {
      return "";
    }
    return axis.name + const ["", "", "2", "'"][n];
  }

  @override
  bool operator ==(Object other) => other is Rotation && other.n == n && (n == 0 || other.axis == axis);

  @override
  int get hashCode => n == 0 ? 0 : Object.hash(axis, n);
}

extension RotationExtension on CubieCube {
  /// This cube seen from the orientation [rotation] puts it in.
  ///
  /// A solved cube stays solved, and an unsolvable one stays unsolvable, so
  /// this only ever changes which face is which.
  CubieCube rotated(Rotation rotation) {
    if (rotation.isNone) {
      return CubieCube.from(this);
    }
    return _conjugate(this, _rotationCube(rotation.axis, rotation.n));
  }
}

extension RotationAlgorithmExtension on Algorithm {
  /// This algorithm renamed for a cube that has been turned by [rotation].
  ///
  /// If this solves a cube, the result solves that cube rotated.
  Algorithm rotated(Rotation rotation) {
    if (rotation.isNone) {
      return this;
    }
    final map = rotation.moveMap;
    return Algorithm(moves.map((m) => map[m]).toList());
  }
}

/// `r.inverse() * cube * r`, the cube seen from the frame `r` puts it in.
CubieCube _conjugate(CubieCube cube, CubieCube r) {
  final result = CubieCube.from(r.inverse());
  result.multiply(cube);
  result.multiply(r);
  return result;
}

bool _same(CubieCube a, CubieCube b) {
  for (var i = 0; i < CubieCube.cornerLength; i++) {
    if (a.cornerState[i] != b.cornerState[i]) return false;
  }
  for (var i = 0; i < CubieCube.edgeLength; i++) {
    if (a.edgeState[i] != b.edgeState[i]) return false;
  }
  return true;
}

/// The move a rotation renames `m` to, or -1 if it is not a face turn.
int _mappedMove(CubieCube r, int m) {
  final image = _conjugate(moveCube[m], r);
  for (var candidate = 0; candidate < moveCount; candidate++) {
    if (_same(moveCube[candidate], image)) return candidate;
  }
  return -1;
}

/// The three generators, derived rather than written down as constants.
///
/// The 24 rotations of the cube are the 8 non-mirror members of [cubeSym] —
/// those that keep the U/D axis — composed with the powers of [urf1], which
/// moves it. Each generator is picked out of those 24 by what it does to the
/// face turns, and there is exactly one match for each.
final List<CubieCube> _generators = _findGenerators();

List<CubieCube> _findGenerators() {
  const u = 0, r = 3, f = 6, l = 12;

  final rotations = <CubieCube>[];
  for (var power = 0; power < 3; power++) {
    for (var s = 0; s < symCount; s++) {
      if (cubeSym[s].cornerState.any((c) => c >> 3 >= 3)) {
        continue; // a mirror, not a rotation
      }
      final cube = CubieCube();
      for (var i = 0; i < power; i++) {
        cube.multiply(urf1);
      }
      cube.multiply(cubeSym[s]);
      rotations.add(cube);
    }
  }

  CubieCube pick(String name, bool Function(List<int> map) matches) {
    final found = rotations.where((rotation) {
      final map = List.generate(moveCount, (m) => _mappedMove(rotation, m));
      return !map.contains(-1) && matches(map);
    }).toList();
    if (found.length != 1) {
      throw StateError("Expected exactly one $name rotation, found ${found.length}");
    }
    return found.single;
  }

  return [
    // x turns like R: the front face goes to the top, the right face stays put.
    pick("x", (map) => map[r] == r && map[f] == u),
    // y turns like U: the front face goes to the left, the top stays put.
    pick("y", (map) => map[u] == u && map[f] == l),
    // z turns like F: the top face goes to the right, the front stays put.
    pick("z", (map) => map[f] == f && map[u] == r),
  ];
}

final List<List<CubieCube>> _cubes = [
  for (var axis = 0; axis < 3; axis++)
    [
      for (var n = 0; n < 4; n++)
        () {
          final cube = CubieCube();
          for (var i = 0; i < n; i++) {
            cube.multiply(_generators[axis]);
          }
          return cube;
        }(),
    ],
];

final List<List<List<int>>> _moveMaps = [
  for (var axis = 0; axis < 3; axis++)
    [for (var n = 0; n < 4; n++) List.generate(moveCount, (m) => _mappedMove(_cubes[axis][n], m))],
];

CubieCube _rotationCube(Axis axis, int n) => _cubes[axis.index][n];
