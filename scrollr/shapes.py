"""Forme grafiche (rettangoli, frecce, stelle…): elenco e geometria, usati dalla tela e dalle icone."""
import math

from PyQt6.QtCore import QPointF, QRectF
from PyQt6.QtGui import QPainterPath, QPolygonF

# (chiave, nome nel menu). Le prime sono forme piene, le ultime linee (vedi LINE_KINDS)
SHAPE_KINDS = [
    ("rect", "Rettangolo"),
    ("ellipse", "Ellisse"),
    ("triangle", "Triangolo"),
    ("diamond", "Rombo"),
    ("star", "Stella"),
    ("heart", "Cuore"),
    ("line", "Linea"),
    ("arrow", "Freccia"),
    ("double_arrow", "Doppia freccia"),
]
SHAPE_NAMES = dict(SHAPE_KINDS)
# Linee e frecce: si allungano tirando i due estremi, hanno solo il colore del tratto
LINE_KINDS = ("line", "arrow", "double_arrow")

# Cuore in coordinate 0..1: punta in basso, due lobi in alto (curve di Bézier)
_HEART = (
    ((0.15, 0.72), (0.0, 0.52), (0.0, 0.30)),
    ((0.0, 0.12), (0.13, 0.0), (0.28, 0.0)),
    ((0.40, 0.0), (0.47, 0.07), (0.5, 0.17)),
    ((0.53, 0.07), (0.60, 0.0), (0.72, 0.0)),
    ((0.87, 0.0), (1.0, 0.12), (1.0, 0.30)),
    ((1.0, 0.52), (0.85, 0.72), (0.5, 1.0)),
)


def shape_path(kind: str, rect: QRectF, radius: float = 0.0) -> QPainterPath:
    """Contorno di una forma piena che riempie `rect` (radius = angoli arrotondati del rettangolo)."""
    x, y, w, h = rect.x(), rect.y(), rect.width(), rect.height()
    path = QPainterPath()
    if kind == "ellipse":
        path.addEllipse(rect)
    elif kind == "triangle":
        path.addPolygon(QPolygonF([QPointF(x + w / 2.0, y), QPointF(x + w, y + h), QPointF(x, y + h)]))
        path.closeSubpath()
    elif kind == "diamond":
        path.addPolygon(QPolygonF([QPointF(x + w / 2.0, y), QPointF(x + w, y + h / 2.0),
                                   QPointF(x + w / 2.0, y + h), QPointF(x, y + h / 2.0)]))
        path.closeSubpath()
    elif kind == "star":
        cx, cy = x + w / 2.0, y + h / 2.0
        pts = []
        for i in range(10):
            r = 1.0 if i % 2 == 0 else 0.42
            a = math.radians(-90 + i * 36)
            pts.append(QPointF(cx + r * w / 2.0 * math.cos(a), cy + r * h / 2.0 * math.sin(a)))
        path.addPolygon(QPolygonF(pts))
        path.closeSubpath()
    elif kind == "heart":
        path.moveTo(x + 0.5 * w, y + h)
        for (ax, ay), (bx, by), (cx, cy) in _HEART:
            path.cubicTo(x + ax * w, y + ay * h, x + bx * w, y + by * h, x + cx * w, y + cy * h)
        path.closeSubpath()
    else:  # "rect"
        r = max(0.0, min(radius, w / 2.0, h / 2.0))
        path.addRoundedRect(rect, r, r)
    return path


def arrow_head_size(width: float) -> float:
    """Lunghezza (e larghezza) della punta di una freccia con tratto di spessore `width`."""
    return max(1.0, width) * 3.0 + 10.0
