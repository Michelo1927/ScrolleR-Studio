"""Icone disegnate a codice (nessun file esterno), miniature e badge."""
import math
from typing import Dict, Optional

from PyQt6.QtCore import Qt, QRectF, QPointF
from PyQt6.QtGui import QPixmap, QPainter, QPen, QColor, QBrush, QPainterPath, QIcon, QPolygonF, QConicalGradient

from scrollr.shapes import LINE_KINDS, shape_path
from scrollr.theme import THEME


# ================= ICONE DISEGNATE (nessun file esterno) =================
# Schemi degli stili Mosaico (coordinate su 24×24; True = foto in evidenza, riempita)
MOSAIC_ICON_CELLS = {
    "auto": ((4, 4, 16, 9, True), (4, 15, 7, 5, False), (13, 15, 7, 5, False)),
    "top": ((4, 4, 16, 9, True), (4, 15, 7, 5, False), (13, 15, 7, 5, False)),
    "bottom": ((4, 11, 16, 9, True), (4, 4, 7, 5, False), (13, 4, 7, 5, False)),
    "left": ((4, 4, 9, 16, True), (15, 4, 5, 7, False), (15, 13, 5, 7, False)),
    "right": ((11, 4, 9, 16, True), (4, 4, 5, 7, False), (4, 13, 5, 7, False)),
    "center": ((8.5, 4, 7, 16, True), (3, 4, 3.8, 7.2, False), (3, 12.8, 3.8, 7.2, False),
               (17.2, 4, 3.8, 7.2, False), (17.2, 12.8, 3.8, 7.2, False)),
    "two": ((4, 4, 7.5, 10, True), (12.5, 4, 7.5, 10, True), (4, 16, 4.6, 4, False),
            (9.7, 16, 4.6, 4, False), (15.4, 16, 4.6, 4, False)),
    "masonry": ((4, 4, 4.6, 9, True), (4, 15, 4.6, 5, False), (9.7, 4, 4.6, 5, False),
                (9.7, 11, 4.6, 9, False), (15.4, 4, 4.6, 7, False), (15.4, 13, 4.6, 7, False)),
}


