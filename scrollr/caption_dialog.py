"""
Finestra «Sottotitoli»: si scrive (o si incolla) tutto il testo, una frase per riga, e intanto si può far
girare il video con il suo audio (Ctrl+Spazio, anche mentre si scrive).

I tempi si mettono da soli: l'app trova i tratti di parlato nell'audio e ci distribuisce le frasi in
proporzione alla lunghezza, con gli stacchi sulle pause. Si correggono trascinando i bordi sulla striscia
del tempo (o nell'elenco): una frase ritoccata a mano resta ferma e le altre si ridistribuiscono intorno.

Le modifiche restano nella finestra (con un Annulla tutto suo) finché non si preme «Fatto».
"""
import copy
import os
import threading
from typing import List, Optional

from PyQt6.QtCore import QByteArray, QBuffer, QElapsedTimer, QEvent, QIODevice, QObject, QPointF, QRectF, Qt, QTimer, pyqtSignal
from PyQt6.QtGui import QColor, QFont, QFontMetricsF, QImage, QKeySequence, QPainter, QPen, QTextCharFormat, QTextCursor, QTextFormat
from PyQt6.QtWidgets import (
    QAbstractItemView, QAbstractSpinBox, QApplication, QButtonGroup, QComboBox, QDialog, QHBoxLayout,
    QHeaderView, QLabel, QLineEdit, QMessageBox, QPlainTextEdit, QPushButton, QSizePolicy, QStackedWidget,
    QTableWidget, QTableWidgetItem, QTextEdit, QToolButton, QVBoxLayout, QWidget
)

from scrollr.captions import (
    MIN_PHRASE, envelope, find_pauses, fits_two_lines, format_clock, insert_index, is_manual, is_synced,
    join_phrases, make_phrase, merge_lines, parse_clock, phrase_index_at, retime, snap, snap_points,
    split_phrase, split_text
)
from scrollr.imaging import pil_to_qimage
from scrollr.theme import THEME, ui_font
from scrollr.video import LISTEN_RATE, FrameReader, read_audio_mono, stretch_audio, video_info

try:
    from PyQt6.QtMultimedia import QAudioFormat, QAudioSink, QMediaDevices
except ImportError:  # Senza Qt Multimedia il video si guarda e si sincronizza lo stesso, ma muto
    QAudioSink = None

PREVIEW_SIDE = 720   # Fotogrammi dell'anteprima: leggeri


