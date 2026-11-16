/// Operazioni della disposizione su uno snapshot immutabile (`scrollr/window/layouts.py`):
/// disposizione automatica, scelta della disposizione, rimescola, scambia, foto libere,
/// foto spostate o inserite in una pagina.
library;

import '../model/canvas_state.dart';
import '../model/context.dart';
import '../model/elements.dart';
import '../model/result.dart';
import '../model/scene.dart';
import '../model/snapshot.dart';
import '../util/py_random.dart';
import 'layout.dart';

/// `apply_auto_layout(mode)` così com'è (la disposizione nel progetto resta quella del modo usato).
EngineResult applyAutoLayout(Snapshot s, String mode, EngineContext ctx) {
  final sc = Scene(s, ctx);
  applyAutoLayoutIn(sc, mode);
  return EngineResult.done(sc);
}

/// `_relayout_keep`: ridispone con la disposizione attuale (dopo spaziatura, margine, foto per pagina…).
EngineResult relayout(Snapshot s, EngineContext ctx) {
  final sc = Scene(s, ctx);
  relayoutKeep(sc);
  return EngineResult.done(sc);
}

/// `_on_layout_button`: scelta esplicita di una disposizione, con un seme nuovo per Polaroid.
EngineResult chooseLayout(
  Snapshot s,
  String mode,
  EngineContext ctx, {
  int? seed,
}) {
  final sc = Scene(s, ctx);
  sc.layoutSeed = seed ?? CanvasState.newLayoutSeed();
  sc.layoutMode = mode;
  applyAutoLayoutIn(sc, mode);
  return EngineResult.done(sc);
}

/// `_on_mosaic_style_changed`: nuovo stile del mosaico, ridispone se la disposizione è il mosaico.
EngineResult setMosaicStyle(Snapshot s, String style, EngineContext ctx) {
  final sc = Scene(s, ctx);
  sc.mosaicStyle = style.isEmpty ? 'auto' : style;
  if (sc.layoutMode == LayoutModes.mosaic) relayoutKeep(sc);
  return EngineResult.done(sc);
}

/// Spaziatura (0–80) e margine (0–120): ridispone come gli slider del desktop.
EngineResult setSpacing(
  Snapshot s,
  EngineContext ctx, {
  int? gap,
  int? margin,
}) {
  final sc = Scene(s, ctx);
  if (gap != null) sc.gap = gap.clamp(0, 80);
  if (margin != null) sc.margin = margin.clamp(0, 120);
  relayoutKeep(sc);
  return EngineResult.done(sc);
}

/// «Una disposizione per ogni pagina» (`chk_per_frame`).
EngineResult setPerFrame(Snapshot s, bool on, EngineContext ctx) {
  final sc = Scene(s, ctx);
  sc.perFrame = on;
  relayoutKeep(sc);
  return EngineResult.done(sc);
}

/// «Foto per pagina» (0 = Auto, massimo 20): `_on_per_page_changed`.
EngineResult setPerPage(Snapshot s, int perPage, EngineContext ctx) {
  final sc = Scene(s, ctx);
  sc.perPage = perPage.clamp(0, 20);
  relayoutKeep(sc);
  return EngineResult.done(sc);
}

/// `shuffle_canvas_photos`: rimescola l'ordine delle foto tenendo posizioni e misure.
EngineResult shufflePhotos(Snapshot s, EngineContext ctx, {PyRandom? rng}) {
  final sc = Scene(s, ctx);
  final photos = sc.layoutPhotos();
  if (photos.length < 2) return EngineResult.refused(s, sc);
  final slots = [for (final p in photos) _Slot.of(p)];
  // Tutti i posti uguali: nessun ordine diverso è possibile (il desktop qui girerebbe all'infinito)
  if (slots.every((x) => x == slots.first)) return EngineResult.refused(s, sc);
  final shuffled = [...slots];
  final r = rng ?? PyRandom(DateTime.now().microsecondsSinceEpoch);
  // Garantisce che qualcosa cambi davvero
  while (_sameSlots(shuffled, slots)) {
    r.shuffle(shuffled);
  }
  for (var i = 0; i < photos.length; i++) {
    sc.put(shuffled[i].applyTo(sc.photo(photos[i].uid)));
  }
  return EngineResult.done(sc);
}

