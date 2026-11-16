import 'dart:convert';
import 'dart:io';

import 'package:scrl_engine/scrl_engine.dart';
import 'package:test/test.dart';

void main() {
  group('pyRound', () {
    test('a metà verso il pari, come Python', () {
      expect(pyRound(0.5), 0);
      expect(pyRound(1.5), 2);
      expect(pyRound(2.5), 2);
      expect(pyRound(3.5), 4);
      expect(pyRound(-2.5), -2);
      expect(pyRound(-0.5), 0);
      expect(pyRound(2.4999999), 2);
      expect(pyRound(2.5000001), 3);
      expect(pyRound(7.0), 7);
    });
  });

  group('pyRoundTo', () {
    test('valore binario esatto e casi a metà', () {
      expect(
        pyRoundTo(0.125, 2),
        0.12,
      ); // 0,125 è esatto: a metà, verso il pari
      expect(pyRoundTo(0.375, 2), 0.38);
      expect(pyRoundTo(2.675, 2), 2.67); // In binario è un po' meno di 2,675
      expect(pyRoundTo(1.0005, 3), 1.0); // In binario è un po' meno di 1,0005
      expect(pyRoundTo(453.3333333333333, 3), 453.333);
      expect(pyRoundTo(-1.25, 1), -1.2);
      expect(pyRoundTo(1e-9, 3), 0.0);
      expect(pyRoundTo(123456.78949, 4), 123456.7895);
    });
  });

  test('pySum come sum() di Python 3.12+ (Neumaier)', () {
    expect(
      pySum(List.filled(10, 0.1)),
      1.0,
    ); // Somma semplice: 0.9999999999999999
    expect(pySum([1e100, 1.0, -1e100]), 1.0);
    expect(pySum(const []), 0.0);
  });

  group('PyRandom contro random.Random del desktop', () {
    final dati = jsonDecode(
      File('test/riferimenti/casuale.json').readAsStringSync(),
    ) as Map<String, Object?>;
    for (final caso in (dati['semi']! as List).cast<Map<String, Object?>>()) {
      final seme = caso['seed']! as int;
      test('seme $seme', () {
        var r = PyRandom(seme);
        expect([
          for (var i = 0; i < 8; i++) r.getrandbits(32),
        ], caso['getrandbits32']);
        r = PyRandom(seme);
        expect([for (var i = 0; i < 20; i++) r.random()], caso['random']);
        r = PyRandom(seme);
        expect([
          for (var i = 0; i < 20; i++) r.uniform(-7.5, 7.5),
        ], caso['uniform_-7.5_7.5']);
        r = PyRandom(seme);
        expect([
          for (var i = 0; i < 5; i++) r.randrange(1 << 30),
        ], caso['randrange_2^30']);
      });
    }
  });

  test('jsonEquals: 1 == 1.0 come in Python', () {
    expect(
      jsonEquals(
        {
          'a': 1,
          'b': [1.0, null],
        },
        {
          'b': [1, null],
          'a': 1.0,
        },
      ),
      isTrue,
    );
    expect(jsonEquals({'a': 1}, {'a': 1, 'b': null}), isFalse);
  });
}
