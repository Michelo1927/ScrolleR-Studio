/// Forme della tela, portate da `scrollr/shapes.py` e `scrollr/canvas/shape_item.py`: contorni delle forme
/// piene, linee e frecce, tratteggi e opacità della forma intera.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:scrl_engine/scrl_engine.dart';

/// Cuore in coordinate 0..1: punta in basso, due lobi in alto (curve di Bézier), come `_HEART`.
const List<List<(double, double)>> _cuore = [
  [(0.15, 0.72), (0.0, 0.52), (0.0, 0.30)],
  [(0.0, 0.12), (0.13, 0.0), (0.28, 0.0)],
  [(0.40, 0.0), (0.47, 0.07), (0.5, 0.17)],
  [(0.53, 0.07), (0.60, 0.0), (0.72, 0.0)],
  [(0.87, 0.0), (1.0, 0.12), (1.0, 0.30)],
  [(1.0, 0.52), (0.85, 0.72), (0.5, 1.0)],
];

/// `shape_path`: contorno di una forma piena che riempie [r] (radius = angoli arrotondati del rettangolo).
ui.Path percorsoForma(String kind, ui.Rect r, [double radius = 0.0]) {
  final x = r.left, y = r.top, w = r.width, h = r.height;
  final p = ui.Path();
  switch (kind) {
    case 'ellipse':
      p.addOval(r);
    case 'triangle':
      p.addPolygon([
        ui.Offset(x + w / 2.0, y),
        ui.Offset(x + w, y + h),
        ui.Offset(x, y + h),
      ], true);
    case 'diamond':
      p.addPolygon([
        ui.Offset(x + w / 2.0, y),
        ui.Offset(x + w, y + h / 2.0),
        ui.Offset(x + w / 2.0, y + h),
        ui.Offset(x, y + h / 2.0),
      ], true);
    case 'star':
      final cx = x + w / 2.0, cy = y + h / 2.0;
      p.addPolygon([
        for (var i = 0; i < 10; i++)
          ui.Offset(
            cx +
                (i.isEven ? 1.0 : 0.42) *
                    w /
                    2.0 *
                    math.cos((-90 + i * 36) * math.pi / 180),
            cy +
                (i.isEven ? 1.0 : 0.42) *
                    h /
                    2.0 *
                    math.sin((-90 + i * 36) * math.pi / 180),
          ),
      ], true);
    case 'heart':
      p.moveTo(x + 0.5 * w, y + h);
      for (final c in _cuore) {
        p.cubicTo(
          x + c[0].$1 * w,
          y + c[0].$2 * h,
          x + c[1].$1 * w,
          y + c[1].$2 * h,
          x + c[2].$1 * w,
          y + c[2].$2 * h,
        );
      }
      p.close();
    default: // 'rect'
      final rr = math.max(0.0, math.min(radius, math.min(w / 2.0, h / 2.0)));
      p.addRRect(ui.RRect.fromRectXY(r, rr, rr));
  }
  return p;
}

/// `arrow_head_size`: lunghezza (e larghezza) della punta di una freccia.
double puntaFreccia(double width) => math.max(1.0, width) * 3.0 + 10.0;

/// Spessore del tratto di una linea (`line_width`).
double spessoreLinea(ShapeItem s) => math.max(1.0, s.strokeWidth);

/// Tratteggio di Qt in unità dello spessore: `DashLine` = 4 pieno, 2 vuoto; `DotLine` = 1 e 2.
List<double>? _motivo(String stile) => switch (stile) {
  'dash' => const [4.0, 2.0],
  'dot' => const [1.0, 2.0],
  _ => null,
};

ui.Paint _penna(ShapeItem s, double width, int argb) => ui.Paint()
  ..style = ui.PaintingStyle.stroke
  ..strokeWidth = width
  ..color = ui.Color(argb)
  ..isAntiAlias = true
  ..strokeMiterLimit =
      2.0 // Limite predefinito di QPen
  ..strokeCap = s.strokeStyle == 'dot' || s.isLine
      ? ui.StrokeCap.round
      : ui.StrokeCap.butt
  ..strokeJoin = s.kind == 'heart' || s.kind == 'ellipse'
      ? ui.StrokeJoin.round
      : ui.StrokeJoin.miter;

