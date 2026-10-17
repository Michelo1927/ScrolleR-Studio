"""Costruzione dell'interfaccia: barre, strumenti, azioni e helper per i widget."""
import os
from typing import Dict, Optional

from PyQt6.QtCore import Qt, QRectF, QSize, QKeyCombination
from PyQt6.QtGui import QPixmap, QPainter, QPen, QColor, QAction, QIcon, QKeySequence
from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QPushButton, QLabel, QComboBox, QSpinBox, QSlider, QFrame,
    QMenu, QSplitter, QToolButton, QScrollArea, QAbstractSpinBox, QSizePolicy
)

from scrollr.icons import icon_pixmap, make_icon
from scrollr.theme import THEME


class UiMixin:
    """Costruzione dell'interfaccia: barre, strumenti, azioni e helper per i widget."""

    # ================= COSTRUZIONE INTERFACCIA =================
    @staticmethod
    def _label(text: str, obj: str = "FieldLabel") -> QLabel:
        lbl = QLabel(text)
        lbl.setObjectName(obj)
        return lbl

    @staticmethod
    def _vsep() -> QFrame:
        sep = QFrame()
        sep.setObjectName("VSep")
        sep.setFixedSize(1, 22)
        return sep

    @staticmethod
    def _divider() -> QFrame:
        div = QFrame()
        div.setObjectName("Divider")
        div.setFixedHeight(1)
        return div

    def _icon_button(self, icon: str, tooltip: str, slot, text: str = "", obj: str = "IconButton") -> QToolButton:
        btn = QToolButton()
        btn.setObjectName(obj)
        btn.setIcon(make_icon(icon, THEME["text"]))
        btn.setIconSize(QSize(18, 18))
        btn.setToolTip(tooltip)
        btn.setCursor(Qt.CursorShape.PointingHandCursor)
        if text:
            btn.setText(text)
            btn.setToolButtonStyle(Qt.ToolButtonStyle.ToolButtonTextBesideIcon)
        if obj == "SoftButton":
            btn.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)
        btn.clicked.connect(slot)
        return btn

    def _button(self, text: str, slot, icon: Optional[str] = None, obj: Optional[str] = None,
                tooltip: str = "") -> QPushButton:
        btn = QPushButton(text)
        if obj:
            btn.setObjectName(obj)
        if icon:
            color = THEME["accent_ink"] if obj == "Primary" else THEME["danger"] if obj == "Danger" else THEME["text"]
            btn.setIcon(make_icon(icon, color, 16))
            btn.setIconSize(QSize(16, 16))
        if tooltip:
            btn.setToolTip(tooltip)
        btn.setCursor(Qt.CursorShape.PointingHandCursor)
        btn.clicked.connect(slot)
        return btn

    def _section_header(self, layout, title: str, trailing: Optional[QWidget] = None):
        row = QHBoxLayout()
        row.setContentsMargins(0, 0, 0, 0)
        row.addWidget(self._label(title, "SectionTitle"))
        row.addStretch()
        if trailing is not None:
            row.addWidget(trailing)
        layout.addLayout(row)

    def _scroll_panel(self, content: QWidget, width: int) -> QScrollArea:
        scroll = QScrollArea()
        scroll.setObjectName("PanelScroll")
        scroll.setWidget(content)
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setFixedWidth(width)
        scroll.viewport().setAutoFillBackground(False)
        content.setObjectName("Panel")
        content.setAttribute(Qt.WidgetAttribute.WA_StyledBackground, True)
        return scroll

    @staticmethod
    def _styled(widget: QWidget, obj: str) -> QWidget:
        widget.setObjectName(obj)
        widget.setAttribute(Qt.WidgetAttribute.WA_StyledBackground, True)
        return widget

    def _dock(self, title: str, content: QWidget) -> QWidget:
        """Pannello agganciato con intestazione a scheda, come i pannelli di Photoshop."""
        dock = self._styled(QWidget(), "Dock")
        lay = QVBoxLayout(dock)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(0)
        header = self._styled(QWidget(), "DockHeader")
        header.setFixedHeight(28)
        hl = QHBoxLayout(header)
        hl.setContentsMargins(0, 0, 0, 0)
        hl.setSpacing(0)
        tab = self._label(title, "DockTab")
        tab.setFixedHeight(28)
        hl.addWidget(tab)
        hl.addStretch()
        lay.addWidget(header)
        lay.addWidget(content, 1)
        return dock

    def _build_tool_strip(self) -> QWidget:
        """
        Colonna strumenti a sinistra: tutte le azioni sulle foto della tela, ognuna con icona ED etichetta.
        I pulsanti che richiedono una selezione si spengono quando non servono (vedi _update_tool_states).
        """
        strip = self._styled(QWidget(), "ToolStrip")
        strip.setFixedWidth(76)
        lay = QVBoxLayout(strip)
        lay.setContentsMargins(4, 6, 4, 8)
        lay.setSpacing(1)
        groups = [
            ("Inserisci", [
                ("text", "Testo", "Aggiungi un testo sulla tela: titolo, didascalia, numero (Ctrl+T)", self.add_text),
            ]),
            ("Ordine", [
                ("shuffle", "Rimescola", "Cambia a caso quale foto va in quale posizione", self.shuffle_canvas_photos),
                ("swap", "Scambia", "Scambia di posto le 2 foto selezionate\n(Ctrl+clic per selezionare la seconda)",
                 self.swap_two_selected_photos),
            ]),
            ("Ruota", [
                ("rot_left", "90° sx", "Ruota la foto di 90° a sinistra", lambda: self._rotate_selected_by(-90)),
                ("rot_right", "90° dx", "Ruota la foto di 90° a destra", lambda: self._rotate_selected_by(90)),
                ("level", "Dritta", "Raddrizza la foto (angolo 0°)", lambda: self._set_selected_rotation(0)),
            ]),
            ("Livello", [
                ("front", "Davanti", "Porta la foto sopra le altre", self._bring_to_front),
                ("back", "Dietro", "Manda la foto sotto le altre", self._send_to_back),
            ]),
            ("Foto", [
                ("duplicate", "Duplica", "Crea una copia della foto (Ctrl+D)", self._duplicate_selected),
                ("trash", "Elimina", "Togli la foto dalla tela (Canc)", self._delete_selected),
            ]),
        ]
        self._tool_buttons: Dict[str, QToolButton] = {}
        for gi, (caption, items) in enumerate(groups):
            if gi:
                lay.addSpacing(3)
                sep = self._styled(QFrame(), "ToolSep")
                sep.setFixedHeight(1)
                lay.addWidget(sep)
                lay.addSpacing(2)
            cap = self._label(caption, "ToolCaption")
            cap.setAlignment(Qt.AlignmentFlag.AlignHCenter)
            lay.addWidget(cap)
            for icon, text, tip, slot in items:
                btn = self._icon_button(icon, tip, slot, text, obj="ToolButton")
                color = THEME["danger"] if icon == "trash" else THEME["text"]
                btn.setIcon(make_icon(icon, color, 18))
                btn.setToolButtonStyle(Qt.ToolButtonStyle.ToolButtonTextUnderIcon)
                if icon == "trash":
                    btn.setProperty("danger", True)
                btn.setFixedSize(66, 44)
                lay.addWidget(btn, 0, Qt.AlignmentFlag.AlignHCenter)
                self._tool_buttons[icon] = btn
        lay.addStretch()
        return strip

    def _update_tool_states(self):
        """Accende solo gli strumenti utilizzabili adesso, e spiega nella barra di stato cosa serve."""
        if not hasattr(self, "_tool_buttons"):
            return
        n_sel = len(self._selected_elements())
        n_photos_sel = len(self._selected_photos())
        n_canvas = len(self.get_canvas_photos())
        for icon, btn in self._tool_buttons.items():
            if icon == "text":
                btn.setEnabled(True)
            elif icon == "shuffle":
                btn.setEnabled(n_canvas >= 2)
            elif icon == "swap":
                btn.setEnabled(n_photos_sel == 2)
            else:
                btn.setEnabled(n_sel > 0)

    def _build_document_area(self) -> QWidget:
        """Finestra documento: scheda col nome del progetto e zoom sopra la tela."""
        area = self._styled(QWidget(), "DocArea")
        lay = QVBoxLayout(area)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(0)
        tabs = self._styled(QWidget(), "DocTabBar")
        tabs.setFixedHeight(28)
        tl = QHBoxLayout(tabs)
        tl.setContentsMargins(0, 0, 0, 0)
        tl.setSpacing(0)
        self.lbl_doc_tab = self._label("", "DocTab")
        self.lbl_doc_tab.setFixedHeight(28)
        tl.addWidget(self.lbl_doc_tab)
        tl.addStretch()
        lay.addWidget(tabs)
        lay.addWidget(self.view, 1)
        return area

    def _update_doc_tab(self):
        if not hasattr(self, "lbl_doc_tab"):
            return
        name = os.path.basename(self.project_path) if self.project_path else "Senza titolo"
        star = "*" if self._history and self._is_dirty() else ""
        zoom = round(self.view.current_scale() * 100)
        self.lbl_doc_tab.setText(f"{name} @ {zoom}% (RGB/8){star}")

    def _refresh_bg_swatches(self):
        """Il campione del pulsante Sfondo mostra il tipo di sfondo: colore, sfumatura o foto."""
        size = 16
        pm = QPixmap(size * 2, size * 2)
        pm.setDevicePixelRatio(2.0)
        pm.fill(Qt.GlobalColor.transparent)
        p = QPainter(pm)
        p.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        rect = QRectF(1.5, 1.5, size - 3, size - 3)
        self.scene.paint_canvas_background(p, rect)
        p.setPen(QPen(QColor("#000000"), 1.0))
        p.setBrush(Qt.BrushStyle.NoBrush)
        p.drawRect(rect)
        p.setPen(QPen(QColor(255, 255, 255, 90), 1.0))
        p.drawRect(QRectF(2.5, 2.5, size - 5, size - 5))
        p.end()
        self.btn_bg_color.setIcon(QIcon(pm))

    def _build_ui(self):
        central = self._styled(QWidget(), "Root")
        self.setCentralWidget(central)
        root = QVBoxLayout(central)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        options = self._styled(QWidget(), "OptionsBar")
        options.setLayout(self._build_top_bar())
        root.addWidget(options)

        # Da sinistra: Libreria | colonna strumenti | documento | Proprietà
        workspace = QWidget()
        ws = QHBoxLayout(workspace)
        ws.setContentsMargins(0, 0, 0, 0)
        ws.setSpacing(0)
        ws.addWidget(self._build_tool_strip())
        ws.addWidget(self._build_document_area(), 1)

        splitter = QSplitter(Qt.Orientation.Horizontal)
        splitter.setHandleWidth(1)
        splitter.setChildrenCollapsible(False)
        splitter.addWidget(self._dock("Libreria", self._scroll_panel(self._build_left_panel(), 296)))
        splitter.addWidget(workspace)
        splitter.addWidget(self._dock("Proprietà", self._scroll_panel(self._build_inspector(), 286)))
        splitter.setStretchFactor(0, 0)
        splitter.setStretchFactor(1, 1)
        splitter.setStretchFactor(2, 0)
        root.addWidget(splitter, 1)
        self._refresh_bg_swatches()

        # Icona dell'app nell'angolo della barra dei menu
        badge = self._styled(QLabel(), "AppBadge")
        badge.setPixmap(icon_pixmap("logo", THEME["accent"], 18))
        badge.setFixedSize(30, 26)
        badge.setAlignment(Qt.AlignmentFlag.AlignCenter)
        badge.setToolTip("ScrolleR Studio")
        self.menuBar().setCornerWidget(badge, Qt.Corner.TopLeftCorner)

    def _build_top_bar(self) -> QHBoxLayout:
        bar = QHBoxLayout()
        bar.setContentsMargins(10, 4, 10, 4)
        bar.setSpacing(8)

        tool = QLabel()
        tool.setPixmap(icon_pixmap("ratio", THEME["text"], 18))
        tool.setToolTip("Impostazioni del documento")
        bar.addWidget(tool)
        bar.addWidget(self._vsep())

        # Formato della pagina (3:4 di default)
        bar.addWidget(self._label("Formato"))
        self.combo_ratio = QComboBox()
        for label in self.ASPECT_RATIOS.keys():
            self.combo_ratio.addItem(label)
        self.combo_ratio.setCurrentIndex(0)
        self.combo_ratio.currentIndexChanged.connect(self._on_aspect_ratio_changed)
        bar.addWidget(self.combo_ratio)

        # Misure personalizzate L × A (visibili solo con "Personalizzato")
        self.custom_size_box = QWidget()
        custom_l = QHBoxLayout(self.custom_size_box)
        custom_l.setContentsMargins(0, 0, 0, 0)
        custom_l.setSpacing(6)
        self.spin_custom_w = QSpinBox()
        self.spin_custom_h = QSpinBox()
        for spin, val, tip in ((self.spin_custom_w, 1080, "Larghezza della pagina"), (self.spin_custom_h, 1440, "Altezza della pagina")):
            spin.setRange(200, 6000)
            spin.setValue(val)
            spin.setSuffix(" px")
            spin.setToolTip(tip)
            spin.setButtonSymbols(QAbstractSpinBox.ButtonSymbols.NoButtons)
            spin.setAlignment(Qt.AlignmentFlag.AlignCenter)
            spin.setFixedWidth(78)
            spin.valueChanged.connect(lambda _v: self._custom_ratio_timer.start())
        custom_l.addWidget(self.spin_custom_w)
        custom_l.addWidget(self._label("×"))
        custom_l.addWidget(self.spin_custom_h)
        self.custom_size_box.setVisible(False)
        bar.addWidget(self.custom_size_box)

        bar.addSpacing(6)
        # Numero di pagine (1 = collage singolo, 2+ = carosello)
        bar.addWidget(self._label("Pagine"))
        self.spin_frames = QSpinBox()
        self.spin_frames.setRange(1, 30)
        self.spin_frames.setValue(1)
        self.spin_frames.setButtonSymbols(QAbstractSpinBox.ButtonSymbols.NoButtons)
        self.spin_frames.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.spin_frames.setFixedWidth(44)
        self.spin_frames.setToolTip("1 = un solo collage nel formato scelto.\n2 o più = carosello continuo da pubblicare a pagine.")
        self.spin_frames.valueChanged.connect(self._on_frames_changed)
        stepper = QHBoxLayout()
        stepper.setSpacing(2)
        stepper.addWidget(self._icon_button("minus", "Una pagina in meno", lambda: self.spin_frames.stepBy(-1)))
        stepper.addWidget(self.spin_frames)
        stepper.addWidget(self._icon_button("plus", "Una pagina in più", lambda: self.spin_frames.stepBy(1)))
        bar.addLayout(stepper)

        bar.addSpacing(6)
        self.btn_bg_color = QToolButton()
        self.btn_bg_color.setObjectName("IconButton")
        self.btn_bg_color.setText("Sfondo")
        self.btn_bg_color.setToolButtonStyle(Qt.ToolButtonStyle.ToolButtonTextBesideIcon)
        self.btn_bg_color.setToolTip("Sfondo della tela: tinta unita, sfumatura o foto sfocata")
        self.btn_bg_color.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_bg_color.clicked.connect(self._open_background_dialog)
        bar.addWidget(self.btn_bg_color)

        bar.addSpacing(4)
        bar.addWidget(self._vsep())
        bar.addSpacing(4)

        # Guide e Snap come interruttori con icona
        self.chk_guides = self._icon_button("guides", "Mostra le linee di centro delle pagine", self._toggle_guides, "Guide", "ToggleButton")
        self.chk_snap = self._icon_button("magnet", "Aggancia le foto a bordi e centri mentre le trascini", self._toggle_snap, "Aggancio", "ToggleButton")
        for btn, icon in ((self.chk_guides, "guides"), (self.chk_snap, "magnet")):
            btn.setCheckable(True)
            btn.setChecked(True)
            btn.setIcon(make_icon(icon, THEME["muted"], 18, on_color=THEME["accent"]))
            btn.clicked.disconnect()
        self.chk_guides.toggled.connect(self._toggle_guides)
        self.chk_snap.toggled.connect(self._toggle_snap)
        bar.addWidget(self.chk_guides)
        bar.addWidget(self.chk_snap)

        bar.addStretch()

        btn_preview = self._icon_button("phone", "Guarda le pagine una alla volta, come nel carosello (F5)",
                                        self.show_carousel_preview, "Anteprima")
        bar.addWidget(btn_preview)
        bar.addSpacing(4)

        # Formato file, qualità ed esportazione
        self.combo_format = QComboBox()
        self.combo_format.addItems(["PNG (massima qualità)", "JPG (file leggeri)"])
        self.combo_format.setToolTip("Tipo di file esportato.\nJPG pesa molto meno ed è ideale per Instagram.")
        bar.addWidget(self.combo_format)
        self.combo_quality = QComboBox()
        self.combo_quality.addItems(["Qualità standard (1×)", "Alta definizione (2×)"])
        self.combo_quality.setCurrentIndex(1)  # 2× di default per massima nitidezza
        self.combo_quality.setToolTip("Risoluzione dei file esportati rispetto al formato scelto")
        bar.addWidget(self.combo_quality)

        btn_export = self._button("Esporta", lambda: None, "export", "Primary")
        export_menu = QMenu(btn_export)
        export_menu.addAction("Collage intero, in un'unica immagine…  (Ctrl+E)", self.export_full_collage)
        export_menu.addAction("Pagine separate, una immagine per pagina…  (Ctrl+Shift+E)", self.export_split_frames)
        btn_export.setMenu(export_menu)
        bar.addWidget(btn_export)
        return bar

    def _build_status_bar(self):
        sb = self.statusBar()
        sb.setSizeGripEnabled(False)
        self.lbl_hint = self._label("", "StatusText")
        sb.addWidget(self.lbl_hint, 1)

        self.lbl_count = self._label("", "StatusText")
        sb.addPermanentWidget(self.lbl_count)
        sb.addPermanentWidget(self._vsep())
        sb.addPermanentWidget(self._icon_button("minus", "Riduci zoom", lambda: self.view.zoom_by(1 / 1.25, False)))
        self.lbl_zoom = self._label("100%", "StatusText")
        self.lbl_zoom.setFixedWidth(44)
        self.lbl_zoom.setAlignment(Qt.AlignmentFlag.AlignCenter)
        sb.addPermanentWidget(self.lbl_zoom)
        sb.addPermanentWidget(self._icon_button("plus", "Aumenta zoom", lambda: self.view.zoom_by(1.25, False)))
        sb.addPermanentWidget(self._icon_button("fit", "Adatta la tela alla finestra (Ctrl+0)", self.fit_canvas_in_view, "Adatta"))

    def _make_slider(self, layout, title: str, lo: int, hi: int, value: int, suffix: str = "",
                     signed: bool = False, resettable: bool = False) -> QSlider:
        """Riga con titolo e valore corrente (a destra), seguita dallo slider.
        Con resettable=True compare un'icona che riporta lo slider al valore iniziale."""
        row = QHBoxLayout()
        row.setContentsMargins(0, 0, 0, 0)
        row.setSpacing(4)
        row.addWidget(self._label(title))
        row.addStretch()
        slider = QSlider(Qt.Orientation.Horizontal)
        if resettable:
            reset = self._icon_button("reset", f"Ripristina il valore iniziale ({value}{suffix})",
                                      lambda: slider.setValue(value))
            reset.setIconSize(QSize(14, 14))
            row.addWidget(reset)
        chip = self._label("", "ValueChip")
        row.addWidget(chip)
        slider.setRange(lo, hi)
        slider.setValue(value)
        slider.setCursor(Qt.CursorShape.PointingHandCursor)
        if signed:
            # Lo zero è al centro: niente riempimento da sinistra che suggerirebbe un "livello"
            slider.setObjectName("Signed")

        def refresh(v):
            chip.setText(f"{v:+d}{suffix}" if signed and v != 0 else f"{v}{suffix}")

        refresh(value)
        slider.valueChanged.connect(refresh)
        block = QVBoxLayout()
        block.setContentsMargins(0, 0, 0, 0)
        block.setSpacing(0)
        block.addLayout(row)
        block.addWidget(slider)
        layout.addLayout(block)
        return slider

    def _build_actions(self):
        menubar = self.menuBar()

        def make(text, slot, shortcut=None, menu=None, target=None):
            act = QAction(text, self)
            if shortcut:
                act.setShortcuts(shortcut if isinstance(shortcut, list) else [shortcut])
            act.triggered.connect(slot)
            if menu is not None:
                menu.addAction(act)
            if target is not None:
                # Scorciatoie attive solo quando la tela ha il focus (non rubano tasti a slider/campi)
                act.setShortcutContext(Qt.ShortcutContext.WidgetWithChildrenShortcut)
                target.addAction(act)
            return act

        m_file = menubar.addMenu("&File")
        make("Aggiungi foto…", self.open_file_dialog, QKeySequence.StandardKey.Open, m_file)
        m_file.addSeparator()
        make("Apri progetto…", self.open_project, QKeySequence("Ctrl+Shift+O"), m_file)
        self.menu_recent = m_file.addMenu("Apri recenti")
        self.menu_recent.aboutToShow.connect(self._rebuild_recent_menu)
        make("Salva progetto", self.save_project, QKeySequence.StandardKey.Save, m_file)
        make("Salva progetto con nome…", self.save_project_as, QKeySequence("Ctrl+Shift+S"), m_file)
        m_file.addSeparator()
        make("Esporta collage intero…", self.export_full_collage, QKeySequence("Ctrl+E"), m_file)
        make("Esporta pagine separate…", self.export_split_frames, QKeySequence("Ctrl+Shift+E"), m_file)
        m_file.addSeparator()
        make("Esci", self.close, QKeySequence.StandardKey.Quit, m_file)

        m_edit = menubar.addMenu("&Modifica")
        self.act_undo = make("Annulla", self.undo, QKeySequence.StandardKey.Undo, m_edit)
        self.act_redo = make("Ripeti", self.redo, [QKeySequence("Ctrl+Y"), QKeySequence("Ctrl+Shift+Z")], m_edit)
        m_edit.addSeparator()
        make("Duplica", self._duplicate_selected, QKeySequence("Ctrl+D"), m_edit)
        make("Reimposta zoom e posizione", self._reset_selected_framing, QKeySequence("Ctrl+R"), m_edit)
        make("Seleziona tutte", self._select_all, QKeySequence.StandardKey.SelectAll, m_edit)
        m_edit.addSeparator()
        make("Copia stile", self._copy_style, QKeySequence("Ctrl+Shift+C"), m_edit)
        make("Incolla stile", self._paste_style, QKeySequence("Ctrl+Shift+V"), m_edit)
        make("Blocca / sblocca posizione", self._toggle_lock_selected, QKeySequence("Ctrl+L"), m_edit)
        m_edit.addSeparator()
        make("Specchia orizzontalmente", lambda: self._flip_selected("h"), None, m_edit)
        make("Specchia verticalmente", lambda: self._flip_selected("v"), None, m_edit)
        m_edit.addSeparator()
        make("Rimescola ordine foto", self.shuffle_canvas_photos, None, m_edit)
        make("Scambia 2 selezionate", self.swap_two_selected_photos, None, m_edit)

        m_insert = menubar.addMenu("&Inserisci")
        make("Testo", self.add_text, QKeySequence("Ctrl+T"), m_insert)
        make("Foto…", self.open_file_dialog, None, m_insert)

        m_pages = menubar.addMenu("&Pagine")
        make("Aggiungi una pagina dopo quella corrente", lambda: self._insert_page_after(self._current_page()), None, m_pages)
        make("Aggiungi una pagina alla fine", lambda: self._insert_page_after(self.scene.num_frames - 1), None, m_pages)
        m_pages.addSeparator()
        make("Sposta la pagina corrente a sinistra", lambda: self._move_page(self._current_page(), -1), None, m_pages)
        make("Sposta la pagina corrente a destra", lambda: self._move_page(self._current_page(), 1), None, m_pages)
        m_pages.addSeparator()
        make("Elimina la pagina corrente…", lambda: self._delete_page(self._current_page()), None, m_pages)
        hint = m_pages.addAction("(Pagina corrente = quella dell'elemento selezionato o al centro della vista)")
        hint.setEnabled(False)

        m_view = menubar.addMenu("&Vista")
        make("Anteprima carosello", self.show_carousel_preview, QKeySequence("F5"), m_view)
        m_view.addSeparator()
        make("Zoom avanti", lambda: self.view.zoom_by(1.25, False), [QKeySequence("Ctrl++"), QKeySequence("Ctrl+=")], m_view)
        make("Zoom indietro", lambda: self.view.zoom_by(1 / 1.25, False), QKeySequence("Ctrl+-"), m_view)
        make("Dimensioni reali (100%)", self._zoom_actual_size, QKeySequence("Ctrl+1"), m_view)
        make("Adatta alla finestra", self.fit_canvas_in_view, QKeySequence("Ctrl+0"), m_view)

        # Scorciatoie solo-tela: Elimina e spostamento fine con le frecce (Shift = 10 px)
        make("Elimina", self._delete_selected, [QKeySequence(Qt.Key.Key_Delete), QKeySequence(Qt.Key.Key_Backspace)], target=self.view)
        for key, dx, dy in ((Qt.Key.Key_Left, -1, 0), (Qt.Key.Key_Right, 1, 0), (Qt.Key.Key_Up, 0, -1), (Qt.Key.Key_Down, 0, 1)):
            make("", lambda _c=False, a=dx, b=dy: self._nudge_selected(a, b), QKeySequence(key), target=self.view)
            make("", lambda _c=False, a=dx, b=dy: self._nudge_selected(a * 10, b * 10),
                 QKeySequence(QKeyCombination(Qt.KeyboardModifier.ShiftModifier, key)), target=self.view)
        self._update_undo_actions()
