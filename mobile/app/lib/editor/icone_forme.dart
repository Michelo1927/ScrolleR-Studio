/// Icone dei 9 tipi di forma, disegnate a codice con la stessa geometria della tela (`render/forme.dart`, da
/// `scrollr/shapes.py` e `scrollr/icons.py`): così sono uguali al desktop e non servono file immagine.
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import '../render/forme.dart';
import '../theme/tokens.dart';

/// L'icona del tipo di forma [tipo] (`rect`, `ellipse`… `double_arrow`), quadrata, a tinta unita.
class IconaForma extends StatelessWidget {
  const IconaForma({
    super.key,
    required this.tipo,
    this.dimensione = 36,
    this.colore = ColoriScrl.testo,
  });

  final String tipo;
  final double dimensione;
  final Color colore;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(dimensione),
      painter: _PitturaIconaForma(tipo, colore),
    ),
  );
}

class _PitturaIconaForma extends CustomPainter {
  _PitturaIconaForma(this.tipo, this.colore);

  final String tipo;
  final Color colore;

  @override
  void paint(Canvas canvas, Size size) {
    const lato = 100.0;
    final argb = colore.toARGB32();
    // Le forme piene riempiono il riquadro; le linee sono un tratto spesso a metà altezza
    final ShapeItem f;
    if (eLineaForma(tipo)) {
      const spessore = 9.0;
      f = ShapeItem(
        uid: 0,
        kind: tipo,
        w: lato,
        h: tipo == 'line' ? spessore : dimensionePunta(spessore),
        fill: 0x00000000,
        stroke: argb,
        strokeWidth: spessore,
      );
    } else {
      f = ShapeItem(
        uid: 0,
        kind: tipo,
        w: lato,
        h: lato,
        fill: argb,
        radius: 14,
      );
    }
    final k = size.width / lato;
    canvas.save();
    canvas.translate((size.width - f.w * k) / 2, (size.height - f.h * k) / 2);
    canvas.scale(k);
    disegnaForma(canvas, f);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PitturaIconaForma old) =>
      old.tipo != tipo || old.colore != colore;
}

/// Anteprima di uno stile di tratto (continuo, tratteggiato, a puntini): una linea orizzontale.
class IconaTratto extends StatelessWidget {
  const IconaTratto({
    super.key,
    required this.stile,
    this.larghezza = 56,
    this.colore = ColoriScrl.testo,
  });

  final String stile;
  final double larghezza;
  final Color colore;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size(larghezza, 16),
      painter: _PitturaTratto(stile, colore),
    ),
  );
}

class _PitturaTratto extends CustomPainter {
  _PitturaTratto(this.stile, this.colore);

  final String stile;
  final Color colore;

  @override
  void paint(Canvas canvas, Size size) {
    const spessore = 3.0;
    final penna = Paint()
      ..color = colore
      ..strokeWidth = spessore
      ..strokeCap = stile == 'dot' ? StrokeCap.round : StrokeCap.butt;
    final y = size.height / 2;
    // Stessi rapporti della tela: tratteggio 4 pieno e 2 vuoto, puntini 1 e 2 (in unità dello spessore)
    final (pieno, vuoto) = switch (stile) {
      'dash' => (4.0 * spessore, 2.0 * spessore),
      'dot' => (spessore * 0.01, 2.0 * spessore + spessore),
      _ => (size.width, 0.0),
    };
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + pieno, size.width), y),
        penna,
      );
      x += pieno + vuoto;
    }
  }

  @override
  bool shouldRepaint(_PitturaTratto old) =>
      old.stile != stile || old.colore != colore;
}
