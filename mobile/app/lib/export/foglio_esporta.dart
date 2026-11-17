/// Foglio «Esporta» che sale dal basso (piano §4.1 e §11): scelta tra pagine separate (miniature), pagina corrente o
/// collage intero; formato (PNG / JPG), qualità JPG in 5 livelli, scala 1× / 2×; nome dei file (si salva nel progetto);
/// destinazione (Galleria, Condividi, Salva in File). Formato, qualità e scala si ricordano tra una sessione e l'altra.
/// Prima di partire avvisa di foto mancanti, tela vuota e collage troppo grande, poi apre l'avanzamento.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;
import 'package:scrl_video/scrl_video.dart' show RegoleVideo;

import '../editor/mancanti_ui.dart';
import '../editor/sessione.dart';
import '../editor/stato.dart';
import '../editor/vista_pagina.dart';
import '../editor/widget_comuni.dart';
import '../l10n/app_localizations.dart';
import '../media/cache_media.dart';
import '../render/risorse_pagina.dart';
import '../theme/tokens.dart';
import 'codifica.dart';
import 'consegna.dart';
import 'esporta_immagini.dart';
import 'pagina_esportazione.dart';
import 'preferenze.dart';
import 'video_pagina.dart';

enum ModoEsportazione { pagine, questa, collage }

enum _SceltaOriginali { annulla, ricollega, comunque }

/// Apre il foglio. Con [pagina] si parte da «Questa pagina» su quella pagina (azione «Esporta questa»); senza, dalle
/// pagine separate, tutte scelte. Sta fuori dal `ProviderScope` dell'editor: gli si passa lo stesso contenitore.
Future<void> apriEsportazione(BuildContext context, {int? pagina}) {
  final contenitore = ProviderScope.containerOf(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: ColoriScrl.pannello,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(MisureScrl.angoloPannello),
      ),
    ),
    builder: (_) => UncontrolledProviderScope(
      container: contenitore,
      child: FoglioEsporta(pagina: pagina),
    ),
  );
}

/// Quante foto (o video) sulle pagine [pagine] non si trovano più, né come originale né come anteprima salvata.
/// Con [pagine] vuoto si contano quelle di tutta la tela (`_missing_on_canvas`).
Future<int> contaFotoMancanti(
  SessioneEditor s,
  Snapshot snap,
  List<int> pagine,
) async {
  final foto = pagine.isEmpty
      ? snap.items
      : {for (final k in pagine) ...RisorsePagina.fotoDellaPagina(snap, k)}
            .toList();
  var n = 0;
  for (final p in foto) {
    final ant = await s.cache.carica(
      sorgenteDi(p, s.cartella.path),
      Dettaglio.anteprima,
    );
    if (ant == null) n++;
  }
  return n;
}

class FoglioEsporta extends ConsumerStatefulWidget {
  const FoglioEsporta({super.key, this.pagina});

  final int? pagina;

  @override
  ConsumerState<FoglioEsporta> createState() => _FoglioEsportaState();
}

class _FoglioEsportaState extends ConsumerState<FoglioEsporta> {
  late ModoEsportazione _modo;
  late Set<int> _scelte;
  late final int _pagina;
  late final Snapshot _documento;
  late final TextEditingController _nome;
  OpzioniEsportazione _opz = const OpzioniEsportazione();
  bool _occupato = false;

  /// Il telefono sa scrivere MP4 (null finché non si sa): decide la nota sui video.
  bool? _mp4;

  SessioneEditor get _s => ref.read(sessioneProvider);

