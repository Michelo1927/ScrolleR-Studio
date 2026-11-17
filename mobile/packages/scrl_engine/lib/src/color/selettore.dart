/// Selettore colore (piano §4.6): conversioni tinta/saturazione/luminosità ⇄ ARGB, esadecimale, trasparenza e
/// colori già usati nel progetto. Il desktop usa `QColorDialog` e `ColorSwatchRow` (`scrollr/widgets.py`):
/// qui ci sono solo i numeri, l'interfaccia sta nell'app.
///
/// I colori sono interi ARGB come nel resto del motore (`0xAARRGGBB`).
library;

import 'dart:math' as math;

import '../model/snapshot.dart';

/// Colore in tinta (0–360°), saturazione e luminosità (0–1), come `QColor.toHsl`.
class Hsl {
  const Hsl(this.h, this.s, this.l);

  /// Tinta in gradi, da 0 (incluso) a 360 (escluso).
  final double h;
  final double s;
  final double l;

  @override
  bool operator ==(Object other) =>
      other is Hsl && other.h == h && other.s == s && other.l == l;

  @override
  int get hashCode => Object.hash(h, s, l);

  @override
  String toString() => 'Hsl($h, $s, $l)';
}

/// Da ARGB a tinta, saturazione e luminosità (l'alfa non conta). Un grigio ha tinta 0 e saturazione 0.
Hsl argbToHsl(int argb) {
  final r = ((argb >> 16) & 0xFF) / 255.0;
  final g = ((argb >> 8) & 0xFF) / 255.0;
  final b = (argb & 0xFF) / 255.0;
  final massimo = math.max(r, math.max(g, b));
  final minimo = math.min(r, math.min(g, b));
  final l = (massimo + minimo) / 2.0;
  final d = massimo - minimo;
  if (d == 0) return Hsl(0.0, 0.0, l);
  final s = l > 0.5 ? d / (2.0 - massimo - minimo) : d / (massimo + minimo);
  double h;
  if (massimo == r) {
    h = (g - b) / d + (g < b ? 6.0 : 0.0);
  } else if (massimo == g) {
    h = (b - r) / d + 2.0;
  } else {
    h = (r - g) / d + 4.0;
  }
  return Hsl(h * 60.0 % 360.0, s, l);
}

/// Da tinta (gradi), saturazione e luminosità (0–1) a ARGB con l'[alfa] dato (0–255, predefinito pieno).
int hslToArgb(double h, double s, double l, {int alfa = 0xFF}) {
  final hh = (h % 360.0 + 360.0) % 360.0 / 360.0;
  final ss = s.clamp(0.0, 1.0);
  final ll = l.clamp(0.0, 1.0);
  double r, g, b;
  if (ss == 0) {
    r = g = b = ll;
  } else {
    final q = ll < 0.5 ? ll * (1.0 + ss) : ll + ss - ll * ss;
    final p = 2.0 * ll - q;
    double canale(double t) {
      var x = t;
      if (x < 0) x += 1.0;
      if (x > 1) x -= 1.0;
      if (x < 1.0 / 6.0) return p + (q - p) * 6.0 * x;
      if (x < 0.5) return q;
      if (x < 2.0 / 3.0) return p + (q - p) * (2.0 / 3.0 - x) * 6.0;
      return p;
    }

    r = canale(hh + 1.0 / 3.0);
    g = canale(hh);
    b = canale(hh - 1.0 / 3.0);
  }
  int c(double v) => (v * 255.0).round().clamp(0, 255);
  return ((alfa.clamp(0, 255)) << 24) | (c(r) << 16) | (c(g) << 8) | c(b);
}

/// Legge un colore scritto a mano: `RRGGBB`, `#RRGGBB`, `RGB` o `#RGB` (maiuscole o minuscole, spazi ai lati
/// ignorati). Il risultato è pieno (alfa 255): la trasparenza si sceglie a parte. Null se il testo non è valido.
int? parseEsadecimale(String testo) {
  var t = testo.trim();
  if (t.startsWith('#')) t = t.substring(1);
  if (t.length != 3 && t.length != 6) return null;
  if (t.contains(RegExp('[^0-9a-fA-F]'))) return null;
  if (t.length == 3) {
    t = t.split('').map((c) => '$c$c').join();
  }
  return 0xFF000000 | int.parse(t, radix: 16);
}

/// `RRGGBB` maiuscolo, senza alfa (quella ha il suo cursore).
String formatEsadecimale(int argb) =>
    (argb & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0');

/// Alfa (0–255) di un colore.
int alfaDi(int argb) => (argb >>> 24) & 0xFF;

/// Lo stesso colore con un altro [alfa] (0–255).
int conAlfa(int argb, int alfa) =>
    (alfa.clamp(0, 255) << 24) | (argb & 0xFFFFFF);

/// Opacità del colore in percentuale (0–100), per il cursore «Trasparenza».
int percentualeAlfa(int argb) => (alfaDi(argb) * 100 / 255.0).round();

/// Colore con l'opacità [percentuale] (0–100).
int conPercentualeAlfa(int argb, int percentuale) =>
    conAlfa(argb, (percentuale.clamp(0, 100) * 255 / 100.0).round());

/// `is_light`: luminanza sopra 150 (pesi 0,299 · 0,587 · 0,114).
bool eChiaro(int argb) {
  final r = (argb >> 16) & 0xFF, g = (argb >> 8) & 0xFF, b = argb & 0xFF;
  return 0.299 * r + 0.587 * g + 0.114 * b > 150;
}

/// Colori usati dagli elementi del progetto e dallo sfondo, dal più frequente (a parità, dal primo incontrato).
/// Esclude i colori totalmente trasparenti, quelli di [escludi] (i campioni rapidi, già sotto mano) e conta un
/// colore una volta sola per ogni uso. Al massimo [massimo] colori.
///
/// Conta solo ciò che si vede: il colore del contorno di un testo senza contorno, del bordo di una forma senza
/// bordo, dell'etichetta spenta non sono «usati».
List<int> coloriDelProgetto(
  Snapshot s, {
  Set<int> escludi = const {},
  int massimo = 16,
}) {
  final conteggio = <int, int>{};
  final ordine = <int>[];
  void usa(int argb) {
    if (alfaDi(argb) == 0) return;
    if (escludi.contains(argb)) return;
    if (!conteggio.containsKey(argb)) ordine.add(argb);
    conteggio[argb] = (conteggio[argb] ?? 0) + 1;
  }

  final c = s.canvas;
  if (c.bgMode != 'blur') usa(c.bgColor);
  if (c.bgMode == 'gradient') usa(c.bgColor2);
  for (final t in s.texts) {
    usa(t.color);
    if (t.outline > 0) usa(t.outlineColor);
    if (t.box) usa(t.boxColor);
  }
  for (final f in s.shapes) {
    if (!f.isLine) usa(f.fill);
    if (f.isLine || f.strokeWidth > 0) usa(f.stroke);
  }
  for (final p in s.items) {
    if (p.borderWidth > 0) usa(p.borderColor);
  }
  final indice = {for (var i = 0; i < ordine.length; i++) ordine[i]: i};
  final l = [...ordine]
    ..sort((a, b) {
      final d = conteggio[b]!.compareTo(conteggio[a]!);
      return d != 0 ? d : indice[a]!.compareTo(indice[b]!);
    });
  return l.length > massimo ? l.sublist(0, massimo) : l;
}
