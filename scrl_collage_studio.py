import sys
import os
import math
import random
from typing import List, Optional, Tuple

from PyQt6.QtCore import (
    Qt, QRectF, QPointF, QSizeF, pyqtSignal, QSize
)
from PyQt6.QtGui import (
    QPixmap, QImage, QPainter, QPen, QColor, QBrush,
    QPainterPath, QAction, QIcon, QCursor, QTransform
)
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QPushButton, QLabel, QComboBox, QSpinBox, QSlider, QFileDialog,
    QColorDialog, QListWidget, QListWidgetItem, QGraphicsView,
    QGraphicsScene, QGraphicsObject, QGraphicsItem, QFrame,
    QCheckBox, QMessageBox, QMenu, QScrollArea, QSplitter, QGroupBox,
    QGridLayout
)
from PIL import Image, ImageOps


class PhotoItem(QGraphicsObject):
    """
    Elemento grafico interattivo che rappresenta una foto sul canvas.
    Supporta:
    - Ridimensionamento cella tramite maniglie agli angoli (con object-fit: cover automatico)
    - Zoom interno e Pan interno (Alt + Trascina o tramite slider)
    - Angoli arrotondati, bordo personalizzabile e rotazione
    - Snap magnetico ai bordi e al centro del collage
    """
    selected_changed = pyqtSignal(object)
    HANDLE_SIZE = 14.0

    def __init__(self, image_path: str, pil_image: Image.Image, cell_w: float = 400.0, cell_h: float = 500.0):
        super().__init__()
        self.image_path = image_path
        self.pil_image = pil_image
        self.qimage = self._pil_to_qimage(pil_image)
        self.pixmap = QPixmap.fromImage(self.qimage)

        # Dimensioni del riquadro/cella della foto sul canvas
        self.cell_w = float(cell_w)
        self.cell_h = float(cell_h)

        # Parametri di trasformazione interna (ritaglio / zoom dentro la cella)
        self.inner_zoom = 1.0       # 1.0 = riempie esattamente la cella (object-fit: cover)
        self.pan_x = 0.0            # Offset orizzontale interno (-1.0 a +1.0)
        self.pan_y = 0.0            # Offset verticale interno (-1.0 a +1.0)

        # Stile cornice
        self.border_radius = 0.0
        self.border_width = 0.0
        self.border_color = QColor("#FFFFFF")

        # Stato interazione maniglie
        self._resizing_handle: Optional[str] = None
        self._panning_inner = False
        self._last_mouse_scene_pos = QPointF()
        self.snap_enabled = True

        self.setFlags(
            QGraphicsItem.GraphicsItemFlag.ItemIsMovable |
            QGraphicsItem.GraphicsItemFlag.ItemIsSelectable |
            QGraphicsItem.GraphicsItemFlag.ItemSendsGeometryChanges
        )
        self.setAcceptHoverEvents(True)
        self._update_transform_origin()

    @staticmethod
    def _pil_to_qimage(pil_img: Image.Image) -> QImage:
        rgba_img = pil_img.convert("RGBA")
        data = rgba_img.tobytes("raw", "RGBA")
        qimg = QImage(data, rgba_img.width, rgba_img.height, rgba_img.width * 4, QImage.Format.Format_RGBA8888)
        return qimg.copy()

    def _update_transform_origin(self):
        self.setTransformOriginPoint(self.cell_w / 2.0, self.cell_h / 2.0)

    def set_cell_size(self, w: float, h: float):
        self.prepareGeometryChange()
        self.cell_w = max(40.0, float(w))
        self.cell_h = max(40.0, float(h))
        self._update_transform_origin()
        self.update()

    def reset_aspect_to_original(self):
        """Adatta il riquadro alle proporzioni originali della foto."""
        if self.pixmap.width() > 0 and self.pixmap.height() > 0:
            ratio = self.pixmap.width() / self.pixmap.height()
            area = self.cell_w * self.cell_h
            new_w = math.sqrt(area * ratio)
            new_h = new_w / ratio
            self.set_cell_size(new_w, new_h)
            self.pan_x = 0.0
            self.pan_y = 0.0
            self.inner_zoom = 1.0
            self.update()

    def boundingRect(self) -> QRectF:
        margin = max(self.HANDLE_SIZE, self.border_width) + 4.0
        return QRectF(-margin, -margin, self.cell_w + margin * 2, self.cell_h + margin * 2)

    def _get_handle_rects(self) -> dict:
        hs = self.HANDLE_SIZE
        half = hs / 2.0
        return {
            "tl": QRectF(-half, -half, hs, hs),
            "tr": QRectF(self.cell_w - half, -half, hs, hs),
            "bl": QRectF(-half, self.cell_h - half, hs, hs),
            "br": QRectF(self.cell_w - half, self.cell_h - half, hs, hs),
        }

    def _handle_at(self, pos: QPointF) -> Optional[str]:
        if not self.isSelected():
            return None
        for name, rect in self._get_handle_rects().items():
            if rect.adjusted(-4, -4, 4, 4).contains(pos):
                return name
        return None

    def paint(self, painter: QPainter, option, widget=None):
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, True)

        cell_rect = QRectF(0, 0, self.cell_w, self.cell_h)

        # Creazione percorso con angoli arrotondati
        path = QPainterPath()
        radius = min(self.border_radius, self.cell_w / 2.0, self.cell_h / 2.0)
        path.addRoundedRect(cell_rect, radius, radius)

        painter.save()
        painter.setClipPath(path)

        # Calcolo Object-Fit: Cover + Zoom interno + Pan interno
        img_w = float(self.pixmap.width())
        img_h = float(self.pixmap.height())
        if img_w > 0 and img_h > 0:
            scale_cover = max(self.cell_w / img_w, self.cell_h / img_h) * self.inner_zoom
            draw_w = img_w * scale_cover
            draw_h = img_h * scale_cover

            # Margine di scorrimento disponibile per il pan interno
            max_dx = max(0.0, (draw_w - self.cell_w) / 2.0)
            max_dy = max(0.0, (draw_h - self.cell_h) / 2.0)

            dx = (self.cell_w - draw_w) / 2.0 + (self.pan_x * max_dx)
            dy = (self.cell_h - draw_h) / 2.0 + (self.pan_y * max_dy)

            target_rect = QRectF(dx, dy, draw_w, draw_h)
            painter.drawPixmap(target_rect, self.pixmap, QRectF(0, 0, img_w, img_h))

        painter.restore()

        # Disegno eventuale bordo della foto
        if self.border_width > 0:
            pen = QPen(self.border_color, self.border_width)
            pen.setJoinStyle(Qt.PenJoinStyle.RoundJoin)
            painter.setPen(pen)
            painter.setBrush(Qt.BrushStyle.NoBrush)
            painter.drawPath(path)

        # Disegno cornice di selezione e maniglie (solo se non siamo in fase di esportazione)
        scene = self.scene()
        is_exporting = getattr(scene, "is_exporting", False) if scene else False
        if self.isSelected() and not is_exporting:
            sel_pen = QPen(QColor("#3B82F6"), 2.5, Qt.PenStyle.SolidLine)
            painter.setPen(sel_pen)
            painter.setBrush(Qt.BrushStyle.NoBrush)
            painter.drawRect(cell_rect)

            # Maniglie agli angoli
            painter.setPen(QPen(QColor("#1E3A8A"), 1.5))
            painter.setBrush(QBrush(QColor("#FFFFFF")))
            for rect in self._get_handle_rects().values():
                painter.drawEllipse(rect)

    def hoverMoveEvent(self, event):
        handle = self._handle_at(event.pos())
        if handle in ("tl", "br"):
            self.setCursor(QCursor(Qt.CursorShape.SizeFDiagCursor))
        elif handle in ("tr", "bl"):
            self.setCursor(QCursor(Qt.CursorShape.SizeBDiagCursor))
        else:
            self.setCursor(QCursor(Qt.CursorShape.OpenHandCursor))
        super().hoverMoveEvent(event)

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            handle = self._handle_at(event.pos())
            if handle:
                self._resizing_handle = handle
                self._last_mouse_scene_pos = event.scenePos()
                event.accept()
                return
            elif event.modifiers() & Qt.KeyboardModifier.AltModifier:
                # Alt + Trascina sposta l'inquadratura interna della foto (Pan interno)
                self._panning_inner = True
                self._last_mouse_scene_pos = event.scenePos()
                self.setCursor(QCursor(Qt.CursorShape.SizeAllCursor))
                event.accept()
                return
            self.setCursor(QCursor(Qt.CursorShape.ClosedHandCursor))
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if self._resizing_handle:
            delta = event.scenePos() - self._last_mouse_scene_pos
            self._last_mouse_scene_pos = event.scenePos()

            keep_ratio = bool(event.modifiers() & Qt.KeyboardModifier.ShiftModifier)
            old_w, old_h = self.cell_w, self.cell_h
            ratio = old_w / old_h if old_h > 0 else 1.0

            new_x, new_y = self.pos().x(), self.pos().y()
            new_w, new_h = old_w, old_h

            if "r" in self._resizing_handle:
                new_w = max(50.0, old_w + delta.x())
            if "b" in self._resizing_handle:
                new_h = max(50.0, old_h + delta.y())
            if "l" in self._resizing_handle:
                potential_w = old_w - delta.x()
                if potential_w >= 50.0:
                    new_w = potential_w
                    new_x += delta.x()
            if "t" in self._resizing_handle:
                potential_h = old_h - delta.y()
                if potential_h >= 50.0:
                    new_h = potential_h
                    new_y += delta.y()

            if keep_ratio:
                new_h = new_w / ratio

            self.setPos(new_x, new_y)
            self.set_cell_size(new_w, new_h)
            self.selected_changed.emit(self)
            event.accept()
            return

        if self._panning_inner:
            delta = event.scenePos() - self._last_mouse_scene_pos
            self._last_mouse_scene_pos = event.scenePos()
            # Assicura che ci sia margine di scorrimento; se zoom è 1.0 sull'asse pieno, aumenta leggermente
            if self.inner_zoom <= 1.02:
                self.inner_zoom = 1.15
            self.pan_x = max(-1.0, min(1.0, self.pan_x + delta.x() / 150.0))
            self.pan_y = max(-1.0, min(1.0, self.pan_y + delta.y() / 150.0))
            self.update()
            self.selected_changed.emit(self)
            event.accept()
            return

        super().mouseMoveEvent(event)

        # Snap magnetico ai bordi del canvas e al centro
        if self.snap_enabled and self.scene() and self.rotation() == 0:
            scene_rect = self.scene().sceneRect()
            snap_dist = 12.0
            pos = self.pos()
            x, y = pos.x(), pos.y()

            # Snap X (bordo sinistro, destro, centro canvas e divisioni frame)
            frame_w = getattr(self.scene(), "frame_w", scene_rect.width())
            num_frames = getattr(self.scene(), "num_frames", 1)
            for i in range(num_frames + 1):
                fx = i * frame_w
                if abs(x - fx) < snap_dist:
                    x = fx
                elif abs((x + self.cell_w) - fx) < snap_dist:
                    x = fx - self.cell_w
                # Centro del singolo frame
                if i < num_frames:
                    cx = fx + frame_w / 2.0
                    if abs((x + self.cell_w / 2.0) - cx) < snap_dist:
                        x = cx - self.cell_w / 2.0

            # Snap Y (bordo superiore, inferiore, centro verticale)
            if abs(y) < snap_dist:
                y = 0.0
            elif abs((y + self.cell_h) - scene_rect.height()) < snap_dist:
                y = scene_rect.height() - self.cell_h
            elif abs((y + self.cell_h / 2.0) - (scene_rect.height() / 2.0)) < snap_dist:
                y = scene_rect.height() / 2.0 - self.cell_h / 2.0

            self.setPos(x, y)

    def mouseReleaseEvent(self, event):
        self._resizing_handle = None
        self._panning_inner = False
        self.setCursor(QCursor(Qt.CursorShape.OpenHandCursor))
        super().mouseReleaseEvent(event)

    def wheelEvent(self, event):
        """Con Ctrl + Rotella esegue lo zoom interno della foto."""
        if event.modifiers() & Qt.KeyboardModifier.ControlModifier and self.isSelected():
            delta = event.delta()
            step = 0.08 if delta > 0 else -0.08
            self.inner_zoom = max(1.0, min(4.0, self.inner_zoom + step))
            self.update()
            self.selected_changed.emit(self)
            event.accept()
        else:
            super().wheelEvent(event)


