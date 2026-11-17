/// Regolazioni colore di una foto applicate con lo shader `shaders/regolazioni.frag` (piano §8.4).
///
/// Le tabelle e i numeri vengono dal motore (`scrl_engine`, stesse formule di `scrollr/imaging.py`); qui si
/// prepara solo l'immagine colorata, una volta per ogni cambio, come `display_pixmap` del desktop. Il risultato
/// si disegna poi con le normali trasformazioni: stesso percorso per lo schermo e per l'esportazione.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:scrl_engine/scrl_engine.dart';

class Regolazioni {
  Regolazioni._(this._programma);

  final ui.FragmentProgram _programma;
  static Future<Regolazioni>? _caricamento;

  /// Carica lo shader una volta sola.
  static Future<Regolazioni> carica() =>
      _caricamento ??= ui.FragmentProgram.fromAsset('shaders/regolazioni.frag')
          .then(Regolazioni._);

  /// Lato della copia piccola usata per il grigio medio del contrasto e per i livelli automatici
  /// (il desktop calcola i livelli sulla foto ridotta a 400 px).
  static const int latoMisure = 400;

  /// Livelli automatici calcolati sulla foto intera ([intera] è l'anteprima della foto non ritagliata).
  static Future<List<int>> livelliAutomatici(ui.Image intera) async {
    final px = await _pixelRidotti(intera, latoMisure);
    return autoLevelsLut(histogramRgb(px));
  }

  /// [sorgente] con le regolazioni di [adj] applicate. `detailScale` = larghezza della foto intera in pixel
  /// / 1000 in questa immagine (serve alla nitidezza). Restituisce [sorgente] se non c'è niente da fare.
  Future<ui.Image> applica(
    ui.Image sorgente,
    Map<String, Object?> adj, {
    required double detailScale,
    List<int>? livelli,
  }) async {
    if (!adjustmentsActive(adj)) return sorgente;
    final auto = adjOn(adj, 'auto') && livelli != null;
    final contrasto = adjOn(adj, 'contrast');
    var grigio = 0.0;
    if (contrasto) {
      final px = await _pixelRidotti(sorgente, latoMisure);
      grigio = contrastMean(px, adj, autoLut: auto ? livelli : null) / 255.0;
    }
    final toni = toneLut(adj);
    final tabLivelli = await _tabella(auto ? livelli : null);
    final tabToni = await _tabella(toni);
    final nitidezza = adjOn(adj, 'sharpness')
        ? sharpenParams(adj, detailScale)
        : null;

    final s = _programma.fragmentShader();
    var i = 0;
    s
      ..setFloat(i++, sorgente.width.toDouble())
      ..setFloat(i++, sorgente.height.toDouble())
      ..setFloat(i++, auto ? 1.0 : 0.0)
      ..setFloat(
        i++,
        adjOn(adj, 'brightness') ? enhanceFactor(adj, 'brightness') : 1.0,
      )
      ..setFloat(i++, contrasto ? enhanceFactor(adj, 'contrast') : 1.0)
      ..setFloat(i++, grigio)
      ..setFloat(i++, adjOn(adj, 'bw') ? 1.0 : 0.0)
      ..setFloat(
        i++,
        adjOn(adj, 'saturation') ? enhanceFactor(adj, 'saturation') : 1.0,
      )
      ..setFloat(i++, toni != null ? 1.0 : 0.0)
      ..setFloat(i++, nitidezza == null ? 0.0 : nitidezza.percent / 100.0)
      ..setFloat(i++, nitidezza?.radius ?? 1.0)
      ..setFloat(i++, (nitidezza?.threshold ?? 0) / 255.0)
      ..setImageSampler(0, sorgente, filterQuality: ui.FilterQuality.none)
      ..setImageSampler(1, tabLivelli)
      ..setImageSampler(2, tabToni);

    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    canvas.drawRect(
      ui.Rect.fromLTWH(
        0,
        0,
        sorgente.width.toDouble(),
        sorgente.height.toDouble(),
      ),
      ui.Paint()..shader = s,
    );
    final pic = rec.endRecording();
    try {
      return await pic.toImage(sorgente.width, sorgente.height);
    } finally {
      pic.dispose();
      s.dispose();
      tabLivelli.dispose();
      tabToni.dispose();
    }
  }

  /// Tabella 256×1 (R, G, B = i tre canali); quella neutra se [lut] è null.
  static Future<ui.Image> _tabella(List<int>? lut) {
    final px = Uint8List(256 * 4);
    for (var v = 0; v < 256; v++) {
      px[v * 4] = lut == null ? v : lut[v];
      px[v * 4 + 1] = lut == null ? v : lut[256 + v];
      px[v * 4 + 2] = lut == null ? v : lut[512 + v];
      px[v * 4 + 3] = 255;
    }
    return immagineDaPixel(px, 256, 1);
  }
}

/// Immagine da pixel RGBA non premoltiplicati.
Future<ui.Image> immagineDaPixel(Uint8List rgba, int w, int h) async {
  final buf = await ui.ImmutableBuffer.fromUint8List(rgba);
  final desc = ui.ImageDescriptor.raw(
    buf,
    width: w,
    height: h,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await desc.instantiateCodec();
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
    desc.dispose();
    buf.dispose();
  }
}

/// Copia ridotta (lato lungo al massimo [lato]) in pixel RGBA non premoltiplicati.
Future<Uint8List> _pixelRidotti(ui.Image img, int lato) async {
  final piccola = await ridimensiona(img, lato);
  try {
    final dati = await piccola.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    return dati!.buffer.asUint8List();
  } finally {
    if (!identical(piccola, img)) piccola.dispose();
  }
}

/// [img] con il lato lungo al massimo [lato] (la stessa immagine se è già più piccola).
Future<ui.Image> ridimensiona(ui.Image img, int lato) async {
  final lungo = img.width > img.height ? img.width : img.height;
  if (lungo <= lato) return img;
  final k = lato / lungo;
  final w = (img.width * k).round().clamp(1, lato);
  final h = (img.height * k).round().clamp(1, lato);
  final rec = ui.PictureRecorder();
  ui.Canvas(rec).drawImageRect(
    img,
    ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.medium,
  );
  final pic = rec.endRecording();
  try {
    return await pic.toImage(w, h);
  } finally {
    pic.dispose();
  }
}
