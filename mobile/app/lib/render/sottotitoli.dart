/// Blocchi di sottotitoli della tela, portati da `scrollr/canvas/caption_item.py`: misura del riquadro
/// (`_content_size`) e disegno di una frase (`phrase_paths`, `paint_phrase`). La frase si appoggia al fondo del
/// riquadro, su una o due righe bilanciate, con la traduzione sotto. Usato dallo schermo, dall'esportazione e
/// dall'anteprima della schermata Sottotitoli.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import 'caratteri.dart';

/// Stile della frase (`_font`): come un testo, con la dimensione in pixel intera.
TextStyle _stileFrase(TextItem t, {Color? colore, Paint? primoPiano}) =>
    TextStyle(
      fontFamily: Caratteri.perDisegno(t.font),
      fontSize: math.max(4, pyRound(t.size)).toDouble(),
      fontWeight: t.bold ? FontWeight.w700 : FontWeight.w400,
      fontStyle: t.italic ? FontStyle.italic : FontStyle.normal,
      letterSpacing: t.letterSpacing != 0
          ? t.size * t.letterSpacing / 100.0
          : null,
      color: primoPiano == null ? colore : null,
      foreground: primoPiano,
    );

/// Stile della traduzione (`_tr_font`): più piccola, corsiva se scelto, senza spaziatura in più.
TextStyle _stileTraduzione(CaptionItem c, {Color? colore, Paint? primoPiano}) =>
    TextStyle(
      fontFamily: Caratteri.perDisegno(c.stile.font),
      fontSize: math
          .max(4, pyRound(c.stile.size * c.trSize / 100.0))
          .toDouble(),
      fontWeight: c.stile.bold ? FontWeight.w700 : FontWeight.w400,
      fontStyle: c.trItalic ? FontStyle.italic : FontStyle.normal,
      color: primoPiano == null ? colore : null,
      foreground: primoPiano,
    );

TextPainter _painter(String riga, TextStyle stile) => TextPainter(
  text: TextSpan(text: riga, style: stile),
  textDirection: TextDirection.ltr,
  maxLines: 1,
)..layout();

/// Misure del carattere di un blocco: altezza di una riga della frase e della traduzione.
class ImpaginazioneSottotitoli {
  final CaptionItem c;

  /// `fm.lineSpacing()` della frase e della traduzione.
  final double altezzaRiga;
  final double altezzaRigaTr;

  /// `_line_step`: distanza tra l'inizio di una riga e quella dopo (con l'interlinea scelta).
  final double passo;
  final double larghezza;
  final double altezza;
  final double pad;

  ImpaginazioneSottotitoli._(
    this.c,
    this.altezzaRiga,
    this.altezzaRigaTr,
    this.passo,
    this.larghezza,
    this.altezza,
    this.pad,
  );

  /// `_content_size` più i margini: la larghezza scelta e il posto per due righe di frase (più due di
  /// traduzione, se c'è).
  factory ImpaginazioneSottotitoli.di(CaptionItem c) {
    final t = c.stile;
    final riga = _painter(' ', _stileFrase(t)).height;
    final rigaTr = _painter(' ', _stileTraduzione(c)).height;
    final passo = riga * t.lineHeight / 100.0;
    var h = riga + passo;
    if (c.mostraTraduzione) h += t.size * 0.12 + rigaTr * 2;
    final pad = c.pad;
    return ImpaginazioneSottotitoli._(
      c,
      riga,
      rigaTr,
      passo,
      c.wrapW + 2 * pad,
      h + 2 * pad,
      pad,
    );
  }

  /// Larghezza di una riga della frase (`fm.horizontalAdvance`).
  double larghezzaFrase(String s) => _painter(s, _stileFrase(c.stile)).width;

  /// Larghezza di una riga della traduzione.
  double larghezzaTraduzione(String s) =>
      _painter(s, _stileTraduzione(c)).width;
}

/// Misura del riquadro di un blocco, per il motore (`EngineContext.captionSize`).
({double w, double h}) misuraSottotitoli(CaptionItem c) {
  final l = ImpaginazioneSottotitoli.di(c);
  return (w: l.larghezza, h: l.altezza);
}

/// Riga già posizionata nel sistema locale del blocco.
class _Riga {
  final String testo;
  final Offset pos;
  final double larghezza;
  final bool traduzione;
  const _Riga(this.testo, this.pos, this.larghezza, this.traduzione);
}