class CollageScene(QGraphicsScene):
    """
    Scena grafica che gestisce la tela del collage (in formato 3:4 o altro),
    lo sfondo, i frame multipli stile SCRL e le linee guida.
    """
    def __init__(self, parent=None):
        super().__init__(parent)
        self.frame_w = 1080
        self.frame_h = 1440  # Default 3:4
        self.num_frames = 1
        self.bg_color = QColor("#FFFFFF")
        self.show_guides = True
        self.is_exporting = False
        self.update_canvas_rect()

    def update_canvas_rect(self):
        total_w = self.frame_w * self.num_frames
        self.setSceneRect(0, 0, total_w, self.frame_h)
        self.update()

    def drawBackground(self, painter: QPainter, rect: QRectF):
        # Area esterna alla tela (grigio scuro)
        painter.fillRect(rect, QColor("#18181B"))

        # Area della tela del collage
        canvas_rect = self.sceneRect()
        if not self.is_exporting:
            # Leggera ombra sotto la tela
            shadow_rect = canvas_rect.translated(8, 8)
            painter.fillRect(shadow_rect, QColor(0, 0, 0, 110))

        painter.fillRect(canvas_rect, self.bg_color)

    def drawForeground(self, painter: QPainter, rect: QRectF):
        if self.is_exporting:
            return

        canvas_rect = self.sceneRect()

        # Maschera semi-trasparente su ciò che esce fuori dalla tela
        outer_path = QPainterPath()
        outer_path.addRect(rect)
        inner_path = QPainterPath()
        inner_path.addRect(canvas_rect)
        mask_path = outer_path.subtracted(inner_path)
        painter.fillPath(mask_path, QColor(24, 24, 27, 190))

        # Bordo esterno della tela
        painter.setPen(QPen(QColor("#52525B"), 2.0))
        painter.setBrush(Qt.BrushStyle.NoBrush)
        painter.drawRect(canvas_rect)

        if self.show_guides:
            # Linee guida centrali leggere
            guide_pen = QPen(QColor(59, 130, 246, 90), 1.5, Qt.PenStyle.DashLine)
            painter.setPen(guide_pen)
            painter.drawLine(
                QPointF(0, self.frame_h / 2.0),
                QPointF(canvas_rect.width(), self.frame_h / 2.0)
            )
            for i in range(self.num_frames):
                cx = i * self.frame_w + self.frame_w / 2.0
                painter.drawLine(QPointF(cx, 0), QPointF(cx, self.frame_h))

            # Linee di separazione tra i Frame (stile SCRL)
            if self.num_frames > 1:
                sep_pen = QPen(QColor("#F43F5E"), 3.0, Qt.PenStyle.DashLine)
                painter.setPen(sep_pen)
                for i in range(1, self.num_frames):
                    x = i * self.frame_w
                    painter.drawLine(QPointF(x, 0), QPointF(x, self.frame_h))


