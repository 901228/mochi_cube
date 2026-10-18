import "dart:math";

import "package:mochi_cube/megaminx.dart";
import "package:test/test.dart";

/// A puzzle whose stickers are numbered, so each one can be followed.
Megaminx labelled() => Megaminx.fromFacelets(List.generate(nMegaminxFacelets, (i) => i));

/// Turning the whole puzzle about [face]: the face and everything else, which
/// is how TNoodle reorients it. Only U and L have their opposite among the big
/// turns.
void spin(Megaminx puzzle, int face, int fifths) {
  puzzle.turnFace(face, fifths);
  puzzle.turnBig(face == Megaminx.u ? Megaminx.d : Megaminx.dbr, 5 - fifths);
}

/// The stickers grouped into pieces by which face turns move them: a corner is
/// moved by the three faces it touches, an edge by two and a centre by none.
Map<String, List<int>> pieces() {
  final movers = List.generate(nMegaminxFacelets, (_) => <int>[]);
  for (var face = 0; face < 12; face++) {
    final turned = labelled()..turnFace(face);
    for (var slot = 0; slot < nMegaminxFacelets; slot++) {
      if (turned.facelets[slot] != slot) movers[turned.facelets[slot]].add(face);
    }
  }
  final grouped = <String, List<int>>{};
  for (var sticker = 0; sticker < nMegaminxFacelets; sticker++) {
    final key = movers[sticker].isEmpty ? "centre $sticker" : movers[sticker].join(",");
    (grouped[key] ??= []).add(sticker);
  }
  return grouped;
}

void main() {
  group("the turns", () {
    test("every turn has order five, and moves a face and its rim", () {
      for (var face = 0; face < 12; face++) {
        final puzzle = Megaminx()..turnFace(face);
        expect(puzzle.isSolved, isFalse);
        puzzle.turnFace(face, 4);
        expect(puzzle.isSolved, isTrue, reason: "face ${megaminxFaceNames[face]}");

        final moved = labelled()..turnFace(face);
        final count = [
          for (var i = 0; i < nMegaminxFacelets; i++) moved.facelets[i] != i,
        ].where((m) => m).length;
        expect(count, 25, reason: "ten of its own and three from each of five neighbours");
      }
      for (final face in [Megaminx.d, Megaminx.dbr]) {
        final puzzle = Megaminx()..turnBig(face, 5);
        expect(puzzle.isSolved, isTrue);
      }
    });

    test("132 stickers make 20 corners, 30 edges and 12 centres", () {
      final grouped = pieces().values.toList();
      expect(grouped.where((p) => p.length == 3), hasLength(20));
      expect(grouped.where((p) => p.length == 2), hasLength(30));
      expect(grouped.where((p) => p.length == 1), hasLength(12));
      expect(grouped, hasLength(62));
    });

    // The face turns and the big turns are separate tables. If they disagree
    // about the shape of the puzzle, a face turn and the big turn the other way
    // about the opposite face will not come to a rotation of the whole thing.
    test("a face and the rest turned together are a rotation, and there are 60", () {
      final seen = <String, Megaminx>{};
      final frontier = [labelled()];
      while (frontier.isNotEmpty) {
        final puzzle = frontier.removeLast();
        for (final face in [Megaminx.u, Megaminx.l]) {
          final turned = Megaminx.from(puzzle);
          spin(turned, face, 1);
          if (seen.putIfAbsent(turned.facelets.join(","), () => turned) == turned) frontier.add(turned);
        }
      }
      expect(seen, hasLength(60));

      for (final rotation in seen.values) {
        final solved = Megaminx();
        final rotated = [for (final i in rotation.facelets) solved.facelets[i]];
        for (var face = 0; face < 12; face++) {
          expect(rotated.sublist(face * 11, face * 11 + 11).toSet(), hasLength(1), reason: "face $face");
        }
      }
    });

    test("every move takes pieces to whole pieces", () {
      final byPiece = {
        for (final piece in pieces().values)
          for (final sticker in piece) sticker: piece,
      };
      for (var move = 0; move < megaminxMoves.count; move++) {
        final turned = labelled()..applyMove(move);
        final where = List<int>.filled(nMegaminxFacelets, 0);
        for (var slot = 0; slot < nMegaminxFacelets; slot++) {
          where[turned.facelets[slot]] = slot;
        }
        for (final piece in pieces().values) {
          final landed = {for (final sticker in piece) ...byPiece[where[sticker]]!};
          expect(landed, hasLength(piece.length), reason: "move ${megaminxMoves.render(move)}");
        }
      }
    });
  });

  group("notation", () {
    test("reads and writes the WCA's moves, and a move and its inverse cancel", () {
      final algorithm = Algorithm.parse("R++ D-- R-- D++ U U'", moveSet: megaminxMoves);
      expect(algorithm.toString(), "R++ D-- R-- D++ U U'");
      expect(algorithm.inverse.toString(), "U U' D-- R++ D++ R--");
      final puzzle = Megaminx()
        ..apply(algorithm)
        ..apply(algorithm.inverse);
      expect(puzzle.isSolved, isTrue);
      expect(() => Algorithm.parse("R+ U2", moveSet: megaminxMoves), throwsFormatException);
    });
  });

  group("scramble", () {
    test("is seven rows of ten R and D turns, each closed by U", () {
      for (var seed = 0; seed < 20; seed++) {
        final scramble = randomMegaminxScramble(random: Random(seed));
        expect(scramble, hasLength(77));
        final rows = megaminxNotation(scramble).split("\n");
        expect(rows, hasLength(7));
        for (final row in rows) {
          final turns = row.split(" ");
          expect(turns, hasLength(11));
          for (var i = 0; i < 10; i++) {
            expect(turns[i], matches(i.isEven ? r"^R(\+\+|--)$" : r"^D(\+\+|--)$"));
          }
          expect(turns.last, turns[9] == "D++" ? "U" : "U'");
        }
        expect(Algorithm.parse(megaminxNotation(scramble), moveSet: megaminxMoves), scramble);
      }
    });

    test("a seed repeats it, and it leaves the puzzle scrambled", () {
      expect(randomMegaminxScramble(random: Random(1)), randomMegaminxScramble(random: Random(1)));
      expect((Megaminx()..apply(randomMegaminxScramble(random: Random(2)))).isSolved, isFalse);
    });
  });

  group("stickers", () {
    test("read back as themselves, and anything else is refused", () {
      final puzzle = Megaminx()..apply(randomMegaminxScramble(random: Random(3)));
      expect(Megaminx.fromFaceletString(puzzle.toFaceletString()).facelets, puzzle.facelets);

      final solved = Megaminx().toFaceletString();
      expect(() => Megaminx.fromFaceletString(solved.substring(1)), throwsFormatException);
      expect(() => Megaminx.fromFaceletString("B${solved.substring(1)}"), throwsFormatException);
      expect(() => Megaminx.fromFaceletString("Z${solved.substring(1)}"), throwsFormatException);
    });
  });
}
