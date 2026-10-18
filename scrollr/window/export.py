"""Esportazione del collage ad alta risoluzione."""
import os
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import List, Optional

from PyQt6.QtCore import QRectF, QStandardPaths, Qt, QUrl
from PyQt6.QtGui import QDesktopServices, QImage, QPainter
from PyQt6.QtWidgets import QApplication, QFileDialog, QMessageBox, QProgressDialog

from scrollr.imaging import IMAGE_CACHE, ImageCache


class ExportMixin:
    """Esportazione del collage ad alta risoluzione."""

    # ================= ESPORTAZIONE AD ALTA RISOLUZIONE =================
    def _get_export_scale(self) -> int:
        return 2 if self.combo_quality.currentIndex() == 1 else 1

    def _export_ext(self) -> str:
        return ".jpg" if self.combo_format.currentIndex() == 1 else ".png"

    @staticmethod
    def _save_image(img: QImage, path: str) -> bool:
        if path.lower().endswith((".jpg", ".jpeg")):
            return img.convertToFormat(QImage.Format.Format_RGB32).save(path, "JPG", 92)
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
        return len({p.image_path for p in self.get_canvas_photos() if not p.is_missing})

    def _prefetch_originals(self, scale: float, progress: QProgressDialog) -> bool:
        """
        Legge in parallelo gli originali delle foto sulla tela, ognuno solo grande quanto serve
        all'uscita (un passo della barra per foto). False se l'utente annulla.
        """
        sides = {}
        for p in self.get_canvas_photos():
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
        name = f"collage_{self.scene.frame_w}x{self.scene.frame_h}{frames_tag}_{out_w}x{out_h}{ext}"
        path, _ = QFileDialog.getSaveFileName(
            self, f"Dove salvo il collage? ({out_w}×{out_h} px)",
            os.path.join(self._export_dir(), name), ";;".join(filters))
        if not path:
            return
        self._remember_export_dir(os.path.dirname(path))

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

    def export_split_frames(self):
        if not self._warn_if_empty():
            return
        folder = QFileDialog.getExistingDirectory(self, "In quale cartella salvo le pagine?", self._export_dir())
        if not folder:
            return
        self._remember_export_dir(folder)

        num_frames = self.scene.num_frames
        ext = self._export_ext()
        file_paths = [os.path.join(folder, f"frame_{i + 1:02d}{ext}") for i in range(num_frames)]
        existing = [p for p in file_paths if os.path.exists(p)]
        if existing:
            answer = QMessageBox.question(
                self, "Sostituire i file?",
                f"Nella cartella ci sono già {len(existing)} file frame_XX{ext}. Vuoi sostituirli?"
            )
            if answer != QMessageBox.StandardButton.Yes:
                return

        scale = self._get_export_scale()
        fw = self.scene.frame_w
        fh = self.scene.frame_h
        out_w = int(fw * scale)
        out_h = int(fh * scale)

        n_photos = self._export_photo_count()
        progress = self._export_progress(n_photos + num_frames)
        saved_files: List[str] = []
        failed: List[str] = []
        canceled = False
        self._begin_export()
        try:
            if not self._prefetch_originals(scale, progress):
                canceled = True
            else:
                for i, file_path in enumerate(file_paths):
                    progress.setValue(n_photos + i)
                    progress.setLabelText(f"Pagina {i + 1} di {num_frames}…")
                    QApplication.processEvents()
                    if progress.wasCanceled():
                        canceled = True
                        break
                    img = self._render_region(QRectF(i * fw, 0, fw, fh), out_w, out_h)
                    if img is not None and self._save_image(img, file_path):
                        saved_files.append(file_path)
                    else:
                        failed.append(os.path.basename(file_path))
        finally:
            progress.setValue(n_photos + num_frames)
            self._end_export()

        if canceled and not saved_files:
            self.statusBar().showMessage("Esportazione annullata", 4000)
            return
        msg = f"{len(saved_files)} pagine esportate ({out_w}×{out_h} px ciascuna) in:\n{folder}"
        if canceled:
            msg += "\n\nEsportazione interrotta: le pagine successive non sono state salvate."
        if failed:
            self._export_done("Esportazione incompleta", msg + "\n\nNon salvate: " + ", ".join(failed), folder, True)
        else:
            self._export_done("Pagine esportate", msg, folder)
