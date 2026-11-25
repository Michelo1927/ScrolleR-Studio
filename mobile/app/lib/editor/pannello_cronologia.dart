/// Cronologia (piano §4.6): l'elenco dal basso con il nome di ogni passaggio (dal più recente); un tocco torna a quel
/// punto, anche in avanti. Si apre con la pressione lunga su Annulla. I nomi li dà il motore (`describeChange`, portato da
/// `_describe_change` del desktop) e i testi vengono dai file `.arb`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'pannello_disposizione.dart' show nomeDisposizione;
import 'stato.dart';
import 'testi_avvisi.dart';
import 'widget_comuni.dart';

/// Apre la Cronologia dal basso. Il foglio sta sopra la schermata dell'editor ma fuori dal suo `ProviderScope`: gli si
/// passa lo stesso contenitore.
Future<void> mostraCronologia(BuildContext context) {
  final contenitore = ProviderScope.containerOf(context);
  return showModalBottomSheet<void>(
    context: context,
    sheetAnimationStyle: MotoScrl.foglio(context),
    isScrollControlled: true,
    backgroundColor: ColoriScrl.pannello,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(MisureScrl.angoloPannello),
      ),
    ),
    builder: (_) => UncontrolledProviderScope(
      container: contenitore,
      child: const FoglioCronologia(),
    ),
  );
}

/// Icona del tipo di modifica (un solo segno per riconoscere a colpo d'occhio il passaggio).
IconData iconaCambio(ChangeKind k) => switch (k) {
  ChangeKind.start => Icons.flag_outlined,
  ChangeKind.pageDuplicated ||
  ChangeKind.pageAdded ||
  ChangeKind.pageDeleted ||
  ChangeKind.pagesCount ||
  ChangeKind.pageFormat ||
  ChangeKind.pageLayout ||
  ChangeKind.pageSeams => Icons.view_carousel_outlined,
  ChangeKind.pageLocks || ChangeKind.positionLock => Icons.lock_outline,
  ChangeKind.photosReplaced ||
  ChangeKind.photoOrder ||
  ChangeKind.photosShuffled ||
  ChangeKind.photoFree ||
  ChangeKind.photoInLayout ||
  ChangeKind.photoFraming ||
  ChangeKind.photoColors => Icons.photo_outlined,
  ChangeKind.added => Icons.add_circle_outline_rounded,
  ChangeKind.removed => Icons.remove_circle_outline_rounded,
  ChangeKind.layout ||
  ChangeKind.mosaicStyle ||
  ChangeKind.filmStyle ||
  ChangeKind.polaroidShadow ||
  ChangeKind.polaroidDepth ||
  ChangeKind.photosPerPage ||
  ChangeKind.spacing ||
  ChangeKind.margin ||
  ChangeKind.layoutUpdated => Icons.dashboard_outlined,
  ChangeKind.background => Icons.wallpaper_rounded,
  ChangeKind.pageNumbers => Icons.pin_outlined,
  ChangeKind.swipeHint => Icons.swipe_rounded,
  ChangeKind.grouped || ChangeKind.ungrouped => Icons.workspaces_outline,
  ChangeKind.levelChanged => Icons.layers_outlined,
  ChangeKind.moved || ChangeKind.movedMany => Icons.open_with_rounded,
  ChangeKind.resized => Icons.aspect_ratio_rounded,
  ChangeKind.rotated => Icons.rotate_right_rounded,
  ChangeKind.textEdited => Icons.title_rounded,
  ChangeKind.captionsEdited => Icons.subtitles_outlined,
  ChangeKind.videoTrim ||
  ChangeKind.videoPoster ||
  ChangeKind.videoAudio => Icons.videocam_outlined,
  _ => Icons.edit_outlined,
};

class FoglioCronologia extends ConsumerWidget {
  const FoglioCronologia({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final cron = ref.watch(editorProvider.select((s) => s.cronologia));
    final ctrl = ref.read(editorProvider.notifier);
    final altezza = MediaQuery.sizeOf(context).height * 0.6;
    final n = cron.states.length;
    return SizedBox(
      height: altezza,
      child: Column(
        children: [
          SizedBox(
            height: MisureScrl.tocco,
            child: Row(
              children: [
                const SizedBox(width: MisureScrl.spazio),
                Expanded(
                  child: Text(
                    t.strumentoCronologia,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                PulsanteIcona(
                  icona: Icons.keyboard_arrow_down_rounded,
                  etichetta: t.chiudi,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: n,
              itemBuilder: (context, riga) {
                // Dal più recente al più vecchio
                final i = n - 1 - riga;
                final nome = testoCambio(
                  t,
                  cron.labels[i],
                  (m) => nomeDisposizione(t, m),
                );
                final attuale = i == cron.index;
                final futuro = i > cron.index;
                final colore = attuale
                    ? ColoriScrl.accentoTesto
                    : futuro
                    ? ColoriScrl.testoSpento
                    : ColoriScrl.testo;
                return Semantics(
                  button: true,
                  selected: attuale,
                  label: t.cronEtichetta(i + 1, nome),
                  excludeSemantics: true,
                  child: InkWell(
                    key: ValueKey('passaggio-$i'),
                    onTap: () {
                      ctrl.vaiAPassaggio(i);
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      height: MisureScrl.tocco,
                      padding: const EdgeInsets.symmetric(
                        horizontal: MisureScrl.spazio,
                      ),
                      color: attuale ? ColoriScrl.premuto : null,
                      child: Row(
                        children: [
                          Icon(iconaCambio(cron.labels[i].kind), color: colore),
                          const SizedBox(width: MisureScrl.spazio),
                          Expanded(
                            child: Text(
                              nome,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: TestoScrl.normale,
                                fontWeight: attuale
                                    ? TestoScrl.marcato
                                    : TestoScrl.regolare,
                                color: colore,
                              ),
                            ),
                          ),
                          if (attuale)
                            Text(
                              t.cronAttuale,
                              style: const TextStyle(
                                fontSize: TestoScrl.piccolo,
                                color: ColoriScrl.accentoTesto,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}
