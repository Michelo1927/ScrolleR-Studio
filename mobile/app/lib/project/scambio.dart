/// Scambio dei progetti (piano §6 «Progetto e file», §7 «Percorsi», §9 «Scambio»):
/// - **esportazione**: «Condividi progetto» crea uno `.zip` con una **copia** del progetto, in cui ogni foto e video
///   (anche quelli collegati alla galleria) è copiato in `media/` e punta a `media/nome` con percorsi relativi; il
///   progetto sul telefono non cambia e resta collegato alla galleria. Sul PC lo `.zip` estratto si apre con tutte
///   le foto trovate;
/// - **importazione**: lo `.zip` (foto in `media/` dentro il progetto) o un `.scrlproj` da solo (foto mancanti: parte
///   il ricollegamento). I collegamenti alla galleria arrivati da un altro telefono si scartano;
/// - **da file ricevuti**: foto e video mandati con «Condividi con» diventano un progetto nuovo.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:scrl_engine/scrl_engine.dart';

import '../media/cache_media.dart';
import '../media/galleria.dart';
import '../media/importa.dart';
import 'archivio.dart';
import 'crea_progetto.dart';
import 'lavoro.dart';
import 'zip.dart';

const String estensioneProgetto = '.scrlproj';

// ===================================================================== esportazione

/// Cosa finirà nello `.zip` di un progetto, deciso prima di scrivere niente: così si può avvisare dei file mancanti
/// e dire quanto pesa.
class PianoZip {
  PianoZip._({
    required this.nome,
    required this.nomeProgetto,
    required this.voci,
    required this.byteTotali,
    required this.copiati,
    required this.soloAnteprima,
    required this.mancanti,
    required this.galleria,
  });

  /// Nome del progetto.
  final String nome;

  /// Nome del `.scrlproj` dentro lo zip.
  final String nomeProgetto;
  final List<VoceZip> voci;
  final int byteTotali;

  /// Quanti originali (foto e video) si copiano.
  final int copiati;

  /// Foto il cui originale non c'è più: nello zip va l'anteprima salvata (lato lungo 1600 px).
  final List<String> soloAnteprima;

  /// File senza originale né anteprima: sul PC compaiono come «Foto mancante» col nome giusto.
  final List<String> mancanti;
  final Galleria galleria;

  bool get haProblemi => soloAnteprima.isNotEmpty || mancanti.isNotEmpty;

  /// Legge il progetto in [progetto] e decide dove prendere il file di ciascuna foto.
  static Future<PianoZip> prepara({
    required ProgettoCaricato progetto,
    Galleria galleria = const Galleria(),
    Annullamento? annullamento,
  }) async {
    final dir = progetto.cartella.path;
    final cache = CacheMedia(
      cartella: Directory('$dir/cache'),
      galleria: galleria,
    );
    final refs = elencaRiferimenti(
      progetto.file.snapshot,
      progetto.file.library,
    );
    final usati = <String>{};
    final rel = <String, String>{}; // chiave → nome nello zip
    final origini = <String, File>{};
    final solo = <String>[];
    final mancanti = <String>[];

    // I file già dentro il progetto tengono il loro percorso (`media/…`, `Foto/…`): si riservano per primi
    final dentro = <RiferimentoMedia, String>{};
    for (final r in refs) {
      final c = r.collegamento;
      final nomeRel = c.asset == null && c.rel != null
          ? nomeSicuro(c.rel!)
          : null;
      if (nomeRel == null || nomeRel.endsWith('/')) continue;
      final f = File('$dir/$nomeRel');
      if (f.existsSync()) {
        dentro[r] = nomeRel;
        usati.add(nomeRel.toLowerCase());
      }
    }

    for (final r in refs) {
      annullamento?.controlla();
      final c = r.collegamento;
      final nomeDentro = dentro[r];
      if (nomeDentro != null) {
        rel[r.chiave] = nomeDentro;
        origini[r.chiave] = File('$dir/$nomeDentro');
        continue;
      }
      final p = PhotoItem(
        uid: 0,
        path: c.path,
        rel: c.rel,
        asset: c.asset,
        isVideo: r.video,
      );
      final src = sorgenteDi(p, dir);
      File? file;
      switch (src.posizione.source) {
        case MediaSource.asset:
          final e = await galleria.entita(src.posizione.asset!);
          file = e == null ? null : await galleria.originale(e);
        case MediaSource.relative || MediaSource.path:
          file = File(src.posizione.file!);
        case MediaSource.missing:
          break;
      }
      if (file != null) {
        final n = 'media/${nomeLibero(nomePulito(r.nome), usati)}';
        rel[r.chiave] = n;
        origini[r.chiave] = file;
        continue;
      }
      // Originale sparito: l'anteprima salvata è meglio di niente (ma solo per le foto, non per i video)
      final ant = r.video ? null : cache.fileAnteprima(src);
      if (ant != null) {
        final ext = await _estensioneImmagine(ant);
        final base = nomePulito(r.nome);
        final punto = base.lastIndexOf('.');
        final senza = punto > 0 ? base.substring(0, punto) : base;
        final n = 'media/${nomeLibero('$senza$ext', usati)}';
        rel[r.chiave] = n;
        origini[r.chiave] = ant;
        solo.add(r.nome);
      } else {
        mancanti.add(r.nome);
      }
    }

    final nome = progetto.dati.nome;
    final nomeFile = '${nomePulito(nome)}$estensioneProgetto';
    final copia = preparaPerCondivisione(progetto.file, rel);
    final json = Uint8List.fromList(utf8.encode(copia.encode()));
    var byte = json.length;
    final voci = <VoceZip>[VoceZip.dati(nomeFile, json)];
    for (final e in rel.entries) {
      final f = origini[e.key]!;
      byte += f.lengthSync();
      voci.add(VoceZip.file(e.value, f));
    }
    return PianoZip._(
      nome: nome,
      nomeProgetto: nomeFile,
      voci: voci,
      byteTotali: byte,
      copiati: rel.length - solo.length,
      soloAnteprima: solo,
      mancanti: mancanti,
      galleria: galleria,
    );
  }

