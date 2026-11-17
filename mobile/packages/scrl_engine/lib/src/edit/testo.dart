/// Strumento Testo (piano §6 «Testo»): aggiunta di un testo e modifica delle sue proprietà. Portato da
/// `scrollr/window/text.py` (`add_text`, `_on_text_prop`, `_pick_text_color`) e da `TextItem.relayout`.
///
/// Sono funzioni pure su [TextItem] e [Snapshot] immutabili: l'app le chiama mentre si trascina un cursore (bozza)
/// e a ✓ produce un passo di cronologia (l'equivalente di `_schedule_commit`).
library;

import 'dart:math' as math;

import '../color/selettore.dart';
import '../model/context.dart';
import '../model/elements.dart';
import '../model/scene.dart';
import '../model/snapshot.dart';
import '../util/py.dart';
import 'elementi.dart';
import 'trasforma.dart';

/// Intervalli dei cursori dell'inspector del desktop.
abstract final class LimitiTesto {
  static const int dimensioneMin = 12, dimensioneMax = 400;
  static const int interlineaMin = 60, interlineaMax = 250;
  static const int spaziaturaMin = -10, spaziaturaMax = 60;
  static const int contornoMin = 0, contornoMax = 40;
  static const int opacitaMin = 5, opacitaMax = 100;
  static const int rotazioneMin = -180, rotazioneMax = 180;
}

/// Testo di partenza di un testo nuovo (`TextItem.text`).
const String testoNuovo = 'Scrivi qui';

/// Allineamenti delle righe (`align`).
const List<String> allineamentiTesto = ['left', 'center', 'right'];

/// `add_text`: un testo nuovo al centro della pagina [pagina], davanti a tutto. I colori sono in contrasto con lo
/// sfondo: testo bianco con ombra e etichetta scura su sfondo scuro (o sfocato), testo scuro e etichetta chiara
/// su sfondo chiaro. La dimensione è il 7% della larghezza della pagina. [carattere] è il font di partenza
/// (sul desktop è quello di sistema, sul telefono uno di quelli inclusi).
({Snapshot snapshot, RifElemento ref}) aggiungiTesto(
  Snapshot s,
  EngineContext ctx, {
  required int pagina,
  required String carattere,
}) {
  final c = s.canvas;
  final scuro = c.bgMode == 'blur' || !eChiaro(c.bgColor);
  final sc = Scene(s, ctx);
  var t = TextItem(
    uid: ctx.newTextUid(),
    text: testoNuovo,
    font: carattere,
    size: pyRound(c.frameW * 0.07).toDouble(),
    color: scuro ? 0xFFFFFFFF : 0xFF1A1A1A,
    shadow: scuro,
    // Etichetta in contrasto col testo: scura dietro il testo bianco, chiara dietro quello scuro
    boxColor: scuro ? 0x96000000 : 0xD7FFFFFF,
    outlineColor: scuro ? 0xFF000000 : 0xFFFFFFFF,
    z: sc.maxZ() + 1.0,
  );
  final k = pagina.clamp(0, c.numFrames - 1);
  final m = ctx.textSize(t);
  t = t.copyWith(
    x: k * c.frameW + c.frameW / 2.0 - m.w / 2.0,
    y: c.frameH / 2.0 - m.h / 2.0,
  );
  sc.put(t);
  return (snapshot: sc.toSnapshot(), ref: rifDi(t));
}

/// Applica [f] ai testi di [s] con questi `uid` (gli altri restano come sono).
Snapshot modificaTesti(
  Snapshot s,
  Iterable<int> uids,
  TextItem Function(TextItem) f,
) {
  final set = uids.toSet();
  return s.copyWith(
    texts: [for (final t in s.texts) set.contains(t.uid) ? f(t) : t],
  );
}

/// `relayout(keep_center=True)`: dopo una modifica che cambia il riquadro il centro del testo resta dov'era.
/// Il riquadro non è nel file ma lo misura l'app ([EngineContext.textSize]), quindi si confronta prima e dopo.
TextItem _ricentrato(TextItem prima, TextItem dopo, EngineContext ctx) {
  final a = ctx.textSize(prima), b = ctx.textSize(dopo);
  if (a.w == b.w && a.h == b.h) return dopo;
  return dopo.copyWith(
    x: dopo.x + (a.w - b.w) / 2.0,
    y: dopo.y + (a.h - b.h) / 2.0,
  );
}

TextItem conScritto(TextItem t, String testo, EngineContext ctx) =>
    _ricentrato(t, t.copyWith(text: testo), ctx);

/// Cambia il carattere. Il nome si scrive nel file così com'è: se sul telefono manca, la tela disegna con quello
/// predefinito ma il nome resta (piano §8.5).
TextItem conCarattere(TextItem t, String nome, EngineContext ctx) =>
    _ricentrato(t, t.copyWith(font: nome), ctx);

