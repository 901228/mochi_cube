import "dart:typed_data";

import "cubies.dart";
import "moves.dart";

/// Phase 2 of the 4x4x4: with U and D done, sort the other four centre colours
/// so that every face has its own — up to the half turns phase 3 can finish.
///
/// The centres split into the sixteen U, D, F and B positions, whose two
/// classes can be arranged 6435 ways (the `ct` coordinate: 15 choose 8, the last
/// position being the reference), and the eight R and L positions, 35 ways
/// which with the wings' parity come to 70 (`rl`).
final class Center2 {
  /// What each of the 28 moves of phase 2 does to `rl`, `[rl * 28 + move]`.
  static final Int32List rlmv = Int32List(70 * 28);

  /// What each does to `ct`, `[ct * 28 + move]`.
  static final Uint16List ctmv = Uint16List(6435 * 28);

  /// Moves to a solved pair of coordinates, `[ct * 70 + rl]`. 255 until it is
  /// filled in.
  static final Uint8List ctprun = Uint8List(6435 * 35 * 2);

  /// Whether each of the 36 moves flips the parity the wings carry along.
  static const List<int> _pmv = [
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, //
    0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0,
  ];

  final List<int> rl = List.filled(8, 0);
  final List<int> ct = List.filled(16, 0);
  int parity = 0;

  static void init() {
    final c = Center2();

    for (var i = 0; i < 35 * 2; i++) {
      for (var m = 0; m < 28; m++) {
        c.setrl(i);
        c.move(move2std[m]);
        rlmv[i * 28 + m] = c.getrl();
      }
    }

    for (var i = 0; i < 6435; i++) {
      for (var m = 0; m < 28; m++) {
        c.setct(i);
        c.move(move2std[m]);
        ctmv[i * 28 + m] = c.getct();
      }
    }

    ctprun.fillRange(0, ctprun.length, 255);
    ctprun[0] = ctprun[18] = ctprun[28] = ctprun[46] = ctprun[54] = ctprun[56] = 0;
    var depth = 0;
    var done = 6;
    while (done != 6435 * 35 * 2) {
      for (var i = 0; i < 6435 * 35 * 2; i++) {
        if (ctprun[i] != depth) continue;
        final ct = i ~/ 70;
        final rl = i % 70;
        for (var m = 0; m < 23; m++) {
          final idx = ctmv[ct * 28 + m] * 70 + rlmv[rl * 28 + m];
          if (ctprun[idx] == 255) {
            ctprun[idx] = depth + 1;
            done++;
          }
        }
      }
      depth++;
    }
  }

  /// Read the centres of [c], with the wings' parity [edgeParity] alongside.
  void set(CenterCube c, int edgeParity) {
    for (var i = 0; i < 16; i++) {
      ct[i] = c.ct[i] % 3;
    }
    for (var i = 0; i < 8; i++) {
      rl[i] = c.ct[i + 16];
    }
    parity = edgeParity;
  }

  int getrl() {
    var idx = 0;
    var r = 4;
    for (var i = 6; i >= 0; i--) {
      if (rl[i] != rl[7]) {
        idx += cnk[i][r--];
      }
    }
    return idx * 2 + parity;
  }

  void setrl(int idx) {
    parity = idx & 1;
    idx >>= 1;
    var r = 4;
    rl[7] = 0;
    for (var i = 6; i >= 0; i--) {
      if (idx >= cnk[i][r]) {
        idx -= cnk[i][r--];
        rl[i] = 1;
      } else {
        rl[i] = 0;
      }
    }
  }

  int getct() {
    var idx = 0;
    var r = 8;
    for (var i = 14; i >= 0; i--) {
      if (ct[i] != ct[15]) {
        idx += cnk[i][r--];
      }
    }
    return idx;
  }

  void setct(int idx) {
    var r = 8;
    ct[15] = 0;
    for (var i = 14; i >= 0; i--) {
      if (idx >= cnk[i][r]) {
        idx -= cnk[i][r--];
        ct[i] = 1;
      } else {
        ct[i] = 0;
      }
    }
  }

  void move(int m) {
    parity ^= _pmv[m];
    final key = m % 3;
    switch (m ~/ 3) {
      case 0: // U
        swap4(ct, 0, 1, 2, 3, key);
      case 1: // R
        swap4(rl, 0, 1, 2, 3, key);
      case 2: // F
        swap4(ct, 8, 9, 10, 11, key);
      case 3: // D
        swap4(ct, 4, 5, 6, 7, key);
      case 4: // L
        swap4(rl, 4, 5, 6, 7, key);
      case 5: // B
        swap4(ct, 12, 13, 14, 15, key);
      case 6: // u
        swap4(ct, 0, 1, 2, 3, key);
        swap4(rl, 0, 5, 4, 1, key);
        swap4(ct, 8, 9, 12, 13, key);
      case 7: // r
        swap4(rl, 0, 1, 2, 3, key);
        swap4(ct, 1, 15, 5, 9, key);
        swap4(ct, 2, 12, 6, 10, key);
      case 8: // f
        swap4(ct, 8, 9, 10, 11, key);
        swap4(rl, 0, 3, 6, 5, key);
        swap4(ct, 3, 2, 5, 4, key);
      case 9: // d
        swap4(ct, 4, 5, 6, 7, key);
        swap4(rl, 3, 2, 7, 6, key);
        swap4(ct, 11, 10, 15, 14, key);
      case 10: // l
        swap4(rl, 4, 5, 6, 7, key);
        swap4(ct, 0, 8, 4, 14, key);
        swap4(ct, 3, 11, 7, 13, key);
      case 11: // b
        swap4(ct, 12, 13, 14, 15, key);
        swap4(rl, 1, 4, 7, 2, key);
        swap4(ct, 1, 0, 7, 6, key);
    }
  }
}
