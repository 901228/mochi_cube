import "dart:math";

import "package:mochi_cube/clock.dart";
import "package:test/test.dart";

/// Straight from the notation reference, so the format is checked against
/// something written down elsewhere rather than against this code.
const String referenceScramble = "UR2- DR5- DL0+ UL1+ U2+ R0+ D3+ L5- ALL5- y2 U4- R3- D1+ L2- ALL3+";

void main() {
  group("notation", () {
    test("reads and writes the reference scramble unchanged", () {
      final state = ClockState.parse(referenceScramble);
      expect(state.toString(), referenceScramble);
      expect(state.dials, [10, 7, 0, 1, 2, 0, 3, 7, 7, 8, 9, 1, 10, 3]);
    });

    test("names the dials in the order a competition writes them", () {
      expect(ClockState.dialNames, [
        "UR", "DR", "DL", "UL", "U", "R", "D", "L", "ALL", //
        "U", "R", "D", "L", "ALL",
      ]);
      expect(ClockState.dialCount, 14);
      expect(ClockState.frontDials, 9);
      expect(ClockState.positions, 12);
    });

    test("puts y2 where the puzzle is turned over", () {
      final tokens = ClockState.random(random: Random(1)).toString().split(" ");
      expect(tokens, hasLength(15));
      expect(tokens[ClockState.frontDials], "y2");
    });

    test("writes the shorter way round, so amounts run from 5- to 6+", () {
      final written = <String>{};
      for (var value = 0; value < ClockState.positions; value++) {
        final dials = List.filled(ClockState.dialCount, 0);
        dials[0] = value;
        written.add(ClockState(dials).toString().split(" ").first.substring(2));
      }
      expect(written, {"0+", "1+", "2+", "3+", "4+", "5+", "6+", "5-", "4-", "3-", "2-", "1-"});
      expect(written, hasLength(ClockState.positions));
    });

    test("round-trips every random state", () {
      for (var seed = 0; seed < 2000; seed++) {
        final state = ClockState.random(random: Random(seed));
        expect(ClockState.parse(state.toString()), state, reason: "seed $seed");
      }
    });

    test("a solved clock is every dial at twelve o'clock", () {
      expect(ClockState.solved().isSolved, isTrue);
      expect(ClockState.solved().movesToSolve, 0);
      expect(
        ClockState.solved().toString(),
        "UR0+ DR0+ DL0+ UL0+ U0+ R0+ D0+ L0+ ALL0+ y2 U0+ R0+ D0+ L0+ ALL0+",
      );
    });

    test("rejects anything that is not a scramble", () {
      expect(() => ClockState.parse(""), throwsFormatException);
      expect(() => ClockState.parse("UR2+"), throwsFormatException);
      // No y2.
      expect(() => ClockState.parse(referenceScramble.replaceAll("y2 ", "")), throwsFormatException);
      // A dial out of order.
      expect(() => ClockState.parse(referenceScramble.replaceFirst("UR2-", "DR2-")), throwsFormatException);
      // More than six hours, which should have been written the other way.
      expect(() => ClockState.parse(referenceScramble.replaceFirst("UR2-", "UR9+")), throwsFormatException);
      // Neither clockwise nor anticlockwise.
      expect(() => ClockState.parse(referenceScramble.replaceFirst("UR2-", "UR2*")), throwsFormatException);
    });
  });

  group("the group", () {
    test("a state and its inverse cancel", () {
      for (var seed = 0; seed < 500; seed++) {
        final state = ClockState.random(random: Random(seed));
        expect((state + state.inverse).isSolved, isTrue, reason: "seed $seed");
        expect((state.inverse + state).isSolved, isTrue);
        expect(state.inverse.inverse, state);
      }
    });

    test("composing is commutative and associative", () {
      // Which is what makes the notation the state: the order the dials are
      // turned in cannot matter.
      for (var seed = 0; seed < 200; seed++) {
        final a = ClockState.random(random: Random(seed));
        final b = ClockState.random(random: Random(seed + 1000));
        final c = ClockState.random(random: Random(seed + 2000));

        expect(a + b, b + a);
        expect((a + b) + c, a + (b + c));
        expect(a + ClockState.solved(), a);
      }
    });

    test("the fewest moves is the number of dials that are off", () {
      // One move turns one dial by any amount, and no move touches two.
      for (var seed = 0; seed < 500; seed++) {
        final state = ClockState.random(random: Random(seed));
        expect(state.movesToSolve, state.dials.where((d) => d != 0).length);
        expect(state.movesToSolve == 0, state.isSolved);
        expect(state.inverse.movesToSolve, state.movesToSolve);
      }
    });
  });

  group("scrambles", () {
    test("meet the WCA minimum", () {
      for (var seed = 0; seed < 200; seed++) {
        expect(randomClockScramble(random: Random(seed)).movesToSolve, greaterThanOrEqualTo(2));
      }
    });

    test("respect a raised minimum", () {
      expect(randomClockScramble(random: Random(3), minimumMoves: 14).movesToSolve, 14);
    });

    test("every dial reaches every position", () {
      final seen = List.generate(ClockState.dialCount, (_) => <int>{});
      for (var seed = 0; seed < 2000; seed++) {
        final state = ClockState.random(random: Random(seed));
        for (var dial = 0; dial < ClockState.dialCount; dial++) {
          seen[dial].add(state[dial]);
        }
      }
      expect(seen.map((s) => s.length), everyElement(ClockState.positions));
    });

    test("the dials are drawn evenly and independently", () {
      // If they were, the number of dials that are off zero is binomial with
      // p = 11/12 over fourteen tries. A generator that repeated itself, or
      // favoured zero, would miss this.
      const draws = 20000;
      final histogram = List.filled(ClockState.dialCount + 1, 0);
      for (var i = 0; i < draws; i++) {
        histogram[ClockState.random(random: Random(i)).movesToSolve]++;
      }
      expect(histogram.reduce((a, b) => a + b), draws);

      double binomial(int k) {
        var coefficient = 1.0;
        for (var i = 0; i < k; i++) {
          coefficient = coefficient * (ClockState.dialCount - i) / (i + 1);
        }
        return coefficient * pow(11 / 12, k) * pow(1 / 12, ClockState.dialCount - k) * draws;
      }

      for (var k = 10; k <= ClockState.dialCount; k++) {
        final expected = binomial(k);
        expect(histogram[k], greaterThan(expected * 0.85), reason: "$k dials off");
        expect(histogram[k], lessThan(expected * 1.15), reason: "$k dials off");
      }
    });

    test("is reproducible from a seed, and varies without one", () {
      expect(ClockState.random(random: Random(9)), ClockState.random(random: Random(9)));
      final many = List.generate(20, (_) => ClockState.random().toString()).toSet();
      expect(many, hasLength(20));
    });
  });

  group("the eighteen dials", () {
    test("a solved clock reads twelve everywhere", () {
      expect(ClockState.solved().toDials(), List.filled(nClockDials, 0));
      expect(nClockDials, 18);
    });

    test("exactly four dials are locked to their opposite number, at the corners", () {
      // This is the mechanism, and it is what makes eighteen dials only
      // fourteen numbers. It is not asserted anywhere in the effect table; it
      // comes out of it.
      final locked = <int>[];
      for (var dial = 0; dial < 9; dial++) {
        final together = [
          for (var move = 0; move < ClockState.dialCount; move++)
            clockMoveEffect[move][dial] == clockMoveEffect[move][9 + mirroredDial(dial)],
        ];
        if (together.every((x) => x)) locked.add(dial);
      }

      expect(locked, clockCorners);
      expect(nClockDials - locked.length, ClockState.dialCount);
    });

    test("each move turns the dials its mechanism reaches", () {
      // A corner drives its own 2x2 block on one side, and its corner dial
      // shows through the other: four plus one. An edge is two corners, whose
      // blocks overlap: six plus two. All four is the whole side plus four.
      const expected = [5, 5, 5, 5, 8, 8, 8, 8, 13, 8, 8, 8, 8, 13];
      for (var move = 0; move < ClockState.dialCount; move++) {
        final dials = List.filled(ClockState.dialCount, 0);
        dials[move] = 1;
        expect(
          ClockState(dials).toDials().where((d) => d != 0),
          hasLength(expected[move]),
          reason: "move $move (${ClockState.dialNames[move]})",
        );
      }
    });

    test("round-trips back to the state that made them", () {
      for (var seed = 0; seed < 1000; seed++) {
        final state = ClockState.random(random: Random(seed));
        expect(ClockDialReading.fromDials(state.toDials()), state, reason: "seed $seed");
      }
    });

    test("different states show different dials", () {
      // The fourteen moves have to be independent, or the puzzle would have
      // fewer than 12^14 positions.
      final seen = <String>{};
      for (var seed = 0; seed < 2000; seed++) {
        seen.add(ClockState.random(random: Random(seed)).toDials().join(","));
      }
      expect(seen, hasLength(2000));
    });

    test("turning a dial back undoes it", () {
      for (var seed = 0; seed < 200; seed++) {
        final state = ClockState.random(random: Random(seed));
        expect((state + state.inverse).toDials(), List.filled(nClockDials, 0));
      }
    });

    test("rejects readings the puzzle cannot show", () {
      final good = ClockState.random(random: Random(1)).toDials();

      expect(() => ClockDialReading.fromDials([1, 2, 3]), throwsFormatException);
      expect(() => ClockDialReading.fromDials([...good.sublist(0, 17), 12]), throwsFormatException);
      expect(() => ClockDialReading.fromDials([...good.sublist(0, 17), -1]), throwsFormatException);

      // A corner that disagrees with itself: it is one piece.
      final broken = [...good];
      broken[0] = (broken[0] + 1) % ClockState.positions;
      expect(() => ClockDialReading.fromDials(broken), throwsFormatException);
    });

    test("reads nicely", () {
      expect(ClockState.solved().toDialString(), "front 0 0 0  0 0 0  0 0 0 | back 0 0 0  0 0 0  0 0 0");
    });
  });
}
