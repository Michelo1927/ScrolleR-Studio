import 'dart:convert';
import 'dart:io';

import 'package:scrl_engine/scrl_engine.dart';
import 'package:test/test.dart';

/// Ritaglio a schermo intero confrontato con `scrollr/crop_dialog.py` (`test/riferimenti/ritaglio.json`):
/// trascinamenti sul `CropCanvas` (angoli, lati, spostamento, riquadro nuovo, con e senza proporzioni bloccate)
/// e scelte del `CropDialog` (proporzioni, scambio, «Foto intera», specchiatura, proporzione iniziale).
void main() {
  final rif = jsonDecode(
    File('test/riferimenti/ritaglio.json').readAsStringSync(),
  ) as Map<String, Object?>;

  const prese = {
    'tl': PresaRitaglio.tl,
    'tr': PresaRitaglio.tr,
    'bl': PresaRitaglio.bl,
    'br': PresaRitaglio.br,
    'l': PresaRitaglio.l,
    'r': PresaRitaglio.r,
    't': PresaRitaglio.t,
    'b': PresaRitaglio.b,
    'move': PresaRitaglio.sposta,
    'new': PresaRitaglio.nuovo,
  };

  void vicini(List<double> a, List<Object?> b, String perche) {
    expect(a.length, b.length, reason: perche);
    for (var i = 0; i < a.length; i++) {
      expect(
        a[i],
        closeTo((b[i]! as num).toDouble(), 1e-6),
        reason: '$perche [$i]',
      );
    }
  }

  test('trascinamenti come il CropCanvas del desktop', () {
    final casi = (rif['trascinamenti']! as List).cast<Map<String, Object?>>();
    expect(casi.length, greaterThan(1000));
    for (final c in casi) {
      final im = (c['img']! as List).cast<num>();
      final r = (c['rect']! as List).cast<num>();
      final m =
          ModelloRitaglio(
              larghezza: im[0].toDouble(),
              altezza: im[1].toDouble(),
              ritaglio: fullCrop,
            )
            ..impostaRiquadro(
              Rect(
                r[0].toDouble(),
                r[1].toDouble(),
                r[2].toDouble(),
                r[3].toDouble(),
              ),
            )
            ..ratio = (c['ratio'] as num?)?.toDouble();
      final scala = (c['scala']! as num).toDouble();
      final premi = (c['premi']! as List).cast<num>();
      final muovi = (c['muovi']! as List).cast<num>();
      final perche = '$c';
      // Il tocco afferra una maniglia entro 10 punti dello schermo (come `GRAB` del desktop)
      m.inizia(premi[0].toDouble(), premi[1].toDouble(), 10.0 / scala);
      expect(m.presa, prese[c['presa']], reason: perche);
      m.trascina(
        muovi[0].toDouble(),
        muovi[1].toDouble(),
        spostamentoSchermo: (c['schermo']! as num).toDouble(),
      );
      m.finisce();
      vicini(
        [m.rect.x, m.rect.y, m.rect.w, m.rect.h],
        (c['risultato']! as List).cast<Object?>(),
        perche,
      );
    }
  });

  test('proporzioni, scambio e «foto intera» come il CropDialog', () {
    final casi = (rif['scelte']! as List).cast<Map<String, Object?>>();
    expect(casi, isNotEmpty);
    for (final c in casi) {
      final im = (c['img']! as List).cast<num>();
      final m = ModelloRitaglio(
        larghezza: im[0].toDouble(),
        altezza: im[1].toDouble(),
        ritaglio: (c['crop']! as List)
            .cast<num>()
            .map((e) => e.toDouble())
            .toList(),
        flipH: c['flip_h']! as bool,
        flipV: c['flip_v']! as bool,
        cellRatio: (c['cella']! as num).toDouble(),
      );
      final perche = '$c';
      final inizio = c['inizio']! as Map<String, Object?>;
      expect(m.chiave, inizio['chiave'], reason: perche);
      expect(m.scambiata, inizio['scambiata'], reason: perche);
      vicini(m.ritaglio, inizio['crop']! as List, perche);
      final copione = (c['copione']! as List).cast<List<Object?>>();
      final passi = (c['passi']! as List).cast<Map<String, Object?>>();
      for (var i = 0; i < copione.length; i++) {
        final op = copione[i];
        switch (op[0]) {
          case 'ratio':
            m.scegliProporzione(op[1] as String);
          case 'swap':
            m.scambia();
          default:
            m.tuttaLaFoto();
        }
        final p = passi[i];
        final dove = '$perche passo $i';
        expect(m.chiave, p['chiave'], reason: dove);
        expect(m.scambiata, p['scambiata'], reason: dove);
        expect(m.etichettaProporzione('4:5'), p['etichetta_4_5'], reason: dove);
        expect(m.puoScambiare, p['scambia'], reason: dove);
        vicini(m.ritaglio, p['crop']! as List, dove);
      }
    }
  });
}
