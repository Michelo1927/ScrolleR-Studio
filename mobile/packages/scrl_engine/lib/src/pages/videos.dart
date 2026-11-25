/// Video dentro una pagina, portato da `scrollr/window/video.py` (`_keep_videos_in_pages`).
///
/// Un video non può stare «a cavallo» tra due pagine: ogni pagina diventa un MP4 a sé. Si esegue prima
/// di ogni passo di cronologia.
library;

import 'dart:math' as math;

import '../model/context.dart';
import '../model/elements.dart';
import '../model/result.dart';
import '../model/scene.dart';
import '../model/snapshot.dart';

/// Un video della disposizione si riduce alla parte nella pagina dove ne sta di più; uno libero (o ruotato)
/// rientra spostandosi. Vero se ne ha sistemato almeno uno.
bool keepVideosInPagesIn(Scene sc) {
  final fw = sc.frameW.toDouble();
  final n = sc.numFrames;
  var fixed = false;
  for (final orig in sc.canvasPhotos().where((p) => p.isVideo)) {
    var v = sc.photo(orig.uid);
    if (v.pageLocked) continue;
    var rect = v.cellRect;
    final first = math.max(
      0,
      math.min(n - 1, ((rect.left + 0.5) / fw).floor()),
    );
    final last = math.max(
      0,
      math.min(n - 1, ((rect.right - 0.5) / fw).floor()),
    );
    if (first == last) continue;
    // Pagina con la parte più grande del video (a parità, la prima)
    var best = first;
    var bestW = -1.0;
    for (var k = first; k <= last; k++) {
      final w = _overlap(rect.left, rect.right, k * fw, (k + 1) * fw);
      if (w > bestW) {
        best = k;
        bestW = w;
      }
    }
    final left = best * fw, right = (best + 1) * fw;
    final straight = v.rotation.abs() < 0.01;
    if (straight && !v.free) {
      final partLeft = math.max(rect.left, left);
      final partW = _overlap(rect.left, rect.right, left, left + fw);
      if (partW >= PhotoItem.minCell) {
        sc.put(v.copyWith(w: partW, x: partLeft));
        fixed = true;
        continue;
      }
    }
    if (rect.w > fw) {
      final k = fw / rect.w * 0.98;
      final cx = v.x + v.w / 2.0, cy = v.y + v.h / 2.0;
      v = v.copyWith(w: v.w * k, h: v.h * k);
      v = v.copyWith(x: cx - v.w / 2.0, y: cy - v.h / 2.0);
      rect = v.cellRect;
    }
    final dx = rect.left < left
        ? left - rect.left
        : (rect.right > right ? right - rect.right : 0.0);
    sc.put(v.copyWith(x: v.x + dx));
    fixed = true;
  }
  if (fixed) sc.notice(NoticeKind.videoKeptInPage);
  return fixed;
}

/// Larghezza dell'intersezione tra due intervalli (0 se non si toccano), come `QRectF.intersected`.
double _overlap(double a0, double a1, double b0, double b1) {
  final w = math.min(a1, b1) - math.max(a0, b0);
  return w > 0 ? w : 0.0;
}

/// Versione su snapshot: stato invariato (e `applied` falso) se nessun video era a cavallo.
EngineResult keepVideosInPages(Snapshot s, EngineContext ctx) {
  final sc = Scene(s, ctx);
  return keepVideosInPagesIn(sc)
      ? EngineResult.done(sc)
      : EngineResult(s, applied: false);
}

/// `_drop_orphan_captions`: i sottotitoli di un video che non è più sulla tela se ne vanno con lui.
Snapshot senzaSottotitoliOrfani(Snapshot s) {
  if (s.captions.isEmpty) return s;
  final video = {
    for (final p in s.items)
      if (p.isVideo) p.uid,
  };
  final restano = [
    for (final c in s.captions)
      if (video.contains(c.videoUid)) c,
  ];
  return restano.length == s.captions.length
      ? s
      : s.copyWith(captions: restano);
}
