import 'package:scrl_engine/scrl_engine.dart';
import 'package:test/test.dart';

EngineContext _ctx() => EngineContext(imageSize: (_) => (w: 800, h: 600));

Snapshot _base() => Snapshot(
  canvas: CanvasState(layoutSeed: 5),
  items: [
    PhotoItem(uid: 1, path: 'a.jpg', layoutIndex: 1),
    PhotoItem(uid: 2, path: 'b.jpg', layoutIndex: 2),
  ],
);

void main() {
  test('passi, annulla, ripeti; un passo nuovo toglie quelli «avanti»', () {
    final ctx = _ctx();
    var h = History.reset(
      _base(),
      ctx,
      startLabel: const ChangeLabel(ChangeKind.start, text: 'Progetto aperto'),
    ).history;
    expect(h.labels.single.text, 'Progetto aperto');
    expect(h.canUndo, isFalse);

    final s1 = applyAutoLayout(h.current, 'grid', ctx).snapshot;
    h = h.commit(s1, ctx).history;
    expect(h.labels.last.kind, ChangeKind.layoutUpdated);

    final uguale = h.commit(s1, ctx);
    expect(uguale.added, isFalse);
    expect(uguale.history.states.length, 2);

    final s2 = s1.copyWith(
      items: [
        s1.items[0].copyWith(x: s1.items[0].x + 10),
        s1.items[1],
      ],
    );
    h = h.commit(s2, ctx).history;
    expect(
      h.labels.last,
      const ChangeLabel(ChangeKind.moved, element: ElementKind.photo),
    );

    h = h.undo();
    expect(h.current, s1);
    expect(h.canRedo, isTrue);
    h = h.redo();
    expect(h.current, s2);
    h = h.goTo(0);
    final s3 = h.current.copyWith(canvas: h.current.canvas.copyWith(gap: 40));
    h = h.commit(s3, ctx).history;
    expect(h.states.length, 2);
    expect(h.labels.last.kind, ChangeKind.spacing);
    expect(h.canRedo, isFalse);
  });

  test('al massimo 100 passi', () {
    final ctx = _ctx();
    var h = History.reset(_base(), ctx).history;
    for (var i = 1; i <= 150; i++) {
      h = h
          .commit(
            h.current.copyWith(
              canvas: h.current.canvas.copyWith(
                gap: i % 80 + 1,
                margin: i % 120,
              ),
            ),
            ctx,
          )
          .history;
    }
    expect(h.states.length, cronologiaLimite);
    expect(h.labels.length, cronologiaLimite);
    expect(h.index, cronologiaLimite - 1);
  });

  test('stato salvato e modifiche non salvate', () {
    final ctx = _ctx();
    var h = History.reset(_base(), ctx).history;
    final salvato = h.current;
    expect(h.isDirty(salvato), isFalse);
    h = h
        .commit(
          salvato.copyWith(
            canvas: salvato.canvas.copyWith(bgColor: 0xFF000000),
          ),
          ctx,
        )
        .history;
    expect(h.isDirty(salvato), isTrue);
    expect(h.labels.last.kind, ChangeKind.background);
  });

  test('un video a cavallo rientra prima del passo', () {
    final ctx = _ctx();
    final s = Snapshot(
      canvas: CanvasState(numFrames: 2, layoutSeed: 1),
      items: [
        PhotoItem(
          uid: 1,
          path: 'v.mp4',
          isVideo: true,
          x: 1000,
          w: 400,
          h: 300,
          free: true,
        ),
      ],
    );
    final c = History.reset(s, ctx);
    expect(c.notices.single.kind, NoticeKind.videoKeptInPage);
    expect(c.history.current.items.single.x, 1080);
  });

  group('nomi dei passaggi (_describe_change)', () {
    final a = _base();
    ChangeLabel d(Snapshot b) => describeChange(a, b);

    test('pagine', () {
      expect(
        d(a.copyWith(canvas: a.canvas.copyWith(numFrames: 2))).kind,
        ChangeKind.pageAdded,
      );
      expect(
        d(a.copyWith(canvas: a.canvas.copyWith(numFrames: 3))),
        const ChangeLabel(ChangeKind.pagesCount, from: 1, to: 3),
      );
    });

    test('aggiunte ed eliminazioni', () {
      final t = TextItem(uid: 1);
      expect(
        d(a.copyWith(texts: [t])),
        const ChangeLabel(
          ChangeKind.added,
          count: 1,
          element: ElementKind.text,
        ),
      );
      expect(
        d(a.copyWith(items: [], texts: [t])).kind,
        ChangeKind.elementsChanged,
      );
      expect(
        d(a.copyWith(items: [])),
        const ChangeLabel(
          ChangeKind.removed,
          count: 2,
          element: ElementKind.photo,
        ),
      );
      expect(
        d(a.copyWith(items: [PhotoItem(uid: 9, path: 'c.jpg')])).kind,
        ChangeKind.photosReplaced,
      );
      expect(
        d(a.copyWith(texts: [t], shapes: [ShapeItem(uid: 1)])),
        const ChangeLabel(ChangeKind.added, count: 2),
      );
    });

    test('tela', () {
      expect(
        d(a.copyWith(canvas: a.canvas.copyWith(layoutMode: 'mosaic'))),
        const ChangeLabel(ChangeKind.layout, layoutMode: 'mosaic'),
      );
      expect(
        d(a.copyWith(canvas: a.canvas.copyWith(layoutSeed: 6))).kind,
        ChangeKind.photosShuffled,
      );
      expect(
        d(a.copyWith(canvas: a.canvas.copyWith(swipeHint: true))).kind,
        ChangeKind.swipeHint,
      );
      expect(d(a).kind, ChangeKind.modified);
    });

    test('elementi', () {
      PhotoItem f(int i) => a.items[i];
      Snapshot con(PhotoItem p) => a.copyWith(items: [p, f(1)]);
      expect(d(con(f(0).copyWith(w: 300))).kind, ChangeKind.resized);
      expect(d(con(f(0).copyWith(rotation: 5))).kind, ChangeKind.rotated);
      expect(d(con(f(0).copyWith(z: 9))).kind, ChangeKind.levelChanged);
      expect(d(con(f(0).copyWith(locked: true))).kind, ChangeKind.positionLock);
      expect(
        d(con(f(0).copyWith(adjust: {'brightness': 5}))).kind,
        ChangeKind.photoColors,
      );
      expect(d(con(f(0).copyWith(innerZoom: 2))).kind, ChangeKind.photoFraming);
      expect(d(con(f(0).copyWith(free: true))).kind, ChangeKind.photoFree);
      expect(
        d(con(f(0).copyWith(borderWidth: 4))),
        const ChangeLabel(ChangeKind.style, element: ElementKind.photo),
      );
      expect(
        d(a.copyWith(items: [f(0).copyWith(group: 1), f(1).copyWith(group: 1)]))
            .kind,
        ChangeKind.grouped,
      );
      expect(
        d(a.copyWith(items: [f(0).copyWith(x: 5), f(1).copyWith(y: 5)])),
        const ChangeLabel(ChangeKind.movedMany, count: 2),
      );
      expect(
        d(
          a.copyWith(
            items: [
              f(0).copyWith(layoutIndex: 2),
              f(1).copyWith(layoutIndex: 1),
            ],
          ),
        ).kind,
        ChangeKind.photoOrder,
      );
    });
  });
}
