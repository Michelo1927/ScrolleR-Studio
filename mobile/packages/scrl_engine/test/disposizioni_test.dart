import 'dart:convert';
import 'dart:io';

import 'package:scrl_engine/src/layout/layout.dart';
import 'package:scrl_engine/src/model/context.dart';
import 'package:scrl_engine/src/model/elements.dart';
import 'package:scrl_engine/src/model/scene.dart';
import 'package:scrl_engine/src/model/snapshot.dart';
import 'package:test/test.dart';

/// Casi prodotti da `mobile/tools/genera_riferimenti.py` con `apply_auto_layout` del desktop.
void main() {
  final righe = File('test/riferimenti/disposizioni.jsonl')
      .readAsLinesSync()
      .where((r) => r.isNotEmpty);
  const tolleranza = 0.001;

  for (final riga in righe) {
    final caso = jsonDecode(riga) as Map<String, Object?>;
    final id = caso['id']! as String;
    test('disposizione $id', () {
      final prima = caso['prima']! as Map<String, Object?>;
      final dopo = caso['dopo']! as Map<String, Object?>;
      final immagini = <int, ({int w, int h})>{
        for (final it in (prima['items']! as List).cast<Map<String, Object?>>())
          it['uid']! as int: (
            w: (it['image']! as List)[0] as int,
            h: (it['image']! as List)[1] as int,
          ),
      };
      final ctx = EngineContext(imageSize: (p) => immagini[p.uid]);
      final s = Snapshot.fromJson(prima);
      final sc = Scene(s, ctx);
      // Il modo applicato dal desktop: in «dopo-polaroid-*» lo stato di partenza è già in Polaroid
      final modo =
          (dopo['canvas']! as Map<String, Object?>)['layout_mode']! as String;
      applyAutoLayoutIn(sc, modo);
      final risultato = sc.toSnapshot();

      final tela = dopo['canvas']! as Map<String, Object?>;
      final mia = risultato.canvas.toJson();
      for (final k in tela.keys) {
        expect(mia[k], tela[k], reason: '$id: canvas.$k');
      }
      final perUid = {for (final p in risultato.items) p.uid: p};
      for (final atteso
          in (dopo['items']! as List).cast<Map<String, Object?>>()) {
        final p = perUid[atteso['uid']]!;
        final valori = <String, double>{
          'x': p.x,
          'y': p.y,
          'w': p.w,
          'h': p.h,
          'rotation': p.rotation,
        };
        for (final e in valori.entries) {
          expect(
            e.value,
            closeTo((atteso[e.key]! as num).toDouble(), tolleranza),
            reason: '$id: uid ${p.uid} ${e.key}',
          );
        }
        expect(
          p.borderWidth,
          (atteso['border_width']! as num).toDouble(),
          reason: '$id: uid ${p.uid} bordo',
        );
        expect(
          p.autoBorder,
          atteso['auto_border'],
          reason: '$id: uid ${p.uid} bordo automatico',
        );
        expect(p.frame, atteso['frame'], reason: '$id: uid ${p.uid} cornice');
      }
      expect(risultato.items.map((p) => p.uid).toSet(), perUid.keys.toSet());
    });
  }

  test('rettangolo ruotato attorno al centro', () {
    final r = Rect.rotated(0, 0, 100, 50, 90);
    expect(r.w, closeTo(50, 1e-9));
    expect(r.h, closeTo(100, 1e-9));
    expect(r.centerX, closeTo(50, 1e-9));
  });
}
