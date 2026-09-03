import "cube.dart";

/// The 36 stickers of a Pyraminx, indexed `face * 9 + slot`.
///
/// Each of the four faces is a triangle cut into nine smaller ones, in rows of
/// one, three and five:
///
/// ```
///           0
///        1  2  3
///     4  5  6  7  8
/// ```
///
/// The three corners of the face are the tips, the inverted triangle beside
/// each corner is that corner's vertex piece, and the middle of each side is an
/// edge. So slots 0, 4 and 8 are tips, 2, 5 and 7 are vertex pieces, and 1, 3
/// and 6 are edges — which is the same three-of-each on every face, and adds up
/// to the puzzle's four tips, four vertices and six edges.
const int nPyraminxFacelets = 36;

/// Slots showing a tip, and which corner of the face each belongs to.
const List<int> tipSlots = [0, 4, 8];

/// Slots showing a vertex piece, in the same corner order as [tipSlots].
const List<int> vertexSlots = [2, 5, 7];

/// Slots showing an edge: the middle of each side.
///
/// In corner order they join corners 0 and 1, 0 and 2, then 1 and 2.
const List<int> edgeSlots = [1, 3, 6];

/// The three corners of a face, as vertices, in the order the slots use.
///
/// A face contains every vertex but its own, since vertex `v` is where the
/// faces other than `v` meet.
List<int> cornersOfFace(int face) => [
  for (var vertex = 0; vertex < PyraminxCube.vertexCount; vertex++)
    if (vertex != face) vertex,
];

/// The edge lying between two corners of a face.
///
/// An edge joins two vertices and lies on the two faces that are neither of
/// them, so the edge between vertices `a` and `b` is the one shared by the
/// remaining pair.
int edgeBetween(int cornerA, int cornerB) {
  final rest = [
    for (var face = 0; face < PyraminxCube.vertexCount; face++)
      if (face != cornerA && face != cornerB) face,
  ];
  return PyraminxCube.edgeIndexOf(rest[0], rest[1]);
}

extension PyraminxFacelets on PyraminxCube {
  /// The 36 stickers of this puzzle, as face indices.
  List<int> toFacelets() {
    final facelets = List.filled(nPyraminxFacelets, 0);

    for (var face = 0; face < PyraminxCube.vertexCount; face++) {
      final corners = cornersOfFace(face);

      for (var i = 0; i < corners.length; i++) {
        final vertex = corners[i];
        facelets[face * 9 + tipSlots[i]] = _twisted(face, vertex, tips[vertex]);
        facelets[face * 9 + vertexSlots[i]] = _twisted(face, vertex, vertices[vertex]);
      }

      // The three edges of a face, between each pair of its corners.
      const pairs = [
        [0, 1],
        [0, 2],
        [1, 2],
      ];
      for (var i = 0; i < pairs.length; i++) {
        final position = edgeBetween(corners[pairs[i][0]], corners[pairs[i][1]]);
        facelets[face * 9 + edgeSlots[i]] = _edgeColour(position, face);
      }
    }

    return facelets;
  }

  /// The 36 stickers as a string of face letters, `A` to `D`.
  String toFaceletString() =>
      toFacelets().map((face) => pyraminxFaceNames[face]).join();

  /// The colour a piece at vertex [vertex] shows on [face] when twisted [amount].
  ///
  /// A turn moves a sticker from face `x` to `faceCycle(v)[x]`, so the one
  /// showing on `face` now started [amount] steps back.
  int _twisted(int face, int vertex, int amount) {
    final sigma = PyraminxCube.faceCycle(vertex);
    var colour = face;
    // Walk the cycle backwards by following it forward twice per step, since it
    // has order three.
    for (var i = 0; i < amount; i++) {
      colour = sigma.indexOf(colour);
    }
    return colour;
  }

  /// The colour the edge at [position] shows on [face].
  int _edgeColour(int position, int face) {
    final here = PyraminxCube.edgeFaces[position];
    final home = PyraminxCube.edgeFaces[edges[position]];

    // Unflipped, the piece's first sticker sits on the lower face of where it
    // is; flipped, on the higher one.
    final onLowerFace = flips[position] == 0 ? home[0] : home[1];
    final onHigherFace = flips[position] == 0 ? home[1] : home[0];
    return face == here[0] ? onLowerFace : onHigherFace;
  }
}

/// What the four faces are called in a sticker string.
const List<String> pyraminxFaceNames = ["A", "B", "C", "D"];

