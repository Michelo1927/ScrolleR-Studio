/// Strumenti Video (Fase 8): taglio, copertina, audio, durata leggibile e video di una pagina. Portati da
/// `scrollr/canvas/video_item.py` (`set_trim`, `format_time`) e da `scrollr/window/video.py` / `export.py`
/// (`_on_video_slider`, `_page_videos`, `_video_page_frames`).
///
/// La durata del video la conosce solo l'app (la legge dal file): qui arriva come parametro, 0 = sconosciuta.
library;

import 'dart:math' as math;

import '../model/elements.dart';
import '../model/snapshot.dart';
import '../util/py.dart';
import 'geometria_foto.dart';

/// Regole dei video del desktop (`scrollr/video.py`).
abstract final class LimitiVideo {
  static const int fps = 30;
  static const double secondiMassimi = 60.0;
}

/// `set_trim(start, end)`: inizio e fine del taglio in secondi; la fine a meno di 0,05 s dalla durata torna
/// «fino alla fine» (null). Con [durata] 0 (sconosciuta) si applica solo la parte che non ne dipende.
PhotoItem conTaglio(PhotoItem v, double inizio, double? fine, double durata) {
  final dur = durata > 0 ? durata : null;
  var start = math.max(0.0, inizio);
  if (dur != null) start = math.min(start, math.max(0.0, dur - 0.1));
  double? end = fine;
  if (end != null) {
    end = math.max(start + 0.1, end);
    if (dur != null && end >= dur - 0.05) end = null; // Fino alla fine
  }
  return v.copyWith(trimStart: start, trimEnd: () => end);
}

/// Cursore «Inizio» (`_on_video_slider("start")`): la fine resta, ma non si incrocia con l'inizio.
PhotoItem conInizio(PhotoItem v, double secondi, double durata) =>
    conTaglio(v, secondi, v.trimEnd, durata);

/// Cursore «Fine» (`_on_video_slider("end")`).
PhotoItem conFine(PhotoItem v, double secondi, double durata) =>
    conTaglio(v, v.trimStart, secondi, durata);

/// Cursore «Copertina»: il secondo mostrato sulla tela, nelle anteprime e nel collage intero.
PhotoItem conCopertina(PhotoItem v, double secondi, double durata) =>
    v.copyWith(
      poster: math.max(0.0, durata > 0 ? math.min(secondi, durata) : secondi),
    );

/// Interruttore «Audio nel video esportato» (`_set_video_audio`).
PhotoItem conAudio(PhotoItem v, bool acceso) => v.copyWith(muted: !acceso);

/// `format_time`: «0:07», «1:05», con i decimi sotto i 10 secondi («0:04,5»).
String formatoTempo(double secondi) {
  final s0 = math.max(0.0, secondi);
  final m = (s0 / 60.0).floorToDouble();
  final s = s0 - m * 60.0;
  if (m < 1 && s < 10 && (s - pyRound(s)).abs() >= 0.05) {
    // f"0:{s:04.1f}" con la virgola (decimi arrotondati come Python: 3,25 → 3,2)
    final t = pyRoundTo(s, 1).toStringAsFixed(1).padLeft(4, '0');
    return '0:${t.replaceAll('.', ',')}';
  }
  final r = pyRound(s);
  final sec = r < 60 ? r : 59;
  return '${m.toInt()}:${sec.toString().padLeft(2, '0')}';
}

/// `_page_videos(k)`: video che compaiono nella pagina [k], con un filo di tolleranza (un video appoggiato al bordo
/// non conta per la pagina accanto). Quelli mancanti li toglie l'app, che sa quali file non ci sono.
List<PhotoItem> videoDellaPagina(Snapshot s, int k) {
  final fw = s.canvas.frameW.toDouble();
  final fh = s.canvas.frameH.toDouble();
  final l = k * fw + 0.5, r = l + fw - 1.0;
  return [
    for (final v in s.items)
      if (v.isVideo &&
          v.cellRect.left < r &&
          v.cellRect.right > l &&
          v.cellRect.top < fh &&
          v.cellRect.bottom > 0)
        v,
  ];
}

/// `_video_page_frames`: fotogrammi dell'MP4 di una pagina con video lunghi [durateTaglio] secondi: dura quanto il
/// più lungo, al massimo 60 s.
int fotogrammiPaginaVideo(Iterable<double> durateTaglio) {
  final piuLungo = durateTaglio.fold(0.0, math.max);
  return math.max(
    1,
    pyRound(math.min(piuLungo, LimitiVideo.secondiMassimi) * LimitiVideo.fps),
  );
}

/// Secondo del video in riproduzione dopo [trascorsi] secondi (`current_time`): il taglio si ripete da capo.
double tempoInRiproduzione(PhotoItem v, double durata, double trascorsi) =>
    v.trimStart + trascorsi % clipLength(v, durata);
