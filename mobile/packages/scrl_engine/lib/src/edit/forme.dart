/// Strumento Forme (piano §6 «Forme»): aggiunta, cambio di tipo, stile e ridimensionamento. Portato da
/// `scrollr/window/shapes.py` (`add_shape`, `_on_shape_prop`, `_set_shape_color`, `_remember_shape_style`) e da
/// `scrollr/canvas/shape_item.py` (`set_size`, `refresh_geometry`, `_resize_to`, `_drag_endpoint`).
/// La geometria dei contorni sta nell'app (`render/forme.dart`, da `scrollr/shapes.py`).
///
/// Sono funzioni pure su [ShapeItem] e [Snapshot] immutabili: l'app le chiama mentre si trascina un cursore o
/// una maniglia (bozza) e a ✓ o a fine gesto produce un passo di cronologia (`_schedule_commit`).
library;

import 'dart:math' as math;

import '../model/canvas_state.dart';
import '../model/context.dart';
import '../model/elements.dart';
import '../model/scene.dart';
import '../model/snapshot.dart';
import '../util/py.dart';
import 'elementi.dart';
import 'trasforma.dart';

/// I 9 tipi, nell'ordine di `SHAPE_KINDS`: prima le forme piene, poi le linee (`LINE_KINDS`).
const List<String> tipiForma = [
  'rect',
  'ellipse',
  'triangle',
  'diamond',
  'star',
  'heart',
  'line',
  'arrow',
  'double_arrow',
];

/// Stili del tratto (`stroke_style`): continuo, tratteggiato, a puntini.
const List<String> stiliTratto = ['solid', 'dash', 'dot'];

/// Intervalli dei cursori dell'inspector del desktop.
abstract final class LimitiForma {
  static const int spessoreMin = 0, spessoreMax = 80;
  static const int angoliMin = 0, angoliMax = 300;
  static const int opacitaMin = 5, opacitaMax = 100;
  static const int rotazioneMin = -180, rotazioneMax = 180;
}

bool eLineaForma(String kind) => lineKinds.contains(kind);

/// `arrow_head_size`: lunghezza (e larghezza) della punta di una freccia con tratto di spessore [width].
double dimensionePunta(double width) => math.max(1.0, width) * 3.0 + 10.0;

/// `_visible_stroke_width`: spessore che si vede bene sulla pagina (almeno 2, lo 0,8% del lato corto).
double spessoreVisibile(CanvasState c) =>
    math.max(2, pyRound(math.min(c.frameW, c.frameH) * 0.008)).toDouble();

/// Altezza del riquadro di una linea: lo spessore, o la punta della freccia (`_line_box_height`).
double _altezzaLinea(String kind, double strokeWidth) {
  final sw = math.max(1.0, strokeWidth);
  return kind != 'line' ? dimensionePunta(sw) : sw;
}

/// Stile di una forma, quello che le prossime forme dello stesso tipo ereditano (`_remember_shape_style`).
class StileForma {
  const StileForma({
    required this.fill,
    required this.stroke,
    required this.strokeWidth,
    required this.strokeStyle,
    required this.radius,
  });

  /// `SHAPE_DEFAULTS`: rosso pieno con bordo bianco assente per le forme piene; linea rossa per le linee.
  /// Lo spessore della linea è null: dipende dalla pagina (1% del lato corto, almeno 2).
  factory StileForma.predefinito({required bool linea}) => linea
      ? const StileForma(
          fill: 0x00000000,
          stroke: 0xFFFF3B30,
          strokeWidth: null,
          strokeStyle: 'solid',
          radius: 0.0,
        )
      : const StileForma(
          fill: 0xFFFF3B30,
          stroke: 0xFFFFFFFF,
          strokeWidth: 0.0,
          strokeStyle: 'solid',
          radius: 0.0,
        );

  factory StileForma.di(ShapeItem f) => StileForma(
    fill: f.fill,
    stroke: f.stroke,
    strokeWidth: f.strokeWidth,
    strokeStyle: f.strokeStyle,
    radius: f.radius,
  );

  final int fill;
  final int stroke;
  final double? strokeWidth;
  final String strokeStyle;
  final double radius;
}

/// Gli ultimi stili usati: uno per le forme piene e uno per le linee. Come sul desktop stanno solo in memoria
/// (non entrano nel progetto né in Annulla).
class StiliForma {
  const StiliForma({this.piena, this.linea});

  final StileForma? piena;
  final StileForma? linea;

