/// Collegamento alla galleria del telefono (piano §9): MediaStore su Android, PHAsset su iOS, tramite
/// `photo_manager` (fluttercandies, Apache-2.0, mantenuto, Android + iOS, identificativi stabili).
///
/// Le foto restano dove sono: il progetto ne salva l'identificativo (`asset`), mai una copia. Il permesso si
/// chiede solo al primo «Aggiungi foto»; con l'accesso parziale («solo le foto selezionate» di Android 14+ e iOS)
/// l'app lavora con quelle concesse e offre «Scegli altre foto».
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';
import 'package:scrl_engine/scrl_engine.dart';

/// Accesso alla galleria concesso dall'utente.
enum AccessoGalleria {
  /// Tutte le foto e i video.
  completo,

  /// Solo quelle scelte dall'utente (si possono aggiungere con «Scegli altre foto»).
  parziale,

  /// Nessun accesso: si ripiega sul selettore di sistema con copia in `media/`.
  negato,

  /// Non ancora chiesto.
  daChiedere,
}

/// L'utente non ha dato accesso alla galleria: non si può salvare lì.
class AccessoGalleriaNegato implements Exception {
  const AccessoGalleriaNegato();
  @override
  String toString() => 'Accesso alla galleria negato';
}

/// Elemento della galleria, con l'identificativo stabile da salvare nel progetto.
class ElementoGalleria {
  final AssetEntity entita;
  const ElementoGalleria(this.entita);

  bool get video => entita.type == AssetType.video;

  /// Riferimento da scrivere nel `.scrlproj` (campo solo mobile `asset`).
  MediaAsset get riferimento => MediaAsset(
    platform: Galleria.piattaforma,
    id: entita.id,
    name: entita.title ?? '',
  );
}

class Galleria {
  const Galleria();

  /// Piattaforma scritta in `asset.platform`: un collegamento vale solo sulla stessa piattaforma.
  static String get piattaforma => Platform.isIOS ? 'ios' : 'android';

  static const _opzioni = PermissionRequestOption(
    androidPermission: AndroidPermission(
      type: RequestType.common,
      mediaLocation: false,
    ),
  );

  static AccessoGalleria _da(PermissionState s) => switch (s) {
    PermissionState.authorized => AccessoGalleria.completo,
    PermissionState.limited => AccessoGalleria.parziale,
    PermissionState.notDetermined => AccessoGalleria.daChiedere,
    _ => AccessoGalleria.negato,
  };

  /// Stato attuale, senza chiedere niente.
  Future<AccessoGalleria> stato() async =>
      _da(await PhotoManager.getPermissionState(requestOption: _opzioni));

  /// Chiede il permesso (mostra la finestra di sistema solo se non è già stato deciso).
  Future<AccessoGalleria> chiedi() async =>
      _da(await PhotoManager.requestPermissionExtend(requestOption: _opzioni));

  /// Accesso parziale: riapre la scelta di sistema per aggiungere altre foto.
  Future<void> scegliAltre() =>
      PhotoManager.presentLimited(type: RequestType.common);

  /// Foto e video della galleria, i più recenti prima, a pagine di [perPagina].
  Future<List<ElementoGalleria>> elenco({
    int pagina = 0,
    int perPagina = 60,
  }) async {
    final l = await PhotoManager.getAssetListPaged(
      page: pagina,
      pageCount: perPagina,
      type: RequestType.common,
    );
    return [for (final e in l) ElementoGalleria(e)];
  }

  /// Elemento collegato, o null se non esiste più (cancellato, o non più concesso con l'accesso parziale).
  Future<AssetEntity?> entita(MediaAsset a) async {
    if (a.platform != piattaforma) return null;
    try {
      return await AssetEntity.fromId(a.id);
    } catch (_) {
      return null;
    }
  }

  /// Controllo all'apertura del progetto: il collegamento esiste ancora.
  Future<bool> esiste(MediaAsset a) async => await entita(a) != null;

