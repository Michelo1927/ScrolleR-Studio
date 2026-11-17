/// Nome breve di una modifica tra due stati, portato da `HistoryMixin._describe_change`
/// (`scrollr/window/history.py`). Il motore restituisce un nome strutturato: il testo
/// («Foto spostata», «3 forme eliminate»…) lo compone l'app dai file `.arb`.
library;

import '../model/snapshot.dart';
import '../util/py.dart';

/// Tipo di elemento della tela (per l'accordo: spostata/spostato).
enum ElementKind { photo, text, shape }

enum ChangeKind {
  /// Primo passaggio: nome scelto da chi apre la cronologia (`HistoryStart`).
  start,
  pageDuplicated,
  pageAdded,
  pageDeleted,
  photosReplaced,
  elementsChanged,

  /// [ChangeLabel.count] elementi aggiunti, tutti di tipo [ChangeLabel.element] (null = tipi diversi).
  added,
  removed,

  /// Pagine: [ChangeLabel.from] → [ChangeLabel.to].
  pagesCount,
  pageFormat,

  /// Disposizione: [ChangeLabel.layoutMode].
  layout,
  mosaicStyle,
  photosShuffled,
  pageLocks,
  pageSeams,
  pageLayout,
  photosPerPage,
  spacing,
  margin,
  background,
  pageNumbers,
  swipeHint,
  exportName,
  modified,
  grouped,
  ungrouped,
  photoOrder,
  levelChanged,
  positionLock,

  /// [ChangeLabel.count] elementi spostati.
  movedMany,
  layoutUpdated,

  /// [ChangeLabel.count] elementi modificati.
  modifiedMany,

  /// Un elemento ([ChangeLabel.element]) spostato, ridimensionato o ruotato.
  moved,
  resized,
  rotated,
  textEdited,
  photoColors,
  videoTrim,
  videoPoster,
  videoAudio,
  photoFraming,
  photoFree,
  photoInLayout,

  /// Stile di un elemento ([ChangeLabel.element]).
  style,
}

/// Nome strutturato di un passaggio della cronologia.
class ChangeLabel {
  final ChangeKind kind;
  final ElementKind? element;
  final int count;
  final int from;
  final int to;
  final String? layoutMode;

  /// Testo libero per [ChangeKind.start] (es. «Progetto aperto», già tradotto dall'app).
  final String? text;

  const ChangeLabel(
    this.kind, {
    this.element,
    this.count = 0,
    this.from = 0,
    this.to = 0,
    this.layoutMode,
    this.text,
  });

  @override
  bool operator ==(Object other) =>
      other is ChangeLabel &&
      other.kind == kind &&
      other.element == element &&
      other.count == count &&
      other.from == from &&
      other.to == to &&
      other.layoutMode == layoutMode &&
      other.text == text;

  @override
  int get hashCode =>
      Object.hash(kind, element, count, from, to, layoutMode, text);

  @override
  String toString() =>
      'ChangeLabel($kind, element: $element, count: $count, from: $from, to: $to, '
      'layoutMode: $layoutMode, text: $text)';
}

const _kinds = {
  'items': ElementKind.photo,
  'texts': ElementKind.text,
  'shapes': ElementKind.shape,
};

Object? _get(Map<String, Object?> m, String k) => m[k];

Set<String> _diff(Map<String, Object?> a, Map<String, Object?> b) => {
  for (final k in {...a.keys, ...b.keys})
    if (!jsonEquals(_get(a, k), _get(b, k))) k,
};

