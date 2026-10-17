"""Scena del collage: pagine, sfondo, guide e snap."""
from typing import List, Optional, Tuple

from PyQt6.QtCore import Qt, QRectF, QPointF
from PyQt6.QtGui import (
    QPixmap, QPainter, QPen, QColor, QBrush, QFont, QPainterPath, QTransform, QLinearGradient
)
from PyQt6.QtWidgets import QGraphicsScene
from PIL import ImageEnhance, ImageFilter

from scrollr.canvas.photo_item import PhotoItem
from scrollr.canvas.text_item import TextItem
from scrollr.icons import icon_pixmap
from scrollr.imaging import IMAGE_CACHE, pil_to_qimage, qimage_to_pil
from scrollr.theme import THEME, is_light, ui_font


class CollageScene(QGraphicsScene):
    """
    Scena grafica che gestisce la tela del collage (in formato 3:4 o altro),
    lo sfondo, i frame multipli del carosello e le linee guida.
    La scena è più grande della tela, così si può fare pan/zoom e recuperare foto finite fuori.
    """
    DOT_SPACING = 24

    def __init__(self, parent=None):
        super().__init__(parent)
        self.frame_w = 1080
        self.frame_h = 1440  # Default 3:4
        self.num_frames = 1
        self.bg_color = QColor("#FFFFFF")
        # Sfondo: "solid" = tinta unita, "gradient" = sfumatura tra due colori, "blur" = foto sfocata
        self.bg_mode = "solid"
        self.bg_color2 = QColor("#2680EB")
        self.bg_direction = "vertical"   # "vertical", "horizontal", "diagonal"
        self.bg_blur_path = ""
        self.bg_blur_amount = 50
        self.bg_dim = 15
        self._blur_cache: Optional[Tuple[tuple, QPixmap]] = None
        self.show_guides = True
        self.is_exporting = False
        self.clean_render = False        # Anteprima: niente guide, etichette né selezione
        self._snap_x: List[float] = []
        self._snap_y: List[float] = []
        self._dot_tile = self._make_dot_tile()
        self._empty_icon_dark = icon_pixmap("image", "#555555", 44)
        self._empty_icon_light = icon_pixmap("image", "#C8C8C8", 44)
        self.update_canvas_rect()

    def _make_dot_tile(self) -> QPixmap:
        # Area di lavoro (pasteboard) a tinta unita, grigio neutro come negli editor professionali
        s = self.DOT_SPACING
        tile = QPixmap(s, s)
        tile.fill(QColor(THEME["backdrop"]))
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

    def blurred_background(self) -> Optional[QPixmap]:
        """Foto di sfondo sfocata e scurita (calcolata su una versione piccola: è sfocata comunque)."""
        if not self.bg_blur_path:
            return None
        key = (self.bg_blur_path, self.bg_blur_amount, self.bg_dim)
        if self._blur_cache is not None and self._blur_cache[0] == key:
            return self._blur_cache[1]
        src = IMAGE_CACHE.preview(self.bg_blur_path)
        if src.isNull():
            try:
                src = IMAGE_CACHE.load(self.bg_blur_path)
            except Exception:
                return None
        img = qimage_to_pil(src.toImage()).convert("RGB")
        img.thumbnail((480, 480))
        if self.bg_blur_amount > 0:
            img = img.filter(ImageFilter.GaussianBlur(radius=self.bg_blur_amount / 4.0))
        if self.bg_dim > 0:
            img = ImageEnhance.Brightness(img).enhance(1.0 - self.bg_dim / 100.0)
        pm = QPixmap.fromImage(pil_to_qimage(img))
        self._blur_cache = (key, pm)
        return pm

    def paint_canvas_background(self, painter: QPainter, rect: QRectF):
        if self.bg_mode == "gradient":
            if self.bg_direction == "horizontal":
                grad = QLinearGradient(rect.topLeft(), rect.topRight())
            elif self.bg_direction == "diagonal":
                grad = QLinearGradient(rect.topLeft(), rect.bottomRight())
            else:
                grad = QLinearGradient(rect.topLeft(), rect.bottomLeft())
            grad.setColorAt(0.0, self.bg_color)
            grad.setColorAt(1.0, self.bg_color2)
            painter.fillRect(rect, QBrush(grad))
            return
        if self.bg_mode == "blur":
            pm = self.blurred_background()
            if pm is not None and pm.width() > 0 and pm.height() > 0:
                # Copre tutta la tela (anche un carosello lungo) tagliando il necessario
                scale = max(rect.width() / pm.width(), rect.height() / pm.height())
                src_w, src_h = rect.width() / scale, rect.height() / scale
                src = QRectF((pm.width() - src_w) / 2.0, (pm.height() - src_h) / 2.0, src_w, src_h)
                painter.save()
                painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, True)
                painter.drawPixmap(rect, pm, src)
                painter.restore()
                return
        painter.fillRect(rect, self.bg_color)

    def drawBackground(self, painter: QPainter, rect: QRectF):
        canvas_rect = self.canvas_rect()
        if not (self.is_exporting or self.clean_render):
            t = painter.worldTransform()
            painter.save()
            painter.resetTransform()
            # Puntini ancorati alla tela, così scorrono insieme al pan
            brush = QBrush(self._dot_tile)
            origin = t.map(QPointF(0, 0))
            brush.setTransform(QTransform.fromTranslate(origin.x() % self.DOT_SPACING, origin.y() % self.DOT_SPACING))
            painter.fillRect(t.mapRect(rect), brush)

            # Ombra netta e corta sotto il documento, con filo scuro di contorno
            canvas_dev = t.mapRect(canvas_rect)
            painter.setPen(Qt.PenStyle.NoPen)
            for i in range(1, 7):
                painter.setBrush(QColor(0, 0, 0, 22))
                painter.drawRect(canvas_dev.adjusted(-i + 2, -i + 3, i + 2, i + 3))
            painter.setPen(QPen(QColor(0, 0, 0, 200), 1.0))
            painter.setBrush(Qt.BrushStyle.NoBrush)
            painter.drawRect(canvas_dev.adjusted(-1, -1, 0, 0))
            painter.restore()
        self.paint_canvas_background(painter, canvas_rect)

    def drawForeground(self, painter: QPainter, rect: QRectF):
        if self.is_exporting or self.clean_render:
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
        has_photos = any(isinstance(it, (PhotoItem, TextItem)) for it in self.items())
        if self.show_guides and has_photos:
            # Linee guida centrali leggere
            guide = QColor(THEME["guide"])
            guide.setAlpha(130)
            guide_pen = QPen(guide, 1.0, Qt.PenStyle.DashLine)
            guide_pen.setCosmetic(True)
            painter.setPen(guide_pen)
            painter.drawLine(QPointF(0, self.frame_h / 2.0), QPointF(canvas_rect.width(), self.frame_h / 2.0))
            for i in range(self.num_frames):
                cx = i * self.frame_w + self.frame_w / 2.0
                painter.drawLine(QPointF(cx, 0), QPointF(cx, self.frame_h))

        # Giunzioni tra le pagine del carosello: sempre visibili, come guide piene
        if self.num_frames > 1:
            sep_pen = QPen(QColor(THEME["guide"]), 1.0, Qt.PenStyle.SolidLine)
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
        painter.setFont(ui_font(11))
        for i in range(self.num_frames):
            top_left = t.map(QPointF(i * self.frame_w, 0))
            label = f"Pagina {i + 1}" if self.num_frames > 1 else f"{self.frame_w} × {self.frame_h} px"
            painter.setPen(QColor(THEME["muted"]))
            painter.drawText(QPointF(top_left.x() + 1, top_left.y() - 8), label)

        if not has_photos:
            canvas_dev = t.mapRect(canvas_rect)
            if canvas_dev.width() > 220 and canvas_dev.height() > 160:
                c = canvas_dev.center()
                icon = self._empty_icon_light if not light_bg else self._empty_icon_dark
                painter.drawPixmap(QPointF(c.x() - 22, c.y() - 58), icon)
                painter.setPen(QColor("#3A3A3A") if light_bg else QColor(THEME["text"]))
                painter.setFont(ui_font(19, QFont.Weight.DemiBold, "display"))
                painter.drawText(QRectF(canvas_dev.left(), c.y() - 4, canvas_dev.width(), 30),
                                 Qt.AlignmentFlag.AlignHCenter, "Trascina qui le tue foto")
                painter.setPen(QColor("#7A7A7A") if light_bg else QColor(THEME["muted"]))
                painter.setFont(ui_font(13))
                painter.drawText(QRectF(canvas_dev.left(), c.y() + 28, canvas_dev.width(), 24),
                                 Qt.AlignmentFlag.AlignHCenter, "oppure usa Aggiungi foto (Ctrl+O)")
        painter.restore()
