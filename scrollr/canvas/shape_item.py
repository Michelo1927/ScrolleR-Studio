"""Forme grafiche sulla tela: rettangoli, ellissi, stelle, linee e frecce."""
import math
from typing import Dict, Optional

from PyQt6.QtCore import Qt, QRectF, QPointF, pyqtSignal
from PyQt6.QtGui import (
    QPainter, QPen, QColor, QBrush, QPainterPath, QPainterPathStroker, QCursor, QTransform, QPolygonF, QImage
)
from PyQt6.QtWidgets import QGraphicsObject, QGraphicsItem

from scrollr.canvas.snap import snap_selection
from scrollr.icons import draw_lock_badge, icon_pixmap
from scrollr.shapes import LINE_KINDS, arrow_head_size, shape_path
from scrollr.theme import THEME

# Maniglie delle forme piene: posizione in frazioni del riquadro (0 = sinistra/alto, 1 = destra/basso)
BOX_HANDLES = {
    "tl": (0.0, 0.0), "t": (0.5, 0.0), "tr": (1.0, 0.0), "r": (1.0, 0.5),
    "br": (1.0, 1.0), "b": (0.5, 1.0), "bl": (0.0, 1.0), "l": (0.0, 0.5),
}
PEN_STYLES = {"solid": Qt.PenStyle.SolidLine, "dash": Qt.PenStyle.DashLine, "dot": Qt.PenStyle.DotLine}


