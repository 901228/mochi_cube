import "../cube/algorithm.dart";

/// What the six faces are called in a sticker string.
const List<String> nxnFaceNames = ["U", "R", "F", "D", "L", "B"];

/// An `n` by `n` by `n` cube, held as its stickers.
///
/// Faces are in the usual U, R, F, D, L, B order and each face's `n * n`
/// stickers in reading order, as the 3x3x3's facelets are, so facelet
/// `face * n * n + row * n + column` is the one [cubeNetLayout] draws in that
/// row and column of that face.
///
/// As with the Skewb, each turn is a permutation of the stickers worked out
/// from where they are in space, so nothing about the turns is written by
/// hand. Nothing is solved here either: the cubes from 5x5x5 up are scrambled
/// by random turns, which needs the turns and nothing else.
class NxNCube {
  /// How many stickers along a side.
  final int size;

  /// The stickers, as face indices.
  final List<int> facelets;

  NxNCube(this.size) : facelets = [for (var i = 0; i < 6 * size * size; i++) i ~/ (size * size)];

  NxNCube.from(NxNCube other) : size = other.size, facelets = [...other.facelets];

  /// A cube showing [facelets], which are taken as they are.
  NxNCube.fromFacelets(this.size, List<int> facelets) : facelets = [...facelets];

  /// For each size, where every sticker goes under a clockwise quarter turn of
  /// each face to each width: `[face * size + width - 1]`.
  static final Map<int, List<List<int>>> _turns = {};

  /// Turn [width] layers of [face] clockwise, as seen from outside that face,
  /// [quarters] quarter turns.
  ///
  /// A width of [size] turns the whole cube, which is a rotation; the notation
  /// has no name for it, but the tests use it.
  void turn(int face, int width, [int quarters = 1]) {
    final to = (_turns[size] ??= _buildTurns(size))[face * size + width - 1];
    for (var t = 0; t < quarters % 4; t++) {
      final moved = List<int>.filled(facelets.length, 0);
      for (var i = 0; i < facelets.length; i++) {
        moved[to[i]] = facelets[i];
      }
      facelets.setAll(0, moved);
    }
  }

  /// Apply one move index of [nxnMoves].
  void applyMove(int move) {
    final moves = nxnMoves(size);
    final axis = moves.axisOf(move);
    turn(axis % 6, axis ~/ 6 + 1, moves.amountOf(move) + 1);
  }

  /// Apply an algorithm written in [nxnMoves].
  void apply(Algorithm algorithm) {
    for (final move in algorithm.moves) {
      applyMove(move);
    }
  }

  /// Whether every face shows one colour, its own.
  bool get isSolved {
    final perFace = size * size;
    for (var i = 0; i < facelets.length; i++) {
      if (facelets[i] != i ~/ perFace) return false;
    }
    return true;
  }

  /// The stickers, as face indices.
  List<int> toFacelets() => [...facelets];

  /// The stickers as a string of face letters, `URFDLB`.
  String toFaceletString() => facelets.map((face) => nxnFaceNames[face]).join();

  @override
  String toString() => toFaceletString();

  /// Parse a sticker string of a cube of [size], faces in the order U, R, F,
  /// D, L, B.
  ///
  /// An odd cube's centres never leave their faces, so they name the colours
  /// and any six distinct letters work. An even cube has no such piece, so its
  /// letters must be the face names themselves.
  ///
  /// Throws [FormatException] if the string is not `6 * size * size` stickers
  /// of six colours, `size * size` each.
  // shortcut: whether the stickers can be reached by turning is not checked,
  // since nothing here solves these cubes and drawing one does not need it.
  // Check it, piece by piece, if a solver is ever added.
  static NxNCube fromFaceletString(int size, String facelets) {
    final cleaned = facelets.replaceAll(RegExp(r"\s"), "");
    final perFace = size * size;
    if (cleaned.length != 6 * perFace) {
      throw FormatException("Expected ${6 * perFace} facelets, got ${cleaned.length}");
    }
    final colours = cleaned.split("");
    final distinct = colours.toSet();
    if (distinct.length != 6) {
      throw FormatException("Expected six colours, got ${distinct.length}: $distinct");
    }
    for (final colour in distinct) {
      final count = colours.where((c) => c == colour).length;
      if (count != perFace) {
        throw FormatException("Colour '$colour' appears $count times, not $perFace");
      }
    }

    final face = <String, int>{};
    if (size.isOdd) {
      for (var f = 0; f < 6; f++) {
        face[colours[f * perFace + perFace ~/ 2]] = f;
      }
      if (face.length != 6) {
        throw FormatException("Two centres show the same colour");
      }
    } else {
      for (var f = 0; f < 6; f++) {
        face[nxnFaceNames[f]] = f;
      }
      if (!distinct.every(face.containsKey)) {
        throw FormatException("An even cube's stickers must be written in the letters URFDLB");
      }
    }
    return NxNCube.fromFacelets(size, [for (final colour in colours) face[colour]!]);
  }
}

