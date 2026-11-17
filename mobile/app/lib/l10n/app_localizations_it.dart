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
}
