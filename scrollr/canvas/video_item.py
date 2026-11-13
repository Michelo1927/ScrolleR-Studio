"""
Video sulla tela: si comporta come una foto (riquadro, ritaglio, bordi, ombra, aggancio), mostra la
copertina e si può riprodurre (senza audio) per vedere il taglio. Le regolazioni colore non valgono.
"""
from typing import Optional, Tuple

from PyQt6.QtCore import QElapsedTimer, QPointF, QRectF, Qt, QTimer, pyqtSignal
from PyQt6.QtGui import QColor, QFont, QFontMetricsF, QPainter, QPixmap, QPolygonF
from PyQt6.QtWidgets import QGraphicsItem
from PIL import Image

from scrollr.canvas.photo_item import PhotoItem
from scrollr.imaging import IMAGE_CACHE, NEUTRAL_ADJUST, pil_to_qimage
from scrollr.theme import ui_font
from scrollr.video import FrameReader, grab_frame, video_info


def format_time(seconds: float) -> str:
    """Durata leggibile: «0:07», «1:05», con i decimi sotto i 10 secondi («0:04,5»)."""
    seconds = max(0.0, seconds)
    m, s = divmod(seconds, 60.0)
    if m < 1 and s < 10 and abs(s - round(s)) >= 0.05:
        return f"0:{s:04.1f}".replace(".", ",")
    return f"{int(m)}:{int(round(s)) if round(s) < 60 else 59:02d}"


