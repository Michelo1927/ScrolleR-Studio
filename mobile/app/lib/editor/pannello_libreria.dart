/// Pannello «Foto» (piano §4.3): la libreria del progetto come una fila di miniature (con il segno su quelle già
/// sulla tela), selezione multipla, aggiunta dal telefono e le azioni «Aggiungi alla tela», «Come foto libera»,
/// «Solo queste», «Rimuovi dalla libreria», «Metti tutte», «Svuota tela». Il riordino si fa con la pressione lunga
/// e il trascinamento. Ogni azione agisce subito e vale un passo di cronologia.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import '../home/scelta_foto.dart';
import '../l10n/app_localizations.dart';
import '../media/cache_media.dart';
import '../project/crea_progetto.dart';
import '../theme/tokens.dart';
import 'sessione.dart';
import 'stato.dart';
import 'testi_avvisi.dart';
import 'widget_comuni.dart';

class PannelloLibreria extends ConsumerStatefulWidget {
  const PannelloLibreria({super.key});

  @override
  ConsumerState<PannelloLibreria> createState() => _PannelloLibreriaState();
}

class _PannelloLibreriaState extends ConsumerState<PannelloLibreria> {
  /// Chiavi delle voci scelte.
  final Set<String> _scelte = {};

  SessioneEditor get _s => ref.read(sessioneProvider);
  ControlloEditor get _ctrl => ref.read(editorProvider.notifier);

  List<LibraryEntry> _vociScelte(List<LibraryEntry> l) => [
    for (final e in l)
      if (_scelte.contains(_s.chiaveVoce(e))) e,
  ];

  Future<void> _aggiungiDalTelefono() async {
    final scelte = await Navigator.of(context).push<List<FotoScelta>>(
      MaterialPageRoute(
        builder: (_) =>
            SceltaFotoPage(cartellaPerCopie: () async => _s.cartella),
      ),
    );
    if (scelte == null || scelte.isEmpty) return;
    for (final f in scelte) {
      _s.ricordaMisura(f.chiave, f.w, f.h);
    }
    _ctrl.aggiungiAllaLibreria([for (final f in scelte) f.voce]);
    // Le foto appena aggiunte restano scelte: «Aggiungi alla tela» è a un tocco
    setState(() => _scelte.addAll([for (final f in scelte) f.chiave]));
  }

  void _dopo(VoidCallback azione) {
    azione();
    setState(_scelte.clear);
  }

