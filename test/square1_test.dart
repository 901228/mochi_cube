import "dart:math";

import "package:mochi_cube/square1.dart";
import "package:test/test.dart";

/// TNoodle's own model of the puzzle, the official scramble program's, kept as
/// the reference ours is checked against.
///
/// It numbers the slots and pieces differently and turns them its own way —
/// `SquareOnePuzzle.SquareOneState` in tnoodle-lib — and maps onto sq12phase's
/// numbering only through `toFullCube`. So agreeing with it after any sequence
/// of moves says our turns are the official ones, not merely self-consistent.
class TNoodleSquare1 {
  List<int> pieces = [0, 0, 1, 2, 2, 3, 4, 4, 5, 6, 6, 7, 8, 9, 9, 10, 11, 11, 12, 13, 13, 14, 15, 15];
  bool sliceSolved = true;

  void rotate(int top, int bottom) {
    top = (-top % 12 + 12) % 12;
    bottom = (-bottom % 12 + 12) % 12;
    final next = [...pieces];
    for (var i = 0; i < 12; i++) {
      next[i] = pieces[(top + i) % 12];
      next[i + 12] = pieces[12 + (bottom + i) % 12];
    }
    pieces = next;
  }

  void slash() {
    for (var i = 0; i < 6; i++) {
      final c = pieces[i + 12];
      pieces[i + 12] = pieces[i + 6];
      pieces[i + 6] = c;
    }
    sliceSolved = !sliceSolved;
  }

  /// `toFullCube`: the same state in sq12phase's numbering.
  String toFullCube() {
    const map1 = [3, 2, 1, 0, 7, 6, 5, 4, 0xa, 0xb, 8, 9, 0xe, 0xf, 0xc, 0xd];
    const map2 = [5, 4, 3, 2, 1, 0, 11, 10, 9, 8, 7, 6, 17, 16, 15, 14, 13, 12, 23, 22, 21, 20, 19, 18];
    final full = List.filled(24, 0);
    for (var i = 0; i < 24; i++) {
      full[map2[i]] = map1[pieces[i]];
    }
    return "${full.map((p) => p.toRadixString(16)).join()}${sliceSolved ? 0 : 1}";
  }
}

void main() {
  group("the puzzle", () {
    test("starts solved, and twelve turns of a layer come back", () {
      final cube = Square1Cube();
      expect(cube.isSolved, isTrue);
      expect(cube.toString(), "011233455677998bbaddcffe0");
      for (var i = 0; i < 12; i++) {
        cube.turnTop(1);
        cube.turnBottom(1);
      }
      expect(cube.isSolved, isTrue);
    });

    test("/ undoes itself and turns the middle over", () {
      final cube = Square1Cube()..slash();
      expect(cube.middle, 1);
      expect(cube.isSolved, isFalse);
      cube.slash();
      expect(cube.isSolved, isTrue);
    });

    test("/ cannot be turned with a corner across the cut", () {
      final cube = Square1Cube()..turnTop(2);
      expect(cube.canSlash, isFalse);
      expect(cube.slash, throwsStateError);
    });

    test("agrees with TNoodle's model, move for move", () {
      final random = Random(1);
      for (var trial = 0; trial < 200; trial++) {
        final ours = Square1Cube();
        final theirs = TNoodleSquare1();
        expect(ours.toString(), theirs.toFullCube());
        for (var step = 0; step < 30; step++) {
          if (ours.canSlash && random.nextBool()) {
            ours.applyMove(Square1MoveSet.slashMove);
            theirs.slash();
          } else {
            final top = random.nextInt(12) - 5;
            final bottom = random.nextInt(12) - 5;
            if (top == 0 && bottom == 0) continue;
            ours.applyMove(Square1MoveSet.turn(top, bottom));
            theirs.rotate(top, bottom);
          }
          expect(ours.toString(), theirs.toFullCube(), reason: "trial $trial, step $step");
        }
      }
    });
  });

  group("notation", () {
    test("reads and writes it the way TNoodle does", () {
      const scramble = "(1,0) / (-3,3) / (0,-1) / (6,-5) / (3,0)";
      final algorithm = Algorithm.parse(scramble, moveSet: square1Moves);
      expect(algorithm.toString(), scramble);
      expect(algorithm.length, 9, reason: "each turn and each / is one move, per 12c4");
    });

    test("takes the spacing people write", () {
      expect(
        Algorithm.parse("(1, 0)/(-3,3)/ (0 ,-1)", moveSet: square1Moves).toString(),
        "(1,0) / (-3,3) / (0,-1)",
      );
      expect(Algorithm.parse("(7,-7)", moveSet: square1Moves).toString(), "(-5,5)");
    });

    test("rejects what is not Square-1", () {
      for (final bad in ["R U", "(1,0) x", "(0,0)", "(12,0)", "(1)"]) {
        expect(() => Algorithm.parse(bad, moveSet: square1Moves), throwsFormatException, reason: bad);
      }
    });

    test("an algorithm and its inverse cancel", () {
      final algorithm = Algorithm.parse("(1,0) / (-3,3) / (0,-1) / (6,-5)", moveSet: square1Moves);
      // A half turn is written 6, whichever way it went.
      expect(algorithm.inverse.toString(), "(6,5) / (0,1) / (3,-3) / (-1,0)");
      final cube = Square1Cube()
        ..apply(algorithm)
        ..apply(algorithm.inverse);
      expect(cube.isSolved, isTrue);
    });
  });

  group("state string", () {
    test("round trips", () {
      final cube = Square1Cube()
        ..apply(Algorithm.parse("(1,0) / (-3,3) / (0,-1) / (2,0)", moveSet: square1Moves));
      final read = Square1Cube.parse(cube.toString());
      expect(read.pieces, cube.pieces);
      expect(read.middle, cube.middle);
    });

    test("holds a corner across the cut", () {
      final cube = Square1Cube()..turnTop(2);
      expect(Square1Cube.parse(cube.toString()).canSlash, isFalse);
    });

    test("rejects what is not a Square-1", () {
      final solved = Square1Cube().toString();
      expect(() => Square1Cube.parse(solved.substring(1)), throwsFormatException);
      expect(() => Square1Cube.parse("${solved.substring(0, 24)}2"), throwsFormatException);
      // An edge twice and a corner once.
      expect(
        () => Square1Cube.parse("0012334556779 98bbaddcffe0".replaceAll(" ", "")),
        throwsFormatException,
      );
      // A corner's halves apart.
      expect(() => Square1Cube.parse("013213455677998bbaddcffe0"), throwsFormatException);
      // A corner's halves in different layers.
      expect(
        () => Square1Cube.parse("011233455677798bbaddcffe0".replaceRange(11, 12, "9")),
        throwsFormatException,
      );
    });
  });
}
