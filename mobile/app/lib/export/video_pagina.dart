/// Esportazione di una pagina con video in MP4 (piano §10), stesso schema di `_export_video_page` del desktop:
/// lo strato sotto i video e quello sopra si disegnano una volta; a ogni fotogramma si ridisegnano solo i video
/// e ciò che sta in mezzo, con **lo stesso modulo di disegno** dello schermo; i fotogrammi vanno al codificatore
/// del telefono (`scrl_video`). La pagina dura quanto il video più lungo (al massimo 60 s); i più corti
/// ripartono; gli audio accesi si sommano. Se fallisce o si annulla, il file a metà si elimina.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrl_engine/scrl_engine.dart';
import 'package:scrl_video/scrl_video.dart';

import '../media/cache_media.dart';
import '../render/disegno.dart';
import '../render/regolazioni.dart';
import '../render/risorse_pagina.dart';

/// Esito di un'esportazione MP4.
class EsitoVideo {
  /// true = fatto, false = errore, null = annullata.
  final bool? fatto;
  final int fotogrammi;
  final Duration tempo;
  final Object? errore;
  const EsitoVideo(
    this.fatto, {
    this.fotogrammi = 0,
    this.tempo = Duration.zero,
    this.errore,
  });

  /// Millisecondi medi per fotogramma.
  double get msPerFotogramma =>
      fotogrammi == 0 ? 0 : tempo.inMicroseconds / 1000.0 / fotogrammi;
}

/// Firma di [esportaPaginaVideo] (le prove la sostituiscono).
typedef EsportaPaginaVideo = Future<EsitoVideo> Function({
  required Snapshot s,
  required int k,
  required String percorso,
  required CacheMedia cache,
  required String cartellaProgetto,
  required TestiDisegno testi,
  void Function(int fatti, int totale)? avanzamento,
  bool Function()? annullato,
});

/// Chi scrive l'MP4 di una pagina: il telefono vero; le prove lo sostituiscono.
final esportaPaginaVideoProvider = Provider<EsportaPaginaVideo>(
  (ref) => esportaPaginaVideo,
);

/// Il telefono sa scrivere MP4 (vero su Android; su iOS dalla Fase 9): altrimenti le pagine con video escono come
/// immagine con la copertina, e il foglio di esportazione lo dice.
final videoDisponibileProvider = Provider<Future<bool> Function()>(
  (ref) => ScrlVideo.disponibile,
);

/// Video della pagina [k] che si trovano (`_page_videos`: i mancanti restano col segnaposto, come le foto).
Future<List<PhotoItem>> videoTrovati(
  Snapshot s,
  int k,
  CacheMedia cache,
  String cartellaProgetto,
) async => [
  for (final v in videoDellaPagina(s, k))
    if (await cache.sorgenteVideo(sorgenteDi(v, cartellaProgetto)) != null) v,
];

class _Video {
  final PhotoItem p;
  final String sorgente;
  final InfoVideo info;
  _Video(this.p, this.sorgente, this.info);

  double get durata => clipLength(p, info.durata);
}

Future<ui.Image> _strato(
  Snapshot s,
  int k,
  int w,
  int h,
  double scala,
  RisorsePagina r,
  OpzioniDisegno o,
) async {
  final rec = ui.PictureRecorder();
  disegnaPagina(ui.Canvas(rec), s, k, r, o, scala: scala);
  final pic = rec.endRecording();
  try {
    return await pic.toImage(w, h);
  } finally {
    pic.dispose();
  }
}

