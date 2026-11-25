import 'package:scrl_engine/scrl_engine.dart';
import 'package:test/test.dart';

import 'cronologia_riferimenti_test.dart' show italiano;
import 'riferimenti_util.dart';

/// Blocchi di sottotitoli sulla tela (`sottotitoli_tela.jsonl`): azioni vere del desktop con un video e i suoi
/// sottotitoli, rifatte col motore (con il passo di cronologia, che toglie i sottotitoli rimasti senza video)
/// e confrontate; per ogni caso anche il nome del passaggio.
void main() {
  for (final caso in leggiJsonl('sottotitoli_tela.jsonl')) {
    final id = caso['id']! as String;
    test('sottotitoli $id', () {
      final prima = StatoDesktop.fromJson(
        caso['prima']! as Map<String, Object?>,
      );
      final dopo = StatoDesktop.fromJson(caso['dopo']! as Map<String, Object?>);
      expect(
        italiano(describeChange(prima.snapshot, dopo.snapshot)),
        caso['nome'],
      );
      final op = caso['op'] as List?;
      if (op == null) return;
      final ctx = prima.contesto();
      final s = prima.snapshot;
      final fatto = switch (op[0]! as String) {
        'duplica_pagina' => duplicatePage(s, op[1]! as int, ctx).snapshot,
        'elimina_pagina' => deletePage(s, op[1]! as int, ctx).snapshot,
        'elimina_video' => eliminaElementi(s, [
          for (final p in s.items)
            if (p.isVideo) rifDi(p),
        ]),
        'svuota' => svuotaTela(s),
        final altro => throw StateError('azione sconosciuta: $altro'),
      };
      final h = History.empty().commit(s, ctx).history.commit(fatto, ctx);
      final errori = confrontaStati(
        h.snapshot,
        caso['dopo']! as Map<String, Object?>,
        s,
      );
      expect(errori, isEmpty, reason: '$id\n${errori.take(15).join('\n')}');
    });
  }

  test('blocco nuovo come `_place_new_caption` del desktop', () {
    final caso = leggiJsonl('sottotitoli_tela.jsonl').first;
    final desktop = StatoDesktop.fromJson(
      caso['prima']! as Map<String, Object?>,
    );
    final atteso = desktop.snapshot.captions.single;
    final misura = desktop.sottotitoli[atteso.uid]!;
    final ctx = EngineContext(captionSize: (_) => misura);
    final senza = desktop.snapshot.copyWith(captions: const []);
    final r = aggiungiSottotitoli(senza, atteso.videoUid, ctx)!;
    expect(r.nuovo, isTrue);
    final c = r.snapshot.captions.single;
    expect(c.videoUid, atteso.videoUid);
    expect(c.stile.size, atteso.stile.size);
    expect(c.wrapW, atteso.wrapW);
    expect(c.x, closeTo(atteso.x, 1e-3));
    // Il desktop ha messo le frasi (con la traduzione) dopo: il blocco è cresciuto restando centrato, quindi
    // qui si controlla il fondo del blocco nuovo (pagina non 9:16: all'86% dell'altezza)
    expect(
      senza.canvas.frameW / senza.canvas.frameH,
      isNot(closeTo(9 / 16, 0.01)),
    );
    expect(c.y + misura.h, closeTo(senza.canvas.frameH * 0.86, 1e-9));
    expect(c.stile.bold && c.stile.shadow, isTrue);
    // Il secondo tocco riapre lo stesso blocco
    final di = aggiungiSottotitoli(r.snapshot, atteso.videoUid, ctx)!;
    expect(di.nuovo, isFalse);
    expect(di.ref, r.ref);
    expect(aggiungiSottotitoli(senza, 999, ctx), isNull);
  });

  test('stile e frasi: il centro del blocco resta fermo', () {
    final c = CaptionItem.nuovo(uid: 1, videoUid: 2).withPosition(100, 200);
    final ctx = EngineContext();
    final m0 = ctx.captionSize(c);
    final conTr = conFrasi(c, const [
      Frase(testo: 'ciao', tr: 'hi', inizio: 0, fine: 1),
    ], ctx);
    final m1 = ctx.captionSize(conTr);
    expect(m1.h, greaterThan(m0.h));
    expect(conTr.y + m1.h / 2, closeTo(c.y + m0.h / 2, 1e-9));
    final grande = conStileSottotitoli(
      c,
      (t) => t.copyWith(size: 90, x: 0, y: 0),
      ctx,
    );
    final m2 = ctx.captionSize(grande);
    expect(grande.x + m2.w / 2, closeTo(c.x + m0.w / 2, 1e-9));
    expect(grande.stile.text, '');
    final stretto = conLarghezzaSottotitoli(c, 50, 1080, ctx);
    expect(stretto.wrapW, 540);
    expect(larghezzaSottotitoliPercento(stretto, 1080), 50);
  });

  test('il progetto dei sottotitoli ha davvero le frasi', () {
    final casi = leggiJsonl('sottotitoli_tela.jsonl');
    final s = StatoDesktop.fromJson(
      casi.first['prima']! as Map<String, Object?>,
    ).snapshot;
    expect(s.captions, hasLength(1));
    final c = s.captions.single;
    expect(s.items.where((p) => p.isVideo).single.uid, c.videoUid);
    expect(c.frasi, hasLength(4));
    expect(c.frasi.first.auto, isTrue);
    expect(c.frasi[1].manuale, isTrue);
    expect(c.frasi.last.sincronizzata, isFalse);
    expect(c.frasi[2].parole, isNotNull);
  });
}
