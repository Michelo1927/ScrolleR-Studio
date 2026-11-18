// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class TestiEn extends Testi {
  TestiEn([String locale = 'en']) : super(locale);

  @override
  String get appTitolo => 'ScrolleR Studio';

  @override
  String get homeVuotaTitolo => 'No projects';

  @override
  String get homeVuotaAiuto => 'Create your first carousel';

  @override
  String get nuovoProgetto => 'New';

  @override
  String get inArrivo => 'Coming in a future version';

  @override
  String get proveApri => 'Tests';

  @override
  String get proveTitolo => 'Phase 2 tests';

  @override
  String get proveGalleria => 'Gallery';

  @override
  String get accessoCompleto => 'Access to all photos and videos';

  @override
  String get accessoParziale => 'Access to selected photos and videos only';

  @override
  String get accessoNegato => 'No access to the gallery';

  @override
  String get accessoDaChiedere =>
      'Photos stay in your gallery: the project links them without copying.';

  @override
  String get consentiAccesso => 'Allow access';

  @override
  String get scegliAltreFoto => 'Choose more photos';

  @override
  String get apriImpostazioni => 'Open settings';

  @override
  String get scegliDalTelefono => 'Choose from phone';

  @override
  String fileCopiati(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n files copied into the project',
      one: '1 file copied into the project',
    );
    return '$_temp0';
  }

  @override
  String get creaPagina => 'Create page';

  @override
  String get esportaVideo => 'Export MP4';

  @override
  String get progettiDiProva => 'Projects from the computer';

  @override
  String progettiDiProvaAiuto(String cartella) {
    return 'Copy each project into its own folder (with .scrlproj and media/) in: $cartella';
  }

  @override
  String paginaDiTotale(int numero, int totale) {
    return 'Page $numero of $totale';
  }

  @override
  String get fotoMancante => 'Missing photo';

  @override
  String get originaleMancante => 'Original missing';

  @override
  String get numeroPaginaDi => 'of';

  @override
  String get esportazioneInCorso => 'Exporting MP4…';

  @override
  String get annulla => 'Cancel';

  @override
  String videoFatto(int fotogrammi, String ms) {
    return 'MP4 saved to the gallery: $fotogrammi frames, $ms ms per frame';
  }

  @override
  String videoErrore(String errore) {
    return 'Export failed: $errore';
  }

  @override
  String get videoAnnullato => 'Export cancelled';

  @override
  String get videoNonDisponibile =>
      'Videos are not available on this phone yet';

  @override
  String get scegliUnVideo => 'Choose at least one video';

  @override
  String get progettoNonValido => 'Unreadable project';

  @override
  String get rinomina => 'Rename';

  @override
  String get duplica => 'Duplicate';

  @override
  String get elimina => 'Delete';

  @override
  String copiaDi(String nome) {
    return 'Copy of $nome';
  }

  @override
  String eliminaProgettoChiede(String nome) {
    return 'Delete “$nome”?';
  }

  @override
  String get eliminaProgettoAiuto =>
      'The project is removed from this phone. Photos in your gallery are not touched.';

  @override
  String get nomeProgetto => 'Project name';

  @override
  String get fatto => 'Done';

  @override
  String numeroPagine(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n pages',
      one: '1 page',
    );
    return '$_temp0';
  }

  @override
  String nomeProgettoNuovo(int n) {
    return 'Project $n';
  }

  @override
  String get passoFormato => 'Format';

  @override
  String get passoFoto => 'Choose photos';

  @override
  String creaConFoto(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Create with $n photos',
      one: 'Create with 1 photo',
      zero: 'Create',
    );
    return '$_temp0';
  }

  @override
  String get formato0 => '3:4 portrait';

  @override
  String get formato1 => '4:3 landscape';

  @override
  String get formato2 => '4:5 Instagram';

  @override
  String get formato3 => '1:1 square';

  @override
  String get formato4 => '9:16 story';

  @override
  String get formato5 => '16:9 widescreen';

  @override
  String get formato6 => '2:3 portrait photo';

  @override
  String get formato7 => '3:2 landscape photo';

  @override
  String get formato8 => 'Custom';

  @override
  String get larghezzaPixel => 'Width (px)';

  @override
  String get altezzaPixel => 'Height (px)';

  @override
  String get formatoAiuto =>
      'The format applies to every page of the carousel.';

  @override
  String get continua => 'Continue';

  @override
  String get salta => 'Skip';

  @override
  String fotoNumero(int n) {
    return 'Photo $n';
  }

  @override
  String aggiungiNFoto(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Add $n photos',
      one: 'Add 1 photo',
      zero: 'Add',
    );
    return '$_temp0';
  }

  @override
  String get tela => 'Canvas';

  @override
  String etichettaPagina(int n) {
    return 'Page $n';
  }

  @override
  String get etichettaBloccata => 'Locked';

  @override
  String etichettaACavallo(int a, int b) {
    return 'Spanning $a–$b';
  }

  @override
  String etichettaFoto(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n photos',
      one: '1 photo',
      zero: 'No photos',
    );
    return '$_temp0';
  }

  @override
  String get paginaVuota => 'Tap ＋ to add photos';

  @override
  String get indietro => 'Back';

  @override
  String get ripeti => 'Redo';

  @override
  String get anteprima => 'Preview';

  @override
  String get esporta => 'Export';

  @override
  String get paginaPrecedente => 'Previous page';

  @override
  String get paginaSuccessiva => 'Next page';

  @override
  String vaiAllaPagina(int n) {
    return 'Go to page $n';
  }

  @override
  String get panoramica => 'Overview';

  @override
  String get barraFoto => 'Photos';

  @override
  String get barraDisposizione => 'Layout';

  @override
  String get barraAggiungi => 'Add';

  @override
  String get barraPagine => 'Pages';

  @override
  String get barraStile => 'Style';

  @override
  String get deseleziona => 'Deselect';

  @override
  String get inDisposizione => 'In layout';

  @override
  String get libera => 'Free';

  @override
  String get conferma => 'Confirm';

  @override
  String get chiudi => 'Close';

  @override
  String get strumentoDisposizione => 'Layout';

  @override
  String get parDisposizione => 'Layout';

  @override
  String get parMosaico => 'Mosaic';

  @override
  String get parPagine => 'Pages';

  @override
  String get parFotoPerPagina => 'Photos per page';

  @override
  String get parFotoQui => 'Photos here';

  @override
  String get parSpaziatura => 'Spacing';

  @override
  String get parMargine => 'Margin';

  @override
  String get auto => 'Auto';

  @override
  String get unaPerPagina => 'One per page';

  @override
  String get rimescola => 'Shuffle';

  @override
  String numeroFoto(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n photos',
      one: '1 photo',
    );
    return '$_temp0';
  }

  @override
  String get menoPagine => 'One page less';

  @override
  String get piuPagine => 'One page more';

  @override
  String get menoFoto => 'One photo less';

  @override
  String get piuFoto => 'One photo more';

  @override
  String get ambitoTutto => 'Whole carousel';

  @override
  String get ambitoPagina => 'This page only';

  @override
  String get dispGriglia => 'Grid';

  @override
  String get dispMosaico => 'Mosaic';

  @override
  String get dispRighe => 'Rows';

  @override
  String get dispColonne => 'Columns';

  @override
  String get dispPolaroid => 'Polaroid';

  @override
  String get dispACavallo => 'Seamless';

  @override
  String get stileAutomatico => 'Automatic';

  @override
  String get stileInAlto => 'Large on top';

  @override
  String get stileInBasso => 'Large at bottom';

  @override
  String get stileASinistra => 'Large on left';

  @override
  String get stileADestra => 'Large on right';

  @override
  String get stileAlCentro => 'Large in center';

  @override
  String get stileDueGrandi => 'Two large';

  @override
  String get stileMuratura => 'Masonry';

  @override
  String libreriaTitolo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Library · $n photos',
      one: 'Library · 1 photo',
    );
    return '$_temp0';
  }

  @override
  String fotoScelte(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n photos selected',
      one: '1 photo selected',
    );
    return '$_temp0';
  }

  @override
  String get libreriaVuota => 'Add photos from your phone';

  @override
  String get aggiungiDalTelefono => 'Add from phone';

  @override
  String get aggiungiAllaTela => 'Add to canvas';

  @override
  String get comeFotoLibera => 'As free photo';

  @override
  String get soloQueste => 'Only these';

  @override
  String get rimuoviDallaLibreria => 'Remove from library';

  @override
  String get mettiTutte => 'Put all';

  @override
  String get svuotaTela => 'Clear canvas';

  @override
  String get fotoOVideo => 'Photo or video';

  @override
  String get paginaNuova => 'New page';

  @override
  String get testo => 'Text';

  @override
  String get forma => 'Shape';

  @override
  String avvisoFotoAggiunte(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n photos added',
      one: '1 photo added',
    );
    return '$_temp0';
  }

  @override
  String get avvisoEliminato => 'Item deleted';

  @override
  String avvisoEliminati(int n) {
    return '$n items deleted';
  }

  @override
  String get avvisoDuplicato => 'Item duplicated';

  @override
  String get avvisoTelaSvuotata => 'Canvas cleared';

  @override
  String get avvisoFotoLibera => 'Free photo: the layout no longer moves it';

  @override
  String get avvisoFotoInDisposizione => 'Photo put back in the layout';

  @override
  String get avvisoPaginaAggiunta => 'Page added';

  @override
  String get avvisoSalvataggioNonRiuscito =>
      'Could not save: will retry at the next change';

  @override
  String noticeSeamAddedPages(int n) {
    return '“Seamless” raised the pages to $n';
  }

  @override
  String noticeSeamRestoredPages(int n) {
    return 'Back to $n pages';
  }

  @override
  String get noticeAddedPageForPhotos => 'Page added for the photos';

  @override
  String noticePageLocked(int n) {
    return 'Page $n is locked: unlock it first';
  }

  @override
  String noticeSeamPagesLocked(int n) {
    return 'The seamless pages around position $n are locked';
  }

  @override
  String noticeSeamPageLocked(int n) {
    return 'Page $n is seamless and locked';
  }

  @override
  String noticeLockedSeamMustStayTogether(int a, int b) {
    return 'Pages $a and $b are seamless and locked: they must stay together';
  }

  @override
  String noticeMaxPages(int n) {
    return 'Maximum of $n pages reached';
  }

  @override
  String get noticeSinglePage => 'It is the only page: it cannot be deleted';

  @override
  String get noticeNothingToReorder =>
      'There is only one page: nothing to reorder';

  @override
  String get noticePageAtEdge => 'The page is already at the edge';

  @override
  String get noticeLastPage => 'It is the last page: nothing to join';

  @override
  String get noticeLockedPagesNoResize =>
      'Some pages are locked: the format cannot change';

  @override
  String get noticePerPageBackToAuto => '“Photos per page” goes back to Auto';

  @override
  String get noticeSeamIgnoresPageSettings =>
      'With “Seamless” per-page choices do not apply';

  @override
  String get noticeVideoKeptInPage => 'Videos cannot span two pages';

  @override
  String get noticeSwapNeedsTwo => 'Swapping needs exactly 2 photos';

  @override
  String get strRitaglia => 'Crop';

  @override
  String get strInquadra => 'Frame';

  @override
  String get strFiltri => 'Filters';

  @override
  String get strRegola => 'Adjust';

  @override
  String get strEffetti => 'Effects';

  @override
  String get strCornice => 'Frame style';

  @override
  String get strOmbra => 'Shadow';

  @override
  String get strRuota => 'Rotate';

  @override
  String get strCopiaStile => 'Copy style';

  @override
  String get strIncollaStile => 'Paste style';

  @override
  String get parZoom => 'Zoom';

  @override
  String get parOrizzontale => 'Horizontal';

  @override
  String get parVerticale => 'Vertical';

  @override
  String get parRuotaContenuto => 'Rotate content';

  @override
  String get parLuminosita => 'Brightness';

  @override
  String get parContrasto => 'Contrast';

  @override
  String get parOmbre => 'Shadows';

  @override
  String get parLuci => 'Highlights';

  @override
  String get parSaturazione => 'Saturation';

  @override
  String get parCalore => 'Warmth';

  @override
  String get parTinta => 'Tint';

  @override
  String get parNitidezza => 'Sharpness';

  @override
  String get parVignettatura => 'Vignette';

  @override
  String get parSbiadito => 'Fade';

  @override
  String get parGrana => 'Grain';

  @override
  String get parAngoli => 'Corners';

  @override
  String get parBordo => 'Border';

  @override
  String get parColore => 'Color';

  @override
  String get parOpacita => 'Opacity';

  @override
  String get parAngolo => 'Angle';

  @override
  String get azBiancoNero => 'B&W';

  @override
  String get azReimpostaColori => 'Reset colors';

  @override
  String get azApplicaATutte => 'Apply to all';

  @override
  String get azRiempi => 'Fill';

  @override
  String get azFotoIntera => 'Whole photo';

  @override
  String get azSoloRiquadro => 'Frame only';

  @override
  String get azReimposta => 'Reset';

  @override
  String get azProporzioniFoto => 'Photo ratio';

  @override
  String get azRiquadroDiPrima => 'Previous frame';

  @override
  String get azSinistra90 => '90° left';

  @override
  String get azDestra90 => '90° right';

  @override
  String get azDritta => 'Straighten';

  @override
  String get azSpecchiaOrizz => 'Flip horizontally';

  @override
  String get azSpecchiaVert => 'Flip vertically';

  @override
  String get confronta => 'Hold to compare with the original';

  @override
  String get filtroOriginale => 'Original';

  @override
  String get filtroVivace => 'Vivid';

  @override
  String get filtroEstate => 'Summer';

  @override
  String get filtroPellicola => 'Film';

  @override
  String get filtroVintage => 'Vintage';

  @override
  String get filtroBnContrastato => 'High-contrast B&W';

  @override
  String get filtroFreddo => 'Cool';

  @override
  String get filtroMorbido => 'Soft';

  @override
  String get filtroDrammatico => 'Dramatic';

  @override
  String get ritTitolo => 'Crop';

  @override
  String get ritLibera => 'Free';

  @override
  String get ritOriginale => 'Original';

  @override
  String get ritRiquadro => 'Frame';

  @override
  String get ritScambia => 'Swap portrait and landscape';

  @override
  String get ritAdatta => 'Fit the frame to the crop';

  @override
  String get ritNonLeggibile => 'This photo cannot be read';

  @override
  String get ritAnnulla => 'Close without cropping';

  @override
  String get ritApplica => 'Apply the crop';

  @override
  String get avvisoStileCopiato =>
      'Style copied: pick another photo and use “Paste style”';

  @override
  String get avvisoStileIncollato => 'Style pasted';

  @override
  String get avvisoRitaglioApplicato => 'Crop applied';

  @override
  String get avvisoRitaglioTolto => 'Crop removed: whole photo';

  @override
  String get avvisoModificaScartata => 'Change discarded';

  @override
  String get ripristina => 'Restore';

  @override
  String ritMisura(int w, int h) {
    return 'Crop: $w × $h px';
  }

  @override
  String coloreEtichetta(String hex) {
    return 'Color #$hex';
  }

  @override
  String get azContagocce => 'Eyedropper';

  @override
  String get azAltroColore => 'More';

  @override
  String get azColori => 'Colors';

  @override
  String get contagocceAiuto => 'Tap a point on the page to pick its color';

  @override
  String get nessuno => 'None';

  @override
  String get parEsadecimale => 'Hex';

  @override
  String get esadecimaleNonValido => 'Enter 6 digits, 0 to F';

  @override
  String get parTintaColore => 'Hue';

  @override
  String get testoSuggerimento => 'Write your text here';

  @override
  String get strModifica => 'Edit';

  @override
  String get catSenzaGrazie => 'Sans serif';

  @override
  String get catConGrazie => 'Serif';

  @override
  String get catTitolo => 'Display';

  @override
  String get catAMano => 'Handwriting';

  @override
  String get catMonospazio => 'Monospace';

  @override
  String avvisoCarattereMancante(String nome, String predefinito) {
    return '“$nome” is not available on this phone, so “$predefinito” is used. The name stays in the file until you choose another font.';
  }

  @override
  String get strCarattere => 'Font';

  @override
  String get strDimensione => 'Size';

  @override
  String get strSpaziatura => 'Spacing';

  @override
  String get parInterlinea => 'Line spacing';

  @override
  String get parSpaziaturaLettere => 'Letters';

  @override
  String get strFormato => 'Format';

  @override
  String get azGrassetto => 'Bold';

  @override
  String get azCorsivo => 'Italic';

  @override
  String get azSinistra => 'Left';

  @override
  String get azCentro => 'Center';

  @override
  String get azDestra => 'Right';

  @override
  String get strContorno => 'Outline';

  @override
  String get parSpessore => 'Thickness';

  @override
  String get strEtichetta => 'Label';

  @override
  String get formaRettangolo => 'Rectangle';

  @override
  String get formaEllisse => 'Ellipse';

  @override
  String get formaTriangolo => 'Triangle';

  @override
  String get formaRombo => 'Diamond';

  @override
  String get formaStella => 'Star';

  @override
  String get formaCuore => 'Heart';

  @override
  String get formaLinea => 'Line';

  @override
  String get formaFreccia => 'Arrow';

  @override
  String get formaDoppiaFreccia => 'Double arrow';

  @override
  String get strTipo => 'Type';

  @override
  String get strRiempimento => 'Fill';

  @override
  String get parTratto => 'Stroke';

  @override
  String get parLinea => 'Line';

  @override
  String get trattoContinuo => 'Solid';

  @override
  String get trattoTratteggiato => 'Dashed';

  @override
  String get trattoPuntini => 'Dotted';

  @override
  String get avvisoFormaAggiunta => 'Shape added';

  @override
  String get pagAggiungiPrima => 'Add before';

  @override
  String get pagAggiungiDopo => 'Add after';

  @override
  String get pagDuplica => 'Duplicate';

  @override
  String get pagSpostaIndietro => 'Move left';

  @override
  String get pagSpostaAvanti => 'Move right';

  @override
  String get pagBlocca => 'Lock';

  @override
  String get pagSblocca => 'Unlock';

  @override
  String get pagUnisci => 'Join across';

  @override
  String get pagSepara => 'Split';

  @override
  String get pagEsporta => 'Export this';

  @override
  String get pagElimina => 'Delete';

  @override
  String get pagFormato => 'Format';

  @override
  String get pagRiordina => 'Reorder';

  @override
  String get pagAzioni => 'Actions';

  @override
  String get pagMisure => 'Size';

  @override
  String get pagFormatoBloccato =>
      'The format can\'t change while pages are locked';

  @override
  String get stileSfondo => 'Background';

  @override
  String get stileNumeri => 'Page numbers';

  @override
  String get stileScorri => '“Swipe” hint';

  @override
  String get stileGuide => 'Guides';

  @override
  String get stileAggancio => 'Snap';

  @override
  String get sfTinta => 'Solid';

  @override
  String get sfSfumatura => 'Gradient';

  @override
  String get sfFotoSfocata => 'Blurred photo';

  @override
  String get sfColoreIniziale => 'Start colour';

  @override
  String get sfColoreFinale => 'End colour';

  @override
  String get sfDirVerticale => 'Top down';

  @override
  String get sfDirOrizzontale => 'Left to right';

  @override
  String get sfDirDiagonale => 'Diagonal';

  @override
  String get sfFoto => 'Photo';

  @override
  String get sfSfocatura => 'Blur';

  @override
  String get sfScurisci => 'Darken';

  @override
  String get sfSenzaFoto => 'Add photos to the library first';

  @override
  String get numAcceso => 'Page number';

  @override
  String get numFormato => 'Format';

  @override
  String get numPosizione => 'Position';

  @override
  String get numStile => 'Style';

  @override
  String get numFormatoDi => '1 of 5';

  @override
  String get numDuePagine =>
      'The number shows when the carousel has at least 2 pages';

  @override
  String get posBassoCentro => 'Bottom centre';

  @override
  String get posBassoDestra => 'Bottom right';

  @override
  String get posBassoSinistra => 'Bottom left';

  @override
  String get posAltoCentro => 'Top centre';

  @override
  String get posAltoDestra => 'Top right';

  @override
  String get posAltoSinistra => 'Top left';

  @override
  String get posCentroDestra => 'Middle right';

  @override
  String get ovScuro => 'Dark label';

  @override
  String get ovChiaro => 'Light label';

  @override
  String get ovSoloTesto => 'Text only';

  @override
  String get scorriAcceso => 'Hint';

  @override
  String get scorriTesto => 'Text';

  @override
  String get scorriTestoEtichetta => 'Hint text';

  @override
  String get strAllinea => 'Align';

  @override
  String get strDistribuisci => 'Distribute';

  @override
  String get strRaggruppa => 'Group';

  @override
  String get strSepara => 'Ungroup';

  @override
  String get strScambia => 'Swap';

  @override
  String get strBlocca => 'Lock';

  @override
  String get strSblocca => 'Unlock';

  @override
  String get strDisponi => 'Arrange';

  @override
  String get selezionaPiuAiuto => 'Tap the elements to pick';

  @override
  String get allSinistra => 'Left';

  @override
  String get allCentroOrizz => 'Centre horizontally';

  @override
  String get allDestra => 'Right';

  @override
  String get allAlto => 'Top';

  @override
  String get allCentroVert => 'Centre vertically';

  @override
  String get allBasso => 'Bottom';

  @override
  String get distOrizzontale => 'Equal gaps across';

  @override
  String get distVerticale => 'Equal gaps down';

  @override
  String get dispLivello => 'Level';

  @override
  String get dispSposta => 'Nudge';

  @override
  String get dispDavanti => 'Bring to front';

  @override
  String get dispDietro => 'Send to back';

  @override
  String passoPx(int n) {
    return '$n px';
  }

  @override
  String get frecciaSu => 'Up';

  @override
  String get frecciaGiu => 'Down';

  @override
  String get frecciaSinistra => 'Left';

  @override
  String get frecciaDestra => 'Right';

  @override
  String get menuCopia => 'Copy';

  @override
  String get menuTaglia => 'Cut';

  @override
  String get menuIncolla => 'Paste here';

  @override
  String get menuSelezionaPiu => 'Select more';

  @override
  String get menuSelezionaTutto => 'Select all';

  @override
  String get menuSpostaInPagina => 'Move to page…';

  @override
  String get menuAggiungiTesto => 'Add text here';

  @override
  String get menuAggiungiForma => 'Add shape here';

  @override
  String get menuAzioniPagina => 'Page actions';

  @override
  String get menuScegliPagina => 'Move to page';

  @override
  String menuPaginaNumero(int n) {
    return 'Page $n';
  }

  @override
  String get panoramicaAiuto =>
      'Tap to open a page · drag to reorder · hold for actions';

  @override
  String panoramicaPagina(int n) {
    return 'Page $n, drag to move it';
  }

  @override
  String get anteprimaChiudi => 'Close the preview';

  @override
  String anteprimaPagina(int n, int tot) {
    return 'Page $n of $tot';
  }

  @override
  String get strumentoCronologia => 'History';

  @override
  String cronEtichetta(int n, String nome) {
    return 'Step $n: $nome';
  }

  @override
  String get cronAttuale => 'Current';

  @override
  String get cambAperto => 'Project opened';

  @override
  String get cambPaginaDuplicata => 'Page duplicated';

  @override
  String get cambPaginaAggiunta => 'Page added';

  @override
  String get cambPaginaEliminata => 'Page deleted';

  @override
  String get cambFotoSostituite => 'Photos replaced';

  @override
  String get cambElementiCambiati => 'Elements changed';

  @override
  String cambFotoAggiunte(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n photos added',
      one: 'Photo added',
    );
    return '$_temp0';
  }

  @override
  String cambTestiAggiunti(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n texts added',
      one: 'Text added',
    );
    return '$_temp0';
  }

  @override
  String cambFormeAggiunte(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n shapes added',
      one: 'Shape added',
    );
    return '$_temp0';
  }

  @override
  String cambElementiAggiunti(int n) {
    return '$n elements added';
  }

  @override
  String cambFotoEliminate(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n photos deleted',
      one: 'Photo deleted',
    );
    return '$_temp0';
  }

  @override
  String cambTestiEliminati(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n texts deleted',
      one: 'Text deleted',
    );
    return '$_temp0';
  }

  @override
  String cambFormeEliminate(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n shapes deleted',
      one: 'Shape deleted',
    );
    return '$_temp0';
  }

  @override
  String cambElementiEliminati(int n) {
    return '$n elements deleted';
  }

  @override
  String cambPagine(int da, int a) {
    return 'Pages: $da → $a';
  }

  @override
  String get cambFormatoPagina => 'Page format';

  @override
  String cambDisposizione(String nome) {
    return 'Layout: $nome';
  }

  @override
  String get cambStileMosaico => 'Mosaic style';

  @override
  String get cambFotoRimescolate => 'Photos shuffled';

  @override
  String get cambLucchettoPagine => 'Page locks';

  @override
  String get cambPagineACavallo => 'Pages across';

  @override
  String get cambDisposizionePagina => 'Page layout';

  @override
  String get cambFotoPerPagina => 'Photos per page';

  @override
  String get cambSpaziatura => 'Spacing';

  @override
  String get cambMargine => 'Margin';

  @override
  String get cambSfondo => 'Background';

  @override
  String get cambNumeriPagina => 'Page numbers';

  @override
  String get cambScorri => '“Swipe” hint';

  @override
  String get cambNomeFile => 'File names';

  @override
  String get cambModifica => 'Change';

  @override
  String get cambRaggruppati => 'Elements grouped';

  @override
  String get cambSeparati => 'Group split';

  @override
  String get cambOrdineFoto => 'Photo order';

  @override
  String get cambLivello => 'Level changed';

  @override
  String get cambBloccoPosizione => 'Position lock';

  @override
  String cambNSpostati(int n) {
    return '$n elements moved';
  }

  @override
  String get cambDispAggiornata => 'Layout updated';

  @override
  String cambNModificati(int n) {
    return '$n elements changed';
  }

  @override
  String cambSpostato(String tipo) {
    String _temp0 = intl.Intl.selectLogic(tipo, {
      'photo': 'Photo moved',
      'text': 'Text moved',
      'shape': 'Shape moved',
      'other': 'Element moved',
    });
    return '$_temp0';
  }

  @override
  String cambRidimensionato(String tipo) {
    String _temp0 = intl.Intl.selectLogic(tipo, {
      'photo': 'Photo resized',
      'text': 'Text resized',
      'shape': 'Shape resized',
      'other': 'Element resized',
    });
    return '$_temp0';
  }

  @override
  String cambRuotato(String tipo) {
    String _temp0 = intl.Intl.selectLogic(tipo, {
      'photo': 'Photo rotated',
      'text': 'Text rotated',
      'shape': 'Shape rotated',
      'other': 'Element rotated',
    });
    return '$_temp0';
  }

  @override
  String cambStile(String tipo) {
    String _temp0 = intl.Intl.selectLogic(tipo, {
      'photo': 'Photo style',
      'text': 'Text style',
      'shape': 'Shape style',
      'other': 'Style',
    });
    return '$_temp0';
  }

  @override
  String get cambTestoModificato => 'Text edited';

  @override
  String get cambColoriFoto => 'Photo colours';

  @override
  String get cambTaglioVideo => 'Video trim';

  @override
  String get cambCopertinaVideo => 'Video cover';

  @override
  String get cambAudioVideo => 'Video audio';

  @override
  String get cambInquadratura => 'Photo framing';

  @override
  String get cambFotoLibera => 'Free photo';

  @override
  String get cambFotoInDisposizione => 'Photo in layout';

  @override
  String avvisoPaginaDuplicata(int n) {
    return 'Page duplicated: the copy is page $n';
  }

  @override
  String avvisoPaginaEliminata(int n) {
    return 'Page $n deleted';
  }

  @override
  String avvisoPaginaSpostata(int n) {
    return 'Page moved to position $n';
  }

  @override
  String avvisoPaginaBloccata(int n) {
    return 'Page $n locked';
  }

  @override
  String avvisoPaginaSbloccata(int n) {
    return 'Page $n unlocked';
  }

  @override
  String avvisoPaginaUnita(int n) {
    return 'Page $n joined to the next one';
  }

  @override
  String avvisoPaginaSeparata(int n) {
    return 'Page $n split from the next one';
  }

  @override
  String get avvisoPagineRiordinate => 'Pages reordered';

  @override
  String avvisoRaggruppati(int n) {
    return '$n elements grouped: they move together';
  }

  @override
  String get avvisoSeparati => 'Group split: the elements now move one by one';

  @override
  String get avvisoServeDue => 'Select at least 2 elements to group';

  @override
  String get avvisoServeTre => 'Select at least 3 elements to distribute';

  @override
  String get avvisoNessunGruppo => 'No group selected';

  @override
  String get avvisoPosizioneBloccata => 'Position locked';

  @override
  String get avvisoPosizioneSbloccata => 'Position unlocked';

  @override
  String get avvisoPortatoDavanti => 'Brought to front';

  @override
  String get avvisoMandatoDietro => 'Sent to back';

  @override
  String avvisoCopiati(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n elements copied',
      one: '1 element copied',
    );
    return '$_temp0';
  }

  @override
  String avvisoTagliati(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n elements cut',
      one: '1 element cut',
    );
    return '$_temp0';
  }

  @override
  String avvisoIncollati(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n elements pasted',
      one: '1 element pasted',
    );
    return '$_temp0';
  }

  @override
  String get avvisoNienteDaIncollare =>
      'Nothing to paste: copy photos, texts or shapes first';

  @override
  String avvisoFotoSpostate(int n) {
    return 'Photos moved to page $n';
  }

  @override
  String get espPagineSeparate => 'Separate pages';

  @override
  String get espQuestaPagina => 'This page';

  @override
  String get espCollage => 'Whole collage';

  @override
  String get espTutte => 'All';

  @override
  String get espNessuna => 'None';

  @override
  String get espFormato => 'Format';

  @override
  String get espFormatoPng => 'PNG · best quality';

  @override
  String get espFormatoJpg => 'JPG · small files';

  @override
  String get espQualita => 'JPG quality';

  @override
  String get espScala => 'Scale';

  @override
  String get espScala1 => '1× standard';

  @override
  String get espScala2 => '2× high definition';

  @override
  String get espNomeFile => 'File name';

  @override
  String get espNomeSuggerimento => 'frame';

  @override
  String espEsempioNome(String nome) {
    return 'Example: $nome';
  }

  @override
  String espMisure(int w, int h) {
    return 'Each image: $w×$h px';
  }

  @override
  String espMisureCollage(int w, int h) {
    return 'Image: $w×$h px';
  }

  @override
  String get espNessunaPagina => 'Choose at least one page';

  @override
  String get espDestinazione => 'Save to';

  @override
  String get espGalleria => 'Gallery';

  @override
  String get espCondividi => 'Share';

  @override
  String get espSalvaInFile => 'Save to Files';

  @override
  String get espMancantiTitolo => 'Missing photos';

  @override
  String espMancanti(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n photos on the canvas were not found and will stay empty',
      one: '1 photo on the canvas was not found and will stay empty',
    );
    return '$_temp0 in the exported image. Export anyway?';
  }

  @override
  String get espTelaVuotaTitolo => 'Empty canvas';

  @override
  String get espTelaVuota =>
      'There are no photos on the canvas. Export anyway?';

  @override
  String get espEsportaComunque => 'Export anyway';

  @override
  String get espCollageGrandeTitolo => 'Collage too large';

  @override
  String espCollageGrande(int w, int h) {
    return 'At 2× the collage would be $w×$h px: too much for the phone\'s memory. You can use 1× or export the separate pages.';
  }

  @override
  String espCollageGrande1x(int w, int h) {
    return 'Even at 1× the collage would be $w×$h px: too much for the phone\'s memory. Export the separate pages.';
  }

  @override
  String get espUsa1x => 'Use 1×';

  @override
  String get espUsaPagine => 'Separate pages';

  @override
  String get espTitoloAvanzamento => 'Exporting';

  @override
  String espFaseFoto(int pagina, int indice, int totale) {
    return 'Preparing photos, page $pagina ($indice of $totale)…';
  }

  @override
  String espFasePagina(int pagina, int indice, int totale) {
    return 'Page $pagina ($indice of $totale)…';
  }

  @override
  String get espFaseComposizione => 'Composing the collage…';

  @override
  String espFaseGalleria(int indice, int totale) {
    return 'Saving to Gallery ($indice of $totale)…';
  }

  @override
  String get espFaseCondividi => 'Opening Share…';

  @override
  String espFaseFile(int indice, int totale) {
    return 'Saving to Files ($indice of $totale)…';
  }

  @override
  String get espAnnullando => 'Cancelling…';

  @override
  String get espFatto => 'Export complete';

  @override
  String espSalvatoGalleria(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n images saved',
      one: '1 image saved',
    );
    return '$_temp0 to the “ScrolleR Studio” album in the Gallery, in page order';
  }

  @override
  String espSalvatoCondiviso(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n images',
      one: '1 image',
    );
    return '$_temp0 ready to share';
  }

  @override
  String espSalvatoFile(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n images saved',
      one: '1 image saved',
    );
    return '$_temp0 to Files';
  }

  @override
  String get espIncompleta => 'Export incomplete';

  @override
  String espNonSalvate(String nomi) {
    return 'Not saved: $nomi';
  }

  @override
  String get espInterrotta =>
      'Export stopped: the following pages were not saved.';

  @override
  String get espAnnullata => 'Export cancelled';

  @override
  String espErrore(String errore) {
    return 'Export failed: $errore';
  }

  @override
  String get espGalleriaNegata =>
      'Without permission for the Gallery I can\'t save there. You can use Share or Save to Files.';

  @override
  String get espFine => 'Done';

  @override
  String get videoMuto => 'muted';

  @override
  String get videoRiproduci => 'Play';

  @override
  String get videoPausa => 'Pause';

  @override
  String get strTaglia => 'Trim';

  @override
  String get strCopertina => 'Cover';

  @override
  String get strAudio => 'Audio';

  @override
  String get parInizio => 'Start';

  @override
  String get parFine => 'End';

  @override
  String videoInfoDurata(String durata, String usati) {
    return 'Length $durata  ·  used $usati';
  }

  @override
  String get videoSenzaAudio => 'no audio';

  @override
  String get videoSenzaAudioAvviso => 'This video has no audio';

  @override
  String videoLimiteInstagram(int secondi) {
    return 'Instagram accepts slides up to $secondi s: the exported page stops there.';
  }

  @override
  String espFaseVideo(
    int pagina,
    int indice,
    int totale,
    int fotogramma,
    int fotogrammi,
  ) {
    return 'Page $pagina ($indice of $totale) · MP4 video, frame $fotogramma of $fotogrammi…';
  }

  @override
  String espVideoMp4(int larghezza, int altezza, int fps) {
    return 'Pages with a video are exported as MP4 ($larghezza×$altezza px, $fps fps), with the audio of the videos that have it on.';
  }

  @override
  String get espVideoCollage =>
      'In the whole collage, videos appear with their cover.';

  @override
  String get espVideoNonDisponibile =>
      'This phone can\'t export MP4 videos yet: pages with a video are exported as an image, with the cover.';

  @override
  String espVideoSalvati(int n, int larghezza, int altezza) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'The $n pages with a video are MP4s',
      one: 'The page with a video is an MP4',
    );
    return '$_temp0 ($larghezza×$altezza px, 30 fps)';
  }

  @override
  String get condividiProgetto => 'Share project';

  @override
  String get importaProgetto => 'Import project';

  @override
  String get scambioPreparo => 'Preparing the project…';

  @override
  String get zipAvvisoTitolo => 'Photos without original';

  @override
  String zipSoloAnteprima(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other:
          '$n photos no longer have their originals: the zip will contain their reduced previews (long side 1600 px).',
      one: '1 photo no longer has its original: the zip will contain its reduced preview (long side 1600 px).',
    );
    return '$_temp0';
  }

  @override
  String zipMancanti(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other:
          '$n files are gone, even as previews: they won\'t be in the zip and will show as “Missing photo” on the PC.',
      one: '1 file is gone, even as a preview: it won\'t be in the zip and will show as “Missing photo” on the PC.',
    );
    return '$_temp0';
  }

  @override
  String get zipContinua => 'Create anyway';

  @override
  String zipFile(String nome) {
    return 'Copying $nome';
  }

  @override
  String get zipPronto => 'Project ready';

  @override
  String zipPronto2(int n, String dimensione) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n files copied',
      one: '1 file copied',
    );
    return '$_temp0 · $dimensione';
  }

  @override
  String get zipSpazio =>
      'Not enough space on the phone. Free some storage and try again.';

  @override
  String zipErrore(String errore) {
    return 'The zip could not be created: $errore';
  }

  @override
  String get lavoroAnnullato => 'Cancelled';

  @override
  String get impScegli => 'Choose a project (.zip or .scrlproj)';

  @override
  String impFile(String nome) {
    return 'Importing $nome';
  }

  @override
  String impFatto(String nome) {
    return '“$nome” was imported';
  }

  @override
  String impEstratti(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n photos and videos imported.',
      one: '1 photo or video imported.',
      zero: 'No photos came with the project: if any are missing, relink them from the editor.',
    );
    return '$_temp0';
  }

  @override
  String impAltriProgetti(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'The zip held $n other projects: they were not imported.',
      one: 'The zip held another project: it was not imported.',
    );
    return '$_temp0';
  }

  @override
  String get impApri => 'Open project';

  @override
  String get impNonRiconosciuto =>
      'This file is not a ScrolleR Studio project (.scrlproj or .zip).';

  @override
  String get impNessunProgetto => 'The zip contains no project (.scrlproj).';

  @override
  String get impNonValido =>
      'The project is damaged or isn\'t from ScrolleR Studio.';

  @override
  String impZipNonSupportato(String motivo) {
    return 'This zip can\'t be opened here: $motivo.';
  }

  @override
  String impErrore(String errore) {
    return 'Import failed: $errore';
  }

  @override
  String impDaFoto(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Project created with $n photos',
      one: 'Project created with 1 photo',
    );
    return '$_temp0';
  }

  @override
  String impScartati(String nomi) {
    return 'Unreadable, skipped: $nomi';
  }

  @override
  String manBadge(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n missing photos',
      one: '1 missing photo',
    );
    return '$_temp0';
  }

  @override
  String get manTitolo => 'Missing photos';

  @override
  String get manIntro =>
      'These photos are no longer in the gallery or can\'t be found. They stay on the canvas with their preview and settings: relink them to get the originals back.';

  @override
  String get manCerca => 'Search the gallery by name';

  @override
  String get manRicollega => 'Relink';

  @override
  String manUsi(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Used $n times',
      one: 'Used once',
      zero: 'Library only',
    );
    return '$_temp0';
  }

  @override
  String manRicerca(int n) {
    return 'Searching the gallery… ($n checked)';
  }

  @override
  String manRitrovate(int n, int tot) {
    return 'Found $n of $tot';
  }

  @override
  String get manNessunaTrovata =>
      'None found by name in the gallery. You can pick them by hand with “Relink”.';

  @override
  String get manTutte => 'All photos are in place.';

  @override
  String get manSenzaAccesso =>
      'Searching the gallery needs access to your photos. You can grant it in the phone settings, or relink the photos one by one.';

  @override
  String get manAperturaTitolo => 'Photos not found';

  @override
  String manApertura(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n photos of the project can no longer be found',
      one: '1 photo of the project can no longer be found',
    );
    return '$_temp0. They stay on the canvas with their preview: you can search the gallery or relink them one by one.';
  }

  @override
  String get manPiuTardi => 'Later';

  @override
  String get manVediElenco => 'Show list';

  @override
  String manScegli(String nome) {
    return 'Where is “$nome” now?';
  }

  @override
  String get manAnteprima => 'Showing the saved preview';

  @override
  String avvisoFotoRicollegate(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n photos relinked',
      one: '1 photo relinked',
    );
    return '$_temp0';
  }

  @override
  String espOriginaliMancanti(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n photos have their originals missing',
      one: '1 photo has its original missing',
    );
    return '$_temp0: in the exported image it will come out at preview quality (long side 1600 px). Export anyway?';
  }

  @override
  String get espRicollega => 'Relink';

  @override
  String get strRicollega => 'Relink';

  @override
  String get suggerimentoTocca => 'Tap a photo to select it';

  @override
  String get suggerimentoPremuto =>
      'Press and hold an item to copy, lock or delete it';

  @override
  String get suggerimentoScorri => 'Swipe sideways to change page';

  @override
  String get suggerimentoChiudi => 'Tap to dismiss';

  @override
  String get impostazioni => 'Settings';

  @override
  String get impAiuto => 'Help';

  @override
  String get impAggiornamenti => 'Updates';

  @override
  String get impRegistro => 'Error log';

  @override
  String get impInfo => 'About';

  @override
  String get impGesti => 'Gestures';

  @override
  String get impGestiAiuto => 'How to use the canvas and the panels';

  @override
  String get impSuggerimenti => 'Show the tips again';

  @override
  String get impSuggerimentiAiuto =>
      'The three first-run tips will show again in the editor';

  @override
  String get impSuggerimentiRimessi => 'The tips will show again in the editor';

  @override
  String impVersione(String versione) {
    return 'Version $versione';
  }

  @override
  String get impLicenze => 'Licenses';

  @override
  String get impLicenzeAiuto => 'Included components and fonts';

  @override
  String get impPrivacy =>
      'No ads, no tracking, no accounts. The network is only used to look for updates.';

  @override
  String get gestiTitolo => 'Gestures';

  @override
  String get gestiSulla => 'On the canvas';

  @override
  String get gestiNeiPannelli => 'In panels and bars';

  @override
  String get gestiNellePagine => 'Pages and Overview';

  @override
  String get gestoTocca => 'Tap';

  @override
  String get gestoToccaDesc =>
      'Selects a photo, a text or a shape. Tap the empty area to deselect.';

  @override
  String get gestoDoppio => 'Double tap on a text';

  @override
  String get gestoDoppioDesc => 'Opens the keyboard to type.';

  @override
  String get gestoPremuto => 'Press and hold an item';

  @override
  String get gestoPremutoDesc =>
      'Copy, cut, duplicate, lock, bring forward or send back, move to another page, delete.';

  @override
  String get gestoPremutoVuoto => 'Press and hold the empty area';

  @override
  String get gestoPremutoVuotoDesc =>
      'Paste here, add a text or a shape, select all and the page actions.';

  @override
  String get gestoTrascina => 'Drag an item';

  @override
  String get gestoTrascinaDesc =>
      'Moves it and snaps to the lines of the others. Near the screen edge it goes to the next page.';

  @override
  String get gestoManiglie => 'Drag a handle';

  @override
  String get gestoManiglieDesc => 'Resizes the selected photo or shape.';

  @override
  String get gestoPizzica => 'Pinch with two fingers';

  @override
  String get gestoPizzicaDesc =>
      'Scales the item; twisting your fingers rotates it, with small detents at the common angles.';

  @override
  String get gestoScorri => 'Swipe sideways';

  @override
  String get gestoScorriDesc => 'Changes page, one at a time.';

  @override
  String get gestoCursore => 'Double tap a slider';

  @override
  String get gestoCursoreDesc => 'Resets the value to its default.';

  @override
  String get gestoPannello => 'Drag the panel down';

  @override
  String get gestoPannelloDesc => 'Closes the tool without applying, like ✕.';

  @override
  String get gestoConfronto => 'Press and hold ◐';

  @override
  String get gestoConfrontoDesc =>
      'Shows the photo as it was before; release to see your edits again.';

  @override
  String get gestoIndietro => 'The phone\'s back gesture';

  @override
  String get gestoIndietroDesc =>
      'Goes back one level in a menu or a tool, then closes the tool, then deselects, then leaves the project.';

  @override
  String get gestoAnnullaLungo => 'Press and hold Undo';

  @override
  String get gestoAnnullaLungoDesc => 'Opens the History.';

  @override
  String get gestoPanoramica => 'Overview: tap, drag, press and hold';

  @override
  String get gestoPanoramicaDesc =>
      'Tap to go to the page, drag to reorder, press and hold for the actions.';

  @override
  String get gestoPuntini => 'Page dots';

  @override
  String get gestoPuntiniDesc => 'Tap one to jump to that page.';

  @override
  String get aggControlla => 'Look for new versions';

  @override
  String get aggControllaAiuto =>
      'Once a day, when the app opens. It is the only use of the network and sends no personal data.';

  @override
  String get aggControllaOra => 'Check now';

  @override
  String get aggInCorso => 'Checking…';

  @override
  String get aggAggiornato => 'The app is up to date';

  @override
  String aggDisponibile(String versione) {
    return 'Version $versione is available';
  }

  @override
  String get aggErrore => 'Could not check: an Internet connection is needed';

  @override
  String get aggScarica => 'Download';

  @override
  String get aggNonApribile => 'Could not open the browser';

  @override
  String get aggChiudi => 'Hide the notice';

  @override
  String get regAiuto =>
      'Unexpected errors are only noted on this phone. The file is never sent by itself: share it if you want to report a problem. Folder and photo paths are already removed.';

  @override
  String get regCondividi => 'Share the log';

  @override
  String get regVuoto => 'No errors recorded';

  @override
  String get regPieno => 'Errors have been recorded';

  @override
  String get regCancella => 'Clear the log';

  @override
  String get regCancellaChiede => 'Clear the error log?';

  @override
  String get regCancellato => 'Log cleared';

  @override
  String get regNonCondiviso => 'Could not share the log';

  @override
  String telaPagina(int pagina, int totale) {
    return 'Page $pagina of $totale';
  }

  @override
  String telaFoto(int n) {
    return 'Photo $n';
  }

  @override
  String telaVideo(int n) {
    return 'Video $n';
  }

  @override
  String telaTesto(String testo) {
    return 'Text: $testo';
  }

  @override
  String telaForma(int n) {
    return 'Shape $n';
  }

  @override
  String telaBloccato(String nome) {
    return '$nome, locked';
  }

  @override
  String get telaApriMenu => 'Actions';

  @override
  String espPagineScelte(int n, int tot) {
    return '$n of $tot pages';
  }

  @override
  String get tutteLeOpzioni => 'All options';

  @override
  String get sfDirezione => 'Direction';

  @override
  String get catAspetto => 'Look';

  @override
  String get catAltro => 'More';

  @override
  String get catGruppo => 'Group';

  @override
  String get catVideo => 'Video';

  @override
  String get formatiPiuUsati => 'Most used';

  @override
  String get formatiPiuUsatiDesc =>
      'Instagram formats for posts, stories and reels';

  @override
  String get formatiAltri => 'Other formats';

  @override
  String get usoFormato45 => 'Feed post';

  @override
  String get usoFormato916 => 'Stories and Reels';

  @override
  String get usoFormato34 => 'Profile grid';

  @override
  String get vistaCentra => 'Center the page';

  @override
  String pesoProgetto(String peso) {
    return 'Uses $peso on this phone';
  }

  @override
  String get pesoCalcolo => 'Working out the size…';

  @override
  String get pesoNota =>
      'Gallery photos are not counted: they stay in the gallery, the project links to them.';
}
