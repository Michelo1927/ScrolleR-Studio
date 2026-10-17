import sys
import os
import io
import json
import math
import random
from collections import OrderedDict
from typing import Dict, List, Optional, Tuple

from PyQt6.QtCore import (
    Qt, QRectF, QPointF, pyqtSignal, QSize, QTimer, QKeyCombination
)
from PyQt6.QtGui import (
    QPixmap, QImage, QPainter, QPen, QColor, QBrush, QFont, QFontDatabase,
    QPainterPath, QAction, QIcon, QCursor, QTransform, QKeySequence, QPolygonF, QPalette
)
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QPushButton, QLabel, QComboBox, QSpinBox, QSlider, QFileDialog,
    QColorDialog, QListWidget, QListWidgetItem, QGraphicsView,
    QGraphicsScene, QGraphicsObject, QGraphicsItem, QFrame,
    QCheckBox, QMessageBox, QMenu, QSplitter, QGridLayout, QProgressDialog,
    QToolButton, QButtonGroup, QScrollArea, QStackedWidget, QAbstractSpinBox,
    QListView, QSizePolicy
)
from PIL import Image, ImageOps, ImageCms

# Supporto HEIC/HEIF (foto iPhone) opzionale: pip install pillow-heif
try:
    import pillow_heif
    pillow_heif.register_heif_opener()
    HEIF_SUPPORTED = True
except ImportError:
    HEIF_SUPPORTED = False

IMAGE_EXTS = (".jpg", ".jpeg", ".png", ".webp", ".bmp") + ((".heic", ".heif") if HEIF_SUPPORTED else ())
PROJECT_EXT = ".scrlproj"
PROJECT_VERSION = 1


# ================= TEMA "TAVOLO LUMINOSO" =================
# Grafite tinta viola come piano di lavoro neutro (per giudicare i colori delle foto)
# e un unico accento calendula, riservato ad azioni, selezione e giunzioni tra pagine.
THEME = {
    "backdrop": "#1E1D25",
    "panel": "#272630",
    "raised": "#322F3C",
    "hover": "#3C3948",
    "line": "#423F50",
    "text": "#EEECF4",
    "muted": "#A6A3B8",
    "faint": "#6F6C82",
    "accent": "#F4B63F",
    "accent_hover": "#F8C865",
    "accent_ink": "#2B1D00",
    "danger": "#F0646F",
    "snap": "#F472D0",
}

_FONT_CACHE: Dict[str, str] = {}


def font_family(role: str = "text") -> str:
    """Segoe UI Variable (Windows 11) se disponibile, altrimenti Segoe UI."""
    if role not in _FONT_CACHE:
        wanted = "Segoe UI Variable Display" if role == "display" else "Segoe UI Variable Text"
        families = set(QFontDatabase.families())
        _FONT_CACHE[role] = next((f for f in (wanted, "Segoe UI Variable", "Segoe UI") if f in families), "Segoe UI")
    return _FONT_CACHE[role]


def ui_font(px: int, weight: QFont.Weight = QFont.Weight.Normal, role: str = "text") -> QFont:
    f = QFont(font_family(role))
    f.setPixelSize(px)
    f.setWeight(weight)
    return f


# ================= ICONE DISEGNATE (nessun file esterno) =================
def _icon_pixmap(name: str, color: str, size: int) -> QPixmap:
    pm = QPixmap(size * 2, size * 2)
    pm.setDevicePixelRatio(2.0)
    pm.fill(Qt.GlobalColor.transparent)
    p = QPainter(pm)
    p.setRenderHint(QPainter.RenderHint.Antialiasing, True)
    p.scale(size / 24.0, size / 24.0)

    col = QColor(color)
    pen = QPen(col, 1.7)
    pen.setCapStyle(Qt.PenCapStyle.RoundCap)
    pen.setJoinStyle(Qt.PenJoinStyle.RoundJoin)
    p.setPen(pen)
    p.setBrush(Qt.BrushStyle.NoBrush)
    tint = QColor(col)
    tint.setAlphaF(0.30)

    def rr(x, y, w, h, r=1.6, brush=None):
        p.setBrush(brush if brush is not None else Qt.BrushStyle.NoBrush)
        p.drawRoundedRect(QRectF(x, y, w, h), r, r)
        p.setBrush(Qt.BrushStyle.NoBrush)

    def poly(*pts):
        p.drawPolyline(QPolygonF([QPointF(a, b) for a, b in pts]))

    def line(x1, y1, x2, y2):
        p.drawLine(QPointF(x1, y1), QPointF(x2, y2))

    def clear(x, y, w, h):
        p.setCompositionMode(QPainter.CompositionMode.CompositionMode_Clear)
        p.fillRect(QRectF(x - 1.4, y - 1.4, w + 2.8, h + 2.8), Qt.GlobalColor.black)
        p.setCompositionMode(QPainter.CompositionMode.CompositionMode_SourceOver)

    def arc_arrow(start, span):
        cx, cy, r = 12.0, 12.5, 7.0
        p.drawArc(QRectF(cx - r, cy - r, 2 * r, 2 * r), int(start * 16), int(span * 16))
        th = math.radians(start + span)
        tip = QPointF(cx + r * math.cos(th), cy - r * math.sin(th))
        s = 1.0 if span > 0 else -1.0
        dx, dy = s * -math.sin(th), s * -math.cos(th)  # Direzione di percorrenza dell'arco
        for a in (math.radians(40), math.radians(-40)):
            bx = -dx * math.cos(a) + dy * math.sin(a)
            by = -dx * math.sin(a) - dy * math.cos(a)
            p.drawLine(tip, tip + QPointF(bx * 4.2, by * 4.2))

    if name == "grid":
        for x, y in ((4, 4), (13, 4), (4, 13), (13, 13)):
            rr(x, y, 7, 7, brush=tint)
    elif name == "mosaic":
        rr(4, 4, 16, 9, brush=tint)
        rr(4, 15, 7, 5)
        rr(13, 15, 7, 5)
    elif name == "strips_h":
        for y in (4, 10, 16):
            rr(4, y, 16, 4, 1.2, brush=tint if y == 4 else None)
    elif name == "strips_v":
        for x in (4, 10, 16):
            rr(x, 4, 4, 16, 1.2, brush=tint if x == 4 else None)
    elif name == "scatter":
        p.save()
        p.translate(9, 11)
        p.rotate(-12)
        rr(-5, -6, 10, 12, 1.2)
        p.restore()
        p.save()
        p.translate(15, 13)
        p.rotate(9)
        clear(-5, -6, 10, 12)
        rr(-5, -6, 10, 12, 1.2, brush=tint)
        p.restore()
    elif name == "seam":
        thin = QPen(pen)
        thin.setWidthF(1.2)
        p.setPen(thin)
        rr(2.5, 5, 9.5, 14, 1.2)
        rr(12, 5, 9.5, 14, 1.2)
        p.setPen(pen)
        clear(7, 8.5, 10, 7)
        rr(7, 8.5, 10, 7, 1.2, brush=tint)
    elif name == "plus":
        line(12, 5, 12, 19)
        line(5, 12, 19, 12)
    elif name == "minus":
        line(6, 12, 18, 12)
    elif name == "image":
        rr(3.5, 5, 17, 14, 2.2)
        poly((4, 17.5), (9, 12), (13, 15.5), (15.5, 13.5), (20, 17.5))
        p.drawEllipse(QPointF(15.8, 9.4), 1.6, 1.6)
    elif name == "export":
        poly((4.5, 13.5), (4.5, 19.5), (19.5, 19.5), (19.5, 13.5))
        line(12, 4, 12, 15)
        poly((8, 8), (12, 4), (16, 8))
    elif name == "fit":
        poly((4, 9), (4, 4), (9, 4))
        poly((15, 4), (20, 4), (20, 9))
        poly((20, 15), (20, 20), (15, 20))
        poly((9, 20), (4, 20), (4, 15))
    elif name == "guides":
        rr(4, 4, 16, 16, 2.2)
        dash = QPen(pen)
        dash.setWidthF(1.2)
        dash.setDashPattern([1.5, 2.0])
        p.setPen(dash)
        line(12, 6.5, 12, 17.5)
        line(6.5, 12, 17.5, 12)
    elif name == "magnet":
        path = QPainterPath()
        path.moveTo(6, 4.5)
        path.lineTo(6, 12)
        path.arcTo(QRectF(6, 6, 12, 12), 180, 180)
        path.lineTo(18, 4.5)
        p.drawPath(path)
        line(4.2, 8, 7.8, 8)
        line(16.2, 8, 19.8, 8)
    elif name == "shuffle":
        poly((4, 7), (8, 7), (16, 17), (20, 17))
        poly((4, 17), (8, 17), (16, 7), (20, 7))
        poly((17.5, 4.5), (20, 7), (17.5, 9.5))
        poly((17.5, 14.5), (20, 17), (17.5, 19.5))
    elif name == "swap":
        line(4, 8, 20, 8)
        poly((16.5, 4.5), (20, 8), (16.5, 11.5))
        line(20, 16, 4, 16)
        poly((7.5, 12.5), (4, 16), (7.5, 19.5))
    elif name == "rot_left":
        arc_arrow(-135, 270)
    elif name == "rot_right":
        arc_arrow(315, -270)
    elif name == "level":
        rr(5, 7, 14, 9, 1.6)
        line(3.5, 19.5, 20.5, 19.5)
    elif name == "front":
        rr(4, 4, 11, 11, 1.6)
        clear(9, 9, 11, 11)
        rr(9, 9, 11, 11, 1.6, brush=QBrush(col))
    elif name == "back":
        rr(4, 4, 11, 11, 1.6, brush=QBrush(col))
        clear(9, 9, 11, 11)
        rr(9, 9, 11, 11, 1.6)
    elif name == "duplicate":
        rr(8.5, 8.5, 11.5, 11.5, 1.8)
        poly((4.5, 15.5), (4.5, 4.5), (15.5, 4.5))
    elif name == "trash":
        line(4, 7, 20, 7)
        poly((9.5, 7), (9.5, 4.5), (14.5, 4.5), (14.5, 7))
        poly((6.2, 7), (7.2, 20), (16.8, 20), (17.8, 7))
        line(10, 10.5, 10, 16.5)
        line(14, 10.5, 14, 16.5)
    elif name == "ratio":
        rr(4, 6, 16, 12, 1.8)
        poly((7, 11), (7, 9), (9, 9))
        poly((17, 13), (17, 15), (15, 15))
    elif name == "logo":
        p.setPen(Qt.PenStyle.NoPen)
        faded = QColor(col)
        faded.setAlphaF(0.45)
        rr(1.5, 6.5, 8, 11, 1.8, brush=QBrush(faded))
        rr(14.5, 6.5, 8, 11, 1.8, brush=QBrush(faded))
        clear(6.5, 3.5, 11, 17)
        rr(6.5, 3.5, 11, 17, 2.2, brush=QBrush(col))
    p.end()
    return pm


def make_icon(name: str, color: str = THEME["muted"], size: int = 18, on_color: Optional[str] = None) -> QIcon:
    icon = QIcon()
    icon.addPixmap(_icon_pixmap(name, color, size), QIcon.Mode.Normal, QIcon.State.Off)
    icon.addPixmap(_icon_pixmap(name, on_color or color, size), QIcon.Mode.Normal, QIcon.State.On)
    icon.addPixmap(_icon_pixmap(name, THEME["faint"], size), QIcon.Mode.Disabled, QIcon.State.Off)
    return icon


def swatch_icon(color: QColor, size: int = 16) -> QIcon:
    pm = QPixmap(size * 2, size * 2)
    pm.setDevicePixelRatio(2.0)
    pm.fill(Qt.GlobalColor.transparent)
    p = QPainter(pm)
    p.setRenderHint(QPainter.RenderHint.Antialiasing, True)
    p.setPen(QPen(QColor(THEME["line"]), 1.5))
    p.setBrush(QBrush(color))
    p.drawEllipse(QRectF(1, 1, size - 2, size - 2))
    p.end()
    return QIcon(pm)


def rounded_thumb(pm: QPixmap, size: int, radius: float = 8.0) -> QPixmap:
    """Miniatura quadrata ritagliata al centro, con angoli arrotondati."""
    out = QPixmap(size * 2, size * 2)
    out.setDevicePixelRatio(2.0)
    out.fill(Qt.GlobalColor.transparent)
    if pm.isNull():
        return out
    side = min(pm.width(), pm.height())
    src = QRectF((pm.width() - side) / 2.0, (pm.height() - side) / 2.0, side, side)
    p = QPainter(out)
    p.setRenderHint(QPainter.RenderHint.Antialiasing, True)
    p.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, True)
    clip = QPainterPath()
    clip.addRoundedRect(QRectF(0, 0, size, size), radius, radius)
    p.setClipPath(clip)
    p.drawPixmap(QRectF(0, 0, size, size), pm, src)
    p.end()
    return out


def is_light(color: QColor) -> bool:
    return (0.299 * color.red() + 0.587 * color.green() + 0.114 * color.blue()) > 150


