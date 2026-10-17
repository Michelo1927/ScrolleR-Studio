"""Pannello sinistro (libreria, layout, pagina) e Inspector."""
from typing import Dict, List, Optional, Tuple

from PyQt6.QtCore import Qt, QSize
from PyQt6.QtGui import QColor
from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QPushButton, QLabel, QComboBox, QSlider, QListWidget,
    QGridLayout, QToolButton, QButtonGroup, QStackedWidget, QListView, QSizePolicy, QPlainTextEdit,
    QFontComboBox
)

from scrollr.icons import icon_pixmap, make_icon, swatch_icon
from scrollr.theme import THEME
from scrollr.widgets import DropZone, LibraryCheckDelegate, ToggleSwitch


class PanelsMixin:
    """Pannello sinistro (libreria, layout, pagina) e Inspector."""

    def _build_left_panel(self) -> QWidget:
        panel = QWidget()
        lay = QVBoxLayout(panel)
        lay.setContentsMargins(12, 10, 12, 12)
        lay.setSpacing(8)

        # --- Foto ---
        self.lbl_library_count = self._label("", "Hint")
        self._section_header(lay, "Foto", self.lbl_library_count)

        lay.addWidget(self._button("Aggiungi foto", self.open_file_dialog, "plus",
                                   tooltip="Ctrl+O — puoi anche trascinarle sulla tela"))

        self.library_stack = QStackedWidget()
        drop = DropZone()
        drop.clicked.connect(self.open_file_dialog)
        self.library_stack.addWidget(drop)

        self.list_library = QListWidget()
        # Griglia di miniature riordinabile trascinandole
        self.list_library.setViewMode(QListView.ViewMode.ListMode)
        self.list_library.setFlow(QListView.Flow.LeftToRight)
        self.list_library.setWrapping(True)
        self.list_library.setIconSize(QSize(80, 80))
        self.list_library.setGridSize(QSize(86, 86))
        self.list_library.setResizeMode(QListView.ResizeMode.Adjust)
        self.list_library.setUniformItemSizes(True)
        self.list_library.setDragDropMode(QListView.DragDropMode.InternalMove)
        self.list_library.setDefaultDropAction(Qt.DropAction.MoveAction)
        self.list_library.model().rowsMoved.connect(self._on_library_reordered)
        # Un clic seleziona/deseleziona la foto (senza dover tenere premuto Ctrl)
        self.list_library.setSelectionMode(QListWidget.SelectionMode.MultiSelection)
        self.list_library.setItemDelegate(LibraryCheckDelegate(self.list_library, lambda path: path in self._canvas_paths))
        self.list_library.setMinimumHeight(100)
        self.list_library.setToolTip("Clic per scegliere le foto (di nuovo per toglierle),\n"
                                     "poi «Metti le selezionate».\nTrascina una miniatura per cambiare l'ordine.\n"
                                     "Clic destro per altre opzioni.")
        self.list_library.itemSelectionChanged.connect(self._update_library_selection_ui)
        self.list_library.itemDoubleClicked.connect(self._on_library_item_double_clicked)
        self.list_library.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.list_library.customContextMenuRequested.connect(self._show_library_context_menu)
        self.library_stack.addWidget(self.list_library)
        lay.addWidget(self.library_stack, 1)

        sel_row = QHBoxLayout()
        sel_row.setSpacing(6)
        self.lbl_library_sel = self._label("Clicca le foto per sceglierle", "Hint")
        sel_row.addWidget(self.lbl_library_sel, 1)
        self.btn_library_sel_all = self._button("Tutte", self.list_library.selectAll, obj="Ghost",
                                                tooltip="Seleziona tutte le foto della libreria")
        self.btn_library_sel_none = self._button("Nessuna", self.list_library.clearSelection, obj="Ghost",
                                                 tooltip="Togli la selezione")
        sel_row.addWidget(self.btn_library_sel_all)
        sel_row.addWidget(self.btn_library_sel_none)
        self.library_sel_box = QWidget()
        self.library_sel_box.setLayout(sel_row)
        sel_row.setContentsMargins(0, 0, 0, 0)
        self.library_sel_box.setVisible(False)
        lay.addWidget(self.library_sel_box)

        # Azioni sulle foto selezionate: compaiono solo quando ce n'è almeno una
        self.library_actions_box = QWidget()
        act_row = QVBoxLayout(self.library_actions_box)
        act_row.setContentsMargins(0, 0, 0, 0)
        act_row.setSpacing(4)
        self.btn_library_add = self._button("Aggiungi alla tela", self._add_selected_library_to_canvas, "plus",
                                            tooltip="Aggiunge le foto selezionate a quelle già sulla tela e ridispone tutto")
        self.btn_library_remove = self._button("Rimuovi dalla libreria", self._remove_selected_from_library, "trash",
                                               "Danger", tooltip="Toglie le foto selezionate dalla libreria\n"
                                                                 "(quelle già sulla tela restano)")
        act_row.addWidget(self.btn_library_add)
        act_row.addWidget(self.btn_library_remove)
        self.library_actions_box.setVisible(False)
        lay.addWidget(self.library_actions_box)

        lib_btns = QHBoxLayout()
        lib_btns.setSpacing(6)
        self.btn_add_all = self._button("Metti tutte sulla tela", self.add_all_library_to_canvas, obj="Ghost")
        self.btn_clear_canvas = self._button("Svuota tela", self.clear_canvas_photos, obj="Ghost")
        lib_btns.addWidget(self.btn_add_all)
        lib_btns.addWidget(self.btn_clear_canvas)
        lay.addLayout(lib_btns)

        lay.addSpacing(2)
        lay.addWidget(self._divider())
        lay.addSpacing(2)

        # --- Disposizione ---
        self._section_header(lay, "Disposizione")
        tiles = QGridLayout()
        tiles.setSpacing(4)
        self.layout_group = QButtonGroup(self)
        self.layout_group.setExclusive(True)
        self.layout_tiles: Dict[str, QToolButton] = {}
        for i, (mode, text, tip) in enumerate(self.LAYOUTS):
            tile = QToolButton()
            tile.setObjectName("LayoutTile")
            tile.setText(text)
            tile.setToolTip(tip)
            icon_name = "seam" if mode == "scrl_seam" else mode
            tile.setIcon(make_icon(icon_name, THEME["muted"], 22, on_color=THEME["text"]))
            tile.setIconSize(QSize(22, 22))
            tile.setToolButtonStyle(Qt.ToolButtonStyle.ToolButtonTextUnderIcon)
            tile.setCheckable(True)
            tile.setCursor(Qt.CursorShape.PointingHandCursor)
            tile.setFixedHeight(50)
            tile.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)
            tile.clicked.connect(lambda _checked=False, m=mode: self._on_layout_button(m))
            self.layout_group.addButton(tile)
            self.layout_tiles[mode] = tile
            tiles.addWidget(tile, i // 3, i % 3)
        lay.addLayout(tiles)

        self.mosaic_style_box = QWidget()
        ms = QHBoxLayout(self.mosaic_style_box)
        ms.setContentsMargins(0, 2, 0, 0)
        ms.setSpacing(8)
        ms.addWidget(self._label("Stile mosaico", "FieldLabel"))
        self.combo_mosaic = QComboBox()
        self.combo_mosaic.setIconSize(QSize(18, 18))
        for key, text, tip in self.MOSAIC_STYLES:
            self.combo_mosaic.addItem(make_icon("mosaic_" + key, THEME["text"], 18), text, key)
            self.combo_mosaic.setItemData(self.combo_mosaic.count() - 1, tip, Qt.ItemDataRole.ToolTipRole)
        self.combo_mosaic.setToolTip("Dove va la foto in evidenza (la prima) e come si dispongono le altre")
        self.combo_mosaic.currentIndexChanged.connect(self._on_mosaic_style_changed)
        ms.addWidget(self.combo_mosaic, 1)
        self.mosaic_style_box.setVisible(False)
        lay.addWidget(self.mosaic_style_box)

        self.chk_per_frame = ToggleSwitch("Una disposizione per ogni pagina")
        self.chk_per_frame.setChecked(True)
        self.chk_per_frame.setToolTip(
            "Con più pagine, distribuisce le foto tra le pagine senza tagliarle sulle giunzioni.\n"
            "Spegni per disporre le foto su tutta la tela continua.\n"
            "(Il layout A cavallo usa sempre la tela continua.)"
        )
        self.chk_per_frame.toggled.connect(self._relayout_keep)
        lay.addWidget(self.chk_per_frame)

        lay.addSpacing(4)
        self.slider_gap = self._make_slider(lay, "Spaziatura", 0, 80, 16, " px", resettable=True)
        self.slider_gap.valueChanged.connect(self._relayout_keep)
        self.slider_margin = self._make_slider(lay, "Margine", 0, 120, 24, " px", resettable=True)
        self.slider_margin.valueChanged.connect(self._relayout_keep)

        return panel

    def _tab_page(self) -> Tuple[QWidget, QVBoxLayout]:
        page = QWidget()
        lay = QVBoxLayout(page)
        lay.setContentsMargins(0, 8, 0, 0)
        lay.setSpacing(6)
        return page, lay

    def _seg_tabs(self, tabs: List[Tuple[str, str]], stack: QStackedWidget) -> QWidget:
        """Schede a segmenti (come i pannelli a schede di Photoshop) che cambiano la pagina di `stack`."""
        bar = QWidget()
        hl = QHBoxLayout(bar)
        hl.setContentsMargins(0, 0, 0, 0)
        hl.setSpacing(0)
        group = QButtonGroup(bar)
        group.setExclusive(True)
        for i, (name, tip) in enumerate(tabs):
            b = QToolButton()
            b.setObjectName("SegTab")
            b.setText(name)
            b.setToolTip(tip)
            b.setCheckable(True)
            b.setChecked(i == 0)
            b.setCursor(Qt.CursorShape.PointingHandCursor)
            b.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)
            b.setFixedHeight(26)
            b.clicked.connect(lambda _c=False, k=i: stack.setCurrentIndex(k))
            group.addButton(b)
            hl.addWidget(b)
        bar._group = group  # Mantiene vivo il gruppo
        # Se la pagina cambia da codice (es. doppio clic su un testo) la scheda giusta si accende
        stack.currentChanged.connect(lambda i: group.buttons()[i].setChecked(True) if 0 <= i < len(group.buttons()) else None)
        return bar

    def _soft_toggle(self, text: str, tooltip: str, slot, icon: Optional[str] = None) -> QToolButton:
        btn = QToolButton()
        btn.setObjectName("SoftButton")
        btn.setText(text)
        btn.setToolTip(tooltip)
        btn.setCheckable(True)
        btn.setCursor(Qt.CursorShape.PointingHandCursor)
        btn.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)
        if icon:
            btn.setIcon(make_icon(icon, THEME["text"]))
            btn.setIconSize(QSize(16, 16))
            btn.setToolButtonStyle(Qt.ToolButtonStyle.ToolButtonTextBesideIcon)
        else:
            btn.setToolButtonStyle(Qt.ToolButtonStyle.ToolButtonTextOnly)
        btn.clicked.connect(slot)
        return btn

    def _build_align_block(self, lay: QVBoxLayout):
        """Allinea / distribuisci / blocca: usato sia per le foto sia per i testi."""
        self._section_header(lay, "Allinea")
        hint = self._label("", "Hint")
        hint.setWordWrap(True)
        lay.addWidget(hint)
        self._align_hints.append(hint)
        for caption, buttons in (
            ("In orizzontale", [("A sinistra", "left"), ("Al centro", "hcenter"), ("A destra", "right")]),
            ("In verticale", [("In alto", "top"), ("Al centro", "vcenter"), ("In basso", "bottom")]),
        ):
            lay.addWidget(self._label(caption))
            row = QHBoxLayout()
            row.setSpacing(4)
            for text, how in buttons:
                b = self._button(text, lambda _c=False, h=how: self._align_selected(h), obj="Ghost")
                b.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)
                row.addWidget(b)
            lay.addLayout(row)
        self._section_header(lay, "Distribuisci a spazi uguali")
        row = QHBoxLayout()
        row.setSpacing(4)
        for text, horiz in (("In orizzontale", True), ("In verticale", False)):
            b = self._button(text, lambda _c=False, h=horiz: self._distribute_selected(h), obj="Ghost",
                             tooltip="Stessa distanza tra 3 o più elementi selezionati")
            b.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)
            self._distribute_buttons.append(b)
            row.addWidget(b)
        lay.addLayout(row)
        lay.addSpacing(4)
        lock = ToggleSwitch("Blocca posizione e dimensioni")
        lock.setToolTip("L'elemento non si sposta né si ridimensiona per sbaglio (Ctrl+L).\n"
                        "Puoi sempre modificarne colori e stile.")
        lock.toggled.connect(self._set_lock_selected)
        lay.addWidget(lock)
        self._lock_switches.append(lock)

    def _build_inspector(self) -> QWidget:
        panel = QWidget()
        outer = QVBoxLayout(panel)
        outer.setContentsMargins(12, 6, 12, 6)
        outer.setSpacing(0)
        self._align_hints: List[QLabel] = []
        self._distribute_buttons: List[QPushButton] = []
        self._lock_switches: List[ToggleSwitch] = []

        self.insp_stack = QStackedWidget()
        outer.addWidget(self.insp_stack)

        # Pagina 0: nessuna selezione
        empty = QWidget()
        el = QVBoxLayout(empty)
        el.setContentsMargins(4, 40, 4, 0)
        el.setSpacing(10)
        empty_icon = QLabel()
        empty_icon.setPixmap(icon_pixmap("image", THEME["faint"], 40))
        empty_icon.setAlignment(Qt.AlignmentFlag.AlignHCenter)
        el.addWidget(empty_icon)
        title = self._label("Nessuna foto selezionata", "EmptyTitle")
        title.setAlignment(Qt.AlignmentFlag.AlignHCenter)
        el.addWidget(title)
        body = self._label("Clicca una foto o un testo sulla tela per modificarli.\n\n"
                           "Ctrl+clic per selezionarne più di uno: le modifiche valgono per tutti.", "Hint")
        body.setWordWrap(True)
        body.setAlignment(Qt.AlignmentFlag.AlignHCenter)
        el.addWidget(body)
        el.addStretch()
        self.insp_stack.addWidget(empty)

        # Pagina 1: foto
        self.insp_controls = QWidget()
        lay = QVBoxLayout(self.insp_controls)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(6)
        head = QHBoxLayout()
        head.setSpacing(12)
        self.lbl_selection_thumb = QLabel()
        self.lbl_selection_thumb.setFixedSize(40, 40)
        head.addWidget(self.lbl_selection_thumb)
        head_text = QVBoxLayout()
        head_text.setSpacing(2)
        self.lbl_selection_name = self._label("", "SelName")
        self.lbl_selection_info = self._label("", "Hint")
        self.lbl_selection_info.setWordWrap(True)
        head_text.addWidget(self.lbl_selection_name)
        head_text.addWidget(self.lbl_selection_info)
        head.addLayout(head_text, 1)
        lay.addLayout(head)

        self.photo_tabs = QStackedWidget()
        lay.addWidget(self._seg_tabs([
            ("Foto", "Riempimento, inquadratura, rotazione e specchio"),
            ("Colore", "Luminosità, contrasto, saturazione, calore, bianco e nero"),
            ("Stile", "Angoli, bordo, opacità, ombra, copia e incolla stile"),
            ("Disponi", "Allinea, distribuisci, blocca"),
        ], self.photo_tabs))
        lay.addWidget(self.photo_tabs)
        self.photo_tabs.addWidget(self._build_photo_tab_frame())
        self.photo_tabs.addWidget(self._build_photo_tab_color())
        self.photo_tabs.addWidget(self._build_photo_tab_style())
        page, pl = self._tab_page()
        self._build_align_block(pl)
        pl.addStretch()
        self.photo_tabs.addWidget(page)
        lay.addStretch()
        self.insp_stack.addWidget(self.insp_controls)

        # Pagina 2: testo
        self.insp_stack.addWidget(self._build_text_inspector())
        outer.addStretch()
        return panel

    def _build_photo_tab_frame(self) -> QWidget:
        page, lay = self._tab_page()
        self._section_header(lay, "Riempimento")
        fit_row = QHBoxLayout()
        fit_row.setSpacing(6)
        self.btn_fit_cover = self._soft_toggle("Riempi riquadro", "La foto riempie tutto il riquadro:\n"
                                               "i bordi in eccesso vengono tagliati", lambda: self._set_fit_mode("cover"), "fit_cover")
        self.btn_fit_contain = self._soft_toggle("Foto intera", "Mostra tutta la foto senza tagli:\n"
                                                 "attorno resta visibile lo sfondo", lambda: self._set_fit_mode("contain"), "fit_contain")
        fit_group = QButtonGroup(page)
        fit_group.setExclusive(True)
        for b in (self.btn_fit_cover, self.btn_fit_contain):
            fit_group.addButton(b)
            fit_row.addWidget(b)
        page._fit_group = fit_group
        lay.addLayout(fit_row)

        self._section_header(lay, "Inquadratura")
        self.slider_inner_zoom = self._make_slider(lay, "Zoom", 100, 400, 100, "%", resettable=True)
        self.slider_inner_zoom.valueChanged.connect(lambda v: self._on_inspector_slider("zoom", v))
        self.slider_pan_x = self._make_slider(lay, "Orizzontale", -100, 100, 0, signed=True, resettable=True)
        self.slider_pan_x.valueChanged.connect(lambda v: self._on_inspector_slider("pan_x", v))
        self.slider_pan_y = self._make_slider(lay, "Verticale", -100, 100, 0, signed=True, resettable=True)
        self.slider_pan_y.valueChanged.connect(lambda v: self._on_inspector_slider("pan_y", v))
        self.slider_inner_rot = self._make_slider(lay, "Ruota contenuto", -180, 180, 0, "°", signed=True, resettable=True)
        self.slider_inner_rot.setToolTip("Ruota la foto dentro il riquadro, senza ruotare il riquadro.\n"
                                         "Lo zoom si adatta da solo per non lasciare angoli vuoti.")
        self.slider_inner_rot.valueChanged.connect(lambda v: self._on_inspector_slider("inner_rotation", v))
        frame_btns = QHBoxLayout()
        frame_btns.setSpacing(6)
        frame_btns.addWidget(self._icon_button("reset", "Reimposta zoom, posizione e rotazione del contenuto (Ctrl+R):\n"
                                               "zoom al 100%, foto centrata e dritta nel riquadro",
                                               self._reset_selected_framing, "Reimposta", "SoftButton"))
        frame_btns.addWidget(self._icon_button("ratio", "Usa le proporzioni della foto:\n"
                                               "adatta il riquadro alle proporzioni originali dello scatto",
                                               self._restore_selected_original_ratio, "Proporzioni foto", "SoftButton"))
        lay.addLayout(frame_btns)

        self._section_header(lay, "Rotazione e specchio")
        self.slider_rotation = self._make_slider(lay, "Angolo", -180, 180, 0, "°", signed=True, resettable=True)
        self.slider_rotation.valueChanged.connect(lambda v: self._on_inspector_slider("rotation", v))
        flip_row = QHBoxLayout()
        flip_row.setSpacing(6)
        flip_row.addWidget(self._icon_button("flip_h", "Specchia la foto da sinistra a destra", lambda: self._flip_selected("h"),
                                             "Specchia orizz.", "SoftButton"))
        flip_row.addWidget(self._icon_button("flip_v", "Capovolgi la foto dall'alto in basso", lambda: self._flip_selected("v"),
                                             "Specchia vert.", "SoftButton"))
        lay.addLayout(flip_row)
        lay.addStretch()
        return page

    def _build_photo_tab_color(self) -> QWidget:
        page, lay = self._tab_page()
        self._section_header(lay, "Regolazioni")
        self.adjust_sliders: Dict[str, QSlider] = {}
        for key, title, tip in (
            ("brightness", "Luminosità", "Schiarisci (+) o scurisci (−) la foto"),
            ("contrast", "Contrasto", "Più (+) o meno (−) differenza tra chiari e scuri"),
            ("saturation", "Saturazione", "Colori più vivi (+) o più spenti (−)"),
            ("warmth", "Calore", "Toni più caldi, verso l'arancio (+), o più freddi, verso il blu (−)"),
        ):
            slider = self._make_slider(lay, title, -100, 100, 0, signed=True, resettable=True)
            slider.setToolTip(tip)
            slider.valueChanged.connect(lambda v, k=key: self._on_inspector_slider(k, v))
            self.adjust_sliders[key] = slider
        self.chk_bw = ToggleSwitch("Bianco e nero")
        self.chk_bw.setToolTip("Converte la foto in bianco e nero (con Calore ottieni un viraggio seppia o freddo)")
        self.chk_bw.toggled.connect(self._set_bw)
        lay.addWidget(self.chk_bw)
        row = QHBoxLayout()
        row.setSpacing(6)
        row.addWidget(self._icon_button("reset", "Riporta tutte le regolazioni colore a zero", self._reset_colors,
                                        "Reimposta colori", "SoftButton"))
        row.addWidget(self._button("Applica a tutte", self._apply_colors_to_all, obj="Ghost",
                                   tooltip="Copia queste regolazioni colore su tutte le foto della tela"))
        lay.addLayout(row)
        lay.addStretch()
        return page

    def _build_photo_tab_style(self) -> QWidget:
        page, lay = self._tab_page()
        self._section_header(lay, "Cornice")
        self.slider_radius = self._make_slider(lay, "Angoli arrotondati", 0, 200, 0, " px")
        self.slider_radius.valueChanged.connect(lambda v: self._on_inspector_slider("radius", v))
        self.slider_border = self._make_slider(lay, "Spessore bordo", 0, 40, 0, " px")
        self.slider_border.valueChanged.connect(lambda v: self._on_inspector_slider("border", v))
        self.btn_border_color = self._icon_button("plus", "Colore del bordo", self._pick_photo_border_color, "Colore bordo", "SoftButton")
        self.btn_border_color.setIcon(swatch_icon(QColor("#FFFFFF")))
        lay.addWidget(self.btn_border_color)

        self._section_header(lay, "Trasparenza e ombra")
        self.slider_opacity = self._make_slider(lay, "Opacità", 5, 100, 100, "%", resettable=True)
        self.slider_opacity.setToolTip("Rendi la foto trasparente (100% = piena)")
        self.slider_opacity.valueChanged.connect(lambda v: self._on_inspector_slider("opacity", v))
        self.slider_shadow = self._make_slider(lay, "Ombra", 0, 100, 0, "%", resettable=True)
        self.slider_shadow.setToolTip("Ombra morbida sotto la foto, per staccarla dallo sfondo")
        self.slider_shadow.valueChanged.connect(lambda v: self._on_inspector_slider("shadow", v))

        self._section_header(lay, "Copia lo stile su altre foto")
        row = QHBoxLayout()
        row.setSpacing(6)
        row.addWidget(self._icon_button("duplicate", "Copia angoli, bordo, opacità, ombra e colori di questa foto (Ctrl+Shift+C)",
                                        self._copy_style, "Copia stile", "SoftButton"))
        self.btn_paste_style = self._icon_button("plus", "Incolla lo stile copiato sulle foto selezionate (Ctrl+Shift+V)",
                                                 self._paste_style, "Incolla stile", "SoftButton")
        row.addWidget(self.btn_paste_style)
        lay.addLayout(row)
        lay.addWidget(self._button("Applica a tutte le foto", self._apply_style_to_all_photos, obj="Ghost",
                                   tooltip="Copia angoli, bordo, colore del bordo, opacità e ombra su tutte le foto della tela"))
        lay.addStretch()
        return page

    def _build_text_inspector(self) -> QWidget:
        page = QWidget()
        lay = QVBoxLayout(page)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(6)
        head = QHBoxLayout()
        head.setSpacing(12)
        icon = QLabel()
        icon.setPixmap(icon_pixmap("text", THEME["text"], 28))
        icon.setFixedSize(40, 40)
        icon.setAlignment(Qt.AlignmentFlag.AlignCenter)
        head.addWidget(icon)
        head_text = QVBoxLayout()
        head_text.setSpacing(2)
        self.lbl_text_title = self._label("Testo", "SelName")
        head_text.addWidget(self.lbl_text_title)
        sub = self._label("Doppio clic sul testo per scriverci", "Hint")
        sub.setWordWrap(True)
        head_text.addWidget(sub)
        head.addLayout(head_text, 1)
        lay.addLayout(head)

        self.text_tabs = QStackedWidget()
        lay.addWidget(self._seg_tabs([
            ("Testo", "Contenuto, carattere, colore"),
            ("Disponi", "Allinea, distribuisci, blocca"),
        ], self.text_tabs))
        lay.addWidget(self.text_tabs)

        tp, tl = self._tab_page()
        self.edit_text = QPlainTextEdit()
        self.edit_text.setPlaceholderText("Scrivi qui il testo… (Invio per andare a capo)")
        self.edit_text.setFixedHeight(72)
        self.edit_text.textChanged.connect(self._on_text_content_changed)
        tl.addWidget(self.edit_text)

        self._section_header(tl, "Carattere")
        self.combo_font = QFontComboBox()
        self.combo_font.setToolTip("Tipo di carattere")
        self.combo_font.currentFontChanged.connect(lambda f: self._on_text_prop("font", f.family()))
        tl.addWidget(self.combo_font)
        self.slider_text_size = self._make_slider(tl, "Dimensione", 12, 400, 72, " px")
        self.slider_text_size.valueChanged.connect(lambda v: self._on_text_prop("size", v))
        style_row = QHBoxLayout()
        style_row.setSpacing(6)
        self.btn_text_bold = self._soft_toggle("Grassetto", "Testo in grassetto", lambda c: self._on_text_prop("bold", c))
        self.btn_text_italic = self._soft_toggle("Corsivo", "Testo in corsivo", lambda c: self._on_text_prop("italic", c))
        style_row.addWidget(self.btn_text_bold)
        style_row.addWidget(self.btn_text_italic)
        tl.addLayout(style_row)
        tl.addWidget(self._label("Allineamento delle righe"))
        align_row = QHBoxLayout()
        align_row.setSpacing(4)
        self.text_align_buttons: Dict[str, QToolButton] = {}
        align_group = QButtonGroup(tp)
        align_group.setExclusive(True)
        for key, text in (("left", "Sinistra"), ("center", "Centro"), ("right", "Destra")):
            b = self._soft_toggle(text, f"Righe allineate a {text.lower()}", lambda _c=False, k=key: self._on_text_prop("align", k))
            align_group.addButton(b)
            align_row.addWidget(b)
            self.text_align_buttons[key] = b
        tp._align_group = align_group
        tl.addLayout(align_row)

        self._section_header(tl, "Colore ed effetti")
        self.btn_text_color = self._icon_button("plus", "Colore del testo", lambda: self._pick_text_color("color"),
                                                "Colore testo", "SoftButton")
        tl.addWidget(self.btn_text_color)
        self.chk_text_shadow = ToggleSwitch("Ombra dietro al testo")
        self.chk_text_shadow.setToolTip("Rende il testo leggibile anche sopra le foto")
        self.chk_text_shadow.toggled.connect(lambda c: self._on_text_prop("shadow", c))
        tl.addWidget(self.chk_text_shadow)
        box_row = QHBoxLayout()
        box_row.setSpacing(6)
        self.chk_text_box = ToggleSwitch("Etichetta")
        self.chk_text_box.setToolTip("Riquadro colorato dietro al testo")
        self.chk_text_box.toggled.connect(lambda c: self._on_text_prop("box", c))
        box_row.addWidget(self.chk_text_box)
        self.btn_box_color = self._icon_button("plus", "Colore e trasparenza dell'etichetta", lambda: self._pick_text_color("box"),
                                               "Colore etichetta", "SoftButton")
        box_row.addWidget(self.btn_box_color)
        tl.addLayout(box_row)
        self.slider_text_opacity = self._make_slider(tl, "Opacità", 5, 100, 100, "%", resettable=True)
        self.slider_text_opacity.valueChanged.connect(lambda v: self._on_text_prop("opacity", v))
        tl.addStretch()
        self.text_tabs.addWidget(tp)

        dp, dl = self._tab_page()
        self._build_align_block(dl)
        dl.addStretch()
        self.text_tabs.addWidget(dp)
        lay.addStretch()
        return page
