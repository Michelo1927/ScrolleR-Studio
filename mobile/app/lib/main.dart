/// ScrolleR Studio Mobile: punto di avvio dell'app.
library;

import 'package:material_ui/material_ui.dart';

import 'home/home.dart';
import 'l10n/app_localizations.dart';
import 'theme/tema.dart';
import 'theme/tokens.dart';

void main() {
  runApp(const ScrollerStudioApp());
}

/// Radice dell'app: tema scuro unico, testi in italiano (principale) e inglese.
class ScrollerStudioApp extends StatelessWidget {
  const ScrollerStudioApp({super.key, this.lingua});

  /// Lingua forzata (per le prove); `null` segue quella del telefono.
  final Locale? lingua;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => Testi.of(context).appTitolo,
      debugShowCheckedModeBanner: false,
      theme: temaScrl(),
      locale: lingua,
      supportedLocales: Testi.supportedLocales,
      // Materiale, Cupertino e widget: tutti i testi di sistema in italiano e inglese
      localizationsDelegates: const [
        Testi.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      // Il testo segue la dimensione di sistema fino a 1,3× (piano §4.7)
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: TestoScrl.scalaMassima,
        child: child!,
      ),
      home: const HomePage(),
    );
  }
}