  @override
  void initState() {
    super.initState();
    final stato = ref.read(editorProvider);
    _documento = stato.cronologia.current;
    final n = _documento.canvas.numFrames;
    _pagina = (widget.pagina ?? stato.pagina).clamp(0, n - 1);
    _modo = widget.pagina != null
        ? ModoEsportazione.questa
        : ModoEsportazione.pagine;
    _scelte = {for (var i = 0; i < n; i++) i};
    _nome = TextEditingController(text: _documento.canvas.exportName);
    unawaited(_leggiPreferenze());
    unawaited(_leggiMp4());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Come `_begin_export`: la riproduzione sulla tela si ferma (il lettore dei video serve all'esportazione)
      ref.read(editorProvider.notifier).fermaTuttiVideo();
      // Le miniature: foto a bassa risoluzione, come nella Panoramica
      for (var i = 0; i < n; i++) {
        unawaited(_s.risorse.prepara(_documento, i, pixelPerUnita: 0.2));
      }
    });
  }

  Future<void> _leggiMp4() async {
    final d = await ref.read(videoDisponibileProvider)();
    if (mounted) setState(() => _mp4 = d);
  }

  Future<void> _leggiPreferenze() async {
    final o = await ref.read(preferenzeProvider).esportazione();
    if (mounted) setState(() => _opz = o);
  }

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  List<int> get _pagineDaEsportare => switch (_modo) {
    ModoEsportazione.pagine => (_scelte.toList()..sort()),
    ModoEsportazione.questa => [_pagina],
    ModoEsportazione.collage => const [],
  };

  void _imposta(OpzioniEsportazione o) {
    setState(() => _opz = o);
    unawaited(ref.read(preferenzeProvider).salvaEsportazione(o));
  }

  Future<bool> _conferma(String titolo, String testo, String azione) async {
    final t = Testi.of(context);
    final r = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(titolo),
        content: Text(testo),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(t.annulla),
          ),
          FilledButton(
            key: const ValueKey('esporta-conferma'),
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(azione),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  /// Il collage intero non entra nella memoria del telefono: si propone 1× o le pagine separate.
  /// Vero se si può proseguire (eventualmente con la scala cambiata).
  Future<bool> _collageGrande() async {
    final t = Testi.of(context);
    final c = _documento.canvas;
    final m2 = MisureUscita(c, _opz.scala);
    if (m2.collageEntra) return true;
    final m1 = MisureUscita(c, 1);
    final puoUsare1x = _opz.scala > 1 && m1.collageEntra;
    final scelta = await showDialog<_RimedioCollage>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(t.espCollageGrandeTitolo),
        content: Text(
          puoUsare1x
              ? t.espCollageGrande(m2.collageW, m2.collageH)
              : t.espCollageGrande1x(m1.collageW, m1.collageH),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(),
            child: Text(t.annulla),
          ),
          TextButton(
            key: const ValueKey('esporta-usa-pagine'),
            onPressed: () => Navigator.of(d).pop(_RimedioCollage.pagine),
            child: Text(t.espUsaPagine),
          ),
          if (puoUsare1x)
            FilledButton(
              key: const ValueKey('esporta-usa-1x'),
              onPressed: () => Navigator.of(d).pop(_RimedioCollage.unoPerUno),
              child: Text(t.espUsa1x),
            ),
        ],
      ),
    );
    if (!mounted) return false;
    switch (scelta) {
      case _RimedioCollage.unoPerUno:
        _imposta(_opz.copia(scala: 1));
        return true;
      case _RimedioCollage.pagine:
        // Passa alle pagine separate, tutte scelte: l'utente conferma con la destinazione
        setState(() {
          _modo = ModoEsportazione.pagine;
          _scelte = {for (var i = 0; i < c.numFrames; i++) i};
        });
        return false;
      case null:
        return false;
    }
  }

  /// Foto mancanti e tela vuota (`_warn_if_empty`). Vero se si può proseguire.
  Future<bool> _avvisi() async {
    final t = Testi.of(context);
    final pagine = _pagineDaEsportare;
    final mancanti = await contaFotoMancanti(_s, _documento, pagine);
    if (!mounted) return false;
    if (mancanti > 0 &&
        !await _conferma(
          t.espMancantiTitolo,
          t.espMancanti(mancanti),
          t.espEsportaComunque,
        )) {
      return false;
    }
    if (!mounted) return false;
    if (!await _avvisoOriginali(pagine, mancanti)) return false;
    if (!mounted) return false;
    if (_documento.items.isEmpty) {
      return _conferma(
        t.espTelaVuotaTitolo,
        t.espTelaVuota,
        t.espEsportaComunque,
      );
    }
    return true;
  }

  /// Foto con l'originale mancante ma l'anteprima salvata: escono alla qualità dell'anteprima (piano §9). Si avvisa e
  /// si propone il ricollegamento. [senzaAnteprima] sono quelle già segnalate (nemmeno l'anteprima).
  Future<bool> _avvisoOriginali(List<int> pagine, int senzaAnteprima) async {
    final t = Testi.of(context);
    final elenco = await ref.read(mancantiProvider.future);
    if (!mounted) return false;
    final foto = pagine.isEmpty
        ? _documento.items
        : {
            for (final k in pagine)
              ...RisorsePagina.fotoDellaPagina(_documento, k),
          }.toList();
    final chiavi = {for (final m in elenco) m.chiave};
    final conAnteprima =
        foto.where((p) => chiavi.contains(chiaveMedia(p))).length -
        senzaAnteprima;
    if (conAnteprima <= 0) return true;
    final scelta = await showDialog<_SceltaOriginali>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(t.espMancantiTitolo),
        content: Text(t.espOriginaliMancanti(conAnteprima)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(_SceltaOriginali.annulla),
            child: Text(t.annulla),
          ),
          TextButton(
            key: const ValueKey('esporta-ricollega'),
            onPressed: () => Navigator.of(d).pop(_SceltaOriginali.ricollega),
            child: Text(t.espRicollega),
          ),
          FilledButton(
            key: const ValueKey('esporta-conferma'),
            onPressed: () => Navigator.of(d).pop(_SceltaOriginali.comunque),
            child: Text(t.espEsportaComunque),
          ),
        ],
      ),
    );
    if (!mounted) return false;
    if (scelta == _SceltaOriginali.ricollega) {
      await apriMancanti(context);
      return false; // Si riesporta dopo il ricollegamento
    }
    return scelta == _SceltaOriginali.comunque;
  }

  Future<void> _esporta(Destinazione destinazione) async {
    if (_occupato) return;
    if (_modo != ModoEsportazione.collage && _pagineDaEsportare.isEmpty) return;
    setState(() => _occupato = true);
    try {
      if (_modo == ModoEsportazione.collage && !await _collageGrande()) return;
      if (!mounted || !await _avvisi() || !mounted) return;
      // Dal punto in cui si parte non si usa più `ref` dopo l'`await` del foglio: tutto si prende qui
      final ctrl = ref.read(editorProvider.notifier);
      final sessione = _s;
      final testi = testiDisegno(context);
      final navigator = Navigator.of(context);
      final consegna = ref.read(consegnaProvider);
      final cartellaTemp = await ref.read(cartellaTemporaneaProvider)();
      if (!mounted) return;
      // Il nome dei file vale per il progetto: si salva con lui, come `_set_export_name`
      ctrl.impostaNomeEsportazione(_nome.text);
      unawaited(ref.read(preferenzeProvider).salvaEsportazione(_opz));
      final lavoro = LavoroEsportazione(
        richiesta: RichiestaEsportazione(
          snapshot: _documento,
          pagine: _pagineDaEsportare,
          collage: _modo == ModoEsportazione.collage,
          opzioni: _opz,
          nome: _nome.text,
          destinazione: destinazione,
        ),
        cache: sessione.cache,
        cartellaProgetto: sessione.cartella.path,
        testi: testi,
        cartellaTemporanea: cartellaTemp,
        consegna: consegna,
        esportaVideo: ref.read(esportaPaginaVideoProvider),
        videoDisponibile: ref.read(videoDisponibileProvider),
      );
      navigator.pop();
      await apriAvanzamento(navigator, lavoro);
    } finally {
      if (mounted) setState(() => _occupato = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final c = _documento.canvas;
    final m = MisureUscita(c, _opz.scala);
    final pagine = _pagineDaEsportare;
    final jpg = _opz.formato.isJpg;
    final ext = estensioneImmagine(jpg);
    final collage = _modo == ModoEsportazione.collage;
    final primo = collage
        ? nomeFileCollage(_nome.text, c, _opz.scala, ext)
        : nomeFilePagina(_nome.text, pagine.isEmpty ? 0 : pagine.first, ext);
    final conVideo = [
      for (final k in collage ? List.generate(c.numFrames, (i) => i) : pagine)
        ...videoDellaPagina(_documento, k),
    ].isNotEmpty;
    final mp4 = RegoleVideo.misuraUscita(
      c.frameW.toDouble(),
      c.frameH.toDouble(),
    );
    final puoEsportare = collage || pagine.isNotEmpty;
    final stile = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: MisureScrl.tocco,
              child: Row(
                children: [
                  const SizedBox(width: MisureScrl.spazio),
                  Expanded(child: Text(t.esporta, style: stile.titleMedium)),
                  if (_modo == ModoEsportazione.pagine) ...[
                    // Center: senza, la pillola si allunga fino all'altezza della riga
                    Center(
                      child: ChipParametro(
                        key: const ValueKey('esporta-tutte'),
                        etichetta: t.espTutte,
                        attivo: _scelte.length == c.numFrames,
                        onTap: () => setState(
                          () => _scelte = {
                            for (var i = 0; i < c.numFrames; i++) i,
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: MisureScrl.spazioPiccolo),
                    Center(
                      child: ChipParametro(
                        key: const ValueKey('esporta-nessuna'),
                        etichetta: t.espNessuna,
                        attivo: _scelte.isEmpty,
                        onTap: () => setState(() => _scelte = {}),
                      ),
                    ),
                  ],
                  PulsanteIcona(
                    icona: Icons.close_rounded,
                    etichetta: t.chiudi,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            _riga([
              _modoChip(t.espPagineSeparate, ModoEsportazione.pagine),
              _modoChip(t.espQuestaPagina, ModoEsportazione.questa),
              _modoChip(t.espCollage, ModoEsportazione.collage),
            ]),
            const SizedBox(height: MisureScrl.spazioPiccolo),
            if (_modo != ModoEsportazione.collage)
              _miniature(c, t)
            else
              const SizedBox.shrink(),
            const SizedBox(height: MisureScrl.spazioPiccolo),
            _riga([
              _etichetta(t.espFormato),
              _chip(
                'esporta-png',
                t.espFormatoPng,
                !jpg,
                () => _imposta(_opz.copia(formato: FormatoImmagine.png)),
              ),
              _chip(
                'esporta-jpg',
                t.espFormatoJpg,
                jpg,
                () => _imposta(_opz.copia(formato: FormatoImmagine.jpg)),
              ),
            ]),
            // La qualità conta solo per il JPG (il PNG non ha perdite)
            if (jpg)
              _riga([
                _etichetta(t.espQualita),
                for (final q in qualitaJpg)
                  _chip(
                    'esporta-q$q',
                    '$q',
                    _opz.qualita == q,
                    () => _imposta(_opz.copia(qualita: q)),
                  ),
              ]),
            _riga([
              _etichetta(t.espScala),
              for (final s in scaleEsportazione)
                _chip(
                  'esporta-x$s',
                  s == 1 ? t.espScala1 : t.espScala2,
                  _opz.scala == s,
                  () => _imposta(_opz.copia(scala: s)),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MisureScrl.spazio,
                MisureScrl.spazioPiccolo,
                MisureScrl.spazio,
                0,
              ),
              child: TextField(
                key: const ValueKey('esporta-nome'),
                controller: _nome,
                onChanged: (_) => setState(() {}),
                maxLength: 80,
                decoration: InputDecoration(
                  labelText: t.espNomeFile,
                  hintText: t.espNomeSuggerimento,
                  counterText: '',
                  isDense: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MisureScrl.spazio,
                MisureScrl.spazioPiccolo,
                MisureScrl.spazio,
                0,
              ),
              child: Text(
                [
                  if (!puoEsportare)
                    t.espNessunaPagina
                  else ...[
                    t.espEsempioNome(primo),
                    collage
                        ? t.espMisureCollage(m.collageW, m.collageH)
                        : t.espMisure(m.paginaW, m.paginaH),
                  ],
                ].join('  ·  '),
                key: const ValueKey('esporta-info'),
                style: stile.bodySmall,
              ),
            ),
            if (conVideo)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MisureScrl.spazio,
                  MisureScrl.spazioPiccolo,
                  MisureScrl.spazio,
                  0,
                ),
                child: Text(
                  collage
                      ? t.espVideoCollage
                      : _mp4 == false
                      ? t.espVideoNonDisponibile
                      : t.espVideoMp4(mp4.w, mp4.h, RegoleVideo.fps),
                  key: const ValueKey('esporta-nota-video'),
                  style: stile.bodySmall,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MisureScrl.spazio,
                MisureScrl.spazio,
                MisureScrl.spazio,
                MisureScrl.spazio,
              ),
              // Galleria (la scelta principale) a tutta larghezza; sotto le altre due, affiancate: così i nomi
              // non vanno a capo nemmeno con il testo ingrandito
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('esporta-galleria'),
                    onPressed: puoEsportare && !_occupato
                        ? () => unawaited(_esporta(Destinazione.galleria))
                        : null,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      t.espGalleria,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: MisureScrl.spazioPiccolo),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const ValueKey('esporta-condividi'),
                          onPressed: puoEsportare && !_occupato
                              ? () =>
                                    unawaited(_esporta(Destinazione.condividi))
                              : null,
                          icon: const Icon(Icons.ios_share_rounded),
                          label: Text(
                            t.espCondividi,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: MisureScrl.spazioPiccolo),
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const ValueKey('esporta-file'),
                          onPressed: puoEsportare && !_occupato
                              ? () => unawaited(_esporta(Destinazione.file))
                              : null,
                          icon: const Icon(Icons.folder_open_rounded),
                          label: Text(
                            t.espSalvaInFile,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Riga che scorre solo in orizzontale (come i parametri degli strumenti).
  Widget _riga(List<Widget> figli) => SizedBox(
    height: 44,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
      children: figli,
    ),
  );

  Widget _etichetta(String testo) => Padding(
    padding: const EdgeInsets.only(right: MisureScrl.spazioPiccolo),
    child: Center(
      child: Text(testo, style: Theme.of(context).textTheme.bodySmall),
    ),
  );

  Widget _chip(String chiave, String testo, bool attivo, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.only(right: MisureScrl.spazioPiccolo),
        child: Center(
          child: ChipParametro(
            key: ValueKey(chiave),
            etichetta: testo,
            attivo: attivo,
            onTap: onTap,
          ),
        ),
      );

  Widget _modoChip(String testo, ModoEsportazione modo) => _chip(
    'esporta-modo-${modo.name}',
    testo,
    _modo == modo,
    () => setState(() => _modo = modo),
  );

  /// Miniature delle pagine: nelle pagine separate si toccano per sceglierle; in «Questa pagina» se ne vede una.
  Widget _miniature(CanvasState c, Testi t) {
    const altezza = 96.0;
    final larghezza = (altezza * c.frameW / c.frameH).clamp(44.0, 140.0);
    final elenco = _modo == ModoEsportazione.questa
        ? [_pagina]
        : List.generate(c.numFrames, (i) => i);
    return SizedBox(
      height: altezza + 8,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
        children: [
          for (final k in elenco)
            Padding(
              padding: const EdgeInsets.only(right: MisureScrl.spazioPiccolo),
              child: _Miniatura(
                key: ValueKey('esporta-pagina-$k'),
                pagina: k,
                larghezza: larghezza,
                altezza: altezza,
                snapshot: _documento,
                risorse: _s.risorse,
                scelta: _modo == ModoEsportazione.questa || _scelte.contains(k),
                onTap: _modo == ModoEsportazione.questa
                    ? null
                    : () => setState(() {
                        if (!_scelte.remove(k)) _scelte.add(k);
                      }),
              ),
            ),
        ],
      ),
    );
  }
}

enum _RimedioCollage { unoPerUno, pagine }

/// Una pagina in miniatura con il suo numero e il segno di scelta.
class _Miniatura extends StatelessWidget {
  const _Miniatura({
    super.key,
    required this.pagina,
    required this.larghezza,
    required this.altezza,
    required this.snapshot,
    required this.risorse,
    required this.scelta,
    required this.onTap,
  });

  final int pagina;
  final double larghezza;
  final double altezza;
  final Snapshot snapshot;
  final RisorsePagina risorse;
  final bool scelta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    return Semantics(
      button: onTap != null,
      selected: scelta,
      label: t.panoramicaPagina(pagina + 1),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: larghezza,
          height: altezza,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: scelta ? ColoriScrl.accento : ColoriScrl.bordo,
                      width: scelta ? 3 : 1,
                    ),
                  ),
                  child: ClipRect(
                    child: Opacity(
                      opacity: scelta ? 1 : 0.5,
                      child: AnimatedBuilder(
                        animation: risorse,
                        builder: (context, _) => RepaintBoundary(
                          child: CustomPaint(
                            size: Size(larghezza, altezza),
                            painter: PitturaMiniatura(
                              snapshot,
                              pagina,
                              risorse,
                              testiDisegno(context),
                              risorse.versione,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 4,
                bottom: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scelta ? ColoriScrl.accento : ColoriScrl.barra,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    child: Text(
                      '${pagina + 1}',
                      style: TextStyle(
                        fontSize: TestoScrl.piccolo,
                        fontWeight: TestoScrl.marcato,
                        color: scelta ? ColoriScrl.suAccento : ColoriScrl.testo,
                      ),
                    ),
                  ),
                ),
              ),
              if (scelta)
                const Positioned(
                  top: 4,
                  right: 4,
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: ColoriScrl.accento,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
