/// Zona sicura dei reel (`REEL_SAFE_MARGINS` e `reel_safe_rect` in `scrollr/canvas/scene.py`): nelle pagine
/// 9:16 Instagram copre con la sua interfaccia il 14% in alto, il 35% in basso e il 6% ai lati.
library;

import '../model/elements.dart';

/// Margini della zona sicura in frazioni della pagina.
abstract final class MarginiReel {
  static const double sinistra = 0.06;
  static const double alto = 0.14;
  static const double destra = 0.06;
  static const double basso = 0.35;
}

/// Zona sicura di una pagina [w] × [h] nelle sue coordinate, solo se la pagina è 9:16; altrimenti null.
Rect? zonaSicuraReel(double w, double h) {
  if (h <= 0 || (w / h - 9.0 / 16.0).abs() > 0.01) return null;
  return Rect(
    w * MarginiReel.sinistra,
    h * MarginiReel.alto,
    w * (1.0 - MarginiReel.sinistra - MarginiReel.destra),
    h * (1.0 - MarginiReel.alto - MarginiReel.basso),
  );
}