/// Traccia [p] con il tratteggio dello stile (pieno se `solid`).
void _traccia(ui.Canvas c, ui.Path p, ui.Paint penna, String stile) {
  final motivo = _motivo(stile);
  if (motivo == null) {
    c.drawPath(p, penna);
    return;
  }
  final w = penna.strokeWidth;
  for (final m in p.computeMetrics()) {
    var d = 0.0;
    var k = 0;
    while (d < m.length) {
      final l = motivo[k % 2] * w;
      if (k.isEven) {
        c.drawPath(m.extractPath(d, math.min(d + l, m.length)), penna);
      }
      d += l;
      k++;
    }
  }
}

/// `_box_path`: contorno della forma piena rientrato di mezzo bordo (il bordo resta dentro il riquadro).
ui.Path percorsoRiquadro(ShapeItem s) {
  final inset = math.min(s.strokeWidth / 2.0, math.min(s.w / 2.0, s.h / 2.0));
  final r = ui.Rect.fromLTWH(inset, inset, s.w - 2 * inset, s.h - 2 * inset);
  return percorsoForma(s.kind, r, math.max(0.0, s.radius - inset));
}

void _disegnaLinea(ui.Canvas c, ShapeItem s) {
  final sw = spessoreLinea(s);
  final y = s.h / 2.0;
  final head = math.min(
    puntaFreccia(sw),
    s.w / (s.kind == 'double_arrow' ? 2.2 : 1.2),
  );
  final cap = sw / 2.0;
  var x0 = s.kind == 'double_arrow' ? head * 0.8 : cap;
  var x1 = s.kind != 'line' ? s.w - head * 0.8 : s.w - cap;
  if (s.strokeStyle != 'solid' && s.kind != 'line') {
    x0 = s.kind == 'double_arrow' ? head : cap;
    x1 = s.w - head;
  }
  if (x1 <= x0) {
    x0 = x1 = s.w / 2.0; // Linea più corta del suo spessore: resta un punto
  }
  final asta = ui.Path()
    ..moveTo(x0, y)
    ..lineTo(x1, y);
  _traccia(c, asta, _penna(s, sw, s.stroke), s.strokeStyle);
  final pieno = ui.Paint()
    ..color = ui.Color(s.stroke)
    ..isAntiAlias = true;
  final punte = s.kind == 'line'
      ? const <(double, double)>[]
      : [(s.w, -1.0), if (s.kind == 'double_arrow') (0.0, 1.0)];
  for (final (tipX, d) in punte) {
    final base = tipX + d * head;
    c.drawPath(
      ui.Path()..addPolygon([
        ui.Offset(tipX, y),
        ui.Offset(base, y - head / 2.0),
        ui.Offset(base, y + head / 2.0),
      ], true),
      pieno,
    );
  }
}

void _disegnaContenuto(ui.Canvas c, ShapeItem s) {
  if (s.isLine) {
    _disegnaLinea(c, s);
    return;
  }
  final p = percorsoRiquadro(s);
  if ((s.fill >>> 24) > 0) {
    c.drawPath(
      p,
      ui.Paint()
        ..color = ui.Color(s.fill)
        ..isAntiAlias = true,
    );
  }
  if (s.strokeWidth > 0) {
    _traccia(c, p, _penna(s, s.strokeWidth, s.stroke), s.strokeStyle);
  }
}

/// Disegna la forma nel suo sistema locale. Semitrasparente: disegnata piena su un livello e sfumata tutta
/// insieme (`_paint_translucent`), così asta e punta o riempimento e bordo non si sommano.
void disegnaForma(ui.Canvas c, ShapeItem s) {
  if (s.opacity >= 100) {
    _disegnaContenuto(c, s);
    return;
  }
  if (s.opacity <= 0) return;
  final pad = s.isLine ? spessoreLinea(s) : 0.0;
  c.saveLayer(
    ui.Rect.fromLTWH(-pad - 2, -pad - 2, s.w + 2 * pad + 4, s.h + 2 * pad + 4),
    ui.Paint()
      ..color = ui.Color.fromARGB((255 * s.opacity / 100).round(), 0, 0, 0),
  );
  _disegnaContenuto(c, s);
  c.restore();
}
