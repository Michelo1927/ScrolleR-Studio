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

Widget _riga(List<Widget> tessere) => ListView(
  scrollDirection: Axis.horizontal,
  padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
  children: tessere,
);

enum _SchedaDisponi { livello, sposta }

/// Disponi: Livello (davanti, dietro, blocca) e Sposta (frecce di 1 o 10 px).
class PannelloDisponi extends ConsumerStatefulWidget {
  const PannelloDisponi({super.key});

  @override
  ConsumerState<PannelloDisponi> createState() => _PannelloDisponiState();
}

class _PannelloDisponiState extends ConsumerState<PannelloDisponi> {
  _SchedaDisponi _scheda = _SchedaDisponi.livello;
  int _passo = 1;

  ControlloEditor get _ctrl => ref.read(editorProvider.notifier);

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final sel = ref.watch(editorProvider.select((s) => s.elementiSelezionati));
    final bloccati = sel.isNotEmpty && sel.every((e) => e.locked);
    final p = _passo.toDouble();
    final Widget contenuto = switch (_scheda) {
      _SchedaDisponi.livello => _riga([
        TesseraVoce(
          key: const ValueKey('disponi-davanti'),
          icona: Icons.flip_to_front_rounded,
          etichetta: t.dispDavanti,
          onTap: _ctrl.davantiSelezione,
        ),
        TesseraVoce(
          key: const ValueKey('disponi-dietro'),
          icona: Icons.flip_to_back_rounded,
          etichetta: t.dispDietro,
          onTap: _ctrl.dietroSelezione,
        ),
        TesseraVoce(
          key: const ValueKey('disponi-blocca'),
          icona: bloccati ? Icons.lock_open_rounded : Icons.lock_outline,
          etichetta: bloccati ? t.strSblocca : t.strBlocca,
          attiva: bloccati,
          onTap: _ctrl.bloccaSelezione,
        ),
      ]),
      _SchedaDisponi.sposta => _riga([
        TesseraVoce(
          key: const ValueKey('disponi-sinistra'),
          icona: Icons.arrow_back_rounded,
          etichetta: t.frecciaSinistra,
          onTap: () => _ctrl.spostaSelezione(-p, 0),
        ),
        TesseraVoce(
          key: const ValueKey('disponi-su'),
          icona: Icons.arrow_upward_rounded,
          etichetta: t.frecciaSu,
          onTap: () => _ctrl.spostaSelezione(0, -p),
        ),
        TesseraVoce(
          key: const ValueKey('disponi-giu'),
          icona: Icons.arrow_downward_rounded,
          etichetta: t.frecciaGiu,
          onTap: () => _ctrl.spostaSelezione(0, p),
        ),
        TesseraVoce(
          key: const ValueKey('disponi-destra'),
          icona: Icons.arrow_forward_rounded,
          etichetta: t.frecciaDestra,
          onTap: () => _ctrl.spostaSelezione(p, 0),
        ),
      ]),
    };
    return Intelaiatura(
      nome: t.strDisponi,
      chips: [
        ChipParametro(
          etichetta: t.dispLivello,
          attivo: _scheda == _SchedaDisponi.livello,
          onTap: () => setState(() => _scheda = _SchedaDisponi.livello),
        ),
        ChipParametro(
          etichetta: t.dispSposta,
          attivo: _scheda == _SchedaDisponi.sposta,
          onTap: () => setState(() => _scheda = _SchedaDisponi.sposta),
        ),
        if (_scheda == _SchedaDisponi.sposta)
          for (final n in const [1, 10])
            ChipParametro(
              key: ValueKey('disponi-passo-$n'),
              etichetta: t.passoPx(n),
              attivo: _passo == n,
              onTap: () => setState(() => _passo = n),
            ),
      ],
      contenuto: contenuto,
    );
  }
}

/// Allinea: a sinistra, al centro, a destra, in alto, al centro (verticale), in basso. Con un solo elemento si allinea
/// alla sua pagina, con più elementi al loro ingombro comune; gli elementi con «Blocca posizione» restano dove sono.
class PannelloAllinea extends ConsumerWidget {
  const PannelloAllinea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final ctrl = ref.read(editorProvider.notifier);
    Widget voce(Allineamento a, IconData icona, String nome) => TesseraVoce(
      key: ValueKey('allinea-${a.name}'),
      icona: icona,
      etichetta: nome,
      larghezza: 104,
      onTap: () => ctrl.allineaSelezione(a),
    );
    return Intelaiatura(
      nome: t.strAllinea,
      chips: const [],
      contenuto: _riga([
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
        voce(Allineamento.alto, Icons.align_vertical_top_rounded, t.allAlto),
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
      ]),
    );
  }
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
      chips: const [],
      contenuto: _riga([
        TesseraVoce(
          key: const ValueKey('distribuisci-orizzontale'),
          icona: Icons.horizontal_distribute_rounded,
          etichetta: t.distOrizzontale,
          larghezza: 160,
          onTap: () => ctrl.distribuisciSelezione(orizzontale: true),
        ),
        TesseraVoce(
          key: const ValueKey('distribuisci-verticale'),
          icona: Icons.vertical_distribute_rounded,
          etichetta: t.distVerticale,
          larghezza: 160,
          onTap: () => ctrl.distribuisciSelezione(orizzontale: false),
        ),
      ]),
    );
  }
}
