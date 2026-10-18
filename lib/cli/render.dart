import "../clock.dart";
import "../mochi_cube.dart";
import "../pocket.dart" show nPocketFacelets;
import "../pyraminx.dart";
import "../skewb.dart" show nSkewbFacelets;
import "../square1.dart" show Square1Cube, square1Layout;

/// Drawing a puzzle in a terminal.
///
/// The same job the layouts in `cube/layout.dart` do for a front end, done with
/// characters instead of polygons: enough to see at a glance that a scramble
/// and a state agree, and not meant to be more than that.
/// How wide one Pyraminx face is drawn: five stickers spaced out, and a margin
/// either side so two faces do not run together.
const int _pyraminxFaceWidth = 11;

abstract final class Ascii {
  /// A cube's net, one letter per sticker.
  ///
  /// Laid out from [cubeNetPosition], so it is the same net the drawing
  /// geometry uses and changing one moves the other.
  static String cubeNet(String facelets) {
    final n = switch (facelets.length) {
      54 => 3,
      nPocketFacelets => 2,
      _ => throw FormatException("Not a cube's stickers: ${facelets.length} of them"),
    };

    final grid = [for (var row = 0; row < 3 * n; row++) List.filled(4 * n, " ")];
    for (var facelet = 0; facelet < facelets.length; facelet++) {
      final (column, row) = cubeNetPosition[facelet ~/ (n * n)];
      final tile = facelet % (n * n);
      grid[row * n + tile ~/ n][column * n + tile % n] = facelets[facelet];
    }

    return grid.map((row) => row.join(" ").trimRight()).join("\n");
  }

  /// A Skewb's net: the 3x3x3's, with the edge tiles left blank.
  ///
  /// The Skewb's slots are the 3x3x3's tiles 0, 2, 4, 6 and 8, so each letter
  /// lands where that tile would and the faces show their X.
  static String skewbNet(String facelets) {
    if (facelets.length != nSkewbFacelets) {
      throw FormatException("Not a Skewb's stickers: ${facelets.length} of them");
    }
    return cubeNet(
      [for (var i = 0; i < 54; i++) i % 9 % 2 == 0 ? facelets[i ~/ 9 * 5 + i % 9 ~/ 2] : " "].join(),
    );
  }

  /// A Pyraminx's four faces, each as a triangle of nine letters.
  ///
  /// Not a net. Folding four triangles into one on a character grid costs more
  /// than it is worth here, so the faces are drawn side by side and named.
  static String pyraminxFaces(String facelets) {
    if (facelets.length != nPyraminxFacelets) {
      throw FormatException("Not a Pyraminx's stickers: ${facelets.length} of them");
    }

    // Rows of one, three and five, spaced out and each centred under the one
    // above, so the bottom row is the nine characters a face is wide.
    String centred(String line) =>
        line.padLeft((_pyraminxFaceWidth + line.length) ~/ 2).padRight(_pyraminxFaceWidth);
    final blocks = [
      for (var face = 0; face < pyraminxFaceNames.length; face++)
        [
          centred("face ${pyraminxFaceNames[face]}"),
          for (var row = 0; row < 3; row++)
            // Row `r` starts at slot `r * r` and holds `2 * r + 1` stickers.
            centred(
              [
                for (var column = 0; column <= 2 * row; column++) facelets[face * 9 + row * row + column],
              ].join(" "),
            ),
        ],
    ];

    return [
      for (var line = 0; line < blocks.first.length; line++)
        blocks.map((block) => block[line]).join(" ").trimRight(),
    ].join("\n");
  }

  /// A Square-1's two layers, each read round from the back, and its middle.
  ///
  /// A piece is its top or bottom face and then its sides, in face letters, so
  /// a corner reads `UBL` and an edge `UB`; `|` is the cut `/` turns along.
  static String square1Layers(Square1Cube cube) {
    const names = ["U", "R", "F", "D", "L", "B"];
    String layer(int first) {
      final out = StringBuffer();
      for (var slot = first; slot < first + 12; slot++) {
        final piece = cube.pieces[slot];
        final faces = square1Layout.pieceFaces[piece];
        final previous = slot == first ? first + 11 : slot - 1;
        final secondHalf = faces.length == 3 && cube.pieces[previous] == piece;
        out.write(secondHalf ? names[faces[2]] : names[faces[0]] + names[faces[1]]);
        if (slot == first + 11) break;
        final next = cube.pieces[slot + 1];
        out.write(slot == first + 5 ? " | " : (next == piece ? "" : " "));
      }
      return out.toString();
    }

    return [
      "top     ${layer(0)}",
      "middle  ${cube.middle == 0 ? "square" : "turned over"}",
      "bottom  ${layer(12)}",
    ].join("\n");
  }

  /// A clock's eighteen dials, as two grids of hours.
  static String clockDials(ClockState state) {
    final shown = state.toDials();
    String side(int from) => [
      for (var row = 0; row < 3; row++)
        [
          for (var column = 0; column < 3; column++) shown[from + row * 3 + column].toString().padLeft(2),
        ].join(" "),
    ].join("\n");

    final front = side(0).split("\n");
    final back = side(9).split("\n");
    return [
      "  front       back",
      for (var row = 0; row < 3; row++) "${front[row]}   ${back[row]}",
    ].join("\n");
  }
}
