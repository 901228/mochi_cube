import "../cube/algorithm.dart";

/// The Pyraminx.
///
/// A tetrahedron with four faces, numbered 0 to 3. Vertex `v` is where the
/// three faces other than `v` meet, so turning at `v` rotates those three and
/// leaves face `v` alone. Edge `{i, j}` is the edge those two faces share, and
/// the three edges in `v`'s layer are the ones whose faces are both something
/// other than `v`.
///
/// The pieces are four vertices that twist without ever moving, six edges that
/// permute and flip, and four tips. The tips are ignored here: each is one turn
/// on its own and would only multiply the state space by 81 without making the
/// puzzle any harder.
class PyraminxCube {
  /// How far each vertex is twisted, 0 to 2.
  final List<int> vertices;

  /// Which edge piece sits at each position.
  final List<int> edges;

  /// Whether the piece at each position is flipped.
  final List<int> flips;

  PyraminxCube()
    : vertices = List.filled(vertexCount, 0),
      edges = List.generate(edgeCount, (i) => i),
      flips = List.filled(edgeCount, 0);

  PyraminxCube.from(PyraminxCube other)
    : vertices = [...other.vertices],
      edges = [...other.edges],
      flips = [...other.flips];

  static const int vertexCount = 4;
  static const int edgeCount = 6;

  /// The two faces meeting at each edge, lowest first.
  static const List<List<int>> edgeFaces = [
    [0, 1],
    [0, 2],
    [0, 3],
    [1, 2],
    [1, 3],
    [2, 3],
  ];

  /// Turn the layer at [vertex] one step, or [times] steps.
  void turn(int vertex, [int times = 1]) {
    for (var t = 0; t < times; t++) {
      _turnOnce(vertex);
    }
  }

  void _turnOnce(int vertex) {
    final sigma = _faceCycle(vertex);

    final movedEdges = [...edges];
    final movedFlips = [...flips];
    for (var position = 0; position < edgeCount; position++) {
      final faces = edgeFaces[position];
      if (faces.contains(vertex)) {
        continue; // not in this layer
      }

      final a = sigma[faces[0]];
      final b = sigma[faces[1]];
      final destination = edgeIndexOf(a, b);

      // A piece's first sticker belongs to the lower face of its home. It is on
      // the position's lower face when unflipped, so follow where that goes.
      final carried = flips[position] == 0 ? a : b;
      movedEdges[destination] = edges[position];
      movedFlips[destination] = carried == (a < b ? a : b) ? 0 : 1;
    }
    edges.setAll(0, movedEdges);
    flips.setAll(0, movedFlips);

    vertices[vertex] = (vertices[vertex] + 1) % 3;
  }

  /// Apply an algorithm written in [pyraminxMoves].
  void apply(Algorithm algorithm) {
    for (final move in algorithm.moves) {
      applyMove(move);
    }
  }

  /// Apply one move index of [pyraminxMoves].
  ///
  /// Tip moves change nothing here: the tips are not part of the state.
  void applyMove(int move) {
    final axis = pyraminxMoves.axisOf(move);
    if (axis >= vertexCount) {
      return;
    }
    turn(axis, pyraminxMoves.amountOf(move) + 1);
  }

  bool get isSolved {
    for (var i = 0; i < vertexCount; i++) {
      if (vertices[i] != 0) return false;
    }
    for (var i = 0; i < edgeCount; i++) {
      if (edges[i] != i || flips[i] != 0) return false;
    }
    return true;
  }

  @override
  String toString() => "${vertices.join()}|${edges.join()}|${flips.join()}";

  /// The face permutation a turn at [vertex] applies: the other three, cycled.
  static List<int> _faceCycle(int vertex) {
    final others = [
      for (var face = 0; face < vertexCount; face++)
        if (face != vertex) face,
    ];
    final sigma = List.generate(vertexCount, (i) => i);
    sigma[others[0]] = others[1];
    sigma[others[1]] = others[2];
    sigma[others[2]] = others[0];
    return sigma;
  }

  /// Which edge two faces share.
  static int edgeIndexOf(int a, int b) {
    final low = a < b ? a : b;
    final high = a < b ? b : a;
    for (var i = 0; i < edgeCount; i++) {
      if (edgeFaces[i][0] == low && edgeFaces[i][1] == high) return i;
    }
    throw ArgumentError("Faces $a and $b do not share an edge");
  }
}

/// Pyraminx notation.
///
/// The four vertices in capitals and the four tips in lower case, each turned
/// one step or, with a prime, two. Tip moves are part of a scramble but not of
/// the puzzle's difficulty, so they appear here and are ignored by the solver.
const MoveSet pyraminxMoves = MoveSet(
  axes: ["U", "L", "R", "B", "u", "l", "r", "b"],
  amounts: ["", "'"],
);

/// The eight layer moves, the ones a solver cares about.
const int layerMoveCount = 8;

/// The eight tip moves.
const int tipMoveCount = 8;
