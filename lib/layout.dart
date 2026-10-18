/// What every layout can say about itself: how big it is, and how to fit it in.
///
/// The puzzles do not all draw the same way — a cube is polygons, a Clock is
/// circles and a Square-1 is polygons that change with the state — so this is
/// the part they share, and all a caller needs to size the box it is going to
/// draw into.
///
/// It is `sealed` so that a caller's switch over the kinds is exhaustive: adding
/// a fifth kind of layout should break the drawing code
/// rather than fall quietly into a default branch. That is also why the four
/// types live here together rather than beside the puzzles they describe — a
/// sealed type's subtypes must share its library.
sealed class Layout {
  const Layout();

  /// The width of the drawing, in the same units as the points.
  double get width;

  /// The height of the drawing, in the same units as the points.
  double get height;

  /// How to fit this layout into a box of [boxWidth] by [boxHeight].
  ///
  /// Multiply a point by [scale] and then add [dx] and [dy]: the result is the
  /// layout as large as it will go, centred.
  ({double scale, double dx, double dy}) fitInto(double boxWidth, double boxHeight) {
    final scale = boxWidth / width < boxHeight / height ? boxWidth / width : boxHeight / height;
    return (scale: scale, dx: (boxWidth - width * scale) / 2, dy: (boxHeight - height * scale) / 2);
  }
}

/// A point in a [PuzzleLayout]. `x` runs right and `y` runs down, as on a screen.
typedef Point = (double x, double y);

/// Where a puzzle's stickers sit when it is drawn flat.
///
/// Geometry and nothing else. There are no colours here, no line widths and no
/// gaps between stickers, for the same reason the rest of the package has none:
/// a caller draws with whatever scheme it likes, and insetting a polygon to
/// leave a gap is one line of its own code.
///
/// What is here is the part that is puzzle knowledge rather than drawing
/// preference — which sticker is next to which, and how a face folds out — so
/// that a front end does not have to work the net out again.
///
/// The polygons are index-matched to the facelets, so `stickers[i]` is where
/// `toFacelets()[i]` goes.
class PuzzleLayout extends Layout {
  @override
  final double width;

  @override
  final double height;

  /// One polygon per sticker, in the facelet order of the puzzle it belongs to.
  ///
  /// Wound the same way round for every sticker, so a caller can tell an
  /// outline from a hole if it wants to.
  final List<List<Point>> stickers;

  const PuzzleLayout({required this.width, required this.height, required this.stickers});

  /// How many stickers there are.
  int get length => stickers.length;

  /// The polygon of one sticker.
  List<Point> operator [](int facelet) => stickers[facelet];
}

/// Where a Rubik's Clock's dials sit when it is drawn flat.
///
/// The two sides side by side, front on the left, each a three by three grid of
/// dials with the four pins at the middles of its four corner blocks. Nothing
/// here is a polygon, so unlike the other puzzles this is circles rather than a
/// [PuzzleLayout].
///
/// Geometry only, as everywhere else: no colours, no hands, no dial faces.
class ClockLayout extends Layout {
  @override
  final double width;

  @override
  final double height;

  /// The middle of each of the eighteen dials, in the order `toDials()` gives.
  final List<Point> dials;

  /// How big a dial is.
  final double dialRadius;

  /// The middle of each pin: the four of the front, then the four of the back.
  ///
  /// In the order `clockCorners` gives, so pin `i` is the one that drives the
  /// block of dials at corner `clockCorners[i]`. Which way a pin is pushed is
  /// not part of a clock's state and so is not here; these are only where they
  /// are.
  final List<Point> pins;

  /// How big a pin is.
  final double pinRadius;

  const ClockLayout({
    required this.width,
    required this.height,
    required this.dials,
    required this.dialRadius,
    required this.pins,
    required this.pinRadius,
  });
}

/// Where a Square-1's stickers are drawn, which depends on the state.
///
/// The other puzzles keep their stickers in fixed places and only change
/// colour. A Square-1 changes shape: a slot holds an edge, a 30 degree wedge,
/// or half a corner, a 60 degree kite, and which it is moves as the puzzle
/// turns. So rather than one polygon per number of the state, this holds the
/// polygons a piece would have in each slot and [stickers] picks out the ones a
/// state uses — the way csTimer and the official scrambler draw it, a kite for
/// a corner rather than two wedges.
///
/// The state is the 24 slots' pieces and then the middle, as the Square-1's own
/// library writes them.
class Square1Layout extends Layout {
  @override
  final double width;

  @override
  final double height;

  /// For each slot, an edge there: its top or bottom sticker, then its side.
  final List<List<List<Point>>> edges;

  /// For each slot, a corner starting there and running into the next: its top
  /// or bottom sticker, then the side over this slot, then the side over the
  /// next.
  final List<List<List<Point>>> corners;

  /// The middle layer's front: the left piece, then the right one square and
  /// the right one turned over, which shows its narrower back.
  final List<List<Point>> middle;

  /// The faces each piece shows, in the order [edges] and [corners] draw them.
  final List<List<int>> pieceFaces;

  /// The faces the middle shows: the left, the right square, the right turned.
  final List<int> middleFaces;

  const Square1Layout({
    required this.width,
    required this.height,
    required this.edges,
    required this.corners,
    required this.middle,
    required this.pieceFaces,
    required this.middleFaces,
  });

  /// How many numbers a state has: 24 slots and the middle.
  int get length => edges.length + 1;

  /// Every sticker [state] shows, each with the face whose colour it is.
  List<(List<Point>, int)> stickers(List<int> state) {
    final shown = <(List<Point>, int)>[];
    for (var slot = 0; slot < edges.length; slot++) {
      final piece = state[slot];
      final faces = pieceFaces[piece];
      if (faces.length == 2) {
        for (var i = 0; i < 2; i++) {
          shown.add((edges[slot][i], faces[i]));
        }
        continue;
      }
      // A corner is drawn from its first slot. The one before it in the same
      // layer, going round past the twelfth, tells which that is.
      final previous = slot % 12 == 0 ? slot + 11 : slot - 1;
      if (state[previous] == piece) continue;
      for (var i = 0; i < 3; i++) {
        shown.add((corners[slot][i], faces[i]));
      }
    }
    final flipped = state[edges.length];
    shown
      ..add((middle[0], middleFaces[0]))
      ..add((middle[1 + flipped], middleFaces[1 + flipped]));
    return shown;
  }
}
