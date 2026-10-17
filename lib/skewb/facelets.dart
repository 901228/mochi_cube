import "coordinates.dart";
import "cube.dart";

/// Reading a Skewb from its stickers.
abstract final class SkewbFacelet {
  /// Parse a 30 character sticker string, faces in the order U, R, F, D, L, B.
  ///
  /// The centres move, so they cannot say which colour is which face. The
  /// up-front-right corner does instead: it never moves, so its three stickers
  /// are the U, R and F colours by definition. No corner carries two opposite
  /// colours, so each of the other three is opposite whichever of those it
  /// never shares a corner with. Any six distinct letters therefore work.
  ///
  /// Throws [FormatException] if the string is not 30 stickers of six colours,
  /// five each, making up a Skewb that can be reached by turning.
  static SkewbCube fromFaceletString(String facelets) {
    final cleaned = facelets.replaceAll(RegExp(r"\s"), "");
    if (cleaned.length != nSkewbFacelets) {
      throw FormatException("Expected $nSkewbFacelets facelets, got ${cleaned.length}");
    }

    final colours = cleaned.split("");
    final distinct = colours.toSet().toList();
    if (distinct.length != 6) {
      throw FormatException("Expected six colours, got ${distinct.length}: $distinct");
    }
    for (final colour in distinct) {
      final count = colours.where((c) => c == colour).length;
      if (count != 5) {
        throw FormatException("Colour '$colour' appears $count times, not five");
      }
    }

    // The stickers of each corner, and which colours ever share one.
    final corners = <(int, int, int), List<String>>{};
    for (var i = 0; i < nSkewbFacelets; i++) {
      final corner = skewbCornerOf(i);
      if (corner != null) (corners[corner] ??= []).add(colours[i]);
    }
    bool together(String a, String b) => corners.values.any((c) => c.contains(a) && c.contains(b));

    // U, R and F from the corner that never moves; D, L and B opposite them.
    final face = <String, int>{};
    for (final facelet in SkewbCube.fixedCornerFacelets) {
      final index = facelet ~/ 5;
      final opposite = index + 3;
      final colour = colours[facelet];
      final across = distinct.where((c) => c != colour && !together(c, colour)).toList();
      if (across.length != 1) {
        throw FormatException("Colour '$colour' has ${across.length} opposites, not one");
      }
      face[colour] = index;
      face[across.single] = opposite;
    }
    if (face.length != 6) {
      throw FormatException("The fixed corner does not name three different faces");
    }

    final state = [for (final colour in colours) face[colour]!];
    if (SkewbPart.corners.indexOf(state) == null) {
      throw FormatException("The corners cannot be reached by turning");
    }
    if (SkewbPart.centres.indexOf(state) == null) {
      throw FormatException("The centres cannot be reached by turning");
    }
    return SkewbCube.fromFacelets(state);
  }
}
