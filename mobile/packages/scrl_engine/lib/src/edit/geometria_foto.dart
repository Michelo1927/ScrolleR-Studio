/// Geometria del disegno di una foto, portata da `scrollr/canvas/photo_item.py` (e `video_item.py`):
/// ritaglio, «cover»/«contain» con zoom, spostamento e rotazione interni, ombra, risoluzione da leggere.
///
/// Tutto in coordinate della cella (origine nell'angolo in alto a sinistra, prima della rotazione dell'elemento);
/// l'app usa questi numeri per disegnare su `dart:ui`, in modo identico per lo schermo e per l'esportazione.
library;

import 'dart:math' as math;

import '../model/elements.dart';
import '../util/py.dart';

/// Risultato di `_cover_geometry`: scala e rettangolo (dx, dy, drawW, drawH) nel sistema di
/// [GeometriaFoto.imageTransform] (origine al centro della cella, assi ruotati e specchiati).
typedef CoverGeometry = ({
  double scale,
  double dx,
  double dy,
  double drawW,
  double drawH,
});

/// Trasformazione affine 2D `x' = a·x + c·y + e`, `y' = b·x + d·y + f` (come `QTransform` senza prospettiva).
class Affine {
  final double a, b, c, d, e, f;
  const Affine(this.a, this.b, this.c, this.d, this.e, this.f);

  (double, double) map(double x, double y) =>
      (a * x + c * y + e, b * x + d * y + f);

  /// Ingombro del rettangolo trasformato (`QTransform.mapRect`).
  Rect mapRect(Rect r) {
    final pts = [
      map(r.left, r.top),
      map(r.right, r.top),
      map(r.left, r.bottom),
      map(r.right, r.bottom),
    ];
    final xs = pts.map((p) => p.$1), ys = pts.map((p) => p.$2);
    final x0 = xs.reduce(math.min), y0 = ys.reduce(math.min);
    return Rect(x0, y0, xs.reduce(math.max) - x0, ys.reduce(math.max) - y0);
  }

  /// Le sei componenti come matrice 4×4 per colonne (quella che vuole `Canvas.transform`).
  List<double> toMatrix4() => [
    a, b, 0, 0, //
    c, d, 0, 0, //
    0, 0, 1, 0, //
    e, f, 0, 1,
  ];
}

/// Intersezione di due rettangoli (vuoto = larghezza o altezza 0).
Rect intersectRect(Rect a, Rect b) {
  final l = math.max(a.left, b.left), t = math.max(a.top, b.top);
  final r = math.min(a.right, b.right), btm = math.min(a.bottom, b.bottom);
  if (r <= l || btm <= t) return Rect(l, t, 0, 0);
  return Rect(l, t, r - l, btm - t);
}

extension GeometriaFoto on PhotoItem {
  /// `_crop_rect`: parte ritagliata in pixel di un'immagine img_w × img_h (foto non specchiata).
  Rect cropRect(double imgW, double imgH) => Rect(
    crop[0] * imgW,
    crop[1] * imgH,
    (crop[2] - crop[0]) * imgW,
    (crop[3] - crop[1]) * imgH,
  );

  /// `_rotated_cell_extent`: ingombro della cella nel sistema ruotato dell'immagine.
  (double, double) rotatedCellExtent() {
    final th = innerRotation * math.pi / 180.0;
    final c = math.cos(th).abs(), s = math.sin(th).abs();
    return (w * c + h * s, w * s + h * c);
  }

  /// `_image_transform`: dal sistema dell'immagine (origine al centro, assi ruotati) alla cella.
  Affine imageTransform() {
    final th = innerRotation * math.pi / 180.0;
    final cs = math.cos(th), sn = math.sin(th);
    final sx = flipH ? -1.0 : 1.0, sy = flipV ? -1.0 : 1.0;
    // translate(w/2, h/2) · rotate(θ) · scale(sx, sy)
    return Affine(cs * sx, sn * sx, -sn * sy, cs * sy, w / 2.0, h / 2.0);
  }

  /// `_cover_geometry`: scala e rettangolo di disegno per «cover» (riempie) o «contain» (foto intera),
  /// con zoom, spostamento e rotazione interni. La foto ruotata copre sempre l'intera cella.
  CoverGeometry coverGeometry(double imgW0, double imgH) {
    final imgW = imgW0 * stretch;
    final (needW, needH) = rotatedCellExtent();
    double scaleCover;
    if (fitMode == 'contain') {
      final th = innerRotation * math.pi / 180.0;
      final c = math.cos(th).abs(), s = math.sin(th).abs();
      final boxW = imgW * c + imgH * s, boxH = imgW * s + imgH * c;
      scaleCover = math.min(w / boxW, h / boxH) * innerZoom;
    } else {
      scaleCover = math.max(needW / imgW, needH / imgH) * innerZoom;
    }
    final drawW = imgW * scaleCover;
    final drawH = imgH * scaleCover;
    final maxDx = math.max(0.0, (drawW - needW) / 2.0);
    final maxDy = math.max(0.0, (drawH - needH) / 2.0);
    return (
      scale: scaleCover,
      dx: -drawW / 2.0 + panX * maxDx,
      dy: -drawH / 2.0 + panY * maxDy,
      drawW: drawW,
      drawH: drawH,
    );
  }

