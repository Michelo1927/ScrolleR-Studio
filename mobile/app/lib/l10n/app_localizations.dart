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

  /// Voce del pannello ＋ (arriva con la Fase 5)
  ///
  /// In it, this message translates to:
  /// **'Testo'**
  String get testo;

  /// Voce del pannello ＋ (arriva con la Fase 5)
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
