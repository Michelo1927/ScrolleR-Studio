/// Pannello «Disposizione» (piano §4.3 e §4.4): le 6 disposizioni come tessere, lo stile del mosaico, l'ambito,
/// le foto per pagina, le pagine, la spaziatura e il margine. L'effetto si vede subito sulla pagina (bozza);
/// ✓ lo conferma come un solo passo di cronologia, ✕ torna com'era.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'icone_disposizione.dart';
import 'sessione.dart';
import 'stato.dart';
import 'widget_comuni.dart';

enum _Parametro {
  disposizione,
  mosaico,
  pagine,
  fotoPerPagina,
  fotoQui,
  spaziatura,
  margine,
}

/// Valori di partenza dei cursori (doppio tocco = valore iniziale), quelli del desktop.
const int _spaziaturaIniziale = 16;
const int _margineIniziale = 24;

String _nomeDisposizione(Testi t, String modo) => switch (modo) {
  LayoutModes.grid => t.dispGriglia,
  LayoutModes.mosaic => t.dispMosaico,
  LayoutModes.stripsH => t.dispRighe,
  LayoutModes.stripsV => t.dispColonne,
  LayoutModes.scatter => t.dispPolaroid,
  _ => t.dispACavallo,
};

String _nomeStile(Testi t, String stile) => switch (stile) {
  'top' => t.stileInAlto,
  'bottom' => t.stileInBasso,
  'left' => t.stileASinistra,
  'right' => t.stileADestra,
  'center' => t.stileAlCentro,
  'two' => t.stileDueGrandi,
  'masonry' => t.stileMuratura,
  _ => t.stileAutomatico,
};

class PannelloDisposizione extends ConsumerStatefulWidget {
  const PannelloDisposizione({super.key});

  @override
  ConsumerState<PannelloDisposizione> createState() =>
      _PannelloDisposizioneState();
}

class _PannelloDisposizioneState extends ConsumerState<PannelloDisposizione> {
  _Parametro _parametro = _Parametro.disposizione;

  /// Ambito della scelta della disposizione: tutto il carosello o solo la pagina corrente.
  bool _soloPagina = false;

  /// Avvisi del motore nati durante l'anteprima, mostrati alla conferma.
  final List<Notice> _notice = [];

  SessioneEditor get _s => ref.read(sessioneProvider);
  ControlloEditor get _ctrl => ref.read(editorProvider.notifier);

  /// Applica [op] alla bozza attuale e la mostra; se il motore la rifiuta, ne dice il motivo.
  void _modifica(EngineResult Function(Snapshot s, EngineContext ctx) op) {
    final r = op(ref.read(editorProvider).snapshot, _s.ctx);
    if (r.applied) {
      _notice.addAll(r.notices);
      _ctrl.anteprima(r.snapshot);
    } else {
      _ctrl.avvisaNotice(r.notices);
    }
  }