/// Reading a Pyraminx from its stickers.
abstract final class PyraminxFacelet {
  /// Parse a 36 character sticker string.
  ///
  /// A Pyraminx has no centres, so nothing announces which colour is which
  /// face. The vertex pieces settle it: one never leaves its corner, and vertex
  /// `v` touches every face but `v`, so whichever colour is missing from a
  /// vertex piece's three stickers is the colour of the face it does not touch.
  /// Any four distinct letters therefore work.
  ///
  /// Throws [FormatException] if the string is not 36 stickers of four colours,
  /// nine each, arranged as a Pyraminx.
  static PyraminxCube fromFaceletString(String facelets) {
    final cleaned = facelets.replaceAll(RegExp(r"\s"), "");
    if (cleaned.length != nPyraminxFacelets) {
      throw FormatException("Expected $nPyraminxFacelets facelets, got ${cleaned.length}");
    }

    final colours = cleaned.split("");
    final distinct = colours.toSet().toList();
    if (distinct.length != PyraminxCube.vertexCount) {
      throw FormatException("Expected four colours, got ${distinct.length}: $distinct");
    }
    for (final colour in distinct) {
      final count = colours.where((c) => c == colour).length;
      if (count != 9) {
        throw FormatException("Colour '$colour' appears $count times, not nine");
      }
    }

    // A vertex piece never moves, and touches every face but its own, so the
    // colour it never shows is the one on the face it is not part of.
    final face = <String, int>{};
    for (var vertex = 0; vertex < PyraminxCube.vertexCount; vertex++) {
      final shown = <String>{};
      for (var f = 0; f < PyraminxCube.vertexCount; f++) {
        if (f == vertex) continue;
        shown.add(colours[f * 9 + vertexSlots[cornersOfFace(f).indexOf(vertex)]]);
      }
      final missing = distinct.where((c) => !shown.contains(c)).toList();
      if (missing.length != 1) {
        throw FormatException("Vertex $vertex shows ${shown.length} colours, not three");
      }
      face[missing.single] = vertex;
    }
    if (face.length != PyraminxCube.vertexCount) {
      throw FormatException("The vertex pieces do not name four different faces");
    }

    int colourAt(int slot) => face[colours[slot]]!;
    final cube = PyraminxCube();

    for (var vertex = 0; vertex < PyraminxCube.vertexCount; vertex++) {
      cube.vertices[vertex] = _twistOf(vertex, colourAt, vertexSlots);
      cube.tips[vertex] = _twistOf(vertex, colourAt, tipSlots);
    }

    for (var position = 0; position < PyraminxCube.edgeCount; position++) {
      final here = PyraminxCube.edgeFaces[position];
      final slot = _edgeSlotOn(here[0], position);
      final onLower = colourAt(here[0] * 9 + slot);
      final onHigher = colourAt(here[1] * 9 + _edgeSlotOn(here[1], position));

      if (onLower == onHigher) {
        throw FormatException("Edge $position shows one colour twice");
      }
      cube.edges[position] = PyraminxCube.edgeIndexOf(onLower, onHigher);
      cube.flips[position] = onLower < onHigher ? 0 : 1;
    }

    if (cube.edges.toSet().length != PyraminxCube.edgeCount) {
      throw FormatException("The same edge appears twice");
    }

    return cube;
  }

  /// How far the piece at [vertex] is twisted, read off [slots].
  ///
  /// Any face the vertex touches will do: walk the cycle back from that face
  /// until it reaches the colour showing there, and count the steps.
  static int _twistOf(int vertex, int Function(int) colourAt, List<int> slots) {
    final face = [
      for (var f = 0; f < PyraminxCube.vertexCount; f++)
        if (f != vertex) f,
    ].first;
    final target = colourAt(face * 9 + slots[cornersOfFace(face).indexOf(vertex)]);

    final sigma = PyraminxCube.faceCycle(vertex);
    var walked = face;
    for (var amount = 0; amount < 3; amount++) {
      if (walked == target) {
        return amount;
      }
      walked = sigma.indexOf(walked);
    }
    throw FormatException("Vertex $vertex shows a colour it cannot");
  }

  /// Which slot of [face] shows the edge at [position].
  static int _edgeSlotOn(int face, int position) {
    final corners = cornersOfFace(face);
    const pairs = [
      [0, 1],
      [0, 2],
      [1, 2],
    ];
    for (var i = 0; i < pairs.length; i++) {
      if (edgeBetween(corners[pairs[i][0]], corners[pairs[i][1]]) == position) {
        return edgeSlots[i];
      }
    }
    throw ArgumentError("Edge $position is not on face $face");
  }
}
