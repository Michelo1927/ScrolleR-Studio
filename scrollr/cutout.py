"""
Sagoma di una foto (scontorno a mano): un contorno chiuso di punti in frazioni 0..1 della foto originale
(non specchiata, come il ritaglio). Dentro il contorno la foto si vede, fuori diventa trasparente; il bordo
è sfumato di `soft` (0..100, vedi soft_radius). Qui solo calcoli: maschere, percorsi e riquadro.
"""
import math
from typing import List, Optional, Sequence, Tuple

from PIL import Image, ImageFilter
from PyQt6.QtCore import QPointF, Qt
from PyQt6.QtGui import QColor, QImage, QPainter, QPainterPath, QPolygonF, QTransform

Points = List[Tuple[float, float]]

DEFAULT_SOFT = 15
MAX_SOFT = 100
SOFT_FRACTION = 0.012  # Morbidezza 100 = sfumatura di 1,2% del lato lungo della foto
MIN_POINTS = 3


def clean_cutout(points) -> Optional[Points]:
    """Sagoma valida (almeno 3 punti dentro la foto, area non nulla); altrimenti None."""
    if not points:
        return None
    try:
        pts = [(min(1.0, max(0.0, float(x))), min(1.0, max(0.0, float(y)))) for x, y in points]
    except (TypeError, ValueError):
        return None
    if len(pts) < MIN_POINTS:
        return None
    # Area col metodo dell'allacciamento delle scarpe: una sagoma piatta non serve
    area = 0.0
    for (x0, y0), (x1, y1) in zip(pts, pts[1:] + pts[:1]):
        area += x0 * y1 - x1 * y0
    if abs(area) < 1e-6:
        return None
    return pts


def clean_soft(value) -> int:
    try:
        return max(0, min(MAX_SOFT, int(round(float(value)))))
    except (TypeError, ValueError):
        return DEFAULT_SOFT


def soft_radius(soft: int, img_w: float, img_h: float) -> float:
    """Raggio della sfumatura in pixel per una foto di img_w × img_h: proporzionale alla foto, così il bordo
    è uguale sulla tela (anteprima) e in esportazione (originale)."""
    return max(0.0, soft) / 100.0 * SOFT_FRACTION * max(img_w, img_h)


def cutout_path(points: Sequence[Tuple[float, float]], w: float, h: float) -> QPainterPath:
    """Contorno chiuso in pixel di un'immagine di w × h (coordinate della foto non specchiata)."""
    path = QPainterPath()
    if points:
        path.addPolygon(QPolygonF([QPointF(x * w, y * h) for x, y in points]))
        path.closeSubpath()
    path.setFillRule(Qt.FillRule.WindingFill)
    return path


def bounding_crop(points: Points, soft: int, img_w: float, img_h: float) -> Tuple[float, float, float, float]:
    """Ritaglio stretto attorno alla sagoma, con lo spazio per la sfumatura (frazioni 0..1)."""
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    r = soft_radius(soft, img_w, img_h) * 1.5
    mx, my = r / max(1.0, img_w), r / max(1.0, img_h)
    return (max(0.0, min(xs) - mx), max(0.0, min(ys) - my), min(1.0, max(xs) + mx), min(1.0, max(ys) + my))


def gray_qimage_to_pil(img: QImage) -> Image.Image:
    """QImage in scala di grigi (Format_Grayscale8) → immagine Pillow in modo "L"."""
    ptr = img.constBits()
    ptr.setsize(img.sizeInBytes())
    return Image.frombuffer("L", (img.width(), img.height()), bytes(ptr), "raw", "L", img.bytesPerLine(), 1)


