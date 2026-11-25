/// Annulla/Ripeti con una pila di snapshot immutabili, portato da `HistoryMixin` (`scrollr/window/history.py`).
///
/// Un passo nasce alla ✓ di uno strumento, alla fine di un gesto, a ogni comando singolo (l'equivalente
/// di `_schedule_commit`). Prima di ogni passo i video rientrano nelle pagine (`_keep_videos_in_pages`).
library;

import '../model/context.dart';
import '../model/snapshot.dart';
import '../pages/videos.dart';
import '../project/formato.dart';
import 'describe.dart';

/// Esito di [History.commit]: la cronologia nuova, lo stato effettivo (con i video sistemati) e gli avvisi.
class HistoryCommit {
  final History history;
  final Snapshot snapshot;
  final List<Notice> notices;

  /// Falso se lo stato era uguale all'ultimo passo: nessun passo nuovo.
  final bool added;
  const HistoryCommit(this.history, this.snapshot, this.notices, this.added);
}

class History {
  final List<Snapshot> states;
  final List<ChangeLabel> labels;
  final int index;

  /// Nome del primo passaggio (`_history_start_label`).
  final ChangeLabel startLabel;

  History._(
    List<Snapshot> states,
    List<ChangeLabel> labels,
    this.index,
    this.startLabel,
  ) : states = List.unmodifiable(states),
      labels = List.unmodifiable(labels);

  /// Cronologia vuota.
  History.empty({ChangeLabel startLabel = const ChangeLabel(ChangeKind.start)})
    : this._(const [], const [], -1, startLabel);

  /// `_reset_history(label)`: cronologia nuova (progetto aperto o nuovo); il primo passaggio è [s].
  static HistoryCommit reset(
    Snapshot s,
    EngineContext ctx, {
    ChangeLabel startLabel = const ChangeLabel(ChangeKind.start),
  }) {
    ctx.resetSession();
    return History.empty(startLabel: startLabel).commit(s, ctx);
  }

  bool get isEmpty => states.isEmpty;

  /// Stato attuale.
  Snapshot get current => states[index];

  bool get canUndo => index > 0;
  bool get canRedo => index < states.length - 1;

  /// `_commit_history`: aggiunge [s] come passo nuovo (se diverso dall'attuale), togliendo i passi «avanti».
  HistoryCommit commit(Snapshot s, EngineContext ctx) {
    final sistemati = keepVideosInPages(s, ctx);
    final snap = senzaSottotitoliOrfani(sistemati.snapshot);
    if (states.isNotEmpty && states[index] == snap) {
      return HistoryCommit(this, snap, sistemati.notices, false);
    }
    final label = states.isNotEmpty
        ? describeChange(states[index], snap)
        : startLabel;
    final nuovi = [...states.sublist(0, index + 1), snap];
    final nomi = [...labels.sublist(0, index + 1), label];
    if (nuovi.length > cronologiaLimite) {
      nuovi.removeAt(0);
      nomi.removeAt(0);
    }
    return HistoryCommit(
      History._(nuovi, nomi, nuovi.length - 1, startLabel),
      snap,
      sistemati.notices,
      true,
    );
  }

  /// `_go_to_history`: torna (o va avanti) a un passaggio qualsiasi. Chi la usa ripristina [current] e
  /// chiama [EngineContext.resetSession], come `_restore_snapshot`.
  History goTo(int i) {
    if (!(0 <= i && i < states.length) || i == index) return this;
    return History._(states, labels, i, startLabel);
  }

  /// Stessa cronologia (indice e nomi dei passaggi) con ogni stato passato da [fn]: il ricollegamento di una foto
  /// mancante vale anche per i passi di Annulla/Ripeti (`_remap_paths` riscrive tutta la cronologia).
  History riscritta(Snapshot Function(Snapshot) fn) =>
      History._([for (final s in states) fn(s)], labels, index, startLabel);

  History undo() => canUndo ? goTo(index - 1) : this;
  History redo() => canRedo ? goTo(index + 1) : this;

  /// `_is_dirty`: lo stato attuale è diverso da quello salvato.
  bool isDirty(Snapshot? saved) => states.isNotEmpty && current != saved;
}
