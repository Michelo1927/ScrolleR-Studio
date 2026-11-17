import 'package:scrl_engine/scrl_engine.dart';
import 'package:test/test.dart';

import 'riferimenti_util.dart';

/// Comandi sulla selezione del desktop (`selezione.jsonl`): raggruppa, allinea, distribuisci, blocca, livelli e
/// appunti, rifatti col motore e confrontati con lo stato che ha prodotto il desktop.
void main() {
  for (final caso in leggiJsonl('selezione.jsonl')) {
    final id = caso['id']! as String;
    test('selezione $id', () {
      final prima = StatoDesktop.fromJson(
        caso['prima']! as Map<String, Object?>,
      );
      final ctx = prima.contesto();
      var s = prima.snapshot;
      AppuntiElementi? appunti;
      var ripetizione = 0;
      for (final azione in (caso['azioni']! as List).cast<List<Object?>>()) {
        final op = azione[0]! as String;
        final a = (azione[1]! as List).cast<Object?>();
        if (op == 'paste') {
          ripetizione++;
          final r = incollaElementi(
            s,
            appunti!,
            a[0]! as int,
            ripetizione,
            ctx,
          );
          s = r.risultato.snapshot;
          continue;
        }
        final refs = [
          for (final r in (a[0]! as List).cast<List<Object?>>())
            (
              tipo: switch (r[0]) {
                'text' => ElementKind.text,
                'shape' => ElementKind.shape,
                _ => ElementKind.photo,
              },
              uid: r[1]! as int,
            ),
        ];
        switch (op) {
          case 'group':
            s = raggruppa(s, refs) ?? s;
          case 'ungroup':
            s = separa(s, refs) ?? s;
          case 'toggle_lock':
            s = alternaBloccoPosizione(s, refs)?.snapshot ?? s;
          case 'front':
            s = portaDavanti(s, refs);
          case 'back':
            s = mandaDietro(s, refs);
          case 'align':
            s = allinea(s, refs, _come(a[1]! as String), ctx);
          case 'distribute':
            s =
                distribuisci(s, refs, orizzontale: a[1]! as bool, ctx: ctx) ??
                s;
          case 'copy':
            appunti = copiaElementi(s, refs, ctx);
            ripetizione = 0;
          case 'cut':
            appunti = copiaElementi(s, refs, ctx);
            s = eliminaElementi(s, refs);
            ripetizione = -1; // L'originale non c'è più: il primo incolla lo rimette dov'era
          default:
            throw ArgumentError(op);
        }
      }
      final errori = confrontaStati(
        s,
        caso['dopo']! as Map<String, Object?>,
        prima.snapshot,
      );
      expect(errori, isEmpty, reason: '$id\n${errori.take(15).join('\n')}');
    });
  }

  test('gli appunti passano per JSON (anche tra progetti)', () {
    final prima = StatoDesktop.fromJson(
      leggiJsonl('selezione.jsonl').first['prima']! as Map<String, Object?>,
    );
    final ctx = prima.contesto();
    final s = prima.snapshot;
    final refs = [for (final e in s.allElements.take(5)) rifDi(e)];
    final a = copiaElementi(s, refs, ctx)!;
    final b = AppuntiElementi.fromJson(a.toJson())!;
    expect(b.numero, 5);
    expect(b.pagina, a.pagina);
    expect(b.toJson(), a.toJson());
    expect(
      AppuntiElementi.fromJson(<String, Object?>{'elements': <Object?>[]}),
      isNull,
    );
    expect(AppuntiElementi.fromJson('niente'), isNull);
  });

  test(
    'un solo elemento si allinea alla sua pagina; meno di 2 non si raggruppa',
    () {
      final prima = StatoDesktop.fromJson(
        leggiJsonl('selezione.jsonl').first['prima']! as Map<String, Object?>,
      );
      final s = prima.snapshot;
      final uno = [rifDi(s.items.first)];
      expect(raggruppa(s, uno), isNull);
      expect(separa(s, uno), isNull);
      expect(
        distribuisci(s, uno, orizzontale: true, ctx: prima.contesto()),
        isNull,
      );
      expect(alternaBloccoPosizione(s, const <RifElemento>[]), isNull);
    },
  );
}

Allineamento _come(String how) => switch (how) {
  'left' => Allineamento.sinistra,
  'hcenter' => Allineamento.centroOrizzontale,
  'right' => Allineamento.destra,
  'top' => Allineamento.alto,
  'vcenter' => Allineamento.centroVerticale,
  _ => Allineamento.basso,
};