/// `phrase_paths`: righe della frase e della traduzione appoggiate al fondo di [inner].
List<_Riga> _righe(ImpaginazioneSottotitoli l, Frase frase, Rect inner) {
  final c = l.c;
  final tr = c.trShow ? pyStrip(frase.tr) : '';
  final righe = bilanciaRighe(frase.testo, l.larghezzaFrase, inner.width);
  final righeTr = tr.isEmpty
      ? const <String>[]
      : bilanciaRighe(tr, l.larghezzaTraduzione, inner.width);
  var altezza = l.altezzaRiga + l.passo * (righe.length - 1);
  if (righeTr.isNotEmpty) {
    altezza += c.stile.size * 0.12 + l.altezzaRigaTr * righeTr.length;
  }
  var y = inner.bottom - altezza;
  final out = <_Riga>[];
  void aggiungi(String riga, double w, bool traduzione) {
    final x = switch (c.stile.align) {
      'left' => inner.left,
      'right' => inner.right - w,
      _ => inner.left + (inner.width - w) / 2.0,
    };
    out.add(_Riga(riga, Offset(x, y), w, traduzione));
  }

  for (final r in righe) {
    aggiungi(r, l.larghezzaFrase(r), false);
    y += l.passo;
  }
  if (righeTr.isNotEmpty) {
    y += l.altezzaRiga - l.passo + c.stile.size * 0.12;
    for (final r in righeTr) {
      aggiungi(r, l.larghezzaTraduzione(r), true);
      y += l.altezzaRigaTr;
    }
  }
  return out;
}

/// `paint_phrase`: una frase con lo stile del blocco, nel suo sistema locale (origine nell'angolo del riquadro).
/// [opacita] moltiplica quella del blocco (la frase di esempio sulla tela è al 45%).
void disegnaFrase(
  ui.Canvas canvas,
  ImpaginazioneSottotitoli l,
  Frase frase, {
  double opacita = 1.0,
}) {
  if (pyStrip(frase.testo).isEmpty && pyStrip(frase.tr).isEmpty) return;
  final c = l.c;
  final t = c.stile;
  final op = (t.opacity / 100.0).clamp(0.0, 1.0) * opacita;
  if (op <= 0) return;
  final inner = Rect.fromLTWH(
    l.pad,
    l.pad,
    l.larghezza - 2 * l.pad,
    l.altezza - 2 * l.pad,
  );
  final righe = _righe(l, frase, inner);
  // L'opacità vale per il blocco intero (`setOpacity` di Qt): si disegna in uno strato
  final strato = op < 1.0;
  if (strato) {
    canvas.saveLayer(
      null,
      Paint()..color = Color.fromARGB((op * 255).round(), 0, 0, 0),
    );
  }
  TextStyle stile(_Riga r, {Color? colore, Paint? primoPiano}) => r.traduzione
      ? _stileTraduzione(c, colore: colore, primoPiano: primoPiano)
      : _stileFrase(t, colore: colore, primoPiano: primoPiano);

  if (t.box && righe.isNotEmpty) {
    final pad = t.size * 0.22;
    final raggio = t.size * 0.18;
    final paint = Paint()..color = Color(t.boxColor);
    for (final r in righe) {
      final h = r.traduzione ? l.altezzaRigaTr : l.altezzaRiga;
      final box = Rect.fromLTWH(
        r.pos.dx - pad,
        r.pos.dy - pad * 0.35,
        r.larghezza + 2 * pad,
        h + pad * 0.7,
      );
      canvas.drawRRect(RRect.fromRectXY(box, raggio, raggio), paint);
    }
  }
  if (t.shadow) {
    // Ombra morbida: alone scuro fatto di tratti sempre più sottili e appena spostati in basso
    final off = Offset(0, t.size * 0.03);
    for (final (spessore, alfa) in const [
      (0.34, 14),
      (0.24, 20),
      (0.15, 28),
      (0.08, 40),
    ]) {
      final tratto = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = t.size * spessore
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = Color.fromARGB(alfa, 0, 0, 0);
      for (final r in righe) {
        _painter(
          r.testo,
          stile(r, primoPiano: tratto),
        ).paint(canvas, r.pos + off);
      }
    }
    for (final r in righe) {
      _painter(
        r.testo,
        stile(r, colore: const Color.fromARGB(90, 0, 0, 0)),
      ).paint(canvas, r.pos + off);
    }
  }
  if (t.outline > 0) {
    final tratto = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = t.outline * 2.0
      ..strokeJoin = StrokeJoin.round
      ..color = Color(t.outlineColor);
    for (final r in righe) {
      _painter(r.testo, stile(r, primoPiano: tratto)).paint(canvas, r.pos);
    }
  }
  for (final r in righe) {
    _painter(
      r.testo,
      stile(r, colore: Color(r.traduzione ? c.trColor : t.color)),
    ).paint(canvas, r.pos);
  }
  if (strato) canvas.restore();
}

/// `CaptionItem.paint`: la frase del secondo [tempo] del video originale. Fuori dalle frasi, se [esempio] è
/// vero (sulla tela, a video fermo), la prima frase in trasparenza per vedere stile e posizione, oppure la
/// parola [segnaposto] se non ci sono frasi.
void disegnaSottotitoli(
  ui.Canvas canvas,
  CaptionItem c,
  ImpaginazioneSottotitoli l,
  double? tempo, {
  required bool esempio,
  required String segnaposto,
}) {
  final frase = fraseAlTempo(c, tempo);
  if (frase != null) {
    disegnaFrase(canvas, l, frase);
  } else if (esempio) {
    disegnaFrase(
      canvas,
      l,
      fraseDiEsempio(c) ?? Frase(testo: segnaposto),
      opacita: 0.45,
    );
  }
}