/// Esporta la pagina [k] di [s] in [percorso]. [avanzamento] riceve (fatti, totale); [annullato] si controlla
/// a ogni fotogramma.
Future<EsitoVideo> esportaPaginaVideo({
  required Snapshot s,
  required int k,
  required String percorso,
  required CacheMedia cache,
  required String cartellaProgetto,
  required TestiDisegno testi,
  void Function(int fatti, int totale)? avanzamento,
  bool Function()? annullato,
}) async {
  final cronometro = Stopwatch()..start();
  final fw = s.canvas.frameW.toDouble(), fh = s.canvas.frameH.toDouble();
  final out = RegoleVideo.misuraUscita(fw, fh);
  final px = out.w / fw; // Pixel dell'MP4 per unità della tela
  final risorse = RisorsePagina(
    cache: cache,
    cartellaProgetto: cartellaProgetto,
  );
  final lettori = <int, LettoreFotogrammi>{};
  ScrittoreMp4? scrittore;
  ui.Image? sotto, sopra;
  var fatto = false;
  var n = 0;
  try {
    final video = <_Video>[];
    for (final p in videoDellaPagina(s, k)) {
      final src = await cache.sorgenteVideo(sorgenteDi(p, cartellaProgetto));
      if (src == null) {
        continue; // Video mancante: resta il segnaposto (o la copertina)
      }
      video.add(_Video(p, src, await ScrlVideo.info(src)));
    }
    if (video.isEmpty) {
      return EsitoVideo(false, errore: StateError('Nessun video nella pagina'));
    }
    n = fotogrammiPaginaVideo(
      video.map((v) => v.durata),
      tipoProgetto: s.canvas.projectType,
    );
    final secondi = n / RegoleVideo.fps;

    await risorse.preparaEsportazione(s, k, px, annullato: annullato);
    if (annullato?.call() ?? false) {
      return EsitoVideo(null, tempo: cronometro.elapsed);
    }
    // I sottotitoli dei video della pagina cambiano frase a ogni fotogramma: stanno nello strato di mezzo
    final perUid = {for (final v in video) v.p.uid: v};
    final sottotitoli = [
      for (final c in s.captions)
        if (perUid.containsKey(c.videoUid)) c,
    ];
    final livelli = [
      for (final v in video) v.p.z,
      for (final c in sottotitoli) c.z,
    ];
    final zLo = livelli.reduce(math.min);
    final zHi = livelli.reduce(math.max);
    sotto = await _strato(
      s,
      k,
      out.w,
      out.h,
      px,
      risorse,
      OpzioniDisegno(
        testi: testi,
        esportazione: true,
        sovrimpressioni: false,
        filtro: (e) => e.z < zLo,
      ),
    );
    sopra = await _strato(
      s,
      k,
      out.w,
      out.h,
      px,
      risorse,
      OpzioniDisegno(
        testi: testi,
        esportazione: true,
        sfondo: false,
        filtro: (e) => e.z > zHi,
      ),
    );
    final mezzo = OpzioniDisegno(
      testi: testi,
      esportazione: true,
      sfondo: false,
      sovrimpressioni: false,
      filtro: (e) => e.z >= zLo && e.z <= zHi,
    );

    // Audio dei video non muti, ripetuto fino alla fine della pagina e sommato
    final tracce = <Uint8List>[];
    for (final v in video) {
      if (!v.info.audio || v.p.muted) continue;
      try {
        final pcm = await ScrlVideo.leggiAudio(
          v.sorgente,
          v.p.trimStart,
          clipEnd(v.p, v.info.durata),
        );
        if (pcm != null && pcm.isNotEmpty) {
          tracce.add(ripetiAudio(pcm, secondi));
        }
      } on ErroreVideo {
        // Audio illeggibile: il video esce muto, come sul desktop
      }
    }
    final audio = tracce.isEmpty ? null : mescolaAudio(tracce);

    for (final v in video) {
      final ant = await cache.carica(
        sorgenteDi(v.p, cartellaProgetto),
        Dettaglio.anteprima,
      );
      final iw = ant?.immagine.width ?? v.info.larghezza;
      final ih = ant?.immagine.height ?? v.info.altezza;
      final misura = v.p.exportFrameSize(iw, ih, px);
      lettori[v.p.uid] = await LettoreFotogrammi.apri(
        v.sorgente,
        misura: misura,
        latoMassimo: misura == null ? v.p.exportSide(iw, ih, px) : null,
      );
    }
    scrittore = await ScrittoreMp4.apri(percorso, out.w, out.h, audio: audio);

    for (var i = 0; i < n; i++) {
      if (annullato?.call() ?? false) {
        return EsitoVideo(null, fotogrammi: i, tempo: cronometro.elapsed);
      }
      final t = i / RegoleVideo.fps;
      for (final v in video) {
        final f = await lettori[v.p.uid]!.a(v.p.trimStart + t % v.durata);
        if (f == null) continue;
        risorse.fotogrammi.remove(v.p.uid)?.dispose();
        risorse.fotogrammi[v.p.uid] = await immagineDaPixel(
          f.rgba,
          f.larghezza,
          f.altezza,
        );
      }
      for (final v in video) {
        risorse.tempiVideo[v.p.uid] = v.p.trimStart + t % v.durata;
      }
      final rec = ui.PictureRecorder();
      final c = ui.Canvas(rec);
      c.drawImage(sotto, ui.Offset.zero, ui.Paint());
      disegnaPagina(c, s, k, risorse, mezzo, scala: px);
      c.drawImage(sopra, ui.Offset.zero, ui.Paint());
      final pic = rec.endRecording();
      final img = await pic.toImage(out.w, out.h);
      pic.dispose();
      final dati = await img.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      img.dispose();
      await scrittore.aggiungi(dati!.buffer.asUint8List());
      avanzamento?.call(i + 1, n);
    }
    await scrittore.chiudi();
    scrittore = null;
    fatto = true;
    return EsitoVideo(true, fotogrammi: n, tempo: cronometro.elapsed);
  } catch (e) {
    return EsitoVideo(
      false,
      fotogrammi: n,
      tempo: cronometro.elapsed,
      errore: e,
    );
  } finally {
    sotto?.dispose();
    sopra?.dispose();
    for (final l in lettori.values) {
      try {
        await l.chiudi();
      } on ErroreVideo {
        // Già chiuso
      }
    }
    for (final f in risorse.fotogrammi.values) {
      f.dispose();
    }
    risorse.fotogrammi.clear();
    risorse.tempiVideo.clear();
    // Originali, copertine e strati letti per questa pagina si liberano subito
    risorse.termina();
    if (scrittore != null) {
      try {
        await scrittore.annulla();
      } on ErroreVideo {
        // Il file si cancella comunque qui sotto
      }
    }
    final file = File(percorso);
    if (!fatto && file.existsSync()) file.deleteSync(); // Niente MP4 a metà
  }
}
