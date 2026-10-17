import "../logger.dart";
import "../table_storage.dart";
import "cube.dart";

/// Move and distance tables for the Pyraminx.
///
/// 933120 states without the tips, which one breadth-first search covers, so
/// the exact number of turns to solve is known for every one of them and
/// solving is a walk downhill rather than a search. God's number is 11.
///
/// The state splits into three parts that each move on their own: how the four
/// vertices are twisted, how the six edges are permuted, and how they are
/// flipped. Only even permutations and even numbers of flips are reachable —
/// a turn is a three-cycle, which is even — which is what makes the count
/// `81 * 360 * 32` rather than `81 * 720 * 64`.
class PyraminxTables {
  factory PyraminxTables() => _instance;
  static final PyraminxTables _instance = PyraminxTables._internal();

  /// Twists of the four vertices.
  static const int nVertices = 81; // 3^4

  /// Even permutations of the six edges.
  static const int nEdgePerms = 360; // 6! / 2

  /// Flip patterns with an even total.
  static const int nEdgeFlips = 32; // 2^6 / 2

  static const int nStates = nVertices * nEdgePerms * nEdgeFlips;

  /// The cache file. Bump the version whenever a builder below changes.
  static TableFile get _cache => const TableFile(
    name: TableFiles.pyraminx,
    magic: [0x50, 0x59, 0x52, 0x41], // "PYRA"
    version: 2,
  );

  static List<int> get _sectionLengths => [
    nVertices * layerMoveCount * 2,
    nEdgePerms * layerMoveCount * 2,
    nEdgeFlips * layerMoveCount * 2,
    (nStates + 1) ~/ 2,
  ];

  PyraminxTables._internal() {
    final cached = _cache.read(_sectionLengths);
    if (cached != null) {
      vertexMove = movingTableFromBytes(cached[0], nVertices, layerMoveCount);
      permMove = movingTableFromBytes(cached[1], nEdgePerms, layerMoveCount);
      flipMove = movingTableFromBytes(cached[2], nEdgeFlips, layerMoveCount);
      distance = PruningTable(cached[3], nEdgeFlips, nStates);
      Logging().info("Loaded the pyraminx tables from ${_cache.location}");
      return;
    }

    vertexMove = _buildVertexMove();
    permMove = _buildPermMove();
    flipMove = _buildFlipMove();
    distance = fillPruningTable(
      length: nStates,
      stride: nEdgeFlips,
      moveCount: layerMoveCount,
      successor: successor,
    );

    _cache.write([
      movingTableBytes(vertexMove),
      movingTableBytes(permMove),
      movingTableBytes(flipMove),
      distance.data,
    ]);
  }

  late final MovingTable vertexMove;
  late final MovingTable permMove;
  late final MovingTable flipMove;

  /// Turns needed to solve, for every state. Exact, not a bound.
  late final PruningTable distance;

  /// The flat index of a state.
  int indexOf(int vertices, int perm, int flips) => (vertices * nEdgePerms + perm) * nEdgeFlips + flips;

  /// The state of [cube], as an index.
  int stateOf(PyraminxCube cube) {
    var vertices = 0;
    for (var i = PyraminxCube.vertexCount - 1; i >= 0; i--) {
      vertices = vertices * 3 + cube.vertices[i];
    }
    return indexOf(vertices, _permIndex[_permKey(cube.edges)]!, _flipIndex(cube.flips));
  }

  /// The state reached from [index] by layer move [move].
  int successor(int index, int move) {
    final flips = index % nEdgeFlips;
    final perm = (index ~/ nEdgeFlips) % nEdgePerms;
    final vertices = index ~/ (nEdgePerms * nEdgeFlips);
    return indexOf(vertexMove[(vertices, move)], permMove[(perm, move)], flipMove[(flips, move)]);
  }

  /// Turns needed to solve [cube]. Exact, not a bound.
  int distanceOf(PyraminxCube cube) => distance.at(stateOf(cube));

