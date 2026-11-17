/// Pannello «Pagine» (piano §4.3): le azioni sulla pagina corrente (aggiungi prima/dopo, duplica, sposta, blocca, unisci
/// «a cavallo», esporta questa, elimina), il formato del carosello e «Riordina» (la Panoramica). Ogni azione agisce subito
/// e vale un passo di cronologia, con il suo messaggio e «Annulla»; il pannello resta aperto per poter ripetere (per
/// esempio spostare una pagina di più posti).
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import '../home/nuovo_progetto.dart' show nomeFormato, ordineFormati;
import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'intelaiatura.dart';
import 'stato.dart';
import 'widget_comuni.dart';

/// Un'azione su una pagina: la usano il pannello Pagine e il menu della pressione lunga nella Panoramica.
class AzionePagina {
  const AzionePagina({
    required this.chiave,
    required this.icona,
    required this.etichetta,
    required this.onTap,
    this.spenta = false,
    this.pericolo = false,
  });

  /// Nome stabile (per le prove e per le chiavi dei widget).
  final String chiave;
  final IconData icona;
  final String etichetta;
  final VoidCallback onTap;

  /// Funzione non ancora pronta: si vede più chiara e il tocco spiega che arriva.
  final bool spenta;
  final bool pericolo;
}

/// Le azioni sulla pagina [k]: stesse regole del desktop (`_delete_page`, `_move_page`, `_set_page_lock`…); quando una
/// azione non si può fare il motore dice perché con un messaggio breve.
List<AzionePagina> azioniPagina(
  Testi t,
  Snapshot s,
  ControlloEditor ctrl,
  int k, {
  required VoidCallback onEsporta,
}) {
  final c = s.canvas;
  return [
    AzionePagina(
      chiave: 'prima',
      icona: Icons.keyboard_double_arrow_left_rounded,
      etichetta: t.pagAggiungiPrima,
      onTap: () => ctrl.inserisciPagina(k),
    ),
    AzionePagina(
      chiave: 'dopo',
      icona: Icons.keyboard_double_arrow_right_rounded,
      etichetta: t.pagAggiungiDopo,
      onTap: () => ctrl.inserisciPagina(k + 1),
    ),
    AzionePagina(
      chiave: 'duplica',
      icona: Icons.content_copy_rounded,
      etichetta: t.pagDuplica,
      onTap: () => ctrl.duplicaPagina(k),
    ),
    AzionePagina(
      chiave: 'indietro',
      icona: Icons.arrow_back_rounded,
      etichetta: t.pagSpostaIndietro,
      onTap: () => ctrl.spostaPagina(-1, k),
    ),
    AzionePagina(
      chiave: 'avanti',
      icona: Icons.arrow_forward_rounded,
      etichetta: t.pagSpostaAvanti,
      onTap: () => ctrl.spostaPagina(1, k),
    ),
    AzionePagina(
      chiave: 'blocca',
      icona: c.pageLocked(k) ? Icons.lock_open_rounded : Icons.lock_outline,
      etichetta: c.pageLocked(k) ? t.pagSblocca : t.pagBlocca,
      onTap: () => ctrl.bloccaPagina(k),
    ),
    AzionePagina(
      chiave: 'unisci',
      icona: c.joined(k) ? Icons.link_off_rounded : Icons.link_rounded,
      etichetta: c.joined(k) ? t.pagSepara : t.pagUnisci,
      onTap: () => ctrl.unisciPagina(k),
    ),
    AzionePagina(
      chiave: 'esporta',
      icona: Icons.ios_share_rounded,
      etichetta: t.pagEsporta,
      onTap: onEsporta,
    ),
    AzionePagina(
      chiave: 'elimina',
      icona: Icons.delete_outline_rounded,
      etichetta: t.pagElimina,
      onTap: () => ctrl.eliminaPagina(k),
      pericolo: true,
    ),
  ];
}

class PannelloPagine extends ConsumerStatefulWidget {
  const PannelloPagine({
    super.key,
    required this.onApriPanoramica,
    required this.onEsporta,
  });

  /// Apre la Panoramica (la schermata, che sta nell'editor).
  final VoidCallback onApriPanoramica;

  /// Apre il foglio «Esporta» sulla pagina corrente.
  final VoidCallback onEsporta;

  @override
  ConsumerState<PannelloPagine> createState() => _PannelloPagineState();
}

class _PannelloPagineState extends ConsumerState<PannelloPagine> {
  final _larghezza = TextEditingController();
  final _altezza = TextEditingController();

  ControlloEditor get _ctrl => ref.read(editorProvider.notifier);

