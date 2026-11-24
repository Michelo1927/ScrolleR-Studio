/// Ritaglio a schermo intero (piano §4.6): la foto intera con un rettangolo dagli angoli e dai lati trascinabili,
/// griglia dei terzi, proporzioni Libera · Originale · Riquadro · 1:1 · 4:5 · 3:4 · 2:3 · 9:16, tasto ⇄, «Foto intera»,
/// misura in pixel e interruttore «Adatta il riquadro al ritaglio». Riferimento: `scrollr/crop_dialog.py`.
///
/// Modo «Sagoma» (scontorno a mano, solo per le foto): col dito si disegna il contorno del soggetto (tratto libero
/// o punti), con una lente che mostra ingrandito quello che il dito copre; due dita ingrandiscono. Fuori dalla
/// sagoma la foto diventa trasparente, con il bordo sfumato dalla «Morbidezza».
///
/// La logica del riquadro (angoli, lati, proporzioni) e della sagoma è in `scrl_engine` (`ModelloRitaglio` e
/// `ModelloSagoma`, confrontati col desktop): qui c'è solo il disegno e il passaggio dai punti dello schermo ai
/// pixel della foto.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import '../l10n/app_localizations.dart';
import '../media/cache_media.dart';
import '../theme/tokens.dart';
import 'sessione.dart';
import 'widget_comuni.dart';

/// Esito del ritaglio confermato: frazioni sulla foto originale e scelta «Adatta il riquadro», oppure la sagoma
/// (sulla foto originale non specchiata) con la sua morbidezza.
class RisultatoRitaglio {
  const RisultatoRitaglio(
    this.ritaglio,
    this.adattaRiquadro, {
    this.sagoma,
    this.morbidezza = sagomaMorbidezza,
  });
  final List<double> ritaglio;
  final bool adattaRiquadro;

  /// Sagoma chiusa del modo «Sagoma» (null = si usa il rettangolo, e la sagoma eventuale si toglie).
  final List<PuntoSagoma>? sagoma;
  final int morbidezza;
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
  ModelloSagoma? _sagoma;
  ui.Image? _immagine;
  bool _errore = false;
  bool _adatta = true;

  /// Modo «Sagoma» invece del rettangolo.
  bool _modoSagoma = false;

