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
    expect(fotogrammiPaginaVideo([90]), 1800);
    expect(fotogrammiPaginaVideo([0.1]), 3);
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