# ================= CARICAMENTO IMMAGINI & CACHE =================
def load_pil_srgb(path: str, max_side: Optional[int] = None) -> Image.Image:
    """
    Apre un'immagine applicando rotazione EXIF e conversione del profilo colore ICC in sRGB
    (es. foto iPhone in Display P3). Se max_side è indicato, l'immagine viene ridotta.
    Restituisce sempre un'immagine in modalità RGB o RGBA.
    """
    with Image.open(path) as src:
        if max_side:
            src.draft("RGB", (max_side, max_side))  # Decodifica JPEG ridotta e veloce
        icc = src.info.get("icc_profile")
        img = ImageOps.exif_transpose(src)
        img.load()

    has_alpha = img.mode in ("RGBA", "LA", "PA") or (img.mode == "P" and "transparency" in img.info)
    out_mode = "RGBA" if has_alpha else "RGB"

    if icc:
        try:
            if img.mode not in ("RGB", "RGBA", "CMYK", "L"):
                img = img.convert(out_mode)
            src_profile = ImageCms.ImageCmsProfile(io.BytesIO(icc))
            dst_profile = ImageCms.createProfile("sRGB")
            img = ImageCms.profileToProfile(img, src_profile, dst_profile, outputMode=out_mode)
        except Exception:
            pass  # Profilo non valido o non compatibile: si usa l'immagine così com'è

    if img.mode != out_mode:
        img = img.convert(out_mode)
    if max_side and max(img.size) > max_side:
        img.thumbnail((max_side, max_side), Image.Resampling.LANCZOS)
    return img


def pil_to_qimage(pil_img: Image.Image) -> QImage:
    if pil_img.mode == "RGBA":
        fmt, bpp = QImage.Format.Format_RGBA8888, 4
    else:
        pil_img = pil_img.convert("RGB") if pil_img.mode != "RGB" else pil_img
        fmt, bpp = QImage.Format.Format_RGB888, 3
    data = pil_img.tobytes("raw", pil_img.mode)
    qimg = QImage(data, pil_img.width, pil_img.height, pil_img.width * bpp, fmt)
    return qimg.copy()


class ImageCache:
    """
    Tiene in memoria una sola anteprima ridotta per ogni file (condivisa da tutte le copie
    sulla tela). La piena risoluzione viene letta dal disco solo durante l'esportazione,
    con una piccola cache LRU, così anche centinaia di foto non saturano la RAM.
    """
    PREVIEW_MAX_SIDE = 1600
    FULL_CACHE_SIZE = 3

    def __init__(self):
        self._previews: Dict[str, QPixmap] = {}
        self._full: "OrderedDict[str, Image.Image]" = OrderedDict()

    def load(self, path: str) -> QPixmap:
        if path not in self._previews:
            preview = load_pil_srgb(path, self.PREVIEW_MAX_SIDE)
            self._previews[path] = QPixmap.fromImage(pil_to_qimage(preview))
        return self._previews[path]

    def preview(self, path: str) -> QPixmap:
        pm = self._previews.get(path)
        return pm if pm is not None else QPixmap()

    def has(self, path: str) -> bool:
        return path in self._previews

    def full(self, path: str) -> Optional[Image.Image]:
        if path in self._full:
            self._full.move_to_end(path)
            return self._full[path]
        try:
            img = load_pil_srgb(path)
        except Exception:
            return None
        self._full[path] = img
        while len(self._full) > self.FULL_CACHE_SIZE:
            self._full.popitem(last=False)
        return img

    def release_full(self):
        self._full.clear()


IMAGE_CACHE = ImageCache()


def normalize_path(p: str) -> str:
    return os.path.normpath(os.path.abspath(p))


def image_paths_from_mime(mime) -> List[str]:
    paths = []
    if mime.hasUrls():
        for url in mime.urls():
            local_path = url.toLocalFile()
            if os.path.isfile(local_path) and local_path.lower().endswith(IMAGE_EXTS):
                paths.append(local_path)
    return paths


class PhotoItem(QGraphicsObject):
    """
    Elemento grafico interattivo che rappresenta una foto sul canvas.
    Supporta:
    - Ridimensionamento cella tramite maniglie agli angoli (con object-fit: cover automatico),
      corretto anche su foto ruotate
    - Zoom interno e Pan interno (Alt + Trascina, Ctrl + Rotella o tramite slider)
    - Angoli arrotondati, bordo interno personalizzabile e rotazione
    - Snap magnetico a bordi/centri della tela, dei frame e delle altre foto
    """
    geometry_changed = pyqtSignal(object)  # Modifica in corso (per aggiornare l'Inspector)
    edit_finished = pyqtSignal()           # Modifica completata (per Annulla/Ripeti)
    HANDLE_PX = 11.0  # Maniglie di dimensione costante sullo schermo, a qualsiasi zoom
    MIN_CELL = 40.0
    SNAP_PX = 8.0     # Distanza di snap in pixel dello schermo

    _next_uid = 1

    def __init__(self, image_path: str, cell_w: float = 400.0, cell_h: float = 500.0, uid: Optional[int] = None):
        super().__init__()
        self.image_path = image_path
        if uid is None:
            uid = PhotoItem._next_uid
        self.uid = uid
        PhotoItem._next_uid = max(PhotoItem._next_uid, uid + 1)

        # Dimensioni del riquadro/cella della foto sul canvas
        self.cell_w = float(cell_w)
        self.cell_h = float(cell_h)

        # Ordine della foto nei layout automatici (indipendente dallo Z-index)
        self.layout_index = 0

        # Parametri di trasformazione interna (ritaglio / zoom dentro la cella)
        self.inner_zoom = 1.0       # 1.0 = riempie esattamente la cella (object-fit: cover)
        self.pan_x = 0.0            # Offset orizzontale interno (-1.0 a +1.0)
        self.pan_y = 0.0            # Offset verticale interno (-1.0 a +1.0)

        # Stile cornice
        self.border_radius = 0.0
        self.border_width = 0.0
        self.border_color = QColor("#FFFFFF")
        self.auto_border = False    # Bordo aggiunto automaticamente dal layout Polaroid

        # Stato interazione maniglie
        self._resizing_handle: Optional[str] = None
        self._resize_anchor_scene = QPointF()
        self._resize_ratio = 1.0
        self._panning_inner = False
        self._dragging = False
        self._hovered = False
        self._last_mouse_scene_pos = QPointF()
        self.snap_enabled = True

        self.setFlags(
            QGraphicsItem.GraphicsItemFlag.ItemIsMovable |
            QGraphicsItem.GraphicsItemFlag.ItemIsSelectable |
            QGraphicsItem.GraphicsItemFlag.ItemSendsGeometryChanges
        )
        self.setAcceptHoverEvents(True)
        self._update_transform_origin()

    @property
    def pixmap(self) -> QPixmap:
        return IMAGE_CACHE.preview(self.image_path)

    # ---------- Stato (per Annulla/Ripeti e salvataggio progetto) ----------
    def get_state(self) -> dict:
        return {
            "uid": self.uid,
            "path": self.image_path,
            "x": round(self.pos().x(), 3),
            "y": round(self.pos().y(), 3),
            "w": round(self.cell_w, 3),
            "h": round(self.cell_h, 3),
            "rotation": round(self.rotation(), 3),
            "z": self.zValue(),
            "layout_index": self.layout_index,
            "inner_zoom": round(self.inner_zoom, 4),
            "pan_x": round(self.pan_x, 4),
            "pan_y": round(self.pan_y, 4),
            "border_radius": self.border_radius,
            "border_width": self.border_width,
            "border_color": self.border_color.name(QColor.NameFormat.HexArgb),
            "auto_border": self.auto_border,
        }

    def set_state(self, s: dict):
        self.set_cell_size(s["w"], s["h"])
        self.setPos(s["x"], s["y"])
        self.setRotation(s["rotation"])
        self.setZValue(s["z"])
        self.layout_index = s["layout_index"]
        self.inner_zoom = s["inner_zoom"]
        self.pan_x = s["pan_x"]
        self.pan_y = s["pan_y"]
        self.border_radius = s["border_radius"]
        self.border_width = s["border_width"]
        self.border_color = QColor(s["border_color"])
        self.auto_border = s.get("auto_border", False)
        self.update()

    # ---------- Geometria ----------
    def _update_transform_origin(self):
        self.setTransformOriginPoint(self.cell_w / 2.0, self.cell_h / 2.0)

    def set_cell_size(self, w: float, h: float):
        self.prepareGeometryChange()
        self.cell_w = max(self.MIN_CELL, float(w))
        self.cell_h = max(self.MIN_CELL, float(h))
        self._update_transform_origin()
        self.update()

    def view_scale_changed(self):
        # Le maniglie hanno dimensione costante sullo schermo: il boundingRect cambia con lo zoom
        self.prepareGeometryChange()
        self.update()

    def _view_scale(self) -> float:
        scene = self.scene()
        views = scene.views() if scene else []
        return max(0.01, views[0].transform().m11()) if views else 1.0

    def _handle_size(self) -> float:
        return self.HANDLE_PX / self._view_scale()

    def _pos_for_local_point(self, local: QPointF, scene_target: QPointF) -> QPointF:
        """Posizione dell'item tale che il punto locale `local` cada su `scene_target` (rotazione inclusa)."""
        origin = QPointF(self.cell_w / 2.0, self.cell_h / 2.0)
        rotated = QTransform().rotate(self.rotation()).map(local - origin)
        return scene_target - origin - rotated

    def reset_aspect_to_original(self):
        """Adatta il riquadro alle proporzioni originali della foto, mantenendo fisso il centro."""
        pm = self.pixmap
        if pm.width() > 0 and pm.height() > 0:
            center = self.mapToScene(QPointF(self.cell_w / 2.0, self.cell_h / 2.0))
            ratio = pm.width() / pm.height()
            area = self.cell_w * self.cell_h
            new_w = math.sqrt(area * ratio)
            new_h = new_w / ratio
            self.set_cell_size(new_w, new_h)
            self.setPos(center - QPointF(self.cell_w / 2.0, self.cell_h / 2.0))
            self.pan_x = 0.0
            self.pan_y = 0.0
            self.inner_zoom = 1.0
            self.update()

    def zoom_by(self, step: float):
        self.inner_zoom = max(1.0, min(4.0, self.inner_zoom + step))
        self.update()
        self.geometry_changed.emit(self)
        self.edit_finished.emit()

    def _cover_geometry(self, img_w: float, img_h: float) -> Tuple[float, float, float, float, float]:
        """Restituisce (scala, dx, dy, draw_w, draw_h) per object-fit: cover + zoom + pan."""
        scale_cover = max(self.cell_w / img_w, self.cell_h / img_h) * self.inner_zoom
        draw_w = img_w * scale_cover
        draw_h = img_h * scale_cover
        max_dx = max(0.0, (draw_w - self.cell_w) / 2.0)
        max_dy = max(0.0, (draw_h - self.cell_h) / 2.0)
        dx = (self.cell_w - draw_w) / 2.0 + (self.pan_x * max_dx)
        dy = (self.cell_h - draw_h) / 2.0 + (self.pan_y * max_dy)
        return scale_cover, dx, dy, draw_w, draw_h

    def _pan_margins(self) -> Tuple[float, float]:
        pm = self.pixmap
        if pm.width() <= 0 or pm.height() <= 0:
            return 0.0, 0.0
        _, _, _, draw_w, draw_h = self._cover_geometry(float(pm.width()), float(pm.height()))
        return max(0.0, (draw_w - self.cell_w) / 2.0), max(0.0, (draw_h - self.cell_h) / 2.0)

    def boundingRect(self) -> QRectF:
        margin = self._handle_size() + 4.0 / self._view_scale()
        return QRectF(-margin, -margin, self.cell_w + margin * 2, self.cell_h + margin * 2)

    def shape(self) -> QPainterPath:
        # Area cliccabile = solo la foto (+ maniglie se selezionata), non tutto il boundingRect
        path = QPainterPath()
        path.addRect(QRectF(0, 0, self.cell_w, self.cell_h))
        if self.isSelected():
            grow = self._handle_size() * 0.4
            for rect in self._get_handle_rects().values():
                path.addEllipse(rect.adjusted(-grow, -grow, grow, grow))
        return path

    def _get_handle_rects(self) -> dict:
        hs = self._handle_size()
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
        grow = self._handle_size() * 0.4
        for name, rect in self._get_handle_rects().items():
            if rect.adjusted(-grow, -grow, grow, grow).contains(pos):
                return name
        return None

    # ---------- Disegno ----------
    def paint(self, painter: QPainter, option, widget=None):
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, True)

        cell_rect = QRectF(0, 0, self.cell_w, self.cell_h)
        scene = self.scene()
        is_exporting = getattr(scene, "is_exporting", False) if scene else False

        # Creazione percorso con angoli arrotondati
        path = QPainterPath()
        radius = min(self.border_radius, self.cell_w / 2.0, self.cell_h / 2.0)
        path.addRoundedRect(cell_rect, radius, radius)

        painter.save()
        painter.setClipPath(path)
        if is_exporting:
            self._paint_full_resolution(painter, cell_rect)
        else:
            pm = self.pixmap
            img_w, img_h = float(pm.width()), float(pm.height())
            if img_w > 0 and img_h > 0:
                _, dx, dy, draw_w, draw_h = self._cover_geometry(img_w, img_h)
                painter.drawPixmap(QRectF(dx, dy, draw_w, draw_h), pm, QRectF(0, 0, img_w, img_h))
        painter.restore()

        # Bordo interno: non sborda nel gap e non viene tagliato ai margini della tela
        if self.border_width > 0:
            bw = min(self.border_width, self.cell_w / 2.0, self.cell_h / 2.0)
            inner = cell_rect.adjusted(bw / 2.0, bw / 2.0, -bw / 2.0, -bw / 2.0)
            inner_radius = max(0.0, radius - bw / 2.0)
            border_path = QPainterPath()
            border_path.addRoundedRect(inner, inner_radius, inner_radius)
            pen = QPen(self.border_color, bw)
            pen.setJoinStyle(Qt.PenJoinStyle.MiterJoin if inner_radius == 0 else Qt.PenJoinStyle.RoundJoin)
            painter.setPen(pen)
            painter.setBrush(Qt.BrushStyle.NoBrush)
            painter.drawPath(border_path)

        if is_exporting:
            return

        accent = QColor(THEME["accent"])
        if self.isSelected():
            # Contorno di selezione che segue gli angoli arrotondati + maniglie circolari
            sel_pen = QPen(accent, 2.0)
            sel_pen.setCosmetic(True)
            painter.setPen(sel_pen)
            painter.setBrush(Qt.BrushStyle.NoBrush)
            painter.drawPath(path)

            handle_pen = QPen(accent, 2.0)
            handle_pen.setCosmetic(True)
            painter.setPen(handle_pen)
            painter.setBrush(QBrush(QColor("#FFFFFF")))
            for rect in self._get_handle_rects().values():
                painter.drawEllipse(rect)
        elif self._hovered:
            hover = QColor(accent)
            hover.setAlpha(150)
            hover_pen = QPen(hover, 1.5)
            hover_pen.setCosmetic(True)
            painter.setPen(hover_pen)
            painter.setBrush(Qt.BrushStyle.NoBrush)
            painter.drawPath(path)

    def _paint_full_resolution(self, painter: QPainter, cell_rect: QRectF):
        """In esportazione ricampiona dall'originale solo la porzione visibile, alla risoluzione di uscita."""
        full = IMAGE_CACHE.full(self.image_path)
        if full is None:
            pm = self.pixmap
            if pm.width() > 0 and pm.height() > 0:
                _, dx, dy, dw, dh = self._cover_geometry(float(pm.width()), float(pm.height()))
                painter.drawPixmap(QRectF(dx, dy, dw, dh), pm, QRectF(0, 0, pm.width(), pm.height()))
            return

        img_w, img_h = float(full.width), float(full.height)
        scale, dx, dy, draw_w, draw_h = self._cover_geometry(img_w, img_h)
        visible = QRectF(dx, dy, draw_w, draw_h).intersected(cell_rect)
        if visible.isEmpty():
            return

        t = painter.worldTransform()
        device_scale = math.hypot(t.m11(), t.m12()) or 1.0
        out_w = max(1, round(visible.width() * device_scale))
        out_h = max(1, round(visible.height() * device_scale))

        box = (
            max(0.0, (visible.left() - dx) / scale),
            max(0.0, (visible.top() - dy) / scale),
            min(img_w, (visible.right() - dx) / scale),
            min(img_h, (visible.bottom() - dy) / scale),
        )
        resized = full.resize((out_w, out_h), Image.Resampling.LANCZOS, box=box)
        painter.drawImage(visible, pil_to_qimage(resized))

    # ---------- Interazione ----------
    def hoverEnterEvent(self, event):
        self._hovered = True
        self.update()
        super().hoverEnterEvent(event)

    def hoverLeaveEvent(self, event):
        self._hovered = False
        self.update()
        super().hoverLeaveEvent(event)

    def hoverMoveEvent(self, event):
        handle = self._handle_at(event.pos())
        if handle:
            # Il cursore diagonale segue la rotazione della foto
            angle = (self.rotation() + (45 if handle in ("tl", "br") else -45)) % 180
            if 22.5 <= angle < 67.5:
                diag = Qt.CursorShape.SizeFDiagCursor
            elif 67.5 <= angle < 112.5:
                diag = Qt.CursorShape.SizeVerCursor
            elif 112.5 <= angle < 157.5:
                diag = Qt.CursorShape.SizeBDiagCursor
            else:
                diag = Qt.CursorShape.SizeHorCursor
            self.setCursor(QCursor(diag))
        else:
            self.setCursor(QCursor(Qt.CursorShape.OpenHandCursor))
        super().hoverMoveEvent(event)

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            handle = self._handle_at(event.pos())
            if handle:
                self._resizing_handle = handle
                anchor_local = QPointF(
                    0.0 if "r" in handle else self.cell_w,
                    0.0 if "b" in handle else self.cell_h,
                )
                self._resize_anchor_scene = self.mapToScene(anchor_local)
                self._resize_ratio = self.cell_w / self.cell_h if self.cell_h > 0 else 1.0
                event.accept()
                return
            elif event.modifiers() & Qt.KeyboardModifier.AltModifier:
                # Alt + Trascina sposta l'inquadratura interna della foto (Pan interno)
                self._panning_inner = True
                self._last_mouse_scene_pos = event.scenePos()
                max_dx, max_dy = self._pan_margins()
                if max_dx < 0.5 and max_dy < 0.5:
                    # Foto con le stesse proporzioni della cella: serve un po' di zoom per poterla spostare
                    self.inner_zoom = max(self.inner_zoom, 1.15)
                self.setCursor(QCursor(Qt.CursorShape.SizeAllCursor))
                event.accept()
                return
            self._dragging = True
            self.setCursor(QCursor(Qt.CursorShape.ClosedHandCursor))
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if self._resizing_handle:
            self._resize_to(event.scenePos(), bool(event.modifiers() & Qt.KeyboardModifier.ShiftModifier))
            event.accept()
            return

        if self._panning_inner:
            delta = event.scenePos() - self._last_mouse_scene_pos
            self._last_mouse_scene_pos = event.scenePos()
            # Il pan segue esattamente il cursore, nel sistema di riferimento (ruotato) della foto
            local = QTransform().rotate(-self.rotation()).map(delta)
            max_dx, max_dy = self._pan_margins()
            if max_dx > 0.5:
                self.pan_x = max(-1.0, min(1.0, self.pan_x + local.x() / max_dx))
            if max_dy > 0.5:
                self.pan_y = max(-1.0, min(1.0, self.pan_y + local.y() / max_dy))
            self.update()
            self.geometry_changed.emit(self)
            event.accept()
            return

        super().mouseMoveEvent(event)
        if self._dragging:
            self._apply_snap()
            self.geometry_changed.emit(self)

    def _resize_to(self, scene_pos: QPointF, keep_ratio: bool):
        handle = self._resizing_handle
        sx = 1.0 if "r" in handle else -1.0
        sy = 1.0 if "b" in handle else -1.0
        local = QTransform().rotate(-self.rotation()).map(scene_pos - self._resize_anchor_scene)
        new_w = max(self.MIN_CELL, sx * local.x())
        new_h = max(self.MIN_CELL, sy * local.y())

        if keep_ratio:
            ratio = self._resize_ratio
            if new_w / ratio >= new_h:
                new_h = new_w / ratio
            else:
                new_w = new_h * ratio

        self.set_cell_size(new_w, new_h)
        anchor_local = QPointF(0.0 if sx > 0 else self.cell_w, 0.0 if sy > 0 else self.cell_h)
        self.setPos(self._pos_for_local_point(anchor_local, self._resize_anchor_scene))
        self.geometry_changed.emit(self)

    def _apply_snap(self):
        """Snap magnetico ai bordi/centri di tela, frame e altre foto. Sposta insieme tutta la selezione."""
        scene = self.scene()
        if not (self.snap_enabled and scene and hasattr(scene, "canvas_rect")):
            if scene is not None and hasattr(scene, "set_snap_lines"):
                scene.set_snap_lines([], [])
            return

        snap_dist = self.SNAP_PX / self._view_scale()

        canvas = scene.canvas_rect()
        targets_x = []
        targets_y = [canvas.top(), canvas.center().y(), canvas.bottom()]
        for i in range(scene.num_frames + 1):
            fx = i * scene.frame_w
            targets_x.append(fx)
            if i < scene.num_frames:
                targets_x.append(fx + scene.frame_w / 2.0)

        for other in scene.items():
            if isinstance(other, PhotoItem) and not other.isSelected():
                r = other.mapRectToScene(QRectF(0, 0, other.cell_w, other.cell_h))
                targets_x += [r.left(), r.center().x(), r.right()]
                targets_y += [r.top(), r.center().y(), r.bottom()]

        me = self.mapRectToScene(QRectF(0, 0, self.cell_w, self.cell_h))

        def best_offset(edges, targets):
            best = None
            for e in edges:
                for t in targets:
                    d = t - e
                    if abs(d) < snap_dist and (best is None or abs(d) < abs(best[0])):
                        best = (d, t)
            return best

        bx = best_offset([me.left(), me.center().x(), me.right()], targets_x)
        by = best_offset([me.top(), me.center().y(), me.bottom()], targets_y)
        off_x = bx[0] if bx else 0.0
        off_y = by[0] if by else 0.0

        if off_x or off_y:
            for it in scene.selectedItems():
                if isinstance(it, PhotoItem):
                    it.moveBy(off_x, off_y)
            if not self.isSelected():
                self.moveBy(off_x, off_y)
        scene.set_snap_lines([bx[1]] if bx else [], [by[1]] if by else [])

    def mouseReleaseEvent(self, event):
        was_editing = self._resizing_handle or self._panning_inner or self._dragging
        self._resizing_handle = None
        self._panning_inner = False
        self._dragging = False
        self.setCursor(QCursor(Qt.CursorShape.OpenHandCursor))
        scene = self.scene()
        if scene is not None and hasattr(scene, "set_snap_lines"):
            scene.set_snap_lines([], [])
        super().mouseReleaseEvent(event)
        if was_editing:
            self.geometry_changed.emit(self)
            self.edit_finished.emit()


