/// The counting helpers of Levi Gibson's fto3phase.
library;

const List<int> _factorial = [1, 1, 2, 6, 24, 120, 720, 5040, 40320, 362880, 3628800, 39916800, 479001600];

/// `n` choose `k`, for `n` up to 12.
int nCr(int n, int k) {
  if (k < 0 || k > n) return 0;
  return _factorial[n] ~/ (_factorial[k] * _factorial[n - k]);
}

int fact(int n) => _factorial[n];

int _bitCount(int value) {
  var count = 0;
  for (; value != 0; value &= value - 1) {
    count++;
  }
  return count;
}

void swap(List<int> arr, int i1, int i2) {
  final tmp = arr[i2];
  arr[i2] = arr[i1];
  arr[i1] = tmp;
}

/// Whether [perm], an arrangement of 0 to n - 1, is odd.
bool isParity(List<int> perm) {
  final p = [...perm];
  var swaps = 0;
  for (var i = 0; i < p.length; i++) {
    while (p[i] != i) {
      swap(p, i, p[i]);
      swaps++;
    }
  }
  return swaps.isOdd;
}

/// The lexicographic rank of the first [size] entries of [arr], halved when
/// only even arrangements are counted.
int packPerm(List<int> arr, bool parity, [int? size]) {
  final n = size ?? arr.length;
  var index = 0;
  var seen = 0;
  for (var i = 0; i < n; i++) {
    final e = arr[i];
    seen |= 1 << ((n - 1) - e);
    final lehmerDigit = e - _bitCount(seen >> (n - e));
    index += _factorial[(n - 1) - i] * lehmerDigit;
  }
  return parity ? index ~/ 2 : index;
}

/// The arrangement [packPerm] numbered [idx], into [arr].
void unpackPerm(List<int> arr, int idx, bool parity, [int? size]) {
  final n = size ?? arr.length;
  if (parity) idx *= 2;
  final used = List.filled(n, false);
  for (var i = 0; i < n; i++) {
    final lehmerDigit = idx ~/ _factorial[(n - 1) - i];
    idx %= _factorial[(n - 1) - i];
    var count = 0;
    var e = -1;
    for (var v = 0; v < n; v++) {
      if (!used[v]) {
        if (count == lehmerDigit) {
          e = v;
          break;
        }
        count++;
      }
    }
    arr[i] = e;
    used[e] = true;
  }
  if (parity && isParity(arr.sublist(0, n))) {
    swap(arr, n - 2, n - 1);
  }
}

/// The rank of a set of positions, given in ascending order.
int packSubset(List<int> idx) {
  var index = 0;
  for (var i = idx.length - 1; i >= 0; i--) {
    index += nCr(idx[i], i + 1);
  }
  return index;
}

/// The set of positions [packSubset] numbered [idx], into [arr].
void unpackSubset(List<int> arr, int idx) {
  final subsetSize = arr.length;
  var k = subsetSize;
  var remaining = idx;
  for (var pos = 0; pos < subsetSize; pos++) {
    var c = k - 1;
    while (nCr(c + 1, k) <= remaining) {
      c++;
    }
    arr[subsetSize - 1 - pos] = c;
    remaining -= nCr(c, k);
    k--;
  }
}
