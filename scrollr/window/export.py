"""Esportazione del collage ad alta risoluzione."""
import os
import re
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Callable, List, Optional

from PyQt6.QtCore import QRectF, QStandardPaths, Qt, QUrl
from PyQt6.QtGui import QDesktopServices, QImage, QPainter
from PyQt6.QtWidgets import QApplication, QFileDialog, QMessageBox, QProgressDialog

from scrollr.canvas.video_item import VideoItem
from scrollr.crashlog import log_handled
from scrollr.dialogs import PageExportDialog
from scrollr.imaging import IMAGE_CACHE, ImageCache
from scrollr.video import (
    VIDEO_FPS, VIDEO_MAX_SECONDS, FrameReader, Mp4Writer, loop_audio, mix_audio, output_size, read_audio
)


class ExportMixin:
    """Esportazione del collage ad alta risoluzione."""

    # ================= ESPORTAZIONE AD ALTA RISOLUZIONE =================
    def _get_export_scale(self) -> int:
        return 2 if self.combo_quality.currentIndex() == 1 else 1

    def _export_ext(self) -> str:
        return ".jpg" if self.combo_format.currentIndex() == 1 else ".png"

    def _save_image(self, img: QImage, path: str) -> bool:
        if path.lower().endswith((".jpg", ".jpeg")):
            return img.convertToFormat(QImage.Format.Format_RGB32).save(path, "JPG", self.combo_jpg_quality.currentData())
        # PNG resta senza perdite; con una compressione un po' più bassa si salva in circa metà tempo
        return img.save(path, "PNG", 80)

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

    def _render_layer(self, source: QRectF, out_w: int, out_h: int, show: Callable,
                      background: bool, overlays: bool) -> Optional[QImage]:
        """
        Solo gli elementi per cui show(elemento) è vero, su fondo trasparente (con background=True
        anche lo sfondo della tela, con overlays=True anche numeri di pagina e «scorri»).
        Gli altri si rendono invisibili per un attimo con l'opacità, che non tocca la selezione.
        """
        hidden = []
        for it in self._all_elements():
            if not show(it) and it.opacity() > 0:
                hidden.append((it, it.opacity()))
                it.setOpacity(0.0)
        self.scene.skip_background = not background
        self.scene.skip_overlays = not overlays
        try:
            img = QImage(out_w, out_h, QImage.Format.Format_ARGB32_Premultiplied)
            if img.isNull():
                return None
            img.fill(self.scene.bg_color if background else Qt.GlobalColor.transparent)
            painter = QPainter(img)
            painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
            painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, True)
            self.scene.render(painter, QRectF(0, 0, out_w, out_h), source)
            painter.end()
            return img
        finally:
            for it, opacity in hidden:
                it.setOpacity(opacity)
            self.scene.skip_background = self.scene.skip_overlays = False

    def _video_page_frames(self, k: int) -> int:
        """Fotogrammi dell'MP4 della pagina k: dura quanto il video più lungo (al massimo 60 s)."""
        longest = max((v.clip_length() for v in self._page_videos(k)), default=0.0)
        return max(1, round(min(longest, VIDEO_MAX_SECONDS) * VIDEO_FPS))

    def _export_video_page(self, k: int, path: str, progress: QProgressDialog, step: int) -> Optional[bool]:
        """
        Pagina k come MP4. Ciò che sta sotto e sopra i video si disegna una volta sola; a ogni fotogramma
        si ridisegnano solo i video (e gli elementi tra un video e l'altro). I video più corti ripartono
        da capo; l'audio dei video non muti si sovrappone. None = annullata dall'utente.
        """
        fw, fh = self.scene.frame_w, self.scene.frame_h
        out_w, out_h = output_size(fw, fh)
        source = QRectF(k * fw, 0, fw, fh)
        videos = self._page_videos(k)
        n = self._video_page_frames(k)
        seconds = n / VIDEO_FPS
        z_lo = min(v.zValue() for v in videos)
        z_hi = max(v.zValue() for v in videos)
        below = self._render_layer(source, out_w, out_h, lambda it: it.zValue() < z_lo, True, False)
        above = self._render_layer(source, out_w, out_h, lambda it: it.zValue() > z_hi, False, True)
        if below is None or above is None:
            return False

        tracks = []
        for v in videos:
            if v.has_audio and not v.muted:
                try:
                    pcm = read_audio(v.image_path, v.trim_start, v.clip_end())
                except Exception:
                    pcm = None
                if pcm:
                    tracks.append(loop_audio(pcm, seconds))
        audio = mix_audio(tracks) if tracks else None

        px = out_w / fw  # Pixel dell'MP4 per unità della tela
        readers = {}
        writer = None
        ok = False
        try:
            for v in videos:
                size = v.export_frame_size(px)
                readers[v] = FrameReader(v.image_path, None if size else v.export_side(px), size)
            writer = Mp4Writer(path, out_w, out_h, VIDEO_FPS, audio)
            for i in range(n):
                t = i / VIDEO_FPS
                for v in videos:
                    v.set_export_frame(readers[v].frame_at(v.trim_start + t % v.clip_length()))
                middle = self._render_layer(source, out_w, out_h, lambda it: z_lo <= it.zValue() <= z_hi, False, False)
                if middle is None:
                    return False
                frame = QImage(below)
                painter = QPainter(frame)
                painter.drawImage(0, 0, middle)
                painter.drawImage(0, 0, above)
                painter.end()
                rgba = frame.convertToFormat(QImage.Format.Format_RGBA8888)
                ptr = rgba.constBits()
                ptr.setsize(rgba.sizeInBytes())
                writer.add_frame(bytes(ptr))
                progress.setValue(step + i)
                if i % 3 == 0:
                    QApplication.processEvents()
                    if progress.wasCanceled():
                        return None
            writer.close()
            writer = None
            ok = True
            return True
        except Exception:
            log_handled(f"Esportazione MP4 della pagina {k + 1}")
            return False
        finally:
            for v in videos:
                v.set_export_frame(None)
            for r in readers.values():
                r.close()
            if writer is not None:
                writer.abort()
            if not ok and os.path.exists(path):
                try:
                    os.remove(path)  # Niente MP4 a metà
                except OSError:
                    pass

    def _begin_export(self):
        self._flush_pending_commit()
        self._stop_all_videos()
        self.scene.is_exporting = True
        QApplication.setOverrideCursor(Qt.CursorShape.WaitCursor)

    def _end_export(self):
        self.scene.is_exporting = False
        IMAGE_CACHE.release_full()
        QApplication.restoreOverrideCursor()
        self.scene.update()

    def _warn_if_empty(self) -> bool:
        missing = self._missing_on_canvas()
        if missing:
            answer = QMessageBox.question(
                self, "Foto mancanti",
                ("1 foto sulla tela non è stata trovata e resterà vuota" if missing == 1
                 else f"{missing} foto sulla tela non sono state trovate e resteranno vuote")
                + " nell'immagine esportata.\n\nPuoi ricollegarle con File → Ricollega foto mancanti. "
                "Esportare comunque?")
            if answer != QMessageBox.StandardButton.Yes:
                return False
        if self.get_canvas_photos():
            return True
        answer = QMessageBox.question(self, "Tela vuota", "Non ci sono foto sulla tela. Esportare comunque?")
        return answer == QMessageBox.StandardButton.Yes

    # ---------- Nome dei file ----------
    @staticmethod
    def _clean_file_name(name: str) -> str:
        """Nome usabile come file su Windows e Mac: niente caratteri vietati, spazi ai bordi o estensione."""
        name = re.sub(r'[\\/:*?"<>|\x00-\x1f]', "", name).strip().strip(".")
        return re.sub(r"\.(png|jpe?g)$", "", name, flags=re.IGNORECASE).strip()

    def _page_file_name(self, k: int, ext: str) -> str:
        """Nome del file della pagina k: «viaggio_01.jpg» col nome scelto, altrimenti «frame_01.jpg»."""
        return f"{self._clean_file_name(self.export_name) or 'frame'}_{k + 1:02d}{ext}"

    def _set_export_name(self, name: str):
        name = self._clean_file_name(name)
        if name != self.export_name:
            self.export_name = name  # Vale per il progetto: si salva con lui
            self._schedule_commit()

    # ---------- Cartella di esportazione ----------
    def _export_dir(self) -> str:
        """Ultima cartella usata per esportare (la prima volta: Immagini)."""
        last = self._settings().value("export_dir", "", type=str)
        if last and os.path.isdir(last):
            return last
        pictures = QStandardPaths.writableLocation(QStandardPaths.StandardLocation.PicturesLocation)
        return pictures or os.path.expanduser("~")

    def _remember_export_dir(self, folder: str):
        self._settings().setValue("export_dir", folder)

    def _export_done(self, title: str, text: str, folder: str, warning: bool = False):
        """Messaggio finale con «Apri cartella», così si vede subito dove sono i file."""
        box = QMessageBox(self)
        box.setWindowTitle(title)
        box.setIcon(QMessageBox.Icon.Warning if warning else QMessageBox.Icon.Information)
        box.setText(text)
        btn_open = box.addButton("Apri cartella", QMessageBox.ButtonRole.ActionRole)
        box.addButton(QMessageBox.StandardButton.Ok)
        box.exec()
        if box.clickedButton() is btn_open:
            QDesktopServices.openUrl(QUrl.fromLocalFile(folder))

    # ---------- Lettura degli originali ----------
    def _export_progress(self, steps: int) -> QProgressDialog:
        progress = QProgressDialog("Preparazione delle foto…", "Annulla", 0, steps, self)
        progress.setWindowTitle("Esportazione")
        progress.setWindowModality(Qt.WindowModality.WindowModal)
        progress.setMinimumDuration(0)
        progress.setValue(0)
        QApplication.processEvents()
        return progress

    def _export_photo_count(self) -> int:
        return len({p.image_path for p in self.get_canvas_photos() if not p.is_missing and not isinstance(p, VideoItem)})

    def _prefetch_originals(self, scale: float, progress: QProgressDialog) -> bool:
        """
        Legge in parallelo gli originali delle foto sulla tela, ognuno solo grande quanto serve
        all'uscita (un passo della barra per foto). False se l'utente annulla.
        """
        sides = {}
        for p in self.get_canvas_photos():
            if isinstance(p, VideoItem):
                continue  # Il fotogramma si legge al momento del disegno
            side = p.export_side(scale * 1.001)  # Un filo più grande: il disegno lo trova già pronto
            if side is not None:
                sides[p.image_path] = max(side, sides.get(p.image_path, 0))
        pool = ThreadPoolExecutor(max_workers=max(1, min(8, (os.cpu_count() or 2) - 1)),
                                  thread_name_prefix="esportazione")
        futures = {pool.submit(ImageCache.decode_full, path, side): (path, side) for path, side in sides.items()}
        try:
            for done, future in enumerate(as_completed(futures), 1):
                path, side = futures[future]
                try:
                    IMAGE_CACHE.store_full(path, side, future.result())
                except Exception:
                    pass  # Il disegno riproverà da solo (o userà l'anteprima)
                progress.setValue(done)
                progress.setLabelText(f"Preparazione delle foto…  ({done} di {len(futures)})")
                QApplication.processEvents()
                if progress.wasCanceled():
                    return False
        finally:
            pool.shutdown(wait=False, cancel_futures=True)
        return True

    # ---------- Esportazioni ----------
    def export_full_collage(self):
        if not self._warn_if_empty():
            return
        scale = self._get_export_scale()
        canvas = self.scene.canvas_rect()
        out_w = int(canvas.width() * scale)
        out_h = int(canvas.height() * scale)
        frames = self.scene.num_frames
        frames_tag = f"_{frames}pagine" if frames > 1 else ""

        ext = self._export_ext()
        filters = ["PNG alta qualità (*.png)", "JPEG, file leggero (*.jpg *.jpeg)"]
        if ext == ".jpg":
            filters.reverse()
        base = self._clean_file_name(self.export_name)
        name = (f"{base}{ext}" if base else
                f"collage_{self.scene.frame_w}x{self.scene.frame_h}{frames_tag}_{out_w}x{out_h}{ext}")
        path, _ = QFileDialog.getSaveFileName(
            self, f"Dove salvo il collage? ({out_w}×{out_h} px)",
            os.path.join(self._export_dir(), name), ";;".join(filters))
        if not path:
            return
        self._remember_export_dir(os.path.dirname(path))
        if base:
            # Il nome cambiato nella finestra di salvataggio diventa il nome dei file del progetto
            self._set_export_name(os.path.splitext(os.path.basename(path))[0])

        n_photos = self._export_photo_count()
        progress = self._export_progress(n_photos + 2)
        img, ok, canceled = None, False, False
        self._begin_export()
        try:
            if not self._prefetch_originals(scale, progress):
                canceled = True
            else:
                progress.setLabelText(f"Composizione del collage ({out_w}×{out_h} px)…")
                progress.setValue(n_photos)
                QApplication.processEvents()
                img = self._render_region(canvas, out_w, out_h)
                if img is not None:
                    progress.setLabelText("Salvataggio del file…")
                    progress.setValue(n_photos + 1)
                    QApplication.processEvents()
                    ok = self._save_image(img, path)
        finally:
            progress.setValue(n_photos + 2)
            self._end_export()

        if canceled:
            self.statusBar().showMessage("Esportazione annullata", 4000)
        elif img is None:
            QMessageBox.critical(
                self, "Collage non esportato",
                f"Memoria insufficiente per creare un'immagine di {out_w}×{out_h} px.\n"
                "Scegli Qualità standard (1×) oppure esporta le pagine separate."
            )
        elif not ok:
            QMessageBox.critical(self, "Collage non esportato", f"Impossibile salvare il file:\n{path}")
        else:
            self._export_done("Collage esportato", f"Salvato in:\n{path}\n\nRisoluzione: {out_w}×{out_h} px",
                              os.path.dirname(path))

    def _choose_export_pages(self) -> Optional[List[int]]:
        """Finestra con le miniature per scegliere le pagine da esportare e il nome dei file (None = annullato)."""
        self._flush_pending_commit()
        QApplication.setOverrideCursor(Qt.CursorShape.WaitCursor)
        try:
            thumbs = self._render_page_previews(max_side=260)
        finally:
            QApplication.restoreOverrideCursor()
        dialog = PageExportDialog(thumbs, [self.scene.page_label(i) for i in range(self.scene.num_frames)],
                                  self.export_name, self._export_ext(), self)
        if not dialog.exec():
            return None
        self._set_export_name(dialog.file_name())
        return dialog.pages()

    def export_split_frames(self, pages: Optional[List[int]] = None):
        """Una immagine per pagina. Senza `pages` si scelgono le pagine dalle miniature."""
        if pages is None:
            pages = self._choose_export_pages()
            if not pages:
                return
        pages = [k for k in pages if 0 <= k < self.scene.num_frames]
        if not pages or not self._warn_if_empty():
            return
        title = ("In quale cartella salvo le pagine?" if len(pages) > 1
                 else f"In quale cartella salvo la pagina {pages[0] + 1}?")
        folder = QFileDialog.getExistingDirectory(self, title, self._export_dir())
        if not folder:
            return
        self._remember_export_dir(folder)

        num_frames = len(pages)
        ext = self._export_ext()
        # Le pagine con un video diventano MP4 (un passo della barra per fotogramma)
        video_frames = {k: self._video_page_frames(k) for k in pages if self._page_videos(k)}
        file_paths = [os.path.join(folder, self._page_file_name(k, ".mp4" if k in video_frames else ext))
                      for k in pages]
        existing = [p for p in file_paths if os.path.exists(p)]
        if existing:
            answer = QMessageBox.question(
                self, "Sostituire i file?",
                (f"Nella cartella c'è già il file {os.path.basename(existing[0])}. Vuoi sostituirlo?"
                 if len(existing) == 1 else
                 f"Nella cartella ci sono già {len(existing)} file con questi nomi "
                 f"({os.path.basename(existing[0])}…). Vuoi sostituirli?")
            )
            if answer != QMessageBox.StandardButton.Yes:
                return

        scale = self._get_export_scale()
        fw = self.scene.frame_w
        fh = self.scene.frame_h
        out_w = int(fw * scale)
        out_h = int(fh * scale)

        n_photos = self._export_photo_count()
        total = n_photos + sum(video_frames.get(k, 1) for k in pages)
        progress = self._export_progress(total)
        saved_files: List[str] = []
        failed: List[str] = []
        canceled = False
        self._begin_export()
        try:
            if not self._prefetch_originals(scale, progress):
                canceled = True
            else:
                step = n_photos
                for i, (k, file_path) in enumerate(zip(pages, file_paths)):
                    progress.setValue(step)
                    progress.setLabelText(f"Pagina {k + 1} ({i + 1} di {num_frames})"
                                          + ("  ·  video MP4…" if k in video_frames else "…"))
                    QApplication.processEvents()
                    if progress.wasCanceled():
                        canceled = True
                        break
                    if k in video_frames:
                        result = self._export_video_page(k, file_path, progress, step)
                        step += video_frames[k]
                        if result is None:
                            canceled = True
                            break
                        if result:
                            saved_files.append(file_path)
                        else:
                            failed.append(os.path.basename(file_path))
                        continue
                    step += 1
                    img = self._render_region(QRectF(k * fw, 0, fw, fh), out_w, out_h)
                    if img is not None and self._save_image(img, file_path):
                        saved_files.append(file_path)
                    else:
                        failed.append(os.path.basename(file_path))
        finally:
            progress.setValue(total)
            self._end_export()

        if canceled and not saved_files:
            self.statusBar().showMessage("Esportazione annullata", 4000)
            return
        if len(saved_files) == 1:
            msg = f"Pagina esportata ({out_w}×{out_h} px):\n{saved_files[0]}"
        else:
            msg = f"{len(saved_files)} pagine esportate ({out_w}×{out_h} px ciascuna) in:\n{folder}"
        n_mp4 = sum(1 for p in saved_files if p.endswith(".mp4"))
        if n_mp4:
            vw, vh = output_size(fw, fh)
            msg += ("\n\nLa pagina con video è un MP4" if n_mp4 == 1 else f"\n\nLe {n_mp4} pagine con video sono MP4") \
                + f" ({vw}×{vh} px, {VIDEO_FPS} fps)."
        if canceled:
            msg += "\n\nEsportazione interrotta: le pagine successive non sono state salvate."
        if failed:
            self._export_done("Esportazione incompleta", msg + "\n\nNon salvate: " + ", ".join(failed), folder, True)
        else:
            self._export_done("Pagine esportate", msg, folder)