  /// Stile con cui nasce una forma nuova: l'ultimo usato per quel gruppo, altrimenti quello di partenza.
  StileForma per({required bool linea}) =>
      (linea ? this.linea : piena) ?? StileForma.predefinito(linea: linea);

  /// Ricorda lo stile di [f] per le forme dello stesso gruppo.
  StiliForma ricorda(ShapeItem f) => f.isLine
      ? StiliForma(piena: piena, linea: StileForma.di(f))
      : StiliForma(piena: StileForma.di(f), linea: linea);
}

/// `add_shape`: una forma nuova al centro della pagina [pagina], davanti a tutto, con l'ultimo stile usato
/// ([stili]). Le forme piene sono il 30% del lato corto della pagina (il rettangolo 1,3 volte più largo);
/// le linee lunghe il 42%.
({Snapshot snapshot, RifElemento ref}) aggiungiForma(
  Snapshot s,
  EngineContext ctx, {
  required String kind,
  required int pagina,
  StiliForma stili = const StiliForma(),
}) {
  final c = s.canvas;
  final sc = Scene(s, ctx);
  final linea = eLineaForma(kind);
  final stile = stili.per(linea: linea);
  final base = math.min(c.frameW, c.frameH) * 0.3;
  final sw =
      stile.strokeWidth ??
      math.max(2, pyRound(math.min(c.frameW, c.frameH) * 0.01)).toDouble();
  final w = linea ? base * 1.4 : base * (kind == 'rect' ? 1.3 : 1.0);
  final h = linea ? _altezzaLinea(kind, sw) : base;
  final k = pagina.clamp(0, c.numFrames - 1);
  final f = ShapeItem(
    uid: ctx.newShapeUid(),
    kind: kind,
    w: w,
    h: h,
    x: k * c.frameW + c.frameW / 2.0 - w / 2.0,
    y: c.frameH / 2.0 - h / 2.0,
    fill: stile.fill,
    stroke: stile.stroke,
    strokeWidth: sw,
    strokeStyle: stile.strokeStyle,
    radius: stile.radius,
    z: sc.maxZ() + 1.0,
  );
  sc.put(f);
  return (snapshot: sc.toSnapshot(), ref: rifDi(f));
}

/// Applica [f] alle forme di [s] con questi `uid` (le altre restano come sono).
Snapshot modificaForme(
  Snapshot s,
  Iterable<int> uids,
  ShapeItem Function(ShapeItem) f,
) {
  final set = uids.toSet();
  return s.copyWith(
    shapes: [for (final x in s.shapes) set.contains(x.uid) ? f(x) : x],
  );
}

/// `set_size` + `setPos`: la forma con la misura [w] × [h] e il centro in ([cx], [cy]).
ShapeItem _conCentro(ShapeItem f, double cx, double cy, double w, double h) {
  final g = f.copyWith(w: w, h: h);
  return g.copyWith(x: cx - g.w / 2.0, y: cy - g.h / 2.0);
}

/// `refresh_geometry`: dopo un cambio di tipo o di spessore una linea ricalcola l'altezza, il centro resta fermo.
ShapeItem _geometriaAggiornata(ShapeItem f) => f.isLine
    ? _conCentro(
        f,
        f.x + f.w / 2.0,
        f.y + f.h / 2.0,
        f.w,
        _altezzaLinea(f.kind, f.strokeWidth),
      )
    : f;

/// Cambio di tipo tenendo stile e posizione (`_on_shape_prop('kind')`). Da forma piena a linea (o viceversa) la
/// larghezza resta e l'altezza si adatta al tipo nuovo (¾ della larghezza per le forme piene); una linea nata da
/// una forma piena ha almeno lo spessore visibile. Il centro non si muove.
ShapeItem conTipoForma(ShapeItem f, String kind, CanvasState c) {
  if (!tipiForma.contains(kind) || kind == f.kind) return f;
  var g = f.copyWith(kind: kind);
  if (g.isLine != f.isLine) {
    final sw = g.isLine
        ? math.max(g.strokeWidth, spessoreVisibile(c))
        : g.strokeWidth;
    // Il centro è quello della forma di prima: il costruttore potrebbe aver già corretto l'altezza
    g = _conCentro(
      g.copyWith(strokeWidth: sw),
      f.x + f.w / 2.0,
      f.y + f.h / 2.0,
      g.w,
      g.isLine ? 1.0 : g.w * 0.75,
    );
  }
  return _geometriaAggiornata(g);
}

