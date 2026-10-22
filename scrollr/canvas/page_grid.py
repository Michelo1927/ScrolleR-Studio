"""Pagine a scacchiera: una vista per pagina sulla stessa tela, disposte in griglia scorrevole."""
import math
from typing import List

from PyQt6.QtCore import Qt, QEvent, QPoint, QPointF, QRectF, pyqtSignal
from PyQt6.QtGui import QColor, QPainter, QPainterPath
from PyQt6.QtWidgets import QFrame, QGridLayout, QScrollArea, QWidget

from scrollr.canvas.scene import CollageScene
from scrollr.canvas.view import CanvasView, wheel_action
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

    def _wheel_zoom(self, factor: float, event):
        self.grid.zoom_at(factor, event.globalPosition())

    def _pinch_zoom(self, factor: float, event):
        self.grid.zoom_at(factor, event.globalPosition())

    def fit_to(self, rect: QRectF):
        self.grid.fit()

    def _pan_bars(self):
        return self.grid.horizontalScrollBar(), self.grid.verticalScrollBar()

    def drawForeground(self, painter: QPainter, rect: QRectF):
        super().drawForeground(painter, rect)
        sc = self.scene()
        if sc.is_exporting or sc.clean_render:
            return
        # Fuori dalla pagina si vedrebbero i bordi delle pagine vicine: coperti del tutto dallo sfondo
        # La copertura è allineata ai pixel dello schermo, così sui bordi non restano filini sfumati
        page = self.page_rect()
        dev = painter.worldTransform().mapRect(page)
        page_px = QRectF(QPointF(round(dev.left()), round(dev.top())), QPointF(round(dev.right()), round(dev.bottom())))
        top_left = page_px.topLeft()
        painter.save()
        painter.resetTransform()
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, False)
        outer = QPainterPath()
        outer.addRect(QRectF(self.viewport().rect()).adjusted(-2, -2, 2, 2))
        inner = QPainterPath()
        inner.addRect(page_px)
        painter.fillPath(outer.subtracted(inner), QColor(THEME["backdrop"]))
        # Etichetta della pagina, in pixel dello schermo
        painter.setRenderHint(QPainter.RenderHint.TextAntialiasing, True)
        painter.setFont(ui_font(11))
        painter.setPen(QColor(THEME["muted"]))
        painter.drawText(QPointF(top_left.x() + 1, top_left.y() - 8), sc.page_label(self.index))
        painter.restore()


class PageGridView(QScrollArea):
    """Griglia delle pagine con barre di scorrimento orizzontale e verticale."""
    zoom_changed = pyqtSignal(float)
    files_dropped = pyqtSignal(list, QPointF)
    library_dropped = pyqtSignal(list, QPointF)
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
        self._drag = None   # Trascinamento tra le pagine: (tasto, inizio, ultimo punto, spostato)
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
            tile.library_dropped.connect(self.library_dropped)
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

    def zoom_at(self, factor: float, global_pos: QPointF):
        """
        Zoom tenendo fermo sotto il mouse lo stesso punto: della tela, se il mouse è su una pagina,
        altrimenti dello spazio tra le pagine.
        """
        s = max(self.MIN_SCALE, min(self.MAX_SCALE, self.scale * factor))
        if abs(s - self.scale) < 1e-9:
            return
        g = global_pos.toPoint()
        in_view = self.viewport().mapFromGlobal(g)
        in_grid = self._container.mapFromGlobal(g)
        tile = next((t for t in self.tiles if t.geometry().contains(in_grid)), None)
        scene_pt = tile.mapToScene(tile.viewport().mapFromGlobal(g)) if tile else None
        fx = in_grid.x() / max(1, self._container.width())
        fy = in_grid.y() / max(1, self._container.height())
        self.scale = s
        self._place()
        self._resize_now()
        if tile is not None:
            target = tile.viewport().mapTo(self._container, tile.mapFromScene(scene_pt))
        else:
            target = QPoint(round(fx * self._container.width()), round(fy * self._container.height()))
        self.horizontalScrollBar().setValue(target.x() - in_view.x())
        self.verticalScrollBar().setValue(target.y() - in_view.y())
        self.zoom_changed.emit(self.scale)

    def wheelEvent(self, event):
        # Tra le pagine come sulle pagine: rotella zoom verso il mouse, due dita sul trackpad spostano
        action = wheel_action(event, getattr(self._scene, "wheel_mode", "auto"))
        if action[0] == "zoom":
            self.zoom_at(action[1], event.globalPosition())
        elif action[0] == "pan":
            self.horizontalScrollBar().setValue(self.horizontalScrollBar().value() - round(action[1]))
            self.verticalScrollBar().setValue(self.verticalScrollBar().value() - round(action[2]))
        event.accept()

    def viewportEvent(self, event):
        # Pizzico sul trackpad del Mac nello spazio tra le pagine
        if event.type() == QEvent.Type.NativeGesture and event.gestureType() == Qt.NativeGestureType.ZoomNativeGesture:
            self.zoom_at(1.0 + event.value(), event.globalPosition())
            return True
        return super().viewportEvent(event)

    # ---------- Trascinamento dello spazio tra le pagine: sposta la griglia ----------
    def mousePressEvent(self, event):
        if event.button() in (Qt.MouseButton.LeftButton, Qt.MouseButton.MiddleButton):
            self._drag = (event.button(), event.globalPosition(), event.globalPosition(), False)
            event.accept()
            return
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        drag = self._drag
        if drag is None:
            super().mouseMoveEvent(event)
            if event.buttons() == Qt.MouseButton.NoButton:
                self.viewport().setCursor(Qt.CursorShape.OpenHandCursor)
            return
        button, origin, last, moved = drag
        pos = event.globalPosition()
        if not moved and (pos - origin).manhattanLength() < PageTileView.DRAG_THRESHOLD:
            return
        self.viewport().setCursor(Qt.CursorShape.ClosedHandCursor)
        delta = pos - last
        self.horizontalScrollBar().setValue(self.horizontalScrollBar().value() - round(delta.x()))
        self.verticalScrollBar().setValue(self.verticalScrollBar().value() - round(delta.y()))
        self._drag = (button, origin, pos, True)
        event.accept()

    def mouseReleaseEvent(self, event):
        drag = self._drag
        if drag is not None and event.button() == drag[0]:
            self._drag = None
            if not drag[3] and event.button() == Qt.MouseButton.LeftButton \
                    and not event.modifiers() & Qt.KeyboardModifier.ControlModifier:
                self._scene.clearSelection()  # Clic semplice tra le pagine: toglie la selezione
            self.viewport().setCursor(Qt.CursorShape.OpenHandCursor)
            event.accept()
            return
        super().mouseReleaseEvent(event)

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
