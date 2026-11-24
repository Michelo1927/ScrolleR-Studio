/// Zona sicura dei reel (`REEL_SAFE_MARGINS`, `REEL_SAFE_BUTTONS` e `reel_safe_polygon` in
/// `scrollr/canvas/scene.py`): nelle pagine 9:16 Instagram copre con la sua interfaccia l'11% in alto, il 16% in
/// basso e il 6% ai lati; dal 61% dell'altezza in giù la colonna dei pulsanti copre il 21% a destra.
library;

/// Margini della zona sicura in frazioni della pagina.
abstract final class MarginiReel {
  static const double sinistra = 0.06;
  static const double alto = 0.11;
  static const double destra = 0.06;
  static const double basso = 0.16;

  /// Margine destro della colonna dei pulsanti (mi piace, commenti, condividi)…
  static const double destraPulsanti = 0.21;

  /// …e altezza da cui comincia.
  static const double altoPulsanti = 0.61;
}

/// Zona sicura di una pagina [w] × [h] nelle sue coordinate, solo se la pagina è 9:16 (altrimenti null):
/// i sei vertici del rettangolo con il rientro in basso a destra, in senso orario dall'angolo in alto a sinistra.
List<(double, double)>? zonaSicuraReel(double w, double h) {
  if (h <= 0 || (w / h - 9.0 / 16.0).abs() > 0.01) return null;
  final sx = w * MarginiReel.sinistra;
  final dx = w * (1.0 - MarginiReel.destra);
  final dxPulsanti = w * (1.0 - MarginiReel.destraPulsanti);
  final su = h * MarginiReel.alto;
  final giu = h * (1.0 - MarginiReel.basso);
  final yPulsanti = h * MarginiReel.altoPulsanti;
  return [
    (sx, su),
    (dx, su),
    (dx, yPulsanti),
    (dxPulsanti, yPulsanti),
    (dxPulsanti, giu),
    (sx, giu),
  ];
}
