/// ScrolleR Studio Mobile: punto di avvio dell'app.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'home/home.dart';
import 'l10n/app_localizations.dart';
import 'project/archivio.dart';
import 'project/provider.dart';
import 'render/caratteri.dart';
import 'theme/tema.dart';
import 'theme/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registraLicenzeCaratteri();
  final documenti = await getApplicationDocumentsDirectory();
  runApp(
    ProviderScope(
      overrides: [
        archivioProvider.overrideWithValue(
          ArchivioProgetti(Directory('${documenti.path}/progetti')),
        ),
      ],
      child: const ScrollerStudioApp(),
    ),
  );
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
