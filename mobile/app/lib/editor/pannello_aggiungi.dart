/// Pannello «＋» (piano §4.3): «Testo» (un testo nuovo al centro della pagina, con la tastiera pronta), «Forma» (le 9
/// forme da scegliere), «Foto o video» (dalla galleria, direttamente nella pagina corrente) e «Pagina nuova».
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../home/scelta_foto.dart';
import '../l10n/app_localizations.dart';
import '../project/crea_progetto.dart';
import '../theme/tokens.dart';
import 'stato.dart';
import 'widget_comuni.dart';

class PannelloAggiungi extends ConsumerWidget {
  const PannelloAggiungi({super.key});

  Future<void> _foto(BuildContext context, WidgetRef ref) async {
    final s = ref.read(sessioneProvider);
    final ctrl = ref.read(editorProvider.notifier);
    final scelte = await Navigator.of(context).push<List<FotoScelta>>(
      MaterialPageRoute(
        builder: (_) =>
            SceltaFotoPage(cartellaPerCopie: () async => s.cartella),
      ),
    );
    if (scelte == null || scelte.isEmpty) return;
    for (final f in scelte) {
      s.ricordaMisura(f.chiave, f.w, f.h);
    }
    final voci = [for (final f in scelte) f.voce];
    ctrl.aggiungiAllaLibreria(voci);
    ctrl.aggiungiATela(voci);
    ctrl.chiudiStrumento();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final ctrl = ref.read(editorProvider.notifier);
    return PannelloBasso(
      onScarta: ctrl.chiudiStrumento,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: MisureScrl.barraInferiore + 24,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(MisureScrl.spazio),
              children: [
                _Voce(
                  Icons.add_photo_alternate_outlined,
                  t.fotoOVideo,
                  () => _foto(context, ref),
                ),
                _Voce(Icons.note_add_outlined, t.paginaNuova, () {
                  ctrl.aggiungiPagina();
                  ctrl.chiudiStrumento();
                }),
                _Voce(Icons.title_rounded, t.testo, ctrl.nuovoTesto),
                _Voce(
                  Icons.category_outlined,
                  t.forma,
                  () => ctrl.apriStrumento(Strumento.formaNuova),
                ),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}

class _Voce extends StatelessWidget {
  const _Voce(this.icona, this.etichetta, this.onTap);

  final IconData icona;
  final String etichetta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: MisureScrl.spazioPiccolo),
    child: Container(
      width: 96,
      decoration: BoxDecoration(
        color: ColoriScrl.rilievo,
        borderRadius: BorderRadius.circular(MisureScrl.angoloTessera),
      ),
      child: VoceBarra(icona: icona, etichetta: etichetta, onTap: onTap),
    ),
  );
}
