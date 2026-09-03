import "cubie_cube.dart";
import "symmetry.dart";

/// A raw coordinate reduced modulo the 16 symmetries.
///
/// Two cube states related by a symmetry are the same distance from solved, so
/// a table only needs one entry per equivalence class. This is where min2phase
/// gets its small tables: the 40320 edge permutations collapse to a few
/// thousand classes.
///
/// The three arrays are the standard trio:
///  * [sym2raw] maps a class index to the smallest raw coordinate in it, its
///    representative.
///  * [raw2sym] maps a raw coordinate to `class << 4 | s`, where applying
///    symmetry `s` to the representative produces that raw coordinate.
///  * [symState] is a bitmask per class of the symmetries that fix the
///    representative — its stabiliser. Classes with a non-trivial stabiliser
///    are the ones smaller than the full 16 states.
class SymCoord {
  /// Class index -> representative raw coordinate.
  final List<int> sym2raw;

  /// Raw coordinate -> `class << 4 | symmetry`.
  final List<int> raw2sym;

  /// Class index -> bitmask of symmetries fixing the representative.
  final List<int> symState;

  /// Number of equivalence classes.
  final int classCount;

  /// Number of raw coordinates that were reduced.
  final int rawCount;

  /// The symmetry indices the reduction was taken over.
  final List<int> syms;

  const SymCoord._(this.sym2raw, this.raw2sym, this.symState, this.classCount, this.rawCount, this.syms);

  /// Split a [raw2sym] entry back into its class and symmetry.
  static (int classIndex, int symmetry) split(int entry) => (entry >> 4, entry & 0xF);

  /// Reduce a coordinate of [rawCount] values.
  ///
  /// [write] puts a raw coordinate onto a cube, [read] reads it back, and the
  /// conjugation in between is the group action. Both are supplied by the
  /// caller so the same routine serves twist, flip and the permutations.
  ///
  /// [syms] selects the symmetries to reduce over, defaulting to all 16. It
  /// must be a subgroup, otherwise the orbits are not well defined; pass a
  /// subset only to reproduce min2phase's phase 1 tables, which use 8.
  factory SymCoord.reduce({
    required int rawCount,
    required void Function(CubieCube cube, int value) write,
    required int Function(CubieCube cube) read,
    List<int>? syms,
  }) {
    final group = syms ?? List<int>.generate(symCount, (i) => i);
    const unset = -1;
    final raw2sym = List<int>.filled(rawCount, unset);
    final sym2raw = <int>[];
    final symState = <int>[];

    for (var raw = 0; raw < rawCount; raw++) {
      if (raw2sym[raw] != unset) {
        // Already covered as a symmetry of an earlier representative.
        continue;
      }

      final classIndex = sym2raw.length;
      final cube = CubieCube();
      write(cube, raw);

      var stabiliser = 0;
      for (final s in group) {
        final image = read(conjugate(cube, s));
        if (image == raw) {
          stabiliser |= 1 << s;
        }
        if (raw2sym[image] == unset) {
          raw2sym[image] = classIndex << 4 | s;
        }
      }

      sym2raw.add(raw);
      symState.add(stabiliser);
    }

    return SymCoord._(sym2raw, raw2sym, symState, sym2raw.length, rawCount, group);
  }
}

/// The 8 symmetries phase 1 reduces over: the even indices of [cubeSym].
///
/// Reducing the edge flip over all 16 is **wrong**. Checked against the exact
/// raw distances in the kociemba tables, a 16-symmetry reduction puts states
/// with different distances in the same class for 256424 of the 1013760
/// (udslice, flip) pairs; over this subgroup there are no conflicts. The
/// mirror symmetries are the problem: edge orientation is defined relative to
/// the F/B faces and does not survive reflection.
///
/// This subgroup reproduces min2phase's documented counts exactly, 324 twist
/// and 336 flip classes, which is a good sign the reduction matches the
/// reference implementation.
const List<int> phase1Syms = [0, 2, 4, 6, 8, 10, 12, 14];

/// Corner orientation, reduced over all 16 symmetries. Raw[0, 2187)
///
/// Corner orientation, unlike edge flip, does survive the mirrors: the full
/// group is conflict-free against the raw distances and halves the table, 168
/// classes against the 324 min2phase uses.
final SymCoord twistSym = SymCoord.reduce(
  rawCount: 2187,
  write: (c, v) => c.twist = v,
  read: (c) => c.twist,
);

/// Corner orientation reduced over [phase1Syms], matching min2phase. Raw[0, 2187)
///
/// Kept for comparison against [twistSym]; the smaller [twistSym] is the one
/// to build the pruning table from.
final SymCoord twistSym8 = SymCoord.reduce(
  rawCount: 2187,
  write: (c, v) => c.twist = v,
  read: (c) => c.twist,
  syms: phase1Syms,
);

/// Edge orientation, reduced over [phase1Syms]. Raw[0, 2048)
final SymCoord flipSym = SymCoord.reduce(
  rawCount: 2048,
  write: (c, v) => c.flip = v,
  read: (c) => c.flip,
  syms: phase1Syms,
);

/// Corner permutation, reduced. Raw[0, 8!)
///
/// NOTE: only the structure of this reduction is verified so far, not that it
/// is conflict-free against the true phase 2 distances the way [twistSym] and
/// [flipSym] are. Run that check before building the phase 2 pruning tables.
final SymCoord cpermSym = SymCoord.reduce(
  rawCount: 40320,
  write: (c, v) => c.cperm = v,
  read: (c) => c.cperm,
);

/// Permutation of the 8 U/D edges, reduced. Raw[0, 8!)
final SymCoord epermSym = SymCoord.reduce(
  rawCount: 40320,
  write: (c, v) => c.eperm = v,
  read: (c) => c.eperm,
);
