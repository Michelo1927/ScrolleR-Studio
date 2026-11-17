/// Contagocce: il colore che la pagina ha in un punto, letto dal disegno vero (stesso modulo di schermo ed
/// esportazione), così comprende foto, sfondo, sfumature, testi e forme come si vedono.
library;

import 'dart:ui' as ui;

import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import 'disegno.dart';

/// Il colore (ARGB, sempre opaco) della pagina [pagina] di [s] nel punto ([x], [y]), in unità della tela con
/// l'origine nell'angolo in alto a sinistra della pagina. Disegna solo un riquadro di 3 × 3 pixel attorno al punto,
/// quindi costa poco anche su una pagina grande. Null se il punto è fuori dalla pagina o la lettura non riesce.
Future<int?> coloreNelPunto(
  Snapshot s,
  int pagina,
  RisorseDisegno risorse,
  TestiDisegno testi,
  double x,
  double y,
) async {
  final c = s.canvas;
  if (x < 0 || y < 0 || x >= c.frameW || y >= c.frameH) return null;
  final registratore = ui.PictureRecorder();
  final tela = ui.Canvas(registratore, const ui.Rect.fromLTWH(0, 0, 3, 3));
  // Il punto cade sul pixel centrale (1, 1) dell'immagine
  tela.translate(1 - x, 1 - y);
  disegnaPagina(
    tela,
    s,
    pagina,
    risorse,
    OpzioniDisegno(testi: testi, pulito: true),
  );
  final quadro = registratore.endRecording();
  try {
    final img = await quadro.toImage(3, 3);
    try {
      final byte = await img.toByteData();
      if (byte == null) return null;
      const centro = (1 * 3 + 1) * 4;
      final r = byte.getUint8(centro);
      final g = byte.getUint8(centro + 1);
      final b = byte.getUint8(centro + 2);
      return 0xFF000000 | (r << 16) | (g << 8) | b;
    } finally {
      img.dispose();
    }
  } finally {
    quadro.dispose();
  }
}
