import "cube.dart";
import "cubie.dart";
import "util.dart";

/// Where fto3phase's pieces sit among the 72 stickers, worked out from the
/// geometry in `cube.dart` and the names fto3phase gives its pieces.
///
/// fto3phase names everything by faces: an edge by the two it joins, a
/// triangle by its face and the face of the same half whose corner it sits
/// in, and a corner by two faces of the U, F, BR and BL half, whose order is
/// which way round the corner is. So the stickers of each piece follow from
/// where the faces are, and the test checks that turning the pieces and
/// turning the stickers agree.

const int _u = 0, _r = 1, _f = 2, _l = 3, _b = 4, _bl = 5, _d = 6, _br = 7;

/// The faces of each half, in the order fto3phase numbers their colours.
const List<int> ufbrblFaces = [_u, _f, _br, _bl];
const List<int> rlbdFaces = [_r, _l, _b, _d];

/// The faces fto3phase names each edge by.
const List<(int, int)> _edgeFaces = [
  (_u, _b), (_u, _r), (_u, _l), (_f, _l), (_f, _r), (_r, _br), //
  (_br, _b), (_bl, _b), (_l, _bl), (_d, _f), (_d, _br), (_d, _bl),
];

/// Each triangle position: its face, and the face of the same half whose
/// corner it sits in.
const List<(int, int)> _ufbrblTriangles = [
  (_u, _bl), (_u, _br), (_u, _f), (_f, _u), (_f, _br), (_f, _bl), //
  (_br, _u), (_br, _bl), (_br, _f), (_bl, _u), (_bl, _f), (_bl, _br),
];
const List<(int, int)> _rlbdTriangles = [
  (_r, _l), (_r, _b), (_r, _d), (_l, _b), (_l, _r), (_l, _d), //
  (_b, _r), (_b, _l), (_b, _d), (_d, _r), (_d, _l), (_d, _b),
];

typedef _Vertex = (int, int, int);

Set<_Vertex> _corners(int face) => ftoFaceCorners(face).toSet();

/// The one corner two faces of the same half share.
_Vertex _sharedCorner(int a, int b) => _corners(a).intersection(_corners(b)).single;

/// The triangle sticker of [face] in the corner [vertex].
int _triangleSlot(int face, _Vertex vertex) =>
    face * 9 + const [0, 5, 2][ftoFaceCorners(face).indexOf(vertex)];

/// The corner sticker of [face] in the corner [vertex].
int _cornerSlot(int face, _Vertex vertex) => face * 9 + const [1, 8, 4][ftoFaceCorners(face).indexOf(vertex)];

/// The edge sticker of [face] on the side it shares with [other].
int _edgeSlot(int face, int other) {
  final corners = ftoFaceCorners(face);
  final shared = _corners(face).intersection(_corners(other));
  final missing = [0, 1, 2].firstWhere((i) => !shared.contains(corners[i]));
  // The side opposite a triangle's first corner is slot 7, its second 3, its third 6.
  return face * 9 + const [7, 3, 6][missing];
}

/// The face that comes next round [vertex] after [face], clockwise as seen
/// from outside: -90 degrees about the corner, which takes `n` to
/// `v (v . n) - v x n`.
int _nextRound(_Vertex vertex, int face) {
  final (vx, vy, vz) = vertex;
  final (nx, ny, nz) = ftoFaceNormal[face];
  final dot = vx * nx + vy * ny + vz * nz;
  final turned = (
    vx * dot - (vy * nz - vz * ny),
    vy * dot - (vz * nx - vx * nz),
    vz * dot - (vx * ny - vy * nx),
  );
  return ftoFaceNormal.indexOf(turned);
}

/// The two U, F, BR and BL faces round each corner, the first being the side
/// fto3phase's orientation counts from.
final List<(int, int)> _cornerSides = [
  for (var corner = 0; corner < 6; corner++)
    () {
      final row = [for (var color = 0; color < 4; color++) FtoCubie.cornerTripleColorLookup[color][corner]];
      return (ufbrblFaces[row.indexOf(0)], ufbrblFaces[row.indexOf(1)]);
    }(),
];

/// Each corner's four faces going round it clockwise from its first side.
final List<List<int>> cornerFaces = [
  for (final (a0, a1) in _cornerSides)
    () {
      final vertex = _sharedCorner(a0, a1);
      return [a0, _nextRound(vertex, a0), a1, _nextRound(vertex, a1)];
    }(),
];

/// The stickers of each corner position, in the order of [cornerFaces].
final List<List<int>> cornerFacelets = [
  for (var corner = 0; corner < 6; corner++)
    [
      for (final face in cornerFaces[corner])
        _cornerSlot(face, _sharedCorner(_cornerSides[corner].$1, _cornerSides[corner].$2)),
    ],
];

/// The stickers of each edge position: on its face of the U, F, BR and BL
/// half first.
final List<(int, int)> edgeFacelets = [
  for (final (x, y) in _edgeFaces)
    () {
      final (a, b) = ufbrblFaces.contains(x) ? (x, y) : (y, x);
      return (_edgeSlot(a, b), _edgeSlot(b, a));
    }(),
];

