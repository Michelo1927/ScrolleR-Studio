// Regolazioni colore delle foto (piano §8.4), stesse formule di `apply_adjustments` in scrollr/imaging.py.
// Ordine: livelli automatici → luminosità → contrasto → bianco e nero oppure saturazione → tabella dei toni
// → nitidezza. Tutto in sRGB a 8 bit come Pillow (ogni passo si limita a 0..1).
// Lo stesso shader serve l'anteprima e l'esportazione: per questo il raggio della nitidezza arriva in pixel
// dell'immagine, calcolato dall'app con `detail_scale`.
#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uDimensioni;   // Pixel dell'immagine
uniform float uAuto;        // 1 = livelli automatici (tabella uLivelli)
uniform float uLuminosita;  // Fattore di ImageEnhance.Brightness (1 = invariato)
uniform float uContrasto;   // Fattore di ImageEnhance.Contrast
uniform float uGrigio;      // Grigio medio della foto (0..1) per il contrasto
uniform float uBiancoNero;  // 1 = bianco e nero
uniform float uSaturazione; // Fattore di ImageEnhance.Color
uniform float uToni;        // 1 = tabella dei toni (uTabellaToni)
uniform float uNitidezza;   // percent / 100 di UnsharpMask (0 = niente)
uniform float uRaggio;      // Raggio (sigma) della nitidezza, in pixel dell'immagine
uniform float uSoglia;      // Soglia di UnsharpMask (0..1)
uniform sampler2D uImmagine;
uniform sampler2D uLivelli;     // 256×1: livelli automatici per canale in R, G, B
uniform sampler2D uTabellaToni; // 256×1: tabella dei toni per canale in R, G, B

out vec4 fragColor;

// Coordinata del valore v (0..1) nella tabella 256×1, al centro del suo pixel.
// (SkSL non accetta campionatori come parametri: una funzione per tabella)
vec2 indice(float v) {
  return vec2((floor(clamp(v, 0.0, 1.0) * 255.0 + 0.5) + 0.5) / 256.0, 0.5);
}

vec3 livelli(vec3 v) {
  return vec3(texture(uLivelli, indice(v.r)).r, texture(uLivelli, indice(v.g)).g,
              texture(uLivelli, indice(v.b)).b);
}

vec3 toni(vec3 v) {
  return vec3(texture(uTabellaToni, indice(v.r)).r, texture(uTabellaToni, indice(v.g)).g,
              texture(uTabellaToni, indice(v.b)).b);
}

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

// Pixel letto e corretto con tutti i passi tranne la nitidezza
vec3 colore(vec2 p) {
  vec4 t = texture(uImmagine, p / uDimensioni);
  vec3 c = t.a > 0.0 ? t.rgb / t.a : vec3(0.0);
  if (uAuto > 0.5) c = livelli(c);
  c = clamp(c * uLuminosita, 0.0, 1.0);
  c = clamp(uGrigio + (c - uGrigio) * uContrasto, 0.0, 1.0);
  if (uBiancoNero > 0.5) {
    c = vec3(luma(c));
  } else {
    float l = luma(c);
    c = clamp(l + (c - l) * uSaturazione, 0.0, 1.0);
  }
  if (uToni > 0.5) c = toni(c);
  return c;
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  float a = texture(uImmagine, p / uDimensioni).a;
  vec3 c = colore(p);
  if (uNitidezza > 0.0) {
    // Sfocatura gaussiana 9×9 con passo proporzionato al raggio (copre ±3 sigma)
    float passo = max(uRaggio * 0.75, 1.0);
    vec3 somma = vec3(0.0);
    float pesi = 0.0;
    for (int j = -4; j <= 4; j++) {
      for (int i = -4; i <= 4; i++) {
        vec2 d = vec2(float(i), float(j)) * passo;
        float w = exp(-dot(d, d) / (2.0 * uRaggio * uRaggio));
        somma += colore(p + d) * w;
        pesi += w;
      }
    }
    vec3 diff = c - somma / pesi;
    vec3 applica = step(vec3(uSoglia), abs(diff));
    c = clamp(c + diff * uNitidezza * applica, 0.0, 1.0);
  }
  fragColor = vec4(c * a, a);
}
