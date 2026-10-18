import "../cube/algorithm.dart";

/// The twelve faces, in TNoodle's order: U and the five round it, then D and
/// the five round it.
const List<String> megaminxFaceNames = ["U", "BL", "BR", "R", "F", "L", "D", "DR", "DBR", "B", "DBL", "DL"];

/// What each face is written as in a sticker string, one letter each since the
/// names are not: `A` for U, `B` for BL and so on in [megaminxFaceNames] order.
const String megaminxFaceLetters = "ABCDEFGHIJKL";

/// How many stickers there are: eleven on each of the twelve faces.
const int nMegaminxFacelets = 132;

/// The Megaminx, held as its stickers in TNoodle's numbering.
///
/// Sticker `face * 11 + slot`: slots 0 to 9 go round the face, the even ones
/// corners and the odd ones edges, and slot 10 is the centre. The turns are
/// TNoodle's own, the official scramble program's, ported cycle for cycle: a
/// Megaminx is scrambled by random turns, so what matters is turning exactly
/// as the official program does. The test checks them against the shape of
/// the puzzle rather than against themselves.
class Megaminx {
  /// The stickers, as face indices.
  final List<int> facelets;

  Megaminx() : facelets = [for (var i = 0; i < nMegaminxFacelets; i++) i ~/ 11];

  Megaminx.from(Megaminx other) : facelets = [...other.facelets];

  /// A puzzle showing [facelets], which are taken as they are.
  Megaminx.fromFacelets(List<int> facelets) : facelets = [...facelets];

  static const int u = 0, l = 5, d = 6, dbr = 8;

  /// Where every sticker goes under a fifth of a turn clockwise of each face.
  static final List<List<int>> _faceTurns = [
    for (var face = 0; face < 12; face++) _permutation(_faceCycles(face)),
  ];

  /// The same for turning everything but [l] about [dbr], and everything but
  /// [u] about [d], which is what Pochmann's `R` and `D` are.
  static final Map<int, List<int>> _bigTurns = {
    dbr: _permutation(_bigCycles(dbr)),
    d: _permutation(_bigCycles(d)),
  };

  /// Turn [face] alone [fifths] of the way round, clockwise seen from outside.
  void turnFace(int face, [int fifths = 1]) => _apply(_faceTurns[face], fifths);

  /// Turn everything but the face opposite [face] — which must be [dbr] or [d]
  /// — [fifths] of the way round [face], clockwise seen from outside it.
  void turnBig(int face, [int fifths = 1]) => _apply(_bigTurns[face]!, fifths);

  void _apply(List<int> to, int fifths) {
    for (var t = 0; t < fifths % 5; t++) {
      final moved = List<int>.filled(nMegaminxFacelets, 0);
      for (var i = 0; i < nMegaminxFacelets; i++) {
        moved[to[i]] = facelets[i];
      }
      facelets.setAll(0, moved);
    }
  }

  /// Apply one move index of [megaminxMoves].
  void applyMove(int move) => switch (move) {
    0 => turnBig(dbr, 2),
    1 => turnBig(dbr, 3),
    2 => turnBig(d, 2),
    3 => turnBig(d, 3),
    4 => turnFace(u, 1),
    _ => turnFace(u, 4),
  };

  /// Apply an algorithm written in [megaminxMoves].
  void apply(Algorithm algorithm) {
    for (final move in algorithm.moves) {
      applyMove(move);
    }
  }

  bool get isSolved {
    for (var i = 0; i < nMegaminxFacelets; i++) {
      if (facelets[i] != i ~/ 11) return false;
    }
    return true;
  }

  List<int> toFacelets() => [...facelets];

  /// The stickers as a string of [megaminxFaceLetters].
  String toFaceletString() => facelets.map((face) => megaminxFaceLetters[face]).join();

  @override
  String toString() => toFaceletString();

  /// Read a sticker string as [toFaceletString] writes it.
  ///
  /// Throws [FormatException] unless it is 132 of [megaminxFaceLetters], eleven
  /// of each.
  // shortcut: the letters are fixed, and whether the stickers can be reached
  // by turning is not checked; nothing here solves a Megaminx, and drawing one
  // needs neither. Read the colours off the pieces if a solver is ever added.
  static Megaminx fromFaceletString(String facelets) {
    final cleaned = facelets.replaceAll(RegExp(r"\s"), "");
    if (cleaned.length != nMegaminxFacelets) {
      throw FormatException("Expected $nMegaminxFacelets facelets, got ${cleaned.length}");
    }
    final faces = [for (final letter in cleaned.split("")) megaminxFaceLetters.indexOf(letter)];
    if (faces.contains(-1)) {
      throw FormatException("A Megaminx's stickers are written in the letters $megaminxFaceLetters");
    }
    for (var face = 0; face < 12; face++) {
      final count = faces.where((f) => f == face).length;
      if (count != 11) {
        throw FormatException("${megaminxFaceLetters[face]} appears $count times, not eleven");
      }
    }
    return Megaminx.fromFacelets(faces);
  }
}