class VideoItem(PhotoItem):
    playing_changed = pyqtSignal(object)  # Riproduzione sulla tela avviata o fermata
    PLAY_SIDE = 960                       # Fotogrammi della riproduzione: leggeri, bastano per guardare
    EXPORT_RESAMPLE = Image.Resampling.BILINEAR  # Un fotogramma alla volta: conta la velocità
    MISSING_LABEL = "Video mancante"

    def __init__(self, image_path: str, cell_w: float = 400.0, cell_h: float = 500.0, uid: Optional[int] = None):
        super().__init__(image_path, cell_w, cell_h, uid)
        self.trim_start = 0.0                  # Taglio: inizio e fine in secondi (None = fino alla fine)
        self.trim_end: Optional[float] = None
        self.muted = False                     # Audio tolto dall'MP4 esportato
        self.poster = 0.0                      # Copertina: secondo mostrato sulla tela e nel collage intero
        self._poster_cache: Optional[Tuple[float, QPixmap]] = None
        self._export_poster: Optional[Tuple[tuple, Image.Image]] = None
        self._export_frame: Optional[Image.Image] = None
        self._reader: Optional[FrameReader] = None
        self._live: Optional[QPixmap] = None
        self._live_src = None
        self._timer = QTimer(self)
        self._timer.setInterval(33)
        self._timer.timeout.connect(self._tick)
        self._clock = QElapsedTimer()

    def _info(self) -> dict:
        """Letta dal file (in cache): vale anche dopo «Ricollega», quando il percorso cambia."""
        try:
            return video_info(self.image_path)
        except Exception:
            return {"duration": 0.0, "audio": False}

    @property
    def duration(self) -> float:
        return float(self._info()["duration"])

    @property
    def has_audio(self) -> bool:
        return bool(self._info()["audio"])

    # Le regolazioni colore non valgono per i video: restano sempre neutre
    @property
    def adjust(self) -> dict:
        return dict(NEUTRAL_ADJUST)

    @adjust.setter
    def adjust(self, value):
        pass

    # ---------- Taglio ----------
    def clip_end(self) -> float:
        end = self.trim_end if self.trim_end is not None else self.duration
        if self.duration > 0:
            end = min(end, self.duration)
        return max(self.trim_start + 0.1, end)

    def clip_length(self) -> float:
        return max(0.1, self.clip_end() - self.trim_start)

    def set_trim(self, start: float, end: Optional[float]):
        dur = self.duration if self.duration > 0 else None
        start = max(0.0, float(start))
        if dur is not None:
            start = min(start, max(0.0, dur - 0.1))
        if end is not None:
            end = max(start + 0.1, float(end))
            if dur is not None and end >= dur - 0.05:
                end = None  # Fino alla fine
        self.trim_start, self.trim_end = start, end
        if self.is_playing:
            self._clock.restart()
        self.update()

    # ---------- Stato ----------
    def get_state(self) -> dict:
        s = super().get_state()
        s.update(kind="video", trim_start=round(self.trim_start, 3),
                 trim_end=None if self.trim_end is None else round(self.trim_end, 3),
                 muted=self.muted, poster=round(self.poster, 3))
        return s

    def set_state(self, s: dict):
        super().set_state(s)
        end = s.get("trim_end")
        self.set_trim(s.get("trim_start", 0.0), None if end is None else end)
        self.muted = bool(s.get("muted", False))
        self.poster = max(0.0, float(s.get("poster", 0.0)))
        self.update()

    # ---------- Disegno ----------
    def display_pixmap(self, sharp: bool = False) -> QPixmap:
        if self._live is not None:
            return self._live
        if self.poster <= 0.01 or self.is_missing:
            return self.pixmap
        if self._poster_cache is None or self._poster_cache[0] != self.poster:
            try:
                img = grab_frame(self.image_path, self.poster, IMAGE_CACHE.PREVIEW_MAX_SIDE)
                pm = QPixmap.fromImage(pil_to_qimage(img))
            except Exception:
                pm = self.pixmap
            self._poster_cache = (self.poster, pm)
        return self._poster_cache[1]

    def _needs_sharp(self, painter: QPainter) -> bool:
        return False  # Niente versione nitida: per lo zoom basta l'anteprima del fotogramma

    def _export_source(self, side: Optional[int]) -> Optional[Image.Image]:
        """In esportazione: il fotogramma del momento (MP4) oppure la copertina (immagini)."""
        if self._export_frame is not None:
            return self._export_frame
        key = (self.poster, side)
        if self._export_poster is None or self._export_poster[0] != key:
            try:
                self._export_poster = (key, grab_frame(self.image_path, self.poster, side))
            except Exception:
                return None
        return self._export_poster[1]

    def export_frame_size(self, px: float) -> Optional[Tuple[int, int]]:
        """
        Misura (larghezza, altezza come appare) a cui leggere i fotogrammi perché, esportando a `px` pixel
        per unità della tela, la parte visibile vada 1:1 sui pixel dell'MP4: così basta ritagliarla.
        None se servirebbe un'immagine enorme (zoom forte): allora si legge a export_side() e si ricampiona.
        """
        pm = self.pixmap
        if pm.width() <= 0 or pm.height() <= 0:
            return None
        src = self._crop_rect(pm.width(), pm.height())
        draw_w, draw_h = self._cover_geometry(src.width(), src.height())[3:5]
        x0, y0, x1, y1 = self.crop
        # Il fotogramma tiene le proporzioni vere: lo stiramento lo applica il disegno (con un video
        # stirato il ritaglio 1:1 non è possibile e _resample ricampiona, come per le foto)
        w = round(draw_w / max(1e-6, self.stretch) / max(1e-6, x1 - x0) * px)
        h = round(draw_h / max(1e-6, y1 - y0) * px)
        if w < 2 or h < 2 or w * h > 24_000_000:
            return None
        return w, h

    def _resample(self, full: Image.Image, size: Tuple[int, int], box: tuple) -> Image.Image:
        """Fotogramma letto già alla misura giusta: la porzione si ritaglia, senza ricampionare."""
        out_w, out_h = size
        x, y = round(box[0]), round(box[1])
        if (abs(box[2] - box[0] - out_w) < 1.0 and abs(box[3] - box[1] - out_h) < 1.0
                and x >= 0 and y >= 0 and x + out_w <= full.width and y + out_h <= full.height):
            return full.crop((x, y, x + out_w, y + out_h))
        return super()._resample(full, size, box)

    def set_export_frame(self, img: Optional[Image.Image]):
        self._export_frame = img
        if img is None:
            self._export_poster = None

    def paint(self, painter: QPainter, option, widget=None):
        super().paint(painter, option, widget)
        scene = self.scene()
        if scene is None or getattr(scene, "is_exporting", False) or getattr(scene, "clean_render", False) \
                or self.is_missing:
            return
        self._paint_badge(painter)

    def _paint_badge(self, painter: QPainter):
        """Etichetta in alto a sinistra: ▶ (o pausa) e durata del taglio, a misura costante sullo schermo."""
        k = 1.0 / self._view_scale()
        font = ui_font(10, QFont.Weight.DemiBold)
        text = format_time(self.clip_length())
        if self.muted or not self.has_audio:
            text += "  muto"
        fm = QFontMetricsF(font)
        h = 18.0
        w = 22.0 + fm.horizontalAdvance(text) + 8.0
        if w * k > self.cell_w - 8 * k or h * k > self.cell_h - 8 * k:
            return
        painter.save()
        painter.translate(6 * k, 6 * k)
        painter.scale(k, k)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        painter.setPen(Qt.PenStyle.NoPen)
        painter.setBrush(QColor(0, 0, 0, 165))
        painter.drawRoundedRect(QRectF(0, 0, w, h), h / 2.0, h / 2.0)
        painter.setBrush(QColor("#FFFFFF"))
        if self.is_playing:
            painter.drawRect(QRectF(8.0, 5.0, 2.6, 8.0))
            painter.drawRect(QRectF(12.4, 5.0, 2.6, 8.0))
        else:
            painter.drawPolygon(QPolygonF([QPointF(8.0, 4.5), QPointF(15.5, 9.0), QPointF(8.0, 13.5)]))
        painter.setPen(QColor("#FFFFFF"))
        painter.setFont(font)
        painter.drawText(QRectF(20.0, 0, w - 24.0, h), Qt.AlignmentFlag.AlignVCenter | Qt.AlignmentFlag.AlignLeft, text)
        painter.restore()

    # ---------- Riproduzione sulla tela ----------
    @property
    def is_playing(self) -> bool:
        return self._timer.isActive()

    def play(self):
        if self.is_playing or self.is_missing:
            return
        try:
            self._reader = FrameReader(self.image_path, self.PLAY_SIDE)
        except Exception:
            self._reader = None
            return
        self._clock.start()
        self._timer.start()
        self._tick()
        self.playing_changed.emit(self)

    def stop(self):
        if self._reader is None and not self._timer.isActive():
            return
        self._timer.stop()
        if self._reader is not None:
            self._reader.close()
            self._reader = None
        self._live = None
        self._live_src = None
        self.update()
        self.playing_changed.emit(self)

    def current_time(self) -> float:
        """Secondo del video in riproduzione: il taglio si ripete da capo."""
        return self.trim_start + (self._clock.elapsed() / 1000.0) % self.clip_length()

    def _tick(self):
        if self.scene() is None or self._reader is None:
            self.stop()
            return
        try:
            img = self._reader.frame_at(self.current_time())
        except Exception:
            self.stop()
            return
        if img is not None and img is not self._live_src:
            self._live_src = img
            self._live = QPixmap.fromImage(pil_to_qimage(img))
            self.update()

    def itemChange(self, change, value):
        if change == QGraphicsItem.GraphicsItemChange.ItemSceneHasChanged and value is None:
            self.stop()  # Tolto dalla tela (eliminato, annullato…): la riproduzione si ferma
        return super().itemChange(change, value)
