"""Finestre di dialogo: nuovo progetto, anteprima carosello, ordine delle pagine, pagine da esportare, scorciatoie e sfondo."""
from typing import TYPE_CHECKING
import os
from typing import Callable, Dict, List, Optional, Tuple

from PyQt6.QtCore import Qt, QSize, QPointF, QRect, QRectF, QTimer, pyqtSignal
from PyQt6.QtGui import QPixmap, QColor, QIcon, QPainter, QKeySequence, QShortcut
from PyQt6.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QHBoxLayout, QPushButton, QLabel, QComboBox, QColorDialog,
    QButtonGroup, QDialog, QRadioButton, QListWidget, QListWidgetItem, QListView, QAbstractItemView, QLineEdit,
    QSizePolicy, QScrollArea, QGridLayout, QFrame, QToolButton, QSpinBox, QAbstractSpinBox
)

from scrollr.icons import make_icon, ratio_icon, rounded_thumb, swatch_icon
from scrollr.keys import SHORTCUTS, kb
from scrollr.imaging import IMAGE_CACHE
from scrollr.theme import THEME

if TYPE_CHECKING:
    from scrollr.window.main_window import MainWindow


class PageViewer(QWidget):
    """
    Una pagina dell'anteprima, con zoom: rotella (verso il puntatore), doppio clic per ingrandire o
    tornare ad Adatta, trascinamento per spostarsi quando la pagina è più grande della finestra.

    La pagina intera arriva già pronta e grande (di solito il doppio della tela), così lo zoom non
    aspetta. Solo se la si mostra più grande di così (molte pagine, finestra ingrandita) e la vista
    resta ferma un attimo, chiede con `detailWanted` la parte
    visibile disegnata nitida alla misura giusta, e la mette sopra la pagina intera.
    """

    zoomChanged = pyqtSignal(float)
    detailWanted = pyqtSignal(QRectF, int, int)  # Parte della pagina (0..1), larghezza e altezza in pixel

    MAX_PX_PER_UNIT = 3.0    # Zoom massimo: 3 pixel dello schermo per unità della tela
    DOUBLE_CLICK_ZOOM = 2.5
    SOFT = 1.15              # Oltre 1,15 pixel dello schermo per pixel dell'immagine serve più dettaglio
    DETAIL_MARGIN = 0.25     # Parte in più intorno al visibile, per spostarsi un po' senza ridisegnare

    def __init__(self, page_w: float, page_h: float, parent=None):
        super().__init__(parent)
        self.setMinimumSize(240, 240)
        self.setFocusPolicy(Qt.FocusPolicy.StrongFocus)
        self._page_w, self._page_h = max(1.0, page_w), max(1.0, page_h)
        self._pm = QPixmap()
        self._zoom = 1.0                  # 1 = pagina intera nella finestra (Adatta)
        self._center = QPointF(0.5, 0.5)  # Punto della pagina (0..1) al centro della finestra
        self._drag: Optional[QPointF] = None
        self._scaled: Optional[QPixmap] = None  # Copia ridotta con buon filtro, per le misure sotto 1:1
        self._detail: Optional[tuple] = None    # (parte della pagina 0..1, immagine nitida di quella parte)
        self._detail_timer = QTimer(self)
        self._detail_timer.setSingleShot(True)
        self._detail_timer.setInterval(250)
        self._detail_timer.timeout.connect(self._ask_detail)

    # ---- Stato ----
    def set_pixmap(self, pm: QPixmap):
        """Nuova pagina: si riparte da Adatta."""
        self._pm = pm
        self._scaled = None
        self._detail = None
        self.reset_zoom()

    def set_detail(self, rect: QRectF, pm: QPixmap):
        if not pm.isNull():
            self._detail = (QRectF(rect), pm)
            self.update()

    def zoom(self) -> float:
        return self._zoom

    def max_zoom(self) -> float:
        """
        Fin dove la pagina già pronta resta nitida (niente attese), al massimo MAX_PX_PER_UNIT.
        Comunque almeno 2×: oltre la pagina pronta si ridisegna nitida la parte visibile.
        """
        fit = self._fit_scale()
        limit = self.MAX_PX_PER_UNIT
        if not self._pm.isNull():
            limit = min(limit, self._pm.width() / self._page_w * self.SOFT)
        return max(2.0, limit / max(1e-6, fit * self.devicePixelRatioF()))

    def reset_zoom(self):
        self._zoom = 1.0
        self._center = QPointF(0.5, 0.5)
        self._changed()

    def zoom_by(self, factor: float, anchor: Optional[QPointF] = None):
        """Cambia lo zoom tenendo fermo sotto `anchor` (punto della finestra) lo stesso punto della pagina."""
        if self._pm.isNull():
            return
        new = max(1.0, min(self.max_zoom(), self._zoom * factor))
        if abs(new - self._zoom) < 1e-6:
            return
        if anchor is None:
            anchor = QPointF(self.width() / 2.0, self.height() / 2.0)
        before = self._to_page(anchor)
        self._zoom = new
        after = self._to_page(anchor)
        self._center += before - after
        self._changed()

    # ---- Geometria ----
    def _fit_scale(self) -> float:
        """Pixel della finestra (logici) per unità della tela con zoom Adatta."""
        return min(self.width() / self._page_w, self.height() / self._page_h)

    def _target(self) -> QRectF:
        """Rettangolo della pagina nella finestra."""
        s = self._fit_scale() * self._zoom
        w, h = self._page_w * s, self._page_h * s
        return QRectF(self.width() / 2.0 - self._center.x() * w, self.height() / 2.0 - self._center.y() * h, w, h)

    def _to_page(self, p: QPointF) -> QPointF:
        t = self._target()
        return QPointF((p.x() - t.x()) / max(1e-6, t.width()), (p.y() - t.y()) / max(1e-6, t.height()))

    def _visible(self) -> QRectF:
        """Parte della pagina (0..1) che si vede nella finestra."""
        t = self._target()
        r = QRectF(-t.x() / t.width(), -t.y() / t.height(), self.width() / t.width(), self.height() / t.height())
        return r.intersected(QRectF(0, 0, 1, 1))

    def _clamp(self):
        """La pagina non esce dalla finestra: più piccola resta al centro, più grande la copre tutta."""
        t = self._target()
        cx, cy = self._center.x(), self._center.y()
        if t.width() <= self.width():
            cx = 0.5
        else:
            half = self.width() / 2.0 / t.width()
            cx = max(half, min(1.0 - half, cx))
        if t.height() <= self.height():
            cy = 0.5
        else:
            half = self.height() / 2.0 / t.height()
            cy = max(half, min(1.0 - half, cy))
        self._center = QPointF(cx, cy)

    def _changed(self):
        self._clamp()
        self._update_cursor()
        self._check_detail()
        self.update()
        self.zoomChanged.emit(self._zoom)

    def _update_cursor(self):
        if self._drag is not None:
            self.setCursor(Qt.CursorShape.ClosedHandCursor)
        elif self._zoom > 1.0 + 1e-6:
            self.setCursor(Qt.CursorShape.OpenHandCursor)
        else:
            self.unsetCursor()

    # ---- Dettaglio nitido ----
    def _device_width(self, part: float) -> float:
        """Pixel dello schermo occupati da una parte della pagina larga `part` (0..1)."""
        return self._target().width() * part * self.devicePixelRatioF()

    def _check_detail(self):
        """Basta la pagina intera, va bene il dettaglio che c'è, oppure se ne chiede uno nuovo."""
        if self._pm.isNull() or self._device_width(1.0) / self._pm.width() <= self.SOFT:
            self._detail = None
            self._detail_timer.stop()
            return
        if self._detail is not None:
            rect, pm = self._detail
            if rect.contains(self._visible()) and self._device_width(rect.width()) / pm.width() <= self.SOFT:
                self._detail_timer.stop()
                return
        self._detail_timer.start()  # Si chiede quando la vista resta ferma

    def _ask_detail(self):
        vis = self._visible()
        if vis.isEmpty():
            return
        mx, my = vis.width() * self.DETAIL_MARGIN, vis.height() * self.DETAIL_MARGIN
        rect = vis.adjusted(-mx, -my, mx, my).intersected(QRectF(0, 0, 1, 1))
        t = self._target()
        dpr = self.devicePixelRatioF()
        w = max(1, round(t.width() * rect.width() * dpr))
        h = max(1, round(t.height() * rect.height() * dpr))
        self.detailWanted.emit(rect, w, h)

    # ---- Disegno ----
    def paintEvent(self, event):
        if self._pm.isNull():
            return
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, True)
        t = self._target()
        dpr = self.devicePixelRatioF()
        w, h = round(t.width() * dpr), round(t.height() * dpr)
        if w < self._pm.width() and h < self._pm.height():
            # Pagina rimpicciolita: copia ridotta con il filtro buono (il bilineare darebbe seghettature)
            if self._scaled is None or self._scaled.size() != QSize(w, h):
                self._scaled = self._pm.scaled(w, h, Qt.AspectRatioMode.IgnoreAspectRatio,
                                               Qt.TransformationMode.SmoothTransformation)
            pm = self._scaled
        else:
            pm = self._pm
        painter.drawPixmap(t, pm, QRectF(pm.rect()))
        if self._detail is not None:
            rect, dpm = self._detail
            painter.drawPixmap(QRectF(t.x() + rect.x() * t.width(), t.y() + rect.y() * t.height(),
                                      rect.width() * t.width(), rect.height() * t.height()),
                               dpm, QRectF(dpm.rect()))
        painter.end()

    # ---- Mouse ----
    def wheelEvent(self, event):
        steps = event.angleDelta().y() / 120.0
        if steps:
            self.zoom_by(1.2 ** steps, event.position())
        event.accept()

    def mouseDoubleClickEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            if self._zoom > 1.0 + 1e-6:
                self.reset_zoom()
            else:
                self.zoom_by(self.DOUBLE_CLICK_ZOOM, event.position())

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton and self._zoom > 1.0 + 1e-6:
            self._drag = event.position()
            self._update_cursor()

    def mouseMoveEvent(self, event):
        if self._drag is None:
            return
        t = self._target()
        d = event.position() - self._drag
        self._drag = event.position()
        self._center -= QPointF(d.x() / max(1e-6, t.width()), d.y() / max(1e-6, t.height()))
        self._clamp()
        self._check_detail()
        self.update()

    def mouseReleaseEvent(self, event):
        self._drag = None
        self._update_cursor()

    def resizeEvent(self, event):
        super().resizeEvent(event)
        self._scaled = None
        self._clamp()
        self._check_detail()