/// `swap_two_selected_photos`: scambia posto, misure, rotazione, livello e ordine di due foto.
EngineResult swapPhotos(Snapshot s, int uidA, int uidB, EngineContext ctx) {
  final sc = Scene(s, ctx);
  final a = sc.photos[uidA], b = sc.photos[uidB];
  if (a == null || b == null || uidA == uidB) {
    sc.notice(NoticeKind.swapNeedsTwo);
    return EngineResult.refused(s, sc);
  }
  sc.put(_Slot.of(b).applyTo(a));
  sc.put(_Slot.of(a).applyTo(b));
  return EngineResult.done(sc);
}

/// `_toggle_free_selected`: foto libera ↔ foto nella disposizione.
EngineResult toggleFree(Snapshot s, List<int> uids, EngineContext ctx) {
  final sc = Scene(s, ctx);
  final photos = [for (final u in uids) ?sc.photos[u]];
  if (photos.isEmpty) return EngineResult.refused(s, sc);
  final makeFree = !photos.every((p) => p.free);
  for (final p in photos) {
    var cur = sc.photo(p.uid).copyWith(free: makeFree);
    if (makeFree) {
      sc.put(cur);
      cur = cur.copyWith(z: sc.maxZ() + 1.0); // Davanti alle foto ordinate
    }
    sc.put(cur);
  }
  relayoutKeep(sc);
  return EngineResult.done(sc);
}

// ---------- Foto spostate da una pagina all'altra ----------
/// Pagina in cui la disposizione mette ogni foto ordinata: {uid: pagina} (`_photo_pages`).
Map<int, int> photoPages(Scene sc) {
  final ordered = sc.layoutPhotos();
  final pages = <int, int>{};
  var start = 0;
  final counts = pagePhotoCounts(sc, ordered.length);
  for (var f = 0; f < counts.length; f++) {
    for (var i = start; i < start + counts[f] && i < ordered.length; i++) {
      pages[ordered[i].uid] = f;
    }
    start += counts[f];
  }
  return pages;
}

/// Le foto si dividono per pagina (`_pages_split`).
bool pagesSplit(Scene sc) =>
    sc.perFrame && sc.layoutMode != LayoutModes.seam && sc.numFrames > 1;

/// `_move_photos_to_page`: mette le foto in fondo alla pagina [target]; le pagine toccate fissano il loro
/// nuovo numero di foto, così il prossimo ridisegno non le riporta dov'erano.
EngineResult movePhotosToPage(
  Snapshot s,
  List<int> uids,
  int target,
  EngineContext ctx,
) {
  final sc = Scene(s, ctx);
  return movePhotosToPageIn(sc, uids, target)
      ? EngineResult.done(sc)
      : EngineResult.refused(s, sc);
}

bool movePhotosToPageIn(Scene sc, List<int> uids, int target) {
  if (!pagesSplit(sc) || !(0 <= target && target < sc.numFrames)) return false;
  if (sc.pageLocked(target)) {
    sc.notice(NoticeKind.pageLocked, [target + 1]);
    return false;
  }
  final ordered = sc.layoutPhotos();
  final current = photoPages(sc);
  final movers = <int>[
    for (final u in uids)
      if (sc.photos[u] != null &&
          !sc.photos[u]!.free &&
          (current[u] ?? target) != target)
        u,
  ];
  if (movers.isEmpty) return false;
  final byPage = [for (var i = 0; i < sc.numFrames; i++) <int>[]];
  for (final p in ordered) {
    if (!movers.contains(p.uid)) {
      final page = current[p.uid] ?? 0;
      byPage[page < sc.numFrames - 1 ? page : sc.numFrames - 1].add(p.uid);
    }
  }
  byPage[target].addAll(movers);
  Scene.padTo(sc.pageCounts, sc.numFrames);
  for (final f in {for (final u in movers) current[u]!, target}) {
    sc.pageCounts[f] = byPage[f].length;
  }
  sc.trimPageLists();
  var i = 0;
  for (final page in byPage) {
    for (final u in page) {
      sc.put(sc.photo(u).copyWith(layoutIndex: i++));
    }
  }
  relayoutKeep(sc);
  return true;
}

