/// Pannelli del blocco di sottotitoli selezionato (`_caption_inspector_box` del desktop): Larghezza delle righe,
/// colore e dimensione della traduzione. Come gli strumenti del testo, ogni cambio è una bozza: ✓ la mette in
/// cronologia, ✕ la scarta. Mostra la traduzione e Corsivo sono comandi singoli della barra.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import '../l10n/app_localizations.dart';
import 'intelaiatura.dart';
import 'selettore_colore.dart';
import 'stato.dart';

/// Il blocco principale tra quelli selezionati (i cursori ne mostrano i valori; i cambi valgono per tutti).
final _sottotitoliPrincipali = Provider.autoDispose<CaptionItem?>((ref) {
  final sel = ref.watch(editorProvider.select((s) => s.elementiSelezionati));
  for (final e in sel) {
    if (e is CaptionItem) return e;
  }
  return null;
}, dependencies: [editorProvider]);

/// Larghezza: quanto possono essere lunghe le righe, in % della pagina (le frasi lunghe vanno su due righe).
class PannelloLarghezzaSottotitoli extends ConsumerWidget {
  const PannelloLarghezzaSottotitoli({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final c = ref.watch(_sottotitoliPrincipali);
    final frameW = ref.watch(
      editorProvider.select((s) => s.snapshot.canvas.frameW),
    );
    final ctrl = ref.read(editorProvider.notifier);
    return PannelloCursori(
      nome: t.strLarghezza,
      parametri: [
        ParametroCursore(
          nome: t.strLarghezza,
          minimo: LimitiSottotitoli.larghezzaMin,
          massimo: LimitiSottotitoli.larghezzaMax,
          iniziale: 80,
          valore: c == null ? null : larghezzaSottotitoliPercento(c, frameW),
          onCambia: (v) => ctrl.modificaSottotitoliSelezionati(
            (x, ctx) => conLarghezzaSottotitoli(x, v, frameW, ctx),
          ),
          unita: '%',
        ),
      ],
    );
  }
}

/// Colore della traduzione.
class PannelloColoreTraduzione extends ConsumerWidget {
  const PannelloColoreTraduzione({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final c = ref.watch(_sottotitoliPrincipali);
    final ctrl = ref.read(editorProvider.notifier);
    return PannelloColore(
      nome: t.sotColoreTraduzione,
      colore: c?.trColor ?? 0xFFFFD43B,
      onColore: (v) => ctrl.modificaSottotitoliSelezionati(
        (x, _) => conColoreTraduzione(x, v),
      ),
    );
  }
}

/// Dimensione della traduzione rispetto alla frase (40–100%).
class PannelloDimensioneTraduzione extends ConsumerWidget {
  const PannelloDimensioneTraduzione({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final c = ref.watch(_sottotitoliPrincipali);
    final ctrl = ref.read(editorProvider.notifier);
    return PannelloCursori(
      nome: t.sotDimensioneTraduzione,
      parametri: [
        ParametroCursore(
          nome: t.strDimensione,
          minimo: LimitiSottotitoli.traduzioneMin,
          massimo: LimitiSottotitoli.traduzioneMax,
          iniziale: 70,
          valore: c?.trSize,
          onCambia: (v) => ctrl.modificaSottotitoliSelezionati(
            (x, ctx) => conDimensioneTraduzione(x, v, ctx),
          ),
          unita: '%',
        ),
      ],
    );
  }
}