  /// Scrive lo `.zip` in [cartella] e ne restituisce il file. [progresso] riceve la frazione (0–1) e il file in corso.
  /// Con Annulla o un errore non resta niente. Disco pieno: [SpazioInsufficiente].
  Future<File> scrivi(
    Directory cartella, {
    void Function(double frazione, String file)? progresso,
    Annullamento? annullamento,
  }) async {
    final zip = File('${cartella.path}/${nomePulito(nome)}.zip');
    try {
      await scriviZip(
        zip,
        voci,
        progresso: (fatti, nome) =>
            progresso?.call(byteTotali == 0 ? 1 : fatti / byteTotali, nome),
        annullamento: annullamento,
      );
    } finally {
      await galleria.pulisciTemporanei();
    }
    return zip;
  }
}

/// Estensione (con il punto) giusta per un'anteprima: la cache tiene JPEG (dalla galleria) o PNG (dai file).
Future<String> _estensioneImmagine(File f) async {
  final raf = await f.open();
  try {
    final b = await raf.read(12);
    if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8) return '.jpg';
    if (b.length >= 4 && b[0] == 0x89 && b[1] == 0x50) return '.png';
    if (b.length >= 12 && b[8] == 0x57 && b[9] == 0x45) return '.webp';
    return '.jpg';
  } finally {
    await raf.close();
  }
}

// ===================================================================== importazione

enum MotivoImportazione {
  /// Né uno `.zip` né un progetto.
  nonRiconosciuto,

  /// Lo `.zip` non contiene nessun `.scrlproj`.
  nessunProgetto,

  /// Il `.scrlproj` non è valido (non è JSON o mancano `canvas` / `items`).
  progettoNonValido,
}

/// Il file non si può importare.
class ImportazioneNonRiuscita implements Exception {
  const ImportazioneNonRiuscita(this.motivo);
  final MotivoImportazione motivo;
  @override
  String toString() => 'ImportazioneNonRiuscita: ${motivo.name}';
}

class EsitoImportazione {
  const EsitoImportazione({
    required this.cartella,
    required this.nome,
    this.fileEstratti = 0,
    this.altriProgetti = 0,
  });

  final Directory cartella;
  final String nome;

  /// File (foto e video) estratti in `media/` dal progetto.
  final int fileEstratti;

  /// Altri `.scrlproj` nello `.zip`, non importati.
  final int altriProgetti;
}

bool _eZip(File f) {
  try {
    final raf = f.openSync();
    try {
      final b = raf.readSync(4);
      return b.length == 4 &&
          b[0] == 0x50 &&
          b[1] == 0x4b &&
          (b[2] == 3 || b[2] == 5);
    } finally {
      raf.closeSync();
    }
  } on FileSystemException {
    return false;
  }
}

String _senzaEstensione(String nome, {String di = estensioneProgetto}) {
  final base = nome.split(RegExp(r'[/\\]')).last;
  final l = base.toLowerCase();
  for (final e in [di, '.zip']) {
    if (l.endsWith(e)) return base.substring(0, base.length - e.length);
  }
  return base;
}

