/// Panoramica (piano §4.6, `⊞`): tutte le pagine in griglia, disegnate dallo stesso modulo della tela. Tocco = vai alla
/// pagina; trascinamento = riordina (un gruppo «a cavallo» si sposta insieme, come `_move_page`); pressione lunga =
/// azioni della pagina. Sostituisce «Pagine a scacchiera» e «Riordina le pagine…» del desktop.
///
/// Il trascinamento parte da un movimento orizzontale; uno verticale fa scorrere la griglia (con tante pagine serve).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import '../l10n/app_localizations.dart';
import '../render/disegno.dart';
import '../render/risorse_pagina.dart';
import '../theme/tokens.dart';
import 'pannello_pagine.dart';
import 'sessione.dart';
import 'stato.dart';
import 'vista_pagina.dart';
import 'widget_comuni.dart';

/// Apre la Panoramica a schermo intero. Sta fuori dal `ProviderScope` dell'editor: gli si passa lo stesso contenitore.
Future<void> apriPanoramica(BuildContext context) {
  final contenitore = ProviderScope.containerOf(context);
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => UncontrolledProviderScope(
        container: contenitore,
        child: const PaginaPanoramica(),
      ),
    ),
  );
}

/// Colonne della griglia.
const int _colonne = 3;
const double _spazio = 12;

class PaginaPanoramica extends ConsumerStatefulWidget {
  const PaginaPanoramica({super.key});

  @override
  ConsumerState<PaginaPanoramica> createState() => _PaginaPanoramicaState();
}

class _PaginaPanoramicaState extends ConsumerState<PaginaPanoramica> {
  int? _inTrascinamento;

