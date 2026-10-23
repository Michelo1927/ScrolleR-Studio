"""Vista della tela: zoom, pan e trascinamento file."""
from typing import Optional

from PyQt6.QtCore import Qt, QEvent, QPoint, QRectF, QPointF, pyqtSignal
from PyQt6.QtGui import QPainter
from PyQt6.QtWidgets import QGraphicsView, QFrame

from scrollr.canvas.photo_item import PhotoItem
from scrollr.canvas.scene import CollageScene
from scrollr.config import LIBRARY_MIME
from scrollr.imaging import image_paths_from_mime
from scrollr.keys import IS_MAC


def is_trackpad_scroll(event) -> bool:
    """
    Scorrimento con due dita sul trackpad (e non rotella del mouse). Qt non lo dice in modo sicuro:
    il trackpad ha le fasi del gesto o i pixel (Mac), oppure passi piccoli e continui; la rotella
    scatta a gradini di 120.
    """
    if event.phase() != Qt.ScrollPhase.NoScrollPhase or not event.pixelDelta().isNull():
        return True
    if IS_MAC:
        return False  # Sul Mac il mouse ha l'accelerazione (passi non a 120) ma niente pixel precisi
    d = event.angleDelta()
    return d.x() % 120 != 0 or d.y() % 120 != 0


def wheel_action(event, mode: str):
    """
    Cosa fa una rotella o uno scorrimento sulla tela:
    ("zoom", fattore) · ("pan", dx, dy) in pixel · ("inner", verso) per lo zoom dentro la foto · ("none",).
    `mode`: "auto" = trackpad sposta e rotella zooma, "zoom" = sempre zoom, "pan" = sempre sposta.
    """
    mods = event.modifiers()
    d = event.angleDelta()
    if mods & Qt.KeyboardModifier.AltModifier:
        # Con Alt Windows può girare la rotella in orizzontale: vale la direzione che c'è
        step = d.y() or d.x()
        return ("inner", step) if step else ("none",)
    if mods & Qt.KeyboardModifier.ControlModifier:
        # Ctrl + rotella e pizzico sul trackpad di Windows: zoom graduale, che segue il gesto
        return ("zoom", 1.15 ** (d.y() / 120.0)) if d.y() else ("none",)
    trackpad = is_trackpad_scroll(event)
    if mode == "pan" or (mode == "auto" and trackpad):
        pixels = event.pixelDelta()
        dx, dy = (pixels.x(), pixels.y()) if not pixels.isNull() else (d.x(), d.y())
        if mods & Qt.KeyboardModifier.ShiftModifier and not dx:
            dx, dy = dy, 0  # Shift + rotella del mouse: in orizzontale
        return ("pan", dx, dy) if (dx or dy) else ("none",)
    if not d.y():
        return ("none",)
    return ("zoom", 1.15 ** (d.y() / 120.0))


