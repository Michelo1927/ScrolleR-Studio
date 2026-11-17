/// Geometria della tela a pagina singola (piano §4.2): dove sta ogni pagina sullo schermo e come si passa dalle
/// coordinate della striscia (quelle del progetto) a quelle dello schermo e viceversa.
///
/// Le pagine sono finestre sulla striscia unica, separate da un piccolo spazio; la funzione è lineare dentro
/// ogni pagina e continua tra una pagina e l'altra, così disegno, selezione e gesti concordano sempre.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import '../theme/tokens.dart';

/// Altezza riservata sopra la pagina all'etichetta («Pagina 2 · …»).
const double altezzaEtichetta = 26;

/// Spazio tra una pagina e l'altra.
const double spazioTraPagine = 8;

/// Area toccabile minima di un elemento piccolo, in dp.
const double toccoMinimo = 44;

class GeometriaTela {
  GeometriaTela._({
    required this.larghezza,
    required this.altezza,
    required this.frameW,
    required this.frameH,
    required this.scala,
    required this.x0,
    required this.y0,
    required this.pw,
    required this.ph,
    required this.pos,
  });

  /// Pagina adattata allo spazio libero, con un lembo di quella vicina visibile ai lati.
  factory GeometriaTela.adatta({
    required double larghezza,
    required double altezza,
    required int frameW,
    required int frameH,
    required double pos,
  }) {
    final maxW = math.max(
      1.0,
      larghezza - 2 * (MisureScrl.lemboPagina + spazioTraPagine),
    );
    final maxH = math.max(1.0, altezza - altezzaEtichetta - spazioTraPagine);
    final scala = math.min(maxW / frameW, maxH / frameH);
    final pw = frameW * scala, ph = frameH * scala;
    return GeometriaTela._(
      larghezza: larghezza,
      altezza: altezza,
      frameW: frameW,
      frameH: frameH,
      scala: scala,
      x0: (larghezza - pw) / 2,
      y0: altezzaEtichetta + (altezza - altezzaEtichetta - ph) / 2,
      pw: pw,
      ph: ph,
      pos: pos,
    );
  }

  final double larghezza, altezza;
  final int frameW, frameH;

  /// dp dello schermo per unità della tela.
  final double scala;

  /// Angolo in alto a sinistra della pagina centrata e misure della pagina sullo schermo.
  final double x0, y0, pw, ph;

  /// Posizione di scorrimento, in pagine (0 = prima pagina centrata).
  final double pos;

  double get passo => pw + spazioTraPagine;

  GeometriaTela conPos(double p) => GeometriaTela._(
    larghezza: larghezza,
    altezza: altezza,
    frameW: frameW,
    frameH: frameH,
    scala: scala,
    x0: x0,
    y0: y0,
    pw: pw,
    ph: ph,
    pos: p,
  );

  /// La stessa vista ingrandita di [zoom] attorno al centro della pagina, spostato di [pan] dp. Disegno, tocchi e
  /// gesti passano tutti di qui, così restano d'accordo a ogni zoom.
  GeometriaTela conVista(double zoom, Offset pan) {
    if (zoom == 1 && pan == Offset.zero) return this;
    final cx = x0 + pw / 2 + pan.dx, cy = y0 + ph / 2 + pan.dy;
    final w = pw * zoom, h = ph * zoom;
    return GeometriaTela._(
      larghezza: larghezza,
      altezza: altezza,
      frameW: frameW,
      frameH: frameH,
      scala: scala * zoom,
      x0: cx - w / 2,
      y0: cy - h / 2,
      pw: w,
      ph: h,
      pos: pos,
    );
  }

  /// Lato sinistro sullo schermo della pagina [i].
  double sinistraPagina(int i) => x0 + (i - pos) * passo;

  /// Dalla striscia allo schermo.
  Offset aSchermo(double sx, double sy) {
    final u = sx / frameW;
    final i = u.floor();
    final x = sinistraPagina(i) + (u - i) * pw;
    return Offset(x, y0 + sy * scala);
  }

  /// Dallo schermo alla striscia.
  (double, double) daSchermo(Offset p) {
    final t = (p.dx - x0) / passo + pos;
    final i = t.floor();
    final dentro = math.min((t - i) * passo, pw);
    return (i * frameW + dentro / scala, (p.dy - y0) / scala);
  }

  /// Pagine che si vedono, anche solo in parte.
  Iterable<int> pagineVisibili(int numPagine) sync* {
    final da = math.max(0, pos.floor() - 1);
    final a = math.min(numPagine - 1, pos.ceil() + 1);
    for (var i = da; i <= a; i++) {
      final l = sinistraPagina(i);
      if (l + pw > 0 && l < larghezza) yield i;
    }
  }
}

/// Misura (larghezza, altezza) dell'elemento prima della rotazione.
({double w, double h}) dimensioniElemento(CanvasElement e, TextSizeOf misura) =>
    switch (e) {
      PhotoItem() => (w: e.w, h: e.h),
      ShapeItem() => (w: e.w, h: e.h),
      TextItem() => misura(e),
    };

/// I quattro angoli dell'elemento in coordinate della striscia (rotazione compresa), in senso orario
/// a partire da in alto a sinistra.
List<(double, double)> angoliElemento(CanvasElement e, TextSizeOf misura) {
  final d = dimensioniElemento(e, misura);
  final t = e.rotation * math.pi / 180.0;
  final c = math.cos(t), s = math.sin(t);
  final cx = e.x + d.w / 2.0, cy = e.y + d.h / 2.0;
  (double, double) p(double lx, double ly) =>
      (cx + lx * c - ly * s, cy + lx * s + ly * c);
  return [
    p(-d.w / 2, -d.h / 2),
    p(d.w / 2, -d.h / 2),
    p(d.w / 2, d.h / 2),
    p(-d.w / 2, d.h / 2),
  ];
}

/// Il punto della striscia ([sx], [sy]) cade sull'elemento, allargato fino ad avere almeno [toccoMinimo] dp.
bool colpisceElemento(
  CanvasElement e,
  double sx,
  double sy,
  TextSizeOf misura,
  double scala,
) {
  final d = dimensioniElemento(e, misura);
  final t = -e.rotation * math.pi / 180.0;
  final c = math.cos(t), s = math.sin(t);
  final dx = sx - (e.x + d.w / 2.0), dy = sy - (e.y + d.h / 2.0);
  final lx = dx * c - dy * s, ly = dx * s + dy * c;
  final minimo = toccoMinimo / scala;
  final mw = math.max(d.w, minimo) / 2.0, mh = math.max(d.h, minimo) / 2.0;
  return lx.abs() <= mw && ly.abs() <= mh;
}
