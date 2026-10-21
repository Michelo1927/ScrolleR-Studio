"""Vista della tela: zoom, pan e trascinamento file."""
from PyQt6.QtCore import Qt, QRectF, QPointF, pyqtSignal
from PyQt6.QtGui import QPainter
from PyQt6.QtWidgets import QGraphicsView, QFrame

from scrollr.canvas.photo_item import PhotoItem
from scrollr.canvas.scene import CollageScene
from scrollr.config import LIBRARY_MIME
from scrollr.imaging import image_paths_from_mime


class CanvasView(QGraphicsView):
    """
    Vista interattiva: zoom con la rotella, spostamento trascinando lo spazio vuoto (o col tasto centrale),
    selezione a riquadro con Shift + trascinamento e drag-and-drop di file immagine dal PC.
    """
    files_dropped = pyqtSignal(list, QPointF)     # File dal PC, punto della tela dove sono rilasciati
    library_dropped = pyqtSignal(list, QPointF)   # Miniature trascinate dalla libreria
    zoom_changed = pyqtSignal(float)
    MIN_SCALE = 0.03
    MAX_SCALE = 16.0
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
        # Barre di scorrimento per muoversi sulla tela (anche con la rotella del mouse si fa zoom)
        self.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        self.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        self.setFrameShape(QFrame.Shape.NoFrame)
        self.setAcceptDrops(True)
        self._panning = False
        self._pan_start = QPointF()
        self._pan_origin = QPointF()
        self._pan_moved = False      # Spostamento vero (non un semplice clic sul vuoto)
        self._pan_button = None

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
        self.zoom_changed.emit(self.current_scale())

    def fit_to(self, rect: QRectF):
        self.fitInView(rect, Qt.AspectRatioMode.KeepAspectRatio)
        self.zoom_changed.emit(self.current_scale())

    def wheelEvent(self, event):
        step_up = event.angleDelta().y() > 0
        if event.modifiers() & Qt.KeyboardModifier.ControlModifier:
            # Ctrl + Rotella su una foto selezionata = zoom interno della foto
            for it in self.items(event.position().toPoint()):
                if isinstance(it, PhotoItem) and it.isSelected():
                    it.zoom_by(0.08 if step_up else -0.08)
                    event.accept()
                    return
        self.zoom_by(1.15 if step_up else 1.0 / 1.15)
        event.accept()

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

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.MiddleButton:
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
