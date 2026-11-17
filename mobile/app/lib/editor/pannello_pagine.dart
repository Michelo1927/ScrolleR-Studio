/// Pannello «Pagine» (piano §4.3): le azioni sulla pagina corrente (aggiungi prima/dopo, duplica, sposta, blocca, unisci
/// «a cavallo», esporta questa, elimina), il formato del carosello e «Riordina» (la Panoramica). Ogni azione agisce subito
/// e vale un passo di cronologia, con il suo messaggio e «Annulla»; il pannello resta aperto per poter ripetere (per
/// esempio spostare una pagina di più posti).
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import '../home/nuovo_progetto.dart' show nomeFormato;
import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
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

enum _Scheda { azioni, formato, misure }

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
  _Scheda _scheda = _Scheda.azioni;
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
    final personalizzato = c.ratioIndex == ratioPersonalizzato;
    // La scheda delle misure ha senso solo col formato Personalizzato
    final scheda = _scheda == _Scheda.misure && !personalizzato
        ? _Scheda.formato
        : _scheda;
    return PannelloBasso(
      onScarta: _ctrl.chiudiStrumento,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: MisureScrl.spazioPiccolo),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: MisureScrl.spazio,
              ),
              children: [
                _chip(t.pagAzioni, _Scheda.azioni, scheda),
                _chip(t.pagFormato, _Scheda.formato, scheda),
                if (personalizzato) _chip(t.pagMisure, _Scheda.misure, scheda),
                Padding(
                  padding: const EdgeInsets.only(
                    right: MisureScrl.spazioPiccolo,
                  ),
                  child: Center(
                    child: ChipParametro(
                      etichetta: t.pagRiordina,
                      attivo: false,
                      onTap: () {
                        _ctrl.chiudiStrumento();
                        widget.onApriPanoramica();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MisureScrl.spazioPiccolo),
          SizedBox(height: 88, child: _contenuto(t, s, stato.pagina, scheda)),
          PiedeStrumento(
            nome: t.barraPagine,
            etichettaAnnulla: t.chiudi,
            etichettaConferma: t.conferma,
            onAnnulla: _ctrl.chiudiStrumento,
            onConferma: _ctrl.chiudiStrumento,
          ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }

  Widget _chip(String nome, _Scheda s, _Scheda attuale) => Padding(
    padding: const EdgeInsets.only(right: MisureScrl.spazioPiccolo),
    child: Center(
      child: ChipParametro(
        etichetta: nome,
        attivo: attuale == s,
        onTap: () => setState(() => _scheda = s),
      ),
    ),
  );

  Widget _contenuto(Testi t, Snapshot s, int k, _Scheda scheda) {
    final c = s.canvas;
    switch (scheda) {
      case _Scheda.azioni:
        return ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
          children: [
            for (final a in azioniPagina(
              t,
              s,
              _ctrl,
              k,
              onEsporta: widget.onEsporta,
            ))
              TesseraVoce(
                key: ValueKey('azione-${a.chiave}'),
                icona: a.icona,
                etichetta: a.etichetta,
                onTap: a.onTap,
                spenta: a.spenta,
                colore: a.pericolo ? ColoriScrl.pericolo : null,
              ),
          ],
        );
      case _Scheda.formato:
        return ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
          children: [
            for (var i = 0; i < aspectRatios.length; i++)
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
        );
      case _Scheda.misure:
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
  }

  double _proporzione(CanvasState c, int i) {
    final m = aspectRatios[i];
    return m != null ? m.$1 / m.$2 : c.customW / c.customH;
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
