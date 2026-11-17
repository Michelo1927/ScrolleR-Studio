import 'package:scrl_engine/scrl_engine.dart';
import 'package:test/test.dart';

void main() {
  group('pulisciNomeFile (_clean_file_name del desktop)', () {
    test('toglie i caratteri vietati e i bordi', () {
      expect(pulisciNomeFile(r'  a/b\c:d*e?f"g<h>i|j  '), 'abcdefghij');
      expect(pulisciNomeFile('..viaggio..'), 'viaggio');
      expect(pulisciNomeFile('a\u0001b'), 'ab');
    });
    test('toglie l\'estensione dell\'immagine, senza badare alle maiuscole', () {
      expect(pulisciNomeFile('viaggio.PNG'), 'viaggio');
      expect(pulisciNomeFile('viaggio.jpeg'), 'viaggio');
      expect(pulisciNomeFile('viaggio.jpg '), 'viaggio');
      expect(pulisciNomeFile('mare.estate'), 'mare.estate');
    });
    test('vuoto resta vuoto', () {
      expect(pulisciNomeFile('   '), '');
      expect(pulisciNomeFile('...'), '');
      // Come sul desktop: il punto iniziale cade prima dell'estensione, quindi resta «png»
      expect(pulisciNomeFile('.png'), 'png');
    });
  });

  group('nomi dei file', () {
    final c = CanvasState(frameW: 1080, frameH: 1350, numFrames: 3);
    test('pagine: nome scelto o frame', () {
      expect(nomeFilePagina('', 0, '.jpg'), 'frame_01.jpg');
      expect(nomeFilePagina('viaggio', 9, '.png'), 'viaggio_10.png');
      expect(nomeFilePagina('viaggio.jpg', 1, '.jpg'), 'viaggio_02.jpg');
      expect(nomeFilePagina('x', 99, '.png'), 'x_100.png');
    });
    test('collage: nome scelto o descrizione con le misure', () {
      expect(nomeFileCollage('', c, 2, '.png'), 'collage_1080x1350_3pagine_6480x2700.png');
      expect(nomeFileCollage('', c, 1, '.jpg'), 'collage_1080x1350_3pagine_3240x1350.jpg');
      expect(nomeFileCollage('mare', c, 2, '.jpg'), 'mare.jpg');
      expect(
        nomeFileCollage('', c.copyWith(numFrames: 1), 1, '.png'),
        'collage_1080x1350_1080x1350.png',
      );
    });
  });

  group('misure e limiti', () {
    test('misure di uscita', () {
      final c = CanvasState(frameW: 1080, frameH: 1350, numFrames: 4);
      final m = MisureUscita(c, 2);
      expect((m.paginaW, m.paginaH), (2160, 2700));
      expect((m.collageW, m.collageH), (8640, 2700));
      expect(m.pixelCollage, 8640 * 2700);
    });
    test('il collage grande non entra a 2× ma entra a 1×', () {
      final c = CanvasState(frameW: 1080, frameH: 1350, numFrames: 10);
      expect(MisureUscita(c, 2).collageEntra, isFalse);
      expect(MisureUscita(c, 1).collageEntra, isTrue);
    });
    test('qualità e scala valide', () {
      expect(qualitaJpgValida(92), 92);
      expect(qualitaJpgValida(90), 92);
      expect(qualitaJpgValida(80), 85);
      expect(qualitaJpgValida(0), 75);
      expect(qualitaJpgValida(200), 100);
      expect(scalaValida(0), 1);
      expect(scalaValida(1), 1);
      expect(scalaValida(2), 2);
      expect(scalaValida(3), 2);
    });
  });
}
