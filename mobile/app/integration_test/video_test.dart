// Prototipo video della Fase 2 (piano §10), da eseguire su un telefono o un emulatore Android:
//   flutter test integration_test/video_test.dart
// Crea un MP4 sorgente con lo scrittore nativo, lo rilegge (informazioni, fotogrammi, audio) e poi esporta
// una pagina con quel video, un testo e una freccia con lo stesso modulo di disegno dello schermo.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:scrl_engine/scrl_engine.dart';
import 'package:scrl_video/scrl_video.dart';
import 'package:scrollr_studio/export/video_pagina.dart';
import 'package:scrollr_studio/media/cache_media.dart';
import 'package:scrollr_studio/render/disegno.dart';

const _w = 480, _h = 272, _secondi = 3;

/// Fotogramma sintetico i: sfumatura che scorre, per riconoscere il tempo dai colori.
Uint8List _fotogramma(int i) {
  final px = Uint8List(_w * _h * 4);
  var o = 0;
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < _w; x++) {
      px[o++] = (x * 255 ~/ _w + i * 3) % 256;
      px[o++] = y * 255 ~/ _h;
      px[o++] = (i * 255 ~/ (_secondi * 30));
      px[o++] = 255;
    }
  }
  return px;
}

/// La 440 Hz stereo in PCM s16 a 44,1 kHz.
Uint8List _la(double secondi) {
  final n = (secondi * RegoleVideo.frequenzaAudio).round();
  final s = Int16List(n * 2);
  for (var i = 0; i < n; i++) {
    final v =
        (math.sin(2 * math.pi * 440 * i / RegoleVideo.frequenzaAudio) * 12000)
            .round();
    s[i * 2] = v;
    s[i * 2 + 1] = v;
  }
  return s.buffer.asUint8List();
}

