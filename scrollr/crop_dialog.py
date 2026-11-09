"""Finestra «Ritaglia foto»: si sceglie la parte della foto da usare e le sue proporzioni."""
from typing import Optional, Tuple

from PyQt6.QtCore import Qt, QPointF, QRectF, pyqtSignal
from PyQt6.QtGui import QColor, QCursor, QPainter, QPainterPath, QPen, QPixmap, QTransform
from PyQt6.QtWidgets import (
    QButtonGroup, QDialog, QHBoxLayout, QLabel, QPushButton, QToolButton, QVBoxLayout, QWidget
)

from scrollr.icons import make_icon
from scrollr.imaging import original_size
from scrollr.theme import THEME
from scrollr.widgets import ToggleSwitch

Crop = Tuple[float, float, float, float]

# (chiave, testo, (larghezza, altezza)); None = proporzioni calcolate a parte
RATIOS = [
    ("free", "Libera", None),
    ("original", "Originale", None),
    ("cell", "Riquadro", None),
    ("1:1", "1:1", (1, 1)),
    ("4:5", "4:5", (4, 5)),
    ("3:4", "3:4", (3, 4)),
    ("2:3", "2:3", (2, 3)),
    ("9:16", "9:16", (9, 16)),
]


class CropCanvas(QWidget):
    """
    Foto intera con il riquadro del ritaglio: si trascinano gli angoli e i lati per ridimensionarlo,
    l'interno per spostarlo, e fuori dal riquadro se ne disegna uno nuovo.
    Il riquadro è in pixel dell'immagine mostrata; `ratio` (larghezza / altezza) lo tiene in forma.
    """
    changed = pyqtSignal()
    MARGIN = 18.0
    GRAB = 10.0  # Distanza in pixel dello schermo entro cui si afferra una maniglia

    def __init__(self, pixmap: QPixmap, parent=None):
        super().__init__(parent)
        self.pm = pixmap
        self.img_w = float(max(1, pixmap.width()))
        self.img_h = float(max(1, pixmap.height()))
        self.rect_img = QRectF(0, 0, self.img_w, self.img_h)
        self.ratio: Optional[float] = None
        self._drag: Optional[str] = None
        self._press_img = QPointF()
        self._press_widget = QPointF()
        self._start_rect = QRectF()
        self.setMouseTracking(True)
        self.setMinimumSize(520, 380)

    # ---------- Coordinate ----------
    def _scale(self) -> float:
        return max(1e-6, min((self.width() - 2 * self.MARGIN) / self.img_w,
                             (self.height() - 2 * self.MARGIN) / self.img_h))

    def _origin(self) -> QPointF:
        s = self._scale()
        return QPointF((self.width() - self.img_w * s) / 2.0, (self.height() - self.img_h * s) / 2.0)

    def _to_widget(self, r: QRectF) -> QRectF:
        s, o = self._scale(), self._origin()
        return QRectF(o.x() + r.x() * s, o.y() + r.y() * s, r.width() * s, r.height() * s)

    def _to_image(self, p: QPointF) -> QPointF:
        s, o = self._scale(), self._origin()
        return QPointF((p.x() - o.x()) / s, (p.y() - o.y()) / s)

    def _min_side(self) -> float:
        return max(8.0, min(self.img_w, self.img_h) * 0.03)

    # ---------- Riquadro ----------
    def set_rect(self, r: QRectF):
        self.rect_img = QRectF(r).intersected(QRectF(0, 0, self.img_w, self.img_h))
        self.update()
        self.changed.emit()

    def set_ratio(self, ratio: Optional[float]):
        """Blocca le proporzioni: il riquadro diventa il più grande possibile con quella forma, centrato."""
        self.ratio = ratio
        if ratio is None:
            return
        w = min(self.img_w, self.img_h * ratio)
        h = w / ratio
        c = self.rect_img.center()
        x = min(max(0.0, c.x() - w / 2.0), self.img_w - w)
        y = min(max(0.0, c.y() - h / 2.0), self.img_h - h)
        self.set_rect(QRectF(x, y, w, h))

    def _handle_at(self, pos: QPointF) -> Optional[str]:
        r = self._to_widget(self.rect_img)
        g = self.GRAB
        near_l, near_r = abs(pos.x() - r.left()) <= g, abs(pos.x() - r.right()) <= g
        near_t, near_b = abs(pos.y() - r.top()) <= g, abs(pos.y() - r.bottom()) <= g
        in_x = r.left() - g <= pos.x() <= r.right() + g
        in_y = r.top() - g <= pos.y() <= r.bottom() + g
        if near_t and near_l:
            return "tl"
        if near_t and near_r:
            return "tr"
        if near_b and near_l:
            return "bl"
        if near_b and near_r:
            return "br"
        if near_l and in_y:
            return "l"
        if near_r and in_y:
            return "r"
        if near_t and in_x:
            return "t"
        if near_b and in_x:
            return "b"
        if r.contains(pos):
            return "move"
        return None

    def _corner(self, ax: float, ay: float, p: QPointF, right: bool, bottom: bool) -> QRectF:
        """Riquadro con un angolo fermo in (ax, ay) e quello opposto verso il punto p."""
        mn = self._min_side()
        max_w = self.img_w - ax if right else ax
        max_h = self.img_h - ay if bottom else ay
        w = min(max(mn, (p.x() - ax) if right else (ax - p.x())), max_w)
        h = min(max(mn, (p.y() - ay) if bottom else (ay - p.y())), max_h)
        if self.ratio:
            # Il riquadro segue il puntatore sul lato che si allunga di più, poi si stringe se esce
            if w / h > self.ratio:
                h = w / self.ratio
            else:
                w = h * self.ratio
            k = min(1.0, max_w / w, max_h / h)
            w, h = w * k, h * k
        return QRectF(ax if right else ax - w, ay if bottom else ay - h, w, h)

    def _edge(self, handle: str, p: QPointF) -> QRectF:
        sr = self._start_rect
        mn = self._min_side()
        if handle in ("l", "r"):
            ax = sr.left() if handle == "r" else sr.right()
            max_w = self.img_w - ax if handle == "r" else ax
            w = min(max(mn, (p.x() - ax) if handle == "r" else (ax - p.x())), max_w)
            h, y = sr.height(), sr.top()
            if self.ratio:
                cy = sr.center().y()
                h = min(w / self.ratio, 2.0 * min(cy, self.img_h - cy))
                w = h * self.ratio
                y = cy - h / 2.0
            return QRectF(ax if handle == "r" else ax - w, y, w, h)
        ay = sr.top() if handle == "b" else sr.bottom()
        max_h = self.img_h - ay if handle == "b" else ay
        h = min(max(mn, (p.y() - ay) if handle == "b" else (ay - p.y())), max_h)
        w, x = sr.width(), sr.left()
        if self.ratio:
            cx = sr.center().x()
            w = min(h * self.ratio, 2.0 * min(cx, self.img_w - cx))
            h = w / self.ratio
            x = cx - w / 2.0
        return QRectF(x, ay if handle == "b" else ay - h, w, h)

    # ---------- Mouse ----------
    def _cursor_for(self, handle: Optional[str]) -> Qt.CursorShape:
        return {
            "tl": Qt.CursorShape.SizeFDiagCursor, "br": Qt.CursorShape.SizeFDiagCursor,
            "tr": Qt.CursorShape.SizeBDiagCursor, "bl": Qt.CursorShape.SizeBDiagCursor,
            "l": Qt.CursorShape.SizeHorCursor, "r": Qt.CursorShape.SizeHorCursor,
            "t": Qt.CursorShape.SizeVerCursor, "b": Qt.CursorShape.SizeVerCursor,
            "move": Qt.CursorShape.SizeAllCursor,
        }.get(handle, Qt.CursorShape.CrossCursor)

    def mousePressEvent(self, event):
        if event.button() != Qt.MouseButton.LeftButton:
            return
        pos = event.position()
        self._drag = self._handle_at(pos) or "new"
        self._press_widget = pos
        p = self._to_image(pos)
        self._press_img = QPointF(min(max(0.0, p.x()), self.img_w), min(max(0.0, p.y()), self.img_h))
        self._start_rect = QRectF(self.rect_img)

    def mouseMoveEvent(self, event):
        pos = event.position()
        if self._drag is None:
            self.setCursor(QCursor(self._cursor_for(self._handle_at(pos))))
            return
        p = self._to_image(pos)
        sr = self._start_rect
        if self._drag == "move":
            d = p - self._press_img
            x = min(max(0.0, sr.x() + d.x()), self.img_w - sr.width())
            y = min(max(0.0, sr.y() + d.y()), self.img_h - sr.height())
            self.set_rect(QRectF(x, y, sr.width(), sr.height()))
        elif self._drag == "new":
            # Riquadro nuovo disegnato da dove si è premuto (solo se il mouse si è mosso davvero)
            if (pos - self._press_widget).manhattanLength() < 5:
                return
            a = self._press_img
            self.set_rect(self._corner(a.x(), a.y(), p, p.x() >= a.x(), p.y() >= a.y()))
        elif len(self._drag) == 2:
            right, bottom = "r" in self._drag, "b" in self._drag
            ax = sr.left() if right else sr.right()
            ay = sr.top() if bottom else sr.bottom()
            self.set_rect(self._corner(ax, ay, p, right, bottom))
        else:
            self.set_rect(self._edge(self._drag, p))

    def mouseReleaseEvent(self, event):
        self._drag = None
        self.setCursor(QCursor(self._cursor_for(self._handle_at(event.position()))))

    # ---------- Disegno ----------
    def paintEvent(self, event):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        p.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, True)
        p.fillRect(self.rect(), QColor(THEME["backdrop"]))
        full = self._to_widget(QRectF(0, 0, self.img_w, self.img_h))
        p.drawPixmap(full, self.pm, QRectF(self.pm.rect()))

        crop = self._to_widget(self.rect_img)
        # Fuori dal ritaglio la foto si scurisce
        outside = QPainterPath()
        outside.addRect(full)
        inner = QPainterPath()
        inner.addRect(crop)
        p.fillPath(outside.subtracted(inner), QColor(0, 0, 0, 150))

        # Terzi, bordo e maniglie
        ink = QColor(THEME["accent_ink"])
        thirds = QColor(ink)
        thirds.setAlpha(90)
        p.setPen(QPen(thirds, 1.0))
        for k in (1, 2):
            x = crop.left() + crop.width() * k / 3.0
            y = crop.top() + crop.height() * k / 3.0
            p.drawLine(QPointF(x, crop.top()), QPointF(x, crop.bottom()))
            p.drawLine(QPointF(crop.left(), y), QPointF(crop.right(), y))
        p.setPen(QPen(ink, 1.5))
        p.setBrush(Qt.BrushStyle.NoBrush)
        p.drawRect(crop)
        # Angoli a L, più spessi
        p.setPen(QPen(ink, 4.0, Qt.PenStyle.SolidLine, Qt.PenCapStyle.SquareCap))
        arm = min(18.0, crop.width() / 3.0, crop.height() / 3.0)
        for cx, cy, sx, sy in ((crop.left(), crop.top(), 1, 1), (crop.right(), crop.top(), -1, 1),
                               (crop.left(), crop.bottom(), 1, -1), (crop.right(), crop.bottom(), -1, -1)):
            p.drawLine(QPointF(cx, cy), QPointF(cx + sx * arm, cy))
            p.drawLine(QPointF(cx, cy), QPointF(cx, cy + sy * arm))
        # Tacche a metà dei lati
        half = min(9.0, crop.width() / 6.0, crop.height() / 6.0)
        c = crop.center()
        p.drawLine(QPointF(c.x() - half, crop.top()), QPointF(c.x() + half, crop.top()))
        p.drawLine(QPointF(c.x() - half, crop.bottom()), QPointF(c.x() + half, crop.bottom()))
        p.drawLine(QPointF(crop.left(), c.y() - half), QPointF(crop.left(), c.y() + half))
        p.drawLine(QPointF(crop.right(), c.y() - half), QPointF(crop.right(), c.y() + half))
        p.end()


