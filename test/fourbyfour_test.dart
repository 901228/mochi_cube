import "dart:math";
import "dart:typed_data";

import "package:mochi_cube/fourbyfour.dart";
import "package:mochi_cube/fourbyfour/center1.dart";
import "package:mochi_cube/fourbyfour/center2.dart";
import "package:mochi_cube/fourbyfour/center3.dart";
import "package:mochi_cube/fourbyfour/cubies.dart";
import "package:mochi_cube/fourbyfour/edge3.dart";
import "package:mochi_cube/fourbyfour/moves.dart";
import "package:mochi_cube/fourbyfour/search.dart";
import "package:test/test.dart";

/// The stickers of [cube] as the NxN model writes them.
List<int> stickers(FullCube cube) {
  final f = Uint8List(96);
  cube.toFacelet(f);
  return f;
}

/// The 24 ways to hold a 4x4x4, as permutations of its stickers:
/// `rotated[i] = cube[permutation[i]]`.
List<List<int>> rotations() {
  final identity = NxNCube.fromFacelets(4, List.generate(96, (i) => i));
  final seen = <String, List<int>>{identity.facelets.join(","): identity.facelets};
  final frontier = [identity];
  while (frontier.isNotEmpty) {
    final cube = frontier.removeLast();
    for (final face in [0, 1]) {
      final turned = NxNCube.from(cube)..turn(face, 4);
      if (seen.putIfAbsent(turned.facelets.join(","), () => turned.facelets) == turned.facelets) {
        frontier.add(turned);
      }
    }
  }
  return seen.values.toList();
}

/// Whether every face of [cube] is one colour and no two faces share one: a
/// solved 4x4x4 in whatever orientation.
bool isSolvedAnyWayUp(NxNCube cube) {
  final colours = <int>{};
  for (var face = 0; face < 6; face++) {
    final stickersOfFace = cube.facelets.sublist(face * 16, face * 16 + 16).toSet();
    if (stickersOfFace.length != 1) return false;
    colours.add(stickersOfFace.single);
  }
  return colours.length == 6;
}