class CarouselPreview(QDialog):
    """
    Anteprima delle pagine una alla volta, come le vedrà chi scorre il carosello.
    `pages` sono le pagine intere già pronte e nitide anche per lo zoom (scorrere è immediato);
    `render_region(k, parte 0..1, w, h)` disegna nitida una parte della pagina k per lo zoom.
    """

    @staticmethod
    def viewer_size(screen: QRect, page_ratio: float) -> Tuple[int, int]:
        """Misura (logica) dello spazio per la pagina con cui si apre la finestra."""
        img_h = int(screen.height() * 0.72)
        img_w = int(img_h * page_ratio)
        if img_w > screen.width() * 0.8:
            img_w = int(screen.width() * 0.8)
            img_h = int(img_w / page_ratio)
        return img_w, img_h

    def __init__(self, pages: List[QPixmap], render_region: Callable[[int, QRectF, int, int], QPixmap],
                 page_size: Tuple[float, float], parent=None):
        super().__init__(parent)
        self.setWindowTitle("Anteprima carosello")
        self.pages = pages
        self.count = len(pages)
        self.render_region = render_region
        self.index = 0
        lay = QVBoxLayout(self)
        lay.setContentsMargins(16, 16, 16, 12)
        lay.setSpacing(10)
        self.viewer = PageViewer(*page_size)
        self.viewer.zoomChanged.connect(self._update_zoom_ui)
        self.viewer.detailWanted.connect(self._render_detail)
        lay.addWidget(self.viewer, 1)

        nav = QHBoxLayout()
        self.btn_prev = QPushButton("Pagina precedente")
        self.btn_prev.setIcon(make_icon("chevron_left", THEME["text"], 16))
        self.btn_prev.clicked.connect(lambda: self.step(-1))
        self.btn_next = QPushButton("Pagina successiva")
        self.btn_next.setIcon(make_icon("chevron_right", THEME["text"], 16))
        self.btn_next.setLayoutDirection(Qt.LayoutDirection.RightToLeft)
        self.btn_next.clicked.connect(lambda: self.step(1))
        self.lbl = QLabel()
        self.lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)

        self.btn_zoom_out = QPushButton("−")
        self.btn_zoom_out.setToolTip("Riduci (−)")
        self.btn_zoom_out.clicked.connect(lambda: self.viewer.zoom_by(1 / 1.5))
        self.btn_fit = QPushButton("Adatta")
        self.btn_fit.setToolTip("Pagina intera nella finestra (0)")
        self.btn_fit.clicked.connect(self.viewer.reset_zoom)
        self.btn_zoom_in = QPushButton("+")
        self.btn_zoom_in.setToolTip("Ingrandisci (+)")
        self.btn_zoom_in.clicked.connect(lambda: self.viewer.zoom_by(1.5))
        for b in (self.btn_zoom_out, self.btn_zoom_in):
            b.setFixedWidth(34)
        self.lbl_zoom = QLabel()
        self.lbl_zoom.setMinimumWidth(44)
        self.lbl_zoom.setAlignment(Qt.AlignmentFlag.AlignCenter)

        # I pulsanti non prendono il fuoco: altrimenti si tengono le frecce per spostarlo tra loro
        for b in (self.btn_prev, self.btn_next, self.btn_zoom_out, self.btn_fit, self.btn_zoom_in):
            b.setFocusPolicy(Qt.FocusPolicy.NoFocus)
            b.setAutoDefault(False)

        nav.addWidget(self.btn_prev)
        nav.addStretch()
        nav.addWidget(self.lbl)
        nav.addStretch()
        nav.addWidget(self.btn_zoom_out)
        nav.addWidget(self.lbl_zoom)
        nav.addWidget(self.btn_zoom_in)
        nav.addWidget(self.btn_fit)
        nav.addSpacing(12)
        nav.addWidget(self.btn_next)
        lay.addLayout(nav)
        hint = QLabel("Frecce ← → per scorrere · rotella, + − o doppio clic per lo zoom, trascina per spostarti"
                      " · Esc per chiudere")
        hint.setObjectName("Hint")
        hint.setAlignment(Qt.AlignmentFlag.AlignCenter)
        lay.addWidget(hint)

        # Scorciatoie della finestra: valgono qualunque cosa abbia il fuoco
        keys = (
            (Qt.Key.Key_Left, lambda: self.step(-1)), (Qt.Key.Key_Right, lambda: self.step(1)),
            (Qt.Key.Key_PageUp, lambda: self.step(-1)), (Qt.Key.Key_PageDown, lambda: self.step(1)),
            (Qt.Key.Key_Home, lambda: self.go_to(0)), (Qt.Key.Key_End, lambda: self.go_to(self.count - 1)),
            (Qt.Key.Key_Plus, lambda: self.viewer.zoom_by(1.5)), (Qt.Key.Key_Equal, lambda: self.viewer.zoom_by(1.5)),
            (Qt.Key.Key_Minus, lambda: self.viewer.zoom_by(1 / 1.5)), (Qt.Key.Key_0, self.viewer.reset_zoom),
        )
        for key, slot in keys:
            QShortcut(QKeySequence(key), self, activated=slot)

        screen = (parent.screen() if parent is not None else QApplication.primaryScreen()).availableGeometry()
        img_w, img_h = self.viewer_size(screen, page_size[0] / max(1e-6, page_size[1]))
        self.resize(max(560, img_w + 32), img_h + 110)
        self._show()
        self.viewer.setFocus()

    def step(self, delta: int):
        self.go_to(self.index + delta)

    def go_to(self, k: int):
        k = max(0, min(self.count - 1, k))
        if k != self.index:
            self.index = k
            self._show()

    def _show(self):
        if self.count <= 0:
            return
        self.viewer.set_pixmap(self.pages[self.index])
        n = self.count
        dots = "  ".join("●" if i == self.index else "○" for i in range(n)) if n <= 12 else ""
        self.lbl.setText(f"Pagina {self.index + 1} di {n}" + (f"\n{dots}" if dots and n > 1 else ""))
        self.btn_prev.setEnabled(self.index > 0)
        self.btn_next.setEnabled(self.index < n - 1)

    def _render_detail(self, rect: QRectF, w: int, h: int):
        index = self.index
        QApplication.setOverrideCursor(Qt.CursorShape.WaitCursor)
        try:
            pm = self.render_region(index, rect, w, h)
        finally:
            QApplication.restoreOverrideCursor()
        if index == self.index:
            self.viewer.set_detail(rect, pm)

    def _update_zoom_ui(self, zoom: float):
        self.lbl_zoom.setText(f"{round(zoom * 100)}%")
        self.btn_zoom_out.setEnabled(zoom > 1.0 + 1e-6)
        self.btn_fit.setEnabled(zoom > 1.0 + 1e-6)
        self.btn_zoom_in.setEnabled(zoom < self.viewer.max_zoom() - 1e-6)