def icon_pixmap(name: str, color: str, size: int) -> QPixmap:
    pm = QPixmap(size * 2, size * 2)
    pm.setDevicePixelRatio(2.0)
    pm.fill(Qt.GlobalColor.transparent)
    p = QPainter(pm)
    p.setRenderHint(QPainter.RenderHint.Antialiasing, True)
    p.scale(size / 24.0, size / 24.0)

    col = QColor(color)
    pen = QPen(col, 1.7)
    pen.setCapStyle(Qt.PenCapStyle.RoundCap)
    pen.setJoinStyle(Qt.PenJoinStyle.RoundJoin)
    p.setPen(pen)
    p.setBrush(Qt.BrushStyle.NoBrush)
    tint = QColor(col)
    tint.setAlphaF(0.30)

    def rr(x, y, w, h, r=1.6, brush=None):
        p.setBrush(brush if brush is not None else Qt.BrushStyle.NoBrush)
        p.drawRoundedRect(QRectF(x, y, w, h), r, r)
        p.setBrush(Qt.BrushStyle.NoBrush)

    def poly(*pts):
        p.drawPolyline(QPolygonF([QPointF(a, b) for a, b in pts]))

    def line(x1, y1, x2, y2):
        p.drawLine(QPointF(x1, y1), QPointF(x2, y2))

    def clear(x, y, w, h):
        p.setCompositionMode(QPainter.CompositionMode.CompositionMode_Clear)
        p.fillRect(QRectF(x - 1.4, y - 1.4, w + 2.8, h + 2.8), Qt.GlobalColor.black)
        p.setCompositionMode(QPainter.CompositionMode.CompositionMode_SourceOver)

    def arc_arrow(start, span):
        cx, cy, r = 12.0, 12.5, 7.0
        p.drawArc(QRectF(cx - r, cy - r, 2 * r, 2 * r), int(start * 16), int(span * 16))
        th = math.radians(start + span)
        tip = QPointF(cx + r * math.cos(th), cy - r * math.sin(th))
        s = 1.0 if span > 0 else -1.0
        dx, dy = s * -math.sin(th), s * -math.cos(th)  # Direzione di percorrenza dell'arco
        for a in (math.radians(40), math.radians(-40)):
            bx = -dx * math.cos(a) + dy * math.sin(a)
            by = -dx * math.sin(a) - dy * math.cos(a)
            p.drawLine(tip, tip + QPointF(bx * 4.2, by * 4.2))

    if name == "grid":
        for x, y in ((4, 4), (13, 4), (4, 13), (13, 13)):
            rr(x, y, 7, 7, brush=tint)
    elif name == "mosaic":
        rr(4, 4, 16, 9, brush=tint)
        rr(4, 15, 7, 5)
        rr(13, 15, 7, 5)
    elif name == "strips_h":
        for y in (4, 10, 16):
            rr(4, y, 16, 4, 1.2, brush=tint if y == 4 else None)
    elif name == "strips_v":
        for x in (4, 10, 16):
            rr(x, 4, 4, 16, 1.2, brush=tint if x == 4 else None)
    elif name == "scatter":
        p.save()
        p.translate(9, 11)
        p.rotate(-12)
        rr(-5, -6, 10, 12, 1.2)
        p.restore()
        p.save()
        p.translate(15, 13)
        p.rotate(9)
        clear(-5, -6, 10, 12)
        rr(-5, -6, 10, 12, 1.2, brush=tint)
        p.restore()
    elif name == "seam":
        thin = QPen(pen)
        thin.setWidthF(1.2)
        p.setPen(thin)
        rr(2.5, 5, 9.5, 14, 1.2)
        rr(12, 5, 9.5, 14, 1.2)
        p.setPen(pen)
        clear(7, 8.5, 10, 7)
        rr(7, 8.5, 10, 7, 1.2, brush=tint)
    elif name == "plus":
        line(12, 5, 12, 19)
        line(5, 12, 19, 12)
    elif name == "minus":
        line(6, 12, 18, 12)
    elif name == "image":
        rr(3.5, 5, 17, 14, 2.2)
        poly((4, 17.5), (9, 12), (13, 15.5), (15.5, 13.5), (20, 17.5))
        p.drawEllipse(QPointF(15.8, 9.4), 1.6, 1.6)
    elif name == "export":
        poly((4.5, 13.5), (4.5, 19.5), (19.5, 19.5), (19.5, 13.5))
        line(12, 4, 12, 15)
        poly((8, 8), (12, 4), (16, 8))
    elif name == "download":
        poly((4.5, 13.5), (4.5, 19.5), (19.5, 19.5), (19.5, 13.5))
        line(12, 4, 12, 15)
        poly((8, 11), (12, 15), (16, 11))
    elif name == "fit":
        poly((4, 9), (4, 4), (9, 4))
        poly((15, 4), (20, 4), (20, 9))
        poly((20, 15), (20, 20), (15, 20))
        poly((9, 20), (4, 20), (4, 15))
    elif name == "guides":
        rr(4, 4, 16, 16, 2.2)
        dash = QPen(pen)
        dash.setWidthF(1.2)
        dash.setDashPattern([1.5, 2.0])
        p.setPen(dash)
        line(12, 6.5, 12, 17.5)
        line(6.5, 12, 17.5, 12)
    elif name == "magnet":
        path = QPainterPath()
        path.moveTo(6, 4.5)
        path.lineTo(6, 12)
        path.arcTo(QRectF(6, 6, 12, 12), 180, 180)
        path.lineTo(18, 4.5)
        p.drawPath(path)
        line(4.2, 8, 7.8, 8)
        line(16.2, 8, 19.8, 8)
    elif name == "shuffle":
        poly((4, 7), (8, 7), (16, 17), (20, 17))
        poly((4, 17), (8, 17), (16, 7), (20, 7))
        poly((17.5, 4.5), (20, 7), (17.5, 9.5))
        poly((17.5, 14.5), (20, 17), (17.5, 19.5))
    elif name == "swap":
        line(4, 8, 20, 8)
        poly((16.5, 4.5), (20, 8), (16.5, 11.5))
        line(20, 16, 4, 16)
        poly((7.5, 12.5), (4, 16), (7.5, 19.5))
    elif name == "rot_left":
        arc_arrow(-135, 270)
    elif name == "rot_right":
        arc_arrow(315, -270)
    elif name == "reset":
        arc_arrow(120, 290)
        p.drawEllipse(QPointF(12, 12.5), 1.3, 1.3)
    elif name == "level":
        rr(5, 7, 14, 9, 1.6)
        line(3.5, 19.5, 20.5, 19.5)
    elif name == "front":
        rr(4, 4, 11, 11, 1.6)
        clear(9, 9, 11, 11)
        rr(9, 9, 11, 11, 1.6, brush=QBrush(col))
    elif name == "back":
        rr(4, 4, 11, 11, 1.6, brush=QBrush(col))
        clear(9, 9, 11, 11)
        rr(9, 9, 11, 11, 1.6)
    elif name == "duplicate":
        rr(8.5, 8.5, 11.5, 11.5, 1.8)
        poly((4.5, 15.5), (4.5, 4.5), (15.5, 4.5))
    elif name in ("group", "ungroup"):
        # Due elementi dentro una cornice tratteggiata (Separa: cornice aperta a metà)
        rr(6.5, 6.5, 6.5, 6.5, 1.2, brush=tint)
        rr(11, 11, 6.5, 6.5, 1.2)
        dash = QPen(pen)
        dash.setWidthF(1.2)
        dash.setDashPattern([1.6, 1.8])
        p.setPen(dash)
        if name == "group":
            rr(3, 3, 18, 18, 2.2)
        else:
            poly((10, 3), (3, 3), (3, 10))
            poly((14, 21), (21, 21), (21, 14))
    elif name == "compare":
        # Prima/dopo: riquadro diviso a metà, una metà piena
        rr(3.5, 5, 17, 14, 2.2)
        p.setPen(Qt.PenStyle.NoPen)
        p.setBrush(tint)
        p.drawRect(QRectF(12, 5.8, 7.7, 12.4))
        p.setPen(pen)
        line(12, 3, 12, 21)
    elif name == "history":
        # Orologio con freccia all'indietro
        arc_arrow(160, -290)
        poly((12, 8.5), (12, 12.5), (14.8, 14.2))
    elif name == "trash":
        line(4, 7, 20, 7)
        poly((9.5, 7), (9.5, 4.5), (14.5, 4.5), (14.5, 7))
        poly((6.2, 7), (7.2, 20), (16.8, 20), (17.8, 7))
        line(10, 10.5, 10, 16.5)
        line(14, 10.5, 14, 16.5)
    elif name == "ratio":
        rr(4, 6, 16, 12, 1.8)
        poly((7, 11), (7, 9), (9, 9))
        poly((17, 13), (17, 15), (15, 15))
    elif name == "text":
        line(6, 6, 18, 6)
        line(12, 6, 12, 19)
        line(9.5, 19, 14.5, 19)
        line(6, 6, 6, 8.5)
        line(18, 6, 18, 8.5)
    elif name in ("flip_h", "flip_v"):
        if name == "flip_v":
            p.translate(12, 12)
            p.rotate(90)
            p.translate(-12, -12)
        dash = QPen(pen)
        dash.setDashPattern([2, 2])
        p.setPen(dash)
        line(12, 3, 12, 21)
        p.setPen(pen)
        p.setBrush(tint)
        p.drawPolygon(QPolygonF([QPointF(9.5, 6.5), QPointF(9.5, 17.5), QPointF(3, 17.5)]))
        p.setBrush(Qt.BrushStyle.NoBrush)
        p.drawPolygon(QPolygonF([QPointF(14.5, 6.5), QPointF(14.5, 17.5), QPointF(21, 17.5)]))
    elif name == "lock":
        rr(5.5, 11, 13, 9.5, 1.8, brush=tint)
        p.drawArc(QRectF(8.2, 4.5, 7.6, 11), 0, 180 * 16)
        line(8.2, 10, 8.2, 11)
        line(15.8, 10, 15.8, 11)
    elif name == "phone":
        rr(7, 3, 10, 18, 2.2)
        line(10.5, 18, 13.5, 18)
    elif name == "chevron_left":
        poly((14.5, 6), (8.5, 12), (14.5, 18))
    elif name == "chevron_right":
        poly((9.5, 6), (15.5, 12), (9.5, 18))
    elif name == "fit_cover":
        rr(4, 4, 16, 16, 1.4, brush=tint)
        poly((4, 15), (9, 10), (13, 14), (16, 12), (20, 16))
    elif name == "fit_contain":
        rr(4, 4, 16, 16, 1.4)
        rr(4, 8, 16, 8, 0.6, brush=tint)
    elif name == "page":
        rr(5.5, 3.5, 13, 17, 1.6)
        line(9, 9, 15, 9)
        line(9, 12.5, 15, 12.5)
    elif name == "shape":
        # Inserisci forma: un quadrato e un cerchio sovrapposti
        rr(3.5, 9, 11, 11, 1.2)
        clear(10.6, 3.6, 10, 10)
        p.setBrush(tint)
        p.drawEllipse(QRectF(10.6, 3.6, 10, 10))
    elif name.startswith("shape_"):
        kind = name[len("shape_"):]
        if kind in LINE_KINDS:
            line(4.5, 19.5, 19.5, 4.5)
            heads = {"line": (), "arrow": ((19.5, 4.5, 1),), "double_arrow": ((19.5, 4.5, 1), (4.5, 19.5, -1))}
            for x, y, d in heads[kind]:
                poly((x - d * 6.5, y), (x, y), (x, y + d * 6.5))
        else:
            box = QRectF(4, 4.5, 16, 15) if kind != "rect" else QRectF(3.5, 6, 17, 12)
            p.setBrush(tint)
            p.drawPath(shape_path(kind, box, 1.6))
    elif name.startswith("mosaic_"):
        for x, y, w, h, filled in MOSAIC_ICON_CELLS.get(name[len("mosaic_"):], ()):
            rr(x, y, w, h, 1.2, brush=tint if filled else None)
    elif name == "logo":
        p.setPen(Qt.PenStyle.NoPen)
        faded = QColor(col)
        faded.setAlphaF(0.45)
        rr(1.5, 6.5, 8, 11, 1.8, brush=QBrush(faded))
        rr(14.5, 6.5, 8, 11, 1.8, brush=QBrush(faded))
        clear(6.5, 3.5, 11, 17)
        rr(6.5, 3.5, 11, 17, 2.2, brush=QBrush(col))
    p.end()
    return pm


