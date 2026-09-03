import "../cube/enums.dart";
import "../puzzle/cube/cubie_cube.dart";
import "coordinates.dart";

/// The 24 stickers of a 2x2x2, indexed `face * 4 + tile`.
///
/// Faces are in the usual U, R, F, D, L, B order and tiles in reading order,
/// so these are the 3x3x3's corner stickers with the edges and centres left
/// out.
const int nPocketFacelets = 24;

/// The three stickers of each corner position, as 2x2x2 indices.
///
/// Derived from the 3x3x3 table rather than written out again, so the two
/// cannot disagree about where a corner is.
final List<List<int>> pocketCornerFacelet = [
  for (final corner in cornerFacelet) [for (final facelet in corner) _fromCubeFacelet(facelet.index)],
];

int _fromCubeFacelet(int index) {
  const tiles = {0: 0, 2: 1, 6: 2, 8: 3};
  final tile = tiles[index % 9];
  if (tile == null) {
    throw StateError("Facelet $index is not a corner sticker");
  }
  return (index ~/ 9) * 4 + tile;
}

extension PocketFacelets on CubieCube {
  /// The 24 stickers of this cube as a 2x2x2, as face indices.
  List<int> toPocketFacelets() {
    final facelets = List.filled(nPocketFacelets, 0);
    for (var i = 0; i < CubieCube.cornerLength; i++) {
      final piece = cornerState[i] & 0x7;
      final ori = (cornerState[i] >> 3) % 3;
      for (var k = 0; k < 3; k++) {
        facelets[pocketCornerFacelet[i][(k + ori) % 3]] = cornerFace[piece][k].index;
      }
    }
    return facelets;
  }

  /// The 24 stickers as a string of face letters.
  String toPocketFaceletString() =>
      toPocketFacelets().map((f) => FaceExtension.faceToString[f]).join();
}

/// Reading a 2x2x2 from its stickers.
abstract final class PocketCube {
  /// Parse a 24 character sticker string.
  ///
  /// A 2x2x2 has no centres, so unlike the 3x3x3 nothing announces which colour
  /// is which face. Two facts settle it. The corner held still names three of
  /// them — its stickers are the D, B and L faces by definition. And no corner
  /// ever carries two opposite colours, so each remaining colour is opposite
  /// whichever of those three it never shares a corner with.
  ///
  /// Any six distinct letters therefore work, in any colour scheme, with no
  /// need to say which is which.
  ///
  /// Throws [FormatException] if the string is not 24 stickers of six colours,
  /// four each, arranged as a cube. A string that describes a real cube in an
  /// unsolvable state cannot occur: every arrangement of the 2x2x2's corners
  /// that this accepts is reachable.
  static CubieCube fromFaceletString(String facelets) {
    final cleaned = facelets.replaceAll(RegExp(r"\s"), "");
    if (cleaned.length != nPocketFacelets) {
      throw FormatException("Expected $nPocketFacelets facelets, got ${cleaned.length}");
    }

    final colours = cleaned.split("");
    final distinct = colours.toSet().toList();
    if (distinct.length != 6) {
      throw FormatException("Expected six colours, got ${distinct.length}: $distinct");
    }
    for (final colour in distinct) {
      final count = colours.where((c) => c == colour).length;
      if (count != 4) {
        throw FormatException("Colour '$colour' appears $count times, not four");
      }
    }

    // Which colours never share a corner: opposite faces.
    final together = {for (final colour in distinct) colour: <String>{}};
    for (final corner in pocketCornerFacelet) {
      final trio = [for (final index in corner) colours[index]];
      if (trio.toSet().length != 3) {
        throw FormatException("A corner carries a colour twice: $trio");
      }
      for (final a in trio) {
        together[a]!.addAll(trio.where((b) => b != a));
      }
    }

    final opposite = <String, String>{};
    for (final colour in distinct) {
      final apart = distinct.where((c) => c != colour && !together[colour]!.contains(c)).toList();
      if (apart.length != 1) {
        throw FormatException("Colour '$colour' has ${apart.length} opposites, not one");
      }
      opposite[colour] = apart.single;
    }

    // The corner held still is D, B and L by definition; the rest follow.
    final held = pocketCornerFacelet[fixedCorner.index];
    final face = <String, int>{
      colours[held[0]]: Face.down.index,
      colours[held[1]]: Face.back.index,
      colours[held[2]]: Face.left.index,
      opposite[colours[held[0]]]!: Face.up.index,
      opposite[colours[held[1]]]!: Face.front.index,
      opposite[colours[held[2]]]!: Face.right.index,
    };
    if (face.length != 6) {
      throw FormatException("The stickers do not name six different faces");
    }

    final cube = CubieCube();
    for (var i = 0; i < CubieCube.cornerLength; i++) {
      final stickers = [for (final index in pocketCornerFacelet[i]) face[colours[index]]!];

      // The U or D sticker says how far the corner is twisted.
      var ori = 0;
      while (ori < 3 && stickers[ori] != Face.up.index && stickers[ori] != Face.down.index) {
        ori++;
      }
      if (ori == 3) {
        throw FormatException("Corner $i has no U or D sticker");
      }

      final first = stickers[(ori + 1) % 3];
      final second = stickers[(ori + 2) % 3];
      var piece = -1;
      for (var j = 0; j < CubieCube.cornerLength; j++) {
        if (cornerFace[j][1].index == first && cornerFace[j][2].index == second) {
          piece = j;
          break;
        }
      }
      if (piece < 0) {
        throw FormatException("Corner $i is not a corner of a cube");
      }

      cube.cornerState[i] = (ori << 3) | piece;
    }

    if (cube.cornerState.map((c) => c & 0x7).toSet().length != CubieCube.cornerLength) {
      throw FormatException("The same corner appears twice");
    }

    return cube;
  }
}