class ShapeItem(QGraphicsObject):
    """
    Forma sulla tela, fuori dalla disposizione automatica (come i testi).
    - Forme piene: 8 maniglie per ridimensionare (Shift sugli angoli = proporzioni bloccate)
      e una maniglia tonda sopra per ruotare (Shift = scatti di 15°), come in Word
    - Linee e frecce: si tirano i due estremi, che ne cambiano lunghezza e direzione
    Riempimento (anche trasparente), bordo con colore/spessore/tratteggio e opacità si cambiano dal pannello.
    """
    geometry_changed = pyqtSignal(object)
    edit_finished = pyqtSignal()
    HANDLE_PX = 11.0
    ROTATE_PX = 26.0   # Distanza della maniglia di rotazione sopra la forma, in pixel dello schermo
    HIT_PX = 12.0      # Larghezza minima cliccabile di linee e contorni, in pixel dello schermo
    MIN_SIZE = 8.0
    _next_uid = 1
    _rotate_cursor: Optional[QCursor] = None

    def __init__(self, kind: str = "rect", w: float = 300.0, h: float = 300.0, uid: Optional[int] = None):
        super().__init__()
        if uid is None:
            uid = ShapeItem._next_uid
        self.uid = uid
        ShapeItem._next_uid = max(ShapeItem._next_uid, uid + 1)
        self.kind = kind
        self.w = float(w)
        self.h = float(h)
        self.fill_color = QColor("#FF3B30")
        self.stroke_color = QColor("#FFFFFF")
        self.stroke_width = 0.0
        self.stroke_style = "solid"   # "solid", "dash", "dot"
        self.corner_radius = 0.0      # Solo per il rettangolo
        self.shape_opacity = 100
        self.locked = False
        self.snap_enabled = True

        self._handle: Optional[str] = None   # Maniglia trascinata ("tl"…, "p1"/"p2" o "rot")
        self._anchor_scene = QPointF()
        self._ratio = 1.0
        self._dragging = False
        self._hovered = False
        self.setFlags(
            QGraphicsItem.GraphicsItemFlag.ItemIsMovable |
            QGraphicsItem.GraphicsItemFlag.ItemIsSelectable |
            QGraphicsItem.GraphicsItemFlag.ItemSendsGeometryChanges
        )
        self.setAcceptHoverEvents(True)
        self.setTransformOriginPoint(self.w / 2.0, self.h / 2.0)

    @property
    def is_line(self) -> bool:
        return self.kind in LINE_KINDS

    # ---------- Stato ----------
    def get_state(self) -> dict:
        return {
            "uid": self.uid,
            "kind": self.kind,
            "x": round(self.pos().x(), 3),
            "y": round(self.pos().y(), 3),
            "w": round(self.w, 3),
            "h": round(self.h, 3),
            "rotation": round(self.rotation(), 3),
            "z": self.zValue(),
            "fill": self.fill_color.name(QColor.NameFormat.HexArgb),
            "stroke": self.stroke_color.name(QColor.NameFormat.HexArgb),
            "stroke_width": self.stroke_width,
            "stroke_style": self.stroke_style,
            "radius": self.corner_radius,
            "opacity": self.shape_opacity,
            "locked": self.locked,
        }

    def set_state(self, s: dict):
        self.kind = s.get("kind", "rect")
        self.fill_color = QColor(s.get("fill", "#FFFF3B30"))
        self.stroke_color = QColor(s.get("stroke", "#FFFFFFFF"))
        self.stroke_width = float(s.get("stroke_width", 0.0))
        self.stroke_style = s.get("stroke_style", "solid")
        self.corner_radius = float(s.get("radius", 0.0))
        self.set_size(s.get("w", 300.0), s.get("h", 300.0))
        self.setPos(s["x"], s["y"])
        self.setRotation(s.get("rotation", 0.0))
        self.setZValue(s.get("z", 0.0))
        self.set_shape_opacity(s.get("opacity", 100))
        self.set_locked(s.get("locked", False))

    def set_locked(self, locked: bool):
        self.locked = bool(locked)
        self.setFlag(QGraphicsItem.GraphicsItemFlag.ItemIsMovable, not self.locked)
        self.update()

    def set_shape_opacity(self, value: int):
        # L'opacità si applica in paint() alla forma intera, non all'item: vedi _paint_translucent
        self.shape_opacity = int(value)
        self.update()

    # ---------- Geometria ----------
    def frame_rect(self) -> QRectF:
        return QRectF(0, 0, self.w, self.h)

    def snap_rect(self) -> QRectF:
        """Riquadro in scena usato come riferimento dallo snap degli altri elementi."""
        return self.mapRectToScene(self.frame_rect())

    def set_size(self, w: float, h: float):
        self.prepareGeometryChange()
        self.w = max(self.MIN_SIZE, float(w))
        self.h = max(1.0, float(h)) if self.is_line else max(self.MIN_SIZE, float(h))
        self.setTransformOriginPoint(self.w / 2.0, self.h / 2.0)
        self.update()

    def line_width(self) -> float:
        return max(1.0, self.stroke_width)

    def _line_box_height(self) -> float:
        """Altezza del riquadro di una linea: lo spessore, o la punta della freccia."""
        return arrow_head_size(self.line_width()) if self.kind != "line" else self.line_width()

    def refresh_geometry(self):
        """Dopo un cambio di tipo o di spessore: una linea ricalcola l'altezza, il centro resta fermo."""
        if not self.is_line:
            self.update()
            return
        center = self.mapToScene(QPointF(self.w / 2.0, self.h / 2.0))
        self.set_size(self.w, self._line_box_height())
        self.setPos(center - QPointF(self.w / 2.0, self.h / 2.0))

    def view_scale_changed(self):
        # Maniglie a misura costante sullo schermo: il boundingRect cambia con lo zoom
        self.prepareGeometryChange()
        self.update()

    def _view_scale(self) -> float:
        scene = self.scene()
        return max(0.01, getattr(scene, "display_scale", 1.0)) if scene else 1.0

    def _handle_size(self) -> float:
        return self.HANDLE_PX / self._view_scale()

    def _pos_for_local_point(self, local: QPointF, scene_target: QPointF) -> QPointF:
        """Posizione dell'item tale che il punto locale `local` cada su `scene_target` (rotazione inclusa)."""
        origin = QPointF(self.w / 2.0, self.h / 2.0)
        rotated = QTransform().rotate(self.rotation()).map(local - origin)
        return scene_target - origin - rotated

    def _handle_points(self) -> Dict[str, QPointF]:
        if self.is_line:
            return {"p1": QPointF(0.0, self.h / 2.0), "p2": QPointF(self.w, self.h / 2.0)}
        return {name: QPointF(fx * self.w, fy * self.h) for name, (fx, fy) in BOX_HANDLES.items()}

    def _rotate_point(self) -> QPointF:
        return QPointF(self.w / 2.0, -self.ROTATE_PX / self._view_scale())

    def _handle_at(self, pos: QPointF) -> Optional[str]:
        if not self.isSelected() or self.locked:
            return None
        reach = self._handle_size() * 0.75
        if not self.is_line and (pos - self._rotate_point()).manhattanLength() <= reach * 1.4:
            return "rot"
        for name, pt in self._handle_points().items():
            if abs(pos.x() - pt.x()) <= reach and abs(pos.y() - pt.y()) <= reach:
                return name
        return None

    def boundingRect(self) -> QRectF:
        vs = self._view_scale()
        m = self._handle_size() + 4.0 / vs
        top = m + (self.ROTATE_PX / vs if not self.is_line else 0.0)
        side = max(m, self.HIT_PX / vs)
        return QRectF(-side, -max(top, side), self.w + 2 * side, self.h + max(top, side) + side)

    def _box_path(self) -> QPainterPath:
        """Contorno della forma piena, rientrato di mezzo bordo: il bordo resta dentro il riquadro."""
        inset = min(self.stroke_width / 2.0, self.w / 2.0, self.h / 2.0)
        rect = self.frame_rect().adjusted(inset, inset, -inset, -inset)
        return shape_path(self.kind, rect, max(0.0, self.corner_radius - inset))

    def shape(self) -> QPainterPath:
        # Area cliccabile: la forma (o solo il contorno, se senza riempimento) più le maniglie
        hit = self.HIT_PX / self._view_scale()
        if self.is_line:
            t = max(self.h, hit)
            path = QPainterPath()
            path.addRect(QRectF(0, self.h / 2.0 - t / 2.0, self.w, t))
        elif self.fill_color.alpha() > 0:
            path = self._box_path()
        else:
            stroker = QPainterPathStroker()
            stroker.setWidth(max(self.stroke_width, hit))
            path = stroker.createStroke(self._box_path())
        if self.isSelected() and not self.locked:
            r = self._handle_size() * 0.75
            for pt in self._handle_points().values():
                path.addEllipse(pt, r, r)
            if not self.is_line:
                path.addEllipse(self._rotate_point(), r * 1.4, r * 1.4)
        return path

    # ---------- Disegno ----------
    def _pen(self, width: float) -> QPen:
        pen = QPen(self.stroke_color, width, PEN_STYLES.get(self.stroke_style, Qt.PenStyle.SolidLine))
        pen.setCapStyle(Qt.PenCapStyle.RoundCap if self.stroke_style == "dot" or self.is_line
                        else Qt.PenCapStyle.FlatCap)
        pen.setJoinStyle(Qt.PenJoinStyle.RoundJoin if self.kind in ("heart", "ellipse") else Qt.PenJoinStyle.MiterJoin)
        return pen

    def _paint_line(self, painter: QPainter):
        sw = self.line_width()
        y = self.h / 2.0
        head = min(arrow_head_size(sw), self.w / (2.2 if self.kind == "double_arrow" else 1.2))
        # L'asta finisce dentro la punta; senza punta l'estremità arrotondata arriva giusta sulla maniglia
        cap = sw / 2.0
        x0 = head * 0.8 if self.kind == "double_arrow" else cap
        x1 = self.w - head * 0.8 if self.kind != "line" else self.w - cap
        if self.stroke_style != "solid" and self.kind != "line":
            x0, x1 = (head if self.kind == "double_arrow" else cap), self.w - head
        if x1 <= x0:  # Linea più corta del suo spessore: resta un punto
            x0 = x1 = self.w / 2.0
        painter.setPen(self._pen(sw))
        painter.setBrush(Qt.BrushStyle.NoBrush)
        if x1 >= x0:
            painter.drawLine(QPointF(x0, y), QPointF(x1, y))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.setBrush(self.stroke_color)
        tips = [] if self.kind == "line" else [(self.w, -1.0)] + ([(0.0, 1.0)] if self.kind == "double_arrow" else [])
        for tip_x, d in tips:
            base = tip_x + d * head
            painter.drawPolygon(QPolygonF([QPointF(tip_x, y), QPointF(base, y - head / 2.0), QPointF(base, y + head / 2.0)]))

    def _paint_content(self, painter: QPainter):
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        if self.is_line:
            self._paint_line(painter)
            return
        path = self._box_path()
        if self.fill_color.alpha() > 0:
            painter.fillPath(path, self.fill_color)
        if self.stroke_width > 0:
            painter.strokePath(path, self._pen(self.stroke_width))

    def _paint_translucent(self, painter: QPainter):
        """
        Forma semitrasparente: disegnata piena su un livello a parte e poi sfumata tutta insieme.
        Così asta e punta della freccia, o riempimento e bordo, non si sommano dove si sovrappongono.
        """
        device = painter.device()
        t = painter.worldTransform()
        pad = self.line_width() if self.is_line else 0.0  # Margine per le estremità arrotondate
        area = t.mapRect(self.frame_rect().adjusted(-pad, -pad, pad, pad)).adjusted(-2, -2, 2, 2)
        if device is not None:
            area = area.intersected(QRectF(0, 0, device.width(), device.height()))
        clip = area.toAlignedRect()
        if clip.isEmpty():
            return
        dpr = device.devicePixelRatioF() if device is not None else 1.0
        layer = QImage(max(1, round(clip.width() * dpr)), max(1, round(clip.height() * dpr)),
                       QImage.Format.Format_ARGB32_Premultiplied)
        layer.setDevicePixelRatio(dpr)
        layer.fill(Qt.GlobalColor.transparent)
        lp = QPainter(layer)
        lp.setTransform(t * QTransform.fromTranslate(-clip.x(), -clip.y()))
        self._paint_content(lp)
        lp.end()
        painter.save()
        painter.resetTransform()
        painter.setOpacity(painter.opacity() * self.shape_opacity / 100.0)
        painter.drawImage(QPointF(clip.topLeft()), layer)
        painter.restore()

    def paint(self, painter: QPainter, option, widget=None):
        scene = self.scene()
        clean = bool(scene) and (getattr(scene, "is_exporting", False) or getattr(scene, "clean_render", False))
        if self.shape_opacity >= 100:
            self._paint_content(painter)
        else:
            self._paint_translucent(painter)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)

        if clean:
            return
        accent = QColor(THEME["accent"])
        vs = self._view_scale()
        if self.isSelected():
            if not self.is_line:
                sel_pen = QPen(accent, 1.5)
                sel_pen.setCosmetic(True)
                painter.setPen(sel_pen)
                painter.setBrush(Qt.BrushStyle.NoBrush)
                painter.drawRect(self.frame_rect())
            if self.locked:
                draw_lock_badge(painter, vs)
                return
            handle_pen = QPen(QColor("#1A1A1A"), 1.0)
            handle_pen.setCosmetic(True)
            s = self._handle_size() * 0.36
            if not self.is_line:
                # Maniglia di rotazione: asta dal lato alto e pallino con freccia circolare
                rp = self._rotate_point()
                painter.setPen(sel_pen)
                painter.drawLine(QPointF(self.w / 2.0, 0.0), QPointF(rp.x(), rp.y() + s * 1.4))
                painter.setPen(handle_pen)
                painter.setBrush(QBrush(QColor("#FFFFFF")))
                painter.drawEllipse(rp, s * 1.4, s * 1.4)
                arc_pen = QPen(QColor("#1A1A1A"), 1.2)
                arc_pen.setCosmetic(True)
                painter.setPen(arc_pen)
                painter.setBrush(Qt.BrushStyle.NoBrush)
                painter.drawArc(QRectF(rp.x() - s * 0.75, rp.y() - s * 0.75, s * 1.5, s * 1.5), 30 * 16, 270 * 16)
            painter.setPen(handle_pen)
            painter.setBrush(QBrush(QColor("#FFFFFF")))
            for pt in self._handle_points().values():
                if self.is_line:
                    painter.drawEllipse(pt, s * 1.2, s * 1.2)
                else:
                    painter.drawRect(QRectF(pt.x() - s, pt.y() - s, 2 * s, 2 * s))
        elif self._hovered:
            hover = QColor(accent)
            hover.setAlpha(170)
            pen = QPen(hover, 1.0, Qt.PenStyle.DashLine)
            pen.setCosmetic(True)
            painter.setPen(pen)
            painter.setBrush(Qt.BrushStyle.NoBrush)
            painter.drawRect(self.frame_rect())

    # ---------- Interazione ----------
    @classmethod
    def _rotation_cursor(cls) -> QCursor:
        if cls._rotate_cursor is None:
            cls._rotate_cursor = QCursor(icon_pixmap("rot_right", THEME["accent"], 22))
        return cls._rotate_cursor

    def _cursor_for(self, handle: Optional[str]) -> QCursor:
        if handle == "rot":
            return self._rotation_cursor()
        if handle in ("p1", "p2"):
            return QCursor(Qt.CursorShape.SizeAllCursor)
        if handle:
            fx, fy = BOX_HANDLES[handle]
            # Il cursore a freccia doppia segue la rotazione della forma
            angle = (self.rotation() + math.degrees(math.atan2(fy - 0.5, fx - 0.5))) % 180
            if 22.5 <= angle < 67.5:
                return QCursor(Qt.CursorShape.SizeFDiagCursor)
            if 67.5 <= angle < 112.5:
                return QCursor(Qt.CursorShape.SizeVerCursor)
            if 112.5 <= angle < 157.5:
                return QCursor(Qt.CursorShape.SizeBDiagCursor)
            return QCursor(Qt.CursorShape.SizeHorCursor)
        return QCursor(Qt.CursorShape.ArrowCursor if self.locked else Qt.CursorShape.OpenHandCursor)

    def hoverEnterEvent(self, event):
        self._hovered = True
        self.update()
        super().hoverEnterEvent(event)

    def hoverLeaveEvent(self, event):
        self._hovered = False
        self.update()
        super().hoverLeaveEvent(event)

    def hoverMoveEvent(self, event):
        self.setCursor(self._cursor_for(self._handle_at(event.pos())))
        super().hoverMoveEvent(event)

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            handle = self._handle_at(event.pos())
            if handle:
                self._handle = handle
                if handle == "p1":
                    self._anchor_scene = self.mapToScene(QPointF(self.w, self.h / 2.0))
                elif handle == "p2":
                    self._anchor_scene = self.mapToScene(QPointF(0.0, self.h / 2.0))
                elif handle != "rot":
                    fx, fy = BOX_HANDLES[handle]
                    self._anchor_scene = self.mapToScene(QPointF((1 - fx) * self.w, (1 - fy) * self.h))
                    self._ratio = self.w / self.h if self.h > 0 else 1.0
                event.accept()
                return
            if not self.locked:
                self._dragging = True
                self.setCursor(QCursor(Qt.CursorShape.ClosedHandCursor))
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        shift = bool(event.modifiers() & Qt.KeyboardModifier.ShiftModifier)
        if self._handle == "rot":
            v = event.scenePos() - self.mapToScene(QPointF(self.w / 2.0, self.h / 2.0))
            angle = math.degrees(math.atan2(v.y(), v.x())) + 90.0
            if shift:
                angle = round(angle / 15.0) * 15.0
            self.setRotation(((angle + 180.0) % 360.0) - 180.0)
            self.geometry_changed.emit(self)
            event.accept()
            return
        if self._handle in ("p1", "p2"):
            self._drag_endpoint(event.scenePos(), shift)
            event.accept()
            return
        if self._handle:
            self._resize_to(event.scenePos(), shift)
            event.accept()
            return
        super().mouseMoveEvent(event)
        if self._dragging:
            snap_selection(self, self.snap_rect(), self._view_scale())
            self.geometry_changed.emit(self)

    def _resize_to(self, scene_pos: QPointF, keep_ratio: bool):
        fx, fy = BOX_HANDLES[self._handle]
        local = QTransform().rotate(-self.rotation()).map(scene_pos - self._anchor_scene)
        new_w = self.w if fx == 0.5 else max(self.MIN_SIZE, (1.0 if fx == 1.0 else -1.0) * local.x())
        new_h = self.h if fy == 0.5 else max(self.MIN_SIZE, (1.0 if fy == 1.0 else -1.0) * local.y())
        if keep_ratio and fx != 0.5 and fy != 0.5:
            if new_w / self._ratio >= new_h:
                new_h = new_w / self._ratio
            else:
                new_w = new_h * self._ratio
        self.set_size(new_w, new_h)
        self.setPos(self._pos_for_local_point(QPointF((1 - fx) * self.w, (1 - fy) * self.h), self._anchor_scene))
        self.geometry_changed.emit(self)

    def _drag_endpoint(self, scene_pos: QPointF, snap_angle: bool):
        """Sposta un estremo della linea: l'altro resta fermo, cambiano lunghezza e direzione."""
        anchor = self._anchor_scene
        v = scene_pos - anchor if self._handle == "p2" else anchor - scene_pos
        angle = math.degrees(math.atan2(v.y(), v.x()))
        if snap_angle:
            angle = round(angle / 15.0) * 15.0
        self.set_size(math.hypot(v.x(), v.y()), self.h)
        self.setRotation(angle)
        fixed = QPointF(0.0, self.h / 2.0) if self._handle == "p2" else QPointF(self.w, self.h / 2.0)
        self.setPos(self._pos_for_local_point(fixed, anchor))
        self.geometry_changed.emit(self)

    def mouseReleaseEvent(self, event):
        was_editing = bool(self._handle) or self._dragging
        self._handle = None
        self._dragging = False
        self.setCursor(self._cursor_for(None))
        scene = self.scene()
        if scene is not None and hasattr(scene, "set_snap_lines"):
            scene.set_snap_lines([], [])
        super().mouseReleaseEvent(event)
        if was_editing:
            self.geometry_changed.emit(self)
            self.edit_finished.emit()
