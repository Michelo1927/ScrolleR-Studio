/// Copia di lavoro modificabile di uno [Snapshot]: le operazioni del motore (portate dal desktop, che
/// modifica la scena sul posto) lavorano qui e alla fine producono un nuovo snapshot immutabile.
library;

import 'dart:math' as math;

import '../project/formato.dart';
import 'canvas_state.dart';
import 'context.dart';
import 'elements.dart';
import 'snapshot.dart';

class Scene {
  final EngineContext ctx;
  final CanvasState _base;
  final List<Notice> notices = [];

  int frameW;
  int frameH;
  int numFrames;
  bool perFrame;
  int perPage;
  int gap;
  int margin;
  String layoutMode;
  String mosaicStyle;
  String filmStyle;
  int layoutSeed;
  final List<int?> pageCounts;
  final List<PageLayout?> pageLayouts;
  final List<bool?> pageSeams;
  final List<bool?> pageLocks;

  /// Elementi per uid, nell'ordine in cui sono entrati nella scena.
  final Map<int, PhotoItem> photos;
  final Map<int, TextItem> texts;
  final Map<int, ShapeItem> shapes;

  Scene(Snapshot s, this.ctx)
    : _base = s.canvas,
      frameW = s.canvas.frameW,
      frameH = s.canvas.frameH,
      numFrames = s.canvas.numFrames,
      perFrame = s.canvas.perFrame,
      perPage = s.canvas.perPage,
      gap = s.canvas.gap,
      margin = s.canvas.margin,
      layoutMode = s.canvas.layoutMode,
      mosaicStyle = s.canvas.mosaicStyle,
      filmStyle = s.canvas.filmStyle,
      layoutSeed = s.canvas.layoutSeed,
      pageCounts = [...s.canvas.pageCounts],
      pageLayouts = [...s.canvas.pageLayouts],
      pageSeams = [...s.canvas.pageSeams],
      pageLocks = [...s.canvas.pageLocks],
      photos = {for (final p in s.items) p.uid: p},
      texts = {for (final t in s.texts) t.uid: t},
      shapes = {for (final sh in s.shapes) sh.uid: sh} {
    ctx.observe(s.allElements);
  }

  Snapshot toSnapshot({CanvasState Function(CanvasState)? canvas}) {
    var c = _base.copyWith(
      frameW: frameW,
      frameH: frameH,
      numFrames: numFrames,
      perFrame: perFrame,
      perPage: perPage,
      gap: gap,
      margin: margin,
      layoutMode: layoutMode,
      mosaicStyle: mosaicStyle,
      filmStyle: filmStyle,
      layoutSeed: layoutSeed,
      pageCounts: pageCounts,
      pageLayouts: pageLayouts,
      pageSeams: pageSeams,
      pageLocks: pageLocks,
    );
    if (canvas != null) c = canvas(c);
    return Snapshot(
      canvas: c,
      items: photos.values.toList(),
      texts: texts.values.toList(),
      shapes: shapes.values.toList(),
    );
  }

  void notice(NoticeKind kind, [List<int> args = const []]) =>
      notices.add(Notice(kind, args));

  // ---------- Pagine (CollageScene) ----------
  bool joined(int k) =>
      0 <= k &&
      k < numFrames - 1 &&
      k < pageSeams.length &&
      (pageSeams[k] ?? false);

  bool pageLocked(int k) =>
      0 <= k &&
      k < numFrames &&
      k < pageLocks.length &&
      (pageLocks[k] ?? false);

  bool anyPageLocked() {
    for (var k = 0; k < numFrames; k++) {
      if (pageLocked(k)) return true;
    }
    return false;
  }

  List<(int, int)> seamGroups() {
    final groups = <(int, int)>[];
    var start = 0;
    for (var k = 0; k < numFrames; k++) {
      if (!joined(k)) {
        groups.add((start, k));
        start = k + 1;
      }
    }
    return groups;
  }

  (int, int) groupOf(int k) =>
      seamGroups().firstWhere((g) => g.$1 <= k && k <= g.$2);

  /// `_set_frames_silently`.
  void setFramesSilently(int frames) => numFrames = frames;

  /// Elenchi con un valore per pagina, da tenere allineati alle pagine (`_page_lists`).
  List<List<Object?>> get pageLists => [
    pageCounts,
    pageLayouts,
    pageSeams,
    pageLocks,
  ];

