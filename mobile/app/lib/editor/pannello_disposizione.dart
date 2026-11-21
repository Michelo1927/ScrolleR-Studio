/// Pannello «Disposizione» (piano §4.3 e §4.4): si apre sulle 7 disposizioni (con l'ambito «Tutto il carosello /
/// Solo questa pagina» sopra); ‹ porta alla griglia di tutte le impostazioni col loro valore: stile del mosaico,
/// pagine, foto per pagina, foto in questa pagina, spaziatura e margine. L'effetto si vede subito sulla pagina (bozza);
/// ✓ lo conferma come un solo passo di cronologia, ✕ torna com'era.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'icone_disposizione.dart';
import 'intelaiatura.dart';
import 'sessione.dart';
import 'stato.dart';
import 'widget_comuni.dart';

/// Valori di partenza dei cursori (doppio tocco = valore iniziale), quelli del desktop.
const int _spaziaturaIniziale = 16;
const int _margineIniziale = 24;

/// Nome del modo di disposizione, dai file `.arb`.
String nomeDisposizione(Testi t, String modo) => switch (modo) {
  LayoutModes.grid => t.dispGriglia,
  LayoutModes.mosaic => t.dispMosaico,
  LayoutModes.stripsH => t.dispRighe,
  LayoutModes.stripsV => t.dispColonne,
  LayoutModes.scatter => t.dispPolaroid,
  LayoutModes.film => t.dispPellicola,
  _ => t.dispACavallo,
};

