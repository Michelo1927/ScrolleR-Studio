/// Foto mancanti (piano §6 e §9): quali foto del progetto non si trovano più, e come ritrovarle (ricerca per nome
/// nella galleria). Sul telefono le foto sono solo collegate: se una viene cancellata dalla galleria resta sulla tela
/// con l'anteprima salvata e il segno «Originale mancante», e qui finisce nell'elenco.
///
/// Il ricollegamento vero (riscrivere i riferimenti ovunque) sta nel motore (`riscriviSnapshot` e `History.riscritta`)
/// e nello stato dell'editor; qui c'è solo ciò che dipende dal telefono.
library;

import 'package:scrl_engine/scrl_engine.dart';

import '../project/lavoro.dart';
import 'cache_media.dart';
import 'galleria.dart';

/// Una foto (o un video) che non si trova più.
class FotoMancante {
  const FotoMancante(this.riferimento, this.misura);

  final RiferimentoMedia riferimento;

  /// Misura in pixel, se nota: aiuta a scegliere tra più foto dallo stesso nome.
  final MisuraImmagine? misura;

  String get chiave => riferimento.chiave;
  String get nome => riferimento.nome;
  bool get video => riferimento.video;
  int get usiSullaTela => riferimento.usiSullaTela;
  Collegamento get collegamento => riferimento.collegamento;

  /// Foto fittizia per leggere l'anteprima salvata con [CacheMedia].
  PhotoItem get comeFoto => PhotoItem(
    uid: 0,
    path: collegamento.path,
    rel: collegamento.rel,
    asset: collegamento.asset,
    isVideo: video,
  );
}

/// Il file che [c] indica si trova ancora? Per la galleria si chiede al sistema (un collegamento può esistere nel
/// file ma la foto essere stata cancellata, o non più concessa con l'accesso parziale).
Future<bool> originaleEsiste(
  Collegamento c,
  String cartellaProgetto,
  Galleria galleria,
) async {
  final p = PhotoItem(uid: 0, path: c.path, rel: c.rel, asset: c.asset);
  final s = sorgenteDi(p, cartellaProgetto);
  return switch (s.posizione.source) {
    MediaSource.asset => await galleria.esiste(s.posizione.asset!),
    MediaSource.missing => false,
    _ => true,
  };
}

/// Controllo all'apertura (e prima di esportare): le foto della tela, della libreria e dello sfondo che non si
/// trovano più, nell'ordine in cui compaiono.
Future<List<FotoMancante>> trovaMancanti({
  required Snapshot snapshot,
  required List<LibraryEntry> libreria,
  required String cartellaProgetto,
  required Galleria galleria,
  required Map<String, MisuraImmagine> misure,
}) async {
  final out = <FotoMancante>[];
  for (final r in elencaRiferimenti(snapshot, libreria)) {
    if (!await originaleEsiste(r.collegamento, cartellaProgetto, galleria)) {
      out.add(FotoMancante(r, misure[r.chiave]));
    }
  }
  return out;
}

/// Un ritrovamento: dove ora si trova la foto e la sua misura.
class Ritrovata {
  const Ritrovata(this.collegamento, this.misura);
  final Collegamento collegamento;
  final MisuraImmagine? misura;
}

/// Ricerca automatica per nome nella galleria (piano §6): per ogni foto di [mancanti] cerca nella galleria un
/// elemento dallo stesso nome file, senza badare alle maiuscole. Con più candidati preferisce quello dello stesso
/// tipo (foto o video) e con le stesse proporzioni; altrimenti il più recente. Restituisce chiave → ritrovamento
/// per quelle trovate. [progresso] riceve quanti elementi della galleria ha guardato.
Future<Map<String, Ritrovata>> cercaInGalleria(
  Galleria galleria,
  List<FotoMancante> mancanti, {
  void Function(int guardati)? progresso,
  Annullamento? annullamento,
}) async {
  final trovati = await galleria.cercaPerNome(
    {for (final m in mancanti) m.nome},
    progresso: progresso,
    annullato: () => annullamento?.annullato ?? false,
  );
  annullamento?.controlla();
  final out = <String, Ritrovata>{};
  for (final m in mancanti) {
    final candidati = (trovati[m.nome.toLowerCase()] ?? const [])
        .where((e) => e.video == m.video)
        .toList();
    if (candidati.isEmpty) continue;
    ElementoGalleria scelto = candidati.first;
    final mis = m.misura;
    if (mis != null && mis.w > 0 && mis.h > 0 && candidati.length > 1) {
      final voluta = mis.w / mis.h;
      scelto = candidati.firstWhere((e) {
        final s = e.entita.orientatedSize;
        return s.height > 0 && ((s.width / s.height) - voluta).abs() < 0.02;
      }, orElse: () => candidati.first);
    }
    final s = scelto.entita.orientatedSize;
    out[m.chiave] = Ritrovata(
      collegaAGalleria(scelto.riferimento, m.collegamento.path),
      s.width > 0 && s.height > 0
          ? (w: s.width.round(), h: s.height.round())
          : null,
    );
  }
  return out;
}

/// Riferimento di una foto collegata alla galleria: `path` = nome originale (il desktop lo mostra come «Foto
/// mancante» col nome giusto), niente `rel`, più il campo `asset`.
Collegamento collegaAGalleria(MediaAsset asset, String pathPrecedente) => (
  path: asset.name.isNotEmpty ? asset.name : pathPrecedente,
  rel: null,
  asset: asset,
);

/// Riferimento di una foto copiata dentro il progetto (`media/…`): stesso valore in `rel` e `path`.
Collegamento dentroIlProgetto(String rel) {
  final r = rel.replaceAll(r'\', '/');
  return (path: r, rel: r, asset: null);
}
