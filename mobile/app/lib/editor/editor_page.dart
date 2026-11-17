/// Schermata dell'editor (piano §4.1): barra superiore, tela a pagina singola, striscia pagine e barra inferiore.
/// Gli strumenti salgono dal basso e la pagina si rimpicciolisce per restare sempre visibile (§3.4).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../export/foglio_esporta.dart';
import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'barra_selezione.dart';
import 'indietro.dart';
import 'mancanti_ui.dart';
import 'pagina_anteprima.dart';
import 'pagina_panoramica.dart';
import 'pannelli_forma.dart';
import 'pannelli_foto.dart';
import 'pannelli_testo.dart';
import 'pannelli_video.dart';
import 'pannello_aggiungi.dart';
import 'pannello_cronologia.dart';
import 'pannello_disponi.dart';
import 'pannello_disposizione.dart';
import 'pannello_libreria.dart';
import 'pannello_pagine.dart';
import 'pannello_stile.dart';
import 'sessione.dart';
import 'stato.dart';
import 'suggerimenti.dart';
import 'tela.dart';
import 'testi_avvisi.dart';
import 'widget_comuni.dart';

/// L'editor di un progetto aperto. Porta con sé la sessione (immagini, contesto del motore, salvataggio).
class EditorPage extends StatefulWidget {
  const EditorPage({super.key, required this.sessione});

  final SessioneEditor sessione;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  @override
  void dispose() {
    unawaited(widget.sessione.chiudi());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [sessioneProvider.overrideWithValue(widget.sessione)],
    child: const _Editor(),
  );
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor();

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> with WidgetsBindingObserver {
  ControlloEditor get _ctrl => ref.read(editorProvider.notifier);

  /// L'avviso «foto non trovate» si dà una volta sola per apertura del progetto.
  bool _avvisatoMancanti = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState stato) {
    // Tornati da un'altra app (la galleria, i file…) una foto può essere sparita o tornata
    if (stato == AppLifecycleState.resumed) ref.invalidate(mancantiProvider);
    // L'app va in secondo piano: si salva subito, senza aspettare il ritardo di 1 s
    if (stato == AppLifecycleState.paused ||
        stato == AppLifecycleState.inactive ||
        stato == AppLifecycleState.hidden) {
      _ctrl.fermaTuttiVideo();
      unawaited(_ctrl.salvaOra());
    }
  }

  @override
  void didHaveMemoryPressure() => ref.read(sessioneProvider).memoriaScarsa();

  /// Uscita in corso: si sta salvando prima di tornare alla Home.
  bool _uscendo = false;

  /// Salva e torna alla Home. Una volta sola: altri «indietro» mentre si salva (freccia, gesto di sistema) non
  /// fanno niente; prima ognuno chiudeva una schermata, e quello in più chiudeva la Home lasciando lo schermo nero.
  Future<void> _esci() async {
    if (_uscendo) return;
    _uscendo = true;
    await _ctrl.salvaOra(attendiMiniatura: true);
    if (!mounted) return;
    final rotta = ModalRoute.of(context);
    // Si chiude solo la schermata dell'editor, se c'è ancora (e quello che le si è aperto sopra nel frattempo)
    if (rotta == null || !rotta.isActive) return;
    Navigator.of(context)
      ..popUntil((r) => r == rotta)
      ..pop();
  }

