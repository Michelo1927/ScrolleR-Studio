/// Formato e numero di pagine della tela, portati da `scrollr/window/main_window.py`
/// (`_on_aspect_ratio_changed`, `_apply_custom_ratio`, `_set_frame_size`, `_on_frames_changed`).
library;

import '../layout/layout.dart';
import '../model/canvas_state.dart';
import '../model/context.dart';
import '../model/result.dart';
import '../model/scene.dart';
import '../model/snapshot.dart';
import '../project/formato.dart';

/// `_on_frames_changed`: numero di pagine scelto a mano (1–30).
EngineResult setNumFrames(Snapshot s, int value, EngineContext ctx) {
  final sc = Scene(s, ctx);
  value = value.clamp(1, pagineMassime);
  if (value == sc.numFrames) return EngineResult.refused(s, sc);
  final locked = [
    for (var k = value; k < sc.numFrames; k++)
      if (sc.pageLocked(k)) k,
  ];
  if (locked.isNotEmpty) {
    // Togliere pagine dalla fine eliminerebbe una pagina bloccata
    sc.notice(NoticeKind.pageLocked, [locked.first + 1]);
    return EngineResult.refused(s, sc);
  }
  ctx.seamAddedFrames = null; // Scelta manuale dell'utente: da ora vale la sua
  if (sc.perPage > 0) {
    // Con un numero fisso di foto per pagina le pagine si calcolano da sole: torna su Auto
    sc.perPage = 0;
    sc.notice(NoticeKind.perPageBackToAuto);
  }
  sc.numFrames = value;
  relayoutKeep(sc);
  return EngineResult.done(sc);
}

/// `_set_frame_size`: misure della pagina; con pagine bloccate non si cambiano.
EngineResult setFrameSize(Snapshot s, int w, int h, EngineContext ctx) =>
    _setFrameSize(s, w, h, ctx);

EngineResult _setFrameSize(
  Snapshot s,
  int w,
  int h,
  EngineContext ctx, {
  int? ratioIndex,
  int? customW,
  int? customH,
}) {
  final sc = Scene(s, ctx);
  CanvasState edit(CanvasState c) =>
      c.copyWith(ratioIndex: ratioIndex, customW: customW, customH: customH);
  if (w == sc.frameW && h == sc.frameH) {
    // Stesse misure: cambia solo la scelta nel pannello
    final t = sc.toSnapshot(canvas: edit);
    return EngineResult(t, applied: t != s);
  }
  if (sc.anyPageLocked()) {
    // `_show_current_frame_size`: il pannello torna al formato e alle misure della tela
    sc.notice(NoticeKind.lockedPagesNoResize);
    final size = (sc.frameW, sc.frameH);
    final i = aspectRatios.indexOf(size);
    final t = s.copyWith(
      canvas: s.canvas.copyWith(
        ratioIndex: i >= 0 ? i : ratioPersonalizzato,
        customW: size.$1.clamp(200, 6000),
        customH: size.$2.clamp(200, 6000),
      ),
    );
    return EngineResult(t, notices: sc.notices, applied: false);
  }
  sc.frameW = w;
  sc.frameH = h;
  relayoutKeep(sc);
  return EngineResult(sc.toSnapshot(canvas: edit), notices: sc.notices);
}

/// `_on_aspect_ratio_changed`: formato scelto dall'elenco ([index] in [aspectRatios]; 8 = Personalizzato,
/// che usa le misure personalizzate).
EngineResult setAspectRatio(Snapshot s, int index, EngineContext ctx) {
  index = index.clamp(0, aspectRatios.length - 1);
  final dims = aspectRatios[index] ?? (s.canvas.customW, s.canvas.customH);
  return _setFrameSize(s, dims.$1, dims.$2, ctx, ratioIndex: index);
}

/// Misure personalizzate (200–6000 px): valgono per la pagina solo con «Personalizzato».
EngineResult setCustomSize(Snapshot s, int w, int h, EngineContext ctx) {
  w = w.clamp(200, 6000);
  h = h.clamp(200, 6000);
  if (aspectRatios[s.canvas.ratioIndex] != null) {
    return EngineResult(
      s.copyWith(
        canvas: s.canvas.copyWith(customW: w, customH: h),
      ),
    );
  }
  return _setFrameSize(s, w, h, ctx, customW: w, customH: h);
}
