import "dart:math";

import "../cube/layout.dart";
import "cube.dart";
import "facelets.dart";

/// The net of a Pyraminx: 36 triangles, in the order `toFacelets()` gives them.
///
/// The standard unfolding — one big triangle of side two cut into four of side
/// one, three of them the right way up and the middle one inverted. Each of
/// those is a face, cut again into the nine the puzzle has.
///
/// Which face lands where is not a choice. A tetrahedron's six net points are
/// its three edge midpoints, each shared by three faces, and three outer
/// corners which are all the same vertex seen three times; vertex `v` is on
/// every face but `v`, so the vertex the middle face does not have is the one
/// at the outside, and that pins all four faces down at once.
final PuzzleLayout pyraminxLayout = _build();

/// The height of a triangle of side two, and so of the whole net.
final double _height = sqrt(3);

/// Where the three edge midpoints are: vertices 1, 2 and 3.
final Map<int, Point> _midpoints = {1: (0.5, _height / 2), 2: (1.5, _height / 2), 3: (1.0, _height)};

/// Where vertex 0 is on each face, being the outer corner of that face.
///
/// Face 0 has no vertex 0, which is why it is the one in the middle.
final Map<int, Point> _outerCorners = {1: (2.0, _height), 2: (0.0, _height), 3: (1.0, 0.0)};

PuzzleLayout _build() => PuzzleLayout(
  width: 2,
  height: _height,
  stickers: [
    for (var face = 0; face < PyraminxCube.vertexCount; face++)
      ..._faceStickers([
        for (final vertex in cornersOfFace(face)) vertex == 0 ? _outerCorners[face]! : _midpoints[vertex]!,
      ]),
  ],
);

/// The nine triangles of one face, given its three corners.
///
/// The corners come in the order the tips are numbered, so the first is the one
/// slot 0 shows, the second slot 4 and the third slot 8. Rows of one, three and
/// five, each row alternating a triangle the right way up with an inverted one,
/// which is what puts the tips at 0, 4 and 8, the vertex pieces at 2, 5 and 7
/// and the edges at 1, 3 and 6.
List<List<Point>> _faceStickers(List<Point> corners) {
  final (ax, ay) = corners[0];
  final (bx, by) = corners[1];
  final (cx, cy) = corners[2];

  // The lattice of the face, three steps along each side.
  Point at(int i, int j) =>
      (ax + (bx - ax) * i / 3 + (cx - bx) * j / 3, ay + (by - ay) * i / 3 + (cy - by) * j / 3);

  return [
    for (var row = 0; row < 3; row++)
      for (var column = 0; column <= 2 * row; column++)
        if (column.isEven)
          [at(row, column ~/ 2), at(row + 1, column ~/ 2), at(row + 1, column ~/ 2 + 1)]
        else
          [at(row + 1, column ~/ 2 + 1), at(row, column ~/ 2 + 1), at(row, column ~/ 2)],
  ];
}
