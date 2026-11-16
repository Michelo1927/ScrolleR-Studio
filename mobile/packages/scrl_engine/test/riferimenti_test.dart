import 'dart:convert';
import 'dart:io';

import 'package:scrl_engine/scrl_engine.dart';
import 'package:test/test.dart';

/// Dati prodotti da `mobile/tools/genera_riferimenti.py` con l'app desktop.
final Directory _cartella = Directory('test/riferimenti');

void main() {
  test('formato invariato rispetto al desktop', () {
    expect(progettoVersione, 1);
    expect(progettoEstensione, '.scrlproj');
  });

  test('i dati di riferimento esistono e si leggono', () {
    final indice = jsonDecode(
      File('${_cartella.path}/indice.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final righe = File('${_cartella.path}/disposizioni.jsonl')
        .readAsLinesSync()
        .where((r) => r.isNotEmpty)
        .toList();
    expect(righe.length, indice['casi_disposizioni']);
    for (final riga in righe) {
      final caso = jsonDecode(riga) as Map<String, Object?>;
      expect(caso.keys, containsAll(<String>['id', 'prima', 'dopo']));
    }
    final casuale = jsonDecode(
      File('${_cartella.path}/casuale.json').readAsStringSync(),
    ) as Map<String, Object?>;
    expect(casuale['semi'], isNotEmpty);
    for (final nome in indice['immagini']! as List<Object?>) {
      expect(
        File('${_cartella.path}/immagini/$nome').existsSync(),
        isTrue,
        reason: '$nome',
      );
    }
  });
}
