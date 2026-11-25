// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class TestiIt extends Testi {
  TestiIt([String locale = 'it']) : super(locale);

  @override
  String get appTitolo => 'ScrolleR Studio';

  @override
  String get homeVuotaTitolo => 'Nessun progetto';

  @override
  String get homeVuotaAiuto => 'Crea il tuo primo carosello';

  @override
  String get nuovoProgetto => 'Nuovo';

  @override
  String get inArrivo => 'In arrivo nelle prossime versioni';

  @override
  String get proveApri => 'Prove';

  @override
  String get proveTitolo => 'Prove della Fase 2';

  @override
  String get proveGalleria => 'Galleria';

  @override
  String get accessoCompleto => 'Accesso a tutte le foto e i video';

  @override
  String get accessoParziale => 'Accesso solo alle foto e ai video scelti';

  @override
  String get accessoNegato => 'Nessun accesso alla galleria';

  @override
  String get accessoDaChiedere =>
      'Le foto restano nella galleria: il progetto le collega senza copiarle.';

  @override
  String get consentiAccesso => 'Consenti accesso';

  @override
  String get scegliAltreFoto => 'Scegli altre foto';

  @override
  String get apriImpostazioni => 'Apri impostazioni';

  @override
  String get scegliDalTelefono => 'Scegli dal telefono';

  @override
  String fileCopiati(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n file copiati nel progetto',
      one: '1 file copiato nel progetto',
    );
    return '$_temp0';
  }

  @override
  String get creaPagina => 'Crea pagina';

  @override
  String get esportaVideo => 'Esporta MP4';

  @override
  String get progettiDiProva => 'Progetti dal computer';

  @override
  String progettiDiProvaAiuto(String cartella) {
    return 'Copia ogni progetto in una sua cartella (con .scrlproj e media/) in: $cartella';
  }

  @override
  String paginaDiTotale(int numero, int totale) {
    return 'Pagina $numero di $totale';
  }

  @override
  String get fotoMancante => 'Foto mancante';

  @override
  String get originaleMancante => 'Originale mancante';

  @override
  String get numeroPaginaDi => 'di';

  @override
  String get esportazioneInCorso => 'Esportazione MP4…';

  @override
  String get annulla => 'Annulla';

  @override
  String videoFatto(int fotogrammi, String ms) {
    return 'MP4 salvato nella galleria: $fotogrammi fotogrammi, $ms ms per fotogramma';
  }

  @override
  String videoErrore(String errore) {
    return 'Esportazione non riuscita: $errore';
  }

  @override
  String get videoAnnullato => 'Esportazione annullata';

  @override
  String get videoNonDisponibile =>
      'I video non sono ancora disponibili su questo telefono';

  @override
  String get scegliUnVideo => 'Scegli almeno un video';

  @override
  String get progettoNonValido => 'Progetto non leggibile';

  @override
  String get rinomina => 'Rinomina';

  @override
  String get duplica => 'Duplica';

  @override
  String get elimina => 'Elimina';

  @override
  String copiaDi(String nome) {
    return 'Copia di $nome';
  }

  @override
  String eliminaProgettoChiede(String nome) {
    return 'Eliminare «$nome»?';
  }

  @override
  String get eliminaProgettoAiuto =>
      'Il progetto sparisce da questo telefono. Le foto della galleria non vengono toccate.';

  @override
  String get nomeProgetto => 'Nome del progetto';

  @override
  String get fatto => 'Fatto';

  @override
  String numeroPagine(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n pagine',
      one: '1 pagina',
    );
    return '$_temp0';
  }

  @override
  String nomeProgettoNuovo(int n) {
    return 'Progetto $n';
  }

  @override
  String get passoFormato => 'Formato';

  @override
  String get passoFoto => 'Scegli le foto';

  @override
  String creaConFoto(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Crea con $n foto',
      one: 'Crea con 1 foto',
      zero: 'Crea',
    );
    return '$_temp0';
  }

  @override
  String get formato0 => '3:4 verticale';

  @override
  String get formato1 => '4:3 orizzontale';

  @override
  String get formato2 => '4:5 Instagram';

  @override
  String get formato3 => '1:1 quadrato';

  @override
  String get formato4 => '9:16 storia';

  @override
  String get formato5 => '16:9 panoramico';

  @override
  String get formato6 => '2:3 foto verticale';

  @override
  String get formato7 => '3:2 foto orizzontale';

  @override
  String get formato8 => 'Personalizzato';

  @override
  String get larghezzaPixel => 'Larghezza (px)';

  @override
  String get altezzaPixel => 'Altezza (px)';

  @override
  String get formatoAiuto => 'Il formato vale per ogni pagina del carosello.';

  @override
  String get continua => 'Continua';

  @override
  String get salta => 'Salta';

  @override
  String fotoNumero(int n) {
    return 'Foto $n';
  }

  @override
  String videoNumero(int n) {
    return 'Video $n';
  }

  @override
  String aggiungiNFoto(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Aggiungi $n foto',
      one: 'Aggiungi 1 foto',
      zero: 'Aggiungi',
    );
    return '$_temp0';
  }

  @override
  String get tela => 'Tela';

  @override
  String etichettaPagina(int n) {
    return 'Pagina $n';
  }

  @override
  String get etichettaBloccata => 'Bloccata';

  @override
  String etichettaACavallo(int a, int b) {
    return 'A cavallo $a–$b';
  }

  @override
  String etichettaFoto(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n foto',
      one: '1 foto',
      zero: 'Nessuna foto',
    );
    return '$_temp0';
  }

  @override
  String get paginaVuota => 'Tocca ＋ per aggiungere le foto';

  @override
  String get indietro => 'Indietro';

  @override
  String get ripeti => 'Ripeti';

  @override
  String get anteprima => 'Anteprima';

  @override
  String get esporta => 'Esporta';

  @override
  String get paginaPrecedente => 'Pagina precedente';

  @override
  String get paginaSuccessiva => 'Pagina successiva';

  @override
  String vaiAllaPagina(int n) {
    return 'Vai alla pagina $n';
  }

  @override
  String get panoramica => 'Panoramica';

  @override
  String get barraFoto => 'Foto';

  @override
  String get barraDisposizione => 'Impagina';

  @override
  String get barraAggiungi => 'Aggiungi';

  @override
  String get barraPagine => 'Pagine';

  @override
  String get barraStile => 'Stile';

  @override
  String get deseleziona => 'Deseleziona';

  @override
  String get inDisposizione => 'In disposizione';

  @override
  String get libera => 'Libera';

  @override
  String get conferma => 'Conferma';

  @override
  String get chiudi => 'Chiudi';

  @override
  String get strumentoDisposizione => 'Impagina';

  @override
  String get parDisposizione => 'Disposizione';

  @override
  String get parMosaico => 'Mosaico';

  @override
  String get parStrisce => 'Strisce';

  @override
  String get parOmbraPolaroid => 'Ombra';

  @override
  String get parRilievo => 'Rilievo 3D';

  @override
  String get strisceAutomatico => 'Automatico';

  @override
  String get strisceOrizzontali => 'Orizzontali';

  @override
  String get strisceVerticali => 'Verticali';

  @override
  String get parPagine => 'Pagine';

  @override
  String get parFotoPerPagina => 'Foto per pagina';

  @override
  String get parFotoQui => 'Foto qui';

  @override
  String get parSpaziatura => 'Spaziatura';

  @override
  String get parMargine => 'Margine';

  @override
  String get auto => 'Auto';

  @override
  String get unaPerPagina => 'Una per pagina';

  @override
  String get rimescola => 'Rimescola';

  @override
  String numeroFoto(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n foto',
      one: '1 foto',
    );
    return '$_temp0';
  }

  @override
  String get menoPagine => 'Una pagina in meno';

  @override
  String get piuPagine => 'Una pagina in più';

  @override
  String get menoFoto => 'Una foto in meno';

  @override
  String get piuFoto => 'Una foto in più';

  @override
  String get ambitoTutto => 'Tutto il carosello';

  @override
  String get ambitoPagina => 'Solo questa pagina';

  @override
  String get dispGriglia => 'Griglia';

  @override
  String get dispMosaico => 'Mosaico';

  @override
  String get dispRighe => 'Righe';

  @override
  String get dispColonne => 'Colonne';

  @override
  String get dispPolaroid => 'Polaroid';

  @override
  String get dispPellicola => 'Pellicola';

  @override
  String get dispACavallo => 'A cavallo';

  @override
  String get stileAutomatico => 'Automatico';

  @override
  String get stileInAlto => 'Grande in alto';

  @override
  String get stileInBasso => 'Grande in basso';

  @override
  String get stileASinistra => 'Grande a sinistra';

  @override
  String get stileADestra => 'Grande a destra';

  @override
  String get stileAlCentro => 'Grande al centro';

  @override
  String get stileDueGrandi => 'Due grandi';

  @override
  String get stileMuratura => 'Muratura';

  @override
  String libreriaTitolo(String conteggio) {
    return 'Libreria · $conteggio';
  }

  @override
  String contaFoto(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n foto',
      one: '1 foto',
    );
    return '$_temp0';
  }

  @override
  String contaVideo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n video',
      one: '1 video',
    );
    return '$_temp0';
  }

  @override
  String fotoScelte(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n foto scelte',
      one: '1 foto scelta',
    );
    return '$_temp0';
  }

  @override
  String videoScelti(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n video scelti',
      one: '1 video scelto',
    );
    return '$_temp0';
  }

  @override
  String mediaScelti(String conteggio) {
    return '$conteggio scelti';
  }

  @override
  String get libreriaVuota => 'Aggiungi foto e video dal telefono';

  @override
  String get aggiungiDalTelefono => 'Aggiungi dal telefono';

  @override
  String get aggiungiAllaTela => 'Aggiungi alla tela';

  @override
  String get comeFotoLibera => 'Fuori dalla disposizione';

  @override
  String get soloQueste => 'Solo la selezione';

  @override
  String get rimuoviDallaLibreria => 'Rimuovi dalla libreria';

  @override
  String get mettiTutte => 'Metti tutto';

  @override
  String get svuotaTela => 'Svuota tela';

  @override
  String get fotoOVideo => 'Foto o video';

  @override
  String get paginaNuova => 'Pagina nuova';

  @override
  String get testo => 'Testo';

  @override
  String get forma => 'Forma';

  @override
  String avvisoFotoAggiunte(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n foto aggiunte',
      one: '1 foto aggiunta',
    );
    return '$_temp0';
  }

  @override
  String avvisoVideoAggiunti(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n video aggiunti',
      one: '1 video aggiunto',
    );
    return '$_temp0';
  }

  @override
  String avvisoMediaAggiunti(String conteggio) {
    return '$conteggio aggiunti';
  }

  @override
  String get avvisoEliminato => 'Elemento eliminato';

  @override
  String avvisoEliminati(int n) {
    return '$n elementi eliminati';
  }

  @override
  String get avvisoDuplicato => 'Elemento duplicato';

  @override
  String get avvisoTelaSvuotata => 'Tela svuotata';

  @override
  String get avvisoFotoLibera =>
      'Foto libera: la disposizione non la tocca più';

  @override
  String get avvisoFotoInDisposizione => 'Foto rimessa nella disposizione';

  @override
  String get avvisoPaginaAggiunta => 'Pagina aggiunta';

  @override
  String get avvisoSalvataggioNonRiuscito =>
      'Salvataggio non riuscito: riprovo alla prossima modifica';

  @override
  String noticeSeamAddedPages(int n) {
    return '«A cavallo» ha portato le pagine a $n';
  }

  @override
  String noticeSeamRestoredPages(int n) {
    return 'Tornate a $n pagine';
  }

  @override
  String get noticeAddedPageForPhotos => 'Pagina aggiunta per le foto';

  @override
  String noticePageLocked(int n) {
    return 'La pagina $n è bloccata: sbloccala prima';
  }

  @override
  String noticeSeamPagesLocked(int n) {
    return 'Le pagine «a cavallo» intorno alla posizione $n sono bloccate';
  }

  @override
  String noticeSeamPageLocked(int n) {
    return 'La pagina $n è «a cavallo» e bloccata';
  }

  @override
  String noticeLockedSeamMustStayTogether(int a, int b) {
    return 'Le pagine $a e $b sono «a cavallo» e bloccate: devono restare vicine';
  }

  @override
  String noticeMaxPages(int n) {
    return 'Massimo di $n pagine raggiunto';
  }

  @override
  String get noticeSinglePage => 'È l\'unica pagina: non si elimina';

  @override
  String get noticeNothingToReorder =>
      'C\'è una sola pagina: niente da riordinare';

  @override
  String get noticePageAtEdge => 'La pagina è già al bordo';

  @override
  String get noticeLastPage => 'È l\'ultima pagina: niente da unire';

  @override
  String get noticeLockedPagesNoResize =>
      'Ci sono pagine bloccate: il formato non si cambia';

  @override
  String get noticePerPageBackToAuto => '«Foto per pagina» torna su Auto';

  @override
  String get noticeSeamIgnoresPageSettings =>
      'Con «A cavallo» le scelte per singola pagina non valgono';

  @override
  String get noticeVideoKeptInPage =>
      'I video non possono stare a cavallo di due pagine';

  @override
  String get noticeSwapNeedsTwo => 'Per scambiare servono esattamente 2 foto';

  @override
  String get strRitaglia => 'Ritaglia';

  @override
  String get strInquadra => 'Inquadra';

  @override
  String get strFiltri => 'Filtri';

  @override
  String get strRegola => 'Regola';

  @override
  String get strEffetti => 'Effetti';

  @override
  String get strCornice => 'Cornice';

  @override
  String get strOmbra => 'Ombra';

  @override
  String get strRuota => 'Ruota';

  @override
  String get strCopiaStile => 'Copia stile';

  @override
  String get strIncollaStile => 'Incolla stile';

  @override
  String get parZoom => 'Zoom';

  @override
  String get parOrizzontale => 'Orizzontale';

  @override
  String get parVerticale => 'Verticale';

  @override
  String get parRuotaContenuto => 'Ruota contenuto';

  @override
  String get parLuminosita => 'Luminosità';

  @override
  String get parContrasto => 'Contrasto';

  @override
  String get parOmbre => 'Ombre';

  @override
  String get parLuci => 'Luci';

  @override
  String get parSaturazione => 'Saturazione';

  @override
  String get parCalore => 'Calore';

  @override
  String get parTinta => 'Tinta';

  @override
  String get parNitidezza => 'Nitidezza';

  @override
  String get parVignettatura => 'Vignettatura';

  @override
  String get parSbiadito => 'Sbiadito';

  @override
  String get parGrana => 'Grana';

  @override
  String get parAngoli => 'Angoli';

  @override
  String get parBordo => 'Bordo';

  @override
  String get parColore => 'Colore';

  @override
  String get parOpacita => 'Opacità';

  @override
  String get parAngolo => 'Angolo';

  @override
  String get azBiancoNero => 'B/N';

  @override
  String get azReimpostaColori => 'Reimposta colori';

  @override
  String get azApplicaATutte => 'Applica a tutte';

  @override
  String get azRiempi => 'Riempi';

  @override
  String get azFotoIntera => 'Foto intera';

  @override
  String get azSoloRiquadro => 'Solo riquadro';

  @override
  String get azReimposta => 'Reimposta';

  @override
  String get azProporzioniFoto => 'Proporzioni foto';

  @override
  String get azRiquadroDiPrima => 'Riquadro di prima';

  @override
  String get azSinistra90 => '90° sx';

  @override
  String get azDestra90 => '90° dx';

  @override
  String get azDritta => 'Dritta';

  @override
  String get azSpecchiaOrizz => 'Specchia orizz.';

  @override
  String get azSpecchiaVert => 'Specchia vert.';

  @override
  String get confronta => 'Tieni premuto per confrontare con l\'originale';

  @override
  String get filtroOriginale => 'Originale';

  @override
  String get filtroVivace => 'Vivace';

  @override
  String get filtroEstate => 'Estate';

  @override
  String get filtroPellicola => 'Pellicola';

  @override
  String get filtroVintage => 'Vintage';

  @override
  String get filtroBnContrastato => 'B/N contrastato';

  @override
  String get filtroFreddo => 'Freddo';

  @override
  String get filtroMorbido => 'Morbido';

  @override
  String get filtroDrammatico => 'Drammatico';

  @override
  String get ritTitolo => 'Ritaglia';

  @override
  String get ritLibera => 'Libera';

  @override
  String get ritOriginale => 'Originale';

  @override
  String get ritRiquadro => 'Riquadro';

  @override
  String get ritScambia => 'Scambia verticale e orizzontale';

  @override
  String get ritAdatta => 'Adatta il riquadro al ritaglio';

  @override
  String get ritNonLeggibile => 'Non riesco a leggere questa foto';

  @override
  String get ritAnnulla => 'Chiudi senza ritagliare';

  @override
  String get ritApplica => 'Applica il ritaglio';

  @override
  String get avvisoStileCopiato =>
      'Stile copiato: scegli un\'altra foto e usa «Incolla stile»';

  @override
  String get avvisoStileIncollato => 'Stile incollato';

  @override
  String get avvisoRitaglioApplicato => 'Ritaglio applicato';

  @override
  String get avvisoRitaglioTolto => 'Ritaglio tolto: foto intera';

  @override
  String get avvisoModificaScartata => 'Modifica scartata';

  @override
  String get ripristina => 'Ripristina';

  @override
  String ritMisura(int w, int h) {
    return 'Ritaglio: $w × $h px';
  }

  @override
  String coloreEtichetta(String hex) {
    return 'Colore #$hex';
  }

  @override
  String get azContagocce => 'Contagocce';

  @override
  String get azAltroColore => 'Altro';

  @override
  String get azColori => 'Colori';

  @override
  String get contagocceAiuto =>
      'Tocca un punto della pagina per prelevarne il colore';

  @override
  String get nessuno => 'Nessuno';

  @override
  String get parEsadecimale => 'Esadecimale';

  @override
  String get esadecimaleNonValido => 'Scrivi 6 cifre, da 0 a F';

  @override
  String get parTintaColore => 'Tinta';

  @override
  String get testoSuggerimento => 'Scrivi qui il testo';

  @override
  String get strModifica => 'Modifica';

  @override
  String get catSenzaGrazie => 'Senza grazie';

  @override
  String get catConGrazie => 'Con grazie';

  @override
  String get catTitolo => 'Titolo';

  @override
  String get catAMano => 'A mano';

  @override
  String get catMonospazio => 'Monospazio';

  @override
  String avvisoCarattereMancante(String nome, String predefinito) {
    return '«$nome» non c’è su questo telefono: si usa «$predefinito». Il nome resta nel file finché non scegli un altro carattere.';
  }

  @override
  String get strCarattere => 'Carattere';

  @override
  String get strDimensione => 'Dimensione';

  @override
  String get strSpaziatura => 'Spaziatura';

  @override
  String get parInterlinea => 'Interlinea';

  @override
  String get parSpaziaturaLettere => 'Lettere';

  @override
  String get strFormato => 'Formato';

  @override
  String get azGrassetto => 'Grassetto';

  @override
  String get azCorsivo => 'Corsivo';

  @override
  String get azSinistra => 'Sinistra';

  @override
  String get azCentro => 'Centro';

  @override
  String get azDestra => 'Destra';

  @override
  String get strContorno => 'Contorno';

  @override
  String get parSpessore => 'Spessore';

  @override
  String get strEtichetta => 'Etichetta';

  @override
  String get formaRettangolo => 'Rettangolo';

  @override
  String get formaEllisse => 'Ellisse';

  @override
  String get formaTriangolo => 'Triangolo';

  @override
  String get formaRombo => 'Rombo';

  @override
  String get formaStella => 'Stella';

  @override
  String get formaCuore => 'Cuore';

  @override
  String get formaLinea => 'Linea';

  @override
  String get formaFreccia => 'Freccia';

  @override
  String get formaDoppiaFreccia => 'Doppia freccia';

  @override
  String get strTipo => 'Tipo';

  @override
  String get strRiempimento => 'Riempimento';

  @override
  String get parTratto => 'Tratto';

  @override
  String get parLinea => 'Linea';

  @override
  String get trattoContinuo => 'Continuo';

  @override
  String get trattoTratteggiato => 'Tratteggiato';

  @override
  String get trattoPuntini => 'A puntini';

  @override
  String get avvisoFormaAggiunta => 'Forma aggiunta';

  @override
  String get pagAggiungiPrima => 'Aggiungi prima';

  @override
  String get pagAggiungiDopo => 'Aggiungi dopo';

  @override
  String get pagDuplica => 'Duplica';

  @override
  String get pagSpostaIndietro => 'Sposta a sinistra';

  @override
  String get pagSpostaAvanti => 'Sposta a destra';

  @override
  String get pagBlocca => 'Blocca';

  @override
  String get pagSblocca => 'Sblocca';

  @override
  String get pagUnisci => 'Unisci a cavallo';

  @override
  String get pagSepara => 'Separa';

  @override
  String get pagEsporta => 'Esporta questa';

  @override
  String get pagElimina => 'Elimina';

  @override
  String get pagFormato => 'Formato';

  @override
  String get pagRiordina => 'Riordina';

  @override
  String get pagAzioni => 'Azioni';

  @override
  String get pagMisure => 'Misure';

  @override
  String get pagFormatoBloccato =>
      'Con pagine bloccate il formato non si cambia';

  @override
  String get stileSfondo => 'Sfondo';

  @override
  String get stileNumeri => 'Numeri di pagina';

  @override
  String get stileScorri => 'Indicatore «scorri»';

  @override
  String get stileGuide => 'Guide';

  @override
  String get zonaSicuraReel => 'Zona sicura reel';

  @override
  String get stileAggancio => 'Aggancio';

  @override
  String get sfTinta => 'Tinta';

  @override
  String get sfSfumatura => 'Sfumatura';

  @override
  String get sfFotoSfocata => 'Foto sfocata';

  @override
  String get sfColoreIniziale => 'Colore iniziale';

  @override
  String get sfColoreFinale => 'Colore finale';

  @override
  String get sfDirVerticale => 'Dall\'alto';

  @override
  String get sfDirOrizzontale => 'Da sinistra';

  @override
  String get sfDirDiagonale => 'In diagonale';

  @override
  String get sfFoto => 'Foto';

  @override
  String get sfSfocatura => 'Sfocatura';

  @override
  String get sfScurisci => 'Scurisci';

  @override
  String get sfSenzaFoto => 'Aggiungi prima delle foto alla libreria';

  @override
  String get numAcceso => 'Numero di pagina';

  @override
  String get numFormato => 'Formato';

  @override
  String get numPosizione => 'Posizione';

  @override
  String get numStile => 'Stile';

  @override
  String get numFormatoDi => '1 di 5';

  @override
  String get numDuePagine =>
      'Il numero compare quando il carosello ha almeno 2 pagine';

  @override
  String get posBassoCentro => 'In basso al centro';

  @override
  String get posBassoDestra => 'In basso a destra';

  @override
  String get posBassoSinistra => 'In basso a sinistra';

  @override
  String get posAltoCentro => 'In alto al centro';

  @override
  String get posAltoDestra => 'In alto a destra';

  @override
  String get posAltoSinistra => 'In alto a sinistra';

  @override
  String get posCentroDestra => 'Al centro a destra';

  @override
  String get ovScuro => 'Etichetta scura';

  @override
  String get ovChiaro => 'Etichetta chiara';

  @override
  String get ovSoloTesto => 'Solo testo';

  @override
  String get scorriAcceso => 'Indicatore';

  @override
  String get scorriTesto => 'Testo';

  @override
  String get scorriTestoEtichetta => 'Testo dell\'indicatore';

  @override
  String get strAllinea => 'Allinea';

  @override
  String get strDistribuisci => 'Distribuisci';

  @override
  String get strRaggruppa => 'Raggruppa';

  @override
  String get strSepara => 'Separa';

  @override
  String get strScambia => 'Scambia';

  @override
  String get strBlocca => 'Blocca';

  @override
  String get strSblocca => 'Sblocca';

  @override
  String get strDisponi => 'Disponi';

  @override
  String get selezionaPiuAiuto => 'Tocca gli elementi da scegliere';

  @override
  String get allSinistra => 'A sinistra';

  @override
  String get allCentroOrizz => 'Centro orizzontale';

  @override
  String get allDestra => 'A destra';

  @override
  String get allAlto => 'In alto';

  @override
  String get allCentroVert => 'Centro verticale';

  @override
  String get allBasso => 'In basso';

  @override
  String get distOrizzontale => 'Spazi uguali in orizzontale';

  @override
  String get distVerticale => 'Spazi uguali in verticale';

  @override
  String get dispLivello => 'Livello';

  @override
  String get dispSposta => 'Sposta';

  @override
  String get dispDavanti => 'Porta davanti';

  @override
  String get dispDietro => 'Manda dietro';

  @override
  String passoPx(int n) {
    return '$n px';
  }

  @override
  String get frecciaSu => 'Su';

  @override
  String get frecciaGiu => 'Giù';

  @override
  String get frecciaSinistra => 'Sinistra';

  @override
  String get frecciaDestra => 'Destra';

  @override
  String get menuCopia => 'Copia';

  @override
  String get menuTaglia => 'Taglia';

  @override
  String get menuIncolla => 'Incolla qui';

  @override
  String get menuSelezionaPiu => 'Seleziona più';

  @override
  String get menuSelezionaTutto => 'Seleziona tutto';

  @override
  String get menuSpostaInPagina => 'Sposta in pagina…';

  @override
  String get menuAggiungiTesto => 'Aggiungi testo qui';

  @override
  String get menuAggiungiForma => 'Aggiungi forma qui';

  @override
  String get menuAzioniPagina => 'Azioni della pagina';

  @override
  String get menuScegliPagina => 'Sposta nella pagina';

  @override
  String menuPaginaNumero(int n) {
    return 'Pagina $n';
  }

  @override
  String get panoramicaAiuto =>
      'Tocca per andare alla pagina · trascina per riordinare · tieni premuto per le azioni';

  @override
  String panoramicaPagina(int n) {
    return 'Pagina $n, trascina per spostarla';
  }

  @override
  String get anteprimaChiudi => 'Chiudi l\'anteprima';

  @override
  String anteprimaPagina(int n, int tot) {
    return 'Pagina $n di $tot';
  }

  @override
  String get strumentoCronologia => 'Cronologia';

  @override
  String cronEtichetta(int n, String nome) {
    return 'Passaggio $n: $nome';
  }

  @override
  String get cronAttuale => 'Attuale';

  @override
  String get cambAperto => 'Progetto aperto';

  @override
  String get cambPaginaDuplicata => 'Pagina duplicata';

  @override
  String get cambPaginaAggiunta => 'Pagina aggiunta';

  @override
  String get cambPaginaEliminata => 'Pagina eliminata';

  @override
  String get cambFotoSostituite => 'Foto sostituite';

  @override
  String get cambElementiCambiati => 'Elementi cambiati';

  @override
  String cambFotoAggiunte(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n foto aggiunte',
      one: 'Foto aggiunta',
    );
    return '$_temp0';
  }

  @override
  String cambTestiAggiunti(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n testi aggiunti',
      one: 'Testo aggiunto',
    );
    return '$_temp0';
  }

  @override
  String cambFormeAggiunte(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n forme aggiunte',
      one: 'Forma aggiunta',
    );
    return '$_temp0';
  }

  @override
  String cambElementiAggiunti(int n) {
    return '$n elementi aggiunti';
  }

  @override
  String cambFotoEliminate(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n foto eliminate',
      one: 'Foto eliminata',
    );
    return '$_temp0';
  }

  @override
  String cambTestiEliminati(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n testi eliminati',
      one: 'Testo eliminato',
    );
    return '$_temp0';
  }

  @override
  String cambFormeEliminate(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n forme eliminate',
      one: 'Forma eliminata',
    );
    return '$_temp0';
  }

  @override
  String cambElementiEliminati(int n) {
    return '$n elementi eliminati';
  }

  @override
  String cambPagine(int da, int a) {
    return 'Pagine: $da → $a';
  }

  @override
  String get cambFormatoPagina => 'Formato della pagina';

  @override
  String cambDisposizione(String nome) {
    return 'Disposizione: $nome';
  }

  @override
  String get cambStileMosaico => 'Stile mosaico';

  @override
  String get cambVersoPellicola => 'Verso della pellicola';

  @override
  String get cambOmbraPolaroid => 'Ombra delle Polaroid';

  @override
  String get cambRilievoPolaroid => 'Rilievo delle Polaroid';

  @override
  String get cambFotoRimescolate => 'Foto rimescolate';

  @override
  String get cambLucchettoPagine => 'Lucchetto delle pagine';

  @override
  String get cambPagineACavallo => 'Pagine a cavallo';

  @override
  String get cambDisposizionePagina => 'Disposizione della pagina';

  @override
  String get cambFotoPerPagina => 'Foto per pagina';

  @override
  String get cambSpaziatura => 'Spaziatura';

  @override
  String get cambMargine => 'Margine';

  @override
  String get cambSfondo => 'Sfondo';

  @override
  String get cambNumeriPagina => 'Numeri di pagina';

  @override
  String get cambScorri => 'Indicatore «scorri»';

  @override
  String get cambNomeFile => 'Nome dei file';

  @override
  String get cambModifica => 'Modifica';

  @override
  String get cambRaggruppati => 'Elementi raggruppati';

  @override
  String get cambSeparati => 'Gruppo separato';

  @override
  String get cambOrdineFoto => 'Ordine delle foto';

  @override
  String get cambLivello => 'Livello cambiato';

  @override
  String get cambBloccoPosizione => 'Blocco della posizione';

  @override
  String cambNSpostati(int n) {
    return '$n elementi spostati';
  }

  @override
  String get cambDispAggiornata => 'Disposizione aggiornata';

  @override
  String cambNModificati(int n) {
    return '$n elementi modificati';
  }

  @override
  String cambSpostato(String tipo) {
    String _temp0 = intl.Intl.selectLogic(tipo, {
      'photo': 'Foto spostata',
      'text': 'Testo spostato',
      'shape': 'Forma spostata',
      'caption': 'Sottotitoli spostati',
      'other': 'Elemento spostato',
    });
    return '$_temp0';
  }

  @override
  String cambRidimensionato(String tipo) {
    String _temp0 = intl.Intl.selectLogic(tipo, {
      'photo': 'Foto ridimensionata',
      'text': 'Testo ridimensionato',
      'shape': 'Forma ridimensionata',
      'caption': 'Sottotitoli ridimensionati',
      'other': 'Elemento ridimensionato',
    });
    return '$_temp0';
  }

  @override
  String cambRuotato(String tipo) {
    String _temp0 = intl.Intl.selectLogic(tipo, {
      'photo': 'Foto ruotata',
      'text': 'Testo ruotato',
      'shape': 'Forma ruotata',
      'caption': 'Sottotitoli ruotati',
      'other': 'Elemento ruotato',
    });
    return '$_temp0';
  }

  @override
  String cambStile(String tipo) {
    String _temp0 = intl.Intl.selectLogic(tipo, {
      'photo': 'Stile della foto',
      'text': 'Stile del testo',
      'shape': 'Stile della forma',
      'caption': 'Stile dei sottotitoli',
      'other': 'Stile',
    });
    return '$_temp0';
  }

  @override
  String get cambTestoModificato => 'Testo modificato';

  @override
  String get cambColoriFoto => 'Colori della foto';

  @override
  String get cambTaglioVideo => 'Taglio del video';

  @override
  String get cambCopertinaVideo => 'Copertina del video';

  @override
  String get cambAudioVideo => 'Audio del video';

  @override
  String get cambInquadratura => 'Inquadratura della foto';

  @override
  String get cambFotoLibera => 'Foto libera';

  @override
  String get cambFotoInDisposizione => 'Foto nella disposizione';

  @override
  String avvisoPaginaDuplicata(int n) {
    return 'Pagina duplicata: la copia è la pagina $n';
  }

  @override
  String avvisoPaginaEliminata(int n) {
    return 'Pagina $n eliminata';
  }

  @override
  String avvisoPaginaSpostata(int n) {
    return 'Pagina spostata in posizione $n';
  }

  @override
  String avvisoPaginaBloccata(int n) {
    return 'Pagina $n bloccata';
  }

  @override
  String avvisoPaginaSbloccata(int n) {
    return 'Pagina $n sbloccata';
  }

  @override
  String avvisoPaginaUnita(int n) {
    return 'Pagina $n unita alla successiva «a cavallo»';
  }

  @override
  String avvisoPaginaSeparata(int n) {
    return 'Pagina $n separata dalla successiva';
  }

  @override
  String get avvisoPagineRiordinate => 'Pagine riordinate';

  @override
  String avvisoRaggruppati(int n) {
    return '$n elementi raggruppati: si spostano insieme';
  }

  @override
  String get avvisoSeparati =>
      'Gruppo separato: ora gli elementi si spostano uno per uno';

  @override
  String get avvisoServeDue => 'Seleziona almeno 2 elementi da raggruppare';

  @override
  String get avvisoServeTre => 'Seleziona almeno 3 elementi per distribuirli';

  @override
  String get avvisoNessunGruppo => 'Nessun gruppo selezionato';

  @override
  String get avvisoPosizioneBloccata => 'Posizione bloccata';

  @override
  String get avvisoPosizioneSbloccata => 'Posizione sbloccata';

  @override
  String get avvisoPortatoDavanti => 'Portato davanti';

  @override
  String get avvisoMandatoDietro => 'Mandato dietro';

  @override
  String avvisoCopiati(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n elementi copiati',
      one: '1 elemento copiato',
    );
    return '$_temp0';
  }

  @override
  String avvisoTagliati(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n elementi tagliati',
      one: '1 elemento tagliato',
    );
    return '$_temp0';
  }

  @override
  String avvisoIncollati(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n elementi incollati',
      one: '1 elemento incollato',
    );
    return '$_temp0';
  }

  @override
  String get avvisoNienteDaIncollare =>
      'Non c\'è niente da incollare: copia prima foto, testi o forme';

  @override
  String avvisoFotoSpostate(int n) {
    return 'Foto spostate nella pagina $n';
  }

  @override
  String get espPagineSeparate => 'Pagine separate';

  @override
  String get espQuestaPagina => 'Questa pagina';

  @override
  String get espCollage => 'Collage intero';

  @override
  String get espTutte => 'Tutte';

  @override
  String get espNessuna => 'Nessuna';

  @override
  String get espFormato => 'Formato';

  @override
  String get espFormatoPng => 'PNG · massima qualità';

  @override
  String get espFormatoJpg => 'JPG · file leggeri';

  @override
  String get espQualita => 'Qualità JPG';

  @override
  String get espScala => 'Scala';

  @override
  String get espScala1 => '1× standard';

  @override
  String get espScala2 => '2× alta definizione';

  @override
  String get espNomeFile => 'Nome dei file';

  @override
  String get espNomeSuggerimento => 'frame';

  @override
  String espEsempioNome(String nome) {
    return 'Esempio: $nome';
  }

  @override
  String espMisure(int w, int h) {
    return 'Ogni immagine: $w×$h px';
  }

  @override
  String espMisureCollage(int w, int h) {
    return 'Immagine: $w×$h px';
  }

  @override
  String get espNessunaPagina => 'Scegli almeno una pagina';

  @override
  String get espDestinazione => 'Salva in';

  @override
  String get espGalleria => 'Galleria';

  @override
  String get espCondividi => 'Condividi';

  @override
  String get espSalvaInFile => 'Salva in File';

  @override
  String get espMancantiTitolo => 'Foto mancanti';

  @override
  String espMancanti(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n foto sulla tela non sono state trovate e resteranno vuote',
      one: '1 foto sulla tela non è stata trovata e resterà vuota',
    );
    return '$_temp0 nell\'immagine esportata. Esportare comunque?';
  }

  @override
  String get espTelaVuotaTitolo => 'Tela vuota';

  @override
  String get espTelaVuota => 'Non ci sono foto sulla tela. Esportare comunque?';

  @override
  String get espEsportaComunque => 'Esporta comunque';

  @override
  String get espCollageGrandeTitolo => 'Collage troppo grande';

  @override
  String espCollageGrande(int w, int h) {
    return 'A 2× il collage sarebbe di $w×$h px: troppo per la memoria del telefono. Puoi usare 1× oppure esportare le pagine separate.';
  }

  @override
  String espCollageGrande1x(int w, int h) {
    return 'Anche a 1× il collage sarebbe di $w×$h px: troppo per la memoria del telefono. Esporta le pagine separate.';
  }

  @override
  String get espUsa1x => 'Usa 1×';

  @override
  String get espUsaPagine => 'Pagine separate';

  @override
  String get espTitoloAvanzamento => 'Esportazione';

  @override
  String espFaseFoto(int pagina, int indice, int totale) {
    return 'Preparazione delle foto, pagina $pagina ($indice di $totale)…';
  }

  @override
  String espFasePagina(int pagina, int indice, int totale) {
    return 'Pagina $pagina ($indice di $totale)…';
  }

  @override
  String get espFaseComposizione => 'Composizione del collage…';

  @override
  String espFaseGalleria(int indice, int totale) {
    return 'Salvataggio in Galleria ($indice di $totale)…';
  }

  @override
  String get espFaseCondividi => 'Apertura di Condividi…';

  @override
  String espFaseFile(int indice, int totale) {
    return 'Salvataggio in File ($indice di $totale)…';
  }

  @override
  String get espAnnullando => 'Annullamento…';

  @override
  String get espFatto => 'Esportazione completata';

  @override
  String espSalvatoGalleria(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n immagini salvate',
      one: '1 immagine salvata',
    );
    return '$_temp0 nell\'album «ScrolleR Studio» della Galleria, in ordine di pagina';
  }

  @override
  String espSalvatoCondiviso(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n immagini pronte',
      one: '1 immagine pronta',
    );
    return '$_temp0 per la condivisione';
  }

  @override
  String espSalvatoFile(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n immagini salvate',
      one: '1 immagine salvata',
    );
    return '$_temp0 in File';
  }

  @override
  String get espIncompleta => 'Esportazione incompleta';

  @override
  String espNonSalvate(String nomi) {
    return 'Non salvate: $nomi';
  }

  @override
  String get espInterrotta =>
      'Esportazione interrotta: le pagine successive non sono state salvate.';

  @override
  String get espAnnullata => 'Esportazione annullata';

  @override
  String espErrore(String errore) {
    return 'Esportazione non riuscita: $errore';
  }

  @override
  String get espGalleriaNegata =>
      'Senza il permesso per la Galleria non posso salvare lì. Puoi usare Condividi o Salva in File.';

  @override
  String get espFine => 'Fine';

  @override
  String get videoMuto => 'muto';

  @override
  String get videoRiproduci => 'Riproduci';

  @override
  String get videoPausa => 'Pausa';

  @override
  String get strTaglia => 'Taglia';

  @override
  String get strCopertina => 'Copertina';

  @override
  String get strAudio => 'Audio';

  @override
  String get parInizio => 'Inizio';

  @override
  String get parFine => 'Fine';

  @override
  String videoInfoDurata(String durata, String usati) {
    return 'Durata $durata  ·  usati $usati';
  }

  @override
  String get videoSenzaAudio => 'senza audio';

  @override
  String get videoSenzaAudioAvviso => 'Questo video non ha audio';

  @override
  String videoLimiteReel(int minuti) {
    return 'Nei reel si usano al massimo $minuti minuti: scegli la parte con Inizio e Fine.';
  }

  @override
  String videoLimiteCarosello(int secondi) {
    return 'Nei caroselli si usano al massimo $secondi s: scegli la parte con Inizio e Fine, o converti il progetto in reel.';
  }

  @override
  String espFaseVideo(
    int pagina,
    int indice,
    int totale,
    int fotogramma,
    int fotogrammi,
  ) {
    return 'Pagina $pagina ($indice di $totale) · video MP4, fotogramma $fotogramma di $fotogrammi…';
  }

  @override
  String espVideoMp4(int larghezza, int altezza, int fps) {
    return 'Le pagine con un video escono in MP4 ($larghezza×$altezza px, $fps fps), con l\'audio dei video accesi.';
  }

  @override
  String get espVideoCollage =>
      'Nel collage intero i video compaiono con la copertina.';

  @override
  String get espVideoNonDisponibile =>
      'Su questo telefono i video non si esportano ancora in MP4: le pagine con un video escono come immagine, con la copertina.';

  @override
  String espVideoSalvati(int n, int larghezza, int altezza) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Le $n pagine con video sono MP4',
      one: 'La pagina con video è un MP4',
    );
    return '$_temp0 ($larghezza×$altezza px, 30 fps)';
  }

  @override
  String get condividiProgetto => 'Condividi progetto';

  @override
  String get importaProgetto => 'Importa progetto';

  @override
  String get scambioPreparo => 'Preparo il progetto…';

  @override
  String get zipAvvisoTitolo => 'Foto senza originale';

  @override
  String zipSoloAnteprima(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other:
          '$n foto non hanno più l\'originale: nello zip ci saranno le loro anteprime ridotte (lato lungo 1600 px).',
      one: '1 foto non ha più l\'originale: nello zip ci sarà la sua anteprima ridotta (lato lungo 1600 px).',
    );
    return '$_temp0';
  }

  @override
  String zipMancanti(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other:
          '$n file non ci sono più, nemmeno come anteprima: non saranno nello zip e sul PC compariranno come «Foto mancante».',
      one: '1 file non c\'è più, nemmeno come anteprima: non sarà nello zip e sul PC comparirà come «Foto mancante».',
    );
    return '$_temp0';
  }

  @override
  String get zipContinua => 'Crea comunque';

  @override
  String zipFile(String nome) {
    return 'Copio $nome';
  }

  @override
  String get zipPronto => 'Progetto pronto';

  @override
  String zipPronto2(int n, String dimensione) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n file copiati',
      one: '1 file copiato',
    );
    return '$_temp0 · $dimensione';
  }

  @override
  String get zipSpazio =>
      'Spazio insufficiente sul telefono. Libera un po\' di memoria e riprova.';

  @override
  String zipErrore(String errore) {
    return 'Non è stato possibile creare lo zip: $errore';
  }

  @override
  String get lavoroAnnullato => 'Operazione annullata';

  @override
  String get impScegli => 'Scegli un progetto (.zip o .scrlproj)';

  @override
  String impFile(String nome) {
    return 'Importo $nome';
  }

  @override
  String impFatto(String nome) {
    return '«$nome» è stato importato';
  }

  @override
  String impEstratti(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n foto e video importati.',
      one: '1 foto o video importato.',
      zero: 'Nessuna foto con il progetto: se mancano, si ricollegano dall\'editor.',
    );
    return '$_temp0';
  }

  @override
  String impAltriProgetti(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Lo zip conteneva altri $n progetti: non sono stati importati.',
      one: 'Lo zip conteneva un altro progetto: non è stato importato.',
    );
    return '$_temp0';
  }

  @override
  String get impApri => 'Apri progetto';

  @override
  String get impNonRiconosciuto =>
      'Questo file non è un progetto di ScrolleR Studio (.scrlproj o .zip).';

  @override
  String get impNessunProgetto =>
      'Nello zip non c\'è nessun progetto (.scrlproj).';

  @override
  String get impNonValido =>
      'Il progetto è rovinato o non è di ScrolleR Studio.';

  @override
  String impZipNonSupportato(String motivo) {
    return 'Questo zip non si può aprire qui: $motivo.';
  }

  @override
  String impErrore(String errore) {
    return 'Importazione non riuscita: $errore';
  }

  @override
  String impDaFoto(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Progetto creato con $n foto',
      one: 'Progetto creato con 1 foto',
    );
    return '$_temp0';
  }

  @override
  String impScartati(String nomi) {
    return 'Non leggibili, saltate: $nomi';
  }

  @override
  String manBadge(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n foto mancanti',
      one: '1 foto mancante',
    );
    return '$_temp0';
  }

  @override
  String get manTitolo => 'Foto mancanti';

  @override
  String get manIntro =>
      'Queste foto non sono più nella galleria o non si trovano. Restano sulla tela con la loro anteprima e le loro impostazioni: ricollegale per tornare agli originali.';

  @override
  String get manCerca => 'Cerca nella galleria per nome';

  @override
  String get manRicollega => 'Ricollega';

  @override
  String manUsi(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Usata $n volte',
      one: 'Usata 1 volta',
      zero: 'Solo in libreria',
    );
    return '$_temp0';
  }

  @override
  String manRicerca(int n) {
    return 'Cerco nella galleria… ($n guardati)';
  }

  @override
  String manRitrovate(int n, int tot) {
    return 'Ritrovate $n su $tot';
  }

  @override
  String get manNessunaTrovata =>
      'Nessuna trovata per nome nella galleria. Puoi sceglierle a mano con «Ricollega».';

  @override
  String get manTutte => 'Tutte le foto sono al loro posto.';

  @override
  String get manSenzaAccesso =>
      'Per cercare nella galleria serve l\'accesso alle foto. Puoi darlo dalle impostazioni del telefono, oppure ricollegare le foto una per una.';

  @override
  String get manAperturaTitolo => 'Foto non trovate';

  @override
  String manApertura(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n foto del progetto non si trovano più',
      one: '1 foto del progetto non si trova più',
    );
    return '$_temp0. Restano sulla tela con la loro anteprima: puoi cercarle nella galleria o ricollegarle una per una.';
  }

  @override
  String get manPiuTardi => 'Più tardi';

  @override
  String get manVediElenco => 'Vedi elenco';

  @override
  String manScegli(String nome) {
    return 'Dov\'è ora «$nome»?';
  }

  @override
  String get manAnteprima => 'Si vede l\'anteprima salvata';

  @override
  String avvisoFotoRicollegate(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n foto ricollegate',
      one: '1 foto ricollegata',
    );
    return '$_temp0';
  }

  @override
  String espOriginaliMancanti(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n foto hanno l\'originale mancante',
      one: '1 foto ha l\'originale mancante',
    );
    return '$_temp0: nell\'immagine esportata uscirà alla qualità dell\'anteprima (lato lungo 1600 px). Esportare comunque?';
  }

  @override
  String get espRicollega => 'Ricollega';

  @override
  String get strRicollega => 'Ricollega';

  @override
  String get suggerimentoTocca => 'Tocca una foto per selezionarla';

  @override
  String get suggerimentoPremuto =>
      'Tieni premuto su un elemento per copiarlo, bloccarlo o eliminarlo';

  @override
  String get suggerimentoScorri => 'Scorri di lato per cambiare pagina';

  @override
  String get suggerimentoChiudi => 'Tocca per chiudere';

  @override
  String get impostazioni => 'Impostazioni';

  @override
  String get impAiuto => 'Aiuto';

  @override
  String get impAggiornamenti => 'Aggiornamenti';

  @override
  String get impRegistro => 'Registro errori';

  @override
  String get impInfo => 'Informazioni';

  @override
  String get impGesti => 'Gesti';

  @override
  String get impGestiAiuto => 'Come si usano tela e pannelli';

  @override
  String get impSuggerimenti => 'Rivedi i suggerimenti';

  @override
  String get impSuggerimentiAiuto =>
      'I tre suggerimenti del primo avvio torneranno nell\'editor';

  @override
  String get impSuggerimentiRimessi => 'I suggerimenti torneranno nell\'editor';

  @override
  String impVersione(String versione) {
    return 'Versione $versione';
  }

  @override
  String get impLicenze => 'Licenze';

  @override
  String get impLicenzeAiuto => 'Componenti e caratteri inclusi';

  @override
  String get impPrivacy =>
      'Nessuna pubblicità, nessun tracciamento, nessun account. La rete serve solo a cercare gli aggiornamenti.';

  @override
  String get gestiTitolo => 'Gesti';

  @override
  String get gestiSulla => 'Sulla tela';

  @override
  String get gestiNeiPannelli => 'Nei pannelli e nelle barre';

  @override
  String get gestiNellePagine => 'Pagine e Panoramica';

  @override
  String get gestoTocca => 'Tocca';

  @override
  String get gestoToccaDesc =>
      'Seleziona una foto, un testo o una forma. Toccando il vuoto, la selezione sparisce.';

  @override
  String get gestoDoppio => 'Doppio tocco su un testo';

  @override
  String get gestoDoppioDesc => 'Apre la tastiera per scriverci.';

  @override
  String get gestoPremuto => 'Tieni premuto su un elemento';

  @override
  String get gestoPremutoDesc =>
      'Copia, taglia, duplica, blocca, porta davanti o dietro, sposta in un\'altra pagina, elimina.';

  @override
  String get gestoPremutoVuoto => 'Tieni premuto sul vuoto';

  @override
  String get gestoPremutoVuotoDesc =>
      'Incolla qui, aggiungi un testo o una forma, seleziona tutto e le azioni della pagina.';

  @override
  String get gestoTrascina => 'Trascina un elemento';

  @override
  String get gestoTrascinaDesc =>
      'Lo sposta e si aggancia alle linee degli altri. Verso il bordo dello schermo passa alla pagina vicina.';

  @override
  String get gestoManiglie => 'Trascina una maniglia';

  @override
  String get gestoManiglieDesc =>
      'Ridimensiona la foto o la forma selezionata.';

  @override
  String get gestoPizzica => 'Pizzica con due dita';

  @override
  String get gestoPizzicaDesc =>
      'Ingrandisce o riduce l\'elemento; girando le dita lo ruota, con piccoli scatti agli angoli più comuni.';

  @override
  String get gestoScorri => 'Scorri di lato';

  @override
  String get gestoScorriDesc => 'Cambia pagina, una alla volta.';

  @override
  String get gestoCursore => 'Doppio tocco su un cursore';

  @override
  String get gestoCursoreDesc => 'Riporta il valore a quello iniziale.';

  @override
  String get gestoPannello => 'Trascina il pannello verso il basso';

  @override
  String get gestoPannelloDesc =>
      'Chiude lo strumento senza applicare, come ✕.';

  @override
  String get gestoConfronto => 'Tieni premuto ◐';

  @override
  String get gestoConfrontoDesc =>
      'Mostra la foto com\'era prima; rilasciando torna con le modifiche.';

  @override
  String get gestoIndietro => 'Gesto «indietro» del telefono';

  @override
  String get gestoIndietroDesc =>
      'Torna al livello di prima di un menu o di uno strumento, poi chiude lo strumento, poi toglie la selezione, poi esce dal progetto.';

  @override
  String get gestoAnnullaLungo => 'Tieni premuto Annulla';

  @override
  String get gestoAnnullaLungoDesc => 'Apre la Cronologia.';

  @override
  String get gestoPanoramica => 'Panoramica: tocca, trascina, tieni premuto';

  @override
  String get gestoPanoramicaDesc =>
      'Tocca per andare alla pagina, trascina per riordinare, tieni premuto per le azioni.';

  @override
  String get gestoPuntini => 'Puntini delle pagine';

  @override
  String get gestoPuntiniDesc => 'Toccane uno per saltare a quella pagina.';

  @override
  String get aggControlla => 'Cerca nuove versioni';

  @override
  String get aggControllaAiuto =>
      'Una volta al giorno, all\'apertura. È l\'unico uso della rete e non invia dati personali.';

  @override
  String get aggControllaOra => 'Controlla adesso';

  @override
  String get aggInCorso => 'Controllo in corso…';

  @override
  String get aggAggiornato => 'L\'app è aggiornata';

  @override
  String aggDisponibile(String versione) {
    return 'È disponibile la versione $versione';
  }

  @override
  String get aggErrore =>
      'Non riesco a controllare: serve una connessione a Internet';

  @override
  String get aggScarica => 'Scarica';

  @override
  String get aggNonApribile => 'Non riesco ad aprire il browser';

  @override
  String get aggChiudi => 'Nascondi l\'avviso';

  @override
  String get regAiuto =>
      'Gli errori inattesi si annotano solo su questo telefono. Il file non parte da solo: se vuoi segnalare un problema, condividilo tu. I percorsi di cartelle e foto sono già tolti.';

  @override
  String get regCondividi => 'Condividi il registro';

  @override
  String get regVuoto => 'Nessun errore registrato';

  @override
  String get regPieno => 'Ci sono errori registrati';

  @override
  String get regCancella => 'Svuota il registro';

  @override
  String get regCancellaChiede => 'Svuotare il registro degli errori?';

  @override
  String get regCancellato => 'Registro svuotato';

  @override
  String get regNonCondiviso => 'Non riesco a condividere il registro';

  @override
  String telaPagina(int pagina, int totale) {
    return 'Pagina $pagina di $totale';
  }

  @override
  String telaFoto(int n) {
    return 'Foto $n';
  }

  @override
  String telaVideo(int n) {
    return 'Video $n';
  }

  @override
  String telaTesto(String testo) {
    return 'Testo: $testo';
  }

  @override
  String telaForma(int n) {
    return 'Forma $n';
  }

  @override
  String telaBloccato(String nome) {
    return '$nome, bloccato';
  }

  @override
  String get telaApriMenu => 'Azioni';

  @override
  String espPagineScelte(int n, int tot) {
    return '$n di $tot pagine';
  }

  @override
  String get tutteLeOpzioni => 'Tutte le opzioni';

  @override
  String get sfDirezione => 'Direzione';

  @override
  String get catAspetto => 'Aspetto';

  @override
  String get catAltro => 'Altro';

  @override
  String get catGruppo => 'Gruppo';

  @override
  String get catVideo => 'Video';

  @override
  String get usoFormato45 => 'Post nel feed';

  @override
  String get usoFormato916 => 'Storie';

  @override
  String get usoFormato34 => 'Griglia del profilo';

  @override
  String get vistaCentra => 'Centra la pagina';

  @override
  String pesoProgetto(String peso) {
    return 'Occupa $peso sul telefono';
  }

  @override
  String get pesoCalcolo => 'Calcolo dello spazio…';

  @override
  String get pesoNota =>
      'Le foto della galleria non sono contate: restano nella galleria, il progetto le collega.';

  @override
  String get ritModoRettangolo => 'Rettangolo';

  @override
  String get ritModoSagoma => 'Sagoma';

  @override
  String get ritApplicaSagoma => 'Applica la sagoma';

  @override
  String get ritTogliSagomaNota =>
      'Applicando il rettangolo la sagoma viene tolta.';

  @override
  String get sagIndietro => 'Indietro';

  @override
  String get sagAvanti => 'Avanti';

  @override
  String get sagRiapri => 'Riapri';

  @override
  String get sagChiudi => 'Chiudi';

  @override
  String get sagTogli => 'Togli sagoma';

  @override
  String get sagRisultato => 'Risultato';

  @override
  String get sagMorbidezza => 'Morbidezza';

  @override
  String get sagAiutoVuota =>
      'Disegna col dito attorno al soggetto, oppure tocca per mettere i punti. Due dita per ingrandire.';

  @override
  String get sagAiutoAperta =>
      'Continua il contorno e torna al primo punto per chiuderlo, oppure tocca «Chiudi».';

  @override
  String get sagAiutoChiusa =>
      'Trascina i punti o la sagoma. Doppio tocco su un lato aggiunge un punto, tocco lungo su un punto lo toglie.';

  @override
  String get sagAiutoRisultato =>
      'Così si vedrà la foto: fuori dalla sagoma è trasparente.';

  @override
  String get avvisoSagomaApplicata =>
      'Sagoma applicata: bordo e ombra ora seguono il soggetto';

  @override
  String get avvisoSagomaTolta => 'Sagoma tolta: la foto torna intera';

  @override
  String get avvisoSagomaSalvata => 'Sagoma salvata in Galleria come PNG';

  @override
  String get avvisoSagomaNonSalvata => 'Non riesco a salvare la sagoma';

  @override
  String get strTogliSagoma => 'Togli sagoma';

  @override
  String get strSalvaSagoma => 'Salva PNG';

  @override
  String get sagSalvataggio => 'Preparo il PNG della sagoma…';

  @override
  String get sagAnnullaSalvataggio => 'Annulla';

  @override
  String get tipoCarosello => 'Carosello o foto';

  @override
  String get tipoCaroselloDesc => 'Fino a 30 pagine, video fino a 60 s';

  @override
  String get tipoReel => 'Reel';

  @override
  String get tipoReelDesc => 'Una pagina, video fino a 5 minuti';

  @override
  String get usoFormatoConsigliato => 'Consigliato';

  @override
  String get formatoAiutoReel =>
      'Il reel ha una pagina sola; si può convertire in carosello da Pagine → Formato.';

  @override
  String get convertiInReel => 'Converti in reel';

  @override
  String get convertiInCarosello => 'Converti in carosello';

  @override
  String get cambConvertitoReel => 'Convertito in reel';

  @override
  String get cambConvertitoCarosello => 'Convertito in carosello';

  @override
  String get noticeReelUnaPagina => 'Un reel ha una sola pagina';

  @override
  String get noticeReelTogliPagine =>
      'Un reel ha una sola pagina: togli le altre pagine, poi converti il progetto';

  @override
  String get noticeVideoPrimoMinuto =>
      'Convertito in carosello: i video più lunghi di 60 s usano il primo minuto. Scegli la parte con Inizio e Fine.';

  @override
  String get avvisoConvertitoReel =>
      'Progetto convertito in reel: i video arrivano a 5 minuti';

  @override
  String get avvisoConvertitoCarosello => 'Progetto convertito in carosello';

  @override
  String cambSottotitoliAggiunti(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n sottotitoli aggiunti',
      one: 'Sottotitoli aggiunti',
    );
    return '$_temp0';
  }

  @override
  String cambSottotitoliEliminati(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n sottotitoli eliminati',
      one: 'Sottotitoli eliminati',
    );
    return '$_temp0';
  }

  @override
  String get cambSottotitoliModificati => 'Sottotitoli modificati';

  @override
  String telaSottotitoli(String testo) {
    return 'Sottotitoli: $testo';
  }

  @override
  String get disegnoSottotitoli => 'Sottotitoli';

  @override
  String get strSottotitoli => 'Sottotitoli';

  @override
  String get strLarghezza => 'Larghezza';

  @override
  String get sotTraduzione => 'Traduzione';

  @override
  String get sotMostraTraduzione => 'Mostra';

  @override
  String get sotColoreTraduzione => 'Colore della traduzione';

  @override
  String get sotDimensioneTraduzione => 'Dimensione della traduzione';

  @override
  String get sotChiudi => 'Chiudi senza salvare';

  @override
  String get sotFatto => 'Fatto';

  @override
  String get sotTesto => 'Testo';

  @override
  String get sotFileSrt => 'File .srt';

  @override
  String get sotImportaSrt => 'Importa .srt';

  @override
  String get sotCondividiSrt => 'Condividi .srt';

  @override
  String get sotSrtVuoto =>
      'Nel file non ho trovato sottotitoli in formato .srt.';

  @override
  String get sotSrtNiente => 'Non ci sono ancora frasi con i tempi.';

  @override
  String sotImportaDomanda(int n) {
    return 'Il file ha $n frasi. Cosa ne faccio?';
  }

  @override
  String get sotSostituisci => 'Sostituisci le frasi';

  @override
  String get sotComeTraduzione => 'Usale come traduzione';

  @override
  String get sotScartaDomanda =>
      'Chiudere senza tenere le modifiche ai sottotitoli?';

  @override
  String get sotContinua => 'Continua';

  @override
  String get sotScarta => 'Scarta';

  @override
  String get sotLetturaAudio => 'Lettura dell\'audio…';

  @override
  String get sotSenzaAudio =>
      'Il video non ha audio: i tempi si distribuiscono su tutto il video.';

  @override
  String get sotAudioIlleggibile =>
      'Audio non leggibile: i tempi si distribuiscono su tutto il video.';

  @override
  String get sotStrisciaTempo => 'Striscia del tempo';

  @override
  String get sotIndietro3 => 'Indietro di 3 secondi';

  @override
  String get sotAvanti3 => 'Avanti di 3 secondi';

  @override
  String sotVelocita(String v) {
    return '$v×';
  }

  @override
  String get sotScegliFrase => 'Tocca una frase sulla striscia per ritoccarla';

  @override
  String get sotTempiAudio => 'Tempi dall\'audio';

  @override
  String get sotIniziaQui => 'Inizia qui';

  @override
  String get sotFinisciQui => 'Finisci qui';

  @override
  String get sotDividiQui => 'Dividi qui';

  @override
  String get sotUnisci => 'Unisci alla successiva';

  @override
  String get sotInizio => 'Inizio';

  @override
  String get sotFine => 'Fine';

  @override
  String get sotMeno01 => '−0,1 s';

  @override
  String get sotPiu01 => '+0,1 s';

  @override
  String get sotVuoto => 'Scrivi o incolla il testo, una frase per riga';

  @override
  String get sotIncolla => 'Incolla';

  @override
  String get sotLinguaTraduzione => 'Lingua della traduzione';
}
