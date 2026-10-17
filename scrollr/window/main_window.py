"""Finestra principale di ScrolleR Studio."""
import random
from typing import List, Optional, Tuple

from PyQt6.QtCore import Qt, QTimer
from PyQt6.QtGui import QColor
from PyQt6.QtWidgets import QMainWindow, QColorDialog

from scrollr.canvas.scene import CollageScene
from scrollr.canvas.view import CanvasView
from scrollr.dialogs import BackgroundDialog
from scrollr.icons import app_icon
from scrollr.imaging import image_paths_from_mime
from scrollr.theme import build_stylesheet
from scrollr.window.export import ExportMixin
from scrollr.window.history import HistoryMixin
from scrollr.window.inspector import InspectorMixin
from scrollr.window.layouts import LayoutMixin
from scrollr.window.library import LibraryMixin
from scrollr.window.pages import PagesMixin
from scrollr.window.panels import PanelsMixin
from scrollr.window.project import ProjectMixin
from scrollr.window.text import TextMixin
from scrollr.window.ui import UiMixin


class MainWindow(UiMixin, PanelsMixin, LibraryMixin, LayoutMixin, InspectorMixin, TextMixin,
                 PagesMixin, HistoryMixin, ProjectMixin, ExportMixin, QMainWindow):
    """Finestra principale. Le funzioni sono divise nei mixin del pacchetto window."""

    ASPECT_RATIOS = {
        "3:4 verticale (1080×1440)": (1080, 1440),
        "4:3 orizzontale (1440×1080)": (1440, 1080),
        "4:5 ritratto Instagram (1080×1350)": (1080, 1350),
        "1:1 quadrato (1080×1080)": (1080, 1080),
        "9:16 storia (1080×1920)": (1080, 1920),
        "16:9 panoramico (1920×1080)": (1920, 1080),
        "2:3 foto verticale (1080×1620)": (1080, 1620),
        "3:2 foto orizzontale (1620×1080)": (1620, 1080),
        "Personalizzato": None,
    }
    LAYOUTS = [
        ("grid", "Griglia", "Righe e colonne adattate al formato della pagina"),
        ("mosaic", "Mosaico", "Una foto grande in evidenza e le altre in griglia"),
        ("strips_h", "Righe", "Una foto per riga, a tutta larghezza"),
        ("strips_v", "Colonne", "Una foto per colonna, a tutta altezza"),
        ("scatter", "Polaroid", "Foto sparse e leggermente inclinate, con bordo bianco"),
        ("scrl_seam", "A cavallo", "Foto che attraversano le giunzioni tra le pagine del carosello"),
    ]
    MOSAIC_STYLES = [
        ("auto", "Automatico", "Grande in alto sulle pagine verticali, a sinistra su quelle orizzontali"),
        ("top", "Grande in alto", "La prima foto in alto, le altre sotto"),
        ("bottom", "Grande in basso", "La prima foto in basso, le altre sopra"),
        ("left", "Grande a sinistra", "La prima foto a sinistra, le altre a destra"),
        ("right", "Grande a destra", "La prima foto a destra, le altre a sinistra"),
        ("center", "Grande al centro", "La prima foto al centro, le altre divise ai due lati"),
        ("two", "Due grandi", "Le prime due foto grandi affiancate, le altre in griglia"),
        ("masonry", "Muratura", "Colonne con foto di altezze diverse, sfalsate (stile Pinterest)"),
    ]
    HISTORY_LIMIT = 100

    def __init__(self):
        super().__init__()
        self.resize(1520, 940)
        self.setMinimumSize(1100, 680)
        self.setAcceptDrops(True)
        self.setWindowIcon(app_icon())

        self.loaded_library: List[str] = []
        self.current_layout_mode = "grid"  # "grid", "mosaic", "strips_h", "strips_v", "scatter", "scrl_seam"
        self.mosaic_style = "auto"  # chiave di MOSAIC_STYLES
        self._layout_seed = random.randrange(1 << 30)
        # Pagine aggiunte in automatico da "A cavallo": (pagine di prima, pagine impostate dal layout)
        self._seam_added_frames: Optional[Tuple[int, int]] = None
        self._updating_inspector = False
        self._restoring = False
        self.project_path: Optional[str] = None
        self._style_clipboard: Optional[dict] = None   # Stile copiato con "Copia stile"
        self._canvas_paths: set = set()                # Foto già sulla tela (segno nella libreria)

        # Cronologia Annulla/Ripeti (snapshot dello stato completo)
        self._history: List[dict] = []
        self._history_index = -1
        self._saved_snapshot: Optional[dict] = None
        self._commit_timer = QTimer(self)
        self._commit_timer.setSingleShot(True)
        self._commit_timer.setInterval(400)
        self._commit_timer.timeout.connect(self._commit_history)

        # Aggiornamento ritardato per le misure personalizzate (evita relayout a ogni cifra)
        self._custom_ratio_timer = QTimer(self)
        self._custom_ratio_timer.setSingleShot(True)
        self._custom_ratio_timer.setInterval(350)
        self._custom_ratio_timer.timeout.connect(self._apply_custom_ratio)

        self.scene = CollageScene(self)
        self.scene.selectionChanged.connect(self._on_selection_changed)
        self.view = CanvasView(self.scene, self)
        self.view.files_dropped.connect(self.load_images_from_paths)
        self.view.zoom_changed.connect(self._on_zoom_changed)
        self.view.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.view.customContextMenuRequested.connect(self._show_canvas_context_menu)

        # Salvataggio automatico ogni minuto, per recuperare il lavoro dopo una chiusura improvvisa
        self._autosave_timer = QTimer(self)
        self._autosave_timer.setInterval(60_000)
        self._autosave_timer.timeout.connect(self._autosave)
        self._autosave_timer.start()

        self._apply_theme()
        self._build_ui()
        self._build_status_bar()
        self._build_actions()
        self._update_library_ui()
        self._sync_layout_tiles()
        self._sync_inspector_from_item(None)
        self._commit_history()
        self._saved_snapshot = self._history[-1]
        self._update_title()
        # La vista ha le dimensioni reali solo dopo show(): adattamento al primo giro dell'event loop
        QTimer.singleShot(0, self.fit_canvas_in_view)

    def _apply_theme(self):
        self.setStyleSheet(build_stylesheet())

    # ================= GESTIONE CANVAS E FORMATO (3:4, ecc.) =================
    def _on_aspect_ratio_changed(self):
        label = self.combo_ratio.currentText()
        dims = self.ASPECT_RATIOS.get(label)
        custom = dims is None
        self.custom_size_box.setVisible(custom)
        if custom:
            dims = (self.spin_custom_w.value(), self.spin_custom_h.value())
        self._set_frame_size(*dims)

    def _apply_custom_ratio(self):
        if self.ASPECT_RATIOS.get(self.combo_ratio.currentText()) is None:
            self._set_frame_size(self.spin_custom_w.value(), self.spin_custom_h.value())

    def _set_frame_size(self, w: int, h: int):
        if (w, h) == (self.scene.frame_w, self.scene.frame_h):
            return
        self.scene.frame_w, self.scene.frame_h = w, h
        self.scene.update_canvas_rect()
        self._relayout_keep()
        self.fit_canvas_in_view()
        self._schedule_commit()

    def _on_frames_changed(self, value: int):
        self._seam_added_frames = None  # Scelta manuale dell'utente: da ora vale la sua
        self.scene.num_frames = value
        self.scene.update_canvas_rect()
        self._relayout_keep()
        self.fit_canvas_in_view()
        self._schedule_commit()

    def _pick_bg_color(self):
        col = QColorDialog.getColor(self.scene.bg_color, self, "Colore di sfondo della tela")
        if col.isValid():
            self.scene.bg_color = col
            self._refresh_bg_swatches()
            self.scene.update()
            self._schedule_commit()

    def _open_background_dialog(self):
        before = self._snapshot()["canvas"]
        BackgroundDialog(self).exec()
        if self._snapshot()["canvas"] != before:
            self._schedule_commit()

    def _apply_background(self, mode: str, color: QColor, color2: QColor, direction: str,
                          blur_path: str, blur_amount: int, dim: int):
        sc = self.scene
        sc.bg_mode = mode
        sc.bg_color = QColor(color)
        sc.bg_color2 = QColor(color2)
        sc.bg_direction = direction
        sc.bg_blur_path = blur_path if mode == "blur" else (sc.bg_blur_path or "")
        sc.bg_blur_amount = int(blur_amount)
        sc.bg_dim = int(dim)
        self._refresh_bg_swatches()
        sc.update()

    def _default_blur_photo(self) -> str:
        """Foto proposta per lo sfondo sfocato: quella selezionata, altrimenti la prima della tela o della libreria."""
        sel = self._get_primary_selected()
        if sel is not None:
            return sel.image_path
        photos = self.get_canvas_photos()
        if photos:
            return photos[0].image_path
        return self.loaded_library[0] if self.loaded_library else ""

    def _toggle_guides(self, checked: bool):
        self.scene.show_guides = checked
        self.scene.update()

    def _toggle_snap(self, checked: bool):
        for item in self.get_canvas_photos():
            item.snap_enabled = checked

    def fit_canvas_in_view(self):
        # Spazio extra in alto per le etichette delle pagine
        self.view.fit_to(self.scene.canvas_rect().adjusted(-70, -110, 70, 70))

    def _zoom_actual_size(self):
        scale = self.view.current_scale()
        if scale > 0:
            self.view.zoom_by(1.0 / scale, False)

    def _on_zoom_changed(self, scale: float):
        self.lbl_zoom.setText(f"{round(scale * 100)}%")
        self._update_doc_tab()
        for p in self.get_canvas_photos():
            p.view_scale_changed()

    # ================= TRASCINAMENTO FILE SULLA FINESTRA =================
    def dragEnterEvent(self, event):
        if event.mimeData().hasUrls():
            event.acceptProposedAction()

    def dropEvent(self, event):
        paths = image_paths_from_mime(event.mimeData())
        if paths:
            event.acceptProposedAction()
            self.load_images_from_paths(paths)
