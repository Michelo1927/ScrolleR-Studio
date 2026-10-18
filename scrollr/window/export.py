"""Esportazione del collage ad alta risoluzione."""
import os
from typing import Optional

from PyQt6.QtCore import Qt, QRectF
from PyQt6.QtGui import QImage, QPainter
from PyQt6.QtWidgets import QApplication, QFileDialog, QMessageBox, QProgressDialog

from scrollr.imaging import IMAGE_CACHE


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
        return img.save(path)

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
        path, _ = QFileDialog.getSaveFileName(
            self,
            f"Esporta collage ({out_w}×{out_h} px)",
            f"collage_{self.scene.frame_w}x{self.scene.frame_h}{frames_tag}_{out_w}x{out_h}{ext}",
            ";;".join(filters)
        )
        if not path:
            return

        self._begin_export()
        try:
            img = self._render_region(canvas, out_w, out_h)
            ok = img is not None and self._save_image(img, path)
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

        progress = QProgressDialog("Esportazione pagine…", "Annulla", 0, num_frames, self)
        progress.setWindowTitle("ScrolleR Studio")
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
                if img is not None and self._save_image(img, file_path):
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