/// Importa [sorgente] (`.zip` o `.scrlproj`) come progetto nuovo nell'archivio. Il progetto compare nell'elenco solo
/// a lavoro finito; con Annulla o un errore la cartella nata a metà si toglie.
Future<EsitoImportazione> importaProgetto({
  required ArchivioProgetti archivio,
  required File sorgente,
  String? nomeOriginale,
  Avanza? avanza,
  Annullamento? annullamento,
}) async {
  final cartella = await archivio.nuovaCartella();
  try {
    final nomeFile = nomeOriginale ?? sorgente.uri.pathSegments.last;
    if (_eZip(sorgente)) {
      return await _importaZip(
        archivio,
        sorgente,
        cartella,
        nomeFile,
        avanza,
        annullamento,
      );
    }
    final testo = await _leggiProgetto(sorgente);
    avanza?.call(null, nomeFile);
    final file = senzaCollegamenti(testo);
    final nome = _senzaEstensione(nomeFile);
    await archivio.salva(
      cartella,
      file,
      DatiAccessori(nome: nome.isEmpty ? 'Progetto' : nome),
    );
    return EsitoImportazione(cartella: cartella, nome: nome);
  } catch (_) {
    if (cartella.existsSync()) await cartella.delete(recursive: true);
    rethrow;
  }
}

Future<ProjectFile> _leggiProgetto(File f) async {
  final String testo;
  try {
    final b = await f.readAsBytes();
    if (b.length > 64 << 20) {
      throw const ImportazioneNonRiuscita(MotivoImportazione.nonRiconosciuto);
    }
    testo = utf8.decode(b, allowMalformed: false);
  } on FormatException {
    throw const ImportazioneNonRiuscita(MotivoImportazione.nonRiconosciuto);
  }
  return _analizza(testo);
}

ProjectFile _analizza(String testo) {
  try {
    return ProjectFile.parse(
      testo.startsWith('﻿') ? testo.substring(1) : testo,
    );
  } on ProjectFormatException {
    throw const ImportazioneNonRiuscita(MotivoImportazione.progettoNonValido);
  }
}

Future<EsitoImportazione> _importaZip(
  ArchivioProgetti archivio,
  File sorgente,
  Directory cartella,
  String nomeFile,
  Avanza? avanza,
  Annullamento? annullamento,
) async {
  final zip = await LettoreZip.apri(sorgente);
  try {
    final utili = <VoceLetta>[];
    for (final v in zip.voci) {
      final n = nomeSicuro(v.nome);
      if (n == null || v.eCartella || eScartoDiSistema(n)) continue;
      utili.add(
        VoceLetta(
          nome: n,
          dimensione: v.dimensione,
          compressa: v.compressa,
          metodo: v.metodo,
          crc: v.crc,
          offset: v.offset,
        ),
      );
    }
    final progetti = [
      for (final v in utili)
        if (v.nome.toLowerCase().endsWith(estensioneProgetto)) v,
    ];
    if (progetti.isEmpty) {
      throw const ImportazioneNonRiuscita(MotivoImportazione.nessunProgetto);
    }
    // Il più vicino alla radice (poi in ordine alfabetico): quello vero, se ce n'è più di uno
    progetti.sort((a, b) {
      final d = '/'
          .allMatches(a.nome)
          .length
          .compareTo('/'.allMatches(b.nome).length);
      return d != 0 ? d : a.nome.compareTo(b.nome);
    });
    final scelto = progetti.first;
    final barra = scelto.nome.lastIndexOf('/');
    final prefisso = barra < 0 ? '' : scelto.nome.substring(0, barra + 1);

    final file = senzaCollegamenti(
      _analizza(utf8.decode(await zip.leggiInMemoria(scelto))),
    );
    final daEstrarre = [
      for (final v in utili)
        if (!identical(v, scelto) &&
            !v.nome.toLowerCase().endsWith(estensioneProgetto) &&
            v.nome.startsWith(prefisso))
          v,
    ];
    final totale = daEstrarre.fold<int>(0, (a, v) => a + v.dimensione);
    var prima = 0;
    for (final v in daEstrarre) {
      annullamento?.controlla();
      final rel = v.nome.substring(prefisso.length);
      avanza?.call(totale == 0 ? null : prima / totale, rel.split('/').last);
      await zip.estrai(
        v,
        File('${cartella.path}/$rel'),
        progresso: (b) => avanza?.call(
          totale == 0 ? null : (prima + b) / totale,
          rel.split('/').last,
        ),
        annullamento: annullamento,
      );
      prima += v.dimensione;
    }
    final nome = _senzaEstensione(scelto.nome.split('/').last);
    await archivio.salva(
      cartella,
      file,
      DatiAccessori(nome: nome.isEmpty ? 'Progetto' : nome),
    );
    return EsitoImportazione(
      cartella: cartella,
      nome: nome,
      fileEstratti: daEstrarre.length,
      altriProgetti: progetti.length - 1,
    );
  } finally {
    await zip.chiudi();
  }
}