  @override
  void dispose() {
    _larghezza.dispose();
    _altezza.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final stato = ref.watch(editorProvider);
    final s = stato.snapshot;
    final c = s.canvas;
    final k = stato.pagina;
    final personalizzato = c.ratioIndex == ratioPersonalizzato;
    final azioni = [
      ...azioniPagina(t, s, _ctrl, k, onEsporta: widget.onEsporta),
      AzionePagina(
        chiave: 'riordina',
        icona: Icons.grid_view_rounded,
        etichetta: t.pagRiordina,
        onTap: () {
          _ctrl.chiudiStrumento();
          widget.onApriPanoramica();
        },
      ),
    ];
    return Intelaiatura(
      nome: t.barraPagine,
      // Le azioni agiscono subito (ognuna è già un passo di cronologia): ✓ e ✕ chiudono soltanto
      onConferma: _ctrl.chiudiStrumento,
      schede: [
        SchedaStrumento(
          etichetta: t.pagAzioni,
          chiave: const ValueKey('pagine-scheda-azioni'),
          altezza: 2 * 60 + MisureScrl.spazioPiccolo,
          contenuto: _GrigliaAzioni(azioni: azioni),
        ),
        SchedaStrumento(
          etichetta: t.pagFormato,
          chiave: const ValueKey('pagine-scheda-formato'),
          contenuto: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
            children: [
              for (final i in ordineFormati)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TesseraScelta(
                    key: ValueKey('formato-$i'),
                    disegno: _Sagoma(
                      proporzione: _proporzione(c, i),
                      scelta: c.ratioIndex == i,
                    ),
                    etichetta: nomeFormato(t, i),
                    scelta: c.ratioIndex == i,
                    larghezza: 96,
                    altezza: 84,
                    onTap: () => _ctrl.impostaFormato(i),
                  ),
                ),
            ],
          ),
        ),
        if (personalizzato)
          SchedaStrumento(
            etichetta: t.pagMisure,
            chiave: const ValueKey('pagine-scheda-misure'),
            contenuto: _misure(t, c),
          ),
      ],
    );
  }

  Widget _misure(Testi t, CanvasState c) {
    if (_larghezza.text.isEmpty) _larghezza.text = '${c.customW}';
    if (_altezza.text.isEmpty) _altezza.text = '${c.customH}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
      child: Row(
        children: [
          Expanded(child: _Campo(t.larghezzaPixel, _larghezza)),
          const SizedBox(width: MisureScrl.spazio),
          Expanded(child: _Campo(t.altezzaPixel, _altezza)),
          const SizedBox(width: MisureScrl.spazio),
          FilledButton(
            onPressed: () => _ctrl.impostaMisure(
              int.tryParse(_larghezza.text) ?? c.customW,
              int.tryParse(_altezza.text) ?? c.customH,
            ),
            child: Text(t.conferma),
          ),
        ],
      ),
    );
  }

  double _proporzione(CanvasState c, int i) {
    final m = aspectRatios[i];
    return m != null ? m.$1 / m.$2 : c.customW / c.customH;
  }
}

/// Le azioni di pagina in due righe di cinque, tutte nello schermo: icona e nome (su due righe se serve).
class _GrigliaAzioni extends StatelessWidget {
  const _GrigliaAzioni({required this.azioni});

  final List<AzionePagina> azioni;

  @override
  Widget build(BuildContext context) {
    const colonne = 5;
    final righe = (azioni.length / colonne).ceil();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazioPiccolo),
      child: Column(
        children: [
          for (var r = 0; r < righe; r++) ...[
            if (r > 0) const SizedBox(height: MisureScrl.spazioPiccolo),
            Expanded(
              child: Row(
                children: [
                  for (var c = 0; c < colonne; c++)
                    Expanded(
                      child: r * colonne + c < azioni.length
                          ? _VoceAzionePagina(azione: azioni[r * colonne + c])
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VoceAzionePagina extends StatelessWidget {
  const _VoceAzionePagina({required this.azione});

  final AzionePagina azione;

  @override
  Widget build(BuildContext context) {
    final a = azione;
    final colore = a.spenta
        ? ColoriScrl.testoSpento
        : a.pericolo
        ? ColoriScrl.pericoloTesto
        : ColoriScrl.testo;
    return Semantics(
      button: true,
      label: a.etichetta,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('azione-${a.chiave}'),
        borderRadius: BorderRadius.circular(MisureScrl.angoloTessera),
        onTap: a.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(a.icona, size: 22, color: colore),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  a.etichetta,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  textScaler: MediaQuery.textScalerOf(context)
                      .clamp(maxScaleFactor: 1.1),
                  style: TextStyle(
                    fontSize: TestoScrl.piccolo,
                    height: 1.15,
                    color: colore,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  const _Campo(this.etichetta, this.controllo);

  final String etichetta;
  final TextEditingController controllo;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controllo,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(labelText: etichetta),
  );
}

/// Sagoma proporzionata di un formato dentro la tessera.
class _Sagoma extends StatelessWidget {
  const _Sagoma({required this.proporzione, required this.scelta});

  final double proporzione;
  final bool scelta;

  @override
  Widget build(BuildContext context) {
    const box = 40.0;
    final w = proporzione >= 1 ? box : box * proporzione;
    final h = proporzione >= 1 ? box / proporzione : box;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: scelta ? ColoriScrl.accento : ColoriScrl.testoSecondario,
          width: scelta ? 2 : 1,
        ),
      ),
    );
  }
}