class CollageScene(QGraphicsScene):
    """
    Scena grafica che gestisce la tela del collage (in formato 3:4 o altro),
    lo sfondo, i frame multipli stile SCRL e le linee guida.
    La scena è più grande della tela, così si può fare pan/zoom e recuperare foto finite fuori.
    """
    DOT_SPACING = 24

    def __init__(self, parent=None):
        super().__init__(parent)
        self.frame_w = 1080
        self.frame_h = 1440  # Default 3:4
        self.num_frames = 1
        self.bg_color = QColor("#FFFFFF")
        self.show_guides = True
        self.is_exporting = False
        self._snap_x: List[float] = []
        self._snap_y: List[float] = []
        self._dot_tile = self._make_dot_tile()
        self._empty_icon_dark = _icon_pixmap("image", "#55526A", 44)
        self._empty_icon_light = _icon_pixmap("image", "#C9C6D8", 44)
        self.update_canvas_rect()

    def _make_dot_tile(self) -> QPixmap:
        # Piano di lavoro "tappetino da taglio": puntini regolari in coordinate schermo
        s = self.DOT_SPACING
        tile = QPixmap(s, s)
        tile.fill(QColor(THEME["backdrop"]))
        p = QPainter(tile)
        p.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        p.setPen(Qt.PenStyle.NoPen)
        p.setBrush(QColor(255, 255, 255, 38))
        p.drawEllipse(QPointF(s / 2.0, s / 2.0), 1.2, 1.2)
        p.end()
        return tile

    def canvas_rect(self) -> QRectF:
        return QRectF(0, 0, self.frame_w * self.num_frames, self.frame_h)

    def update_canvas_rect(self):
        canvas = self.canvas_rect()
        pad = max(self.frame_w, self.frame_h)
        self.setSceneRect(canvas.adjusted(-pad, -pad, pad, pad))
        self.update()

    def set_snap_lines(self, xs: List[float], ys: List[float]):
        if xs != self._snap_x or ys != self._snap_y:
            self._snap_x, self._snap_y = xs, ys
            self.update()

    def drawBackground(self, painter: QPainter, rect: QRectF):
        canvas_rect = self.canvas_rect()
        if not self.is_exporting:
            t = painter.worldTransform()
            painter.save()
            painter.resetTransform()
            # Puntini ancorati alla tela, così scorrono insieme al pan
            brush = QBrush(self._dot_tile)
            origin = t.map(QPointF(0, 0))
            brush.setTransform(QTransform.fromTranslate(origin.x() % self.DOT_SPACING, origin.y() % self.DOT_SPACING))
            painter.fillRect(t.mapRect(rect), brush)

            # Ombra morbida a strati sotto la tela (come una stampa appoggiata sul tavolo)
            canvas_dev = t.mapRect(canvas_rect)
            painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
            painter.setPen(Qt.PenStyle.NoPen)
            for i in range(1, 16):
                painter.setBrush(QColor(0, 0, 0, 9))
                painter.drawRoundedRect(canvas_dev.adjusted(-i, -i + 6, i, i + 6), i, i)
            painter.restore()
        painter.fillRect(canvas_rect, self.bg_color)

    def drawForeground(self, painter: QPainter, rect: QRectF):
        if self.is_exporting:
            return

        canvas_rect = self.canvas_rect()

        # Le foto che escono dalla tela restano visibili ma attenuate
        outer_path = QPainterPath()
        outer_path.addRect(rect)
        inner_path = QPainterPath()
        inner_path.addRect(canvas_rect)
        veil = QColor(THEME["backdrop"])
        veil.setAlpha(175)
        painter.fillPath(outer_path.subtracted(inner_path), veil)

        light_bg = is_light(self.bg_color)
        has_photos = any(isinstance(it, PhotoItem) for it in self.items())
        if self.show_guides and has_photos:
            # Linee guida centrali leggere
            guide = QColor(0, 0, 0, 40) if light_bg else QColor(255, 255, 255, 45)
            guide_pen = QPen(guide, 1.0, Qt.PenStyle.DashLine)
            guide_pen.setCosmetic(True)
            painter.setPen(guide_pen)
            painter.drawLine(QPointF(0, self.frame_h / 2.0), QPointF(canvas_rect.width(), self.frame_h / 2.0))
            for i in range(self.num_frames):
                cx = i * self.frame_w + self.frame_w / 2.0
                painter.drawLine(QPointF(cx, 0), QPointF(cx, self.frame_h))

        # Giunzioni tra le pagine del carosello: sempre visibili, nel colore d'accento
        if self.num_frames > 1:
            sep_pen = QPen(QColor(THEME["accent"]), 1.5, Qt.PenStyle.DashLine)
            sep_pen.setCosmetic(True)
            painter.setPen(sep_pen)
            for i in range(1, self.num_frames):
                x = i * self.frame_w
                painter.drawLine(QPointF(x, 0), QPointF(x, self.frame_h))

        # Linee di snap attive durante il trascinamento
        if self._snap_x or self._snap_y:
            snap_pen = QPen(QColor(THEME["snap"]), 1.2)
            snap_pen.setCosmetic(True)
            painter.setPen(snap_pen)
            for x in self._snap_x:
                painter.drawLine(QPointF(x, rect.top()), QPointF(x, rect.bottom()))
            for y in self._snap_y:
                painter.drawLine(QPointF(rect.left(), y), QPointF(rect.right(), y))

        # Etichette delle pagine e stato vuoto, disegnati in coordinate schermo
        t = painter.worldTransform()
        painter.save()
        painter.resetTransform()
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        painter.setRenderHint(QPainter.RenderHint.TextAntialiasing, True)
        painter.setFont(ui_font(12, QFont.Weight.DemiBold))
        for i in range(self.num_frames):
            top_left = t.map(QPointF(i * self.frame_w, 0))
            label = f"Pagina {i + 1}" if self.num_frames > 1 else f"{self.frame_w} × {self.frame_h} px"
            painter.setPen(QColor(THEME["muted"]))
            painter.drawText(QPointF(top_left.x() + 2, top_left.y() - 10), label)

        if not has_photos:
            canvas_dev = t.mapRect(canvas_rect)
            if canvas_dev.width() > 220 and canvas_dev.height() > 160:
                c = canvas_dev.center()
                icon = self._empty_icon_light if not light_bg else self._empty_icon_dark
                painter.drawPixmap(QPointF(c.x() - 22, c.y() - 58), icon)
                painter.setPen(QColor("#3A3748") if light_bg else QColor(THEME["text"]))
                painter.setFont(ui_font(19, QFont.Weight.DemiBold, "display"))
                painter.drawText(QRectF(canvas_dev.left(), c.y() - 4, canvas_dev.width(), 30),
                                 Qt.AlignmentFlag.AlignHCenter, "Trascina qui le tue foto")
                painter.setPen(QColor("#7A7690") if light_bg else QColor(THEME["muted"]))
                painter.setFont(ui_font(13))
                painter.drawText(QRectF(canvas_dev.left(), c.y() + 28, canvas_dev.width(), 24),
                                 Qt.AlignmentFlag.AlignHCenter, "oppure usa Aggiungi foto (Ctrl+O)")
        painter.restore()