class CanvasView(QGraphicsView):
    """
    Vista interattiva con supporto Zoom con rotella, Pan con tasto centrale
    e Drag-and-Drop diretto di file immagine dal PC.
    """
    files_dropped = pyqtSignal(list)

    def __init__(self, scene: CollageScene, parent=None):
        super().__init__(scene, parent)
        self.setRenderHints(
            QPainter.RenderHint.Antialiasing |
            QPainter.RenderHint.SmoothPixmapTransform
        )
        self.setViewportUpdateMode(QGraphicsView.ViewportUpdateMode.FullViewportUpdate)
        self.setTransformationAnchor(QGraphicsView.ViewportAnchor.AnchorUnderMouse)
        self.setResizeAnchor(QGraphicsView.ViewportAnchor.AnchorViewCenter)
        self.setDragMode(QGraphicsView.DragMode.RubberBandDrag)
        self.setAcceptDrops(True)
        self._panning = False
        self._pan_start = QPointF()

    def wheelEvent(self, event):
        if event.modifiers() & Qt.KeyboardModifier.ControlModifier:
            # Lascia gestire Ctrl+Rotella alla foto selezionata per lo zoom interno
            super().wheelEvent(event)
            if event.isAccepted():
                return

        factor = 1.15 if event.angleDelta().y() > 0 else 1.0 / 1.15
        self.scale(factor, factor)

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.MiddleButton:
            self._panning = True
            self._pan_start = event.position()
            self.setCursor(Qt.CursorShape.ClosedHandCursor)
            event.accept()
            return
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if self._panning:
            delta = event.position() - self._pan_start
            self._pan_start = event.position()
            self.horizontalScrollBar().setValue(self.horizontalScrollBar().value() - int(delta.x()))
            self.verticalScrollBar().setValue(self.verticalScrollBar().value() - int(delta.y()))
            event.accept()
            return
        super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event):
        if event.button() == Qt.MouseButton.MiddleButton:
            self._panning = False
            self.setCursor(Qt.CursorShape.ArrowCursor)
            event.accept()
            return
        super().mouseReleaseEvent(event)

    def dragEnterEvent(self, event):
        if event.mimeData().hasUrls():
            event.acceptProposedAction()
        else:
            super().dragEnterEvent(event)

    def dragMoveEvent(self, event):
        if event.mimeData().hasUrls():
            event.acceptProposedAction()
        else:
            super().dragMoveEvent(event)

    def dropEvent(self, event):
        if event.mimeData().hasUrls():
            paths = []
            valid_exts = (".jpg", ".jpeg", ".png", ".webp", ".bmp")
            for url in event.mimeData().urls():
                local_path = url.toLocalFile()
                if os.path.isfile(local_path) and local_path.lower().endswith(valid_exts):
                    paths.append(local_path)
            if paths:
                self.files_dropped.emit(paths)
            event.acceptProposedAction()
        else:
            super().dropEvent(event)


