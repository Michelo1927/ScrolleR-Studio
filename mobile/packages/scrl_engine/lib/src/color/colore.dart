/// Regolazioni colore delle foto, portate da `scrollr/imaging.py`.
///
/// Qui ci sono solo i numeri (tabelle, fattori, filtri pronti), calcolati con le stesse formule del desktop:
/// l'app li passa allo shader che colora la foto, uguale per lo schermo e per l'esportazione (piano §8.4).
/// Ordine delle operazioni: livelli automatici → luminosità → contrasto → bianco e nero **oppure** saturazione →
/// tabella dei toni → nitidezza. Vignettatura e grana si disegnano sopra la foto.
library;

import 'dart:math' as math;

import '../model/elements.dart';
import '../util/py.dart';
import '../util/py_random.dart';

/// Regolazioni che cambiano i pixel della foto (`PIXEL_ADJUST`); le altre sono effetti disegnati sopra.
const List<String> pixelAdjust = [
  'brightness',
  'contrast',
  'shadows',
  'highlights',
  'saturation',
  'warmth',
  'tint',
  'sharpness',
  'fade',
  'bw',
  'auto',
];

/// Filtro pronto: chiave e valori (`PRESETS`). Il nome da mostrare sta nei file `.arb`.
class Preset {
  final String key;
  final Map<String, Object?> values;
  const Preset(this.key, this.values);
}

/// I 9 filtri pronti del desktop, con gli stessi valori.
const List<Preset> presets = [
  Preset('original', {}),
  Preset('vivid', {'contrast': 15, 'saturation': 35, 'sharpness': 30}),
  Preset('summer', {
    'warmth': 35,
    'saturation': 15,
    'shadows': 15,
    'vignette': -15,
  }),
  Preset('film', {
    'fade': 35,
    'contrast': -10,
    'saturation': -15,
    'warmth': 10,
    'grain': 25,
  }),
  Preset('vintage', {
    'fade': 40,
    'warmth': 40,
    'tint': 10,
    'saturation': -30,
    'vignette': -35,
    'grain': 30,
  }),
  Preset('bw_contrast', {
    'bw': true,
    'contrast': 35,
    'vignette': -20,
    'grain': 15,
  }),
  Preset('cold', {'warmth': -35, 'contrast': 10, 'highlights': -10}),
  Preset('soft', {
    'fade': 20,
    'contrast': -15,
    'highlights': -20,
    'shadows': 20,
  }),
  Preset('dramatic', {
    'contrast': 30,
    'shadows': -15,
    'highlights': -25,
    'saturation': -10,
    'sharpness': 40,
    'vignette': -40,
  }),
];

/// `preset_adjust`: regolazioni complete di un filtro pronto (le voci che non usa tornano a zero).
Map<String, Object?> presetAdjust(String key) {
  final p = presets.where((p) => p.key == key);
  return {...neutralAdjust, if (p.isNotEmpty) ...p.first.values};
}

/// Valore numerico di una regolazione (`adj.get(k, 0)`; i booleani valgono 0/1 come in Python).
double adjValue(Map<String, Object?> adj, String key) {
  final v = adj[key];
  if (v is num) return v.toDouble();
  if (v is bool) return v ? 1.0 : 0.0;
  return 0.0;
}

/// Verità alla Python (`if adj.get(k)`): 0, False e None sono falsi.
bool adjOn(Map<String, Object?> adj, String key) => adjValue(adj, key) != 0.0;

/// `adjustments_active`: almeno una regolazione cambia i pixel.
bool adjustmentsActive(Map<String, Object?> adj) =>
    pixelAdjust.any((k) => adjOn(adj, k));

/// `_tone_lut`: ombre, luci, sbiadito, calore e tinta in un'unica tabella (768 valori: R, poi G, poi B).
/// Null se non serve.
List<int>? toneLut(Map<String, Object?> adj) {
  final shadows = adjValue(adj, 'shadows') / 100.0;
  final highlights = adjValue(adj, 'highlights') / 100.0;
  final fade = adjValue(adj, 'fade') / 100.0 * 0.25;
  final warm = adjValue(adj, 'warmth') / 100.0 * 0.18;
  final tint = adjValue(adj, 'tint') / 100.0 * 0.12;
  if (shadows == 0 && highlights == 0 && fade == 0 && warm == 0 && tint == 0) {
    return null;
  }
  final tone = <double>[];
  for (var v = 0; v < 256; v++) {
    var x = v / 255.0;
    // Ombre agiscono sui toni scuri (picco a 1/3), luci su quelli chiari (picco a 2/3)
    x +=
        shadows * 1.6 * x * math.pow(1.0 - x, 2) +
        highlights * 1.6 * x * x * (1.0 - x);
    x = fade + x * (1.0 - fade); // Sbiadito: i neri diventano grigi scuri
    tone.add(math.min(1.0, math.max(0.0, x)));
  }
  // Calore: più rosso e meno blu. Tinta: + magenta (meno verde), − verde
  final gains = [1.0 + warm + tint * 0.5, 1.0 - tint, 1.0 - warm + tint * 0.5];
  return [
    for (final g in gains)
      for (final t in tone) math.max(0, math.min(255, pyRound(t * 255.0 * g))),
  ];
}