  /// Geometria per un'immagine di img_w × img_h pixel (la parte ritagliata).
  CoverGeometry coverFor(int imgW, int imgH) {
    final src = cropRect(imgW.toDouble(), imgH.toDouble());
    return coverGeometry(src.w, src.h);
  }

  /// `_visible_image_rect`: parte della cella coperta dalla foto (con «contain» resta fuori lo spazio vuoto).
  Rect visibleImageRect(int imgW, int imgH) {
    final cell = Rect(0, 0, w, h);
    if (imgW <= 0 || imgH <= 0) return cell;
    final g = coverFor(imgW, imgH);
    return intersectRect(
      imageTransform().mapRect(Rect(g.dx, g.dy, g.drawW, g.drawH)),
      cell,
    );
  }

  /// Raggio effettivo degli angoli (`min(border_radius, w/2, h/2)`).
  double get cornerRadius => math.min(borderRadius, math.min(w / 2.0, h / 2.0));

  /// `_shadow_extent`.
  double get shadowExtent => shadow <= 0 ? 0.0 : math.min(w, h) * 0.05 + 8.0;

  /// Opacità (0..255) di ciascuno dei 12 rettangoli dell'ombra (`_paint_shadow`).
  int get shadowAlpha =>
      math.max(1, math.min(255, pyRound(255 * (shadow / 100.0) * 0.075)));

  /// `_needs_sharp`: la foto è mostrata più grande dell'anteprima (oltre il 115% dei suoi pixel).
  /// [pixelPerUnita] = zoom della vista × densità dello schermo.
  bool needsSharp(int previewW, int previewH, double pixelPerUnita) {
    if (previewW <= 0 || previewH <= 0) return false;
    final src = cropRect(previewW.toDouble(), previewH.toDouble());
    final g = coverGeometry(src.w, src.h);
    final enlarge = math.max(
      g.drawW / math.max(1e-6, src.w),
      g.drawH / math.max(1e-6, src.h),
    );
    return enlarge * pixelPerUnita > 1.15;
  }

  /// `export_side`: lato lungo (px) a cui leggere l'originale per esportare a [outScale] pixel per
  /// unità della tela (la foto intera disegnata, con un po' di margine). Null se la misura non è nota.
  int? exportSide(int previewW, int previewH, double outScale) {
    if (previewW <= 0 || previewH <= 0) return null;
    final src = cropRect(previewW.toDouble(), previewH.toDouble());
    final g = coverGeometry(src.w, src.h);
    final wholeW = g.drawW / math.max(1e-6, crop[2] - crop[0]);
    final wholeH = g.drawH / math.max(1e-6, crop[3] - crop[1]);
    final longSide = math.max(previewW, previewH);
    final need = math.max(
      wholeW * longSide / previewW,
      wholeH * longSide / previewH,
    );
    return math.max(64, (need * outScale * 1.1).ceil());
  }

  /// `export_frame_size` (video): misura a cui leggere i fotogrammi perché la parte visibile vada 1:1
  /// sui pixel dell'MP4. Null se servirebbe un'immagine enorme.
  ({int w, int h})? exportFrameSize(int previewW, int previewH, double px) {
    if (previewW <= 0 || previewH <= 0) return null;
    final src = cropRect(previewW.toDouble(), previewH.toDouble());
    final g = coverGeometry(src.w, src.h);
    final fw = pyRound(
      g.drawW /
          math.max(1e-6, stretch) /
          math.max(1e-6, crop[2] - crop[0]) *
          px,
    );
    final fh = pyRound(g.drawH / math.max(1e-6, crop[3] - crop[1]) * px);
    if (fw < 2 || fh < 2 || fw * fh > 24000000) return null;
    return (w: fw, h: fh);
  }
}

/// Video: fine del taglio (`clip_end`), data la durata in secondi (0 = sconosciuta).
double clipEnd(PhotoItem v, double duration) {
  var end = v.trimEnd ?? duration;
  if (duration > 0) end = math.min(end, duration);
  return math.max(v.trimStart + 0.1, end);
}

/// Video: durata del taglio (`clip_length`).
double clipLength(PhotoItem v, double duration) =>
    math.max(0.1, clipEnd(v, duration) - v.trimStart);
