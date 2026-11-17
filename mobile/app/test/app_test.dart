import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrollr_studio/main.dart';
import 'package:scrollr_studio/project/archivio.dart';
import 'package:scrollr_studio/project/provider.dart';
import 'package:scrollr_studio/theme/tokens.dart';

/// App con un archivio vuoto in una cartella temporanea.
Widget _app(Locale lingua) {
  final radice = Directory.systemTemp.createTempSync('scrl_app_test');
  addTearDown(() => radice.deleteSync(recursive: true));
  return ProviderScope(
    overrides: [archivioProvider.overrideWithValue(ArchivioProgetti(radice))],
    child: ScrollerStudioApp(lingua: lingua),
  );
}

void main() {
  testWidgets('Home vuota in italiano', (tester) async {
    await tester.pumpWidget(_app(const Locale('it')));
    await tester.pumpAndSettle();
    expect(find.text('Nessun progetto'), findsOneWidget);
    expect(find.text('Nuovo'), findsOneWidget);
  });

  testWidgets('Home vuota in inglese', (tester) async {
    await tester.pumpWidget(_app(const Locale('en')));
    await tester.pumpAndSettle();
    expect(find.text('No projects'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
  });

  testWidgets('Tema scuro con un solo accento dai token', (tester) async {
    await tester.pumpWidget(_app(const Locale('it')));
    final tema = Theme.of(tester.element(find.byType(Scaffold)));
    expect(tema.brightness, Brightness.dark);
    expect(tema.colorScheme.primary, ColoriScrl.accento);
    expect(tema.scaffoldBackgroundColor, ColoriScrl.fondo);
  });

  testWidgets('Nuovo apre la scelta del formato con le sagome', (tester) async {
    await tester.pumpWidget(_app(const Locale('it')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nuovo'));
    await tester.pumpAndSettle();
    expect(find.text('Formato'), findsWidgets);
    expect(find.text('3:4 verticale'), findsOneWidget);
    expect(find.text('Personalizzato'), findsOneWidget);
    // Il personalizzato mostra le due misure, dentro la pagina (niente finestre)
    await tester.ensureVisible(find.text('Personalizzato'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personalizzato'));
    await tester.pumpAndSettle();
    expect(find.text('Larghezza (px)'), findsOneWidget);
    expect(find.text('Altezza (px)'), findsOneWidget);
  });
}
