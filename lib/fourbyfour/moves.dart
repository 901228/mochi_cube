import "dart:typed_data";

/// The 4x4x4's 36 moves, as threephase numbers them and as `nxnMoves(4)` does:
/// `3 * axis + power`, with the axes U R F D L B and then the same six turned
/// two layers deep, and the powers a quarter turn, a half turn and a quarter
/// turn back. The two numberings are the same, which is what lets this solver
/// speak the package's own [Algorithm] without translating.
const int uw1 = 18, uw2 = 19, uw3 = 20, rw1 = 21, rw2 = 22, rw3 = 23, fw1 = 24, fw2 = 25, fw3 = 26;
const int dw1 = 27, dw2 = 28, dw3 = 29, lw1 = 30, lw2 = 31, lw3 = 32, bw1 = 33, bw2 = 34, bw3 = 35;

/// "End of moves": the last move before the first one, so nothing is blocked.
const int eom = 36;

/// The moves phase 2 uses, as indices of the 36: every face turn, and the wide
/// turns that keep the centres in the shape phase 1 reached. Its last entry is
/// [eom].
const List<int> move2std = [
  0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, //
  uw2, rw1, rw2, rw3, fw2, dw2, lw1, lw2, lw3, bw2, eom,
];

/// The moves phase 3 uses: the half turns of the wide layers and a 3x3x3's own
/// subgroup of the face turns. Its last entry is [eom].
const List<int> move3std = [
  0, 1, 2, 4, 6, 7, 8, 9, 10, 11, 13, 15, 16, 17, //
  uw2, rw2, fw2, dw2, lw2, bw2, eom,
];

/// Whether move [j] is not worth making straight after move [i]: it turns the
/// same face, or the face opposite and it is the later of the two.
bool _blocked(int i, int j) =>
    i == 36 ? false : (i ~/ 3 == j ~/ 3) || ((i ~/ 3 % 3 == j ~/ 3 % 3) && (i > j));

/// [_blocked] over the moves of phase 2, `[last * 28 + next]`.
final Uint8List ckmv2 = Uint8List(29 * 28)
  ..setAll(0, [
    for (var i = 0; i < 29; i++)
      for (var j = 0; j < 28; j++) _blocked(move2std[i], move2std[j]) ? 1 : 0,
  ]);

/// [_blocked] over the moves of phase 3, `[last * 20 + next]`.
final Uint8List ckmv3 = Uint8List(21 * 20)
  ..setAll(0, [
    for (var i = 0; i < 21; i++)
      for (var j = 0; j < 20; j++) _blocked(move3std[i], move3std[j]) ? 1 : 0,
  ]);

/// For a move, the last move of its run of blocked ones: a search that has
/// found `m` out of reach can jump to here and carry on from the next.
Uint8List _skip(int count, Uint8List blocked, int columns) {
  final out = Uint8List(count);
  for (var i = 0; i < count; i++) {
    out[i] = count;
    for (var j = i; j < count; j++) {
      if (blocked[i * columns + j] == 0) {
        out[i] = j - 1;
        break;
      }
    }
  }
  return out;
}

final Uint8List skipAxis2 = _skip(28, ckmv2, 28);
final Uint8List skipAxis3 = _skip(20, ckmv3, 20);

/// `n` choose `k`, for `n` and `k` up to 24.
final List<List<int>> cnk = _cnk();

List<List<int>> _cnk() {
  final table = [for (var i = 0; i < 25; i++) List.filled(25, 0)];
  for (var i = 0; i < 25; i++) {
    table[i][i] = 1;
    table[i][0] = 1;
  }
  for (var i = 1; i < 25; i++) {
    for (var j = 1; j <= i; j++) {
      table[i][j] = table[i - 1][j] + table[i - 1][j - 1];
    }
  }
  return table;
}

/// Four entries moved the way threephase moves them: [key] 0 cycles a to b to
/// c to d, 1 swaps a with c and b with d, and 2 cycles the other way.
void swap4(List<int> arr, int a, int b, int c, int d, int key) {
  switch (key) {
    case 0:
      final temp = arr[d];
      arr[d] = arr[c];
      arr[c] = arr[b];
      arr[b] = arr[a];
      arr[a] = temp;
    case 1:
      var temp = arr[a];
      arr[a] = arr[c];
      arr[c] = temp;
      temp = arr[b];
      arr[b] = arr[d];
      arr[d] = temp;
    case 2:
      final temp = arr[a];
      arr[a] = arr[b];
      arr[b] = arr[c];
      arr[c] = arr[d];
      arr[d] = temp;
  }
}

/// The parity of a permutation, 0 for even.
int permutationParity(List<int> arr) {
  var parity = 0;
  for (var i = 0; i < arr.length; i++) {
    for (var j = i; j < arr.length; j++) {
      if (arr[i] > arr[j]) parity ^= 1;
    }
  }
  return parity;
}

/// The arrangement of 0 to 7 numbered [idx] in the factorial number system,
/// written into [arr]. The corner permutations of the 3x3x3.
void set8Perm(List<int> arr, int idx) {
  const fact = [1, 1, 2, 6, 24, 120, 720, 5040];
  var val = 0x76543210;
  for (var i = 0; i < 7; i++) {
    final p = fact[7 - i];
    var v = idx ~/ p;
    idx -= v * p;
    v <<= 2;
    arr[i] = (val >> v) & 0xf;
    final m = (1 << v) - 1;
    val = (val & m) + ((val >> 4) & ~m);
  }
  arr[7] = val;
}