  /// Gesto «indietro» di sistema: torna su da un sottomenu, poi chiude lo strumento (scartando; dentro un menu si torna
  /// al menu), poi toglie la selezione, poi esce.
  void _indietro() {
    if (_uscendo) return;
    final s = ref.read(editorProvider);
    // Un sottomenu aperto (dettaglio di un parametro, selettore completo, categoria della barra) torna su di un livello
    if (ref.read(pilaIndietroProvider).indietro()) return;
    if (s.strumento != Strumento.nessuno) {
      _ctrl.chiudiStrumentoDaGesto();
    } else if (s.selezione.isNotEmpty || s.selezionePiu) {
      _ctrl.deseleziona();
    } else {
      unawaited(_esci());
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    ref.listen(editorProvider.select((s) => s.avviso), (_, a) {
      if (a == null) return;
      final m = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
      m.showSnackBar(
        SnackBar(
          content: Text(testoAvviso(t, a)),
          duration: const Duration(seconds: 4),
          action: a.annullabile
              ? SnackBarAction(label: t.annulla, onPressed: _ctrl.annulla)
              : a.ripristinabile
              ? SnackBarAction(
                  label: t.ripristina,
                  onPressed: _ctrl.ripristinaScartata,
                )
              : null,
        ),
      );
    });
    // Controllo all'apertura (piano §9): le foto che non si trovano più si dicono subito, con la ricerca a un tocco
    ref.listen(mancantiProvider, (_, m) {
      final l = m.value;
      if (_avvisatoMancanti || l == null) return;
      _avvisatoMancanti = true;
      if (l.isEmpty) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(avvisaMancantiAllApertura(context, l.length));
      });
    });
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (esce, _) {
        if (!esce) _indietro();
      },
      child: Scaffold(
        backgroundColor: ColoriScrl.fondo,
        // La tastiera (strumento Testo → Modifica) non copre il pannello: la zona inferiore ci sale sopra e la pagina
        // si ridimensiona, come per ogni altro pannello
        resizeToAvoidBottomInset: false,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(MisureScrl.barraSuperiore),
          child: SafeArea(
            bottom: false,
            child: _BarraSuperiore(onIndietro: _esci),
          ),
        ),
        body: const Stack(
          children: [
            Positioned.fill(child: TelaEditor()),
            // Primo avvio: al massimo tre suggerimenti, una volta sola (non bloccano mai la tela)
            Positioned.fill(child: SuggerimentiEditor()),
            // Segno «N foto mancanti», in alto a sinistra
            Positioned(
              top: MisureScrl.spazioPiccolo,
              left: MisureScrl.spazio,
              child: BadgeMancanti(),
            ),
          ],
        ),
        // Il padding porta la zona inferiore sopra la tastiera; restando un bottomNavigationBar, gli avvisi
        // continuano a comparire sopra la barra
        bottomNavigationBar: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: const _ZonaInferiore(),
        ),
      ),
    );
  }
}

class _BarraSuperiore extends ConsumerWidget {
  const _BarraSuperiore({required this.onIndietro});

  final VoidCallback onIndietro;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final stato = ref.watch(editorProvider);
    final ctrl = ref.read(editorProvider.notifier);
    return Container(
      height: MisureScrl.barraSuperiore,
      color: ColoriScrl.barra,
      child: Row(
        children: [
          PulsanteIcona(
            icona: Icons.arrow_back_rounded,
            etichetta: t.indietro,
            onTap: onIndietro,
          ),
          // Annulla e Ripeti al centro, vicini: sono i comandi che si usano di continuo
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PulsanteIcona(
                  icona: Icons.undo_rounded,
                  etichetta: t.annulla,
                  onTap: stato.puoAnnullare ? ctrl.annulla : null,
                  // Pressione lunga su Annulla = Cronologia
                  onLongPress: () => unawaited(mostraCronologia(context)),
                ),
                PulsanteIcona(
                  icona: Icons.redo_rounded,
                  etichetta: t.ripeti,
                  onTap: stato.puoRipetere ? ctrl.ripeti : null,
                ),
              ],
            ),
          ),
          PulsanteIcona(
            icona: Icons.play_arrow_rounded,
            etichetta: t.anteprima,
            onTap: () => unawaited(apriAnteprima(context)),
          ),
          // Esporta è l'azione che chiude il lavoro: una pillola piena, l'unico elemento colorato della barra
          _PillolaEsporta(
            etichetta: t.esporta,
            // Schermo stretto o testo molto grande: solo l'icona, il nome resta per i lettori di schermo
            compatta:
                MediaQuery.sizeOf(context).width <
                340 +
                    160 * (MediaQuery.textScalerOf(context).scale(14) / 14 - 1),
            onTap: () => unawaited(apriEsportazione(context)),
          ),
          const SizedBox(width: MisureScrl.spazioPiccolo),
        ],
      ),
    );
  }
}

