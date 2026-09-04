import "../clock.dart";
import "../mochi_cube.dart";
import "../pocket.dart" show nPocketFacelets;
import "../pyraminx.dart";

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
