"""Finestre di dialogo: anteprima carosello, ordine delle pagine, pagine da esportare e sfondo."""
from typing import TYPE_CHECKING
import os
from typing import Dict, List

from PyQt6.QtCore import Qt, QSize
from PyQt6.QtGui import QPixmap, QColor, QIcon
from PyQt6.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QHBoxLayout, QPushButton, QLabel, QComboBox, QColorDialog,
    QButtonGroup, QDialog, QRadioButton, QListWidget, QListWidgetItem, QListView, QAbstractItemView, QLineEdit,
    QSizePolicy
)

from scrollr.icons import make_icon, rounded_thumb, swatch_icon
from scrollr.imaging import IMAGE_CACHE
from scrollr.theme import THEME

if TYPE_CHECKING:
    from scrollr.window.main_window import MainWindow


class CarouselPreview(QDialog):
    """Anteprima delle pagine una alla volta, come le vedrà chi scorre il carosello."""

    def __init__(self, pages: List[QPixmap], page_ratio: float, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Anteprima carosello")
        self.pages = pages
        self.index = 0
        lay = QVBoxLayout(self)
        lay.setContentsMargins(16, 16, 16, 12)
        lay.setSpacing(10)
        self.image = QLabel()
        self.image.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.image.setMinimumSize(240, 240)
        lay.addWidget(self.image, 1)

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
        nav.addWidget(self.btn_prev)
        nav.addStretch()
        nav.addWidget(self.lbl)
        nav.addStretch()
        nav.addWidget(self.btn_next)
        lay.addLayout(nav)
        hint = QLabel("Frecce ← → della tastiera per scorrere, Esc per chiudere")
        hint.setObjectName("Hint")
        hint.setAlignment(Qt.AlignmentFlag.AlignCenter)
        lay.addWidget(hint)

        screen = (parent.screen() if parent is not None else QApplication.primaryScreen()).availableGeometry()
        img_h = int(screen.height() * 0.72)
        img_w = int(img_h * page_ratio)
        if img_w > screen.width() * 0.8:
            img_w = int(screen.width() * 0.8)
            img_h = int(img_w / page_ratio)
        self.resize(max(460, img_w + 32), img_h + 110)
        self._show()

    def step(self, delta: int):
        self.index = max(0, min(len(self.pages) - 1, self.index + delta))
        self._show()

    def _show(self):
        if not self.pages:
            return
        pm = self.pages[self.index]
        dpr = self.devicePixelRatioF()
        target = self.image.size() * dpr
        scaled = pm.scaled(target, Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation)
        scaled.setDevicePixelRatio(dpr)
        self.image.setPixmap(scaled)
        n = len(self.pages)
        dots = "  ".join("●" if i == self.index else "○" for i in range(n)) if n <= 12 else ""
        self.lbl.setText(f"Pagina {self.index + 1} di {n}" + (f"\n{dots}" if dots and n > 1 else ""))
        self.btn_prev.setEnabled(self.index > 0)
        self.btn_next.setEnabled(self.index < n - 1)

    def resizeEvent(self, event):
        super().resizeEvent(event)
        self._show()

    def keyPressEvent(self, event):
        if event.key() == Qt.Key.Key_Left:
            self.step(-1)
        elif event.key() == Qt.Key.Key_Right:
            self.step(1)
        else:
            super().keyPressEvent(event)


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