void _riferisci(String r) =>
    print('PROTOTIPO VIDEO: $r'); // ignore: avoid_print

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory cartella;
  late String fonte;

  setUpAll(() async {
    cartella = Directory('${(await getTemporaryDirectory()).path}/prova_video');
    if (cartella.existsSync()) cartella.deleteSync(recursive: true);
    Directory('${cartella.path}/media').createSync(recursive: true);
    fonte = '${cartella.path}/media/fonte.mp4';
  });

  testWidgets('scrittura MP4 H.264 + AAC e rilettura', (tester) async {
    await tester.runAsync(() async {
      expect(await ScrlVideo.disponibile(), isTrue);
      final cr = Stopwatch()..start();
      final s = await ScrittoreMp4.apri(
        fonte,
        _w,
        _h,
        audio: _la(_secondi.toDouble()),
      );
      for (var i = 0; i < _secondi * 30; i++) {
        await s.aggiungi(_fotogramma(i));
      }
      await s.chiudi();
      _riferisci(
        'sorgente ${_w}x$_h, ${_secondi * 30} fotogrammi in ${cr.elapsedMilliseconds} ms',
      );
      final info = await ScrlVideo.info(fonte);
      _riferisci(
        'info ${info.larghezza}x${info.altezza} ${info.durata}s ${info.fps}fps audio=${info.audio}',
      );
      expect(info.larghezza, _w);
      expect(info.altezza, _h);
      expect(info.durata, closeTo(_secondi, 0.2));
      expect(info.audio, isTrue);

      // Fotogramma a 1 s: i colori del fotogramma 30 (la compressione cambia di poco i valori)
      final l = await LettoreFotogrammi.apri(fonte);
      final f = (await l.a(1.0))!;
      final atteso = _fotogramma(30);
      var somma = 0;
      for (var i = 0; i < f.rgba.length; i += 4) {
        for (var c = 0; c < 3; c++) {
          somma += (f.rgba[i + c] - atteso[i + c]).abs();
        }
      }
      final media = somma / (_w * _h * 3);
      _riferisci('fotogramma a 1 s: differenza media $media');
      expect(media, lessThan(8));
      // Indietro (come quando un video corto riparte)
      expect(await l.a(0.0), isNotNull);
      await l.chiudi();

      final pcm = (await ScrlVideo.leggiAudio(fonte, 0.5, 2.5))!;
      expect(
        pcm.length,
        2 * RegoleVideo.frequenzaAudio * RegoleVideo.bytePerCampione,
      );
      // Il canale dà una vista dentro il messaggio: si leggono solo i suoi byte (copia allineata)
      final campioni = Uint8List.fromList(pcm).buffer.asInt16List();
      final picco = campioni.map((v) => v.abs()).reduce(math.max);
      var quadrati = 0.0;
      for (final v in campioni) {
        quadrati += v * v;
      }
      final efficace = math.sqrt(quadrati / campioni.length);
      _riferisci(
        'audio letto: ${pcm.length} byte, picco $picco, valore efficace ${efficace.round()}',
      );
      // La 440 Hz scritta ha picco 12000 e valore efficace 12000/√2 ≈ 8485 (l'AAC li cambia di poco)
      expect(picco, inInclusiveRange(9000, 15000));
      expect(efficace, closeTo(8485, 1200));
    });
  });

  Snapshot pagina() => Snapshot(
    canvas: CanvasState(bgColor: 0xFF202020, pageNumbers: true),
    items: [
      PhotoItem(
        uid: 1,
        path: 'media/fonte.mp4',
        rel: 'media/fonte.mp4',
        isVideo: true,
        x: 40,
        y: 300,
        w: 1000,
        h: 700,
        z: 1,
        borderRadius: 40,
        shadow: 50,
      ),
    ],
    texts: [
      TextItem(
        uid: 1,
        text: 'ScrolleR',
        x: 200,
        y: 80,
        size: 110,
        z: 2,
        box: true,
      ),
    ],
    shapes: [
      ShapeItem(
        uid: 1,
        kind: 'arrow',
        x: 600,
        y: 1150,
        w: 380,
        h: 52,
        strokeWidth: 14,
        stroke: 0xFFFFD60A,
        z: 3,
      ),
    ],
  );

  const testi = TestiDisegno(
    fotoMancante: 'Foto mancante',
    originaleMancante: 'Originale mancante',
    di: 'di',
  );

  testWidgets('esportazione MP4 di una pagina con un video', (tester) async {
    await tester.runAsync(() async {
      final uscita = '${cartella.path}/pagina_01.mp4';
      final esito = await esportaPaginaVideo(
        s: pagina(),
        k: 0,
        percorso: uscita,
        cache: CacheMedia(cartella: Directory('${cartella.path}/cache')),
        cartellaProgetto: cartella.path,
        testi: testi,
      );
      _riferisci(
        'esito ${esito.fatto} errore ${esito.errore}: ${esito.fotogrammi} fotogrammi in '
        '${esito.tempo.inMilliseconds} ms (${esito.msPerFotogramma.toStringAsFixed(1)} ms per fotogramma)',
      );
      expect(esito.fatto, isTrue);
      final info = await ScrlVideo.info(uscita);
      _riferisci(
        'uscita ${info.larghezza}x${info.altezza} ${info.durata}s audio=${info.audio}, '
        '${File(uscita).lengthSync()} byte',
      );
      expect(info.larghezza, 1080);
      expect(info.altezza, 1440);
      expect(info.durata, closeTo(_secondi, 0.2));
      expect(info.audio, isTrue);
      // Il fotogramma esportato: sfondo scuro in alto a sinistra, video al centro
      final l = await LettoreFotogrammi.apri(uscita);
      final f = (await l.a(1.0))!;
      await l.chiudi();
      int px(int x, int y, int c) => f.rgba[(y * f.larghezza + x) * 4 + c];
      expect(px(5, 5, 0), closeTo(0x20, 12));
      expect(
        px(540, 650, 1),
        greaterThan(60),
      ); // Verde della sfumatura a metà altezza
    });
  });

  testWidgets('Annulla: niente MP4 a metà', (tester) async {
    await tester.runAsync(() async {
      final uscita = '${cartella.path}/annullato.mp4';
      var n = 0;
      final esito = await esportaPaginaVideo(
        s: pagina(),
        k: 0,
        percorso: uscita,
        cache: CacheMedia(cartella: Directory('${cartella.path}/cache')),
        cartellaProgetto: cartella.path,
        testi: testi,
        annullato: () => ++n > 10,
      );
      expect(esito.fatto, isNull);
      expect(File(uscita).existsSync(), isFalse);
    });
  });
}
