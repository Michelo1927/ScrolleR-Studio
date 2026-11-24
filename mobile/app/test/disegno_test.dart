import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:scrl_engine/scrl_engine.dart';
import 'package:scrollr_studio/render/disegno.dart';
import 'package:scrollr_studio/render/regolazioni.dart';

/// Pagine disegnate dal modulo di disegno e confrontate con quelle esportate dal desktop
/// (`scrl_engine/test/riferimenti/immagini/`, prodotte da `tools/genera_riferimenti.py`).
const _cartella = '../packages/scrl_engine/test/riferimenti';

class _Risorse implements RisorseDisegno {
  _Risorse(this.immagini);
  final Map<String, ui.Image> immagini;

  @override
  FotoPronta? foto(PhotoItem p) {
    final i = immagini[p.path];
    return i == null ? null : FotoPronta(i);
  }

  @override
  bool mancante(PhotoItem p) => !immagini.containsKey(p.path);

  @override
  ui.Image? get sfondoSfocato => null;

  @override
  ui.Image? get grana => null;

  @override
  bool get mostraOriginale => false;
}

/// Le foto sintetiche di `crea_foto`: sfumatura diversa per ogni foto.
Future<ui.Image> _fotoSintetica(int i, int w, int h) {
  final px = Uint8List(w * h * 4);
  final r0 = (37 * i) % 256,
      g0 = (91 * i + 60) % 256,
      b0 = (151 * i + 120) % 256;
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

Future<Uint8List> _pixel(ui.Image img) async =>
    (await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!.buffer
        .asUint8List();

void main() {
  final indice = jsonDecode(
    File('$_cartella/indice.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final foto = (indice['foto']! as List).cast<List<Object?>>();
  final immagini = (indice['immagini']! as List).cast<String>();
  const testi = TestiDisegno(
    fotoMancante: 'Foto mancante',
    originaleMancante: 'Originale mancante',
    di: 'di',
  );

  for (final file in immagini) {
    test('pagina come sul desktop: $file', () async {
      final nome = file.substring(0, file.lastIndexOf('_'));
      final k =
          int.parse(
            file.substring(file.lastIndexOf('_') + 1, file.lastIndexOf('.')),
          ) -
          1;
      final dati = jsonDecode(
        File('$_cartella/immagini/$nome.json').readAsStringSync(),
      ) as Map<String, Object?>;
      final s = ProjectFile.parse(jsonEncode(dati['progetto'])).snapshot;
      final mappa = <String, ui.Image>{};
      for (var i = 0; i < foto.length; i++) {
        mappa[foto[i][0]! as String] = await _fotoSintetica(
          i,
          foto[i][1]! as int,
          foto[i][2]! as int,
        );
      }
      final fw = s.canvas.frameW, fh = s.canvas.frameH;
      final rec = ui.PictureRecorder();
      disegnaPagina(
        ui.Canvas(rec),
        s,
        k,
        _Risorse(mappa),
        const OpzioniDisegno(testi: testi, esportazione: true),
      );
      final disegnata = await rec.endRecording().toImage(fw, fh);
      final mia = await _pixel(disegnata);
      // SCRL_DISEGNO_USCITA=CARTELLA: scrive anche le pagine disegnate qui, da guardare accanto a quelle del desktop
      final uscita = Platform.environment['SCRL_DISEGNO_USCITA'];
      if (uscita != null) {
        final png = await disegnata.toByteData(format: ui.ImageByteFormat.png);
        File('$uscita/$file').writeAsBytesSync(png!.buffer.asUint8List());
      }

      final codec = await ui.instantiateImageCodec(
        File('$_cartella/immagini/$file').readAsBytesSync(),
      );
      final rif = await _pixel((await codec.getNextFrame()).image);
      expect(rif.length, mia.length);

      // Differenza media per canale e quota di pixel visibilmente diversi (bordi antialias esclusi)
      var somma = 0;
      var diversi = 0;
      for (var i = 0; i < rif.length; i += 4) {
        var d = 0;
        for (var c = 0; c < 3; c++) {
          final x = (rif[i + c] - mia[i + c]).abs();
          somma += x;
          if (x > d) d = x;
        }
        if (d > 24) diversi++;
      }
      final media = somma / (rif.length / 4 * 3);
      final quota = diversi / (rif.length / 4);
      printOnFailure(
        '$file: differenza media $media, pixel diversi ${(quota * 100).toStringAsFixed(3)}%',
      );
      expect(media, lessThan(1.5), reason: file);
      expect(quota, lessThan(0.005), reason: file);
    });
  }

  // Sulla tela la pagina si disegna ingrandita o ridotta: sfumatura della sagoma e ombra devono seguire la scala
  test('sagoma a metà misura come quella del desktop ridotta', () async {
    final dati = jsonDecode(
      File('$_cartella/immagini/immagine-sagoma.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final s = ProjectFile.parse(jsonEncode(dati['progetto'])).snapshot;
    final mappa = <String, ui.Image>{};
    for (var i = 0; i < foto.length; i++) {
      mappa[foto[i][0]! as String] = await _fotoSintetica(
        i,
        foto[i][1]! as int,
        foto[i][2]! as int,
      );
    }
    final fw = s.canvas.frameW, fh = s.canvas.frameH;
    final rec = ui.PictureRecorder();
    disegnaPagina(
      ui.Canvas(rec),
      s,
      0,
      _Risorse(mappa),
      const OpzioniDisegno(testi: testi, esportazione: true),
      scala: 0.5,
    );
    final mia = await _pixel(
      await rec.endRecording().toImage(fw ~/ 2, fh ~/ 2),
    );
    final codec = await ui.instantiateImageCodec(
      File('$_cartella/immagini/immagine-sagoma_01.png').readAsBytesSync(),
    );
    final rif = await _pixel((await codec.getNextFrame()).image);
    // Media di ogni quadrato 2 × 2 del desktop
    var somma = 0.0;
    var diversi = 0;
    for (var y = 0; y < fh ~/ 2; y++) {
      for (var x = 0; x < fw ~/ 2; x++) {
        var d = 0.0;
        for (var c = 0; c < 3; c++) {
          var v = 0;
          for (final (dx, dy) in const [(0, 0), (1, 0), (0, 1), (1, 1)]) {
            v += rif[((2 * y + dy) * fw + 2 * x + dx) * 4 + c];
          }
          final x0 = (v / 4 - mia[(y * (fw ~/ 2) + x) * 4 + c]).abs();
          somma += x0;
          d = math.max(d, x0);
        }
        if (d > 24) diversi++;
      }
    }
    final n = (fw ~/ 2) * (fh ~/ 2);
    expect(somma / (n * 3), lessThan(1.5));
    expect(diversi / n, lessThan(0.005));
  });
}
