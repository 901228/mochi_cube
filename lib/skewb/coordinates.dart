import "../table_storage.dart";
import "cube.dart";

/// One part of a Skewb's state — its corners or its centres — numbered densely.
///
/// A turn takes corner stickers to corner stickers and centres to centres, so
/// each part moves on its own and the whole state is the pair. Rather than
/// working out which twists and permutations each part can reach, the states
/// are found by walking every turn from solved and numbered in the order they
/// turn up; there is then nothing to get wrong about parity or twist sums, and
/// a state not in [states] cannot be reached.
///
/// The numbering follows from the turns and the order of [skewbMoves], and the
/// distance table is indexed by it, so changing either means bumping the
/// table's cache version.
final class SkewbPart {
  /// The corners: 8748 states, the up-front-right corner standing still.
  static final SkewbPart corners = SkewbPart._([
    for (var i = 0; i < nSkewbFacelets; i++)
      if (i % 5 != centreSlot) i,
  ]);

  /// The centres: 360 states, the even permutations of six.
  static final SkewbPart centres = SkewbPart._([for (var face = 0; face < 6; face++) face * 5 + centreSlot]);

  /// The stickers that make up this part.
  final List<int> slots;

  /// Every reachable state, as the colours of [slots], solved first.
  final List<List<int>> states = [];

  final Map<String, int> _index = {};

  /// Where each move takes each state.
  late final MovingTable move;

  SkewbPart._(this.slots) {
    _add(_read(SkewbCube().facelets));

    final rows = <List<int>>[];
    for (var state = 0; state < states.length; state++) {
      rows.add([
        for (var m = 0; m < skewbMoves.count; m++)
          () {
            final cube = SkewbCube();
            write(cube.facelets, state);
            final turned = _read((cube..applyMove(m)).facelets);
            return _index[_key(turned)] ?? _add(turned);
          }(),
      ]);
    }

    move = MovingTable.filled(states.length, skewbMoves.count);
    for (var state = 0; state < states.length; state++) {
      for (var m = 0; m < skewbMoves.count; m++) {
        move[(state, m)] = rows[state][m];
      }
    }
  }

  int get length => states.length;

  /// The state [facelets] show for this part, or null if it cannot be reached.
  int? indexOf(List<int> facelets) => _index[_key(_read(facelets))];

  /// Paint state [index] of this part onto [facelets].
  void write(List<int> facelets, int index) {
    final state = states[index];
    for (var i = 0; i < slots.length; i++) {
      facelets[slots[i]] = state[i];
    }
  }

  List<int> _read(List<int> facelets) => [for (final slot in slots) facelets[slot]];

  int _add(List<int> state) {
    _index[_key(state)] = states.length;
    states.add(state);
    return states.length - 1;
  }

  static String _key(List<int> state) => String.fromCharCodes(state);
}
