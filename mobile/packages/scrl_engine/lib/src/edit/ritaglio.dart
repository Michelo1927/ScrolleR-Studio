/// Ritaglio a schermo intero (piano §4.6): la logica del riquadro, portata da `scrollr/crop_dialog.py`
/// (`CropCanvas` e `CropDialog`). Dart puro: lavora sulla foto **come appare** (specchiata se lo è) in pixel
/// dell'immagine; l'app disegna il riquadro e passa i punti toccati già in pixel dell'immagine.
///
/// Il risultato è un ritaglio sulla foto originale, in frazioni (sinistra, alto, destra, basso).
library;

import 'dart:math' as math;

import '../model/elements.dart';

/// Proporzioni offerte: (chiave, (larghezza, altezza)); `null` = proporzioni calcolate a parte (`RATIOS`).
const List<(String, (int, int)?)> proporzioniRitaglio = [
  ('free', null),
  ('original', null),
  ('cell', null),
  ('1:1', (1, 1)),
  ('4:5', (4, 5)),
  ('3:4', (3, 4)),
  ('2:3', (2, 3)),
  ('9:16', (9, 16)),
];

/// `QRectF.intersected`: l'intersezione, o un riquadro vuoto in (0, 0) se non si toccano.
Rect _interseca(Rect a, Rect b) {
  final l = math.max(a.left, b.left), t = math.max(a.top, b.top);
  final r = math.min(a.right, b.right), btm = math.min(a.bottom, b.bottom);
  if (r <= l || btm <= t) return const Rect(0, 0, 0, 0);
  return Rect(l, t, r - l, btm - t);
}

/// Cosa si sta trascinando: una maniglia del riquadro, il riquadro intero o un riquadro nuovo.
enum PresaRitaglio { tl, tr, bl, br, l, r, t, b, sposta, nuovo }

class ModelloRitaglio {
  /// [img] è la foto come appare ([flipH] e [flipV] dicono se è specchiata rispetto all'originale); [cellRatio]
  /// le proporzioni del riquadro attuale sulla tela (larghezza / altezza / stiramento).
  ModelloRitaglio({
    required double larghezza,
    required double altezza,
    required List<double> ritaglio,
    this.flipH = false,
    this.flipV = false,
    this.cellRatio = 1.0,
  }) : imgW = math.max(1.0, larghezza),
       imgH = math.max(1.0, altezza) {
    rect = Rect(0, 0, imgW, imgH);
    final (x0, y0, x1, y1) = _specchia(ritaglio);
    impostaRiquadro(
      Rect(x0 * imgW, y0 * imgH, (x1 - x0) * imgW, (y1 - y0) * imgH),
    );
    _scegliProporzioneIniziale();
  }

  final double imgW, imgH;
  final bool flipH, flipV;
  final double cellRatio;

  /// Riquadro in pixel dell'immagine mostrata.
  late Rect rect;

  /// Proporzioni bloccate (larghezza / altezza), o null per un riquadro libero.
  double? ratio;

  /// Chiave della proporzione scelta (`free`, `original`, `cell`, `4:5`…) e scambio verticale/orizzontale.
  String chiave = 'free';
  bool scambiata = false;

  PresaRitaglio? _presa;
  double _pressX = 0, _pressY = 0;
  Rect _inizio = const Rect(0, 0, 0, 0);

  // ---------- Coordinate ----------
  /// Lato minimo del riquadro (`_min_side`).
  double get latoMinimo => math.max(8.0, math.min(imgW, imgH) * 0.03);

  /// Da foto originale a foto come appare (e viceversa: l'operazione è la stessa).
  (double, double, double, double) _specchia(List<double> c) {
    var x0 = c[0], y0 = c[1], x1 = c[2], y1 = c[3];
    if (flipH) {
      final t = 1.0 - x1;
      x1 = 1.0 - x0;
      x0 = t;
    }
    if (flipV) {
      final t = 1.0 - y1;
      y1 = 1.0 - y0;
      y0 = t;
    }
    return (x0, y0, x1, y1);
  }

  /// `crop()`: il ritaglio sulla foto originale, in frazioni (sinistra, alto, destra, basso).
  List<double> get ritaglio {
    final (a, b, c, d) = _specchia([
      rect.left / imgW,
      rect.top / imgH,
      rect.right / imgW,
      rect.bottom / imgH,
    ]);
    return [a, b, c, d];
  }

  /// Misura del ritaglio in pixel dell'originale (`_update_info`).
  (int, int) misuraOriginale(int origW, int origH) {
    final c = ritaglio;
    return (((c[2] - c[0]) * origW).round(), ((c[3] - c[1]) * origH).round());
  }

