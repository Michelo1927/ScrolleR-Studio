/// Testi dei messaggi brevi dell'editor: avvisi del motore (`Notice`) e messaggi dell'app, dai file `.arb`.
library;

import 'package:scrl_engine/scrl_engine.dart'
    show ChangeKind, ChangeLabel, ElementKind, Notice, NoticeKind;

import '../l10n/app_localizations.dart';
import 'stato.dart';

/// «8 foto», «2 video», «6 foto · 2 video» (come `media_count` del desktop); vuota dà «0 foto».
String conteggioMedia(Testi t, int foto, int video) => [
  if (foto > 0 || video == 0) t.contaFoto(foto),
  if (video > 0) t.contaVideo(video),
].join(' · ');

/// Quante miniature sono scelte, accordato a foto, video o tutte e due (`selection_text` del desktop).
String testoScelte(Testi t, int foto, int video) {
  if (video == 0) return t.fotoScelte(foto);
  if (foto == 0) return t.videoScelti(video);
  return t.mediaScelti(conteggioMedia(t, foto, video));
}

/// «3 foto aggiunte», «1 video aggiunto», «2 foto · 1 video aggiunti».
String testoAggiunti(Testi t, int foto, int video) {
  if (video == 0) return t.avvisoFotoAggiunte(foto);
  if (foto == 0) return t.avvisoVideoAggiunti(video);
  return t.avvisoMediaAggiunti(conteggioMedia(t, foto, video));
}

/// Testo di un avviso da mostrare in basso sopra la barra.
String testoAvviso(Testi t, Avviso a) {
  final n = a.notice;
  if (n != null) return _notice(t, n);
  return switch (a.messaggio) {
    MessaggioEditor.fotoAggiunte => testoAggiunti(t, a.n - a.nVideo, a.nVideo),
    MessaggioEditor.fotoRicollegate => t.avvisoFotoRicollegate(a.n),
    MessaggioEditor.elementoEliminato => t.avvisoEliminato,
    MessaggioEditor.elementiEliminati => t.avvisoEliminati(a.n),
    MessaggioEditor.elementoDuplicato => t.avvisoDuplicato,
    MessaggioEditor.telaSvuotata => t.avvisoTelaSvuotata,
    MessaggioEditor.fotoLibere => t.avvisoFotoLibera,
    MessaggioEditor.fotoInDisposizione => t.avvisoFotoInDisposizione,
    MessaggioEditor.paginaAggiunta => t.avvisoPaginaAggiunta,
    MessaggioEditor.convertitoReel => t.avvisoConvertitoReel,
    MessaggioEditor.convertitoCarosello => t.avvisoConvertitoCarosello,
    MessaggioEditor.salvataggioNonRiuscito => t.avvisoSalvataggioNonRiuscito,
    MessaggioEditor.stileCopiato => t.avvisoStileCopiato,
    MessaggioEditor.stileIncollato => t.avvisoStileIncollato,
    MessaggioEditor.ritaglioApplicato => t.avvisoRitaglioApplicato,
    MessaggioEditor.ritaglioTolto => t.avvisoRitaglioTolto,
    MessaggioEditor.sagomaApplicata => t.avvisoSagomaApplicata,
    MessaggioEditor.sagomaTolta => t.avvisoSagomaTolta,
    MessaggioEditor.sagomaSalvata => t.avvisoSagomaSalvata,
    MessaggioEditor.sagomaNonSalvata => t.avvisoSagomaNonSalvata,
    MessaggioEditor.modificaScartata => t.avvisoModificaScartata,
    MessaggioEditor.formaAggiunta => t.avvisoFormaAggiunta,
    MessaggioEditor.paginaDuplicata => t.avvisoPaginaDuplicata(a.n),
    MessaggioEditor.paginaEliminata => t.avvisoPaginaEliminata(a.n),
    MessaggioEditor.paginaSpostata => t.avvisoPaginaSpostata(a.n),
    MessaggioEditor.paginaBloccata => t.avvisoPaginaBloccata(a.n),
    MessaggioEditor.paginaSbloccata => t.avvisoPaginaSbloccata(a.n),
    MessaggioEditor.paginaUnita => t.avvisoPaginaUnita(a.n),
    MessaggioEditor.paginaSeparata => t.avvisoPaginaSeparata(a.n),
    MessaggioEditor.paginaRiordinata => t.avvisoPagineRiordinate,
    MessaggioEditor.raggruppati => t.avvisoRaggruppati(a.n),
    MessaggioEditor.separati => t.avvisoSeparati,
    MessaggioEditor.serveDueElementi => t.avvisoServeDue,
    MessaggioEditor.serveTreElementi => t.avvisoServeTre,
    MessaggioEditor.nessunGruppo => t.avvisoNessunGruppo,
    MessaggioEditor.posizioneBloccata => t.avvisoPosizioneBloccata,
    MessaggioEditor.posizioneSbloccata => t.avvisoPosizioneSbloccata,
    MessaggioEditor.portatoDavanti => t.avvisoPortatoDavanti,
    MessaggioEditor.mandatoDietro => t.avvisoMandatoDietro,
    MessaggioEditor.copiati => t.avvisoCopiati(a.n),
    MessaggioEditor.tagliati => t.avvisoTagliati(a.n),
    MessaggioEditor.incollati => t.avvisoIncollati(a.n),
    MessaggioEditor.nienteDaIncollare => t.avvisoNienteDaIncollare,
    MessaggioEditor.fotoSpostate => t.avvisoFotoSpostate(a.n),
    MessaggioEditor.selezionaPiu => t.selezionaPiuAiuto,
    MessaggioEditor.sfondoSenzaFoto => t.sfSenzaFoto,
    MessaggioEditor.inArrivo => t.inArrivo,
    MessaggioEditor.videoSenzaAudio => t.videoSenzaAudioAvviso,
    null => '',
  };
}

