import "dart:math";

import "../cube/layout.dart";
import "cube.dart";
import "facelets.dart";

/// The net of a Pyraminx: 36 triangles, in the order `toFacelets()` gives them.
///
/// The standard unfolding, as csTimer and Twisty Timer draw it: one big triangle
/// of side two standing on its point, cut into four of side one. Each of those
/// is a face, cut again into the nine the puzzle has.
///
/// The vertices are numbered as `pyraminxMoves` names them: U, L, R, B. Held
/// with U up and B at the back, the front is the face without B, the bottom the
/// one without U, the left the one without R and the right the one without L.
/// So B is in the middle, U at the bottom, R top left and L top right. The
/// middle face lacks vertex B, which makes B the outer corner of the other
/// three, and U comes out at the top, where a turn of it is drawn.
final PuzzleLayout pyraminxLayout = _build();

/// The height of a triangle of side two, and so of the whole net.
final double _height = sqrt(3);

/// The face in the middle of the net, and so the vertex at its outer corners.
const int pyraminxMiddleFace = 3;

/// Where the three edge midpoints are: vertices U, L and R.
final Map<int, Point> _midpoints = {0: (1.0, 0.0), 1: (0.5, _height / 2), 2: (1.5, _height / 2)};

/// Where the middle face's vertex is on each other face, being the outer corner of that face.
final Map<int, Point> _outerCorners = {0: (1.0, _height), 1: (2.0, 0.0), 2: (0.0, 0.0)};

PuzzleLayout _build() => PuzzleLayout(
  width: 2,
  height: _height,
  stickers: [
    for (var face = 0; face < PyraminxCube.vertexCount; face++)
      ..._faceStickers([
        for (final vertex in cornersOfFace(face))
          vertex == pyraminxMiddleFace ? _outerCorners[face]! : _midpoints[vertex]!,
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
