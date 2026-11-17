/// Pagine del carosello, portate 1:1 da `scrollr/window/pages.py` (`PagesMixin`): inserisci, duplica,
/// elimina, sposta, riordina, blocca, unisci «a cavallo», disposizione e numero di foto di una pagina.
///
/// Ogni operazione sposta gli elementi di `frame_w` e tiene allineate le quattro liste per pagina
/// (`page_counts`, `page_layouts`, `page_seams`, `page_locks`). Le conferme (es. «Eliminare la pagina?»)
/// spettano all'app, prima di chiamare il motore.
library;

import '../layout/layout.dart';
import '../layout/layout_ops.dart';
import '../model/canvas_state.dart';
import '../model/context.dart';
import '../model/elements.dart';
import '../model/result.dart';
import '../model/scene.dart';
import '../model/snapshot.dart';
import '../project/formato.dart';

/// Pagina di un elemento: `floor(x_centro / frame_w)` (`_page_of`).
int pageOf(Snapshot s, CanvasElement e, EngineContext ctx) =>
    Scene(s, ctx).pageOf(e);

/// Elementi che stanno nella pagina [k] (per chiedere conferma prima di eliminarla).
List<CanvasElement> elementsInPage(Snapshot s, int k, EngineContext ctx) {
  final sc = Scene(s, ctx);
  return [
    for (final e in sc.allElements())
      if (sc.pageOf(e) == k) e,
  ];
}

/// `_insert_page_at`: pagina vuota in posizione [i] (0 = all'inizio); le pagine da [i] in poi scorrono a destra.
EngineResult insertPageAt(Snapshot s, int i, EngineContext ctx) {
  final sc = Scene(s, ctx);
  final n = sc.numFrames;
  if (n >= pagineMassime) {
    sc.notice(NoticeKind.maxPages, [n]);
    return EngineResult.refused(s, sc);
  }
  final inside = sc.joined(
    i - 1,
  ); // Pagina nuova in mezzo a un gruppo «a cavallo»: ne fa parte
  if (inside && sc.pageLocked(i - 1)) {
    sc.notice(NoticeKind.seamPagesLocked, [i + 1]);
    return EngineResult.refused(s, sc);
  }
  final fw = sc.frameW.toDouble();
  for (final it in sc.allElements()) {
    if (sc.pageOf(it) >= i) sc.moveBy(it, fw);
  }
  for (final values in sc.pageLists) {
    if (i < values.length) values.insert(i, null);
  }
  if (inside) {
    Scene.padTo(sc.pageSeams, i + 1);
    sc.pageSeams[i] = true;
  }
  if (sc.photos.isNotEmpty) {
    // La pagina nuova resta vuota (copertina, testo…): il prossimo ridisegno non ci sposta foto
    Scene.padTo(sc.pageCounts, i + 1);
    sc.pageCounts[i] = 0;
  }
  ctx.seamAddedFrames = null;
  sc.setFramesSilently(n + 1);
  if (inside) relayoutKeep(sc);
  return EngineResult.done(sc);
}

/// `_insert_page_after`.
EngineResult insertPageAfter(Snapshot s, int k, EngineContext ctx) =>
    insertPageAt(s, k + 1, ctx);

