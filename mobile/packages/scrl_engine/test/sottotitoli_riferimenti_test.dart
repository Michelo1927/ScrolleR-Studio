import 'dart:convert';
import 'dart:io';

import 'package:scrl_engine/scrl_engine.dart';
import 'package:test/test.dart';

/// Sottotitoli confrontati con il desktop (`test/riferimenti/sottotitoli.json`, da `scrollr/captions.py`):
/// divisione del testo, righe bilanciate, frasi, `merge_lines`, tempi automatici, .srt, forma d'onda e pause.
void main() {
  final rif = jsonDecode(
    File('test/riferimenti/sottotitoli.json').readAsStringSync(),
  ) as Map<String, Object?>;
  List<Map<String, Object?>> casi(String k) =>
      (rif[k]! as List).cast<Map<String, Object?>>();
  final tabella = (rif['larghezze']! as Map).cast<String, Object?>();
  double larghezza(String s) {
    var w = 0.0;
    for (final c in s.runes) {
      w += ((tabella[String.fromCharCode(c)] as num?) ?? 10).toDouble();
    }
    return w;
  }

  double? num_(Object? v) => (v as num?)?.toDouble();

  /// Frase del desktop (dizionario) come `Frase`, senza passare da `clean_phrases`.
  Frase frase(Object? v) {
    final m = (v! as Map).cast<String, Object?>();
    return Frase(
      testo: m['text']! as String,
      inizio: num_(m['start']),
      fine: num_(m['end']),
      tr: (m['tr'] as String?) ?? '',
      auto: m['auto'] == true,
      parole: m['words'] as List<Object?>?,
    );
  }

  List<Frase> frasi(Object? v) => [for (final p in v! as List) frase(p)];

  void stessaFrase(Frase mia, Object? att, String dove) {
    final m = (att! as Map).cast<String, Object?>();
    expect(mia.testo, m['text'], reason: '$dove testo');
    expect(mia.tr, (m['tr'] as String?) ?? '', reason: '$dove tr');
    expect(mia.auto, m['auto'] == true, reason: '$dove auto');
    for (final (mio, chiave) in [(mia.inizio, 'start'), (mia.fine, 'end')]) {
      final a = num_(m[chiave]);
      if (a == null) {
        expect(mio, isNull, reason: '$dove $chiave');
      } else {
        expect(mio, closeTo(a, 1e-9), reason: '$dove $chiave');
      }
    }
  }

  void stesseFrasi(List<Frase> mie, Object? att, String dove) {
    final l = att! as List;
    expect(mie.length, l.length, reason: '$dove numero di frasi');
    for (var i = 0; i < l.length; i++) {
      stessaFrase(mie[i], l[i], '$dove [$i]');
    }
  }

  List<Pausa> pause(Object? v) => [
    for (final p in (v! as List).cast<List<Object?>>())
      ((p[0]! as num).toDouble(), (p[1]! as num).toDouble()),
  ];

  void stessePause(List<Pausa> mie, Object? att, String dove) {
    final l = att! as List;
    expect(mie.length, l.length, reason: '$dove numero');
    for (var i = 0; i < l.length; i++) {
      final p = l[i] as List;
      expect(
        mie[i].$1,
        closeTo((p[0] as num).toDouble(), 1e-9),
        reason: '$dove [$i].0',
      );
      expect(
        mie[i].$2,
        closeTo((p[1] as num).toDouble(), 1e-9),
        reason: '$dove [$i].1',
      );
    }
  }

  test('split_text', () {
    for (final c in casi('split_text')) {
      final limite = num_(c['limite']);
      final mie = dividiTesto(
        c['testo']! as String,
        limite == null ? null : (s) => staInDueRighe(s, larghezza, limite),
      );
      expect(mie, c['frasi'], reason: '${c['testo']} / $limite');
    }
  });

  test('balance_lines e fits_two_lines', () {
    for (final c in casi('balance_lines')) {
      final t = c['testo']! as String;
      final w = num_(c['max_w'])!;
      expect(bilanciaRighe(t, larghezza, w), c['righe'], reason: '$t / $w');
      expect(staInDueRighe(t, larghezza, w), c['stanno'], reason: '$t / $w');
    }
  });

  test('clean_phrases e phrase_state', () {
    final c = rif['clean_phrases']! as Map<String, Object?>;
    final mie = pulisciFrasi(c['dati']);
    stesseFrasi(mie, c['frasi'], 'clean');
    expect(
      jsonEquals([for (final p in mie) p.toJson()], c['stato']),
      isTrue,
      reason: '${[for (final p in mie) p.toJson()]}\n${c['stato']}',
    );
    // I tempi delle parole si conservano
    expect(mie[4].parole, isNotNull);
  });

  test('split_phrase, join_phrases, phrase_index_at, insert_index', () {
    for (final c in casi('split_phrase')) {
      final (a, b) = dividiFrase(frase(c['frase']));
      stessaFrase(a, c['a'], 'dividi a ${c['frase']}');
      stessaFrase(b, c['b'], 'dividi b ${c['frase']}');
    }
    for (final c in casi('join_phrases')) {
      stessaFrase(
        unisciFrasi(frase(c['a']), frase(c['b'])),
        c['frase'],
        'unisci',
      );
    }
    for (final c in casi('phrase_index_at')) {
      expect(indiceFraseA(frasi(c['frasi']), num_(c['t'])!), c['indice']);
    }
    for (final c in casi('insert_index')) {
      expect(
        indiceInserimento(frasi(c['frasi']), num_(c['start'])!),
        c['indice'],
      );
    }
  });

  test('merge_lines', () {
    var n = 0;
    for (final c in casi('merge_lines')) {
      final righe = (c['righe']! as List).cast<String>();
      stesseFrasi(
        unisciRighe(frasi(c['vecchie']), righe),
        c['frasi'],
        'merge ${n++} $righe',
      );
    }
  });

  test('format_clock e parse_clock', () {
    for (final c in rif['format_clock']! as List) {
      final l = c as List;
      expect(formatoOrologio(num_(l[0])), l[1], reason: '${l[0]}');
    }
    for (final c in rif['parse_clock']! as List) {
      final l = c as List;
      final a = num_(l[1]);
      final mio = leggiOrologio(l[0] as String);
      if (a == null) {
        expect(mio, isNull, reason: '«${l[0]}»');
      } else {
        expect(mio, closeTo(a, 1e-9), reason: '«${l[0]}»');
      }
    }
  });

  test('to_srt e parse_srt', () {
    for (final c in casi('to_srt')) {
      expect(
        inSrt(frasi(c['frasi']), traduzione: c['campo'] == 'tr'),
        c['srt'],
      );
    }
    for (final c in casi('parse_srt')) {
      stesseFrasi(leggiSrt(c['srt']! as String), c['frasi'], 'srt ${c['srt']}');
    }
  });

  test('envelope e find_pauses', () {
    for (final c in casi('envelope')) {
      final mio = inviluppo(
        base64Decode(c['pcm']! as String),
        (c['rate']! as num).toInt(),
      );
      final att = (c['env']! as List).cast<num>();
      expect(mio.length, att.length);
      for (var i = 0; i < att.length; i++) {
        expect(mio[i], closeTo(att[i].toDouble(), 1e-12));
      }
    }
    var n = 0;
    for (final c in casi('find_pauses')) {
      final env = [for (final v in c['env']! as List) (v as num).toDouble()];
      stessePause(
        trovaPause(env, minimo: num_(c['min_len'])!),
        c['pause'],
        'pause ${n++}',
      );
    }
  });

  test('snap, speech_spans, auto_times, retime, phrase_weight', () {
    for (final c in casi('snap')) {
      final punti = [
        for (final v in c['punti']! as List) (v as num).toDouble(),
      ];
      expect(
        aggancia(num_(c['t'])!, punti, num_(c['tol'])!),
        closeTo(num_(c['r'])!, 1e-12),
      );
    }
    var n = 0;
    for (final c in casi('speech_spans')) {
      stessePause(
        trattiParlato(pause(c['pause']), num_(c['lo'])!, num_(c['hi'])!),
        c['tratti'],
        'parlato ${n++}',
      );
    }
    n = 0;
    for (final c in casi('auto_times')) {
      stessePause(
        tempiAutomatici(
          [for (final v in c['pesi']! as List) (v as num).toDouble()],
          pause(c['pause']),
          num_(c['lo'])!,
          num_(c['hi'])!,
        ),
        c['tempi'],
        'automatici ${n++}',
      );
    }
    n = 0;
    for (final c in casi('retime')) {
      stesseFrasi(
        ridistribuisci(
          frasi(c['frasi']),
          pause(c['pause']),
          num_(c['lo'])!,
          num_(c['hi'])!,
          azzera: c['reset'] == true,
        ),
        c['dopo'],
        'retime ${n++}',
      );
    }
    for (final c in rif['phrase_weight']! as List) {
      final l = c as List;
      expect(pesoFrase(Frase(testo: l[0] as String)), num_(l[1]));
    }
  });
}
