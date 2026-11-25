/// Striscia del tempo della schermata Sottotitoli (`TimelineStrip` del desktop, alla maniera degli editor video del
/// telefono): la linea di lettura è fissa al centro e la striscia, con la forma d'onda e le frasi come blocchi,
/// scorre sotto il dito. Due dita = zoom (circa 8 s visibili all'inizio). Un tocco su un blocco sceglie la frase e
/// mostra due maniglie grandi, che si agganciano alle pause con uno scatto. Le regole dei bordi sono nel motore
/// (`ModificaSottotitoli.trascina`).
library;

import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import '../theme/tokens.dart';

/// Distanza (punti dello schermo) entro cui si afferra una maniglia: un'area di 48 dp.
const double _presa = 24;

/// Altezza del righello in cima.
const double _righello = 18;

/// Altezza della fascia delle maniglie in fondo.
const double _fasciaManiglie = 26;

/// Secondi visibili all'apertura.
const double _spanIniziale = 8;

enum _Gesto { nessuno, scorri, zoom, trascina }

class StrisciaTempo extends StatefulWidget {
  const StrisciaTempo({
    super.key,
    required this.modifica,
    required this.tempo,
    required this.inviluppo,
    required this.scelta,
    required this.etichetta,
    required this.onScorri,
    required this.onScorriFine,
    required this.onScegli,
    required this.onModificata,
    this.avviso,
  });

  final ModificaSottotitoli modifica;

  /// Secondo del video sotto la linea di lettura.
  final double tempo;
  final List<double> inviluppo;

  /// Frase scelta (-1 = nessuna).
  final int scelta;

  /// Nome per i lettori di schermo.
  final String etichetta;

  /// Testo al posto della forma d'onda (lettura dell'audio, video senza audio…).
  final String? avviso;

  /// Il dito trascina la striscia: il nuovo secondo sotto la linea di lettura.
  final ValueChanged<double> onScorri;
  final VoidCallback onScorriFine;

  /// Tocco su un blocco (o sul vuoto: -1).
  final ValueChanged<int> onScegli;

  /// Una maniglia ha cambiato i tempi.
  final VoidCallback onModificata;

  @override
  State<StrisciaTempo> createState() => _StrisciaTempoState();
}

class _StrisciaTempoState extends State<StrisciaTempo> {
  late double _span;
  _Gesto _gesto = _Gesto.nessuno;
  double _x0 = 0, _t0 = 0, _span0 = 0, _scala0 = 1;
  TrascinamentoFrase? _trascina;
  bool _agganciato = false;
  double _larghezza = 1;

  ModificaSottotitoli get _m => widget.modifica;
  double get _durata => math.max(0.5, _m.durata);

  @override
  void initState() {
    super.initState();
    _span = math.min(_spanIniziale, math.max(2.0, _durata));
  }

  double _xDi(double t) =>
      _larghezza / 2 + (t - widget.tempo) / _span * _larghezza;

  /// Maniglia della frase scelta sotto [x] (la più vicina), se c'è.
  ParteFrase? _maniglia(double x) {
    final i = widget.scelta;
    if (i < 0 || i >= _m.frasi.length || !_m.frasi[i].sincronizzata) {
      return null;
    }
    final p = _m.frasi[i];
    final di = (x - _xDi(p.inizio!)).abs(), df = (x - _xDi(p.fine!)).abs();
    if (math.min(di, df) > _presa) return null;
    return di <= df ? ParteFrase.inizio : ParteFrase.fine;
  }

  int _bloccoSotto(double x) {
    final f = _m.frasi;
    for (var i = 0; i < f.length; i++) {
      final p = f[i];
      if (p.sincronizzata && _xDi(p.inizio!) <= x && x <= _xDi(p.fine!)) {
        return i;
      }
    }
    return -1;
  }

  void _inizio(ScaleStartDetails d) {
    _x0 = d.localFocalPoint.dx;
    if (d.pointerCount >= 2) {
      _iniziaZoom(1.0);
      return;
    }
    final parte = _maniglia(_x0);
    if (parte != null) {
      _gesto = _Gesto.trascina;
      _trascina = _m.iniziaTrascinamento(widget.scelta, parte);
      _agganciato = false;
      return;
    }
    _gesto = _Gesto.scorri;
    _t0 = widget.tempo;
  }

  void _iniziaZoom(double scala) {
    _gesto = _Gesto.zoom;
    _span0 = _span;
    _scala0 = scala;
  }