  int get lengthInBytes =>
      vertexMove.lengthInBytes + permMove.lengthInBytes + flipMove.lengthInBytes + distance.lengthInBytes;

  // ==========================
  // Coordinates
  // ==========================

  /// The even permutations of the six edges, in order.
  static final List<List<int>> evenPermutations = _evenPermutations();

  static final Map<String, int> _permIndex = {
    for (var i = 0; i < evenPermutations.length; i++) _permKey(evenPermutations[i]): i,
  };

  static String _permKey(List<int> permutation) => permutation.join();

  static List<List<int>> _evenPermutations() {
    final all = _permutationsOf([0, 1, 2, 3, 4, 5]);
    return [
      for (final permutation in all)
        if (!_isOdd(permutation)) permutation,
    ];
  }

  static List<List<int>> _permutationsOf(List<int> of) {
    if (of.length <= 1) return [of];
    return [
      for (var i = 0; i < of.length; i++)
        for (final rest in _permutationsOf([...of]..removeAt(i))) [of[i], ...rest],
    ];
  }

  static bool _isOdd(List<int> permutation) {
    var inversions = 0;
    for (var i = 0; i < permutation.length; i++) {
      for (var j = i + 1; j < permutation.length; j++) {
        if (permutation[i] > permutation[j]) inversions++;
      }
    }
    return inversions.isOdd;
  }

  /// The flips, as a number. The last is forced, so only five are stored.
  static int _flipIndex(List<int> flips) {
    var index = 0;
    for (var i = PyraminxCube.edgeCount - 2; i >= 0; i--) {
      index = index * 2 + flips[i];
    }
    return index;
  }

  static List<int> _flipsFromIndex(int index) {
    final flips = List.filled(PyraminxCube.edgeCount, 0);
    var total = 0;
    var rest = index;
    for (var i = 0; i < PyraminxCube.edgeCount - 1; i++) {
      flips[i] = rest % 2;
      total ^= flips[i];
      rest ~/= 2;
    }
    flips[PyraminxCube.edgeCount - 1] = total;
    return flips;
  }
}

MovingTable _buildVertexMove() {
  final table = MovingTable.filled(PyraminxTables.nVertices, layerMoveCount);
  for (var value = 0; value < PyraminxTables.nVertices; value++) {
    for (var move = 0; move < layerMoveCount; move++) {
      final digits = <int>[];
      var rest = value;
      for (var i = 0; i < PyraminxCube.vertexCount; i++) {
        digits.add(rest % 3);
        rest ~/= 3;
      }
      digits[pyraminxMoves.axisOf(move)] =
          (digits[pyraminxMoves.axisOf(move)] + PyraminxCube.stepsOf(move)) % 3;

      var next = 0;
      for (var i = PyraminxCube.vertexCount - 1; i >= 0; i--) {
        next = next * 3 + digits[i];
      }
      table[(value, move)] = next;
    }
  }
  return table;
}

MovingTable _buildPermMove() {
  final table = MovingTable.filled(PyraminxTables.nEdgePerms, layerMoveCount);
  for (var value = 0; value < PyraminxTables.nEdgePerms; value++) {
    for (var move = 0; move < layerMoveCount; move++) {
      final cube = PyraminxCube();
      cube.edges.setAll(0, PyraminxTables.evenPermutations[value]);
      cube.applyMove(move);
      table[(value, move)] = PyraminxTables._permIndex[PyraminxTables._permKey(cube.edges)]!;
    }
  }
  return table;
}

MovingTable _buildFlipMove() {
  final table = MovingTable.filled(PyraminxTables.nEdgeFlips, layerMoveCount);
  for (var value = 0; value < PyraminxTables.nEdgeFlips; value++) {
    for (var move = 0; move < layerMoveCount; move++) {
      final cube = PyraminxCube();
      cube.flips.setAll(0, PyraminxTables._flipsFromIndex(value));
      cube.applyMove(move);
      table[(value, move)] = PyraminxTables._flipIndex(cube.flips);
    }
  }
  return table;
}
