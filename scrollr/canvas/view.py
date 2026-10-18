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
    Vista interattiva con supporto Zoom con rotella, Pan con tasto centrale
    e Drag-and-Drop diretto di file immagine dal PC.
    """
    files_dropped = pyqtSignal(list, QPointF)     # File dal PC, punto della tela dove sono rilasciati
    library_dropped = pyqtSignal(list, QPointF)   # Miniature trascinate dalla libreria
    zoom_changed = pyqtSignal(float)
    MIN_SCALE = 0.03
    MAX_SCALE = 16.0

    def __init__(self, scene: CollageScene, parent=None):
        super().__init__(scene, parent)
        self.setRenderHints(
            QPainter.RenderHint.Antialiasing |
            QPainter.RenderHint.SmoothPixmapTransform
        )
        self.setViewportUpdateMode(QGraphicsView.ViewportUpdateMode.SmartViewportUpdate)
        self.setTransformationAnchor(QGraphicsView.ViewportAnchor.AnchorUnderMouse)
        self.setResizeAnchor(QGraphicsView.ViewportAnchor.AnchorViewCenter)
        self.setDragMode(QGraphicsView.DragMode.RubberBandDrag)
        # Barre di scorrimento per muoversi sulla tela (anche con la rotella del mouse si fa zoom)
        self.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        self.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        self.setFrameShape(QFrame.Shape.NoFrame)
        self.setAcceptDrops(True)
        self._panning = False
        self._pan_start = QPointF()

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

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.MiddleButton:
            self._panning = True
            self._pan_start = event.position()
            self.viewport().setCursor(Qt.CursorShape.ClosedHandCursor)
            event.accept()
            return
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if self._panning:
            delta = event.position() - self._pan_start
            self._pan_start = event.position()
            h_bar, v_bar = self._pan_bars()
            h_bar.setValue(h_bar.value() - int(delta.x()))
            v_bar.setValue(v_bar.value() - int(delta.y()))
            event.accept()
            return
        super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event):
        if event.button() == Qt.MouseButton.MiddleButton:
            self._panning = False
            self.viewport().unsetCursor()
            event.accept()
            return
        super().mouseReleaseEvent(event)

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