  void _aggiorna(ScaleUpdateDetails d) {
    if (d.pointerCount >= 2 && _gesto != _Gesto.trascina) {
      if (_gesto != _Gesto.zoom) _iniziaZoom(d.scale);
      setState(() {
        _span = (_span0 * _scala0 / d.scale).clamp(2.0, math.max(2.0, _durata));
      });
      return;
    }
    final dx = d.localFocalPoint.dx - _x0;
    switch (_gesto) {
      case _Gesto.scorri:
        widget.onScorri((_t0 - dx / _larghezza * _span).clamp(0.0, _durata));
      case _Gesto.trascina:
        final g = _trascina;
        if (g == null) return;
        _m.trascina(
          g,
          dx / _larghezza * _span,
          tolleranza: 12 / _larghezza * _span,
          lettura: widget.tempo,
        );
        final p = _m.frasi[g.indice];
        final bordo = g.parte == ParteFrase.inizio ? p.inizio! : p.fine!;
        final agganciato = _suUnPunto(bordo, g);
        if (agganciato && !_agganciato) HapticFeedback.selectionClick();
        _agganciato = agganciato;
        widget.onModificata();
      case _Gesto.zoom || _Gesto.nessuno:
        break;
    }
  }

  /// Il bordo è finito su una pausa, sul bordo di una frase fissata o sulla linea di lettura.
  bool _suUnPunto(double t, TrascinamentoFrase g) {
    bool vicino(double p) => (p - t).abs() < 6e-4;
    if (vicino(widget.tempo) || _m.punti.any(vicino)) return true;
    for (var j = 0; j < _m.frasi.length; j++) {
      final q = _m.frasi[j];
      if (j != g.indice && j != g.compagna && q.manuale) {
        if (vicino(q.inizio!) || vicino(q.fine!)) return true;
      }
    }
    return false;
  }

  void _fine(ScaleEndDetails d) {
    final era = _gesto;
    _gesto = _Gesto.nessuno;
    _trascina = null;
    if (era == _Gesto.scorri) widget.onScorriFine();
  }