String _nomeStrisce(Testi t, String verso) => switch (verso) {
  'horizontal' => t.strisceOrizzontali,
  'vertical' => t.strisceVerticali,
  _ => t.strisceAutomatico,
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
    final k = stato.pagina;
    final propria = c.pageLayouts.length > k ? c.pageLayouts[k] : null;
    final attuale = _soloPagina && propria != null
        ? propria.mode
        : c.layoutMode;
    final proprie = c.pageCounts.length > k ? c.pageCounts[k] : null;
    // Verso delle strisce: quello della pagina se ha una sua Pellicola, altrimenti quello di tutta la tela
    final pellicolaPropria =
        _soloPagina && propria != null && propria.mode == LayoutModes.film;
    final versoStrisce = pellicolaPropria
        ? (propria.style == null || propria.style!.isEmpty
              ? c.filmStyle
              : propria.style!)
        : c.filmStyle;
    final totale = stato.snapshot.items.length;
    return Intelaiatura(
      nome: t.strumentoDisposizione,
      // Si apre sul menu di tutte le impostazioni (disposizione, mosaico, pagine, foto per pagina…)
      onConferma: _conferma,
      azioni: [
        AzioneStrumento(
          chiave: const ValueKey('disp-una-per-pagina'),
          icona: Icons.view_day_outlined,
          etichetta: t.unaPerPagina,
          attiva: c.perFrame,
          onTap: () =>
              _modifica((s, ctx) => setPerFrame(s, !s.canvas.perFrame, ctx)),
        ),
        AzioneStrumento(
          chiave: const ValueKey('disp-rimescola'),
          icona: Icons.shuffle_rounded,
          etichetta: t.rimescola,
          onTap: () => _modifica(shufflePhotos),
        ),
      ],
      schede: [
        SchedaStrumento(
          etichetta: t.parDisposizione,
          chiave: const ValueKey('disp-scheda-disposizione'),
          valore: nomeDisposizione(t, attuale),
          altezza: 88,
          intestazione: ControlloSegmentato<bool>(
            voci: [
              VoceSegmento(
                valore: false,
                etichetta: t.ambitoTutto,
                chiave: const ValueKey('disp-ambito-tutto'),
              ),
              VoceSegmento(
                valore: true,
                etichetta: t.ambitoPagina,
                chiave: const ValueKey('disp-ambito-pagina'),
              ),
            ],
            scelto: _soloPagina,
            onScelto: (v) => setState(() => _soloPagina = v),
          ),
          contenuto: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
            children: [
              for (final m in LayoutModes.all)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TesseraScelta(
                    disegno: IconaDisposizione(m, colore: ColoriScrl.testo),
                    etichetta: nomeDisposizione(t, m),
                    scelta: attuale == m,
                    onTap: () => _scegliDisposizione(m),
                  ),
                ),
            ],
          ),
        ),
        SchedaStrumento(
          etichetta: t.parMosaico,
          chiave: const ValueKey('disp-scheda-mosaico'),
          valore: _nomeStile(t, c.mosaicStyle),
          altezza: 88,
          contenuto: ListView(
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
                    onTap: () =>
                        _modifica((s, ctx) => setMosaicStyle(s, m, ctx)),
                    larghezza: 96,
                  ),
                ),
            ],
          ),
        ),
        if (attuale == LayoutModes.film)
          SchedaStrumento(
            etichetta: t.parStrisce,
            chiave: const ValueKey('disp-scheda-strisce'),
            valore: _nomeStrisce(t, versoStrisce),
            modificata: versoStrisce != 'auto',
            altezza: 88,
            contenuto: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: MisureScrl.spazio,
              ),
              children: [
                for (final v in FilmStyles.all)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TesseraScelta(
                      disegno: IconaDisposizione(
                        v == 'vertical' ? 'film_v' : 'film',
                        colore: ColoriScrl.testo,
                      ),
                      etichetta: _nomeStrisce(t, v),
                      scelta: versoStrisce == v,
                      onTap: () => _scegliStrisce(v),
                      larghezza: 96,
                    ),
                  ),
              ],
            ),
          ),
        if (attuale == LayoutModes.scatter) ...[
          SchedaStrumento(
            etichetta: t.parOmbraPolaroid,
            chiave: const ValueKey('disp-scheda-ombra-polaroid'),
            valore: '${c.polaroidShadow}',
            modificata: c.polaroidShadow != 0,
            contenuto: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MisureScrl.spazio,
              ),
              child: Center(
                child: CursoreGrande(
                  etichetta: t.parOmbraPolaroid,
                  valore: c.polaroidShadow.toDouble(),
                  minimo: 0,
                  massimo: 100,
                  iniziale: 0,
                  onCambia: (v) =>
                      _modifica((s, ctx) => setPolaroidLook(s, ctx, shadow: v)),
                  onFine: () {},
                ),
              ),
            ),
          ),
          SchedaStrumento(
            etichetta: t.parRilievo,
            chiave: const ValueKey('disp-scheda-rilievo'),
            valore: '${c.polaroidDepth}',
            modificata: c.polaroidDepth != 0,
            contenuto: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MisureScrl.spazio,
              ),
              child: Center(
                child: CursoreGrande(
                  etichetta: t.parRilievo,
                  valore: c.polaroidDepth.toDouble(),
                  minimo: 0,
                  massimo: 100,
                  iniziale: 0,
                  onCambia: (v) =>
                      _modifica((s, ctx) => setPolaroidLook(s, ctx, depth: v)),
                  onFine: () {},
                ),
              ),
            ),
          ),
        ],
        SchedaStrumento(
          etichetta: t.parPagine,
          chiave: const ValueKey('disp-scheda-pagine'),
          valore: '${c.numFrames}',
          contenuto: Center(
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
          ),
        ),
        SchedaStrumento(
          etichetta: t.parFotoPerPagina,
          chiave: const ValueKey('disp-scheda-foto-per-pagina'),
          valore: c.perPage == 0 ? t.auto : '${c.perPage}',
          modificata: c.perPage != 0,
          contenuto: Center(
            child: Contatore(
              testo: c.perPage == 0 ? t.auto : t.numeroFoto(c.perPage),
              etichettaMeno: t.menoFoto,
              etichettaPiu: t.piuFoto,
              onMeno: c.perPage > 0
                  ? () => _modifica(
                      (s, ctx) => setPerPage(
                        s,
                        s.canvas.perPage - 1,
                        ctx,
                        liberaPagineVuote: true,
                      ),
                    )
                  : null,
              onPiu: c.perPage < 20
                  ? () => _modifica(
                      (s, ctx) => setPerPage(
                        s,
                        s.canvas.perPage + 1,
                        ctx,
                        liberaPagineVuote: true,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        SchedaStrumento(
          etichetta: t.parFotoQui,
          chiave: const ValueKey('disp-scheda-foto-qui'),
          valore: proprie == null ? t.auto : '$proprie',
          modificata: proprie != null,
          contenuto: Center(
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
          ),
        ),
        SchedaStrumento(
          etichetta: t.parSpaziatura,
          chiave: const ValueKey('disp-scheda-spaziatura'),
          valore: '${c.gap}',
          modificata: c.gap != _spaziaturaIniziale,
          contenuto: Padding(
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
          ),
        ),
        SchedaStrumento(
          etichetta: t.parMargine,
          chiave: const ValueKey('disp-scheda-margine'),
          valore: '${c.margin}',
          modificata: c.margin != _margineIniziale,
          contenuto: Padding(
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
          ),
        ),
      ],
    );
  }

  void _scegliStrisce(String verso) {
    final stato = ref.read(editorProvider);
    final k = stato.pagina;
    final pl = stato.snapshot.canvas.pageLayouts;
    final propria = pl.length > k ? pl[k] : null;
    if (_soloPagina && propria != null && propria.mode == LayoutModes.film) {
      _modifica((s, ctx) => setPageLayout(s, k, LayoutModes.film, ctx, verso));
    } else {
      _modifica((s, ctx) => setFilmStyle(s, verso, ctx));
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
