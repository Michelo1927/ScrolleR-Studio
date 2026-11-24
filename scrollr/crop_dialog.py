"""Finestra «Ritaglia foto»: si sceglie la parte della foto da usare (rettangolo) oppure se ne disegna a mano la sagoma."""
import math
from typing import List, Optional, Tuple

from PIL import Image
from PyQt6.QtCore import Qt, QPointF, QRectF, pyqtSignal
from PyQt6.QtGui import (
    QBrush, QColor, QCursor, QImage, QKeySequence, QPainter, QPainterPath, QPen, QPixmap, QPolygonF, QTransform
)
from PyQt6.QtWidgets import (
    QButtonGroup, QDialog, QHBoxLayout, QLabel, QPushButton, QSlider, QToolButton, QVBoxLayout, QWidget
)

from scrollr.cutout import DEFAULT_SOFT, MAX_SOFT, MIN_POINTS, Points, clean_cutout, clean_soft, cut_image, simplify
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

MODE_RECT = "rect"
MODE_CUT = "cutout"


class CropCanvas(QWidget):
    """
    Foto intera con due modi di lavoro.
    - Rettangolo: il riquadro del ritaglio; si trascinano gli angoli e i lati per ridimensionarlo, l'interno per
      spostarlo, e fuori dal riquadro se ne disegna uno nuovo. `ratio` (larghezza / altezza) lo tiene in forma.
    - Sagoma: un contorno di punti disegnato a mano (clic per punti, trascinamento per il tratto libero),
      con zoom e spostamento della vista.
    Riquadro e punti sono in pixel dell'immagine mostrata (già specchiata).
    """
    changed = pyqtSignal()        # Il riquadro è cambiato
    shape_changed = pyqtSignal()  # La sagoma (punti, chiusura) è cambiata
    MARGIN = 18.0
    GRAB = 10.0        # Distanza in pixel dello schermo entro cui si afferra una maniglia
    DRAG_PX = 4.0      # Spostamento oltre il quale un clic diventa un tratto a mano libera
    STEP_PX = 3.0      # Distanza (schermo) tra due punti campionati nel tratto a mano libera
    ZOOM_MAX = 8.0
    PREVIEW_MAX = 1600  # Lato lungo (px) dell'immagine su cui si calcola l'anteprima dello scontorno
    HANDLE_R = 4.5

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
        # Sagoma
        self.mode = MODE_RECT
        self.pts: List[QPointF] = []
        self.closed = False
        self.soft = DEFAULT_SOFT
        self.preview = False
        self._stroke: List[QPointF] = []
        self._cut_drag: Optional[str] = None  # pending, free, vertex, shape, pan
        self._drag_idx = -1
        self._start_pts: List[QPointF] = []
        self._start_pan = QPointF()
        self._mouse: Optional[QPointF] = None
        self._space = False
        self._src: Optional[Image.Image] = None
        # Annulla/Ripeti della sagoma: stati (punti, chiusa) prima di ogni modifica
        self._undo: List[Tuple[List[QPointF], bool]] = []
        self._redo: List[Tuple[List[QPointF], bool]] = []
        self._drag_saved = False  # Lo stato prima del trascinamento in corso è già nella cronologia
        self._result_pm: Optional[QPixmap] = None
        # Vista (zoom e spostamento, solo in Sagoma)
        self._zoom = 1.0
        self._pan = QPointF()
        self._checker = self._make_checker()
        self.setMouseTracking(True)
        self.setFocusPolicy(Qt.FocusPolicy.ClickFocus)
        self.setMinimumSize(520, 380)

    # ---------- Coordinate ----------
    def _fit_scale(self) -> float:
        return max(1e-6, min((self.width() - 2 * self.MARGIN) / self.img_w,
                             (self.height() - 2 * self.MARGIN) / self.img_h))

    def _scale(self) -> float:
        return self._fit_scale() * self._zoom

    def _centered(self, s: float) -> QPointF:
        return QPointF((self.width() - self.img_w * s) / 2.0, (self.height() - self.img_h * s) / 2.0)

    def _axis_origin(self, view: float, size: float, centered: float, pan: float) -> float:
        """Origine su un asse: la foto resta centrata finché ci sta, poi si sposta senza uscire dalla vista."""
        if size <= view - 2 * self.MARGIN + 0.01:
            return centered
        return min(max(centered + pan, view - self.MARGIN - size), self.MARGIN)

    def _origin(self) -> QPointF:
        s = self._scale()
        c = self._centered(s)
        return QPointF(self._axis_origin(self.width(), self.img_w * s, c.x(), self._pan.x()),
                       self._axis_origin(self.height(), self.img_h * s, c.y(), self._pan.y()))

    def _to_widget(self, r: QRectF) -> QRectF:
        s, o = self._scale(), self._origin()
        return QRectF(o.x() + r.x() * s, o.y() + r.y() * s, r.width() * s, r.height() * s)

    def _to_image(self, p: QPointF) -> QPointF:
        s, o = self._scale(), self._origin()
        return QPointF((p.x() - o.x()) / s, (p.y() - o.y()) / s)

    def _pt_to_widget(self, q: QPointF) -> QPointF:
        s, o = self._scale(), self._origin()
        return QPointF(o.x() + q.x() * s, o.y() + q.y() * s)

    def _clamp_img(self, q: QPointF) -> QPointF:
        return QPointF(min(max(0.0, q.x()), self.img_w), min(max(0.0, q.y()), self.img_h))

    def _screen_dist(self, a: QPointF, b: QPointF) -> float:
        """Distanza in pixel dello schermo tra due punti in pixel dell'immagine."""
        return math.hypot(a.x() - b.x(), a.y() - b.y()) * self._scale()

    def _min_side(self) -> float:
        return max(8.0, min(self.img_w, self.img_h) * 0.03)

    # ---------- Modo, vista ----------
    def set_mode(self, mode: str):
        if mode == self.mode:
            return
        self.mode = mode
        self._drag = None
        self._cut_drag = None
        self._stroke = []
        self._space = False
        if mode == MODE_RECT:
            self.reset_view()
        self._update_cursor()
        self.update()
        self.shape_changed.emit()

    def reset_view(self):
        self._zoom = 1.0
        self._pan = QPointF()
        self.update()

    def zoom(self) -> float:
        return self._zoom

    def _normalize_pan(self):
        """Il valore salvato dello spostamento è quello effettivo (dopo i limiti della vista)."""
        o = self._origin()
        c = self._centered(self._scale())
        self._pan = QPointF(o.x() - c.x(), o.y() - c.y())

    def zoom_at(self, pos: QPointF, factor: float):
        """Cambia lo zoom tenendo fermo il punto della foto sotto il cursore."""
        anchor = self._to_image(pos)
        self._zoom = min(max(1.0, self._zoom * factor), self.ZOOM_MAX)
        s = self._scale()
        c = self._centered(s)
        self._pan = QPointF(pos.x() - anchor.x() * s - c.x(), pos.y() - anchor.y() * s - c.y())
        self._normalize_pan()
        self._update_cursor()
        self.update()

    def _begin_pan(self, pos: QPointF):
        self._cut_drag = "pan"
        self._press_widget = pos
        self._start_pan = QPointF(self._pan)
        self._update_cursor()

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

    # ---------- Sagoma: Annulla/Ripeti ----------
    UNDO_MAX = 200

    def _state(self) -> Tuple[List[QPointF], bool]:
        return [QPointF(q) for q in self.pts], self.closed

    def _push_undo(self):
        """Ricorda la sagoma com'è prima di una modifica (così si può tornare indietro)."""
        self._undo.append(self._state())
        del self._undo[:-self.UNDO_MAX]
        self._redo.clear()

    def can_undo(self) -> bool:
        return bool(self._undo)

    def can_redo(self) -> bool:
        return bool(self._redo)

    def _restore(self, state: Tuple[List[QPointF], bool]):
        self.pts, self.closed = [QPointF(q) for q in state[0]], state[1]
        self._cut_drag = None
        self._stroke = []
        self._shape_edited()

    def undo_shape(self) -> bool:
        if not self._undo:
            return False
        self._redo.append(self._state())
        self._restore(self._undo.pop())
        return True

    def redo_shape(self) -> bool:
        if not self._redo:
            return False
        self._undo.append(self._state())
        self._restore(self._redo.pop())
        return True

    def reopen_shape(self) -> bool:
        """Riapre la sagoma chiusa: si continua ad aggiungere punti dall'ultimo."""
        if not self.closed:
            return False
        self._push_undo()
        self.closed = False
        self._shape_edited()
        return True

    # ---------- Sagoma: dati ----------
    def set_shape(self, points: List[QPointF], closed: bool):
        """Imposta la sagoma (punti in pixel dell'immagine mostrata)."""
        self.pts = [self._clamp_img(q) for q in points]
        self.closed = closed and len(self.pts) >= MIN_POINTS
        self._stroke = []
        self._shape_edited()

    def shape_fractions(self) -> Optional[Points]:
        """I punti della sagoma chiusa in frazioni 0..1 dell'immagine mostrata; None se non è chiusa."""
        if not self.closed:
            return None
        return [(q.x() / self.img_w, q.y() / self.img_h) for q in self.pts]

    def clear_shape(self):
        if self.pts:
            self._push_undo()
        self._cut_drag = None
        self.pts = []
        self.closed = False
        self._stroke = []
        self._shape_edited()

    def close_shape(self) -> bool:
        if self.closed or len(self.pts) < MIN_POINTS:
            return False
        self._push_undo()
        self.closed = True
        self._shape_edited()
        return True

    def set_soft(self, value: int):
        self.soft = clean_soft(value)
        self._result_pm = None
        self.update()

    def set_preview(self, on: bool):
        self.preview = bool(on)
        self._cut_drag = None
        self._update_cursor()
        self.update()

    def _shape_edited(self):
        self._result_pm = None
        self._update_cursor()
        self.update()
        self.shape_changed.emit()

    def _add_point(self, q: QPointF):
        if self.pts and self._screen_dist(self.pts[-1], q) < 2.0:
            return
        self._push_undo()
        self.pts.append(QPointF(q))
        self._shape_edited()

    def _shape_path(self) -> QPainterPath:
        path = QPainterPath()
        if self.pts:
            path.addPolygon(QPolygonF(self.pts))
            path.closeSubpath()
        path.setFillRule(Qt.FillRule.WindingFill)  # Come la maschera vera (scrollr/cutout.py)
        return path

    # ---------- Sagoma: ricerche ----------
    def _vertex_at(self, pos: QPointF) -> Optional[int]:
        best, best_d = None, self.GRAB
        for i, q in enumerate(self.pts):
            d = math.hypot(pos.x() - self._pt_to_widget(q).x(), pos.y() - self._pt_to_widget(q).y())
            if d <= best_d:
                best, best_d = i, d
        return best

    def _near_first(self, pos: QPointF) -> bool:
        if not self.pts:
            return False
        f = self._pt_to_widget(self.pts[0])
        return math.hypot(pos.x() - f.x(), pos.y() - f.y()) <= self.GRAB

    def _edge_at(self, pos: QPointF) -> Optional[Tuple[int, QPointF]]:
        """Il lato della sagoma chiusa vicino a `pos`: (indice del punto che lo precede, punto sul lato in pixel immagine)."""
        n = len(self.pts)
        best: Optional[Tuple[int, QPointF]] = None
        best_d = self.GRAB
        for i in range(n):
            a, b = self._pt_to_widget(self.pts[i]), self._pt_to_widget(self.pts[(i + 1) % n])
            dx, dy = b.x() - a.x(), b.y() - a.y()
            den = dx * dx + dy * dy
            t = 0.0 if den < 1e-9 else min(1.0, max(0.0, ((pos.x() - a.x()) * dx + (pos.y() - a.y()) * dy) / den))
            px, py = a.x() + t * dx, a.y() + t * dy
            d = math.hypot(pos.x() - px, pos.y() - py)
            if d <= best_d:
                best_d, best = d, (i, self._clamp_img(self._to_image(QPointF(px, py))))
        return best

    # ---------- Sagoma: anteprima dello scontorno ----------
    def _source_image(self) -> Image.Image:
        """La foto mostrata come immagine Pillow (ridotta se enorme), tenuta per i calcoli dell'anteprima."""
        if self._src is None:
            img = self.pm.toImage().convertToFormat(QImage.Format.Format_RGBA8888)
            ptr = img.constBits()
            ptr.setsize(img.sizeInBytes())
            pil = Image.frombuffer("RGBA", (img.width(), img.height()), bytes(ptr), "raw", "RGBA",
                                   img.bytesPerLine(), 1)
            longest = max(pil.size)
            if longest > self.PREVIEW_MAX:
                k = self.PREVIEW_MAX / longest
                pil = pil.resize((max(1, round(pil.width * k)), max(1, round(pil.height * k))),
                                 Image.Resampling.BILINEAR)
            self._src = pil
        return self._src

    def _result_pixmap(self) -> QPixmap:
        """La foto scontornata; si ricalcola solo quando cambiano i punti o la morbidezza."""
        if self._result_pm is None:
            out = cut_image(self._source_image(), self.shape_fractions() or [], self.soft)
            data = out.tobytes()
            qi = QImage(data, out.width, out.height, 4 * out.width, QImage.Format.Format_RGBA8888).copy()
            self._result_pm = QPixmap.fromImage(qi)
        return self._result_pm

    @staticmethod
    def _make_checker() -> QPixmap:
        """Tassello della scacchiera della trasparenza (due caselle per lato)."""
        n = 8
        tile = QPixmap(2 * n, 2 * n)
        tile.fill(QColor(THEME["checker_light"]))
        p = QPainter(tile)
        p.fillRect(0, 0, n, n, QColor(THEME["checker_dark"]))
        p.fillRect(n, n, n, n, QColor(THEME["checker_dark"]))
        p.end()
        return tile

    # ---------- Mouse ----------
    def _cursor_for(self, handle: Optional[str]) -> Qt.CursorShape:
        return {
            "tl": Qt.CursorShape.SizeFDiagCursor, "br": Qt.CursorShape.SizeFDiagCursor,
            "tr": Qt.CursorShape.SizeBDiagCursor, "bl": Qt.CursorShape.SizeBDiagCursor,
            "l": Qt.CursorShape.SizeHorCursor, "r": Qt.CursorShape.SizeHorCursor,
            "t": Qt.CursorShape.SizeVerCursor, "b": Qt.CursorShape.SizeVerCursor,
            "move": Qt.CursorShape.SizeAllCursor,
        }.get(handle, Qt.CursorShape.CrossCursor)

    def _update_cursor(self, pos: Optional[QPointF] = None):
        if self.mode == MODE_RECT:
            if pos is not None:
                self.setCursor(QCursor(self._cursor_for(self._handle_at(pos))))
            return
        pos = pos if pos is not None else self._mouse
        shape = Qt.CursorShape.CrossCursor
        if self._cut_drag in ("pan", "vertex", "shape"):
            shape = Qt.CursorShape.ClosedHandCursor
        elif self._space:
            shape = Qt.CursorShape.OpenHandCursor
        elif self.preview:
            shape = Qt.CursorShape.OpenHandCursor if self._zoom > 1.0 else Qt.CursorShape.ArrowCursor
        elif self.closed:
            over = pos is not None and (self._vertex_at(pos) is not None
                                        or self._shape_path().contains(self._to_image(pos)))
            shape = Qt.CursorShape.OpenHandCursor if over or self._zoom > 1.0 else Qt.CursorShape.ArrowCursor
        self.setCursor(QCursor(shape))

    def mousePressEvent(self, event):
        if self.mode == MODE_CUT:
            self._cut_press(event)
            return
        if event.button() != Qt.MouseButton.LeftButton:
            return
        pos = event.position()
        self._drag = self._handle_at(pos) or "new"
        self._press_widget = pos
        p = self._to_image(pos)
        self._press_img = QPointF(min(max(0.0, p.x()), self.img_w), min(max(0.0, p.y()), self.img_h))
        self._start_rect = QRectF(self.rect_img)

    def mouseMoveEvent(self, event):
        if self.mode == MODE_CUT:
            self._cut_move(event)
            return
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
        if self.mode == MODE_CUT:
            self._cut_release(event)
            return
        self._drag = None
        self.setCursor(QCursor(self._cursor_for(self._handle_at(event.position()))))

    def mouseDoubleClickEvent(self, event):
        if self.mode == MODE_CUT:
            self._cut_double(event)
            return
        self.mousePressEvent(event)

    def wheelEvent(self, event):
        dy = event.angleDelta().y()
        if self.mode != MODE_CUT or dy == 0:
            event.ignore()
            return
        self.zoom_at(event.position(), 1.2 ** (dy / 120.0))
        event.accept()

    def leaveEvent(self, event):
        self._mouse = None
        self.update()
        super().leaveEvent(event)

    def enterEvent(self, event):
        if self.mode == MODE_CUT:
            self.setFocus()  # Per la barra spaziatrice (spostamento) e i tasti della sagoma
        super().enterEvent(event)

    # ---------- Sagoma: mouse ----------
    def _cut_press(self, event):
        pos = event.position()
        btn = event.button()
        self._cut_drag = None
        self._mouse = pos
        if btn == Qt.MouseButton.MiddleButton or (btn == Qt.MouseButton.LeftButton and self._space):
            self._begin_pan(pos)
            return
        if self.preview:
            # Nell'anteprima del risultato si può solo muovere la vista
            if btn == Qt.MouseButton.LeftButton and self._zoom > 1.0:
                self._begin_pan(pos)
            return
        if btn == Qt.MouseButton.RightButton:
            if self.closed:
                i = self._vertex_at(pos)
                if i is not None and len(self.pts) > MIN_POINTS:
                    self._push_undo()
                    del self.pts[i]
                    self._shape_edited()
            return
        if btn != Qt.MouseButton.LeftButton:
            return
        self._press_widget = pos
        self._press_img = self._clamp_img(self._to_image(pos))
        self._drag_saved = False
        if not self.closed:
            self._cut_drag = "pending"
            return
        i = self._vertex_at(pos)
        if i is not None:
            self._cut_drag, self._drag_idx = "vertex", i
        elif self._shape_path().contains(self._to_image(pos)):
            self._cut_drag = "shape"
            self._start_pts = [QPointF(q) for q in self.pts]
        elif self._zoom > 1.0:
            self._begin_pan(pos)
        self._update_cursor(pos)

    def _cut_move(self, event):
        pos = event.position()
        self._mouse = pos
        d = self._cut_drag
        if d == "pan":
            self._pan = self._start_pan + (pos - self._press_widget)
            self._normalize_pan()
            self.update()
            return
        if d == "pending":
            if math.hypot(pos.x() - self._press_widget.x(), pos.y() - self._press_widget.y()) <= self.DRAG_PX:
                return
            # Si è trascinato: tratto a mano libera che parte dal punto premuto
            d = self._cut_drag = "free"
            self._stroke = [QPointF(self._press_img)]
        if d == "free":
            q = self._clamp_img(self._to_image(pos))
            if self._screen_dist(self._stroke[-1], q) >= self.STEP_PX:
                self._stroke.append(q)
            self.update()
            return
        if d in ("vertex", "shape") and not self._drag_saved:
            self._push_undo()
            self._drag_saved = True
        if d == "vertex":
            self.pts[self._drag_idx] = self._clamp_img(self._to_image(pos))
            self._shape_edited()
            return
        if d == "shape":
            delta = self._to_image(pos) - self._to_image(self._press_widget)
            xs = [q.x() for q in self._start_pts]
            ys = [q.y() for q in self._start_pts]
            dx = min(max(delta.x(), -min(xs)), self.img_w - max(xs))
            dy = min(max(delta.y(), -min(ys)), self.img_h - max(ys))
            self.pts = [QPointF(q.x() + dx, q.y() + dy) for q in self._start_pts]
            self._shape_edited()
            return
        self._update_cursor(pos)
        self.update()  # Il tratteggio fino al mouse e il primo punto evidenziato

    def _cut_release(self, event):
        d = self._cut_drag
        self._cut_drag = None
        if d == "pending" and event.button() == Qt.MouseButton.LeftButton:
            if len(self.pts) >= MIN_POINTS and self._near_first(event.position()):
                self.close_shape()
            else:
                self._add_point(self._press_img)
        elif d == "free":
            self._finish_stroke()
        self._update_cursor(event.position())
        self.update()

    def _cut_double(self, event):
        pos = event.position()
        self._cut_drag = None
        if event.button() == Qt.MouseButton.MiddleButton:
            self.reset_view()
            return
        if event.button() != Qt.MouseButton.LeftButton or self.preview or self._space:
            return
        if not self.closed:
            self.close_shape()  # Il primo clic del doppio clic ha già messo l'ultimo punto
        elif self._vertex_at(pos) is None:
            hit = self._edge_at(pos)
            if hit is not None:
                self._push_undo()
                self.pts.insert(hit[0] + 1, hit[1])
                self._shape_edited()

    def _finish_stroke(self):
        """Fine del tratto a mano libera: si semplifica e si unisce ai punti; se torna al primo punto chiude."""
        stroke, self._stroke = self._stroke, []
        if not stroke:
            return
        tol = 1.0 / self._scale()  # 1 px dello schermo in pixel immagine
        new = [QPointF(x, y) for x, y in simplify([(q.x(), q.y()) for q in stroke], tol)]
        if self.pts and self._screen_dist(self.pts[-1], new[0]) < 2.0:
            new = new[1:]
        combined = self.pts + new
        close = False
        if len(combined) >= MIN_POINTS + 1:
            first = combined[0]
            reach = max(self._screen_dist(first, q) for q in combined)
            if self._screen_dist(first, combined[-1]) <= self.GRAB and reach > 3 * self.GRAB:
                combined = combined[:-1]
                close = True
        self._push_undo()
        self.pts = combined
        self.closed = close and len(combined) >= MIN_POINTS
        self._shape_edited()

    # ---------- Tastiera ----------
    def handle_key(self, event) -> bool:
        """Tasti della sagoma (Invio chiude, Indietro toglie l'ultimo punto, Esc ricomincia). True se gestito."""
        if self.mode != MODE_CUT:
            return False
        if event.matches(QKeySequence.StandardKey.Undo):
            self.undo_shape()
            return True
        if event.matches(QKeySequence.StandardKey.Redo) or (
                event.key() == Qt.Key.Key_Y and event.modifiers() & Qt.KeyboardModifier.ControlModifier):
            self.redo_shape()
            return True
        k = event.key()
        if k in (Qt.Key.Key_Return, Qt.Key.Key_Enter):
            if self.closed:
                return False
            self.close_shape()  # Con meno di 3 punti non fa nulla, ma l'Invio non deve applicare
            return True
        if k in (Qt.Key.Key_Backspace, Qt.Key.Key_Delete):
            if self.closed:
                return self.reopen_shape()  # Prima si riapre, poi si tolgono i punti uno alla volta
            if not self.pts:
                return False
            self._push_undo()
            self.pts.pop()
            self._shape_edited()
            return True
        if k == Qt.Key.Key_Escape:
            if self.pts or self._stroke:
                self.clear_shape()
                return True
            return False
        return False

    def keyPressEvent(self, event):
        if event.key() == Qt.Key.Key_Space and self.mode == MODE_CUT:
            if not event.isAutoRepeat():
                self._space = True
                self._update_cursor()
            event.accept()
            return
        if self.handle_key(event):
            event.accept()
            return
        super().keyPressEvent(event)

    def keyReleaseEvent(self, event):
        if event.key() == Qt.Key.Key_Space and not event.isAutoRepeat():
            self._space = False
            self._update_cursor()
        super().keyReleaseEvent(event)

    def focusOutEvent(self, event):
        self._space = False
        super().focusOutEvent(event)

    # ---------- Disegno ----------
    def paintEvent(self, event):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        p.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, True)
        p.fillRect(self.rect(), QColor(THEME["backdrop"]))
        if self.mode == MODE_CUT:
            self._paint_cutout(p)
        else:
            self._paint_rect(p)
        p.end()

    def _paint_rect(self, p: QPainter):
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

    def _draw_visible(self, p: QPainter, pm: QPixmap):
        """Disegna solo la parte visibile della foto (utile con lo zoom alto)."""
        full = self._to_widget(QRectF(0, 0, self.img_w, self.img_h))
        vis = full.intersected(QRectF(self.rect()))
        if vis.isEmpty():
            return
        k = pm.width() / self.img_w  # La foto scontornata può essere ridotta
        s = self._scale()
        src = QRectF((vis.left() - full.left()) / s * k, (vis.top() - full.top()) / s * k,
                     vis.width() / s * k, vis.height() / s * k)
        p.drawPixmap(vis, pm, src)

    def _draw_handle(self, p: QPainter, c: QPointF, radius: float, hot: bool):
        p.setPen(QPen(QColor(THEME["line"]), 1.5))
        p.setBrush(QColor(THEME["accent"] if hot else THEME["accent_ink"]))
        p.drawEllipse(c, radius, radius)

    def _paint_cutout(self, p: QPainter):
        full = self._to_widget(QRectF(0, 0, self.img_w, self.img_h))
        show_result = self.preview and self.closed
        if show_result:
            vis = full.intersected(QRectF(self.rect()))
            if not vis.isEmpty():
                p.setBrushOrigin(full.topLeft())
                p.fillRect(vis, QBrush(self._checker))
            self._draw_visible(p, self._result_pixmap())
        else:
            self._draw_visible(p, self.pm)
        if self._zoom > 1.001:
            p.setPen(QColor(THEME["muted"]))
            p.drawText(QRectF(self.rect()).adjusted(0, 0, -8, -4),
                       Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignBottom, f"{self._zoom:.1f}×")
        if show_result:
            return

        poly = QPolygonF([self._pt_to_widget(q) for q in self.pts])
        if self.closed:
            # Fuori dalla sagoma la foto si scurisce
            outside = QPainterPath()
            outside.addRect(full)
            inner = QPainterPath()
            inner.addPolygon(poly)
            inner.closeSubpath()
            inner.setFillRule(Qt.FillRule.WindingFill)
            p.fillPath(outside.subtracted(inner), QColor(0, 0, 0, 150))

        ink = QColor(THEME["accent_ink"])
        shadow = QColor(THEME["line"])
        shadow.setAlpha(170)
        p.setBrush(Qt.BrushStyle.NoBrush)

        def stroke_lines(draw):
            # Filo scuro sotto e colore del tema sopra, per vederlo su qualsiasi foto
            p.setPen(QPen(shadow, 3.5, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap, Qt.PenJoinStyle.RoundJoin))
            draw()
            p.setPen(QPen(ink, 1.5, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap, Qt.PenJoinStyle.RoundJoin))
            draw()

        if self.closed:
            stroke_lines(lambda: p.drawPolygon(poly))
        elif len(self.pts) >= 2:
            stroke_lines(lambda: p.drawPolyline(poly))
        if self._stroke:
            line = QPolygonF([self._pt_to_widget(q) for q in self._stroke])
            if self.pts:
                line.prepend(self._pt_to_widget(self.pts[-1]))
            stroke_lines(lambda: p.drawPolyline(line))
        elif not self.closed and self.pts and self._mouse is not None and self._cut_drag in (None, "pending"):
            # Segmento tratteggiato dall'ultimo punto al mouse
            dash = QPen(ink, 1.2, Qt.PenStyle.DashLine)
            p.setPen(dash)
            p.drawLine(self._pt_to_widget(self.pts[-1]), self._mouse)

        # Maniglie, a misura costante sullo schermo
        hover_first = (not self.closed and len(self.pts) >= MIN_POINTS and self._mouse is not None
                       and self._cut_drag is None and self._near_first(self._mouse))
        hover_idx = self._vertex_at(self._mouse) if self.closed and self._mouse is not None else None
        for i, q in enumerate(self.pts):
            c = self._pt_to_widget(q)
            if self.closed:
                self._draw_handle(p, c, self.HANDLE_R, i == hover_idx or (self._cut_drag == "vertex" and i == self._drag_idx))
            elif i == 0:
                self._draw_handle(p, c, self.HANDLE_R + (2.0 if hover_first else 1.0), hover_first)
            else:
                self._draw_handle(p, c, self.HANDLE_R - 1.5, False)