def app_icon_pixmap(size: int, margin: float = 0.0) -> QPixmap:
    """
    Il logo blu su un quadrato scuro arrotondato, di lato `size`.
    `margin` è il bordo trasparente in proporzione al lato (le icone Mac ne vogliono circa il 10%).
    """
    pm = QPixmap(size, size)
    pm.fill(Qt.GlobalColor.transparent)
    p = QPainter(pm)
    p.setRenderHint(QPainter.RenderHint.Antialiasing, True)
    p.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, True)
    p.setPen(Qt.PenStyle.NoPen)
    p.setBrush(QColor(THEME["header"]))
    m = size * margin
    side = size - 2 * m
    p.drawRoundedRect(QRectF(m, m, side, side), side * 0.22, side * 0.22)
    logo = icon_pixmap("logo", THEME["accent"], int(round(side)))
    inset = m + side * 0.08
    p.drawPixmap(QRectF(inset, inset, size - 2 * inset, size - 2 * inset), logo, QRectF(logo.rect()))
    p.end()
    return pm


def app_icon() -> QIcon:
    """Icona della finestra, in più risoluzioni."""
    icon = QIcon()
    for size in (16, 20, 24, 32, 40, 48, 64, 128, 256):
        icon.addPixmap(app_icon_pixmap(size))
    return icon