  static bool _eVideo(LibraryEntry v) => Scene.isVideoPath(v.path);

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final stato = ref.watch(editorProvider);
    final libreria = stato.libreria;
    final sulla = {for (final p in stato.snapshot.items) chiaveMedia(p)};
    final scelte = _vociScelte(libreria);
    final haScelte = scelte.isNotEmpty;
    final video = libreria.where(_eVideo).length;
    final videoScelti = scelte.where(_eVideo).length;
    return PannelloBasso(
      onScarta: _ctrl.chiudiStrumento,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: MisureScrl.tocco,
            child: Row(
              children: [
                const SizedBox(width: MisureScrl.spazio),
                Expanded(
                  child: Text(
                    haScelte
                        ? testoScelte(
                            t,
                            scelte.length - videoScelti,
                            videoScelti,
                          )
                        : t.libreriaTitolo(
                            conteggioMedia(t, libreria.length - video, video),
                          ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                PulsanteIcona(
                  icona: Icons.keyboard_arrow_down_rounded,
                  etichetta: t.chiudi,
                  onTap: _ctrl.chiudiStrumento,
                ),
              ],
            ),
          ),
          SizedBox(
            height: 88,
            child: libreria.isEmpty
                ? Center(
                    child: Text(
                      t.libreriaVuota,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                : ReorderableListView.builder(
                    scrollDirection: Axis.horizontal,
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: MisureScrl.spazio,
                    ),
                    itemCount: libreria.length,
                    onReorderItem: _ctrl.riordinaLibreria,
                    itemBuilder: (context, i) {
                      final v = libreria[i];
                      final k = _s.chiaveVoce(v);
                      return ReorderableDelayedDragStartListener(
                        key: ValueKey(k),
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _Miniatura(
                            sessione: _s,
                            voce: v,
                            scelta: _scelte.contains(k),
                            sullaTela: sulla.contains(k),
                            etichetta: _eVideo(v)
                                ? t.videoNumero(i + 1)
                                : t.fotoNumero(i + 1),
                            onTap: () => setState(() {
                              if (!_scelte.remove(k)) _scelte.add(k);
                            }),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: MisureScrl.spazio,
                vertical: 8,
              ),
              children: [
                _azione(t.aggiungiDalTelefono, _aggiungiDalTelefono, true),
                if (haScelte) ...[
                  _azione(
                    t.aggiungiAllaTela,
                    () => _dopo(() => _ctrl.aggiungiATela(scelte)),
                  ),
                  _azione(
                    t.comeFotoLibera,
                    () =>
                        _dopo(() => _ctrl.aggiungiATela(scelte, libere: true)),
                  ),
                  _azione(
                    t.soloQueste,
                    () => _dopo(() => _ctrl.mettiSullaTela(scelte)),
                  ),
                  _azione(
                    t.rimuoviDallaLibreria,
                    () => _dopo(() => _ctrl.rimuoviDallaLibreria(scelte)),
                  ),
                ] else if (libreria.isNotEmpty) ...[
                  _azione(t.mettiTutte, () => _ctrl.mettiSullaTela(libreria)),
                  _azione(t.svuotaTela, _ctrl.svuotaLaTela),
                ],
              ],
            ),
          ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }

  Widget _azione(String testo, VoidCallback onTap, [bool evidente = false]) =>
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChipParametro(etichetta: testo, attivo: evidente, onTap: onTap),
      );
}

/// Miniatura di una voce: segno di scelta (spunta) e punto sulle foto già sulla tela.
class _Miniatura extends StatelessWidget {
  const _Miniatura({
    required this.sessione,
    required this.voce,
    required this.scelta,
    required this.sullaTela,
    required this.etichetta,
    required this.onTap,
  });

  final SessioneEditor sessione;
  final LibraryEntry voce;
  final bool scelta;
  final bool sullaTela;
  final String etichetta;
  final VoidCallback onTap;

  static const double _lato = 80;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: scelta,
      label: etichetta,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: _lato,
          height: _lato,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ImmagineVoce(sessione: sessione, voce: voce),
                if (scelta)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: ColoriScrl.accento.withValues(alpha: 0.3),
                      border: Border.all(color: ColoriScrl.accento, width: 3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                if (scelta)
                  const Positioned(
                    top: 4,
                    right: 4,
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: ColoriScrl.suAccento,
                    ),
                  ),
                if (sullaTela)
                  Positioned(
                    left: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: ColoriScrl.accento,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.photo_rounded,
                        size: 12,
                        color: ColoriScrl.suAccento,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Miniatura di una voce della libreria (carica la sua miniatura dalla cache).
class ImmagineVoce extends StatefulWidget {
  const ImmagineVoce({super.key, required this.sessione, required this.voce});

  final SessioneEditor sessione;
  final LibraryEntry voce;

  @override
  State<ImmagineVoce> createState() => _ImmagineVoceState();
}

class _ImmagineVoceState extends State<ImmagineVoce> {
  late final Future<ImmagineMedia?> _immagine = widget.sessione.cache.carica(
    widget.sessione.sorgenteVoce(widget.voce),
    Dettaglio.miniatura,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ImmagineMedia?>(
      future: _immagine,
      builder: (context, s) {
        final img = s.data?.immagine;
        if (img == null) {
          return const ColoredBox(
            color: ColoriScrl.rilievo,
            child: Icon(
              Icons.image_not_supported_outlined,
              color: ColoriScrl.testoSpento,
            ),
          );
        }
        return RawImage(image: img, fit: BoxFit.cover);
      },
    );
  }
}