class _PillolaEsporta extends StatelessWidget {
  const _PillolaEsporta({
    required this.etichetta,
    required this.onTap,
    this.compatta = false,
  });

  final String etichetta;
  final VoidCallback onTap;
  final bool compatta;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: etichetta,
    excludeSemantics: true,
    child: Material(
      color: ColoriScrl.accentoPieno,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('barra-esporta'),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compatta ? 9 : 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.ios_share_rounded,
                  size: 18,
                  color: ColoriScrl.suAccento,
                ),
                if (!compatta) ...[
                  const SizedBox(width: 6),
                  Text(
                    etichetta,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: TestoScrl.normale,
                      fontWeight: TestoScrl.marcato,
                      color: ColoriScrl.suAccento,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Striscia pagine e, sotto, la barra inferiore o il pannello dello strumento aperto. Il passaggio si anima
/// e la pagina nella tela si ridimensiona insieme.
class _ZonaInferiore extends ConsumerStatefulWidget {
  const _ZonaInferiore();

  @override
  ConsumerState<_ZonaInferiore> createState() => _ZonaInferioreState();
}

class _ZonaInferioreState extends ConsumerState<_ZonaInferiore> {
  /// Categoria aperta della barra di selezione: resta mentre uno strumento è aperto, così ✓ e ✕ ci riportano.
  String? _categoria;

  @override
  Widget build(BuildContext context) {
    // Cambia il tipo di cosa è selezionata (o non c'è più niente): si riparte dalle categorie
    ref.listen(editorProvider.select(tipoSelezione), (prima, dopo) {
      if (prima != dopo && _categoria != null) {
        setState(() => _categoria = null);
      }
    });
    final strumento = ref.watch(editorProvider.select((s) => s.strumento));
    final haSelezione = ref.watch(
      editorProvider.select((s) => s.selezione.isNotEmpty || s.selezionePiu),
    );
    final Widget sotto = switch (strumento) {
      Strumento.libreria => const PannelloLibreria(key: ValueKey('libreria')),
      Strumento.disposizione => const PannelloDisposizione(
        key: ValueKey('disposizione'),
      ),
      Strumento.aggiungi => const PannelloAggiungi(key: ValueKey('aggiungi')),
      Strumento.inquadra => const PannelloInquadra(key: ValueKey('inquadra')),
      Strumento.filtri => const PannelloFiltri(key: ValueKey('filtri')),
      Strumento.regola => const PannelloRegola(key: ValueKey('regola')),
      Strumento.effetti => const PannelloEffetti(key: ValueKey('effetti')),
      Strumento.cornice => const PannelloCornice(key: ValueKey('cornice')),
      Strumento.ombra => const PannelloOmbra(key: ValueKey('ombra')),
      Strumento.ruota => const PannelloRuota(key: ValueKey('ruota')),
      Strumento.testoModifica => const PannelloModificaTesto(
        key: ValueKey('testoModifica'),
      ),
      Strumento.testoCarattere => const PannelloCarattere(
        key: ValueKey('testoCarattere'),
      ),
      Strumento.testoDimensione => const PannelloDimensione(
        key: ValueKey('testoDimensione'),
      ),
      Strumento.testoFormato => const PannelloFormato(
        key: ValueKey('testoFormato'),
      ),
      Strumento.testoColore => const PannelloColoreTesto(
        key: ValueKey('testoColore'),
      ),
      Strumento.testoContorno => const PannelloContornoTesto(
        key: ValueKey('testoContorno'),
      ),
      Strumento.testoEtichetta => const PannelloEtichetta(
        key: ValueKey('testoEtichetta'),
      ),
      Strumento.testoSpaziatura => const PannelloSpaziatura(
        key: ValueKey('testoSpaziatura'),
      ),
      Strumento.testoOpacita => const PannelloOpacitaTesto(
        key: ValueKey('testoOpacita'),
      ),
      Strumento.testoRuota => const PannelloRuotaTesto(
        key: ValueKey('testoRuota'),
      ),
      Strumento.formaNuova => const PannelloNuovaForma(
        key: ValueKey('formaNuova'),
      ),
      Strumento.formaTipo => const PannelloTipoForma(
        key: ValueKey('formaTipo'),
      ),
      Strumento.formaRiempimento => const PannelloRiempimento(
        key: ValueKey('formaRiempimento'),
      ),
      Strumento.formaBordo => const PannelloBordo(key: ValueKey('formaBordo')),
      Strumento.formaAngoli => const PannelloAngoliForma(
        key: ValueKey('formaAngoli'),
      ),
      Strumento.formaOpacita => const PannelloOpacitaForma(
        key: ValueKey('formaOpacita'),
      ),
      Strumento.formaRuota => const PannelloRuotaForma(
        key: ValueKey('formaRuota'),
      ),
      Strumento.pagine => PannelloPagine(
        key: const ValueKey('pagine'),
        onApriPanoramica: () => unawaited(apriPanoramica(context)),
        onEsporta: () => unawaited(
          apriEsportazione(context, pagina: ref.read(editorProvider).pagina),
        ),
      ),
      Strumento.stile => const PannelloStile(key: ValueKey('stile')),
      Strumento.sfondo => const PannelloSfondo(key: ValueKey('sfondo')),
      Strumento.numeriPagina => const PannelloNumeriPagina(
        key: ValueKey('numeriPagina'),
      ),
      Strumento.scorri => const PannelloScorri(key: ValueKey('scorri')),
      Strumento.disponi => const PannelloDisponi(key: ValueKey('disponi')),
      Strumento.allinea => const PannelloAllinea(key: ValueKey('allinea')),
      Strumento.distribuisci => const PannelloDistribuisci(
        key: ValueKey('distribuisci'),
      ),
      Strumento.videoTaglia => const PannelloTaglioVideo(
        key: ValueKey('videoTaglia'),
      ),
      Strumento.videoCopertina => const PannelloCopertinaVideo(
        key: ValueKey('videoCopertina'),
      ),
      Strumento.nessuno =>
        haSelezione
            ? BarraSelezione(
                key: const ValueKey('selezione'),
                categoria: _categoria,
                onCategoria: (c) => setState(() => _categoria = c),
              )
            : const _BarraInferiore(key: ValueKey('barra')),
    };
    final senzaMovimento = MediaQuery.disableAnimationsOf(context);
    return ColoredBox(
      color: ColoriScrl.barra,
      child: SafeArea(
        top: false,
        // Con un pannello aperto è lui a occuparsi dell'area dei gesti di sistema
        bottom: strumento == Strumento.nessuno,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _StrisciaPagine(),
            // Con «riduci animazioni» niente AnimatedSize: a durata zero in debug solleva un'asserzione di layout
            senzaMovimento
                ? sotto
                : AnimatedSize(
                    duration: MotoScrl.pannello,
                    curve: MotoScrl.curva,
                    alignment: Alignment.topCenter,
                    child: sotto,
                  ),
          ],
        ),
      ),
    );
  }
}

/// Puntini delle pagine: tocco = vai alla pagina; lucchetto sulle bloccate, trattino tra le pagine unite.
class _StrisciaPagine extends ConsumerWidget {
  const _StrisciaPagine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final stato = ref.watch(editorProvider);
    final c = stato.snapshot.canvas;
    final ctrl = ref.read(editorProvider.notifier);
    final k = stato.pagina;
    return SizedBox(
      height: MisureScrl.strisciaPagine,
      child: Row(
        children: [
          _Freccia(
            Icons.chevron_left_rounded,
            t.paginaPrecedente,
            k > 0 ? () => ctrl.vaiAPagina(k - 1) : null,
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < c.numFrames; i++) ...[
                      _Puntino(
                        attivo: i == k,
                        bloccata: c.pageLocked(i),
                        etichetta: t.vaiAllaPagina(i + 1),
                        onTap: () => ctrl.vaiAPagina(i),
                      ),
                      if (i < c.numFrames - 1 && c.joined(i))
                        Container(
                          width: 6,
                          height: 2,
                          color: ColoriScrl.testoSecondario,
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Text(
            '${k + 1}/${c.numFrames}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          _Freccia(
            Icons.chevron_right_rounded,
            t.paginaSuccessiva,
            k < c.numFrames - 1 ? () => ctrl.vaiAPagina(k + 1) : null,
          ),
          _Freccia(
            Icons.grid_view_rounded,
            t.panoramica,
            () => unawaited(apriPanoramica(context)),
          ),
        ],
      ),
    );
  }
}

class _Freccia extends StatelessWidget {
  const _Freccia(this.icona, this.etichetta, this.onTap);

