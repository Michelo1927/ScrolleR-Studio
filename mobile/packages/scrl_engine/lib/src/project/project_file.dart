/// Lettura e scrittura dei file `.scrlproj`, come `ProjectMixin` (`scrollr/window/project.py`).
///
/// Regole (§7 del piano): ogni campo ha un predefinito, i campi sconosciuti si conservano e si riscrivono
/// tali e quali, `version` resta 1.
library;

import 'dart:convert';

import '../model/elements.dart';
import '../model/json_read.dart';
import '../model/snapshot.dart';
import 'formato.dart';

/// Voce della libreria: `{"path": ..., "rel": ...}` (più `asset` sul telefono).
class LibraryEntry {
  final String path;
  final String? rel;
  final MediaAsset? asset;
  final Map<String, Object?> extra;

  LibraryEntry({
    required this.path,
    this.rel,
    this.asset,
    Map<String, Object?> extra = const {},
  }) : extra = Map.unmodifiable(extra);

  factory LibraryEntry.fromJson(Object? json) {
    final m = asMap(json);
    return LibraryEntry(
      path: readString(m, 'path', ''),
      rel: readStringOrNull(m, 'rel'),
      asset: MediaAsset.fromJson(m['asset']),
      extra: unknownFields(m, const {'path', 'rel', 'asset'}),
    );
  }

  Map<String, Object?> toJson() => {
    'path': path,
    'rel': rel,
    if (asset != null) 'asset': asset!.toJson(),
    ...extra,
  };
}

/// File di progetto non valido (non è JSON, o mancano `canvas` / `items`, come per il desktop).
class ProjectFormatException implements Exception {
  final String message;
  const ProjectFormatException(this.message);
  @override
  String toString() => 'ProjectFormatException: $message';
}

class ProjectFile {
  final int version;
  final Snapshot snapshot;
  final List<LibraryEntry> library;

  /// Campi in cima al file non conosciuti (es. `original_path` del salvataggio automatico del desktop).
  final Map<String, Object?> extra;

  ProjectFile({
    required this.snapshot,
    List<LibraryEntry> library = const [],
    this.version = progettoVersione,
    Map<String, Object?> extra = const {},
  }) : library = List.unmodifiable(library),
       extra = Map.unmodifiable(extra);

  static const _noti = {
    'version',
    'canvas',
    'library',
    'items',
    'texts',
    'shapes',
  };

  /// `_load_project_file`: legge il testo di un `.scrlproj`.
  factory ProjectFile.parse(String testo) {
    Object? dati;
    try {
      dati = jsonDecode(testo);
    } on FormatException catch (e) {
      throw ProjectFormatException('JSON non valido: ${e.message}');
    }
    if (dati is! Map) {
      throw const ProjectFormatException(
        'il file non contiene un oggetto JSON',
      );
    }
    final m = asMap(dati);
    if (m['canvas'] is! Map) {
      throw const ProjectFormatException('manca "canvas"');
    }
    if (m['items'] is! List) {
      throw const ProjectFormatException('manca "items"');
    }
    return ProjectFile(
      version: readInt(m, 'version', progettoVersione),
      snapshot: Snapshot.fromJson(m),
      library: [for (final e in asList(m['library'])) LibraryEntry.fromJson(e)],
      extra: unknownFields(m, _noti),
    );
  }

  /// `_project_data`: stessa forma del desktop (`version, canvas, library, items, texts, shapes`).
  Map<String, Object?> toJson() {
    final snap = snapshot.toJson();
    return <String, Object?>{
      'version': progettoVersione,
      'canvas': snap['canvas'],
      'library': [for (final e in library) e.toJson()],
      'items': snap['items'],
      'texts': snap['texts'],
      'shapes': snap['shapes'],
      ...extra,
    };
  }

  /// Testo del file: JSON UTF-8 rientrato di 1 come `json.dump(..., ensure_ascii=False, indent=1)`.
  String encode() => const JsonEncoder.withIndent(' ').convert(toJson());

  ProjectFile copyWith({
    Snapshot? snapshot,
    List<LibraryEntry>? library,
    Map<String, Object?>? extra,
  }) => ProjectFile(
    snapshot: snapshot ?? this.snapshot,
    library: library ?? this.library,
    version: version,
    extra: extra ?? this.extra,
  );
}
