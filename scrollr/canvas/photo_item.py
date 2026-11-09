"""Foto interattiva sulla tela."""
import math
import os
import random
from typing import Dict, List, Optional, Tuple

from PyQt6.QtCore import Qt, QLineF, QRectF, QPointF, pyqtSignal
from PyQt6.QtGui import (
    QPixmap, QPainter, QPen, QColor, QBrush, QPainterPath, QCursor, QTransform, QImage, QRadialGradient
)
from PyQt6.QtWidgets import QGraphicsObject, QGraphicsItem
from PIL import Image

from scrollr.canvas.snap import snap_selection
from scrollr.icons import draw_lock_badge, icon_pixmap
from scrollr.imaging import (
    IMAGE_CACHE, NEUTRAL_ADJUST, PIXEL_ADJUST, adjustments_active, apply_adjustments, auto_levels_lut,
    pil_to_qimage, qimage_to_pil
)

_GRAIN_TILE: Optional[QImage] = None


def grain_tile() -> QImage:
    """Riquadro di rumore grigio sempre uguale (stesso seme): la grana non cambia a ogni ridisegno."""
    global _GRAIN_TILE
    if _GRAIN_TILE is None:
        side = 256
        data = random.Random(20261022).randbytes(side * side)
        gray = QImage(data, side, side, side, QImage.Format.Format_Grayscale8)
        _GRAIN_TILE = gray.convertToFormat(QImage.Format.Format_ARGB32_Premultiplied)
    return _GRAIN_TILE
from scrollr.theme import THEME, ui_font

FULL_CROP = (0.0, 0.0, 1.0, 1.0)


def clean_crop(c) -> Tuple[float, float, float, float]:
    """Ritaglio valido (dentro la foto, non vuoto); se non lo è, la foto intera."""
    try:
        x0, y0, x1, y1 = (max(0.0, min(1.0, float(v))) for v in c)
    except (TypeError, ValueError):
        return FULL_CROP
    if x1 - x0 < 0.005 or y1 - y0 < 0.005:
        return FULL_CROP
    return (x0, y0, x1, y1)


