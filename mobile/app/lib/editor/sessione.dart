/// Sessione di un progetto aperto nell'editor: tutto ciò che non è stato dell'interfaccia ma serve a lavorare
/// (cartella, cache delle immagini, risorse di disegno, contesto del motore, salvataggio su disco).
///
/// Non contiene logica di dominio: le operazioni sul documento stanno in `scrl_engine`, lo stato che cambia
/// (cronologia, selezione…) sta in `stato.dart`.
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:scrl_engine/scrl_engine.dart';

import '../media/cache_media.dart';
import '../media/galleria.dart';
import '../project/archivio.dart';
import '../render/disegno.dart';
import '../render/risorse_pagina.dart';
import '../render/testo.dart';

class SessioneEditor {
  SessioneEditor({
    required this.archivio,
    required this.cartella,
    required this.cache,
    required this.galleria,
    required DatiAccessori dati,
    required this.inizio,
    this.libreriaIniziale = const [],
    this.extraFile = const {},
  }) : nome = dati.nome,
       misure = {...dati.misure} {
    risorse = RisorsePagina(cache: cache, cartellaProgetto: cartella.path);
    ctx = EngineContext(
      imageSize: (p) => misure[chiaveMedia(p)],
      textSize: misuraTesto,
    );
  }

  final ArchivioProgetti archivio;
  final Directory cartella;
  final CacheMedia cache;
  final Galleria galleria;

  /// Documento com'era all'apertura (o appena creato) e sua libreria.
  final Snapshot inizio;
  final List<LibraryEntry> libreriaIniziale;

  late final RisorsePagina risorse;
  late final EngineContext ctx;

  /// Nome del progetto (si cambia dalla Home).
  String nome;

  /// Misura in pixel delle foto per chiave di sorgente (si salva in `info.json`).
  final Map<String, ({int w, int h})> misure;

  /// Campi in cima al `.scrlproj` che l'app non conosce: si riscrivono tali e quali.
  final Map<String, Object?> extraFile;

  Future<void> _codaSalvataggio = Future.value();
  DateTime? _ultimaMiniatura;
  bool _chiusa = false;

  /// Voce di libreria per una foto della tela o scelta dall'utente.
  static PhotoItem fotoDiVoce(LibraryEntry e) =>
      PhotoItem(uid: 0, path: e.path, rel: e.rel, asset: e.asset);

  SorgenteMedia sorgenteVoce(LibraryEntry e) =>
      sorgenteDi(fotoDiVoce(e), cartella.path);

  String chiaveVoce(LibraryEntry e) => chiaveMedia(fotoDiVoce(e));

  /// Misura in pixel della foto [p] (null se ancora non nota: foto mancante o non ancora letta).
  MisuraImmagine? misuraDi(PhotoItem p) => misure[chiaveMedia(p)];

  void ricordaMisura(String chiave, int w, int h) {
    if (w > 0 && h > 0) misure[chiave] = (w: w, h: h);
  }

  /// Misura delle foto che ancora non si conoscono (progetti aperti senza `info.json`, per esempio venuti dal
  /// computer): si legge dall'anteprima, una alla volta e senza bloccare niente. Vero se ne ha trovate di nuove.
  Future<bool> completaMisure(Snapshot s, List<LibraryEntry> libreria) async {
    final foto = [...s.items, for (final e in libreria) fotoDiVoce(e)];
    var nuove = false;
    for (final p in foto) {
      final k = chiaveMedia(p);
      if (misure.containsKey(k) || _chiusa) continue;
      final ant = await cache.carica(
        sorgenteDi(p, cartella.path),
        Dettaglio.anteprima,
      );
      if (ant == null) continue;
      ricordaMisura(k, ant.immagine.width, ant.immagine.height);
      nuove = true;
    }
    return nuove;
  }

  /// Scrive il progetto su disco (atomico). Le richieste si mettono in coda una dopo l'altra.
  Future<void> salva(Snapshot s, List<LibraryEntry> libreria) {
    final file = ProjectFile(snapshot: s, library: libreria, extra: extraFile);
    final dati = DatiAccessori(nome: nome, misure: {...misure});
    return _codaSalvataggio = _codaSalvataggio.then(
      (_) => archivio.salva(cartella, file, dati),
    );
  }

  /// Rigenera la miniatura della Home (prima pagina), a bassa priorità e al massimo ogni 10 secondi.
  Future<void> aggiornaMiniatura(Snapshot s, {bool subito = false}) async {
    final adesso = DateTime.now();
    final ultima = _ultimaMiniatura;
    if (!subito &&
        ultima != null &&
        adesso.difference(ultima) < const Duration(seconds: 10)) {
      return;
    }
    _ultimaMiniatura = adesso;
    try {
      await risorse.prepara(s, 0);
      const larghezza = 360.0;
      final scala = larghezza / s.canvas.frameW;
      final altezza = s.canvas.frameH * scala;
      final rec = ui.PictureRecorder();
      disegnaPagina(
        ui.Canvas(rec),
        s,
        0,
        risorse,
        const OpzioniDisegno(
          testi: TestiDisegno(fotoMancante: '', originaleMancante: '', di: ''),
          pulito: true,
        ),
        scala: scala,
      );
      final pic = rec.endRecording();
      final img = await pic.toImage(larghezza.round(), altezza.round());
      pic.dispose();
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      if (png == null) return;
      final f = archivio.fileMiniatura(cartella);
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsBytes(png.buffer.asUint8List(), flush: true);
      await tmp.rename(f.path);
    } on Exception {
      // La miniatura è un di più: se non riesce, la Home mostra il segnaposto
    }
  }

  /// Il sistema segnala poca memoria: restano solo le immagini che si possono ricaricare dal disco.
  void memoriaScarsa() => cache.svuota();

  Future<void> chiudi() async {
    _chiusa = true;
    await _codaSalvataggio;
    risorse.dispose();
  }
}