  /// `_trim_page_lists`: toglie i None in fondo.
  void trimPageLists() {
    for (final values in pageLists) {
      while (values.isNotEmpty && values.last == null) {
        values.removeLast();
      }
    }
  }

  /// `values.extend([None] * (n - len(values)))`.
  static void padTo(List<Object?> values, int n) {
    while (values.length < n) {
      values.add(null);
    }
  }

  // ---------- Elementi ----------
  /// Foto nell'ordine di disposizione (`get_canvas_photos`).
  List<PhotoItem> canvasPhotos() => Snapshot.sortPhotos(photos.values);

  List<TextItem> canvasTexts() =>
      texts.values.toList()..sort((a, b) => a.uid.compareTo(b.uid));

  List<ShapeItem> canvasShapes() =>
      shapes.values.toList()..sort((a, b) => a.uid.compareTo(b.uid));

  /// `_all_elements`: foto, testi, forme.
  List<CanvasElement> allElements() => [
    ...canvasPhotos(),
    ...canvasTexts(),
    ...canvasShapes(),
  ];

  /// Foto ordinate dalla disposizione: tutte tranne le libere e quelle delle pagine bloccate.
  List<PhotoItem> layoutPhotos() => [
    for (final p in canvasPhotos())
      if (!p.free && !p.pageLocked) p,
  ];

  PhotoItem photo(int uid) => photos[uid]!;

  void put(CanvasElement e) {
    switch (e) {
      case PhotoItem():
        photos[e.uid] = e;
      case TextItem():
        texts[e.uid] = e;
      case ShapeItem():
        shapes[e.uid] = e;
    }
  }

  void remove(CanvasElement e) {
    switch (e) {
      case PhotoItem():
        photos.remove(e.uid);
      case TextItem():
        texts.remove(e.uid);
      case ShapeItem():
        shapes.remove(e.uid);
    }
  }

  /// Versione attuale dell'elemento (gli elementi sono immutabili: si rilegge per uid).
  CanvasElement current(CanvasElement e) => switch (e) {
    PhotoItem() => photos[e.uid]!,
    TextItem() => texts[e.uid]!,
    ShapeItem() => shapes[e.uid]!,
  };

  void moveBy(CanvasElement e, double dx) {
    final c = current(e);
    put(c.withPosition(c.x + dx, c.y));
  }

  /// Ingombro in scena, rotazione inclusa (`_element_rect`).
  Rect elementRect(CanvasElement e) => switch (e) {
    PhotoItem() => e.cellRect,
    ShapeItem() => e.frameRect,
    TextItem() => () {
      final s = ctx.textSize(e);
      return Rect.rotated(e.x, e.y, s.w, s.h, e.rotation);
    }(),
  };

  /// Pagina di un elemento: `floor(x_centro / frame_w)` (`_page_of`).
  int pageOf(CanvasElement e) => (elementRect(e).centerX / frameW).floor();

  double maxZ() =>
      allElements().fold<double?>(
        null,
        (m, e) => m == null ? e.z : math.max(m, e.z),
      ) ??
      0.0;

  int newGroupId() =>
      allElements().fold<int>(0, (m, e) => math.max(m, e.group)) + 1;

  double sourceRatio(PhotoItem p) => p.sourceRatio(ctx.imageSize(p));

  /// `_spawn_photo_item`: livello e ordine di disposizione dopo tutte le foto già sulla tela.
  PhotoItem spawnPhoto(
    String path, {
    String? rel,
    MediaAsset? asset,
    bool? isVideo,
  }) {
    final existing = photos.values;
    final z =
        existing.fold<double?>(
          null,
          (m, p) => m == null ? p.z : math.max(m, p.z),
        ) ??
        0.0;
    final li =
        existing.fold<int?>(
          null,
          (m, p) => m == null ? p.layoutIndex : math.max(m, p.layoutIndex),
        ) ??
        0;
    final p = PhotoItem(
      uid: ctx.newPhotoUid(),
      path: path,
      rel: rel,
      asset: asset,
      z: z + 1.0,
      layoutIndex: li + 1,
      isVideo: isVideo ?? isVideoPath(path),
    );
    photos[p.uid] = p;
    return p;
  }

  static bool isVideoPath(String path) {
    final l = path.toLowerCase();
    return estensioniVideo.any(l.endsWith);
  }
}