/// Istogramma RGB (768 valori, come `Image.histogram()` di un'immagine RGB) da pixel RGBA.
List<int> histogramRgb(List<int> rgba) {
  final h = List<int>.filled(768, 0);
  for (var i = 0; i + 3 < rgba.length; i += 4) {
    h[rgba[i]]++;
    h[256 + rgba[i + 1]]++;
    h[512 + rgba[i + 2]]++;
  }
  return h;
}

/// `auto_levels_lut` a partire dall'istogramma della foto intera ridotta a 400 px:
/// si scarta lo 0,5% dei pixel più scuri e più chiari, per canale.
List<int> autoLevelsLut(List<int> histogram) {
  final lut = <int>[];
  for (var c = 0; c < 3; c++) {
    final h = histogram.sublist(c * 256, (c + 1) * 256);
    final total = h.fold<int>(0, (a, b) => a + b);
    final cut = total * 0.005;
    var lo = 0, acc = 0;
    while (lo < 255 && acc + h[lo] <= cut) {
      acc += h[lo];
      lo++;
    }
    var hi = 255;
    acc = 0;
    while (hi > 0 && acc + h[hi] <= cut) {
      acc += h[hi];
      hi--;
    }
    if (hi <= lo) {
      lut.addAll(List<int>.generate(256, (v) => v));
    } else {
      final scale = 255.0 / (hi - lo);
      for (var v = 0; v < 256; v++) {
        lut.add(math.max(0, math.min(255, pyRound((v - lo) * scale))));
      }
    }
  }
  return lut;
}

/// Fattore di `ImageEnhance` per una regolazione da −100 a +100.
double enhanceFactor(Map<String, Object?> adj, String key) =>
    1.0 + adjValue(adj, key) / 100.0;

/// `Image.blend` di Pillow a 8 bit: `in1 + alpha·(in2 − in1)`, troncato e limitato a 0..255.
int pillowBlend(int in1, int in2, double alpha) {
  final t = in1 + alpha * (in2 - in1);
  if (t <= 0) return 0;
  if (t >= 255) return 255;
  return t.toInt();
}

/// Luminanza 601 di Pillow (`L24`, arrotondata), usata da contrasto, saturazione e bianco e nero.
int pillowLuma(int r, int g, int b) =>
    (r * 19595 + g * 38470 + b * 7471 + 0x8000) >> 16;

/// Grigio medio (0..255) che `ImageEnhance.Contrast` usa per questa foto: media della luminanza
/// dopo livelli automatici e luminosità, arrotondata come `int(mean + 0.5)`. [rgba] è una versione
/// piccola della foto (bastano poche centinaia di pixel di lato).
int contrastMean(
  List<int> rgba,
  Map<String, Object?> adj, {
  List<int>? autoLut,
}) {
  final useAuto = adjOn(adj, 'auto') && autoLut != null;
  final bright = adjOn(adj, 'brightness');
  final f = enhanceFactor(adj, 'brightness');
  var sum = 0, n = 0;
  for (var i = 0; i + 3 < rgba.length; i += 4) {
    var r = rgba[i], g = rgba[i + 1], b = rgba[i + 2];
    if (useAuto) {
      r = autoLut[r];
      g = autoLut[256 + g];
      b = autoLut[512 + b];
    }
    if (bright) {
      r = pillowBlend(0, r, f);
      g = pillowBlend(0, g, f);
      b = pillowBlend(0, b, f);
    }
    sum += pillowLuma(r, g, b);
    n++;
  }
  return n == 0 ? 0 : (sum / n + 0.5).floor();
}

/// Raggio (in pixel dell'immagine) e intensità della nitidezza (`UnsharpMask`): il raggio dipende da
/// `detail_scale` = larghezza della foto intera in pixel / 1000, così è uguale in anteprima e in esportazione.
({double radius, double percent, int threshold}) sharpenParams(
  Map<String, Object?> adj,
  double detailScale,
) => (
  radius: math.max(0.6, 1.4 * detailScale),
  percent: pyRound(adjValue(adj, 'sharpness') * 1.6).toDouble(),
  threshold: 2,
);

/// Lato del riquadro di grana (`grain_tile`).
const int grainSide = 256;

/// Riquadro di rumore grigio della grana, sempre uguale (`random.Random(20261022).randbytes(256 * 256)`).
List<int> grainTileBytes() =>
    PyRandom(20261022).randbytes(grainSide * grainSide);
