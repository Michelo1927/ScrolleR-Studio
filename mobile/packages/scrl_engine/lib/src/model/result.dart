/// Risultato di un'operazione del motore: il nuovo stato e gli avvisi per l'utente.
library;

import 'context.dart';
import 'scene.dart';
import 'snapshot.dart';

class EngineResult {
  final Snapshot snapshot;
  final List<Notice> notices;

  /// Falso quando l'operazione non è stata fatta (pagina bloccata, limite raggiunto…): lo stato è quello di prima.
  final bool applied;

  EngineResult(
    this.snapshot, {
    List<Notice> notices = const [],
    this.applied = true,
  }) : notices = List.unmodifiable(notices);

  /// Operazione rifiutata: stato invariato, con il motivo negli avvisi.
  factory EngineResult.refused(Snapshot s, Scene sc) =>
      EngineResult(s, notices: sc.notices, applied: false);

  factory EngineResult.done(Scene sc) =>
      EngineResult(sc.toSnapshot(), notices: sc.notices);
}
