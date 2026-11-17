/// «Gesti» (piano §4.7): la versione mobile di «Scorciatoie da tastiera e mouse» del desktop. Elenca come si usano
/// tela, pannelli e pagine. Ogni riga è un solo elemento per i lettori di schermo (gesto e spiegazione insieme).
library;

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';

class _Gesto {
  const _Gesto(this.icona, this.nome, this.descrizione);
  final IconData icona;
  final String nome;
  final String descrizione;
}

class GestiPage extends StatelessWidget {
  const GestiPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final gruppi = <(String, List<_Gesto>)>[
      (
        t.gestiSulla,
        [
          _Gesto(Icons.touch_app_outlined, t.gestoTocca, t.gestoToccaDesc),
          _Gesto(Icons.ads_click_rounded, t.gestoDoppio, t.gestoDoppioDesc),
          _Gesto(
            Icons.pan_tool_alt_outlined,
            t.gestoPremuto,
            t.gestoPremutoDesc,
          ),
          _Gesto(
            Icons.pan_tool_outlined,
            t.gestoPremutoVuoto,
            t.gestoPremutoVuotoDesc,
          ),
          _Gesto(Icons.open_with_rounded, t.gestoTrascina, t.gestoTrascinaDesc),
          _Gesto(
            Icons.drag_indicator_rounded,
            t.gestoManiglie,
            t.gestoManiglieDesc,
          ),
          _Gesto(Icons.pinch_rounded, t.gestoPizzica, t.gestoPizzicaDesc),
          _Gesto(Icons.swipe_rounded, t.gestoScorri, t.gestoScorriDesc),
        ],
      ),
      (
        t.gestiNeiPannelli,
        [
          _Gesto(Icons.tune_rounded, t.gestoCursore, t.gestoCursoreDesc),
          _Gesto(
            Icons.keyboard_arrow_down_rounded,
            t.gestoPannello,
            t.gestoPannelloDesc,
          ),
          _Gesto(Icons.contrast, t.gestoConfronto, t.gestoConfrontoDesc),
          _Gesto(
            Icons.undo_rounded,
            t.gestoAnnullaLungo,
            t.gestoAnnullaLungoDesc,
          ),
          _Gesto(
            Icons.arrow_back_rounded,
            t.gestoIndietro,
            t.gestoIndietroDesc,
          ),
        ],
      ),
      (
        t.gestiNellePagine,
        [
          _Gesto(
            Icons.view_carousel_outlined,
            t.gestoPanoramica,
            t.gestoPanoramicaDesc,
          ),
          _Gesto(Icons.more_horiz_rounded, t.gestoPuntini, t.gestoPuntiniDesc),
        ],
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(t.gestiTitolo)),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('gesti-elenco'),
          padding: const EdgeInsets.only(bottom: MisureScrl.spazio),
          children: [
            for (final (titolo, gesti) in gruppi) ...[
              Semantics(
                header: true,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    MisureScrl.spazio,
                    MisureScrl.spazio,
                    MisureScrl.spazio,
                    MisureScrl.spazioPiccolo,
                  ),
                  child: Text(
                    titolo,
                    style: const TextStyle(
                      fontSize: TestoScrl.normale,
                      fontWeight: TestoScrl.marcato,
                      color: ColoriScrl.testoSecondario,
                    ),
                  ),
                ),
              ),
              for (final g in gesti) _RigaGesto(g),
            ],
          ],
        ),
      ),
    );
  }
}

class _RigaGesto extends StatelessWidget {
  const _RigaGesto(this.gesto);
  final _Gesto gesto;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${gesto.nome}. ${gesto.descrizione}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MisureScrl.spazio,
          vertical: MisureScrl.spazioPiccolo,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: MisureScrl.tocco,
              height: MisureScrl.tocco,
              decoration: BoxDecoration(
                color: ColoriScrl.rilievo,
                borderRadius: BorderRadius.circular(MisureScrl.angoloTessera),
              ),
              child: Icon(gesto.icona, color: ColoriScrl.testo),
            ),
            const SizedBox(width: MisureScrl.spazio),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gesto.nome,
                    style: const TextStyle(
                      fontSize: TestoScrl.normale,
                      fontWeight: TestoScrl.marcato,
                      color: ColoriScrl.testo,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    gesto.descrizione,
                    style: const TextStyle(
                      fontSize: TestoScrl.normale,
                      color: ColoriScrl.testoSecondario,
                    ),
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