class CanvasView(QGraphicsView):
    """
    Vista interattiva: zoom con rotella, Ctrl + rotella o pizzico; spostamento con due dita sul trackpad,
    trascinando lo spazio vuoto, col tasto centrale o con Spazio + trascina; selezione a riquadro con Shift + trascinamento;
    drag-and-drop di file immagine dal PC.
    """
    files_dropped = pyqtSignal(list, QPointF)     # File dal PC, punto della tela dove sono rilasciati
    library_dropped = pyqtSignal(list, QPointF)   # Miniature trascinate dalla libreria
    zoom_changed = pyqtSignal(float)
    MIN_SCALE = 0.03
    MAX_SCALE = 16.0
    FREE_PAN = True  # Area scorribile attorno alla tela adattata allo zoom (le viste a scacchiera hanno la loro)
    DRAG_THRESHOLD = 4  # Pixel oltre i quali un clic sul vuoto diventa uno spostamento della vista

    def __init__(self, scene: CollageScene, parent=None):
        super().__init__(scene, parent)
        self.setRenderHints(
            QPainter.RenderHint.Antialiasing |
            QPainter.RenderHint.SmoothPixmapTransform
        )
        self.setViewportUpdateMode(QGraphicsView.ViewportUpdateMode.SmartViewportUpdate)
        self.setTransformationAnchor(QGraphicsView.ViewportAnchor.AnchorUnderMouse)
        self.setResizeAnchor(QGraphicsView.ViewportAnchor.AnchorViewCenter)
        # Il riquadro di selezione si accende solo con Shift (vedi mousePressEvent)
        self.setDragMode(QGraphicsView.DragMode.NoDrag)
        # Barre di scorrimento per muoversi sulla tela (anche con due dita sul trackpad o trascinando)
        self.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        self.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        self.setFrameShape(QFrame.Shape.NoFrame)
        self.setAcceptDrops(True)
        self._panning = False
        self._pan_start = QPointF()
        self._pan_origin = QPointF()
        self._pan_moved = False      # Spostamento vero (non un semplice clic sul vuoto)
        self._pan_button = None
        self._space_down = False     # Spazio tenuto premuto: si trascina la vista anche sopra le foto

    def update_pan_area(self, center: Optional[QPointF] = None):
        """
        Area in cui si può scorrere: la tela più, per lato, metà finestra (allo zoom attuale) e un po' di più.
        Trascinando lo sfondo, qualunque pagina, anche la prima o l'ultima, arriva al centro dello schermo.
        """
        sc = self.scene()
        if not self.FREE_PAN or not hasattr(sc, "canvas_rect"):
            return
        if center is None:
            center = self.mapToScene(self.viewport().rect().center())
        s = max(self.current_scale(), 1e-6)
        pad_x = max(sc.frame_w, 0.6 * self.viewport().width() / s)
        pad_y = max(sc.frame_h, 0.6 * self.viewport().height() / s)
        self.setSceneRect(sc.canvas_rect().adjusted(-pad_x, -pad_y, pad_x, pad_y))
        self.centerOn(center)

    def resizeEvent(self, event):
        center = self.mapToScene(QPoint(event.oldSize().width() // 2, event.oldSize().height() // 2))             if event.oldSize().isValid() else None
        super().resizeEvent(event)
        self.update_pan_area(center)

    def _pan_bars(self):
        """Barre mosse dal trascinamento col tasto centrale (la vista a scacchiera usa quelle della griglia)."""
        return self.horizontalScrollBar(), self.verticalScrollBar()

    def current_scale(self) -> float:
        return self.transform().m11()

    def zoom_by(self, factor: float, under_mouse: bool = True):
        target = self.current_scale() * factor
        if not (self.MIN_SCALE <= target <= self.MAX_SCALE):
            return
        if not under_mouse:
            self.setTransformationAnchor(QGraphicsView.ViewportAnchor.AnchorViewCenter)
        self.scale(factor, factor)
        self.setTransformationAnchor(QGraphicsView.ViewportAnchor.AnchorUnderMouse)
        self.update_pan_area()
        self.zoom_changed.emit(self.current_scale())

    def zoom_at(self, factor: float, view_pos: QPointF):
        """Zoom tenendo fermo il punto della tela sotto `view_pos` (la posizione del mouse nella vista)."""
        target = self.current_scale() * factor
        if not (self.MIN_SCALE <= target <= self.MAX_SCALE):
            return
        anchor = self.mapToScene(view_pos.toPoint())
        self.setTransformationAnchor(QGraphicsView.ViewportAnchor.NoAnchor)
        self.scale(factor, factor)
        self.setTransformationAnchor(QGraphicsView.ViewportAnchor.AnchorUnderMouse)
        # Dove è finito quel punto dopo lo zoom: le barre lo riportano sotto il mouse
        moved = self.viewportTransform().map(anchor) - view_pos
        h_bar, v_bar = self.horizontalScrollBar(), self.verticalScrollBar()
        h_bar.setValue(h_bar.value() + round(moved.x()))
        v_bar.setValue(v_bar.value() + round(moved.y()))
        self.update_pan_area()
        self.zoom_changed.emit(self.current_scale())

    def fit_to(self, rect: QRectF):
        self.fitInView(rect, Qt.AspectRatioMode.KeepAspectRatio)
        self.update_pan_area(rect.center())
        self.zoom_changed.emit(self.current_scale())

    def _wheel_zoom(self, factor: float, event):
        """Zoom verso il punto sotto il mouse (la vista a scacchiera lo fa sulla griglia)."""
        self.zoom_at(factor, event.position())

    def _wheel_pan(self, dx: float, dy: float):
        h_bar, v_bar = self._pan_bars()
        h_bar.setValue(h_bar.value() - round(dx))
        v_bar.setValue(v_bar.value() - round(dy))

    def wheelEvent(self, event):
        action = wheel_action(event, getattr(self.scene(), "wheel_mode", "auto"))
        if action[0] == "inner":
            # Alt + rotella su una foto selezionata = zoom dentro la foto (come Alt + trascina per l'inquadratura)
            for it in self.items(event.position().toPoint()):
                if isinstance(it, PhotoItem) and it.isSelected():
                    it.zoom_by(0.08 if action[1] > 0 else -0.08)
                    event.accept()
                    return
            event.accept()
            return
        if action[0] == "zoom":
            self._wheel_zoom(action[1], event)
        elif action[0] == "pan":
            self._wheel_pan(action[1], action[2])
        else:
            event.ignore()
            return
        event.accept()

    def viewportEvent(self, event):
        # Pizzico sul trackpad del Mac: arriva come gesto nativo, non come rotella
        if event.type() == QEvent.Type.NativeGesture and event.gestureType() == Qt.NativeGestureType.ZoomNativeGesture:
            self._pinch_zoom(1.0 + event.value(), event)
            return True
        return super().viewportEvent(event)

    def _pinch_zoom(self, factor: float, event):
        self.zoom_at(factor, event.position())

    def _element_at(self, pos) -> bool:
        return self.itemAt(pos) is not None

    def _start_pan(self, event):
        self._panning = True
        self._pan_moved = False
        self._pan_button = event.button()
        # Posizione sullo schermo: nella vista a scacchiera la pagina stessa scorre sotto il mouse
        self._pan_start = event.globalPosition()
        self._pan_origin = event.globalPosition()
        event.accept()

    def keyPressEvent(self, event):
        if event.key() == Qt.Key.Key_Space and not event.modifiers():
            if not event.isAutoRepeat():
                self._space_down = True
                if not self._panning:
                    self.viewport().setCursor(Qt.CursorShape.OpenHandCursor)
            event.accept()
            return
        super().keyPressEvent(event)

    def keyReleaseEvent(self, event):
        if event.key() == Qt.Key.Key_Space:
            if not event.isAutoRepeat():
                self._space_down = False
                if not self._panning:
                    self.viewport().unsetCursor()
            event.accept()
            return
        super().keyReleaseEvent(event)

    def focusOutEvent(self, event):
        self._space_down = False
        super().focusOutEvent(event)

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.MiddleButton or (
                self._space_down and event.button() == Qt.MouseButton.LeftButton):
            self._start_pan(event)
            self.viewport().setCursor(Qt.CursorShape.ClosedHandCursor)
            return
        if event.button() == Qt.MouseButton.LeftButton and not self._element_at(event.position().toPoint()):
            if event.modifiers() & Qt.KeyboardModifier.ShiftModifier:
                # Shift + trascina sul vuoto: riquadro di selezione (con Ctrl si aggiunge alla selezione)
                self.setDragMode(QGraphicsView.DragMode.RubberBandDrag)
                if not event.modifiers() & Qt.KeyboardModifier.ControlModifier:
                    self.scene().clearSelection()
                super().mousePressEvent(event)
                return
            # Trascina sul vuoto: sposta la vista. La selezione resta finché non è un semplice clic
            scene = self.scene()
            if hasattr(scene, "canvas_rect"):
                pt = self.mapToScene(event.position().toPoint())
                if scene.canvas_rect().contains(pt):
                    scene.last_click_page = max(0, min(scene.num_frames - 1, int(pt.x() // scene.frame_w)))
            self._start_pan(event)
            return
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if self._panning:
            pos = event.globalPosition()
            if not self._pan_moved and (pos - self._pan_origin).manhattanLength() < self.DRAG_THRESHOLD:
                event.accept()
                return
            if not self._pan_moved:
                self._pan_moved = True
                self.viewport().setCursor(Qt.CursorShape.ClosedHandCursor)
            delta = pos - self._pan_start
            self._pan_start = pos
            h_bar, v_bar = self._pan_bars()
            h_bar.setValue(h_bar.value() - round(delta.x()))
            v_bar.setValue(v_bar.value() - round(delta.y()))
            event.accept()
            return
        super().mouseMoveEvent(event)
        if event.buttons() == Qt.MouseButton.NoButton:
            # Sul vuoto la mano aperta dice che si può trascinare; con Shift la croce della selezione.
            # Sopra un elemento il cursore lo sceglie l'elemento stesso
            if not self._element_at(event.position().toPoint()):
                shift = event.modifiers() & Qt.KeyboardModifier.ShiftModifier
                self.viewport().setCursor(Qt.CursorShape.CrossCursor if shift else Qt.CursorShape.OpenHandCursor)

    def mouseReleaseEvent(self, event):
        if self._panning and event.button() == self._pan_button:
            self._panning = False
            if not self._pan_moved and event.button() == Qt.MouseButton.LeftButton \
                    and not event.modifiers() & Qt.KeyboardModifier.ControlModifier:
                self.scene().clearSelection()  # Clic semplice sul vuoto: toglie la selezione
            self.viewport().setCursor(Qt.CursorShape.OpenHandCursor)
            event.accept()
            return
        super().mouseReleaseEvent(event)
        if self.dragMode() == QGraphicsView.DragMode.RubberBandDrag:
            self.setDragMode(QGraphicsView.DragMode.NoDrag)

    @staticmethod
    def _accept_drag(event) -> bool:
        mime = event.mimeData()
        if mime.hasFormat(LIBRARY_MIME):
            # Copia, non spostamento: la foto resta anche nella libreria
            event.setDropAction(Qt.DropAction.CopyAction)
            event.accept()
            return True
        if mime.hasUrls():
            event.acceptProposedAction()
            return True
        return False

    def dragEnterEvent(self, event):
        if not self._accept_drag(event):
            super().dragEnterEvent(event)

    def dragMoveEvent(self, event):
        if not self._accept_drag(event):
            super().dragMoveEvent(event)

    def dropEvent(self, event):
        mime = event.mimeData()
        scene_pos = self.mapToScene(event.position().toPoint())
        if mime.hasFormat(LIBRARY_MIME):
            paths = [p for p in bytes(mime.data(LIBRARY_MIME)).decode("utf-8").split("\n") if p]
            event.setDropAction(Qt.DropAction.CopyAction)
            event.accept()
            if paths:
                self.library_dropped.emit(paths, scene_pos)
        elif mime.hasUrls():
            paths = image_paths_from_mime(mime)
            event.acceptProposedAction()
            if paths:
                self.files_dropped.emit(paths, scene_pos)
        else:
            super().dropEvent(event)