class CropDialog(QDialog):
    """
    Ritaglio di una foto della tela. Si lavora sulla foto come appare (specchiata se lo è);
    crop() restituisce il ritaglio sulla foto originale, in frazioni (sinistra, alto, destra, basso).
    """

    def __init__(self, pixmap: QPixmap, crop: Crop, flip_h: bool, flip_v: bool, cell_ratio: float,
                 path: str, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Ritaglia foto")
        self.flip_h, self.flip_v = flip_h, flip_v
        self.cell_ratio = cell_ratio
        self.orig_size = original_size(path)
        self._swapped = False
        shown = pixmap
        if flip_h or flip_v:
            shown = pixmap.transformed(QTransform().scale(-1.0 if flip_h else 1.0, -1.0 if flip_v else 1.0))

        lay = QVBoxLayout(self)
        lay.setContentsMargins(16, 14, 16, 14)
        lay.setSpacing(10)

        # Proporzioni
        row = QHBoxLayout()
        row.setSpacing(6)
        title = QLabel("Proporzioni")
        title.setObjectName("FieldLabel")
        row.addWidget(title)
        self.ratio_buttons = {}
        group = QButtonGroup(self)
        group.setExclusive(True)
        tips = {"free": "Ritaglio di qualsiasi forma", "original": "Stessa forma della foto intera",
                "cell": "Stessa forma del riquadro attuale sulla tela"}
        for key, text, _wh in RATIOS:
            b = QToolButton()
            b.setObjectName("SoftButton")
            b.setText(text)
            b.setCheckable(True)
            b.setCursor(Qt.CursorShape.PointingHandCursor)
            b.setToolTip(tips.get(key, f"Proporzioni {text}"))
            b.clicked.connect(lambda _=False, k=key: self._set_ratio_key(k))
            group.addButton(b)
            self.ratio_buttons[key] = b
            row.addWidget(b)
        self._ratio_group = group
        self.btn_swap = QToolButton()
        self.btn_swap.setObjectName("SoftButton")
        self.btn_swap.setIcon(make_icon("swap", THEME["text"]))
        self.btn_swap.setToolTip("Scambia verticale e orizzontale (es. 4:5 ⇄ 5:4)")
        self.btn_swap.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_swap.clicked.connect(self._swap)
        row.addWidget(self.btn_swap)
        row.addStretch()
        lay.addLayout(row)

        self.canvas = CropCanvas(shown)
        self.canvas.changed.connect(self._update_info)
        lay.addWidget(self.canvas, 1)

        hint = QLabel("Trascina gli angoli o i lati per ritagliare, l'interno per spostare il ritaglio, "
                      "fuori per disegnarne uno nuovo.")
        hint.setObjectName("FieldLabel")
        hint.setWordWrap(True)
        lay.addWidget(hint)

        info_row = QHBoxLayout()
        self.info = QLabel()
        self.info.setObjectName("FieldLabel")
        info_row.addWidget(self.info)
        info_row.addStretch()
        self.chk_fit = ToggleSwitch("Dai al riquadro sulla tela la forma del ritaglio")
        self.chk_fit.setChecked(True)
        self.chk_fit.setToolTip("Il riquadro della foto prende le proporzioni scelte, tenendo fermo il centro.\n"
                                "Se lo spegni, il riquadro resta com'è e il ritaglio lo riempie.")
        info_row.addWidget(self.chk_fit)
        lay.addLayout(info_row)

        foot = QHBoxLayout()
        whole = QPushButton("Foto intera")
        whole.setObjectName("Ghost")
        whole.setToolTip("Togli il ritaglio: torna a tutta la foto")
        whole.setCursor(Qt.CursorShape.PointingHandCursor)
        whole.clicked.connect(self._whole)
        foot.addWidget(whole)
        foot.addStretch()
        cancel = QPushButton("Annulla")
        cancel.setCursor(Qt.CursorShape.PointingHandCursor)
        cancel.clicked.connect(self.reject)
        ok = QPushButton("Applica")
        ok.setObjectName("Primary")
        ok.setDefault(True)
        ok.setCursor(Qt.CursorShape.PointingHandCursor)
        ok.clicked.connect(self.accept)
        foot.addWidget(cancel)
        foot.addWidget(ok)
        lay.addLayout(foot)

        # Ritaglio di partenza (sulla foto come appare) e proporzioni che gli corrispondono
        x0, y0, x1, y1 = self._mirror(crop)
        w, h = self.canvas.img_w, self.canvas.img_h
        self.canvas.set_rect(QRectF(x0 * w, y0 * h, (x1 - x0) * w, (y1 - y0) * h))
        self._select_initial_ratio()
        self._update_labels()
        self._update_info()
        self.resize(760, 620)

    # ---------- Proporzioni ----------
    def _mirror(self, c: Crop) -> Crop:
        """Da foto originale a foto come appare (e viceversa: l'operazione è la stessa)."""
        x0, y0, x1, y1 = c
        if self.flip_h:
            x0, x1 = 1.0 - x1, 1.0 - x0
        if self.flip_v:
            y0, y1 = 1.0 - y1, 1.0 - y0
        return (x0, y0, x1, y1)

    def _ratio_for(self, key: str) -> Optional[float]:
        if key == "original":
            return self.canvas.img_w / self.canvas.img_h
        if key == "cell":
            return self.cell_ratio
        wh = dict((k, v) for k, _t, v in RATIOS).get(key)
        if wh is None:
            return None
        a, b = wh
        return b / a if self._swapped else a / b

    def _current_key(self) -> str:
        return next((k for k, b in self.ratio_buttons.items() if b.isChecked()), "free")

    def _set_ratio_key(self, key: str):
        self.ratio_buttons[key].setChecked(True)
        self.btn_swap.setEnabled(dict((k, v) for k, _t, v in RATIOS).get(key) not in (None, (1, 1)))
        self.canvas.set_ratio(self._ratio_for(key))

    def _swap(self):
        self._swapped = not self._swapped
        self._update_labels()
        key = self._current_key()
        self.canvas.set_ratio(self._ratio_for(key))

    def _update_labels(self):
        for key, text, wh in RATIOS:
            if wh is not None and self._swapped:
                self.ratio_buttons[key].setText(f"{wh[1]}:{wh[0]}")
            else:
                self.ratio_buttons[key].setText(text)

    def _select_initial_ratio(self):
        """Un ritaglio che ha già una forma pronta riapre la finestra con quella forma scelta."""
        r = self.canvas.rect_img
        current = r.width() / r.height() if r.height() > 0 else 1.0
        is_whole = r.width() >= self.canvas.img_w - 0.5 and r.height() >= self.canvas.img_h - 0.5
        if not is_whole:
            for key, _text, wh in RATIOS:
                if wh is None:
                    continue
                for swapped in (False, True):
                    target = wh[1] / wh[0] if swapped else wh[0] / wh[1]
                    if abs(current / target - 1.0) < 0.006:
                        self._swapped = swapped
                        self.ratio_buttons[key].setChecked(True)
                        self.btn_swap.setEnabled(wh != (1, 1))
                        self.canvas.ratio = target
                        return
        self.ratio_buttons["free"].setChecked(True)
        self.btn_swap.setEnabled(False)

    def _whole(self):
        self.ratio_buttons["free"].setChecked(True)
        self.btn_swap.setEnabled(False)
        self.canvas.ratio = None
        self.canvas.set_rect(QRectF(0, 0, self.canvas.img_w, self.canvas.img_h))

    def _update_info(self):
        c = self.crop()
        if self.orig_size:
            ow, oh = self.orig_size
            w, h = round((c[2] - c[0]) * ow), round((c[3] - c[1]) * oh)
            self.info.setText(f"Ritaglio: {w} × {h} px")
        else:
            self.info.setText("")

    # ---------- Risultato ----------
    def crop(self) -> Crop:
        r = self.canvas.rect_img
        w, h = self.canvas.img_w, self.canvas.img_h
        return self._mirror((r.left() / w, r.top() / h, r.right() / w, r.bottom() / h))

    def fit_cell(self) -> bool:
        return self.chk_fit.isChecked()