/// `_set_shape_color('fill')`: il colore di riempimento (non vale per linee e frecce). Senza riempimento né
/// bordo la forma sparirebbe: resta il contorno.
ShapeItem conRiempimento(ShapeItem f, int argb, CanvasState c) {
  if (f.isLine) return f;
  final g = f.copyWith(fill: argb);
  return (argb >>> 24) == 0 && g.strokeWidth <= 0
      ? g.copyWith(strokeWidth: spessoreVisibile(c))
      : g;
}

/// `_set_shape_color('stroke')`: scegliere il colore del bordo lo mostra (una forma piena senza bordo ne prende uno).
ShapeItem conColoreTratto(ShapeItem f, int argb, CanvasState c) {
  final g = f.copyWith(stroke: argb);
  return g.strokeWidth <= 0 && !g.isLine
      ? g.copyWith(strokeWidth: spessoreVisibile(c))
      : g;
}

/// Spessore del bordo o della linea (0 = senza bordo). Una linea ricalcola l'altezza del riquadro.
ShapeItem conSpessoreForma(ShapeItem f, int v) => _geometriaAggiornata(
  f.copyWith(
    strokeWidth: v
        .clamp(LimitiForma.spessoreMin, LimitiForma.spessoreMax)
        .toDouble(),
  ),
);

ShapeItem conTratto(ShapeItem f, String stile) =>
    stiliTratto.contains(stile) ? f.copyWith(strokeStyle: stile) : f;

/// Angoli arrotondati (solo il rettangolo li disegna).
ShapeItem conAngoliForma(ShapeItem f, int v) => f.copyWith(
  radius: v.clamp(LimitiForma.angoliMin, LimitiForma.angoliMax).toDouble(),
);

ShapeItem conOpacitaForma(ShapeItem f, int v) => f.copyWith(
  opacity: v.clamp(LimitiForma.opacitaMin, LimitiForma.opacitaMax),
);

ShapeItem conRotazioneForma(ShapeItem f, int gradi) => f.copyWith(
  rotation: gradi
      .clamp(LimitiForma.rotazioneMin, LimitiForma.rotazioneMax)
      .toDouble(),
);

// ---------------------------------------------------------------- Gesti sulla tela

/// Punto locale ([lx], [ly]) del riquadro w × h in (x, y) ruotato di [gradi] attorno al centro, in scena.
(double, double) _inScena(
  double x,
  double y,
  double w,
  double h,
  double gradi,
  double lx,
  double ly,
) {
  final t = gradi * math.pi / 180.0;
  final c = math.cos(t), s = math.sin(t);
  final dx = lx - w / 2.0, dy = ly - h / 2.0;
  return (x + w / 2.0 + dx * c - dy * s, y + h / 2.0 + dx * s + dy * c);
}

/// Punto locale della forma [f] (origine in alto a sinistra, prima della rotazione) in scena.
(double, double) formaInScena(ShapeItem f, double lx, double ly) =>
    _inScena(f.x, f.y, f.w, f.h, f.rotation, lx, ly);

/// Posizione in scena del pallino di rotazione: sopra il centro del lato alto, a [distanza] unità di scena.
(double, double) pallinoRotazione(ShapeItem f, double distanza) =>
    formaInScena(f, f.w / 2.0, -distanza);

(double, double) _ruota(double x, double y, double gradi) {
  final t = gradi * math.pi / 180.0;
  final c = math.cos(t), s = math.sin(t);
  return (x * c - y * s, x * s + y * c);
}

/// `_resize_to`: la forma [inizio] (com'era al tocco) con la maniglia [m] portata sul punto di scena ([px], [py]);
/// l'angolo (o il lato) opposto resta fermo. Le maniglie d'angolo mantengono le proporzioni, quelle sui lati
/// cambiano una sola misura (piano §4.5). Non vale per linee e frecce: lì ci sono gli estremi ([estremoLinea]).
ShapeItem ridimensionaForma(
  ShapeItem inizio,
  Maniglia m,
  double px,
  double py,
) {
  if (inizio.isLine) return inizio;
  final (fx, fy) = m.frazione;
  final ax = 1.0 - fx, ay = 1.0 - fy;
  final ancora = formaInScena(inizio, ax * inizio.w, ay * inizio.h);
  final (lx, ly) = _ruota(px - ancora.$1, py - ancora.$2, -inizio.rotation);
  var w = fx == 0.5
      ? inizio.w
      : math.max(ShapeItem.minSize, (fx == 1.0 ? 1.0 : -1.0) * lx);
  var h = fy == 0.5
      ? inizio.h
      : math.max(ShapeItem.minSize, (fy == 1.0 ? 1.0 : -1.0) * ly);
  if (m.angolo) {
    final rapporto = inizio.h > 0 ? inizio.w / inizio.h : 1.0;
    if (w / rapporto >= h) {
      h = w / rapporto;
    } else {
      w = h * rapporto;
    }
  }
  w = math.max(ShapeItem.minSize, w);
  h = math.max(ShapeItem.minSize, h);
  // Nuova posizione: l'ancora resta dov'era
  final (ox, oy) = _ruota(w / 2.0 - ax * w, h / 2.0 - ay * h, inizio.rotation);
  final cx = ancora.$1 + ox, cy = ancora.$2 + oy;
  return inizio.copyWith(w: w, h: h, x: cx - w / 2.0, y: cy - h / 2.0);
}

