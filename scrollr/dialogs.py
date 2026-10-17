"""Finestre di dialogo: anteprima carosello e sfondo."""
from typing import TYPE_CHECKING
import os
from typing import Dict, List

from PyQt6.QtCore import Qt, QSize
from PyQt6.QtGui import QPixmap, QColor, QIcon
from PyQt6.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QHBoxLayout, QPushButton, QLabel, QComboBox, QColorDialog,
    QButtonGroup, QDialog, QRadioButton
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