/// The notation of a cube of [size], WCA regulation 12a: the faces turned one
/// layer deep, `Rw` two layers, `3Rw` three and so on up to half the cube, each
/// clockwise, twice or anticlockwise.
///
/// A move is `axis * 3 + amount` with the axes listed one width at a time, so
/// the first eighteen are the 3x3x3's own and a 3x3x3's [MoveSet] is the one
/// this gives for sizes 2 and 3.
MoveSet nxnMoves(int size) => _moveSets[size] ??= MoveSet(
  axes: [
    for (var width = 1; width <= size ~/ 2 || width == 1; width++)
      for (final face in nxnFaceNames)
        switch (width) {
          1 => face,
          2 => "${face}w",
          _ => "$width${face}w",
        },
  ],
  amounts: const ["", "2", "'"],
);

final Map<int, MoveSet> _moveSets = {};

/// Where sticker [facelet] of a cube of [size] is in space, on a cube from
/// `-size` to `size`.
///
/// x runs right, y up and z to the front, and each face is laid out the way the
/// 3x3x3 net draws it, so `right` and `down` are the directions its rows and
/// columns run in. Sticker centres are two apart.
(int, int, int) nxnFaceletPosition(int size, int facelet) {
  const right = [(1, 0, 0), (0, 0, -1), (1, 0, 0), (1, 0, 0), (0, 0, 1), (-1, 0, 0)];
  const down = [(0, 0, 1), (0, -1, 0), (0, -1, 0), (0, 0, -1), (0, -1, 0), (0, -1, 0)];

  final face = facelet ~/ (size * size);
  final tile = facelet % (size * size);
  final across = 2 * (tile % size) - (size - 1);
  final along = 2 * (tile ~/ size) - (size - 1);
  final (nx, ny, nz) = _normal[face];
  final (rx, ry, rz) = right[face];
  final (dx, dy, dz) = down[face];
  return (
    size * nx + across * rx + along * dx,
    size * ny + across * ry + along * dy,
    size * nz + across * rz + along * dz,
  );
}

/// Which way each face looks, as x, y and z.
const List<(int, int, int)> _normal = [(0, 1, 0), (1, 0, 0), (0, 0, 1), (0, -1, 0), (-1, 0, 0), (0, 0, -1)];

/// Every clockwise quarter turn of a cube of [size], by face and width.
///
/// A sticker is in the turning layers when it is far enough along the face's
/// normal: the face itself is at `size`, and the side stickers of the k-th
/// layer in at `size - 1 - 2k`. Clockwise seen from outside is -90 degrees
/// about the normal `u`, which takes `p` to `u (u . p) - u x p`.
List<List<int>> _buildTurns(int size) {
  final positions = [for (var i = 0; i < 6 * size * size; i++) nxnFaceletPosition(size, i)];
  final index = {for (var i = 0; i < positions.length; i++) positions[i]: i};

  return [
    for (var face = 0; face < 6; face++)
      for (var width = 1; width <= size; width++)
        [
          for (final p in positions)
            () {
              final (ux, uy, uz) = _normal[face];
              final (x, y, z) = p;
              final dot = ux * x + uy * y + uz * z;
              if (width < size && dot < size + 1 - 2 * width) return index[p]!;
              final turned = (
                ux * dot - (uy * z - uz * y),
                uy * dot - (uz * x - ux * z),
                uz * dot - (ux * y - uy * x),
              );
              return index[turned] ?? (throw StateError("A turn of face $face leaves the cube at $turned"));
            }(),
        ],
  ];
}
