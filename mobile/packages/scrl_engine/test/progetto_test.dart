import 'dart:convert';
import 'dart:io';

import 'package:scrl_engine/scrl_engine.dart';
import 'package:test/test.dart';

void main() {
  group('progetti salvati dal desktop', () {
    for (final nome in [
      'immagine-griglia',
      'immagine-polaroid',
      'immagine-unite',
      'immagine-pellicola',
      'immagine-polaroid-rilievo',
      'immagine-pellicola-verticale',
    ]) {
      test('$nome: letto e riscritto resta identico', () {
        final dati = jsonDecode(
          File('test/riferimenti/immagini/$nome.json').readAsStringSync(),
        ) as Map<String, Object?>;
        final originale = dati['progetto']! as Map<String, Object?>;
        final testo = const JsonEncoder.withIndent(' ').convert(originale);
        final progetto = ProjectFile.parse(testo);
        expect(progetto.version, 1);
        final riscritto = jsonDecode(progetto.encode()) as Map<String, Object?>;
        expect(
          jsonEquals(riscritto, originale),
          isTrue,
          reason: _differenze(riscritto, originale).join('\n'),
        );
        // Una seconda lettura dà lo stesso stato
        expect(
          ProjectFile.parse(progetto.encode()).snapshot,
          progetto.snapshot,
        );
      });
    }
  });

  group('progetti completi salvati dal desktop (riferimenti/progetti)', () {
    final cartella = Directory('test/riferimenti/progetti');
    final indice = jsonDecode(
      File('test/riferimenti/indice.json').readAsStringSync(),
    ) as Map<String, Object?>;
    test('ci sono tutti', () {
      final presenti = cartella
          .listSync()
          .map((f) => f.uri.pathSegments.last)
          .toSet();
      expect(
        presenti,
        containsAll((indice['progetti']! as List).cast<String>()),
      );
    });
    for (final nome in (indice['progetti']! as List).cast<String>()) {
      test('$nome: letto e riscritto resta identico', () {
        final testo = File('${cartella.path}/$nome').readAsStringSync();
        final originale = jsonDecode(testo) as Map<String, Object?>;
        final progetto = ProjectFile.parse(testo);
        final riscritto = jsonDecode(progetto.encode()) as Map<String, Object?>;
        expect(
          jsonEquals(riscritto, originale),
          isTrue,
          reason: _differenze(riscritto, originale).join('\n'),
        );
        expect(progetto.snapshot.allElements, isNotEmpty);
      });
    }
    test('il progetto completo ha davvero tutti i tipi di dato', () {
      final p = ProjectFile.parse(
        File('${cartella.path}/completo.scrlproj').readAsStringSync(),
      );
      final s = p.snapshot;
      expect(s.texts, isNotEmpty);
      expect(s.shapes, isNotEmpty);
      expect(s.canvas.pageLocks, contains(true));
      expect(s.canvas.pageSeams, contains(true));
      expect(s.canvas.pageLayouts.whereType<PageLayout>(), isNotEmpty);
      expect(s.items.any((f) => f.free), isTrue);
      expect(s.items.any((f) => f.crop != fullCrop), isTrue);
      expect(s.items.any((f) => f.savedCell != null), isTrue);
      expect(s.items.any((f) => f.group != 0), isTrue);
      expect(s.texts.any((t) => t.text.contains('\n')), isTrue);
      expect(p.library, isNotEmpty);
    });
  });

  test('i campi sconosciuti sopravvivono a ogni livello', () {
    final testo = jsonEncode({
      'version': 1,
      'futuro': {'a': 1},
      'canvas': {
        'frame_w': 1080,
        'frame_h': 1440,
        'num_frames': 2,
        'nuova_opzione': true,
      },
      'library': [
        {'path': 'a.jpg', 'rel': 'a.jpg', 'tag': 'x'},
      ],
      'items': [
        {
          'uid': 3,
          'path': 'a.jpg',
          'x': 1,
          'y': 2,
          'w': 300,
          'h': 200,
          'filtro_nuovo': [1, 2],
          'adjust': {'brightness': 10, 'clarity': 5},
          'asset': {
            'platform': 'android',
            'id': '42',
            'name': 'IMG_1.jpg',
            'extra': 1,
          },
        },
        {
          'uid': 4,
          'kind': 'video',
          'path': 'v.mp4',
          'trim_end': 3.5,
          'altro': 'z',
        },
      ],
      'texts': [
        {'uid': 1, 'text': 'Ciao', 'x': 5, 'y': 6, 'effetto': 'neon'},
      ],
      'shapes': [
        {'uid': 1, 'kind': 'ellipse', 'x': 0, 'y': 0, 'tratteggio': 3},
      ],
    });
    final p = ProjectFile.parse(testo);
    final j = jsonDecode(p.encode()) as Map<String, Object?>;
    expect(j['futuro'], {'a': 1});
    expect((j['canvas']! as Map)['nuova_opzione'], true);
    expect(((j['library']! as List)[0] as Map)['tag'], 'x');
    final foto = (j['items']! as List)[0] as Map;
    expect(foto['filtro_nuovo'], [1, 2]);
    expect(foto['adjust'], containsPair('clarity', 5));
    expect(foto['adjust'], containsPair('brightness', 10));
    expect(foto['asset'], {
      'platform': 'android',
      'id': '42',
      'name': 'IMG_1.jpg',
      'extra': 1,
    });
    final video = (j['items']! as List)[1] as Map;
    expect(video['kind'], 'video');
    expect(video['altro'], 'z');
    expect(video['adjust'], neutralAdjust);
    expect(((j['texts']! as List)[0] as Map)['effetto'], 'neon');
    expect(((j['shapes']! as List)[0] as Map)['tratteggio'], 3);
  });

  test('progetto vecchio senza campi: predefiniti del desktop', () {
    final p = ProjectFile.parse(
      jsonEncode({
        'canvas': <String, Object?>{},
        'items': [
          {'uid': 1, 'path': 'x.jpg'},
        ],
        'texts': [
          {'uid': 1, 'text': 'Senza carattere', 'x': 0, 'y': 0},
        ],
      }),
    );
    final c = p.snapshot.canvas;
    expect(c.frameW, 1080);
    expect(c.frameH, 1440);
    expect(c.numFrames, 1);
    expect(c.gap, 16);
    expect(c.margin, 24);
    expect(c.bgColor, 0xFFFFFFFF);
    expect(c.bgColor2, 0xFF2680EB);
    expect(c.layoutMode, 'grid');
    expect(c.swipeText, 'Scorri →');
    expect(c.layoutSeed, inInclusiveRange(0, (1 << 30) - 1));
    final f = p.snapshot.items.single;
    expect(f.w, 400);
    expect(f.h, 500);
    expect(f.crop, fullCrop);
    expect(f.fitMode, 'cover');
    expect(f.opacity, 100);
    // Carattere predefinito confermato: quello del desktop su Windows
    expect(p.snapshot.texts.single.font, 'Segoe UI Variable Display');
    expect(
      (p.snapshot.toJson()['texts']! as List).single,
      containsPair('font', 'Segoe UI Variable Display'),
    );
    expect(p.library, isEmpty);
  });

  test('file non valido', () {
    expect(
      () => ProjectFile.parse('non json'),
      throwsA(isA<ProjectFormatException>()),
    );
    expect(
      () => ProjectFile.parse('{"canvas": {}}'),
      throwsA(isA<ProjectFormatException>()),
    );
  });

  test('colori #aarrggbb minuscoli; #rrggbb letto opaco', () {
    expect(parseArgb('#FF2680EB', 0), 0xFF2680EB);
    expect(parseArgb('#2680eb', 0), 0xFF2680EB);
    expect(parseArgb('#fff', 0), 0xFFFFFFFF);
    expect(parseArgb('rosso', 7), 7);
    expect(formatArgb(0x96000000), '#96000000');
    expect(formatArgb(0xFF2680EB), '#ff2680eb');
  });

  test('arrotondamenti del desktop nel file', () {
    final s = Snapshot(
      canvas: CanvasState(layoutSeed: 1),
      items: [
        PhotoItem(
          uid: 1,
          path: 'a',
          x: 1.23456,
          w: 100.0005,
          innerZoom: 1.234567,
          crop: const [0.1234567, 0, 1, 1],
        ),
      ],
    );
    final f = (s.toJson()['items']! as List)[0] as Map;
    expect(f['x'], 1.235);
    expect(f['w'], 100.001); // Come round(100.0005, 3) di Python
    expect(f['inner_zoom'], 1.2346);
    expect((f['crop'] as List)[0], 0.12346);
  });

  test('ritaglio non valido → foto intera; misure minime', () {
    expect(cleanCrop([0.5, 0.5, 0.5, 0.9]), fullCrop);
    expect(cleanCrop([-1, 0, 2, 1]), [0.0, 0.0, 1.0, 1.0]);
    expect(cleanCrop('x'), fullCrop);
    final f = PhotoItem.fromJson({
      'uid': 1,
      'path': 'a',
      'w': 10,
      'h': 5,
      'stretch': 100,
    });
    expect(f.w, 40);
    expect(f.h, 40);
    expect(f.stretch, 20);
    final linea = ShapeItem.fromJson({
      'uid': 1,
      'kind': 'line',
      'w': 2,
      'h': 0.5,
    });
    expect(linea.w, 8);
    expect(linea.h, 1);
  });

  group('percorsi', () {
    final asset = MediaAsset(platform: 'android', id: '9', name: 'IMG_9.jpg');
    test('asset della stessa piattaforma, poi rel, poi path, poi mancante', () {
      MediaLocation r({
        MediaAsset? a,
        String? rel,
        Set<String> esistenti = const {},
        String platform = 'android',
      }) => resolveMedia(
        path: 'C:/Foto/IMG_9.jpg',
        rel: rel,
        asset: a,
        projectDir: '/progetti/uno',
        platform: platform,
        fileExists: esistenti.contains,
      );
      expect(r(a: asset).source, MediaSource.asset);
      expect(r(a: asset, platform: 'ios').source, MediaSource.missing);
      expect(
        r(
          rel: r'media\IMG_9.jpg',
          esistenti: {'/progetti/uno/media/IMG_9.jpg'},
        ).file,
        '/progetti/uno/media/IMG_9.jpg',
      );
      expect(r(esistenti: {'C:/Foto/IMG_9.jpg'}).source, MediaSource.path);
      final mancante = r();
      expect(mancante.source, MediaSource.missing);
      expect(mancante.name, 'IMG_9.jpg');
    });

    test('foto collegata alla galleria e foto dentro il progetto', () {
      final f = PhotoItem(uid: 1, path: '/data/x.jpg', rel: 'x.jpg');
      final g = linkToGallery(f, asset);
      expect(g.toJson()['path'], 'IMG_9.jpg');
      expect(g.toJson()['rel'], isNull);
      expect(g.toJson()['asset'], asset.toJson());
      final m = placeInProject(f, r'media\x.jpg');
      expect(m.path, 'media/x.jpg');
      expect(m.rel, 'media/x.jpg');
      expect(m.asset, isNull);
    });
  });
}

List<String> _differenze(Object? a, Object? b, [String dove = '']) {
  if (jsonEquals(a, b)) return const [];
  if (a is Map && b is Map) {
    return [
      for (final k in {...a.keys, ...b.keys})
        ..._differenze(a[k], b[k], '$dove.$k'),
    ];
  }
  if (a is List && b is List && a.length == b.length) {
    return [
      for (var i = 0; i < a.length; i++)
        ..._differenze(a[i], b[i], '$dove[$i]'),
    ];
  }
  return ['$dove: $a ≠ $b'];
}
