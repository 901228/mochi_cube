import "dart:math";

/// The Rubik's Clock.
///
/// The odd one out. Every other puzzle here needs a search, or at least a table
/// of distances; this one needs neither, because its notation *is* its state.
///
/// Fourteen dials, each with twelve positions, and fourteen moves that each
/// turn exactly one of them. The moves commute and none undoes another, so the
/// puzzle is the group `(Z12)^14`: a state is a vector of fourteen numbers,
/// composing states adds them, and solving negates them. There is nothing to
/// search for.
///
/// That also settles the two things a search would otherwise have to work out.
/// Every state is reachable, so there is no such thing as an invalid one; and
/// the fewest moves that solve a state is simply how many of its dials are not
/// already at zero, since one move can fix one dial by any amount.
///
/// The eighteen dials you can see on the puzzle are not modelled. They are a
/// linear image of these fourteen and belong to whatever draws the thing, in
/// the same way the sticker colours of a cube do.
class ClockState {
  /// The fourteen dials, each 0 to 11, in the order [dialNames] gives.
  final List<int> dials;

  /// How many dials there are, and so how many numbers a scramble has.
  static const int dialCount = 14;

  /// Positions of one dial: twelve hours.
  static const int positions = 12;

  /// The dials that are turned before the puzzle is flipped over.
  static const int frontDials = 9;

  /// What each dial is called, in the order a scramble writes them.
  ///
  /// The first nine are turned with the puzzle facing you and the last five
  /// after flipping it, which is why five of the names appear twice.
  static const List<String> dialNames = [
    "UR", "DR", "DL", "UL", "U", "R", "D", "L", "ALL", //
    "U", "R", "D", "L", "ALL",
  ];

  const ClockState(this.dials);

  /// A solved clock: every dial at twelve o'clock.
  ClockState.solved() : dials = List.filled(dialCount, 0);

  /// A clock drawn evenly from all 12^14 states.
  ///
  /// [random] defaults to [Random.secure]; pass a seeded [Random] to reproduce
  /// a state.
  factory ClockState.random({Random? random}) {
    final rng = random ?? Random.secure();
    return ClockState(List.generate(dialCount, (_) => rng.nextInt(positions)));
  }

  /// Read a scramble, e.g. `"UR2- DR5- ... ALL5- y2 U4- ... ALL3+"`.
  ///
  /// Throws [FormatException] if it is not fourteen numbers in the expected
  /// order with `y2` between the ninth and the tenth.
  factory ClockState.parse(String notation) {
    final tokens = notation.split(RegExp(r"\s+")).where((t) => t.isNotEmpty).toList();
    if (tokens.length != dialCount + 1) {
      throw FormatException("Expected ${dialCount + 1} tokens, got ${tokens.length}");
    }
    if (tokens[frontDials] != "y2") {
      throw FormatException("Expected y2 after the first $frontDials dials, got ${tokens[frontDials]}");
    }

    final read = [...tokens]..removeAt(frontDials);
    return ClockState([for (var i = 0; i < dialCount; i++) _parseDial(read[i], dialNames[i], i)]);
  }

  /// The moves that undo this state.
  ///
  /// Turning every dial back the way it came, which is the whole of solving a
  /// clock.
  ClockState get inverse => ClockState([for (final dial in dials) (positions - dial) % positions]);

  /// This state followed by [other]: the dials added up.
  ClockState operator +(ClockState other) =>
      ClockState([for (var i = 0; i < dialCount; i++) (dials[i] + other.dials[i]) % positions]);

  int operator [](int dial) => dials[dial];

  bool get isSolved => dials.every((dial) => dial == 0);

  /// The fewest moves that solve this state.
  ///
  /// Exactly the number of dials that are not already at zero: each move turns
  /// one dial by as much as you like, and no move touches two.
  int get movesToSolve => dials.where((dial) => dial != 0).length;

  /// The state as a scramble, in the notation a competition uses.
  @override
  String toString() {
    final parts = <String>[];
    for (var i = 0; i < dialCount; i++) {
      if (i == frontDials) {
        parts.add("y2");
      }
      parts.add("${dialNames[i]}${_renderDial(dials[i])}");
    }
    return parts.join(" ");
  }

  @override
  bool operator ==(Object other) =>
      other is ClockState && Iterable.generate(dialCount).every((i) => other.dials[i] == dials[i]);

  @override
  int get hashCode => Object.hashAll(dials);
}

/// Write one dial as hours and a direction.
///
/// Six or fewer clockwise is written as it is; more than that is written as the
/// shorter turn the other way, so the numbers only ever run from `5-` to `6+`.
String _renderDial(int value) => value <= 6 ? "$value+" : "${ClockState.positions - value}-";

int _parseDial(String token, String name, int index) {
  if (!token.startsWith(name)) {
    throw FormatException("Dial $index should be $name, got $token");
  }

  final amount = token.substring(name.length);
  if (amount.length < 2) {
    throw FormatException("Missing an amount on $token");
  }

  final sign = amount[amount.length - 1];
  final hours = int.tryParse(amount.substring(0, amount.length - 1));
  if (hours == null || hours < 0 || hours > 6) {
    throw FormatException("Amount out of range on $token");
  }
  if (sign == "+") {
    return hours % ClockState.positions;
  }
  if (sign == "-") {
    return (ClockState.positions - hours) % ClockState.positions;
  }
  throw FormatException("Expected + or - on $token");
}

/// A scramble drawn evenly from every state of the clock.
///
/// There is no solving involved. The state is the scramble, so this draws
/// fourteen numbers and writes them down.
///
/// [minimumMoves] rejects states that are too nearly solved; WCA regulation
/// 4b3 asks for at least two moves. Since the distance is exact, so is the
/// check — and it almost never fires: fewer than two dials are off in about one
/// draw in 10^14.
ClockState randomClockScramble({Random? random, int minimumMoves = 2}) {
  while (true) {
    final state = ClockState.random(random: random);
    if (state.movesToSolve >= minimumMoves) {
      return state;
    }
  }
}
