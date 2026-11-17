/// Testi dei messaggi brevi dell'editor: avvisi del motore (`Notice`) e messaggi dell'app, dai file `.arb`.
library;

import 'package:scrl_engine/scrl_engine.dart' show Notice, NoticeKind;

import '../l10n/app_localizations.dart';
import 'stato.dart';

/// Testo di un avviso da mostrare in basso sopra la barra.
String testoAvviso(Testi t, Avviso a) {
  final n = a.notice;
  if (n != null) return _notice(t, n);
  return switch (a.messaggio) {
    MessaggioEditor.fotoAggiunte => t.avvisoFotoAggiunte(a.n),
    MessaggioEditor.elementoEliminato => t.avvisoEliminato,
    MessaggioEditor.elementiEliminati => t.avvisoEliminati(a.n),
    MessaggioEditor.elementoDuplicato => t.avvisoDuplicato,
    MessaggioEditor.telaSvuotata => t.avvisoTelaSvuotata,
    MessaggioEditor.fotoLibere => t.avvisoFotoLibera,
    MessaggioEditor.fotoInDisposizione => t.avvisoFotoInDisposizione,
    MessaggioEditor.paginaAggiunta => t.avvisoPaginaAggiunta,
    MessaggioEditor.salvataggioNonRiuscito => t.avvisoSalvataggioNonRiuscito,
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