TextItem conDimensione(TextItem t, int v, EngineContext ctx) => _ricentrato(
  t,
  t.copyWith(
    size: v
        .clamp(LimitiTesto.dimensioneMin, LimitiTesto.dimensioneMax)
        .toDouble(),
  ),
  ctx,
);

TextItem conGrassetto(TextItem t, bool acceso, EngineContext ctx) =>
    _ricentrato(t, t.copyWith(bold: acceso), ctx);

TextItem conCorsivo(TextItem t, bool acceso, EngineContext ctx) =>
    _ricentrato(t, t.copyWith(italic: acceso), ctx);

/// [allineamento]: `left`, `center` o `right`; un altro valore lascia il testo com'è.
TextItem conAllineamento(TextItem t, String allineamento) =>
    allineamentiTesto.contains(allineamento)
    ? t.copyWith(align: allineamento)
    : t;

TextItem conInterlinea(TextItem t, int v, EngineContext ctx) => _ricentrato(
  t,
  t.copyWith(
    lineHeight: v.clamp(LimitiTesto.interlineaMin, LimitiTesto.interlineaMax),
  ),
  ctx,
);

TextItem conSpaziatura(TextItem t, int v, EngineContext ctx) => _ricentrato(
  t,
  t.copyWith(
    letterSpacing: v.clamp(
      LimitiTesto.spaziaturaMin,
      LimitiTesto.spaziaturaMax,
    ),
  ),
  ctx,
);

TextItem conColoreTesto(TextItem t, int argb) => t.copyWith(color: argb);

TextItem conContorno(TextItem t, int v, EngineContext ctx) => _ricentrato(
  t,
  t.copyWith(
    outline: v
        .clamp(LimitiTesto.contornoMin, LimitiTesto.contornoMax)
        .toDouble(),
  ),
  ctx,
);

/// `_pick_text_color('outline')`: scelto il colore, il contorno si vede subito (almeno 2 px, il 5% del carattere).
TextItem conColoreContorno(TextItem t, int argb, EngineContext ctx) {
  final dopo = t.outline <= 0
      ? t.copyWith(
          outlineColor: argb,
          outline: math.max(2.0, pyRound(t.size * 0.05).toDouble()),
        )
      : t.copyWith(outlineColor: argb);
  return _ricentrato(t, dopo, ctx);
}

TextItem conOmbraTesto(TextItem t, bool acceso) => t.copyWith(shadow: acceso);

/// Etichetta accesa o spenta: il riquadro cambia il margine interno, quindi il testo si ricentra.
TextItem conEtichetta(TextItem t, bool accesa, EngineContext ctx) =>
    _ricentrato(t, t.copyWith(box: accesa), ctx);

/// `_pick_text_color('box')`: scegliere il colore accende l'etichetta.
TextItem conColoreEtichetta(TextItem t, int argb, EngineContext ctx) =>
    _ricentrato(t, t.copyWith(boxColor: argb, box: true), ctx);

TextItem conOpacitaTesto(TextItem t, int v) => t.copyWith(
  opacity: v.clamp(LimitiTesto.opacitaMin, LimitiTesto.opacitaMax),
);

/// Rotazione in gradi, tra −180° e 180°. Il testo ruota attorno al suo centro, che resta fermo.
TextItem conRotazioneTesto(TextItem t, int gradi) => t.copyWith(
  rotation: gradi
      .clamp(LimitiTesto.rotazioneMin, LimitiTesto.rotazioneMax)
      .toDouble(),
);

/// Pizzico e rotazione a due dita su un testo: [scala] moltiplica la dimensione del carattere (12–400) attorno al
/// centro, [gradi] si somma alla rotazione, con gli scatti ogni 15°. `agganciata` dice se la rotazione è scattata.
({TextItem testo, bool agganciata}) trasformaTesto(
  TextItem inizio,
  EngineContext ctx, {
  required double scala,
  required double gradi,
}) {
  final a = ctx.textSize(inizio);
  final cx = inizio.x + a.w / 2.0, cy = inizio.y + a.h / 2.0;
  final size = (inizio.size * scala).clamp(
    LimitiTesto.dimensioneMin.toDouble(),
    LimitiTesto.dimensioneMax.toDouble(),
  );
  final r = agganciaRotazione(inizio.rotation + gradi);
  final g = inizio.copyWith(size: size, rotation: r.gradi);
  final b = ctx.textSize(g);
  return (
    testo: g.copyWith(x: cx - b.w / 2.0, y: cy - b.h / 2.0),
    agganciata: r.agganciata,
  );
}
