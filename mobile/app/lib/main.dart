/// ScrolleR Studio Mobile: punto di avvio dell'app.
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'export/preferenze.dart';
import 'home/home.dart';
import 'home/scambio_ui.dart';
import 'l10n/app_localizations.dart';
import 'media/pulizia.dart';
import 'project/archivio.dart';
import 'project/provider.dart';
import 'render/caratteri.dart';
import 'settings/aggiornamenti.dart';
import 'settings/registro_errori.dart';
import 'theme/tema.dart';
import 'theme/tokens.dart';

/// Tetto della cache delle immagini decodificate dell'interfaccia, in megabyte.
const int limiteImmaginiInterfacciaMb = 64;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registraLicenzeCaratteri();
  final documenti = await getApplicationDocumentsDirectory();
  final versione = (await PackageInfo.fromPlatform()).version;
  // Registro degli errori (Fase 10): resta sul telefono, si condivide da Impostazioni
  final registro = RegistroErrori(
    File('${documenti.path}/errori.log'),
    versione: versione,
    radice: documenti.parent.path,
  );
  await registro.avvia();
  final erroreFlutter = FlutterError.onError;
  FlutterError.onError = (dettagli) {
    registro.registra(dettagli.exception, dettagli.stack, contesto: 'Flutter');
    // Si lascia il comportamento di sempre (console in sviluppo)
    if (erroreFlutter != null) {
      erroreFlutter(dettagli);
    } else {
      FlutterError.presentError(dettagli);
    }
  };
  // Errori asincroni fuori dal framework: registrati, e l'app continua a funzionare
  PlatformDispatcher.instance.onError = (errore, traccia) {
    registro.registra(errore, traccia, contesto: 'Asincrono');
    return true;
  };
  final preferenze = PreferenzeApp(File('${documenti.path}/impostazioni.json'));
  // Memoria: le immagini decodificate dell'interfaccia (miniature della Home) hanno un tetto più basso del predefinito
  // (100 MB, 1000 immagini): le foto vere stanno nella cache a livelli di `CacheMedia`, che ha il suo limite
  final cacheImmagini = PaintingBinding.instance.imageCache;
  cacheImmagini.maximumSizeBytes = limiteImmaginiInterfacciaMb * 1024 * 1024;
  cacheImmagini.maximumSize = 200;
  // Spazio: via ciò che un'esportazione o uno scambio interrotti hanno lasciato in temporanea, senza bloccare l'avvio
  unawaited(
    getTemporaryDirectory()
        .then(puliziaTemporanei)
        .then<void>((_) {})
        .catchError((Object _) {}),
  );
  runApp(
    ProviderScope(
      overrides: [
        archivioProvider.overrideWithValue(
          ArchivioProgetti(Directory('${documenti.path}/progetti')),
        ),
        preferenzeProvider.overrideWithValue(preferenze),
        registroErroriProvider.overrideWithValue(registro),
        versioneAppProvider.overrideWithValue(versione),
        // La rete serve solo al controllo degli aggiornamenti (piano §14)
        scaricaTestoProvider.overrideWithValue(
          (indirizzo) => scaricaTestoDaRete(indirizzo, versione: versione),
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
      builder: (context, child) {
        final testo = MediaQuery.withClampedTextScaling(
          maxScaleFactor: TestoScrl.scalaMassima,
          child: child!,
        );
        // «Riduci animazioni» del sistema: anche i cambi di schermata diventano istantanei (piano §4.7)
        return MediaQuery.disableAnimationsOf(context)
            ? Theme(data: temaSenzaMovimento(Theme.of(context)), child: testo)
            : testo;
      },
      home: const AscoltaFileRicevuti(child: HomePage()),
    );
  }
}
