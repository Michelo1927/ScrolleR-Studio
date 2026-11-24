import 'dart:convert';
import 'dart:io';

import 'package:scrl_engine/scrl_engine.dart';
import 'package:test/test.dart';

/// Sagoma confrontata con il desktop (`test/riferimenti/sagoma.json`): pulizia dei dati del file, raggio della
/// morbidezza, ritaglio stretto, semplificazione dei tratti, `apply_cutout`, fine del tratto a mano libera e
/// specchio nella finestra Ritaglia.
void main() {
  final rif = jsonDecode(
    File('test/riferimenti/sagoma.json').readAsStringSync(),
  ) as Map<String, Object?>;
  List<Map<String, Object?>> casi(String k) =>
      (rif[k]! as List).cast<Map<String, Object?>>();

  List<PuntoSagoma> punti(Object? v) => [
    for (final q in (v! as List).cast<List<Object?>>())
      ((q[0]! as num).toDouble(), (q[1]! as num).toDouble()),
  ];

  void stessiPunti(List<PuntoSagoma>? a, Object? att, String perche) {
    if (att == null) {
      expect(a, isNull, reason: perche);
      return;
    }
    final b = punti(att);
    expect(a, isNotNull, reason: perche);
    expect(a!.length, b.length, reason: perche);
    for (var i = 0; i < b.length; i++) {
      expect(a[i].$1, closeTo(b[i].$1, 1e-9), reason: '$perche [$i].x');
      expect(a[i].$2, closeTo(b[i].$2, 1e-9), reason: '$perche [$i].y');
    }
  }

  /// Confronta i campi di `get_state` del desktop con [toJson] del motore (numeri con tolleranza).
  void stessoStato(Object? mio, Object? att, String dove) {
    if (att is Map) {
      expect(mio, isA<Map<String, Object?>>(), reason: dove);
      for (final e in att.entries) {
        if (e.key == 'uid' || e.key == 'path') continue;
        stessoStato((mio! as Map)[e.key], e.value, '$dove.${e.key}');
      }
    } else if (att is List) {
      expect(mio, isA<List<Object?>>(), reason: dove);
      expect((mio! as List).length, att.length, reason: dove);
      for (var i = 0; i < att.length; i++) {
        stessoStato((mio as List)[i], att[i], '$dove[$i]');
      }
    } else if (att is num && att is! bool) {
      expect(
        (mio! as num).toDouble(),
        closeTo(att.toDouble(), 1e-6),
        reason: dove,
      );
    } else {
      expect(mio, att, reason: dove);
    }
  }

  test('pulizia di punti e morbidezza come `clean_cutout` e `clean_soft`', () {
    for (final c in casi('pulizia')) {
      stessiPunti(cleanCutout(c['punti']), c['pulita'], '${c['punti']}');
    }
    for (final c in casi('morbidezze')) {
      expect(cleanSoft(c['valore']), c['pulita'], reason: '${c['valore']}');
    }
  });

  test('raggio della morbidezza e ritaglio stretto', () {
    for (final c in casi('funzioni')) {
      final im = (c['img']! as List).cast<int>();
      final w = im[0].toDouble(), h = im[1].toDouble();
      final soft = c['soft']! as int;
      expect(
        raggioMorbidezza(soft, w, h),
        closeTo((c['raggio']! as num).toDouble(), 1e-9),
      );
      final r = ritaglioSagoma(punti(c['punti']), soft, w, h);
      final att = (c['ritaglio']! as List).cast<num>();
      for (var i = 0; i < 4; i++) {
        expect(r[i], closeTo(att[i].toDouble(), 1e-12), reason: '$c [$i]');
      }
    }
  });

  test('semplificazione dei tratti (Ramer-Douglas-Peucker)', () {
    for (final c in casi('semplifica')) {
      stessiPunti(
        semplificaSagoma(
          punti(c['punti']),
          (c['tolleranza']! as num).toDouble(),
        ),
        c['risultato'],
        'tolleranza ${c['tolleranza']}',
      );
    }
  });

  test('`apply_cutout` e «Togli sagoma» su foto diverse', () {
    final tutti = casi('applica');
    expect(tutti, hasLength(32));
    for (final c in tutti) {
      final im = (c['img']! as List).cast<int>();
      final misura = (w: im[0], h: im[1]);
      final prima = PhotoItem.fromJson(c['prima']);
      final dopo = conSagoma(
        prima,
        punti(c['punti']).length >= 3 ? punti(c['punti']) : null,
        c['soft']! as int,
        misura,
      );
      stessoStato(dopo.toJson(), c['dopo'], 'dopo');
      stessoStato(senzaSagoma(dopo, misura).toJson(), c['tolta'], 'tolta');
    }
  });

  test('stato riletto dal file e riscritto uguale', () {
    for (final c in casi('applica')) {
      final dopo = c['dopo']! as Map<String, Object?>;
      stessoStato(PhotoItem.fromJson(dopo).toJson(), dopo, 'riletto');
    }
  });

  test('fine del tratto a mano libera: semplificato, unito, chiuso', () {
    final tutti = casi('tratti');
    expect(tutti, isNotEmpty);
    var chiusi = 0;
    for (final c in tutti) {
      final im = (c['img']! as List).cast<int>();
      final scala = (c['scala']! as num).toDouble();
      final presa = (c['presa']! as num).toDouble();
      final m = ModelloSagoma(
        larghezza: im[0].toDouble(),
        altezza: im[1].toDouble(),
      );
      for (final q in punti(c['prima'])) {
        m.aggiungiPunto(q, scala);
      }
      final tratto = punti(c['tratto']);
      m.iniziaTratto(tratto.first);
      // Il desktop campiona il tratto mentre si muove il mouse: qui i punti sono già quelli campionati
      m.tratto = List.of(tratto);
      m.finisciTratto(scala, presa);
      final att = punti(c['punti']);
      expect(m.punti.length, att.length, reason: '$im $scala');
      for (var i = 0; i < att.length; i++) {
        expect(m.punti[i].$1, closeTo(att[i].$1, 1e-9));
        expect(m.punti[i].$2, closeTo(att[i].$2, 1e-9));
      }
      expect(m.chiusa, c['chiusa'], reason: '$im $scala');
      if (m.chiusa) chiusi++;
    }
    expect(chiusi, greaterThan(0));
  });

  test('specchio: punti mostrati e sagoma restituita come `CropDialog`', () {
    final stella = punti(rif['stella']);
    for (final c in casi('specchi')) {
      final m = ModelloSagoma(
        larghezza: 900,
        altezza: 600,
        sagoma: stella,
        flipH: c['flip_h']! as bool,
        flipV: c['flip_v']! as bool,
      );
      final mostrati = punti(c['mostrati']);
      for (var i = 0; i < mostrati.length; i++) {
        expect(m.punti[i].$1, closeTo(mostrati[i].$1, 1e-6));
        expect(m.punti[i].$2, closeTo(mostrati[i].$2, 1e-6));
      }
      expect(m.chiusa, c['chiusa']);
      stessiPunti(m.risultato(), c['sagoma'], '$c');
    }
  });

  group('modello del disegno della sagoma', () {
    ModelloSagoma nuovo() => ModelloSagoma(larghezza: 1000, altezza: 800);

    test('Indietro e Avanti, anche dopo averla chiusa per sbaglio', () {
      final m = nuovo();
      expect(m.puoAnnullare, isFalse);
      for (final q in [(100.0, 100.0), (600.0, 120.0), (500.0, 600.0)]) {
        m.aggiungiPunto(q, 1.0);
      }
      expect(m.chiudi(), isTrue);
      expect(m.annulla(), isTrue);
      expect(m.chiusa, isFalse);
      expect(m.punti, hasLength(3));
      expect(m.ripeti(), isTrue);
      expect(m.chiusa, isTrue);
      expect(m.togliUltimo(), isTrue, reason: 'su sagoma chiusa la riapre');
      expect(m.chiusa, isFalse);
      expect(m.punti, hasLength(3));
      m.aggiungiPunto((150.0, 500.0), 1.0);
      expect(m.punti, hasLength(4));
      expect(m.puoRipetere, isFalse);
    });

    test('un trascinamento è un solo passo', () {
      final m = nuovo();
      for (final q in [(100.0, 100.0), (600.0, 120.0), (500.0, 600.0)]) {
        m.aggiungiPunto(q, 1.0);
      }
      m.chiudi();
      final passi = <PuntoSagoma>[...m.punti];
      m.iniziaTrascinamento();
      for (var k = 1; k <= 5; k++) {
        m.spostaVertice(1, (600.0 + 10 * k, 120.0 + 5 * k));
      }
      m.fineTrascinamento();
      expect(m.punti[1], (650.0, 145.0));
      m.annulla();
      expect(m.punti, passi);
    });

    test('un trascinamento annullato non lascia passi', () {
      final m = nuovo();
      for (final q in [(100.0, 100.0), (600.0, 120.0), (500.0, 600.0)]) {
        m.aggiungiPunto(q, 1.0);
      }
      m.chiudi();
      final prima = <PuntoSagoma>[...m.punti];
      m.iniziaTrascinamento();
      m.spostaSagoma(40, 40);
      m.annullaTrascinamento();
      expect(m.punti, prima);
      m.annulla();
      expect(m.chiusa, isFalse, reason: "l'ultimo passo resta la chiusura");
    });

    test('la sagoma intera non esce dalla foto', () {
      final m = nuovo();
      for (final q in [(100.0, 100.0), (600.0, 120.0), (500.0, 600.0)]) {
        m.aggiungiPunto(q, 1.0);
      }
      m.chiudi();
      m.iniziaTrascinamento();
      m.spostaSagoma(-500, 5000);
      m.fineTrascinamento();
      expect(m.punti.first, (0.0, 300.0));
      expect(m.punti.last.$2, 800.0);
    });

    test('ricerche: punto, lato, dentro', () {
      final m = nuovo();
      for (final q in [(100.0, 100.0), (600.0, 100.0), (600.0, 600.0)]) {
        m.aggiungiPunto(q, 1.0);
      }
      m.chiudi();
      expect(m.verticeVicino((605.0, 98.0), 1.0, 10), 1);
      expect(m.verticeVicino((300.0, 300.0), 1.0, 10), isNull);
      final lato = m.latoVicino((350.0, 104.0), 1.0, 10);
      expect(lato?.$1, 0);
      expect(lato?.$2, (350.0, 100.0));
      expect(m.contiene((500.0, 200.0)), isTrue);
      expect(m.contiene((150.0, 500.0)), isFalse);
      m.inserisciPunto(lato!.$1, lato.$2);
      expect(m.punti, hasLength(4));
      expect(m.togliPunto(1), isTrue);
      expect(m.togliPunto(0), isFalse, reason: 'ne restano almeno 3');
    });

    test('i video non hanno sagoma', () {
      final v = PhotoItem(uid: 1, path: 'v.mp4', isVideo: true);
      final q = conSagoma(v, punti(rif['stella']), 15, (w: 1920, h: 1080));
      expect(q.cutout, isNull);
      expect(haSagoma(q), isFalse);
      final j = q.toJson();
      expect(j.containsKey('cutout'), isTrue);
      expect(j['cutout'], isNull);
    });
  });
}
