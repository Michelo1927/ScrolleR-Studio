// Strumenti Video (Fase 8): valori attesi presi dal desktop (`format_time`, `VideoItem.set_trim`,
// `clip_end`, `clip_length`), calcolati con l'app Python.
import 'package:scrl_engine/scrl_engine.dart';
import 'package:test/test.dart';

void main() {
  group('formatoTempo come format_time', () {
    final attesi = <double, String>{
      0.0: '0:00',
      0.05: '0:00,1',
      4.5: '0:04,5',
      4.54: '0:04,5',
      7.0: '0:07',
      9.96: '0:10',
      9.94: '0:09,9',
      10.4: '0:10',
      59.6: '0:59',
      65.0: '1:05',
      125.3: '2:05',
      -1.0: '0:00',
      0.1: '0:00,1',
      3.25: '0:03,2',
    };
    attesi.forEach((s, testo) {
      test('$s → $testo', () => expect(formatoTempo(s), testo));
    });
  });

  group('conTaglio come set_trim', () {
    // (durata, inizio, fine) → (trim_start, trim_end, clip_end, clip_length)
    const casi = <(double, double, double?, double, double?, double, double)>[
      (10, 0, null, 0, null, 10, 10),
      (10, 2, 5, 2, 5, 5, 3),
      (10, 9.95, null, 9.9, null, 10, 0.1),
      (10, 3, 9.96, 3, null, 10, 7),
      (10, 4, 3, 4, 4.1, 4.1, 0.1),
      (10, -1, 2, 0, 2, 2, 2),
      (0, 5, 4, 5, 5.1, 5.1, 0.1),
      (0, 5, null, 5, null, 5.1, 0.1),
      (10, 12, null, 9.9, null, 10, 0.1),
      (8.5, 1, 8.44, 1, 8.44, 8.44, 7.44),
    ];
    for (final c in casi) {
      test('$c', () {
        final v = conTaglio(
          PhotoItem(uid: 1, path: 'v.mp4', isVideo: true),
          c.$2,
          c.$3,
          c.$1,
        );
        expect(v.trimStart, closeTo(c.$4, 1e-9));
        if (c.$5 == null) {
          expect(v.trimEnd, isNull);
        } else {
          expect(v.trimEnd, closeTo(c.$5!, 1e-9));
        }
        expect(clipEnd(v, c.$1), closeTo(c.$6, 1e-9));
        expect(clipLength(v, c.$1), closeTo(c.$7, 1e-9));
      });
    }

    test('Inizio oltre la Fine: la fine segue', () {
      var v = conTaglio(
        PhotoItem(uid: 1, path: 'v.mp4', isVideo: true),
        1,
        3,
        10,
      );
      v = conInizio(v, 5, 10);
      expect((v.trimStart, v.trimEnd), (5.0, 5.1));
      v = conFine(v, 2, 10);
      expect(v.trimStart, 5.0);
      expect(v.trimEnd, closeTo(5.1, 1e-9));
    });
  });

  test('Copertina dentro la durata, Audio = muted negato', () {
    final v = PhotoItem(uid: 1, path: 'v.mp4', isVideo: true);
    expect(conCopertina(v, 12, 10).poster, 10.0);
    expect(conCopertina(v, -1, 10).poster, 0.0);
    expect(conCopertina(v, 12, 0).poster, 12.0);
    expect(conAudio(v, false).muted, isTrue);
    expect(conAudio(v.copyWith(muted: true), true).muted, isFalse);
  });

  test('le modifiche del video sono passi di cronologia con il loro nome', () {
    final v = PhotoItem(uid: 1, path: 'v.mp4', isVideo: true, w: 300, h: 300);
    final s = Snapshot(canvas: CanvasState(layoutSeed: 1), items: [v]);
    String nome(PhotoItem p) =>
        describeChange(s, s.copyWith(items: [p])).kind.name;
    expect(nome(conTaglio(v, 1, 4, 10)), 'videoTrim');
    expect(nome(conCopertina(v, 2, 10)), 'videoPoster');
    expect(nome(conAudio(v, false)), 'videoAudio');
  });

  test('videoDellaPagina: tolleranza di mezza unità sui bordi', () {
    final s = Snapshot(
      canvas: CanvasState(numFrames: 3, layoutSeed: 1),
      items: [
        PhotoItem(uid: 1, path: 'a.mp4', isVideo: true, x: 0, w: 1080, h: 500),
        PhotoItem(uid: 2, path: 'b.jpg', x: 1100, w: 200, h: 200),
        PhotoItem(
          uid: 3,
          path: 'c.mp4',
          isVideo: true,
          x: 1080.3,
          w: 500,
          h: 500,
        ),
      ],
    );
    expect([for (final v in videoDellaPagina(s, 0)) v.uid], [1]);
    expect([for (final v in videoDellaPagina(s, 1)) v.uid], [3]);
    expect(videoDellaPagina(s, 2), isEmpty);
  });

  test('fotogrammiPaginaVideo come _video_page_frames', () {
    expect(fotogrammiPaginaVideo([]), 1);
    expect(fotogrammiPaginaVideo([2.5, 7.44]), 223);
    // Carosello: al massimo 60 s; reel: al massimo 5 minuti
    expect(fotogrammiPaginaVideo([90]), 1800);
    expect(fotogrammiPaginaVideo([90], tipoProgetto: 'reel'), 2700);
    expect(fotogrammiPaginaVideo([400], tipoProgetto: 'reel'), 9000);
    expect(fotogrammiPaginaVideo([0.1]), 3);
  });

  group('tipo di progetto come toggle_project_type e limit_clip', () {
    final ctx = EngineContext(
      imageSize: (_) => (w: 600, h: 800),
      textSize: (_) => (w: 200.0, h: 100.0),
    );
    PhotoItem video(double inizio, double? fine) => conTaglio(
      PhotoItem(uid: 1, path: 'v.mp4', isVideo: true),
      inizio,
      fine,
      400,
    );

    test("conLimiteTaglio tiene l'inizio o la fine", () {
      final v = conLimiteTaglio(video(100, null), 60, 400);
      expect([v.trimStart, v.trimEnd], [100.0, 160.0]);
      final w = conLimiteTaglio(video(0, 300), 60, 400, tieniFine: true);
      expect([w.trimStart, w.trimEnd], [240.0, 300.0]);
      final corto = video(10, 40);
      expect(conLimiteTaglio(corto, 60, 400), same(corto));
    });

    test("cursori: oltre il massimo l'altro estremo segue", () {
      final v = conFine(video(0, 30), 300, 400, massimo: 60);
      expect([v.trimStart, v.trimEnd], [240.0, 300.0]);
      final w = conInizio(video(0, null), 100, 400, massimo: 60);
      expect([w.trimStart, w.trimEnd], [100.0, 160.0]);
    });

    test('il tipo si legge e si scrive; i progetti vecchi sono caroselli', () {
      expect(CanvasState.fromJson(const {}).projectType, 'carousel');
      expect(
        CanvasState.fromJson(const {'project_type': 'reel'}).projectType,
        'reel',
      );
      expect(
        CanvasState.fromJson(const {'project_type': 'boh'}).projectType,
        'carousel',
      );
      expect(CanvasState(projectType: 'reel').toJson()['project_type'], 'reel');
    });

    test('reel: una sola pagina', () {
      final s = Snapshot(
        canvas: CanvasState(layoutSeed: 1, projectType: 'reel'),
      );
      final r = insertPageAt(s, 1, ctx);
      expect(r.applied, isFalse);
      expect(r.notices.single.kind, NoticeKind.reelSinglePage);
      expect(setNumFrames(s, 3, ctx).applied, isFalse);
    });

    test('in reel solo con una pagina; in carosello il primo minuto', () {
      final due = Snapshot(canvas: CanvasState(layoutSeed: 1, numFrames: 2));
      final no = convertiTipoProgetto(due, const {}, ctx);
      expect(no.applied, isFalse);
      expect(no.notices.single.kind, NoticeKind.reelNeedsOnePage);

      final una = Snapshot(
        canvas: CanvasState(layoutSeed: 1),
        items: [video(100, null)],
      );
      final reel = convertiTipoProgetto(una, const {'v.mp4': 400}, ctx);
      expect(reel.snapshot.canvas.projectType, 'reel');
      expect(reel.snapshot.items.single.trimEnd, isNull);

      final car = convertiTipoProgetto(reel.snapshot, const {
        'v.mp4': 400,
      }, ctx);
      expect(car.snapshot.canvas.projectType, 'carousel');
      expect(car.snapshot.items.single.trimStart, 100.0);
      expect(car.snapshot.items.single.trimEnd, 160.0);
      expect(car.notices.single.kind, NoticeKind.videosTrimmedToCarousel);
      expect(
        describeChange(una, reel.snapshot).kind,
        ChangeKind.convertedToReel,
      );
    });
  });

  test('zonaSicuraReel come reel_safe_rect', () {
    // Valori del desktop: reel_safe_rect(1080, 1920), (720, 1280), (1080, 1919)
    final attesi = <(double, double), List<double>>{
      (1080, 1920): [64.8, 268.8, 950.4, 979.2],
      (720, 1280): [43.2, 179.2, 633.6, 652.8],
      (1080, 1919): [64.8, 268.66, 950.4, 978.69],
    };
    attesi.forEach((misura, r) {
      final z = zonaSicuraReel(misura.$1, misura.$2)!;
      expect([z.x, z.y, z.w, z.h], [for (final v in r) closeTo(v, 1e-9)]);
    });
    expect(zonaSicuraReel(1080, 1350), isNull);
    expect(zonaSicuraReel(1080, 0), isNull);
  });

  test('tempoInRiproduzione ripete il taglio', () {
    final v = conTaglio(
      PhotoItem(uid: 1, path: 'v.mp4', isVideo: true),
      2,
      5,
      10,
    );
    expect(tempoInRiproduzione(v, 10, 0), 2.0);
    expect(tempoInRiproduzione(v, 10, 4), closeTo(3.0, 1e-9));
  });
}
