/// Ritaglio a schermo intero (piano §4.6): la foto intera con un rettangolo dagli angoli e dai lati trascinabili,
/// griglia dei terzi, proporzioni Libera · Originale · Riquadro · 1:1 · 4:5 · 3:4 · 2:3 · 9:16, tasto ⇄, «Foto intera»,
/// misura in pixel e interruttore «Adatta il riquadro al ritaglio». Riferimento: `scrollr/crop_dialog.py`.
///
/// La logica del riquadro (angoli, lati, proporzioni) è in `scrl_engine` (`ModelloRitaglio`, confrontato col
/// desktop): qui c'è solo il disegno e il passaggio dai punti dello schermo ai pixel della foto.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import '../l10n/app_localizations.dart';
import '../media/cache_media.dart';
import '../theme/tokens.dart';
import 'sessione.dart';
import 'widget_comuni.dart';

/// Esito del ritaglio confermato: frazioni sulla foto originale e scelta «Adatta il riquadro».
class RisultatoRitaglio {
  const RisultatoRitaglio(this.ritaglio, this.adattaRiquadro);
  final List<double> ritaglio;
  final bool adattaRiquadro;
}

class PaginaRitaglio extends StatefulWidget {
  const PaginaRitaglio({super.key, required this.sessione, required this.foto});

  final SessioneEditor sessione;
  final PhotoItem foto;

  @override
  State<PaginaRitaglio> createState() => _PaginaRitaglioState();
}

class _PaginaRitaglioState extends State<PaginaRitaglio> {
  ModelloRitaglio? _modello;
  ui.Image? _immagine;
  bool _errore = false;
  bool _adatta = true;

  @override
  void initState() {
    super.initState();
    unawaited(_carica());
  }

  Future<void> _carica() async {
    final s = widget.sessione;
    final foto = widget.foto;
    final img = await s.cache.carica(
      sorgenteDi(foto, s.cartella.path),
      Dettaglio.anteprima,
    );
    if (!mounted) return;
    if (img == null) {
      setState(() => _errore = true);
      return;
    }
    setState(() {
      _immagine = img.immagine;
      _modello = ModelloRitaglio(
        larghezza: img.immagine.width.toDouble(),
        altezza: img.immagine.height.toDouble(),
        ritaglio: foto.crop,
        flipH: foto.flipH,
        flipV: foto.flipV,
        // Come il desktop: proporzioni del riquadro sulla tela, senza lo stiramento
        cellRatio: foto.h > 0 ? foto.w / foto.h / foto.stretch : 1.0,
      );
    });
  }

  void _conferma() {
    final m = _modello;
    if (m == null) return;
    Navigator.of(context).pop(RisultatoRitaglio(m.ritaglio, _adatta));
  }

