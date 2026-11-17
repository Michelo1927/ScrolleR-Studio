import 'dart:math' as math;

import 'package:scrl_engine/scrl_engine.dart';
import 'package:test/test.dart';

/// Un testo misura 10 unità per carattere (più il margine) e 100 di altezza per riga: abbastanza per vedere che
/// il centro resta fermo quando il testo cambia.
EngineContext _ctx() => EngineContext(
  textSize: (t) {
    final righe = t.text.isEmpty ? const [' '] : t.text.split('\n');
    final lunga = righe.map((r) => r.length).fold<int>(0, math.max);
    return (
      w: lunga * t.size / 2.0 + 2 * t.pad,
      h: righe.length * t.size * 1.2 + 2 * t.pad,
    );
  },
);

Snapshot _tela({int pagine = 3, int bg = 0xFFFFFFFF, String modo = 'solid'}) =>
    Snapshot(
      canvas: CanvasState(
        numFrames: pagine,
        frameW: 1000,
        frameH: 1400,
        bgColor: bg,
        bgMode: modo,
      ),
    );

void main() {
  group('selettore colore', () {
    test('HSL e ARGB sono l\'uno l\'inverso dell\'altro sui 12 campioni', () {
      const campioni = [
        0xFFFFFFFF,
        0xFF000000,
        0xFF8E8E93,
        0xFFFF3B30,
        0xFFFF9500,
        0xFFFFCC00,
        0xFF34C759,
        0xFF00C7BE,
        0xFF007AFF,
        0xFF5856D6,
        0xFFAF52DE,
        0xFFFF2D55,
      ];
      for (final c in campioni) {
        final h = argbToHsl(c);
        final r = hslToArgb(h.h, h.s, h.l);
        for (final sh in [16, 8, 0]) {
          expect(
            ((r >> sh) & 0xFF) - ((c >> sh) & 0xFF),
            inInclusiveRange(-1, 1),
            reason: '${c.toRadixString(16)} canale a $sh bit',
          );
        }
      }
    });

    test('valori noti: rosso, grigio e bianco', () {
      expect(argbToHsl(0xFFFF0000), const Hsl(0, 1, 0.5));
      final g = argbToHsl(0xFF808080);
      expect((g.h, g.s), (0.0, 0.0));
      expect(g.l, closeTo(0.5, 0.01));
      expect(argbToHsl(0xFFFFFFFF).l, 1.0);
      expect(hslToArgb(120, 1, 0.5), 0xFF00FF00);
      expect(hslToArgb(240, 1, 0.5, alfa: 0x80), 0x800000FF);
    });

    test('l\'esadecimale si legge in tutte le forme e si scrive maiuscolo', () {
      expect(parseEsadecimale('#ff3b30'), 0xFFFF3B30);
      expect(parseEsadecimale(' FF3B30 '), 0xFFFF3B30);
      expect(parseEsadecimale('f00'), 0xFFFF0000);
      expect(parseEsadecimale('#abc'), 0xFFAABBCC);
      for (final x in [
        '',
        '#',
        'ff',
        'ff3b3',
        'ff3b300',
        'gg0000',
        '#12 345',
      ]) {
        expect(parseEsadecimale(x), isNull, reason: x);
      }
      expect(formatEsadecimale(0x80FF3B30), 'FF3B30');
      expect(formatEsadecimale(0xFF00000A), '00000A');
    });

    test('la trasparenza è una percentuale', () {
      expect(percentualeAlfa(0xFFFF0000), 100);
      expect(percentualeAlfa(0x00FF0000), 0);
      expect(percentualeAlfa(0x96000000), 59);
      expect(conPercentualeAlfa(0xFFFF0000, 50), 0x80FF0000);
      expect(conPercentualeAlfa(0xFFFF0000, 0), 0x00FF0000);
      expect(conPercentualeAlfa(0x10123456, 100), 0xFF123456);
      expect(alfaDi(0x96000000), 0x96);
      expect(conAlfa(0xFF123456, 0x40), 0x40123456);
    });

    test('is_light: soglia 150 sulla luminanza', () {
      expect(eChiaro(0xFFFFFFFF), isTrue);
      expect(eChiaro(0xFF000000), isFalse);
      expect(
        eChiaro(0xFF8E8E93),
        isFalse,
      ); // 0,299·142+0,587·142+0,114·147 ≈ 142,5
      expect(eChiaro(0xFFFFCC00), isTrue);
    });

    test('i colori del progetto: usati, senza doppioni, i più frequenti prima', () {
      final ctx = _ctx();
      var s = _tela(bg: 0xFF112233);
      s = aggiungiTesto(s, ctx, pagina: 0, carattere: 'Inter').snapshot;
      s = aggiungiTesto(s, ctx, pagina: 1, carattere: 'Inter').snapshot;
      // Sfondo scuro: due testi bianchi. Il contorno e l'etichetta spenti non contano.
      var colori = coloriDelProgetto(s);
      expect(colori, [0xFFFFFFFF, 0xFF112233]);
      // Una forma rossa e una linea verde con una trasparente senza riempimento
      s = aggiungiForma(s, ctx, kind: 'rect', pagina: 0).snapshot;
      s = aggiungiForma(s, ctx, kind: 'line', pagina: 0).snapshot;
      colori = coloriDelProgetto(s);
      // Rosso: riempimento del rettangolo e tratto della linea. Pari merito col bianco: vale chi è venuto prima.
      expect(colori, [0xFFFFFFFF, 0xFFFF3B30, 0xFF112233]);
      // Un contorno acceso e un'etichetta accesa entrano
      final uid = s.texts.first.uid;
      s = modificaTesti(s, [uid], (t) => conColoreContorno(t, 0xFF00FF00, ctx));
      s = modificaTesti(s, [
        uid,
      ], (t) => conColoreEtichetta(t, 0x80FF00FF, ctx));
      colori = coloriDelProgetto(s);
      expect(colori, containsAll([0xFF00FF00, 0x80FF00FF]));
      // I campioni rapidi si possono escludere e il massimo vale
      expect(
        coloriDelProgetto(s, escludi: {0xFFFFFFFF}),
        isNot(contains(0xFFFFFFFF)),
      );
      expect(coloriDelProgetto(s, massimo: 2), hasLength(2));
      // Completamente trasparente: mai
      s = modificaForme(s, [s.shapes.first.uid], (f) => f.copyWith(fill: 0));
      expect(coloriDelProgetto(s), isNot(contains(0)));
    });

    test('lo sfondo sfocato non è un colore; il sfumato ne ha due', () {
      expect(coloriDelProgetto(_tela(bg: 0xFF123456, modo: 'blur')), isEmpty);
      expect(coloriDelProgetto(_tela(bg: 0xFF123456, modo: 'gradient')), [
        0xFF123456,
        0xFF2680EB,
      ]);
    });
  });

  group('testo', () {
    test('un testo nuovo: contrasto con lo sfondo, 7% della larghezza, centro della pagina', () {
      final ctx = _ctx();
      final chiaro = aggiungiTesto(_tela(), ctx, pagina: 1, carattere: 'Inter');
      final t = chiaro.snapshot.texts.single;
      expect(t.text, 'Scrivi qui');
      expect(t.font, 'Inter');
      expect(t.size, 70); // round(1000 · 0,07)
      expect((t.color, t.shadow), (0xFF1A1A1A, false));
      expect((t.boxColor, t.outlineColor), (0xD7FFFFFF, 0xFFFFFFFF));
      expect(chiaro.ref, (tipo: ElementKind.text, uid: t.uid));
      // Il centro del riquadro è il centro della pagina 2
      final m = ctx.textSize(t);
      expect(t.x + m.w / 2, closeTo(1500, 1e-9));
      expect(t.y + m.h / 2, closeTo(700, 1e-9));

      final scuro = aggiungiTesto(
        _tela(bg: 0xFF202020),
        ctx,
        pagina: 0,
        carattere: 'Inter',
      ).snapshot.texts.single;
      expect((scuro.color, scuro.shadow), (0xFFFFFFFF, true));
      expect((scuro.boxColor, scuro.outlineColor), (0x96000000, 0xFF000000));
      // Sfondo sfocato: conta come scuro
      final sfocato = aggiungiTesto(
        _tela(bg: 0xFFFFFFFF, modo: 'blur'),
        ctx,
        pagina: 0,
        carattere: 'Inter',
      ).snapshot.texts.single;
      expect(sfocato.color, 0xFFFFFFFF);
    });

    test('davanti a tutto e con uid nuovi; la pagina fuori misura si riporta dentro', () {
      final ctx = _ctx();
      var s = _tela(pagine: 2);
      final a = aggiungiTesto(s, ctx, pagina: 0, carattere: 'Inter');
      s = a.snapshot;
      final b = aggiungiTesto(s, ctx, pagina: 9, carattere: 'Inter');
      expect(b.ref.uid, isNot(a.ref.uid));
      final due = b.snapshot.texts;
      expect(due[1].z, greaterThan(due[0].z));
      expect(due[1].x, greaterThan(1000)); // Pagina 9 → l'ultima, la seconda
    });

    test('ogni modifica tiene fermo il centro del testo', () {
      final ctx = _ctx();
      final t0 = aggiungiTesto(
        _tela(),
        ctx,
        pagina: 0,
        carattere: 'Inter',
      ).snapshot.texts.single;
      ({double x, double y}) centro(TextItem t) {
        final m = ctx.textSize(t);
        return (x: t.x + m.w / 2, y: t.y + m.h / 2);
      }

      final c0 = centro(t0);
      for (final t in [
        conScritto(t0, 'Una frase molto più lunga\ne su due righe', ctx),
        conDimensione(t0, 300, ctx),
        conInterlinea(t0, 200, ctx),
        conSpaziatura(t0, 30, ctx),
        conContorno(t0, 20, ctx),
        conEtichetta(t0, true, ctx),
        conCarattere(t0, 'Lora', ctx),
        conGrassetto(t0, false, ctx),
      ]) {
        final c = centro(t);
        expect(c.x, closeTo(c0.x, 1e-9));
        expect(c.y, closeTo(c0.y, 1e-9));
      }
    });

    test('limiti dei cursori', () {
      final ctx = _ctx();
      final t = aggiungiTesto(
        _tela(),
        ctx,
        pagina: 0,
        carattere: 'Inter',
      ).snapshot.texts.single;
      expect(conDimensione(t, 1, ctx).size, 12);
      expect(conDimensione(t, 9999, ctx).size, 400);
      expect(conInterlinea(t, 0, ctx).lineHeight, 60);
      expect(conInterlinea(t, 999, ctx).lineHeight, 250);
      expect(conSpaziatura(t, -50, ctx).letterSpacing, -10);
      expect(conSpaziatura(t, 500, ctx).letterSpacing, 60);
      expect(conContorno(t, -3, ctx).outline, 0);
      expect(conContorno(t, 99, ctx).outline, 40);
      expect(conOpacitaTesto(t, 0).opacity, 5);
      expect(conOpacitaTesto(t, 300).opacity, 100);
      expect(conRotazioneTesto(t, 270).rotation, 180);
      expect(conAllineamento(t, 'right').align, 'right');
      expect(conAllineamento(t, 'giustificato').align, 'center');
    });

    test('scegliere il colore del contorno lo mostra; quello dell\'etichetta la accende', () {
      final ctx = _ctx();
      final t = aggiungiTesto(
        _tela(),
        ctx,
        pagina: 0,
        carattere: 'Inter',
      ).snapshot.texts.single;
      expect(t.outline, 0);
      final c = conColoreContorno(t, 0xFFFF0000, ctx);
      expect(c.outlineColor, 0xFFFF0000);
      expect(
        c.outline,
        4,
      ); // max(2, round(70 · 0,05)) = 4 (3,5 arrotondato come Python)
      // Con un contorno già acceso lo spessore non si tocca
      expect(
        conColoreContorno(conContorno(t, 9, ctx), 0xFF00FF00, ctx).outline,
        9,
      );
      expect(t.box, isFalse);
      final e = conColoreEtichetta(t, 0x4000FF00, ctx);
      expect((e.box, e.boxColor), (true, 0x4000FF00));
    });

    test('un testo cambia il carattere senza perdere il nome: il nome è quello scelto, anche se sconosciuto', () {
      final ctx = _ctx();
      final t = aggiungiTesto(
        _tela(),
        ctx,
        pagina: 0,
        carattere: 'Inter',
      ).snapshot.texts.single;
      expect(
        conCarattere(t, 'Segoe UI Variable Display', ctx).font,
        'Segoe UI Variable Display',
      );
    });

    test(
      'pizzico: dimensione e rotazione attorno al centro, con gli scatti',
      () {
        final ctx = _ctx();
        final t = aggiungiTesto(
          _tela(),
          ctx,
          pagina: 0,
          carattere: 'Inter',
        ).snapshot.texts.single;
        final m0 = ctx.textSize(t);
        final r = trasformaTesto(t, ctx, scala: 2, gradi: 44);
        expect(r.testo.size, 140);
        expect(r.testo.rotation, 45); // Scatta a 45°
        expect(r.agganciata, isTrue);
        final m1 = ctx.textSize(r.testo);
        expect(r.testo.x + m1.w / 2, closeTo(t.x + m0.w / 2, 1e-9));
        expect(trasformaTesto(t, ctx, scala: 100, gradi: 0).testo.size, 400);
        expect(trasformaTesto(t, ctx, scala: 0.01, gradi: 0).testo.size, 12);
        expect(trasformaTesto(t, ctx, scala: 1, gradi: 20).agganciata, isFalse);
      },
    );

    test('modificaTesti tocca solo i testi scelti e il file di prima si riscrive uguale', () {
      final ctx = _ctx();
      var s = _tela();
      final a = aggiungiTesto(s, ctx, pagina: 0, carattere: 'Inter');
      final b = aggiungiTesto(a.snapshot, ctx, pagina: 0, carattere: 'Inter');
      s = modificaTesti(b.snapshot, [
        a.ref.uid,
      ], (t) => conColoreTesto(t, 0xFFFF0000));
      expect(s.texts[0].color, 0xFFFF0000);
      expect(s.texts[1].color, isNot(0xFFFF0000));
      final json = s.texts[0].toJson();
      expect(TextItem.fromJson(json).toJson(), json);
    });
  });

  group('forme', () {
    test('tutti i 9 tipi nascono al centro della pagina, con le misure del desktop', () {
      final ctx = _ctx();
      expect(tipiForma, hasLength(9));
      for (final kind in tipiForma) {
        final r = aggiungiForma(_tela(), ctx, kind: kind, pagina: 2);
        final f = r.snapshot.shapes.single;
        expect(f.kind, kind);
        expect(r.ref, (tipo: ElementKind.shape, uid: f.uid));
        // Lato corto 1000 → base 300
        if (eLineaForma(kind)) {
          expect(f.w, closeTo(420, 1e-9), reason: kind);
          expect(f.h, kind == 'line' ? 10 : dimensionePunta(10), reason: kind);
          expect((f.fill >>> 24, f.stroke), (0, 0xFFFF3B30), reason: kind);
          expect(f.strokeWidth, 10); // 1% del lato corto
        } else {
          expect(f.w, kind == 'rect' ? 390 : 300, reason: kind);
          expect(f.h, 300);
          expect((f.fill, f.strokeWidth), (0xFFFF3B30, 0.0), reason: kind);
        }
        expect(f.x + f.w / 2, closeTo(2500, 1e-9), reason: kind);
        expect(f.y + f.h / 2, closeTo(700, 1e-9), reason: kind);
        expect(f.opacity, 100);
        final json = f.toJson();
        expect(ShapeItem.fromJson(json).toJson(), json);
      }
    });

    test('la forma nuova riprende l\'ultimo stile, separato per forme piene e linee', () {
      final ctx = _ctx();
      var stili = const StiliForma();
      var s = _tela();
      final f = aggiungiForma(s, ctx, kind: 'ellipse', pagina: 0, stili: stili);
      s = f.snapshot;
      var forma = s.shapes.single;
      forma = conRiempimento(forma, 0xFF34C759, s.canvas);
      forma = conSpessoreForma(forma, 12);
      forma = conColoreTratto(forma, 0xFF000000, s.canvas);
      forma = conTratto(forma, 'dash');
      forma = conAngoliForma(forma, 40);
      stili = stili.ricorda(forma);
      // Una forma piena nuova eredita tutto
      final nuova = aggiungiForma(
        s,
        ctx,
        kind: 'star',
        pagina: 0,
        stili: stili,
      ).snapshot.shapes.last;
      expect(
        (
          nuova.fill,
          nuova.stroke,
          nuova.strokeWidth,
          nuova.strokeStyle,
          nuova.radius,
        ),
        (0xFF34C759, 0xFF000000, 12.0, 'dash', 40.0),
      );
      // Una linea no: ha il suo stile di partenza
      final linea = aggiungiForma(
        s,
        ctx,
        kind: 'arrow',
        pagina: 0,
        stili: stili,
      ).snapshot.shapes.last;
      expect(
        (linea.stroke, linea.strokeStyle, linea.strokeWidth),
        (0xFFFF3B30, 'solid', 10.0),
      );
      // Dopo aver cambiato una linea, le linee ereditano la sua
      stili = stili.ricorda(
        conColoreTratto(conSpessoreForma(linea, 20), 0xFF007AFF, s.canvas),
      );
      final linea2 = aggiungiForma(
        s,
        ctx,
        kind: 'line',
        pagina: 0,
        stili: stili,
      ).snapshot.shapes.last;
      expect((linea2.stroke, linea2.strokeWidth), (0xFF007AFF, 20.0));
      expect(linea2.h, 20); // Una linea semplice è alta quanto il suo spessore
      // …e le forme piene restano come prima
      expect(
        aggiungiForma(
          s,
          ctx,
          kind: 'heart',
          pagina: 0,
          stili: stili,
        ).snapshot.shapes.last.fill,
        0xFF34C759,
      );
    });

    test('cambiare tipo tiene stile, posizione e rotazione; da forma a linea si adatta l\'altezza', () {
      final ctx = _ctx();
      final s = aggiungiForma(_tela(), ctx, kind: 'rect', pagina: 0).snapshot;
      var f = s.shapes.single.copyWith(
        fill: 0xFF5856D6,
        stroke: 0xFF00C7BE,
        strokeWidth: 6,
        strokeStyle: 'dot',
        radius: 30,
        opacity: 60,
        rotation: 33,
      );
      final cx = f.x + f.w / 2, cy = f.y + f.h / 2;
      void controlla(ShapeItem g, String kind) {
        expect(g.kind, kind);
        expect(
          (g.fill, g.stroke, g.strokeStyle, g.radius, g.opacity, g.rotation),
          (0xFF5856D6, 0xFF00C7BE, 'dot', 30.0, 60, 33.0),
          reason: kind,
        );
        expect(g.x + g.w / 2, closeTo(cx, 1e-9), reason: kind);
        expect(g.y + g.h / 2, closeTo(cy, 1e-9), reason: kind);
      }

      for (final kind in ['ellipse', 'triangle', 'diamond', 'star', 'heart']) {
        f = conTipoForma(f, kind, s.canvas);
        controlla(f, kind);
        expect(
          (f.w, f.h),
          (390, 300),
          reason: 'tra forme piene la misura non cambia',
        );
      }
      // Forma piena → freccia: stessa larghezza, altezza della punta, spessore almeno quello visibile
      final freccia = conTipoForma(f, 'arrow', s.canvas);
      controlla(freccia, 'arrow');
      expect(freccia.w, 390);
      expect(
        freccia.strokeWidth,
        8,
      ); // max(6, 8): 8 è lo spessore visibile su una pagina larga 1000
      expect(freccia.h, dimensionePunta(freccia.strokeWidth));
      // Da freccia a linea: l'altezza segue lo spessore
      final linea = conTipoForma(freccia, 'line', s.canvas);
      controlla(linea, 'line');
      expect(linea.h, linea.strokeWidth);
      // Da linea a forma piena: ¾ della larghezza
      final rett = conTipoForma(linea, 'rect', s.canvas);
      controlla(rett, 'rect');
      expect((rett.w, rett.h), (390, 390 * 0.75));
      // Un tipo sconosciuto o lo stesso tipo non cambiano niente
      expect(identical(conTipoForma(f, f.kind, s.canvas), f), isTrue);
      expect(identical(conTipoForma(f, 'pentagono', s.canvas), f), isTrue);
    });

    test('riempimento «Nessuno» senza bordo lascia il contorno; il colore del bordo lo mostra', () {
      final ctx = _ctx();
      final s = aggiungiForma(_tela(), ctx, kind: 'rect', pagina: 0).snapshot;
      final f = s.shapes.single;
      expect(f.strokeWidth, 0);
      final nessuno = conRiempimento(f, 0x00000000, s.canvas);
      expect(nessuno.fill >>> 24, 0);
      expect(nessuno.strokeWidth, 8);
      // Con un bordo già presente non si tocca
      final conBordo = conSpessoreForma(f, 5);
      expect(conRiempimento(conBordo, 0, s.canvas).strokeWidth, 5);
      // Scegliere il colore del bordo su una forma senza bordo ne dà uno
      expect(conColoreTratto(f, 0xFF000000, s.canvas).strokeWidth, 8);
      // Una linea non ha riempimento
      final l = aggiungiForma(
        s,
        ctx,
        kind: 'line',
        pagina: 0,
      ).snapshot.shapes.last;
      expect(identical(conRiempimento(l, 0xFF00FF00, s.canvas), l), isTrue);
    });

    test('limiti dei cursori e spessore di una linea', () {
      final ctx = _ctx();
      final s = aggiungiForma(_tela(), ctx, kind: 'arrow', pagina: 0).snapshot;
      final f = s.shapes.single;
      expect(conSpessoreForma(f, 500).strokeWidth, 80);
      expect(conSpessoreForma(f, -4).strokeWidth, 0);
      // Una linea ricalcola l'altezza e il centro non si muove
      final g = conSpessoreForma(f, 30);
      expect(g.h, dimensionePunta(30));
      expect(g.y + g.h / 2, closeTo(f.y + f.h / 2, 1e-9));
      expect(conAngoliForma(f, 999).radius, 300);
      expect(conOpacitaForma(f, 0).opacity, 5);
      expect(conOpacitaForma(f, 400).opacity, 100);
      expect(conRotazioneForma(f, -270).rotation, -180);
      expect(identical(conTratto(f, 'ondulato'), f), isTrue);
      expect(conTratto(f, 'dot').strokeStyle, 'dot');
    });

    test('maniglie: l\'angolo opposto resta fermo e le proporzioni si tengono; i lati cambiano una misura', () {
      final ctx = _ctx();
      final s = aggiungiForma(_tela(), ctx, kind: 'rect', pagina: 0).snapshot;
      final f = s.shapes.single.copyWith(rotation: 30);
      final fermoAngolo = formaInScena(f, 0, 0);
      final tr = formaInScena(f, f.w, 0);
      // Trascinando l'angolo in basso a destra ci si ferma sul punto dato, mantenendo le proporzioni
      final br = formaInScena(f, f.w, f.h);
      final g = ridimensionaForma(f, Maniglia.br, br.$1 + 100, br.$2 + 60);
      expect(g.w / g.h, closeTo(f.w / f.h, 1e-9));
      expect(g.w, greaterThan(f.w));
      final dopoAngolo = formaInScena(g, 0, 0);
      expect(dopoAngolo.$1, closeTo(fermoAngolo.$1, 1e-6));
      expect(dopoAngolo.$2, closeTo(fermoAngolo.$2, 1e-6));
      expect(g.rotation, 30);
      // Lato destro: cambia solo la larghezza; il lato sinistro non si muove
      final latoSx = formaInScena(f, 0, f.h / 2);
      final h = ridimensionaForma(f, Maniglia.r, tr.$1 + 50, tr.$2 + 20);
      expect(h.h, f.h);
      expect(h.w, isNot(f.w));
      final dopoSx = formaInScena(h, 0, h.h / 2);
      expect(dopoSx.$1, closeTo(latoSx.$1, 1e-6));
      expect(dopoSx.$2, closeTo(latoSx.$2, 1e-6));
      // Lato alto: cambia solo l'altezza e il lato basso resta
      final latoGiu = formaInScena(f, f.w / 2, f.h);
      final alto = formaInScena(f, f.w / 2, 0);
      final v = ridimensionaForma(f, Maniglia.t, alto.$1 - 20, alto.$2 - 50);
      expect(v.w, f.w);
      expect(v.h, isNot(f.h));
      final dopoGiu = formaInScena(v, v.w / 2, v.h);
      expect(dopoGiu.$1, closeTo(latoGiu.$1, 1e-6));
      expect(dopoGiu.$2, closeTo(latoGiu.$2, 1e-6));
      // Mai sotto il minimo
      final minimo = ridimensionaForma(
        f,
        Maniglia.br,
        fermoAngolo.$1,
        fermoAngolo.$2,
      );
      expect(minimo.h, ShapeItem.minSize);
      expect(minimo.w / minimo.h, closeTo(f.w / f.h, 1e-9));
    });

    test('estremi di una linea: l\'altro resta fermo, lunghezza e direzione seguono il dito', () {
      final ctx = _ctx();
      final s = aggiungiForma(_tela(), ctx, kind: 'line', pagina: 0).snapshot;
      final f = s.shapes.single;
      final inizio = estremoInScena(f, EstremoLinea.inizio);
      final r = spostaEstremo(
        f,
        EstremoLinea.fine,
        inizio.$1 + 300,
        inizio.$2 + 400,
      );
      expect(r.forma.w, closeTo(500, 1e-6));
      expect(
        r.forma.rotation,
        closeTo(math.atan2(400, 300) * 180 / math.pi, 1e-6),
      );
      expect(r.agganciata, isFalse);
      final ancoraDopo = estremoInScena(r.forma, EstremoLinea.inizio);
      expect(ancoraDopo.$1, closeTo(inizio.$1, 1e-6));
      expect(ancoraDopo.$2, closeTo(inizio.$2, 1e-6));
      final fineDopo = estremoInScena(r.forma, EstremoLinea.fine);
      expect(fineDopo.$1, closeTo(inizio.$1 + 300, 1e-6));
      expect(fineDopo.$2, closeTo(inizio.$2 + 400, 1e-6));
      // L'estremo iniziale: ora è l'altro, quello a destra, a restare fermo
      final fine = estremoInScena(r.forma, EstremoLinea.fine);
      final q = spostaEstremo(
        r.forma,
        EstremoLinea.inizio,
        fine.$1 - 500,
        fine.$2,
      );
      expect(q.forma.rotation, closeTo(0, 1e-9));
      expect(q.agganciata, isTrue);
      expect(q.forma.w, closeTo(500, 1e-6));
      final fineFermo = estremoInScena(q.forma, EstremoLinea.fine);
      expect(fineFermo.$1, closeTo(fine.$1, 1e-6));
      expect(fineFermo.$2, closeTo(fine.$2, 1e-6));
      // Una linea non si ridimensiona con le maniglie dei lati
      expect(identical(ridimensionaForma(f, Maniglia.r, 0, 0), f), isTrue);
    });

    test('pallino di rotazione e pizzico', () {
      final ctx = _ctx();
      final s = aggiungiForma(_tela(), ctx, kind: 'rect', pagina: 0).snapshot;
      final f = s.shapes.single;
      final cx = f.x + f.w / 2, cy = f.y + f.h / 2;
      // Il pallino sopra il centro è a 0°; a destra del centro la forma è ruotata di 90°
      expect(ruotaConPallino(f, cx, cy - 200).forma.rotation, closeTo(0, 1e-9));
      final dx = ruotaConPallino(f, cx + 200, cy);
      expect(dx.forma.rotation, closeTo(90, 1e-9));
      expect(dx.agganciata, isTrue);
      expect(
        ruotaConPallino(f, cx - 200, cy).forma.rotation,
        closeTo(-90, 1e-9),
      );
      final p = pallinoRotazione(f, 40);
      expect(p.$1, closeTo(cx, 1e-9));
      expect(p.$2, closeTo(f.y - 40, 1e-9));
      // Pizzico: misure e rotazione attorno al centro
      final t = trasformaForma(f, scala: 0.5, gradi: 31);
      expect((t.forma.w, t.forma.h), (f.w / 2, f.h / 2));
      expect(t.forma.rotation, 30);
      expect(t.agganciata, isTrue);
      expect(t.forma.x + t.forma.w / 2, closeTo(cx, 1e-9));
      expect(
        trasformaForma(f, scala: 0.0001, gradi: 0).forma.h,
        closeTo(ShapeItem.minSize, 1e-9),
      );
      // Una linea si allunga ma non si ingrossa
      final l = aggiungiForma(
        s,
        ctx,
        kind: 'arrow',
        pagina: 0,
      ).snapshot.shapes.last;
      final tl = trasformaForma(l, scala: 2, gradi: 0).forma;
      expect((tl.w, tl.h), (l.w * 2, l.h));
    });
  });
}
