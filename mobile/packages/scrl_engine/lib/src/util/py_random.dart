/// Generatore di numeri casuali identico a `random.Random` di Python (Mersenne Twister MT19937).
///
/// Serve a Polaroid: con lo stesso `layout_seed` le due app devono inclinare e spostare le foto
/// allo stesso modo. Semina da intero come `random.seed(int)` (chiave = blocchi da 32 bit di |seme|).
library;

class PyRandom {
  static const int _n = 624;
  static const int _m = 397;
  static const int _mask32 = 0xFFFFFFFF;

  final List<int> _mt = List<int>.filled(_n, 0);
  int _mti = _n + 1;

  PyRandom(int seme) {
    seed(seme);
  }

  /// `random.seed(seme)` con un intero.
  void seed(int seme) {
    var v = seme.abs();
    final chiave = <int>[];
    if (v == 0) {
      chiave.add(0);
    } else {
      while (v > 0) {
        chiave.add(v & _mask32);
        v >>= 32;
      }
    }
    _initByArray(chiave);
  }

  void _initGenrand(int s) {
    _mt[0] = s & _mask32;
    for (var i = 1; i < _n; i++) {
      final prev = _mt[i - 1];
      _mt[i] = (1812433253 * (prev ^ (prev >> 30)) + i) & _mask32;
    }
    _mti = _n;
  }

  void _initByArray(List<int> chiave) {
    _initGenrand(19650218);
    var i = 1;
    var j = 0;
    final len = chiave.length;
    var k = _n > len ? _n : len;
    for (; k > 0; k--) {
      final prev = _mt[i - 1];
      _mt[i] =
          ((_mt[i] ^ (((prev ^ (prev >> 30)) * 1664525) & _mask32)) +
              chiave[j] +
              j) &
          _mask32;
      i++;
      j++;
      if (i >= _n) {
        _mt[0] = _mt[_n - 1];
        i = 1;
      }
      if (j >= len) j = 0;
    }
    for (k = _n - 1; k > 0; k--) {
      final prev = _mt[i - 1];
      _mt[i] =
          ((_mt[i] ^ (((prev ^ (prev >> 30)) * 1566083941) & _mask32)) - i) &
          _mask32;
      i++;
      if (i >= _n) {
        _mt[0] = _mt[_n - 1];
        i = 1;
      }
    }
    _mt[0] = 0x80000000;
  }

  /// Un intero da 32 bit (`genrand_uint32`).
  int _genrand() {
    if (_mti >= _n) {
      int y;
      var kk = 0;
      for (; kk < _n - _m; kk++) {
        y = (_mt[kk] & 0x80000000) | (_mt[kk + 1] & 0x7FFFFFFF);
        _mt[kk] = _mt[kk + _m] ^ (y >> 1) ^ ((y & 1) != 0 ? 0x9908B0DF : 0);
      }
      for (; kk < _n - 1; kk++) {
        y = (_mt[kk] & 0x80000000) | (_mt[kk + 1] & 0x7FFFFFFF);
        _mt[kk] =
            _mt[kk + (_m - _n)] ^ (y >> 1) ^ ((y & 1) != 0 ? 0x9908B0DF : 0);
      }
      y = (_mt[_n - 1] & 0x80000000) | (_mt[0] & 0x7FFFFFFF);
      _mt[_n - 1] = _mt[_m - 1] ^ (y >> 1) ^ ((y & 1) != 0 ? 0x9908B0DF : 0);
      _mti = 0;
    }
    var y = _mt[_mti++];
    y ^= y >> 11;
    y ^= (y << 7) & 0x9D2C5680;
    y ^= (y << 15) & 0xEFC60000;
    y ^= y >> 18;
    return y & _mask32;
  }

  /// `random.random()`: float in [0, 1) con 53 bit.
  double random() {
    final a = _genrand() >> 5;
    final b = _genrand() >> 6;
    return (a * 67108864.0 + b) * (1.0 / 9007199254740992.0);
  }

  /// `random.uniform(a, b)`.
  double uniform(double a, double b) => a + (b - a) * random();

  /// `random.getrandbits(k)` per 0 < k ≤ 32.
  int getrandbits(int k) {
    RangeError.checkValueInInterval(k, 1, 32, 'k');
    return _genrand() >> (32 - k);
  }

  /// `random.randrange(n)` (con `_randbelow`, per n ≤ 2^32).
  int randrange(int n) {
    if (n <= 0) throw ArgumentError.value(n, 'n', 'deve essere positivo');
    final k = n.bitLength;
    var r = getrandbits(k);
    while (r >= n) {
      r = getrandbits(k);
    }
    return r;
  }

  /// `random.shuffle(lista)` (Fisher–Yates dall'ultimo elemento, come Python).
  void shuffle<T>(List<T> lista) {
    for (var i = lista.length - 1; i > 0; i--) {
      final j = randrange(i + 1);
      final t = lista[i];
      lista[i] = lista[j];
      lista[j] = t;
    }
  }
}
