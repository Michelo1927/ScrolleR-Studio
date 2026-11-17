/// Esportazione delle immagini (piano §11), portata da `export_split_frames` e `export_full_collage` del desktop.
///
/// Ogni pagina si disegna **con lo stesso modulo dello schermo** (`disegnaPagina`, in modalità esportazione) alla scala
/// scelta; le foto si leggono dagli originali grandi quanto serve, una pagina alla volta, e si liberano subito dopo.
/// Il collage intero si disegna a pezzi (una pagina per volta, più pezzi se una pagina supera il lato massimo di una
/// texture) e si unisce nell'isolate di codifica. I file nascono in una cartella temporanea e poi vanno alla
/// destinazione scelta: Galleria (in ordine), foglio Condividi o Salva in File.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:scrl_engine/scrl_engine.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../media/cache_media.dart';
import '../render/disegno.dart';
import '../render/risorse_pagina.dart';
import 'codifica.dart';
import 'consegna.dart';
import 'preferenze.dart';

/// Che cosa fa il telefono con i file pronti.
enum Destinazione {
  /// Album «ScrolleR Studio» della galleria.
  galleria,

  /// Foglio Condividi di sistema.
  condividi,

  /// Salva in File (selettore di sistema).
  file,
}

/// Che cosa esportare e come.
class RichiestaEsportazione {
  const RichiestaEsportazione({
    required this.snapshot,
    required this.pagine,
    required this.collage,
    required this.opzioni,
    required this.nome,
    required this.destinazione,
  });

  /// Documento da esportare (quello committato, senza bozza).
  final Snapshot snapshot;

  /// Pagine da esportare, in ordine (vuoto per il collage).
  final List<int> pagine;
  final bool collage;
  final OpzioniEsportazione opzioni;

  /// Nome scelto per i file (`export_name`); vuoto = predefinito.
  final String nome;
  final Destinazione destinazione;
}

enum FaseEsportazione {
  /// Lettura degli originali di una pagina.
  foto,

  /// Disegno e codifica della pagina.
  pagina,

  /// Codifica del collage intero.
  composizione,

  /// Consegna dei file alla destinazione.
  consegna,
}

/// Dove si è arrivati: la fase, la pagina in corso (1 … [totale]) e la frazione del lavoro fatto (0 … 1).
class Avanzamento {
  const Avanzamento(
    this.fase, {
    this.indice = 0,
    this.totale = 0,
    this.pagina = 0,
    this.frazione = 0,
  });
  final FaseEsportazione fase;
  final int indice;
  final int totale;

  /// Numero della pagina del documento (da 1) mentre si legge o si disegna.
  final int pagina;
  final double frazione;
}

enum StatoEsito {
  /// Tutto salvato.
  fatto,

  /// Qualche file salvato, qualcuno no (errore o annullata a metà).
  parziale,

  /// Annullata dall'utente prima di salvare qualcosa.
  annullato,

  /// Non si è salvato niente per un errore.
  errore,
}

class EsitoEsportazione {
  const EsitoEsportazione(
    this.stato,
    this.destinazione, {
    this.salvati = const [],
    this.falliti = const [],
    this.larghezza = 0,
    this.altezza = 0,
    this.errore,
    this.collage = false,
  });
  final StatoEsito stato;
  final Destinazione destinazione;

  /// Nomi dei file consegnati, nell'ordine.
  final List<String> salvati;

  /// Nomi dei file non riusciti.
  final List<String> falliti;

  /// Misure in pixel di ogni immagine.
  final int larghezza;
  final int altezza;
  final Object? errore;
  final bool collage;
}

class _Annullata implements Exception {
  const _Annullata();
}

class _Uscita {
  _Uscita(this.nome, this.file);
  final String nome;
  final File file;
}

/// Un'esportazione in corso. Si avvia con [esegui]; [avanzamento] si osserva dall'interfaccia e [annulla] si può
/// chiamare in ogni momento (si ferma alla prossima pausa: tra una foto, un pezzo o una pagina e l'altra).
class LavoroEsportazione {
  LavoroEsportazione({
    required this.richiesta,
    required this.cache,
    required this.cartellaProgetto,
    required this.testi,
    required this.cartellaTemporanea,
    required this.consegna,
    this.schermoAcceso = _schermoAccesoDiSistema,
    DateTime Function()? adesso,
  }) : _adesso = adesso ?? DateTime.now;

  final RichiestaEsportazione richiesta;
  final CacheMedia cache;
  final String cartellaProgetto;
  final TestiDisegno testi;

  /// Cartella dove nascono i file prima della consegna (si svuota a fine lavoro).
  final Directory cartellaTemporanea;
  final Consegna consegna;

  /// Tiene lo schermo acceso durante l'esportazione (si può sostituire nelle prove).
  final Future<void> Function(bool acceso) schermoAcceso;
  final DateTime Function() _adesso;

  /// Lato massimo di un pezzo disegnato: sotto il lato massimo delle texture dei telefoni.
  static const int latoPezzo = 4096;

