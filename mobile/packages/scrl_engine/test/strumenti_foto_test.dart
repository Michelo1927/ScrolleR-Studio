import 'dart:convert';
import 'dart:io';

import 'package:scrl_engine/scrl_engine.dart';
import 'package:test/test.dart';

/// Strumenti Foto: riquadro e ritaglio confrontati con `PhotoItem` del desktop
/// (`test/riferimenti/strumenti_foto.json`), più colori, cornice, stile e «Applica a tutte».
void main() {
  final casi = (jsonDecode(
    File('test/riferimenti/strumenti_foto.json').readAsStringSync(),
  ) as List).cast<Map<String, Object?>>();

  PhotoItem nuova(Map<String, Object?> c) => PhotoItem(
    uid: 1,
    path: 'x.jpg',
    x: (c['x']! as num).toDouble(),
    y: (c['y']! as num).toDouble(),
    w: (c['w']! as num).toDouble(),
    h: (c['h']! as num).toDouble(),
    rotation: ((c['rotation'] ?? 0.0) as num).toDouble(),
    free: (c['free'] ?? false) as bool,
    innerZoom: ((c['inner_zoom'] ?? 1.0) as num).toDouble(),
    panX: ((c['pan_x'] ?? 0.0) as num).toDouble(),
    panY: ((c['pan_y'] ?? 0.0) as num).toDouble(),
    stretch: ((c['stretch'] ?? 1.0) as num).toDouble(),
    crop: c['crop'] == null
        ? fullCrop
        : [for (final v in c['crop']! as List) (v as num).toDouble()],
  );

  void uguale(PhotoItem p, Map<String, Object?> att, String perche) {
    void v(double a, String k) => expect(
      a,
      closeTo((att[k]! as num).toDouble(), 1e-6),
      reason: '$perche $k',
    );
    v(p.x, 'x');
    v(p.y, 'y');
    v(p.w, 'w');
    v(p.h, 'h');
    v(p.innerZoom, 'inner_zoom');
    v(p.panX, 'pan_x');
    v(p.panY, 'pan_y');
    v(p.stretch, 'stretch');
    final crop = (att['crop']! as List).cast<num>();
    for (var i = 0; i < 4; i++) {
      expect(
        p.crop[i],
        closeTo(crop[i].toDouble(), 1e-9),
        reason: '$perche crop[$i]',
      );
    }
    final saved = att['saved'] as Map<String, Object?>?;
    if (saved == null) {
      expect(p.savedCell, isNull, reason: perche);
    } else {
      expect(p.savedCell, isNotNull, reason: perche);
      for (final e in saved.entries) {
        expect(
          (p.savedCell![e.key]! as num).toDouble(),
          closeTo((e.value! as num).toDouble(), 1e-6),
          reason: '$perche saved ${e.key}',
        );
      }
    }
  }

  test(
    '«Proporzioni foto», «Riquadro di prima» e ritaglio come il desktop',
    () {
      expect(casi, isNotEmpty);
      for (final c in casi) {
        final im = (c['img']! as List).cast<int>();
        final misura = (w: im[0], h: im[1]);
        final f = (c['foto']! as Map).cast<String, Object?>();
        final perche = '$f $im';
        final p = proporzioniFoto(nuova(f), misura);
        uguale(
          p,
          (c['proporzioni']! as Map).cast<String, Object?>(),
          '$perche proporzioni',
        );
        // Una seconda volta il riquadro di prima non si ricorda di nuovo
        final due = proporzioniFoto(p, misura);
        uguale(
          due,
          (c['proporzioni_due_volte']! as Map).cast<String, Object?>(),
          '$perche due volte',
        );
        uguale(
          riquadroDiPrima(due),
          (c['ripristino']! as Map).cast<String, Object?>(),
          '$perche ripristino',
        );
        for (final r in (c['ritagli']! as List).cast<Map<String, Object?>>()) {
          final crop = [
            for (final v in r['crop']! as List) (v as num).toDouble(),
          ];
          final q = conRitaglio(nuova(f), crop, r['fit']! as bool, misura);
          uguale(
            q,
            (r['dopo']! as Map).cast<String, Object?>(),
            '$perche ritaglio $crop ${r['fit']}',
          );
        }
      }
    },
  );

  group('colori', () {
    final p = PhotoItem(uid: 1, path: 'x.jpg');

    test('filtro pronto: sostituisce le regolazioni e si riconosce', () {
      for (final preset in presets) {
        final q = conFiltro(conRegolazione(p, 'brightness', 40), preset.key);
        expect(q.adjust, presetAdjust(preset.key));
        expect(filtroAttivo(q.adjust), preset.key);
      }
      // Ritoccato a mano non corrisponde più a nessun filtro
      expect(
        filtroAttivo(
          conRegolazione(conFiltro(p, 'vivid'), 'contrast', 16).adjust,
        ),
        isNull,
      );
      // La foto senza regolazioni è «Originale»
      expect(filtroAttivo(p.adjust), 'original');
    });

    test('regolazioni, interruttori e reimposta', () {
      var q = conRegolazione(p, 'shadows', 30);
      q = conInterruttore(q, 'bw', true);
      q = conInterruttore(q, 'auto', true);
      expect(valoreRegolazione(q, 'shadows'), 30);
      expect(q.adjust['bw'], isTrue);
      expect(adjustmentsActive(q.adjust), isTrue);
      expect(coloriReimpostati(q).adjust, neutralAdjust);
    });

    test('«Applica a tutte» salta le pagine bloccate', () {
      final primaria = conFiltro(p, 'film');
      final s = Snapshot(
        canvas: Snapshot.blank().canvas,
        items: [
          primaria.copyWith(uid: 1),
          p.copyWith(uid: 2),
          p.copyWith(uid: 3, pageLocked: true),
        ],
      );
      final r = coloriATutte(s, primaria);
      expect(r.items[0].adjust, primaria.adjust);
      expect(r.items[1].adjust, primaria.adjust);
      expect(r.items[2].adjust, neutralAdjust);
    });
  });

  group('inquadratura', () {
    final p = PhotoItem(uid: 1, path: 'x.jpg', w: 400, h: 400);

    test('reimposta riporta zoom, spostamento e rotazione interna', () {
      final q = inquadraturaReimpostata(
        p.copyWith(
          innerZoom: 2.5,
          panX: 0.4,
          panY: -0.7,
          innerRotation: 30,
          rotation: 12,
        ),
      );
      expect(
        (q.innerZoom, q.panX, q.panY, q.innerRotation),
        (1.0, 0.0, 0.0, 0.0),
      );
      expect(q.rotation, 12); // La rotazione del riquadro resta
    });

    test('«Foto intera» e «Riempi» azzerano lo spostamento', () {
      final q = conFit(p.copyWith(panX: 0.3, panY: 0.2), 'contain');
      expect((q.fitMode, q.panX, q.panY), ('contain', 0.0, 0.0));
    });

    test('lo zoom resta tra 100% e 400%, la rotazione tra −180° e 180°', () {
      expect(conZoomInterno(p, 9).innerZoom, 4.0);
      expect(conZoomInterno(p, 0.2).innerZoom, 1.0);
      expect(conRotazioneInterna(p, 190).innerRotation, -170);
      final k = pizzicoInterno(p.copyWith(innerZoom: 3), scala: 2, gradi: 20);
      expect((k.innerZoom, k.innerRotation), (4.0, 20.0));
    });

    test(
      'un dito sposta la foto, con un po di zoom se le proporzioni coincidono',
      () {
        const misura = (w: 400, h: 400);
        final q = panInterno(p, misura, 10, 0);
        expect(q.innerZoom, 1.15);
        expect(q.panX, greaterThan(0));
        expect(q.panY, 0.0);
        // Specchiata: il verso si inverte
        final s = panInterno(p.copyWith(flipH: true), misura, 10, 0);
        expect(s.panX, lessThan(0));
        // Senza la misura non si sposta
        expect(panInterno(p, null, 10, 0), same(p));
      },
    );

    test('le maniglie sui lati stirano la foto, gli angoli no; «Solo riquadro» no', () {
      final q = PhotoItem(uid: 1, path: 'x.jpg', w: 200, h: 100);
      // Lato destro portato a 300: una volta e mezza più larga → stiramento 1,5
      final a = ridimensionaFoto(q, Maniglia.r, 300, 50);
      expect(a.w, closeTo(300, 1e-9));
      expect(a.stretch, closeTo(1.5, 1e-9));
      // Con «Solo riquadro» il campo non si tocca
      expect(
        ridimensionaFoto(q, Maniglia.r, 300, 50, soloRiquadro: true).stretch,
        1.0,
      );
      // Lato basso: più alta → stiramento minore
      final b = ridimensionaFoto(q, Maniglia.b, 100, 200);
      expect(b.stretch, closeTo(0.5, 1e-9));
      // Angolo: proporzioni bloccate, niente stiramento
      expect(ridimensionaFoto(q, Maniglia.br, 400, 200).stretch, 1.0);
    });
  });

  group('rotazione e specchio', () {
    final p = PhotoItem(uid: 1, path: 'x.jpg');
    test('90° a sinistra e a destra, sempre tra −180° e 180°', () {
      expect(ruotataDi(p, 90).rotation, 90);
      expect(ruotataDi(ruotataDi(p, 90), 90).rotation, -180);
      expect(ruotataDi(p, -90).rotation, -90);
      expect(ruotataDi(p.copyWith(rotation: 170), 20).rotation, -170);
      expect(conRotazione(p.copyWith(rotation: 33), 0).rotation, 0);
    });
    test('specchia in orizzontale e in verticale', () {
      final a = specchiata(p, orizzontale: true);
      expect((a.flipH, a.flipV), (true, false));
      final b = specchiata(a, orizzontale: false);
      expect((b.flipH, b.flipV), (true, true));
      expect(specchiata(a, orizzontale: true).flipH, isFalse);
    });
  });

  group('cornice, ombra e stile', () {
    final p = PhotoItem(uid: 1, path: 'x.jpg');
    test('il bordo a mano spegne quello automatico', () {
      final q = conBordo(p.copyWith(autoBorder: true), 12);
      expect((q.borderWidth, q.autoBorder), (12.0, false));
    });
    test('opacità tra 5 e 100', () {
      expect(conOpacita(p, 0).opacity, 5);
      expect(conOpacita(p, 500).opacity, 100);
    });
    test('copia e incolla stile', () {
      final modello = conFiltro(
        p.copyWith(
          borderRadius: 40,
          borderWidth: 8,
          borderColor: 0xFFFF3B30,
          opacity: 70,
          shadow: 55,
        ),
        'vintage',
      );
      final stile = StileFoto.di(modello);
      final s = Snapshot(
        canvas: Snapshot.blank().canvas,
        items: [
          modello.copyWith(uid: 1),
          p.copyWith(uid: 2, autoBorder: true),
          p.copyWith(uid: 3),
        ],
      );
      final r = incollaStile(s, [2], stile);
      final q = r.items[1];
      expect(q.borderRadius, 40);
      expect(q.borderWidth, 8);
      expect(q.borderColor, 0xFFFF3B30);
      expect(q.opacity, 70);
      expect(q.shadow, 55);
      expect(q.adjust, modello.adjust);
      expect(q.autoBorder, isFalse);
      expect(r.items[2].borderWidth, 0); // L'altra non cambia
    });
    test('«Applica a tutte»: cornice, opacità e ombra, non i colori; pagine bloccate escluse', () {
      final primaria = conFiltro(
        p.copyWith(borderRadius: 20, borderWidth: 4, opacity: 80, shadow: 30),
        'film',
      );
      final s = Snapshot(
        canvas: Snapshot.blank().canvas,
        items: [
          primaria.copyWith(uid: 1),
          p.copyWith(uid: 2),
          p.copyWith(uid: 3, pageLocked: true),
        ],
      );
      final r = stileATutte(s, primaria);
      expect(r.items[1].borderRadius, 20);
      expect(r.items[1].opacity, 80);
      expect(r.items[1].shadow, 30);
      expect(r.items[1].adjust, neutralAdjust);
      expect(r.items[2].borderRadius, 0);
    });
  });

  test('ritaglio: la foto intera non è un ritaglio', () {
    final p = PhotoItem(uid: 1, path: 'x.jpg');
    expect(haRitaglio(p), isFalse);
    expect(haRitaglio(p.copyWith(crop: [0.1, 0, 1, 1])), isTrue);
  });
}
