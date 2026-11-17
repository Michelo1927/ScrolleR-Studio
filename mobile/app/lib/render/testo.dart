/// Testi della tela, portati da `scrollr/canvas/text_item.py`: misura del riquadro (`relayout`) e disegno
/// (riquadro di sfondo, ombra in due passate, contorno delle lettere). Usato dallo schermo e dall'esportazione.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;

/// Riga di testo già impaginata (testo e larghezza).
class RigaTesto {
  final String testo;
  final double larghezza;
  const RigaTesto(this.testo, this.larghezza);
}

/// Impaginazione di un testo: righe, interlinea e riquadro (`_rect`, `_pad`).
class ImpaginazioneTesto {
  final TextItem t;
  final List<RigaTesto> righe;

  /// `fm.lineSpacing()`: altezza di una riga del carattere.
  final double altezzaRiga;

  /// `_line_step`: distanza tra l'inizio di una riga e quella dopo (con l'interlinea scelta).
  final double passo;
  final double larghezza;
  final double altezza;
  final double pad;

  ImpaginazioneTesto._(
    this.t,
    this.righe,
    this.altezzaRiga,
    this.passo,
    this.larghezza,
    this.altezza,
    this.pad,
  );

  factory ImpaginazioneTesto.di(TextItem t) {
    final righe = t.text.isEmpty ? const [' '] : t.text.split('\n');
    final misurate = [
      for (final r in righe)
        RigaTesto(r, _painter(t, r, const Color(0xFF000000)).width),
    ];
    final altezzaRiga = _painter(t, ' ', const Color(0xFF000000)).height;
    final passo = altezzaRiga * t.lineHeight / 100.0;
    final w = misurate.map((r) => r.larghezza).fold<double>(0, math.max);
    final h = altezzaRiga + passo * (righe.length - 1);
    final pad = t.pad;
    return ImpaginazioneTesto._(
      t,
      misurate,
      altezzaRiga,
      passo,
      w + 2 * pad,
      h + 2 * pad,
      pad,
    );
  }
}

/// Misura del riquadro di un testo, per il motore (`EngineContext.textSize`).
({double w, double h}) misuraTesto(TextItem t) {
  final l = ImpaginazioneTesto.di(t);
  return (w: l.larghezza, h: l.altezza);
}

/// Stile del carattere (`_font`): dimensione in pixel intera, grassetto, corsivo, spaziatura.
TextStyle _stile(TextItem t, {Color? colore, Paint? primoPiano}) => TextStyle(
  fontFamily: t.font,
  fontSize: math.max(4, pyRound(t.size)).toDouble(),
  fontWeight: t.bold ? FontWeight.w700 : FontWeight.w400,
  fontStyle: t.italic ? FontStyle.italic : FontStyle.normal,
  letterSpacing: t.letterSpacing != 0 ? t.size * t.letterSpacing / 100.0 : null,
  color: primoPiano == null ? colore : null,
  foreground: primoPiano,
);

TextPainter _painter(
  TextItem t,
  String riga,
  Color colore, {
  Paint? primoPiano,
}) => TextPainter(
  text: TextSpan(
    text: riga,
    style: _stile(t, colore: colore, primoPiano: primoPiano),
  ),
  textDirection: TextDirection.ltr,
  maxLines: 1,
)..layout();

Color _conOpacita(int argb, double opacita) {
  final c = Color(argb);
  return c.withValues(alpha: c.a * opacita);
}

/// Disegna il testo nel suo sistema locale (origine nell'angolo del riquadro, prima della rotazione).
void disegnaTesto(ui.Canvas canvas, TextItem t, ImpaginazioneTesto l) {
  // L'opacità dell'elemento vale per ogni pezzo disegnato, come `setOpacity` di Qt
  final op = (t.opacity / 100.0).clamp(0.0, 1.0);
  if (op <= 0) return;
  final rect = Rect.fromLTWH(0, 0, l.larghezza, l.altezza);
  if (t.box) {
    final r = t.size * 0.18;
    canvas.drawRRect(
      RRect.fromRectXY(rect, r, r),
      Paint()..color = _conOpacita(t.boxColor, op),
    );
  }
  final inner = rect.deflate(l.pad);
  final off = math.max(1.0, t.size * 0.035);
  final ombre = [
    (Offset(off * 0.9, off * 1.8), const Color.fromARGB(70, 0, 0, 0)),
    (Offset(off * 0.5, off), const Color.fromARGB(110, 0, 0, 0)),
  ];
  var y = inner.top;
  for (final riga in l.righe) {
    final x = switch (t.align) {
      'left' => inner.left,
      'right' => inner.right - riga.larghezza,
      _ => inner.left + (inner.width - riga.larghezza) / 2.0,
    };
    final pos = Offset(x, y);
    if (t.outline > 0) {
      // Contorno: le lettere bordate sotto e riempite sopra; l'ombra segue la sagoma col contorno
      Paint tratto(Color c) => Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = t.outline * 2.0
        ..strokeJoin = StrokeJoin.round
        ..color = c;
      if (t.shadow) {
        for (final (d, c) in ombre) {
          final cc = c.withValues(alpha: c.a * op);
          _painter(
            t,
            riga.testo,
            cc,
            primoPiano: tratto(cc),
          ).paint(canvas, pos + d);
          _painter(t, riga.testo, cc).paint(canvas, pos + d);
        }
      }
      _painter(
        t,
        riga.testo,
        const Color(0xFF000000),
        primoPiano: tratto(_conOpacita(t.outlineColor, op)),
      ).paint(canvas, pos);
      _painter(t, riga.testo, _conOpacita(t.color, op)).paint(canvas, pos);
    } else {
      if (t.shadow) {
        for (final (d, c) in ombre) {
          _painter(
            t,
            riga.testo,
            c.withValues(alpha: c.a * op),
          ).paint(canvas, pos + d);
        }
      }
      _painter(t, riga.testo, _conOpacita(t.color, op)).paint(canvas, pos);
    }
    y += l.passo;
  }
}
