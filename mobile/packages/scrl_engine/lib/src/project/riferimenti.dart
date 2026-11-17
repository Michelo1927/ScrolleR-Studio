/// Riferimenti alle foto di un progetto (§7 e §9 del piano): dove puntano, come si riscrivono e quali sono usati.
///
/// Serve a tre cose, tutte sul documento e senza toccare il disco:
/// - **condivisione**: nella copia che finisce nello `.zip` ogni foto punta a `media/nome` (stesso valore in `rel` e
///   `path`) e il campo solo mobile `asset` sparisce ([preparaPerCondivisione]);
/// - **importazione**: un identificativo di galleria arrivato da un altro telefono non vale su questo e potrebbe
///   puntare a una foto sbagliata, quindi si toglie ([senzaCollegamenti]);
/// - **ricollegamento**: una foto mancante riprende un nuovo riferimento ovunque (tela, libreria, sfondo e tutta la
///   cronologia), come `_remap_paths` del desktop ([riscriviSnapshot], [riscriviProgetto]).
library;

import '../model/canvas_state.dart';
import '../model/elements.dart';
import '../model/scene.dart';
import '../model/snapshot.dart';
import 'paths.dart';
import 'project_file.dart';

/// Campo solo mobile dentro `canvas`: collegamento alla galleria della foto di sfondo (`bg_blur_asset`).
const String campoSfondoAsset = 'bg_blur_asset';

/// Dove punta una foto: `path`, `rel` e (solo mobile) `asset`.
typedef Collegamento = ({String path, String? rel, MediaAsset? asset});

/// Come cambia un riferimento. Restituire [attuale] lo lascia com'è.
typedef RiscriviRiferimento = Collegamento Function(Collegamento attuale);

/// Chiave stabile di un riferimento: identificativo della galleria oppure percorso nel progetto (`rel`, poi `path`).
/// Due foto con la stessa chiave sono lo stesso file.
String chiaveRiferimento(String path, String? rel, MediaAsset? asset) =>
    asset != null ? 'a:${asset.platform}:${asset.id}' : 'f:${rel ?? path}';

/// Chiave di [c].
String chiaveDi(Collegamento c) => chiaveRiferimento(c.path, c.rel, c.asset);

/// Nome del file da mostrare: quello salvato con la galleria, altrimenti il nome nel percorso.
String nomeRiferimento(Collegamento c) {
  final a = c.asset;
  if (a != null && a.name.isNotEmpty) return a.name;
  return baseName(c.path.isNotEmpty ? c.path : (c.rel ?? ''));
}

/// Un file usato dal progetto, con dove lo usa.
class RiferimentoMedia {
  final String chiave;
  final Collegamento collegamento;
  final bool video;

  /// Quante foto della tela lo usano.
  final int usiSullaTela;
  final bool nellaLibreria;
  final bool comeSfondo;

  const RiferimentoMedia({
    required this.chiave,
    required this.collegamento,
    required this.video,
    required this.usiSullaTela,
    required this.nellaLibreria,
    required this.comeSfondo,
  });

  String get nome => nomeRiferimento(collegamento);
}

Collegamento _di(PhotoItem p) => (path: p.path, rel: p.rel, asset: p.asset);

MediaAsset? _assetSfondo(CanvasState c) =>
    MediaAsset.fromJson(c.extra[campoSfondoAsset]);

/// Collegamento della foto di sfondo sfocato, o null se il progetto non ne ha una.
Collegamento? collegamentoSfondo(CanvasState c) {
  final asset = _assetSfondo(c);
  if (c.bgBlurPath.isEmpty && c.bgBlurRel == null && asset == null) {
    return null;
  }
  return (path: c.bgBlurPath, rel: c.bgBlurRel, asset: asset);
}