/// `_insert_into_page`: foto appena create ([newUids]) in fondo alla pagina [target]; [current] è la
/// pagina delle foto già ordinate letta prima di crearle (`photoPages`).
void insertIntoPageIn(
  Scene sc,
  List<int> newUids,
  int target,
  Map<int, int> current,
) {
  final n = sc.numFrames;
  final byPage = [for (var i = 0; i < n; i++) <int>[]];
  for (final p in sc.layoutPhotos()) {
    if (!newUids.contains(p.uid)) {
      final page = current[p.uid] ?? n - 1;
      byPage[page < n - 1 ? page : n - 1].add(p.uid);
    }
  }
  byPage[target].addAll(newUids);
  Scene.padTo(sc.pageCounts, n);
  sc.pageCounts[target] = byPage[target].length;
  sc.trimPageLists();
  var i = 0;
  for (final page in byPage) {
    for (final u in page) {
      sc.put(sc.photo(u).copyWith(layoutIndex: i++));
    }
  }
  relayoutKeep(sc);
}

/// `_on_photo_dropped`: foto rilasciate (già spostate a mano in [s]) su un'altra pagina: passano a
/// quella pagina e ci restano. [dragged] sono le foto trascinate.
EngineResult photosDropped(Snapshot s, List<int> dragged, EngineContext ctx) {
  final sc = Scene(s, ctx);
  final photos = [
    for (final u in dragged)
      if (sc.photos[u] != null && !sc.photos[u]!.free) sc.photos[u]!,
  ];
  final locked = [
    for (final p in photos)
      if (sc.pageLocked(sc.pageOf(p))) sc.pageOf(p),
  ];
  if (locked.isNotEmpty) {
    // Su una pagina bloccata non entra niente: la foto torna al suo posto
    relayoutKeep(sc);
    sc.notice(NoticeKind.pageLocked, [locked[0] + 1]);
    return EngineResult.done(sc);
  }
  if (!pagesSplit(sc)) return EngineResult(s);
  final current = photoPages(sc);
  final group = <int, (int, int)>{
    for (final g in sc.seamGroups())
      for (var f = g.$1; f <= g.$2; f++) f: g,
  };
  final targets = <int, List<int>>{};
  for (final p in photos) {
    final page = sc.pageOf(p);
    // Dentro lo stesso gruppo «a cavallo» la foto non cambia pagina
    if (0 <= page &&
        page < sc.numFrames &&
        group[page] != group[current[p.uid] ?? page]) {
      targets.putIfAbsent(page, () => []).add(p.uid);
    }
  }
  for (final e in targets.entries) {
    movePhotosToPageIn(sc, e.value, e.key);
  }
  return EngineResult.done(sc);
}

/// `_slot`: posto di una foto nella disposizione.
class _Slot {
  final double x, y, w, h, rotation, z;
  final int layoutIndex;
  const _Slot(
    this.x,
    this.y,
    this.w,
    this.h,
    this.rotation,
    this.z,
    this.layoutIndex,
  );

  factory _Slot.of(PhotoItem p) =>
      _Slot(p.x, p.y, p.w, p.h, p.rotation, p.z, p.layoutIndex);

  PhotoItem applyTo(PhotoItem p) => p.copyWith(
    w: w,
    h: h,
    x: x,
    y: y,
    rotation: rotation,
    z: z,
    layoutIndex: layoutIndex,
  );

  @override
  bool operator ==(Object other) =>
      other is _Slot &&
      other.x == x &&
      other.y == y &&
      other.w == w &&
      other.h == h &&
      other.rotation == rotation &&
      other.z == z &&
      other.layoutIndex == layoutIndex;

  @override
  int get hashCode => Object.hash(x, y, w, h, rotation, z, layoutIndex);
}

bool _sameSlots(List<_Slot> a, List<_Slot> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