  /// «Risultato»: la foto scontornata sulla scacchiera.
  bool _risultato = false;
  int _morbidezza = sagomaMorbidezza;

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
      // Mai sui video (`SUPPORTS_CUTOUT = False`)
      if (!foto.isVideo) {
        _sagoma = ModelloSagoma(
          larghezza: img.immagine.width.toDouble(),
          altezza: img.immagine.height.toDouble(),
          sagoma: foto.cutout,
          flipH: foto.flipH,
          flipV: foto.flipV,
        );
        _modoSagoma = _sagoma!.chiusa;
        _morbidezza = foto.cutoutSoft;
      }
    });
  }

  bool get _puoConfermare =>
      _modello != null && (!_modoSagoma || (_sagoma?.chiusa ?? false));

  void _conferma() {
    final m = _modello;
    if (m == null || !_puoConfermare) return;
    final sagoma = _modoSagoma ? _sagoma?.risultato() : null;
    if (_modoSagoma && sagoma == null) return;
    Navigator.of(context).pop(
      RisultatoRitaglio(
        m.ritaglio,
        _adatta,
        sagoma: sagoma,
        morbidezza: _morbidezza,
      ),
    );
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
                    key: const ValueKey('ritaglio-applica'),
                    icona: Icons.check_rounded,
                    etichetta: _modoSagoma ? t.ritApplicaSagoma : t.ritApplica,
                    onTap: _puoConfermare ? _conferma : null,
                    colore: ColoriScrl.accento,
                  ),
                ],
              ),
            ),
            if (m != null && img != null && _sagoma != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MisureScrl.spazio,
                  0,
                  MisureScrl.spazio,
                  MisureScrl.spazioPiccolo,
                ),
                child: ControlloSegmentato<bool>(
                  voci: [
                    VoceSegmento(
                      valore: false,
                      etichetta: t.ritModoRettangolo,
                      chiave: const ValueKey('modo-rettangolo'),
                    ),
                    VoceSegmento(
                      valore: true,
                      etichetta: t.ritModoSagoma,
                      chiave: const ValueKey('modo-sagoma'),
                    ),
                  ],
                  scelto: _modoSagoma,
                  onScelto: (v) => setState(() {
                    _modoSagoma = v;
                    _risultato = false;
                  }),
                ),
              ),
            if (m != null && img != null && _modoSagoma && _sagoma != null) ...[
              _RigaSagoma(
                modello: _sagoma!,
                risultato: _risultato,
                onCambia: () => setState(() {
                  if (!_sagoma!.chiusa) _risultato = false;
                }),
                onRisultato: (v) => setState(() => _risultato = v),
              ),
              Expanded(
                child: _AreaSagoma(
                  modello: _sagoma!,
                  immagine: img,
                  morbidezza: _morbidezza,
                  risultato: _risultato,
                  onCambia: () => setState(() {
                    if (!_sagoma!.chiusa) _risultato = false;
                  }),
                ),
              ),
              _PiedeSagoma(
                modello: _sagoma!,
                risultato: _risultato,
                morbidezza: _morbidezza,
                onMorbidezza: (v) => setState(() => _morbidezza = v),
              ),
            ] else if (m != null && img != null) ...[
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
                notaSagoma: haSagoma(widget.foto),
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
    this.notaSagoma = false,
  });

  final ModelloRitaglio modello;
  final MisuraImmagine misura;
  final bool adatta;
  final ValueChanged<bool> onAdatta;
  final VoidCallback onFotoIntera;

  /// La foto ha una sagoma: applicando il rettangolo si toglie (lo si dice sotto la misura).
  final bool notaSagoma;

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
          if (notaSagoma)
            Text(
              t.ritTogliSagomaNota,
              style: Theme.of(context).textTheme.bodySmall,
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
      Paint()..color = ColoriScrl.veloEscluso,
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

// ================================================================ Sagoma

/// Velocità dei passi della lente: quanto ingrandisce rispetto alla vista.
const double _ingrandimentoLente = 2.0;

/// Raggio della lente (dp).
const double _raggioLente = 58;

/// Spostamento (dp) oltre il quale un tocco diventa un tratto a mano libera o un trascinamento.
const double _sogliaTratto = 8;

/// Zoom massimo della vista della sagoma (come `ZOOM_MAX` del desktop).
const double _zoomMassimo = 8;

/// Comando della riga della sagoma: icona e una parola, spento quando non si può usare.
class _ComandoSagoma extends StatelessWidget {
  const _ComandoSagoma({
    required this.icona,
    required this.etichetta,
    required this.onTap,
    this.attivo = false,
    this.chiave,
  });

  final IconData icona;
  final String etichetta;
  final VoidCallback? onTap;
  final bool attivo;
  final Key? chiave;

  @override
  Widget build(BuildContext context) {
    final c = onTap == null
        ? ColoriScrl.testoSpento
        : (attivo ? ColoriScrl.accentoTesto : ColoriScrl.testo);
    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: attivo,
      label: etichetta,
      excludeSemantics: true,
      child: InkWell(
        key: chiave,
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icona, size: 24, color: c),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  etichetta,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: TestoScrl.piccolo,
                    fontWeight: attivo ? TestoScrl.marcato : TestoScrl.regolare,
                    color: c,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Comandi della sagoma: Indietro · Avanti · Chiudi/Riapri · Risultato · Togli.
class _RigaSagoma extends StatelessWidget {
  const _RigaSagoma({
    required this.modello,
    required this.risultato,
    required this.onCambia,
    required this.onRisultato,
  });

  final ModelloSagoma modello;
  final bool risultato;
  final VoidCallback onCambia;
  final ValueChanged<bool> onRisultato;

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final m = modello;
    VoidCallback? se(bool si, bool Function() f) => si
        ? () {
            f();
            onCambia();
          }
        : null;
    return Row(
      children: [
        Expanded(
          child: _ComandoSagoma(
            chiave: const ValueKey('sagoma-indietro'),
            icona: Icons.undo_rounded,
            etichetta: t.sagIndietro,
            onTap: se(m.puoAnnullare && !risultato, m.annulla),
          ),
        ),
        Expanded(
          child: _ComandoSagoma(
            chiave: const ValueKey('sagoma-avanti'),
            icona: Icons.redo_rounded,
            etichetta: t.sagAvanti,
            onTap: se(m.puoRipetere && !risultato, m.ripeti),
          ),
        ),
        Expanded(
          child: m.chiusa
              ? _ComandoSagoma(
                  chiave: const ValueKey('sagoma-riapri'),
                  icona: Icons.edit_rounded,
                  etichetta: t.sagRiapri,
                  onTap: se(!risultato, m.riapri),
                )
              : _ComandoSagoma(
                  chiave: const ValueKey('sagoma-chiudi'),
                  icona: Icons.check_circle_outline_rounded,
                  etichetta: t.sagChiudi,
                  onTap: se(m.punti.length >= sagomaPuntiMinimi, m.chiudi),
                ),
        ),
        Expanded(
          child: _ComandoSagoma(
            chiave: const ValueKey('sagoma-risultato'),
            icona: Icons.visibility_outlined,
            etichetta: t.sagRisultato,
            attivo: risultato,
            onTap: m.chiusa ? () => onRisultato(!risultato) : null,
          ),
        ),
        Expanded(
          child: _ComandoSagoma(
            chiave: const ValueKey('sagoma-togli'),
            icona: Icons.delete_outline_rounded,
            etichetta: t.sagTogli,
            onTap: se(m.punti.isNotEmpty && !risultato, () {
              m.cancella();
              return true;
            }),
          ),
        ),
      ],
    );
  }
}

/// Testo d'aiuto e cursore della morbidezza.
class _PiedeSagoma extends StatelessWidget {
  const _PiedeSagoma({
    required this.modello,
    required this.risultato,
    required this.morbidezza,
    required this.onMorbidezza,
  });

  final ModelloSagoma modello;
  final bool risultato;
  final int morbidezza;
  final ValueChanged<int> onMorbidezza;

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final m = modello;
    final aiuto = risultato
        ? t.sagAiutoRisultato
        : m.chiusa
        ? t.sagAiutoChiusa
        : m.punti.isNotEmpty
        ? t.sagAiutoAperta
        : t.sagAiutoVuota;
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
          Text(
            aiuto,
            key: const ValueKey('sagoma-aiuto'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: MisureScrl.spazioPiccolo),
          Row(
            children: [
              Text(
                t.sagMorbidezza,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Expanded(
                child: CursoreGrande(
                  key: const ValueKey('sagoma-morbidezza'),
                  valore: morbidezza.toDouble(),
                  minimo: 0,
                  massimo: sagomaMorbidezzaMax.toDouble(),
                  iniziale: sagomaMorbidezza.toDouble(),
                  onCambia: onMorbidezza,
                  onFine: () {},
                  etichetta: t.sagMorbidezza,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Che cosa sta facendo il dito sulla sagoma.
enum _Azione { attesa, tratto, vertice, sposta, vista, niente }

/// La foto con la sagoma. Un dito: disegna (tratto o punti), trascina un punto o la sagoma intera; due dita:
/// zoom e spostamento della vista. Mentre il dito disegna, una lente mostra ingrandito quello che copre.
class _AreaSagoma extends StatefulWidget {
  const _AreaSagoma({
    required this.modello,
    required this.immagine,
    required this.morbidezza,
    required this.risultato,
    required this.onCambia,
  });

  final ModelloSagoma modello;
  final ui.Image immagine;
  final int morbidezza;
  final bool risultato;

  /// La sagoma è cambiata (comandi e testo d'aiuto si aggiornano).
  final VoidCallback onCambia;

  @override
  State<_AreaSagoma> createState() => _AreaSagomaState();
}

class _AreaSagomaState extends State<_AreaSagoma> {
  Size _size = Size.zero;
  double _zoom = 1.0;
  Offset _pan = Offset.zero;

  final Map<int, Offset> _dita = {};
  _Azione? _azione;
  Offset _giu = Offset.zero;
  bool _mosso = false;
  int _indice = -1;
  Offset _panIniziale = Offset.zero;

  /// Dito che disegna (per la lente), null se nessuno.
  Offset? _lente;

  // Pizzico
  double _distanzaIniziale = 1.0;
  double _zoomIniziale = 1.0;
  Offset _ancora = Offset.zero;

  // Doppio tocco su un lato e tocco lungo su un punto
  DateTime? _ultimoTocco;
  Offset _puntoUltimoTocco = Offset.zero;
  Timer? _toccoLungo;

  ModelloSagoma get _m => widget.modello;

  @override
  void dispose() {
    _toccoLungo?.cancel();
    super.dispose();
  }

  // ---------- Geometria della vista (`_fit_scale`, `_origin` del desktop) ----------
  double get _scalaAdatta => math.max(
    1e-6,
    math.min(
      (_size.width - 2 * _margine) / _m.imgW,
      (_size.height - 2 * _margine) / _m.imgH,
    ),
  );

  double get _scala => _scalaAdatta * _zoom;

  Offset _centrata(double s) => Offset(
    (_size.width - _m.imgW * s) / 2.0,
    (_size.height - _m.imgH * s) / 2.0,
  );

  double _asse(double vista, double misura, double centrata, double pan) {
    if (misura <= vista - 2 * _margine + 0.01) return centrata;
    return math.min(
      math.max(centrata + pan, vista - _margine - misura),
      _margine,
    );
  }

  Offset get _origine {
    final s = _scala;
    final c = _centrata(s);
    return Offset(
      _asse(_size.width, _m.imgW * s, c.dx, _pan.dx),
      _asse(_size.height, _m.imgH * s, c.dy, _pan.dy),
    );
  }

  /// Lo spostamento salvato è quello effettivo, dopo i limiti della vista.
  void _normalizza() => _pan = _origine - _centrata(_scala);

  PuntoSagoma _aFoto(Offset p) {
    final s = _scala, o = _origine;
    return ((p.dx - o.dx) / s, (p.dy - o.dy) / s);
  }

  // ---------- Dita ----------
  void _giuDito(PointerDownEvent e) {
    _dita[e.pointer] = e.localPosition;
    if (_dita.length == 1) {
      _inizia(e.localPosition);
    } else if (_dita.length == 2) {
      _annullaGesto();
      final (a, b) = _dueDita();
      _distanzaIniziale = math.max(1.0, (a - b).distance);
      _zoomIniziale = _zoom;
      final f = _aFoto((a + b) / 2);
      _ancora = Offset(f.$1, f.$2);
      _azione = _Azione.niente;
    }
    setState(() {});
  }

  (Offset, Offset) _dueDita() {
    final v = _dita.values.toList();
    return (v[0], v[1]);
  }

  void _inizia(Offset pos) {
    final m = _m;
    _giu = pos;
    _mosso = false;
    _lente = null;
    final p = _aFoto(pos);
    final s = _scala;
    if (widget.risultato) {
      _azione = _zoom > 1.0 ? _Azione.vista : _Azione.niente;
      _panIniziale = _pan;
      return;
    }
    if (!m.chiusa) {
      _azione = _Azione.attesa;
      _lente = pos;
      return;
    }
    final i = m.verticeVicino(p, s, _presa);
    if (i != null) {
      _azione = _Azione.vertice;
      _indice = i;
      _lente = pos;
      m.iniziaTrascinamento();
      _toccoLungo?.cancel();
      _toccoLungo = Timer(const Duration(milliseconds: 500), _togliPuntoTenuto);
    } else if (m.contiene(p)) {
      _azione = _Azione.sposta;
      m.iniziaTrascinamento();
    } else {
      _azione = _zoom > 1.0 ? _Azione.vista : _Azione.niente;
      _panIniziale = _pan;
    }
  }

  /// Tocco lungo su un punto della sagoma chiusa: si toglie (ne restano almeno 3).
  void _togliPuntoTenuto() {
    if (_azione != _Azione.vertice || _mosso || !mounted) return;
    _m.annullaTrascinamento();
    if (_m.togliPunto(_indice)) {
      unawaited(HapticFeedback.mediumImpact());
      widget.onCambia();
    }
    _azione = _Azione.niente;
    setState(() => _lente = null);
  }

  /// Arriva il secondo dito: quello che il primo stava facendo non conta.
  void _annullaGesto() {
    _toccoLungo?.cancel();
    switch (_azione) {
      case _Azione.tratto:
        _m.tratto = [];
      case _Azione.vertice || _Azione.sposta:
        _m.annullaTrascinamento();
      default:
        break;
    }
    _lente = null;
    _azione = _Azione.niente;
  }

  void _muoviDito(PointerMoveEvent e) {
    if (!_dita.containsKey(e.pointer)) return;
    _dita[e.pointer] = e.localPosition;
    if (_dita.length == 2) {
      final (a, b) = _dueDita();
      final f = (a + b) / 2;
      _zoom = (_zoomIniziale * (a - b).distance / _distanzaIniziale).clamp(
        1.0,
        _zoomMassimo,
      );
      final s = _scala;
      final c = _centrata(s);
      _pan = Offset(f.dx - _ancora.dx * s - c.dx, f.dy - _ancora.dy * s - c.dy);
      _normalizza();
      setState(() {});
      return;
    }
    if (_dita.length != 1) return;
    final pos = e.localPosition;
    final m = _m;
    final s = _scala;
    if (!_mosso && (pos - _giu).distance > _sogliaTratto) {
      _mosso = true;
      _toccoLungo?.cancel();
    }
    switch (_azione) {
      case _Azione.attesa:
        if (!_mosso) break;
        // Si è trascinato: tratto a mano libera che parte da dove si è toccato
        m.iniziaTratto(_aFoto(_giu));
        m.continuaTratto(_aFoto(pos), s);
        _azione = _Azione.tratto;
        _lente = pos;
      case _Azione.tratto:
        m.continuaTratto(_aFoto(pos), s);
        _lente = pos;
      case _Azione.vertice:
        if (!_mosso) break;
        m.spostaVertice(_indice, _aFoto(pos));
        _lente = pos;
      case _Azione.sposta:
        if (!_mosso) break;
        final d = (pos - _giu) / s;
        m.spostaSagoma(d.dx, d.dy);
      case _Azione.vista:
        _pan = _panIniziale + (pos - _giu);
        _normalizza();
      default:
        break;
    }
    setState(() {});
  }

  void _suDito(PointerEvent e, {bool annullato = false}) {
    if (_dita.remove(e.pointer) == null) return;
    if (_dita.isNotEmpty) {
      // Resta un dito dopo lo zoom: non disegna finché non si alzano tutte
      _azione = _Azione.niente;
      setState(() {});
      return;
    }
    _toccoLungo?.cancel();
    final m = _m;
    final s = _scala;
    final pos = e.localPosition;
    final p = _aFoto(pos);
    var cambiata = false;
    switch (_azione) {
      case _Azione.attesa when !annullato:
        if (m.punti.length >= sagomaPuntiMinimi &&
            m.vicinoAlPrimo(p, s, _presa)) {
          cambiata = m.chiudi();
        } else {
          m.aggiungiPunto(p, s);
          cambiata = true;
        }
      case _Azione.tratto:
        if (annullato) {
          m.tratto = [];
        } else {
          m.finisciTratto(s, _presa);
          cambiata = true;
        }
      case _Azione.vertice || _Azione.sposta:
        m.fineTrascinamento();
        cambiata = _mosso;
        if (!_mosso && !annullato) cambiata = _doppioTocco(pos);
      case _Azione.vista || _Azione.niente:
        if (!_mosso && !annullato && m.chiusa && !widget.risultato) {
          cambiata = _doppioTocco(pos);
        }
      default:
        break;
    }
    _azione = null;
    _lente = null;
    setState(() {});
    if (cambiata) widget.onCambia();
  }

  /// Secondo tocco vicino al primo, entro poco tempo, su un lato della sagoma chiusa: aggiunge un punto lì.
  bool _doppioTocco(Offset pos) {
    final ora = DateTime.now();
    final prima = _ultimoTocco;
    _ultimoTocco = ora;
    final vicino = (pos - _puntoUltimoTocco).distance <= _presa;
    _puntoUltimoTocco = pos;
    if (prima == null ||
        ora.difference(prima) > const Duration(milliseconds: 350) ||
        !vicino) {
      return false;
    }
    _ultimoTocco = null;
    final m = _m;
    final p = _aFoto(pos);
    if (m.verticeVicino(p, _scala, _presa) != null) return false;
    final lato = m.latoVicino(p, _scala, _presa);
    if (lato == null) return false;
    m.inserisciPunto(lato.$1, lato.$2);
    unawaited(HapticFeedback.selectionClick());
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    return LayoutBuilder(
      builder: (context, vincoli) {
        final size = Size(vincoli.maxWidth, vincoli.maxHeight);
        if (size != _size) {
          _size = size;
          _normalizza();
        }
        return Semantics(
          label: t.ritModoSagoma,
          hint: widget.risultato
              ? t.sagAiutoRisultato
              : _m.chiusa
              ? t.sagAiutoChiusa
              : t.sagAiutoVuota,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _giuDito,
            onPointerMove: _muoviDito,
            onPointerUp: _suDito,
            onPointerCancel: (e) => _suDito(e, annullato: true),
            child: CustomPaint(
              size: size,
              painter: _PittoreSagoma(
                m: _m,
                immagine: widget.immagine,
                scala: _scala,
                origine: _origine,
                zoom: _zoom,
                morbidezza: widget.morbidezza,
                risultato: widget.risultato && _m.chiusa,
                trascinato: _azione == _Azione.vertice && _mosso
                    ? _indice
                    : null,
                lente: _lente,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Foto con la sagoma: fuori dalla sagoma chiusa la foto si scurisce; contorno chiaro su un filo scuro, punti,
/// tratto in corso e lente (`_paint_cutout` del desktop). Con [risultato] la foto scontornata su una scacchiera.
class _PittoreSagoma extends CustomPainter {
  _PittoreSagoma({
    required this.m,
    required this.immagine,
    required this.scala,
    required this.origine,
    required this.zoom,
    required this.morbidezza,
    required this.risultato,
    required this.trascinato,
    required this.lente,
  });

  final ModelloSagoma m;
  final ui.Image immagine;
  final double scala;
  final Offset origine;
  final double zoom;
  final int morbidezza;
  final bool risultato;
  final int? trascinato;
  final Offset? lente;

  Offset _schermo(PuntoSagoma q) =>
      Offset(origine.dx + q.$1 * scala, origine.dy + q.$2 * scala);

  Rect get _intera =>
      Rect.fromLTWH(origine.dx, origine.dy, m.imgW * scala, m.imgH * scala);

  void _foto(Canvas canvas) {
    final intera = _intera;
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
  }

  Path get _contorno =>
      Path()..addPolygon([for (final q in m.punti) _schermo(q)], true);

  /// Foto, velo fuori dalla sagoma, contorno e punti: la scena che si vede (e che la lente ingrandisce).
  /// [k] riduce le misure fisse (fili, punti) dentro la lente ingrandita.
  void _scena(Canvas canvas, Size size, {double k = 1.0}) {
    final intera = _intera;
    if (risultato) {
      _scacchiera(canvas, intera, size);
      canvas.saveLayer(intera, Paint());
      _foto(canvas);
      canvas.saveLayer(intera, Paint()..blendMode = BlendMode.dstIn);
      final sigma = raggioMorbidezza(morbidezza, m.imgW, m.imgH) / 2.0 * scala;
      canvas.drawPath(
        _contorno,
        Paint()
          ..color = ColoriScrl.suAccento
          ..maskFilter = sigma > 0.05
              ? MaskFilter.blur(BlurStyle.normal, sigma)
              : null,
      );
      canvas.restore();
      canvas.restore();
      return;
    }
    _foto(canvas);
    if (m.chiusa) {
      canvas.drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(intera),
          _contorno,
        ),
        Paint()..color = ColoriScrl.veloEscluso,
      );
    }
    final sotto = Paint()
      ..color = Colors.black.withAlpha(170)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5 * k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final sopra = Paint()
      ..color = ColoriScrl.suAccento
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void linea(Path p) {
      canvas.drawPath(p, sotto);
      canvas.drawPath(p, sopra);
    }

    if (m.chiusa) {
      linea(_contorno);
    } else if (m.punti.length >= 2) {
      linea(Path()..addPolygon([for (final q in m.punti) _schermo(q)], false));
    }
    if (m.tratto.isNotEmpty) {
      linea(
        Path()..addPolygon([
          if (m.punti.isNotEmpty) _schermo(m.punti.last),
          for (final q in m.tratto) _schermo(q),
        ], false),
      );
    }
    // Punti, a misura costante sullo schermo
    final bordo = Paint()
      ..color = Colors.black.withAlpha(170)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * k;
    void punto(Offset c, double r, bool acceso) {
      canvas.drawCircle(
        c,
        r * k,
        Paint()..color = acceso ? ColoriScrl.accento : ColoriScrl.suAccento,
      );
      canvas.drawCircle(c, r * k, bordo);
    }

    final primoGrande = !m.chiusa && m.punti.length >= sagomaPuntiMinimi;
    // Un contorno disegnato col dito ha moltissimi punti vicini: i pallini si rimpiccioliscono, così non
    // coprono il contorno (si afferrano lo stesso, la presa è di 24 dp)
    var perimetro = 0.0;
    for (var i = 0; i < m.punti.length; i++) {
      perimetro +=
          (_schermo(m.punti[i]) - _schermo(m.punti[(i + 1) % m.punti.length]))
              .distance;
    }
    final passo = m.punti.isEmpty ? 0.0 : perimetro / m.punti.length;
    final raggio = (passo / 3.5).clamp(2.5, 5.5);
    for (var i = 0; i < m.punti.length; i++) {
      final c = _schermo(m.punti[i]);
      if (m.chiusa) {
        punto(c, i == trascinato ? 7 : raggio, i == trascinato);
      } else if (i == 0) {
        // Il primo punto: toccandolo (o tornandoci col tratto) la sagoma si chiude
        punto(c, primoGrande ? 8 : 5.5, primoGrande);
      } else {
        punto(c, 3.5, false);
      }
    }
  }

  void _scacchiera(Canvas canvas, Rect intera, Size size) {
    final vis = intera.intersect(Offset.zero & size);
    if (vis.isEmpty) return;
    canvas.save();
    canvas.clipRect(vis);
    canvas.drawRect(vis, Paint()..color = ColoriScrl.scacchiChiari);
    const lato = 10.0;
    final scuro = Paint()..color = ColoriScrl.scacchiScuri;
    final i0 = ((vis.left - intera.left) / lato).floor();
    final j0 = ((vis.top - intera.top) / lato).floor();
    for (var j = j0; intera.top + j * lato < vis.bottom; j++) {
      for (var i = i0; intera.left + i * lato < vis.right; i++) {
        if ((i + j).isOdd) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            intera.left + i * lato,
            intera.top + j * lato,
            lato,
            lato,
          ),
          scuro,
        );
      }
    }
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    _scena(canvas, size);
    if (zoom > 1.001) {
      final tp = TextPainter(
        text: TextSpan(
          text: '${zoom.toStringAsFixed(1)}×',
          style: const TextStyle(
            fontSize: TestoScrl.piccolo,
            color: ColoriScrl.testoSecondario,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(size.width - tp.width - 8, size.height - tp.height - 4),
      );
    }
    final f = lente;
    if (f != null && !risultato) _lente(canvas, size, f);
    canvas.restore();
  }

  /// Lente in alto, dal lato opposto al dito: la parte della foto sotto il dito, ingrandita, con un mirino.
  void _lente(Canvas canvas, Size size, Offset dito) {
    const r = _raggioLente;
    const bordo = 12.0;
    final aSinistra =
        !(dito.dx < size.width / 2 && dito.dy < r * 2 + bordo * 3);
    final c = Offset(aSinistra ? bordo + r : size.width - bordo - r, bordo + r);
    final cerchio = Rect.fromCircle(center: c, radius: r);
    canvas.save();
    canvas.clipPath(Path()..addOval(cerchio));
    canvas.drawRect(cerchio, Paint()..color = ColoriScrl.fondo);
    canvas.translate(c.dx, c.dy);
    canvas.scale(_ingrandimentoLente);
    canvas.translate(-dito.dx, -dito.dy);
    _scena(canvas, size, k: 1 / _ingrandimentoLente);
    canvas.restore();
    // Mirino e bordo della lente
    final mirino = Paint()
      ..color = ColoriScrl.accento
      ..strokeWidth = 1.5;
    canvas.drawLine(c - const Offset(7, 0), c + const Offset(7, 0), mirino);
    canvas.drawLine(c - const Offset(0, 7), c + const Offset(0, 7), mirino);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = Colors.black.withAlpha(170)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = ColoriScrl.suAccento
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_PittoreSagoma old) => true;
}
