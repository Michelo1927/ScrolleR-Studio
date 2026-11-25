/// Aiuti delle prove per i menu a due livelli: la barra di selezione (categorie → strumenti) e i pannelli con la
/// griglia delle schede (‹ per tornarci).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrollr_studio/editor/barra_selezione.dart';
import 'package:scrollr_studio/editor/widget_comuni.dart';

/// Categorie che agiscono subito, senza aprire un secondo livello.
const _dirette = {
  'cat-modifica',
  'cat-tipo',
  'cat-ricollega',
  'cat-sottotitoli',
};

final Finder _indietro = find.byKey(const ValueKey('barra-indietro'));

/// La voce [voce] nel livello aperto della barra (non il nome della categoria accanto a ‹).
Finder _inBarra(String voce) => find.descendant(
  of: find.byType(BarraSelezione),
  matching: find.widgetWithText(VoceBarra, voce),
);

/// Le categorie della barra, con prima quella che si chiama come [voce].
List<VoceBarra> _categorie([String? voce]) {
  final f = find.descendant(
    of: find.byType(BarraSelezione),
    matching: find.byWidgetPredicate(
      (w) =>
          w is VoceBarra &&
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('cat-'),
    ),
  );
  final c = [for (final e in f.evaluate()) e.widget as VoceBarra];
  c.sort(
    (a, b) =>
        (a.etichetta == voce ? 0 : 1).compareTo(b.etichetta == voce ? 0 : 1),
  );
  return c;
}

String _chiave(VoceBarra v) => (v.key! as ValueKey<String>).value;

/// Riporta la barra di selezione alle categorie.
Future<void> categorieBarra(WidgetTester tester) async {
  if (_indietro.evaluate().isNotEmpty) {
    await tester.tap(_indietro);
    await tester.pump();
  }
}

/// Tocca la voce [voce] della barra di selezione: entra nella categoria che la contiene (o tocca la categoria, se
/// agisce subito).
Future<void> toccaVoceBarra(
  WidgetTester tester,
  String voce, {
  bool settle = true,
}) async {
  Future<void> fine() async {
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  if (_indietro.evaluate().isNotEmpty) {
    if (_inBarra(voce).evaluate().isNotEmpty) {
      await tester.tap(_inBarra(voce).first);
      return fine();
    }
    await categorieBarra(tester);
  }
  for (final c in _categorie(voce)) {
    final diretta = _dirette.contains(_chiave(c));
    if (diretta && c.etichetta != voce) continue;
    await tester.tap(find.byKey(c.key!));
    if (diretta) return fine();
    await tester.pump();
    if (_inBarra(voce).evaluate().isNotEmpty) {
      await tester.tap(_inBarra(voce).first);
      return fine();
    }
    await categorieBarra(tester);
  }
  throw TestFailure('Voce «$voce» non trovata nella barra di selezione');
}

/// Tutti i nomi raggiungibili dalla barra di selezione (le categorie dirette e le voci delle altre).
Future<Set<String>> vociBarra(WidgetTester tester) async {
  await categorieBarra(tester);
  final voci = <String>{};
  for (final c in _categorie()) {
    if (_dirette.contains(_chiave(c))) {
      voci.add(c.etichetta);
      continue;
    }
    await tester.tap(find.byKey(c.key!));
    await tester.pump();
    for (final e
        in find
            .descendant(
              of: find.byType(BarraSelezione),
              matching: find.byType(VoceBarra),
            )
            .evaluate()) {
      voci.add((e.widget as VoceBarra).etichetta);
    }
    await categorieBarra(tester);
  }
  return voci;
}

/// Tocca [f] nel pannello aperto: se è nella griglia delle schede ci torna con ‹, se è in una fila che scorre la fa
/// scorrere fino a vederlo.
Future<void> toccaNelPannello(
  WidgetTester tester,
  Finder f, {
  bool settle = true,
}) async {
  final indietro = find.byKey(const ValueKey('scheda-indietro'));
  if (f.evaluate().isEmpty && indietro.evaluate().isNotEmpty) {
    await tester.tap(indietro);
    await tester.pump();
  }
  if (f.evaluate().isEmpty) {
    final liste = find.descendant(
      of: find.byType(PannelloBasso),
      matching: find.byType(Scrollable),
    );
    for (final l in liste.evaluate().toList()) {
      final lista = find.byWidget(l.widget);
      await tester.drag(lista, const Offset(10000, 0));
      await tester.pump();
      try {
        await tester.scrollUntilVisible(f, 80, scrollable: lista);
        break;
      } on StateError {
        // Non è in questa fila
      }
    }
  }
  await tester.ensureVisible(f.first);
  await tester.pump();
  await tester.tap(f.first);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}
