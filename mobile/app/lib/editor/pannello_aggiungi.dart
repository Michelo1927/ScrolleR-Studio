/// Pannello «＋» (piano §4.3): «Testo» (un testo nuovo al centro della pagina, con la tastiera pronta), «Forma» (le 9
/// forme da scegliere), «Foto o video» (dalla galleria, direttamente nella pagina corrente) e «Pagina nuova».
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../home/scelta_foto.dart';
import '../l10n/app_localizations.dart';
import '../project/crea_progetto.dart';
import '../theme/tokens.dart';
import 'intelaiatura.dart';
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
    Widget voce(
      String chiave,
      IconData icona,
      String etichetta,
      VoidCallback onTap,
    ) => TesseraVoce(
      key: ValueKey(chiave),
      icona: icona,
      etichetta: etichetta,
      larghezza: null,
      margine: false,
      onTap: onTap,
    );
    return PannelloBasso(
      onScarta: ctrl.chiudiStrumento,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: MisureScrl.spazio),
          RigaTessere(
            altezza: MisureScrl.barraInferiore + 8,
            children: [
              voce(
                'aggiungi-foto',
                Icons.add_photo_alternate_outlined,
                t.fotoOVideo,
                () => _foto(context, ref),
              ),
              voce(
                'aggiungi-pagina',
                Icons.note_add_outlined,
                t.paginaNuova,
                () {
                  ctrl.aggiungiPagina();
                  ctrl.chiudiStrumento();
                },
              ),
              voce(
                'aggiungi-testo',
                Icons.title_rounded,
                t.testo,
                ctrl.nuovoTesto,
              ),
              voce(
                'aggiungi-forma',
                Icons.category_outlined,
                t.forma,
                () => ctrl.apriStrumento(Strumento.formaNuova),
              ),
            ],
          ),
          const SizedBox(height: MisureScrl.spazioPiccolo),
          PiedeStrumento(
            nome: t.barraAggiungi,
            etichettaAnnulla: t.chiudi,
            etichettaConferma: t.conferma,
            onAnnulla: ctrl.chiudiStrumento,
            onConferma: null,
          ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}
