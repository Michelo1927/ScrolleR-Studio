/// Funzioni numeriche che riproducono il comportamento di Python.
///
/// Il desktop è la fonte di verità: dove il Python usa `round()` o `sum()`, il motore deve dare
/// esattamente lo stesso risultato, altrimenti le disposizioni divergono.
library;

import 'dart:typed_data';

/// `round(x)` di Python: intero più vicino, con i casi a metà verso il pari
/// (2,5 → 2; 3,5 → 4). Il `round()` di Dart invece arrotonda via dallo zero.
int pyRound(double x) {
  if (x.isNaN || x.isInfinite) {
    throw ArgumentError.value(x, 'x', 'non si arrotonda a un intero');
  }
  final f = x.floorToDouble();
  final diff = x - f;
  final i = f.toInt();
  if (diff > 0.5) return i + 1;
  if (diff < 0.5) return i;
  return i.isEven ? i : i + 1;
}

/// `round(x, cifre)` di Python per i float: arrotondamento corretto del valore binario esatto,
/// con i casi esattamente a metà verso la cifra pari, poi il double più vicino al decimale ottenuto.
double pyRoundTo(double x, int cifre) {
  if (x.isNaN || x.isInfinite || x == 0.0) return x;
  RangeError.checkValueInInterval(cifre, 0, 15, 'cifre');
  final (m, e) = _esatto(x);
  final negativo = m.isNegative;
  var num = m.abs() * BigInt.from(10).pow(cifre);
  var den = BigInt.one;
  if (e >= 0) {
    num = num << e;
  } else {
    den = BigInt.one << -e;
  }
  var q = num ~/ den;
  final doppioResto = (num - q * den) * BigInt.two;
  if (doppioResto > den || (doppioResto == den && q.isOdd)) {
    q += BigInt.one;
  }
  final valore = double.parse('${q}e-$cifre');
  return negativo ? -valore : valore;
}

/// Mantissa intera ed esponente tali che x = m · 2^e esattamente.
(BigInt, int) _esatto(double x) {
  final dati = ByteData(8)..setFloat64(0, x);
  final alto = dati.getUint32(0);
  final basso = dati.getUint32(4);
  final negativo = (alto >> 31) == 1;
  final esponente = (alto >> 20) & 0x7FF;
  var mantissa = (BigInt.from(alto & 0xFFFFF) << 32) | BigInt.from(basso);
  int e;
  if (esponente == 0) {
    e = -1074;
  } else {
    mantissa |= BigInt.one << 52;
    e = esponente - 1075;
  }
  return (negativo ? -mantissa : mantissa, e);
}

/// `sum()` di Python 3.12+ su float: somma compensata di Neumaier, come in `bltinmodule.c`.
double pySum(Iterable<double> valori) {
  var somma = 0.0;
  var c = 0.0;
  for (final x in valori) {
    final t = somma + x;
    if (somma.abs() >= x.abs()) {
      c += (somma - t) + x;
    } else {
      c += (x - t) + somma;
    }
    somma = t;
  }
  if (c != 0.0 && c.isFinite) somma += c;
  return somma;
}

/// `math.ceil(a / b)` di Python (divisione vera, poi intero superiore).
int pyCeilDiv(num a, num b) => (a / b).ceil();

/// Uguaglianza profonda tra valori JSON (mappe, liste, numeri, testi), come `==` tra dict di Python
/// (1 == 1.0 vale vero).
bool jsonEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is num && b is num) return a == b;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || !jsonEquals(a[k], b[k])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!jsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// Copia profonda e non modificabile di un valore JSON.
Object? jsonFreeze(Object? v) {
  if (v is Map) {
    return Map<String, Object?>.unmodifiable(
      v.map((k, x) => MapEntry(k.toString(), jsonFreeze(x))),
    );
  }
  if (v is List) return List<Object?>.unmodifiable(v.map(jsonFreeze));
  return v;
}

/// Copia profonda e modificabile di un valore JSON.
Object? jsonCopy(Object? v) {
  if (v is Map) {
    return <String, Object?>{
      for (final e in v.entries) e.key.toString(): jsonCopy(e.value),
    };
  }
  if (v is List) return <Object?>[for (final x in v) jsonCopy(x)];
  return v;
}
