/// Disegno di una pagina su una tela `dart:ui` (piano §8.3): **un solo modulo** per lo schermo e per
/// l'esportazione, con gli indicatori [OpzioniDisegno.esportazione] e [OpzioniDisegno.pulito] come
/// `is_exporting` e `clean_render` del desktop.
///
/// Ordine: sfondo → elementi per `z` → numeri di pagina e «scorri». Portato da `scrollr/canvas/scene.py`
/// (`paint_canvas_background`, `paint_page_overlays`) e da `photo_item.py` (ombra, foto, effetti, bordo interno).
/// Il disegno è sincrono: le immagini (già colorate) arrivano pronte da [RisorseDisegno].
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:material_ui/material_ui.dart' show Icons;
import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import '../theme/tokens.dart';
import 'forme.dart';
import 'testo.dart';

/// Immagine pronta di una foto (o del fotogramma di un video): la foto intera, già con le regolazioni colore.
class FotoPronta {
  final ui.Image immagine;

  /// L'originale non c'è più: si vede l'anteprima salvata (a schermo compare il segno «Originale mancante»).
  final bool originaleMancante;
  const FotoPronta(this.immagine, {this.originaleMancante = false});
}

/// Ciò che il disegno legge senza aspettare: immagini delle foto, sfondo sfocato, grana.
abstract class RisorseDisegno {
  /// Immagine pronta della foto, o null se non c'è (foto mancante o non ancora caricata).
  FotoPronta? foto(PhotoItem p);

  /// La foto non è stata trovata (né originale né anteprima): segnaposto «Foto mancante».
  bool mancante(PhotoItem p);

  /// Foto di sfondo già sfocata e scurita (`blurred_background`), o null.
  ui.Image? get sfondoSfocato;

  /// Riquadro della grana (`grain_tile`), o null se non ancora pronto.
  ui.Image? get grana;

  /// Prima/dopo: le foto si vedono senza filtri, regolazioni ed effetti (`scene.show_original`).
  bool get mostraOriginale;
}

/// Etichetta di un video sulla tela: durata del taglio, muto, ▶ o pausa.
class EtichettaVideo {
  final double durata;
  final bool muto;
  final bool inRiproduzione;
  const EtichettaVideo({
    required this.durata,
    required this.muto,
    required this.inRiproduzione,
  });
}

/// Risorse che sanno qualcosa dei video (durata, audio, riproduzione): servono all'etichetta a schermo.
abstract class RisorseVideo {
  /// Etichetta del video [p], o null se non va mostrata (video mancante).
  EtichettaVideo? etichettaVideo(PhotoItem p);
}

/// Testi del disegno che dipendono dalla lingua (dai file `.arb`).
class TestiDisegno {
  /// «Foto mancante».
  final String fotoMancante;

  /// «Originale mancante».
  final String originaleMancante;

  /// Parola del formato «1 di 5» dei numeri di pagina.
  final String di;

  /// «muto», nell'etichetta dei video.
  final String muto;
  const TestiDisegno({
    required this.fotoMancante,
    required this.originaleMancante,
    required this.di,
    this.muto = '',
  });
}

class OpzioniDisegno {
  /// Esportazione (`is_exporting`): niente segnaposto, niente indicazioni a schermo.
  final bool esportazione;

  /// Anteprima pulita (`clean_render`): come a schermo ma senza guide, etichette e selezione.
  final bool pulito;

  /// Esportazione a strati (pagine video): sfondo e numeri di pagina solo dove servono.
  final bool sfondo;
  final bool sovrimpressioni;

  /// Quali elementi disegnare (null = tutti): serve agli strati sotto e sopra i video.
  final bool Function(CanvasElement e)? filtro;
  final TestiDisegno testi;

  const OpzioniDisegno({
    required this.testi,
    this.esportazione = false,
    this.pulito = false,
    this.sfondo = true,
    this.sovrimpressioni = true,
    this.filtro,
  });

  bool get senzaIndicazioni => esportazione || pulito;
}