  final IconData icona;
  final String etichetta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: etichetta,
    excludeSemantics: true,
    child: InkResponse(
      onTap: onTap,
      child: SizedBox(
        width: MisureScrl.tocco,
        height: MisureScrl.strisciaPagine,
        child: Icon(
          icona,
          size: 22,
          color: onTap == null ? ColoriScrl.testoSpento : ColoriScrl.testo,
        ),
      ),
    ),
  );
}

class _Puntino extends StatelessWidget {
  const _Puntino({
    required this.attivo,
    required this.bloccata,
    required this.etichetta,
    required this.onTap,
  });

  final bool attivo;
  final bool bloccata;
  final String etichetta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: attivo,
    label: etichetta,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 28,
        height: MisureScrl.strisciaPagine,
        child: Center(
          child: bloccata
              ? Icon(
                  Icons.lock_rounded,
                  size: 12,
                  color: attivo
                      ? ColoriScrl.accento
                      : ColoriScrl.testoSecondario,
                )
              : AnimatedContainer(
                  duration: MotoScrl.durata(context, MotoScrl.breve),
                  width: attivo ? 10 : 7,
                  height: attivo ? 10 : 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: attivo
                        ? ColoriScrl.accento
                        : ColoriScrl.testoSecondario,
                  ),
                ),
        ),
      ),
    ),
  );
}

