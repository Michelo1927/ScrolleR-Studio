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
  String get barraDisposizione => 'Disposizione';

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
  String get strumentoDisposizione => 'Disposizione';

  @override
  String get parDisposizione => 'Disposizione';

  @override
  String get parMosaico => 'Mosaico';

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
  String libreriaTitolo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Libreria · $n foto',
      one: 'Libreria · 1 foto',
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
  String get libreriaVuota => 'Aggiungi le foto dal telefono';

  @override
  String get aggiungiDalTelefono => 'Aggiungi dal telefono';

  @override
  String get aggiungiAllaTela => 'Aggiungi alla tela';

  @override
  String get comeFotoLibera => 'Come foto libera';

  @override
  String get soloQueste => 'Solo queste';

  @override
  String get rimuoviDallaLibreria => 'Rimuovi dalla libreria';

  @override
  String get mettiTutte => 'Metti tutte';

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
  String get azDeforma => 'Deforma';

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
}