class PageOrderDialog(QDialog):
    """Riordina le pagine trascinando le miniature; Applica restituisce il nuovo ordine."""

    def __init__(self, thumbs: List[QPixmap], labels: List[str], parent=None):
        super().__init__(parent)
        self.setWindowTitle("Riordina le pagine")
        lay = QVBoxLayout(self)
        lay.setContentsMargins(16, 16, 16, 12)
        lay.setSpacing(10)
        hint = QLabel("Trascina le pagine nell'ordine che vuoi. Ogni pagina si porta dietro foto, testi e impostazioni.")
        hint.setObjectName("Hint")
        hint.setWordWrap(True)
        lay.addWidget(hint)

        side = 150
        self.list = QListWidget()
        self.list.setViewMode(QListView.ViewMode.IconMode)
        self.list.setFlow(QListView.Flow.LeftToRight)
        self.list.setWrapping(True)
        self.list.setResizeMode(QListView.ResizeMode.Adjust)
        # Movimento "statico": il trascinamento cambia l'ordine delle righe. Con Snap/Free un QListWidget
        # a icone sposta le miniature solo graficamente e l'ordine resterebbe quello di prima
        self.list.setMovement(QListView.Movement.Static)
        self.list.setDragDropMode(QAbstractItemView.DragDropMode.InternalMove)
        self.list.setDefaultDropAction(Qt.DropAction.MoveAction)
        self.list.setIconSize(QSize(side, side))
        self.list.setGridSize(QSize(side + 24, side + 44))
        self.list.setSpacing(6)
        self.list.setUniformItemSizes(True)
        for i, (pm, label) in enumerate(zip(thumbs, labels)):
            item = QListWidgetItem(QIcon(pm), label.split("  ·  ")[0] if len(labels) > 1 else label)
            item.setData(Qt.ItemDataRole.UserRole, i)
            item.setToolTip(label)
            self.list.addItem(item)
        lay.addWidget(self.list, 1)

        if self.list.count():
            self.list.setCurrentRow(0)
        buttons = QHBoxLayout()
        self.btn_before = QPushButton("Prima")
        self.btn_before.setIcon(make_icon("chevron_left", THEME["text"], 16))
        self.btn_before.setToolTip("Sposta la pagina selezionata una posizione prima")
        self.btn_before.clicked.connect(lambda: self._shift(-1))
        self.btn_after = QPushButton("Dopo")
        self.btn_after.setIcon(make_icon("chevron_right", THEME["text"], 16))
        self.btn_after.setLayoutDirection(Qt.LayoutDirection.RightToLeft)
        self.btn_after.setToolTip("Sposta la pagina selezionata una posizione dopo")
        self.btn_after.clicked.connect(lambda: self._shift(1))
        reset = QPushButton("Ordine di prima")
        reset.clicked.connect(self._reset)
        cancel = QPushButton("Annulla")
        cancel.clicked.connect(self.reject)
        apply = QPushButton("Applica")
        apply.setObjectName("Primary")
        apply.setDefault(True)
        apply.clicked.connect(self.accept)
        buttons.addWidget(self.btn_before)
        buttons.addWidget(self.btn_after)
        buttons.addSpacing(12)
        buttons.addWidget(reset)
        buttons.addStretch()
        buttons.addWidget(cancel)
        buttons.addWidget(apply)
        lay.addLayout(buttons)

        cols = max(1, min(len(thumbs), 5))
        rows = (len(thumbs) + cols - 1) // cols
        self.resize(cols * (side + 30) + 60, min(720, rows * (side + 50) + 140))

    def order(self) -> List[int]:
        """order[nuova posizione] = vecchia posizione."""
        return [self.list.item(r).data(Qt.ItemDataRole.UserRole) for r in range(self.list.count())]

    def _shift(self, delta: int):
        """Sposta la pagina selezionata di una posizione (alternativa al trascinamento)."""
        row = self.list.currentRow()
        new = row + delta
        if row < 0 or not (0 <= new < self.list.count()):
            return
        item = self.list.takeItem(row)
        self.list.insertItem(new, item)
        self.list.setCurrentRow(new)

    def _reset(self):
        items = sorted((self.list.takeItem(0) for _ in range(self.list.count())),
                       key=lambda it: it.data(Qt.ItemDataRole.UserRole))
        for it in items:
            self.list.addItem(it)


