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
  String get azDeforma => 'Stretch';

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
}