  SessioneEditor get _s => ref.read(sessioneProvider);
  ControlloEditor get _ctrl => ref.read(editorProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepara());
  }

  /// Prepara le foto di tutte le pagine (a bassa risoluzione: sono miniature).
  void _prepara() {
    if (!mounted) return;
    final s = ref.read(editorProvider).snapshot;
    for (var i = 0; i < s.canvas.numFrames; i++) {
      unawaited(_s.risorse.prepara(s, i, pixelPerUnita: 0.2));
    }
  }

  /// Il gruppo [da] va alla posizione del gruppo [a]: i gruppi «a cavallo» restano uniti.
  void _sposta(int da, int a) {
    if (da == a) return;
    final gruppi = ref.read(editorProvider).snapshot.canvas.seamGroups();
    final mosso = gruppi.removeAt(da);
    gruppi.insert(a, mosso);
    _ctrl.riordinaPagine([
      for (final (x, y) in gruppi)
        for (var p = x; p <= y; p++) p,
    ]);
  }

  Future<void> _azioni(int k) async {
    final t = Testi.of(context);
    final ctrl = _ctrl;
    final contenitore = ProviderScope.containerOf(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ColoriScrl.pannello,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MisureScrl.angoloPannello),
        ),
      ),
      builder: (sheet) => UncontrolledProviderScope(
        container: contenitore,
        child: Consumer(
          builder: (context, ref, _) {
            final s = ref.watch(editorProvider.select((x) => x.snapshot));
            final azioni = azioniPagina(
              t,
              s,
              ctrl,
              k,
              onEsporta: ctrl.inArrivo,
            );
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(MisureScrl.spazio),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.etichettaPagina(k + 1),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: MisureScrl.spazioPiccolo),
                    Wrap(
                      runSpacing: MisureScrl.spazioPiccolo,
                      children: [
                        for (final a in azioni)
                          SizedBox(
                            height: MisureScrl.barraInferiore,
                            child: TesseraVoce(
                              key: ValueKey('panoramica-azione-${a.chiave}'),
                              icona: a.icona,
                              etichetta: a.etichetta,
                              spenta: a.spenta,
                              colore: a.pericolo ? ColoriScrl.pericolo : null,
                              onTap: () {
                                Navigator.of(sheet).pop();
                                a.onTap();
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final stato = ref.watch(editorProvider);
    final s = stato.snapshot;
    final c = s.canvas;
    ref.listen(editorProvider.select((x) => x.cronologia.current), (_, _) {
      _prepara();
    });
    final larghezza = MediaQuery.sizeOf(context).width - 2 * MisureScrl.spazio;
    // Un filo in meno, così le tessere di una riga ci stanno sempre (errori di arrotondamento)
    final lato = (larghezza - (_colonne - 1) * _spazio) / _colonne - 0.5;
    final gruppi = c.seamGroups();
    return Scaffold(
      backgroundColor: ColoriScrl.fondo,
      appBar: AppBar(
        backgroundColor: ColoriScrl.barra,
        title: Text(t.panoramica),
        leading: PulsanteIcona(
          icona: Icons.close_rounded,
          etichetta: t.chiudi,
          onTap: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MisureScrl.spazio,
              MisureScrl.spazioPiccolo,
              MisureScrl.spazio,
              0,
            ),
            child: Text(
              t.panoramicaAiuto,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(MisureScrl.spazio),
              child: Wrap(
                spacing: _spazio,
                runSpacing: _spazio,
                children: [
                  for (var g = 0; g < gruppi.length; g++)
                    _gruppo(context, g, gruppi[g], lato, s, stato.pagina),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gruppo(
    BuildContext context,
    int g,
    (int, int) pagine,
    double lato,
    Snapshot s,
    int corrente,
  ) {
    final n = pagine.$2 - pagine.$1 + 1;
    // Un gruppo di più di 3 pagine occupa tutta la larghezza e va a capo
    final colonne = n < _colonne ? n : _colonne;
    final larghezzaGruppo = colonne * lato + (colonne - 1) * _spazio;
    Widget corpo({bool trascinato = false}) => SizedBox(
      width: larghezzaGruppo,
      child: Wrap(
        spacing: _spazio,
        runSpacing: _spazio,
        children: [
          for (var k = pagine.$1; k <= pagine.$2; k++)
            _Tessera(
              key: ValueKey(trascinato ? 'trascinata-$k' : 'pagina-$k'),
              pagina: k,
              lato: lato,
              risorse: _s.risorse,
              snapshot: s,
              corrente: k == corrente,
              unitaAllaSuccessiva: k < pagine.$2,
              onTap: () {
                _ctrl.vaiAPagina(k);
                Navigator.of(context).pop();
              },
              onLungo: () => unawaited(_azioni(k)),
            ),
        ],
      ),
    );
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != g,
      onAcceptWithDetails: (d) => _sposta(d.data, g),
      builder: (context, candidati, _) => Draggable<int>(
        data: g,
        affinity: Axis.horizontal,
        onDragStarted: () => setState(() => _inTrascinamento = g),
        onDragEnd: (_) => setState(() => _inTrascinamento = null),
        feedback: Material(
          color: Colors.transparent,
          child: Opacity(opacity: 0.85, child: corpo(trascinato: true)),
        ),
        childWhenDragging: Opacity(opacity: 0.25, child: corpo()),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: candidati.isNotEmpty && _inTrascinamento != g
                ? const Border(
                    left: BorderSide(color: ColoriScrl.accento, width: 3),
                  )
                : null,
          ),
          child: corpo(),
        ),
      ),
    );
  }
}

/// Una pagina in miniatura, con il numero sotto, il lucchetto se è bloccata e un anello se è la corrente. Non legge
/// da Riverpod: la copia che si trascina vive nella sovrapposizione del Navigator, fuori dal `ProviderScope`.
class _Tessera extends StatelessWidget {
  const _Tessera({
    super.key,
    required this.pagina,
    required this.lato,
    required this.risorse,
    required this.snapshot,
    required this.corrente,
    required this.unitaAllaSuccessiva,
    required this.onTap,
    required this.onLungo,
  });

  final int pagina;
  final double lato;
  final RisorsePagina risorse;
  final Snapshot snapshot;
  final bool corrente;
  final bool unitaAllaSuccessiva;
  final VoidCallback onTap;
  final VoidCallback onLungo;

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final c = snapshot.canvas;
    final altezza = lato * c.frameH / c.frameW;
    return Semantics(
      button: true,
      selected: corrente,
      label: t.panoramicaPagina(pagina + 1),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLungo,
        child: SizedBox(
          width: lato,
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: lato,
                    height: altezza,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: corrente ? ColoriScrl.accento : ColoriScrl.bordo,
                        width: corrente ? 3 : 1,
                      ),
                    ),
                    child: ClipRect(
                      child: AnimatedBuilder(
                        animation: risorse,
                        builder: (context, _) => RepaintBoundary(
                          child: CustomPaint(
                            size: Size(lato, altezza),
                            painter: _PitturaMiniatura(
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
                  if (c.pageLocked(pagina))
                    const Positioned(
                      top: 4,
                      right: 4,
                      child: Icon(
                        Icons.lock_rounded,
                        size: 18,
                        color: ColoriScrl.accento,
                      ),
                    ),
                  if (unitaAllaSuccessiva)
                    const Positioned(
                      right: -12,
                      top: 0,
                      bottom: 0,
                      child: Icon(
                        Icons.link_rounded,
                        size: 16,
                        color: ColoriScrl.testoSecondario,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${pagina + 1}',
                style: TextStyle(
                  fontSize: TestoScrl.normale,
                  fontWeight: corrente ? TestoScrl.marcato : TestoScrl.regolare,
                  color: corrente ? ColoriScrl.accento : ColoriScrl.testo,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PitturaMiniatura extends CustomPainter {
  _PitturaMiniatura(
    this.s,
    this.pagina,
    this.risorse,
    this.testi,
    this.versione,
  );

  final Snapshot s;
  final int pagina;
  final RisorsePagina risorse;
  final TestiDisegno testi;
  final int versione;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    disegnaPagina(
      canvas,
      s,
      pagina,
      risorse,
      OpzioniDisegno(testi: testi, pulito: true),
      scala: size.width / s.canvas.frameW,
    );
  }

  @override
  bool shouldRepaint(_PitturaMiniatura old) =>
      old.s != s || old.pagina != pagina || old.versione != versione;
}