/// Barra inferiore con niente selezionato: le 5 voci del piano (§4.3).
class _BarraInferiore extends ConsumerWidget {
  const _BarraInferiore({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final ctrl = ref.read(editorProvider.notifier);
    return SizedBox(
      height: MisureScrl.barraInferiore,
      child: Row(
        children: [
          Expanded(
            child: VoceBarra(
              icona: Icons.photo_library_outlined,
              etichetta: t.barraFoto,
              onTap: () => ctrl.apriStrumento(Strumento.libreria),
            ),
          ),
          Expanded(
            child: VoceBarra(
              icona: Icons.dashboard_outlined,
              etichetta: t.barraDisposizione,
              onTap: () => ctrl.apriStrumento(Strumento.disposizione),
            ),
          ),
          Expanded(
            child: VoceBarra(
              icona: Icons.add_circle_outline_rounded,
              etichetta: t.barraAggiungi,
              onTap: () => ctrl.apriStrumento(Strumento.aggiungi),
            ),
          ),
          Expanded(
            child: VoceBarra(
              icona: Icons.view_carousel_outlined,
              etichetta: t.barraPagine,
              onTap: () => ctrl.apriStrumento(Strumento.pagine),
            ),
          ),
          Expanded(
            child: VoceBarra(
              icona: Icons.palette_outlined,
              etichetta: t.barraStile,
              onTap: () => ctrl.apriStrumento(Strumento.stile),
            ),
          ),
        ],
      ),
    );
  }
}
