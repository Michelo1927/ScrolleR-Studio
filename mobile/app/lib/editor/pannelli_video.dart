/// Pannelli degli strumenti Video (piano §6 «Video», Fase 8): **Taglia** (Inizio e Fine) e **Copertina**, con la
/// stessa anatomia degli strumenti Foto: schede, un solo cursore, `✕` scarta, `✓` conferma (un passo di cronologia).
/// Portati dalla sezione «Video» dell'inspector del desktop (`scrollr/window/video.py`). Le regole del taglio
/// stanno in `scrl_engine` (`edit/video.dart`); la durata del video la legge l'app dal file.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'intelaiatura.dart';
import 'sessione.dart';
import 'stato.dart';
import 'widget_comuni.dart';

/// Il video principale tra quelli selezionati (i cursori ne mostrano i valori; i cambi valgono per tutti).
final _videoPrincipale = Provider.autoDispose<PhotoItem?>((ref) {
  final sel = ref.watch(editorProvider.select((s) => s.elementiSelezionati));
  for (final e in sel) {
    if (e is PhotoItem && e.isVideo) return e;
  }
  return null;
}, dependencies: [editorProvider]);

/// Decimi di secondo come tempo leggibile («0:04,5»).
String _decimi(int v) => formatoTempo(v / 10.0);

/// Riga sotto il cursore (`_update_video_info`): durata, parte usata, senza audio e, per un video più lungo del
/// massimo del tipo di progetto ([tipo]), come sceglierne la parte.
String testoInfoVideo(
  Testi t,
  PhotoItem v,
  double durata,
  bool audio,
  String tipo,
) {
  final usati = clipLength(v, durata);
  final parti = [
    t.videoInfoDurata(formatoTempo(durata), formatoTempo(usati)),
    if (!audio) t.videoSenzaAudio,
  ];
  var testo = parti.join('  ·  ');
  if (durata > secondiMassimiPer(tipo) + 0.05) {
    testo += tipo == 'reel'
        ? '\n${t.videoLimiteReel(LimitiVideo.secondiMassimi ~/ 60)}'
        : '\n${t.videoLimiteCarosello(LimitiVideo.secondiSlideCarosello.toInt())}';
  }
  return testo;
}

/// Base comune: legge la durata del video all'apertura e si ridisegna quando arriva.
abstract class _PannelloVideoState<T extends ConsumerStatefulWidget>
    extends ConsumerState<T> {
  late final SessioneEditor _s;

  @override
  void initState() {
    super.initState();
    _s = ref.read(sessioneProvider);
    for (final v in ref.read(editorProvider.notifier).videoSelezionati) {
      unawaited(_s.risorse.caricaInfoVideo(v));
    }
  }

  /// Cursore in decimi di secondo da 0 alla durata del video principale.
  Widget cursore(
    PhotoItem v,
    String nome,
    double secondi,
    double iniziale,
    PhotoItem Function(PhotoItem, double secondi, double durata) scrivi,
  ) {
    final ctrl = ref.read(editorProvider.notifier);
    final t = Testi.of(context);
    return ListenableBuilder(
      listenable: _s.risorse,
      builder: (context, _) {
        final info = _s.risorse.infoVideo(v);
        final durata = info?.durata ?? 0.0;
        final massimo = math.max(1, pyRound(durata * 10));
        return Padding(
          key: ValueKey(nome),
          padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CursoreGrande(
                etichetta: nome,
                valore: (secondi * 10).clamp(0, massimo).toDouble(),
                minimo: 0,
                massimo: massimo.toDouble(),
                iniziale: iniziale * 10,
                formato: _decimi,
                onCambia: (d) => ctrl.modificaVideoSelezionati(
                  (p, dur) => scrivi(p, d / 10.0, dur),
                ),
                onFine: () {},
              ),
              Text(
                testoInfoVideo(
                  t,
                  v,
                  durata,
                  info?.audio ?? false,
                  ref.read(editorProvider).snapshot.canvas.projectType,
                ),
                key: const ValueKey('video-info'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Riproduci / Pausa dentro i pannelli: si guarda il taglio mentre lo si cambia.
AzioneStrumento _azioneRiproduci(Testi t, WidgetRef ref) {
  final ctrl = ref.read(editorProvider.notifier);
  final v = ref.watch(_videoPrincipale);
  final gira = ref.watch(
    editorProvider.select(
      (s) => v != null && s.videoInRiproduzione.contains(v.uid),
    ),
  );
  return AzioneStrumento(
    chiave: const ValueKey('video-riproduci'),
    icona: gira ? Icons.pause_rounded : Icons.play_arrow_rounded,
    etichetta: gira ? t.videoPausa : t.videoRiproduci,
    attiva: gira,
    onTap: ctrl.alternaRiproduzione,
  );
}

// ---------------------------------------------------------------- Taglia

/// Taglia: da che punto parte il video nella pagina esportata (Inizio) e dove finisce (Fine); poi ricomincia da
/// capo se un altro video della stessa pagina dura di più.
class PannelloTaglioVideo extends ConsumerStatefulWidget {
  const PannelloTaglioVideo({super.key});

  @override
  ConsumerState<PannelloTaglioVideo> createState() =>
      _PannelloTaglioVideoState();
}

class _PannelloTaglioVideoState
    extends _PannelloVideoState<PannelloTaglioVideo> {
  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final v = ref.watch(_videoPrincipale);
    ref.watch(editorProvider.select((s) => s.snapshot));
    final durata = v == null ? 0.0 : _s.risorse.durataVideo(v);
    // Oltre la durata massima del tipo di progetto l'altro estremo segue: si sceglie la parte da mostrare
    final massimo = secondiMassimiPer(
      ref.watch(editorProvider.select((s) => s.snapshot.canvas.projectType)),
    );
    return Intelaiatura(
      nome: t.strTaglia,
      azioni: [_azioneRiproduci(t, ref)],
      schede: [
        SchedaStrumento(
          chiave: const ValueKey('video-inizio'),
          etichetta: t.parInizio,
          valore: v == null ? null : formatoTempo(v.trimStart),
          contenuto: v == null
              ? const SizedBox.shrink()
              : cursore(
                  v,
                  t.parInizio,
                  v.trimStart,
                  0,
                  (p, s, d) => conInizio(p, s, d, massimo: massimo),
                ),
        ),
        SchedaStrumento(
          chiave: const ValueKey('video-fine'),
          etichetta: t.parFine,
          valore: v == null ? null : formatoTempo(clipEnd(v, durata)),
          contenuto: v == null
              ? const SizedBox.shrink()
              : cursore(
                  v,
                  t.parFine,
                  clipEnd(v, durata),
                  durata,
                  (p, s, d) => conFine(p, s, d, massimo: massimo),
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Copertina

/// Copertina: il fotogramma mostrato sulla tela, nelle anteprime e nell'esportazione del collage intero.
class PannelloCopertinaVideo extends ConsumerStatefulWidget {
  const PannelloCopertinaVideo({super.key});

  @override
  ConsumerState<PannelloCopertinaVideo> createState() =>
      _PannelloCopertinaVideoState();
}

class _PannelloCopertinaVideoState
    extends _PannelloVideoState<PannelloCopertinaVideo> {
  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final v = ref.watch(_videoPrincipale);
    return Intelaiatura(
      nome: t.strCopertina,
      contenuto: v == null
          ? null
          : cursore(v, t.strCopertina, v.poster, 0, conCopertina),
    );
  }
}
