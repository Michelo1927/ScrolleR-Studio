/// Anteprima del carosello (piano §4.6, `▶`): schermo intero, sfondo nero, si scorre di pagina in pagina come su
/// Instagram, senza guide né selezione (`scene.clean_render`). Le pagine sono disegnate dallo stesso modulo della tela e
/// dell'esportazione. I video della pagina in vista partono da soli, senza audio e a ripetizione, come sulla tela.
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import '../l10n/app_localizations.dart';
import '../media/riproduzione_video.dart';
import '../render/disegno.dart';
import '../render/risorse_pagina.dart';
import '../theme/tokens.dart';
import 'sessione.dart';
import 'stato.dart';
import 'vista_pagina.dart';
import 'widget_comuni.dart';

/// Apre l'Anteprima a schermo intero, dalla pagina corrente. Sta fuori dal `ProviderScope` dell'editor: gli si passa lo
/// stesso contenitore.
Future<void> apriAnteprima(BuildContext context) {
  final contenitore = ProviderScope.containerOf(context);
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => UncontrolledProviderScope(
        container: contenitore,
        child: const PaginaAnteprima(),
      ),
    ),
  );
}

class PaginaAnteprima extends ConsumerStatefulWidget {
  const PaginaAnteprima({super.key});

  @override
  ConsumerState<PaginaAnteprima> createState() => _PaginaAnteprimaState();
}

class _PaginaAnteprimaState extends ConsumerState<PaginaAnteprima> {
  late final PageController _controllo = PageController(
    initialPage: ref.read(editorProvider).pagina,
  );
  late int _corrente = ref.read(editorProvider).pagina;
  late final Snapshot _documento = ref.read(editorProvider).cronologia.current;

  SessioneEditor get _s => ref.read(sessioneProvider);
  late final RiproduzioneVideo _riproduzione;

  @override
  void initState() {
    super.initState();
    final s = _s;
    _riproduzione = RiproduzioneVideo(
      risorse: s.risorse,
      cache: s.cache,
      cartellaProgetto: s.cartella.path,
      apriLettore: s.apriLettoreVideo,
    );
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // I video della tela si fermano: qui girano quelli della pagina in vista
      ref.read(editorProvider.notifier).fermaTuttiVideo();
      _prepara();
    });
  }

  @override
  void dispose() {
    _riproduzione.chiudi();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    _controllo.dispose();
    super.dispose();
  }

  /// Prepara la pagina corrente e le vicine, alla risoluzione dello schermo.
  void _prepara() {
    if (!mounted) return;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final c = _documento.canvas;
    final scala =
        (MediaQuery.sizeOf(context).width / c.frameW).clamp(0.05, 4.0) * dpr;
    for (var i = _corrente - 1; i <= _corrente + 1; i++) {
      if (i < 0 || i >= c.numFrames) continue;
      unawaited(_s.risorse.prepara(_documento, i, pixelPerUnita: scala));
    }
    _riproduzione.sincronizza(_documento, {
      for (final v in videoDellaPagina(_documento, _corrente)) v.uid,
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final c = _documento.canvas;
    final testi = testiDisegno(context);
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            key: const ValueKey('anteprima-pagine'),
            controller: _controllo,
            itemCount: c.numFrames,
            onPageChanged: (i) {
              setState(() => _corrente = i);
              _prepara();
            },
            itemBuilder: (context, i) => Semantics(
              label: t.etichettaPagina(i + 1),
              child: Center(
                child: AspectRatio(
                  aspectRatio: c.frameW / c.frameH,
                  child: LayoutBuilder(
                    builder: (context, vincoli) => AnimatedBuilder(
                      animation: _s.risorse,
                      builder: (context, _) => CustomPaint(
                        key: ValueKey('anteprima-$i'),
                        painter: _PitturaAnteprima(
                          _documento,
                          i,
                          _s.risorse,
                          testi,
                          _s.risorse.versione,
                          vincoli.maxWidth / c.frameW,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: PulsanteIcona(
                icona: Icons.close_rounded,
                etichetta: t.anteprimaChiudi,
                onTap: () => Navigator.of(context).pop(),
                colore: ColoriScrl.suAccento,
              ),
            ),
          ),
          if (c.numFrames > 1)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(MisureScrl.spazio),
                  child: Semantics(
                    label: t.anteprimaPagina(_corrente + 1, c.numFrames),
                    excludeSemantics: true,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < c.numFrames; i++)
                          Container(
                            width: i == _corrente ? 8 : 6,
                            height: i == _corrente ? 8 : 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == _corrente
                                  ? ColoriScrl.accento
                                  : ColoriScrl.testoSpento,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Una pagina senza guide né selezione: l'anteprima «pulita».
class _PitturaAnteprima extends CustomPainter {
  _PitturaAnteprima(
    this.s,
    this.pagina,
    this.risorse,
    this.testi,
    this.versione,
    this.scala,
  );

  final Snapshot s;
  final int pagina;
  final RisorsePagina risorse;
  final TestiDisegno testi;
  final int versione;
  final double scala;

  @override
  void paint(ui.Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    disegnaPagina(
      canvas,
      s,
      pagina,
      risorse,
      OpzioniDisegno(testi: testi, pulito: true),
      scala: scala,
    );
  }

  @override
  bool shouldRepaint(_PitturaAnteprima old) =>
      old.s != s ||
      old.pagina != pagina ||
      old.versione != versione ||
      old.scala != scala;
}
