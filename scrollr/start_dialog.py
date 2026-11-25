"""
Finestra di avvio: all'apertura dell'app chiede che progetto fare, come la Home del telefono.
A sinistra i progetti recenti con la miniatura (un clic li apre) e «Apri progetto…»,
a destra i formati di un nuovo progetto (lo stesso pannello di File → Nuovo progetto).

Le miniature non stanno nel .scrlproj: l'app le salva a parte, nella sua cartella dati,
ogni volta che salva o apre un progetto.
"""
import hashlib
import json
import os
import tempfile
from datetime import date, datetime
from typing import Dict, List, Optional, Tuple

from PyQt6.QtCore import Qt, QRectF, QSize, QStandardPaths
from PyQt6.QtGui import QColor, QPainter, QPen, QPixmap
from PyQt6.QtWidgets import (
    QAbstractItemView, QDialog, QFileDialog, QFrame, QHBoxLayout, QLabel, QListWidget, QListWidgetItem,
    QPushButton, QVBoxLayout, QWidget
)

from scrollr.config import PROJECT_EXT
from scrollr.dialogs import NewProjectPanel
from scrollr.icons import ratio_pixmap
from scrollr.theme import THEME

THUMB_SIDE = 320   # Lato lungo della miniatura salvata
LIST_THUMB = 64    # Riquadro della miniatura nell'elenco dei recenti


# ---------- Miniature dei progetti ----------
def thumbnail_dir() -> str:
    base = QStandardPaths.writableLocation(QStandardPaths.StandardLocation.AppDataLocation) or tempfile.gettempdir()
    return os.path.join(base, "miniature")


def thumbnail_path(project_path: str) -> str:
    """Una miniatura per progetto, con il nome ricavato dal percorso (lo stesso file risalvato la sostituisce)."""
    key = os.path.normcase(os.path.abspath(project_path))
    return os.path.join(thumbnail_dir(), hashlib.sha1(key.encode("utf-8")).hexdigest()[:20] + ".png")


def prune_thumbnails(keep: List[str]):
    """Toglie le miniature dei progetti usciti dall'elenco dei recenti."""
    folder = thumbnail_dir()
    keep_names = {os.path.basename(thumbnail_path(p)) for p in keep}
    try:
        names = os.listdir(folder)
    except OSError:
        return
    for name in names:
        if name.endswith(".png") and name not in keep_names:
            try:
                os.remove(os.path.join(folder, name))
            except OSError:
                pass


# ---------- Descrizione di un progetto recente ----------
def project_summary(path: str, ratios: Dict[str, Optional[Tuple[int, int]]]) -> Tuple[str, Optional[Tuple[int, int]]]:
    """«Carosello · 4:5 · 6 pagine» o «Reel · 9:16», letti dal file, e il formato della pagina."""
    try:
        with open(path, "r", encoding="utf-8") as f:
            canvas = json.load(f)["canvas"]
        wh = (int(canvas["frame_w"]), int(canvas["frame_h"]))
        kind = canvas.get("project_type", "carousel")
        pages = int(canvas.get("num_frames", 1))
    except (OSError, ValueError, KeyError, TypeError):
        return "", None
    name = next((label.split(" ")[0] for label, v in ratios.items() if v == wh), f"{wh[0]}×{wh[1]}")
    if kind == "reel":
        return f"Reel · {name}", wh
    return f"Carosello · {name} · {pages} {'pagina' if pages == 1 else 'pagine'}", wh


def modified_text(path: str) -> str:
    try:
        when = datetime.fromtimestamp(os.path.getmtime(path))
    except OSError:
        return ""
    days = (date.today() - when.date()).days
    if days == 0:
        return f"oggi, {when:%H:%M}"
    if days == 1:
        return f"ieri, {when:%H:%M}"
    return f"{when:%d/%m/%Y}"


def list_thumbnail(project_path: str, wh: Optional[Tuple[int, int]]) -> QPixmap:
    """Miniatura nel riquadro dell'elenco; senza miniatura salvata, la sagoma del formato."""
    side = LIST_THUMB
    out = QPixmap(side * 2, side * 2)
    out.setDevicePixelRatio(2.0)
    out.fill(Qt.GlobalColor.transparent)
    p = QPainter(out)
    p.setRenderHint(QPainter.RenderHint.Antialiasing, True)
    p.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, True)
    thumb = QPixmap(thumbnail_path(project_path))
    if not thumb.isNull():
        scale = min(side / thumb.width(), side / thumb.height())
        w, h = thumb.width() * scale, thumb.height() * scale
        rect = QRectF((side - w) / 2, (side - h) / 2, w, h)
        p.drawPixmap(rect, thumb, QRectF(thumb.rect()))
        p.setPen(QPen(QColor(THEME["edge"]), 1.0))
        p.setBrush(Qt.BrushStyle.NoBrush)
        p.drawRect(rect.adjusted(0.5, 0.5, -0.5, -0.5))
    else:
        shape = ratio_pixmap(wh, THEME["muted"], 40)
        p.drawPixmap(QRectF((side - 40) / 2, (side - 40) / 2, 40, 40), shape, QRectF(shape.rect()))
    p.end()
    return out


