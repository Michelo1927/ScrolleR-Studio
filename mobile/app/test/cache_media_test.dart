import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:scrl_engine/scrl_engine.dart';
import 'package:scrollr_studio/media/cache_media.dart';
import 'package:scrollr_studio/render/regolazioni.dart';

/// Cache delle anteprime con una foto del progetto (`media/`): niente galleria, gira sul computer.
void main() {
  late Directory cartella;

  setUp(() async {
    cartella = await Directory.systemTemp.createTemp('cache_media_');
    Directory('${cartella.path}/media').createSync();
    final px = Uint8List(40 * 30 * 4);
    for (var i = 0; i < px.length; i += 4) {
      px[i] = 200;
      px[i + 1] = 100;
      px[i + 2] = 50;
      px[i + 3] = 255;
    }
    final img = await immagineDaPixel(px, 40, 30);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('${cartella.path}/media/foto.png')
        .writeAsBytesSync(png!.buffer.asUint8List());
  });

  tearDown(() => cartella.deleteSync(recursive: true));

  test('anteprima: richieste insieme, poi dalla memoria e dal disco', () async {
    final foto = PhotoItem(
      uid: 1,
      path: 'media/foto.png',
      rel: 'media/foto.png',
    );
    final src = sorgenteDi(foto, cartella.path);
    final cache = CacheMedia(cartella: Directory('${cartella.path}/cache'));

    // Due richieste insieme: un solo caricamento, ed entrambe ricevono la risposta (prima restava appesa)
    final insieme = await Future.wait([
      cache.carica(src, Dettaglio.anteprima),
      cache.carica(src, Dettaglio.anteprima),
    ]).timeout(const Duration(seconds: 10));
    expect(insieme[0]!.immagine.width, 40);
    expect(identical(insieme[0], insieme[1]), isTrue);
    expect(cache.pronta(src, Dettaglio.anteprima), isNotNull);

    // Nome del file in cache: 16 cifre esadecimali e il lato
    final file = Directory('${cartella.path}/cache').listSync().single;
    expect(
      file.uri.pathSegments.last,
      matches(RegExp(r'^[0-9a-f]{16}_1600\.img$')),
    );

    // Memoria svuotata: si rilegge dal disco
    cache.svuota();
    final dalDisco = await cache
        .carica(src, Dettaglio.anteprima)
        .timeout(const Duration(seconds: 10));
    expect(dalDisco!.immagine.height, 30);
    expect(dalDisco.originaleMancante, isFalse);
  });
}
