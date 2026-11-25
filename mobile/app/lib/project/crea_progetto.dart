/// Creazione di un progetto nuovo: formato scelto, foto scelte → documento disposto a griglia, salvato subito.
library;

import 'dart:io';

import 'package:scrl_engine/scrl_engine.dart';

import '../media/cache_media.dart';
import '../media/importa.dart';
import '../render/sottotitoli.dart' show misuraSottotitoli;
import '../render/testo.dart';
import 'archivio.dart';

/// Una foto scelta, con la sua voce di libreria e la misura in pixel.
typedef FotoScelta = ({LibraryEntry voce, String chiave, int w, int h});

/// Formato della pagina: un indice di [aspectRatios] (8 = Personalizzato) e, per questo, le misure.
typedef FormatoScelto = ({int indice, int larghezza, int altezza});

/// Documento nuovo con il formato scelto, come lo crea il desktop: pagina singola, sfondo bianco. [tipo] è
/// «carousel» (carosello o foto) o «reel» (`_start_new_project`).
Snapshot documentoVuoto(
  FormatoScelto f, {
  int? seme,
  String tipo = 'carousel',
}) {
  final misure = aspectRatios[f.indice] ?? (f.larghezza, f.altezza);
  final personalizzato = f.indice == ratioPersonalizzato;
  return Snapshot(
    canvas: CanvasState(
      ratioIndex: f.indice,
      frameW: misure.$1,
      frameH: misure.$2,
      customW: personalizzato ? f.larghezza.clamp(200, 6000) : 1080,
      customH: personalizzato ? f.altezza.clamp(200, 6000) : 1440,
      layoutSeed: seme,
      projectType: tipo,
    ),
  );
}

/// Crea il progetto in [cartella] (già creata) con le foto [scelte] disposte a griglia (`Griglia` è la
/// disposizione di partenza) e lo salva. Le foto della galleria restano dove sono: il progetto ne tiene il
/// collegamento.
Future<ProgettoCaricato> creaProgetto({
  required ArchivioProgetti archivio,
  required Directory cartella,
  required String nome,
  required FormatoScelto formato,
  required List<FotoScelta> scelte,
  String tipo = 'carousel',
}) async {
  final misure = <String, ({int w, int h})>{
    for (final s in scelte)
      if (s.w > 0 && s.h > 0) s.chiave: (w: s.w, h: s.h),
  };
  final ctx = EngineContext(
    imageSize: (p) => misure[chiaveMedia(p)],
    textSize: misuraTesto,
    captionSize: misuraSottotitoli,
  );
  var s = documentoVuoto(formato, tipo: tipo);
  if (scelte.isNotEmpty) {
    s = mettiFotoSullaTela(s, [
      for (final f in scelte)
        (
          path: f.voce.path,
          rel: f.voce.rel,
          asset: f.voce.asset,
          video: Scene.isVideoPath(f.voce.path),
        ),
    ], ctx).risultato.snapshot;
  }
  final file = ProjectFile(
    snapshot: s,
    library: [for (final f in scelte) f.voce],
  );
  final dati = DatiAccessori(nome: nome, misure: misure);
  await archivio.salva(cartella, file, dati);
  return ProgettoCaricato(cartella, file, dati);
}

/// Foto copiate in `media/` di [cartella] (dal selettore di sistema o da un'altra app) come foto scelte, con la misura
/// letta dall'anteprima, che resta in `cache/`. Un file non leggibile non blocca gli altri: si salta.
Future<List<FotoScelta>> scelteDaCopie(
  Directory cartella,
  List<FileImportato> copiati,
) async {
  final cache = CacheMedia(cartella: Directory('${cartella.path}/cache'));
  final scelte = <FotoScelta>[];
  for (final f in copiati) {
    final p = PhotoItem(uid: 0, path: f.rel, rel: f.rel, isVideo: f.video);
    final ant = await cache.carica(
      sorgenteDi(p, cartella.path),
      Dettaglio.anteprima,
    );
    if (ant == null) continue; // File non leggibile: si salta
    scelte.add((
      voce: LibraryEntry(path: f.rel, rel: f.rel),
      chiave: chiaveMedia(p),
      w: ant.immagine.width,
      h: ant.immagine.height,
    ));
  }
  return scelte;
}