/// Gli estremi di una linea o freccia: `inizio` a sinistra del riquadro, `fine` a destra.
enum EstremoLinea { inizio, fine }

/// Posizione in scena di un estremo della linea.
(double, double) estremoInScena(ShapeItem f, EstremoLinea e) =>
    formaInScena(f, e == EstremoLinea.inizio ? 0.0 : f.w, f.h / 2.0);

/// `_drag_endpoint`: sposta un estremo della linea sul punto ([px], [py]); l'altro resta fermo, cambiano lunghezza
/// e direzione. L'angolo scatta ogni 15° (0° e 90° compresi) se è a meno di 3° da uno scatto. L'esito dice se è
/// scattato, per il tocco aptico.
({ShapeItem forma, bool agganciata}) spostaEstremo(
  ShapeItem inizio,
  EstremoLinea estremo,
  double px,
  double py,
) {
  final ancora = estremoInScena(
    inizio,
    estremo == EstremoLinea.fine ? EstremoLinea.inizio : EstremoLinea.fine,
  );
  final vx = estremo == EstremoLinea.fine ? px - ancora.$1 : ancora.$1 - px;
  final vy = estremo == EstremoLinea.fine ? py - ancora.$2 : ancora.$2 - py;
  final r = agganciaRotazione(math.atan2(vy, vx) * 180.0 / math.pi);
  final w = math.max(ShapeItem.minSize, math.sqrt(vx * vx + vy * vy));
  final h = inizio.h;
  // Il punto fisso (l'altro estremo) torna sull'ancora
  final fissoX = estremo == EstremoLinea.fine ? 0.0 : w;
  final (ox, oy) = _ruota(w / 2.0 - fissoX, 0.0, r.gradi);
  final cx = ancora.$1 + ox, cy = ancora.$2 + oy;
  return (
    forma: inizio.copyWith(
      w: w,
      h: h,
      rotation: r.gradi,
      x: cx - w / 2.0,
      y: cy - h / 2.0,
    ),
    agganciata: r.agganciata,
  );
}

/// Pallino sopra la forma: la forma ruota perché il pallino segua il punto ([px], [py]) (rotazione dal centro,
/// con gli scatti ogni 15°).
({ShapeItem forma, bool agganciata}) ruotaConPallino(
  ShapeItem f,
  double px,
  double py,
) {
  final cx = f.x + f.w / 2.0, cy = f.y + f.h / 2.0;
  final gradi = math.atan2(py - cy, px - cx) * 180.0 / math.pi + 90.0;
  final r = agganciaRotazione(gradi);
  return (forma: f.copyWith(rotation: r.gradi), agganciata: r.agganciata);
}

/// Pizzico e rotazione a due dita su una forma: [scala] moltiplica le misure attorno al centro (mai sotto il
/// minimo; una linea si allunga soltanto), [gradi] si somma alla rotazione, con gli scatti.
({ShapeItem forma, bool agganciata}) trasformaForma(
  ShapeItem inizio, {
  required double scala,
  required double gradi,
}) {
  final minimo = inizio.isLine
      ? ShapeItem.minSize / inizio.w
      : ShapeItem.minSize / math.min(inizio.w, inizio.h);
  final k = math.max(scala, minimo);
  final w = inizio.w * k, h = inizio.isLine ? inizio.h : inizio.h * k;
  final r = agganciaRotazione(inizio.rotation + gradi);
  final cx = inizio.x + inizio.w / 2.0, cy = inizio.y + inizio.h / 2.0;
  final g = inizio.copyWith(w: w, h: h, rotation: r.gradi);
  return (
    forma: g.copyWith(x: cx - g.w / 2.0, y: cy - g.h / 2.0),
    agganciata: r.agganciata,
  );
}