# ================= LETTORE: AUDIO E OROLOGIO =================
class ClipPlayer(QObject):
    """
    Orologio della riproduzione (in secondi del video) e audio: il PCM letto con PyAV va a QAudioSink.
    Più lento di 1× l'audio passa dal filtro atempo, che non cambia il tono della voce.
    Senza scheda audio (o senza audio nel video) l'orologio va avanti lo stesso, in silenzio.
    """
    finished = pyqtSignal()

    def __init__(self, duration: float, parent=None):
        super().__init__(parent)
        self.duration = max(0.1, duration)
        self.pcm: Optional[bytes] = None    # Mono s16 a LISTEN_RATE
        self._out_cache = {}                # tempo -> PCM nel formato della scheda audio
        self._fmt = None
        self._sink = None
        self._buffer = None
        self._clock = QElapsedTimer()
        self._start_t = 0.0
        self._pos = 0.0
        self.tempo = 1.0
        self.playing = False
        self._setup_output()

    def _setup_output(self):
        if QAudioSink is None:
            return
        device = QMediaDevices.defaultAudioOutput()
        if device.isNull():
            return
        preferred = device.preferredFormat()
        for rate, channels in ((LISTEN_RATE, 1), (preferred.sampleRate(), 1), (preferred.sampleRate(), 2)):
            fmt = QAudioFormat()
            fmt.setSampleRate(rate)
            fmt.setChannelCount(channels)
            fmt.setSampleFormat(QAudioFormat.SampleFormat.Int16)
            if device.isFormatSupported(fmt):
                self._fmt = fmt
                self._device = device
                return

    @property
    def has_sound(self) -> bool:
        return self._fmt is not None and self.pcm is not None

    def set_pcm(self, pcm: Optional[bytes]):
        self.pcm = pcm
        self._out_cache = {}

    def _output_pcm(self) -> bytes:
        """L'audio alla velocità scelta, nel formato della scheda audio (preparato una volta per velocità)."""
        key = round(self.tempo, 3)
        if key not in self._out_cache:
            QApplication.setOverrideCursor(Qt.CursorShape.WaitCursor)  # Un audio di 5 minuti: circa un secondo
            try:
                self._out_cache = {key: self._convert(stretch_audio(self.pcm, LISTEN_RATE, self.tempo))}
            finally:
                QApplication.restoreOverrideCursor()
        return self._out_cache[key]

    def _convert(self, pcm: bytes) -> bytes:
        """
        PCM mono a LISTEN_RATE -> formato della scheda audio (se la scheda non accetta quello).
        Si tiene una velocità alla volta: l'audio di 5 minuti pesa.
        """
        rate, channels = self._fmt.sampleRate(), self._fmt.channelCount()
        if rate == LISTEN_RATE and channels == 1:
            return pcm
        import av
        frame = av.AudioFrame(format="s16", layout="mono", samples=len(pcm) // 2)
        frame.planes[0].update(pcm)
        frame.sample_rate = LISTEN_RATE
        rs = av.AudioResampler(format="s16", layout="stereo" if channels == 2 else "mono", rate=rate)
        out = bytearray()
        for f in rs.resample(frame) + rs.resample(None):
            out += bytes(f.planes[0])[:f.samples * 2 * channels]
        return bytes(out)

    def position(self) -> float:
        if self.playing:
            return min(self.duration, self._start_t + self._clock.elapsed() / 1000.0 * self.tempo)
        return self._pos

    def play(self, from_t: Optional[float] = None):
        if from_t is not None:
            self._pos = max(0.0, min(self.duration, from_t))
        if self._pos >= self.duration - 0.02:
            self._pos = 0.0
        self._stop_sink()
        self._start_t = self._pos
        if self.has_sound:
            try:
                data = self._output_pcm()
                bps = self._fmt.sampleRate() * self._fmt.channelCount() * 2
                offset = int(self._pos / self.tempo * self._fmt.sampleRate()) * self._fmt.channelCount() * 2
                self._buffer = QBuffer(self)
                self._buffer.setData(QByteArray(data[min(len(data), offset):]))
                self._buffer.open(QIODevice.OpenModeFlag.ReadOnly)
                self._sink = QAudioSink(self._device, self._fmt, self)
                self._sink.setBufferSize(max(4096, bps // 20))  # ~50 ms: il suono segue da vicino l'orologio
                self._sink.start(self._buffer)
            except Exception:
                self._stop_sink()
        self._clock.start()
        self.playing = True

    def pause(self):
        if not self.playing:
            return
        self._pos = self.position()
        self.playing = False
        self._stop_sink()

    def seek(self, t: float):
        was = self.playing
        self.pause()
        self._pos = max(0.0, min(self.duration, t))
        if was:
            self.play()

    def set_tempo(self, tempo: float):
        was = self.playing
        self.pause()
        self.tempo = tempo
        if was:
            self.play()

    def _stop_sink(self):
        if self._sink is not None:
            try:
                self._sink.stop()
            except Exception:
                pass
            self._sink.deleteLater()
            self._sink = None
        if self._buffer is not None:
            self._buffer.close()
            self._buffer.deleteLater()
            self._buffer = None

    def close(self):
        self.pause()
        self._stop_sink()


# ================= ANTEPRIMA DELLA PAGINA =================
class PagePreview(QWidget):
    """La pagina rimpicciolita: il fotogramma nel riquadro del video e la frase con lo stile vero."""
    clicked = pyqtSignal()

    def __init__(self, dialog: "CaptionsDialog"):
        super().__init__(dialog)
        self.dlg = dialog
        self.frame: Optional[QImage] = None
        self.phrase: Optional[dict] = None
        self.setMinimumSize(260, 360)
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
        self.setFocusPolicy(Qt.FocusPolicy.StrongFocus)

    def mousePressEvent(self, event):
        self.setFocus()
        self.clicked.emit()

    def paintEvent(self, event):
        d = self.dlg
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        p.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, True)
        p.fillRect(self.rect(), QColor(THEME["backdrop"]))
        fw, fh = d.page_rect.width(), d.page_rect.height()
        k = min((self.width() - 16) / fw, (self.height() - 16) / fh)
        ox = (self.width() - fw * k) / 2.0
        oy = (self.height() - fh * k) / 2.0
        p.translate(ox, oy)
        p.scale(k, k)
        p.fillRect(QRectF(0, 0, fw, fh), d.bg_color)
        p.setClipRect(QRectF(0, 0, fw, fh))
        cell = d.video_rect
        if self.frame is not None and not cell.isEmpty():
            # Il fotogramma riempie il riquadro del video (ritaglio al centro, come «Riempi»)
            iw, ih = self.frame.width(), self.frame.height()
            s = max(cell.width() / iw, cell.height() / ih)
            sw, sh = cell.width() / s, cell.height() / s
            src = QRectF((iw - sw) / 2.0, (ih - sh) / 2.0, sw, sh)
            p.drawImage(cell, self.frame, src)
        if self.phrase is not None:
            c = d.caption
            p.save()
            p.translate(d.caption_origin)
            rect = c.text_rect()
            inner = rect.adjusted(c._pad, c._pad, -c._pad, -c._pad)
            c.paint_phrase(p, self.phrase, inner)
            p.restore()
        p.end()


# ================= STRISCIA DEL TEMPO =================
class TimelineStrip(QWidget):
    """
    Forma d'onda dell'audio con le frasi come blocchi: clic = salta lì, trascinando i bordi si cambiano
    inizio e fine (agganciati alle pause e ai bordi vicini), trascinando un blocco lo si sposta.
    Rotella: scorre; Ctrl + rotella: zoom.
    """
    seek_requested = pyqtSignal(float)
    phrase_clicked = pyqtSignal(int)
    edit_started = pyqtSignal()
    edited = pyqtSignal()
    EDGE = 6

    def __init__(self, dialog: "CaptionsDialog"):
        super().__init__(dialog)
        self.dlg = dialog
        self.env: List[float] = []
        self.points: List[float] = []
        self.t0 = 0.0
        self.span = min(20.0, dialog.duration)
        self.playhead = 0.0
        self.selected = -1
        self._drag = None
        self._moved = False
        self.setMinimumHeight(130)
        self.setMouseTracking(True)
        self.setFocusPolicy(Qt.FocusPolicy.StrongFocus)

    # ---------- Coordinate ----------
    def x_of(self, t: float) -> float:
        return (t - self.t0) / self.span * self.width()

    def t_of(self, x: float) -> float:
        return self.t0 + x / max(1, self.width()) * self.span

    def _clamp_view(self):
        self.span = max(2.0, min(self.dlg.duration, self.span))
        self.t0 = max(0.0, min(self.dlg.duration - self.span, self.t0))

    def follow(self, t: float):
        """Durante la riproduzione la striscia scorre per tenere visibile il cursore."""
        if t < self.t0 or t > self.t0 + self.span * 0.9:
            self.t0 = t - self.span * 0.1
            self._clamp_view()
        self.playhead = t
        self.update()

    # ---------- Disegno ----------
    def paintEvent(self, event):
        d = self.dlg
        p = QPainter(self)
        w, h = self.width(), self.height()
        p.fillRect(self.rect(), QColor(THEME["field"]))
        # Fuori dal taglio del video: più scuro
        shade = QColor(0, 0, 0, 90)
        x1 = self.x_of(d.trim_start)
        x2 = self.x_of(d.trim_end)
        if x1 > 0:
            p.fillRect(QRectF(0, 0, x1, h), shade)
        if x2 < w:
            p.fillRect(QRectF(x2, 0, w - x2, h), shade)
        # Righello
        p.setFont(ui_font(9))
        p.setPen(QColor(THEME["faint"]))
        step = next((s for s in (0.5, 1, 2, 5, 10, 15, 30, 60) if self.span / s <= 14), 60)
        t = (int(self.t0 / step) + 1) * step
        while t < self.t0 + self.span:
            x = self.x_of(t)
            p.drawLine(QPointF(x, 0), QPointF(x, 5))
            p.drawText(QPointF(x + 3, 12), format_clock(t)[:-3])
            t += step
        # Forma d'onda
        mid = 18 + (h - 18) / 2.0
        amp = (h - 22) / 2.0
        if self.env:
            p.setPen(QPen(QColor(THEME["waveform"]), 1.0))
            n = len(self.env)
            for x in range(w):
                i0 = int(self.t_of(x) / 0.01)
                i1 = max(i0 + 1, int(self.t_of(x + 1) / 0.01))
                if i0 >= n or i1 <= 0:
                    continue
                v = max(self.env[max(0, i0):min(n, i1)], default=0.0)
                y = max(0.5, min(1.0, v * 1.6) * amp)
                p.drawLine(QPointF(x + 0.5, mid - y), QPointF(x + 0.5, mid + y))
        else:
            p.setPen(QColor(THEME["muted"]))
            p.drawText(QRectF(0, 18, w, h - 18), Qt.AlignmentFlag.AlignCenter, d.audio_status)
        # Frasi
        accent = QColor(THEME["accent"])
        p.setFont(ui_font(10, QFont.Weight.DemiBold))
        fm = QFontMetricsF(p.font())
        for i, ph in enumerate(d.phrases):
            if not is_synced(ph):
                continue
            a, b = self.x_of(ph["start"]), self.x_of(ph["end"])
            if b < 0 or a > w:
                continue
            r = QRectF(a, 20, max(2.0, b - a), h - 24)
            fill = QColor(accent)
            auto = bool(ph.get("auto"))
            # Tempi automatici: più tenui e con il bordo tratteggiato; quelli ritoccati a mano pieni
            fill.setAlpha((90 if auto else 120) if i == self.selected else (35 if auto else 60))
            pen = QPen(accent.lighter(130) if i == self.selected else accent, 1.5 if i == self.selected else 1.0)
            if auto:
                pen.setStyle(Qt.PenStyle.DashLine)
            p.setPen(pen)
            p.setBrush(fill)
            p.drawRoundedRect(r, 4, 4)
            p.setPen(QColor(THEME["text"]))
            txt = fm.elidedText(ph.get("text", ""), Qt.TextElideMode.ElideRight, max(0.0, r.width() - 8))
            p.drawText(r.adjusted(4, 2, -4, 0), Qt.AlignmentFlag.AlignTop | Qt.AlignmentFlag.AlignLeft, txt)
        # Cursore
        x = self.x_of(self.playhead)
        p.setPen(QPen(QColor(THEME["danger"]), 2.0))
        p.drawLine(QPointF(x, 0), QPointF(x, h))
        p.end()

    # ---------- Interazione ----------
    def _hit(self, x: float):
        """(indice, «start»/«end»/«body») del blocco sotto x, con i bordi che hanno la precedenza."""
        best = None
        for i, ph in enumerate(self.dlg.phrases):
            if not is_synced(ph):
                continue
            a, b = self.x_of(ph["start"]), self.x_of(ph["end"])
            for edge, ex in (("start", a), ("end", b)):
                dist = abs(x - ex)
                if dist <= self.EDGE and (best is None or dist < best[2]):
                    best = (i, edge, dist)
        if best is not None:
            return best[0], best[1]
        for i, ph in enumerate(self.dlg.phrases):
            if is_synced(ph) and self.x_of(ph["start"]) <= x <= self.x_of(ph["end"]):
                return i, "body"
        return None

    def mousePressEvent(self, event):
        self.setFocus()
        if event.button() != Qt.MouseButton.LeftButton:
            return
        x = event.position().x()
        hit = self._hit(x) if event.position().y() > 18 else None
        if hit is None:
            self.seek_requested.emit(max(0.0, min(self.dlg.duration, self.t_of(x))))
            return
        i, part = hit
        phs = self.dlg.phrases
        ph = phs[i]
        # Bordo condiviso con la frase vicina ritoccata a mano: si spostano insieme
        # (le vicine con i tempi automatici si ridistribuiscono da sole)
        partner = None
        if part == "start" and i > 0 and is_manual(phs[i - 1]) and abs(phs[i - 1]["end"] - ph["start"]) < 0.01:
            partner = i - 1
        elif part == "end" and i + 1 < len(phs) and is_manual(phs[i + 1]) \
                and abs(phs[i + 1]["start"] - ph["end"]) < 0.01:
            partner = i + 1
        # Limiti: un blocco non scavalca le frasi fissate a mano prima e dopo di lui nell'elenco, e lascia
        # posto a quelle automatiche in mezzo
        lo, hi, room = None, None, 0
        for j in range(i - 1, -1, -1):
            if j != partner and is_manual(phs[j]):
                lo = phs[j]["end"]
                break
            room += j != partner
        lo = (self.dlg.trim_start if room else 0.0) if lo is None else lo
        lo += MIN_PHRASE * room
        room = 0
        for j in range(i + 1, len(phs)):
            if j != partner and is_manual(phs[j]):
                hi = phs[j]["start"]
                break
            room += j != partner
        hi = (self.dlg.trim_end if room else self.dlg.duration) if hi is None else hi
        hi -= MIN_PHRASE * room
        if partner is not None:
            q = phs[partner]
            if part == "start":
                lo = max(lo, q["start"] + MIN_PHRASE)
            else:
                hi = min(hi, q["end"] - MIN_PHRASE)
        self._limits = (min(lo, ph["start"]), max(hi, ph["end"]))
        self._drag = (i, part, x, ph["start"], ph["end"], partner)
        self._moved = False
        self.phrase_clicked.emit(i)
        if part == "body":
            self.seek_requested.emit(ph["start"])

    def mouseMoveEvent(self, event):
        x = event.position().x()
        if self._drag is None:
            hit = self._hit(x) if event.position().y() > 18 else None
            if hit and hit[1] in ("start", "end"):
                self.setCursor(Qt.CursorShape.SizeHorCursor)
            elif hit:
                self.setCursor(Qt.CursorShape.OpenHandCursor)
            else:
                self.unsetCursor()
            return
        i, part, x0, s0, e0, partner = self._drag
        if not self._moved:
            if abs(x - x0) < 2:
                return
            self._moved = True
            self.edit_started.emit()  # Un passo dell'Annulla della finestra, prima di cambiare i tempi
        dt = (x - x0) / max(1, self.width()) * self.span
        tol = self.EDGE * 1.5 / max(1, self.width()) * self.span
        ph = self.dlg.phrases[i]
        others = [v for j, q in enumerate(self.dlg.phrases) if j not in (i, partner) and is_manual(q)
                  for v in (q["start"], q["end"])]
        pts = self.points + others + [self.playhead]
        lo, hi = self._limits
        ph.pop("auto", None)  # Ritoccata a mano: i tempi automatici non la spostano più
        if part == "start":
            t = snap(max(lo, min(e0 - MIN_PHRASE, s0 + dt)), pts, tol)
            t = max(lo, min(e0 - MIN_PHRASE, t))
            ph["start"] = round(t, 3)
            if partner is not None:
                q = self.dlg.phrases[partner]
                q["end"] = round(max(q["start"] + MIN_PHRASE, t), 3)
        elif part == "end":
            t = snap(max(s0 + MIN_PHRASE, min(hi, e0 + dt)), pts, tol)
            t = max(s0 + MIN_PHRASE, min(hi, t))
            ph["end"] = round(t, 3)
            if partner is not None:
                q = self.dlg.phrases[partner]
                q["start"] = round(min(q["end"] - MIN_PHRASE, t), 3)
        else:
            length = e0 - s0
            t = snap(max(lo, min(hi - length, s0 + dt)), pts, tol)
            t = max(lo, min(hi - length, t))
            ph["start"], ph["end"] = round(t, 3), round(t + length, 3)
        self.dlg.on_timeline_dragged()
        self.update()

    def mouseReleaseEvent(self, event):
        if self._drag is not None:
            self._drag = None
            if self._moved:
                self.edited.emit()

    def wheelEvent(self, event):
        delta = event.angleDelta().y() or event.angleDelta().x()
        if event.modifiers() & Qt.KeyboardModifier.ControlModifier:
            anchor = self.t_of(event.position().x())
            k = 0.8 if delta > 0 else 1.25
            self.span *= k
            self._clamp_view()
            self.t0 = anchor - event.position().x() / max(1, self.width()) * self.span
        else:
            self.t0 -= delta / 120.0 * self.span * 0.15
        self._clamp_view()
        self.update()


class PhraseEdit(QPlainTextEdit):
    """Casella del testo, una frase per riga: il testo incollato si divide da solo in frasi corte."""

    def __init__(self, fits):
        super().__init__()
        self._fits = fits

    def insertFromMimeData(self, source):
        text = source.text() if source.hasText() else ""
        if text and (chr(10) in text or len(text) > 60):
            self.insertPlainText(chr(10).join(split_text(text, self._fits())))
            return
        super().insertFromMimeData(source)


# ================= FINESTRA =================
class CaptionsDialog(QDialog):
    SPEEDS = ((1.0, "1×"), (0.75, "0,75×"), (0.5, "0,5×"))
    JUMP = 3.0   # Alt+←/→: secondi indietro o avanti, anche mentre si scrive

    def __init__(self, window, caption, video):
        super().__init__(window)
        self.window_ = window
        self.caption = caption
        self.video = video
        info = video_info(video.image_path)
        self.duration = max(0.5, float(info.get("duration", 0.0)) or video.clip_end())
        self.fps = float(info.get("fps") or 30.0)
        self.trim_start = video.trim_start
        self.trim_end = video.clip_end()
        self.phrases: List[dict] = copy.deepcopy(caption.phrases)
        self.tr_lang = caption.tr_lang
        self._saved = copy.deepcopy(self.phrases)
        self._undo: List[List[dict]] = []
        self._redo: List[List[dict]] = []
        self.pauses = []
        self.audio_status = "Lettura dell'audio…"
        self._shown_row = -1
        self._updating = False

        # Pagina del video, per l'anteprima
        scene = caption.scene()
        fw, fh = scene.frame_w, scene.frame_h
        center = video.mapToScene(QPointF(video.cell_w / 2.0, video.cell_h / 2.0))
        k = max(0, min(scene.num_frames - 1, int(center.x() // fw)))
        self.page_rect = QRectF(k * fw, 0, fw, fh)
        self.bg_color = QColor(scene.bg_color)
        self.video_rect = video.mapRectToScene(QRectF(0, 0, video.cell_w, video.cell_h)).translated(-k * fw, 0)
        self.caption_origin = caption.pos() - self.page_rect.topLeft()

        self.player = ClipPlayer(self.duration, self)
        self.reader: Optional[FrameReader] = None
        try:
            self.reader = FrameReader(video.image_path, PREVIEW_SIDE)
        except Exception:
            self.reader = None

        self.setWindowTitle(f"Sottotitoli – {os.path.basename(video.image_path)}")
        self.resize(1280, 840)
        self._timer = QTimer(self)
        self._timer.setInterval(16)
        self._timer.timeout.connect(self._tick)
        self._text_timer = QTimer(self)
        self._text_timer.setSingleShot(True)
        self._text_timer.setInterval(600)
        self._text_timer.timeout.connect(self._apply_text_box)
        self._text_loaded = False  # La casella di testo è stata riempita con le frasi (e si può rileggere)
        self._build_ui()
        self._settings_load()
        self._load_audio_async()
        self._refresh_all()
        self._seek(self.trim_start)
        QTimer.singleShot(0, self.text_box.setFocus)
        QApplication.instance().installEventFilter(self)

    # ---------- Interfaccia ----------
    def _label(self, text: str, obj: str = "FieldLabel") -> QLabel:
        lbl = QLabel(text)
        lbl.setObjectName(obj)
        return lbl

    def _soft(self, text: str, tip: str, slot) -> QToolButton:
        b = QToolButton()
        b.setObjectName("SoftButton")
        b.setText(text)
        b.setToolTip(tip)
        b.setCursor(Qt.CursorShape.PointingHandCursor)
        b.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        b.clicked.connect(slot)
        return b

    def _build_ui(self):
        root = QVBoxLayout(self)
        root.setContentsMargins(14, 14, 14, 12)
        root.setSpacing(10)

        top = QHBoxLayout()
        top.setSpacing(14)
        self.preview = PagePreview(self)
        self.preview.clicked.connect(self._toggle_play)
        top.addWidget(self.preview, 4)

        side = QVBoxLayout()
        side.setSpacing(8)
        tabs = QHBoxLayout()
        tabs.setSpacing(0)
        self.side_stack = QStackedWidget()
        group = QButtonGroup(self)
        for i, (name, tip) in enumerate((("Testo", "Tutto il testo, una frase per riga"),
                                         ("Elenco", "Frasi con inizio, fine e traduzione"))):
            b = QToolButton()
            b.setObjectName("SegTab")
            b.setText(name)
            b.setToolTip(tip)
            b.setCheckable(True)
            b.setFocusPolicy(Qt.FocusPolicy.NoFocus)
            b.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)
            b.setFixedHeight(26)
            b.clicked.connect(lambda _c=False, k=i: self._show_side(k))
            group.addButton(b)
            tabs.addWidget(b)
        self._side_group = group
        side.addLayout(tabs)
        side.addWidget(self.side_stack, 1)

        # Scheda Testo
        tp = QWidget()
        tl = QVBoxLayout(tp)
        tl.setContentsMargins(0, 0, 0, 0)
        tl.setSpacing(6)
        hint = self._label("Scrivi o incolla tutto il testo, una frase per riga (al massimo due righe a schermo): "
                           "quello incollato si divide da solo in frasi corte.\n"
                           "Ctrl+Spazio fa partire o ferma il video anche mentre scrivi, Alt+←/→ torna indietro "
                           "o va avanti di 3 secondi. I tempi si mettono da soli dall'audio.", "Hint")
        hint.setWordWrap(True)
        tl.addWidget(hint)
        self.text_box = PhraseEdit(self._fits)
        self.text_box.setPlaceholderText("Scrivi o incolla qui il testo del video…")
        self.text_box.setFont(ui_font(13))
        self.text_box.textChanged.connect(self._on_text_box_changed)
        tl.addWidget(self.text_box, 1)
        row = QHBoxLayout()
        row.addWidget(self._soft("Dividi in frasi corte", "Divide il testo alla punteggiatura e spezza le frasi "
                                 "che non stanno in due righe", self._split_text_box))
        row.addStretch()
        tl.addLayout(row)
        self.side_stack.addWidget(tp)

        # Scheda Elenco
        lp = QWidget()
        ll = QVBoxLayout(lp)
        ll.setContentsMargins(0, 0, 0, 0)
        ll.setSpacing(6)
        bar = QHBoxLayout()
        bar.setSpacing(4)
        for text, tip, slot in (
                ("Aggiungi", "Nuova frase al punto del video", self._add_phrase),
                ("Dividi", "Divide la frase scelta in due", self._split_selected),
                ("Unisci", "Unisce la frase scelta con la successiva", self._join_selected),
                ("Elimina", "Elimina la frase scelta", self._delete_selected),
                ("Segna inizio", "Inizio della frase scelta al punto del video (Invio)", lambda: self._mark("start")),
                ("Segna fine", "Fine della frase scelta al punto del video (Shift+Invio)", lambda: self._mark("end"))):
            bar.addWidget(self._soft(text, tip, slot))
        bar.addStretch()
        ll.addLayout(bar)
        lang = QHBoxLayout()
        lang.addWidget(self._label("Lingua della traduzione"))
        self.edit_tr_lang = QLineEdit(self.tr_lang)
        self.edit_tr_lang.setMaxLength(8)
        self.edit_tr_lang.setFixedWidth(60)
        self.edit_tr_lang.setToolTip("Sigla della lingua (en, es, fr…): serve al nome del file .srt della traduzione")
        self.edit_tr_lang.textEdited.connect(self._on_tr_lang)
        lang.addWidget(self.edit_tr_lang)
        lang.addStretch()
        ll.addLayout(lang)
        self.table = QTableWidget(0, 4)
        self.table.setHorizontalHeaderLabels(["Inizio", "Fine", "Frase", "Traduzione"])
        self.table.verticalHeader().setVisible(False)
        hh = self.table.horizontalHeader()
        hh.setSectionResizeMode(0, QHeaderView.ResizeMode.ResizeToContents)
        hh.setSectionResizeMode(1, QHeaderView.ResizeMode.ResizeToContents)
        hh.setSectionResizeMode(2, QHeaderView.ResizeMode.Stretch)
        hh.setSectionResizeMode(3, QHeaderView.ResizeMode.Stretch)
        self.table.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        self.table.setSelectionMode(QAbstractItemView.SelectionMode.SingleSelection)
        self.table.setEditTriggers(QAbstractItemView.EditTrigger.DoubleClicked
                                   | QAbstractItemView.EditTrigger.EditKeyPressed
                                   | QAbstractItemView.EditTrigger.AnyKeyPressed)
        self.table.setWordWrap(True)
        self.table.itemChanged.connect(self._on_table_item)
        self.table.currentCellChanged.connect(self._on_table_row)
        self.table.cellClicked.connect(lambda r, _c: self._jump_to_row(r))
        ll.addWidget(self.table, 1)
        self.side_stack.addWidget(lp)
        top.addLayout(side, 5)
        root.addLayout(top, 1)

        # Comandi della riproduzione
        transport = QHBoxLayout()
        transport.setSpacing(6)
        self.btn_back = self._soft("◀", "Un fotogramma indietro (←)", lambda: self._step(-1))
        self.btn_play = self._soft("Riproduci", "Avvia o ferma il video (Ctrl+Spazio, anche mentre scrivi)",
                                   self._toggle_play)
        self.btn_play.setMinimumWidth(96)
        self.btn_fwd = self._soft("▶", "Un fotogramma avanti (→)", lambda: self._step(1))
        for b in (self.btn_back, self.btn_play, self.btn_fwd):
            transport.addWidget(b)
        self.lbl_time = self._label("0:00,00 / 0:00,00")
        self.lbl_time.setFont(ui_font(12, QFont.Weight.DemiBold))
        self.lbl_time.setMinimumWidth(150)
        transport.addWidget(self.lbl_time)
        self.combo_speed = QComboBox()
        for v, name in self.SPEEDS:
            self.combo_speed.addItem(name, v)
        self.combo_speed.setToolTip("Velocità del video: più lento è più facile scrivere (la voce non cambia tono)")
        self.combo_speed.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        self.combo_speed.currentIndexChanged.connect(lambda _i: self.player.set_tempo(self.combo_speed.currentData()))
        transport.addWidget(self.combo_speed)
        transport.addStretch()
        transport.addWidget(self._soft("Tempi dall'audio", "Ridistribuisce tutte le frasi sui tratti di parlato, "
                                       "anche quelle ritoccate a mano", self._auto_all))
        root.addLayout(transport)

        hint = self._label("I tempi si mettono da soli sui tratti di parlato (blocchi tratteggiati). Per correggerli "
                           "trascina i bordi di un blocco: resta dove l'hai messo e le altre frasi si sistemano "
                           "intorno.  Clic sulla striscia: salta lì.  Spazio: avvia/ferma.  ←/→: un fotogramma.",
                           "Hint")
        hint.setWordWrap(True)
        root.addWidget(hint)

        self.timeline = TimelineStrip(self)
        self.timeline.seek_requested.connect(self._seek)
        self.timeline.phrase_clicked.connect(self._select_phrase)
        self.timeline.edit_started.connect(self._push_undo)
        self.timeline.edited.connect(self._after_timeline_edit)
        root.addWidget(self.timeline)

        bottom = QHBoxLayout()
        self.btn_undo = self._soft("Annulla", "Annulla l'ultima modifica nella finestra (Ctrl+Z)", self._undo_step)
        self.btn_redo = self._soft("Ripeti", "Ripeti (Ctrl+Y)", self._redo_step)
        bottom.addWidget(self.btn_undo)
        bottom.addWidget(self.btn_redo)
        self.lbl_status = self._label("", "Hint")
        bottom.addWidget(self.lbl_status, 1)
        cancel = QPushButton("Annulla")
        cancel.setObjectName("Ghost")
        cancel.setAutoDefault(False)
        cancel.clicked.connect(self.reject)
        done = QPushButton("Fatto")
        done.setObjectName("Primary")
        done.setAutoDefault(False)
        done.clicked.connect(self.accept)
        bottom.addWidget(cancel)
        bottom.addWidget(done)
        root.addLayout(bottom)

        self._show_side(0)

    def _show_side(self, k: int):
        if self.side_stack.currentIndex() == 0 and k != 0:
            self._apply_text_box()
        self.side_stack.setCurrentIndex(k)
        self._side_group.buttons()[k].setChecked(True)
        if k == 0:
            self._fill_text_box()
        else:
            self._fill_table()
        self._shown_row = -2
        self._highlight_row(phrase_index_at(self.phrases, self.player.position()))

    # ---------- Impostazioni ricordate ----------
    def _settings(self):
        return self.window_._settings()

    def _settings_load(self):
        try:
            speed = float(self._settings().value("captions/speed", 1.0))
        except Exception:
            speed = 1.0
        idx = next((i for i, (v, _) in enumerate(self.SPEEDS) if abs(v - speed) < 1e-3), 0)
        self.combo_speed.setCurrentIndex(idx)
        self.player.tempo = self.SPEEDS[idx][0]

    def _settings_save(self):
        try:
            self._settings().setValue("captions/speed", self.combo_speed.currentData())
        except Exception:
            pass

    # ---------- Audio (letto in un thread: un video di 5 minuti richiede qualche secondo) ----------
    def _load_audio_async(self):
        path = self.video.image_path
        result = {}

        def work():
            try:
                pcm = read_audio_mono(path)
                if pcm:
                    env = envelope(pcm, LISTEN_RATE)
                    result.update(pcm=pcm, env=env, pauses=find_pauses(env))
                else:
                    result["none"] = True
            except Exception as e:
                result["error"] = str(e)

        thread = threading.Thread(target=work, daemon=True)
        thread.start()

        def poll():
            if thread.is_alive():
                return
            self._audio_poll.stop()
            if "pcm" in result:
                self.player.set_pcm(result["pcm"])
                self.timeline.env = result["env"]
                self.pauses = result["pauses"]
                self.timeline.points = snap_points(self.pauses)
                self.audio_status = ""
                if self.player._fmt is None:
                    self.lbl_status.setText("Nessuna uscita audio trovata: il video gira muto.")
                # Le frasi scritte prima che l'audio fosse pronto prendono i tempi veri
                self._retime()
                self._refresh_time_cells()
                self._refresh_status_only()
                self._show_time(self.player.position())
            else:
                self.audio_status = "Il video non ha audio" if "none" in result else "Audio non leggibile"
            self.timeline.update()

        self._audio_poll = QTimer(self)
        self._audio_poll.setInterval(100)
        self._audio_poll.timeout.connect(poll)
        self._audio_poll.start()

    # ---------- Tempi automatici ----------
    def _retime(self, reset: bool = False):
        retime(self.phrases, self.pauses, self.trim_start, self.trim_end, reset)

    def _auto_all(self):
        """«Tempi dall'audio»: tutte le frasi tornano automatiche e si ridistribuiscono."""
        self._apply_text_box()
        if not self.phrases:
            self.lbl_status.setText("Prima scrivi o incolla il testo")
            return
        self._push_undo()
        self._retime(reset=True)
        self._after_change()

    # ---------- Riproduzione ----------
    def _toggle_play(self):
        if self.player.playing:
            self._pause()
        else:
            self._play()

    def _play(self):
        t = self.player.position()
        if t >= self.duration - 0.05:
            t = self.trim_start
        self.player.play(t)
        self._timer.start()
        self.btn_play.setText("Pausa")

    def _pause(self):
        self.player.pause()
        self._timer.stop()
        self.btn_play.setText("Riproduci")
        self._show_time(self.player.position())

    def _seek(self, t: float):
        t = max(0.0, min(self.duration, t))
        self.player.seek(t)
        self._show_time(t)

    def _step(self, frames: int):
        self._pause()
        self._seek(self.player.position() + frames / self.fps)

    def _jump(self, seconds: float):
        """Alt+←/→: salta indietro o avanti; se il video gira continua a girare."""
        self._seek(self.player.position() + seconds)

    def _tick(self):
        t = self.player.position()
        if t >= self.duration - 1e-3:
            self._pause()
            t = self.duration
        self._show_time(t)

    def _show_time(self, t: float):
        if self.reader is not None:
            try:
                img = self.reader.frame_at(t)
                if img is not None and img is not getattr(self, "_last_img", None):
                    self._last_img = img
                    self.preview.frame = pil_to_qimage(img)
            except Exception:
                pass
        self.lbl_time.setText(f"{format_clock(t)} / {format_clock(self.duration)}")
        if self.player.playing:
            self.timeline.follow(t)
        else:
            self.timeline.playhead = t
            self.timeline.update()
        idx = phrase_index_at(self.phrases, t)
        self.preview.phrase = self.phrases[idx] if idx >= 0 else None
        self.preview.update()
        if idx != self._shown_row:
            self._shown_row = idx
            self._highlight_row(idx)

    def on_timeline_dragged(self):
        """Mentre si trascina un bordo: le frasi automatiche si sistemano, anteprima e tempi seguono."""
        self._retime()
        self._show_time(self.player.position())
        self._refresh_time_cells()

    # ---------- Annulla interno ----------
    def _push_undo(self):
        self._undo.append(copy.deepcopy(self.phrases))
        del self._undo[:-200]
        self._redo.clear()

    def _undo_step(self):
        if not self._undo:
            return
        self._redo.append(copy.deepcopy(self.phrases))
        self.phrases = self._undo.pop()
        self._after_change()

    def _redo_step(self):
        if not self._redo:
            return
        self._undo.append(copy.deepcopy(self.phrases))
        self.phrases = self._redo.pop()
        self._after_change()

    def _after_change(self):
        self._refresh_all()
        self._shown_row = -2
        self._show_time(self.player.position())

    def _after_timeline_edit(self):
        self._refresh_all()

    def _refresh_all(self):
        if self.side_stack.currentIndex() == 0:
            self._fill_text_box()
        else:
            self._fill_table()
        self.timeline.update()
        self._refresh_status_only()

    def _refresh_status_only(self):
        total = len(self.phrases)
        missing = sum(1 for p in self.phrases if not is_synced(p))
        manual = sum(1 for p in self.phrases if is_manual(p))
        msg = "Nessuna frase" if not total else (f"{total} frasi" if total != 1 else "1 frase")
        if manual:
            msg += f", {manual} ritoccat{'e' if manual != 1 else 'a'} a mano"
        if missing:
            msg += f", {missing} senza posto nel tempo"
        self.lbl_status.setText(msg)
        self.btn_undo.setEnabled(bool(self._undo))
        self.btn_redo.setEnabled(bool(self._redo))

    # ---------- Scheda Testo ----------
    def _fill_text_box(self):
        text = "\n".join(p.get("text", "") for p in self.phrases)
        if self.text_box.toPlainText() != text:
            self._updating = True
            self._text_timer.stop()
            cursor = self.text_box.textCursor().position()
            self.text_box.setPlainText(text)
            c = self.text_box.textCursor()
            c.setPosition(min(cursor, len(text)))
            self.text_box.setTextCursor(c)
            self._updating = False
            self._shown_row = -2
        self._text_loaded = True

    def _on_text_box_changed(self):
        if not self._updating:
            self._text_timer.start()

    def _apply_text_box(self):
        self._text_timer.stop()
        if not self._text_loaded:
            return
        lines = [ln.strip() for ln in self.text_box.toPlainText().split("\n")]
        lines = [ln for ln in lines if ln]
        if lines == [p.get("text", "") for p in self.phrases]:
            return
        self._push_undo()
        self.phrases = merge_lines(self.phrases, lines)
        self._retime()
        self.timeline.update()
        self._refresh_status_only()
        self._shown_row = -2
        self._show_time(self.player.position())

    def _fits(self):
        c = self.caption
        fm = QFontMetricsF(c._font())
        return lambda s: fits_two_lines(s, fm.horizontalAdvance, c.wrap_w)

    def _split_text_box(self):
        parts = split_text(self.text_box.toPlainText(), self._fits())
        self._text_loaded = True
        self.text_box.setPlainText("\n".join(parts))
        self._apply_text_box()

    def _highlight_text_line(self, idx: int):
        """Durante la riproduzione la riga della frase a schermo si colora (le righe vuote non contano)."""
        sels = []
        block, k = self.text_box.document().firstBlock(), -1
        while idx >= 0 and block.isValid():
            if block.text().strip():
                k += 1
                if k == idx:
                    break
            block = block.next()
        if idx >= 0 and block.isValid() and k == idx:
            sel = QTextEdit.ExtraSelection()
            fmt = QTextCharFormat()
            color = QColor(THEME["accent"])
            color.setAlpha(70)
            fmt.setBackground(color)
            fmt.setProperty(QTextFormat.Property.FullWidthSelection, True)
            sel.format = fmt
            cur = QTextCursor(block)
            cur.movePosition(QTextCursor.MoveOperation.EndOfBlock, QTextCursor.MoveMode.KeepAnchor)
            sel.cursor = cur
            sels.append(sel)
            if self.player.playing and not self.text_box.hasFocus():
                c = QTextCursor(block)
                self.text_box.setTextCursor(c)
                self.text_box.ensureCursorVisible()
        self.text_box.setExtraSelections(sels)

    # ---------- Scheda Elenco ----------
    def _fill_table(self):
        if self.table.state() == QAbstractItemView.State.EditingState:
            return
        self._updating = True
        self.table.setHorizontalHeaderLabels(["Inizio", "Fine", "Frase", f"Traduzione ({self.tr_lang or '–'})"])
        self.table.setRowCount(len(self.phrases))
        for r, p in enumerate(self.phrases):
            for c, value in enumerate((format_clock(p.get("start")), format_clock(p.get("end")),
                                       p.get("text", ""), p.get("tr", ""))):
                item = self.table.item(r, c)
                if item is None:
                    item = QTableWidgetItem()
                    self.table.setItem(r, c, item)
                if item.text() != value:
                    item.setText(value)
                if c < 2:
                    item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
                    item.setToolTip("Tempo automatico" if p.get("auto") else "")
        self.table.resizeRowsToContents()
        self._updating = False
        self._shown_row = -2
        self._highlight_row(phrase_index_at(self.phrases, self.player.position()))

    def _refresh_time_cells(self):
        if self.side_stack.currentIndex() != 1 or self.table.rowCount() != len(self.phrases):
            return
        self._updating = True
        for r, p in enumerate(self.phrases):
            for c, key in ((0, "start"), (1, "end")):
                item = self.table.item(r, c)
                if item is not None:
                    item.setText(format_clock(p.get(key)))
        self._updating = False

    def _highlight_row(self, idx: int):
        if self.side_stack.currentIndex() == 0:
            self._highlight_text_line(idx)
            return
        normal = QColor(0, 0, 0, 0)
        hot = QColor(THEME["accent"])
        hot.setAlpha(70)
        was, self._updating = self._updating, True  # Il colore non è una modifica delle celle
        for r in range(self.table.rowCount()):
            for c in range(4):
                item = self.table.item(r, c)
                if item is not None:
                    item.setBackground(hot if r == idx else normal)
        self._updating = was
        if 0 <= idx < self.table.rowCount() and self.table.state() != QAbstractItemView.State.EditingState:
            self.table.scrollToItem(self.table.item(idx, 2), QAbstractItemView.ScrollHint.EnsureVisible)

    def _on_table_item(self, item: QTableWidgetItem):
        if self._updating:
            return
        r, c = item.row(), item.column()
        if not (0 <= r < len(self.phrases)):
            return
        p = self.phrases[r]
        text = item.text().strip()
        if c in (0, 1):
            t = parse_clock(text)
            key = "start" if c == 0 else "end"
            if t is None and text not in ("", "–"):
                self._updating = True
                item.setText(format_clock(p.get(key)))
                self._updating = False
                return
            old = p.get(key)
            if text == format_clock(old):
                return  # Cella riscritta uguale: i tempi restano quelli di prima (con i millesimi)
            self._push_undo()
            p.pop("auto", None)  # Tempo scritto a mano: resta fermo (cancellato torna automatico)
            p[key] = None if t is None else round(min(self.duration, t), 3)
            if is_synced(p) and p["end"] < p["start"] + MIN_PHRASE:
                if c == 0:
                    p["end"] = round(p["start"] + max(MIN_PHRASE, 1.0), 3)
                else:
                    p["start"] = round(max(0.0, p["end"] - MIN_PHRASE), 3)
            if p.get("start") is not None and p.get("end") is None:
                nxt = next((q["start"] for q in self.phrases[r + 1:] if is_manual(q) and q["start"] > p["start"]),
                           None)
                p["end"] = round(nxt if nxt is not None else min(self.duration, p["start"] + 2.0), 3)
            elif p.get("start") is None:
                p["end"] = None
            self._retime()
            self._refresh_time_cells()
        else:
            key = "text" if c == 2 else "tr"
            if p.get(key, "") == text:
                return
            self._push_undo()
            p[key] = text
            if key == "text":
                self._retime()
                self._refresh_time_cells()
        self.timeline.update()
        self._refresh_status_only()
        self._show_time(self.player.position())

    def _on_table_row(self, row: int, _col: int, _prow: int, _pcol: int):
        if 0 <= row < len(self.phrases):
            self.timeline.selected = row
            self.timeline.update()

    def _jump_to_row(self, r: int):
        if 0 <= r < len(self.phrases):
            p = self.phrases[r]
            self.timeline.selected = r
            if p.get("start") is not None and not self.player.playing:
                self._seek(p["start"])
            self.timeline.update()

    def _select_phrase(self, i: int):
        self.timeline.selected = i
        if self.side_stack.currentIndex() == 1 and 0 <= i < self.table.rowCount():
            self.table.setCurrentCell(i, 2)

    def _selected_index(self) -> int:
        if self.side_stack.currentIndex() == 1:
            r = self.table.currentRow()
            if 0 <= r < len(self.phrases):
                return r
        return self.timeline.selected if 0 <= self.timeline.selected < len(self.phrases) else -1

    def _add_phrase(self):
        t = round(self.player.position(), 3)
        self._push_undo()
        idx = insert_index(self.phrases, t)
        nxt = next((q["start"] for q in self.phrases[idx:] if is_manual(q) and q["start"] > t), None)
        end = min(self.duration, t + 2.0) if nxt is None else max(t + MIN_PHRASE, min(nxt, t + 2.0))
        self.phrases.insert(idx, make_phrase("", t, round(end, 3)))
        self._retime()
        self._show_side(1)
        self._refresh_all()
        self.table.setCurrentCell(idx, 2)
        self.table.editItem(self.table.item(idx, 2))

    def _split_selected(self):
        i = self._selected_index()
        if i < 0:
            return
        self._push_undo()
        p = self.phrases[i]
        a, b = split_phrase(p)
        if not is_manual(p):
            a["auto"] = b["auto"] = True
        self.phrases[i:i + 1] = [a, b]
        self._retime()
        self._refresh_all()

    def _join_selected(self):
        i = self._selected_index()
        if i < 0 or i + 1 >= len(self.phrases):
            return
        self._push_undo()
        a, b = self.phrases[i], self.phrases[i + 1]
        p = join_phrases(a, b)
        if not (is_manual(a) or is_manual(b)):
            p["auto"] = True
        self.phrases[i:i + 2] = [p]
        self._retime()
        self._refresh_all()

    def _delete_selected(self):
        i = self._selected_index()
        if i < 0:
            return
        self._push_undo()
        del self.phrases[i]
        self.timeline.selected = -1
        self._retime()
        self._refresh_all()
        self._show_time(self.player.position())

    def _mark(self, which: str):
        """Invio: inizio della frase scelta al punto del video; Shift+Invio: la fine."""
        i = self._selected_index()
        if i < 0:
            return
        t = round(self.player.position(), 3)
        self._push_undo()
        p = self.phrases[i]
        p.pop("auto", None)
        if which == "start":
            old = p.get("start")
            p["start"] = t
            if p.get("end") is None or p["end"] < t + MIN_PHRASE:
                p["end"] = round(min(self.duration, t + 2.0), 3)
            # La frase fissata prima che finiva dove cominciava questa la segue
            for q in self.phrases:
                if q is not p and is_manual(q) and old is not None and abs(q["end"] - old) < 0.01:
                    q["end"] = max(q["start"] + MIN_PHRASE, t)
        else:
            p["end"] = max(t, (p.get("start") or 0.0) + MIN_PHRASE)
            if p.get("start") is None:
                p["start"] = round(max(0.0, t - 2.0), 3)
        self._retime()
        self._refresh_all()
        self._show_time(self.player.position())

    def _on_tr_lang(self, text: str):
        self.tr_lang = text.strip()
        self.table.setHorizontalHeaderItem(3, QTableWidgetItem(f"Traduzione ({self.tr_lang or '–'})"))

    # ---------- Tastiera ----------
    def eventFilter(self, obj, event):
        if event.type() == QEvent.Type.KeyPress and self.isActiveWindow() and isinstance(obj, QWidget) \
                and obj.window() is self:
            if self._handle_key(event):
                return True
        return super().eventFilter(obj, event)

    def _typing(self) -> bool:
        fw = QApplication.focusWidget()
        return isinstance(fw, (QLineEdit, QPlainTextEdit, QTextEdit, QAbstractSpinBox)) \
            or self.table.state() == QAbstractItemView.State.EditingState

    def _handle_key(self, event) -> bool:
        key, mods = event.key(), event.modifiers()
        ctrl = bool(mods & Qt.KeyboardModifier.ControlModifier)
        alt = bool(mods & Qt.KeyboardModifier.AltModifier)
        # Questi valgono anche mentre si scrive
        if key == Qt.Key.Key_Space and ctrl:
            self._toggle_play()
            return True
        if alt and key in (Qt.Key.Key_Left, Qt.Key.Key_Right):
            self._jump(-self.JUMP if key == Qt.Key.Key_Left else self.JUMP)
            return True
        if key == Qt.Key.Key_Escape:
            if self.table.state() == QAbstractItemView.State.EditingState:
                return False  # Esc chiude la cella in modifica
            self._pause()
            return True  # Esc non chiude la finestra
        if self._typing():
            return False
        if ctrl and event.matches(QKeySequence.StandardKey.Undo):
            self._undo_step()
            return True
        if ctrl and (event.matches(QKeySequence.StandardKey.Redo) or key == Qt.Key.Key_Y):
            self._redo_step()
            return True
        if key == Qt.Key.Key_Space:
            self._toggle_play()
            return True
        if key in (Qt.Key.Key_Left, Qt.Key.Key_Right):
            self._step(-1 if key == Qt.Key.Key_Left else 1)
            return True
        if key in (Qt.Key.Key_Return, Qt.Key.Key_Enter):
            self._mark("end" if mods & Qt.KeyboardModifier.ShiftModifier else "start")
            return True
        if key == Qt.Key.Key_Delete and QApplication.focusWidget() is self.table:
            self._delete_selected()
            return True
        return False

    # ---------- Chiusura ----------
    def _changed(self) -> bool:
        return self.phrases != self._saved or self.tr_lang != self.caption.tr_lang

    def _finish(self):
        self._text_timer.stop()
        if self.side_stack.currentIndex() == 0:
            self._apply_text_box()

    def accept(self):
        self._finish()
        # Frasi vuote non servono a niente: si tolgono e le automatiche si riprendono il loro tempo
        kept = [p for p in self.phrases if p.get("text", "").strip() or p.get("tr", "").strip()]
        if len(kept) != len(self.phrases):
            self.phrases = kept
            self._retime()
        self._cleanup()
        super().accept()

    def reject(self):
        self._finish()
        if self._changed():
            answer = QMessageBox.question(self, "Sottotitoli", "Chiudere senza tenere le modifiche ai sottotitoli?")
            if answer != QMessageBox.StandardButton.Yes:
                return
        self._cleanup()
        super().reject()

    def closeEvent(self, event):
        event.ignore()
        self.reject()

    def _cleanup(self):
        QApplication.instance().removeEventFilter(self)
        self._settings_save()
        self._timer.stop()
        self.player.close()
        if self.reader is not None:
            self.reader.close()
            self.reader = None
