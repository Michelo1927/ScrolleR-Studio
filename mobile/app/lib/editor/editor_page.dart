/// Schermata dell'editor (piano §4.1): barra superiore, tela a pagina singola, striscia pagine e barra inferiore.
/// Gli strumenti salgono dal basso e la pagina si rimpicciolisce per restare sempre visibile (§3.4).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import '../export/foglio_esporta.dart';
import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'menu_pressione_lunga.dart';
import 'pagina_anteprima.dart';
import 'pagina_panoramica.dart';
import 'pagina_ritaglio.dart';
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

  Future<void> _esci() async {
    await _ctrl.salvaOra(attendiMiniatura: true);
    if (mounted) Navigator.of(context).pop();
  }

  /// Gesto «indietro» di sistema: chiude lo strumento (scartando), poi toglie la selezione, poi esce.
  void _indietro() {
    final s = ref.read(editorProvider);
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
        body: const TelaEditor(),
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
          const Spacer(),
          PulsanteIcona(
            icona: Icons.play_arrow_rounded,
            etichetta: t.anteprima,
            onTap: () => unawaited(apriAnteprima(context)),
          ),
          PulsanteIcona(
            icona: Icons.ios_share_rounded,
            etichetta: t.esporta,
            onTap: () => unawaited(apriEsportazione(context)),
          ),
        ],
      ),
    );
  }
}

