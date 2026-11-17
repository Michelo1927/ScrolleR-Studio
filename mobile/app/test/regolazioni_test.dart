import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:scrollr_studio/render/regolazioni.dart';

/// Lo shader delle regolazioni confrontato con `apply_adjustments` di Pillow (`riferimenti/colore.json`):
/// non serve l'identità al pixel, ma la differenza non deve vedersi (piano §8.4, §13).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final rif =
      (jsonDecode(
            File('../packages/scrl_engine/test/riferimenti/colore.json')
                .readAsStringSync(),
          ) as Map<String, Object?>)['regolate']!
          as Map<String, Object?>;
  final w = rif['w']! as int, h = rif['h']! as int, n = rif['foto']! as int;

  Future<ui.Image> foto() {
    final px = Uint8List(w * h * 4);
    final r0 = (37 * n) % 256,
        g0 = (91 * n + 60) % 256,
        b0 = (151 * n + 120) % 256;
    var o = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        px[o++] = (r0 + x * 255 ~/ w) % 256;
        px[o++] = (g0 + y * 255 ~/ h) % 256;
        px[o++] = b0;
        px[o++] = 255;
      }
    }
    return immagineDaPixel(px, w, h);
  }

  for (final c in (rif['casi']! as List).cast<Map<String, Object?>>()) {
    final adj = (c['adj']! as Map).cast<String, Object?>();
    final attivi = {
      for (final e in adj.entries)
        if (e.value != 0 && e.value != false) e.key: e.value,
    };
    test('regolazioni come Pillow: $attivi', () async {
      final r = await Regolazioni.carica();
      final src = await foto();
      final livelli = await Regolazioni.livelliAutomatici(src);
      final out = await r.applica(
        src,
        adj,
        detailScale: w / 1000.0,
        livelli: livelli,
      );
      final px = (await out.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      ))!.buffer.asUint8List();
      final atteso = (c['rgb']! as List).cast<int>();
      var somma = 0, massimo = 0;
      for (var i = 0; i < w * h; i++) {
        for (var k = 0; k < 3; k++) {
          final d = (px[i * 4 + k] - atteso[i * 3 + k]).abs();
          somma += d;
          if (d > massimo) massimo = d;
        }
      }
      final media = somma / (w * h * 3);
      printOnFailure('$attivi: differenza media $media, massima $massimo');
      expect(media, lessThan(2.0));
      expect(massimo, lessThan(12));
    });
  }
}
