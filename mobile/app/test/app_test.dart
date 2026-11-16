import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrollr_studio/main.dart';
import 'package:scrollr_studio/theme/tokens.dart';

void main() {
  testWidgets('Home vuota in italiano', (tester) async {
    await tester.pumpWidget(const ScrollerStudioApp(lingua: Locale('it')));
    await tester.pumpAndSettle();
    expect(find.text('Nessun progetto'), findsOneWidget);
    expect(find.text('Nuovo'), findsOneWidget);
  });

  testWidgets('Home vuota in inglese', (tester) async {
    await tester.pumpWidget(const ScrollerStudioApp(lingua: Locale('en')));
    await tester.pumpAndSettle();
    expect(find.text('No projects'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
  });

  testWidgets('Tema scuro con un solo accento dai token', (tester) async {
    await tester.pumpWidget(const ScrollerStudioApp(lingua: Locale('it')));
    final tema = Theme.of(tester.element(find.byType(Scaffold)));
    expect(tema.brightness, Brightness.dark);
    expect(tema.colorScheme.primary, ColoriScrl.accento);
    expect(tema.scaffoldBackgroundColor, ColoriScrl.fondo);
  });
}
