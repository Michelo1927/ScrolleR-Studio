/// «Salva sagoma come PNG» (`cutout_image` del desktop): il soggetto scontornato, ritagliato stretto attorno alla
/// sagoma, con le regolazioni colore e lo specchio, su sfondo trasparente.
///
/// L'originale si legge al massimo a [latoMassimo] pixel di lato lungo (mai l'originale intero in memoria):
/// sulle foto più grandi il PNG ne è la parte corrispondente a quella misura.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:scrl_engine/scrl_engine.dart';

import '../media/cache_media.dart';
import '../render/regolazioni.dart';

/// Lato lungo massimo a cui si legge l'originale per il PNG della sagoma.
const int latoMassimo = 4096;

/// Nome del file: `<nome della foto>_sagoma.png`, come il desktop.
String nomePngSagoma(PhotoItem p) {
  final nome = p.path.split(RegExp(r'[/\\]')).last;
  final punto = nome.lastIndexOf('.');
  final base = punto > 0 ? nome.substring(0, punto) : nome;
  return '${base.isEmpty ? 'foto' : base}_sagoma.png';
}

/// PNG del soggetto della foto [p] (null se non ha sagoma o non si legge).
Future<Uint8List?> pngSagoma(
  PhotoItem p,
  CacheMedia cache,
  String cartellaProgetto,
) async {
  final punti = p.cutout;
  if (!haSagoma(p) || punti == null) return null;
  final src = sorgenteDi(p, cartellaProgetto);
  final ant = await cache.carica(src, Dettaglio.anteprima);
  if (ant == null) return null;
  final daLiberare = <ui.Image>[];
  try {
    // Originale grande quanto serve (o, se manca, l'anteprima)
    var img = await cache.perEsportazione(src, latoMassimo);
    if (img != null) {
      daLiberare.add(img);
    } else {
      img = ant.immagine;
    }
    if (adjustmentsActive(p.adjust)) {
      List<int>? livelli;
      if (adjOn(p.adjust, 'auto')) {
        livelli = await Regolazioni.livelliAutomatici(ant.immagine);
      }
      final r = await Regolazioni.carica();
      img = await r.applica(
        img,
        p.adjust,
        detailScale: img.width / 1000.0,
        livelli: livelli,
      );
      daLiberare.add(img);
    }
    final iw = img.width.toDouble(), ih = img.height.toDouble();
    final (x0, y0, x1, y1) = switch (ritaglioSagoma(
      punti,
      p.cutoutSoft,
      iw,
      ih,
    )) {
      [final a, final b, final c, final d] => (a, b, c, d),
      _ => (0.0, 0.0, 1.0, 1.0),
    };
    final bx = (x0 * iw).floorToDouble(), by = (y0 * ih).floorToDouble();
    final bw = math.max(1, (x1 * iw).ceil() - bx.toInt());
    final bh = math.max(1, (y1 * ih).ceil() - by.toInt());
    final uscita = ui.Rect.fromLTWH(0, 0, bw.toDouble(), bh.toDouble());

    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    // Lo specchio vale per tutto (foto e sagoma), come il `transpose` finale del desktop
    canvas.translate(bw / 2.0, bh / 2.0);
    canvas.scale(p.flipH ? -1.0 : 1.0, p.flipV ? -1.0 : 1.0);
    canvas.translate(-bw / 2.0, -bh / 2.0);
    canvas.saveLayer(uscita, ui.Paint());
    canvas.drawImageRect(
      img,
      ui.Rect.fromLTWH(bx, by, bw.toDouble(), bh.toDouble()),
      uscita,
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    canvas.saveLayer(uscita, ui.Paint()..blendMode = ui.BlendMode.dstIn);
    final sigma = raggioMorbidezza(p.cutoutSoft, iw, ih) / 2.0;
    canvas.drawPath(
      ui.Path()..addPolygon([
        for (final (u, v) in punti) ui.Offset(u * iw - bx, v * ih - by),
      ], true),
      ui.Paint()
        ..color = const ui.Color(0xFFFFFFFF)
        ..maskFilter = sigma > 0.05
            ? ui.MaskFilter.blur(ui.BlurStyle.normal, sigma)
            : null,
    );
    canvas.restore();
    canvas.restore();
    final risultato = await rec.endRecording().toImage(bw, bh);
    daLiberare.add(risultato);
    final dati = await risultato.toByteData(format: ui.ImageByteFormat.png);
    return dati?.buffer.asUint8List();
  } finally {
    for (final i in daLiberare) {
      i.dispose();
    }
  }
}