class CanvasView(QGraphicsView):
    """
    Vista interattiva con supporto Zoom con rotella, Pan con tasto centrale
    e Drag-and-Drop diretto di file immagine dal PC.
    """
    files_dropped = pyqtSignal(list)
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
        self.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.setFrameShape(QFrame.Shape.NoFrame)
        self.setAcceptDrops(True)
        self._panning = False
        self._pan_start = QPointF()

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
            self.horizontalScrollBar().setValue(self.horizontalScrollBar().value() - int(delta.x()))
            self.verticalScrollBar().setValue(self.verticalScrollBar().value() - int(delta.y()))
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
            paths = image_paths_from_mime(event.mimeData())
            if paths:
                self.files_dropped.emit(paths)
            event.acceptProposedAction()
        else:
            super().dropEvent(event)


# ================= WIDGET PERSONALIZZATI =================
class ToggleSwitch(QCheckBox):
    """Interruttore a levetta al posto della classica casella di spunta."""
    TRACK_W, TRACK_H = 32, 18

    def __init__(self, text: str, parent=None):
        super().__init__(text, parent)
        self.setCursor(Qt.CursorShape.PointingHandCursor)

    def sizeHint(self) -> QSize:
        fm = self.fontMetrics()
        return QSize(self.TRACK_W + 10 + fm.horizontalAdvance(self.text()), max(self.TRACK_H + 4, fm.height() + 6))

    def hitButton(self, pos) -> bool:
        return self.rect().contains(pos)

    def paintEvent(self, event):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        y = (self.height() - self.TRACK_H) / 2.0
        track = QRectF(0, y, self.TRACK_W, self.TRACK_H)
        on = self.isChecked()
        track_color = QColor(THEME["accent"] if on else THEME["hover"])
        if not self.isEnabled():
            track_color.setAlphaF(0.4)
        p.setPen(Qt.PenStyle.NoPen)
        p.setBrush(track_color)
        p.drawRoundedRect(track, self.TRACK_H / 2.0, self.TRACK_H / 2.0)
        knob_x = self.TRACK_W - self.TRACK_H + 2 if on else 2
        p.setBrush(QColor(THEME["accent_ink"] if on else THEME["text"]))
        p.drawEllipse(QRectF(knob_x, y + 2, self.TRACK_H - 4, self.TRACK_H - 4))
        p.setPen(QColor(THEME["text"] if self.isEnabled() else THEME["faint"]))
        p.drawText(QRectF(self.TRACK_W + 10, 0, self.width() - self.TRACK_W - 10, self.height()),
                   Qt.AlignmentFlag.AlignVCenter | Qt.AlignmentFlag.AlignLeft, self.text())
        if self.hasFocus():
            focus = QPen(QColor(THEME["accent"]), 1.2)
            p.setPen(focus)
            p.setBrush(Qt.BrushStyle.NoBrush)
            p.drawRoundedRect(track.adjusted(-2, -2, 2, 2), self.TRACK_H / 2.0 + 2, self.TRACK_H / 2.0 + 2)
        p.end()


class DropZone(QFrame):
    """Stato vuoto della libreria: area tratteggiata cliccabile che invita a caricare le foto."""
    clicked = pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setMinimumHeight(190)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self._icon = _icon_pixmap("image", THEME["muted"], 34)
        self._hover = False

    def enterEvent(self, event):
        self._hover = True
        self.update()

    def leaveEvent(self, event):
        self._hover = False
        self.update()

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self.clicked.emit()

    def paintEvent(self, event):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        r = QRectF(self.rect()).adjusted(1, 1, -1, -1)
        pen = QPen(QColor(THEME["accent"] if self._hover else THEME["line"]), 1.5, Qt.PenStyle.DashLine)
        pen.setDashPattern([4, 4])
        p.setPen(pen)
        p.setBrush(QColor(THEME["raised"]) if self._hover else Qt.BrushStyle.NoBrush)
        p.drawRoundedRect(r, 12, 12)
        c = r.center()
        p.drawPixmap(QPointF(c.x() - 17, c.y() - 46), self._icon)
        p.setPen(QColor(THEME["text"]))
        p.setFont(ui_font(14, QFont.Weight.DemiBold))
        p.drawText(QRectF(r.left(), c.y() - 4, r.width(), 22), Qt.AlignmentFlag.AlignHCenter, "Trascina qui le foto")
        p.setPen(QColor(THEME["muted"]))
        p.setFont(ui_font(12))
        p.drawText(QRectF(r.left() + 16, c.y() + 20, r.width() - 32, 40),
                   Qt.AlignmentFlag.AlignHCenter | Qt.TextFlag.TextWordWrap,
                   "oppure clicca per sceglierle dal PC.\nNessun limite di numero.")
        p.end()