def make_icon(name: str, color: str = THEME["muted"], size: int = 18, on_color: Optional[str] = None) -> QIcon:
    icon = QIcon()
    icon.addPixmap(icon_pixmap(name, color, size), QIcon.Mode.Normal, QIcon.State.Off)
    icon.addPixmap(icon_pixmap(name, on_color or color, size), QIcon.Mode.Normal, QIcon.State.On)
    icon.addPixmap(icon_pixmap(name, THEME["faint"], size), QIcon.Mode.Disabled, QIcon.State.Off)
    return icon


def swatch_icon(color: QColor, size: int = 16) -> QIcon:
    pm = QPixmap(size * 2, size * 2)
    pm.setDevicePixelRatio(2.0)
    pm.fill(Qt.GlobalColor.transparent)
    p = QPainter(pm)
    p.setRenderHint(QPainter.RenderHint.Antialiasing, True)
    # Campione quadrato con doppio filo, come i colori di primo piano/sfondo di Photoshop
    p.setPen(QPen(QColor("#000000"), 1.0))
    p.setBrush(QBrush(color))
    p.drawRect(QRectF(1.5, 1.5, size - 3, size - 3))
    p.setPen(QPen(QColor(255, 255, 255, 90), 1.0))
    p.setBrush(Qt.BrushStyle.NoBrush)
    p.drawRect(QRectF(2.5, 2.5, size - 5, size - 5))
    p.end()
    return QIcon(pm)


