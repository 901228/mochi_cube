import "dart:math";

import "package:mochi_cube/mochi_cube.dart";
import "package:test/test.dart";

/// The permutation coordinates against the implementation they replaced.
///
/// min2phase numbers a permutation in the factorial number system, and kept the
/// values still to be placed in one 64-bit register, four bits each. That
/// cannot run on the web, so it is a small list now — and this file is what
/// says the *numbering* did not change with it.
///
/// The distinction matters more than it looks. A rewrite that produced a
/// different but self-consistent bijection would pass every other test in the
/// suite, because everything else is built through these same two functions and
/// would simply agree with itself. What it would break is the cached table
/// files: `min2phase-phase1.bin` is indexed by these coordinates, so a cache
/// written before the change would be loaded afterwards, silently trusted, and
/// read at the wrong offsets. Proving the encoding identical is what says no
/// cache version needs bumping.
///
/// The two functions below are min2phase's originals, transcribed to work on a
/// plain list of values rather than on a packed cube. They are the reference;
/// [CubieCube] is what is being checked.
void main() {
  group("corner permutation", () {
    test("agrees on all 40320 orderings, both ways", () {
      final cube = CubieCube();
      for (var idx = 0; idx < 40320; idx++) {
        cube.cperm = idx;
        expect(_permutationOf(cube.cornerState, 8, isEdge: false), _oldSetNPerm(idx, 8));
        expect(cube.cperm, idx);
        expect(_oldGetNPerm(_permutationOf(cube.cornerState, 8, isEdge: false), 8), idx);
      }
    });
  });

  group("edge permutation", () {
    test("agrees on all 40320 orderings of the eight, both ways", () {
      final cube = CubieCube();
      for (var idx = 0; idx < 40320; idx++) {
        cube.eperm = idx;
        expect(_permutationOf(cube.edgeState, 8, isEdge: true), _oldSetNPerm(idx, 8));
        expect(cube.eperm, idx);
      }
    });

    // 12! is 479001600, too many to walk, so this is a sample plus the ends.
    test("agrees on a sample of the 479001600 orderings of all twelve", () {
      final cube = CubieCube();
      final random = Random(20260904);
      final indices = <int>[
        for (var i = 0; i < 2000; i++) i,
        for (var i = 0; i < 2000; i++) 479001600 - 1 - i,
        for (var i = 0; i < 100000; i++) random.nextInt(479001600),
      ];

      for (final idx in indices) {
        cube.eperm12 = idx;
        expect(_permutationOf(cube.edgeState, 12, isEdge: true), _oldSetNPerm(idx, 12));
        expect(cube.eperm12, idx);
      }
    });
  });

  group("slice permutation", () {
    test("agrees on all 24 orderings", () {
      final cube = CubieCube();
      for (var idx = 0; idx < 24; idx++) {
        cube.mperm = idx;
        expect(_permutationOf(cube.edgeState, 12, isEdge: true), _oldSetNPerm(idx, 12));
        expect(cube.mperm, idx);
      }
    });
  });

  test("the flip and orientation bits beside the permutation are left alone", () {
    // The permutation shares a byte with the flip or the twist, so a setter
    // that wrote the whole entry would corrupt the other coordinate rather than
    // fail outright.
    final cube = CubieCube();
    cube.flip = 1234;
    cube.twist = 567;
    cube.eperm12 = 89012;
    cube.cperm = 3456;
    expect(cube.flip, 1234);
    expect(cube.twist, 567);
    expect(cube.eperm12, 89012);
    expect(cube.cperm, 3456);
  });
}

/// The permutation [state] holds, as plain values.
List<int> _permutationOf(List<int> state, int n, {required bool isEdge}) => [
  for (var i = 0; i < n; i++) isEdge ? state[i] >> 1 : state[i] & 7,
];

/// min2phase's original, on a 64-bit register: the ordering [perm] is.
int _oldGetNPerm(List<int> perm, int n) {
  var idx = 0;
  var val = 0xFEDCBA9876543210;
  for (var i = 0; i < n - 1; i++) {
    final v = perm[i] << 2;
    idx = (n - i) * idx + (val >> v & 0xf);
    val -= 0x1111111111111110 << v;
  }
  return idx;
}

/// min2phase's original, on a 64-bit register: the ordering [idx] names.
List<int> _oldSetNPerm(int idx, int n) {
  var val = 0xFEDCBA9876543210;
  var extract = 0;
  var rest = idx;
  for (var p = 2; p <= n; p++) {
    extract = extract << 4 | rest % p;
    rest ~/= p;
  }

  final perm = List.filled(n, 0);
  for (var i = 0; i < n - 1; i++) {
    final v = (extract & 0xf) << 2;
    extract >>= 4;
    perm[i] = val >> v & 0xf;
    final m = (1 << v) - 1;
    val = val & m | val >> 4 & ~m;
  }
  perm[n - 1] = val & 0xf;
  return perm;
}