  // ---------- Riquadro ----------
  void impostaRiquadro(Rect r) {
    rect = _interseca(r, Rect(0, 0, imgW, imgH));
  }

  /// `set_ratio`: il riquadro diventa il più grande possibile con quella forma, centrato dove si trova.
  void impostaProporzione(double? r) {
    ratio = r;
    if (r == null) return;
    final w = math.min(imgW, imgH * r);
    final h = w / r;
    final cx = rect.centerX, cy = rect.centerY;
    final x = math.min(math.max(0.0, cx - w / 2.0), imgW - w);
    final y = math.min(math.max(0.0, cy - h / 2.0), imgH - h);
    impostaRiquadro(Rect(x, y, w, h));
  }

  /// Proporzioni (larghezza / altezza) per la chiave [k], o null (`_ratio_for`).
  double? proporzioniPer(String k) {
    if (k == 'original') return imgW / imgH;
    if (k == 'cell') return cellRatio;
    final wh = proporzioniRitaglio.firstWhere((e) => e.$1 == k).$2;
    if (wh == null) return null;
    final (a, b) = wh;
    return scambiata ? b / a : a / b;
  }

  /// Il tasto ⇄ serve solo alle proporzioni con due misure diverse (`btn_swap`).
  bool get puoScambiare {
    final wh = proporzioniRitaglio.firstWhere((e) => e.$1 == chiave).$2;
    return wh != null && wh != (1, 1);
  }

  /// `_set_ratio_key`.
  void scegliProporzione(String k) {
    chiave = k;
    impostaProporzione(proporzioniPer(k));
  }

  /// `_swap`.
  void scambia() {
    scambiata = !scambiata;
    impostaProporzione(proporzioniPer(chiave));
  }

  /// Testo del tasto di una proporzione: «4:5» diventa «5:4» se scambiata (`_update_labels`).
  String etichettaProporzione(String k) {
    final wh = proporzioniRitaglio.firstWhere((e) => e.$1 == k).$2;
    if (wh == null) return k;
    return scambiata ? '${wh.$2}:${wh.$1}' : '${wh.$1}:${wh.$2}';
  }

  /// `_select_initial_ratio`: un ritaglio che ha già una forma pronta riapre con quella forma scelta.
  void _scegliProporzioneIniziale() {
    final r = rect;
    final attuale = r.h > 0 ? r.w / r.h : 1.0;
    final intera = r.w >= imgW - 0.5 && r.h >= imgH - 0.5;
    if (!intera) {
      for (final (k, wh) in proporzioniRitaglio) {
        if (wh == null) continue;
        for (final scamb in [false, true]) {
          final target = scamb ? wh.$2 / wh.$1 : wh.$1 / wh.$2;
          if ((attuale / target - 1.0).abs() < 0.006) {
            scambiata = scamb;
            chiave = k;
            ratio = target;
            return;
          }
        }
      }
    }
    chiave = 'free';
  }

  /// «Foto intera»: toglie il ritaglio.
  void tuttaLaFoto() {
    chiave = 'free';
    ratio = null;
    impostaRiquadro(Rect(0, 0, imgW, imgH));
  }

  // ---------- Presa e trascinamento ----------
  /// `_handle_at`: cosa c'è sotto il punto ([px], [py]) (in pixel dell'immagine); [presa] è la distanza entro cui si
  /// afferra una maniglia, in pixel dell'immagine (sul telefono: 24 dp divisi per la scala).
  PresaRitaglio? presaIn(double px, double py, double presa) {
    final r = rect;
    final g = presa;
    final nearL = (px - r.left).abs() <= g, nearR = (px - r.right).abs() <= g;
    final nearT = (py - r.top).abs() <= g, nearB = (py - r.bottom).abs() <= g;
    final inX = r.left - g <= px && px <= r.right + g;
    final inY = r.top - g <= py && py <= r.bottom + g;
    if (nearT && nearL) return PresaRitaglio.tl;
    if (nearT && nearR) return PresaRitaglio.tr;
    if (nearB && nearL) return PresaRitaglio.bl;
    if (nearB && nearR) return PresaRitaglio.br;
    if (nearL && inY) return PresaRitaglio.l;
    if (nearR && inY) return PresaRitaglio.r;
    if (nearT && inX) return PresaRitaglio.t;
    if (nearB && inX) return PresaRitaglio.b;
    if (px >= r.left && px <= r.right && py >= r.top && py <= r.bottom) {
      return PresaRitaglio.sposta;
    }
    return null;
  }