  void _conferma() {
    _ctrl.confermaEChiudi([..._notice]);
  }

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final stato = ref.watch(editorProvider);
    final c = stato.snapshot.canvas;
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
                _chip(t.parDisposizione, _Parametro.disposizione),
                _chip(t.parMosaico, _Parametro.mosaico),
                _chip(t.parPagine, _Parametro.pagine, '${c.numFrames}'),
                _chip(
                  t.parFotoPerPagina,
                  _Parametro.fotoPerPagina,
                  c.perPage == 0 ? t.auto : '${c.perPage}',
                ),
                _chip(t.parFotoQui, _Parametro.fotoQui),
                _chip(t.parSpaziatura, _Parametro.spaziatura, '${c.gap}'),
                _chip(t.parMargine, _Parametro.margine, '${c.margin}'),
                const SizedBox(width: MisureScrl.spazioPiccolo),
                ChipParametro(
                  etichetta: t.unaPerPagina,
                  attivo: c.perFrame,
                  onTap: () => _modifica(
                    (s, ctx) => setPerFrame(s, !s.canvas.perFrame, ctx),
                  ),
                ),
                const SizedBox(width: MisureScrl.spazioPiccolo),
                ChipParametro(
                  etichetta: t.rimescola,
                  attivo: false,
                  onTap: () => _modifica(shufflePhotos),
                ),
              ],
            ),
          ),
          const SizedBox(height: MisureScrl.spazioPiccolo),
          SizedBox(height: 110, child: _contenuto(t, stato)),
          PiedeStrumento(
            nome: t.strumentoDisposizione,
            etichettaAnnulla: t.annulla,
            etichettaConferma: t.conferma,
            onAnnulla: _ctrl.chiudiStrumento,
            onConferma: _conferma,
          ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }

  Widget _chip(String nome, _Parametro p, [String? valore]) => Padding(
    padding: const EdgeInsets.only(right: MisureScrl.spazioPiccolo),
    child: Center(
      child: ChipParametro(
        etichetta: nome,
        valore: valore,
        attivo: _parametro == p,
        onTap: () => setState(() => _parametro = p),
      ),
    ),
  );

  Widget _contenuto(Testi t, StatoEditor stato) {
    final c = stato.snapshot.canvas;
    final k = stato.pagina;
    switch (_parametro) {
      case _Parametro.disposizione:
        final propria = c.pageLayouts.length > k ? c.pageLayouts[k] : null;
        final attuale = _soloPagina && propria != null
            ? propria.mode
            : c.layoutMode;
        return Column(
          children: [
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: MisureScrl.spazio,
                ),
                children: [
                  for (final m in LayoutModes.all)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TesseraScelta(
                        disegno: IconaDisposizione(m, colore: ColoriScrl.testo),
                        etichetta: _nomeDisposizione(t, m),
                        scelta: attuale == m,
                        onTap: () => _scegliDisposizione(m),
                      ),
                    ),
                  const SizedBox(width: MisureScrl.spazio),
                  Center(
                    child: _Ambito(
                      soloPagina: _soloPagina,
                      onCambia: (v) => setState(() => _soloPagina = v),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      case _Parametro.mosaico:
        return ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
          children: [
            for (final m in MosaicStyles.all)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TesseraScelta(
                  disegno: IconaDisposizione(m, colore: ColoriScrl.testo),
                  etichetta: _nomeStile(t, m),
                  scelta: c.mosaicStyle == m,
                  onTap: () => _modifica((s, ctx) => setMosaicStyle(s, m, ctx)),
                  larghezza: 96,
                ),
              ),
          ],
        );
      case _Parametro.pagine:
        return Center(
          child: Contatore(
            testo: t.numeroPagine(c.numFrames),
            etichettaMeno: t.menoPagine,
            etichettaPiu: t.piuPagine,
            onMeno: c.numFrames > 1
                ? () => _modifica(
                    (s, ctx) => setNumFrames(s, s.canvas.numFrames - 1, ctx),
                  )
                : null,
            onPiu: c.numFrames < pagineMassime
                ? () => _modifica(
                    (s, ctx) => setNumFrames(s, s.canvas.numFrames + 1, ctx),
                  )
                : null,
          ),
        );
      case _Parametro.fotoPerPagina:
        return Center(
          child: Contatore(
            testo: c.perPage == 0 ? t.auto : t.numeroFoto(c.perPage),
            etichettaMeno: t.menoFoto,
            etichettaPiu: t.piuFoto,
            onMeno: c.perPage > 0
                ? () => _modifica(
                    (s, ctx) => setPerPage(s, s.canvas.perPage - 1, ctx),
                  )
                : null,
            onPiu: c.perPage < 20
                ? () => _modifica(
                    (s, ctx) => setPerPage(s, s.canvas.perPage + 1, ctx),
                  )
                : null,
          ),
        );
      case _Parametro.fotoQui:
        final proprie = c.pageCounts.length > k ? c.pageCounts[k] : null;
        final totale = stato.snapshot.items.length;
        return Center(
          child: Contatore(
            testo: proprie == null ? t.auto : t.numeroFoto(proprie),
            etichettaMeno: t.menoFoto,
            etichettaPiu: t.piuFoto,
            onMeno: proprie != null
                ? () => _modifica(
                    (s, ctx) => setPageCount(
                      s,
                      k,
                      proprie == 0 ? null : proprie - 1,
                      ctx,
                    ),
                  )
                : null,
            onPiu: (proprie ?? 0) < totale
                ? () => _modifica(
                    (s, ctx) => setPageCount(s, k, (proprie ?? 0) + 1, ctx),
                  )
                : null,
          ),
        );
      case _Parametro.spaziatura:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
          child: Center(
            child: CursoreGrande(
              etichetta: t.parSpaziatura,
              valore: c.gap.toDouble(),
              minimo: 0,
              massimo: 80,
              iniziale: _spaziaturaIniziale.toDouble(),
              onCambia: (v) =>
                  _modifica((s, ctx) => setSpacing(s, ctx, gap: v)),
              onFine: () {},
            ),
          ),
        );
      case _Parametro.margine:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
          child: Center(
            child: CursoreGrande(
              etichetta: t.parMargine,
              valore: c.margin.toDouble(),
              minimo: 0,
              massimo: 120,
              iniziale: _margineIniziale.toDouble(),
              onCambia: (v) =>
                  _modifica((s, ctx) => setSpacing(s, ctx, margin: v)),
              onFine: () {},
            ),
          ),
        );
    }
  }

  void _scegliDisposizione(String modo) {
    final k = ref.read(editorProvider).pagina;
    if (_soloPagina) {
      _modifica((s, ctx) => setPageLayout(s, k, modo, ctx));
    } else {
      _modifica((s, ctx) => chooseLayout(s, modo, ctx));
    }
  }
}

/// Interruttore «Tutto il carosello / Solo questa pagina».
class _Ambito extends StatelessWidget {
  const _Ambito({required this.soloPagina, required this.onCambia});

  final bool soloPagina;
  final ValueChanged<bool> onCambia;

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ChipParametro(
          etichetta: t.ambitoTutto,
          attivo: !soloPagina,
          onTap: () => onCambia(false),
        ),
        const SizedBox(height: MisureScrl.spazioPiccolo),
        ChipParametro(
          etichetta: t.ambitoPagina,
          attivo: soloPagina,
          onTap: () => onCambia(true),
        ),
      ],
    );
  }
}