String _notice(Testi t, Notice n) {
  int arg(int i) => i < n.args.length ? n.args[i] : 0;
  return switch (n.kind) {
    NoticeKind.seamAddedPages => t.noticeSeamAddedPages(arg(0)),
    NoticeKind.seamRestoredPages => t.noticeSeamRestoredPages(arg(0)),
    NoticeKind.addedPageForPhotos => t.noticeAddedPageForPhotos,
    NoticeKind.pageLocked => t.noticePageLocked(arg(0)),
    NoticeKind.seamPagesLocked => t.noticeSeamPagesLocked(arg(0)),
    NoticeKind.seamPageLocked => t.noticeSeamPageLocked(arg(0)),
    NoticeKind.lockedSeamMustStayTogether => t.noticeLockedSeamMustStayTogether(
      arg(0),
      arg(1),
    ),
    NoticeKind.maxPages => t.noticeMaxPages(arg(0)),
    NoticeKind.reelSinglePage => t.noticeReelUnaPagina,
    NoticeKind.reelNeedsOnePage => t.noticeReelTogliPagine,
    NoticeKind.videosTrimmedToCarousel => t.noticeVideoPrimoMinuto,
    NoticeKind.singlePage => t.noticeSinglePage,
    NoticeKind.nothingToReorder => t.noticeNothingToReorder,
    NoticeKind.pageAtEdge => t.noticePageAtEdge,
    NoticeKind.lastPage => t.noticeLastPage,
    NoticeKind.lockedPagesNoResize => t.noticeLockedPagesNoResize,
    NoticeKind.perPageBackToAuto => t.noticePerPageBackToAuto,
    NoticeKind.seamIgnoresPageSettings => t.noticeSeamIgnoresPageSettings,
    NoticeKind.videoKeptInPage => t.noticeVideoKeptInPage,
    NoticeKind.swapNeedsTwo => t.noticeSwapNeedsTwo,
  };
}