// ===================================================================== file ricevuti

/// Un file arrivato da un'altra app («Apri con», «Condividi con»), già copiato nella cartella temporanea dell'app.
class FileRicevuto {
  const FileRicevuto({
    required this.percorso,
    required this.nome,
    this.mime,
    this.temporaneo = false,
  });

  final String percorso;
  final String nome;
  final String? mime;

  /// Copia fatta apposta per l'app (intent o selettore): finito il lavoro si toglie. Un file dell'utente no, mai.
  final bool temporaneo;

  static FileRicevuto? daMappa(Object? m) {
    if (m is! Map) return null;
    final p = m['percorso'];
    final n = m['nome'];
    if (p is! String || p.isEmpty) return null;
    return FileRicevuto(
      percorso: p,
      nome: n is String && n.isNotEmpty ? n : p.split(RegExp(r'[/\\]')).last,
      mime: m['mime'] as String?,
      temporaneo: true,
    );
  }

  String get _minuscolo => nome.toLowerCase();

  /// Uno `.zip` o un `.scrlproj`.
  bool get eProgetto =>
      _minuscolo.endsWith(estensioneProgetto) ||
      _minuscolo.endsWith('.zip') ||
      (mime ?? '').contains('zip');

  /// Una foto o un video (estensioni del desktop `MEDIA_EXTS`, o tipo MIME).
  bool get eMedia =>
      !eProgetto &&
      ((mime ?? '').startsWith('image/') ||
          (mime ?? '').startsWith('video/') ||
          _estensioniFoto.any(_minuscolo.endsWith) ||
          eVideo(nome));
}

const _estensioniFoto = [
  '.jpg',
  '.jpeg',
  '.png',
  '.webp',
  '.bmp',
  '.heic',
  '.heif',
];

/// Progetto nuovo con le foto e i video [file] (copiati in `media/`, perché un file mandato da un'altra app non si
/// può collegare alla galleria in modo stabile), disposti a griglia nel formato [formato]. Quelli non leggibili si
/// saltano e se ne dà il nome in [EsitoDaFile.scartati]. I file temporanei si tolgono.
Future<EsitoDaFile> creaProgettoDaFile({
  required ArchivioProgetti archivio,
  required List<FileRicevuto> file,
  required String nome,
  FormatoScelto formato = (indice: 0, larghezza: 1080, altezza: 1440),
  Avanza? avanza,
  Annullamento? annullamento,
}) async {
  final cartella = await archivio.nuovaCartella();
  try {
    avanza?.call(null, nome);
    final copiati = await copiaInMedia([
      for (final f in file) (percorso: f.percorso, nome: f.nome),
    ], cartella);
    annullamento?.controlla();
    final scelte = await scelteDaCopie(cartella, copiati);
    final scartati = <String>[
      for (var i = 0; i < copiati.length; i++)
        if (!scelte.any((s) => s.voce.rel == copiati[i].rel)) file[i].nome,
    ];
    if (scelte.isEmpty) {
      throw const ImportazioneNonRiuscita(MotivoImportazione.nonRiconosciuto);
    }
    await creaProgetto(
      archivio: archivio,
      cartella: cartella,
      nome: nome,
      formato: formato,
      scelte: scelte,
    );
    return EsitoDaFile(cartella, scelte.length, scartati);
  } catch (_) {
    if (cartella.existsSync()) await cartella.delete(recursive: true);
    rethrow;
  } finally {
    for (final f in file) {
      if (f.temporaneo) await eliminaTemporaneo(f);
    }
  }
}

/// Toglie la copia temporanea [f] (se c'è ancora).
Future<void> eliminaTemporaneo(FileRicevuto f) async {
  try {
    await File(f.percorso).delete();
  } on FileSystemException {
    // Già tolto
  }
}

class EsitoDaFile {
  const EsitoDaFile(this.cartella, this.foto, this.scartati);
  final Directory cartella;
  final int foto;
  final List<String> scartati;
}
