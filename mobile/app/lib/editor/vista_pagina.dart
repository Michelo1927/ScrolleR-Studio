/// Una pagina del progetto sullo schermo, in sola lettura (Fase 2): stesso modulo di disegno dell'esportazione.
/// Si può ingrandire con due dita; oltre il 115% dei pixel dell'anteprima arriva la versione nitida.
library;

import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import '../l10n/app_localizations.dart';
import '../render/disegno.dart';
import '../render/risorse_pagina.dart';
import '../theme/tokens.dart';

/// Testi del disegno presi dai file `.arb`.
TestiDisegno testiDisegno(BuildContext context) {
  final t = Testi.of(context);
  return TestiDisegno(
    fotoMancante: t.fotoMancante,
    originaleMancante: t.originaleMancante,
    di: t.numeroPaginaDi,
  );
}

class VistaPagina extends StatefulWidget {
  const VistaPagina({
    super.key,
    required this.snapshot,
    required this.pagina,
    required this.risorse,
  });

  final Snapshot snapshot;
  final int pagina;
  final RisorsePagina risorse;

  @override
  State<VistaPagina> createState() => _VistaPaginaState();
}

class _VistaPaginaState extends State<VistaPagina> {
  final _trasformazione = TransformationController();
  double _adatta = 1.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prepara();
  }

  @override
  void didUpdateWidget(VistaPagina old) {
    super.didUpdateWidget(old);
    if (old.snapshot != widget.snapshot || old.pagina != widget.pagina) {
      _prepara();
    }
  }

  @override
  void dispose() {
    _trasformazione.dispose();
    super.dispose();
  }

  /// Pixel dello schermo per unità della tela: adattamento × zoom × densità.
  double get _pixelPerUnita =>
      _adatta *
      _trasformazione.value.getMaxScaleOnAxis() *
      MediaQuery.devicePixelRatioOf(context);

  void _prepara() {
    // Lavoro asincrono: il disegno si aggiorna da solo quando le immagini sono pronte
    widget.risorse.prepara(
      widget.snapshot,
      widget.pagina,
      pixelPerUnita: _pixelPerUnita,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.snapshot.canvas;
    final testi = testiDisegno(context);
    return LayoutBuilder(
      builder: (context, vincoli) {
        const spazio = MisureScrl.lemboPagina;
        final maxW = vincoli.maxWidth - 2 * spazio;
        final maxH = vincoli.maxHeight - 2 * spazio;
        _adatta = [
          maxW / c.frameW,
          maxH / c.frameH,
        ].reduce((a, b) => a < b ? a : b);
        final w = c.frameW * _adatta, h = c.frameH * _adatta;
        return InteractiveViewer(
          transformationController: _trasformazione,
          maxScale: 8,
          onInteractionEnd: (_) => _prepara(),
          child: Center(
            child: SizedBox(
              width: w,
              height: h,
              child: CustomPaint(
                painter: _PitturaPagina(
                  widget.snapshot,
                  widget.pagina,
                  widget.risorse,
                  testi,
                  _adatta,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PitturaPagina extends CustomPainter {
  _PitturaPagina(this.s, this.pagina, this.risorse, this.testi, this.scala)
    : super(repaint: risorse);

  final Snapshot s;
  final int pagina;
  final RisorsePagina risorse;
  final TestiDisegno testi;
  final double scala;

  @override
  void paint(Canvas canvas, Size size) {
    disegnaPagina(
      canvas,
      s,
      pagina,
      risorse,
      OpzioniDisegno(testi: testi),
      scala: scala,
    );
  }

  @override
  bool shouldRepaint(_PitturaPagina old) =>
      old.s != s ||
      old.pagina != pagina ||
      old.scala != scala ||
      old.risorse != risorse;
}

/// Schermata con le pagine di un progetto, una alla volta, scorrendo di lato.
class SchermataPagine extends StatefulWidget {
  const SchermataPagine({
    super.key,
    required this.titolo,
    required this.snapshot,
    required this.risorse,
    this.azioni = const [],
  });

  final String titolo;
  final Snapshot snapshot;
  final RisorsePagina risorse;
  final List<Widget> azioni;

  @override
  State<SchermataPagine> createState() => _SchermataPagineState();
}

class _SchermataPagineState extends State<SchermataPagine> {
  int _pagina = 0;

  @override
  void dispose() {
    widget.risorse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.snapshot.canvas.numFrames;
    return Scaffold(
      appBar: AppBar(title: Text(widget.titolo), actions: widget.azioni),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                itemCount: n,
                onPageChanged: (i) => setState(() => _pagina = i),
                itemBuilder: (context, i) => VistaPagina(
                  snapshot: widget.snapshot,
                  pagina: i,
                  risorse: widget.risorse,
                ),
              ),
            ),
            SizedBox(
              height: MisureScrl.strisciaPagine,
              child: Center(
                child: Text(
                  Testi.of(context).paginaDiTotale(_pagina + 1, n),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
