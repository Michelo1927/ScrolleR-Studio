import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of Testi
/// returned by `Testi.of(context)`.
///
/// Applications need to include `Testi.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: Testi.localizationsDelegates,
///   supportedLocales: Testi.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the Testi.supportedLocales
/// property.
abstract class Testi {
  Testi(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static Testi of(BuildContext context) {
    return Localizations.of<Testi>(context, Testi)!;
  }

  static const LocalizationsDelegate<Testi> delegate = _TestiDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it'),
  ];

  /// Nome dell'app
  ///
  /// In it, this message translates to:
  /// **'ScrolleR Studio'**
  String get appTitolo;

  /// Home senza progetti
  ///
  /// In it, this message translates to:
  /// **'Nessun progetto'**
  String get homeVuotaTitolo;

  /// Riga di aiuto sotto la Home vuota
  ///
  /// In it, this message translates to:
  /// **'Crea il tuo primo carosello'**
  String get homeVuotaAiuto;

  /// Pulsante principale della Home
  ///
  /// In it, this message translates to:
  /// **'Nuovo'**
  String get nuovoProgetto;

  /// Messaggio breve per le funzioni non ancora pronte
  ///
  /// In it, this message translates to:
  /// **'In arrivo nelle prossime versioni'**
  String get inArrivo;

  /// Pulsante della Home che apre le prove della Fase 2
  ///
  /// In it, this message translates to:
  /// **'Prove'**
  String get proveApri;

  /// Titolo della schermata delle prove
  ///
  /// In it, this message translates to:
  /// **'Prove della Fase 2'**
  String get proveTitolo;

  /// Sezione delle prove sulla galleria
  ///
  /// In it, this message translates to:
  /// **'Galleria'**
  String get proveGalleria;

  /// Permesso completo alla galleria
  ///
  /// In it, this message translates to:
  /// **'Accesso a tutte le foto e i video'**
  String get accessoCompleto;

  /// Permesso parziale alla galleria
  ///
  /// In it, this message translates to:
  /// **'Accesso solo alle foto e ai video scelti'**
  String get accessoParziale;

  /// Permesso alla galleria negato
  ///
  /// In it, this message translates to:
  /// **'Nessun accesso alla galleria'**
  String get accessoNegato;

  /// Riga che spiega perché serve il permesso, prima di chiederlo
  ///
  /// In it, this message translates to:
  /// **'Le foto restano nella galleria: il progetto le collega senza copiarle.'**
  String get accessoDaChiedere;

  /// Pulsante che chiede il permesso alla galleria
  ///
  /// In it, this message translates to:
  /// **'Consenti accesso'**
  String get consentiAccesso;

  /// Accesso parziale: aggiunge altre foto concesse
  ///
  /// In it, this message translates to:
  /// **'Scegli altre foto'**
  String get scegliAltreFoto;

  /// Permesso negato: apre le impostazioni dell'app
  ///
  /// In it, this message translates to:
  /// **'Apri impostazioni'**
  String get apriImpostazioni;

  /// Permesso negato: sceglie foto e video col selettore di sistema e li copia nel progetto
  ///
  /// In it, this message translates to:
  /// **'Scegli dal telefono'**
  String get scegliDalTelefono;

  /// Quanti file scelti col selettore di sistema sono stati copiati in media/
  ///
  /// In it, this message translates to:
  /// **'{n, plural, =1{1 file copiato nel progetto} other{{n} file copiati nel progetto}}'**
  String fileCopiati(int n);

  /// Crea una pagina di prova con gli elementi scelti
  ///
  /// In it, this message translates to:
  /// **'Crea pagina'**
  String get creaPagina;

  /// Esporta in MP4 una pagina con un video
  ///
  /// In it, this message translates to:
  /// **'Esporta MP4'**
  String get esportaVideo;

  /// Sezione con i progetti .scrlproj copiati sul telefono
  ///
  /// In it, this message translates to:
  /// **'Progetti dal computer'**
  String get progettiDiProva;

  /// Dove copiare i progetti di prova
  ///
  /// In it, this message translates to:
  /// **'Copia ogni progetto in una sua cartella (con .scrlproj e media/) in: {cartella}'**
  String progettiDiProvaAiuto(String cartella);

  /// Titolo della vista di una pagina
  ///
  /// In it, this message translates to:
  /// **'Pagina {numero} di {totale}'**
  String paginaDiTotale(int numero, int totale);

  /// Segnaposto di una foto non trovata
  ///
  /// In it, this message translates to:
  /// **'Foto mancante'**
  String get fotoMancante;

  /// Segno su una foto il cui originale non c'è più
  ///
  /// In it, this message translates to:
  /// **'Originale mancante'**
  String get originaleMancante;

  /// Parola del formato «1 di 5» dei numeri di pagina
  ///
  /// In it, this message translates to:
  /// **'di'**
  String get numeroPaginaDi;

  /// Titolo dell'avanzamento dell'esportazione
  ///
  /// In it, this message translates to:
  /// **'Esportazione MP4…'**
  String get esportazioneInCorso;

  /// Pulsante per annullare
  ///
  /// In it, this message translates to:
  /// **'Annulla'**
  String get annulla;

  /// Esito dell'esportazione MP4
  ///
  /// In it, this message translates to:
  /// **'MP4 salvato nella galleria: {fotogrammi} fotogrammi, {ms} ms per fotogramma'**
  String videoFatto(int fotogrammi, String ms);

  /// Errore dell'esportazione MP4
  ///
  /// In it, this message translates to:
  /// **'Esportazione non riuscita: {errore}'**
  String videoErrore(String errore);

  /// Esportazione MP4 annullata
  ///
  /// In it, this message translates to:
  /// **'Esportazione annullata'**
  String get videoAnnullato;

  /// Il plugin video non funziona su questa piattaforma
  ///
  /// In it, this message translates to:
  /// **'I video non sono ancora disponibili su questo telefono'**
  String get videoNonDisponibile;

  /// Esporta MP4 senza video scelti
  ///
  /// In it, this message translates to:
  /// **'Scegli almeno un video'**
  String get scegliUnVideo;

  /// Errore nell'aprire un .scrlproj
  ///
  /// In it, this message translates to:
  /// **'Progetto non leggibile'**
  String get progettoNonValido;
}

class _TestiDelegate extends LocalizationsDelegate<Testi> {
  const _TestiDelegate();

  @override
  Future<Testi> load(Locale locale) {
    return SynchronousFuture<Testi>(lookupTesti(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_TestiDelegate old) => false;
}

Testi lookupTesti(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return TestiEn();
    case 'it':
      return TestiIt();
  }

  throw FlutterError(
    'Testi.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
