"""Casella di testo sulla tela."""
from typing import List, Optional

from PyQt6.QtCore import Qt, QRectF, pyqtSignal
from PyQt6.QtGui import QPainter, QPen, QColor, QFont, QPainterPath, QCursor, QFontMetricsF
from PyQt6.QtWidgets import QGraphicsObject, QGraphicsItem

from scrollr.icons import draw_lock_badge
from scrollr.theme import THEME, font_family


class TextItem(QGraphicsObject):
    """
    Testo sulla tela (titoli, didascalie, numeri delle slide): si sposta e si ruota come le foto,
    si modifica dal pannello Proprietà. In esportazione è disegnato in vettoriale, sempre nitido.
    """
    geometry_changed = pyqtSignal(object)
    edit_finished = pyqtSignal()
    edit_requested = pyqtSignal(object)
    _next_uid = 1

    def __init__(self, text: str = "Scrivi qui", uid: Optional[int] = None):
        super().__init__()
        if uid is None:
            uid = TextItem._next_uid
        self.uid = uid
        TextItem._next_uid = max(TextItem._next_uid, uid + 1)
        self.text = text
        self.font_family = font_family("display")
        self.font_size = 72.0
        self.bold = True
        self.italic = False
        self.align = "center"
        self.color = QColor("#FFFFFF")
        self.shadow = True
        self.box = False
        self.box_color = QColor(0, 0, 0, 150)
        self.text_opacity = 100
        self.locked = False
        self._rect = QRectF()
        self._pad = 0.0
        self._hovered = False
        self._dragging = False
        self.setFlags(
            QGraphicsItem.GraphicsItemFlag.ItemIsMovable |
            QGraphicsItem.GraphicsItemFlag.ItemIsSelectable |
            QGraphicsItem.GraphicsItemFlag.ItemSendsGeometryChanges
        )
        self.setAcceptHoverEvents(True)
        self.relayout(keep_center=False)

    # ---------- Stato ----------
    def get_state(self) -> dict:
        return {
            "uid": self.uid,
            "text": self.text,
            "x": round(self.pos().x(), 3),
            "y": round(self.pos().y(), 3),
            "rotation": round(self.rotation(), 3),
            "z": self.zValue(),
            "font": self.font_family,
            "size": self.font_size,
            "bold": self.bold,
            "italic": self.italic,
            "align": self.align,
            "color": self.color.name(QColor.NameFormat.HexArgb),
            "shadow": self.shadow,
            "box": self.box,
            "box_color": self.box_color.name(QColor.NameFormat.HexArgb),
            "opacity": self.text_opacity,
            "locked": self.locked,
        }

    def set_state(self, s: dict):
        self.text = s.get("text", "")
        self.font_family = s.get("font", self.font_family)
        self.font_size = float(s.get("size", 72.0))
        self.bold = s.get("bold", True)
        self.italic = s.get("italic", False)
        self.align = s.get("align", "center")
        self.color = QColor(s.get("color", "#FFFFFFFF"))
        self.shadow = s.get("shadow", True)
        self.box = s.get("box", False)
        self.box_color = QColor(s.get("box_color", "#96000000"))
        self.relayout(keep_center=False)
        self.setPos(s["x"], s["y"])
        self.setRotation(s.get("rotation", 0.0))
        self.setZValue(s.get("z", 0.0))
        self.set_text_opacity(s.get("opacity", 100))
        self.set_locked(s.get("locked", False))

    def set_locked(self, locked: bool):
        self.locked = bool(locked)
        self.setFlag(QGraphicsItem.GraphicsItemFlag.ItemIsMovable, not self.locked)
        self.update()

    def set_text_opacity(self, value: int):
        self.text_opacity = int(value)
        self.setOpacity(self.text_opacity / 100.0)

    # ---------- Geometria ----------
    def _font(self) -> QFont:
        f = QFont(self.font_family)
        f.setPixelSize(max(4, int(round(self.font_size))))
        f.setBold(self.bold)
        f.setItalic(self.italic)
        return f

    def _lines(self) -> List[str]:
        return self.text.split("\n") if self.text else [" "]

    def text_rect(self) -> QRectF:
        return QRectF(self._rect)

    def relayout(self, keep_center: bool = True):
        """Ricalcola il riquadro dopo una modifica; il centro del testo resta dov'era."""
        old_center = self._rect.center() if not self._rect.isNull() else None
        self.prepareGeometryChange()
        fm = QFontMetricsF(self._font())
        lines = self._lines()
        w = max(fm.horizontalAdvance(line) for line in lines)
        h = fm.lineSpacing() * len(lines)
        self._pad = self.font_size * (0.35 if self.box else 0.08)
        self._rect = QRectF(0, 0, w + 2 * self._pad, h + 2 * self._pad)
        self.setTransformOriginPoint(self._rect.center())
        if keep_center and old_center is not None:
            self.setPos(self.pos() + old_center - self._rect.center())
        self.update()

    def view_scale_changed(self):
        # Il margine di selezione ha misura costante sullo schermo: il boundingRect cambia con lo zoom
        self.prepareGeometryChange()
        self.update()

    def set_text(self, text: str):
        self.text = text
        self.relayout()

    def _view_scale(self) -> float:
        # Zoom della vista attiva (in fila o a scacchiera), impostato dalla finestra
        scene = self.scene()
        return max(0.01, getattr(scene, "display_scale", 1.0)) if scene else 1.0

    def boundingRect(self) -> QRectF:
        m = max(self.font_size * 0.12, 8.0 / self._view_scale())
        return self._rect.adjusted(-m, -m, m, m)

    def shape(self) -> QPainterPath:
        path = QPainterPath()
        path.addRect(self._rect)
        return path

    # ---------- Disegno ----------
    def paint(self, painter: QPainter, option, widget=None):
        scene = self.scene()
        clean = bool(scene) and (getattr(scene, "is_exporting", False) or getattr(scene, "clean_render", False))
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        painter.setRenderHint(QPainter.RenderHint.TextAntialiasing, True)

        if self.box:
            r = self.font_size * 0.18
            painter.setPen(Qt.PenStyle.NoPen)
            painter.setBrush(self.box_color)
            painter.drawRoundedRect(self._rect, r, r)

        font = self._font()
        painter.setFont(font)
        fm = QFontMetricsF(font)
        h_align = {"left": Qt.AlignmentFlag.AlignLeft, "right": Qt.AlignmentFlag.AlignRight}.get(
            self.align, Qt.AlignmentFlag.AlignHCenter)
        flags = h_align | Qt.AlignmentFlag.AlignVCenter
        inner = self._rect.adjusted(self._pad, self._pad, -self._pad, -self._pad)
        y = inner.top()
        off = max(1.0, self.font_size * 0.035)
        for line in self._lines():
            line_rect = QRectF(inner.left(), y, inner.width(), fm.lineSpacing())
            if self.shadow:
                painter.setPen(QColor(0, 0, 0, 70))
                painter.drawText(line_rect.translated(off * 0.9, off * 1.8), flags, line)
                painter.setPen(QColor(0, 0, 0, 110))
                painter.drawText(line_rect.translated(off * 0.5, off), flags, line)
            painter.setPen(self.color)
            painter.drawText(line_rect, flags, line)
            y += fm.lineSpacing()

        if clean:
            return
        accent = QColor(THEME["accent"])
        if self.isSelected():
            pen = QPen(accent, 1.5)
            pen.setCosmetic(True)
            painter.setPen(pen)
            painter.setBrush(Qt.BrushStyle.NoBrush)
            painter.drawRect(self._rect)
            if self.locked:
                draw_lock_badge(painter, self._view_scale())
        elif self._hovered:
            hover = QColor(accent)
            hover.setAlpha(170)
            pen = QPen(hover, 1.0, Qt.PenStyle.DashLine)
            pen.setCosmetic(True)
            painter.setPen(pen)
            painter.setBrush(Qt.BrushStyle.NoBrush)
            painter.drawRect(self._rect)

    # ---------- Interazione ----------
    def hoverEnterEvent(self, event):
        self._hovered = True
        self.setCursor(QCursor(Qt.CursorShape.ArrowCursor if self.locked else Qt.CursorShape.OpenHandCursor))
        self.update()
        super().hoverEnterEvent(event)

    def hoverLeaveEvent(self, event):
        self._hovered = False
        self.update()
        super().hoverLeaveEvent(event)

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton and not self.locked:
            self._dragging = True
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        super().mouseMoveEvent(event)
        if self._dragging:
            self.geometry_changed.emit(self)

    def mouseReleaseEvent(self, event):
        was_dragging = self._dragging
        self._dragging = False
        super().mouseReleaseEvent(event)
        if was_dragging:
            self.geometry_changed.emit(self)
            self.edit_finished.emit()

    def mouseDoubleClickEvent(self, event):
        self.edit_requested.emit(self)
        event.accept()
