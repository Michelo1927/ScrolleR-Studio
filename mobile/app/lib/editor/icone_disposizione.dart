/// Icone delle disposizioni e degli stili del mosaico, disegnate a codice con la geometria di
/// `scrollr/icons.py` (`icon_pixmap`, `MOSAIC_ICON_CELLS`): sono uguali a quelle del desktop (piano §4.7).
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Schemi degli stili Mosaico su 24×24: (x, y, larghezza, altezza, in evidenza).
const Map<String, List<(double, double, double, double, bool)>>
_celleMosaico = {
  'auto': [(4, 4, 16, 9, true), (4, 15, 7, 5, false), (13, 15, 7, 5, false)],
  'top': [(4, 4, 16, 9, true), (4, 15, 7, 5, false), (13, 15, 7, 5, false)],
  'bottom': [(4, 11, 16, 9, true), (4, 4, 7, 5, false), (13, 4, 7, 5, false)],
  'left': [(4, 4, 9, 16, true), (15, 4, 5, 7, false), (15, 13, 5, 7, false)],
  'right': [(11, 4, 9, 16, true), (4, 4, 5, 7, false), (4, 13, 5, 7, false)],
  'center': [
    (8.5, 4, 7, 16, true),
    (3, 4, 3.8, 7.2, false),
    (3, 12.8, 3.8, 7.2, false),
    (17.2, 4, 3.8, 7.2, false),
    (17.2, 12.8, 3.8, 7.2, false),
  ],
  'two': [
    (4, 4, 7.5, 10, true),
    (12.5, 4, 7.5, 10, true),
    (4, 16, 4.6, 4, false),
    (9.7, 16, 4.6, 4, false),
    (15.4, 16, 4.6, 4, false),
  ],
  'masonry': [
    (4, 4, 4.6, 9, true),
    (4, 15, 4.6, 5, false),
    (9.7, 4, 4.6, 5, false),
    (9.7, 11, 4.6, 9, false),
    (15.4, 4, 4.6, 7, false),
    (15.4, 13, 4.6, 7, false),
  ],
};

/// Icona di una disposizione (`grid`, `mosaic`, `strips_h`, `strips_v`, `scatter`, `film`, `scrl_seam`) o di uno
/// stile del mosaico (`auto`, `top`, … `masonry`).
class IconaDisposizione extends StatelessWidget {
  const IconaDisposizione(
    this.nome, {
    super.key,
    required this.colore,
    this.misura = 28,
  });

  final String nome;
  final Color colore;
  final double misura;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: misura,
    height: misura,
    child: CustomPaint(painter: _Pittura(nome, colore)),
  );
}

class _Pittura extends CustomPainter {
  _Pittura(this.nome, this.colore);

  final String nome;
  final Color colore;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24.0, size.height / 24.0);
    final tratto = Paint()
      ..color = colore
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final velo = Paint()..color = colore.withValues(alpha: 0.30);

    void rr(
      double x,
      double y,
      double w,
      double h, {
      double r = 1.6,
      bool pieno = false,
    }) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h),
        Radius.circular(r),
      );
      if (pieno) canvas.drawRRect(rect, velo);
      canvas.drawRRect(rect, tratto);
    }

    // Come `clear()` del desktop: cancella una zona prima di disegnare il riquadro sopra
    void cancella(double x, double y, double w, double h) {
      canvas.drawRect(
        Rect.fromLTWH(x - 1.4, y - 1.4, w + 2.8, h + 2.8),
        Paint()..blendMode = BlendMode.clear,
      );
    }

    canvas.saveLayer(const Rect.fromLTWH(0, 0, 24, 24), Paint());
    switch (nome) {
      case 'grid':
        for (final (x, y) in const [
          (4.0, 4.0),
          (13.0, 4.0),
          (4.0, 13.0),
          (13.0, 13.0),
        ]) {
          rr(x, y, 7, 7, pieno: true);
        }
      case 'mosaic':
        rr(4, 4, 16, 9, pieno: true);
        rr(4, 15, 7, 5);
        rr(13, 15, 7, 5);
      case 'strips_h':
        for (final y in const [4.0, 10.0, 16.0]) {
          rr(4, y, 16, 4, r: 1.2, pieno: y == 4);
        }
      case 'strips_v':
        for (final x in const [4.0, 10.0, 16.0]) {
          rr(x, 4, 4, 16, r: 1.2, pieno: x == 4);
        }
      case 'scatter':
        canvas.save();
        canvas.translate(9, 11);
        canvas.rotate(-12 * math.pi / 180);
        rr(-5, -6, 10, 12, r: 1.2);
        canvas.restore();
        canvas.save();
        canvas.translate(15, 13);
        canvas.rotate(9 * math.pi / 180);
        cancella(-5, -6, 10, 12);
        rr(-5, -6, 10, 12, r: 1.2, pieno: true);
        canvas.restore();
      case 'film' || 'film_v':
        if (nome == 'film_v') {
          // Stessa pellicola, girata di 90°
          canvas.translate(24, 0);
          canvas.rotate(math.pi / 2);
        }
        rr(3, 5, 18, 14, r: 1.4);
        final pieno = Paint()..color = colore;
        for (final x in const [5.2, 9.2, 13.2, 17.2]) {
          canvas.drawRect(Rect.fromLTWH(x, 6.6, 1.6, 1.5), pieno);
          canvas.drawRect(Rect.fromLTWH(x, 15.9, 1.6, 1.5), pieno);
        }
        rr(5.2, 9.6, 6.3, 4.8, r: 0.8, pieno: true);
        rr(12.5, 9.6, 6.3, 4.8, r: 0.8);
      case 'scrl_seam':
        final sottile = Paint()
          ..color = colore
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        for (final x in const [2.5, 12.0]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, 5, 9.5, 14),
              const Radius.circular(1.2),
            ),
            sottile,
          );
        }
        cancella(7, 8.5, 10, 7);
        rr(7, 8.5, 10, 7, r: 1.2, pieno: true);
      default:
        final celle = _celleMosaico[nome];
        if (celle != null) {
          for (final (x, y, w, h, grande) in celle) {
            rr(x, y, w, h, pieno: grande);
          }
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Pittura old) => old.nome != nome || old.colore != colore;
}
