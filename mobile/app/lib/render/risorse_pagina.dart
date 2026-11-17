/// Preparazione delle risorse di una pagina per [disegnaPagina]: immagini delle foto al dettaglio giusto e già
/// colorate (una volta per ogni cambio, come `_adjusted_cache` del desktop), sfondo sfocato e grana.
/// Tutto il lavoro è asincrono e fuori dal thread dell'interfaccia; il disegno resta sincrono.
library;

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
  const _Pronta(this.chiave, this.foto);
}

class RisorsePagina extends ChangeNotifier implements RisorseDisegno {
  RisorsePagina({required this.cache, required this.cartellaProgetto});

  final CacheMedia cache;

  /// Cartella del progetto (per `rel` e `media/`).
  final String cartellaProgetto;

  final Map<int, _Pronta> _foto = {};
  final Set<int> _mancanti = {};
  final Map<String, List<int>> _livelli = {};
  final Map<int, String> _inCorso = {};
  ui.Image? _grana;
  ui.Image? _sfondo;
  String? _chiaveSfondo;
  bool _chiuso = false;

  /// Fotogrammi dei video impostati dall'esportazione (uid → immagine), al posto della copertina.
  final Map<int, ui.Image> fotogrammi = {};

  @override
  FotoPronta? foto(PhotoItem p) {
    final f = fotogrammi[p.uid];
    if (f != null) return FotoPronta(f);
    return _foto[p.uid]?.foto;
  }

  @override
  bool mancante(PhotoItem p) => _mancanti.contains(p.uid);

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
    if (!_chiuso) notifyListeners();
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

  /// Prepara la pagina [k] per l'esportazione a [scala] pixel per unità: ogni foto letta dall'originale
  /// grande quanto serve (`export_side`), con le regolazioni calcolate a quella risoluzione.
  Future<void> preparaEsportazione(Snapshot s, int k, double scala) async {
    await _preparaComuni(s);
    for (final p in fotoDellaPagina(s, k)) {
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
      }
      // Originale mancante (o video, che usa i fotogrammi): l'anteprima
      img ??= ant.immagine;
      final colorata = await _colora(p, src, img, ant.immagine);
      _foto[p.uid] = _Pronta('esportazione', FotoPronta(colorata));
    }
  }

  Future<void> _preparaComuni(Snapshot s) async {
    _grana ??= await _creaGrana();
    final c = s.canvas;
    if (c.bgMode == 'blur' &&
        (c.bgBlurPath.isNotEmpty || c.bgBlurRel != null)) {
      final chiave =
          '${c.bgBlurPath}|${c.bgBlurRel}|${c.bgBlurAmount}|${c.bgDim}';
      if (chiave != _chiaveSfondo) {
        final finta = PhotoItem(uid: 0, path: c.bgBlurPath, rel: c.bgBlurRel);
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
    final chiave =
        '${identityHashCode(base)}|${jsonEncodeStable(p.adjust)}|${ant.originaleMancante}';
    if (_foto[p.uid]?.chiave == chiave || _inCorso[p.uid] == chiave) return;
    _inCorso[p.uid] = chiave;
    try {
      final colorata = await _colora(p, src, base, ant.immagine);
      if (_inCorso[p.uid] != chiave) return; // Nel frattempo è cambiata
      _foto[p.uid] = _Pronta(
        chiave,
        FotoPronta(colorata, originaleMancante: ant.originaleMancante),
      );
      _avvisa();
    } finally {
      if (_inCorso[p.uid] == chiave) _inCorso.remove(p.uid);
    }
  }

  final Map<String, ui.Image> _copertine = {};

  Future<ui.Image?> _copertina(SorgenteMedia src, double t) async {
    final k = '${src.chiave}|$t';
    final c = _copertine[k];
    if (c != null) return c;
    final sorgente = await cache.sorgenteVideo(src);
    if (sorgente == null) return null;
    try {
      final f = await ScrlVideo.fotogramma(sorgente, t);
      return _copertine[k] = await immagineDaPixel(
        f.rgba,
        f.larghezza,
        f.altezza,
      );
    } on Exception {
      return null;
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
