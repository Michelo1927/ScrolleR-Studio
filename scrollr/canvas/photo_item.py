"""Foto interattiva sulla tela."""
import math
from typing import Optional, Tuple

from PyQt6.QtCore import Qt, QRectF, QPointF, pyqtSignal
from PyQt6.QtGui import QPixmap, QPainter, QPen, QColor, QBrush, QPainterPath, QCursor, QTransform
from PyQt6.QtWidgets import QGraphicsObject, QGraphicsItem
from PIL import Image

from scrollr.canvas.text_item import TextItem
from scrollr.icons import draw_lock_badge
from scrollr.imaging import (
    IMAGE_CACHE, NEUTRAL_ADJUST, adjustments_active, apply_adjustments, pil_to_qimage, qimage_to_pil
)
from scrollr.theme import THEME


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
        self.inner_rotation = 0.0   # Rotazione del contenuto dentro la cella (gradi), il riquadro resta fermo

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
        self._adjusted_cache: Optional[Tuple[tuple, QPixmap]] = None

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

    def display_pixmap(self) -> QPixmap:
        """Anteprima con le regolazioni colore applicate (ricalcolata solo quando cambiano)."""
        pm = self.pixmap
        if pm.isNull() or not adjustments_active(self.adjust):
            return pm
        key = (pm.cacheKey(), tuple(sorted(self.adjust.items())))
        if self._adjusted_cache is None or self._adjusted_cache[0] != key:
            out = apply_adjustments(qimage_to_pil(pm.toImage()), self.adjust)
            self._adjusted_cache = (key, QPixmap.fromImage(pil_to_qimage(out)))
        return self._adjusted_cache[1]

    def set_locked(self, locked: bool):
        self.locked = bool(locked)
        self.setFlag(QGraphicsItem.GraphicsItemFlag.ItemIsMovable, not self.locked)
        self.update()

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
        _, _, _, draw_w, draw_h = self._cover_geometry(float(pm.width()), float(pm.height()))
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
        return {
            "tl": QRectF(-half, -half, hs, hs),
            "tr": QRectF(self.cell_w - half, -half, hs, hs),
            "bl": QRectF(-half, self.cell_h - half, hs, hs),
            "br": QRectF(self.cell_w - half, self.cell_h - half, hs, hs),
        }

    def _handle_at(self, pos: QPointF) -> Optional[str]:
        if not self.isSelected() or self.locked:
            return None
        grow = self._handle_size() * 0.4
        for name, rect in self._get_handle_rects().items():
            if rect.adjusted(-grow, -grow, grow, grow).contains(pos):
                return name
        return None

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
            self._paint_full_resolution(painter, cell_rect)
        else:
            pm = self.display_pixmap()
            img_w, img_h = float(pm.width()), float(pm.height())
            if img_w > 0 and img_h > 0:
                _, dx, dy, draw_w, draw_h = self._cover_geometry(img_w, img_h)
                painter.setTransform(self._image_transform(), True)
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

    def _paint_full_resolution(self, painter: QPainter, cell_rect: QRectF):
        """In esportazione ricampiona dall'originale solo la porzione visibile, alla risoluzione di uscita."""
        full = IMAGE_CACHE.full(self.image_path)
        img_t = self._image_transform()
        painter.setTransform(img_t, True)
        if full is None:
            pm = self.display_pixmap()
            if pm.width() > 0 and pm.height() > 0:
                _, dx, dy, dw, dh = self._cover_geometry(float(pm.width()), float(pm.height()))
                painter.drawPixmap(QRectF(dx, dy, dw, dh), pm, QRectF(0, 0, pm.width(), pm.height()))
            return

        img_w, img_h = float(full.width), float(full.height)
        scale, dx, dy, draw_w, draw_h = self._cover_geometry(img_w, img_h)
        cell_in_img = img_t.inverted()[0].mapRect(cell_rect)
        visible = QRectF(dx, dy, draw_w, draw_h).intersected(cell_in_img)
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
        resized = apply_adjustments(resized, self.adjust)
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
            self._resize_to(event.scenePos(), bool(event.modifiers() & Qt.KeyboardModifier.ShiftModifier))
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
                if isinstance(it, (PhotoItem, TextItem)) and not it.locked:
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
