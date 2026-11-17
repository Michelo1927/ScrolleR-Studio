import 'dart:convert';
import 'dart:io';

import 'package:scrl_engine/scrl_engine.dart';
import 'package:test/test.dart';

/// Regolazioni colore e grana confrontate con `scrollr/imaging.py` (`test/riferimenti/colore.json`).
void main() {
  final rif = jsonDecode(
    File('test/riferimenti/colore.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final img = rif['img']! as Map<String, Object?>;
  final rgb = (img['rgb']! as List).cast<int>();
  final rgba = <int>[
    for (var i = 0; i < rgb.length; i += 3) ...[
      rgb[i],
      rgb[i + 1],
      rgb[i + 2],
      255,
    ],
  ];

  test('tabella dei toni identica al desktop', () {
    for (final c in (rif['tone']! as List).cast<Map<String, Object?>>()) {
      final adj = (c['adj']! as Map).cast<String, Object?>();
      expect(toneLut(adj), (c['lut']! as List).cast<int>(), reason: '$adj');
    }
    expect(toneLut(neutralAdjust), isNull);
  });

  test('livelli automatici identici al desktop', () {
    expect(
      autoLevelsLut(histogramRgb(rgba)),
      (rif['auto']! as List).cast<int>(),
    );
  });

  test('luminosità e grigio medio del contrasto come Pillow', () {
    final adj = {...neutralAdjust, 'brightness': 25};
    final f = enhanceFactor(adj, 'brightness');
    final px = (rif['brightness_px']! as List).cast<int>();
    for (var i = 0; i < px.length; i++) {
      expect(pillowBlend(0, rgb[i], f), px[i], reason: 'byte $i');
    }
    expect(contrastMean(rgba, adj), rif['brightness_mean']);
  });

  test('grana: stesso rumore di random.Random(20261022).randbytes', () {
    final g = grainTileBytes();
    expect(g.length, grainSide * grainSide);
    expect(g.sublist(0, 16), (rif['grain_head']! as List).cast<int>());
    expect(_crc32(g), rif['grain_crc']);
  });

  test('filtri pronti e regolazioni attive', () {
    expect(presets.length, 9);
    final v = presetAdjust('vintage');
    expect(v['fade'], 40);
    expect(v['brightness'], 0);
    expect(adjustmentsActive(neutralAdjust), isFalse);
    expect(adjustmentsActive({...neutralAdjust, 'vignette': -20}), isFalse);
    expect(adjustmentsActive({...neutralAdjust, 'bw': true}), isTrue);
    final s = sharpenParams({'sharpness': 30}, 1.6);
    expect(s.radius, closeTo(2.24, 1e-9));
    expect(s.percent, 48);
  });
}

int _crc32(List<int> data) {
  var crc = 0xFFFFFFFF;
  for (final b in data) {
    crc ^= b;
    for (var k = 0; k < 8; k++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}
