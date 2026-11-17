import 'dart:ui' show Tristate;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrollr_studio/editor/widget_comuni.dart';
import 'package:scrollr_studio/export/preferenze.dart';
import 'package:scrollr_studio/l10n/app_localizations.dart';
import 'package:scrollr_studio/theme/tema.dart';

Widget _casa(Widget child) => ProviderScope(
  overrides: [preferenzeProvider.overrideWithValue(PreferenzeApp.inMemoria())],
  child: MaterialApp(
    theme: temaScrl(),
    locale: const Locale('it'),
    supportedLocales: Testi.supportedLocales,
    localizationsDelegates: const [
      Testi.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    home: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('il cursore a righello mostra il valore sopra il marcatore', (
    tester,
  ) async {
    var v = 12;
    var finito = 0;
    await tester.pumpWidget(
      _casa(
        StatefulBuilder(
          builder: (context, setState) => CursoreGrande(
            valore: v.toDouble(),
            minimo: -100,
            massimo: 100,
            iniziale: 0,
            daCentro: true,
            etichetta: 'Luminosità',
            onCambia: (n) => setState(() => v = n),
            onFine: () => finito++,
          ),
        ),
      ),
    );
    expect(find.text('+12'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    // Il righello occupa la stessa zona di sempre (48 dp): si regola solo lì, non su tutta la schermata
    expect(tester.getSize(find.byType(Slider)).height, 48);
    final r = tester.getRect(find.byType(Slider));
    double x(double f) => r.left + 24 + (r.width - 48) * f;
    final g = await tester.startGesture(Offset(x(0.56), r.center.dy));
    await g.moveTo(Offset(x(0.75), r.center.dy));
    await g.up();
    await tester.pump(const Duration(milliseconds: 400));
    expect(v, 50);
    expect(find.text('+50'), findsOneWidget);
    expect(finito, 1);
    // Doppio tocco = valore iniziale
    await tester.tap(find.byType(Slider));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(Slider));
    await tester.pump(const Duration(milliseconds: 400));
    expect(v, 0);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('il controllo segmentato sceglie una voce alla volta', (
    tester,
  ) async {
    var scelto = 'b';
    final semantica = tester.ensureSemantics();
    await tester.pumpWidget(
      _casa(
        StatefulBuilder(
          builder: (context, setState) => ControlloSegmentato<String>(
            voci: const [
              VoceSegmento(
                valore: 'a',
                etichetta: 'Uno',
                chiave: ValueKey('a'),
              ),
              VoceSegmento(
                valore: 'b',
                etichetta: 'Due',
                chiave: ValueKey('b'),
              ),
            ],
            scelto: scelto,
            onScelto: (v) => setState(() => scelto = v),
          ),
        ),
      ),
    );
    Tristate scelta(String k) => tester.semantics
        .find(find.byKey(ValueKey(k)))
        .flagsCollection
        .isSelected;
    expect(scelta('b'), Tristate.isTrue);
    await tester.tap(find.byKey(const ValueKey('a')));
    await tester.pumpAndSettle();
    expect(scelto, 'a');
    expect(scelta('a'), Tristate.isTrue);
    semantica.dispose();
  });
}