  /// `mousePressEvent`.
  void inizia(double px, double py, double presa) {
    _presa = presaIn(px, py, presa) ?? PresaRitaglio.nuovo;
    _pressX = math.min(math.max(0.0, px), imgW);
    _pressY = math.min(math.max(0.0, py), imgH);
    _inizio = rect;
  }

  PresaRitaglio? get presa => _presa;

  /// `mouseReleaseEvent`.
  void finisce() => _presa = null;

  /// `mouseMoveEvent` con una presa attiva. [spostamentoSchermo] = distanza (in punti dello schermo) dal punto
  /// toccato: un riquadro nuovo parte solo se il dito si è mosso davvero (5).
  void trascina(double px, double py, {double spostamentoSchermo = 99}) {
    final p = _presa;
    if (p == null) return;
    final sr = _inizio;
    switch (p) {
      case PresaRitaglio.sposta:
        final dx = px - _pressX, dy = py - _pressY;
        final x = math.min(math.max(0.0, sr.x + dx), imgW - sr.w);
        final y = math.min(math.max(0.0, sr.y + dy), imgH - sr.h);
        impostaRiquadro(Rect(x, y, sr.w, sr.h));
      case PresaRitaglio.nuovo:
        if (spostamentoSchermo < 5) return;
        impostaRiquadro(
          angolo(_pressX, _pressY, px, py, px >= _pressX, py >= _pressY),
        );
      case PresaRitaglio.tl ||
          PresaRitaglio.tr ||
          PresaRitaglio.bl ||
          PresaRitaglio.br:
        final right = p == PresaRitaglio.tr || p == PresaRitaglio.br;
        final bottom = p == PresaRitaglio.bl || p == PresaRitaglio.br;
        final ax = right ? sr.left : sr.right;
        final ay = bottom ? sr.top : sr.bottom;
        impostaRiquadro(angolo(ax, ay, px, py, right, bottom));
      case PresaRitaglio.l ||
          PresaRitaglio.r ||
          PresaRitaglio.t ||
          PresaRitaglio.b:
        impostaRiquadro(lato(p, px, py));
    }
  }

  /// `_corner`: riquadro con un angolo fermo in ([ax], [ay]) e quello opposto verso il punto ([px], [py]).
  Rect angolo(
    double ax,
    double ay,
    double px,
    double py,
    bool right,
    bool bottom,
  ) {
    final mn = latoMinimo;
    final maxW = right ? imgW - ax : ax;
    final maxH = bottom ? imgH - ay : ay;
    var w = math.min(math.max(mn, right ? (px - ax) : (ax - px)), maxW);
    var h = math.min(math.max(mn, bottom ? (py - ay) : (ay - py)), maxH);
    final rt = ratio;
    if (rt != null && rt != 0) {
      // Il riquadro segue il puntatore sul lato che si allunga di più, poi si stringe se esce
      if (w / h > rt) {
        h = w / rt;
      } else {
        w = h * rt;
      }
      final k = math.min(1.0, math.min(maxW / w, maxH / h));
      w *= k;
      h *= k;
    }
    return Rect(right ? ax : ax - w, bottom ? ay : ay - h, w, h);
  }

  /// `_edge`: ridimensiona da un lato, rispetto al riquadro di partenza della presa.
  Rect lato(PresaRitaglio presa, double px, double py) {
    final sr = _inizio;
    final mn = latoMinimo;
    if (presa == PresaRitaglio.l || presa == PresaRitaglio.r) {
      final r = presa == PresaRitaglio.r;
      final ax = r ? sr.left : sr.right;
      final maxW = r ? imgW - ax : ax;
      var w = math.min(math.max(mn, r ? (px - ax) : (ax - px)), maxW);
      var h = sr.h, y = sr.top;
      final rt = ratio;
      if (rt != null && rt != 0) {
        final cy = sr.centerY;
        h = math.min(w / rt, 2.0 * math.min(cy, imgH - cy));
        w = h * rt;
        y = cy - h / 2.0;
      }
      return Rect(r ? ax : ax - w, y, w, h);
    }
    final b = presa == PresaRitaglio.b;
    final ay = b ? sr.top : sr.bottom;
    final maxH = b ? imgH - ay : ay;
    var h = math.min(math.max(mn, b ? (py - ay) : (ay - py)), maxH);
    var w = sr.w, x = sr.left;
    final rt = ratio;
    if (rt != null && rt != 0) {
      final cx = sr.centerX;
      w = math.min(h * rt, 2.0 * math.min(cx, imgW - cx));
      h = w / rt;
      x = cx - w / 2.0;
    }
    return Rect(x, b ? ay : ay - h, w, h);
  }
}
