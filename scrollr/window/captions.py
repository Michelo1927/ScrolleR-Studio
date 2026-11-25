"""Sottotitoli dei video: blocchi sulla tela, proprietà, finestra Sottotitoli, file .srt."""
import os
from typing import List, Optional

from PyQt6.QtCore import QPointF
from PyQt6.QtGui import QColor
from PyQt6.QtWidgets import QColorDialog, QFileDialog, QMessageBox, QVBoxLayout, QWidget

from scrollr.canvas.caption_item import CaptionItem
from scrollr.canvas.scene import reel_safe_polygon
from scrollr.canvas.video_item import VideoItem
from scrollr.captions import is_synced, parse_srt, to_srt
from scrollr.crashlog import log_handled
from scrollr.icons import swatch_icon
from scrollr.widgets import ToggleSwitch


class CaptionsMixin:
    """Sottotitoli dei video: blocchi sulla tela, proprietà, finestra Sottotitoli, file .srt."""

    # ================= BLOCCHI SULLA TELA =================
    def get_canvas_captions(self) -> List[CaptionItem]:
        items = [it for it in self.scene.items() if isinstance(it, CaptionItem)]
        items.sort(key=lambda c: c.uid)
        return items

    def _selected_captions(self) -> List[CaptionItem]:
        return [it for it in self.scene.selectedItems() if isinstance(it, CaptionItem)]

    def _spawn_caption_item(self, video_uid: int = 0, uid: Optional[int] = None) -> CaptionItem:
        c = CaptionItem(video_uid, uid=uid)
        c.geometry_changed.connect(self._on_item_geometry_changed)
        c.edit_finished.connect(self._schedule_commit)
        c.edit_requested.connect(self._open_captions_dialog)
        self.scene.addItem(c)
        return c

    def _restore_captions(self, states: list):
        existing = {c.uid: c for c in self.get_canvas_captions()}
        wanted = set()
        for s in states:
            wanted.add(s["uid"])
            c = existing.get(s["uid"]) or self._spawn_caption_item(uid=s["uid"])
            c.set_state(s)
        for uid, c in existing.items():
            if uid not in wanted:
                self.scene.removeItem(c)

    def _drop_orphan_captions(self):
        """I sottotitoli di un video tolto dalla tela se ne vanno con lui (nello stesso passo di Annulla)."""
        videos = {v.uid for v in self.get_canvas_videos()}
        for c in self.get_canvas_captions():
            if c.video_uid not in videos:
                self.scene.removeItem(c)

    def _captions_of(self, video: VideoItem) -> Optional[CaptionItem]:
        return next((c for c in self.get_canvas_captions() if c.video_uid == video.uid), None)

    def _caption_video(self, c: CaptionItem) -> Optional[VideoItem]:
        return next((v for v in self.get_canvas_videos() if v.uid == c.video_uid), None)

    def _place_new_caption(self, c: CaptionItem, video: VideoItem):
        """
        Posizione e misure di partenza: centrato, verso il centro-basso. Sulle pagine 9:16 il fondo del
        blocco sta dove comincia la colonna dei pulsanti, così resta tutto nella zona sicura del reel.
        """
        fw, fh = self.scene.frame_w, self.scene.frame_h
        k = self._page_of(video)
        c.font_size = float(round(fw * 0.054))
        c.wrap_w = round(fw * 0.80)
        poly = reel_safe_polygon(fw, fh)
        bottom = poly.at(2).y() if poly is not None else fh * 0.86
        c.relayout(keep_center=False)
        rect = c.text_rect()
        c.setPos(QPointF(k * fw + (fw - rect.width()) / 2.0, bottom - rect.height()))

    def add_captions_to_video(self, video: Optional[VideoItem] = None):
        """Apre i sottotitoli del video (selezionato): se non ci sono ancora, li crea."""
        if not isinstance(video, VideoItem):
            videos = self._selected_videos()
            caps = self._selected_captions()
            if caps:
                self._open_captions_dialog(caps[0])
                return
            if not videos:
                self.statusBar().showMessage("Seleziona prima un video", 4000)
                return
            video = videos[0]
        existing = self._captions_of(video)
        if existing is not None:
            self._open_captions_dialog(existing)
            return
        if video.is_missing:
            self.statusBar().showMessage("Il video non è stato trovato: ricollegalo prima", 5000)
            return
        c = self._spawn_caption_item(video.uid)
        self._place_new_caption(c, video)
        c.setZValue(self._max_z() + 1.0)
        if not self._open_captions_dialog(c, new=True):
            self.scene.removeItem(c)  # Finestra chiusa senza frasi: il blocco nuovo non resta
            return
        self.scene.clearSelection()
        c.setSelected(True)

    def _open_captions_dialog(self, c: CaptionItem, new: bool = False) -> bool:
        """Finestra Sottotitoli; alla chiusura con «Fatto» le modifiche entrano in un solo passo di Annulla."""
        from scrollr.caption_dialog import CaptionsDialog  # Import tardivo: la finestra usa Qt Multimedia
        video = self._caption_video(c)
        if video is None:
            return False
        self._flush_pending_commit()
        self._stop_all_videos()
        dlg = CaptionsDialog(self, c, video)
        if not dlg.exec():
            return False
        if new and not dlg.phrases:
            return False
        c.set_phrases(dlg.phrases)
        c.tr_lang = dlg.tr_lang
        c.update()
        self._schedule_commit()
        self._sync_inspector_from_item(self._get_primary_selected())
        return True

    # ================= PROPRIETÀ (in cima all'inspector del testo) =================
    def _caption_inspector_box(self) -> QWidget:
        box = QWidget()
        lay = QVBoxLayout(box)
        lay.setContentsMargins(0, 0, 0, 6)
        lay.setSpacing(6)
        self._section_header(lay, "Sottotitoli")
        btn = self._icon_button("captions", "Scrivi, sincronizza e traduci le frasi (doppio clic sul blocco)",
                                lambda: self._open_selected_captions(), "Modifica sottotitoli…", "SoftButton")
        lay.addWidget(btn)
        self.lbl_caption_info = self._label("", "Hint")
        self.lbl_caption_info.setWordWrap(True)
        lay.addWidget(self.lbl_caption_info)
        self.slider_caption_width = self._make_slider(lay, "Larghezza", 20, 100, 80, "%")
        self.slider_caption_width.setToolTip("Larghezza massima delle righe, rispetto alla pagina:\n"
                                             "le frasi lunghe vanno su due righe bilanciate")
        self.slider_caption_width.valueChanged.connect(lambda v: self._on_caption_prop("wrap", v))
        self._section_header(lay, "Traduzione")
        self.chk_caption_tr = ToggleSwitch("Mostra la traduzione")
        self.chk_caption_tr.setToolTip("Seconda riga sotto la frase (si scrive nella finestra Sottotitoli)")
        self.chk_caption_tr.toggled.connect(lambda on: self._on_caption_prop("tr_show", on))
        lay.addWidget(self.chk_caption_tr)
        self.btn_caption_tr_color = self._icon_button("plus", "Colore della traduzione", self._pick_caption_tr_color,
                                                      "Colore traduzione", "SoftButton")
        lay.addWidget(self.btn_caption_tr_color)
        self.slider_caption_tr_size = self._make_slider(lay, "Dimensione", 40, 100, 70, "%", resettable=True)
        self.slider_caption_tr_size.setToolTip("Grandezza della traduzione rispetto alla frase")
        self.slider_caption_tr_size.valueChanged.connect(lambda v: self._on_caption_prop("tr_size", v))
        self.btn_caption_tr_italic = self._soft_toggle("Corsivo", "Traduzione in corsivo",
                                                       lambda c: self._on_caption_prop("tr_italic", c))
        lay.addWidget(self.btn_caption_tr_italic)
        row = QWidget()
        rl = QVBoxLayout(row)
        rl.setContentsMargins(0, 4, 0, 0)
        rl.setSpacing(6)
        rl.addWidget(self._icon_button("download", "Legge le frasi (o la traduzione) da un file di sottotitoli .srt",
                                       self._import_caption_srt, "Importa .srt…", "SoftButton"))
        rl.addWidget(self._icon_button("export", "Salva le frasi come file .srt (e la traduzione in un secondo file)",
                                       self._export_caption_srt, "Esporta .srt…", "SoftButton"))
        lay.addWidget(row)
        lay.addWidget(self._divider())
        box.setVisible(False)
        self.caption_box = box
        return box

    def _open_selected_captions(self):
        caps = self._selected_captions()
        if caps:
            self._open_captions_dialog(caps[0])

    def _sync_caption_inspector(self, t):
        """Sezione Sottotitoli visibile solo per un blocco di sottotitoli (che non ha il testo libero)."""
        is_caption = isinstance(t, CaptionItem)
        self.caption_box.setVisible(is_caption)
        self.edit_text.setVisible(not is_caption)
        if not is_caption:
            return
        self.lbl_text_title.setText("Sottotitoli")
        total = len(t.phrases)
        synced = sum(1 for p in t.phrases if is_synced(p))
        if not total:
            info = "Nessuna frase: apri la finestra per scriverle."
        else:
            info = f"{total} frasi" if total != 1 else "1 frase"
            if synced < total:
                info += f", {total - synced} da sincronizzare"
        video = self._caption_video(t)
        if video is not None:
            info += f"\nVideo: {os.path.basename(video.image_path)}"
        self.lbl_caption_info.setText(info)
        self.slider_caption_width.setValue(round(t.wrap_w / max(1.0, self.scene.frame_w) * 100))
        self.chk_caption_tr.setChecked(t.tr_show)
        self.btn_caption_tr_color.setIcon(swatch_icon(t.tr_color))
        self.slider_caption_tr_size.setValue(t.tr_size)
        self.btn_caption_tr_italic.setChecked(t.tr_italic)

    def _on_caption_prop(self, prop: str, value):
        if self._updating_inspector:
            return
        for c in self._selected_captions():
            if prop == "wrap":
                c.wrap_w = round(self.scene.frame_w * value / 100.0)
            elif prop == "tr_show":
                c.tr_show = bool(value)
            elif prop == "tr_size":
                c.tr_size = int(value)
            elif prop == "tr_italic":
                c.tr_italic = bool(value)
            c.relayout()
        self._schedule_commit()

    def _pick_caption_tr_color(self):
        caps = self._selected_captions()
        if not caps:
            return
        col = QColorDialog.getColor(caps[0].tr_color, self, "Colore della traduzione")
        if not col.isValid():
            return
        for c in caps:
            c.tr_color = QColor(col)
            c.update()
        self.btn_caption_tr_color.setIcon(swatch_icon(col))
        self._schedule_commit()

    # ================= FILE .SRT =================
    def _srt_base_name(self, c: CaptionItem) -> str:
        video = self._caption_video(c)
        return os.path.splitext(video.image_path)[0] if video is not None else "sottotitoli"

    def _import_caption_srt(self):
        caps = self._selected_captions()
        if not caps:
            return
        c = caps[0]
        path, _ = QFileDialog.getOpenFileName(self, "Importa sottotitoli", os.path.dirname(self._srt_base_name(c)),
                                              "Sottotitoli SubRip (*.srt)")
        if not path:
            return
        phrases = self._read_srt(path)
        if phrases is None:
            return
        if c.phrases:
            box = QMessageBox(QMessageBox.Icon.Question, "Importa sottotitoli",
                              f"Il file ha {len(phrases)} frasi. Cosa ne faccio?", parent=self)
            replace = box.addButton("Sostituisci le frasi", QMessageBox.ButtonRole.AcceptRole)
            as_tr = box.addButton("Usale come traduzione", QMessageBox.ButtonRole.ActionRole)
            box.addButton("Annulla", QMessageBox.ButtonRole.RejectRole)
            box.exec()
            if box.clickedButton() is as_tr:
                c.set_phrases(self._translation_from(c.phrases, phrases))
            elif box.clickedButton() is replace:
                c.set_phrases(phrases)
            else:
                return
        else:
            c.set_phrases(phrases)
        self._schedule_commit()
        self._sync_inspector_from_item(None)
        self.statusBar().showMessage(f"Sottotitoli importati da {os.path.basename(path)}", 4000)

    def _read_srt(self, path: str) -> Optional[list]:
        try:
            with open(path, "rb") as f:
                raw = f.read()
            try:
                text = raw.decode("utf-8-sig")
            except UnicodeDecodeError:
                text = raw.decode("cp1252", errors="replace")  # Vecchi .srt di Windows
        except OSError as e:
            QMessageBox.warning(self, "File non letto", f"Il file non si può leggere:\n{e}")
            return None
        phrases = parse_srt(text)
        if not phrases:
            QMessageBox.warning(self, "Nessun sottotitolo", "Nel file non ho trovato sottotitoli in formato .srt.")
            return None
        return phrases

    @staticmethod
    def _translation_from(phrases: list, other: list) -> list:
        """La traduzione di ogni frase è il testo dei sottotitoli del file che la coprono di più nel tempo."""
        out = []
        for p in phrases:
            q = dict(p)
            if is_synced(p):
                best = max(other, key=lambda o: min(p["end"], o["end"]) - max(p["start"], o["start"]))
                if min(p["end"], best["end"]) - max(p["start"], best["start"]) > 0:
                    q["tr"] = best["text"]
            out.append(q)
        return out

    def _export_caption_srt(self):
        caps = self._selected_captions()
        if not caps:
            return
        c = caps[0]
        if not any(is_synced(p) and p.get("text", "").strip() for p in c.phrases):
            QMessageBox.information(self, "Niente da esportare", "Non ci sono ancora frasi sincronizzate.")
            return
        base = self._srt_base_name(c)
        path, _ = QFileDialog.getSaveFileName(self, "Esporta sottotitoli", f"{base}.{c.lang or 'it'}.srt",
                                              "Sottotitoli SubRip (*.srt)")
        if not path:
            return
        written = [path]
        try:
            with open(path, "w", encoding="utf-8", newline="\r\n") as f:
                f.write(to_srt(c.phrases, "text"))
            if c.has_translation():
                stem = path[:-4] if path.lower().endswith(".srt") else path
                lang = c.lang or "it"
                if stem.endswith("." + lang):
                    stem = stem[:-len(lang) - 1]
                tr_path = f"{stem}.{c.tr_lang or 'tr'}.srt"
                with open(tr_path, "w", encoding="utf-8", newline="\r\n") as f:
                    f.write(to_srt(c.phrases, "tr"))
                written.append(tr_path)
        except OSError as e:
            log_handled("Esportazione .srt")
            QMessageBox.warning(self, "Sottotitoli non salvati", f"Il file non si può scrivere:\n{e}")
            return
        names = " e ".join(os.path.basename(p) for p in written)
        self.statusBar().showMessage(f"Sottotitoli salvati: {names}", 6000)