  /// Versione ridotta (JPEG) col lato lungo [lato], decodificata e ruotata dal sistema in sRGB.
  /// Per i video è il primo fotogramma.
  Future<Uint8List?> ridotta(AssetEntity e, int lato) {
    final s = e.orientatedSize;
    final lungo = s.width > s.height ? s.width : s.height;
    final k = lungo > 0 && lungo > lato ? lato / lungo : 1.0;
    final w = (s.width * k).round().clamp(1, 1 << 14);
    final h = (s.height * k).round().clamp(1, 1 << 14);
    // Misure come appare la foto: Glide (Android) e PHImageManager (iOS) tengono conto della rotazione
    return e.thumbnailDataWithSize(ThumbnailSize(w, h), quality: 92);
  }

  /// File originale (solo per leggerlo, mai copiarlo nel progetto).
  Future<File?> originale(AssetEntity e) => e.originFile;

  /// Sorgente per `scrl_video` (URI `content://` su Android).
  Future<String?> sorgenteVideo(AssetEntity e) async {
    if (Platform.isAndroid) return (await e.getMediaUrl());
    return (await e.originFile)?.path;
  }

  /// Album della galleria dove finiscono le esportazioni (piano §11).
  static const String album = 'ScrolleR Studio';

  /// Salva l'immagine [dati] in galleria, nell'album [album] (su Android la cartella `Pictures/ScrolleR Studio`).
  /// [data] è la data di creazione: le pagine di un carosello si salvano con date crescenti, così restano in
  /// sequenza. Chiede il permesso solo se serve; lancia [AccessoGalleriaNegato] se è negato.
  Future<void> salvaImmagine(
    Uint8List dati,
    String nomeFile, {
    required DateTime data,
  }) async {
    var accesso = await stato();
    if (accesso == AccessoGalleria.daChiedere ||
        accesso == AccessoGalleria.negato) {
      accesso = await chiedi();
    }
    if (accesso == AccessoGalleria.negato) {
      throw const AccessoGalleriaNegato();
    }
    final e = await PhotoManager.editor.saveImage(
      dati,
      filename: nomeFile,
      title: nomeFile,
      relativePath: Platform.isAndroid ? 'Pictures/$album' : null,
      creationDate: data,
    );
    if (Platform.isIOS) await _inAlbumIos(e);
  }

  /// Salva l'MP4 [file] in galleria, nello stesso album delle immagini (così le pagine di un carosello restano
  /// insieme e in ordine). Stesse regole di [salvaImmagine] per il permesso.
  Future<void> salvaVideo(
    File file,
    String nomeFile, {
    required DateTime data,
  }) async {
    var accesso = await stato();
    if (accesso == AccessoGalleria.daChiedere ||
        accesso == AccessoGalleria.negato) {
      accesso = await chiedi();
    }
    if (accesso == AccessoGalleria.negato) {
      throw const AccessoGalleriaNegato();
    }
    final e = await PhotoManager.editor.saveVideo(
      file,
      title: nomeFile,
      relativePath: Platform.isAndroid ? 'Pictures/$album' : null,
      creationDate: data,
    );
    if (Platform.isIOS) await _inAlbumIos(e);
  }

  /// iOS: l'immagine nasce tra gli «Recenti»; la si mette anche nell'album, che si crea la prima volta.
  Future<void> _inAlbumIos(AssetEntity e) async {
    try {
      final tutti = await PhotoManager.getAssetPathList(
        type: RequestType.image,
      );
      var a = tutti.where((p) => p.name == album && !p.isAll).firstOrNull;
      a ??= await PhotoManager.editor.darwin.createAlbum(album);
      if (a != null) {
        await PhotoManager.editor.copyAssetToPath(asset: e, pathEntity: a);
      }
    } catch (_) {
      // L'album è un di più: l'immagine è comunque salvata in galleria
    }
  }
}
