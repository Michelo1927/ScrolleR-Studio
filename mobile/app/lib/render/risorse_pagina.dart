/// Preparazione delle risorse di una pagina per [disegnaPagina]: immagini delle foto al dettaglio giusto e già
/// colorate (una volta per ogni cambio, come `_adjusted_cache` del desktop), sfondo sfocato e grana.
/// Tutto il lavoro è asincrono e fuori dal thread dell'interfaccia; il disegno resta sincrono.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:scrl_engine/scrl_engine.dart';
import 'package:scrl_video/scrl_video.dart';

import '../media/cache_media.dart';
import 'disegno.dart';
import 'regolazioni.dart';

class _Pronta {
  final String chiave;
  final FotoPronta foto;

  /// La foto com'era prima delle regolazioni (per il confronto prima/dopo).
  final ui.Image originale;
  const _Pronta(this.chiave, this.foto, this.originale);
}

/// Legge durata e audio di un video (sostituibile nelle prove).
typedef LeggiInfoVideo = Future<InfoVideo> Function(String sorgente);

class RisorsePagina extends ChangeNotifier
    implements RisorseDisegno, RisorseVideo {
  RisorsePagina({
    required this.cache,
    required this.cartellaProgetto,
    this.leggiInfo = ScrlVideo.info,
  });

  final LeggiInfoVideo leggiInfo;

  final CacheMedia cache;

  /// Cartella del progetto (per `rel` e `media/`).
  final String cartellaProgetto;

  final Map<int, _Pronta> _foto = {};
  final Set<int> _mancanti = {};
  final Map<String, List<int>> _livelli = {};
  final Map<int, String> _inCorso = {};

  /// Richiesta arrivata mentre la foto si stava ancora colorando: parte appena finisce quella in corso, così
  /// scorrendo un cursore il lavoro non si accumula e conta solo l'ultimo valore.
  final Map<int, (PhotoItem, double)> _inAttesa = {};
  ui.Image? _grana;
  ui.Image? _sfondo;
  String? _chiaveSfondo;
  bool _chiuso = false;

  /// Fotogrammi dei video impostati dall'esportazione (uid → immagine), al posto della copertina.
  final Map<int, ui.Image> fotogrammi = {};

  /// Video in riproduzione sulla tela (per l'etichetta ▶/pausa).
  final Set<int> _inRiproduzione = {};

  /// Durata e audio dei video per chiave di sorgente (null = file non leggibile).
  final Map<String, InfoVideo?> _infoVideo = {};
  final Map<String, Future<InfoVideo?>> _infoInCorso = {};

  /// Cresce a ogni cambio di risorse: chi disegna lo confronta per sapere se deve ridisegnare.
  int versione = 0;

  bool _mostraOriginale = false;
  bool _qualitaRidotta = false;

  /// Chiamata quando si torna alla qualità piena (la tela ricalcola le foto).
  VoidCallback? ripristinaQualita;

  /// Lato lungo delle foto mentre un cursore è in movimento: la colorazione è molto più leggera e l'anteprima
  /// segue il dito; a dito fermo si ricalcola alla qualità piena.
  static const int latoInterattivo = 720;
  final Map<int, (ui.Image, ui.Image)> _ridotte = {};

  /// Un cursore è in movimento: si lavora su copie ridotte delle foto.
  bool get qualitaRidotta => _qualitaRidotta;
  set qualitaRidotta(bool v) {
    if (v == _qualitaRidotta) return;
    _qualitaRidotta = v;
    if (!v) ripristinaQualita?.call();
  }

  /// Prima/dopo (`scene.show_original`): finché è acceso tutte le foto si vedono senza filtri e regolazioni.
  @override
  bool get mostraOriginale => _mostraOriginale;
  set mostraOriginale(bool v) {
    if (v == _mostraOriginale) return;
    _mostraOriginale = v;
    _avvisa();
  }

  @override
  FotoPronta? foto(PhotoItem p) {
    final f = fotogrammi[p.uid];
    if (f != null) return FotoPronta(f);
    final pronta = _foto[p.uid];
    if (pronta != null && _mostraOriginale) {
      return FotoPronta(
        pronta.originale,
        originaleMancante: pronta.foto.originaleMancante,
      );
    }
    return pronta?.foto;
  }

  @override
  bool mancante(PhotoItem p) => _mancanti.contains(p.uid);

  // ---------------- Video ----------------

  /// Durata e audio del video [p], se già letti (null finché non si conoscono o se il file non si legge).
  InfoVideo? infoVideo(PhotoItem p) => _infoVideo[chiaveMedia(p)];

  /// Durata del video [p] in secondi (0 = sconosciuta, come `duration` del desktop quando il file non si legge).
  double durataVideo(PhotoItem p) => infoVideo(p)?.durata ?? 0.0;

  /// Legge (una volta sola per file) durata e audio del video [p].
  Future<InfoVideo?> caricaInfoVideo(PhotoItem p) {
    final k = chiaveMedia(p);
    if (_infoVideo.containsKey(k)) return Future.value(_infoVideo[k]);
    return _infoInCorso[k] ??= _leggiInfoVideo(p, k);
  }

  Future<InfoVideo?> _leggiInfoVideo(PhotoItem p, String k) async {
    InfoVideo? info;
    try {
      final src = await cache.sorgenteVideo(sorgenteDi(p, cartellaProgetto));
      if (src != null) info = await leggiInfo(src);
    } on Exception {
      info = null; // Video non leggibile (o piattaforma senza video): durata sconosciuta
    }
    unawaited(_infoInCorso.remove(k));
    if (_chiuso) return info;
    _infoVideo[k] = info;
    _avvisa();
    return info;
  }

  /// Prove: durata e audio di un video già noti.
  @visibleForTesting
  void ricordaInfoVideo(PhotoItem p, InfoVideo info) =>
      _infoVideo[chiaveMedia(p)] = info;

  @override
  EtichettaVideo? etichettaVideo(PhotoItem p) {
    if (!p.isVideo || _mancanti.contains(p.uid)) return null;
    final info = infoVideo(p);
    final durata = info?.durata ?? 0.0;
    return EtichettaVideo(
      durata: clipLength(p, durata),
      muto: p.muted || !(info?.audio ?? false),
      inRiproduzione: _inRiproduzione.contains(p.uid),
    );
  }

  /// Riproduzione sulla tela: mostra [img] al posto della copertina del video [uid] (la precedente si libera).
  void impostaFotogramma(int uid, ui.Image img) {
    if (_chiuso) {
      img.dispose();
      return;
    }
    _inRiproduzione.add(uid);
    final vecchio = fotogrammi[uid];
    fotogrammi[uid] = img;
    _avvisa();
    // Con un attimo di ritardo: un disegno (miniatura) in corso potrebbe ancora usarla
    if (vecchio != null && !identical(vecchio, img)) {
      Timer(const Duration(milliseconds: 200), vecchio.dispose);
    }
  }

  /// Fine della riproduzione del video [uid]: torna la copertina.
  void togliFotogramma(int uid) {
    final f = fotogrammi.remove(uid);
    final c = _inRiproduzione.remove(uid);
    if (f != null) Timer(const Duration(milliseconds: 200), f.dispose);
    if (f != null || c) _avvisa();
  }

  /// Segna l'inizio della riproduzione del video [uid] (l'etichetta passa a «pausa» subito).
  void segnaRiproduzione(int uid) {
    if (_inRiproduzione.add(uid)) _avvisa();
  }

  @override
  ui.Image? get sfondoSfocato => _sfondo;

  @override
  ui.Image? get grana => _grana;

  @override
  void dispose() {
    _chiuso = true;
    super.dispose();
  }

  void _avvisa() {
    if (_chiuso) return;
    versione++;
    notifyListeners();
  }

  /// Foto (e video) che toccano la pagina [k].
  static List<PhotoItem> fotoDellaPagina(Snapshot s, int k) {
    final fw = s.canvas.frameW.toDouble();
    return [
      for (final p in s.items)
        if (p.cellRect.right > k * fw && p.cellRect.left < (k + 1) * fw) p,
    ];
  }

  /// Prepara la pagina [k] per lo schermo. [pixelPerUnita] = pixel dello schermo per unità della tela
  /// (zoom × densità): oltre il 115% dei pixel dell'anteprima si chiede l'alta risoluzione.
  Future<void> prepara(Snapshot s, int k, {double pixelPerUnita = 1.0}) async {
    await _preparaComuni(s);
    await Future.wait([
      for (final p in fotoDellaPagina(s, k)) _preparaFoto(p, pixelPerUnita),
    ]);
  }

  /// Immagini create per l'esportazione (originali letti grandi e foto colorate): non sono della cache, quindi si
  /// liberano da qui appena la pagina è stata disegnata.
  final List<ui.Image> _daLiberare = [];

  /// Prepara la pagina [k] per l'esportazione a [scala] pixel per unità: ogni foto letta dall'originale
  /// grande quanto serve (`export_side`), con le regolazioni calcolate a quella risoluzione. Gli originali si
  /// leggono una foto alla volta; dopo il disegno si liberano con [liberaEsportazione].
  /// [annullato] si controlla tra una foto e l'altra.
  Future<void> preparaEsportazione(
    Snapshot s,
    int k,
    double scala, {
    bool Function()? annullato,
  }) async {
    await _preparaComuni(s);
    for (final p in fotoDellaPagina(s, k)) {
      if (annullato?.call() ?? false) return;
      final src = sorgenteDi(p, cartellaProgetto);
      final ant = await cache.carica(src, Dettaglio.anteprima);
      if (ant == null) {
        _mancanti.add(p.uid);
        continue;
      }
      final lato = p.exportSide(ant.immagine.width, ant.immagine.height, scala);
      ui.Image? img;
      if (lato != null && !p.isVideo) {
        img = await cache.perEsportazione(src, lato);
        if (img != null) _daLiberare.add(img);
      }
      // Originale mancante (o video, che usa i fotogrammi): l'anteprima
      img ??= ant.immagine;
      if (p.isVideo && p.poster > 0.01) {
        // Video: la copertina scelta, come a schermo (il fotogramma si legge una volta e resta nella cache locale)
        img = await _copertina(src, p.poster) ?? img;
      }
      final colorata = await _colora(p, src, img, ant.immagine);
      if (!identical(colorata, img) && !identical(colorata, ant.immagine)) {
        _daLiberare.add(colorata);
      }
      _foto[p.uid] = _Pronta('esportazione', FotoPronta(colorata), img);
    }
  }

  /// Libera subito le immagini lette e colorate per l'esportazione (non quelle della cache).
  void liberaEsportazione() {
    _foto.removeWhere((_, p) => p.chiave == 'esportazione');
    for (final i in _daLiberare) {
      i.dispose();
    }
    _daLiberare.clear();
  }

  /// Fine di un'esportazione: libera anche grana, sfondo sfocato e copertine, che qui sono solo di questa risorsa.
  void termina() {
    liberaEsportazione();
    _grana?.dispose();
    _grana = null;
    _sfondo?.dispose();
    _sfondo = null;
    for (final c in _copertine.values) {
      c.dispose();
    }
    _copertine.clear();
    dispose();
  }

  Future<void> _preparaComuni(Snapshot s) async {
    _grana ??= await _creaGrana();
    final c = s.canvas;
    final asset = MediaAsset.fromJson(c.extra[campoSfondoAsset]);
    if (c.bgMode == 'blur' &&
        (c.bgBlurPath.isNotEmpty || c.bgBlurRel != null || asset != null)) {
      final chiave =
          '${c.bgBlurPath}|${c.bgBlurRel}|${asset?.id}|${c.bgBlurAmount}|${c.bgDim}';
      if (chiave != _chiaveSfondo) {
        final finta = PhotoItem(
          uid: 0,
          path: c.bgBlurPath,
          rel: c.bgBlurRel,
          asset: asset,
        );
        final ant = await cache.carica(
          sorgenteDi(finta, cartellaProgetto),
          Dettaglio.anteprima,
        );
        _sfondo = ant == null
            ? null
            : await _sfoca(ant.immagine, c.bgBlurAmount, c.bgDim);
        _chiaveSfondo = chiave;
        _avvisa();
      }
    }
  }

  Future<void> _preparaFoto(PhotoItem p, double pixelPerUnita) async {
    final src = sorgenteDi(p, cartellaProgetto);
    // Durata e audio servono all'etichetta e agli strumenti Video anche prima che la copertina sia pronta
    if (p.isVideo && !_infoVideo.containsKey(chiaveMedia(p))) {
      unawaited(caricaInfoVideo(p));
    }
    final ant = await cache.carica(src, Dettaglio.anteprima);
    if (ant == null) {
      if (_mancanti.add(p.uid)) _avvisa();
      _foto.remove(p.uid);
      return;
    }
    _mancanti.remove(p.uid);
    final nitida =
        !p.isVideo &&
        !ant.originaleMancante &&
        p.needsSharp(ant.immagine.width, ant.immagine.height, pixelPerUnita);
    var base = ant.immagine;
    if (nitida) {
      final alta = await cache.carica(src, Dettaglio.alta);
      if (alta != null) base = alta.immagine;
    }
    if (p.isVideo && p.poster > 0.01) {
      final cop = await _copertina(src, p.poster);
      if (cop != null) base = cop;
    }
    if (_qualitaRidotta &&
        math.max(base.width, base.height) > latoInterattivo) {
      final r = _ridotte[p.uid];
      if (r != null && identical(r.$1, base)) {
        base = r.$2;
      } else {
        final piccola = await ridimensiona(base, latoInterattivo);
        _ridotte[p.uid] = (base, piccola);
        base = piccola;
      }
    }
    final chiave =
        '${identityHashCode(base)}|${jsonEncodeStable(p.adjust)}|${ant.originaleMancante}';
    if (_foto[p.uid]?.chiave == chiave || _inCorso[p.uid] == chiave) return;
    if (_inCorso.containsKey(p.uid)) {
      _inAttesa[p.uid] = (p, pixelPerUnita);
      return;
    }
    _inCorso[p.uid] = chiave;
    try {
      final colorata = await _colora(p, src, base, ant.immagine);
      if (_chiuso) {
        if (!identical(colorata, base)) colorata.dispose();
        return;
      }
      final vecchia = _foto[p.uid];
      _foto[p.uid] = _Pronta(
        chiave,
        FotoPronta(colorata, originaleMancante: ant.originaleMancante),
        base,
      );
      _avvisa();
      // L'immagine colorata di prima non serve più (quelle della cache non si toccano)
      // (con un po' di ritardo: la miniatura o un'esportazione in corso potrebbero ancora disegnarla)
      if (vecchia != null &&
          !identical(vecchia.foto.immagine, vecchia.originale) &&
          !identical(vecchia.foto.immagine, colorata)) {
        final daLiberare = vecchia.foto.immagine;
        Timer(const Duration(seconds: 5), daLiberare.dispose);
      }
    } finally {
      _inCorso.remove(p.uid);
      final a = _inAttesa.remove(p.uid);
      if (a != null && !_chiuso) unawaited(_preparaFoto(a.$1, a.$2));
    }
  }

  /// Copertine lette (chiave e secondo → fotogramma), dalla meno alla più recente.
  final LinkedHashMap<String, ui.Image> _copertine = LinkedHashMap();

  /// Copertine tenute in memoria oltre a quelle in uso: scorrendo il cursore Copertina se ne leggono molte.
  static const int copertineMassime = 6;

  Future<ui.Image?> _copertina(SorgenteMedia src, double t) async {
    final k = '${src.chiave}|$t';
    final c = _copertine.remove(k);
    if (c != null) return _copertine[k] = c;
    final sorgente = await cache.sorgenteVideo(src);
    if (sorgente == null) return null;
    try {
      final f = await ScrlVideo.fotogramma(sorgente, t);
      final img = await immagineDaPixel(f.rgba, f.larghezza, f.altezza);
      _copertine[k] = img;
      _potaCopertine();
      return img;
    } on Exception {
      return null;
    }
  }

  /// Libera le copertine più vecchie che nessuna foto pronta sta usando.
  void _potaCopertine() {
    if (_copertine.length <= copertineMassime) return;
    final inUso = <ui.Image>{
      for (final p in _foto.values) ...[p.foto.immagine, p.originale],
    };
    for (final k in _copertine.keys.toList()) {
      if (_copertine.length <= copertineMassime) break;
      final img = _copertine[k]!;
      if (inUso.any((i) => identical(i, img))) continue;
      _copertine.remove(k);
      // Con ritardo: una miniatura o un'esportazione potrebbe ancora disegnarla
      Timer(const Duration(seconds: 5), img.dispose);
    }
  }

  /// Regolazioni colore applicate a [img]; i livelli automatici si calcolano sull'anteprima della foto intera.
  Future<ui.Image> _colora(
    PhotoItem p,
    SorgenteMedia src,
    ui.Image img,
    ui.Image anteprima,
  ) async {
    if (!adjustmentsActive(p.adjust)) return img;
    List<int>? livelli;
    if (adjOn(p.adjust, 'auto')) {
      livelli = _livelli[src.chiave] ??= await Regolazioni.livelliAutomatici(
        anteprima,
      );
    }
    final r = await Regolazioni.carica();
    return r.applica(
      img,
      p.adjust,
      detailScale: img.width / 1000.0,
      livelli: livelli,
    );
  }

  /// Grana: riquadro di rumore grigio sempre uguale (stesso seme del desktop).
  static Future<ui.Image> _creaGrana() {
    final g = grainTileBytes();
    final px = Uint8List(grainSide * grainSide * 4);
    for (var i = 0; i < g.length; i++) {
      px[i * 4] = px[i * 4 + 1] = px[i * 4 + 2] = g[i];
      px[i * 4 + 3] = 255;
    }
    return immagineDaPixel(px, grainSide, grainSide);
  }

  /// `blurred_background`: versione piccola (480 px) sfocata e scurita.
  static Future<ui.Image> _sfoca(ui.Image src, int quanto, int scurisci) async {
    final piccola = await ridimensiona(src, 480);
    final w = piccola.width, h = piccola.height;
    final rec = ui.PictureRecorder();
    final k = 1.0 - scurisci / 100.0;
    final paint = ui.Paint()..filterQuality = ui.FilterQuality.medium;
    if (quanto > 0) {
      final sigma = quanto / 4.0;
      paint.imageFilter = ui.ImageFilter.blur(
        sigmaX: sigma,
        sigmaY: sigma,
        tileMode: ui.TileMode.clamp,
      );
    }
    if (scurisci > 0) {
      paint.colorFilter = ui.ColorFilter.matrix([
        k, 0, 0, 0, 0, //
        0, k, 0, 0, 0, //
        0, 0, k, 0, 0, //
        0, 0, 0, 1, 0,
      ]);
    }
    ui.Canvas(rec).drawImage(piccola, ui.Offset.zero, paint);
    final pic = rec.endRecording();
    try {
      return await pic.toImage(math.max(1, w), math.max(1, h));
    } finally {
      pic.dispose();
    }
  }
}

/// Testo stabile di una mappa di regolazioni (chiavi in ordine), per riconoscere i cambi.
String jsonEncodeStable(Map<String, Object?> m) {
  final k = m.keys.toList()..sort();
  return k.map((c) => '$c=${m[c]}').join(',');
}
