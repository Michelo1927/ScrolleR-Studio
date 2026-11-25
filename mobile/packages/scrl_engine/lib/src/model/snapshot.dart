/// Stato immutabile del documento, con la stessa forma di `HistoryMixin._snapshot()`:
/// `{canvas, items, texts, shapes}`, più `captions` quando ci sono sottotitoli.
library;

import '../util/py.dart';
import 'canvas_state.dart';
import 'elements.dart';

class Snapshot {
  final CanvasState canvas;

  /// Foto e video nell'ordine della disposizione (`layout_index`, poi `uid`), come `get_canvas_photos`.
  final List<PhotoItem> items;

  /// Testi e forme in ordine di `uid`.
  final List<TextItem> texts;
  final List<ShapeItem> shapes;

  /// Blocchi di sottotitoli in ordine di `uid` (`get_canvas_captions`).
  final List<CaptionItem> captions;

  Snapshot({
    required this.canvas,
    List<PhotoItem> items = const [],
    List<TextItem> texts = const [],
    List<ShapeItem> shapes = const [],
    List<CaptionItem> captions = const [],
  }) : items = List.unmodifiable(sortPhotos(items)),
       texts = List.unmodifiable(
         List<TextItem>.of(texts)..sort((a, b) => a.uid.compareTo(b.uid)),
       ),
       shapes = List.unmodifiable(
         List<ShapeItem>.of(shapes)..sort((a, b) => a.uid.compareTo(b.uid)),
       ),
       captions = List.unmodifiable(
         List<CaptionItem>.of(captions)..sort((a, b) => a.uid.compareTo(b.uid)),
       );

  /// Documento vuoto con le impostazioni di partenza del desktop.
  factory Snapshot.blank({int? layoutSeed}) =>
      Snapshot(canvas: CanvasState(layoutSeed: layoutSeed));

  factory Snapshot.fromJson(Map<String, Object?> json) => Snapshot(
    canvas: CanvasState.fromJson(json['canvas']),
    items: [for (final s in _list(json['items'])) PhotoItem.fromJson(s)],
    texts: [for (final s in _list(json['texts'])) TextItem.fromJson(s)],
    shapes: [for (final s in _list(json['shapes'])) ShapeItem.fromJson(s)],
    captions: [
      for (final s in _list(json['captions'])) CaptionItem.fromJson(s),
    ],
  );

  static List<Object?> _list(Object? v) => v is List ? v : const [];

  /// Ordine stabile per (`layout_index`, `uid`).
  static List<PhotoItem> sortPhotos(Iterable<PhotoItem> photos) {
    final l = [...photos];
    // Ordinamento stabile (a parità vale l'ordine di partenza), come `list.sort` di Python
    final indexed = [for (var i = 0; i < l.length; i++) (i, l[i])];
    indexed.sort((a, b) {
      final c = a.$2.layoutIndex.compareTo(b.$2.layoutIndex);
      if (c != 0) return c;
      final d = a.$2.uid.compareTo(b.$2.uid);
      return d != 0 ? d : a.$1.compareTo(b.$1);
    });
    return [for (final e in indexed) e.$2];
  }

  Map<String, Object?>? _json;

  /// Forma JSON (con gli arrotondamenti del desktop): serve al confronto tra stati e al salvataggio.
  Map<String, Object?> toJson() => _json ??=
      jsonFreeze(<String, Object?>{
            'canvas': canvas.toJson(),
            'items': [for (final p in items) p.toJson()],
            'texts': [for (final t in texts) t.toJson()],
            'shapes': [for (final s in shapes) s.toJson()],
            // Solo se ci sono: i progetti senza sottotitoli restano identici a prima
            if (captions.isNotEmpty)
              'captions': [for (final c in captions) c.toJson()],
          })!
          as Map<String, Object?>;

  Iterable<CanvasElement> get allElements sync* {
    yield* items;
    yield* texts;
    yield* captions;
    yield* shapes;
  }

  Snapshot copyWith({
    CanvasState? canvas,
    List<PhotoItem>? items,
    List<TextItem>? texts,
    List<ShapeItem>? shapes,
    List<CaptionItem>? captions,
  }) => Snapshot(
    canvas: canvas ?? this.canvas,
    items: items ?? this.items,
    texts: texts ?? this.texts,
    shapes: shapes ?? this.shapes,
    captions: captions ?? this.captions,
  );

  /// Uguaglianza come tra i dict del desktop (valori arrotondati).
  @override
  bool operator ==(Object other) =>
      other is Snapshot &&
      (identical(this, other) || jsonEquals(toJson(), other.toJson()));

  @override
  int get hashCode => Object.hash(
    canvas.layoutSeed,
    items.length,
    texts.length,
    shapes.length,
    captions.length,
  );
}
