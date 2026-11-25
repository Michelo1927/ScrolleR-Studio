/// Informazioni che il motore non può calcolare da solo e che l'app fornisce: misura delle immagini
/// (per le proporzioni usate dalle disposizioni) e misura dei testi (dipende dai caratteri installati).
/// Tiene anche i contatori degli `uid`, che come nel desktop non tornano mai indietro.
library;

import 'dart:math' as math;

import '../util/py.dart';
import 'elements.dart';

/// Misura in pixel dell'immagine di una foto; null = foto mancante.
typedef ImageSizeOf = ({int w, int h})? Function(PhotoItem photo);

/// Larghezza e altezza del riquadro di un testo (`TextItem.text_rect`).
typedef TextSizeOf = ({double w, double h}) Function(TextItem text);

/// Larghezza e altezza del riquadro di un blocco di sottotitoli (`CaptionItem._content_size` più i margini).
typedef CaptionSizeOf = ({double w, double h}) Function(CaptionItem caption);

/// Avvisi per l'utente prodotti dal motore (i testi stanno nei file `.arb` dell'app).
enum NoticeKind {
  /// «A cavallo» ha aggiunto pagine (args: pagine).
  seamAddedPages,

  /// Lasciando «A cavallo» è tornato il numero di pagine di prima (args: pagine).
  seamRestoredPages,

  /// Pagine bloccate o piene: aggiunta una pagina per le foto.
  addedPageForPhotos,

  /// La pagina è bloccata (args: pagina, da 1).
  pageLocked,

  /// Le pagine «a cavallo» intorno alla posizione sono bloccate (args: posizione, da 1).
  seamPagesLocked,

  /// Pagina «a cavallo» e bloccata (args: pagina, da 1).
  seamPageLocked,

  /// Due pagine «a cavallo» e bloccate devono restare vicine (args: pagina, pagina successiva, da 1).
  lockedSeamMustStayTogether,

  /// Massimo di pagine raggiunto (args: pagine).
  maxPages,

  /// Un reel ha una sola pagina: niente pagine in più.
  reelSinglePage,

  /// Un reel ha una sola pagina: la conversione da carosello chiede di togliere le altre.
  reelNeedsOnePage,

  /// Conversione in carosello: i video oltre 60 s usano il primo minuto.
  videosTrimmedToCarousel,

  /// Una sola pagina: non si elimina.
  singlePage,

  /// Una sola pagina: niente da riordinare.
  nothingToReorder,

  /// La pagina è già al bordo.
  pageAtEdge,

  /// È l'ultima pagina: niente da unire.
  lastPage,

  /// Ci sono pagine bloccate: niente cambio di formato.
  lockedPagesNoResize,

  /// Pagine scelte a mano: «Foto per pagina» torna su Auto.
  perPageBackToAuto,

  /// Con «A cavallo» le scelte per singola pagina non valgono.
  seamIgnoresPageSettings,

  /// I video non possono stare a cavallo tra due pagine.
  videoKeptInPage,

  /// Selezione non valida per lo scambio (servono esattamente 2 foto).
  swapNeedsTwo,
}

class Notice {
  final NoticeKind kind;
  final List<int> args;
  const Notice(this.kind, [this.args = const []]);

  @override
  bool operator ==(Object other) =>
      other is Notice &&
      other.kind == kind &&
      other.args.length == args.length &&
      _same(other.args, args);

  static bool _same(List<int> a, List<int> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(kind, Object.hashAll(args));

  @override
  String toString() => 'Notice($kind, $args)';
}

class EngineContext {
  final ImageSizeOf imageSize;
  final TextSizeOf textSize;
  final CaptionSizeOf captionSize;

  /// Pagine aggiunte in automatico da «A cavallo»: (pagine di prima, pagine impostate dalla disposizione).
  /// Stato dell'editor, fuori dallo snapshot come `_seam_added_frames` del desktop.
  (int, int)? seamAddedFrames;

  /// Da chiamare quando si torna a uno stato salvato (Annulla/Ripeti, apertura): come `_restore_snapshot`.
  void resetSession() => seamAddedFrames = null;

  int _nextPhotoUid = 1;
  int _nextTextUid = 1;
  int _nextShapeUid = 1;

  EngineContext({
    ImageSizeOf? imageSize,
    TextSizeOf? textSize,
    CaptionSizeOf? captionSize,
  }) : imageSize = imageSize ?? _noImage,
       textSize = textSize ?? estimateTextSize,
       captionSize = captionSize ?? estimateCaptionSize;

  static ({int w, int h})? _noImage(PhotoItem _) => null;

  /// Stima della misura di un testo quando l'app non fornisce le metriche vere del carattere.
  static ({double w, double h}) estimateTextSize(TextItem t) {
    final righe = t.text.isEmpty ? const [' '] : t.text.split('\n');
    final lunga = righe.map((r) => r.length).fold<int>(0, math.max);
    final interlinea = t.size * 1.33;
    final w = lunga * t.size * (0.55 + t.letterSpacing / 100.0);
    final h =
        interlinea + interlinea * t.lineHeight / 100.0 * (righe.length - 1);
    return (w: w + 2 * t.pad, h: h + 2 * t.pad);
  }

  /// Stima della misura di un blocco di sottotitoli: la larghezza scelta e lo spazio per due righe di frase
  /// (più due di traduzione, se c'è), con l'interlinea stimata come in [estimateTextSize].
  static ({double w, double h}) estimateCaptionSize(CaptionItem c) {
    final t = c.stile;
    final interlinea = t.size * 1.33;
    var h = interlinea + interlinea * t.lineHeight / 100.0;
    if (c.mostraTraduzione) {
      final px = pyRound(t.size * c.trSize / 100.0);
      h += t.size * 0.12 + (px > 4 ? px : 4) * 1.33 * 2;
    }
    return (w: c.wrapW + 2 * c.pad, h: h + 2 * c.pad);
  }

  // ---------- Contatori degli uid (separati per foto, testi e forme) ----------
  /// Fa sapere al contesto gli uid già usati (progetto aperto, Annulla): i nuovi saranno più grandi.
  void observe(Iterable<CanvasElement> elementi) {
    for (final e in elementi) {
      switch (e) {
        case PhotoItem():
          _nextPhotoUid = math.max(_nextPhotoUid, e.uid + 1);
        case TextItem():
          _nextTextUid = math.max(_nextTextUid, e.uid + 1);
        case CaptionItem(): // Stesso contatore dei testi, come sul desktop
          _nextTextUid = math.max(_nextTextUid, e.uid + 1);
        case ShapeItem():
          _nextShapeUid = math.max(_nextShapeUid, e.uid + 1);
      }
    }
  }

  int newPhotoUid() => _nextPhotoUid++;
  int newTextUid() => _nextTextUid++;
  int newShapeUid() => _nextShapeUid++;
}
