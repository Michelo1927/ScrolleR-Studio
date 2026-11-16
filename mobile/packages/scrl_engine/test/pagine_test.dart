import 'package:scrl_engine/scrl_engine.dart';
import 'package:test/test.dart';

/// Contesto con tutte le foto 600 × 800 e testi larghi 200 × 100.
EngineContext _ctx() => EngineContext(
  imageSize: (_) => (w: 600, h: 800),
  textSize: (_) => (w: 200.0, h: 100.0),
);

/// Tela di [pagine] pagine con [n] foto disposte in griglia, una disposizione per pagina.
Snapshot _tela(
  int pagine,
  int n,
  EngineContext ctx, {
  List<TextItem> testi = const [],
}) {
  final foto = [
    for (var i = 1; i <= n; i++)
      PhotoItem(uid: i, path: 'f$i.jpg', layoutIndex: i, z: i.toDouble()),
  ];
  final s = Snapshot(
    canvas: CanvasState(numFrames: pagine, layoutSeed: 7),
    items: foto,
    texts: testi,
  );
  return applyAutoLayout(s, 'grid', ctx).snapshot;
}

List<int> _pagine(Snapshot s, EngineContext ctx) => [
  for (final p in s.items) pageOf(s, p, ctx),
];

void main() {
  test('foto divise in parti uguali tra le pagine', () {
    final ctx = _ctx();
    final s = _tela(3, 7, ctx);
    expect(_pagine(s, ctx), [0, 0, 0, 1, 1, 2, 2]);
  });

  test('inserisci una pagina: gli elementi dopo scorrono e la pagina nuova resta vuota', () {
    final ctx = _ctx();
    final testo = TextItem(uid: 1, x: 1080 + 100, y: 50);
    final s = _tela(2, 4, ctx, testi: [testo]);
    final r = insertPageAt(s, 1, ctx);
    expect(r.applied, isTrue);
    expect(r.snapshot.canvas.numFrames, 3);
    expect(r.snapshot.canvas.pageCounts, [null, 0]);
    expect(_pagine(r.snapshot, ctx), [0, 0, 2, 2]);
    expect(r.snapshot.texts.single.x, 2160 + 100);
    // Ridisponendo, la pagina nuova resta vuota
    final d = relayout(r.snapshot, ctx).snapshot;
    expect(_pagine(d, ctx), [0, 0, 2, 2]);
  });

  test(
    'inserisci dentro un gruppo «a cavallo»: la pagina nuova ne fa parte',
    () {
      final ctx = _ctx();
      final s = setPageJoined(_tela(2, 4, ctx), 0, true, ctx).snapshot;
      final r = insertPageAt(s, 1, ctx).snapshot;
      expect(r.canvas.numFrames, 3);
      expect(r.canvas.seamGroups(), [(0, 2)]);
    },
  );

  test('massimo 30 pagine', () {
    final ctx = _ctx();
    final s = Snapshot(canvas: CanvasState(numFrames: 30, layoutSeed: 1));
    final r = insertPageAt(s, 0, ctx);
    expect(r.applied, isFalse);
    expect(r.notices, [
      const Notice(NoticeKind.maxPages, [30]),
    ]);
  });

  test('elimina una pagina: i suoi elementi spariscono, quelli dopo tornano indietro', () {
    final ctx = _ctx();
    final s = _tela(3, 6, ctx);
    final r = deletePage(s, 1, ctx).snapshot;
    expect(r.canvas.numFrames, 2);
    expect(r.items.map((p) => p.uid), [1, 2, 5, 6]);
    expect(_pagine(r, ctx), [0, 0, 1, 1]);
  });

  test('una pagina bloccata non si elimina; una sola pagina nemmeno', () {
    final ctx = _ctx();
    final s = setPageLock(_tela(2, 4, ctx), 1, true, ctx).snapshot;
    expect(deletePage(s, 1, ctx).notices, [
      const Notice(NoticeKind.pageLocked, [2]),
    ]);
    expect(deletePage(_tela(1, 2, ctx), 0, ctx).notices, [
      const Notice(NoticeKind.singlePage),
    ]);
  });

  test('blocca: elementi bloccati e esclusi dalla disposizione; sblocca: la pagina fissa le sue foto', () {
    final ctx = _ctx();
    final s = _tela(2, 4, ctx);
    final b = setPageLock(s, 1, true, ctx).snapshot;
    expect(b.canvas.pageLocks, [null, true]);
    expect(b.items.where((p) => p.pageLocked).map((p) => p.uid), [3, 4]);
    // Con la pagina 2 bloccata, cambiare spaziatura non tocca le sue foto
    final g = setSpacing(b, ctx, gap: 60).snapshot;
    expect(
      g.items.firstWhere((p) => p.uid == 3).x,
      b.items.firstWhere((p) => p.uid == 3).x,
    );
    expect(setNumFrames(b, 1, ctx).applied, isFalse);
    expect(setAspectRatio(b, 3, ctx).notices, [
      const Notice(NoticeKind.lockedPagesNoResize),
    ]);
    final u = setPageLock(b, 1, false, ctx).snapshot;
    expect(u.canvas.pageLocks, isEmpty);
    expect(u.canvas.pageCounts, [null, 2]);
    expect(u.items.every((p) => !p.pageLocked), isTrue);
  });

  test('bloccare una pagina «a cavallo» blocca tutto il gruppo', () {
    final ctx = _ctx();
    final s = setPageJoined(_tela(3, 6, ctx), 1, true, ctx).snapshot;
    final b = setPageLock(s, 2, true, ctx).snapshot;
    expect(b.canvas.pageLocks, [null, true, true]);
  });

  test('duplica una pagina: copie nella pagina nuova, nella disposizione', () {
    final ctx = _ctx();
    final s = _tela(2, 4, ctx);
    final r = duplicatePage(s, 0, ctx).snapshot;
    expect(r.canvas.numFrames, 3);
    expect(r.items.length, 6);
    expect(r.canvas.pageCounts, [2, 2]);
    final copie = r.items.where((p) => p.uid > 4).toList();
    expect(copie.map((p) => p.path), ['f1.jpg', 'f2.jpg']);
    expect(copie.every((p) => !p.free), isTrue);
    expect([for (final p in copie) pageOf(r, p, ctx)], [1, 1]);
    expect(_pagine(r, ctx), [0, 0, 1, 1, 2, 2]);
  });

  test('duplica con la tela continua: le copie diventano foto libere', () {
    final ctx = _ctx();
    final s = setPerFrame(_tela(2, 4, ctx), false, ctx).snapshot;
    final r = duplicatePage(s, 1, ctx).snapshot;
    final copie = r.items.where((p) => p.uid > 4).toList();
    expect(copie, isNotEmpty);
    expect(copie.every((p) => p.free), isTrue);
  });

  test(
    'sposta e riordina: le pagine si portano dietro foto e impostazioni',
    () {
      final ctx = _ctx();
      var s = _tela(3, 6, ctx);
      s = setPageLayout(s, 2, 'strips_h', ctx).snapshot;
      final m = movePage(s, 2, -1, ctx).snapshot;
      expect(m.canvas.pageLayouts, [null, PageLayout('strips_h')]);
      final perUid = {for (final p in m.items) p.uid: pageOf(m, p, ctx)};
      expect(perUid, {1: 0, 2: 0, 5: 1, 6: 1, 3: 2, 4: 2});
      // L'ordine della disposizione segue le pagine
      expect(m.items.map((p) => p.uid), [1, 2, 5, 6, 3, 4]);
      expect(movePage(m, 0, -1, ctx).notices, [
        const Notice(NoticeKind.pageAtEdge),
      ]);
      // Ordine non valido o uguale: nessun cambiamento
      expect(reorderPages(m, [0, 1, 2], ctx).applied, isFalse);
      expect(reorderPages(m, [0, 0, 2], ctx).applied, isFalse);
    },
  );

  test('un gruppo «a cavallo» si sposta insieme; bloccato non si separa', () {
    final ctx = _ctx();
    final s = setPageJoined(_tela(3, 6, ctx), 0, true, ctx).snapshot;
    final m = movePage(s, 2, -1, ctx).snapshot;
    expect(m.canvas.seamGroups(), [(0, 0), (1, 2)]);
    final b = setPageLock(s, 0, true, ctx).snapshot;
    expect(reorderPages(b, [2, 0, 1], ctx).applied, isTrue);
    final r = reorderPages(b, [1, 0, 2], ctx);
    expect(r.applied, isFalse);
    expect(r.notices.single.kind, NoticeKind.lockedSeamMustStayTogether);
  });

  test('foto fissate per pagina e disposizione propria', () {
    final ctx = _ctx();
    final s = setPageCount(_tela(2, 6, ctx), 0, 1, ctx).snapshot;
    expect(_pagine(s, ctx), [0, 1, 1, 1, 1, 1]);
    final c = setPageCount(
      setPerFrame(_tela(2, 6, ctx), false, ctx).snapshot,
      0,
      2,
      ctx,
    ).snapshot;
    expect(
      c.canvas.perFrame,
      isTrue,
    ); // La scelta su una pagina accende la divisione per pagina
    expect(togglePageJoined(c, 1, ctx).notices, [
      const Notice(NoticeKind.lastPage),
    ]);
  });

  test('foto spostata in un\'altra pagina ci resta', () {
    final ctx = _ctx();
    final s = _tela(2, 4, ctx);
    final r = movePhotosToPage(s, [1], 1, ctx).snapshot;
    expect(r.canvas.pageCounts, [1, 3]);
    expect(
      {for (final p in r.items) p.uid: pageOf(r, p, ctx)},
      {2: 0, 3: 1, 4: 1, 1: 1},
    );
  });

  test('numero di pagine a mano: «Foto per pagina» torna su Auto', () {
    final ctx = _ctx();
    final s = setPerPage(_tela(1, 6, ctx), 2, ctx).snapshot;
    expect(s.canvas.numFrames, 3);
    final r = setNumFrames(s, 2, ctx);
    expect(r.snapshot.canvas.perPage, 0);
    expect(r.notices, [const Notice(NoticeKind.perPageBackToAuto)]);
  });

  test(
    '«A cavallo» aggiunge pagine e le toglie tornando a un\'altra disposizione',
    () {
      final ctx = _ctx();
      final s = _tela(1, 8, ctx);
      final a = chooseLayout(s, 'scrl_seam', ctx, seed: 3);
      expect(a.snapshot.canvas.numFrames, 2);
      expect(a.notices, [
        const Notice(NoticeKind.seamAddedPages, [2]),
      ]);
      final b = chooseLayout(a.snapshot, 'grid', ctx, seed: 4);
      expect(b.snapshot.canvas.numFrames, 1);
    },
  );

  test('formato: ratio_index coerente con le misure', () {
    final ctx = _ctx();
    final s = _tela(1, 3, ctx);
    final q = setAspectRatio(s, 3, ctx).snapshot;
    expect(
      (q.canvas.ratioIndex, q.canvas.frameW, q.canvas.frameH),
      (3, 1080, 1080),
    );
    final p = setAspectRatio(
      setCustomSize(q, 1000, 2000, ctx).snapshot,
      ratioPersonalizzato,
      ctx,
    ).snapshot;
    expect(
      (p.canvas.ratioIndex, p.canvas.frameW, p.canvas.frameH),
      (8, 1000, 2000),
    );
    final c = setCustomSize(p, 900, 100, ctx).snapshot;
    expect((c.canvas.frameW, c.canvas.frameH), (900, 200));
  });

  test('rimescola tiene i posti; scambia due foto', () {
    final ctx = _ctx();
    final s = _tela(1, 4, ctx);
    final r = shufflePhotos(s, ctx, rng: PyRandom(1)).snapshot;
    final posti = {for (final p in s.items) (p.x, p.y, p.w, p.h)};
    expect({for (final p in r.items) (p.x, p.y, p.w, p.h)}, posti);
    expect(r, isNot(s));
    final w = swapPhotos(s, 1, 4, ctx).snapshot;
    final a = s.items.firstWhere((p) => p.uid == 1),
        d = s.items.firstWhere((p) => p.uid == 4);
    expect(w.items.firstWhere((p) => p.uid == 1).x, d.x);
    expect(w.items.firstWhere((p) => p.uid == 4).x, a.x);
  });

  test('foto libera: fuori dalla disposizione, davanti alle altre', () {
    final ctx = _ctx();
    final s = _tela(1, 3, ctx);
    final r = toggleFree(s, [2], ctx).snapshot;
    final libera = r.items.firstWhere((p) => p.uid == 2);
    expect(libera.free, isTrue);
    expect(libera.z, 4.0);
    expect(
      toggleFree(r, [2], ctx).snapshot.items.firstWhere((p) => p.uid == 2).free,
      isFalse,
    );
  });

  test('un video non resta a cavallo di due pagine', () {
    final ctx = _ctx();
    final v = PhotoItem(
      uid: 1,
      path: 'v.mp4',
      isVideo: true,
      x: 900,
      y: 100,
      w: 400,
      h: 300,
    );
    final s = Snapshot(
      canvas: CanvasState(numFrames: 2, layoutSeed: 1),
      items: [v],
    );
    final r = keepVideosInPages(s, ctx);
    expect(r.notices, [const Notice(NoticeKind.videoKeptInPage)]);
    final dopo = r.snapshot.items.single;
    // Nella pagina 2 ne stanno 220 px, nella 1 ne stanno 180: si riduce alla parte nella pagina 2
    expect((dopo.x, dopo.w), (1080.0, 220.0));
    final libero = keepVideosInPages(
      s.copyWith(items: [v.copyWith(free: true)]),
      ctx,
    ).snapshot.items.single;
    expect((libero.x, libero.w), (1080.0, 400.0));
  });
}
