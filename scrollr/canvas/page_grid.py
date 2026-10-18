"""Pagine a scacchiera: una vista per pagina sulla stessa tela, disposte in griglia scorrevole."""
import math
from typing import List

from PyQt6.QtCore import Qt, QPoint, QPointF, QRectF, pyqtSignal
from PyQt6.QtGui import QColor, QPainter, QPainterPath
from PyQt6.QtWidgets import QFrame, QGridLayout, QScrollArea, QWidget

from scrollr.canvas.scene import CollageScene
from scrollr.canvas.view import CanvasView
from scrollr.theme import THEME, ui_font

# Margini di ogni pagina sullo schermo, in pixel: in alto c'è l'etichetta "Pagina N"
SIDE_PX, TOP_PX, BOTTOM_PX = 10, 26, 10
OUTER_PX = 24  # Spazio libero attorno alla griglia


class PageTileView(CanvasView):
    """
    Vista fissa su una sola pagina della tela condivisa. La tela resta una striscia continua
    (le foto «a cavallo» si vedono spezzate tra le due pagine, come nel carosello pubblicato):
    cambia solo il modo di mostrarla. Zoom e scorrimento li gestisce la griglia.
    """

    def __init__(self, scene: CollageScene, grid: "PageGridView", index: int):
        super().__init__(scene)
        self.grid = grid
        self.index = index
        self.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)

    def page_rect(self) -> QRectF:
        sc = self.scene()
        return QRectF(self.index * sc.frame_w, 0, sc.frame_w, sc.frame_h)

    def apply_scale(self, s: float):
        rect = self.page_rect().adjusted(-SIDE_PX / s, -TOP_PX / s, SIDE_PX / s, BOTTOM_PX / s)
        self.setSceneRect(rect)
        self.resetTransform()
        self.scale(s, s)
        self.setFixedSize(math.ceil(rect.width() * s), math.ceil(rect.height() * s))
        self.centerOn(rect.center())

    # Zoom e scorrimento sono quelli della griglia
    def current_scale(self) -> float:
        return self.grid.scale

    def zoom_by(self, factor: float, under_mouse: bool = True):
        self.grid.zoom_by(factor)

    def fit_to(self, rect: QRectF):
        self.grid.fit()

    def _pan_bars(self):
        return self.grid.horizontalScrollBar(), self.grid.verticalScrollBar()

    def drawForeground(self, painter: QPainter, rect: QRectF):
        super().drawForeground(painter, rect)
        sc = self.scene()
        if sc.is_exporting or sc.clean_render:
            return
        # Quello che sta fuori dalla pagina (bordi delle pagine vicine) resta attenuato
        page = self.page_rect()
        outer = QPainterPath()
        outer.addRect(rect)
        inner = QPainterPath()
        inner.addRect(page)
        veil = QColor(THEME["backdrop"])
        veil.setAlpha(200)
        painter.fillPath(outer.subtracted(inner), veil)
        # Etichetta della pagina, in pixel dello schermo
        top_left = painter.worldTransform().map(page.topLeft())
        painter.save()
        painter.resetTransform()
        painter.setRenderHint(QPainter.RenderHint.TextAntialiasing, True)
        painter.setFont(ui_font(11))
        painter.setPen(QColor(THEME["muted"]))
        painter.drawText(QPointF(top_left.x() + 1, top_left.y() - 8), sc.page_label(self.index))
        painter.restore()


