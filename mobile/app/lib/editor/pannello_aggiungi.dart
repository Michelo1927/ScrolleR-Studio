/// Pannello «＋» (piano §4.3). In questa fase: «Foto o video» (dalla galleria, direttamente nella pagina corrente)
/// e «Pagina nuova». Testo e Forma ci sono già ma arrivano con la Fase 5: si vedono spenti e dicono che arrivano.
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
    void arrivera() => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t.inArrivo)));
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
                _Voce(Icons.title_rounded, t.testo, arrivera, spenta: true),
                _Voce(Icons.category_outlined, t.forma, arrivera, spenta: true),
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
  const _Voce(this.icona, this.etichetta, this.onTap, {this.spenta = false});

  final IconData icona;
  final String etichetta;
  final VoidCallback onTap;
  final bool spenta;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: MisureScrl.spazioPiccolo),
    child: Container(
      width: 96,
      decoration: BoxDecoration(
        color: ColoriScrl.rilievo,
        borderRadius: BorderRadius.circular(MisureScrl.angoloTessera),
      ),
      child: VoceBarra(
        icona: icona,
        etichetta: etichetta,
        onTap: onTap,
        spenta: spenta,
      ),
    ),
  );
}
