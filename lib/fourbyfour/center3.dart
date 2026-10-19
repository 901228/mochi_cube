import "dart:typed_data";

import "cubies.dart";
import "moves.dart";

/// Phase 3 of the 4x4x4: with every centre colour on the right axis, finish the
/// centres and pair the wings using only moves that keep both done, so the
/// result is a 3x3x3.
///
/// The three axes' centres are each 35 arrangements, the R and L ones in 12
/// that the other two allow, and a parity bit: 29400 states in all, which is
/// few enough to hold the exact number of moves to solve for every one.
final class Center3 {
  /// What each of the 20 moves of phase 3 does, `[state * 20 + move]`.
  static final Uint16List ctmove = Uint16List(35 * 35 * 12 * 2 * 20);

  /// Whether each of the 20 moves flips the parity.
  static const List<int> _pmove = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1];

  /// Moves to solved, for each of the 29400 states. 255 until it is filled in.
  static final Uint8List prun = Uint8List(35 * 35 * 12 * 2);

  /// The 12 arrangements of the R and L centres that are reachable, as
  /// combinations of 8 choose 4, and the way back.
  static const List<int> rl2std = [0, 9, 14, 23, 27, 28, 41, 42, 46, 55, 60, 69];
  static final List<int> std2rl = _std2rl();

  static List<int> _std2rl() {
    final out = List.filled(70, 0);
    for (var i = 0; i < 12; i++) {
      out[rl2std[i]] = i;
    }
    return out;
  }

  final List<int> ud = List.filled(8, 0);
  final List<int> rl = List.filled(8, 0);
  final List<int> fb = List.filled(8, 0);
  int parity = 0;

  static void init() {
    final c = Center3();
    for (var i = 0; i < 35 * 35 * 12 * 2; i++) {
      for (var m = 0; m < 20; m++) {
        c.setct(i);
        c.move(m);
        ctmove[i * 20 + m] = c.getct();
      }
    }

    prun.fillRange(0, prun.length, 255);
    prun[0] = 0;
    var depth = 0;
    var done = 1;
    while (done != 29400) {
      for (var i = 0; i < 29400; i++) {
        if (prun[i] != depth) continue;
        for (var m = 0; m < 17; m++) {
          final next = ctmove[i * 20 + m];
          if (prun[next] == 255) {
            prun[next] = depth + 1;
            done++;
          }
        }
      }
      depth++;
    }
  }

  /// Read the centres of [c], with [edgeParity] the wings' and corners' parity.
  void set(CenterCube c, int edgeParity) {
    final parity =
        (((c.ct[0] % 3 > c.ct[8] % 3) != (c.ct[8] % 3 > c.ct[16] % 3)) != (c.ct[0] % 3 > c.ct[16] % 3))
        ? 0
        : 1;
    for (var i = 0; i < 8; i++) {
      ud[i] = (c.ct[i] ~/ 3) ^ 1;
      fb[i] = (c.ct[i + 8] ~/ 3) ^ 1;
      rl[i] = (c.ct[i + 16] ~/ 3) ^ 1 ^ parity;
    }
    this.parity = parity ^ edgeParity;
  }

  int getct() {
    var idx = 0;
    var r = 4;
    for (var i = 6; i >= 0; i--) {
      if (ud[i] != ud[7]) {
        idx += cnk[i][r--];
      }
    }
    idx *= 35;
    r = 4;
    for (var i = 6; i >= 0; i--) {
      if (fb[i] != fb[7]) {
        idx += cnk[i][r--];
      }
    }
    idx *= 12;
    final check = fb[7] ^ ud[7];
    var idxrl = 0;
    r = 4;
    for (var i = 7; i >= 0; i--) {
      if (rl[i] != check) {
        idxrl += cnk[i][r--];
      }
    }
    return parity + 2 * (idx + std2rl[idxrl]);
  }

  void setct(int idx) {
    parity = idx & 1;
    idx >>= 1;
    var idxrl = rl2std[idx % 12];
    idx ~/= 12;
    var r = 4;
    for (var i = 7; i >= 0; i--) {
      rl[i] = 0;
      if (idxrl >= cnk[i][r]) {
        idxrl -= cnk[i][r--];
        rl[i] = 1;
      }
    }
    var idxfb = idx % 35;
    idx ~/= 35;
    r = 4;
    fb[7] = 0;
    for (var i = 6; i >= 0; i--) {
      if (idxfb >= cnk[i][r]) {
        idxfb -= cnk[i][r--];
        fb[i] = 1;
      } else {
        fb[i] = 0;
      }
    }
    r = 4;
    ud[7] = 0;
    for (var i = 6; i >= 0; i--) {
      if (idx >= cnk[i][r]) {
        idx -= cnk[i][r--];
        ud[i] = 1;
      } else {
        ud[i] = 0;
      }
    }
  }

  void move(int i) {
    parity ^= _pmove[i];
    switch (i) {
      case 0 || 1 || 2: // U
        swap4(ud, 0, 1, 2, 3, i % 3);
      case 3: // R2
        swap4(rl, 0, 1, 2, 3, 1);
      case 4 || 5 || 6: // F
        swap4(fb, 0, 1, 2, 3, (i - 1) % 3);
      case 7 || 8 || 9: // D
        swap4(ud, 4, 5, 6, 7, (i - 1) % 3);
      case 10: // L2
        swap4(rl, 4, 5, 6, 7, 1);
      case 11 || 12 || 13: // B
        swap4(fb, 4, 5, 6, 7, (i + 1) % 3);
      case 14: // u2
        swap4(ud, 0, 1, 2, 3, 1);
        swap4(rl, 0, 5, 4, 1, 1);
        swap4(fb, 0, 5, 4, 1, 1);
      case 15: // r2
        swap4(rl, 0, 1, 2, 3, 1);
        swap4(fb, 1, 4, 7, 2, 1);
        swap4(ud, 1, 6, 5, 2, 1);
      case 16: // f2
        swap4(fb, 0, 1, 2, 3, 1);
        swap4(ud, 3, 2, 5, 4, 1);
        swap4(rl, 0, 3, 6, 5, 1);
      case 17: // d2
        swap4(ud, 4, 5, 6, 7, 1);
        swap4(rl, 3, 2, 7, 6, 1);
        swap4(fb, 3, 2, 7, 6, 1);
      case 18: // l2
        swap4(rl, 4, 5, 6, 7, 1);
        swap4(fb, 0, 3, 6, 5, 1);
        swap4(ud, 0, 3, 4, 7, 1);
      case 19: // b2
        swap4(fb, 4, 5, 6, 7, 1);
        swap4(ud, 0, 7, 6, 1, 1);
        swap4(rl, 1, 4, 7, 2, 1);
    }
  }
}
