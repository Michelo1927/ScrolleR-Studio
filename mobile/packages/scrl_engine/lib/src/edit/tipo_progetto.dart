/// Tipo di progetto, carosello o reel (`toggle_project_type` e `_keep_videos_in_limit` in
/// `scrollr/window/project.py` e `scrollr/window/video.py`).
library;

import '../model/context.dart';
import '../model/result.dart';
import '../model/scene.dart';
import '../model/snapshot.dart';
import 'video.dart';

/// Video della tela accorciati alla durata massima del tipo di progetto, tenendo l'inizio. [durate] ha la durata
/// di ogni file video (secondi; quelli sconosciuti non si toccano).
Snapshot conVideoNelLimite(Snapshot s, Map<String, double> durate) {
  final massimo = secondiMassimiPer(s.canvas.projectType);
  var cambiato = false;
  final items = [
    for (final p in s.items)
      if (p.isVideo && (durate[p.path] ?? 0) > 0)
        () {
          final q = conLimiteTaglio(p, massimo, durate[p.path]!);
          if (q != p) cambiato = true;
          return q;
        }()
      else
        p,
  ];
  return cambiato ? s.copyWith(items: items) : s;
}

/// File → Converti in reel / in carosello. In reel solo con una pagina; in carosello i video oltre 60 s usano il
/// primo minuto (dall'inizio del taglio).
EngineResult convertiTipoProgetto(
  Snapshot s,
  Map<String, double> durate,
  EngineContext ctx,
) {
  final sc = Scene(s, ctx);
  if (s.canvas.projectType == 'carousel') {
    if (s.canvas.numFrames > 1) {
      sc.notice(NoticeKind.reelNeedsOnePage);
      return EngineResult.refused(s, sc);
    }
    return EngineResult(
      s.copyWith(canvas: s.canvas.copyWith(projectType: 'reel')),
    );
  }
  final carosello = s.copyWith(
    canvas: s.canvas.copyWith(projectType: 'carousel'),
  );
  final t = conVideoNelLimite(carosello, durate);
  if (t != carosello) sc.notice(NoticeKind.videosTrimmedToCarousel);
  return EngineResult(t, notices: sc.notices);
}