class MainWindow(QMainWindow):
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
    HISTORY_LIMIT = 100

    def __init__(self):
        super().__init__()
        self.resize(1520, 940)
        self.setMinimumSize(1100, 680)
        self.setAcceptDrops(True)

        self.loaded_library: List[str] = []
        self.current_layout_mode = "grid"  # "grid", "mosaic", "strips_h", "strips_v", "scatter", "scrl_seam"
        self._layout_seed = random.randrange(1 << 30)
        self._updating_inspector = False
        self._restoring = False
        self.project_path: Optional[str] = None

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

    def _build_ui(self):
        central = QWidget()
        central.setObjectName("Root")
        central.setAttribute(Qt.WidgetAttribute.WA_StyledBackground, True)
        self.setCentralWidget(central)
        root = QVBoxLayout(central)
        root.setContentsMargins(14, 10, 14, 4)
        root.setSpacing(10)

        root.addLayout(self._build_top_bar())

        splitter = QSplitter(Qt.Orientation.Horizontal)
        splitter.setHandleWidth(12)
        splitter.setChildrenCollapsible(False)
        splitter.addWidget(self._scroll_panel(self._build_left_panel(), 312))
        splitter.addWidget(self.view)
        splitter.addWidget(self._scroll_panel(self._build_inspector(), 300))
        splitter.setStretchFactor(0, 0)
        splitter.setStretchFactor(1, 1)
        splitter.setStretchFactor(2, 0)
        root.addWidget(splitter, 1)

    def _build_top_bar(self) -> QHBoxLayout:
        bar = QHBoxLayout()
        bar.setSpacing(10)

        logo = QLabel()
        logo.setPixmap(_icon_pixmap("logo", THEME["accent"], 26))
        bar.addWidget(logo)
        bar.addWidget(self._label("SCRL Studio", "Brand"))
        bar.addSpacing(8)
        bar.addWidget(self._vsep())
        bar.addSpacing(4)

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
        # Numero di pagine (1 = collage singolo, 2+ = carosello SCRL)
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
        self.btn_bg_color.setIcon(swatch_icon(self.scene.bg_color))
        self.btn_bg_color.setToolTip("Colore di sfondo della tela")
        self.btn_bg_color.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_bg_color.clicked.connect(self._pick_bg_color)
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

        # Qualità ed esportazione
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

    def _build_left_panel(self) -> QWidget:
        panel = QWidget()
        lay = QVBoxLayout(panel)
        lay.setContentsMargins(16, 16, 16, 16)
        lay.setSpacing(10)

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
        self.list_library.setViewMode(QListView.ViewMode.IconMode)
        self.list_library.setIconSize(QSize(80, 80))
        self.list_library.setGridSize(QSize(88, 88))
        self.list_library.setResizeMode(QListView.ResizeMode.Adjust)
        self.list_library.setMovement(QListView.Movement.Static)
        self.list_library.setUniformItemSizes(True)
        self.list_library.setSelectionMode(QListWidget.SelectionMode.ExtendedSelection)
        self.list_library.setMinimumHeight(200)
        self.list_library.setToolTip("Doppio clic per aggiungere la foto alla tela.\nClic destro per altre opzioni.")
        self.list_library.itemDoubleClicked.connect(self._on_library_item_double_clicked)
        self.list_library.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.list_library.customContextMenuRequested.connect(self._show_library_context_menu)
        self.library_stack.addWidget(self.list_library)
        lay.addWidget(self.library_stack, 1)

        lib_btns = QHBoxLayout()
        lib_btns.setSpacing(6)
        self.btn_add_all = self._button("Metti tutte sulla tela", self.add_all_library_to_canvas, obj="Ghost")
        self.btn_clear_canvas = self._button("Svuota tela", self.clear_canvas_photos, obj="Ghost")
        lib_btns.addWidget(self.btn_add_all)
        lib_btns.addWidget(self.btn_clear_canvas)
        lay.addLayout(lib_btns)

        lay.addSpacing(6)
        lay.addWidget(self._divider())
        lay.addSpacing(6)

        # --- Disposizione ---
        self._section_header(lay, "Disposizione")
        tiles = QGridLayout()
        tiles.setSpacing(8)
        self.layout_group = QButtonGroup(self)
        self.layout_group.setExclusive(True)
        self.layout_tiles: Dict[str, QToolButton] = {}
        for i, (mode, text, tip) in enumerate(self.LAYOUTS):
            tile = QToolButton()
            tile.setObjectName("LayoutTile")
            tile.setText(text)
            tile.setToolTip(tip)
            icon_name = "seam" if mode == "scrl_seam" else mode
            tile.setIcon(make_icon(icon_name, THEME["muted"], 30, on_color=THEME["accent"]))
            tile.setIconSize(QSize(30, 30))
            tile.setToolButtonStyle(Qt.ToolButtonStyle.ToolButtonTextUnderIcon)
            tile.setCheckable(True)
            tile.setCursor(Qt.CursorShape.PointingHandCursor)
            tile.setFixedHeight(72)
            tile.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)
            tile.clicked.connect(lambda _checked=False, m=mode: self._on_layout_button(m))
            self.layout_group.addButton(tile)
            self.layout_tiles[mode] = tile
            tiles.addWidget(tile, i // 3, i % 3)
        lay.addLayout(tiles)

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
        self.slider_gap = self._make_slider(lay, "Spaziatura", 0, 80, 16, " px")
        self.slider_gap.valueChanged.connect(self._relayout_keep)
        self.slider_margin = self._make_slider(lay, "Margine", 0, 120, 24, " px")
        self.slider_margin.valueChanged.connect(self._relayout_keep)

        lay.addSpacing(4)
        action_btns = QHBoxLayout()
        action_btns.setSpacing(6)
        action_btns.addWidget(self._button("Rimescola", self.shuffle_canvas_photos, "shuffle",
                                           tooltip="Cambia a caso quale foto va in quale posizione"))
        action_btns.addWidget(self._button("Scambia due", self.swap_two_selected_photos, "swap",
                                           tooltip="Seleziona 2 foto (Ctrl+clic sulla seconda) e scambiale di posto"))
        lay.addLayout(action_btns)
        return panel

    def _build_inspector(self) -> QWidget:
        panel = QWidget()
        outer = QVBoxLayout(panel)
        outer.setContentsMargins(16, 16, 16, 16)
        outer.setSpacing(0)

        self.insp_stack = QStackedWidget()
        outer.addWidget(self.insp_stack)

        # Pagina vuota: nessuna selezione
        empty = QWidget()
        el = QVBoxLayout(empty)
        el.setContentsMargins(4, 40, 4, 0)
        el.setSpacing(10)
        empty_icon = QLabel()
        empty_icon.setPixmap(_icon_pixmap("image", THEME["faint"], 40))
        empty_icon.setAlignment(Qt.AlignmentFlag.AlignHCenter)
        el.addWidget(empty_icon)
        title = self._label("Nessuna foto selezionata", "EmptyTitle")
        title.setAlignment(Qt.AlignmentFlag.AlignHCenter)
        el.addWidget(title)
        body = self._label("Clicca una foto sulla tela per regolarne inquadratura, rotazione e cornice.\n\n"
                           "Ctrl+clic per selezionarne più di una: le modifiche valgono per tutte.", "Hint")
        body.setWordWrap(True)
        body.setAlignment(Qt.AlignmentFlag.AlignHCenter)
        el.addWidget(body)
        el.addStretch()
        self.insp_stack.addWidget(empty)

        # Pagina di modifica
        self.insp_controls = QWidget()
        lay = QVBoxLayout(self.insp_controls)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(10)

        head = QHBoxLayout()
        head.setSpacing(12)
        self.lbl_selection_thumb = QLabel()
        self.lbl_selection_thumb.setFixedSize(52, 52)
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

        lay.addSpacing(4)
        lay.addWidget(self._divider())
        lay.addSpacing(4)

        # Ogni slider modifica SOLO la sua proprietà, su tutte le foto selezionate
        self._section_header(lay, "Inquadratura")
        self.slider_inner_zoom = self._make_slider(lay, "Zoom", 100, 400, 100, "%")
        self.slider_inner_zoom.valueChanged.connect(lambda v: self._on_inspector_slider("zoom", v))
        self.slider_pan_x = self._make_slider(lay, "Orizzontale", -100, 100, 0, signed=True)
        self.slider_pan_x.valueChanged.connect(lambda v: self._on_inspector_slider("pan_x", v))
        self.slider_pan_y = self._make_slider(lay, "Verticale", -100, 100, 0, signed=True)
        self.slider_pan_y.valueChanged.connect(lambda v: self._on_inspector_slider("pan_y", v))
        lay.addWidget(self._button("Usa le proporzioni della foto", self._restore_selected_original_ratio, "ratio", "Ghost",
                                   "Adatta il riquadro alle proporzioni originali dello scatto"))

        lay.addSpacing(4)
        self._section_header(lay, "Rotazione")
        self.slider_rotation = self._make_slider(lay, "Angolo", -180, 180, 0, "°", signed=True)
        self.slider_rotation.valueChanged.connect(lambda v: self._on_inspector_slider("rotation", v))
        rot_btns = QHBoxLayout()
        rot_btns.setSpacing(6)
        rot_btns.addWidget(self._icon_button("rot_left", "Ruota di 90° a sinistra", lambda: self._rotate_selected_by(-90), "90° sx", "SoftButton"))
        rot_btns.addWidget(self._icon_button("level", "Raddrizza (0°)", lambda: self._set_selected_rotation(0), "Dritta", "SoftButton"))
        rot_btns.addWidget(self._icon_button("rot_right", "Ruota di 90° a destra", lambda: self._rotate_selected_by(90), "90° dx", "SoftButton"))
        lay.addLayout(rot_btns)

        lay.addSpacing(4)
        self._section_header(lay, "Cornice")
        self.slider_radius = self._make_slider(lay, "Angoli arrotondati", 0, 200, 0, " px")
        self.slider_radius.valueChanged.connect(lambda v: self._on_inspector_slider("radius", v))
        self.slider_border = self._make_slider(lay, "Spessore bordo", 0, 40, 0, " px")
        self.slider_border.valueChanged.connect(lambda v: self._on_inspector_slider("border", v))
        style_btns = QHBoxLayout()
        style_btns.setSpacing(6)
        self.btn_border_color = self._icon_button("plus", "Colore del bordo", self._pick_photo_border_color, "Colore", "SoftButton")
        self.btn_border_color.setIcon(swatch_icon(QColor("#FFFFFF")))
        style_btns.addWidget(self.btn_border_color)
        style_btns.addWidget(self._button("Applica a tutte", self._apply_style_to_all_photos, obj="Ghost",
                                          tooltip="Copia angoli, bordo e colore su tutte le foto della tela"))
        lay.addLayout(style_btns)

        lay.addSpacing(4)
        self._section_header(lay, "Livello")
        z_btns = QHBoxLayout()
        z_btns.setSpacing(6)
        z_btns.addWidget(self._icon_button("front", "Porta sopra le altre foto", self._bring_to_front, "Davanti", "SoftButton"))
        z_btns.addWidget(self._icon_button("back", "Manda sotto le altre foto", self._send_to_back, "Dietro", "SoftButton"))
        lay.addLayout(z_btns)

        lay.addSpacing(8)
        lay.addWidget(self._divider())
        lay.addSpacing(4)
        foot = QHBoxLayout()
        foot.setSpacing(6)
        foot.addWidget(self._button("Duplica", self._duplicate_selected, "duplicate", tooltip="Ctrl+D"))
        foot.addWidget(self._button("Elimina", self._delete_selected, "trash", "Danger", tooltip="Canc"))
        lay.addLayout(foot)
        lay.addStretch()

        self.insp_stack.addWidget(self.insp_controls)
        outer.addStretch()
        return panel

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
                     signed: bool = False) -> QSlider:
        """Riga con titolo e valore corrente (a destra), seguita dallo slider."""
        row = QHBoxLayout()
        row.setContentsMargins(0, 2, 0, 0)
        row.addWidget(self._label(title))
        row.addStretch()
        chip = self._label("", "ValueChip")
        row.addWidget(chip)
        slider = QSlider(Qt.Orientation.Horizontal)
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
        layout.addLayout(row)
        layout.addWidget(slider)
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
        make("Seleziona tutte", self._select_all, QKeySequence.StandardKey.SelectAll, m_edit)
        m_edit.addSeparator()
        make("Rimescola ordine foto", self.shuffle_canvas_photos, None, m_edit)
        make("Scambia 2 selezionate", self.swap_two_selected_photos, None, m_edit)

        m_view = menubar.addMenu("&Vista")
        make("Adatta alla finestra", self.fit_canvas_in_view, QKeySequence("Ctrl+0"), m_view)

        # Scorciatoie solo-tela: Elimina e spostamento fine con le frecce (Shift = 10 px)
        make("Elimina", self._delete_selected, [QKeySequence(Qt.Key.Key_Delete), QKeySequence(Qt.Key.Key_Backspace)], target=self.view)
        for key, dx, dy in ((Qt.Key.Key_Left, -1, 0), (Qt.Key.Key_Right, 1, 0), (Qt.Key.Key_Up, 0, -1), (Qt.Key.Key_Down, 0, 1)):
            make("", lambda _c=False, a=dx, b=dy: self._nudge_selected(a, b), QKeySequence(key), target=self.view)
            make("", lambda _c=False, a=dx, b=dy: self._nudge_selected(a * 10, b * 10),
                 QKeySequence(QKeyCombination(Qt.KeyboardModifier.ShiftModifier, key)), target=self.view)
        self._update_undo_actions()

    def _apply_theme(self):
        qss = """
            QWidget {
                color: @text;
                font-family: '@font';
                font-size: 13px;
            }
            QMainWindow, #Root {
                background-color: @backdrop;
            }
            QToolTip {
                background-color: @raised;
                color: @text;
                border: 1px solid @line;
                border-radius: 6px;
                padding: 6px 8px;
            }

            /* ---- Barra dei menu e menu ---- */
            QMenuBar {
                background-color: @backdrop;
                color: @muted;
                padding: 2px 8px;
            }
            QMenuBar::item {
                padding: 5px 10px;
                border-radius: 6px;
                background: transparent;
            }
            QMenuBar::item:selected {
                background-color: @raised;
                color: @text;
            }
            QMenu {
                background-color: @panel;
                border: 1px solid @line;
                border-radius: 10px;
                padding: 6px;
            }
            QMenu::item {
                padding: 7px 18px 7px 12px;
                border-radius: 6px;
            }
            QMenu::item:selected {
                background-color: @hover;
            }
            QMenu::item:disabled {
                color: @faint;
            }
            QMenu::separator {
                height: 1px;
                background: @line;
                margin: 5px 6px;
            }

            /* ---- Pannelli ---- */
            #PanelScroll, #PanelScroll > QWidget {
                background: transparent;
            }
            QWidget#Panel {
                background-color: @panel;
                border-radius: 14px;
            }
            QSplitter::handle {
                background: transparent;
            }
            #Divider {
                background-color: @line;
            }
            #VSep {
                background-color: @line;
            }

            /* ---- Testi ---- */
            #Brand {
                font-family: '@display';
                font-size: 17px;
                font-weight: 600;
                color: @text;
            }
            #SectionTitle {
                font-family: '@display';
                font-size: 15px;
                font-weight: 600;
                color: @text;
            }
            #FieldLabel {
                color: @muted;
            }
            #Hint {
                color: @muted;
                font-size: 12px;
            }
            #EmptyTitle {
                font-family: '@display';
                font-size: 15px;
                font-weight: 600;
            }
            #SelName {
                font-weight: 600;
                font-size: 14px;
            }
            #ValueChip {
                color: @text;
                background-color: @raised;
                border-radius: 6px;
                padding: 1px 7px;
                font-size: 12px;
            }
            #StatusText {
                color: @muted;
                font-size: 12px;
                padding: 0 6px;
            }
            QStatusBar {
                background-color: @backdrop;
                padding: 2px 10px 4px 10px;
            }
            QStatusBar::item {
                border: none;
            }

            /* ---- Pulsanti ---- */
            QPushButton {
                background-color: @raised;
                border: none;
                border-radius: 9px;
                padding: 8px 12px;
                font-weight: 500;
            }
            QPushButton:hover {
                background-color: @hover;
            }
            QPushButton:pressed {
                background-color: @line;
            }
            QPushButton:disabled {
                color: @faint;
            }
            QPushButton:focus {
                outline: none;
            }
            QPushButton#Primary {
                background-color: @accent;
                color: @accent_ink;
                font-weight: 600;
                padding: 8px 18px;
            }
            QPushButton#Primary:hover {
                background-color: @accent_hover;
            }
            QPushButton#Primary::menu-indicator {
                image: none;
                width: 0;
            }
            QPushButton#Ghost {
                background-color: transparent;
                border: 1px solid @line;
                color: @muted;
            }
            QPushButton#Ghost:hover {
                background-color: @raised;
                color: @text;
            }
            QPushButton#Danger {
                background-color: transparent;
                border: 1px solid @line;
                color: @danger;
            }
            QPushButton#Danger:hover {
                background-color: rgba(240, 100, 111, 0.14);
                border-color: @danger;
            }
            QToolButton {
                border: none;
                background: transparent;
            }
            QToolButton#IconButton {
                border-radius: 7px;
                padding: 4px 6px;
                color: @text;
            }
            QToolButton#IconButton:hover {
                background-color: @raised;
            }
            QToolButton#ToggleButton {
                border-radius: 8px;
                padding: 5px 10px;
                color: @muted;
            }
            QToolButton#ToggleButton:hover {
                background-color: @raised;
            }
            QToolButton#ToggleButton:checked {
                color: @text;
                background-color: rgba(244, 182, 63, 0.13);
            }
            QToolButton#SoftButton {
                background-color: @raised;
                border-radius: 9px;
                padding: 7px 8px;
                color: @text;
            }
            QToolButton#SoftButton:hover {
                background-color: @hover;
            }
            QToolButton#LayoutTile {
                background-color: @raised;
                border: 1.5px solid transparent;
                border-radius: 12px;
                padding: 6px 2px 4px 2px;
                color: @muted;
                font-size: 12px;
            }
            QToolButton#LayoutTile:hover {
                background-color: @hover;
                color: @text;
            }
            QToolButton#LayoutTile:checked {
                background-color: rgba(244, 182, 63, 0.12);
                border-color: @accent;
                color: @text;
                font-weight: 600;
            }

            /* ---- Campi ---- */
            QComboBox, QSpinBox {
                background-color: @raised;
                border: 1px solid transparent;
                border-radius: 9px;
                padding: 6px 10px;
                min-height: 18px;
            }
            QComboBox:hover, QSpinBox:hover {
                background-color: @hover;
            }
            QComboBox:focus, QSpinBox:focus {
                border-color: @accent;
            }
            QComboBox::drop-down {
                border: none;
                width: 22px;
            }
            QComboBox QAbstractItemView {
                background-color: @panel;
                border: 1px solid @line;
                border-radius: 8px;
                padding: 4px;
                outline: none;
                selection-background-color: @hover;
                selection-color: @text;
            }

            /* ---- Libreria a miniature ---- */
            QListWidget {
                background-color: transparent;
                border: none;
                outline: none;
            }
            QListWidget::item {
                border-radius: 10px;
                padding: 2px;
            }
            QListWidget::item:hover {
                background-color: @raised;
            }
            QListWidget::item:selected {
                background-color: rgba(244, 182, 63, 0.22);
            }

            /* ---- Slider ---- */
            QSlider {
                min-height: 22px;
            }
            QSlider::groove:horizontal {
                height: 4px;
                background: @hover;
                border-radius: 2px;
            }
            QSlider::sub-page:horizontal {
                background: @accent;
                border-radius: 2px;
            }
            QSlider::handle:horizontal {
                background: #FFFFFF;
                width: 14px;
                height: 14px;
                margin: -5px 0;
                border-radius: 7px;
            }
            QSlider::handle:horizontal:hover {
                background: @accent_hover;
            }
            QSlider::sub-page:horizontal:disabled {
                background: @faint;
            }
            QSlider#Signed::sub-page:horizontal {
                background: @hover;
            }

            /* ---- Barre di scorrimento sottili ---- */
            QScrollBar:vertical {
                background: transparent;
                width: 8px;
                margin: 4px 2px;
            }
            QScrollBar::handle:vertical {
                background: @hover;
                border-radius: 3px;
                min-height: 30px;
            }
            QScrollBar::handle:vertical:hover {
                background: @faint;
            }
            QScrollBar::add-line, QScrollBar::sub-line, QScrollBar::add-page, QScrollBar::sub-page {
                background: none;
                height: 0;
            }

            /* ---- Finestre di dialogo ---- */
            QMessageBox, QProgressDialog, QColorDialog {
                background-color: @panel;
            }
            QProgressBar {
                background-color: @raised;
                border: none;
                border-radius: 4px;
                height: 8px;
                text-align: center;
                color: transparent;
            }
            QProgressBar::chunk {
                background-color: @accent;
                border-radius: 4px;
            }
        """
        tokens = dict(THEME, font=font_family("text"), display=font_family("display"))
        for key in sorted(tokens, key=len, reverse=True):
            qss = qss.replace("@" + key, tokens[key])
        self.setStyleSheet(qss)

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
        self.scene.num_frames = value
        self.scene.update_canvas_rect()
        self._relayout_keep()
        self.fit_canvas_in_view()
        self._schedule_commit()

    def _pick_bg_color(self):
        col = QColorDialog.getColor(self.scene.bg_color, self, "Colore di sfondo della tela")
        if col.isValid():
            self.scene.bg_color = col
            self.btn_bg_color.setIcon(swatch_icon(col))
            self.scene.update()
            self._schedule_commit()

    def _toggle_guides(self, checked: bool):
        self.scene.show_guides = checked
        self.scene.update()

    def _toggle_snap(self, checked: bool):
        for item in self.get_canvas_photos():
            item.snap_enabled = checked

    def fit_canvas_in_view(self):
        # Spazio extra in alto per le etichette delle pagine
        self.view.fit_to(self.scene.canvas_rect().adjusted(-70, -110, 70, 70))

    def _on_zoom_changed(self, scale: float):
        self.lbl_zoom.setText(f"{round(scale * 100)}%")
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

    # ================= CARICAMENTO E LIBRERIA FOTO =================
    def open_file_dialog(self):
        patterns = " ".join(f"*{ext}" for ext in IMAGE_EXTS)
        paths, _ = QFileDialog.getOpenFileNames(
            self,
            "Scegli le foto",
            "",
            f"Immagini ({patterns})"
        )
        if paths:
            self.load_images_from_paths(paths)

    def _load_into_library(self, paths: List[str], title: str) -> Tuple[List[str], List[str]]:
        """Carica i file nella cache/libreria con barra di avanzamento. Ritorna (caricati, errori)."""
        loaded, errors = [], []
        progress = None
        if len(paths) > 2:
            progress = QProgressDialog(title, "Annulla", 0, len(paths), self)
            progress.setWindowTitle("SCRL Studio")
            progress.setWindowModality(Qt.WindowModality.WindowModal)
            progress.setMinimumDuration(300)

        for i, p in enumerate(paths):
            if progress is not None:
                if progress.wasCanceled():
                    break
                progress.setValue(i)
                progress.setLabelText(f"{title}\n{os.path.basename(p)}  ({i + 1} di {len(paths)})")
                QApplication.processEvents()
            p = normalize_path(p)
            try:
                pixmap = IMAGE_CACHE.load(p)
            except Exception as e:
                errors.append(f"{os.path.basename(p)}: {e}")
                continue
            if p not in self.loaded_library:
                self.loaded_library.append(p)
                item = QListWidgetItem(QIcon(rounded_thumb(pixmap, 80)), "")
                item.setData(Qt.ItemDataRole.UserRole, p)
                item.setToolTip(os.path.basename(p))
                item.setSizeHint(QSize(86, 86))
                self.list_library.addItem(item)
            loaded.append(p)

        if progress is not None:
            progress.setValue(len(paths))
        self._update_library_ui()
        return loaded, errors

    def _report_load_errors(self, errors: List[str]):
        if errors:
            shown = "\n".join(errors[:15])
            more = f"\n… e altri {len(errors) - 15}" if len(errors) > 15 else ""
            QMessageBox.warning(self, "Alcune foto non sono state caricate",
                                "Questi file non sono immagini leggibili:\n\n" + shown + more)

    def _update_library_ui(self):
        n = len(self.loaded_library)
        self.lbl_library_count.setText("" if n == 0 else ("1 foto" if n == 1 else f"{n} foto"))
        self.library_stack.setCurrentIndex(1 if n else 0)
        self.btn_add_all.setEnabled(n > 0)

    def _update_canvas_count(self):
        n = len(self.get_canvas_photos())
        self.lbl_count.setText("Tela vuota" if n == 0 else ("1 foto sulla tela" if n == 1 else f"{n} foto sulla tela"))
        self.btn_clear_canvas.setEnabled(n > 0)

    def load_images_from_paths(self, paths: List[str]):
        loaded, errors = self._load_into_library(paths, "Caricamento foto…")
        for p in loaded:
            self._spawn_photo_item(p)
        if loaded:
            # Dispone automaticamente tutte le foto caricate nel formato selezionato (es. 3:4)
            self._relayout_keep()
            self.fit_canvas_in_view()
            self._schedule_commit()
        self._report_load_errors(errors)

    def _spawn_photo_item(self, path: str, uid: Optional[int] = None) -> PhotoItem:
        photo_item = PhotoItem(path, 400, 500, uid=uid)
        photo_item.snap_enabled = self.chk_snap.isChecked()
        photo_item.geometry_changed.connect(self._on_item_geometry_changed)
        photo_item.edit_finished.connect(self._schedule_commit)
        # Z-index e ordine di layout crescenti
        existing = self.get_canvas_photos()
        photo_item.setZValue(max([it.zValue() for it in existing], default=0.0) + 1.0)
        photo_item.layout_index = max([it.layout_index for it in existing], default=0) + 1
        self.scene.addItem(photo_item)
        return photo_item

    def _on_library_item_double_clicked(self, item: QListWidgetItem):
        self._add_library_paths_to_canvas([item.data(Qt.ItemDataRole.UserRole)])

    def _add_library_paths_to_canvas(self, paths: List[str]):
        # Le nuove foto compaiono al centro della zona visibile della tela
        center = self.view.mapToScene(self.view.viewport().rect().center())
        self.scene.clearSelection()
        for i, path in enumerate(paths):
            if not IMAGE_CACHE.has(path):
                continue
            new_item = self._spawn_photo_item(path)
            new_item.setPos(center - QPointF(new_item.cell_w / 2.0, new_item.cell_h / 2.0) + QPointF(i * 30, i * 30))
            new_item.setSelected(True)
        self._schedule_commit()

    def _show_library_context_menu(self, pos):
        items = self.list_library.selectedItems()
        if not items:
            return
        menu = QMenu(self)
        act_add = menu.addAction(make_icon("plus", THEME["text"], 16), "Aggiungi alla tela")
        act_remove = menu.addAction(make_icon("trash", THEME["text"], 16), "Rimuovi dalla libreria")
        chosen = menu.exec(self.list_library.mapToGlobal(pos))
        paths = [it.data(Qt.ItemDataRole.UserRole) for it in items]
        if chosen == act_add:
            self._add_library_paths_to_canvas(paths)
        elif chosen == act_remove:
            for it in items:
                self.loaded_library.remove(it.data(Qt.ItemDataRole.UserRole))
                self.list_library.takeItem(self.list_library.row(it))
            self._update_library_ui()

    def add_all_library_to_canvas(self):
        if not self.loaded_library:
            return
        self._remove_all_photos()
        for path in self.loaded_library:
            self._spawn_photo_item(path)
        self._relayout_keep()
        self._schedule_commit()

    def _remove_all_photos(self):
        for item in self.get_canvas_photos():
            self.scene.removeItem(item)

    def clear_canvas_photos(self):
        self._remove_all_photos()
        self._schedule_commit()

    def get_canvas_photos(self) -> List[PhotoItem]:
        """Foto sulla tela, nell'ordine di layout (indipendente dai livelli/Z-index)."""
        items = [it for it in self.scene.items() if isinstance(it, PhotoItem)]
        items.sort(key=lambda x: (x.layout_index, x.uid))
        return items

    def _selected_photos(self) -> List[PhotoItem]:
        return [it for it in self.scene.selectedItems() if isinstance(it, PhotoItem)]

    # ================= ALGORITMI DI LAYOUT E RIORGANIZZAZIONE =================
    def _on_layout_button(self, mode: str):
        # Nuovo seed solo quando si sceglie esplicitamente un layout: gli slider non rigenerano il random
        self._layout_seed = random.randrange(1 << 30)
        self.current_layout_mode = mode
        self.apply_auto_layout(mode)
        self._sync_layout_tiles()
        self._schedule_commit()

    def _sync_layout_tiles(self):
        tile = self.layout_tiles.get(self.current_layout_mode)
        if tile is not None:
            tile.setChecked(True)

    def _relayout_keep(self, *_):
        if self._restoring:
            return
        if self.get_canvas_photos():
            self.apply_auto_layout(self.current_layout_mode)
            self._schedule_commit()

    def apply_auto_layout(self, mode: str):
        photos = self.get_canvas_photos()
        if not photos:
            return
        self.current_layout_mode = mode
        rng = random.Random(self._layout_seed)
        gap = float(self.slider_gap.value())
        margin = float(self.slider_margin.value())

        # Il bordo bianco "Polaroid" aggiunto in automatico viene tolto se si cambia layout
        if mode != "scatter":
            for p in photos:
                if p.auto_border:
                    p.border_width = 0.0
                    p.auto_border = False
                    p.update()

        if mode == "scrl_seam":
            if self.scene.num_frames < 2:
                # Cambia il numero di frame senza far scattare un secondo relayout
                frames = max(2, math.ceil(len(photos) / 2))
                self.spin_frames.blockSignals(True)
                self.spin_frames.setValue(frames)
                self.spin_frames.blockSignals(False)
                self.scene.num_frames = frames
                self.scene.update_canvas_rect()
                self.fit_canvas_in_view()
            canvas = self.scene.canvas_rect().adjusted(margin, margin, -margin, -margin)
            self._layout_seam(photos, self._safe_rect(canvas), rng)
        else:
            frames = self.scene.num_frames
            if self.chk_per_frame.isChecked() and frames > 1:
                # Distribuisce le foto tra i frame in modo equilibrato (le prime pagine prendono l'eccedenza)
                base, extra = divmod(len(photos), frames)
                start = 0
                for f in range(frames):
                    count = base + (1 if f < extra else 0)
                    chunk = photos[start:start + count]
                    start += count
                    if chunk:
                        frame_rect = QRectF(f * self.scene.frame_w, 0, self.scene.frame_w, self.scene.frame_h)
                        area = self._safe_rect(frame_rect.adjusted(margin, margin, -margin, -margin))
                        self._layout_in_rect(mode, chunk, area, gap, rng)
            else:
                area = self._safe_rect(self.scene.canvas_rect().adjusted(margin, margin, -margin, -margin))
                self._layout_in_rect(mode, photos, area, gap, rng)

        self.scene.update()
        self._sync_inspector_from_item(self._get_primary_selected())

    @staticmethod
    def _safe_rect(r: QRectF) -> QRectF:
        return QRectF(r.x(), r.y(), max(100.0, r.width()), max(100.0, r.height()))

    @staticmethod
    def _place(p: PhotoItem, x: float, y: float, w: float, h: float, rotation: float = 0.0):
        p.setRotation(rotation)
        p.set_cell_size(w, h)
        p.setPos(x, y)

    def _layout_in_rect(self, mode: str, photos: List[PhotoItem], area: QRectF, gap: float, rng: random.Random):
        if mode == "mosaic":
            self._layout_mosaic(photos, area, gap)
        elif mode == "strips_h":
            self._layout_strips(photos, area, gap, horizontal=True)
        elif mode == "strips_v":
            self._layout_strips(photos, area, gap, horizontal=False)
        elif mode == "scatter":
            self._layout_scatter(photos, area, rng)
        else:
            self._layout_grid(photos, area, gap)

    def _layout_grid(self, photos: List[PhotoItem], area: QRectF, gap: float):
        # Calcola numero ottimale di righe e colonne in base al rapporto dell'area (es. 3:4)
        n = len(photos)
        cols = min(n, max(1, round(math.sqrt(n * area.width() / area.height()))))
        rows = math.ceil(n / cols)
        row_h = (area.height() - gap * (rows - 1)) / rows
        idx = 0
        for r in range(rows):
            remaining = n - idx
            cols_in_row = min(cols, math.ceil(remaining / (rows - r)))
            col_w = (area.width() - gap * (cols_in_row - 1)) / cols_in_row
            for c in range(cols_in_row):
                self._place(photos[idx], area.x() + c * (col_w + gap), area.y() + r * (row_h + gap), col_w, row_h)
                idx += 1

    def _layout_mosaic(self, photos: List[PhotoItem], area: QRectF, gap: float):
        # 1 Foto "Hero" grande in alto (formato verticale) o a sinistra (orizzontale) + griglia per le altre
        hero, others = photos[0], photos[1:]
        if not others:
            self._place(hero, area.x(), area.y(), area.width(), area.height())
            return
        if area.height() >= area.width():
            hero_h = (area.height() - gap) * 0.55
            self._place(hero, area.x(), area.y(), area.width(), hero_h)
            rest = QRectF(area.x(), area.y() + hero_h + gap, area.width(), area.height() - hero_h - gap)
        else:
            hero_w = (area.width() - gap) * 0.55
            self._place(hero, area.x(), area.y(), hero_w, area.height())
            rest = QRectF(area.x() + hero_w + gap, area.y(), area.width() - hero_w - gap, area.height())
        self._layout_grid(others, rest, gap)

    def _layout_strips(self, photos: List[PhotoItem], area: QRectF, gap: float, horizontal: bool):
        n = len(photos)
        if horizontal:
            row_h = (area.height() - gap * (n - 1)) / n
            for i, p in enumerate(photos):
                self._place(p, area.x(), area.y() + i * (row_h + gap), area.width(), row_h)
        else:
            col_w = (area.width() - gap * (n - 1)) / n
            for i, p in enumerate(photos):
                self._place(p, area.x() + i * (col_w + gap), area.y(), col_w, area.height())

    def _layout_scatter(self, photos: List[PhotoItem], area: QRectF, rng: random.Random):
        # Stile Freestyle / Polaroid con leggera inclinazione casuale (riproducibile tramite seed)
        n = len(photos)
        cols = max(1, math.ceil(math.sqrt(n * area.width() / area.height())))
        rows = math.ceil(n / cols)
        cell_w = area.width() / cols
        cell_h = area.height() / rows
        for i, p in enumerate(photos):
            r, c = divmod(i, cols)
            w = cell_w * 0.88
            h = cell_h * 0.88
            jitter_x = rng.uniform(-cell_w * 0.08, cell_w * 0.08)
            jitter_y = rng.uniform(-cell_h * 0.08, cell_h * 0.08)
            x = area.x() + c * cell_w + (cell_w - w) / 2.0 + jitter_x
            y = area.y() + r * cell_h + (cell_h - h) / 2.0 + jitter_y
            self._place(p, x, y, w, h, rng.uniform(-7.5, 7.5))
            if p.border_width == 0:
                p.border_width = 8.0
                p.auto_border = True
                p.update()

    def _layout_seam(self, photos: List[PhotoItem], area: QRectF, rng: random.Random):
        # Dispone le foto in modo fluido anche a cavallo tra più frame, senza uscire dalla tela
        n = len(photos)
        w = min(self.scene.frame_w * 0.75, area.width() * 1.15 / n, area.width())
        step_x = (area.width() - w) / (n - 1) if n > 1 else 0.0
        for i, p in enumerate(photos):
            h = area.height() * rng.uniform(0.55, 0.82)
            x = area.x() + (i * step_x if n > 1 else (area.width() - w) / 2.0)
            y = area.y() + (area.height() - h) * (0.15 if i % 2 == 0 else 0.80)
            self._place(p, x, y, w, h)

    @staticmethod
    def _slot(p: PhotoItem) -> tuple:
        return (QPointF(p.pos()), p.cell_w, p.cell_h, p.rotation(), p.zValue(), p.layout_index)

    @staticmethod
    def _apply_slot(p: PhotoItem, slot: tuple):
        pos, w, h, rot, z, layout_index = slot
        p.set_cell_size(w, h)
        p.setPos(pos)
        p.setRotation(rot)
        p.setZValue(z)
        p.layout_index = layout_index

    def shuffle_canvas_photos(self):
        """Rimescola l'ordine delle foto mantenendo esattamente le posizioni e dimensioni correnti."""
        photos = self.get_canvas_photos()
        if len(photos) < 2:
            return
        slots = [self._slot(p) for p in photos]
        shuffled = slots[:]
        while shuffled == slots:  # Garantisce che qualcosa cambi davvero
            random.shuffle(shuffled)
        for p, slot in zip(photos, shuffled):
            self._apply_slot(p, slot)
        self.scene.update()
        self._schedule_commit()

    def swap_two_selected_photos(self):
        selected = self._selected_photos()
        if len(selected) != 2:
            QMessageBox.information(
                self,
                "Scambia due foto",
                "Seleziona esattamente 2 foto sulla tela: clicca la prima, poi Ctrl+clic sulla seconda."
            )
            return
        p1, p2 = selected
        s1, s2 = self._slot(p1), self._slot(p2)
        self._apply_slot(p1, s2)
        self._apply_slot(p2, s1)
        self.scene.update()
        self._schedule_commit()

    # ================= INSPECTOR & CONTROLLI FOTO SINGOLA =================
    def _get_primary_selected(self) -> Optional[PhotoItem]:
        selected = self._selected_photos()
        return selected[0] if selected else None

    def _on_selection_changed(self):
        self._sync_inspector_from_item(self._get_primary_selected())

    def _on_item_geometry_changed(self, item: PhotoItem):
        if item is self._get_primary_selected():
            self._sync_inspector_from_item(item)

    def _sync_inspector_from_item(self, item: Optional[PhotoItem]):
        self._updating_inspector = True
        count = len(self._selected_photos())
        self.insp_stack.setCurrentIndex(0 if item is None else 1)
        if item is None:
            self.lbl_hint.setText("Clicca una foto per selezionarla.   Rotella: zoom della vista.   "
                                  "Tasto centrale + trascina: sposta la vista.")
        else:
            self.lbl_selection_thumb.setPixmap(rounded_thumb(item.pixmap, 52, 9))
            if count > 1:
                self.lbl_selection_name.setText(f"{count} foto selezionate")
                self.lbl_selection_info.setText("Le modifiche valgono per tutte")
            else:
                self.lbl_selection_name.setText(self.fontMetrics().elidedText(
                    os.path.basename(item.image_path), Qt.TextElideMode.ElideMiddle, 190))
                self.lbl_selection_info.setText(f"Riquadro {int(item.cell_w)} × {int(item.cell_h)} px")
            self.lbl_hint.setText("Alt + trascina: sposta l'inquadratura.   Ctrl + rotella: zoom nella foto.   "
                                  "Shift sulle maniglie: mantieni le proporzioni.")
            self.btn_border_color.setIcon(swatch_icon(item.border_color))
            self.slider_inner_zoom.setValue(round(item.inner_zoom * 100))
            self.slider_pan_x.setValue(round(item.pan_x * 100))
            self.slider_pan_y.setValue(round(item.pan_y * 100))
            self.slider_rotation.setValue(round(item.rotation()))
            self.slider_radius.setValue(round(item.border_radius))
            self.slider_border.setValue(round(item.border_width))
        self._update_canvas_count()
        self._updating_inspector = False

    def _on_inspector_slider(self, prop: str, value: int):
        if self._updating_inspector:
            return
        for item in self._selected_photos():
            if prop == "zoom":
                item.inner_zoom = value / 100.0
            elif prop == "pan_x":
                item.pan_x = value / 100.0
            elif prop == "pan_y":
                item.pan_y = value / 100.0
            elif prop == "rotation":
                item.setRotation(float(value))
            elif prop == "radius":
                item.border_radius = float(value)
            elif prop == "border":
                item.border_width = float(value)
                item.auto_border = False
            item.update()
        self._schedule_commit()

    def _rotate_selected_by(self, delta_deg: float):
        for item in self._selected_photos():
            item.setRotation(((item.rotation() + delta_deg + 180) % 360) - 180)
        self._sync_inspector_from_item(self._get_primary_selected())
        self._schedule_commit()

    def _set_selected_rotation(self, angle: float):
        for item in self._selected_photos():
            item.setRotation(angle)
        self._sync_inspector_from_item(self._get_primary_selected())
        self._schedule_commit()

    def _pick_photo_border_color(self):
        item = self._get_primary_selected()
        initial = item.border_color if item else QColor("#FFFFFF")
        col = QColorDialog.getColor(initial, self, "Colore del bordo")
        if col.isValid():
            for sel in self._selected_photos():
                sel.border_color = col
                sel.update()
            self.btn_border_color.setIcon(swatch_icon(col))
            self._schedule_commit()

    def _apply_style_to_all_photos(self):
        radius = float(self.slider_radius.value())
        border_w = float(self.slider_border.value())
        primary = self._get_primary_selected()
        border_col = primary.border_color if primary else QColor("#FFFFFF")
        for p in self.get_canvas_photos():
            p.border_radius = radius
            p.border_width = border_w
            p.border_color = border_col
            p.auto_border = False
            p.update()
        self._schedule_commit()

    def _restore_selected_original_ratio(self):
        for sel in self._selected_photos():
            sel.reset_aspect_to_original()
        self._sync_inspector_from_item(self._get_primary_selected())
        self._schedule_commit()

    def _bring_to_front(self):
        selected = sorted(self._selected_photos(), key=lambda p: p.zValue())
        if selected:
            max_z = max([it.zValue() for it in self.get_canvas_photos()], default=0.0)
            for i, item in enumerate(selected):
                item.setZValue(max_z + 1.0 + i)
            self._schedule_commit()

    def _send_to_back(self):
        selected = sorted(self._selected_photos(), key=lambda p: p.zValue(), reverse=True)
        if selected:
            min_z = min([it.zValue() for it in self.get_canvas_photos()], default=0.0)
            for i, item in enumerate(selected):
                item.setZValue(min_z - 1.0 - i)
            self._schedule_commit()

    def _duplicate_selected(self):
        selected = self._selected_photos()
        if not selected:
            return
        duplicates = []
        for item in selected:
            dup = self._spawn_photo_item(item.image_path)
            state = item.get_state()
            # Copia tutto (incluso zoom/pan interni) tranne identità, livello e ordine
            state.update(uid=dup.uid, z=dup.zValue(), layout_index=dup.layout_index,
                         x=state["x"] + 30, y=state["y"] + 30)
            dup.set_state(state)
            duplicates.append(dup)
        self.scene.clearSelection()
        for dup in duplicates:
            dup.setSelected(True)
        self._schedule_commit()

    def _delete_selected(self):
        selected = self._selected_photos()
        for sel in selected:
            self.scene.removeItem(sel)
        if selected:
            self._update_canvas_count()
            self._schedule_commit()

    def _select_all(self):
        for p in self.get_canvas_photos():
            p.setSelected(True)

    def _nudge_selected(self, dx: float, dy: float):
        selected = self._selected_photos()
        for p in selected:
            p.moveBy(dx, dy)
        if selected:
            self._sync_inspector_from_item(self._get_primary_selected())
            self._schedule_commit()

    def _show_canvas_context_menu(self, pos):
        # Il clic destro su una foto non selezionata la seleziona (come in ogni editor grafico)
        clicked = next((it for it in self.view.items(pos) if isinstance(it, PhotoItem)), None)
        if clicked is not None and not clicked.isSelected():
            self.scene.clearSelection()
            clicked.setSelected(True)

        n_sel = len(self._selected_photos())
        has_sel = n_sel > 0
        menu = QMenu(self)
        entries = [
            ("front", "Porta davanti", self._bring_to_front, has_sel),
            ("back", "Manda dietro", self._send_to_back, has_sel),
            None,
            ("swap", "Scambia le 2 foto selezionate", self.swap_two_selected_photos, n_sel == 2),
            ("ratio", "Usa le proporzioni della foto", self._restore_selected_original_ratio, has_sel),
            ("duplicate", "Duplica", self._duplicate_selected, has_sel),
            None,
            ("trash", "Elimina", self._delete_selected, has_sel),
        ]
        for entry in entries:
            if entry is None:
                menu.addSeparator()
                continue
            icon, text, slot, enabled = entry
            act = menu.addAction(make_icon(icon, THEME["text"], 16), text)
            act.setEnabled(enabled)
            act.triggered.connect(slot)
        menu.exec(self.view.mapToGlobal(pos))

    # ================= ANNULLA / RIPETI =================
    def _snapshot(self) -> dict:
        return {
            "canvas": {
                "ratio_index": self.combo_ratio.currentIndex(),
                "custom_w": self.spin_custom_w.value(),
                "custom_h": self.spin_custom_h.value(),
                "frame_w": self.scene.frame_w,
                "frame_h": self.scene.frame_h,
                "num_frames": self.scene.num_frames,
                "bg_color": self.scene.bg_color.name(QColor.NameFormat.HexArgb),
                "gap": self.slider_gap.value(),
                "margin": self.slider_margin.value(),
                "per_frame": self.chk_per_frame.isChecked(),
                "layout_mode": self.current_layout_mode,
                "layout_seed": self._layout_seed,
            },
            "items": [p.get_state() for p in self.get_canvas_photos()],
        }

    def _restore_snapshot(self, snap: dict):
        self._restoring = True
        try:
            c = snap["canvas"]
            widgets = (self.combo_ratio, self.spin_custom_w, self.spin_custom_h,
                       self.spin_frames, self.slider_gap, self.slider_margin, self.chk_per_frame)
            for w in widgets:
                w.blockSignals(True)
            self.combo_ratio.setCurrentIndex(c["ratio_index"])
            self.spin_custom_w.setValue(c["custom_w"])
            self.spin_custom_h.setValue(c["custom_h"])
            self.spin_frames.setValue(c["num_frames"])
            self.slider_gap.setValue(c["gap"])
            self.slider_margin.setValue(c["margin"])
            self.chk_per_frame.setChecked(c["per_frame"])
            for w in widgets:
                w.blockSignals(False)
            self.chk_per_frame.update()
            self.custom_size_box.setVisible(self.ASPECT_RATIOS.get(self.combo_ratio.currentText()) is None)

            canvas_changed = (self.scene.frame_w, self.scene.frame_h, self.scene.num_frames) != \
                (c["frame_w"], c["frame_h"], c["num_frames"])
            self.scene.frame_w, self.scene.frame_h = c["frame_w"], c["frame_h"]
            self.scene.num_frames = c["num_frames"]
            self.scene.bg_color = QColor(c["bg_color"])
            self.btn_bg_color.setIcon(swatch_icon(self.scene.bg_color))
            self.scene.update_canvas_rect()
            self.current_layout_mode = c["layout_mode"]
            self._layout_seed = c["layout_seed"]
            self._sync_layout_tiles()

            existing = {p.uid: p for p in self.get_canvas_photos()}
            wanted = set()
            for s in snap["items"]:
                if not IMAGE_CACHE.has(s["path"]):
                    continue
                wanted.add(s["uid"])
                item = existing.get(s["uid"]) or self._spawn_photo_item(s["path"], uid=s["uid"])
                item.set_state(s)
            for uid, item in existing.items():
                if uid not in wanted:
                    self.scene.removeItem(item)
            self.scene.update()
            if canvas_changed:
                self.fit_canvas_in_view()
        finally:
            self._restoring = False
        self._refresh_slider_labels()
        self._sync_inspector_from_item(self._get_primary_selected())

    def _refresh_slider_labels(self):
        # Ri-emette il valore per aggiornare le etichette (i relayout sono bloccati da _restoring)
        self._restoring = True
        try:
            for s in (self.slider_gap, self.slider_margin):
                s.valueChanged.emit(s.value())
        finally:
            self._restoring = False

    def _schedule_commit(self):
        if not self._restoring:
            self._commit_timer.start()

    def _commit_history(self):
        self._commit_timer.stop()
        snap = self._snapshot()
        if self._history and self._history[self._history_index] == snap:
            return
        del self._history[self._history_index + 1:]
        self._history.append(snap)
        if len(self._history) > self.HISTORY_LIMIT:
            self._history.pop(0)
        self._history_index = len(self._history) - 1
        self._update_undo_actions()
        self._update_title()
        self._update_canvas_count()

    def _flush_pending_commit(self):
        if self._commit_timer.isActive():
            self._commit_history()

    def undo(self):
        self._flush_pending_commit()
        if self._history_index > 0:
            self._history_index -= 1
            self._restore_snapshot(self._history[self._history_index])
            self._update_undo_actions()
            self._update_title()

    def redo(self):
        self._flush_pending_commit()
        if self._history_index < len(self._history) - 1:
            self._history_index += 1
            self._restore_snapshot(self._history[self._history_index])
            self._update_undo_actions()
            self._update_title()

    def _update_undo_actions(self):
        if hasattr(self, "act_undo"):
            self.act_undo.setEnabled(self._history_index > 0)
            self.act_redo.setEnabled(self._history_index < len(self._history) - 1)

    def _is_dirty(self) -> bool:
        if not self._history:
            return False
        return self._history[self._history_index] != self._saved_snapshot

    def _update_title(self):
        name = os.path.basename(self.project_path) if self.project_path else "Senza titolo"
        star = " •" if self._is_dirty() else ""
        self.setWindowTitle(f"{name}{star} — SCRL Studio")

    # ================= PROGETTO (SALVA / APRI) =================
    def save_project(self) -> bool:
        if not self.project_path:
            return self.save_project_as()
        return self._write_project(self.project_path)

    def save_project_as(self) -> bool:
        path, _ = QFileDialog.getSaveFileName(
            self, "Salva progetto", self.project_path or f"collage{PROJECT_EXT}",
            f"Progetto SCRL (*{PROJECT_EXT})"
        )
        if not path:
            return False
        if not path.lower().endswith(PROJECT_EXT):
            path += PROJECT_EXT
        return self._write_project(path)

    def _write_project(self, path: str) -> bool:
        self._flush_pending_commit()
        snap = self._history[self._history_index]
        base_dir = os.path.dirname(os.path.abspath(path))

        def rel(p):
            try:
                return os.path.relpath(p, base_dir)
            except ValueError:  # Unità diversa su Windows
                return None

        data = {
            "version": PROJECT_VERSION,
            "canvas": snap["canvas"],
            "library": [{"path": p, "rel": rel(p)} for p in self.loaded_library],
            "items": [dict(s, rel=rel(s["path"])) for s in snap["items"]],
        }
        try:
            with open(path, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=1)
        except OSError as e:
            QMessageBox.critical(self, "Progetto non salvato", f"Impossibile scrivere il file:\n{e}")
            return False
        self.project_path = path
        self._saved_snapshot = snap
        self._update_title()
        self.statusBar().showMessage(f"Progetto salvato: {os.path.basename(path)}", 3000)
        return True

    def open_project(self):
        if not self._confirm_discard_changes():
            return
        path, _ = QFileDialog.getOpenFileName(self, "Apri progetto", "", f"Progetto SCRL (*{PROJECT_EXT})")
        if not path:
            return
        try:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
            canvas = data["canvas"]
            items = data["items"]
            library = data.get("library", [])
        except (OSError, ValueError, KeyError) as e:
            QMessageBox.critical(self, "Progetto non aperto", f"Il file non è un progetto valido:\n{e}")
            return

        base_dir = os.path.dirname(os.path.abspath(path))

        def resolve(entry) -> str:
            # Prova il percorso assoluto, poi quello relativo al progetto (cartella spostata)
            if os.path.isfile(entry["path"]):
                return normalize_path(entry["path"])
            if entry.get("rel"):
                candidate = os.path.join(base_dir, entry["rel"])
                if os.path.isfile(candidate):
                    return normalize_path(candidate)
            return normalize_path(entry["path"])

        for s in items:
            s["path"] = resolve(s)
        lib_paths = [resolve(e) for e in library]
        all_paths = list(dict.fromkeys(lib_paths + [s["path"] for s in items]))

        self._remove_all_photos()
        self.loaded_library.clear()
        self.list_library.clear()
        _, errors = self._load_into_library(all_paths, "Apertura progetto…")

        self._restore_snapshot({"canvas": canvas, "items": items})
        self.project_path = path
        self._history = []
        self._history_index = -1
        self._commit_history()
        self._saved_snapshot = self._history[-1]
        self._update_title()
        self.fit_canvas_in_view()
        self._report_load_errors(errors)

    def _confirm_discard_changes(self) -> bool:
        self._flush_pending_commit()
        if not self._is_dirty() or not self.get_canvas_photos():
            return True
        answer = QMessageBox.question(
            self, "Modifiche non salvate",
            "Il collage ha modifiche non salvate. Vuoi salvare il progetto?",
            QMessageBox.StandardButton.Save | QMessageBox.StandardButton.Discard | QMessageBox.StandardButton.Cancel,
        )
        if answer == QMessageBox.StandardButton.Save:
            return self.save_project()
        return answer == QMessageBox.StandardButton.Discard

    def closeEvent(self, event):
        if self._confirm_discard_changes():
            event.accept()
        else:
            event.ignore()

    # ================= ESPORTAZIONE AD ALTA RISOLUZIONE =================
    def _get_export_scale(self) -> int:
        return 2 if self.combo_quality.currentIndex() == 1 else 1

    def _render_region(self, source: QRectF, out_w: int, out_h: int) -> Optional[QImage]:
        img = QImage(out_w, out_h, QImage.Format.Format_ARGB32_Premultiplied)
        if img.isNull():
            return None
        img.fill(self.scene.bg_color)
        painter = QPainter(img)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, True)
        self.scene.render(painter, QRectF(0, 0, out_w, out_h), source)
        painter.end()
        return img

    def _begin_export(self):
        self._flush_pending_commit()
        self.scene.is_exporting = True
        QApplication.setOverrideCursor(Qt.CursorShape.WaitCursor)

    def _end_export(self):
        self.scene.is_exporting = False
        IMAGE_CACHE.release_full()
        QApplication.restoreOverrideCursor()
        self.scene.update()

    def _warn_if_empty(self) -> bool:
        if self.get_canvas_photos():
            return True
        answer = QMessageBox.question(self, "Tela vuota", "Non ci sono foto sulla tela. Esportare comunque?")
        return answer == QMessageBox.StandardButton.Yes

    def export_full_collage(self):
        if not self._warn_if_empty():
            return
        scale = self._get_export_scale()
        canvas = self.scene.canvas_rect()
        out_w = int(canvas.width() * scale)
        out_h = int(canvas.height() * scale)
        frames = self.scene.num_frames
        frames_tag = f"_{frames}pagine" if frames > 1 else ""

        path, _ = QFileDialog.getSaveFileName(
            self,
            f"Esporta collage ({out_w}×{out_h} px)",
            f"collage_{self.scene.frame_w}x{self.scene.frame_h}{frames_tag}_{out_w}x{out_h}.png",
            "PNG alta qualità (*.png);;JPEG (*.jpg *.jpeg)"
        )
        if not path:
            return

        self._begin_export()
        try:
            img = self._render_region(canvas, out_w, out_h)
            ok = img is not None and img.save(path, quality=95 if path.lower().endswith((".jpg", ".jpeg")) else -1)
        finally:
            self._end_export()

        if img is None:
            QMessageBox.critical(
                self, "Collage non esportato",
                f"Memoria insufficiente per creare un'immagine di {out_w}×{out_h} px.\n"
                "Scegli Qualità standard (1×) oppure esporta le pagine separate."
            )
        elif not ok:
            QMessageBox.critical(self, "Collage non esportato", f"Impossibile salvare il file:\n{path}")
        else:
            QMessageBox.information(
                self,
                "Collage esportato",
                f"Salvato in:\n{path}\n\nRisoluzione: {out_w}×{out_h} px"
            )

    def export_split_frames(self):
        if not self._warn_if_empty():
            return
        folder = QFileDialog.getExistingDirectory(self, "Scegli la cartella per le pagine")
        if not folder:
            return

        num_frames = self.scene.num_frames
        file_paths = [os.path.join(folder, f"frame_{i + 1:02d}.png") for i in range(num_frames)]
        existing = [p for p in file_paths if os.path.exists(p)]
        if existing:
            answer = QMessageBox.question(
                self, "Sostituire i file?",
                f"Nella cartella ci sono già {len(existing)} file frame_XX.png. Vuoi sostituirli?"
            )
            if answer != QMessageBox.StandardButton.Yes:
                return

        scale = self._get_export_scale()
        fw = self.scene.frame_w
        fh = self.scene.frame_h
        out_w = int(fw * scale)
        out_h = int(fh * scale)

        progress = QProgressDialog("Esportazione pagine…", "Annulla", 0, num_frames, self)
        progress.setWindowTitle("SCRL Studio")
        progress.setWindowModality(Qt.WindowModality.WindowModal)
        progress.setMinimumDuration(300)

        saved_files, failed = [], []
        self._begin_export()
        try:
            for i, file_path in enumerate(file_paths):
                if progress.wasCanceled():
                    break
                progress.setValue(i)
                QApplication.processEvents()
                img = self._render_region(QRectF(i * fw, 0, fw, fh), out_w, out_h)
                if img is not None and img.save(file_path):
                    saved_files.append(file_path)
                else:
                    failed.append(os.path.basename(file_path))
        finally:
            progress.setValue(num_frames)
            self._end_export()

        msg = f"{len(saved_files)} pagine esportate ({out_w}×{out_h} px ciascuna) in:\n{folder}"
        if failed:
            QMessageBox.warning(self, "Esportazione incompleta", msg + "\n\nNon salvate: " + ", ".join(failed))
        else:
            QMessageBox.information(self, "Pagine esportate", msg)


