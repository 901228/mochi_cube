import "package:mochi_cube/kociemba/cube/cubie_cube.dart" as k;
import "package:mochi_cube/kociemba/cube/face_cube.dart" as k;
import "package:mochi_cube/kociemba/tables.dart" as k;
import "package:mochi_cube/kociemba/cube/enums.dart" as k;
import "package:mochi_cube/puzzle/coord_tables.dart";
import "package:mochi_cube/puzzle/phase2_tables.dart";
import "package:mochi_cube/puzzle/search.dart";
import "package:mochi_cube/solver.dart";
import "package:mochi_cube/table_storage.dart";
import "package:mochi_cube/puzzle/cube/cubie_cube.dart";
import "package:mochi_cube/cube/enums.dart";
import "package:mochi_cube/cube/algorithm.dart";
import "package:mochi_cube/puzzle/cube/moves.dart";
import "package:mochi_cube/puzzle/cube/sym_coord.dart";
import "package:mochi_cube/puzzle/cube/symmetry.dart";
import "package:test/test.dart";

/// The kociemba solver is verified end to end, so it is the reference the
/// min2phase port is checked against.
List<int> _facelets(k.CubieCube c) => k.FaceCube.fromCubieCube(c).state.map((e) => e.index).toList();

CubieCube viaKociemba(String scramble) =>
    CubieCube.fromFacelets(_facelets(scramble.isEmpty ? k.CubieCube() : k.CubieCube.fromScramble(scramble)));

String state(CubieCube c) => "${c.cornerState}|${c.edgeState}";

/// The same cube state in the kociemba representation, so kociemba coordinates
/// can be read off a puzzle cube.
k.CubieCube toKociemba(CubieCube c) => k.CubieCube(
      cornerState: List.generate(
          8, (i) => k.CCorner(k.Corner.values[c.cornerState[i] & 0x7], (c.cornerState[i] >> 3) % 3)),
      edgeState: List.generate(
          12, (i) => k.CEdge(k.Edge.values[c.edgeState[i] >> 1], c.edgeState[i] & 1)),
    );

/// Deterministic generator, so a failure is reproducible.
int _rng = 12345;
int _next(int n) {
  _rng = (_rng * 1103515245 + 12345) & 0x7FFFFFFF;
  return _rng % n;
}