  final ValueNotifier<Avanzamento> avanzamento = ValueNotifier(
    const Avanzamento(FaseEsportazione.foto),
  );

  bool _annullato = false;
  CodificatoreStriscia? _striscia;

  bool get annullato => _annullato;

  void annulla() {
    _annullato = true;
    _striscia?.chiudi();
  }

  static Future<void> _schermoAccesoDiSistema(bool acceso) async {
    try {
      await WakelockPlus.toggle(enable: acceso);
    } on Object {
      // Senza il servizio (prove, piattaforme senza) l'esportazione va avanti comunque
    }
  }

  void _controlla() {
    if (_annullato) throw const _Annullata();
  }

  void _segna(
    FaseEsportazione fase,
    int fatti,
    int totale, {
    int indice = 0,
    int pagina = 0,
  }) {
    avanzamento.value = Avanzamento(
      fase,
      indice: indice,
      totale: totale,
      pagina: pagina,
      frazione: totale == 0 ? 0 : (fatti / totale).clamp(0.0, 1.0),
    );
  }

  /// Esegue l'esportazione fino in fondo (o fino all'annullamento) e dice com'è andata. Non lancia errori.
  Future<EsitoEsportazione> esegui() async {
    final r = richiesta;
    final c = r.snapshot.canvas;
    final m = MisureUscita(c, r.opzioni.scala);
    final jpg = r.opzioni.formato.isJpg;
    final ext = estensioneImmagine(jpg);
    final larghezza = r.collage ? m.collageW : m.paginaW;
    final altezza = r.collage ? m.collageH : m.paginaH;
    final cartella = Directory(
      '${cartellaTemporanea.path}/esportazione_${_adesso().microsecondsSinceEpoch}',
    );
    final prodotti = <_Uscita>[];
    final falliti = <String>[];
    final salvati = <String>[];
    try {
      await schermoAcceso(true);
      await cartella.create(recursive: true);
      final pagine = r.collage
          ? List.generate(c.numFrames, (i) => i)
          : r.pagine.where((k) => k >= 0 && k < c.numFrames).toList();
      // Passi del lavoro: una pagina ciascuna; il collage ha in più la codifica; poi la consegna
      final consegne = r.collage ? 1 : pagine.length;
      final passiProduzione = pagine.length + (r.collage ? 1 : 0);
      final totale = passiProduzione + consegne;

      if (r.collage) {
        final nome = nomeFileCollage(r.nome, c, r.opzioni.scala, ext);
        final striscia = _striscia = await CodificatoreStriscia.avvia(
          larghezza: larghezza,
          altezza: altezza,
          formato: r.opzioni.formato,
          qualita: r.opzioni.qualita,
        );
        for (var i = 0; i < pagine.length; i++) {
          _controlla();
          final k = pagine[i];
          final rgba = await _rendiPagina(k, m, i, pagine.length, totale);
          striscia.aggiungi(k * m.paginaW, m.paginaW, rgba);
        }
        _controlla();
        _segna(FaseEsportazione.composizione, pagine.length, totale);
        final dati = await striscia.finisci();
        _striscia = null;
        _controlla();
        final f = File('${cartella.path}/$nome');
        await f.writeAsBytes(dati, flush: true);
        prodotti.add(_Uscita(nome, f));
      } else {
        for (var i = 0; i < pagine.length; i++) {
          _controlla();
          final k = pagine[i];
          final nome = nomeFilePagina(r.nome, k, ext);
          try {
            final rgba = await _rendiPagina(k, m, i, pagine.length, totale);
            _controlla();
            final striscia = _striscia = await CodificatoreStriscia.avvia(
              larghezza: larghezza,
              altezza: altezza,
              formato: r.opzioni.formato,
              qualita: r.opzioni.qualita,
            );
            striscia.aggiungi(0, larghezza, rgba);
            final dati = await striscia.finisci();
            _striscia = null;
            _controlla();
            final f = File('${cartella.path}/$nome');
            await f.writeAsBytes(dati, flush: true);
            prodotti.add(_Uscita(nome, f));
          } on _Annullata {
            rethrow;
          } on Object catch (e) {
            if (_annullato) rethrow;
            debugPrint('Esportazione della pagina ${k + 1}: $e');
            falliti.add(nome);
          }
        }
      }

      await _consegna(prodotti, salvati, totale, passiProduzione, jpg);
      return _esito(
        salvati,
        falliti,
        larghezza,
        altezza,
        annullata: _annullato,
      );
    } on _Annullata {
      return _esito(salvati, falliti, larghezza, altezza, annullata: true);
    } on Object catch (e) {
      if (_annullato) {
        return _esito(salvati, falliti, larghezza, altezza, annullata: true);
      }
      return _esito(salvati, falliti, larghezza, altezza, errore: e);
    } finally {
      _striscia?.chiudi();
      _striscia = null;
      await schermoAcceso(false);
      try {
        if (cartella.existsSync()) await cartella.delete(recursive: true);
      } on FileSystemException {
        // Resta nella cartella temporanea del sistema, che la ripulisce da sé
      }
    }
  }