void main() {
  setUpAll(Center1.initSym);

  // threephase is a port of the official program's solver, so what a move does
  // to it is checked against the package's own model of the puzzle, which was
  // itself checked against the 3x3x3 and 2x2x2 and built from 3D positions.
  group("the cube", () {
    test("starts solved, in the same sticker order as NxNCube", () {
      expect(stickers(FullCube()), NxNCube(4).toFacelets());
    });

    test("turns exactly as NxNCube(4) does, move for move", () {
      final random = Random(1);
      for (var trial = 0; trial < 100; trial++) {
        final cube = FullCube();
        final model = NxNCube(4);
        for (var step = 0; step < 40; step++) {
          final move = random.nextInt(36);
          cube.doMove(move);
          model.applyMove(move);
          expect(stickers(cube), model.toFacelets(), reason: "trial $trial, step $step, move $move");
        }
      }
    });

    test("queued moves are applied when a part is asked for", () {
      final random = Random(2);
      final eager = FullCube();
      final lazy = FullCube();
      for (var i = 0; i < 30; i++) {
        final move = random.nextInt(36);
        eager.doMove(move);
        lazy.move(move);
      }
      expect(stickers(lazy), stickers(eager));
    });

    test("a random state reads back from its own stickers", () {
      for (var seed = 0; seed < 100; seed++) {
        final cube = FullCube.random(Random(seed));
        final f = Uint8List.fromList(stickers(cube));
        expect(stickers(FullCube.fromFacelets(f)), f, reason: "seed $seed");
      }
    });

    test("a state reached by turning reads back from its own stickers", () {
      final random = Random(3);
      for (var trial = 0; trial < 50; trial++) {
        final model = NxNCube(4);
        for (var i = 0; i < 40; i++) {
          model.applyMove(random.nextInt(36));
        }
        final f = Uint8List.fromList(model.toFacelets());
        expect(stickers(FullCube.fromFacelets(f)), f);
      }
    });

    test("rejects stickers that are not a 4x4x4", () {
      final solved = Uint8List.fromList(NxNCube(4).toFacelets());

      // Two stickers of one corner traded: a corner twisted on its own.
      final twisted = Uint8List.fromList(solved);
      twisted[0x0f] = solved[0x10];
      twisted[0x10] = solved[0x0f];
      expect(() => FullCube.fromFacelets(twisted), throwsFormatException);

      // A wing's stickers traded for a colour pair no wing has.
      final badWing = Uint8List.fromList(solved);
      badWing[0x0d] = badWing[0x21] = 0;
      expect(() => FullCube.fromFacelets(badWing), throwsFormatException);

      // Two centres traded between colours.
      final badCentre = Uint8List.fromList(solved);
      badCentre[0x05] = 1;
      expect(() => FullCube.fromFacelets(badCentre), throwsFormatException);
    });

    test("the corners and wings of a random state need no parity of their own", () {
      // The 4x4x4 has no fixed centres, so any permutation of the pieces is a
      // state — which is what lets the generator draw them independently.
      var even = 0;
      for (var seed = 0; seed < 200; seed++) {
        final cube = FullCube.random(Random(seed));
        if (cube.getEdge().parity == cube.getCorner().parity) even++;
      }
      expect(even, inInclusiveRange(60, 140));
    });
  });

  group("the symmetries", () {
    test("form a group of 48: every row of the product is a permutation", () {
      for (var a = 0; a < 48; a++) {
        final row = {for (var b = 0; b < 48; b++) symmult[a * 48 + b]};
        expect(row, hasLength(48), reason: "row $a");
        expect(symmult[a * 48 + syminv[a]], 0, reason: "inverse of $a");
        expect(symmult[a * 48], a, reason: "identity on the right of $a");
      }
    });

    test("move conjugation is a permutation of the 36 moves", () {
      for (var s = 0; s < 48; s++) {
        final row = {for (var m = 0; m < 36; m++) symmove[s * 36 + m]};
        expect(row, hasLength(36), reason: "symmetry $s");
      }
      for (var m = 0; m < 36; m++) {
        expect(symmove[m], m, reason: "the identity leaves move $m alone");
      }
    });
  });

  group("the tables", () {
    setUpAll(FourByFourTables.init);

    test("phase 1's distances are those of an independent search over raw states", () {
      // A breadth-first search over the 735471 raw states, which uses none of
      // the symmetry reduction, to depth 5; every state it finds must be the
      // distance away that its class says, and nothing else may be nearer. The
      // class of the finished state holds three raw states: the colour class on
      // U and D, on F and B, or on R and L.
      final seen = Uint8List(Center1.nRaw)..fillRange(0, Center1.nRaw, 255);
      const finished = [0, 12869, 735470];
      for (final raw in finished) {
        seen[raw] = 0;
      }
      var frontier = [...finished];
      final c = Center1();
      for (var depth = 1; depth <= 5; depth++) {
        final next = <int>[];
        for (final state in frontier) {
          for (var m = 0; m < 27; m++) {
            c.setIndex(state);
            c.move(m);
            final idx = c.index;
            if (seen[idx] == 255) {
              seen[idx] = depth;
              next.add(idx);
            }
          }
        }
        frontier = next;
      }

      var checked = 0;
      final probe = Center1();
      for (var raw = 0; raw < Center1.nRaw; raw++) {
        if (seen[raw] == 255 && raw % 37 != 0) continue;
        probe.setIndex(raw);
        final distance = Center1.csprun[probe.getsym() >> 6];
        if (seen[raw] == 255) {
          expect(distance, greaterThan(5), reason: "raw state $raw is deeper than 5");
        } else {
          expect(distance, seen[raw], reason: "raw state $raw");
        }
        checked++;
      }
      expect(checked, greaterThan(10000));
      expect(Center1.csprun, isNot(contains(255)));
    });

    test("phase 1's move table follows the centres' own moves", () {
      // A class is held by its representative, so a state's own move is the
      // representative's move conjugated by the symmetry that links them.
      final random = Random(4);
      for (var trial = 0; trial < 300; trial++) {
        final centres = CenterCube();
        for (var i = 0; i < 12; i++) {
          centres.move(random.nextInt(27));
        }
        final before = Center1.fromCenter(centres, 0).getsym();
        final m = random.nextInt(36);
        centres.move(m);
        final after = Center1.fromCenter(centres, 0).getsym() >> 6;
        final through = symmove[(before & 0x3f) * 36 + m];
        expect(Center1.ctsmv[(before >> 6) * 36 + through] >> 6, after, reason: "trial $trial, move $m");
      }
    });

    test("every state of phases 1, 2 and 3 can be solved", () {
      expect(Center1.csprun, isNot(contains(255)));
      expect(Center2.ctprun, isNot(contains(255)));
      expect(Center3.prun, isNot(contains(255)));
      expect(Center1.csprun.reduce(max), 8);
      expect(Center3.prun.reduce(max), 10);
    });

    test("the wing table has as many entries as the original's, to the last", () {
      var set = 0;
      for (final byte in Edge3.eprun) {
        for (var k = 0; k < 4; k++) {
          if (((byte >> (k * 2)) & 3) != 3) set++;
        }
      }
      expect(set, Edge3.prunValues[Edge3.maxDepth - 1]);
    });

    // An independent search over real cubes, using only the wing moves already
    // checked against the NxN model. A face turn does not change what the table
    // looks at, so it is never above the true distance, not always equal to it;
    // but the classes the search reaches within each depth must be exactly the
    // published count of them.
    test("the wing distances never exceed those of a search over cubes, and the classes match", () {
      final e = Edge3();
      final moves = [for (var m = 0; m < 17; m++) move3std[m]];
      String key(EdgeCube c) => c.ep.join(",");

      var frontier = [EdgeCube()];
      final seen = {key(frontier.single)};
      final reached = <int>{};
      for (var depth = 0; depth <= 4; depth++) {
        for (final cube in frontier) {
          e.setCube(cube);
          final index = e.getsym();
          reached.add(index);
          expect(Edge3.getprun(index), lessThanOrEqualTo(depth), reason: "a state $depth moves out");
        }
        expect(reached, hasLength(Edge3.prunValues[depth]), reason: "classes within $depth moves");

        final next = <EdgeCube>[];
        for (final cube in frontier) {
          for (final m in moves) {
            final turned = EdgeCube.from(cube)..move(m);
            if (seen.add(key(turned))) next.add(turned);
          }
        }
        frontier = next;
      }
    });
  });

  group("the solver", () {
    test("a scramble leaves the random cube it was made from, up to turning it over", () {
      final holds = rotations();
      for (var seed = 0; seed < 25; seed++) {
        final target = FullCube.random(Random(seed));
        final scramble = Algorithm(ThreePhaseSearch().search(target), moveSet: nxnMoves(4));
        final made = NxNCube(4)..apply(scramble);
        final wanted = stickers(target);
        final found = holds.any((hold) {
          for (var i = 0; i < 96; i++) {
            if (made.facelets[i] != wanted[hold[i]]) return false;
          }
          return true;
        });
        expect(found, isTrue, reason: "seed $seed: $scramble");
      }
    });

    test("a solution solves the cube it was found for", () {
      for (var seed = 0; seed < 25; seed++) {
        final target = FullCube.random(Random(100 + seed));
        final cube = NxNCube.fromFacelets(4, stickers(target));
        final solution = FourByFourSearch.solve(cube);
        expect(isSolvedAnyWayUp(cube..apply(solution)), isTrue, reason: "seed $seed: $solution");
      }
    });

    test("it solves what is reached by turning, whichever way round the cube is held", () {
      final random = Random(5);
      for (var trial = 0; trial < 10; trial++) {
        final cube = NxNCube(4);
        for (var i = 0; i < 60; i++) {
          cube.applyMove(random.nextInt(36));
        }
        // Held another way: the whole cube turned, which moves the centres.
        cube.turn(random.nextInt(6), 4, 1 + random.nextInt(3));
        final solution = FourByFourSearch.solve(cube);
        expect(isSolvedAnyWayUp(cube..apply(solution)), isTrue, reason: "trial $trial");
        expect(solution.length, lessThan(70));
      }
    });

    test("solved needs nothing but possibly a rotation, and a scramble is not solved", () {
      final solution = FourByFourSearch.solve(NxNCube(4));
      expect(isSolvedAnyWayUp(NxNCube(4)..apply(solution)), isTrue);
      expect((NxNCube(4)..apply(randomFourByFourScramble(random: Random(7)))).isSolved, isFalse);
    });

    test("a scramble is the same on every run of one seed, and uses the three wide turns", () {
      final once = randomFourByFourScramble(random: Random(8));
      expect(randomFourByFourScramble(random: Random(8)), once);
      expect(once.moveSet, nxnMoves(4));
      expect(once.length, inInclusiveRange(30, 70));
      // Only U, R and F wide: axes 6 to 8 of the 12, never D, L or B.
      for (final move in once.moves) {
        final axis = nxnMoves(4).axisOf(move);
        if (axis >= 6) expect(axis, lessThan(9), reason: "$once");
      }
    });

    test("stickers that are not a 4x4x4 are refused", () {
      expect(() => FourByFourSearch.solve(NxNCube(3)), throwsArgumentError);
      final twisted = NxNCube(4);
      twisted.facelets[0x0f] = 1;
      expect(() => FourByFourSearch.solve(twisted), throwsFormatException);
    });
  });
}