  String _etichetta(Testi t, ModelloRitaglio m, String chiave) =>
      switch (chiave) {
        'free' => t.ritLibera,
        'original' => t.ritOriginale,
        'cell' => t.ritRiquadro,
        _ => m.etichettaProporzione(chiave),
      };

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final m = _modello;
    final img = _immagine;
    return Scaffold(
      backgroundColor: ColoriScrl.fondo,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: MisureScrl.tocco,
              child: Row(
                children: [
                  PulsanteIcona(
                    icona: Icons.close_rounded,
                    etichetta: t.ritAnnulla,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      t.ritTitolo,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  PulsanteIcona(
                    icona: Icons.check_rounded,
                    etichetta: t.ritApplica,
                    onTap: m == null ? null : _conferma,
                    colore: ColoriScrl.accento,
                  ),
                ],
              ),
            ),
            if (m != null && img != null) ...[
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: MisureScrl.spazio,
                  ),
                  children: [
                    for (final (chiave, _) in proporzioniRitaglio)
                      Padding(
                        padding: const EdgeInsets.only(
                          right: MisureScrl.spazioPiccolo,
                        ),
                        child: Center(
                          child: ChipParametro(
                            etichetta: _etichetta(t, m, chiave),
                            attivo: m.chiave == chiave,
                            onTap: () =>
                                setState(() => m.scegliProporzione(chiave)),
                          ),
                        ),
                      ),
                    PulsanteIcona(
                      icona: Icons.swap_horiz_rounded,
                      etichetta: t.ritScambia,
                      onTap: m.puoScambiare ? () => setState(m.scambia) : null,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _AreaRitaglio(
                  modello: m,
                  immagine: img,
                  onCambia: () => setState(() {}),
                ),
              ),
              _Piede(
                modello: m,
                misura:
                    widget.sessione.misuraDi(widget.foto) ??
                    (w: img.width, h: img.height),
                adatta: _adatta,
                onAdatta: (v) => setState(() => _adatta = v),
                onFotoIntera: () => setState(m.tuttaLaFoto),
              ),
            ] else
              Expanded(
                child: Center(
                  child: _errore
                      ? Text(
                          t.ritNonLeggibile,
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      : const CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Misura in pixel, interruttore «Adatta il riquadro al ritaglio» e «Foto intera».
class _Piede extends StatelessWidget {
  const _Piede({
    required this.modello,
    required this.misura,
    required this.adatta,
    required this.onAdatta,
    required this.onFotoIntera,
  });

  final ModelloRitaglio modello;
  final MisuraImmagine misura;
  final bool adatta;
  final ValueChanged<bool> onAdatta;
  final VoidCallback onFotoIntera;

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final (w, h) = modello.misuraOriginale(misura.w, misura.h);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MisureScrl.spazio,
        MisureScrl.spazioPiccolo,
        MisureScrl.spazio,
        MisureScrl.spazioPiccolo,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.ritMisura(w, h),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              ChipParametro(
                etichetta: t.azFotoIntera,
                attivo: false,
                onTap: onFotoIntera,
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  t.ritAdatta,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Semantics(
                label: t.ritAdatta,
                child: Switch(value: adatta, onChanged: onAdatta),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Distanza (in punti dello schermo) entro cui si afferra una maniglia: 24 dp, cioè un'area di 48 dp.
const double _presa = 24;

/// Margine attorno alla foto, perché le maniglie ai bordi si possano afferrare.
const double _margine = 24;

/// La foto con il rettangolo del ritaglio. Un dito alla volta: afferra una maniglia, sposta il rettangolo o,
/// fuori da esso, ne disegna uno nuovo.
class _AreaRitaglio extends StatefulWidget {
  const _AreaRitaglio({
    required this.modello,
    required this.immagine,
    required this.onCambia,
  });

  final ModelloRitaglio modello;
  final ui.Image immagine;
  final VoidCallback onCambia;

  @override
  State<_AreaRitaglio> createState() => _AreaRitaglioState();
}

class _AreaRitaglioState extends State<_AreaRitaglio> {
  int? _dito;
  Offset _giu = Offset.zero;

  /// Scala (punti dello schermo per pixel della foto) e origine della foto nell'area.
  (double, Offset) _geo(Size size) {
    final m = widget.modello;
    final s = math.max(
      1e-6,
      math.min(
        (size.width - 2 * _margine) / m.imgW,
        (size.height - 2 * _margine) / m.imgH,
      ),
    );
    return (
      s,
      Offset((size.width - m.imgW * s) / 2.0, (size.height - m.imgH * s) / 2.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    return LayoutBuilder(
      builder: (context, vincoli) {
        final size = Size(vincoli.maxWidth, vincoli.maxHeight);
        final (s, o) = _geo(size);
        final m = widget.modello;
        Offset aFoto(Offset p) => Offset((p.dx - o.dx) / s, (p.dy - o.dy) / s);
        return Semantics(
          label: t.ritTitolo,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) {
              if (_dito != null) return;
              _dito = e.pointer;
              _giu = e.localPosition;
              final p = aFoto(e.localPosition);
              m.inizia(p.dx, p.dy, _presa / s);
              widget.onCambia();
            },
            onPointerMove: (e) {
              if (e.pointer != _dito) return;
              final p = aFoto(e.localPosition);
              final d = e.localPosition - _giu;
              m.trascina(
                p.dx,
                p.dy,
                spostamentoSchermo: d.dx.abs() + d.dy.abs(),
              );
              widget.onCambia();
            },
            onPointerUp: (e) {
              if (e.pointer != _dito) return;
              _dito = null;
              m.finisce();
            },
            onPointerCancel: (e) {
              if (e.pointer != _dito) return;
              _dito = null;
              m.finisce();
            },
            child: CustomPaint(
              size: size,
              painter: _PittoreRitaglio(m, widget.immagine, s, o),
            ),
          ),
        );
      },
    );
  }
}

/// Foto, parte esclusa scurita, terzi, bordo, angoli a L e tacche a metà dei lati (`CropCanvas.paintEvent`).
class _PittoreRitaglio extends CustomPainter {
  _PittoreRitaglio(this.m, this.immagine, this.scala, this.origine);

  final ModelloRitaglio m;
  final ui.Image immagine;
  final double scala;
  final Offset origine;

  @override
  void paint(Canvas canvas, Size size) {
    final intera = Rect.fromLTWH(
      origine.dx,
      origine.dy,
      m.imgW * scala,
      m.imgH * scala,
    );
    // La foto come appare: specchiata se lo è
    canvas.save();
    canvas.translate(intera.center.dx, intera.center.dy);
    canvas.scale(m.flipH ? -1.0 : 1.0, m.flipV ? -1.0 : 1.0);
    canvas.translate(-intera.center.dx, -intera.center.dy);
    canvas.drawImageRect(
      immagine,
      Rect.fromLTWH(
        0,
        0,
        immagine.width.toDouble(),
        immagine.height.toDouble(),
      ),
      intera,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();

    final r = m.rect;
    final crop = Rect.fromLTWH(
      origine.dx + r.x * scala,
      origine.dy + r.y * scala,
      r.w * scala,
      r.h * scala,
    );
    // Fuori dal ritaglio la foto si scurisce
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(intera),
        Path()..addRect(crop),
      ),
      Paint()..color = Colors.black.withAlpha(150),
    );

    const inchiostro = ColoriScrl.suAccento;
    final terzi = Paint()
      ..color = inchiostro.withAlpha(90)
      ..strokeWidth = 1;
    for (var k = 1; k <= 2; k++) {
      final x = crop.left + crop.width * k / 3.0;
      final y = crop.top + crop.height * k / 3.0;
      canvas.drawLine(Offset(x, crop.top), Offset(x, crop.bottom), terzi);
      canvas.drawLine(Offset(crop.left, y), Offset(crop.right, y), terzi);
    }
    canvas.drawRect(
      crop,
      Paint()
        ..color = inchiostro
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Angoli a L, più spessi
    final spesso = Paint()
      ..color = inchiostro
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.square;
    final braccio = math.min(18.0, math.min(crop.width, crop.height) / 3.0);
    for (final (cx, cy, sx, sy) in [
      (crop.left, crop.top, 1.0, 1.0),
      (crop.right, crop.top, -1.0, 1.0),
      (crop.left, crop.bottom, 1.0, -1.0),
      (crop.right, crop.bottom, -1.0, -1.0),
    ]) {
      canvas.drawLine(Offset(cx, cy), Offset(cx + sx * braccio, cy), spesso);
      canvas.drawLine(Offset(cx, cy), Offset(cx, cy + sy * braccio), spesso);
    }
    // Tacche a metà dei lati
    final meta = math.min(9.0, math.min(crop.width, crop.height) / 6.0);
    final c = crop.center;
    canvas.drawLine(
      Offset(c.dx - meta, crop.top),
      Offset(c.dx + meta, crop.top),
      spesso,
    );
    canvas.drawLine(
      Offset(c.dx - meta, crop.bottom),
      Offset(c.dx + meta, crop.bottom),
      spesso,
    );
    canvas.drawLine(
      Offset(crop.left, c.dy - meta),
      Offset(crop.left, c.dy + meta),
      spesso,
    );
    canvas.drawLine(
      Offset(crop.right, c.dy - meta),
      Offset(crop.right, c.dy + meta),
      spesso,
    );
  }

  @override
  bool shouldRepaint(_PittoreRitaglio old) => true;
}