class PageExportDialog(QDialog):
    """
    Sceglie quali pagine esportare (tutte all'inizio: un clic su una miniatura la toglie o la rimette)
    e il nome dei file, con l'anteprima del nome che avranno.
    """

    def __init__(self, thumbs: List[QPixmap], labels: List[str], name: str, ext: str, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Esporta pagine")
        lay = QVBoxLayout(self)
        lay.setContentsMargins(16, 16, 16, 12)
        lay.setSpacing(10)
        hint = QLabel("Clicca le pagine da esportare (di nuovo per toglierle). Ogni pagina diventa un'immagine.")
        hint.setObjectName("Hint")
        hint.setWordWrap(True)
        lay.addWidget(hint)

        side = 150
        self.list = QListWidget()
        self.list.setViewMode(QListView.ViewMode.IconMode)
        self.list.setFlow(QListView.Flow.LeftToRight)
        self.list.setWrapping(True)
        self.list.setResizeMode(QListView.ResizeMode.Adjust)
        self.list.setMovement(QListView.Movement.Static)
        self.list.setSelectionMode(QAbstractItemView.SelectionMode.MultiSelection)
        self.list.setIconSize(QSize(side, side))
        self.list.setGridSize(QSize(side + 24, side + 44))
        self.list.setSpacing(6)
        self.list.setUniformItemSizes(True)
        for i, (pm, label) in enumerate(zip(thumbs, labels)):
            item = QListWidgetItem(QIcon(pm), f"Pagina {i + 1}")
            item.setData(Qt.ItemDataRole.UserRole, i)
            item.setToolTip(label)
            self.list.addItem(item)
        self.list.selectAll()
        self.list.itemSelectionChanged.connect(self._refresh)
        lay.addWidget(self.list, 1)

        self.ext = ext
        name_row = QHBoxLayout()
        name_row.setSpacing(8)
        name_lbl = QLabel("Nome dei file")
        name_lbl.setObjectName("FieldLabel")
        name_row.addWidget(name_lbl)
        self.edit_name = QLineEdit(name)
        self.edit_name.setPlaceholderText("frame")
        self.edit_name.setToolTip("Per esempio «viaggio»: le pagine diventano viaggio_01, viaggio_02…\n"
                                  "Il nome resta salvato nel progetto.")
        self.edit_name.textChanged.connect(self._refresh)
        name_row.addWidget(self.edit_name, 1)
        lay.addLayout(name_row)
        # Anteprima del nome sotto il campo: se è lunga si accorcia al centro, il campo resta largo uguale
        self.lbl_example = QLabel()
        self.lbl_example.setObjectName("Hint")
        self.lbl_example.setSizePolicy(QSizePolicy.Policy.Ignored, QSizePolicy.Policy.Preferred)
        lay.addWidget(self.lbl_example)

        buttons = QHBoxLayout()
        self.btn_all = btn_all = QPushButton("Tutte")
        btn_all.setToolTip("Sceglie tutte le pagine")
        btn_all.clicked.connect(self.list.selectAll)
        self.btn_none = btn_none = QPushButton("Nessuna")
        btn_none.setToolTip("Toglie tutte le pagine, per sceglierne poche")
        btn_none.clicked.connect(self.list.clearSelection)
        self.lbl_count = QLabel()
        self.lbl_count.setObjectName("Hint")
        cancel = QPushButton("Annulla")
        cancel.clicked.connect(self.reject)
        self.btn_export = QPushButton("Esporta")
        self.btn_export.setObjectName("Primary")
        self.btn_export.setDefault(True)
        self.btn_export.clicked.connect(self.accept)
        buttons.addWidget(btn_all)
        buttons.addWidget(btn_none)
        buttons.addSpacing(8)
        buttons.addWidget(self.lbl_count)
        buttons.addStretch()
        buttons.addWidget(cancel)
        buttons.addWidget(self.btn_export)
        lay.addLayout(buttons)
        self._refresh()

        cols = max(1, min(len(thumbs), 5))
        rows = (len(thumbs) + cols - 1) // cols
        self.resize(cols * (side + 30) + 60, min(720, rows * (side + 50) + 140))

    def file_name(self) -> str:
        return self.edit_name.text()

    def pages(self) -> List[int]:
        """Pagine scelte, in ordine."""
        return sorted(it.data(Qt.ItemDataRole.UserRole) for it in self.list.selectedItems())

    def _refresh(self):
        n = len(self.list.selectedItems())
        total = self.list.count()
        self.lbl_count.setText("Tutte le pagine" if n == total else
                               "Nessuna pagina scelta" if n == 0 else
                               "1 pagina scelta" if n == 1 else f"{n} pagine scelte")
        self.btn_export.setEnabled(n > 0)
        self.btn_export.setToolTip("" if n else "Scegli almeno una pagina da esportare")
        self.btn_all.setEnabled(n < total)
        self.btn_none.setEnabled(n > 0)
        pages = self.pages()
        base = self.edit_name.text().strip() or "frame"
        first = pages[0] + 1 if pages else 1
        example = f"I file si chiameranno {base}_{first:02d}{self.ext}" + (", …" if len(pages) > 1 else "")
        width = self.lbl_example.width()
        if width > 50:
            example = self.lbl_example.fontMetrics().elidedText(example, Qt.TextElideMode.ElideMiddle, width)
        self.lbl_example.setText(example)
        self.lbl_example.setToolTip(f"{base}_{first:02d}{self.ext}")

    def resizeEvent(self, event):
        super().resizeEvent(event)
        self._refresh()


class ShortcutsDialog(QDialog):
    """Guida → Scorciatoie: tasti e gesti del mouse, divisi per argomento."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Scorciatoie da tastiera e mouse")
        outer = QVBoxLayout(self)
        outer.setContentsMargins(16, 16, 16, 12)
        outer.setSpacing(10)
        intro = QLabel("Le scorciatoie valgono quando la tela è attiva (clicca sulla tela se non rispondono).")
        intro.setObjectName("Hint")
        intro.setWordWrap(True)
        outer.addWidget(intro)

        body = QWidget()
        body.setObjectName("Panel")
        grid = QGridLayout(body)
        grid.setContentsMargins(0, 0, 8, 0)
        grid.setHorizontalSpacing(14)
        grid.setVerticalSpacing(5)
        grid.setColumnStretch(1, 1)
        row = 0
        for section, entries in SHORTCUTS:
            if row:
                grid.setRowMinimumHeight(row, 10)
                row += 1
            title = QLabel(section)
            title.setObjectName("SectionTitle")
            grid.addWidget(title, row, 0, 1, 2)
            row += 1
            for keys, action in entries:
                chip = QLabel(kb(keys))
                chip.setObjectName("ValueChip")
                chip.setAlignment(Qt.AlignmentFlag.AlignCenter)
                grid.addWidget(chip, row, 0, Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter)
                text = QLabel(action)
                text.setWordWrap(True)
                grid.addWidget(text, row, 1, Qt.AlignmentFlag.AlignVCenter)
                row += 1
        scroll = QScrollArea()
        scroll.setObjectName("PanelScroll")
        scroll.setWidget(body)
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        outer.addWidget(scroll, 1)

        buttons = QHBoxLayout()
        buttons.addStretch()
        close = QPushButton("Chiudi")
        close.setObjectName("Primary")
        close.setDefault(True)
        close.clicked.connect(self.accept)
        buttons.addWidget(close)
        outer.addLayout(buttons)
        self.resize(620, 640)


class BackgroundDialog(QDialog):
    """Sfondo della tela: tinta unita, sfumatura o foto sfocata. Le modifiche si vedono subito sulla tela."""
    DIRECTIONS = [("vertical", "Dall'alto in basso"), ("horizontal", "Da sinistra a destra"), ("diagonal", "In diagonale")]

    def __init__(self, win: "MainWindow"):
        super().__init__(win)
        self.win = win
        sc = win.scene
        self.setWindowTitle("Sfondo della tela")
        self.setMinimumWidth(360)
        lay = QVBoxLayout(self)
        lay.setContentsMargins(16, 14, 16, 14)
        lay.setSpacing(8)

        lay.addWidget(win._label("Tipo di sfondo", "SectionTitle"))
        self.radios: Dict[str, QRadioButton] = {}
        group = QButtonGroup(self)
        for key, text in (("solid", "Tinta unita"), ("gradient", "Sfumatura tra due colori"), ("blur", "Foto sfocata")):
            rb = QRadioButton(text)
            rb.setCursor(Qt.CursorShape.PointingHandCursor)
            group.addButton(rb)
            self.radios[key] = rb
            lay.addWidget(rb)
        self.radios[sc.bg_mode if sc.bg_mode in self.radios else "solid"].setChecked(True)
        has_photos = bool(win.loaded_library)
        self.radios["blur"].setEnabled(has_photos)
        if not has_photos:
            self.radios["blur"].setToolTip("Aggiungi prima delle foto alla libreria")

        lay.addWidget(win._divider())

        # Colori (tinta unita e sfumatura)
        self.colors_box = QWidget()
        cl = QVBoxLayout(self.colors_box)
        cl.setContentsMargins(0, 0, 0, 0)
        cl.setSpacing(6)
        row = QHBoxLayout()
        row.setSpacing(6)
        self.btn_c1 = win._icon_button("plus", "Scegli il colore", lambda: self._pick(1), "Colore", "SoftButton")
        self.btn_c2 = win._icon_button("plus", "Scegli il colore finale della sfumatura", lambda: self._pick(2),
                                       "Colore finale", "SoftButton")
        row.addWidget(self.btn_c1)
        row.addWidget(self.btn_c2)
        cl.addLayout(row)
        self.dir_row = QWidget()
        dl = QHBoxLayout(self.dir_row)
        dl.setContentsMargins(0, 0, 0, 0)
        dl.addWidget(win._label("Direzione"))
        self.combo_dir = QComboBox()
        for key, text in self.DIRECTIONS:
            self.combo_dir.addItem(text, key)
        self.combo_dir.setCurrentIndex(max(0, [k for k, _ in self.DIRECTIONS].index(sc.bg_direction)
                                           if sc.bg_direction in dict(self.DIRECTIONS) else 0))
        self.combo_dir.currentIndexChanged.connect(self._apply)
        dl.addWidget(self.combo_dir, 1)
        cl.addWidget(self.dir_row)
        lay.addWidget(self.colors_box)

        # Foto sfocata
        self.photo_box = QWidget()
        pl = QVBoxLayout(self.photo_box)
        pl.setContentsMargins(0, 0, 0, 0)
        pl.setSpacing(6)
        prow = QHBoxLayout()
        prow.addWidget(win._label("Foto"))
        self.combo_photo = QComboBox()
        self.combo_photo.setIconSize(QSize(28, 28))
        for path in win.loaded_library:
            self.combo_photo.addItem(QIcon(rounded_thumb(IMAGE_CACHE.preview(path), 28)), os.path.basename(path), path)
        start = sc.bg_blur_path or win._default_blur_photo()
        idx = self.combo_photo.findData(start)
        self.combo_photo.setCurrentIndex(max(0, idx))
        self.combo_photo.currentIndexChanged.connect(self._apply)
        prow.addWidget(self.combo_photo, 1)
        pl.addLayout(prow)
        self.slider_blur = win._make_slider(pl, "Sfocatura", 0, 100, 50, resettable=True)
        self.slider_blur.setValue(sc.bg_blur_amount)
        self.slider_blur.valueChanged.connect(self._apply)
        self.slider_dim = win._make_slider(pl, "Scurisci", 0, 80, 15, "%", resettable=True)
        self.slider_dim.setValue(sc.bg_dim)
        self.slider_dim.valueChanged.connect(self._apply)
        lay.addWidget(self.photo_box)

        lay.addStretch()
        done = QPushButton("Fatto")
        done.setObjectName("Primary")
        done.setCursor(Qt.CursorShape.PointingHandCursor)
        done.clicked.connect(self.accept)
        foot = QHBoxLayout()
        foot.addStretch()
        foot.addWidget(done)
        lay.addLayout(foot)

        for rb in self.radios.values():
            rb.toggled.connect(self._apply)
        self._c1 = QColor(sc.bg_color)
        self._c2 = QColor(sc.bg_color2)
        self._apply()

    def _mode(self) -> str:
        return next((k for k, rb in self.radios.items() if rb.isChecked()), "solid")

    def _pick(self, which: int):
        initial = self._c1 if which == 1 else self._c2
        col = QColorDialog.getColor(initial, self, "Colore dello sfondo")
        if col.isValid():
            if which == 1:
                self._c1 = col
            else:
                self._c2 = col
            self._apply()

    def _apply(self, *_):
        mode = self._mode()
        self.colors_box.setVisible(mode != "blur")
        self.btn_c2.setVisible(mode == "gradient")
        self.dir_row.setVisible(mode == "gradient")
        self.btn_c1.setText("Colore iniziale" if mode == "gradient" else "Colore")
        self.btn_c1.setIcon(swatch_icon(self._c1))
        self.btn_c2.setIcon(swatch_icon(self._c2))
        self.photo_box.setVisible(mode == "blur")
        self.win._apply_background(
            mode=mode, color=self._c1, color2=self._c2,
            direction=self.combo_dir.currentData() or "vertical",
            blur_path=self.combo_photo.currentData() or "",
            blur_amount=self.slider_blur.value(), dim=self.slider_dim.value(),
        )
        self.adjustSize()


class NewProjectPanel(QWidget):
    """
    I formati di un nuovo progetto divisi tra «Carosello o foto» (a sinistra) e «Reel» (a destra).
    Una tessera sceglie insieme il tipo di progetto e il formato; le pagine valgono solo per il carosello.
    Sta in File → Nuovo progetto e nella finestra di avvio.
    """

    # Formati del carosello a righe di tre (in cima i post: 4:5, 3:4, e il quadrato) e del reel (9:16 proposto)
    CAROUSEL_ROWS = [[(1080, 1350), (1080, 1440), (1080, 1080)],
                     [(1080, 1920), (1440, 1080), (1920, 1080)],
                     [(1080, 1620), (1620, 1080), None]]
    REEL_SIZES = [(1080, 1920), (1080, 1350), (1080, 1080)]
    NOTES = {(1080, 1350): "post", (1080, 1440): "profilo", (1080, 1920): "storie"}

    def __init__(self, ratios: Dict[str, Optional[Tuple[int, int]]], size: Tuple[int, int], custom: Tuple[int, int],
                 pages: int, max_pages: int, parent=None):
        super().__init__(parent)
        self._ratios = list(ratios.items())
        self._choice: Dict[QToolButton, Tuple[str, Optional[Tuple[int, int]]]] = {}
        self.group = QButtonGroup(self)
        self.group.setExclusive(True)

        lay = QVBoxLayout(self)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(12)
        cols = QHBoxLayout()
        cols.setSpacing(16)
        lay.addLayout(cols)

        # ---- Carosello o foto ----
        left = QVBoxLayout()
        left.setSpacing(6)
        self._section(left, "Carosello o foto", f"Fino a {max_pages} pagine, video fino a 60 s")
        grid = QGridLayout()
        grid.setSpacing(6)
        for r, row in enumerate(self.CAROUSEL_ROWS):
            for c, wh in enumerate(row):
                grid.addWidget(self._tile("carousel", wh), r, c)
        left.addLayout(grid)
        self.custom_box = QWidget()
        custom_l = QHBoxLayout(self.custom_box)
        custom_l.setContentsMargins(0, 2, 0, 0)
        custom_l.setSpacing(6)
        self.spin_w, self.spin_h = QSpinBox(), QSpinBox()
        for spin, val, tip in ((self.spin_w, custom[0], "Larghezza della pagina"),
                               (self.spin_h, custom[1], "Altezza della pagina")):
            spin.setRange(200, 6000)
            spin.setValue(val)
            spin.setSuffix(" px")
            spin.setToolTip(tip)
            spin.setButtonSymbols(QAbstractSpinBox.ButtonSymbols.NoButtons)
            spin.setAlignment(Qt.AlignmentFlag.AlignCenter)
            spin.setFixedWidth(78)
        custom_l.addWidget(self.spin_w)
        custom_l.addWidget(QLabel("×"))
        custom_l.addWidget(self.spin_h)
        custom_l.addStretch()
        left.addWidget(self.custom_box)
        pages_row = QHBoxLayout()
        pages_row.setSpacing(8)
        self.lbl_pages = QLabel("Pagine")
        self.lbl_pages.setObjectName("FieldLabel")
        # Come il campo Pagine della barra in alto: numero al centro tra − e +
        self.spin_pages = QSpinBox()
        self.spin_pages.setRange(1, max_pages)
        self.spin_pages.setValue(max(1, min(max_pages, pages)))
        self.spin_pages.setButtonSymbols(QAbstractSpinBox.ButtonSymbols.NoButtons)
        self.spin_pages.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.spin_pages.setFixedWidth(44)
        self.spin_pages.setToolTip("1 = un solo collage nel formato scelto.\n"
                                   "2 o più = carosello continuo da pubblicare a pagine.")
        self.btn_pages_less = self._step_button("minus", "Una pagina in meno", -1)
        self.btn_pages_more = self._step_button("plus", "Una pagina in più", 1)
        pages_row.addWidget(self.lbl_pages)
        pages_row.addSpacing(4)
        pages_row.addWidget(self.btn_pages_less)
        pages_row.addWidget(self.spin_pages)
        pages_row.addWidget(self.btn_pages_more)
        pages_row.addStretch()
        left.addLayout(pages_row)
        left.addStretch()
        cols.addLayout(left, 3)

        sep = QFrame()
        sep.setObjectName("VSep")
        sep.setFixedWidth(1)
        cols.addWidget(sep)

        # ---- Reel ----
        right = QVBoxLayout()
        right.setSpacing(6)
        self._section(right, "Reel", "Una pagina, video fino a 5 minuti")
        reel = QGridLayout()
        reel.setSpacing(6)
        reel.addWidget(self._tile("reel", self.REEL_SIZES[0], note="consigliato", icon=56), 0, 0, 2, 1)
        reel.addWidget(self._tile("reel", self.REEL_SIZES[1]), 0, 1)
        reel.addWidget(self._tile("reel", self.REEL_SIZES[2]), 1, 1)
        right.addLayout(reel)
        right.addStretch()
        cols.addLayout(right, 2)

        self.lbl_hint = QLabel()
        self.lbl_hint.setObjectName("Hint")
        self.lbl_hint.setWordWrap(True)
        lay.addWidget(self.lbl_hint)

        # Di partenza il formato del carosello indicato (il personalizzato se non è tra le tessere)
        carousel = {wh: b for b, (k, wh) in self._choice.items() if k == "carousel"}
        carousel.get(size, carousel[None]).setChecked(True)
        self.group.buttonToggled.connect(lambda _b, _on: self._refresh())
        self._refresh()

    def _section(self, lay: QVBoxLayout, title: str, hint: str):
        t = QLabel(title)
        t.setObjectName("SectionTitle")
        h = QLabel(hint)
        h.setObjectName("Hint")
        lay.addWidget(t)
        lay.addWidget(h)
        lay.addSpacing(2)

    def _step_button(self, icon: str, tooltip: str, step: int) -> QToolButton:
        b = QToolButton()
        b.setObjectName("IconButton")
        b.setIcon(make_icon(icon, THEME["text"]))
        b.setIconSize(QSize(18, 18))
        b.setToolTip(tooltip)
        b.setCursor(Qt.CursorShape.PointingHandCursor)
        b.clicked.connect(lambda: self.spin_pages.stepBy(step))
        return b

    def _tile(self, kind: str, wh: Optional[Tuple[int, int]], note: str = "", icon: int = 36) -> QToolButton:
        b = QToolButton()
        b.setObjectName("FormatTile")
        b.setCheckable(True)
        b.setToolButtonStyle(Qt.ToolButtonStyle.ToolButtonTextUnderIcon)
        b.setIcon(ratio_icon(wh, icon))
        b.setIconSize(QSize(icon, icon))
        b.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
        b.setMinimumSize(76, 88)  # Due righe di testo sotto la sagoma
        label = next((name for name, v in self._ratios if v == wh), "Personalizzato")
        short = label.split(" ")[0] if wh is not None else "Altro"
        note = note or (self.NOTES.get(wh, "") if kind == "carousel" else "")
        b.setText(f"{short}\n{note}" if note else short)
        where = "Reel" if kind == "reel" else "Carosello o foto"
        b.setToolTip(f"{where}: {label}")
        b.setAccessibleName(f"{where}, {label}")
        self.group.addButton(b)
        self._choice[b] = (kind, wh)
        return b

    def _refresh(self):
        kind, wh = self._choice.get(self.group.checkedButton(), ("carousel", None))
        self.custom_box.setVisible(kind == "carousel" and wh is None)
        # Il reel ha una pagina sola: il campo Pagine resta visibile ma spento
        for widget in (self.lbl_pages, self.spin_pages, self.btn_pages_less, self.btn_pages_more):
            widget.setEnabled(kind == "carousel")
        self.lbl_hint.setText(
            "Il reel ha una pagina sola; si può convertire in carosello da File → Converti in carosello."
            if kind == "reel" else
            "Il formato vale per ogni pagina del carosello. Il tipo si può cambiare da File → Converti in reel.")

    def kind(self) -> str:
        return self._choice[self.group.checkedButton()][0]

    def ratio_index(self) -> int:
        """Posizione del formato scelto nell'elenco dei formati (il personalizzato è l'ultimo)."""
        wh = self._choice[self.group.checkedButton()][1]
        return next(i for i, (_n, v) in enumerate(self._ratios) if v == wh)

    def frame_size(self) -> Tuple[int, int]:
        wh = self._choice[self.group.checkedButton()][1]
        return wh if wh is not None else (self.spin_w.value(), self.spin_h.value())

    def pages(self) -> int:
        return self.spin_pages.value() if self.kind() == "carousel" else 1


class NewProjectDialog(QDialog):
    """File → Nuovo progetto: il pannello dei formati con Annulla e Crea."""

    def __init__(self, ratios: Dict[str, Optional[Tuple[int, int]]], size: Tuple[int, int], custom: Tuple[int, int],
                 pages: int, max_pages: int, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Nuovo progetto")
        lay = QVBoxLayout(self)
        lay.setContentsMargins(16, 16, 16, 12)
        lay.setSpacing(12)
        self.panel = NewProjectPanel(ratios, size, custom, pages, max_pages, self)
        lay.addWidget(self.panel)

        buttons = QHBoxLayout()
        buttons.addStretch()
        cancel = QPushButton("Annulla")
        cancel.clicked.connect(self.reject)
        self.btn_create = QPushButton("Crea")
        self.btn_create.setObjectName("Primary")
        self.btn_create.setDefault(True)
        self.btn_create.clicked.connect(self.accept)
        buttons.addWidget(cancel)
        buttons.addWidget(self.btn_create)
        lay.addLayout(buttons)

    def kind(self) -> str:
        return self.panel.kind()

    def ratio_index(self) -> int:
        return self.panel.ratio_index()

    def frame_size(self) -> Tuple[int, int]:
        return self.panel.frame_size()

    def pages(self) -> int:
        return self.panel.pages()