void main() {
  setUp(() => _rng = 12345);

  group("cubie cube", () {
    test("a solved cube is solvable and has zero coordinates", () {
      final c = CubieCube();
      expect(c.verify(), CubeVerificationStatus.solvable);
      expect([c.twist, c.flip, c.udslice, c.cperm, c.eperm, c.mperm], everyElement(0));
    });

    test("fromFacelets agrees with the kociemba representation", () {
      for (var seed = 0; seed < 100; seed++) {
        final kc = k.CubieCube.randomize(seed);
        final pc = CubieCube.fromFacelets(_facelets(kc));
        expect(pc.verify(), CubeVerificationStatus.solvable, reason: "seed $seed");
        expect(pc.twist, kc.twist, reason: "seed $seed twist");
        expect(pc.flip, kc.flip, reason: "seed $seed flip");
        expect(pc.udslice, kc.udslice, reason: "seed $seed udslice");
        expect(pc.cornerParityBit, kc.cornerParity ? 1 : 0, reason: "seed $seed corner parity");
        expect(pc.edgeParityBit, kc.edgeParity ? 1 : 0, reason: "seed $seed edge parity");
      }
    });

    test("coordinates round-trip through their setters", () {
      final c = CubieCube();
      for (final v in [0, 1, 42, 1000, 2186]) {
        c.twist = v;
        expect(c.twist, v);
      }
      for (final v in [0, 1, 42, 1000, 2047]) {
        c.flip = v;
        expect(c.flip, v);
      }
      for (var v = 0; v < 495; v++) {
        c.udslice = v;
        expect(c.udslice, v);
      }
      for (final v in [0, 1, 5039, 40319]) {
        c.cperm = v;
        expect(c.cperm, v);
        c.eperm = v;
        expect(c.eperm, v);
      }
      for (var v = 0; v < 24; v++) {
        c.mperm = v;
        expect(c.mperm, v);
      }
    });

    test("inverse is an involution", () {
      final c = viaKociemba("R U R' U' F2 L D B'");
      expect(state(c.inverse().inverse()), state(c));
      expect(c.inverse().verify(), CubeVerificationStatus.solvable);
    });

    test("fromCoordinates applies every coordinate", () {
      final c = CubieCube.fromCoordinates(cperm: 1234, twist: 567, eperm: 89012, flip: 89);
      expect(c.cperm, 1234);
      expect(c.twist, 567);
      expect(c.eperm12, 89012);
      expect(c.flip, 89);
    });
  });

  group("move cubes", () {
    const faces = ["U", "R", "F", "D", "L", "B"];
    const powers = ["", "2", "'"];

    test("match the same turn built by kociemba", () {
      for (var f = 0; f < 6; f++) {
        for (var p = 0; p < 3; p++) {
          final notation = faces[f] + powers[p];
          expect(state(moveCube[3 * f + p]), state(viaKociemba(notation)), reason: notation);
        }
      }
    });

    test("four quarter turns of any face is the identity", () {
      for (var f = 0; f < 6; f++) {
        final c = CubieCube();
        for (var i = 0; i < 4; i++) {
          c.multiply(moveCube[3 * f]);
        }
        expect(state(c), state(CubieCube()), reason: "${faces[f]}4");
      }
    });

    test("random sequences track kociemba", () {
      for (var trial = 0; trial < 200; trial++) {
        final moves = List.generate(15, (_) => _next(18));
        final c = CubieCube();
        for (final m in moves) {
          c.moveIndex(m);
        }
        expect(state(c), state(viaKociemba(moves.map(moveToString).join(" "))),
            reason: moves.map(moveToString).join(" "));
      }
    });

    test("move(Face) turns that face once, clockwise", () {
      for (final face in Face.values) {
        final byFace = CubieCube();
        byFace.move(face);
        final byIndex = CubieCube();
        byIndex.moveIndex(3 * face.index);
        expect(state(byFace), state(byIndex), reason: face.name);
        expect(state(byFace), state(viaKociemba(face.letter)), reason: face.name);
      }
    });

    test("notation round-trips", () {
      for (var i = 0; i < 18; i++) {
        expect(parseMove(moveToString(i)), i);
      }
      expect(() => parseMove("X"), throwsFormatException);
      expect(() => parseMove("U3"), throwsFormatException);
    });
  });

  group("symmetry", () {
    test("there are 16 distinct symmetries starting with the identity", () {
      expect(cubeSym.map(state).toSet().length, 16);
      expect(state(cubeSym[0]), state(CubieCube()));
    });

    test("symMult is a group table", () {
      for (var i = 0; i < 16; i++) {
        expect(symMult[i].toSet().length, 16, reason: "row $i");
        expect(List.generate(16, (j) => symMult[j][i]).toSet().length, 16, reason: "column $i");
        expect(symMult[0][i], i);
        expect(symMult[i][0], i);
      }
      for (var a = 0; a < 16; a++) {
        for (var b = 0; b < 16; b++) {
          for (var c = 0; c < 16; c++) {
            expect(symMult[symMult[a][b]][c], symMult[a][symMult[b][c]], reason: "($a,$b,$c)");
          }
        }
      }
    });

    test("every symmetry has a two-sided inverse", () {
      for (var i = 0; i < 16; i++) {
        expect(symMult[i][symInv[i]], 0);
        expect(symMult[symInv[i]][i], 0);
      }
    });

    test("symMove permutes the 18 moves and preserves half turns", () {
      for (var s = 0; s < 16; s++) {
        expect(symMove[s].toSet().length, 18, reason: "row $s");
        for (var m = 0; m < 18; m++) {
          // Mirror symmetries swap clockwise and anticlockwise, so only "is a
          // half turn" is invariant.
          expect(symMove[s][m] % 3 == 1, m % 3 == 1, reason: "sym $s move $m");
        }
      }
      for (var m = 0; m < 18; m++) {
        expect(symMove[0][m], m);
      }
    });

    test("conjugating a sequence equals applying the conjugated sequence", () {
      for (var trial = 0; trial < 200; trial++) {
        final s = _next(16);
        final moves = List.generate(8, (_) => _next(18));

        final direct = CubieCube();
        final viaSym = CubieCube();
        for (final m in moves) {
          direct.moveIndex(m);
          viaSym.moveIndex(symMove[s][m]);
        }

        expect(state(conjugate(direct, symInv[s])), state(viaSym),
            reason: "sym $s, ${moves.map(moveToString).join(' ')}");
      }
    });

    test("conjugation preserves solvability and reverses", () {
      for (var trial = 0; trial < 100; trial++) {
        final c = CubieCube();
        for (var i = 0; i < 12; i++) {
          c.moveIndex(_next(18));
        }
        expect(c.verify(), CubeVerificationStatus.solvable);
        final s = _next(16);
        expect(state(conjugate(conjugate(c, s), symInv[s])), state(c));
      }
    });
  });

  group("symmetry reduction", () {
    void audit(String name, SymCoord sc, void Function(CubieCube, int) write, int Function(CubieCube) read) {
      test("$name reduces consistently", () {
        expect(sc.raw2sym, isNot(contains(-1)), reason: "every raw coordinate is classified");
        expect(sc.sym2raw.toSet().length, sc.classCount, reason: "representatives are distinct");

        for (var i = 1; i < sc.classCount; i++) {
          expect(sc.sym2raw[i], greaterThan(sc.sym2raw[i - 1]), reason: "representatives increase");
        }

        // Orbit-stabiliser: |orbit| * |stabiliser| == 16, and the orbits
        // partition the raw coordinates.
        final order = sc.syms.length;
        var total = 0;
        for (var cls = 0; cls < sc.classCount; cls++) {
          expect(sc.symState[cls] & 1, 1, reason: "class $cls stabiliser contains the identity");
          final stab = sc.symState[cls].toRadixString(2).replaceAll("0", "").length;
          expect(order % stab, 0, reason: "class $cls stabiliser size $stab divides $order");
          total += order ~/ stab;
        }
        expect(total, sc.rawCount, reason: "orbit sizes sum to the number of raw coordinates");

        // Decoding a raw coordinate must reproduce it.
        final step = sc.rawCount > 3000 ? 37 : 1;
        for (var raw = 0; raw < sc.rawCount; raw += step) {
          final (cls, s) = SymCoord.split(sc.raw2sym[raw]);
          final cube = CubieCube();
          write(cube, sc.sym2raw[cls]);
          expect(read(conjugate(cube, s)), raw, reason: "$name raw $raw via class $cls sym $s");
        }
      });
    }

    audit("twist", twistSym, (c, v) => c.twist = v, (c) => c.twist);
    audit("cperm", cpermSym, (c, v) => c.cperm = v, (c) => c.cperm);
    audit("eperm", epermSym, (c, v) => c.eperm = v, (c) => c.eperm);

    audit("flip over 8 symmetries", flipSym, (c, v) => c.flip = v, (c) => c.flip);

    test("phase1Syms is a subgroup", () {
      final set = phase1Syms.toSet();
      expect(set, contains(0));
      for (final a in phase1Syms) {
        expect(set, contains(symInv[a]), reason: "closed under inverses");
        for (final b in phase1Syms) {
          expect(set, contains(symMult[a][b]), reason: "closed under multiplication");
        }
      }
    });

    test("class counts match the reference implementation", () {
      // min2phase documents N_TWIST_SYM = 324, N_FLIP_SYM = 336, N_PERM_SYM = 2768.
      expect(twistSym8.classCount, 324);
      expect(flipSym.classCount, 336);
      expect(epermSym.classCount, 2768);
      expect(cpermSym.classCount, 2768);
      // Corner orientation survives the mirrors, so the full group halves it.
      expect(twistSym.classCount, 168);
    });
  });

  group("phase 1 tables", () {
    late Phase1Tables t;
    late k.Table raw;

    setUpAll(() {
      t = Phase1Tables();
      raw = k.Table();
    });

    test("raw move tables agree with kociemba", () {
      for (var i = 0; i < Phase1Tables.nTwist; i++) {
        for (var m = 0; m < Phase1Tables.nMoves; m++) {
          expect(t.twistMove[(i, m)], raw.twistMove[(i, m)], reason: "twist $i move $m");
        }
      }
      for (var i = 0; i < Phase1Tables.nFlip; i++) {
        for (var m = 0; m < Phase1Tables.nMoves; m++) {
          expect(t.flipMove[(i, m)], raw.flipMove[(i, m)], reason: "flip $i move $m");
        }
      }
      for (var i = 0; i < Phase1Tables.nUdslice; i++) {
        for (var m = 0; m < Phase1Tables.nMoves; m++) {
          expect(t.udsliceMove[(i, m)], raw.udsliceMove[(i, m)], reason: "udslice $i move $m");
        }
      }
    });

    test("the reduced pruning tables equal the raw distances everywhere", () {
      // Exhaustive: the symmetry reduction must not lose or change a single
      // distance, otherwise the search can miss a solution.
      var twistBad = 0;
      var flipBad = 0;
      for (var u = 0; u < Phase1Tables.nUdslice; u++) {
        for (var tw = 0; tw < Phase1Tables.nTwist; tw++) {
          if (t.twistPrune.at(t.indexOf(twistSym, tw, u)) != raw.udsliceTwistPrune[(u, tw)]) {
            twistBad++;
          }
        }
        for (var f = 0; f < Phase1Tables.nFlip; f++) {
          if (t.flipPrune.at(t.indexOf(flipSym, f, u)) != raw.udsliceFlipPrune[(u, f)]) {
            flipBad++;
          }
        }
      }
      expect(twistBad, 0, reason: "of ${Phase1Tables.nUdslice * Phase1Tables.nTwist} pairs");
      expect(flipBad, 0, reason: "of ${Phase1Tables.nUdslice * Phase1Tables.nFlip} pairs");
    }, timeout: Timeout(Duration(minutes: 2)));

    test("the heuristic is zero at the goal and admissible on random walks", () {
      expect(t.phase1Cost(0, 0, 0), 0);
      for (var trial = 0; trial < 2000; trial++) {
        final depth = _next(9) + 1;
        final c = CubieCube();
        for (var i = 0; i < depth; i++) {
          c.moveIndex(_next(18));
        }
        expect(t.phase1Cost(c.twist, c.flip, c.udslice), lessThanOrEqualTo(depth),
            reason: "estimate exceeds a known $depth move solution");
      }
    });

    test("the combined table equals a raw BFS over the whole (flip, twist) space", () {
      // This one pairs the two orientations and drops the slice, so the
      // kociemba tables are no help; the reference is the unreduced search.
      final rawPrune = fillPruningTable(
        length: Phase1Tables.nFlip * Phase1Tables.nTwist,
        stride: Phase1Tables.nTwist,
        moveCount: Phase1Tables.nMoves,
        successor: (i, m) =>
            t.flipMove[(i ~/ Phase1Tables.nTwist, m)] * Phase1Tables.nTwist +
            t.twistMove[(i % Phase1Tables.nTwist, m)],
      );

      var bad = 0;
      for (var f = 0; f < Phase1Tables.nFlip; f++) {
        final (cls, sym) = SymCoord.split(flipSym.raw2sym[f]);
        for (var tw = 0; tw < Phase1Tables.nTwist; tw++) {
          if (t.twistFlipPrune!.at(cls * Phase1Tables.nTwist + t.twistConj[(tw, symInv[sym])]) !=
              rawPrune[(f, tw)]) {
            bad++;
          }
        }
      }
      expect(bad, 0, reason: "of ${Phase1Tables.nFlip * Phase1Tables.nTwist} pairs");
    }, timeout: Timeout(Duration(minutes: 3)));

    test("is much smaller than the raw tables", () {
      final rawEntries = Phase1Tables.nUdslice * (Phase1Tables.nTwist + Phase1Tables.nFlip);
      final reduced = (twistSym.classCount + flipSym.classCount) * Phase1Tables.nUdslice;
      expect(reduced, lessThan(rawEntries ~/ 8));
    });
  });

  group("phase 2 tables", () {
    late Phase2Tables t;
    late k.Table raw;
    late List<int> edge4Of;
    late List<int> cornerOf;
    late List<int> edge8Of;

    setUpAll(() {
      t = Phase2Tables();
      raw = k.Table();
      edge4Of = List.generate(Phase2Tables.nMperm, (m) {
        final c = CubieCube();
        c.mperm = m;
        return toKociemba(c).edge4;
      });
      cornerOf = List.generate(Phase2Tables.nPerm, (v) {
        final c = CubieCube();
        c.cperm = v;
        return toKociemba(c).corner;
      });
      edge8Of = List.generate(Phase2Tables.nPerm, (v) {
        final c = CubieCube();
        c.eperm = v;
        return toKociemba(c).edge8;
      });
    });

    test("the 10 phase 2 moves are closed under symmetry", () {
      // If a symmetry could turn a phase 2 move into one that leaves the
      // subgroup, reducing phase 2 by symmetry would be invalid.
      expect(Phase2Tables.moves, hasLength(Phase2Tables.nMoves));
      for (var s = 0; s < symCount; s++) {
        for (final m in Phase2Tables.moves) {
          expect(Phase2Tables.moves, contains(symMove[s][m]), reason: "sym $s move $m");
        }
      }
    });

    test("the coordinate maps onto kociemba are bijections", () {
      expect(edge4Of.toSet(), hasLength(Phase2Tables.nMperm));
      expect(cornerOf.toSet(), hasLength(Phase2Tables.nPerm));
      expect(edge8Of.toSet(), hasLength(Phase2Tables.nPerm));
    });

    test("the reduced pruning tables equal the raw distances everywhere", () {
      var cornerBad = 0;
      var edgeBad = 0;
      for (var m = 0; m < Phase2Tables.nMperm; m++) {
        for (var v = 0; v < Phase2Tables.nPerm; v++) {
          if (t.cpermPrune.at(t.cpermIndex(v, m)) !=
              raw.edge4CornerPrune[(edge4Of[m], cornerOf[v])]) {
            cornerBad++;
          }
          if (t.epermPrune.at(t.epermIndex(v, m)) !=
              raw.edge4Edge8Prune[(edge4Of[m], edge8Of[v])]) {
            edgeBad++;
          }
        }
      }
      expect(cornerBad, 0, reason: "of ${Phase2Tables.nMperm * Phase2Tables.nPerm} pairs");
      expect(edgeBad, 0, reason: "of ${Phase2Tables.nMperm * Phase2Tables.nPerm} pairs");
    }, timeout: Timeout(Duration(minutes: 2)));

    test("the heuristic is zero at the goal and admissible on random walks", () {
      expect(t.phase2Cost(0, 0, 0, 0), 0);
      for (var trial = 0; trial < 3000; trial++) {
        final depth = _next(12) + 1;
        final c = CubieCube();
        for (var i = 0; i < depth; i++) {
          c.moveIndex(Phase2Tables.moves[_next(Phase2Tables.nMoves)]);
        }
        expect(t.phase2Cost(c.cperm, c.eperm, c.mperm, c.ccombo), lessThanOrEqualTo(depth),
            reason: "estimate exceeds a known $depth move solution");
      }
    });
  });

  group("corner combination table", () {
    test("equals a raw BFS over the whole (eperm, ccombo) space", () {
      // This table has no kociemba counterpart, so the reference is the
      // unreduced breadth-first search over the product space.
      final t = Phase2Tables();

      final epermMove = MovingTable.filled(Phase2Tables.nPerm, Phase2Tables.nMoves);
      for (var v = 0; v < Phase2Tables.nPerm; v++) {
        for (var i = 0; i < Phase2Tables.nMoves; i++) {
          final c = CubieCube();
          c.eperm = v;
          c.multiply(moveCube[Phase2Tables.moves[i]]);
          epermMove[(v, i)] = c.eperm;
        }
      }

      final rawPrune = fillPruningTable(
        length: Phase2Tables.nPerm * Phase2Tables.nCcombo,
        stride: Phase2Tables.nCcombo,
        moveCount: Phase2Tables.nMoves,
        successor: (i, m) =>
            epermMove[(i ~/ Phase2Tables.nCcombo, m)] * Phase2Tables.nCcombo +
            t.ccomboMove[(i % Phase2Tables.nCcombo, m)],
      );

      var bad = 0;
      for (var v = 0; v < Phase2Tables.nPerm; v++) {
        for (var cc = 0; cc < Phase2Tables.nCcombo; cc++) {
          if (t.ccomboPrune.at(t.ccomboIndex(v, cc)) != rawPrune[(v, cc)]) {
            bad++;
          }
        }
      }
      expect(bad, 0,
          reason: "of ${Phase2Tables.nPerm * Phase2Tables.nCcombo} pairs");
    }, timeout: Timeout(Duration(minutes: 3)));
  });

  group("S_URF", () {
    test("has order 3 and is not one of the 16 symmetries", () {
      final u1u1 = CubieCube.from(urf1);
      u1u1.multiply(urf1);
      expect(state(u1u1), state(urf2), reason: "urf1 * urf1 == urf2");

      final u1u2 = CubieCube.from(urf1);
      u1u2.multiply(urf2);
      expect(state(u1u2), state(CubieCube()), reason: "urf1 * urf2 == identity");

      final c = CubieCube.from(moveCube[0]);
      expect(state(urfConjugate(urfConjugate(urfConjugate(c)))), state(moveCube[0]));

      // It moves the U/D axis, which is exactly why it cannot reduce the
      // coordinate tables and can only be used to re-run the search.
      expect(cubeSym.map(state), isNot(contains(state(urf1))));
    });

    test("cycles the axes", () {
      expect(urfMove.toSet(), hasLength(18));
      expect(moveToString(urfMove[parseMove("U")]), "R");
      expect(moveToString(urfMove[parseMove("R")]), "F");
      expect(moveToString(urfMove[parseMove("F")]), "U");
      for (var m = 0; m < 18; m++) {
        expect(urfMove[m] % 3, m % 3, reason: "S_URF is a rotation, it keeps the turn amount");
      }
    });

    test("conjugating a sequence equals applying the conjugated sequence", () {
      for (var trial = 0; trial < 300; trial++) {
        final moves = List.generate(10, (_) => _next(18));
        final direct = CubieCube();
        final viaUrf = CubieCube();
        for (final m in moves) {
          direct.moveIndex(m);
          viaUrf.moveIndex(urfMove[m]);
        }
        expect(state(urfConjugate(direct)), state(viaUrf),
            reason: moves.map(moveToString).join(" "));
      }
    });

    test("preserves solvability", () {
      for (var trial = 0; trial < 200; trial++) {
        final c = CubieCube();
        for (var i = 0; i < 12; i++) {
          c.moveIndex(_next(18));
        }
        expect(urfConjugate(c).verify(), CubeVerificationStatus.solvable);
      }
    });
  });

  group("toFacelets", () {
    test("renders the solved cube", () {
      expect(CubieCube().toFaceletString(),
          "UUUUUUUUU" "RRRRRRRRR" "FFFFFFFFF" "DDDDDDDDD" "LLLLLLLLL" "BBBBBBBBB");
    });

    test("agrees with the kociemba renderer on random cubes", () {
      for (var seed = 0; seed < 200; seed++) {
        final kc = k.CubieCube.randomize(seed);
        expect(CubieCube.fromFacelets(_facelets(kc)).toFaceletString(),
            k.FaceCube.fromCubieCube(kc).toString(),
            reason: "seed $seed");
      }
    });

    test("round-trips through fromFacelets", () {
      for (var trial = 0; trial < 200; trial++) {
        final c = CubieCube();
        for (var i = 0; i < 15; i++) {
          c.moveIndex(_next(18));
        }
        expect(state(CubieCube.fromFacelets(c.toFacelets())), state(c));
      }
    });

    test("the search accepts what toFaceletString produces", () {
      final c = CubieCube();
      for (var i = 0; i < 20; i++) {
        c.moveIndex(_next(18));
      }
      final r = Search.solution(c.toFaceletString());
      expect(r.status, SolveStatus.foundSolution);

      for (final m in r.solution!.moves) {
        c.moveIndex(m);
      }
      expect(c.toFaceletString(), CubieCube().toFaceletString());
    });
  });
}