/// The faces of each edge, its U, F, BR and BL one first.
final List<(int, int)> edgeColours = [
  for (final (x, y) in _edgeFaces) ufbrblFaces.contains(x) ? (x, y) : (y, x),
];

final List<int> ufbrblTriangleFacelets = [
  for (final (face, other) in _ufbrblTriangles) _triangleSlot(face, _sharedCorner(face, other)),
];
final List<int> rlbdTriangleFacelets = [
  for (final (face, other) in _rlbdTriangles) _triangleSlot(face, _sharedCorner(face, other)),
];

extension FtoCubieFacelets on FtoCubie {
  /// The 72 stickers of this state, as faces.
  List<int> toFacelets() {
    final f = List.filled(nFtoFacelets, -1);
    for (var pos = 0; pos < 6; pos++) {
      for (var i = 0; i < 4; i++) {
        f[cornerFacelets[pos][i]] = cornerFaces[cornerPerm[pos]][(i + 2 * cornerOri[pos]) % 4];
      }
    }
    for (var pos = 0; pos < 12; pos++) {
      final (sa, sb) = edgeFacelets[pos];
      final (ca, cb) = edgeColours[edges[pos]];
      f[sa] = ca;
      f[sb] = cb;
      f[ufbrblTriangleFacelets[pos]] = ufbrblFaces[trianglesUFBrBl[pos]];
      f[rlbdTriangleFacelets[pos]] = rlbdFaces[trianglesRLBD[pos]];
    }
    return f;
  }
}

/// Read a state from its 72 stickers, as faces.
///
/// Throws [FormatException] unless they are the stickers of a state the
/// puzzle can reach by turning.
FtoCubie ftoCubieFromFacelets(List<int> f) {
  final cubie = FtoCubie();
  for (var pos = 0; pos < 6; pos++) {
    final colours = [for (final s in cornerFacelets[pos]) f[s]];
    var found = false;
    for (var piece = 0; piece < 6 && !found; piece++) {
      for (var ori = 0; ori < 2; ori++) {
        if ([for (var i = 0; i < 4; i++) cornerFaces[piece][(i + 2 * ori) % 4]].join() == colours.join()) {
          cubie.cornerPerm[pos] = piece;
          cubie.cornerOri[pos] = ori;
          found = true;
          break;
        }
      }
    }
    if (!found) throw FormatException("Corner $pos shows colours no corner has");
  }
  for (var pos = 0; pos < 12; pos++) {
    final (sa, sb) = edgeFacelets[pos];
    final piece = edgeColours.indexOf((f[sa], f[sb]));
    if (piece < 0) throw FormatException("Edge $pos shows colours no edge has");
    cubie.edges[pos] = piece;
    cubie.trianglesUFBrBl[pos] = ufbrblFaces.indexOf(f[ufbrblTriangleFacelets[pos]]);
    cubie.trianglesRLBD[pos] = rlbdFaces.indexOf(f[rlbdTriangleFacelets[pos]]);
    if (cubie.trianglesUFBrBl[pos] < 0 || cubie.trianglesRLBD[pos] < 0) {
      throw FormatException("A triangle is on the wrong half of the puzzle");
    }
  }

  if (cubie.cornerPerm.toSet().length != 6 || cubie.edges.toSet().length != 12) {
    throw const FormatException("A piece appears twice");
  }
  for (final orbit in [cubie.trianglesUFBrBl, cubie.trianglesRLBD]) {
    for (var colour = 0; colour < 4; colour++) {
      if (orbit.where((c) => c == colour).length != 3) {
        throw const FormatException("The triangles are not three of each colour");
      }
    }
  }
  if (isParity(cubie.edges) || isParity(cubie.cornerPerm)) {
    throw const FormatException("Two pieces are swapped, which no turn does");
  }
  if (cubie.cornerOri.fold<int>(0, (a, b) => a + b).isOdd) {
    throw const FormatException("A corner is turned on its own");
  }
  return cubie;
}

/// Read an FTO written as [Fto.toFaceletString] writes it: 72 of
/// [ftoFaceLetters], faces in the order of [ftoFaceNames].
///
/// Throws [FormatException] unless it is nine of each letter making up a
/// state the puzzle can reach by turning. The letters are fixed: nothing on an
/// FTO stays put to say which colour is which face.
Fto ftoFromFaceletString(String facelets) {
  final cleaned = facelets.replaceAll(RegExp(r"\s"), "");
  if (cleaned.length != nFtoFacelets) {
    throw FormatException("Expected $nFtoFacelets facelets, got ${cleaned.length}");
  }
  final faces = [for (final letter in cleaned.split("")) ftoFaceLetters.indexOf(letter)];
  if (faces.contains(-1)) {
    throw FormatException("An FTO's stickers are written in the letters $ftoFaceLetters");
  }
  for (var face = 0; face < 8; face++) {
    final count = faces.where((f) => f == face).length;
    if (count != 9) throw FormatException("${ftoFaceLetters[face]} appears $count times, not nine");
  }
  final cubie = ftoCubieFromFacelets(faces);
  if (cubie.toFacelets().join(",") != faces.join(",")) {
    throw const FormatException("The stickers are not those of an FTO");
  }
  return Fto.fromFacelets(faces);
}
