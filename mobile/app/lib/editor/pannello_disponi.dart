/// Comandi sulla selezione (piano §4.3 e §6 «Comuni a tutti gli elementi»): **Disponi** (porta davanti, manda dietro,
/// blocca posizione e le quattro frecce per lo spostamento fine di 1 o 10 px), **Allinea** (6) e **Distribuisci** (2).
/// Sono comandi singoli: ogni tocco agisce subito e vale un passo di cronologia; il pannello resta aperto per ripetere.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'intelaiatura.dart';
import 'stato.dart';
import 'widget_comuni.dart';

/// Tessera di un comando che agisce subito, nelle righe che stanno tutte nello schermo.
Widget _voce(
  String chiave,
  IconData icona,
  String etichetta,
  VoidCallback onTap, {
  bool attiva = false,
}) => TesseraVoce(
  key: ValueKey(chiave),
  icona: icona,
  etichetta: etichetta,
  attiva: attiva,
  larghezza: null,
  margine: false,
  onTap: onTap,
);

/// Disponi: Livello (davanti, dietro, blocca) e Sposta (frecce di 1 px, o di 10 px con «×10»).
class PannelloDisponi extends ConsumerStatefulWidget {
  const PannelloDisponi({super.key});

  @override
  ConsumerState<PannelloDisponi> createState() => _PannelloDisponiState();
}

class _PannelloDisponiState extends ConsumerState<PannelloDisponi> {
  int _passo = 1;

  ControlloEditor get _ctrl => ref.read(editorProvider.notifier);

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final sel = ref.watch(editorProvider.select((s) => s.elementiSelezionati));
    final bloccati = sel.isNotEmpty && sel.every((e) => e.locked);
    final p = _passo.toDouble();
    return Intelaiatura(
      nome: t.strDisponi,
      schede: [
        SchedaStrumento(
          etichetta: t.dispLivello,
          chiave: const ValueKey('disponi-scheda-livello'),
          contenuto: RigaTessere(
            children: [
              _voce(
                'disponi-davanti',
                Icons.flip_to_front_rounded,
                t.dispDavanti,
                _ctrl.davantiSelezione,
              ),
              _voce(
                'disponi-dietro',
                Icons.flip_to_back_rounded,
                t.dispDietro,
                _ctrl.dietroSelezione,
              ),
              _voce(
                'disponi-blocca',
                bloccati ? Icons.lock_open_rounded : Icons.lock_outline,
                bloccati ? t.strSblocca : t.strBlocca,
                _ctrl.bloccaSelezione,
                attiva: bloccati,
              ),
            ],
          ),
        ),
        SchedaStrumento(
          etichetta: t.dispSposta,
          chiave: const ValueKey('disponi-scheda-sposta'),
          contenuto: RigaTessere(
            children: [
              _voce(
                'disponi-sinistra',
                Icons.arrow_back_rounded,
                t.frecciaSinistra,
                () => _ctrl.spostaSelezione(-p, 0),
              ),
              _voce(
                'disponi-su',
                Icons.arrow_upward_rounded,
                t.frecciaSu,
                () => _ctrl.spostaSelezione(0, -p),
              ),
              _voce(
                'disponi-giu',
                Icons.arrow_downward_rounded,
                t.frecciaGiu,
                () => _ctrl.spostaSelezione(0, p),
              ),
              _voce(
                'disponi-destra',
                Icons.arrow_forward_rounded,
                t.frecciaDestra,
                () => _ctrl.spostaSelezione(p, 0),
              ),
              _voce(
                'disponi-passo-10',
                Icons.speed_rounded,
                t.passoPx(10),
                () => setState(() => _passo = _passo == 10 ? 1 : 10),
                attiva: _passo == 10,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Allinea: a sinistra, al centro, a destra, in alto, al centro (verticale), in basso. Con un solo elemento si allinea
/// alla sua pagina, con più elementi al loro ingombro comune; gli elementi con «Blocca posizione» restano dove sono.
/// Sei comandi in due righe da tre, tutti nello schermo.
class PannelloAllinea extends ConsumerWidget {
  const PannelloAllinea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final ctrl = ref.read(editorProvider.notifier);
    Widget voce(Allineamento a, IconData icona, String nome) => _VoceInRiga(
      chiave: ValueKey('allinea-${a.name}'),
      icona: icona,
      etichetta: nome,
      onTap: () => ctrl.allineaSelezione(a),
    );
    return Intelaiatura(
      nome: t.strAllinea,
      contenuto: Padding(
        padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  voce(
                    Allineamento.sinistra,
                    Icons.align_horizontal_left_rounded,
                    t.allSinistra,
                  ),
                  voce(
                    Allineamento.centroOrizzontale,
                    Icons.align_horizontal_center_rounded,
                    t.allCentroOrizz,
                  ),
                  voce(
                    Allineamento.destra,
                    Icons.align_horizontal_right_rounded,
                    t.allDestra,
                  ),
                ],
              ),
            ),
            const SizedBox(height: MisureScrl.spazioPiccolo),
            Expanded(
              child: Row(
                children: [
                  voce(
                    Allineamento.alto,
                    Icons.align_vertical_top_rounded,
                    t.allAlto,
                  ),
                  voce(
                    Allineamento.centroVerticale,
                    Icons.align_vertical_center_rounded,
                    t.allCentroVert,
                  ),
                  voce(
                    Allineamento.basso,
                    Icons.align_vertical_bottom_rounded,
                    t.allBasso,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Comando a pillola con icona e nome affiancati (le righe di Allinea).
class _VoceInRiga extends StatelessWidget {
  const _VoceInRiga({
    required this.chiave,
    required this.icona,
    required this.etichetta,
    required this.onTap,
  });

  final Key chiave;
  final IconData icona;
  final String etichetta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Semantics(
        button: true,
        label: etichetta,
        excludeSemantics: true,
        child: Material(
          color: ColoriScrl.rilievo,
          borderRadius: BorderRadius.circular(MisureScrl.angoloTessera),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: chiave,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Icon(icona, size: 20, color: ColoriScrl.testo),
                  const SizedBox(width: 6),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        etichetta,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: TestoScrl.piccolo,
                          color: ColoriScrl.testo,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Distribuisci: spazi uguali tra gli elementi (da 3 elementi), in orizzontale o in verticale.
class PannelloDistribuisci extends ConsumerWidget {
  const PannelloDistribuisci({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final ctrl = ref.read(editorProvider.notifier);
    return Intelaiatura(
      nome: t.strDistribuisci,
      contenuto: RigaTessere(
        children: [
          _voce(
            'distribuisci-orizzontale',
            Icons.horizontal_distribute_rounded,
            t.distOrizzontale,
            () => ctrl.distribuisciSelezione(orizzontale: true),
          ),
          _voce(
            'distribuisci-verticale',
            Icons.vertical_distribute_rounded,
            t.distVerticale,
            () => ctrl.distribuisciSelezione(orizzontale: false),
          ),
        ],
      ),
    );
  }
}