/// Elementi nell'ordine in cui si disegnano: per `z`, a parità nell'ordine di entrata nella scena
/// (foto, poi testi, poi forme, come li rimette `_restore_snapshot`).
List<CanvasElement> elementiInOrdine(Snapshot s) {
  final l = [...s.allElements];
  final idx = {for (var i = 0; i < l.length; i++) l[i]: i};
  l.sort((a, b) {
    final c = a.z.compareTo(b.z);
    return c != 0 ? c : idx[a]!.compareTo(idx[b]!);
  });
  return l;
}

/// Disegna la pagina [pagina] di [s] su [canvas], a [scala] pixel per unità della tela (la pagina occupa
/// `frameW × scala` per `frameH × scala` a partire dall'origine).
void disegnaPagina(
  ui.Canvas canvas,
  Snapshot s,
  int pagina,
  RisorseDisegno r,
  OpzioniDisegno o, {
  double scala = 1.0,
}) {
  final c = s.canvas;
  final fw = c.frameW.toDouble(), fh = c.frameH.toDouble();
  final paginaRect = ui.Rect.fromLTWH(pagina * fw, 0, fw, fh);
  canvas.save();
  canvas.scale(scala);
  canvas.translate(-pagina * fw, 0);
  canvas.clipRect(paginaRect);
  if (o.sfondo) {
    // L'esportazione parte da un'immagine riempita col colore di sfondo (`img.fill(bg_color)`)
    canvas.drawRect(paginaRect, ui.Paint()..color = ui.Color(c.bgColor));
    _sfondo(canvas, c, r);
  }
  for (final e in elementiInOrdine(s)) {
    if (o.filtro != null && !o.filtro!(e)) continue;
    switch (e) {
      case PhotoItem():
        _foto(canvas, e, r, o, scala, c);
      case TextItem():
        final l = ImpaginazioneTesto.di(e);
        _inPosizione(canvas, e.x, e.y, l.larghezza, l.altezza, e.rotation, () {
          disegnaTesto(canvas, e, l);
        });
      case ShapeItem():
        _inPosizione(canvas, e.x, e.y, e.w, e.h, e.rotation, () {
          disegnaForma(canvas, e);
        });
    }
  }
  if (o.sovrimpressioni) _sovrimpressioni(canvas, c, o.testi);
  canvas.restore();
}

/// Elemento in (x, y), ruotato di [gradi] attorno al centro del suo riquadro w × h (`transformOriginPoint`).
void _inPosizione(
  ui.Canvas canvas,
  double x,
  double y,
  double w,
  double h,
  double gradi,
  void Function() disegna,
) {
  canvas.save();
  canvas.translate(x + w / 2.0, y + h / 2.0);
  if (gradi != 0) canvas.rotate(gradi * math.pi / 180.0);
  canvas.translate(-w / 2.0, -h / 2.0);
  disegna();
  canvas.restore();
}

// ---------------- Sfondo ----------------