def no_color_icon(size: int = 16) -> QIcon:
    """Campione «nessun colore» (trasparente): bianco con una diagonale rossa, come negli editor grafici."""
    pm = QPixmap(size * 2, size * 2)
    pm.setDevicePixelRatio(2.0)
    pm.fill(Qt.GlobalColor.transparent)
    p = QPainter(pm)
    p.setRenderHint(QPainter.RenderHint.Antialiasing, True)
    p.setPen(QPen(QColor("#000000"), 1.0))
    p.setBrush(QBrush(QColor("#FFFFFF")))
    p.drawRect(QRectF(1.5, 1.5, size - 3, size - 3))
    p.setPen(QPen(QColor(THEME["danger"]), 1.6))
    p.drawLine(QPointF(size - 3, 3), QPointF(3, size - 3))
    p.end()
    return QIcon(pm)


def color_wheel_icon(size: int = 16) -> QIcon:
    """Ruota dei colori: «scegli un altro colore» col selettore completo."""
    pm = QPixmap(size * 2, size * 2)
    pm.setDevicePixelRatio(2.0)
    pm.fill(Qt.GlobalColor.transparent)
    p = QPainter(pm)
    p.setRenderHint(QPainter.RenderHint.Antialiasing, True)
    c = QPointF(size / 2.0, size / 2.0)
    grad = QConicalGradient(c, 90)
    for i in range(7):
        grad.setColorAt(i / 6.0, QColor.fromHsv((i * 60) % 360, 230, 255))
    p.setPen(QPen(QColor(0, 0, 0, 160), 1.0))
    p.setBrush(QBrush(grad))
    p.drawEllipse(c, size / 2.0 - 1.5, size / 2.0 - 1.5)
    p.end()
    return QIcon(pm)


def rounded_thumb(pm: QPixmap, size: int, radius: float = 2.0) -> QPixmap:
    """Miniatura quadrata ritagliata al centro, con angoli arrotondati."""
    out = QPixmap(size * 2, size * 2)
    out.setDevicePixelRatio(2.0)
    out.fill(Qt.GlobalColor.transparent)
    if pm.isNull():
        return out
    side = min(pm.width(), pm.height())
    src = QRectF((pm.width() - side) / 2.0, (pm.height() - side) / 2.0, side, side)
    p = QPainter(out)
    p.setRenderHint(QPainter.RenderHint.Antialiasing, True)
    p.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, True)
    clip = QPainterPath()
    clip.addRoundedRect(QRectF(0, 0, size, size), radius, radius)
    p.setClipPath(clip)
    p.drawPixmap(QRectF(0, 0, size, size), pm, src)
    p.end()
    return out


_LOCK_BADGE: Dict[str, QPixmap] = {}


def draw_lock_badge(painter: QPainter, view_scale: float):
    """Piccolo lucchetto nell'angolo in alto a sinistra di un elemento bloccato (dimensione fissa a schermo)."""
    if "pm" not in _LOCK_BADGE:
        _LOCK_BADGE["pm"] = icon_pixmap("lock", "#FFFFFF", 16)
    vs = max(0.01, view_scale)
    box = QRectF(6.0 / vs, 6.0 / vs, 22.0 / vs, 22.0 / vs)
    painter.save()
    painter.setPen(Qt.PenStyle.NoPen)
    painter.setBrush(QColor(0, 0, 0, 170))
    painter.drawRoundedRect(box, 3.0 / vs, 3.0 / vs)
    pm = _LOCK_BADGE["pm"]
    painter.drawPixmap(box.adjusted(3.0 / vs, 3.0 / vs, -3.0 / vs, -3.0 / vs), pm, QRectF(pm.rect()))
    painter.restore()
