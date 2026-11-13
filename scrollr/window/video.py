"""Video sulla tela: pannello nell'inspector, riproduzione e video sempre dentro una pagina."""
from typing import List

from PyQt6.QtCore import QRectF, QPointF
from PyQt6.QtWidgets import QVBoxLayout, QWidget

from scrollr.canvas.video_item import VideoItem, format_time
from scrollr.icons import make_icon
from scrollr.theme import THEME
from scrollr.video import VIDEO_MAX_SECONDS
from scrollr.widgets import ToggleSwitch


class VideoMixin:
    """Video sulla tela: pannello nell'inspector, riproduzione e video sempre dentro una pagina."""

    # ================= PANNELLO VIDEO NELL'INSPECTOR =================
    def _video_inspector_box(self) -> QWidget:
        """Sezione «Video» in cima all'inspector della foto: compare solo quando è selezionato un video."""
        box = QWidget()
        lay = QVBoxLayout(box)
        lay.setContentsMargins(0, 4, 0, 6)
        lay.setSpacing(6)
        self._section_header(lay, "Video")
        self.btn_video_play = self._icon_button("play", "Guarda il video sulla tela, senza audio (si ripete da capo)",
                                                self._toggle_video_play, "Riproduci", "SoftButton")
        lay.addWidget(self.btn_video_play)

        def tenths(v: int) -> str:
            return format_time(v / 10.0)

        self.slider_video_start = self._make_slider(lay, "Inizio", 0, 10, 0, fmt=tenths)
        self.slider_video_start.setToolTip("Da che punto parte il video nella pagina esportata")
        self.slider_video_start.valueChanged.connect(lambda v: self._on_video_slider("start", v))
        self.slider_video_end = self._make_slider(lay, "Fine", 0, 10, 10, fmt=tenths)
        self.slider_video_end.setToolTip("Dove finisce il video: poi ricomincia da capo se un altro video\n"
                                         "della stessa pagina dura di più")
        self.slider_video_end.valueChanged.connect(lambda v: self._on_video_slider("end", v))
        self.slider_video_poster = self._make_slider(lay, "Copertina", 0, 10, 0, fmt=tenths)
        self.slider_video_poster.setToolTip("Fotogramma mostrato sulla tela, nelle anteprime\n"
                                            "e nell'esportazione del collage intero")
        self.slider_video_poster.valueChanged.connect(lambda v: self._on_video_slider("poster", v))
        self.chk_video_audio = ToggleSwitch("Audio nel video esportato")
        self.chk_video_audio.setToolTip("Con più video sulla stessa pagina, l'audio di quelli accesi si sovrappone")
        self.chk_video_audio.toggled.connect(self._set_video_audio)
        lay.addWidget(self.chk_video_audio)
        self.lbl_video_info = self._label("", "Hint")
        self.lbl_video_info.setWordWrap(True)
        lay.addWidget(self.lbl_video_info)
        lay.addWidget(self._divider())
        box.setVisible(False)
        self.video_box = box
        return box

    def _selected_videos(self) -> List[VideoItem]:
        return [p for p in self._selected_photos() if isinstance(p, VideoItem)]

    def get_canvas_videos(self) -> List[VideoItem]:
        return [p for p in self.get_canvas_photos() if isinstance(p, VideoItem)]

    def _sync_video_inspector(self, item):
        """Mostra la sezione Video (e spegne la scheda Colore, che per i video non vale)."""
        is_video = isinstance(item, VideoItem)
        self.video_box.setVisible(is_video)
        color_tab = self.photo_tab_bar._group.buttons()[1]
        color_tab.setEnabled(not is_video)
        color_tab.setToolTip("Le regolazioni colore non valgono per i video" if is_video
                             else "Luminosità, contrasto, saturazione, calore, bianco e nero")
        if is_video and self.photo_tabs.currentIndex() == 1:
            self.photo_tabs.setCurrentIndex(0)
        if not is_video:
            return
        top = max(1, round(item.duration * 10))
        for slider, value in ((self.slider_video_start, item.trim_start), (self.slider_video_end, item.clip_end()),
                              (self.slider_video_poster, item.poster)):
            slider.blockSignals(True)
            slider.setRange(0, top)
            slider.setValue(round(value * 10))
            slider.blockSignals(False)
            slider.valueChanged.emit(slider.value())  # Aggiorna il valore mostrato (_updating_inspector è attivo)
        self.chk_video_audio.setEnabled(item.has_audio)
        self.chk_video_audio.setChecked(item.has_audio and not item.muted)
        self._update_video_play_button()
        self._update_video_info(item)

    def _update_video_info(self, item: VideoItem):
        text = f"Durata {format_time(item.duration)}  ·  usati {format_time(item.clip_length())}"
        if not item.has_audio:
            text += "  ·  senza audio"
        if item.clip_length() > VIDEO_MAX_SECONDS + 0.05:
            text += (f"\nInstagram accetta slide fino a {int(VIDEO_MAX_SECONDS)} s: "
                     f"la pagina esportata si ferma lì.")
        self.lbl_video_info.setText(text)

    def _on_video_slider(self, which: str, value: int):
        if self._updating_inspector:
            return
        seconds = value / 10.0
        videos = self._selected_videos()
        for v in videos:
            if which == "start":
                v.set_trim(seconds, v.trim_end)
            elif which == "end":
                v.set_trim(v.trim_start, seconds)
            else:
                v.poster = max(0.0, min(seconds, v.duration))
                v.update()
        primary = self._get_primary_selected()
        if isinstance(primary, VideoItem):
            # Inizio e fine non si incrociano: l'altro cursore segue
            self._updating_inspector = True
            try:
                if which == "start":
                    self.slider_video_end.setValue(round(primary.clip_end() * 10))
                elif which == "end":
                    self.slider_video_start.setValue(round(primary.trim_start * 10))
            finally:
                self._updating_inspector = False
            self._update_video_info(primary)
            if which == "poster":
                self._refresh_selection_thumb()
        self._schedule_commit()

    def _set_video_audio(self, on: bool):
        if self._updating_inspector:
            return
        for v in self._selected_videos():
            v.muted = not on
            v.update()
        self._schedule_commit()

    # ---------- Riproduzione ----------
    def _toggle_video_play(self):
        videos = self._selected_videos()
        if not videos:
            return
        if any(v.is_playing for v in videos):
            for v in videos:
                v.stop()
        else:
            for v in videos:
                v.play()

    def _stop_all_videos(self):
        for v in self.get_canvas_videos():
            v.stop()

    def _on_video_playing_changed(self, _item):
        self._update_video_play_button()

    def _update_video_play_button(self):
        playing = any(v.is_playing for v in self._selected_videos())
        self.btn_video_play.setText("Pausa" if playing else "Riproduci")
        self.btn_video_play.setIcon(make_icon("pause" if playing else "play", THEME["text"]))

    # ================= VIDEO DENTRO UNA PAGINA =================
    def _page_videos(self, k: int) -> List[VideoItem]:
        """Video (trovati) che compaiono nella pagina k."""
        # Un filo di tolleranza: un video appoggiato al bordo non conta per la pagina accanto
        page = QRectF(k * self.scene.frame_w + 0.5, 0, self.scene.frame_w - 1.0, self.scene.frame_h)
        return [v for v in self.get_canvas_videos() if not v.is_missing and self._element_rect(v).intersects(page)]

    def _keep_videos_in_pages(self) -> bool:
        """
        Un video non può stare «a cavallo» tra due pagine: ogni pagina diventa un MP4 a sé e sui social
        le due metà non partirebbero insieme. Un video della disposizione si riduce alla parte nella
        pagina dove ne sta di più; uno libero (o ruotato) rientra spostandosi. True se ne ha sistemato uno.
        """
        fw, n = self.scene.frame_w, self.scene.num_frames
        fixed = False
        for v in self.get_canvas_videos():
            if v.page_locked:
                continue
            rect = self._element_rect(v)
            first = max(0, min(n - 1, int((rect.left() + 0.5) // fw)))
            last = max(0, min(n - 1, int((rect.right() - 0.5) // fw)))
            if first == last:
                continue
            # Pagina con la parte più grande del video
            best = max(range(first, last + 1),
                       key=lambda k: QRectF(k * fw, rect.top(), fw, rect.height()).intersected(rect).width())
            left, right = best * fw, (best + 1) * fw
            straight = abs(v.rotation()) < 0.01
            if straight and not v.free:
                part = rect.intersected(QRectF(left, rect.top(), fw, rect.height()))
                if part.width() >= v.MIN_CELL:
                    v.set_cell_size(part.width(), v.cell_h)
                    v.setPos(part.left(), v.pos().y())
                    fixed = True
                    continue
            if rect.width() > fw:
                k = fw / rect.width() * 0.98
                center = v.mapToScene(QPointF(v.cell_w / 2.0, v.cell_h / 2.0))
                v.set_cell_size(v.cell_w * k, v.cell_h * k)
                v.setPos(center - QPointF(v.cell_w / 2.0, v.cell_h / 2.0))
                rect = self._element_rect(v)
            dx = left - rect.left() if rect.left() < left else (right - rect.right() if rect.right() > right else 0.0)
            v.setPos(v.pos() + QPointF(dx, 0.0))
            fixed = True
        if fixed:
            self.statusBar().showMessage("I video non possono stare a cavallo tra due pagine: "
                                         "ogni pagina con un video diventa un MP4 a sé", 6000)
        return fixed