/// `paint_canvas_background`: tinta unita, sfumatura o foto sfocata su tutta la tela (tutte le pagine).
void _sfondo(ui.Canvas canvas, CanvasState c, RisorseDisegno r) {
  final rect = ui.Rect.fromLTWH(
    0,
    0,
    c.frameW * c.numFrames.toDouble(),
    c.frameH.toDouble(),
  );
  if (c.bgMode == 'gradient') {
    final fine = switch (c.bgDirection) {
      'horizontal' => rect.topRight,
      'diagonal' => rect.bottomRight,
      _ => rect.bottomLeft,
    };
    canvas.drawRect(
      rect,
      ui.Paint()
        ..shader = ui.Gradient.linear(rect.topLeft, fine, [
          ui.Color(c.bgColor),
          ui.Color(c.bgColor2),
        ]),
    );
    return;
  }
  if (c.bgMode == 'blur') {
    final pm = r.sfondoSfocato;
    if (pm != null && pm.width > 0 && pm.height > 0) {
      // Copre tutta la tela (anche un carosello lungo) tagliando il necessario
      final k = math.max(rect.width / pm.width, rect.height / pm.height);
      final sw = rect.width / k, sh = rect.height / k;
      canvas.drawImageRect(
        pm,
        ui.Rect.fromLTWH((pm.width - sw) / 2.0, (pm.height - sh) / 2.0, sw, sh),
        rect,
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
      return;
    }
  }
  canvas.drawRect(rect, ui.Paint()..color = ui.Color(c.bgColor));
}

// ---------------- Foto ----------------

ui.Color _alfa(ui.Color c, double op) => c.withValues(alpha: c.a * op);

void _foto(
  ui.Canvas canvas,
  PhotoItem p,
  RisorseDisegno r,
  OpzioniDisegno o,
  double scala,
  CanvasState tela,
) {
  // L'opacità della foto vale per ogni pezzo disegnato (ombra, foto, effetti, bordo), come `setOpacity` di Qt
  final op = (p.opacity / 100.0).clamp(0.0, 1.0);
  if (op <= 0) return;
  // Le Polaroid prendono ombra e rilievo dalla disposizione
  final ombra = p.ombraEffettiva(tela);
  if (ombra != p.shadow) p = p.copyWith(shadow: ombra);
  final rilievo = p.rilievo(tela);
  _inPosizione(canvas, p.x, p.y, p.w, p.h, p.rotation, () {
    final cell = ui.Rect.fromLTWH(0, 0, p.w, p.h);
    final radius = p.cornerRadius;
    if (p.shadow > 0) _ombra(canvas, p, radius, op);

    canvas.save();
    if (radius > 0) {
      canvas.clipRRect(ui.RRect.fromRectXY(cell, radius, radius));
    } else {
      canvas.clipRect(cell);
    }
    // Con la cornice (Polaroid, Pellicola) la foto si vede solo nella finestra: mezza unità in più, coperta
    // dalla cornice, così tra foto e cornice non resta un filo chiaro dell'antialiasing
    final fin = p.windowRect();
    final finestra = ui.Rect.fromLTWH(fin.x, fin.y, fin.w, fin.h);
    if (p.frame.isNotEmpty) {
      // Sotto la foto la finestra prende il colore della cornice: sui bordi sfumati non traspare lo sfondo
      canvas.clipRect(finestra.inflate(0.5));
      canvas.drawRect(
        finestra.inflate(0.5),
        ui.Paint()..color = _alfa(ui.Color(frameColors[p.frame]!), op),
      );
    }
    final pronta = r.foto(p);
    final img = pronta?.immagine;
    if (img != null && img.width > 0 && img.height > 0) {
      final src = p.cropRect(img.width.toDouble(), img.height.toDouble());
      final g = p.coverGeometry(src.w, src.h);
      canvas.save();
      canvas.transform(Float64List.fromList(p.imageTransform().toMatrix4()));
      canvas.drawImageRect(
        img,
        ui.Rect.fromLTWH(src.x, src.y, src.w, src.h),
        ui.Rect.fromLTWH(g.dx, g.dy, g.drawW, g.drawH),
        ui.Paint()
          ..color = ui.Color.fromARGB((255 * op).round(), 0, 0, 0)
          ..filterQuality = o.esportazione
              ? ui.FilterQuality.high
              : ui.FilterQuality.medium,
      );
      canvas.restore();
      if (!r.mostraOriginale) _effetti(canvas, p, img, r, op);
    } else if (!o.senzaIndicazioni && r.mancante(p)) {
      _segnapostoMancante(canvas, p, o.testi.fotoMancante);
    }
    if (rilievo > 0) _rilievoFinestra(canvas, p, finestra, rilievo, op);
    canvas.restore();
    if (p.frame.isNotEmpty) _cornice(canvas, p, cell, radius, finestra, op);
    if (rilievo > 0) {
      _rilievoCartoncino(canvas, p, cell, radius, finestra, rilievo, op);
    }

    // Bordo interno: non sborda nel gap e non viene tagliato ai margini della tela
    if (p.borderWidth > 0) {
      final bw = math.min(p.borderWidth, math.min(p.w / 2.0, p.h / 2.0));
      final inner = cell.deflate(bw / 2.0);
      final ir = math.max(0.0, radius - bw / 2.0);
      canvas.drawRRect(
        ui.RRect.fromRectXY(inner, ir, ir),
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = bw
          ..strokeJoin = ir == 0 ? ui.StrokeJoin.miter : ui.StrokeJoin.round
          ..color = _alfa(ui.Color(p.borderColor), op),
      );
    }
    if (!o.senzaIndicazioni && pronta != null && pronta.originaleMancante) {
      _segnoOriginaleMancante(canvas, p, o.testi.originaleMancante);
    }
    if (!o.senzaIndicazioni && p.isVideo && r is RisorseVideo) {
      final e = (r as RisorseVideo).etichettaVideo(p);
      if (e != null) _etichettaVideo(canvas, p, e, o.testi.muto, scala);
    }
  });
}

/// `_paint_frame`: cartoncino Polaroid o pellicola intorno alla finestra; i fori lasciano vedere quello che
/// c'è sotto.
void _cornice(
  ui.Canvas canvas,
  PhotoItem p,
  ui.Rect cell,
  double radius,
  ui.Rect finestra,
  double op,
) {
  final path = ui.Path()..fillType = ui.PathFillType.evenOdd;
  if (radius > 0) {
    path.addRRect(ui.RRect.fromRectXY(cell, radius, radius));
  } else {
    path.addRect(cell);
  }
  path.addRect(finestra);
  for (final foro in p.filmHoles()) {
    final rr = (p.frame == 'film' ? foro.w : foro.h) * 0.22;
    path.addRRect(
      ui.RRect.fromRectXY(
        ui.Rect.fromLTWH(foro.x, foro.y, foro.w, foro.h),
        rr,
        rr,
      ),
    );
  }
  canvas.drawPath(
    path,
    ui.Paint()..color = _alfa(ui.Color(frameColors[p.frame]!), op),
  );
}

ui.Color _nero(int a, double op) =>
    ui.Color.fromARGB((a * op).round(), 0, 0, 0);
ui.Color _bianco(int a, double op) =>
    ui.Color.fromARGB((a * op).round(), 255, 255, 255);

/// `_paint_depth_window`: rilievo dentro la finestra della Polaroid. Riflesso lucido in diagonale e ombra del
/// cartoncino sulla foto (in alto e a sinistra), così la foto sembra incassata sotto il bordo.
void _rilievoFinestra(
  ui.Canvas canvas,
  PhotoItem p,
  ui.Rect win,
  double d,
  double op,
) {
  if (win.isEmpty) return;
  canvas.drawRect(
    win,
    ui.Paint()
      ..shader = ui.Gradient.linear(
        win.topLeft,
        win.bottomRight,
        [_bianco(alfaRilievo(0.18, d), op), _bianco(0, op), _bianco(0, op)],
        const [0.0, 0.45, 1.0],
      ),
  );
  final s = 0.045 * math.min(p.w, p.h);
  canvas.drawRect(
    ui.Rect.fromLTWH(win.left, win.top, win.width, s),
    ui.Paint()
      ..shader = ui.Gradient.linear(
        ui.Offset(0, win.top),
        ui.Offset(0, win.top + s),
        [_nero(alfaRilievo(0.45, d), op), _nero(0, op)],
      ),
  );
  canvas.drawRect(
    ui.Rect.fromLTWH(win.left, win.top, s, win.height),
    ui.Paint()
      ..shader = ui.Gradient.linear(
        ui.Offset(win.left, 0),
        ui.Offset(win.left + s, 0),
        [_nero(alfaRilievo(0.30, d), op), _nero(0, op)],
      ),
  );
}

/// `_paint_depth_card`: rilievo sul cartoncino della Polaroid. Luce dall'alto a sinistra (più scuro verso il
/// basso a destra) e fili sottili sul bordo esterno e su quello della finestra: lo spessore della carta.
void _rilievoCartoncino(
  ui.Canvas canvas,
  PhotoItem p,
  ui.Rect cell,
  double radius,
  ui.Rect win,
  double d,
  double op,
) {
  final card = ui.Path()..fillType = ui.PathFillType.evenOdd;
  if (radius > 0) {
    card.addRRect(ui.RRect.fromRectXY(cell, radius, radius));
  } else {
    card.addRect(cell);
  }
  card.addRect(win);
  canvas.drawPath(
    card,
    ui.Paint()
      ..shader = ui.Gradient.linear(ui.Offset.zero, ui.Offset(p.w, p.h), [
        _nero(0, op),
        _nero(alfaRilievo(0.10, d), op),
      ]),
  );
  final e = p.spessoreRilievo;
  final filo = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = e
    ..strokeJoin = ui.StrokeJoin.miter
    ..color = _nero(alfaRilievo(0.22, d), op);
  canvas.drawRect(win, filo);
  filo.color = _nero(alfaRilievo(0.20, d), op);
  final bordo = ui.Rect.fromLTWH(e / 2.0, e / 2.0, p.w - e, p.h - e);
  if (radius > 0) {
    final r = math.max(0.0, radius - e / 2.0);
    canvas.drawRRect(ui.RRect.fromRectXY(bordo, r, r), filo);
  } else {
    canvas.drawRect(bordo, filo);
  }
}

/// `_paint_badge`: etichetta in alto a sinistra con ▶ (o pausa) e durata del taglio, a misura costante sullo
/// schermo ([scala] = pixel per unità della tela). Non compare se il riquadro è troppo piccolo per contenerla.
void _etichettaVideo(
  ui.Canvas canvas,
  PhotoItem p,
  EtichettaVideo e,
  String muto,
  double scala,
) {
  final k = 1.0 / math.max(1e-6, scala);
  var testo = formatoTempo(e.durata);
  if (e.muto && muto.isNotEmpty) testo += '  $muto';
  final tp = TextPainter(
    text: TextSpan(
      text: testo,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: TestoScrl.marcato,
        color: ColoriScrl.suAccento,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  const h = 18.0;
  final w = 22.0 + tp.width + 8.0;
  if (w * k > p.w - 8 * k || h * k > p.h - 8 * k) return;
  canvas.save();
  canvas.translate(6 * k, 6 * k);
  canvas.scale(k, k);
  canvas.drawRRect(
    ui.RRect.fromRectXY(ui.Rect.fromLTWH(0, 0, w, h), h / 2.0, h / 2.0),
    ui.Paint()..color = ColoriScrl.veloEtichetta,
  );
  final bianco = ui.Paint()..color = ColoriScrl.suAccento;
  if (e.inRiproduzione) {
    canvas.drawRect(const ui.Rect.fromLTWH(8.0, 5.0, 2.6, 8.0), bianco);
    canvas.drawRect(const ui.Rect.fromLTWH(12.4, 5.0, 2.6, 8.0), bianco);
  } else {
    canvas.drawPath(
      ui.Path()
        ..moveTo(8.0, 4.5)
        ..lineTo(15.5, 9.0)
        ..lineTo(8.0, 13.5)
        ..close(),
      bianco,
    );
  }
  tp.paint(canvas, ui.Offset(20.0, (h - tp.height) / 2.0));
  canvas.restore();
}

/// `_paint_shadow`: ombra morbida, 12 rettangoli arrotondati sempre più piccoli e trasparenti.
void _ombra(ui.Canvas canvas, PhotoItem p, double radius, double op) {
  final ext = p.shadowExtent;
  const steps = 12;
  final paint = ui.Paint()
    ..color = ui.Color.fromARGB((p.shadowAlpha * op).round(), 0, 0, 0);
  final off = ext * 0.35;
  for (var i = 0; i < steps; i++) {
    final g = ext * (1.0 - i / steps) * 0.6;
    canvas.drawRRect(
      ui.RRect.fromRectXY(
        ui.Rect.fromLTWH(-g, -g + off, p.w + 2 * g, p.h + 2 * g),
        radius + g,
        radius + g,
      ),
      paint,
    );
  }
}

/// `_paint_effects`: vignettatura e grana sopra la parte visibile della foto, in misure della tela.
void _effetti(
  ui.Canvas canvas,
  PhotoItem p,
  ui.Image img,
  RisorseDisegno r,
  double op,
) {
  final vignette = adjValue(p.adjust, 'vignette');
  final grain = adjValue(p.adjust, 'grain');
  if (vignette == 0 && grain == 0) return;
  final a = p.visibleImageRect(img.width, img.height);
  if (a.w <= 0 || a.h <= 0) return;
  final area = ui.Rect.fromLTWH(a.x, a.y, a.w, a.h);
  if (vignette != 0) {
    // Ellisse che tocca gli angoli: bordi più scuri (−) o più chiari (+), centro intatto
    final forza = math.min(1.0, vignette.abs() / 100.0);
    final base = vignette < 0
        ? const ui.Color(0xFF000000)
        : const ui.Color(0xFFFFFFFF);
    const stops = [0.0, 0.42, 0.72, 1.0];
    const ks = [0.0, 0.0, 0.38, 0.9];
    canvas.save();
    canvas.translate(area.center.dx, area.center.dy);
    canvas.scale(area.width / 2.0 * math.sqrt2, area.height / 2.0 * math.sqrt2);
    canvas.drawRect(
      const ui.Rect.fromLTWH(-1, -1, 2, 2),
      ui.Paint()
        ..shader = ui.Gradient.radial(ui.Offset.zero, 1.0, [
          for (final k in ks) base.withValues(alpha: forza * k * op),
        ], stops),
    );
    canvas.restore();
  }
  final tile = r.grana;
  if (grain != 0 && tile != null) {
    final m = Matrix4Scala.scala(1.3); // Un granello ≈ 1,3 px della tela
    canvas.drawRect(
      area,
      ui.Paint()
        ..blendMode = ui.BlendMode.overlay
        ..color = ui.Color.fromARGB(
          (255 * math.min(1.0, grain / 100.0) * 0.6 * op).round(),
          0,
          0,
          0,
        )
        ..shader = ui.ImageShader(
          tile,
          ui.TileMode.repeated,
          ui.TileMode.repeated,
          m,
        ),
    );
  }
}

/// Matrice 4×4 di una scala uniforme (per i motivi ripetuti).
abstract final class Matrix4Scala {
  static Float64List scala(double k) => Float64List.fromList([
    k, 0, 0, 0, //
    0, k, 0, 0, //
    0, 0, 1, 0, //
    0, 0, 0, 1,
  ]);
}

/// `_paint_missing`: segnaposto di una foto non trovata, tiene il posto e ricorda il nome del file.
void _segnapostoMancante(ui.Canvas canvas, PhotoItem p, String etichetta) {
  final cell = ui.Rect.fromLTWH(0, 0, p.w, p.h);
  canvas.drawRect(cell, ui.Paint()..color = ColoriScrl.rilievo);
  final bordo = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..color = ColoriScrl.testoSecondario;
  final r = cell.deflate(1);
  final contorno = ui.Path()..addRect(r);
  for (final m in contorno.computeMetrics()) {
    for (var d = 0.0; d < m.length; d += 9) {
      canvas.drawPath(m.extractPath(d, math.min(d + 6, m.length)), bordo);
    }
  }
  final side = math.min(p.w, p.h);
  final icona = math.max(24.0, side * 0.16);
  final c = cell.center;
  final tpIcona = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(Icons.image_outlined.codePoint),
      style: TextStyle(
        fontFamily: Icons.image_outlined.fontFamily,
        package: Icons.image_outlined.fontPackage,
        fontSize: icona,
        color: ColoriScrl.testoSecondario,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tpIcona.paint(canvas, ui.Offset(c.dx - icona / 2.0, c.dy - icona * 1.1));
  final px = math.max(12.0, math.min(56.0, side * 0.065));
  final nome = p.asset?.name.isNotEmpty == true
      ? p.asset!.name
      : baseName(p.path);
  final tp = TextPainter(
    text: TextSpan(
      text: '$etichetta\n$nome',
      style: TextStyle(fontSize: px, color: ColoriScrl.testo),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
    maxLines: 2,
    ellipsis: '…',
  )..layout(maxWidth: math.max(1.0, p.w - 16));
  tp.paint(canvas, ui.Offset(c.dx - tp.width / 2.0, c.dy + icona * 0.1));
}

/// Segno «Originale mancante» (solo a schermo): la foto si vede dall'anteprima salvata.
void _segnoOriginaleMancante(ui.Canvas canvas, PhotoItem p, String etichetta) {
  final px = math.max(12.0, math.min(40.0, math.min(p.w, p.h) * 0.05));
  final tp = TextPainter(
    text: TextSpan(
      text: etichetta,
      style: TextStyle(fontSize: px, color: ColoriScrl.suAccento),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: math.max(1.0, p.w - px * 2));
  final box = ui.Rect.fromLTWH(
    px * 0.5,
    px * 0.5,
    tp.width + px,
    tp.height + px * 0.5,
  );
  canvas.drawRRect(
    ui.RRect.fromRectXY(box, box.height / 2, box.height / 2),
    ui.Paint()..color = ColoriScrl.pericolo,
  );
  tp.paint(canvas, ui.Offset(box.left + px * 0.5, box.top + px * 0.25));
}

// ---------------- Numeri di pagina e «scorri» ----------------

/// `page_number_text`.
String testoNumeroPagina(CanvasState c, int i, String di) {
  final n = c.numFrames;
  return switch (c.pageNumberFormat) {
    'of' => '${i + 1} $di $n',
    'plain' => '${i + 1}',
    'padded' =>
      '${(i + 1).toString().padLeft(2, '0')}/${n.toString().padLeft(2, '0')}',
    _ => '${i + 1}/$n',
  };
}

/// `paint_page_overlays`: numero di pagina e «Scorri →», disegnati sopra tutto ed esportati con le pagine.
void _sovrimpressioni(ui.Canvas canvas, CanvasState c, TestiDisegno testi) {
  if (!(c.pageNumbers || c.swipeHint)) return;
  // Carattere: il 3% del lato corto della pagina, semigrassetto
  final size = math
      .max(8, pyRound(math.min(c.frameW, c.frameH) * 0.03))
      .toDouble();
  final n = c.numFrames;
  for (var i = 0; i < n; i++) {
    final page = ui.Rect.fromLTWH(
      i * c.frameW.toDouble(),
      0,
      c.frameW.toDouble(),
      c.frameH.toDouble(),
    );
    var lift = 0.0;
    final swipe = c.swipeText.trim();
    if (c.swipeHint && i < n - 1 && swipe.isNotEmpty) {
      final h = _etichetta(canvas, c, page, swipe, c.swipePos, size);
      lift = c.pageNumberPos == c.swipePos ? h + size * 0.5 : 0.0;
    }
    if (c.pageNumbers && n > 1) {
      _etichetta(
        canvas,
        c,
        page,
        testoNumeroPagina(c, i, testi.di),
        c.pageNumberPos,
        size,
        lift,
      );
    }
  }
}

/// `_overlay_badge`: etichetta arrotondata con [testo] nella posizione [pos]; restituisce l'altezza.
double _etichetta(
  ui.Canvas canvas,
  CanvasState c,
  ui.Rect page,
  String testo,
  String pos,
  double size, [
  double lift = 0.0,
]) {
  TextPainter painter(ui.Color colore) => TextPainter(
    text: TextSpan(
      text: testo,
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: colore,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  final light = c.overlayStyle == 'light';
  final plain = c.overlayStyle == 'plain';
  final tp = painter(
    plain || !light ? const ui.Color(0xFFFFFFFF) : const ui.Color(0xFF1A1A1A),
  );
  final padX = size * 0.75, padY = size * 0.38;
  final w = tp.width + 2 * padX;
  final h = tp.height + 2 * padY;
  final margin = math.min(page.width, page.height) * 0.04;
  final vert = pos.isNotEmpty ? pos[0] : 'b';
  final horiz = pos.length > 1 ? pos[1] : 'c';
  final x = switch (horiz) {
    'l' => page.left + margin,
    'c' => page.center.dx - w / 2.0,
    _ => page.right - margin - w,
  };
  final y = switch (vert) {
    't' => page.top + margin + lift,
    'c' => page.center.dy - h / 2.0 - lift,
    _ => page.bottom - margin - h - lift,
  };
  final box = ui.Rect.fromLTWH(x, y, w, h);
  final dentro = ui.Offset(
    box.center.dx - tp.width / 2.0,
    box.center.dy - tp.height / 2.0,
  );
  if (plain) {
    // Solo testo: bianco con un'ombra leggera, leggibile sulle foto
    final off = math.max(1.0, size * 0.06);
    painter(const ui.Color.fromARGB(120, 0, 0, 0))
        .paint(canvas, dentro + ui.Offset(off, off));
  } else {
    canvas.drawRRect(
      ui.RRect.fromRectXY(box, h / 2.0, h / 2.0),
      ui.Paint()
        ..color = light
            ? const ui.Color.fromARGB(225, 255, 255, 255)
            : const ui.Color.fromARGB(140, 0, 0, 0),
    );
  }
  tp.paint(canvas, dentro);
  return h;
}