/// Megaminx notation as the WCA scrambles it, regulation 12e: `R++` and `R--`
/// turn everything but the left face two fifths, `D++` and `D--` everything
/// but the top, and `U` and `U'` the top face one fifth.
///
/// A move and its opposite are neighbours, so this only overrides [invert].
class MegaminxMoveSet extends MoveSet {
  const MegaminxMoveSet._() : super(axes: const ["R++", "R--", "D++", "D--", "U", "U'"], amounts: const [""]);

  @override
  int invert(int move) => move ^ 1;
}

const MegaminxMoveSet megaminxMoves = MegaminxMoveSet._();

/// Where each sticker goes when [cycles] are applied to the stickers, each
/// cycle written as TNoodle writes its swaps: the first sticker takes the
/// second's place's contents, the second the third's, and the last the first's.
List<int> _permutation(List<List<int>> cycles) {
  final image = [for (var i = 0; i < nMegaminxFacelets; i++) i];
  for (final cycle in cycles) {
    final first = image[cycle[0]];
    for (var i = 0; i < cycle.length - 1; i++) {
      image[cycle[i]] = image[cycle[i + 1]];
    }
    image[cycle.last] = first;
  }
  // image[slot] is which sticker now sits there; the inverse is where each goes.
  final to = List<int>.filled(nMegaminxFacelets, 0);
  for (var slot = 0; slot < nMegaminxFacelets; slot++) {
    to[image[slot]] = slot;
  }
  return to;
}

int _at(int face, int slot) => face % 12 * 11 + slot;

/// The face's own ten stickers going round, as TNoodle's `rotateFace`.
List<List<int>> _rotateFace(int face) => [
  [
    for (final slot in [0, 8, 6, 4, 2]) _at(face, slot),
  ],
  [
    for (final slot in [1, 9, 7, 5, 3]) _at(face, slot),
  ],
];

/// TNoodle's `turn`: the three stickers along each neighbour's side, and the
/// face itself.
List<List<int>> _faceCycles(int face) {
  final b = face >= 6 ? 6 : 0;
  const sides = [
    [1, 6, 5, 4, 4, 2, 3, 0, 2, 8],
    [0, 0, 2, 0, 9, 6, 10, 6, 5, 2],
    [0, 2, 3, 2, 8, 4, 9, 4, 1, 4],
    [0, 4, 4, 4, 7, 2, 8, 2, 2, 6],
    [0, 6, 5, 6, 11, 0, 7, 0, 3, 8],
    [0, 8, 1, 8, 10, 8, 11, 8, 4, 0],
  ];
  final s = sides[face % 6];
  return [
    for (var i = 0; i < 3; i++) [for (var k = 0; k < 5; k++) _at(s[2 * k] + b, (s[2 * k + 1] + i) % 10)],
    ..._rotateFace(face),
  ];
}

/// TNoodle's `bigTurn`, about DBR or D.
List<List<int>> _bigCycles(int face) {
  List<List<int>> wholeFaces(List<int> s) => [
    for (var i = 0; i < 10; i++) [for (var k = 0; k < 5; k++) _at(s[2 * k], (s[2 * k + 1] + i) % 10)],
    [for (var k = 0; k < 5; k++) _at(s[2 * k], 10)],
  ];
  List<List<int>> partFaces(List<int> s) => [
    for (var i = 0; i < 7; i++) [for (var k = 0; k < 5; k++) _at(s[2 * k], (s[2 * k + 1] + i) % 10)],
    [for (var k = 0; k < 5; k++) _at(s[2 * k], 10)],
  ];
  return face == Megaminx.dbr
      ? [
          ...partFaces([0, 1, 4, 3, 11, 1, 10, 1, 1, 1]),
          ...wholeFaces([2, 0, 3, 0, 7, 0, 6, 8, 9, 8]),
          ..._rotateFace(Megaminx.dbr),
        ]
      : [
          ...partFaces([1, 9, 2, 1, 3, 3, 4, 5, 5, 7]),
          ...wholeFaces([11, 0, 10, 8, 9, 6, 8, 4, 7, 2]),
          ..._rotateFace(Megaminx.d),
        ];
}
