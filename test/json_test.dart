import "dart:convert";
import "dart:math";

import "package:mochi_cube/mochi_cube.dart";
import "package:test/test.dart";

void main() {
  final solved = CubieCube().toFaceletString();

  group("facelet strings", () {
    test("round-trip through fromFaceletString", () {
      for (var seed = 0; seed < 50; seed++) {
        final cube = randomScramble(random: Random(seed)).cube;
        final text = cube.toFaceletString();
        expect(CubieCube.fromFaceletString(text).toFaceletString(), text);
      }
    });

    test("accepts any six colours, named by the centres", () {
      const scheme = {"U": "W", "R": "R", "F": "G", "D": "Y", "L": "O", "B": "B"};
      final cube = randomScramble(random: Random(1)).cube;
      final recoloured = cube.toFaceletString().split("").map((c) => scheme[c]!).join();
      expect(CubieCube.fromFaceletString(recoloured).toFaceletString(), cube.toFaceletString());
    });

    test("ignores whitespace", () {
      expect(
        CubieCube.fromFaceletString(
          "UUUUUUUUU RRRRRRRRR FFFFFFFFF DDDDDDDDD LLLLLLLLL BBBBBBBBB",
        ).toFaceletString(),
        solved,
      );
    });

    test("rejects strings that are not a cube", () {
      expect(() => CubieCube.fromFaceletString("UUU"), throwsFormatException);
      // Two centres the same colour.
      expect(
        () => CubieCube.fromFaceletString(
          "UUUUUUUUU" "RRRRURRRR" "FFFFFFFFF" "DDDDDDDDD" "LLLLLLLLL" "BBBBBBBBB",
        ),
        throwsFormatException,
      );
      // Ten of one colour, eight of another.
      expect(
        () => CubieCube.fromFaceletString(
          "UUUUUUUUU" "RRRRRRRRU" "FFFFFFFFF" "DDDDDDDDD" "LLLLLLLLL" "BBBBBBBBB",
        ),
        throwsFormatException,
      );
      // A colour that is not one of the centres.
      expect(
        () => CubieCube.fromFaceletString(
          "XUUUUUUUU" "RRRRRRRRR" "FFFFFFFFF" "DDDDDDDDD" "LLLLLLLLL" "BBBBBBBBB",
        ),
        throwsFormatException,
      );
    });

    test("accepts a well formed but unsolvable cube, leaving verify to judge", () {
      final broken = CubieCube();
      broken.edgeState[0] ^= 1;
      final parsed = CubieCube.fromFaceletString(broken.toFaceletString());
      expect(parsed.verify(), CubeVerificationStatus.flipError);
    });
  });

  group("JSON", () {
    test("round-trips a cube", () {
      for (var seed = 0; seed < 20; seed++) {
        final cube = randomScramble(random: Random(seed)).cube;
        final json = jsonDecode(jsonEncode(cube.toJson())) as Map<String, dynamic>;
        expect(CubieCube.fromJson(json).toFaceletString(), cube.toFaceletString());
      }
    });

    test("stores the facelet string, not the internal packing", () {
      final cube = Patterns.checkerboard.cube;
      expect(cube.toJson(), {"facelets": cube.toFaceletString()});
    });

    test("rejects JSON that is not a cube", () {
      expect(() => CubieCube.fromJson({}), throwsFormatException);
      expect(() => CubieCube.fromJson({"facelets": 42}), throwsFormatException);
      expect(() => CubieCube.fromJson({"facelets": "nope"}), throwsFormatException);
    });

    test("a solved cube survives the trip", () {
      expect(CubieCube.fromJson(CubieCube().toJson()).toFaceletString(), solved);
    });
  });
}
