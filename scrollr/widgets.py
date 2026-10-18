"""Widget personalizzati dell'interfaccia."""
from PyQt6.QtCore import Qt, QRectF, QPointF, pyqtSignal, QSize
from PyQt6.QtGui import QPainter, QPen, QColor, QFont, QPolygonF, QFontMetricsF
from PyQt6.QtWidgets import QFrame, QCheckBox, QStyledItemDelegate, QStyle, QListWidget

from scrollr.config import LIBRARY_MIME

from scrollr.icons import icon_pixmap
from scrollr.theme import THEME, ui_font


# ================= WIDGET PERSONALIZZATI =================
class ToggleSwitch(QCheckBox):
    """Casella di spunta compatta in stile pannello Adobe (quadratino blu con segno di spunta)."""
    BOX = 14

    def __init__(self, text: str, parent=None):
        super().__init__(text, parent)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self._hover = False

    def sizeHint(self) -> QSize:
        fm = self.fontMetrics()
        return QSize(self.BOX + 8 + fm.horizontalAdvance(self.text()), max(self.BOX + 6, fm.height() + 6))

    def hitButton(self, pos) -> bool:
        return self.rect().contains(pos)

    def enterEvent(self, event):
        self._hover = True
        self.update()
        super().enterEvent(event)

    def leaveEvent(self, event):
        self._hover = False
        self.update()
        super().leaveEvent(event)

    def paintEvent(self, event):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        y = (self.height() - self.BOX) / 2.0
        box = QRectF(0.5, y + 0.5, self.BOX - 1, self.BOX - 1)
        on = self.isChecked()
        if on:
            fill = QColor(THEME["accent_hover"] if self._hover else THEME["accent"])
            border = fill
        else:
            fill = QColor(THEME["field"])
            border = QColor(THEME["text"] if self._hover else "#8A8A8A")
        if not self.isEnabled():
            fill.setAlphaF(0.4)
            border.setAlphaF(0.4)
        p.setPen(QPen(border, 1.0))
        p.setBrush(fill)
        p.drawRoundedRect(box, 2, 2)
        if on:
            tick = QPen(QColor(THEME["accent_ink"]), 1.8)
            tick.setCapStyle(Qt.PenCapStyle.RoundCap)
            tick.setJoinStyle(Qt.PenJoinStyle.RoundJoin)
            p.setPen(tick)
            p.drawPolyline(QPolygonF([QPointF(3.5, y + 7.2), QPointF(6.0, y + 9.8), QPointF(10.6, y + 4.4)]))
        p.setPen(QColor(THEME["text"] if self.isEnabled() else THEME["faint"]))
        p.drawText(QRectF(self.BOX + 8, 0, self.width() - self.BOX - 8, self.height()),
                   Qt.AlignmentFlag.AlignVCenter | Qt.AlignmentFlag.AlignLeft, self.text())
        if self.hasFocus():
            p.setPen(QPen(QColor(THEME["accent"]), 1.2))
            p.setBrush(Qt.BrushStyle.NoBrush)
            p.drawRoundedRect(box.adjusted(-2, -2, 2, 2), 3, 3)
        p.end()


class LibraryListWidget(QListWidget):
    """
    Miniature della libreria: si riordinano trascinandole e si possono trascinare sulla tela.
    Nel trascinamento c'è anche l'elenco dei percorsi (formato interno, non file veri: così
    rilasciandole fuori dall'app non si copiano file per sbaglio).
    """

    def mimeData(self, items):
        data = super().mimeData(items)
        paths = [it.data(Qt.ItemDataRole.UserRole) for it in items]
        data.setData(LIBRARY_MIME, "\n".join(p for p in paths if p).encode("utf-8"))
        return data


class LibraryCheckDelegate(QStyledItemDelegate):
    """Miniatura della libreria con un segno di spunta blu ben visibile quando è selezionata."""

    def __init__(self, parent=None, on_canvas=None):
        super().__init__(parent)
        self._on_canvas = on_canvas

    def paint(self, painter: QPainter, option, index):
        super().paint(painter, option, index)
        path = index.data(Qt.ItemDataRole.UserRole)
        if self._on_canvas is not None and path and self._on_canvas(path):
            # Etichetta "sulla tela" per le foto già usate nel collage
            painter.save()
            painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
            r = QRectF(option.rect)
            font = ui_font(9, QFont.Weight.DemiBold)
            painter.setFont(font)
            label = "sulla tela"
            w = QFontMetricsF(font).horizontalAdvance(label) + 10
            pill = QRectF(r.left() + 6, r.bottom() - 20, w, 14)
            painter.setPen(Qt.PenStyle.NoPen)
            painter.setBrush(QColor(0, 0, 0, 175))
            painter.drawRoundedRect(pill, 7, 7)
            painter.setPen(QColor("#FFFFFF"))
            painter.drawText(pill, Qt.AlignmentFlag.AlignCenter, label)
            painter.restore()
        if not option.state & QStyle.StateFlag.State_Selected:
            return
        painter.save()
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        r = QRectF(option.rect)
        badge = QRectF(r.right() - 22, r.top() + 5, 17, 17)
        painter.setPen(QPen(QColor("#FFFFFF"), 1.5))
        painter.setBrush(QColor(THEME["accent"]))
        painter.drawEllipse(badge)
        tick = QPen(QColor("#FFFFFF"), 2.0)
        tick.setCapStyle(Qt.PenCapStyle.RoundCap)
        tick.setJoinStyle(Qt.PenJoinStyle.RoundJoin)
        painter.setPen(tick)
        painter.setBrush(Qt.BrushStyle.NoBrush)
        x, y = badge.x(), badge.y()
        painter.drawPolyline(QPolygonF([QPointF(x + 4.5, y + 8.8), QPointF(x + 7.4, y + 11.6), QPointF(x + 12.6, y + 5.8)]))
        painter.restore()


class DropZone(QFrame):
    """Stato vuoto della libreria: area tratteggiata cliccabile che invita a caricare le foto."""
    clicked = pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setMinimumHeight(120)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self._icon = icon_pixmap("image", THEME["muted"], 34)
        self._hover = False

    def enterEvent(self, event):
        self._hover = True
        self.update()

    def leaveEvent(self, event):
        self._hover = False
        self.update()

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self.clicked.emit()

    def paintEvent(self, event):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        r = QRectF(self.rect()).adjusted(1, 1, -1, -1)
        pen = QPen(QColor(THEME["accent"] if self._hover else THEME["edge"]), 1.0, Qt.PenStyle.DashLine)
        pen.setDashPattern([3, 3])
        p.setPen(pen)
        p.setBrush(QColor(THEME["field"]))
        p.drawRoundedRect(r, 3, 3)
        c = r.center()
        p.drawPixmap(QPointF(c.x() - 17, c.y() - 52), self._icon)
        p.setPen(QColor(THEME["text"]))
        p.setFont(ui_font(13, QFont.Weight.DemiBold))
        p.drawText(QRectF(r.left(), c.y() - 12, r.width(), 22), Qt.AlignmentFlag.AlignHCenter, "Trascina qui le foto")
        p.setPen(QColor(THEME["muted"]))
        p.setFont(ui_font(11))
        p.drawText(QRectF(r.left() + 16, c.y() + 12, r.width() - 32, 40),
                   Qt.AlignmentFlag.AlignHCenter | Qt.TextFlag.TextWordWrap,
                   "oppure clicca per sceglierle dal PC.\nNessun limite di numero.")
        p.end()