/// `_describe_change(a, b)`.
ChangeLabel describeChange(Snapshot sa, Snapshot sb) {
  final a = sa.toJson(), b = sb.toJson();
  final ca = a['canvas']! as Map<String, Object?>,
      cb = b['canvas']! as Map<String, Object?>;
  final added = <ElementKind>[], removed = <ElementKind>[];
  final changed = <(ElementKind, Set<String>, Map<String, Object?>)>[];
  for (final e in _kinds.entries) {
    final before = {
      for (final s in (a[e.key]! as List).cast<Map<String, Object?>>())
        s['uid']: s,
    };
    final after = {
      for (final s in (b[e.key]! as List).cast<Map<String, Object?>>())
        s['uid']: s,
    };
    added.addAll([
      for (final u in after.keys)
        if (!before.containsKey(u)) e.value,
    ]);
    removed.addAll([
      for (final u in before.keys)
        if (!after.containsKey(u)) e.value,
    ]);
    for (final u in before.keys) {
      if (!after.containsKey(u)) continue;
      final d = _diff(before[u]!, after[u]!);
      if (d.isNotEmpty) changed.add((e.value, d, after[u]!));
    }
  }

  final fa = ca['num_frames']! as int, fb = cb['num_frames']! as int;
  if (fb == fa + 1) {
    return ChangeLabel(
      added.isNotEmpty ? ChangeKind.pageDuplicated : ChangeKind.pageAdded,
    );
  }
  if (fb == fa - 1) return const ChangeLabel(ChangeKind.pageDeleted);

  ChangeLabel countLabel(List<ElementKind> kinds, ChangeKind kind) =>
      ChangeLabel(
        kind,
        count: kinds.length,
        element: kinds.toSet().length > 1 ? null : kinds.first,
      );

  if (added.isNotEmpty && removed.isNotEmpty) {
    final sameKinds =
        added.toSet().length == 1 &&
        removed.toSet().length == 1 &&
        added.first == ElementKind.photo &&
        removed.first == ElementKind.photo;
    return ChangeLabel(
      sameKinds ? ChangeKind.photosReplaced : ChangeKind.elementsChanged,
    );
  }
  if (added.isNotEmpty) return countLabel(added, ChangeKind.added);
  if (removed.isNotEmpty) return countLabel(removed, ChangeKind.removed);

  if (fb != fa) return ChangeLabel(ChangeKind.pagesCount, from: fa, to: fb);
  final canvasDiff = _diff(ca, cb);
  final canvasNames = <(Set<String>, ChangeKind)>[
    (
      {'ratio_index', 'frame_w', 'frame_h', 'custom_w', 'custom_h'},
      ChangeKind.pageFormat,
    ),
    ({'layout_mode'}, ChangeKind.layout),
    ({'mosaic_style'}, ChangeKind.mosaicStyle),
    ({'layout_seed'}, ChangeKind.photosShuffled),
    ({'page_locks'}, ChangeKind.pageLocks),
    ({'page_seams'}, ChangeKind.pageSeams),
    ({'page_layouts'}, ChangeKind.pageLayout),
    ({'per_frame', 'per_page', 'page_counts'}, ChangeKind.photosPerPage),
    ({'gap'}, ChangeKind.spacing),
    ({'margin'}, ChangeKind.margin),
    (
      {
        'bg_color',
        'bg_mode',
        'bg_color2',
        'bg_direction',
        'bg_blur_path',
        'bg_blur_asset',
        'bg_blur_amount',
        'bg_dim',
      },
      ChangeKind.background,
    ),
    (
      {
        'page_numbers',
        'page_number_format',
        'page_number_pos',
        'overlay_style',
      },
      ChangeKind.pageNumbers,
    ),
    ({'swipe_hint', 'swipe_text', 'swipe_pos'}, ChangeKind.swipeHint),
    ({'export_name'}, ChangeKind.exportName),
  ];
  for (final (keys, kind) in canvasNames) {
    if (canvasDiff.intersection(keys).isNotEmpty) {
      return kind == ChangeKind.layout
          ? ChangeLabel(kind, layoutMode: cb['layout_mode'] as String?)
          : ChangeLabel(kind);
    }
  }

  if (changed.isEmpty) return const ChangeLabel(ChangeKind.modified);
  final allKeys = {for (final c in changed) ...c.$2};
  bool sub(Set<String> keys, Set<String> of) => keys.difference(of).isEmpty;
  if (allKeys.length == 1 && allKeys.first == 'group') {
    return ChangeLabel(
      changed.every((c) => truthyGroup(c.$3['group']))
          ? ChangeKind.grouped
          : ChangeKind.ungrouped,
    );
  }
  if (sub(allKeys, {'layout_index'})) {
    return const ChangeLabel(ChangeKind.photoOrder);
  }
  if (sub(allKeys, {'z'})) return const ChangeLabel(ChangeKind.levelChanged);
  if (sub(allKeys, {'locked'})) {
    return const ChangeLabel(ChangeKind.positionLock);
  }
  final moved = sub(allKeys, {'x', 'y'});
  if (changed.length > 1) {
    if (moved) return ChangeLabel(ChangeKind.movedMany, count: changed.length);
    if (allKeys.intersection({'w', 'h'}).isNotEmpty &&
        sub(allKeys, {'x', 'y', 'w', 'h', 'rotation', 'layout_index'})) {
      return const ChangeLabel(ChangeKind.layoutUpdated);
    }
    return ChangeLabel(ChangeKind.modifiedMany, count: changed.length);
  }
  final (kind, diff, _) = changed.first;
  if (moved) return ChangeLabel(ChangeKind.moved, element: kind);
  if (sub(diff, {'x', 'y', 'w', 'h'})) {
    return ChangeLabel(ChangeKind.resized, element: kind);
  }
  if (sub(diff, {'x', 'y', 'rotation'})) {
    return ChangeLabel(ChangeKind.rotated, element: kind);
  }
  if (diff.contains('text')) return const ChangeLabel(ChangeKind.textEdited);
  if (diff.contains('adjust')) return const ChangeLabel(ChangeKind.photoColors);
  if (diff.contains('trim_start') || diff.contains('trim_end')) {
    return const ChangeLabel(ChangeKind.videoTrim);
  }
  if (diff.contains('poster')) return const ChangeLabel(ChangeKind.videoPoster);
  if (diff.contains('muted')) return const ChangeLabel(ChangeKind.videoAudio);
  if (sub(diff, {'inner_zoom', 'pan_x', 'pan_y', 'inner_rotation'})) {
    return const ChangeLabel(ChangeKind.photoFraming);
  }
  if (diff.contains('free')) {
    // Come il desktop: «Foto libera» se nello stato nuovo c'è almeno una foto libera
    final anyFree = (b['items']! as List).cast<Map<String, Object?>>().any(
      (s) => s['free'] == true,
    );
    return ChangeLabel(
      anyFree ? ChangeKind.photoFree : ChangeKind.photoInLayout,
    );
  }
  return ChangeLabel(ChangeKind.style, element: kind);
}

bool truthyGroup(Object? g) => g is num && g != 0;