def mask_image(points: Points, soft: int, full_w: float, full_h: float,
               box: Tuple[float, float, float, float], size: Tuple[int, int]) -> Image.Image:
    """
    Maschera (Pillow, modo "L": 255 = si vede) della porzione `box` (sinistra, alto, destra, basso in pixel
    della foto intera full_w × full_h) portata a `size` pixel. Il contorno è antialiasato e sfumato;
    la sfumatura tiene conto anche della sagoma appena fuori dalla porzione.
    """
    out_w, out_h = max(1, int(size[0])), max(1, int(size[1]))
    bw, bh = max(1e-6, box[2] - box[0]), max(1e-6, box[3] - box[1])
    kx, ky = out_w / bw, out_h / bh
    radius = soft_radius(soft, full_w, full_h) * (kx + ky) / 2.0  # In pixel dell'uscita
    pad = int(math.ceil(radius * 3.0)) + 2 if radius > 0.05 else 0
    # Maschere enormi (zoom fortissimo) non servono: la sfumatura si calcola più piccola e si ingrandisce
    limit = 6000
    down = max(1.0, (out_w + 2 * pad) / limit, (out_h + 2 * pad) / limit)
    lw, lh = max(1, round((out_w + 2 * pad) / down)), max(1, round((out_h + 2 * pad) / down))
    img = QImage(lw, lh, QImage.Format.Format_Grayscale8)
    img.fill(0)
    p = QPainter(img)
    p.setRenderHint(QPainter.RenderHint.Antialiasing, True)
    t = QTransform()
    t.scale(1.0 / down, 1.0 / down)
    t.translate(pad, pad)
    t.scale(kx, ky)
    t.translate(-box[0], -box[1])
    p.setTransform(t)
    p.setPen(Qt.PenStyle.NoPen)
    p.setBrush(QColor(255, 255, 255))
    p.drawPath(cutout_path(points, full_w, full_h))
    p.end()
    mask = gray_qimage_to_pil(img)
    if radius > 0.05:
        mask = mask.filter(ImageFilter.GaussianBlur(radius / down / 2.0))
    if down > 1.0:
        mask = mask.resize((out_w + 2 * pad, out_h + 2 * pad), Image.Resampling.BILINEAR)
    if pad:
        mask = mask.crop((pad, pad, pad + out_w, pad + out_h))
    return mask


def apply_mask(img: Image.Image, mask: Image.Image) -> Image.Image:
    """La foto con la maschera come trasparenza (moltiplicata per quella che ha già)."""
    out = img.convert("RGBA")
    if mask.size != out.size:
        mask = mask.resize(out.size, Image.Resampling.BILINEAR)
    alpha = out.getchannel("A")
    if alpha.getextrema() != (255, 255):
        from PIL import ImageChops
        mask = ImageChops.multiply(alpha, mask)
    out.putalpha(mask)
    return out


def cut_image(img: Image.Image, points: Points, soft: int) -> Image.Image:
    """Tutta l'immagine (la foto intera a qualsiasi misura) scontornata."""
    mask = mask_image(points, soft, img.width, img.height, (0.0, 0.0, float(img.width), float(img.height)), img.size)
    return apply_mask(img, mask)


def simplify(points: Points, tolerance: float) -> Points:
    """Meno punti con la stessa forma (Ramer-Douglas-Peucker), per i tratti a mano libera."""
    if len(points) < 3 or tolerance <= 0:
        return list(points)

    def rdp(pts: Points) -> Points:
        a, b = pts[0], pts[-1]
        dx, dy = b[0] - a[0], b[1] - a[1]
        norm = math.hypot(dx, dy)
        best, idx = -1.0, 0
        for i in range(1, len(pts) - 1):
            px, py = pts[i]
            if norm < 1e-12:
                d = math.hypot(px - a[0], py - a[1])
            else:
                d = abs(dy * px - dx * py + b[0] * a[1] - b[1] * a[0]) / norm
            if d > best:
                best, idx = d, i
        if best > tolerance:
            return rdp(pts[:idx + 1])[:-1] + rdp(pts[idx:])
        return [a, b]

    return rdp(list(points))
