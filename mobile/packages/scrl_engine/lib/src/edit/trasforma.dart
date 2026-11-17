/// Ridimensiona e ruota una foto con le maniglie e con due dita, portato da `PhotoItem._resize_to`
/// (`scrollr/canvas/photo_item.py`) con le regole del telefono (piano §4.5):
///
/// - maniglie d'angolo: ridimensionano mantenendo le proporzioni;
/// - maniglie sui lati: cambiano la forma del riquadro e la foto lo riempie senza deformarsi (il campo `stretch`
///   non si tocca: lo stiramento vero si attiva con «Deforma» nello strumento Inquadra, sul desktop è il contrario);
/// - pizzico e rotazione: scala il riquadro e lo ruota, con scatti a 0°, 90° e ogni 15°.
library;

import 'dart:math' as math;

import '../model/elements.dart';

/// Le otto maniglie di una foto; la lettera dice da che lato sta (come `"tl"`, `"r"`… del desktop).
enum Maniglia {
  tl,
  t,
  tr,
  r,
  br,
  b,
  bl,
  l;

  bool get angolo => name.length == 2;
  bool get destra => name.contains('r');
  bool get basso => name.contains('b');
  bool get sinistra => name.contains('l');
  bool get alto => name.contains('t');

  /// Posizione della maniglia nel riquadro, in frazioni (0, 0,5 o 1) di larghezza e altezza.
  (double, double) get frazione =>
      (destra ? 1.0 : (sinistra ? 0.0 : 0.5), basso ? 1.0 : (alto ? 0.0 : 0.5));
}

/// Punto del riquadro locale [lx], [ly] (origine in alto a sinistra, prima della rotazione) in scena.
(double, double) localeInScena(PhotoItem p, double lx, double ly) {
  final t = p.rotation * math.pi / 180.0;
  final c = math.cos(t), s = math.sin(t);
  final dx = lx - p.w / 2.0, dy = ly - p.h / 2.0;
  return (p.x + p.w / 2.0 + dx * c - dy * s, p.y + p.h / 2.0 + dx * s + dy * c);
}

/// Punto in scena [sx], [sy] nel riquadro locale della foto (inverso di [localeInScena]).
(double, double) sceneInLocale(PhotoItem p, double sx, double sy) {
  final t = -p.rotation * math.pi / 180.0;
  final c = math.cos(t), s = math.sin(t);
  final dx = sx - (p.x + p.w / 2.0), dy = sy - (p.y + p.h / 2.0);
  return (p.w / 2.0 + dx * c - dy * s, p.h / 2.0 + dx * s + dy * c);
}

/// `_resize_to`: la foto [inizio] (com'era al tocco) con la maniglia [m] portata sul punto di scena ([px], [py]).
/// L'angolo (o il lato) opposto resta fermo.
///
/// Con [deforma] (interruttore «Deforma» di Inquadra) le maniglie sui lati stirano davvero la foto insieme al
/// riquadro (campo `stretch`, come sul desktop senza Shift): il contenuto visibile resta lo stesso, deformato.
PhotoItem ridimensionaFoto(
  PhotoItem inizio,
  Maniglia m,
  double px,
  double py, {
  bool deforma = false,
}) {
  final sx = m.destra ? 1.0 : -1.0;
  final sy = m.basso ? 1.0 : -1.0;
  final ancoraLocale = (sx > 0 ? 0.0 : inizio.w, sy > 0 ? 0.0 : inizio.h);
  final ancora = localeInScena(inizio, ancoraLocale.$1, ancoraLocale.$2);
  final (lx, ly) = _ruota(px - ancora.$1, py - ancora.$2, -inizio.rotation);
  var w = math.max(PhotoItem.minCell, sx * lx);
  var h = math.max(PhotoItem.minCell, sy * ly);
  if (m == Maniglia.l || m == Maniglia.r) {
    h = inizio.h;
  } else if (m == Maniglia.t || m == Maniglia.b) {
    w = inizio.w;
  } else {
    final rapporto = inizio.h > 0 ? inizio.w / inizio.h : 1.0;
    if (w / rapporto >= h) {
      h = w / rapporto;
    } else {
      w = h * rapporto;
    }
  }
  // Nuova posizione: l'ancora resta dov'era
  w = math.max(PhotoItem.minCell, w);
  h = math.max(PhotoItem.minCell, h);
  final nuovaAncora = (sx > 0 ? 0.0 : w, sy > 0 ? 0.0 : h);
  final (ox, oy) = _ruota(
    w / 2.0 - nuovaAncora.$1,
    h / 2.0 - nuovaAncora.$2,
    inizio.rotation,
  );
  final cx = ancora.$1 + ox, cy = ancora.$2 + oy;
  final lato =
      m == Maniglia.l || m == Maniglia.r || m == Maniglia.t || m == Maniglia.b;
  return inizio.copyWith(
    w: w,
    h: h,
    x: cx - w / 2.0,
    y: cy - h / 2.0,
    stretch: deforma && lato
        ? inizio.stretch * (w / inizio.w) * (inizio.h / h)
        : null,
    // Ridimensionata a mano: il riquadro «di prima» non vale più
    savedCell: () => null,
  );
}

(double, double) _ruota(double x, double y, double gradi) {
  final t = gradi * math.pi / 180.0;
  final c = math.cos(t), s = math.sin(t);
  return (x * c - y * s, x * s + y * c);
}

/// Angolo riportato tra −180° (escluso) e 180°.
double normalizzaGradi(double g) {
  var r = g % 360.0;
  if (r > 180.0) r -= 360.0;
  if (r <= -180.0) r += 360.0;
  return r;
}

/// Passo degli scatti della rotazione e distanza entro cui scatta.
const double passoRotazione = 15.0;
const double sogliaRotazione = 3.0;

/// Rotazione [gradi] con gli scatti ogni 15° (0° e 90° compresi) quando è a meno di 3° da uno di essi.
/// `agganciata` dice se è scattata, per il tocco aptico.
({double gradi, bool agganciata}) agganciaRotazione(double gradi) {
  final g = normalizzaGradi(gradi);
  final vicino = (g / passoRotazione).roundToDouble() * passoRotazione;
  if ((g - vicino).abs() <= sogliaRotazione) {
    return (gradi: normalizzaGradi(vicino), agganciata: true);
  }
  return (gradi: g, agganciata: false);
}

/// Pizzico e rotazione su una foto selezionata: [scala] moltiplica larghezza e altezza attorno al centro
/// (mai sotto il minimo), [gradi] si somma alla rotazione di partenza, con gli scatti.
({PhotoItem foto, bool agganciata}) trasformaFoto(
  PhotoItem inizio, {
  required double scala,
  required double gradi,
}) {
  final minimo = PhotoItem.minCell / math.min(inizio.w, inizio.h);
  final k = math.max(scala, minimo);
  final w = inizio.w * k, h = inizio.h * k;
  final r = agganciaRotazione(inizio.rotation + gradi);
  final cx = inizio.x + inizio.w / 2.0, cy = inizio.y + inizio.h / 2.0;
  return (
    foto: inizio.copyWith(
      w: w,
      h: h,
      x: cx - w / 2.0,
      y: cy - h / 2.0,
      rotation: r.gradi,
      savedCell: () => null,
    ),
    agganciata: r.agganciata,
  );
}
