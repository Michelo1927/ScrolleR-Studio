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

  /// Azione di un progetto nella Home
  ///
  /// In it, this message translates to:
  /// **'Rinomina'**
  String get rinomina;

  /// Azione: copia un progetto o un elemento
  ///
  /// In it, this message translates to:
  /// **'Duplica'**
  String get duplica;

  /// Azione distruttiva
  ///
  /// In it, this message translates to:
  /// **'Elimina'**
  String get elimina;

  /// Nome di un progetto duplicato
  ///
  /// In it, this message translates to:
  /// **'Copia di {nome}'**
  String copiaDi(String nome);

  /// Conferma di eliminazione di un progetto
  ///
  /// In it, this message translates to:
  /// **'Eliminare «{nome}»?'**
  String eliminaProgettoChiede(String nome);

  /// Spiegazione della conferma di eliminazione
  ///
  /// In it, this message translates to:
  /// **'Il progetto sparisce da questo telefono. Le foto della galleria non vengono toccate.'**
  String get eliminaProgettoAiuto;

  /// Campo per rinominare un progetto
  ///
  /// In it, this message translates to:
  /// **'Nome del progetto'**
  String get nomeProgetto;

  /// Conferma di un campo di testo
  ///
  /// In it, this message translates to:
  /// **'Fatto'**
  String get fatto;

  /// Numero di pagine di un progetto
  ///
  /// In it, this message translates to:
  /// **'{n, plural, =1{1 pagina} other{{n} pagine}}'**
  String numeroPagine(int n);

  /// Nome di partenza di un progetto nuovo
  ///
  /// In it, this message translates to:
  /// **'Progetto {n}'**
  String nomeProgettoNuovo(int n);

  /// Primo passo di Nuovo progetto
  ///
  /// In it, this message translates to:
  /// **'Formato'**
  String get passoFormato;

  /// Secondo passo di Nuovo progetto e titolo della scelta foto
  ///
  /// In it, this message translates to:
  /// **'Scegli le foto'**
  String get passoFoto;

  /// Pulsante che crea il progetto
  ///
  /// In it, this message translates to:
  /// **'{n, plural, =0{Crea} =1{Crea con 1 foto} other{Crea con {n} foto}}'**
  String creaConFoto(int n);

  /// Formato della pagina n. 0 (come ASPECT_RATIOS del desktop)
  ///
  /// In it, this message translates to:
  /// **'3:4 verticale'**
  String get formato0;

  /// Formato della pagina n. 1 (come ASPECT_RATIOS del desktop)
  ///
  /// In it, this message translates to:
  /// **'4:3 orizzontale'**
  String get formato1;

  /// Formato della pagina n. 2 (come ASPECT_RATIOS del desktop)
  ///
  /// In it, this message translates to:
  /// **'4:5 Instagram'**
  String get formato2;

  /// Formato della pagina n. 3 (come ASPECT_RATIOS del desktop)
  ///
  /// In it, this message translates to:
  /// **'1:1 quadrato'**
  String get formato3;

  /// Formato della pagina n. 4 (come ASPECT_RATIOS del desktop)
  ///
  /// In it, this message translates to:
  /// **'9:16 storia'**
  String get formato4;

  /// Formato della pagina n. 5 (come ASPECT_RATIOS del desktop)
  ///
  /// In it, this message translates to:
  /// **'16:9 panoramico'**
  String get formato5;

  /// Formato della pagina n. 6 (come ASPECT_RATIOS del desktop)
  ///
  /// In it, this message translates to:
  /// **'2:3 foto verticale'**
  String get formato6;

  /// Formato della pagina n. 7 (come ASPECT_RATIOS del desktop)
  ///
  /// In it, this message translates to:
  /// **'3:2 foto orizzontale'**
  String get formato7;

  /// Formato della pagina n. 8 (come ASPECT_RATIOS del desktop)
  ///
  /// In it, this message translates to:
  /// **'Personalizzato'**
  String get formato8;

  /// Misura personalizzata della pagina
  ///
  /// In it, this message translates to:
  /// **'Larghezza (px)'**
  String get larghezzaPixel;

  /// Misura personalizzata della pagina
  ///
  /// In it, this message translates to:
  /// **'Altezza (px)'**
  String get altezzaPixel;

  /// Riga di aiuto del passo Formato
  ///
  /// In it, this message translates to:
  /// **'Il formato vale per ogni pagina del carosello.'**
  String get formatoAiuto;

  /// Va al passo dopo
  ///
  /// In it, this message translates to:
  /// **'Continua'**
  String get continua;

  /// Salta la scelta delle foto
  ///
  /// In it, this message translates to:
  /// **'Salta'**
  String get salta;

  /// Etichetta per i lettori di schermo di una miniatura
  ///
  /// In it, this message translates to:
  /// **'Foto {n}'**
  String fotoNumero(int n);

  /// Pulsante che aggiunge le foto scelte
  ///
  /// In it, this message translates to:
  /// **'{n, plural, =0{Aggiungi} =1{Aggiungi 1 foto} other{Aggiungi {n} foto}}'**
  String aggiungiNFoto(int n);

  /// Etichetta per i lettori di schermo della tela
  ///
  /// In it, this message translates to:
  /// **'Tela'**
  String get tela;

  /// Etichetta sopra la pagina
  ///
  /// In it, this message translates to:
  /// **'Pagina {n}'**
  String etichettaPagina(int n);

  /// Etichetta sopra una pagina bloccata
  ///
  /// In it, this message translates to:
  /// **'Bloccata'**
  String get etichettaBloccata;

  /// Etichetta sopra una pagina unita «a cavallo»
  ///
  /// In it, this message translates to:
  /// **'A cavallo {a}–{b}'**
  String etichettaACavallo(int a, int b);

  /// Foto presenti in una pagina
  ///
  /// In it, this message translates to:
  /// **'{n, plural, =0{Nessuna foto} =1{1 foto} other{{n} foto}}'**
  String etichettaFoto(int n);

  /// Invito sulla pagina vuota
  ///
  /// In it, this message translates to:
  /// **'Tocca ＋ per aggiungere le foto'**
  String get paginaVuota;

  /// Torna alla Home
  ///
  /// In it, this message translates to:
  /// **'Indietro'**
  String get indietro;

  /// Ripeti l'ultimo passo annullato
  ///
  /// In it, this message translates to:
  /// **'Ripeti'**
  String get ripeti;

  /// Anteprima del carosello a schermo intero
  ///
  /// In it, this message translates to:
  /// **'Anteprima'**
  String get anteprima;

  /// Esporta il carosello
  ///
  /// In it, this message translates to:
  /// **'Esporta'**
  String get esporta;

  /// Freccia della striscia pagine
  ///
  /// In it, this message translates to:
  /// **'Pagina precedente'**
  String get paginaPrecedente;

  /// Freccia della striscia pagine
  ///
  /// In it, this message translates to:
  /// **'Pagina successiva'**
  String get paginaSuccessiva;

  /// Puntino della striscia pagine
  ///
  /// In it, this message translates to:
  /// **'Vai alla pagina {n}'**
  String vaiAllaPagina(int n);

  /// Griglia di tutte le pagine
  ///
  /// In it, this message translates to:
  /// **'Panoramica'**
  String get panoramica;

  /// Voce della barra inferiore: libreria
  ///
  /// In it, this message translates to:
  /// **'Foto'**
  String get barraFoto;

  /// Voce della barra inferiore
  ///
  /// In it, this message translates to:
  /// **'Disposizione'**
  String get barraDisposizione;

  /// Voce della barra inferiore (＋)
  ///
  /// In it, this message translates to:
  /// **'Aggiungi'**
  String get barraAggiungi;

  /// Voce della barra inferiore
  ///
  /// In it, this message translates to:
  /// **'Pagine'**
  String get barraPagine;

  /// Voce della barra inferiore
  ///
  /// In it, this message translates to:
  /// **'Stile'**
  String get barraStile;

  /// Toglie la selezione
  ///
  /// In it, this message translates to:
  /// **'Deseleziona'**
  String get deseleziona;

  /// Rimette la foto libera nella disposizione
  ///
  /// In it, this message translates to:
  /// **'In disposizione'**
  String get inDisposizione;

  /// Rende libera la foto: la disposizione non la tocca
  ///
  /// In it, this message translates to:
  /// **'Libera'**
  String get libera;

  /// Conferma di uno strumento (✓)
  ///
  /// In it, this message translates to:
  /// **'Conferma'**
  String get conferma;

  /// Chiude un pannello
  ///
  /// In it, this message translates to:
  /// **'Chiudi'**
  String get chiudi;

  /// Nome dello strumento Disposizione
  ///
  /// In it, this message translates to:
  /// **'Disposizione'**
  String get strumentoDisposizione;

  /// Parametro: la disposizione
  ///
  /// In it, this message translates to:
  /// **'Disposizione'**
  String get parDisposizione;

  /// Parametro: stile del mosaico
  ///
  /// In it, this message translates to:
  /// **'Mosaico'**
  String get parMosaico;

  /// Parametro: numero di pagine
  ///
  /// In it, this message translates to:
  /// **'Pagine'**
  String get parPagine;

  /// Parametro
  ///
  /// In it, this message translates to:
  /// **'Foto per pagina'**
  String get parFotoPerPagina;

  /// Parametro: foto nella pagina corrente
  ///
  /// In it, this message translates to:
  /// **'Foto qui'**
  String get parFotoQui;

  /// Parametro (0–80)
  ///
  /// In it, this message translates to:
  /// **'Spaziatura'**
  String get parSpaziatura;

  /// Parametro (0–120)
  ///
  /// In it, this message translates to:
  /// **'Margine'**
  String get parMargine;

  /// Valore automatico
  ///
  /// In it, this message translates to:
  /// **'Auto'**
  String get auto;

  /// Interruttore: una disposizione per ogni pagina
  ///
  /// In it, this message translates to:
  /// **'Una per pagina'**
  String get unaPerPagina;

  /// Rimescola l'ordine delle foto
  ///
  /// In it, this message translates to:
  /// **'Rimescola'**
  String get rimescola;

  /// Numero di foto
  ///
  /// In it, this message translates to:
  /// **'{n, plural, =1{1 foto} other{{n} foto}}'**
  String numeroFoto(int n);

  /// Per i lettori di schermo
  ///
  /// In it, this message translates to:
  /// **'Una pagina in meno'**
  String get menoPagine;

  /// Per i lettori di schermo
  ///
  /// In it, this message translates to:
  /// **'Una pagina in più'**
  String get piuPagine;

  /// Per i lettori di schermo
  ///
  /// In it, this message translates to:
  /// **'Una foto in meno'**
  String get menoFoto;

  /// Per i lettori di schermo
  ///
  /// In it, this message translates to:
  /// **'Una foto in più'**
  String get piuFoto;

  /// Ambito della disposizione
  ///
  /// In it, this message translates to:
  /// **'Tutto il carosello'**
  String get ambitoTutto;

  /// Ambito della disposizione
  ///
  /// In it, this message translates to:
  /// **'Solo questa pagina'**
  String get ambitoPagina;

  /// Nome di una disposizione (come LAYOUTS del desktop)
  ///
  /// In it, this message translates to:
  /// **'Griglia'**
  String get dispGriglia;

  /// Nome di una disposizione (come LAYOUTS del desktop)
  ///
  /// In it, this message translates to:
  /// **'Mosaico'**
  String get dispMosaico;

  /// Nome di una disposizione (come LAYOUTS del desktop)
  ///
  /// In it, this message translates to:
  /// **'Righe'**
  String get dispRighe;

  /// Nome di una disposizione (come LAYOUTS del desktop)
  ///
  /// In it, this message translates to:
  /// **'Colonne'**
  String get dispColonne;

  /// Nome di una disposizione (come LAYOUTS del desktop)
  ///
  /// In it, this message translates to:
  /// **'Polaroid'**
  String get dispPolaroid;

  /// Nome di una disposizione (come LAYOUTS del desktop)
  ///
  /// In it, this message translates to:
  /// **'A cavallo'**
  String get dispACavallo;

  /// Stile del mosaico (come MOSAIC_STYLES del desktop)
  ///
  /// In it, this message translates to:
  /// **'Automatico'**
  String get stileAutomatico;

  /// Stile del mosaico (come MOSAIC_STYLES del desktop)
  ///
  /// In it, this message translates to:
  /// **'Grande in alto'**
  String get stileInAlto;

  /// Stile del mosaico (come MOSAIC_STYLES del desktop)
  ///
  /// In it, this message translates to:
  /// **'Grande in basso'**
  String get stileInBasso;

  /// Stile del mosaico (come MOSAIC_STYLES del desktop)
  ///
  /// In it, this message translates to:
  /// **'Grande a sinistra'**
  String get stileASinistra;

  /// Stile del mosaico (come MOSAIC_STYLES del desktop)
  ///
  /// In it, this message translates to:
  /// **'Grande a destra'**
  String get stileADestra;

  /// Stile del mosaico (come MOSAIC_STYLES del desktop)
  ///
  /// In it, this message translates to:
  /// **'Grande al centro'**
  String get stileAlCentro;

  /// Stile del mosaico (come MOSAIC_STYLES del desktop)
  ///
  /// In it, this message translates to:
  /// **'Due grandi'**
  String get stileDueGrandi;

  /// Stile del mosaico (come MOSAIC_STYLES del desktop)
  ///
  /// In it, this message translates to:
  /// **'Muratura'**
  String get stileMuratura;

  /// Titolo del pannello Foto
  ///
  /// In it, this message translates to:
  /// **'{n, plural, =1{Libreria · 1 foto} other{Libreria · {n} foto}}'**
  String libreriaTitolo(int n);

  /// Titolo del pannello Foto con una selezione
  ///
  /// In it, this message translates to:
  /// **'{n, plural, =1{1 foto scelta} other{{n} foto scelte}}'**
  String fotoScelte(int n);

  /// Libreria vuota
  ///
  /// In it, this message translates to:
  /// **'Aggiungi le foto dal telefono'**
  String get libreriaVuota;

  /// Azione della libreria
  ///
  /// In it, this message translates to:
  /// **'Aggiungi dal telefono'**
  String get aggiungiDalTelefono;

  /// Azione della libreria
  ///
  /// In it, this message translates to:
  /// **'Aggiungi alla tela'**
  String get aggiungiAllaTela;

  /// Azione della libreria
  ///
  /// In it, this message translates to:
  /// **'Come foto libera'**
  String get comeFotoLibera;

  /// Azione della libreria: sostituisce le foto sulla tela
  ///
  /// In it, this message translates to:
  /// **'Solo queste'**
  String get soloQueste;

  /// Azione della libreria
  ///
  /// In it, this message translates to:
  /// **'Rimuovi dalla libreria'**
  String get rimuoviDallaLibreria;

  /// Azione della libreria: tutte le foto sulla tela
  ///
  /// In it, this message translates to:
  /// **'Metti tutte'**
  String get mettiTutte;

  /// Azione della libreria
  ///
  /// In it, this message translates to:
  /// **'Svuota tela'**
  String get svuotaTela;

  /// Voce del pannello ＋
  ///
  /// In it, this message translates to:
  /// **'Foto o video'**
  String get fotoOVideo;

  /// Voce del pannello ＋
  ///
  /// In it, this message translates to:
  /// **'Pagina nuova'**
  String get paginaNuova;

  /// Voce del pannello ＋: aggiunge un testo
  ///
  /// In it, this message translates to:
  /// **'Testo'**
  String get testo;

  /// Voce del pannello ＋: aggiunge una forma; titolo del pannello delle forme
  ///
  /// In it, this message translates to:
  /// **'Forma'**
  String get forma;

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'{n, plural, =1{1 foto aggiunta} other{{n} foto aggiunte}}'**
  String avvisoFotoAggiunte(int n);

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'Elemento eliminato'**
  String get avvisoEliminato;

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'{n} elementi eliminati'**
  String avvisoEliminati(int n);

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'Elemento duplicato'**
  String get avvisoDuplicato;

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'Tela svuotata'**
  String get avvisoTelaSvuotata;

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'Foto libera: la disposizione non la tocca più'**
  String get avvisoFotoLibera;

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'Foto rimessa nella disposizione'**
  String get avvisoFotoInDisposizione;

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'Pagina aggiunta'**
  String get avvisoPaginaAggiunta;

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'Salvataggio non riuscito: riprovo alla prossima modifica'**
  String get avvisoSalvataggioNonRiuscito;

  /// Avviso del motore
  ///
  /// In it, this message translates to:
  /// **'«A cavallo» ha portato le pagine a {n}'**
  String noticeSeamAddedPages(int n);

  /// Avviso del motore
  ///
  /// In it, this message translates to:
  /// **'Tornate a {n} pagine'**
  String noticeSeamRestoredPages(int n);

  /// Avviso del motore
  ///
  /// In it, this message translates to:
  /// **'Pagina aggiunta per le foto'**
  String get noticeAddedPageForPhotos;

  /// Avviso del motore
  ///
  /// In it, this message translates to:
  /// **'La pagina {n} è bloccata: sbloccala prima'**
  String noticePageLocked(int n);

  /// Avviso del motore
  ///
  /// In it, this message translates to:
  /// **'Le pagine «a cavallo» intorno alla posizione {n} sono bloccate'**
  String noticeSeamPagesLocked(int n);

  /// Avviso del motore
  ///
  /// In it, this message translates to:
  /// **'La pagina {n} è «a cavallo» e bloccata'**
  String noticeSeamPageLocked(int n);

  /// Avviso del motore
  ///
  /// In it, this message translates to:
  /// **'Le pagine {a} e {b} sono «a cavallo» e bloccate: devono restare vicine'**
  String noticeLockedSeamMustStayTogether(int a, int b);

  /// Avviso del motore
  ///
  /// In it, this message translates to:
  /// **'Massimo di {n} pagine raggiunto'**
  String noticeMaxPages(int n);

  /// Avviso del motore
  ///
  /// In it, this message translates to:
  /// **'È l\'unica pagina: non si elimina'**
  String get noticeSinglePage;

  /// Avviso del motore
  ///
  /// In it, this message translates to:
  /// **'C\'è una sola pagina: niente da riordinare'**
  String get noticeNothingToReorder;

  /// Avviso del motore
  ///
  /// In it, this message translates to:
  /// **'La pagina è già al bordo'**
  String get noticePageAtEdge;

  /// Avviso del motore
  ///
  /// In it, this message translates to:
  /// **'È l\'ultima pagina: niente da unire'**
  String get noticeLastPage;

  /// Avviso del motore
  ///
  /// In it, this message translates to:
  /// **'Ci sono pagine bloccate: il formato non si cambia'**
  String get noticeLockedPagesNoResize;

  /// Avviso del motore
  ///
  /// In it, this message translates to:
  /// **'«Foto per pagina» torna su Auto'**
  String get noticePerPageBackToAuto;

  /// Avviso del motore
  ///
  /// In it, this message translates to:
  /// **'Con «A cavallo» le scelte per singola pagina non valgono'**
  String get noticeSeamIgnoresPageSettings;

  /// Avviso del motore
  ///
  /// In it, this message translates to:
  /// **'I video non possono stare a cavallo di due pagine'**
  String get noticeVideoKeptInPage;

  /// Avviso del motore
  ///
  /// In it, this message translates to:
  /// **'Per scambiare servono esattamente 2 foto'**
  String get noticeSwapNeedsTwo;

  /// Strumento Foto: ritaglio a schermo intero
  ///
  /// In it, this message translates to:
  /// **'Ritaglia'**
  String get strRitaglia;

  /// Strumento Foto: zoom e spostamento dentro il riquadro
  ///
  /// In it, this message translates to:
  /// **'Inquadra'**
  String get strInquadra;

  /// Strumento Foto: filtri pronti
  ///
  /// In it, this message translates to:
  /// **'Filtri'**
  String get strFiltri;

  /// Strumento Foto: regolazioni colore
  ///
  /// In it, this message translates to:
  /// **'Regola'**
  String get strRegola;

  /// Strumento Foto: nitidezza, vignettatura, sbiadito, grana
  ///
  /// In it, this message translates to:
  /// **'Effetti'**
  String get strEffetti;

  /// Strumento Foto: angoli e bordo
  ///
  /// In it, this message translates to:
  /// **'Cornice'**
  String get strCornice;

  /// Strumento Foto: ombra (e parametro dell'ombra)
  ///
  /// In it, this message translates to:
  /// **'Ombra'**
  String get strOmbra;

  /// Strumento Foto: rotazione e specchio
  ///
  /// In it, this message translates to:
  /// **'Ruota'**
  String get strRuota;

  /// Strumento Foto a comando singolo
  ///
  /// In it, this message translates to:
  /// **'Copia stile'**
  String get strCopiaStile;

  /// Strumento Foto a comando singolo
  ///
  /// In it, this message translates to:
  /// **'Incolla stile'**
  String get strIncollaStile;

  /// Parametro di Inquadra
  ///
  /// In it, this message translates to:
  /// **'Zoom'**
  String get parZoom;

  /// Parametro di Inquadra: spostamento orizzontale
  ///
  /// In it, this message translates to:
  /// **'Orizzontale'**
  String get parOrizzontale;

  /// Parametro di Inquadra: spostamento verticale
  ///
  /// In it, this message translates to:
  /// **'Verticale'**
  String get parVerticale;

  /// Parametro di Inquadra
  ///
  /// In it, this message translates to:
  /// **'Ruota contenuto'**
  String get parRuotaContenuto;

  /// Parametro di Regola
  ///
  /// In it, this message translates to:
  /// **'Luminosità'**
  String get parLuminosita;

  /// Parametro di Regola
  ///
  /// In it, this message translates to:
  /// **'Contrasto'**
  String get parContrasto;

  /// Parametro di Regola: zone scure
  ///
  /// In it, this message translates to:
  /// **'Ombre'**
  String get parOmbre;

  /// Parametro di Regola: zone chiare
  ///
  /// In it, this message translates to:
  /// **'Luci'**
  String get parLuci;

  /// Parametro di Regola
  ///
  /// In it, this message translates to:
  /// **'Saturazione'**
  String get parSaturazione;

  /// Parametro di Regola
  ///
  /// In it, this message translates to:
  /// **'Calore'**
  String get parCalore;

  /// Parametro di Regola
  ///
  /// In it, this message translates to:
  /// **'Tinta'**
  String get parTinta;

  /// Parametro di Effetti
  ///
  /// In it, this message translates to:
  /// **'Nitidezza'**
  String get parNitidezza;

  /// Parametro di Effetti
  ///
  /// In it, this message translates to:
  /// **'Vignettatura'**
  String get parVignettatura;

  /// Parametro di Effetti
  ///
  /// In it, this message translates to:
  /// **'Sbiadito'**
  String get parSbiadito;

  /// Parametro di Effetti
  ///
  /// In it, this message translates to:
  /// **'Grana'**
  String get parGrana;

  /// Parametro di Cornice
  ///
  /// In it, this message translates to:
  /// **'Angoli'**
  String get parAngoli;

  /// Parametro di Cornice: spessore
  ///
  /// In it, this message translates to:
  /// **'Bordo'**
  String get parBordo;

  /// Parametro di Cornice: colore del bordo
  ///
  /// In it, this message translates to:
  /// **'Colore'**
  String get parColore;

  /// Parametro di Ombra
  ///
  /// In it, this message translates to:
  /// **'Opacità'**
  String get parOpacita;

  /// Parametro di Ruota
  ///
  /// In it, this message translates to:
  /// **'Angolo'**
  String get parAngolo;

  /// Interruttore di Regola: bianco e nero
  ///
  /// In it, this message translates to:
  /// **'B/N'**
  String get azBiancoNero;

  /// Azione di Regola
  ///
  /// In it, this message translates to:
  /// **'Reimposta colori'**
  String get azReimpostaColori;

  /// Azione che copia le impostazioni su tutte le foto
  ///
  /// In it, this message translates to:
  /// **'Applica a tutte'**
  String get azApplicaATutte;

  /// Inquadra: la foto riempie il riquadro
  ///
  /// In it, this message translates to:
  /// **'Riempi'**
  String get azRiempi;

  /// Inquadra e Ritaglio: tutta la foto, senza tagli
  ///
  /// In it, this message translates to:
  /// **'Foto intera'**
  String get azFotoIntera;

  /// Inquadra: i lati stirano la foto
  ///
  /// In it, this message translates to:
  /// **'Deforma'**
  String get azDeforma;

  /// Inquadra: zoom e posizione al valore iniziale
  ///
  /// In it, this message translates to:
  /// **'Reimposta'**
  String get azReimposta;

  /// Inquadra: il riquadro prende la forma della foto
  ///
  /// In it, this message translates to:
  /// **'Proporzioni foto'**
  String get azProporzioniFoto;

  /// Inquadra: torna al riquadro di prima
  ///
  /// In it, this message translates to:
  /// **'Riquadro di prima'**
  String get azRiquadroDiPrima;

  /// Ruota di 90° a sinistra
  ///
  /// In it, this message translates to:
  /// **'90° sx'**
  String get azSinistra90;

  /// Ruota di 90° a destra
  ///
  /// In it, this message translates to:
  /// **'90° dx'**
  String get azDestra90;

  /// Ruota: angolo a zero
  ///
  /// In it, this message translates to:
  /// **'Dritta'**
  String get azDritta;

  /// Specchia da sinistra a destra
  ///
  /// In it, this message translates to:
  /// **'Specchia orizz.'**
  String get azSpecchiaOrizz;

  /// Capovolge dall'alto in basso
  ///
  /// In it, this message translates to:
  /// **'Specchia vert.'**
  String get azSpecchiaVert;

  /// Etichetta del pulsante prima/dopo
  ///
  /// In it, this message translates to:
  /// **'Tieni premuto per confrontare con l\'originale'**
  String get confronta;

  /// Filtro pronto
  ///
  /// In it, this message translates to:
  /// **'Originale'**
  String get filtroOriginale;

  /// Filtro pronto
  ///
  /// In it, this message translates to:
  /// **'Vivace'**
  String get filtroVivace;

  /// Filtro pronto
  ///
  /// In it, this message translates to:
  /// **'Estate'**
  String get filtroEstate;

  /// Filtro pronto
  ///
  /// In it, this message translates to:
  /// **'Pellicola'**
  String get filtroPellicola;

  /// Filtro pronto
  ///
  /// In it, this message translates to:
  /// **'Vintage'**
  String get filtroVintage;

  /// Filtro pronto
  ///
  /// In it, this message translates to:
  /// **'B/N contrastato'**
  String get filtroBnContrastato;

  /// Filtro pronto
  ///
  /// In it, this message translates to:
  /// **'Freddo'**
  String get filtroFreddo;

  /// Filtro pronto
  ///
  /// In it, this message translates to:
  /// **'Morbido'**
  String get filtroMorbido;

  /// Filtro pronto
  ///
  /// In it, this message translates to:
  /// **'Drammatico'**
  String get filtroDrammatico;

  /// Titolo della pagina del ritaglio
  ///
  /// In it, this message translates to:
  /// **'Ritaglia'**
  String get ritTitolo;

  /// Ritaglio: proporzioni libere
  ///
  /// In it, this message translates to:
  /// **'Libera'**
  String get ritLibera;

  /// Ritaglio: stessa forma della foto intera
  ///
  /// In it, this message translates to:
  /// **'Originale'**
  String get ritOriginale;

  /// Ritaglio: stessa forma del riquadro sulla tela
  ///
  /// In it, this message translates to:
  /// **'Riquadro'**
  String get ritRiquadro;

  /// Ritaglio: tasto ⇄
  ///
  /// In it, this message translates to:
  /// **'Scambia verticale e orizzontale'**
  String get ritScambia;

  /// Ritaglio: interruttore
  ///
  /// In it, this message translates to:
  /// **'Adatta il riquadro al ritaglio'**
  String get ritAdatta;

  /// Ritaglio: errore
  ///
  /// In it, this message translates to:
  /// **'Non riesco a leggere questa foto'**
  String get ritNonLeggibile;

  /// Ritaglio: ✕
  ///
  /// In it, this message translates to:
  /// **'Chiudi senza ritagliare'**
  String get ritAnnulla;

  /// Ritaglio: ✓
  ///
  /// In it, this message translates to:
  /// **'Applica il ritaglio'**
  String get ritApplica;

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'Stile copiato: scegli un\'altra foto e usa «Incolla stile»'**
  String get avvisoStileCopiato;

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'Stile incollato'**
  String get avvisoStileIncollato;

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'Ritaglio applicato'**
  String get avvisoRitaglioApplicato;

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'Ritaglio tolto: foto intera'**
  String get avvisoRitaglioTolto;

  /// Messaggio breve dopo il gesto indietro
  ///
  /// In it, this message translates to:
  /// **'Modifica scartata'**
  String get avvisoModificaScartata;

  /// Azione del messaggio dopo aver scartato una modifica
  ///
  /// In it, this message translates to:
  /// **'Ripristina'**
  String get ripristina;

  /// Misura del ritaglio in pixel
  ///
  /// In it, this message translates to:
  /// **'Ritaglio: {w} × {h} px'**
  String ritMisura(int w, int h);

  /// Etichetta per i lettori di schermo di un campione di colore
  ///
  /// In it, this message translates to:
  /// **'Colore #{hex}'**
  String coloreEtichetta(String hex);

  /// Selettore colore: preleva un colore dalla pagina
  ///
  /// In it, this message translates to:
  /// **'Contagocce'**
  String get azContagocce;

  /// Selettore colore: apre il selettore completo
  ///
  /// In it, this message translates to:
  /// **'Altro'**
  String get azAltroColore;

  /// Selettore colore: torna ai campioni
  ///
  /// In it, this message translates to:
  /// **'Colori'**
  String get azColori;

  /// Aiuto mentre il contagocce è acceso
  ///
  /// In it, this message translates to:
  /// **'Tocca un punto della pagina per prelevarne il colore'**
  String get contagocceAiuto;

  /// Primo campione del riempimento delle forme: nessun colore
  ///
  /// In it, this message translates to:
  /// **'Nessuno'**
  String get nessuno;

  /// Selettore colore: codice esadecimale
  ///
  /// In it, this message translates to:
  /// **'Esadecimale'**
  String get parEsadecimale;

  /// Errore del campo esadecimale
  ///
  /// In it, this message translates to:
  /// **'Scrivi 6 cifre, da 0 a F'**
  String get esadecimaleNonValido;

  /// Selettore colore: tinta (HSL)
  ///
  /// In it, this message translates to:
  /// **'Tinta'**
  String get parTintaColore;

  /// Suggerimento del campo di testo
  ///
  /// In it, this message translates to:
  /// **'Scrivi qui il testo'**
  String get testoSuggerimento;

  /// Strumento Testo: scrivere il testo
  ///
  /// In it, this message translates to:
  /// **'Modifica'**
  String get strModifica;

  /// Gruppo di caratteri
  ///
  /// In it, this message translates to:
  /// **'Senza grazie'**
  String get catSenzaGrazie;

  /// Gruppo di caratteri
  ///
  /// In it, this message translates to:
  /// **'Con grazie'**
  String get catConGrazie;

  /// Gruppo di caratteri
  ///
  /// In it, this message translates to:
  /// **'Titolo'**
  String get catTitolo;

  /// Gruppo di caratteri
  ///
  /// In it, this message translates to:
  /// **'A mano'**
  String get catAMano;

  /// Gruppo di caratteri
  ///
  /// In it, this message translates to:
  /// **'Monospazio'**
  String get catMonospazio;

  /// Nota dello strumento Carattere quando il carattere del testo non è tra quelli inclusi
  ///
  /// In it, this message translates to:
  /// **'«{nome}» non c’è su questo telefono: si usa «{predefinito}». Il nome resta nel file finché non scegli un altro carattere.'**
  String avvisoCarattereMancante(String nome, String predefinito);

  /// Strumento Testo
  ///
  /// In it, this message translates to:
  /// **'Carattere'**
  String get strCarattere;

  /// Strumento Testo
  ///
  /// In it, this message translates to:
  /// **'Dimensione'**
  String get strDimensione;

  /// Strumento Testo
  ///
  /// In it, this message translates to:
  /// **'Spaziatura'**
  String get strSpaziatura;

  /// Parametro di Spaziatura
  ///
  /// In it, this message translates to:
  /// **'Interlinea'**
  String get parInterlinea;

  /// Parametro di Spaziatura: spazio tra le lettere
  ///
  /// In it, this message translates to:
  /// **'Lettere'**
  String get parSpaziaturaLettere;

  /// Strumento Testo: grassetto, corsivo, allineamento
  ///
  /// In it, this message translates to:
  /// **'Formato'**
  String get strFormato;

  /// Azione di Formato
  ///
  /// In it, this message translates to:
  /// **'Grassetto'**
  String get azGrassetto;

  /// Azione di Formato
  ///
  /// In it, this message translates to:
  /// **'Corsivo'**
  String get azCorsivo;

  /// Allineamento delle righe
  ///
  /// In it, this message translates to:
  /// **'Sinistra'**
  String get azSinistra;

  /// Allineamento delle righe
  ///
  /// In it, this message translates to:
  /// **'Centro'**
  String get azCentro;

  /// Allineamento delle righe
  ///
  /// In it, this message translates to:
  /// **'Destra'**
  String get azDestra;

  /// Strumento Testo
  ///
  /// In it, this message translates to:
  /// **'Contorno'**
  String get strContorno;

  /// Parametro di Contorno e Bordo
  ///
  /// In it, this message translates to:
  /// **'Spessore'**
  String get parSpessore;

  /// Strumento Testo: riquadro dietro al testo
  ///
  /// In it, this message translates to:
  /// **'Etichetta'**
  String get strEtichetta;

  /// Tipo di forma
  ///
  /// In it, this message translates to:
  /// **'Rettangolo'**
  String get formaRettangolo;

  /// Tipo di forma
  ///
  /// In it, this message translates to:
  /// **'Ellisse'**
  String get formaEllisse;

  /// Tipo di forma
  ///
  /// In it, this message translates to:
  /// **'Triangolo'**
  String get formaTriangolo;

  /// Tipo di forma
  ///
  /// In it, this message translates to:
  /// **'Rombo'**
  String get formaRombo;

  /// Tipo di forma
  ///
  /// In it, this message translates to:
  /// **'Stella'**
  String get formaStella;

  /// Tipo di forma
  ///
  /// In it, this message translates to:
  /// **'Cuore'**
  String get formaCuore;

  /// Tipo di forma
  ///
  /// In it, this message translates to:
  /// **'Linea'**
  String get formaLinea;

  /// Tipo di forma
  ///
  /// In it, this message translates to:
  /// **'Freccia'**
  String get formaFreccia;

  /// Tipo di forma
  ///
  /// In it, this message translates to:
  /// **'Doppia freccia'**
  String get formaDoppiaFreccia;

  /// Strumento Forme: cambia il tipo di forma
  ///
  /// In it, this message translates to:
  /// **'Tipo'**
  String get strTipo;

  /// Strumento Forme
  ///
  /// In it, this message translates to:
  /// **'Riempimento'**
  String get strRiempimento;

  /// Strumento Forme: continuo, tratteggiato, a puntini
  ///
  /// In it, this message translates to:
  /// **'Tratto'**
  String get parTratto;

  /// Strumento Forme: nome del bordo quando la forma è una linea o una freccia
  ///
  /// In it, this message translates to:
  /// **'Linea'**
  String get parLinea;

  /// Stile del tratto
  ///
  /// In it, this message translates to:
  /// **'Continuo'**
  String get trattoContinuo;

  /// Stile del tratto
  ///
  /// In it, this message translates to:
  /// **'Tratteggiato'**
  String get trattoTratteggiato;

  /// Stile del tratto
  ///
  /// In it, this message translates to:
  /// **'A puntini'**
  String get trattoPuntini;

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'Forma aggiunta'**
  String get avvisoFormaAggiunta;

  /// Pagine: aggiunge una pagina vuota prima della corrente
  ///
  /// In it, this message translates to:
  /// **'Aggiungi prima'**
  String get pagAggiungiPrima;

  /// Pagine: aggiunge una pagina vuota dopo la corrente
  ///
  /// In it, this message translates to:
  /// **'Aggiungi dopo'**
  String get pagAggiungiDopo;

  /// Pagine: duplica la pagina corrente
  ///
  /// In it, this message translates to:
  /// **'Duplica'**
  String get pagDuplica;

  /// Pagine: sposta la pagina di un posto indietro
  ///
  /// In it, this message translates to:
  /// **'Sposta a sinistra'**
  String get pagSpostaIndietro;

  /// Pagine: sposta la pagina di un posto avanti
  ///
  /// In it, this message translates to:
  /// **'Sposta a destra'**
  String get pagSpostaAvanti;

  /// Pagine: blocca la pagina
  ///
  /// In it, this message translates to:
  /// **'Blocca'**
  String get pagBlocca;

  /// Pagine: sblocca la pagina
  ///
  /// In it, this message translates to:
  /// **'Sblocca'**
  String get pagSblocca;

  /// Pagine: unisce la pagina alla successiva «a cavallo»
  ///
  /// In it, this message translates to:
  /// **'Unisci a cavallo'**
  String get pagUnisci;

  /// Pagine: separa la pagina dalla successiva
  ///
  /// In it, this message translates to:
  /// **'Separa'**
  String get pagSepara;

  /// Pagine: esporta la pagina corrente
  ///
  /// In it, this message translates to:
  /// **'Esporta questa'**
  String get pagEsporta;

  /// Pagine: elimina la pagina corrente
  ///
  /// In it, this message translates to:
  /// **'Elimina'**
  String get pagElimina;

  /// Pagine: formato del carosello
  ///
  /// In it, this message translates to:
  /// **'Formato'**
  String get pagFormato;

  /// Pagine: apre la Panoramica per riordinare
  ///
  /// In it, this message translates to:
  /// **'Riordina'**
  String get pagRiordina;

  /// Pagine: scheda delle azioni di pagina
  ///
  /// In it, this message translates to:
  /// **'Azioni'**
  String get pagAzioni;

  /// Pagine: misure del formato personalizzato
  ///
  /// In it, this message translates to:
  /// **'Misure'**
  String get pagMisure;

  /// Pagine: avviso sul formato
  ///
  /// In it, this message translates to:
  /// **'Con pagine bloccate il formato non si cambia'**
  String get pagFormatoBloccato;

  /// Stile: sfondo del carosello
  ///
  /// In it, this message translates to:
  /// **'Sfondo'**
  String get stileSfondo;

  /// Stile: numeri di pagina
  ///
  /// In it, this message translates to:
  /// **'Numeri di pagina'**
  String get stileNumeri;

  /// Stile: indicatore «scorri»
  ///
  /// In it, this message translates to:
  /// **'Indicatore «scorri»'**
  String get stileScorri;

  /// Stile: guide di centro sulla pagina
  ///
  /// In it, this message translates to:
  /// **'Guide'**
  String get stileGuide;

  /// Stile: aggancio degli elementi
  ///
  /// In it, this message translates to:
  /// **'Aggancio'**
  String get stileAggancio;

  /// Sfondo: tinta unita
  ///
  /// In it, this message translates to:
  /// **'Tinta'**
  String get sfTinta;

  /// Sfondo: sfumatura tra due colori
  ///
  /// In it, this message translates to:
  /// **'Sfumatura'**
  String get sfSfumatura;

  /// Sfondo: foto sfocata
  ///
  /// In it, this message translates to:
  /// **'Foto sfocata'**
  String get sfFotoSfocata;

  /// Sfondo: primo colore della sfumatura
  ///
  /// In it, this message translates to:
  /// **'Colore iniziale'**
  String get sfColoreIniziale;

  /// Sfondo: secondo colore della sfumatura
  ///
  /// In it, this message translates to:
  /// **'Colore finale'**
  String get sfColoreFinale;

  /// Sfondo: sfumatura verticale
  ///
  /// In it, this message translates to:
  /// **'Dall\'alto'**
  String get sfDirVerticale;

  /// Sfondo: sfumatura orizzontale
  ///
  /// In it, this message translates to:
  /// **'Da sinistra'**
  String get sfDirOrizzontale;

  /// Sfondo: sfumatura diagonale
  ///
  /// In it, this message translates to:
  /// **'In diagonale'**
  String get sfDirDiagonale;

  /// Sfondo: scelta della foto sfocata
  ///
  /// In it, this message translates to:
  /// **'Foto'**
  String get sfFoto;

  /// Sfondo: quanto è sfocata la foto
  ///
  /// In it, this message translates to:
  /// **'Sfocatura'**
  String get sfSfocatura;

  /// Sfondo: quanto si scurisce la foto
  ///
  /// In it, this message translates to:
  /// **'Scurisci'**
  String get sfScurisci;

  /// Sfondo: non ci sono foto per lo sfondo sfocato
  ///
  /// In it, this message translates to:
  /// **'Aggiungi prima delle foto alla libreria'**
  String get sfSenzaFoto;

  /// Numeri di pagina: interruttore
  ///
  /// In it, this message translates to:
  /// **'Numero di pagina'**
  String get numAcceso;

  /// Numeri di pagina: come si scrive il numero
  ///
  /// In it, this message translates to:
  /// **'Formato'**
  String get numFormato;

  /// Numeri di pagina e indicatore: dove va
  ///
  /// In it, this message translates to:
  /// **'Posizione'**
  String get numPosizione;

  /// Numeri di pagina: aspetto dell'etichetta
  ///
  /// In it, this message translates to:
  /// **'Stile'**
  String get numStile;

  /// Numeri di pagina: formato «1 di 5»
  ///
  /// In it, this message translates to:
  /// **'1 di 5'**
  String get numFormatoDi;

  /// Numeri di pagina: promemoria
  ///
  /// In it, this message translates to:
  /// **'Il numero compare quando il carosello ha almeno 2 pagine'**
  String get numDuePagine;

  /// Posizione
  ///
  /// In it, this message translates to:
  /// **'In basso al centro'**
  String get posBassoCentro;

  /// Posizione
  ///
  /// In it, this message translates to:
  /// **'In basso a destra'**
  String get posBassoDestra;

  /// Posizione
  ///
  /// In it, this message translates to:
  /// **'In basso a sinistra'**
  String get posBassoSinistra;

  /// Posizione
  ///
  /// In it, this message translates to:
  /// **'In alto al centro'**
  String get posAltoCentro;

  /// Posizione
  ///
  /// In it, this message translates to:
  /// **'In alto a destra'**
  String get posAltoDestra;

  /// Posizione
  ///
  /// In it, this message translates to:
  /// **'In alto a sinistra'**
  String get posAltoSinistra;

  /// Posizione dell'indicatore «scorri»
  ///
  /// In it, this message translates to:
  /// **'Al centro a destra'**
  String get posCentroDestra;

  /// Stile dell'etichetta
  ///
  /// In it, this message translates to:
  /// **'Etichetta scura'**
  String get ovScuro;

  /// Stile dell'etichetta
  ///
  /// In it, this message translates to:
  /// **'Etichetta chiara'**
  String get ovChiaro;

  /// Stile dell'etichetta
  ///
  /// In it, this message translates to:
  /// **'Solo testo'**
  String get ovSoloTesto;

  /// Indicatore «scorri»: interruttore
  ///
  /// In it, this message translates to:
  /// **'Indicatore'**
  String get scorriAcceso;

  /// Indicatore «scorri»: il testo
  ///
  /// In it, this message translates to:
  /// **'Testo'**
  String get scorriTesto;

  /// Indicatore «scorri»: campo di testo
  ///
  /// In it, this message translates to:
  /// **'Testo dell\'indicatore'**
  String get scorriTestoEtichetta;

  /// Strumento Allinea
  ///
  /// In it, this message translates to:
  /// **'Allinea'**
  String get strAllinea;

  /// Strumento Distribuisci
  ///
  /// In it, this message translates to:
  /// **'Distribuisci'**
  String get strDistribuisci;

  /// Raggruppa gli elementi scelti
  ///
  /// In it, this message translates to:
  /// **'Raggruppa'**
  String get strRaggruppa;

  /// Separa il gruppo
  ///
  /// In it, this message translates to:
  /// **'Separa'**
  String get strSepara;

  /// Scambia due foto
  ///
  /// In it, this message translates to:
  /// **'Scambia'**
  String get strScambia;

  /// Blocca posizione e dimensioni
  ///
  /// In it, this message translates to:
  /// **'Blocca'**
  String get strBlocca;

  /// Sblocca posizione e dimensioni
  ///
  /// In it, this message translates to:
  /// **'Sblocca'**
  String get strSblocca;

  /// Strumento Disponi: livello, blocco e frecce
  ///
  /// In it, this message translates to:
  /// **'Disponi'**
  String get strDisponi;

  /// Aiuto della selezione multipla vuota
  ///
  /// In it, this message translates to:
  /// **'Tocca gli elementi da scegliere'**
  String get selezionaPiuAiuto;

  /// Allinea a sinistra
  ///
  /// In it, this message translates to:
  /// **'A sinistra'**
  String get allSinistra;

  /// Allinea al centro in orizzontale
  ///
  /// In it, this message translates to:
  /// **'Centro orizzontale'**
  String get allCentroOrizz;

  /// Allinea a destra
  ///
  /// In it, this message translates to:
  /// **'A destra'**
  String get allDestra;

  /// Allinea in alto
  ///
  /// In it, this message translates to:
  /// **'In alto'**
  String get allAlto;

  /// Allinea al centro in verticale
  ///
  /// In it, this message translates to:
  /// **'Centro verticale'**
  String get allCentroVert;

  /// Allinea in basso
  ///
  /// In it, this message translates to:
  /// **'In basso'**
  String get allBasso;

  /// Distribuisci in orizzontale
  ///
  /// In it, this message translates to:
  /// **'Spazi uguali in orizzontale'**
  String get distOrizzontale;

  /// Distribuisci in verticale
  ///
  /// In it, this message translates to:
  /// **'Spazi uguali in verticale'**
  String get distVerticale;

  /// Disponi: scheda del livello
  ///
  /// In it, this message translates to:
  /// **'Livello'**
  String get dispLivello;

  /// Disponi: scheda delle frecce
  ///
  /// In it, this message translates to:
  /// **'Sposta'**
  String get dispSposta;

  /// Disponi: davanti a tutto
  ///
  /// In it, this message translates to:
  /// **'Porta davanti'**
  String get dispDavanti;

  /// Disponi: dietro a tutto
  ///
  /// In it, this message translates to:
  /// **'Manda dietro'**
  String get dispDietro;

  /// Passo delle frecce di Disponi
  ///
  /// In it, this message translates to:
  /// **'{n} px'**
  String passoPx(int n);

  /// Freccia di Disponi
  ///
  /// In it, this message translates to:
  /// **'Su'**
  String get frecciaSu;

  /// Freccia di Disponi
  ///
  /// In it, this message translates to:
  /// **'Giù'**
  String get frecciaGiu;

  /// Freccia di Disponi
  ///
  /// In it, this message translates to:
  /// **'Sinistra'**
  String get frecciaSinistra;

  /// Freccia di Disponi
  ///
  /// In it, this message translates to:
  /// **'Destra'**
  String get frecciaDestra;

  /// Menu della pressione lunga
  ///
  /// In it, this message translates to:
  /// **'Copia'**
  String get menuCopia;

  /// Menu della pressione lunga
  ///
  /// In it, this message translates to:
  /// **'Taglia'**
  String get menuTaglia;

  /// Menu della pressione lunga sul vuoto
  ///
  /// In it, this message translates to:
  /// **'Incolla qui'**
  String get menuIncolla;

  /// Menu della pressione lunga: modalità selezione multipla
  ///
  /// In it, this message translates to:
  /// **'Seleziona più'**
  String get menuSelezionaPiu;

  /// Menu della pressione lunga sul vuoto
  ///
  /// In it, this message translates to:
  /// **'Seleziona tutto'**
  String get menuSelezionaTutto;

  /// Menu della pressione lunga su una foto
  ///
  /// In it, this message translates to:
  /// **'Sposta in pagina…'**
  String get menuSpostaInPagina;

  /// Menu della pressione lunga sul vuoto
  ///
  /// In it, this message translates to:
  /// **'Aggiungi testo qui'**
  String get menuAggiungiTesto;

  /// Menu della pressione lunga sul vuoto
  ///
  /// In it, this message translates to:
  /// **'Aggiungi forma qui'**
  String get menuAggiungiForma;

  /// Menu della pressione lunga sul vuoto
  ///
  /// In it, this message translates to:
  /// **'Azioni della pagina'**
  String get menuAzioniPagina;

  /// Titolo della scelta della pagina
  ///
  /// In it, this message translates to:
  /// **'Sposta nella pagina'**
  String get menuScegliPagina;

  /// Una pagina nella scelta
  ///
  /// In it, this message translates to:
  /// **'Pagina {n}'**
  String menuPaginaNumero(int n);

  /// Panoramica: come si usa
  ///
  /// In it, this message translates to:
  /// **'Tocca per andare alla pagina · trascina per riordinare · tieni premuto per le azioni'**
  String get panoramicaAiuto;

  /// Panoramica: etichetta di una pagina
  ///
  /// In it, this message translates to:
  /// **'Pagina {n}, trascina per spostarla'**
  String panoramicaPagina(int n);

  /// Anteprima: pulsante di chiusura
  ///
  /// In it, this message translates to:
  /// **'Chiudi l\'anteprima'**
  String get anteprimaChiudi;

  /// Anteprima: pagina corrente
  ///
  /// In it, this message translates to:
  /// **'Pagina {n} di {tot}'**
  String anteprimaPagina(int n, int tot);

  /// Nome del pannello Cronologia
  ///
  /// In it, this message translates to:
  /// **'Cronologia'**
  String get strumentoCronologia;

  /// Cronologia: etichetta di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Passaggio {n}: {nome}'**
  String cronEtichetta(int n, String nome);

  /// Cronologia: il passaggio dove si è
  ///
  /// In it, this message translates to:
  /// **'Attuale'**
  String get cronAttuale;

  /// Primo passaggio della cronologia
  ///
  /// In it, this message translates to:
  /// **'Progetto aperto'**
  String get cambAperto;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Pagina duplicata'**
  String get cambPaginaDuplicata;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Pagina aggiunta'**
  String get cambPaginaAggiunta;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Pagina eliminata'**
  String get cambPaginaEliminata;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Foto sostituite'**
  String get cambFotoSostituite;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Elementi cambiati'**
  String get cambElementiCambiati;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'{n, plural, =1{Foto aggiunta} other{{n} foto aggiunte}}'**
  String cambFotoAggiunte(int n);

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'{n, plural, =1{Testo aggiunto} other{{n} testi aggiunti}}'**
  String cambTestiAggiunti(int n);

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'{n, plural, =1{Forma aggiunta} other{{n} forme aggiunte}}'**
  String cambFormeAggiunte(int n);

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'{n} elementi aggiunti'**
  String cambElementiAggiunti(int n);

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'{n, plural, =1{Foto eliminata} other{{n} foto eliminate}}'**
  String cambFotoEliminate(int n);

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'{n, plural, =1{Testo eliminato} other{{n} testi eliminati}}'**
  String cambTestiEliminati(int n);

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'{n, plural, =1{Forma eliminata} other{{n} forme eliminate}}'**
  String cambFormeEliminate(int n);

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'{n} elementi eliminati'**
  String cambElementiEliminati(int n);

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Pagine: {da} → {a}'**
  String cambPagine(int da, int a);

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Formato della pagina'**
  String get cambFormatoPagina;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Disposizione: {nome}'**
  String cambDisposizione(String nome);

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Stile mosaico'**
  String get cambStileMosaico;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Foto rimescolate'**
  String get cambFotoRimescolate;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Lucchetto delle pagine'**
  String get cambLucchettoPagine;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Pagine a cavallo'**
  String get cambPagineACavallo;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Disposizione della pagina'**
  String get cambDisposizionePagina;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Foto per pagina'**
  String get cambFotoPerPagina;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Spaziatura'**
  String get cambSpaziatura;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Margine'**
  String get cambMargine;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Sfondo'**
  String get cambSfondo;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Numeri di pagina'**
  String get cambNumeriPagina;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Indicatore «scorri»'**
  String get cambScorri;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Nome dei file'**
  String get cambNomeFile;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Modifica'**
  String get cambModifica;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Elementi raggruppati'**
  String get cambRaggruppati;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Gruppo separato'**
  String get cambSeparati;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Ordine delle foto'**
  String get cambOrdineFoto;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Livello cambiato'**
  String get cambLivello;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Blocco della posizione'**
  String get cambBloccoPosizione;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'{n} elementi spostati'**
  String cambNSpostati(int n);

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Disposizione aggiornata'**
  String get cambDispAggiornata;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'{n} elementi modificati'**
  String cambNModificati(int n);

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'{tipo, select, photo{Foto spostata} text{Testo spostato} shape{Forma spostata} other{Elemento spostato}}'**
  String cambSpostato(String tipo);

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'{tipo, select, photo{Foto ridimensionata} text{Testo ridimensionato} shape{Forma ridimensionata} other{Elemento ridimensionato}}'**
  String cambRidimensionato(String tipo);

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'{tipo, select, photo{Foto ruotata} text{Testo ruotato} shape{Forma ruotata} other{Elemento ruotato}}'**
  String cambRuotato(String tipo);

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'{tipo, select, photo{Stile della foto} text{Stile del testo} shape{Stile della forma} other{Stile}}'**
  String cambStile(String tipo);

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Testo modificato'**
  String get cambTestoModificato;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Colori della foto'**
  String get cambColoriFoto;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Taglio del video'**
  String get cambTaglioVideo;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Copertina del video'**
  String get cambCopertinaVideo;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Audio del video'**
  String get cambAudioVideo;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Inquadratura della foto'**
  String get cambInquadratura;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Foto libera'**
  String get cambFotoLibera;

  /// Nome di un passaggio
  ///
  /// In it, this message translates to:
  /// **'Foto nella disposizione'**
  String get cambFotoInDisposizione;

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'Pagina duplicata: la copia è la pagina {n}'**
  String avvisoPaginaDuplicata(int n);

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'Pagina {n} eliminata'**
  String avvisoPaginaEliminata(int n);

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'Pagina spostata in posizione {n}'**
  String avvisoPaginaSpostata(int n);

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'Pagina {n} bloccata'**
  String avvisoPaginaBloccata(int n);

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'Pagina {n} sbloccata'**
  String avvisoPaginaSbloccata(int n);

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'Pagina {n} unita alla successiva «a cavallo»'**
  String avvisoPaginaUnita(int n);

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'Pagina {n} separata dalla successiva'**
  String avvisoPaginaSeparata(int n);

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'Pagine riordinate'**
  String get avvisoPagineRiordinate;

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'{n} elementi raggruppati: si spostano insieme'**
  String avvisoRaggruppati(int n);

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'Gruppo separato: ora gli elementi si spostano uno per uno'**
  String get avvisoSeparati;

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'Seleziona almeno 2 elementi da raggruppare'**
  String get avvisoServeDue;

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'Seleziona almeno 3 elementi per distribuirli'**
  String get avvisoServeTre;

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'Nessun gruppo selezionato'**
  String get avvisoNessunGruppo;

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'Posizione bloccata'**
  String get avvisoPosizioneBloccata;

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'Posizione sbloccata'**
  String get avvisoPosizioneSbloccata;

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'Portato davanti'**
  String get avvisoPortatoDavanti;

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'Mandato dietro'**
  String get avvisoMandatoDietro;

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'{n, plural, =1{1 elemento copiato} other{{n} elementi copiati}}'**
  String avvisoCopiati(int n);

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'{n, plural, =1{1 elemento tagliato} other{{n} elementi tagliati}}'**
  String avvisoTagliati(int n);

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'{n, plural, =1{1 elemento incollato} other{{n} elementi incollati}}'**
  String avvisoIncollati(int n);

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'Non c\'è niente da incollare: copia prima foto, testi o forme'**
  String get avvisoNienteDaIncollare;

  /// Messaggio breve
  ///
  /// In it, this message translates to:
  /// **'Foto spostate nella pagina {n}'**
  String avvisoFotoSpostate(int n);

  /// Esportazione: una immagine per pagina
  ///
  /// In it, this message translates to:
  /// **'Pagine separate'**
  String get espPagineSeparate;

  /// Esportazione: solo la pagina corrente
  ///
  /// In it, this message translates to:
  /// **'Questa pagina'**
  String get espQuestaPagina;

  /// Esportazione: tutta la striscia in un'immagine
  ///
  /// In it, this message translates to:
  /// **'Collage intero'**
  String get espCollage;

  /// Esportazione: seleziona tutte le pagine
  ///
  /// In it, this message translates to:
  /// **'Tutte'**
  String get espTutte;

  /// Esportazione: toglie la selezione alle pagine
  ///
  /// In it, this message translates to:
  /// **'Nessuna'**
  String get espNessuna;

  /// Esportazione: etichetta del formato del file
  ///
  /// In it, this message translates to:
  /// **'Formato'**
  String get espFormato;

  /// Esportazione: scelta PNG
  ///
  /// In it, this message translates to:
  /// **'PNG · massima qualità'**
  String get espFormatoPng;

  /// Esportazione: scelta JPG
  ///
  /// In it, this message translates to:
  /// **'JPG · file leggeri'**
  String get espFormatoJpg;

  /// Esportazione: etichetta della qualità
  ///
  /// In it, this message translates to:
  /// **'Qualità JPG'**
  String get espQualita;

  /// Esportazione: etichetta della scala
  ///
  /// In it, this message translates to:
  /// **'Scala'**
  String get espScala;

  /// Esportazione: scala 1×
  ///
  /// In it, this message translates to:
  /// **'1× standard'**
  String get espScala1;

  /// Esportazione: scala 2×
  ///
  /// In it, this message translates to:
  /// **'2× alta definizione'**
  String get espScala2;

  /// Esportazione: etichetta del nome dei file
  ///
  /// In it, this message translates to:
  /// **'Nome dei file'**
  String get espNomeFile;

  /// Esportazione: nome predefinito dei file
  ///
  /// In it, this message translates to:
  /// **'frame'**
  String get espNomeSuggerimento;

  /// Esportazione: nome del primo file
  ///
  /// In it, this message translates to:
  /// **'Esempio: {nome}'**
  String espEsempioNome(String nome);

  /// Esportazione: misure di ogni immagine
  ///
  /// In it, this message translates to:
  /// **'Ogni immagine: {w}×{h} px'**
  String espMisure(int w, int h);

  /// Esportazione: misure del collage
  ///
  /// In it, this message translates to:
  /// **'Immagine: {w}×{h} px'**
  String espMisureCollage(int w, int h);

  /// Esportazione: nessuna pagina scelta
  ///
  /// In it, this message translates to:
  /// **'Scegli almeno una pagina'**
  String get espNessunaPagina;

  /// Esportazione: nota sui video
  ///
  /// In it, this message translates to:
  /// **'Le pagine con un video escono come immagine, con la copertina: l\'MP4 arriva più avanti.'**
  String get espVideoCopertina;

  /// Esportazione: etichetta delle destinazioni
  ///
  /// In it, this message translates to:
  /// **'Salva in'**
  String get espDestinazione;

  /// Esportazione: salva nella galleria
  ///
  /// In it, this message translates to:
  /// **'Galleria'**
  String get espGalleria;

  /// Esportazione: foglio Condividi
  ///
  /// In it, this message translates to:
  /// **'Condividi'**
  String get espCondividi;

  /// Esportazione: selettore di sistema
  ///
  /// In it, this message translates to:
  /// **'Salva in File'**
  String get espSalvaInFile;

  /// Avviso prima di esportare
  ///
  /// In it, this message translates to:
  /// **'Foto mancanti'**
  String get espMancantiTitolo;

  /// Avviso prima di esportare
  ///
  /// In it, this message translates to:
  /// **'{n, plural, =1{1 foto sulla tela non è stata trovata e resterà vuota} other{{n} foto sulla tela non sono state trovate e resteranno vuote}} nell\'immagine esportata. Esportare comunque?'**
  String espMancanti(int n);

  /// Avviso prima di esportare
  ///
  /// In it, this message translates to:
  /// **'Tela vuota'**
  String get espTelaVuotaTitolo;

  /// Avviso prima di esportare
  ///
  /// In it, this message translates to:
  /// **'Non ci sono foto sulla tela. Esportare comunque?'**
  String get espTelaVuota;

  /// Conferma dell'avviso
  ///
  /// In it, this message translates to:
  /// **'Esporta comunque'**
  String get espEsportaComunque;

  /// Avviso prima di esportare
  ///
  /// In it, this message translates to:
  /// **'Collage troppo grande'**
  String get espCollageGrandeTitolo;

  /// Avviso prima di esportare
  ///
  /// In it, this message translates to:
  /// **'A 2× il collage sarebbe di {w}×{h} px: troppo per la memoria del telefono. Puoi usare 1× oppure esportare le pagine separate.'**
  String espCollageGrande(int w, int h);

  /// Avviso prima di esportare
  ///
  /// In it, this message translates to:
  /// **'Anche a 1× il collage sarebbe di {w}×{h} px: troppo per la memoria del telefono. Esporta le pagine separate.'**
  String espCollageGrande1x(int w, int h);

  /// Passa a 1× e prosegue
  ///
  /// In it, this message translates to:
  /// **'Usa 1×'**
  String get espUsa1x;

  /// Passa alle pagine separate
  ///
  /// In it, this message translates to:
  /// **'Pagine separate'**
  String get espUsaPagine;

  /// Titolo della schermata di avanzamento
  ///
  /// In it, this message translates to:
  /// **'Esportazione'**
  String get espTitoloAvanzamento;

  /// Avanzamento
  ///
  /// In it, this message translates to:
  /// **'Preparazione delle foto, pagina {pagina} ({indice} di {totale})…'**
  String espFaseFoto(int pagina, int indice, int totale);

  /// Avanzamento
  ///
  /// In it, this message translates to:
  /// **'Pagina {pagina} ({indice} di {totale})…'**
  String espFasePagina(int pagina, int indice, int totale);

  /// Avanzamento
  ///
  /// In it, this message translates to:
  /// **'Composizione del collage…'**
  String get espFaseComposizione;

  /// Avanzamento
  ///
  /// In it, this message translates to:
  /// **'Salvataggio in Galleria ({indice} di {totale})…'**
  String espFaseGalleria(int indice, int totale);

  /// Avanzamento
  ///
  /// In it, this message translates to:
  /// **'Apertura di Condividi…'**
  String get espFaseCondividi;

  /// Avanzamento
  ///
  /// In it, this message translates to:
  /// **'Salvataggio in File ({indice} di {totale})…'**
  String espFaseFile(int indice, int totale);

  /// Avanzamento: l'annullamento è richiesto, si ferma alla prossima pausa
  ///
  /// In it, this message translates to:
  /// **'Annullamento…'**
  String get espAnnullando;

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'Esportazione completata'**
  String get espFatto;

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'{n, plural, =1{1 immagine salvata} other{{n} immagini salvate}} nell\'album «ScrolleR Studio» della Galleria, in ordine di pagina'**
  String espSalvatoGalleria(int n);

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'{n, plural, =1{1 immagine pronta} other{{n} immagini pronte}} per la condivisione'**
  String espSalvatoCondiviso(int n);

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'{n, plural, =1{1 immagine salvata} other{{n} immagini salvate}} in File'**
  String espSalvatoFile(int n);

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'Esportazione incompleta'**
  String get espIncompleta;

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'Non salvate: {nomi}'**
  String espNonSalvate(String nomi);

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'Esportazione interrotta: le pagine successive non sono state salvate.'**
  String get espInterrotta;

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'Esportazione annullata'**
  String get espAnnullata;

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'Esportazione non riuscita: {errore}'**
  String espErrore(String errore);

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'Senza il permesso per la Galleria non posso salvare lì. Puoi usare Condividi o Salva in File.'**
  String get espGalleriaNegata;

  /// Chiude la schermata dell'esito
  ///
  /// In it, this message translates to:
  /// **'Fine'**
  String get espFine;
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