/// Tutti i file che il progetto usa (tela, libreria, sfondo sfocato), senza doppioni, nell'ordine in cui compaiono.
List<RiferimentoMedia> elencaRiferimenti(
  Snapshot s,
  List<LibraryEntry> libreria,
) {
  final per = <String, _Voce>{};
  _Voce voce(Collegamento c, bool video) =>
      per.putIfAbsent(chiaveDi(c), () => _Voce(c, video));
  for (final p in s.items) {
    voce(_di(p), p.isVideo).tela++;
  }
  for (final e in libreria) {
    voce((
      path: e.path,
      rel: e.rel,
      asset: e.asset,
    ), Scene.isVideoPath(e.path)).libreria = true;
  }
  final sf = collegamentoSfondo(s.canvas);
  if (sf != null) voce(sf, false).sfondo = true;
  return [
    for (final e in per.entries)
      RiferimentoMedia(
        chiave: e.key,
        collegamento: e.value.c,
        video: e.value.video,
        usiSullaTela: e.value.tela,
        nellaLibreria: e.value.libreria,
        comeSfondo: e.value.sfondo,
      ),
  ];
}

class _Voce {
  _Voce(this.c, this.video);
  final Collegamento c;
  final bool video;
  int tela = 0;
  bool libreria = false;
  bool sfondo = false;
}

/// [s] con ogni riferimento riscritto da [fn]: foto e video della tela e foto di sfondo. Il resto non cambia.
Snapshot riscriviSnapshot(Snapshot s, RiscriviRiferimento fn) {
  var cambiato = false;
  final items = <PhotoItem>[];
  for (final p in s.items) {
    final prima = _di(p);
    final dopo = fn(prima);
    if (dopo == prima) {
      items.add(p);
    } else {
      cambiato = true;
      items.add(
        p.copyWith(
          path: dopo.path,
          rel: () => dopo.rel,
          asset: () => dopo.asset,
        ),
      );
    }
  }
  var canvas = s.canvas;
  final sf = collegamentoSfondo(canvas);
  if (sf != null) {
    final dopo = fn(sf);
    if (dopo != sf) {
      cambiato = true;
      final extra = {...canvas.extra};
      if (dopo.asset != null) {
        extra[campoSfondoAsset] = dopo.asset!.toJson();
      } else {
        extra.remove(campoSfondoAsset);
      }
      canvas = canvas.copyWith(
        bgBlurPath: dopo.path,
        bgBlurRel: () => dopo.rel,
        extra: extra,
      );
    }
  }
  if (!cambiato) return s;
  return s.copyWith(canvas: canvas, items: items);
}

/// Voci di libreria con ogni riferimento riscritto da [fn].
List<LibraryEntry> riscriviLibreria(
  List<LibraryEntry> libreria,
  RiscriviRiferimento fn,
) => [
  for (final e in libreria)
    () {
      final prima = (path: e.path, rel: e.rel, asset: e.asset);
      final dopo = fn(prima);
      if (dopo == prima) return e;
      return LibraryEntry(
        path: dopo.path,
        rel: dopo.rel,
        asset: dopo.asset,
        extra: e.extra,
      );
    }(),
];

/// Il progetto con ogni riferimento riscritto da [fn] (tela, libreria, sfondo). Campi sconosciuti conservati.
ProjectFile riscriviProgetto(ProjectFile f, RiscriviRiferimento fn) =>
    f.copyWith(
      snapshot: riscriviSnapshot(f.snapshot, fn),
      library: riscriviLibreria(f.library, fn),
    );

/// Copia del progetto per lo `.zip` di «Condividi progetto»: ogni file in [relPerChiave] (chiave → `media/nome`)
/// punta alla sua copia (stesso valore in `rel` e `path`) e il campo `asset` sparisce ovunque. Un file non copiato
/// (mancante) resta col suo nome e senza `asset`: sul PC compare come «Foto mancante» col nome giusto.
ProjectFile preparaPerCondivisione(
  ProjectFile f,
  Map<String, String> relPerChiave,
) => riscriviProgetto(f, (c) {
  final r = relPerChiave[chiaveDi(c)];
  if (r != null) return (path: r, rel: r, asset: null);
  final a = c.asset;
  if (a == null) return c;
  return (path: a.name.isNotEmpty ? a.name : c.path, rel: null, asset: null);
});

/// Progetto arrivato da fuori: toglie i collegamenti alla galleria, che valgono solo sul telefono che li ha scritti.
/// Le foto restano col loro nome (e con `rel`, se c'è): se non si trovano partono il ricollegamento e la ricerca.
ProjectFile senzaCollegamenti(ProjectFile f) => riscriviProgetto(f, (c) {
  final a = c.asset;
  if (a == null) return c;
  return (path: a.name.isNotEmpty ? a.name : c.path, rel: c.rel, asset: null);
});