class CropDialog(QDialog):
    """
    Ritaglio di una foto della tela. Si lavora sulla foto come appare (specchiata se lo è).
    Due modi: «Rettangolo» (crop() dà il ritaglio sulla foto originale, in frazioni sinistra, alto, destra, basso)
    e «Sagoma» (cutout() dà il contorno disegnato a mano, sulla foto originale non specchiata; fuori da esso
    la foto diventa trasparente).
    """

    def __init__(self, pixmap: QPixmap, crop: Crop, flip_h: bool, flip_v: bool, cell_ratio: float,
                 path: str, parent=None, cutout: Optional[Points] = None, cutout_soft: int = DEFAULT_SOFT,
                 allow_cutout: bool = True):
        super().__init__(parent)
        self.setWindowTitle("Ritaglia foto")
        self.flip_h, self.flip_v = flip_h, flip_v
        self.cell_ratio = cell_ratio
        self.orig_size = original_size(path)
        self._swapped = False
        self._allow_cutout = allow_cutout
        initial = clean_cutout(cutout) if (allow_cutout and cutout) else None
        self._had_cutout = initial is not None
        shown = pixmap
        if flip_h or flip_v:
            shown = pixmap.transformed(QTransform().scale(-1.0 if flip_h else 1.0, -1.0 if flip_v else 1.0))

        lay = QVBoxLayout(self)
        lay.setContentsMargins(16, 14, 16, 14)
        lay.setSpacing(10)

        # Rettangolo | Sagoma
        self.mode_buttons = {}
        if allow_cutout:
            mrow = QHBoxLayout()
            mrow.setSpacing(6)
            mtitle = QLabel("Ritaglio")
            mtitle.setObjectName("FieldLabel")
            mrow.addWidget(mtitle)
            mgroup = QButtonGroup(self)
            mgroup.setExclusive(True)
            for key, text, tip in ((MODE_RECT, "Rettangolo", "Ritaglia con un riquadro"),
                                   (MODE_CUT, "Sagoma", "Disegna a mano il contorno del soggetto: il resto diventa trasparente")):
                b = QToolButton()
                b.setObjectName("SoftButton")
                b.setText(text)
                b.setCheckable(True)
                b.setCursor(Qt.CursorShape.PointingHandCursor)
                b.setToolTip(tip)
                b.clicked.connect(lambda _=False, k=key: self._set_mode(k))
                mgroup.addButton(b)
                self.mode_buttons[key] = b
                mrow.addWidget(b)
            self._mode_group = mgroup
            mrow.addStretch()
            lay.addLayout(mrow)

        # Proporzioni
        self.ratio_box = QWidget()
        row = QHBoxLayout(self.ratio_box)
        row.setContentsMargins(0, 0, 0, 0)
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
        lay.addWidget(self.ratio_box)

        # Comandi della sagoma
        self.cut_box = QWidget()
        self.slider_soft = QSlider(Qt.Orientation.Horizontal)
        self.chip_soft = QLabel()
        self.chk_result = ToggleSwitch("Mostra il risultato")
        self.btn_clear = QPushButton("Togli sagoma")
        self.btn_undo = QToolButton()
        self.btn_redo = QToolButton()
        self.btn_reopen = QToolButton()
        self.btn_fit_view = QToolButton()
        self.slider_soft.setRange(0, MAX_SOFT)
        self.slider_soft.setValue(clean_soft(cutout_soft))
        if allow_cutout:
            crow = QHBoxLayout(self.cut_box)
            crow.setContentsMargins(0, 0, 0, 0)
            crow.setSpacing(8)
            stitle = QLabel("Morbidezza")
            stitle.setObjectName("FieldLabel")
            crow.addWidget(stitle)
            self.slider_soft.setMinimumWidth(150)
            self.slider_soft.setCursor(Qt.CursorShape.PointingHandCursor)
            self.slider_soft.setToolTip("Quanto è sfumato il bordo della sagoma")
            self.slider_soft.valueChanged.connect(self._on_soft_changed)
            crow.addWidget(self.slider_soft, 1)
            self.chip_soft.setObjectName("ValueChip")
            self.chip_soft.setText(str(self.slider_soft.value()))
            crow.addWidget(self.chip_soft)
            crow.addSpacing(10)
            self.chk_result.setToolTip("Mostra la foto scontornata su una scacchiera, com'è con la sagoma applicata")
            self.chk_result.toggled.connect(self._on_result_toggled)
            crow.addWidget(self.chk_result)
            crow.addSpacing(6)
            for b, text, tip, slot in (
                    (self.btn_undo, "Indietro", "Annulla l'ultima modifica della sagoma (Ctrl+Z)",
                     lambda: self.canvas.undo_shape()),
                    (self.btn_redo, "Avanti", "Rifai la modifica annullata (Ctrl+Y)", lambda: self.canvas.redo_shape()),
                    (self.btn_reopen, "Riapri", "Riapri la sagoma chiusa per continuare ad aggiungere punti "
                                                "dall'ultimo (Backspace)", lambda: self.canvas.reopen_shape())):
                b.setObjectName("SoftButton")
                b.setText(text)
                b.setToolTip(tip)
                b.setCursor(Qt.CursorShape.PointingHandCursor)
                b.clicked.connect(slot)
                b.clicked.connect(lambda _=False: self.canvas.setFocus())
                crow.addWidget(b)
            self.btn_clear.setObjectName("Ghost")
            self.btn_clear.setToolTip("Cancella tutti i punti e ricomincia")
            self.btn_clear.setCursor(Qt.CursorShape.PointingHandCursor)
            self.btn_clear.clicked.connect(lambda: self.canvas.clear_shape())
            crow.addWidget(self.btn_clear)
            self.btn_fit_view.setObjectName("SoftButton")
            self.btn_fit_view.setText("Adatta")
            self.btn_fit_view.setToolTip("Torna alla foto intera nella finestra (doppio clic col tasto centrale)")
            self.btn_fit_view.setCursor(Qt.CursorShape.PointingHandCursor)
            self.btn_fit_view.clicked.connect(lambda: self.canvas.reset_view())
            crow.addWidget(self.btn_fit_view)
        lay.addWidget(self.cut_box)

        self.canvas = CropCanvas(shown)
        self.canvas.changed.connect(self._update_info)
        self.canvas.shape_changed.connect(self._on_shape_changed)
        lay.addWidget(self.canvas, 1)

        self.hint = QLabel()
        self.hint.setObjectName("FieldLabel")
        self.hint.setWordWrap(True)
        lay.addWidget(self.hint)

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
        self.btn_whole = QPushButton("Foto intera")
        self.btn_whole.setObjectName("Ghost")
        self.btn_whole.setToolTip("Togli il ritaglio: torna a tutta la foto")
        self.btn_whole.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_whole.clicked.connect(self._whole)
        foot.addWidget(self.btn_whole)
        foot.addStretch()
        cancel = QPushButton("Annulla")
        cancel.setCursor(Qt.CursorShape.PointingHandCursor)
        cancel.clicked.connect(self.reject)
        self.btn_ok = QPushButton("Applica")
        self.btn_ok.setObjectName("Primary")
        self.btn_ok.setDefault(True)
        self.btn_ok.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_ok.clicked.connect(self.accept)
        foot.addWidget(cancel)
        foot.addWidget(self.btn_ok)
        lay.addLayout(foot)

        # Ritaglio di partenza (sulla foto come appare) e proporzioni che gli corrispondono
        x0, y0, x1, y1 = self._mirror(crop)
        w, h = self.canvas.img_w, self.canvas.img_h
        self.canvas.set_rect(QRectF(x0 * w, y0 * h, (x1 - x0) * w, (y1 - y0) * h))
        self._select_initial_ratio()
        self._update_labels()
        # Sagoma di partenza
        self.canvas.set_soft(self.slider_soft.value())
        if initial is not None:
            pts = [QPointF(px * w, py * h) for px, py in self._mirror_points(initial)]
            self.canvas.set_shape(pts, True)
        self.resize(760, 640)
        self._set_mode(MODE_CUT if initial is not None else MODE_RECT)

    # ---------- Modo ----------
    def mode(self) -> str:
        return self.canvas.mode

    def _set_mode(self, mode: str):
        if mode == MODE_CUT and not self._allow_cutout:
            mode = MODE_RECT
        cut = mode == MODE_CUT
        self.canvas.set_mode(mode)
        if self.mode_buttons:
            self.mode_buttons[mode].setChecked(True)
        self.ratio_box.setVisible(not cut)
        self.chk_fit.setVisible(not cut)
        self.btn_whole.setVisible(not cut)
        self.cut_box.setVisible(cut)
        # In Sagoma l'Invio chiude il contorno: Applica non deve scattare da sola
        self.btn_ok.setDefault(not cut)
        if cut:
            self.canvas.setFocus()
        self._on_shape_changed()

    def _on_soft_changed(self, value: int):
        self.chip_soft.setText(str(value))
        self.canvas.set_soft(value)

    def _on_result_toggled(self, on: bool):
        self.canvas.set_preview(on and self.canvas.closed)

    def _on_shape_changed(self):
        """Aggiorna comandi, testo d'aiuto e pulsante Applica secondo lo stato della sagoma."""
        c = self.canvas
        if self._allow_cutout:
            self.chk_result.setEnabled(c.closed)
            if not c.closed and self.chk_result.isChecked():
                self.chk_result.setChecked(False)  # Senza sagoma chiusa non c'è un risultato da mostrare
            self.btn_clear.setEnabled(bool(c.pts) or bool(c._stroke))
            self.btn_undo.setEnabled(c.can_undo())
            self.btn_redo.setEnabled(c.can_redo())
            self.btn_reopen.setEnabled(c.closed)
        cut = self.mode() == MODE_CUT
        self.btn_ok.setEnabled(not cut or c.closed)
        if cut:
            if c.closed:
                text = ("Trascina i punti per sistemare la sagoma. Doppio clic su un lato aggiunge un punto, "
                        "clic destro su un punto lo toglie. Backspace o «Riapri» la riapre per continuare, "
                        "Ctrl+Z torna indietro. Rotella per lo zoom.")
            elif c.pts:
                text = ("Backspace toglie l'ultimo punto, Ctrl+Z torna indietro, Esc ricomincia. "
                        "Doppio clic, Invio o clic sul primo punto chiude la sagoma.")
            else:
                text = ("Clicca per aggiungere punti attorno al soggetto, oppure tieni premuto e trascina per "
                        "disegnare a mano libera. Chiudi cliccando sul primo punto.")
        else:
            text = ("Trascina gli angoli o i lati per ritagliare, l'interno per spostare il ritaglio, "
                    "fuori per disegnarne uno nuovo.")
            if self._had_cutout:
                text += " Applicando con il rettangolo la sagoma viene tolta."
        self.hint.setText(text)
        self._update_info()

    # ---------- Proporzioni ----------
    def _mirror(self, c: Crop) -> Crop:
        """Da foto originale a foto come appare (e viceversa: l'operazione è la stessa)."""
        x0, y0, x1, y1 = c
        if self.flip_h:
            x0, x1 = 1.0 - x1, 1.0 - x0
        if self.flip_v:
            y0, y1 = 1.0 - y1, 1.0 - y0
        return (x0, y0, x1, y1)

    def _mirror_points(self, pts: Points) -> Points:
        """Come _mirror, per i punti della sagoma."""
        return [(1.0 - x if self.flip_h else x, 1.0 - y if self.flip_v else y) for x, y in pts]

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
        if self.mode() == MODE_CUT:
            n = len(self.canvas.pts)
            self.info.setText(f"Sagoma: {n} {'punto' if n == 1 else 'punti'}")
            return
        c = self.crop()
        if self.orig_size:
            ow, oh = self.orig_size
            w, h = round((c[2] - c[0]) * ow), round((c[3] - c[1]) * oh)
            self.info.setText(f"Ritaglio: {w} × {h} px")
        else:
            self.info.setText("")

    # ---------- Tastiera ----------
    def keyPressEvent(self, event):
        """In Sagoma Invio, Indietro ed Esc servono al contorno, non a Applica o alla chiusura della finestra."""
        if self.mode() == MODE_CUT:
            if self.canvas.handle_key(event):
                event.accept()
                return
            if event.key() in (Qt.Key.Key_Return, Qt.Key.Key_Enter):
                # Sagoma già chiusa: l'Invio conferma come il pulsante Applica
                if self.btn_ok.isEnabled():
                    self.accept()
                event.accept()
                return
        super().keyPressEvent(event)

    # ---------- Risultato ----------
    def crop(self) -> Crop:
        r = self.canvas.rect_img
        w, h = self.canvas.img_w, self.canvas.img_h
        return self._mirror((r.left() / w, r.top() / h, r.right() / w, r.bottom() / h))

    def fit_cell(self) -> bool:
        return self.chk_fit.isChecked()

    def cutout(self) -> Optional[Points]:
        """La sagoma chiusa, in frazioni 0..1 della foto originale non specchiata; None se si usa il rettangolo."""
        if self.mode() != MODE_CUT:
            return None
        pts = self.canvas.shape_fractions()
        if pts is None:
            return None
        return clean_cutout(self._mirror_points(pts))

    def cutout_soft(self) -> int:
        return clean_soft(self.slider_soft.value())