/// Striscia pagine e, sotto, la barra inferiore o il pannello dello strumento aperto. Il passaggio si anima
/// e la pagina nella tela si ridimensiona insieme.
class _ZonaInferiore extends ConsumerWidget {
  const _ZonaInferiore();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            ? const _BarraSelezione(key: ValueKey('selezione'))
            : const _BarraInferiore(key: ValueKey('barra')),
    };
    final durata = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : MotoScrl.pannello;
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
            AnimatedSize(
              duration: durata,
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
                  duration: MotoScrl.breve,
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

/// Con un elemento selezionato la barra diventa una striscia di strumenti, con ✕ a sinistra per deselezionare.
/// Foto: Ritaglia · Inquadra · Filtri · Regola · Effetti · Cornice · Ombra · Ruota · Libera · Copia stile ·
/// Incolla stile · Duplica · Elimina (un video non ha Filtri, Regola ed Effetti, e ha in testa Riproduci · Taglia ·
/// Copertina · Audio).
/// Testo: Modifica · Carattere · Dimensione · Formato · Colore · Contorno · Ombra · Etichetta · Spaziatura · Opacità ·
/// Ruota · Duplica · Elimina. Forma: Tipo · Riempimento · Bordo · Angoli · Opacità · Ruota · Duplica · Elimina
/// (le linee non hanno Riempimento né Angoli, il rettangolo ha gli Angoli, gli altri tipi no).
class _BarraSelezione extends ConsumerWidget {
  const _BarraSelezione({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final ctrl = ref.read(editorProvider.notifier);
    final stato = ref.watch(editorProvider);
    final sel = stato.elementiSelezionati;
    final foto = sel.whereType<PhotoItem>().toList();
    final tutteLibere = foto.isNotEmpty && foto.every((p) => p.free);
    final conColori = foto.any((p) => !p.isVideo);
    final conVideo = foto.any((p) => p.isVideo);
    final videoGira =
        conVideo &&
        foto.any((p) => p.isVideo && stato.videoInRiproduzione.contains(p.uid));
    final testi = sel.whereType<TextItem>().toList();
    final forme = sel.whereType<ShapeItem>().toList();
    // Gli strumenti di foto, testi e forme valgono quando la selezione è fatta di un solo tipo; con tipi diversi restano
    // i comandi per più elementi (Allinea, Distribuisci, Raggruppa, Blocca…)
    final soloFoto = testi.isEmpty && forme.isEmpty && foto.isNotEmpty;
    final soloTesti = foto.isEmpty && forme.isEmpty && testi.isNotEmpty;
    final soloForme = foto.isEmpty && testi.isEmpty && forme.isNotEmpty;
    final multi = sel.length > 1;
    final inGruppi = selezioneHaGruppi(stato.snapshot, stato.selezione);
    final unGruppo = selezioneEUnGruppo(stato.snapshot, stato.selezione);
    final bloccati = sel.isNotEmpty && sel.every((e) => e.locked);
    final tutteLinee = soloForme && forme.every((f) => f.isLine);
    final conAngoli = soloForme && forme.any((f) => f.kind == 'rect');
    void apri(Strumento s) => ctrl.apriStrumento(s);
    return SizedBox(
      height: MisureScrl.barraInferiore,
      child: Row(
        children: [
          PulsanteIcona(
            icona: Icons.close_rounded,
            etichetta: t.deseleziona,
            onTap: ctrl.deseleziona,
          ),
          if (sel.isEmpty)
            Expanded(
              child: Text(
                t.selezionaPiuAiuto,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  if (soloFoto && conVideo) ...[
                    VoceBarra(
                      key: const ValueKey('voce-riproduci'),
                      icona: videoGira
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      etichetta: videoGira ? t.videoPausa : t.videoRiproduci,
                      attiva: videoGira,
                      onTap: ctrl.alternaRiproduzione,
                    ),
                    VoceBarra(
                      key: const ValueKey('voce-taglia'),
                      icona: Icons.content_cut_rounded,
                      etichetta: t.strTaglia,
                      onTap: () => apri(Strumento.videoTaglia),
                    ),
                    VoceBarra(
                      key: const ValueKey('voce-copertina'),
                      icona: Icons.image_outlined,
                      etichetta: t.strCopertina,
                      onTap: () => apri(Strumento.videoCopertina),
                    ),
                    const _VoceAudio(key: ValueKey('voce-audio')),
                  ],
                  if (soloFoto) ...[
                    VoceBarra(
                      icona: Icons.crop_rounded,
                      etichetta: t.strRitaglia,
                      onTap: () => _ritaglia(context, ref),
                    ),
                    VoceBarra(
                      icona: Icons.center_focus_strong_outlined,
                      etichetta: t.strInquadra,
                      onTap: () => ctrl.apriStrumento(Strumento.inquadra),
                    ),
                    if (conColori) ...[
                      VoceBarra(
                        icona: Icons.auto_awesome_outlined,
                        etichetta: t.strFiltri,
                        onTap: () => ctrl.apriStrumento(Strumento.filtri),
                      ),
                      VoceBarra(
                        icona: Icons.tune_rounded,
                        etichetta: t.strRegola,
                        onTap: () => ctrl.apriStrumento(Strumento.regola),
                      ),
                      VoceBarra(
                        icona: Icons.auto_fix_high_rounded,
                        etichetta: t.strEffetti,
                        onTap: () => ctrl.apriStrumento(Strumento.effetti),
                      ),
                    ],
                    VoceBarra(
                      icona: Icons.rounded_corner_rounded,
                      etichetta: t.strCornice,
                      onTap: () => ctrl.apriStrumento(Strumento.cornice),
                    ),
                    VoceBarra(
                      icona: Icons.blur_on_rounded,
                      etichetta: t.strOmbra,
                      onTap: () => ctrl.apriStrumento(Strumento.ombra),
                    ),
                    VoceBarra(
                      icona: Icons.rotate_right_rounded,
                      etichetta: t.strRuota,
                      onTap: () => ctrl.apriStrumento(Strumento.ruota),
                    ),
                    VoceBarra(
                      icona: Icons.layers_outlined,
                      etichetta: t.strDisponi,
                      onTap: () => ctrl.apriStrumento(Strumento.disponi),
                    ),
                    VoceBarra(
                      icona: tutteLibere
                          ? Icons.grid_view_rounded
                          : Icons.open_with_rounded,
                      etichetta: tutteLibere ? t.inDisposizione : t.libera,
                      onTap: ctrl.liberaSelezione,
                    ),
                    VoceBarra(
                      icona: Icons.drive_file_move_outlined,
                      etichetta: t.menuSpostaInPagina,
                      onTap: () => unawaited(
                        mostraMenuElemento(context, soloPagina: true),
                      ),
                    ),
                    VoceBarra(
                      icona: Icons.colorize_rounded,
                      etichetta: t.strCopiaStile,
                      onTap: ctrl.copiaStile,
                    ),
                    VoceBarra(
                      icona: Icons.format_paint_rounded,
                      etichetta: t.strIncollaStile,
                      onTap: ctrl.incollaStileCopiato,
                      spenta: stato.stileCopiato == null,
                    ),
                  ],
                  if (soloTesti) ...[
                    VoceBarra(
                      icona: Icons.edit_outlined,
                      etichetta: t.strModifica,
                      onTap: () => apri(Strumento.testoModifica),
                    ),
                    VoceBarra(
                      icona: Icons.font_download_outlined,
                      etichetta: t.strCarattere,
                      onTap: () => apri(Strumento.testoCarattere),
                    ),
                    VoceBarra(
                      icona: Icons.format_size_rounded,
                      etichetta: t.strDimensione,
                      onTap: () => apri(Strumento.testoDimensione),
                    ),
                    VoceBarra(
                      icona: Icons.format_bold_rounded,
                      etichetta: t.strFormato,
                      onTap: () => apri(Strumento.testoFormato),
                    ),
                    VoceBarra(
                      icona: Icons.format_color_text_rounded,
                      etichetta: t.parColore,
                      onTap: () => apri(Strumento.testoColore),
                    ),
                    VoceBarra(
                      icona: Icons.border_color_outlined,
                      etichetta: t.strContorno,
                      onTap: () => apri(Strumento.testoContorno),
                    ),
                    VoceBarra(
                      icona: Icons.blur_on_rounded,
                      etichetta: t.strOmbra,
                      attiva: testi.first.shadow,
                      onTap: ctrl.alternaOmbraTesto,
                    ),
                    VoceBarra(
                      icona: Icons.label_outline_rounded,
                      etichetta: t.strEtichetta,
                      attiva: testi.first.box,
                      onTap: () => apri(Strumento.testoEtichetta),
                    ),
                    VoceBarra(
                      icona: Icons.format_line_spacing_rounded,
                      etichetta: t.strSpaziatura,
                      onTap: () => apri(Strumento.testoSpaziatura),
                    ),
                    VoceBarra(
                      icona: Icons.opacity_rounded,
                      etichetta: t.parOpacita,
                      onTap: () => apri(Strumento.testoOpacita),
                    ),
                    VoceBarra(
                      icona: Icons.rotate_right_rounded,
                      etichetta: t.strRuota,
                      onTap: () => apri(Strumento.testoRuota),
                    ),
                    VoceBarra(
                      icona: Icons.layers_outlined,
                      etichetta: t.strDisponi,
                      onTap: () => apri(Strumento.disponi),
                    ),
                  ],
                  if (soloForme) ...[
                    VoceBarra(
                      icona: Icons.category_outlined,
                      etichetta: t.strTipo,
                      onTap: () => apri(Strumento.formaTipo),
                    ),
                    if (!tutteLinee)
                      VoceBarra(
                        icona: Icons.format_color_fill_rounded,
                        etichetta: t.strRiempimento,
                        onTap: () => apri(Strumento.formaRiempimento),
                      ),
                    VoceBarra(
                      icona: Icons.line_weight_rounded,
                      etichetta: tutteLinee ? t.parLinea : t.parBordo,
                      onTap: () => apri(Strumento.formaBordo),
                    ),
                    if (conAngoli)
                      VoceBarra(
                        icona: Icons.rounded_corner_rounded,
                        etichetta: t.parAngoli,
                        onTap: () => apri(Strumento.formaAngoli),
                      ),
                    VoceBarra(
                      icona: Icons.opacity_rounded,
                      etichetta: t.parOpacita,
                      onTap: () => apri(Strumento.formaOpacita),
                    ),
                    VoceBarra(
                      icona: Icons.rotate_right_rounded,
                      etichetta: t.strRuota,
                      onTap: () => apri(Strumento.formaRuota),
                    ),
                    VoceBarra(
                      icona: Icons.layers_outlined,
                      etichetta: t.strDisponi,
                      onTap: () => apri(Strumento.disponi),
                    ),
                  ],
                  if (multi && !soloFoto && !soloTesti && !soloForme)
                    VoceBarra(
                      icona: Icons.layers_outlined,
                      etichetta: t.strDisponi,
                      onTap: () => apri(Strumento.disponi),
                    ),
                  VoceBarra(
                    icona: Icons.align_horizontal_left_rounded,
                    etichetta: t.strAllinea,
                    onTap: () => apri(Strumento.allinea),
                  ),
                  if (multi) ...[
                    VoceBarra(
                      icona: Icons.horizontal_distribute_rounded,
                      etichetta: t.strDistribuisci,
                      onTap: () => apri(Strumento.distribuisci),
                    ),
                    if (!unGruppo)
                      VoceBarra(
                        icona: Icons.workspaces_outline,
                        etichetta: t.strRaggruppa,
                        onTap: ctrl.raggruppaSelezione,
                      ),
                    if (inGruppi)
                      VoceBarra(
                        icona: Icons.workspaces_filled,
                        etichetta: t.strSepara,
                        onTap: ctrl.separaSelezione,
                      ),
                    if (foto.length == 2 && sel.length == 2)
                      VoceBarra(
                        icona: Icons.swap_horiz_rounded,
                        etichetta: t.strScambia,
                        onTap: ctrl.scambiaFoto,
                      ),
                    VoceBarra(
                      icona: bloccati
                          ? Icons.lock_open_rounded
                          : Icons.lock_outline,
                      etichetta: bloccati ? t.strSblocca : t.strBlocca,
                      attiva: bloccati,
                      onTap: ctrl.bloccaSelezione,
                    ),
                  ] else if (inGruppi)
                    VoceBarra(
                      icona: Icons.workspaces_filled,
                      etichetta: t.strSepara,
                      onTap: ctrl.separaSelezione,
                    ),
                  VoceBarra(
                    icona: Icons.copy_rounded,
                    etichetta: t.duplica,
                    onTap: ctrl.duplicaSelezione,
                  ),
                  VoceBarra(
                    icona: Icons.delete_outline_rounded,
                    etichetta: t.elimina,
                    onTap: ctrl.eliminaSelezione,
                    colore: ColoriScrl.pericolo,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Ritaglio a schermo intero: si apre una pagina nuova e, con ✓, il ritaglio entra in cronologia.
  Future<void> _ritaglia(BuildContext context, WidgetRef ref) async {
    final ctrl = ref.read(editorProvider.notifier);
    final s = ref.read(sessioneProvider);
    final foto = ctrl.fotoSelezionate;
    if (foto.isEmpty) return;
    final r = await Navigator.of(context).push<RisultatoRitaglio>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PaginaRitaglio(sessione: s, foto: foto.first),
      ),
    );
    if (r != null) {
      ctrl.applicaRitaglio(r.ritaglio, adattaRiquadro: r.adattaRiquadro);
    }
  }
}

/// «Audio» del video selezionato (`chk_video_audio`): acceso o spento nell'MP4 esportato, un tocco = un passo.
/// Un video senza traccia audio ha la voce spenta, e il tocco lo dice.
class _VoceAudio extends ConsumerWidget {
  const _VoceAudio({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final ctrl = ref.read(editorProvider.notifier);
    final risorse = ref.read(sessioneProvider).risorse;
    final video = ref.watch(
      editorProvider.select(
        (s) => s.elementiSelezionati
            .whereType<PhotoItem>()
            .where((p) => p.isVideo)
            .firstOrNull,
      ),
    );
    if (video == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: risorse,
      builder: (context, _) {
        final audio = risorse.infoVideo(video)?.audio ?? false;
        final acceso = audio && !video.muted;
        return VoceBarra(
          icona: acceso ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          etichetta: t.strAudio,
          attiva: acceso,
          spenta: !audio,
          onTap: audio
              ? ctrl.alternaAudioVideo
              : () => ctrl.messaggio(MessaggioEditor.videoSenzaAudio),
        );
      },
    );
  }
}