class PhotoItem(QGraphicsObject):
    """
    Elemento grafico interattivo che rappresenta una foto sul canvas.
    Supporta:
    - Ridimensionamento cella tramite maniglie agli angoli (con object-fit: cover automatico),
      corretto anche su foto ruotate
    - Zoom interno e Pan interno (Alt + Trascina, Alt + Rotella o tramite slider)
    - Angoli arrotondati, bordo interno personalizzabile e rotazione
    - Snap magnetico a bordi/centri della tela, dei frame e delle altre foto
    """
    geometry_changed = pyqtSignal(object)  # Modifica in corso (per aggiornare l'Inspector)
    edit_finished = pyqtSignal()           # Modifica completata (per Annulla/Ripeti)
    dropped = pyqtSignal(object)           # Rilasciata dopo un trascinamento (forse su un'altra pagina)
    crop_requested = pyqtSignal(object)    # Doppio clic: apre la finestra del ritaglio
    HANDLE_PX = 11.0  # Maniglie di dimensione costante sullo schermo, a qualsiasi zoom
    MIN_CELL = 40.0

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
        self.inner_rotation = 0.0   # Rotazione del contenuto dentro la cella (gradi), il riquadro resta fermo
        # Ritaglio della foto: parte dell'originale usata (sinistra, alto, destra, basso in frazioni 0..1,
        # sulla foto non specchiata). (0, 0, 1, 1) = foto intera.
        self.crop: Tuple[float, float, float, float] = FULL_CROP
        # Stiramento orizzontale della foto rispetto alle sue proporzioni vere (1.0 = non deformata):
        # cambia quando si tirano i quadratini sui lati
        self.stretch = 1.0

        # Stile cornice
        self.border_radius = 0.0
        self.border_width = 0.0
        self.border_color = QColor("#FFFFFF")
        self.auto_border = False    # Bordo aggiunto automaticamente dal layout Polaroid

        # Colore, specchio, riempimento, opacità, ombra, blocco
        self.adjust = dict(NEUTRAL_ADJUST)
        self.flip_h = False
        self.flip_v = False
        self.fit_mode = "cover"     # "cover" = riempie il riquadro, "contain" = foto intera senza tagli
        self.photo_opacity = 100
        self.shadow = 0             # Intensità dell'ombra 0..100
        self.locked = False
        self.page_locked = False  # Pagina bloccata col lucchetto: l'elemento resta com'è
        self.group = 0              # Gruppo di elementi che si selezionano insieme (0 = nessuno)
        self.free = False           # Foto libera: fuori dalla disposizione automatica, si muove a mano
        # Riquadro prima di "Proporzioni foto", per poterci tornare con un clic
        self.saved_cell: Optional[dict] = None
        # Regolazioni colore già applicate, una per versione (anteprima e nitida per lo zoom)
        self._adjusted_cache: Dict[bool, Tuple[tuple, QPixmap]] = {}
        self._auto_lut: Optional[Tuple[int, List[int]]] = None  # Livelli automatici (chiave dell'anteprima)

        # Stato interazione maniglie
        self._resizing_handle: Optional[str] = None
        self._resize_anchor_scene = QPointF()
        self._resize_ratio = 1.0
        self._resize_start = (1.0, 1.0, 1.0)  # Larghezza, altezza e stiramento all'inizio del trascinamento
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

    @property
    def is_missing(self) -> bool:
        """Il file non è stato trovato (spostato o rinominato): la foto resta sulla tela come segnaposto."""
        return not IMAGE_CACHE.has(self.image_path)

    def display_pixmap(self, sharp: bool = False) -> QPixmap:
        """
        Anteprima con le regolazioni colore applicate (ricalcolata solo quando cambiano).
        Con sharp=True usa la versione nitida per lo zoom, se è già pronta.
        """
        hires = IMAGE_CACHE.hires(self.image_path) if sharp else None
        sharp = hires is not None
        pm = hires if sharp else self.pixmap
        if pm.isNull() or not adjustments_active(self.adjust) or self._showing_original():
            return pm
        key = (pm.cacheKey(), tuple((k, self.adjust.get(k)) for k in PIXEL_ADJUST))
        cached = self._adjusted_cache.get(sharp)
        if cached is None or cached[0] != key:
            out = apply_adjustments(qimage_to_pil(pm.toImage()), self.adjust,
                                    detail_scale=pm.width() / 1000.0, auto_lut=self.auto_lut())
            cached = self._adjusted_cache[sharp] = (key, QPixmap.fromImage(pil_to_qimage(out)))
        return cached[1]

    def auto_lut(self) -> Optional[List[int]]:
        """Livelli automatici calcolati una volta sull'anteprima della foto intera (None se non servono)."""
        if not self.adjust.get("auto"):
            return None
        pm = self.pixmap
        if pm.isNull():
            return None
        if self._auto_lut is None or self._auto_lut[0] != pm.cacheKey():
            self._auto_lut = (pm.cacheKey(), auto_levels_lut(qimage_to_pil(pm.toImage())))
        return self._auto_lut[1]

    def _showing_original(self) -> bool:
        """Pulsante Prima/dopo tenuto premuto: si vede la foto senza regolazioni (mai in esportazione)."""
        scene = self.scene()
        return bool(scene) and getattr(scene, "show_original", False) and not getattr(scene, "is_exporting", False)

    def _needs_sharp(self, painter: QPainter) -> bool:
        """La foto è mostrata più grande dell'anteprima (zoom forte): serve la versione nitida."""
        pm = self.pixmap
        if pm.width() <= 0 or pm.height() <= 0:
            return False
        src = self._crop_rect(pm.width(), pm.height())
        draw_w, draw_h = self._cover_geometry(src.width(), src.height())[3:5]
        device = painter.device()
        ratio = device.devicePixelRatioF() if device is not None else 1.0
        enlarge = max(draw_w / max(1e-6, src.width()), draw_h / max(1e-6, src.height()))
        return enlarge * self._view_scale() * ratio > 1.15

    def set_locked(self, locked: bool):
        self.locked = bool(locked)
        self.setFlag(QGraphicsItem.GraphicsItemFlag.ItemIsMovable, not (self.locked or self.page_locked))
        self.update()

    def set_page_locked(self, on: bool):
        """
        Pagina bloccata: l'elemento non si seleziona, non si sposta e non riceve i clic
        (trascinandoci sopra si sposta la vista, come sul vuoto).
        """
        self.page_locked = bool(on)
        if self.page_locked:
            self.setSelected(False)
            self.unsetCursor()
        self.setFlag(QGraphicsItem.GraphicsItemFlag.ItemIsSelectable, not self.page_locked)
        self.setFlag(QGraphicsItem.GraphicsItemFlag.ItemIsMovable, not (self.locked or self.page_locked))
        self.setAcceptedMouseButtons(Qt.MouseButton.NoButton if self.page_locked else Qt.MouseButton.AllButtons)
        self.setAcceptHoverEvents(not self.page_locked)

    def set_free(self, free: bool):
        self.free = bool(free)
        self.setToolTip("Foto libera: non segue la disposizione automatica" if self.free else "")

    def set_photo_opacity(self, value: int):
        self.photo_opacity = int(value)
        self.setOpacity(self.photo_opacity / 100.0)

    def set_shadow(self, value: int):
        self.prepareGeometryChange()
        self.shadow = int(value)
        self.update()

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
            "inner_rotation": round(self.inner_rotation, 3),
            "crop": [round(v, 5) for v in self.crop],
            "stretch": round(self.stretch, 5),
            "border_radius": self.border_radius,
            "border_width": self.border_width,
            "border_color": self.border_color.name(QColor.NameFormat.HexArgb),
            "auto_border": self.auto_border,
            "adjust": dict(self.adjust),
            "flip_h": self.flip_h,
            "flip_v": self.flip_v,
            "fit_mode": self.fit_mode,
            "opacity": self.photo_opacity,
            "shadow": self.shadow,
            "locked": self.locked,
            "page_locked": self.page_locked,
            "free": self.free,
            "saved_cell": dict(self.saved_cell) if self.saved_cell else None,
            "group": self.group,
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
        self.inner_rotation = s.get("inner_rotation", 0.0)
        self.crop = clean_crop(s.get("crop", FULL_CROP))
        self.stretch = min(20.0, max(0.05, float(s.get("stretch", 1.0))))
        self.border_radius = s["border_radius"]
        self.border_width = s["border_width"]
        self.border_color = QColor(s["border_color"])
        self.auto_border = s.get("auto_border", False)
        self.adjust = dict(NEUTRAL_ADJUST, **s.get("adjust", {}))
        self.flip_h = s.get("flip_h", False)
        self.flip_v = s.get("flip_v", False)
        self.fit_mode = s.get("fit_mode", "cover")
        self.set_photo_opacity(s.get("opacity", 100))
        self.set_shadow(s.get("shadow", 0))
        self.set_locked(s.get("locked", False))
        self.set_page_locked(s.get("page_locked", False))
        self.set_free(s.get("free", False))
        self.saved_cell = dict(s["saved_cell"]) if s.get("saved_cell") else None
        self.group = int(s.get("group", 0))
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
        # Zoom della vista attiva (in fila o a scacchiera), impostato dalla finestra
        scene = self.scene()
        return max(0.01, getattr(scene, "display_scale", 1.0)) if scene else 1.0

    def _handle_size(self) -> float:
        return self.HANDLE_PX / self._view_scale()

    def _pos_for_local_point(self, local: QPointF, scene_target: QPointF) -> QPointF:
        """Posizione dell'item tale che il punto locale `local` cada su `scene_target` (rotazione inclusa)."""
        origin = QPointF(self.cell_w / 2.0, self.cell_h / 2.0)
        rotated = QTransform().rotate(self.rotation()).map(local - origin)
        return scene_target - origin - rotated

    def reset_aspect_to_original(self):
        """
        Adatta il riquadro alle proporzioni originali della foto, restando DENTRO il riquadro attuale
        (così non copre le foto vicine) e mantenendo fisso il centro. Il riquadro di prima viene
        ricordato: restore_saved_cell() lo ripristina.
        """
        pm = self.pixmap
        if pm.width() > 0 and pm.height() > 0:
            if self.saved_cell is None:
                self.saved_cell = {"x": self.pos().x(), "y": self.pos().y(), "w": self.cell_w, "h": self.cell_h,
                                   "inner_zoom": self.inner_zoom, "pan_x": self.pan_x, "pan_y": self.pan_y,
                                   "stretch": self.stretch}
            self.stretch = 1.0
            center = self.mapToScene(QPointF(self.cell_w / 2.0, self.cell_h / 2.0))
            ratio = self.source_ratio()
            new_w = min(self.cell_w, self.cell_h * ratio)
            new_h = new_w / ratio
            self.set_cell_size(new_w, new_h)
            self.setPos(center - QPointF(self.cell_w / 2.0, self.cell_h / 2.0))
            self.pan_x = 0.0
            self.pan_y = 0.0
            self.inner_zoom = 1.0
            self.update()

    def restore_saved_cell(self):
        """Torna al riquadro com'era prima di "Proporzioni foto"."""
        sc = self.saved_cell
        if sc is None:
            return
        self.set_cell_size(sc["w"], sc["h"])
        self.setPos(sc["x"], sc["y"])
        self.inner_zoom, self.pan_x, self.pan_y = sc["inner_zoom"], sc["pan_x"], sc["pan_y"]
        self.stretch = sc.get("stretch", self.stretch)
        self.saved_cell = None
        self.update()

    # ---------- Ritaglio ----------
    def has_crop(self) -> bool:
        return self.crop != FULL_CROP

    def _crop_rect(self, img_w: float, img_h: float) -> QRectF:
        """Parte ritagliata, in pixel di un'immagine di img_w × img_h (foto non specchiata)."""
        x0, y0, x1, y1 = self.crop
        return QRectF(x0 * img_w, y0 * img_h, (x1 - x0) * img_w, (y1 - y0) * img_h)

    def source_ratio(self) -> float:
        """Proporzioni (larghezza / altezza) della foto ritagliata: le usano i layout e «Proporzioni foto»."""
        pm = self.pixmap
        if pm.width() <= 0 or pm.height() <= 0:
            return 1.0
        src = self._crop_rect(pm.width(), pm.height())
        return src.width() * self.stretch / src.height() if src.height() > 0 else 1.0

    def apply_crop(self, crop, fit_cell: bool = True):
        """
        Imposta il ritaglio e riparte da un'inquadratura pulita (zoom 100%, centrata).
        Con fit_cell il riquadro prende la forma del ritaglio, tenendo fermo il centro: una foto libera
        mantiene circa la stessa area, una foto nella disposizione resta dentro il suo spazio.
        """
        self.crop = clean_crop(crop)
        self.inner_zoom = 1.0
        self.pan_x = self.pan_y = 0.0
        self.saved_cell = None
        if fit_cell and not self.is_missing:
            ratio = self.source_ratio()
            center = self.mapToScene(QPointF(self.cell_w / 2.0, self.cell_h / 2.0))
            if self.free:
                area = self.cell_w * self.cell_h
                new_w, new_h = math.sqrt(area * ratio), math.sqrt(area / ratio)
            else:
                new_w = min(self.cell_w, self.cell_h * ratio)
                new_h = new_w / ratio
            self.set_cell_size(new_w, new_h)
            self.setPos(center - QPointF(self.cell_w / 2.0, self.cell_h / 2.0))
        self.update()

    def zoom_by(self, step: float):
        self.inner_zoom = max(1.0, min(4.0, self.inner_zoom + step))
        self.update()
        self.geometry_changed.emit(self)
        self.edit_finished.emit()

    def _rotated_cell_extent(self) -> Tuple[float, float]:
        """Ingombro della cella vista nel sistema di riferimento ruotato dell'immagine."""
        th = math.radians(self.inner_rotation)
        c, s = abs(math.cos(th)), abs(math.sin(th))
        return self.cell_w * c + self.cell_h * s, self.cell_w * s + self.cell_h * c

    def _image_transform(self) -> QTransform:
        """Dal sistema dell'immagine (origine al centro della cella, assi ruotati) alle coordinate della cella."""
        t = QTransform()
        t.translate(self.cell_w / 2.0, self.cell_h / 2.0)
        t.rotate(self.inner_rotation)
        t.scale(-1.0 if self.flip_h else 1.0, -1.0 if self.flip_v else 1.0)
        return t

    def _cover_geometry(self, img_w: float, img_h: float) -> Tuple[float, float, float, float, float]:
        """
        Restituisce (scala, dx, dy, draw_w, draw_h) per object-fit: cover + zoom + pan + rotazione interna.
        Il rettangolo (dx, dy, draw_w, draw_h) è nel sistema di _image_transform(): la foto ruotata
        copre sempre l'intera cella, così non compaiono mai angoli vuoti.
        """
        img_w = img_w * self.stretch
        need_w, need_h = self._rotated_cell_extent()
        if self.fit_mode == "contain":
            # Foto intera: l'immagine (ruotata) entra tutta nel riquadro
            th = math.radians(self.inner_rotation)
            c, s = abs(math.cos(th)), abs(math.sin(th))
            box_w, box_h = img_w * c + img_h * s, img_w * s + img_h * c
            scale_cover = min(self.cell_w / box_w, self.cell_h / box_h) * self.inner_zoom
        else:
            scale_cover = max(need_w / img_w, need_h / img_h) * self.inner_zoom
        draw_w = img_w * scale_cover
        draw_h = img_h * scale_cover
        max_dx = max(0.0, (draw_w - need_w) / 2.0)
        max_dy = max(0.0, (draw_h - need_h) / 2.0)
        dx = -draw_w / 2.0 + (self.pan_x * max_dx)
        dy = -draw_h / 2.0 + (self.pan_y * max_dy)
        return scale_cover, dx, dy, draw_w, draw_h

    def _pan_margins(self) -> Tuple[float, float]:
        pm = self.pixmap
        if pm.width() <= 0 or pm.height() <= 0:
            return 0.0, 0.0
        src = self._crop_rect(pm.width(), pm.height())
        _, _, _, draw_w, draw_h = self._cover_geometry(src.width(), src.height())
        need_w, need_h = self._rotated_cell_extent()
        return max(0.0, (draw_w - need_w) / 2.0), max(0.0, (draw_h - need_h) / 2.0)

    def boundingRect(self) -> QRectF:
        margin = max(self._handle_size() + 4.0 / self._view_scale(), self._shadow_extent() * 1.4)
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
        w, h = self.cell_w, self.cell_h
        # Prima gli angoli (mantengono le proporzioni), poi i lati (cambiano la forma)
        return {
            "tl": QRectF(-half, -half, hs, hs),
            "tr": QRectF(w - half, -half, hs, hs),
            "bl": QRectF(-half, h - half, hs, hs),
            "br": QRectF(w - half, h - half, hs, hs),
            "t": QRectF(w / 2.0 - half, -half, hs, hs),
            "b": QRectF(w / 2.0 - half, h - half, hs, hs),
            "l": QRectF(-half, h / 2.0 - half, hs, hs),
            "r": QRectF(w - half, h / 2.0 - half, hs, hs),
        }

    def _handle_at(self, pos: QPointF) -> Optional[str]:
        if not self.isSelected() or self.locked:
            return None
        grow = self._handle_size() * 0.4
        # Su una foto piccola i quadratini si sovrappongono: vince quello più vicino al puntatore
        hits = [(QLineF(rect.center(), pos).length(), name) for name, rect in self._get_handle_rects().items()
                if rect.adjusted(-grow, -grow, grow, grow).contains(pos)]
        return min(hits)[1] if hits else None

    # ---------- Disegno ----------
    def _shadow_extent(self) -> float:
        return 0.0 if self.shadow <= 0 else min(self.cell_w, self.cell_h) * 0.05 + 8.0

    def _paint_shadow(self, painter: QPainter, radius: float):
        """Ombra morbida sotto la foto: rettangoli arrotondati sempre più piccoli e trasparenti."""
        ext = self._shadow_extent()
        steps = 12
        alpha = max(1, min(255, round(255 * (self.shadow / 100.0) * 0.075)))
        off = ext * 0.35
        painter.save()
        painter.setPen(Qt.PenStyle.NoPen)
        painter.setBrush(QColor(0, 0, 0, alpha))
        for i in range(steps):
            g = ext * (1.0 - i / steps) * 0.6
            painter.drawRoundedRect(QRectF(-g, -g + off, self.cell_w + 2 * g, self.cell_h + 2 * g), radius + g, radius + g)
        painter.restore()

    def paint(self, painter: QPainter, option, widget=None):
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, True)

        cell_rect = QRectF(0, 0, self.cell_w, self.cell_h)
        scene = self.scene()
        is_exporting = getattr(scene, "is_exporting", False) if scene else False
        clean = is_exporting or (getattr(scene, "clean_render", False) if scene else False)

        # Creazione percorso con angoli arrotondati
        path = QPainterPath()
        radius = min(self.border_radius, self.cell_w / 2.0, self.cell_h / 2.0)
        path.addRoundedRect(cell_rect, radius, radius)

        if self.shadow > 0:
            self._paint_shadow(painter, radius)

        painter.save()
        painter.setClipPath(path)
        if is_exporting:
            painter.save()
            self._paint_full_resolution(painter, cell_rect)
            painter.restore()
        else:
            sharp = self._needs_sharp(painter)
            if sharp:
                IMAGE_CACHE.request_hires(self.image_path)  # In sottofondo: per ora si usa l'anteprima
            pm = self.display_pixmap(sharp)
            if pm.width() > 0 and pm.height() > 0:
                src = self._crop_rect(pm.width(), pm.height())
                _, dx, dy, draw_w, draw_h = self._cover_geometry(src.width(), src.height())
                painter.save()
                painter.setTransform(self._image_transform(), True)
                painter.drawPixmap(QRectF(dx, dy, draw_w, draw_h), pm, src)
                painter.restore()
            elif not clean and self.is_missing:
                self._paint_missing(painter, cell_rect)
        if not self.is_missing:
            self._paint_effects(painter, cell_rect)
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

        if clean:
            return

        accent = QColor(THEME["accent"])
        if self.isSelected():
            # Riquadro di trasformazione: filo sottile sul bordo + maniglie quadrate bianche
            sel_pen = QPen(accent, 1.5)
            sel_pen.setCosmetic(True)
            painter.setPen(sel_pen)
            painter.setBrush(Qt.BrushStyle.NoBrush)
            painter.drawRect(cell_rect)
            if radius > 0:
                soft = QColor(accent)
                soft.setAlpha(120)
                soft_pen = QPen(soft, 1.0, Qt.PenStyle.DashLine)
                soft_pen.setCosmetic(True)
                painter.setPen(soft_pen)
                painter.drawPath(path)

            if self.locked:
                draw_lock_badge(painter, self._view_scale())
            else:
                painter.setRenderHint(QPainter.RenderHint.Antialiasing, False)
                handle_pen = QPen(QColor("#1A1A1A"), 1.0)
                handle_pen.setCosmetic(True)
                painter.setPen(handle_pen)
                painter.setBrush(QBrush(QColor("#FFFFFF")))
                for rect in self._get_handle_rects().values():
                    c = rect.center()
                    s = rect.width() * 0.36
                    painter.drawRect(QRectF(c.x() - s, c.y() - s, 2 * s, 2 * s))
                painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        elif self._hovered:
            hover = QColor(accent)
            hover.setAlpha(170)
            hover_pen = QPen(hover, 1.0)
            hover_pen.setCosmetic(True)
            painter.setPen(hover_pen)
            painter.setBrush(Qt.BrushStyle.NoBrush)
            painter.drawPath(path)

    def _paint_missing(self, painter: QPainter, cell_rect: QRectF):
        """Segnaposto di una foto non trovata: tiene il posto e ricorda il nome del file."""
        painter.fillRect(cell_rect, QColor(THEME["raised"]))
        pen = QPen(QColor(THEME["muted"]), 1.5, Qt.PenStyle.DashLine)
        pen.setCosmetic(True)
        painter.setPen(pen)
        painter.drawRect(cell_rect.adjusted(1, 1, -1, -1))
        side = min(self.cell_w, self.cell_h)
        icon = max(24, int(side * 0.16))
        c = cell_rect.center()
        icon_pm = icon_pixmap("image", THEME["muted"], icon)
        painter.drawPixmap(QRectF(c.x() - icon / 2.0, c.y() - icon * 1.1, icon, icon), icon_pm, QRectF(icon_pm.rect()))
        px = int(max(12, min(56, side * 0.065)))
        painter.setPen(QColor(THEME["text"]))
        painter.setFont(ui_font(px))
        text_rect = QRectF(cell_rect.left() + 8, c.y() + icon * 0.1, cell_rect.width() - 16, px * 3.2)
        name = os.path.basename(self.image_path)
        painter.drawText(text_rect, Qt.AlignmentFlag.AlignHCenter | Qt.AlignmentFlag.AlignTop,
                         "Foto mancante\n" + painter.fontMetrics().elidedText(
                             name, Qt.TextElideMode.ElideMiddle, int(text_rect.width())))

    def export_side(self, out_scale: float) -> Optional[int]:
        """
        Lato lungo (in pixel) a cui serve leggere l'originale per esportare a `out_scale` pixel
        per unità della tela: la foto intera disegnata, con un po' di margine. None se mancante.
        """
        pm = self.pixmap
        if pm.width() <= 0 or pm.height() <= 0:
            return None
        src = self._crop_rect(pm.width(), pm.height())
        draw_w, draw_h = self._cover_geometry(src.width(), src.height())[3:5]
        # Con un ritaglio serve l'originale più grande: la parte ritagliata deve arrivare a draw_w × draw_h
        x0, y0, x1, y1 = self.crop
        whole_w, whole_h = draw_w / max(1e-6, x1 - x0), draw_h / max(1e-6, y1 - y0)
        # Lato lungo dell'originale che dà almeno whole_w px in larghezza e whole_h px in altezza
        long_side = max(pm.width(), pm.height())
        need = max(whole_w * long_side / pm.width(), whole_h * long_side / pm.height())
        return max(64, math.ceil(need * out_scale * 1.1))

    def _paint_full_resolution(self, painter: QPainter, cell_rect: QRectF):
        """In esportazione ricampiona dall'originale solo la porzione visibile, alla risoluzione di uscita."""
        t0 = painter.worldTransform()
        full = IMAGE_CACHE.full(self.image_path, self.export_side(math.hypot(t0.m11(), t0.m12()) or 1.0))
        img_t = self._image_transform()
        painter.setTransform(img_t, True)
        if full is None:
            pm = self.display_pixmap()
            if pm.width() > 0 and pm.height() > 0:
                src = self._crop_rect(pm.width(), pm.height())
                _, dx, dy, dw, dh = self._cover_geometry(src.width(), src.height())
                painter.drawPixmap(QRectF(dx, dy, dw, dh), pm, src)
            return

        src = self._crop_rect(full.width, full.height)
        img_w, img_h = src.width(), src.height()
        _, dx, dy, draw_w, draw_h = self._cover_geometry(img_w, img_h)
        kx, ky = draw_w / max(1e-6, img_w), draw_h / max(1e-6, img_h)
        cell_in_img = img_t.inverted()[0].mapRect(cell_rect)
        visible = QRectF(dx, dy, draw_w, draw_h).intersected(cell_in_img)
        if visible.isEmpty():
            return

        t = painter.worldTransform()
        device_scale = math.hypot(t.m11(), t.m12()) or 1.0
        out_w = max(1, round(visible.width() * device_scale))
        out_h = max(1, round(visible.height() * device_scale))

        # Porzione dell'originale da leggere (dentro il ritaglio)
        box = (
            src.left() + max(0.0, (visible.left() - dx) / kx),
            src.top() + max(0.0, (visible.top() - dy) / ky),
            src.left() + min(img_w, (visible.right() - dx) / kx),
            src.top() + min(img_h, (visible.bottom() - dy) / ky),
        )
        resized = full.resize((out_w, out_h), Image.Resampling.LANCZOS, box=box)
        # Larghezza che avrebbe la foto intera a questa risoluzione: la nitidezza resta come in anteprima
        whole_w = out_h * full.height / max(1e-6, box[3] - box[1]) * full.width / full.height
        resized = apply_adjustments(resized, self.adjust, detail_scale=whole_w / 1000.0, auto_lut=self.auto_lut())
        painter.drawImage(visible, pil_to_qimage(resized))

    # ---------- Vignettatura e grana ----------
    def _visible_image_rect(self, cell_rect: QRectF) -> QRectF:
        """Parte del riquadro coperta dalla foto (con «Foto intera» resta fuori lo spazio vuoto)."""
        pm = self.pixmap
        if pm.width() <= 0 or pm.height() <= 0:
            return cell_rect
        src = self._crop_rect(pm.width(), pm.height())
        _, dx, dy, dw, dh = self._cover_geometry(src.width(), src.height())
        return self._image_transform().mapRect(QRectF(dx, dy, dw, dh)).intersected(cell_rect)

    def _paint_effects(self, painter: QPainter, cell_rect: QRectF):
        """
        Vignettatura e grana disegnate sopra la parte visibile della foto, in misure della tela:
        sono uguali sulla tela, nell'anteprima e nell'esportazione a qualsiasi risoluzione.
        """
        vignette = self.adjust.get("vignette", 0)
        grain = self.adjust.get("grain", 0)
        if not (vignette or grain) or self._showing_original():
            return
        area = self._visible_image_rect(cell_rect)
        if area.isEmpty():
            return
        if vignette:
            # Ellisse che tocca gli angoli: bordi più scuri (−) o più chiari (+), centro intatto
            strength = min(1.0, abs(vignette) / 100.0)
            base = QColor(0, 0, 0) if vignette < 0 else QColor(255, 255, 255)
            grad = QRadialGradient(QPointF(0, 0), 1.0)
            for stop, k in ((0.0, 0.0), (0.42, 0.0), (0.72, 0.38), (1.0, 0.9)):
                c = QColor(base)
                c.setAlphaF(strength * k)
                grad.setColorAt(stop, c)
            painter.save()
            painter.translate(area.center())
            painter.scale(area.width() / 2.0 * math.sqrt(2.0), area.height() / 2.0 * math.sqrt(2.0))
            painter.setPen(Qt.PenStyle.NoPen)
            painter.setBrush(QBrush(grad))
            painter.drawRect(QRectF(-1.0, -1.0, 2.0, 2.0))
            painter.restore()
        if grain:
            painter.save()
            painter.setCompositionMode(QPainter.CompositionMode.CompositionMode_Overlay)
            painter.setOpacity(painter.opacity() * min(1.0, grain / 100.0) * 0.6)
            brush = QBrush(grain_tile())
            brush.setTransform(QTransform.fromScale(1.3, 1.3))  # Un granello ≈ 1,3 px della tela
            painter.fillRect(area, brush)
            painter.restore()

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
            # Il cursore segue la rotazione della foto (diagonale sugli angoli, dritto sui lati)
            offset = {"tl": 45, "br": 45, "tr": -45, "bl": -45, "l": 0, "r": 0, "t": 90, "b": 90}[handle]
            angle = (self.rotation() + offset) % 180
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
            self.setCursor(QCursor(Qt.CursorShape.ArrowCursor if self.locked else Qt.CursorShape.OpenHandCursor))
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
                self._resize_start = (self.cell_w, self.cell_h, self.stretch)
                event.accept()
                return
            elif self.locked:
                # Foto bloccata: si può selezionare, ma non spostare né ridimensionare
                super().mousePressEvent(event)
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
            # Angoli: proporzioni bloccate. Lati: la foto si stira. Con Shift si cambia solo il riquadro.
            self._resize_to(event.scenePos(), not (event.modifiers() & Qt.KeyboardModifier.ShiftModifier))
            event.accept()
            return

        if self._panning_inner:
            delta = event.scenePos() - self._last_mouse_scene_pos
            self._last_mouse_scene_pos = event.scenePos()
            # Il pan segue esattamente il cursore, nel sistema di riferimento (ruotato) della foto
            local = QTransform().rotate(-(self.rotation() + self.inner_rotation)).map(delta)
            sx = -1.0 if self.flip_h else 1.0
            sy = -1.0 if self.flip_v else 1.0
            max_dx, max_dy = self._pan_margins()
            if max_dx > 0.5:
                self.pan_x = max(-1.0, min(1.0, self.pan_x + sx * local.x() / max_dx))
            if max_dy > 0.5:
                self.pan_y = max(-1.0, min(1.0, self.pan_y + sy * local.y() / max_dy))
            self.update()
            self.geometry_changed.emit(self)
            event.accept()
            return

        super().mouseMoveEvent(event)
        if self._dragging:
            self._apply_snap()
            self.geometry_changed.emit(self)

    def mouseDoubleClickEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton and not self.is_missing:
            self.crop_requested.emit(self)
            event.accept()
            return
        super().mouseDoubleClickEvent(event)

    def _resize_to(self, scene_pos: QPointF, keep_ratio: bool):
        handle = self._resizing_handle
        sx = 1.0 if "r" in handle else -1.0
        sy = 1.0 if "b" in handle else -1.0
        local = QTransform().rotate(-self.rotation()).map(scene_pos - self._resize_anchor_scene)
        new_w = max(self.MIN_CELL, sx * local.x())
        new_h = max(self.MIN_CELL, sy * local.y())

        if handle in ("l", "r", "t", "b"):
            # Lato: cambia una sola misura, l'altra resta com'era. Senza Shift la foto si stira insieme
            # al riquadro (stesso contenuto visibile, deformato); con Shift riempie la nuova forma.
            start_w, start_h, start_stretch = self._resize_start
            if handle in ("l", "r"):
                new_h = start_h
            else:
                new_w = start_w
            if keep_ratio:
                self.stretch = start_stretch * (new_w / start_w) * (start_h / new_h)
            else:
                self.stretch = start_stretch
        elif keep_ratio:
            ratio = self._resize_ratio
            if new_w / ratio >= new_h:
                new_h = new_w / ratio
            else:
                new_w = new_h * ratio

        self.set_cell_size(new_w, new_h)
        anchor_local = QPointF(0.0 if sx > 0 else self.cell_w, 0.0 if sy > 0 else self.cell_h)
        self.setPos(self._pos_for_local_point(anchor_local, self._resize_anchor_scene))
        self.geometry_changed.emit(self)

    def snap_rect(self) -> QRectF:
        """Riquadro in scena usato come riferimento dallo snap degli altri elementi."""
        return self.mapRectToScene(QRectF(0, 0, self.cell_w, self.cell_h))

    def _apply_snap(self):
        """Snap magnetico ai bordi/centri di tela, frame e altri elementi. Sposta insieme tutta la selezione."""
        snap_selection(self, self.snap_rect(), self._view_scale())

    def mouseReleaseEvent(self, event):
        if self._resizing_handle:
            self.saved_cell = None  # Ridimensionata a mano: il riquadro "di prima" non vale più
        was_editing = self._resizing_handle or self._panning_inner or self._dragging
        was_dragged = self._dragging
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
            if was_dragged:
                self.dropped.emit(self)
            self.edit_finished.emit()
