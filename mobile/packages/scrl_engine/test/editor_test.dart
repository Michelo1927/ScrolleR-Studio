import 'dart:math' as math;

import 'package:scrl_engine/scrl_engine.dart';
import 'package:test/test.dart';

EngineContext _ctx() => EngineContext(
  imageSize: (_) => (w: 600, h: 800),
  textSize: (_) => (w: 200.0, h: 100.0),
);

NuovaFoto _foto(int i) =>
    (path: 'f$i.jpg', rel: null, asset: null, video: false);

Snapshot _tela(int pagine, int n, EngineContext ctx) {
  final s = Snapshot(canvas: CanvasState(numFrames: pagine, layoutSeed: 7));
  return mettiFotoSullaTela(s, [
    for (var i = 1; i <= n; i++) _foto(i),
  ], ctx).risultato.snapshot;
}

void main() {
  group('aggiunta foto', () {
    test(
      'mettiFotoSullaTela dispone tutte le foto e sostituisce le vecchie',
      () {
        final ctx = _ctx();
        final s = _tela(2, 6, ctx);
        expect(s.items.length, 6);
        final t = mettiFotoSullaTela(s, [_foto(7), _foto(8)], ctx);
        expect(t.uids.length, 2);
        expect(t.risultato.snapshot.items.map((p) => p.path), [
          'f7.jpg',
          'f8.jpg',
        ]);
      },
    );

    test(
      'aggiungiFoto in una pagina mette le nuove in fondo a quella pagina',
      () {
        final ctx = _ctx();
        final s = _tela(3, 6, ctx);
        final a = aggiungiFoto(s, [_foto(7)], ctx, pagina: 2);
        final nuova = a.risultato.snapshot.items.firstWhere(
          (p) => p.uid == a.uids.single,
        );
        expect(pageOf(a.risultato.snapshot, nuova, ctx), 2);
        expect(a.risultato.snapshot.items.length, 7);
      },
    );

    test('aggiungiFoto su una pagina bloccata è rifiutata', () {
      final ctx = _ctx();
      final s = _tela(2, 4, ctx);
      final bloccata = setPageLock(s, 1, true, ctx).snapshot;
      final a = aggiungiFoto(bloccata, [_foto(9)], ctx, pagina: 1);
      expect(a.risultato.applied, isFalse);
      expect(a.risultato.snapshot, bloccata);
      expect(a.risultato.notices.single.kind, NoticeKind.pageLocked);
    });

    test('foto libere: al centro della pagina, fuori dalla disposizione', () {
      final ctx = _ctx();
      final s = _tela(2, 2, ctx);
      final a = aggiungiFoto(s, [_foto(3)], ctx, pagina: 1, libere: true);
      final p = a.risultato.snapshot.items.firstWhere(
        (p) => p.uid == a.uids.single,
      );
      expect(p.free, isTrue);
      expect(pageOf(a.risultato.snapshot, p, ctx), 1);
      expect(p.h, closeTo(1080 * 0.4, 1e-6));
      expect(p.w, closeTo(1080 * 0.4 * 0.75, 1e-6));
    });
  });

  group('elementi', () {
    test('spostaElementi non muove le foto con «Blocca posizione»', () {
      final ctx = _ctx();
      var s = _tela(1, 2, ctx);
      final b = s.items[1].copyWith(locked: true);
      s = s.copyWith(items: [s.items[0], b]);
      final t = spostaElementi(s, s.items.map(rifDi), 10, 20);
      expect(t.items[0].x, s.items[0].x + 10);
      expect(t.items[1].x, s.items[1].x);
    });

    test('eliminaElementi e svuotaTela', () {
      final ctx = _ctx();
      final s = _tela(1, 3, ctx);
      final t = eliminaElementi(s, [rifDi(s.items[0])]);
      expect(t.items.length, 2);
      expect(svuotaTela(s).items, isEmpty);
    });

    test('duplicaElementi: copia spostata di 30, davanti, selezionabile', () {
      final ctx = _ctx();
      final s = _tela(1, 2, ctx);
      final d = duplicaElementi(s, [rifDi(s.items[0])], ctx);
      expect(d.snapshot.items.length, 3);
      final copia = elementoDi(d.snapshot, d.copie.single)! as PhotoItem;
      expect(copia.x, s.items[0].x + 30);
      expect(copia.z, greaterThan(s.items.map((p) => p.z).reduce(math.max)));
      expect(copia.uid, isNot(s.items[0].uid));
    });

    test('conGruppo seleziona tutto il gruppo', () {
      final ctx = _ctx();
      var s = _tela(1, 3, ctx);
      s = s.copyWith(
        items: [
          s.items[0].copyWith(group: 4),
          s.items[1].copyWith(group: 4),
          s.items[2],
        ],
      );
      expect(conGruppo(s, s.items[0]).length, 2);
      expect(conGruppo(s, s.items[2]).length, 1);
    });
  });

  group('aggancio', () {
    test('si aggancia al centro della pagina entro la distanza', () {
      final s = Snapshot(
        canvas: CanvasState(numFrames: 2, layoutSeed: 1),
        items: [PhotoItem(uid: 1, path: 'a', x: 0, y: 0, w: 400, h: 400)],
      );
      // Centro del riquadro a 540 + 3 = vicino al centro della pagina 0 (540)
      const r = Rect(343, 100, 400, 400);
      final a = calcolaAggancio(s, r, [rifDi(s.items[0])], 8);
      expect(a.dx, closeTo(-3, 1e-9));
      expect(a.lineeX, [540.0]);
      expect(a.dy, 0);
    });

    test('fuori dalla distanza non aggancia', () {
      final s = Snapshot(
        canvas: CanvasState(numFrames: 1, layoutSeed: 1),
        items: [PhotoItem(uid: 1, path: 'a', w: 100, h: 100)],
      );
      final a = calcolaAggancio(s, const Rect(300, 300, 100, 100), [
        rifDi(s.items[0]),
      ], 8);
      expect(a.attivo, isFalse);
    });

    test('gli altri elementi fanno da riferimento, quelli selezionati no', () {
      final s = Snapshot(
        canvas: CanvasState(numFrames: 1, layoutSeed: 1),
        items: [
          PhotoItem(uid: 1, path: 'a', x: 100, y: 100, w: 200, h: 200),
          PhotoItem(uid: 2, path: 'b', x: 500, y: 700, w: 100, h: 100),
        ],
      );
      // Il lato sinistro della foto 2 a 103 si aggancia al lato sinistro della foto 1 (100)
      const r = Rect(103, 700, 100, 100);
      final a = calcolaAggancio(s, r, [rifDi(s.items[1])], 8);
      expect(a.dx, closeTo(-3, 1e-9));
      final senza = calcolaAggancio(s, r, [
        rifDi(s.items[0]),
        rifDi(s.items[1]),
      ], 8);
      expect(senza.lineeX, isEmpty);
    });
  });

  group('ridimensiona e ruota', () {
    final base = PhotoItem(uid: 1, path: 'a', x: 100, y: 200, w: 400, h: 300);

    test('angolo: proporzioni mantenute, angolo opposto fermo', () {
      final p = ridimensionaFoto(base, Maniglia.br, 700, 500);
      // Il vertice in alto a sinistra resta in (100, 200)
      expect(p.x, closeTo(100, 1e-9));
      expect(p.y, closeTo(200, 1e-9));
      expect(p.w / p.h, closeTo(400 / 300, 1e-9));
      expect(p.w, closeTo(600, 1e-9));
    });

    test('angolo in alto a sinistra: ferma il vertice in basso a destra', () {
      final p = ridimensionaFoto(base, Maniglia.tl, 300, 350);
      expect(p.x + p.w, closeTo(500, 1e-9));
      expect(p.y + p.h, closeTo(500, 1e-9));
      expect(p.w, closeTo(200, 1e-9));
    });

    test('lato: cambia solo una misura e non deforma la foto', () {
      final p = ridimensionaFoto(base, Maniglia.r, 800, 999);
      expect(p.w, closeTo(700, 1e-9));
      expect(p.h, 300);
      expect(p.stretch, base.stretch);
      expect(p.x, closeTo(100, 1e-9));
    });

    test('mai sotto il minimo', () {
      final p = ridimensionaFoto(base, Maniglia.br, 101, 201);
      expect(p.w, greaterThanOrEqualTo(PhotoItem.minCell));
      expect(p.h, greaterThanOrEqualTo(PhotoItem.minCell));
    });

    test('foto ruotata: l\'ancora resta ferma in scena', () {
      final r = base.copyWith(rotation: 30);
      final ancora = localeInScena(r, 0, 0);
      // Punto sul bordo opposto, già ruotato
      final fuori = localeInScena(r, 600, 450);
      final p = ridimensionaFoto(r, Maniglia.br, fuori.$1, fuori.$2);
      final dopo = localeInScena(p, 0, 0);
      expect(dopo.$1, closeTo(ancora.$1, 1e-6));
      expect(dopo.$2, closeTo(ancora.$2, 1e-6));
      expect(p.w, closeTo(600, 1e-6));
    });

    test('rotazione: scatti ogni 15° entro 3°', () {
      expect(agganciaRotazione(2).gradi, 0);
      expect(agganciaRotazione(2).agganciata, isTrue);
      expect(agganciaRotazione(88).gradi, 90);
      expect(agganciaRotazione(-44).gradi, -45);
      expect(agganciaRotazione(8).agganciata, isFalse);
      expect(agganciaRotazione(8).gradi, 8);
      expect(agganciaRotazione(359).gradi, 0);
    });

    test('pizzico: scala attorno al centro e somma la rotazione', () {
      final t = trasformaFoto(base, scala: 2, gradi: 8);
      expect(t.foto.w, 800);
      expect(t.foto.x + t.foto.w / 2, closeTo(300, 1e-9));
      expect(t.foto.y + t.foto.h / 2, closeTo(350, 1e-9));
      expect(t.foto.rotation, 8);
      expect(trasformaFoto(base, scala: 0.01, gradi: 0).foto.h, 40);
    });
  });
}