def apply_app_style(app: QApplication):
    """Stile Fusion con palette scura coerente, così anche le finestre di dialogo seguono il tema."""
    app.setStyle("Fusion")
    pal = QPalette()
    roles = {
        QPalette.ColorRole.Window: THEME["panel"],
        QPalette.ColorRole.WindowText: THEME["text"],
        QPalette.ColorRole.Base: THEME["raised"],
        QPalette.ColorRole.AlternateBase: THEME["panel"],
        QPalette.ColorRole.Text: THEME["text"],
        QPalette.ColorRole.Button: THEME["raised"],
        QPalette.ColorRole.ButtonText: THEME["text"],
        QPalette.ColorRole.Highlight: THEME["accent"],
        QPalette.ColorRole.HighlightedText: THEME["accent_ink"],
        QPalette.ColorRole.ToolTipBase: THEME["raised"],
        QPalette.ColorRole.ToolTipText: THEME["text"],
        QPalette.ColorRole.PlaceholderText: THEME["faint"],
    }
    for role, color in roles.items():
        pal.setColor(role, QColor(color))
    pal.setColor(QPalette.ColorGroup.Disabled, QPalette.ColorRole.Text, QColor(THEME["faint"]))
    pal.setColor(QPalette.ColorGroup.Disabled, QPalette.ColorRole.ButtonText, QColor(THEME["faint"]))
    pal.setColor(QPalette.ColorGroup.Disabled, QPalette.ColorRole.WindowText, QColor(THEME["faint"]))
    app.setPalette(pal)
    app.setFont(ui_font(13))


if __name__ == "__main__":
    app = QApplication(sys.argv)
    apply_app_style(app)
    window = MainWindow()
    window.show()
    sys.exit(app.exec())