  void _tocco(TapUpDetails d) {
    final x = d.localPosition.dx;
    if (_maniglia(x) != null) return;
    widget.onScegli(_bloccoSotto(x));
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.etichetta,
      value: formatoOrologio(widget.tempo),
      child: LayoutBuilder(
        builder: (context, vincoli) {
          _larghezza = math.max(1.0, vincoli.maxWidth);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: _inizio,
            onScaleUpdate: _aggiorna,
            onScaleEnd: _fine,
            onTapUp: _tocco,
            child: CustomPaint(
              size: Size(vincoli.maxWidth, vincoli.maxHeight),
              painter: _PitturaStriscia(
                frasi: _m.frasi,
                tempo: widget.tempo,
                span: _span,
                durata: _durata,
                inizioTaglio: _m.inizioTaglio,
                fineTaglio: _m.fineTaglio,
                inviluppo: widget.inviluppo,
                scelta: widget.scelta,
                avviso: widget.avviso,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PitturaStriscia extends CustomPainter {
  _PitturaStriscia({
    required this.frasi,
    required this.tempo,
    required this.span,
    required this.durata,
    required this.inizioTaglio,
    required this.fineTaglio,
    required this.inviluppo,
    required this.scelta,
    required this.avviso,
  });

  final List<Frase> frasi;
  final double tempo, span, durata, inizioTaglio, fineTaglio;
  final List<double> inviluppo;
  final int scelta;
  final String? avviso;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    double xDi(double t) => w / 2 + (t - tempo) / span * w;
    double tDi(double x) => tempo + (x - w / 2) / w * span;
    canvas.drawRect(Offset.zero & size, Paint()..color = ColoriScrl.barra);
    // Prima dell'inizio e dopo la fine del video, e fuori dal taglio: più scuro
    final velo = Paint()..color = ColoriScrl.veloEscluso;
    final a = xDi(inizioTaglio), b = xDi(fineTaglio);
    if (a > 0) canvas.drawRect(Rect.fromLTRB(0, 0, a, h), velo);
    if (b < w) canvas.drawRect(Rect.fromLTRB(b, 0, w, h), velo);
    final x0 = xDi(0), x1 = xDi(durata);
    if (x0 > 0) canvas.drawRect(Rect.fromLTRB(0, 0, x0, h), velo);
    if (x1 < w) canvas.drawRect(Rect.fromLTRB(x1, 0, w, h), velo);

    // Righello
    final passo = [
      0.5,
      1.0,
      2.0,
      5.0,
      10.0,
      15.0,
      30.0,
      60.0,
    ].firstWhere((s) => span / s <= 6, orElse: () => 60.0);
    final tacca = Paint()
      ..color = ColoriScrl.testoSpento
      ..strokeWidth = 1;
    var t = (tDi(0) / passo).floorToDouble() * passo;
    while (t <= tDi(w)) {
      if (t >= 0) {
        final x = xDi(t);
        canvas.drawLine(Offset(x, 0), Offset(x, 5), tacca);
        final orologio = formatoOrologio(t);
        _scrivi(
          canvas,
          orologio.substring(0, orologio.length - 3),
          Offset(x + 3, 2),
          ColoriScrl.testoSpento,
          10,
        );
      }
      t += passo;
    }

    // Forma d'onda
    final alto = _righello + 2, basso = h - _fasciaManiglie;
    final mezzo = (alto + basso) / 2, ampiezza = (basso - alto) / 2;
    if (inviluppo.isNotEmpty) {
      final onda = Paint()
        ..color = ColoriScrl.testoSecondario.withValues(alpha: 0.55)
        ..strokeWidth = 1;
      final n = inviluppo.length;
      for (var x = 0; x < w; x++) {
        final i0 = (tDi(x.toDouble()) / passoInviluppo).floor();
        final i1 = math.max(i0 + 1, (tDi(x + 1.0) / passoInviluppo).floor());
        if (i0 >= n || i1 <= 0) continue;
        var v = 0.0;
        for (var i = math.max(0, i0); i < math.min(n, i1); i++) {
          if (inviluppo[i] > v) v = inviluppo[i];
        }
        final y = math.max(0.5, math.min(1.0, v * 1.6) * ampiezza);
        canvas.drawLine(
          Offset(x + 0.5, mezzo - y),
          Offset(x + 0.5, mezzo + y),
          onda,
        );
      }
    } else if (avviso != null) {
      _scrivi(
        canvas,
        avviso!,
        Offset(12, mezzo - 8),
        ColoriScrl.testoSecondario,
        12,
        larghezza: w - 24,
      );
    }

    // Frasi
    for (var i = 0; i < frasi.length; i++) {
      final p = frasi[i];
      if (!p.sincronizzata) continue;
      final xa = xDi(p.inizio!), xb = xDi(p.fine!);
      if (xb < 0 || xa > w) continue;
      final r = RRect.fromRectAndRadius(
        Rect.fromLTRB(xa, alto, math.max(xa + 2, xb), basso),
        const Radius.circular(4),
      );
      final scelta = i == this.scelta;
      // Tempi automatici più tenui, quelli ritoccati a mano pieni
      final alfa = scelta ? (p.auto ? 0.40 : 0.50) : (p.auto ? 0.16 : 0.26);
      canvas.drawRRect(
        r,
        Paint()..color = ColoriScrl.accento.withValues(alpha: alfa),
      );
      canvas.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = scelta ? 2 : 1
          ..color = scelta
              ? ColoriScrl.accentoTesto
              : ColoriScrl.accento.withValues(alpha: p.auto ? 0.5 : 1),
      );
      if (xb - xa > 16) {
        canvas.save();
        canvas.clipRect(Rect.fromLTRB(xa + 4, alto, xb - 4, basso));
        _scrivi(
          canvas,
          p.testo,
          Offset(math.max(xa + 4, 4), alto + 3),
          ColoriScrl.testo,
          12,
          larghezza: math.max(0, xb - math.max(xa + 4, 4) - 4),
        );
        canvas.restore();
      }
    }

    // Maniglie della frase scelta
    if (scelta >= 0 && scelta < frasi.length && frasi[scelta].sincronizzata) {
      final p = frasi[scelta];
      for (final x in [xDi(p.inizio!), xDi(p.fine!)]) {
        if (x < -_presa || x > w + _presa) continue;
        canvas.drawLine(
          Offset(x, alto),
          Offset(x, h - _fasciaManiglie / 2),
          Paint()
            ..color = ColoriScrl.accentoTesto
            ..strokeWidth = 2,
        );
        final centro = Offset(x, h - _fasciaManiglie / 2);
        canvas.drawCircle(centro, 11, Paint()..color = ColoriScrl.accento);
        canvas.drawCircle(
          centro,
          11,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = ColoriScrl.suAccento,
        );
      }
    }

    // Linea di lettura, fissa al centro
    canvas.drawLine(
      Offset(w / 2, 0),
      Offset(w / 2, h),
      Paint()
        ..color = ColoriScrl.pericolo
        ..strokeWidth = 2,
    );
  }

  static void _scrivi(
    Canvas canvas,
    String testo,
    Offset pos,
    Color colore,
    double dimensione, {
    double? larghezza,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: testo,
        style: TextStyle(color: colore, fontSize: dimensione),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: larghezza == null ? null : '…',
    )..layout(maxWidth: larghezza ?? double.infinity);
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(_PitturaStriscia old) =>
      !identical(old.frasi, frasi) ||
      old.tempo != tempo ||
      old.span != span ||
      old.scelta != scelta ||
      !identical(old.inviluppo, inviluppo) ||
      old.avviso != avviso;
}
