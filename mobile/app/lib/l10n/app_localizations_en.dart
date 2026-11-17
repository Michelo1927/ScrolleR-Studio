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
}