  EsitoEsportazione _esito(
    List<String> salvati,
    List<String> falliti,
    int w,
    int h, {
    bool annullata = false,
    Object? errore,
  }) {
    final StatoEsito stato;
    if (salvati.isNotEmpty) {
      stato = falliti.isEmpty && !annullata && errore == null
          ? StatoEsito.fatto
          : StatoEsito.parziale;
    } else if (annullata) {
      stato = StatoEsito.annullato;
    } else {
      stato = StatoEsito.errore;
    }
    return EsitoEsportazione(
      stato,
      richiesta.destinazione,
      salvati: salvati,
      falliti: falliti,
      larghezza: w,
      altezza: h,
      errore: errore,
      collage: richiesta.collage,
    );
  }

  /// Disegna la pagina [k] alla scala di [m] e ne restituisce i pixel RGBA (`paginaW × paginaH × 4`).
  Future<Uint8List> _rendiPagina(
    int k,
    MisureUscita m,
    int i,
    int n,
    int totale,
  ) async {
    final s = richiesta.snapshot;
    final scala = m.scala.toDouble();
    _segna(FaseEsportazione.foto, i, totale, indice: i + 1, pagina: k + 1);
    final risorse = RisorsePagina(
      cache: cache,
      cartellaProgetto: cartellaProgetto,
    );
    try {
      await risorse.preparaEsportazione(
        s,
        k,
        scala,
        annullato: () => _annullato,
      );
      _controlla();
      _segna(FaseEsportazione.pagina, i, totale, indice: i + 1, pagina: k + 1);
      final out = Uint8List(m.paginaW * m.paginaH * 4);
      final opzioni = OpzioniDisegno(testi: testi, esportazione: true);
      for (var y0 = 0; y0 < m.paginaH; y0 += latoPezzo) {
        for (var x0 = 0; x0 < m.paginaW; x0 += latoPezzo) {
          _controlla();
          final tw = math.min(latoPezzo, m.paginaW - x0);
          final th = math.min(latoPezzo, m.paginaH - y0);
          final rec = ui.PictureRecorder();
          final canvas = ui.Canvas(rec)
            ..translate(-x0.toDouble(), -y0.toDouble());
          disegnaPagina(canvas, s, k, risorse, opzioni, scala: scala);
          final pic = rec.endRecording();
          final img = await pic.toImage(tw, th);
          pic.dispose();
          final dati = await img.toByteData(
            format: ui.ImageByteFormat.rawStraightRgba,
          );
          img.dispose();
          final px = dati!.buffer.asUint8List(
            dati.offsetInBytes,
            dati.lengthInBytes,
          );
          for (var y = 0; y < th; y++) {
            out.setRange(
              ((y0 + y) * m.paginaW + x0) * 4,
              ((y0 + y) * m.paginaW + x0 + tw) * 4,
              px,
              y * tw * 4,
            );
          }
        }
      }
      return out;
    } finally {
      // Gli originali letti per questa pagina si liberano subito, prima della prossima
      risorse.termina();
    }
  }

  /// Consegna i file alla destinazione, nell'ordine delle pagine.
  Future<void> _consegna(
    List<_Uscita> prodotti,
    List<String> salvati,
    int totale,
    int fatti,
    bool jpg,
  ) async {
    if (prodotti.isEmpty) return;
    final n = prodotti.length;
    switch (richiesta.destinazione) {
      case Destinazione.galleria:
        // Date crescenti, l'ultima è adesso: nella galleria le pagine restano in sequenza per il carosello
        final fine = _adesso();
        for (var i = 0; i < n; i++) {
          _controlla();
          _segna(FaseEsportazione.consegna, fatti + i, totale, indice: i + 1);
          final u = prodotti[i];
          await consegna.salvaInGalleria(
            await u.file.readAsBytes(),
            u.nome,
            fine.subtract(Duration(seconds: n - 1 - i)),
          );
          salvati.add(u.nome);
        }
      case Destinazione.condividi:
        _controlla();
        _segna(FaseEsportazione.consegna, fatti, totale, indice: 1);
        await consegna.condividi([for (final u in prodotti) u.file], jpg);
        salvati.addAll([for (final u in prodotti) u.nome]);
      case Destinazione.file:
        for (var i = 0; i < n; i++) {
          _controlla();
          _segna(FaseEsportazione.consegna, fatti + i, totale, indice: i + 1);
          final u = prodotti[i];
          final fatto = await consegna.salvaInFile(
            u.nome,
            await u.file.readAsBytes(),
            mimeImmagine(jpg),
          );
          // Il selettore di sistema è stato chiuso senza scegliere: si smette qui
          if (!fatto) throw const _Annullata();
          salvati.add(u.nome);
        }
    }
    _segna(FaseEsportazione.consegna, totale, totale, indice: n);
  }
}