/// Nome di un passaggio della cronologia, composto dai file `.arb` (il motore dà un nome strutturato, come
/// `_describe_change` del desktop). [nomeDisposizione] traduce il modo di disposizione.
String testoCambio(
  Testi t,
  ChangeLabel c,
  String Function(String modo) nomeDisposizione,
) {
  String tipo(ElementKind? k) => switch (k) {
    ElementKind.photo => 'photo',
    ElementKind.text => 'text',
    ElementKind.caption => 'caption',
    ElementKind.shape => 'shape',
    null => 'other',
  };
  String aggiunti() => switch (c.element) {
    ElementKind.photo => t.cambFotoAggiunte(c.count),
    ElementKind.text => t.cambTestiAggiunti(c.count),
    ElementKind.caption => t.cambSottotitoliAggiunti(c.count),
    ElementKind.shape => t.cambFormeAggiunte(c.count),
    null => t.cambElementiAggiunti(c.count),
  };
  String eliminati() => switch (c.element) {
    ElementKind.photo => t.cambFotoEliminate(c.count),
    ElementKind.text => t.cambTestiEliminati(c.count),
    ElementKind.caption => t.cambSottotitoliEliminati(c.count),
    ElementKind.shape => t.cambFormeEliminate(c.count),
    null => t.cambElementiEliminati(c.count),
  };
  return switch (c.kind) {
    ChangeKind.start => c.text ?? t.cambAperto,
    ChangeKind.pageDuplicated => t.cambPaginaDuplicata,
    ChangeKind.pageAdded => t.cambPaginaAggiunta,
    ChangeKind.pageDeleted => t.cambPaginaEliminata,
    ChangeKind.photosReplaced => t.cambFotoSostituite,
    ChangeKind.elementsChanged => t.cambElementiCambiati,
    ChangeKind.added => aggiunti(),
    ChangeKind.removed => eliminati(),
    ChangeKind.pagesCount => t.cambPagine(c.from, c.to),
    ChangeKind.pageFormat => t.cambFormatoPagina,
    ChangeKind.layout => t.cambDisposizione(
      nomeDisposizione(c.layoutMode ?? ''),
    ),
    ChangeKind.mosaicStyle => t.cambStileMosaico,
    ChangeKind.filmStyle => t.cambVersoPellicola,
    ChangeKind.polaroidShadow => t.cambOmbraPolaroid,
    ChangeKind.polaroidDepth => t.cambRilievoPolaroid,
    ChangeKind.photosShuffled => t.cambFotoRimescolate,
    ChangeKind.pageLocks => t.cambLucchettoPagine,
    ChangeKind.pageSeams => t.cambPagineACavallo,
    ChangeKind.pageLayout => t.cambDisposizionePagina,
    ChangeKind.photosPerPage => t.cambFotoPerPagina,
    ChangeKind.spacing => t.cambSpaziatura,
    ChangeKind.margin => t.cambMargine,
    ChangeKind.background => t.cambSfondo,
    ChangeKind.pageNumbers => t.cambNumeriPagina,
    ChangeKind.swipeHint => t.cambScorri,
    ChangeKind.exportName => t.cambNomeFile,
    ChangeKind.convertedToReel => t.cambConvertitoReel,
    ChangeKind.convertedToCarousel => t.cambConvertitoCarosello,
    ChangeKind.modified => t.cambModifica,
    ChangeKind.grouped => t.cambRaggruppati,
    ChangeKind.ungrouped => t.cambSeparati,
    ChangeKind.photoOrder => t.cambOrdineFoto,
    ChangeKind.levelChanged => t.cambLivello,
    ChangeKind.positionLock => t.cambBloccoPosizione,
    ChangeKind.movedMany => t.cambNSpostati(c.count),
    ChangeKind.layoutUpdated => t.cambDispAggiornata,
    ChangeKind.modifiedMany => t.cambNModificati(c.count),
    ChangeKind.moved => t.cambSpostato(tipo(c.element)),
    ChangeKind.resized => t.cambRidimensionato(tipo(c.element)),
    ChangeKind.rotated => t.cambRuotato(tipo(c.element)),
    ChangeKind.textEdited => t.cambTestoModificato,
    ChangeKind.captionsEdited => t.cambSottotitoliModificati,
    ChangeKind.photoColors => t.cambColoriFoto,
    ChangeKind.videoTrim => t.cambTaglioVideo,
    ChangeKind.videoPoster => t.cambCopertinaVideo,
    ChangeKind.videoAudio => t.cambAudioVideo,
    ChangeKind.photoFraming => t.cambInquadratura,
    ChangeKind.photoFree => t.cambFotoLibera,
    ChangeKind.photoInLayout => t.cambFotoInDisposizione,
    ChangeKind.style => t.cambStile(tipo(c.element)),
  };
}