class MainWindow(QMainWindow):
    ASPECT_RATIOS = {
        "3:4 Verticale (1080×1440) [Predefinito]": (1080, 1440),
        "4:3 Orizzontale (1440×1080)": (1440, 1080),
        "4:5 Portrait IG (1080×1350)": (1080, 1350),
        "1:1 Quadrato (1080×1080)": (1080, 1080),
        "9:16 Story (1080×1920)": (1080, 1920),
        "16:9 Widescreen (1920×1080)": (1920, 1080),
        "2:3 Fotografico (1080×1620)": (1080, 1620),
        "3:2 Fotografico (1620×1080)": (1620, 1080),
        "Personalizzato (Custom W×H)": None,
    }

    def __init__(self):
        super().__init__()
        self.setWindowTitle("SCRL Collage Studio — Senza Limiti (Formato 3:4 & Multi-Frame)")
        self.resize(1500, 920)

        self.loaded_library: List[Tuple[str, Image.Image]] = []
        self.current_layout_mode = "grid"  # "grid", "mosaic", "strips_h", "strips_v", "scatter"
        self._updating_inspector = False

        self.scene = CollageScene(self)
        self.scene.selectionChanged.connect(self._on_selection_changed)
        self.view = CanvasView(self.scene, self)
        self.view.files_dropped.connect(self.load_images_from_paths)
        self.view.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.view.customContextMenuRequested.connect(self._show_canvas_context_menu)

        self._build_ui()
        self._apply_dark_theme()
        self.fit_canvas_in_view()

    def _build_ui(self):
        central = QWidget()
        self.setCentralWidget(central)
        main_v_layout = QVBoxLayout(central)
        main_v_layout.setContentsMargins(8, 8, 8, 8)
        main_v_layout.setSpacing(8)

        # ================= 1. TOP TOOLBAR =================
        toolbar_frame = QFrame()
        toolbar_frame.setObjectName("TopBar")
        tb_layout = QHBoxLayout(toolbar_frame)
        tb_layout.setContentsMargins(12, 8, 12, 8)
        tb_layout.setSpacing(12)

        # Selettore Rapporto di Forma (3:4 di default)
        tb_layout.addWidget(QLabel("Rapporto di Forma:"))
        self.combo_ratio = QComboBox()
        for label in self.ASPECT_RATIOS.keys():
            self.combo_ratio.addItem(label)
        self.combo_ratio.setCurrentIndex(0)  # 3:4 Verticale
        self.combo_ratio.currentIndexChanged.connect(self._on_aspect_ratio_changed)
        tb_layout.addWidget(self.combo_ratio)

        # Campi Custom W x H (visibili solo se si sceglie Personalizzato)
        self.spin_custom_w = QSpinBox()
        self.spin_custom_w.setRange(200, 6000)
        self.spin_custom_w.setValue(1080)
        self.spin_custom_w.setSuffix(" px")
        self.spin_custom_w.setVisible(False)
        self.spin_custom_w.valueChanged.connect(self._apply_custom_ratio)

        self.spin_custom_h = QSpinBox()
        self.spin_custom_h.setRange(200, 6000)
        self.spin_custom_h.setValue(1440)
        self.spin_custom_h.setSuffix(" px")
        self.spin_custom_h.setVisible(False)
        self.spin_custom_h.valueChanged.connect(self._apply_custom_ratio)

        tb_layout.addWidget(self.spin_custom_w)
        tb_layout.addWidget(self.spin_custom_h)

        # Numero di Frame (1 = Collage singolo 3:4, >1 = Carosello SCRL)
        tb_layout.addWidget(QLabel("N° Frame (Pagine):"))
        self.spin_frames = QSpinBox()
        self.spin_frames.setRange(1, 30)
        self.spin_frames.setValue(1)
        self.spin_frames.setToolTip("1 = Collage unico nel formato scelto (es. 3:4).\n2+ = Carosello continuo multi-pagina stile SCRL.")
        self.spin_frames.valueChanged.connect(self._on_frames_changed)
        tb_layout.addWidget(self.spin_frames)

        # Colore Sfondo
        self.btn_bg_color = QPushButton("Sfondo Tela")
        self.btn_bg_color.clicked.connect(self._pick_bg_color)
        tb_layout.addWidget(self.btn_bg_color)

        # Guide e Snap
        self.chk_guides = QCheckBox("Linee Guida")
        self.chk_guides.setChecked(True)
        self.chk_guides.toggled.connect(self._toggle_guides)
        tb_layout.addWidget(self.chk_guides)

        self.chk_snap = QCheckBox("Snap Magnetico")
        self.chk_snap.setChecked(True)
        self.chk_snap.toggled.connect(self._toggle_snap)
        tb_layout.addWidget(self.chk_snap)

        btn_fit = QPushButton("Adatta Vista")
        btn_fit.clicked.connect(self.fit_canvas_in_view)
        tb_layout.addWidget(btn_fit)

        tb_layout.addStretch()

        # Qualità Esportazione (1x Standard HD / 2x Ultra HD)
        tb_layout.addWidget(QLabel("Qualità:"))
        self.combo_quality = QComboBox()
        self.combo_quality.addItems(["Standard HD (1x)", "Ultra HD (2x - 2160p)"])
        self.combo_quality.setCurrentIndex(1)  # Ultra HD di default per massima nitidezza
        tb_layout.addWidget(self.combo_quality)

        btn_export_full = QPushButton("Esporta Collage Intero")
        btn_export_full.setObjectName("PrimaryButton")
        btn_export_full.clicked.connect(self.export_full_collage)
        tb_layout.addWidget(btn_export_full)

        btn_export_frames = QPushButton("Esporta Frame Separati")
        btn_export_frames.clicked.connect(self.export_split_frames)
        tb_layout.addWidget(btn_export_frames)

        main_v_layout.addWidget(toolbar_frame)

        # ================= 2. CORPO CENTRALE (3 PANNELLI) =================
        splitter = QSplitter(Qt.Orientation.Horizontal)

        # --- PANNELLO SINISTRO: Libreria Foto + Generatore Disposizioni ---
        left_panel = QFrame()
        left_panel.setObjectName("SidePanel")
        left_panel.setMinimumWidth(300)
        left_panel.setMaximumWidth(360)
        left_layout = QVBoxLayout(left_panel)

        # Sezione Caricamento Foto
        grp_lib = QGroupBox("1. Foto (Senza Limiti)")
        lib_layout = QVBoxLayout(grp_lib)

        btn_load = QPushButton("+ Carica Foto dal PC")
        btn_load.setObjectName("AccentButton")
        btn_load.clicked.connect(self.open_file_dialog)
        lib_layout.addWidget(btn_load)

        self.list_library = QListWidget()
        self.list_library.setIconSize(QSize(64, 64))
        self.list_library.setToolTip("Fai doppio clic su una miniatura per aggiungerla al collage")
        self.list_library.itemDoubleClicked.connect(self._on_library_item_double_clicked)
        lib_layout.addWidget(self.list_library)

        lib_btns = QHBoxLayout()
        btn_add_all = QPushButton("Inserisci Tutte sul Collage")
        btn_add_all.clicked.connect(self.add_all_library_to_canvas)
        btn_clear_canvas = QPushButton("Svuota Tela")
        btn_clear_canvas.clicked.connect(self.clear_canvas_photos)
        lib_btns.addWidget(btn_add_all)
        lib_btns.addWidget(btn_clear_canvas)
        lib_layout.addLayout(lib_btns)

        left_layout.addWidget(grp_lib)

        # Sezione Layout Automatici e Riorganizzazione
        grp_layout = QGroupBox("2. Disposizione Automatica & Riorganizzazione")
        lay_vbox = QVBoxLayout(grp_layout)

        grid_btns = QGridLayout()
        btn_grid = QPushButton("Griglia Auto (3:4 / N Foto)")
        btn_grid.clicked.connect(lambda: self.apply_auto_layout("grid"))

        btn_mosaic = QPushButton("Mosaico (Foto Hero + Griglia)")
        btn_mosaic.clicked.connect(lambda: self.apply_auto_layout("mosaic"))

        btn_strips_h = QPushButton("Strisce Orizzontali")
        btn_strips_h.clicked.connect(lambda: self.apply_auto_layout("strips_h"))

        btn_strips_v = QPushButton("Colonne Verticali")
        btn_strips_v.clicked.connect(lambda: self.apply_auto_layout("strips_v"))

        btn_scatter = QPushButton("Collage Libero / Polaroid")
        btn_scatter.clicked.connect(lambda: self.apply_auto_layout("scatter"))

        btn_seam = QPushButton("Carosello SCRL (A Cavallo)")
        btn_seam.clicked.connect(lambda: self.apply_auto_layout("scrl_seam"))

        grid_btns.addWidget(btn_grid, 0, 0)
        grid_btns.addWidget(btn_mosaic, 0, 1)
        grid_btns.addWidget(btn_strips_h, 1, 0)
        grid_btns.addWidget(btn_strips_v, 1, 1)
        grid_btns.addWidget(btn_scatter, 2, 0)
        grid_btns.addWidget(btn_seam, 2, 1)
        lay_vbox.addLayout(grid_btns)

        # Pulsante Rimescola (Shuffle) e Scambia
        action_btns = QHBoxLayout()
        btn_shuffle = QPushButton("🔀 Rimescola Ordine Foto")
        btn_shuffle.setObjectName("PrimaryButton")
        btn_shuffle.clicked.connect(self.shuffle_canvas_photos)

        btn_swap = QPushButton("⇄ Scambia 2 Selezionate")
        btn_swap.setToolTip("Seleziona 2 foto sulla tela (tenendo premuto Shift/Ctrl) e clicca qui per scambiarle di posto")
        btn_swap.clicked.connect(self.swap_two_selected_photos)

        action_btns.addWidget(btn_shuffle)
        action_btns.addWidget(btn_swap)
        lay_vbox.addLayout(action_btns)

        # Slider Spaziatura (Gap) e Margine Esterno
        lay_vbox.addWidget(QLabel("Spaziatura tra le foto (Gap):"))
        self.slider_gap = QSlider(Qt.Orientation.Horizontal)
        self.slider_gap.setRange(0, 80)
        self.slider_gap.setValue(16)
        self.slider_gap.valueChanged.connect(lambda: self.apply_auto_layout(self.current_layout_mode, keep_order=True))
        lay_vbox.addWidget(self.slider_gap)

        lay_vbox.addWidget(QLabel("Margine esterno del Collage:"))
        self.slider_margin = QSlider(Qt.Orientation.Horizontal)
        self.slider_margin.setRange(0, 120)
        self.slider_margin.setValue(24)
        self.slider_margin.valueChanged.connect(lambda: self.apply_auto_layout(self.current_layout_mode, keep_order=True))
        lay_vbox.addWidget(self.slider_margin)

        left_layout.addWidget(grp_layout)
        splitter.addWidget(left_panel)

        # --- CENTRO: Canvas View ---
        splitter.addWidget(self.view)

        # --- PANNELLO DESTRO: Inspector Proprietà Foto Selezionata ---
        right_panel = QFrame()
        right_panel.setObjectName("SidePanel")
        right_panel.setMinimumWidth(290)
        right_panel.setMaximumWidth(340)
        right_layout = QVBoxLayout(right_panel)

        grp_insp = QGroupBox("3. Modifica Foto Selezionata")
        insp_layout = QVBoxLayout(grp_insp)

        self.lbl_selection_info = QLabel("Nessuna foto selezionata.\nClicca su una foto nella tela.")
        self.lbl_selection_info.setWordWrap(True)
        insp_layout.addWidget(self.lbl_selection_info)

        # Zoom interno (Ritaglio)
        insp_layout.addWidget(QLabel("Zoom Interno (Ritaglio senza deformare):"))
        self.slider_inner_zoom = QSlider(Qt.Orientation.Horizontal)
        self.slider_inner_zoom.setRange(100, 350)
        self.slider_inner_zoom.setValue(100)
        self.slider_inner_zoom.valueChanged.connect(self._on_inspector_changed)
        insp_layout.addWidget(self.slider_inner_zoom)

        # Pan Interno X e Y (Inquadratura dentro la cella)
        insp_layout.addWidget(QLabel("Sposta Inquadratura Orizzontale (o Alt+Drag):"))
        self.slider_pan_x = QSlider(Qt.Orientation.Horizontal)
        self.slider_pan_x.setRange(-100, 100)
        self.slider_pan_x.setValue(0)
        self.slider_pan_x.valueChanged.connect(self._on_inspector_changed)
        insp_layout.addWidget(self.slider_pan_x)

        insp_layout.addWidget(QLabel("Sposta Inquadratura Verticale (o Alt+Drag):"))
        self.slider_pan_y = QSlider(Qt.Orientation.Horizontal)
        self.slider_pan_y.setRange(-100, 100)
        self.slider_pan_y.setValue(0)
        self.slider_pan_y.valueChanged.connect(self._on_inspector_changed)
        insp_layout.addWidget(self.slider_pan_y)

        # Rotazione
        insp_layout.addWidget(QLabel("Rotazione (-180° a +180°):"))
        self.slider_rotation = QSlider(Qt.Orientation.Horizontal)
        self.slider_rotation.setRange(-180, 180)
        self.slider_rotation.setValue(0)
        self.slider_rotation.valueChanged.connect(self._on_inspector_changed)
        insp_layout.addWidget(self.slider_rotation)

        rot_btns = QHBoxLayout()
        btn_rot_left = QPushButton("↺ -90°")
        btn_rot_left.clicked.connect(lambda: self._rotate_selected_by(-90))
        btn_rot_zero = QPushButton("0° Reset")
        btn_rot_zero.clicked.connect(lambda: self._set_selected_rotation(0))
        btn_rot_right = QPushButton("↻ +90°")
        btn_rot_right.clicked.connect(lambda: self._rotate_selected_by(90))
        rot_btns.addWidget(btn_rot_left)
        rot_btns.addWidget(btn_rot_zero)
        rot_btns.addWidget(btn_rot_right)
        insp_layout.addLayout(rot_btns)

        # Angoli Arrotondati e Bordo (Applicabili anche a tutte le foto)
        insp_layout.addWidget(QLabel("Arrotondamento Angoli (Radius):"))
        self.slider_radius = QSlider(Qt.Orientation.Horizontal)
        self.slider_radius.setRange(0, 200)
        self.slider_radius.setValue(0)
        self.slider_radius.valueChanged.connect(self._on_inspector_changed)
        insp_layout.addWidget(self.slider_radius)

        insp_layout.addWidget(QLabel("Spessore Bordo Foto:"))
        self.slider_border = QSlider(Qt.Orientation.Horizontal)
        self.slider_border.setRange(0, 40)
        self.slider_border.setValue(0)
        self.slider_border.valueChanged.connect(self._on_inspector_changed)
        insp_layout.addWidget(self.slider_border)

        style_btns = QHBoxLayout()
        btn_border_col = QPushButton("Colore Bordo")
        btn_border_col.clicked.connect(self._pick_photo_border_color)
        btn_apply_style_all = QPushButton("Applica Stile a Tutte")
        btn_apply_style_all.clicked.connect(self._apply_style_to_all_photos)
        style_btns.addWidget(btn_border_col)
        style_btns.addWidget(btn_apply_style_all)
        insp_layout.addLayout(style_btns)

        btn_orig_ratio = QPushButton("Ripristina Proporzioni Originali Foto")
        btn_orig_ratio.clicked.connect(self._restore_selected_original_ratio)
        insp_layout.addWidget(btn_orig_ratio)

        # Controlli Livelli (Z-Index)
        insp_layout.addWidget(QLabel("Ordine Sovrapposizione (Livelli):"))
        z_btns1 = QHBoxLayout()
        btn_front = QPushButton("In Primo Piano")
        btn_front.clicked.connect(self._bring_to_front)
        btn_back = QPushButton("Sullo Sfondo")
        btn_back.clicked.connect(self._send_to_back)
        z_btns1.addWidget(btn_front)
        z_btns1.addWidget(btn_back)
        insp_layout.addLayout(z_btns1)

        z_btns2 = QHBoxLayout()
        btn_dup = QPushButton("Duplica Foto")
        btn_dup.clicked.connect(self._duplicate_selected)
        btn_del = QPushButton("Elimina Foto")
        btn_del.setObjectName("DangerButton")
        btn_del.clicked.connect(self._delete_selected)
        z_btns2.addWidget(btn_dup)
        z_btns2.addWidget(btn_del)
        insp_layout.addLayout(z_btns2)

        insp_layout.addStretch()
        right_layout.addWidget(grp_insp)
        splitter.addWidget(right_panel)

        splitter.setStretchFactor(0, 0)
        splitter.setStretchFactor(1, 1)
        splitter.setStretchFactor(2, 0)
        main_v_layout.addWidget(splitter, 1)

    def _apply_dark_theme(self):
        self.setStyleSheet("""
            QMainWindow, QWidget {
                background-color: #18181B;
                color: #F4F4F5;
                font-family: 'Segoe UI', Roboto, sans-serif;
                font-size: 13px;
            }
            #TopBar, #SidePanel {
                background-color: #27272A;
                border: 1px solid #3F3F46;
                border-radius: 8px;
            }
            QGroupBox {
                font-weight: bold;
                border: 1px solid #3F3F46;
                border-radius: 6px;
                margin-top: 8px;
                padding-top: 10px;
            }
            QGroupBox::title {
                subcontrol-origin: margin;
                left: 10px;
                padding: 0 4px;
                color: #60A5FA;
            }
            QPushButton {
                background-color: #3F3F46;
                border: 1px solid #52525B;
                border-radius: 5px;
                padding: 6px 10px;
                color: #F4F4F5;
                font-weight: 500;
            }
            QPushButton:hover {
                background-color: #52525B;
            }
            QPushButton#PrimaryButton {
                background-color: #2563EB;
                border-color: #3B82F6;
                font-weight: bold;
            }
            QPushButton#PrimaryButton:hover {
                background-color: #1D4ED8;
            }
            QPushButton#AccentButton {
                background-color: #059669;
                border-color: #10B981;
                font-weight: bold;
                padding: 8px;
            }
            QPushButton#AccentButton:hover {
                background-color: #047857;
            }
            QPushButton#DangerButton {
                background-color: #DC2626;
                border-color: #EF4444;
            }
            QComboBox, QSpinBox, QListWidget {
                background-color: #18181B;
                border: 1px solid #52525B;
                border-radius: 5px;
                padding: 4px 8px;
                color: #F4F4F5;
            }
            QSlider::groove:horizontal {
                height: 6px;
                background: #3F3F46;
                border-radius: 3px;
            }
            QSlider::handle:horizontal {
                background: #3B82F6;
                width: 14px;
                margin: -4px 0;
                border-radius: 7px;
            }
        """)

    # ================= GESTIONE CANVAS E FORMATO (3:4, ecc.) =================
    def _on_aspect_ratio_changed(self):
        label = self.combo_ratio.currentText()
        dims = self.ASPECT_RATIOS.get(label)
        if dims is None:
            self.spin_custom_w.setVisible(True)
            self.spin_custom_h.setVisible(True)
            self._apply_custom_ratio()
        else:
            self.spin_custom_w.setVisible(False)
            self.spin_custom_h.setVisible(False)
            self.scene.frame_w, self.scene.frame_h = dims
            self.scene.update_canvas_rect()
            if self.get_canvas_photos():
                self.apply_auto_layout(self.current_layout_mode, keep_order=True)
            self.fit_canvas_in_view()

    def _apply_custom_ratio(self):
        self.scene.frame_w = self.spin_custom_w.value()
        self.scene.frame_h = self.spin_custom_h.value()
        self.scene.update_canvas_rect()
        if self.get_canvas_photos():
            self.apply_auto_layout(self.current_layout_mode, keep_order=True)
        self.fit_canvas_in_view()

    def _on_frames_changed(self, value: int):
        self.scene.num_frames = value
        self.scene.update_canvas_rect()
        self.fit_canvas_in_view()

    def _pick_bg_color(self):
        col = QColorDialog.getColor(self.scene.bg_color, self, "Scegli Colore Sfondo Tela")
        if col.isValid():
            self.scene.bg_color = col
            self.scene.update()

    def _toggle_guides(self, checked: bool):
        self.scene.show_guides = checked
        self.scene.update()

    def _toggle_snap(self, checked: bool):
        for item in self.get_canvas_photos():
            item.snap_enabled = checked

    def fit_canvas_in_view(self):
        rect = self.scene.sceneRect().adjusted(-80, -80, 80, 80)
        self.view.fitInView(rect, Qt.AspectRatioMode.KeepAspectRatio)

    # ================= CARICAMENTO E LIBRERIA FOTO =================
    def open_file_dialog(self):
        paths, _ = QFileDialog.getOpenFileNames(
            self,
            "Seleziona Foto (Nessun limite di numero)",
            "",
            "Immagini (*.jpg *.jpeg *.png *.webp *.bmp)"
        )
        if paths:
            self.load_images_from_paths(paths)

    def load_images_from_paths(self, paths: List[str]):
        added_now = []
        for p in paths:
            try:
                pil_img = Image.open(p)
                pil_img = ImageOps.exif_transpose(pil_img)  # Corregge rotazione EXIF smartphone
                pil_img.load()
                self.loaded_library.append((p, pil_img))

                # Crea miniatura nella barra laterale
                thumb = pil_img.copy()
                thumb.thumbnail((128, 128))
                qimg = PhotoItem._pil_to_qimage(thumb)
                icon = QIcon(QPixmap.fromImage(qimg))
                item = QListWidgetItem(icon, os.path.basename(p))
                item.setData(Qt.ItemDataRole.UserRole, len(self.loaded_library) - 1)
                self.list_library.addItem(item)

                photo_item = self._spawn_photo_item(p, pil_img)
                added_now.append(photo_item)
            except Exception as e:
                print(f"Errore caricamento {p}: {e}")

        if added_now:
            # Dispone automaticamente tutte le foto caricate nel formato selezionato (es. 3:4)
            self.apply_auto_layout(self.current_layout_mode, keep_order=True)
            self.fit_canvas_in_view()

    def _spawn_photo_item(self, path: str, pil_img: Image.Image) -> PhotoItem:
        photo_item = PhotoItem(path, pil_img, 400, 500)
        photo_item.snap_enabled = self.chk_snap.isChecked()
        photo_item.selected_changed.connect(self._sync_inspector_from_item)
        # Assegna Z-index crescente
        existing = self.get_canvas_photos()
        max_z = max([it.zValue() for it in existing], default=0.0)
        photo_item.setZValue(max_z + 1.0)
        self.scene.addItem(photo_item)
        return photo_item

    def _on_library_item_double_clicked(self, item: QListWidgetItem):
        idx = item.data(Qt.ItemDataRole.UserRole)
        if 0 <= idx < len(self.loaded_library):
            path, pil_img = self.loaded_library[idx]
            new_item = self._spawn_photo_item(path, pil_img)
            new_item.setPos(self.scene.frame_w * 0.2, self.scene.frame_h * 0.2)
            self.scene.clearSelection()
            new_item.setSelected(True)

    def add_all_library_to_canvas(self):
        self.clear_canvas_photos()
        for path, pil_img in self.loaded_library:
            self._spawn_photo_item(path, pil_img)
        self.apply_auto_layout(self.current_layout_mode, keep_order=True)

    def clear_canvas_photos(self):
        for item in self.get_canvas_photos():
            self.scene.removeItem(item)

    def get_canvas_photos(self) -> List[PhotoItem]:
        items = [it for it in self.scene.items() if isinstance(it, PhotoItem)]
        # Ordina per Z-Value o posizione così l'ordine è stabile
        items.sort(key=lambda x: x.zValue())
        return items

    # ================= ALGORITMI DI LAYOUT E RIORGANIZZAZIONE =================
    def apply_auto_layout(self, mode: str, keep_order: bool = True):
        photos = self.get_canvas_photos()
        n = len(photos)
        if n == 0:
            return

        self.current_layout_mode = mode
        if not keep_order:
            random.shuffle(photos)
            for idx, p in enumerate(photos):
                p.setZValue(idx + 1.0)

        total_w = float(self.scene.sceneRect().width())
        total_h = float(self.scene.sceneRect().height())
        gap = float(self.slider_gap.value())
        margin = float(self.slider_margin.value())

        avail_w = max(100.0, total_w - 2 * margin)
        avail_h = max(100.0, total_h - 2 * margin)

        if mode == "grid":
            # Calcola numero ottimale di righe e colonne in base al rapporto della tela (es. 3:4)
            canvas_aspect = avail_w / avail_h
            cols = max(1, round(math.sqrt(n * canvas_aspect)))
            rows = math.ceil(n / cols)

            row_h = (avail_h - gap * (rows - 1)) / rows
            idx = 0
            for r in range(rows):
                remaining = n - idx
                cols_in_this_row = min(cols, remaining) if r == rows - 1 else min(cols, math.ceil(remaining / (rows - r)))
                col_w = (avail_w - gap * (cols_in_this_row - 1)) / cols_in_this_row
                for c in range(cols_in_this_row):
                    if idx >= n:
                        break
                    p = photos[idx]
                    p.setRotation(0)
                    x = margin + c * (col_w + gap)
                    y = margin + r * (row_h + gap)
                    p.setPos(x, y)
                    p.set_cell_size(col_w, row_h)
                    idx += 1

        elif mode == "mosaic":
            # 1 Foto "Hero" grande in alto (o a sinistra) + le altre distribuite sotto/accanto
            if n == 1:
                photos[0].setRotation(0)
                photos[0].setPos(margin, margin)
                photos[0].set_cell_size(avail_w, avail_h)
            else:
                hero = photos[0]
                others = photos[1:]
                hero.setRotation(0)
                if avail_h >= avail_w:
                    # Formato verticale (es. 3:4): Hero occupa il 55% superiore
                    hero_h = (avail_h - gap) * 0.55
                    hero.setPos(margin, margin)
                    hero.set_cell_size(avail_w, hero_h)

                    rem_y = margin + hero_h + gap
                    rem_h = avail_h - hero_h - gap
                    m = len(others)
                    cols = max(1, round(math.sqrt(m * (avail_w / max(1.0, rem_h)))))
                    rows = math.ceil(m / cols)
                    row_h = (rem_h - gap * (rows - 1)) / rows
                    idx = 0
                    for r in range(rows):
                        cols_row = min(cols, m - idx) if r == rows - 1 else cols
                        col_w = (avail_w - gap * (cols_row - 1)) / cols_row
                        for c in range(cols_row):
                            p = others[idx]
                            p.setRotation(0)
                            p.setPos(margin + c * (col_w + gap), rem_y + r * (row_h + gap))
                            p.set_cell_size(col_w, row_h)
                            idx += 1
                else:
                    # Formato orizzontale: Hero occupa il 55% a sinistra
                    hero_w = (avail_w - gap) * 0.55
                    hero.setPos(margin, margin)
                    hero.set_cell_size(hero_w, avail_h)

                    rem_x = margin + hero_w + gap
                    rem_w = avail_w - hero_w - gap
                    m = len(others)
                    cols = max(1, round(math.sqrt(m * (rem_w / avail_h))))
                    rows = math.ceil(m / cols)
                    row_h = (avail_h - gap * (rows - 1)) / rows
                    idx = 0
                    for r in range(rows):
                        cols_row = min(cols, m - idx) if r == rows - 1 else cols
                        col_w = (rem_w - gap * (cols_row - 1)) / cols_row
                        for c in range(cols_row):
                            p = others[idx]
                            p.setRotation(0)
                            p.setPos(rem_x + c * (col_w + gap), margin + r * (row_h + gap))
                            p.set_cell_size(col_w, row_h)
                            idx += 1

        elif mode == "strips_h":
            row_h = (avail_h - gap * (n - 1)) / n
            for i, p in enumerate(photos):
                p.setRotation(0)
                p.setPos(margin, margin + i * (row_h + gap))
                p.set_cell_size(avail_w, row_h)

        elif mode == "strips_v":
            col_w = (avail_w - gap * (n - 1)) / n
            for i, p in enumerate(photos):
                p.setRotation(0)
                p.setPos(margin + i * (col_w + gap), margin)
                p.set_cell_size(col_w, avail_h)

        elif mode == "scatter":
            # Stile Freestyle / Polaroid con leggera inclinazione casuale
            cols = max(1, math.ceil(math.sqrt(n)))
            rows = math.ceil(n / cols)
            cell_w = avail_w / cols
            cell_h = avail_h / rows
            for i, p in enumerate(photos):
                r = i // cols
                c = i % cols
                w = cell_w * 0.88
                h = cell_h * 0.88
                jitter_x = random.uniform(-cell_w * 0.08, cell_w * 0.08)
                jitter_y = random.uniform(-cell_h * 0.08, cell_h * 0.08)
                x = margin + c * cell_w + (cell_w - w) / 2.0 + jitter_x
                y = margin + r * cell_h + (cell_h - h) / 2.0 + jitter_y
                p.setPos(x, y)
                p.set_cell_size(w, h)
                p.setRotation(random.uniform(-7.5, 7.5))
                if p.border_width == 0:
                    p.border_width = 8.0
                    p.update()

        elif mode == "scrl_seam":
            # Dispone le foto in modo fluido anche a cavallo tra più frame
            if self.scene.num_frames < 2:
                self.spin_frames.setValue(max(2, math.ceil(n / 2)))
                total_w = float(self.scene.sceneRect().width())
                avail_w = total_w - 2 * margin

            step_x = avail_w / n
            for i, p in enumerate(photos):
                w = min(self.scene.frame_w * 0.75, step_x * 1.15)
                h = avail_h * random.uniform(0.55, 0.82)
                x = margin + i * step_x
                y = margin + (avail_h - h) * (0.15 if i % 2 == 0 else 0.80)
                p.setPos(x, y)
                p.set_cell_size(w, h)
                p.setRotation(0)

        self.scene.update()

    def shuffle_canvas_photos(self):
        """Rimescola l'ordine delle foto mantenendo esattamente le posizioni e dimensioni correnti."""
        photos = self.get_canvas_photos()
        if len(photos) < 2:
            return

        transforms = [
            (p.pos(), p.cell_w, p.cell_h, p.rotation(), p.zValue())
            for p in photos
        ]
        random.shuffle(transforms)
        for p, (pos, w, h, rot, z) in zip(photos, transforms):
            p.setPos(pos)
            p.set_cell_size(w, h)
            p.setRotation(rot)
            p.setZValue(z)
        self.scene.update()

    def swap_two_selected_photos(self):
        selected = [it for it in self.scene.selectedItems() if isinstance(it, PhotoItem)]
        if len(selected) != 2:
            QMessageBox.information(
                self,
                "Scambia 2 Foto",
                "Seleziona esattamente 2 foto sulla tela (tieni premuto Shift o Ctrl mentre clicchi sulla seconda foto) per scambiarle di posto."
            )
            return

        p1, p2 = selected[0], selected[1]
        pos1, w1, h1, rot1, z1 = p1.pos(), p1.cell_w, p1.cell_h, p1.rotation(), p1.zValue()
        pos2, w2, h2, rot2, z2 = p2.pos(), p2.cell_w, p2.cell_h, p2.rotation(), p2.zValue()

        p1.setPos(pos2)
        p1.set_cell_size(w2, h2)
        p1.setRotation(rot2)
        p1.setZValue(z2)

        p2.setPos(pos1)
        p2.set_cell_size(w1, h1)
        p2.setRotation(rot1)
        p2.setZValue(z1)
        self.scene.update()

    # ================= INSPECTOR & CONTROLLI FOTO SINGOLA =================
    def _get_primary_selected(self) -> Optional[PhotoItem]:
        selected = [it for it in self.scene.selectedItems() if isinstance(it, PhotoItem)]
        return selected[0] if selected else None

    def _on_selection_changed(self):
        item = self._get_primary_selected()
        self._sync_inspector_from_item(item)

    def _sync_inspector_from_item(self, item: Optional[PhotoItem]):
        self._updating_inspector = True
        if item is None:
            self.lbl_selection_info.setText("Nessuna foto selezionata.\nClicca su una foto nella tela.")
        else:
            name = os.path.basename(item.image_path)
            self.lbl_selection_info.setText(
                f"File: {name}\nCella: {int(item.cell_w)}×{int(item.cell_h)} px"
            )
            self.slider_inner_zoom.setValue(int(item.inner_zoom * 100))
            self.slider_pan_x.setValue(int(item.pan_x * 100))
            self.slider_pan_y.setValue(int(item.pan_y * 100))
            self.slider_rotation.setValue(int(item.rotation()))
            self.slider_radius.setValue(int(item.border_radius))
            self.slider_border.setValue(int(item.border_width))
        self._updating_inspector = False

    def _on_inspector_changed(self):
        if self._updating_inspector:
            return
        item = self._get_primary_selected()
        if not item:
            return

        item.inner_zoom = self.slider_inner_zoom.value() / 100.0
        item.pan_x = self.slider_pan_x.value() / 100.0
        item.pan_y = self.slider_pan_y.value() / 100.0
        item.setRotation(float(self.slider_rotation.value()))
        item.border_radius = float(self.slider_radius.value())
        item.border_width = float(self.slider_border.value())
        item.update()

    def _rotate_selected_by(self, delta_deg: float):
        item = self._get_primary_selected()
        if item:
            new_angle = ((item.rotation() + delta_deg + 180) % 360) - 180
            item.setRotation(new_angle)
            self._sync_inspector_from_item(item)

    def _set_selected_rotation(self, angle: float):
        item = self._get_primary_selected()
        if item:
            item.setRotation(angle)
            self._sync_inspector_from_item(item)

    def _pick_photo_border_color(self):
        item = self._get_primary_selected()
        initial = item.border_color if item else QColor("#FFFFFF")
        col = QColorDialog.getColor(initial, self, "Colore Bordo Foto")
        if col.isValid():
            for sel in [it for it in self.scene.selectedItems() if isinstance(it, PhotoItem)]:
                sel.border_color = col
                sel.update()

    def _apply_style_to_all_photos(self):
        radius = float(self.slider_radius.value())
        border_w = float(self.slider_border.value())
        primary = self._get_primary_selected()
        border_col = primary.border_color if primary else QColor("#FFFFFF")
        for p in self.get_canvas_photos():
            p.border_radius = radius
            p.border_width = border_w
            p.border_color = border_col
            p.update()

    def _restore_selected_original_ratio(self):
        for sel in [it for it in self.scene.selectedItems() if isinstance(it, PhotoItem)]:
            sel.reset_aspect_to_original()
        self._sync_inspector_from_item(self._get_primary_selected())

    def _bring_to_front(self):
        item = self._get_primary_selected()
        if item:
            max_z = max([it.zValue() for it in self.get_canvas_photos()], default=0.0)
            item.setZValue(max_z + 1.0)

    def _send_to_back(self):
        item = self._get_primary_selected()
        if item:
            min_z = min([it.zValue() for it in self.get_canvas_photos()], default=0.0)
            item.setZValue(min_z - 1.0)

    def _duplicate_selected(self):
        item = self._get_primary_selected()
        if item:
            dup = self._spawn_photo_item(item.image_path, item.pil_image)
            dup.set_cell_size(item.cell_w, item.cell_h)
            dup.setPos(item.pos() + QPointF(30, 30))
            dup.setRotation(item.rotation())
            dup.border_radius = item.border_radius
            dup.border_width = item.border_width
            dup.border_color = item.border_color
            self.scene.clearSelection()
            dup.setSelected(True)

    def _delete_selected(self):
        for sel in [it for it in self.scene.selectedItems() if isinstance(it, PhotoItem)]:
            self.scene.removeItem(sel)

    def keyPressEvent(self, event):
        if event.key() in (Qt.Key.Key_Delete, Qt.Key.Key_Backspace):
            self._delete_selected()
        super().keyPressEvent(event)

    def _show_canvas_context_menu(self, pos):
        menu = QMenu(self)
        act_front = QAction("Porta in Primo Piano", self)
        act_front.triggered.connect(self._bring_to_front)
        act_back = QAction("Sposta sullo Sfondo", self)
        act_back.triggered.connect(self._send_to_back)
        act_swap = QAction("Scambia 2 Foto Selezionate", self)
        act_swap.triggered.connect(self.swap_two_selected_photos)
        act_orig = QAction("Proporzioni Originali Foto", self)
        act_orig.triggered.connect(self._restore_selected_original_ratio)
        act_dup = QAction("Duplica", self)
        act_dup.triggered.connect(self._duplicate_selected)
        act_del = QAction("Elimina", self)
        act_del.triggered.connect(self._delete_selected)

        menu.addAction(act_front)
        menu.addAction(act_back)
        menu.addSeparator()
        menu.addAction(act_swap)
        menu.addAction(act_orig)
        menu.addAction(act_dup)
        menu.addSeparator()
        menu.addAction(act_del)
        menu.exec(self.view.mapToGlobal(pos))

    # ================= ESPORTAZIONE AD ALTA RISOLUZIONE =================
    def _get_export_scale(self) -> int:
        return 2 if self.combo_quality.currentIndex() == 1 else 1

    def export_full_collage(self):
        scale = self._get_export_scale()
        out_w = int(self.scene.sceneRect().width() * scale)
        out_h = int(self.scene.sceneRect().height() * scale)

        path, _ = QFileDialog.getSaveFileName(
            self,
            f"Salva Collage ({out_w}×{out_h} px)",
            f"collage_3_4_{out_w}x{out_h}.png",
            "PNG Alta Qualità (*.png);;JPEG (*.jpg *.jpeg)"
        )
        if not path:
            return

        self.scene.is_exporting = True
        img = QImage(out_w, out_h, QImage.Format.Format_ARGB32)
        img.fill(self.scene.bg_color)

        painter = QPainter(img)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, True)
        self.scene.render(painter, QRectF(0, 0, out_w, out_h), self.scene.sceneRect())
        painter.end()
        self.scene.is_exporting = False
        self.scene.update()

        img.save(path, quality=98)
        QMessageBox.information(
            self,
            "Esportazione Completata",
            f"Collage salvato con successo in:\n{path}\nRisoluzione: {out_w}×{out_h} px"
        )

    def export_split_frames(self):
        folder = QFileDialog.getExistingDirectory(self, "Scegli Cartella dove salvare i singoli Frame")
        if not folder:
            return

        scale = self._get_export_scale()
        fw = self.scene.frame_w
        fh = self.scene.frame_h
        out_w = int(fw * scale)
        out_h = int(fh * scale)

        self.scene.is_exporting = True
        saved_files = []
        for i in range(self.scene.num_frames):
            img = QImage(out_w, out_h, QImage.Format.Format_ARGB32)
            img.fill(self.scene.bg_color)
            painter = QPainter(img)
            painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
            painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, True)

            source_rect = QRectF(i * fw, 0, fw, fh)
            self.scene.render(painter, QRectF(0, 0, out_w, out_h), source_rect)
            painter.end()

            file_path = os.path.join(folder, f"frame_{i + 1:02d}.png")
            img.save(file_path, quality=98)
            saved_files.append(file_path)

        self.scene.is_exporting = False
        self.scene.update()

        QMessageBox.information(
            self,
            "Frame Esportati",
            f"Esportati {len(saved_files)} frame ({out_w}×{out_h} px ciascuno) nella cartella:\n{folder}"
        )


if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec())