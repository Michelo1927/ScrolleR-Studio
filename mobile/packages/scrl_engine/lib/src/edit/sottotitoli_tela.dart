/// Blocchi di sottotitoli sulla tela: creazione per un video, frasi e proprietà.
///
/// Portato da `scrollr/window/captions.py` (`add_captions_to_video`, `_place_new_caption`, `_on_caption_prop`)
/// e da `CaptionItem` (`set_phrases`, `relayout`). Funzioni pure su [Snapshot] e [CaptionItem] immutabili.
library;

import '../model/context.dart';
import '../model/elements.dart';
import '../model/scene.dart';
import '../model/snapshot.dart';
import '../util/py.dart';
import 'elementi.dart';
import 'sottotitoli.dart';
import 'testo.dart' show LimitiTesto;
import 'trasforma.dart' show agganciaRotazione;
import 'zona_reel.dart';

/// Il blocco di sottotitoli del video [videoUid] (`_captions_of`), se c'è.
CaptionItem? sottotitoliDelVideo(Snapshot s, int videoUid) {
  for (final c in s.captions) {
    if (c.videoUid == videoUid) return c;
  }
  return null;
}

/// Il video collegato al blocco (`_caption_video`), se è sulla tela.
PhotoItem? videoDeiSottotitoli(Snapshot s, CaptionItem c) {
  for (final p in s.items) {
    if (p.isVideo && p.uid == c.videoUid) return p;
  }
  return null;
}

/// `add_captions_to_video` + `_place_new_caption`: il blocco del video [videoUid]; se non c'è ancora si crea,
/// centrato e verso il centro-basso della pagina del video, davanti a tutto. Sulle pagine 9:16 il fondo del
/// blocco sta dove comincia la colonna dei pulsanti, così resta tutto nella zona sicura del reel.
/// Null se il video non è sulla tela.
({Snapshot snapshot, RifElemento ref, bool nuovo})? aggiungiSottotitoli(
  Snapshot s,
  int videoUid,
  EngineContext ctx,
) {
  final esistente = sottotitoliDelVideo(s, videoUid);
  if (esistente != null) {
    return (snapshot: s, ref: rifDi(esistente), nuovo: false);
  }
  final sc = Scene(s, ctx);
  final video = sc.photos[videoUid];
  if (video == null || !video.isVideo) return null;
  final fw = sc.frameW.toDouble(), fh = sc.frameH.toDouble();
  final k = sc.pageOf(video);
  var c = CaptionItem.nuovo(uid: ctx.newTextUid(), videoUid: videoUid);
  c = c.copyWith(
    stile: c.stile.copyWith(
      size: pyRound(fw * 0.054).toDouble(),
      z: sc.maxZ() + 1.0,
    ),
    wrapW: pyRound(fw * 0.80).toDouble(),
  );
  final zona = zonaSicuraReel(fw, fh);
  final fondo = zona != null ? zona[2].$2 : fh * 0.86;
  final m = ctx.captionSize(c);
  c = c.withPosition(k * fw + (fw - m.w) / 2.0, fondo - m.h);
  sc.put(c);
  return (snapshot: sc.toSnapshot(), ref: rifDi(c), nuovo: true);
}

/// Applica [f] ai blocchi di sottotitoli di [s] con questi `uid` (gli altri restano come sono).
Snapshot modificaSottotitoli(
  Snapshot s,
  Iterable<int> uids,
  CaptionItem Function(CaptionItem) f,
) {
  final set = uids.toSet();
  return s.copyWith(
    captions: [for (final c in s.captions) set.contains(c.uid) ? f(c) : c],
  );
}

/// `relayout(keep_center=True)`: dopo una modifica che cambia il riquadro il centro del blocco resta dov'era.
CaptionItem _ricentrato(
  CaptionItem prima,
  CaptionItem dopo,
  EngineContext ctx,
) {
  final a = ctx.captionSize(prima), b = ctx.captionSize(dopo);
  if (a.w == b.w && a.h == b.h) return dopo;
  return dopo.withPosition(
    dopo.x + (a.w - b.w) / 2.0,
    dopo.y + (a.h - b.h) / 2.0,
  );
}

/// `set_phrases`: frasi nuove (pulite come quelle lette dal file).
CaptionItem conFrasi(CaptionItem c, List<Frase> frasi, EngineContext ctx) =>
    _ricentrato(
      c,
      c.copyWith(frasi: pulisciFrasi([for (final p in frasi) p.toJson()])),
      ctx,
    );

/// Uno strumento del testo (carattere, dimensione, colore, ombra, etichetta…) applicato allo stile del blocco.
/// La posizione la decide il blocco: si ricentra sul suo riquadro, non su quello di un testo.
CaptionItem conStileSottotitoli(
  CaptionItem c,
  TextItem Function(TextItem) f,
  EngineContext ctx,
) {
  final stile = f(c.stile).copyWith(x: c.stile.x, y: c.stile.y, text: '');
  return _ricentrato(c, c.copyWith(stile: stile), ctx);
}

/// Larghezza delle righe in % della pagina (20–100), come il cursore «Larghezza» del desktop.
int larghezzaSottotitoliPercento(CaptionItem c, int frameW) =>
    pyRound(c.wrapW / (frameW > 1 ? frameW : 1) * 100);

/// `_on_caption_prop("wrap")`: larghezza massima delle righe in % della pagina.
CaptionItem conLarghezzaSottotitoli(
  CaptionItem c,
  int percento,
  int frameW,
  EngineContext ctx,
) => _ricentrato(
  c,
  c.copyWith(wrapW: pyRound(frameW * percento / 100.0).toDouble()),
  ctx,
);

/// «Mostra la traduzione».
CaptionItem conTraduzioneVisibile(
  CaptionItem c,
  bool acceso,
  EngineContext ctx,
) => _ricentrato(c, c.copyWith(trShow: acceso), ctx);

/// Dimensione della traduzione in % della frase (40–100).
CaptionItem conDimensioneTraduzione(
  CaptionItem c,
  int percento,
  EngineContext ctx,
) => _ricentrato(c, c.copyWith(trSize: percento), ctx);

CaptionItem conCorsivoTraduzione(CaptionItem c, bool acceso) =>
    c.copyWith(trItalic: acceso);

CaptionItem conColoreTraduzione(CaptionItem c, int argb) =>
    c.copyWith(trColor: argb);

/// Pizzico e rotazione a due dita su un blocco: come un testo, [scala] moltiplica la dimensione del carattere
/// (12–400) attorno al centro e [gradi] si somma alla rotazione, con gli scatti ogni 15°.
({CaptionItem sottotitoli, bool agganciata}) trasformaSottotitoli(
  CaptionItem inizio,
  EngineContext ctx, {
  required double scala,
  required double gradi,
}) {
  final a = ctx.captionSize(inizio);
  final cx = inizio.x + a.w / 2.0, cy = inizio.y + a.h / 2.0;
  final size = (inizio.stile.size * scala).clamp(
    LimitiTesto.dimensioneMin.toDouble(),
    LimitiTesto.dimensioneMax.toDouble(),
  );
  final r = agganciaRotazione(inizio.rotation + gradi);
  final g = inizio.copyWith(
    stile: inizio.stile.copyWith(size: size, rotation: r.gradi),
  );
  final b = ctx.captionSize(g);
  return (
    sottotitoli: g.withPosition(cx - b.w / 2.0, cy - b.h / 2.0),
    agganciata: r.agganciata,
  );
}

/// Limiti dei cursori del blocco (`slider_caption_width`, `slider_caption_tr_size`).
abstract final class LimitiSottotitoli {
  static const int larghezzaMin = 20, larghezzaMax = 100;
  static const int traduzioneMin = 40, traduzioneMax = 100;
}

/// `CaptionItem.current_time` + `phrase_index_at`: la frase da mostrare al secondo [t] del video originale,
/// o null fuori dalle frasi.
Frase? fraseAlTempo(CaptionItem c, double? t) =>
    t == null ? null : fraseA(c.frasi, t);

/// Sulla tela, fuori dalle frasi e a video fermo: la prima frase con del testo, mostrata in trasparenza per
/// vedere stile e posizione (null se non ce n'è: l'app mostra la parola «Sottotitoli»).
Frase? fraseDiEsempio(CaptionItem c) {
  for (final p in c.frasi) {
    if (pyStrip(p.testo).isNotEmpty) return p;
  }
  return null;
}
