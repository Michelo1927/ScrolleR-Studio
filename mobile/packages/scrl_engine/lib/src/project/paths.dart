/// Percorsi delle foto di un progetto (§7 del piano, «Percorsi»).
///
/// Il desktop prova `path` (assoluto) e poi `rel` (relativo alla cartella del progetto, con `/`).
/// Sul telefono si prova `asset` (galleria, se della stessa piattaforma), poi `rel`, poi `path`: i percorsi
/// assoluti sul telefono non sono affidabili. Il motore non tocca il disco: chi chiama dice se un file esiste.
library;

import '../model/elements.dart';

enum MediaSource {
  /// Foto collegata alla galleria del telefono.
  asset,

  /// File trovato tramite `rel` (es. `media/nome.jpg` dentro il progetto).
  relative,

  /// File trovato tramite `path`.
  path,

  /// Non trovata: «Foto mancante», con il nome giusto.
  missing,
}

class MediaLocation {
  final MediaSource source;

  /// Percorso del file trovato (null per [MediaSource.asset] e [MediaSource.missing]).
  final String? file;
  final MediaAsset? asset;

  /// Nome da mostrare (anche per una foto mancante).
  final String name;

  const MediaLocation(this.source, {this.file, this.asset, required this.name});
}

/// Unisce la cartella del progetto e un percorso relativo (anche salvato su Windows con `\`).
String joinProjectPath(String projectDir, String rel) {
  final r = rel.replaceAll(r'\', '/');
  if (projectDir.isEmpty) return r;
  final d = projectDir.replaceAll(r'\', '/');
  return d.endsWith('/') ? '$d$r' : '$d/$r';
}

/// Nome del file in un percorso (con `/` o `\`).
String baseName(String path) {
  final p = path.replaceAll(r'\', '/');
  final i = p.lastIndexOf('/');
  return i < 0 ? p : p.substring(i + 1);
}

/// Dove trovare una foto: `asset` della stessa piattaforma, poi `rel`, poi `path`, altrimenti mancante.
MediaLocation resolveMedia({
  required String path,
  String? rel,
  MediaAsset? asset,
  required String projectDir,
  required String platform,
  required bool Function(String file) fileExists,
  bool Function(MediaAsset asset)? assetExists,
}) {
  final name = asset != null && asset.name.isNotEmpty
      ? asset.name
      : baseName(path);
  if (asset != null &&
      asset.platform == platform &&
      (assetExists?.call(asset) ?? true)) {
    return MediaLocation(MediaSource.asset, asset: asset, name: name);
  }
  if (rel != null && rel.isNotEmpty) {
    final f = joinProjectPath(projectDir, rel);
    if (fileExists(f)) {
      return MediaLocation(MediaSource.relative, file: f, name: name);
    }
  }
  if (path.isNotEmpty && fileExists(path)) {
    return MediaLocation(MediaSource.path, file: path, name: name);
  }
  return MediaLocation(MediaSource.missing, asset: asset, name: name);
}

/// Riferimenti scritti nel file per una foto collegata alla galleria: `path` = nome originale,
/// `rel` = null, più il campo `asset` (il desktop lo ignora e mostra «Foto mancante» col nome giusto).
PhotoItem linkToGallery(PhotoItem p, MediaAsset asset) => p.copyWith(
  path: asset.name.isNotEmpty ? asset.name : p.path,
  rel: () => null,
  asset: () => asset,
);

/// Riferimenti per una foto dentro il progetto (cartella `media/`): stesso valore relativo in `rel` e `path`.
PhotoItem placeInProject(PhotoItem p, String relativeInProject) {
  final r = relativeInProject.replaceAll(r'\', '/');
  return p.copyWith(path: r, rel: () => r, asset: () => null);
}