class StartDialog(QDialog):
    """
    All'avvio: «Recenti» a sinistra, «Nuovo progetto» a destra.
    Dopo exec() accettato, choice() dice cosa fare: ("open", percorso) oppure ("new", None) e i valori
    del pannello. Chiusa senza scegliere resta il carosello vuoto di partenza.
    """

    def __init__(self, recent: List[str], ratios: Dict[str, Optional[Tuple[int, int]]], size: Tuple[int, int],
                 custom: Tuple[int, int], pages: int, max_pages: int, parent=None):
        super().__init__(parent)
        self.setWindowTitle("ScrolleR Studio")
        self._choice: Tuple[str, Optional[str]] = ("new", None)

        lay = QVBoxLayout(self)
        lay.setContentsMargins(16, 16, 16, 12)
        lay.setSpacing(12)
        cols = QHBoxLayout()
        cols.setSpacing(16)
        lay.addLayout(cols)

        # ---- Recenti ----
        left = QVBoxLayout()
        left.setSpacing(6)
        title = QLabel("Recenti")
        title.setObjectName("EmptyTitle")
        left.addWidget(title)
        self.list_recent = QListWidget()
        self.list_recent.setObjectName("RecentList")
        self.list_recent.setSelectionMode(QAbstractItemView.SelectionMode.SingleSelection)
        self.list_recent.setVerticalScrollMode(QAbstractItemView.ScrollMode.ScrollPerPixel)
        self.list_recent.setMinimumWidth(300)
        self.list_recent.setCursor(Qt.CursorShape.PointingHandCursor)
        for path in recent:
            self._add_recent_row(path, ratios)
        self.list_recent.itemClicked.connect(self._open_item)
        self.list_recent.itemActivated.connect(self._open_item)
        self.lbl_empty = QLabel("Nessun progetto recente.\nI progetti che salvi compaiono qui.")
        self.lbl_empty.setObjectName("Hint")
        self.lbl_empty.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.lbl_empty.setMinimumWidth(300)  # La finestra resta larga uguale anche senza recenti
        self.list_recent.setVisible(bool(recent))
        self.lbl_empty.setVisible(not recent)
        left.addWidget(self.list_recent, 1)
        left.addWidget(self.lbl_empty, 1)
        self.btn_open = QPushButton("Apri progetto…")
        self.btn_open.clicked.connect(self._browse)
        left.addWidget(self.btn_open)
        cols.addLayout(left, 2)

        sep = QFrame()
        sep.setObjectName("VSep")
        sep.setFixedWidth(1)
        cols.addWidget(sep)

        # ---- Nuovo progetto ----
        right = QVBoxLayout()
        right.setSpacing(6)
        title = QLabel("Nuovo progetto")
        title.setObjectName("EmptyTitle")
        right.addWidget(title)
        self.panel = NewProjectPanel(ratios, size, custom, pages, max_pages, self)
        right.addWidget(self.panel, 1)
        cols.addLayout(right, 5)

        buttons = QHBoxLayout()
        buttons.addStretch()
        cancel = QPushButton("Annulla")
        cancel.setToolTip("Inizia con un carosello vuoto")
        cancel.clicked.connect(self.reject)
        self.btn_create = QPushButton("Crea")
        self.btn_create.setObjectName("Primary")
        self.btn_create.setDefault(True)
        self.btn_create.clicked.connect(self._create)
        buttons.addWidget(cancel)
        buttons.addWidget(self.btn_create)
        lay.addLayout(buttons)

    def _add_recent_row(self, path: str, ratios: Dict[str, Optional[Tuple[int, int]]]):
        summary, wh = project_summary(path, ratios)
        row = QWidget()
        row.setAttribute(Qt.WidgetAttribute.WA_TransparentForMouseEvents)
        h = QHBoxLayout(row)
        h.setContentsMargins(6, 4, 6, 4)
        h.setSpacing(10)
        pic = QLabel()
        pic.setFixedSize(LIST_THUMB, LIST_THUMB)
        pic.setPixmap(list_thumbnail(path, wh))
        h.addWidget(pic)
        text = QVBoxLayout()
        text.setSpacing(2)
        text.addStretch()
        name = QLabel(os.path.splitext(os.path.basename(path))[0])
        name.setObjectName("SelName")
        text.addWidget(name)
        for line in (summary, modified_text(path)):
            if line:
                lbl = QLabel(line)
                lbl.setObjectName("Hint")
                text.addWidget(lbl)
        text.addStretch()
        h.addLayout(text, 1)

        item = QListWidgetItem()
        item.setData(Qt.ItemDataRole.UserRole, path)
        item.setToolTip(path)
        item.setSizeHint(QSize(0, LIST_THUMB + 10))
        self.list_recent.addItem(item)
        self.list_recent.setItemWidget(item, row)

    def _open_item(self, item: QListWidgetItem):
        self._choice = ("open", item.data(Qt.ItemDataRole.UserRole))
        self.accept()

    def _browse(self):
        path, _ = QFileDialog.getOpenFileName(self, "Apri progetto", "", f"Progetto ScrolleR (*{PROJECT_EXT})")
        if path:
            self._choice = ("open", path)
            self.accept()

    def _create(self):
        self._choice = ("new", None)
        self.accept()

    def choice(self) -> Tuple[str, Optional[str]]:
        return self._choice