class PageGridView(QScrollArea):
    """Griglia delle pagine con barre di scorrimento orizzontale e verticale."""
    zoom_changed = pyqtSignal(float)
    files_dropped = pyqtSignal(list)
    context_menu_requested = pyqtSignal(object, QPoint)  # (vista della pagina, punto nella vista)
    MIN_SCALE = 0.03
    MAX_SCALE = 4.0

    def __init__(self, scene: CollageScene, parent=None):
        super().__init__(parent)
        self._scene = scene
        self.scale = 0.25
        self.columns = 1
        self.tiles: List[PageTileView] = []
        self._shape = None  # (pagine, larghezza, altezza) delle viste costruite
        self.setObjectName("PageGridArea")
        self.setFrameShape(QFrame.Shape.NoFrame)
        self.setWidgetResizable(True)
        self.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        self.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        self._container = QWidget()
        self._container.setObjectName("PageGrid")
        self._container.setAttribute(Qt.WidgetAttribute.WA_StyledBackground, True)
        self._layout = QGridLayout(self._container)
        self._layout.setContentsMargins(OUTER_PX, OUTER_PX, OUTER_PX, OUTER_PX)
        self._layout.setSpacing(0)
        self._layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.setWidget(self._container)

    # ---------- Costruzione ----------
    def sync(self):
        """Ricostruisce le viste se sono cambiati numero o formato delle pagine."""
        sc = self._scene
        shape = (sc.num_frames, sc.frame_w, sc.frame_h)
        if shape != self._shape or len(self.tiles) != sc.num_frames:
            self._shape = shape
            self._rebuild()

    def _rebuild(self):
        self.detach()
        for i in range(self._scene.num_frames):
            tile = PageTileView(self._scene, self, i)
            tile.files_dropped.connect(self.files_dropped)
            tile.customContextMenuRequested.connect(
                lambda pos, t=tile: self.context_menu_requested.emit(t, pos))
            self.tiles.append(tile)
        self._place()

    def detach(self):
        """Toglie le viste dalla tela (in modalità «in fila» non devono restare collegate alla scena)."""
        for tile in self.tiles:
            self._layout.removeWidget(tile)
            tile.setScene(None)
            tile.deleteLater()
        self.tiles = []
        self._shape = None

    def _place(self):
        for tile in self.tiles:
            self._layout.removeWidget(tile)
        for tile in self.tiles:
            r, c = divmod(tile.index, self.columns)
            self._layout.addWidget(tile, r, c)
            tile.apply_scale(self.scale)

    # ---------- Zoom ----------
    def current_scale(self) -> float:
        return self.scale

    def fit(self):
        """Colonne e zoom che mostrano tutte le pagine nella finestra, il più grandi possibile."""
        self.sync()
        sc = self._scene
        n = max(1, sc.num_frames)
        avail_w = max(100, self.viewport().width() - 2 * OUTER_PX)
        avail_h = max(100, self.viewport().height() - 2 * OUTER_PX)
        best = None
        for cols in range(1, n + 1):
            rows = math.ceil(n / cols)
            s = min((avail_w - cols * 2 * SIDE_PX) / (cols * sc.frame_w),
                    (avail_h - rows * (TOP_PX + BOTTOM_PX)) / (rows * sc.frame_h))
            if best is None or s > best[0] + 1e-9:
                best = (s, cols)
        self.columns = best[1]
        self.scale = max(self.MIN_SCALE, min(self.MAX_SCALE, best[0]))
        self._place()
        self._resize_now()
        self.zoom_changed.emit(self.scale)

    def set_scale(self, s: float):
        s = max(self.MIN_SCALE, min(self.MAX_SCALE, s))
        h, v = self.horizontalScrollBar(), self.verticalScrollBar()
        # Mantiene al centro lo stesso punto della griglia
        fx = (h.value() + self.viewport().width() / 2) / max(1, self._container.width())
        fy = (v.value() + self.viewport().height() / 2) / max(1, self._container.height())
        self.scale = s
        self._place()
        self._resize_now()
        h.setValue(int(fx * self._container.width() - self.viewport().width() / 2))
        v.setValue(int(fy * self._container.height() - self.viewport().height() / 2))
        self.zoom_changed.emit(self.scale)

    def _resize_now(self):
        """Dimensione nuova della griglia subito (non al prossimo giro), così le barre sono già giuste."""
        self._layout.activate()
        self._container.resize(self._container.sizeHint().expandedTo(self.viewport().size()))

    def zoom_by(self, factor: float, under_mouse: bool = True):
        self.set_scale(self.scale * factor)

    def wheelEvent(self, event):
        # Rotella = zoom, come sulla tela in fila (per muoversi ci sono le barre)
        self.zoom_by(1.15 if event.angleDelta().y() > 0 else 1.0 / 1.15)
        event.accept()

    # ---------- Posizione ----------
    def visible_center_scene(self) -> QPointF:
        """Punto della tela al centro della zona visibile (nella pagina più vicina al centro)."""
        if not self.tiles:
            return QPointF(0, 0)
        center = self._container.mapFrom(self.viewport(), self.viewport().rect().center())
        tile = min(self.tiles, key=lambda t: (t.geometry().center() - center).manhattanLength())
        local = tile.mapFrom(self._container, center)
        local.setX(max(0, min(tile.width() - 1, local.x())))
        local.setY(max(0, min(tile.height() - 1, local.y())))
        return tile.mapToScene(local)