/// `_duplicate_page`: copia la pagina [k] subito dopo di lei, con elementi e impostazioni della pagina.
/// Con una disposizione per ogni pagina le foto copiate restano nella disposizione della pagina nuova;
/// con la tela continua diventano foto libere, così la copia resta identica.
EngineResult duplicatePage(Snapshot s, int k, EngineContext ctx) {
  final sc = Scene(s, ctx);
  final n = sc.numFrames;
  if (!(0 <= k && k < n)) return EngineResult.refused(s, sc);
  if (n >= pagineMassime) {
    sc.notice(NoticeKind.maxPages, [n]);
    return EngineResult.refused(s, sc);
  }
  if (sc.pageLocked(k) && sc.joined(k)) {
    sc.notice(NoticeKind.seamPageLocked, [k + 1]);
    return EngineResult.refused(s, sc);
  }
  final split = pagesSplit(sc);
  final current = split ? photoPages(sc) : <int, int>{};
  final inside = [
    for (final it in sc.allElements())
      if (sc.pageOf(it) == k) it,
  ];
  final fw = sc.frameW.toDouble();
  // Le pagine dopo k scorrono a destra; le impostazioni della pagina k valgono anche per la copia
  for (final it in sc.allElements()) {
    if (sc.pageOf(it) > k) sc.moveBy(it, fw);
  }
  for (final values in sc.pageLists) {
    if (k < values.length) {
      values.insert(
        k + 1,
        values[k],
      ); // Valori immutabili: la copia è implicita
    }
  }
  if (k + 1 < sc.pageLocks.length) {
    sc.pageLocks[k + 1] =
        null; // La copia di una pagina bloccata nasce sbloccata
  }
  ctx.seamAddedFrames = null;
  sc.setFramesSilently(n + 1);

  final firstGroup = sc.newGroupId();
  final groups = <int, int>{};
  final copies = <int>{};
  final ordinati = [for (var j = 0; j < inside.length; j++) (j, inside[j])]
    ..sort((a, b) {
      final c = a.$2.z.compareTo(b.$2.z);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
  for (final (_, orig) in ordinati) {
    final it = sc.current(orig);
    final group = it.group != 0
        ? groups.putIfAbsent(it.group, () => firstGroup + groups.length)
        : it.group;
    switch (it) {
      case TextItem():
        final dup = TextItem(uid: ctx.newTextUid());
        sc.put(dup);
        sc.put(
          it.copyWith(
            uid: dup.uid,
            group: group,
            z: sc.maxZ() + 1.0,
            x: it.x + fw,
            pageLocked: false,
          ),
        );
      case ShapeItem():
        final dup = ShapeItem(uid: ctx.newShapeUid(), kind: it.kind);
        sc.put(dup);
        sc.put(
          it.copyWith(
            uid: dup.uid,
            group: group,
            z: sc.maxZ() + 1.0,
            x: it.x + fw,
            pageLocked: false,
          ),
        );
      case PhotoItem():
        final dup = sc.spawnPhoto(
          it.path,
          rel: it.rel,
          asset: it.asset,
          isVideo: it.isVideo,
        );
        copies.add(dup.uid);
        sc.put(
          it.copyWith(
            uid: dup.uid,
            layoutIndex: dup.layoutIndex,
            free: it.free || !split,
            group: group,
            z: sc.maxZ() + 1.0,
            x: it.x + fw,
            pageLocked: false,
          ),
        );
    }
  }

  if (split) {
    // Ordine delle foto per pagina, con le copie nella pagina nuova: ogni pagina fissa le sue
    final byPage = [for (var i = 0; i <= n; i++) <int>[]];
    for (final p in sc.layoutPhotos()) {
      if (copies.contains(p.uid)) {
        byPage[k + 1].add(p.uid);
      } else {
        final page = current[p.uid] ?? n - 1;
        byPage[page > k ? page + 1 : page].add(p.uid);
      }
    }
    Scene.padTo(sc.pageCounts, n + 1);
    sc.pageCounts[k] = byPage[k].length;
    sc.pageCounts[k + 1] = byPage[k + 1].length;
    sc.trimPageLists();
    var i = 0;
    for (final page in byPage) {
      for (final u in page) {
        sc.put(sc.photo(u).copyWith(layoutIndex: i++));
      }
    }
    relayoutKeep(sc);
  }
  return EngineResult.done(sc);
}

/// `_delete_page`: toglie la pagina [k] con i suoi elementi; le pagine dopo scorrono a sinistra.
EngineResult deletePage(Snapshot s, int k, EngineContext ctx) {
  final sc = Scene(s, ctx);
  final n = sc.numFrames;
  if (n <= 1) {
    sc.notice(NoticeKind.singlePage);
    return EngineResult.refused(s, sc);
  }
  if (sc.pageLocked(k)) {
    sc.notice(NoticeKind.pageLocked, [k + 1]);
    return EngineResult.refused(s, sc);
  }
  final inside = [
    for (final it in sc.allElements())
      if (sc.pageOf(it) == k) it,
  ];
  final fw = sc.frameW.toDouble();
  inside.forEach(sc.remove);
  for (final it in sc.allElements()) {
    if (sc.pageOf(it) > k) sc.moveBy(it, -fw);
  }
  // La pagina prima resta unita a quella dopo solo se k stava in mezzo a un gruppo «a cavallo»
  final seams = sc.pageSeams;
  if (0 < k && k <= seams.length) {
    seams[k - 1] = sc.joined(k - 1) && sc.joined(k) ? true : null;
  }
  for (final values in sc.pageLists) {
    if (k < values.length) values.removeAt(k);
  }
  sc.trimPageLists();
  ctx.seamAddedFrames = null;
  sc.setFramesSilently(n - 1);
  return EngineResult.done(sc);
}

/// Nuovo ordine delle pagine dopo `_move_page`: la pagina [k] (con tutto il suo gruppo «a cavallo») di un posto
/// ([direction] −1 o +1); `order[nuova posizione] = vecchia posizione`. Null se è già al bordo.
List<int>? ordineSpostaPagina(CanvasState c, int k, int direction) {
  final groups = c.seamGroups();
  final g = groups.indexWhere((x) => x.$1 <= k && k <= x.$2);
  final h = g < 0 ? -1 : g + direction;
  if (g < 0 || !(0 <= h && h < groups.length)) return null;
  final t = groups[g];
  groups[g] = groups[h];
  groups[h] = t;
  return [
    for (final (a, b) in groups)
      for (var p = a; p <= b; p++) p,
  ];
}

/// `_move_page`: sposta la pagina [k] di un posto ([direction] −1 o +1); una pagina «a cavallo» si
/// sposta con tutto il suo gruppo.
EngineResult movePage(Snapshot s, int k, int direction, EngineContext ctx) {
  final order = ordineSpostaPagina(s.canvas, k, direction);
  if (order == null) {
    final sc = Scene(s, ctx)..notice(NoticeKind.pageAtEdge);
    return EngineResult.refused(s, sc);
  }
  return reorderPages(s, order, ctx);
}

/// `_reorder_pages`: nuovo ordine delle pagine, `order[nuova posizione] = vecchia posizione`. Ogni pagina
/// si porta dietro elementi, disposizione e numero di foto.
EngineResult reorderPages(Snapshot s, List<int> order, EngineContext ctx) {
  final sc = Scene(s, ctx);
  final n = sc.numFrames;
  final ordinato = [...order]..sort();
  var valido = ordinato.length == n;
  var identico = order.length == n;
  for (var i = 0; i < ordinato.length && valido; i++) {
    if (ordinato[i] != i) valido = false;
  }
  for (var i = 0; i < order.length && identico; i++) {
    if (order[i] != i) identico = false;
  }
  if (!valido || identico) {
    if (n < 2) sc.notice(NoticeKind.nothingToReorder);
    return EngineResult.refused(s, sc);
  }
  final newPos = {for (var i = 0; i < n; i++) order[i]: i};
  for (var k = 0; k < n - 1; k++) {
    if (sc.pageLocked(k) && sc.joined(k) && newPos[k + 1] != newPos[k]! + 1) {
      // Separarle cambierebbe le foto che attraversano la giunzione
      sc.notice(NoticeKind.lockedSeamMustStayTogether, [k + 1, k + 2]);
      return EngineResult.refused(s, sc);
    }
  }
  final joined = [for (var k = 0; k < n; k++) sc.joined(k)];
  final fw = sc.frameW.toDouble();
  final pages = [for (final it in sc.allElements()) (it, sc.pageOf(it))];
  for (final (it, page) in pages) {
    if (0 <= page && page < n) {
      sc.moveBy(it, (newPos[page]! - page) * fw); // Fuori dalla tela restano
    }
  }
  void riordina<T>(List<T?> values) {
    final padded = List<T?>.of(values);
    Scene.padTo(padded, n);
    final nuovi = [for (final old in order) padded[old]];
    values
      ..clear()
      ..addAll(nuovi);
  }

  riordina(sc.pageCounts);
  riordina(sc.pageLayouts);
  riordina(sc.pageSeams);
  riordina(sc.pageLocks);
  // Due pagine restano «a cavallo» solo se restano vicine e nello stesso ordine
  final seams = [
    for (var j = 0; j < n - 1; j++)
      joined[order[j]] && order[j + 1] == order[j] + 1 ? true : null,
  ];
  sc.pageSeams
    ..clear()
    ..addAll(seams);
  sc.trimPageLists();
  // L'ordine delle foto segue le pagine: un nuovo ridisegno non le rimette dov'erano
  _reindexByPage(sc, sc.canvasPhotos());
  return EngineResult.done(sc);
}

/// Riassegna `layout_index` in ordine di (pagina, layout_index, uid).
void _reindexByPage(Scene sc, List<PhotoItem> photos) {
  final chiavi = [for (final p in photos) (sc.pageOf(p), p.layoutIndex, p.uid)];
  final ordine = [for (var i = 0; i < photos.length; i++) i]
    ..sort((a, b) {
      final (pa, la, ua) = chiavi[a];
      final (pb, lb, ub) = chiavi[b];
      if (pa != pb) return pa.compareTo(pb);
      if (la != lb) return la.compareTo(lb);
      return ua.compareTo(ub);
    });
  for (var i = 0; i < ordine.length; i++) {
    final p = photos[ordine[i]];
    sc.put(sc.photo(p.uid).copyWith(layoutIndex: i));
  }
}

/// `_set_page_lock`: blocca (o sblocca) la pagina [k] così com'è. Una pagina «a cavallo» si blocca e si
/// sblocca con tutto il suo gruppo.
EngineResult setPageLock(Snapshot s, int k, bool on, EngineContext ctx) {
  final sc = Scene(s, ctx);
  if (!(0 <= k && k < sc.numFrames)) return EngineResult.refused(s, sc);
  final (a, b) = sc.groupOf(k);
  Scene.padTo(sc.pageLocks, b + 1);
  final inside = [
    for (final it in sc.allElements())
      if (a <= sc.pageOf(it) && sc.pageOf(it) <= b) it,
  ];
  for (var f = a; f <= b; f++) {
    sc.pageLocks[f] = on ? true : null;
  }
  for (final it in inside) {
    sc.put(sc.current(it).withPageLocked(on));
  }
  if (!on) {
    // Le foto tornano nella disposizione là dove sono: ogni pagina sbloccata fissa il suo numero di foto
    _reindexByPage(sc, sc.layoutPhotos());
    if (pagesSplit(sc)) {
      final photos = sc.layoutPhotos();
      Scene.padTo(sc.pageCounts, b + 1);
      for (var f = a; f <= b; f++) {
        sc.pageCounts[f] = photos.where((p) => sc.pageOf(p) == f).length;
      }
    }
  }
  sc.trimPageLists();
  return EngineResult.done(sc);
}

/// `_toggle_page_lock`.
EngineResult togglePageLock(Snapshot s, int k, EngineContext ctx) =>
    setPageLock(s, k, !s.canvas.pageLocked(k), ctx);

/// `_apply_page_setting`: dopo una scelta su una singola pagina ridispone, accendendo la divisione per pagina.
void _applyPageSetting(Scene sc) {
  if (sc.layoutMode == LayoutModes.seam) {
    sc.notice(NoticeKind.seamIgnoresPageSettings);
  } else if (!sc.perFrame) {
    sc.perFrame = true; // Senza, le foto non si dividono per pagina (il desktop ridispone al cambio)
    relayoutKeep(sc);
  } else {
    relayoutKeep(sc);
  }
}

/// `_set_page_joined`: unisce (o separa) «a cavallo» la pagina [k] e la successiva, e ridispone.
EngineResult setPageJoined(Snapshot s, int k, bool on, EngineContext ctx) {
  final sc = Scene(s, ctx);
  if (!(0 <= k && k < sc.numFrames - 1)) return EngineResult.refused(s, sc);
  if (sc.pageLocked(k) || sc.pageLocked(k + 1)) {
    final j = sc.pageLocked(k) ? k : k + 1;
    sc.notice(NoticeKind.pageLocked, [j + 1]);
    return EngineResult.refused(s, sc);
  }
  Scene.padTo(sc.pageSeams, k + 1);
  sc.pageSeams[k] = on ? true : null;
  sc.trimPageLists();
  _applyPageSetting(sc);
  return EngineResult.done(sc);
}

/// `_toggle_page_joined`.
EngineResult togglePageJoined(Snapshot s, int k, EngineContext ctx) {
  if (k >= s.canvas.numFrames - 1) {
    return EngineResult(
      s,
      notices: const [Notice(NoticeKind.lastPage)],
      applied: false,
    );
  }
  return setPageJoined(s, k, !s.canvas.joined(k), ctx);
}

/// `_set_page_layout`: disposizione propria della pagina [k] (null = come le altre) e ridispone.
EngineResult setPageLayout(
  Snapshot s,
  int k,
  String? mode,
  EngineContext ctx, [
  String? style,
]) {
  final sc = Scene(s, ctx);
  if (sc.pageLocked(k)) {
    sc.notice(NoticeKind.pageLocked, [k + 1]);
    return EngineResult.refused(s, sc);
  }
  Scene.padTo(sc.pageLayouts, k + 1);
  sc.pageLayouts[k] = mode != null && mode.isNotEmpty
      ? PageLayout(mode, style)
      : null;
  sc.trimPageLists();
  _applyPageSetting(sc);
  return EngineResult.done(sc);
}

/// `_set_page_count`: quante foto vanno nella pagina [k] (null = automatico) e ridispone.
EngineResult setPageCount(Snapshot s, int k, int? value, EngineContext ctx) {
  final sc = Scene(s, ctx);
  if (sc.pageLocked(k)) {
    sc.notice(NoticeKind.pageLocked, [k + 1]);
    return EngineResult.refused(s, sc);
  }
  Scene.padTo(sc.pageCounts, k + 1);
  sc.pageCounts[k] = value;
  sc.trimPageLists();
  _applyPageSetting(sc);
  return EngineResult.done(sc);
}
