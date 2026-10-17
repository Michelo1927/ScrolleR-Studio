"""Pagine del carosello e anteprima."""
import math
from typing import List

from PyQt6.QtCore import Qt, QRectF
from PyQt6.QtGui import QPixmap, QImage, QPainter
from PyQt6.QtWidgets import QApplication, QMessageBox

from scrollr.dialogs import CarouselPreview


class PagesMixin:
    """Pagine del carosello e anteprima."""

    # ---------- Pagine ----------
    def _page_of(self, it) -> int:
        return int(math.floor(self._element_rect(it).center().x() / self.scene.frame_w))

    def _current_page(self) -> int:
        sel = self._selected_elements()
        x = (self._element_rect(sel[0]).center().x() if sel
             else self.view.mapToScene(self.view.viewport().rect().center()).x())
        return max(0, min(self.scene.num_frames - 1, int(math.floor(x / self.scene.frame_w))))

    def _insert_page_after(self, k: int):
        n = self.scene.num_frames
        if n >= self.spin_frames.maximum():
            self.statusBar().showMessage(f"Massimo {n} pagine", 4000)
            return
        fw = self.scene.frame_w
        for it in self._all_elements():
            if self._page_of(it) > k:
                it.moveBy(fw, 0)
        self._seam_added_frames = None
        self._set_frames_silently(n + 1)
        self.statusBar().showMessage(f"Nuova pagina {k + 2} aggiunta", 3000)
        self._schedule_commit()

    def _delete_page(self, k: int):
        n = self.scene.num_frames
        if n <= 1:
            self.statusBar().showMessage("C'è una sola pagina: non si può eliminare", 4000)
            return
        inside = [it for it in self._all_elements() if self._page_of(it) == k]
        if inside:
            answer = QMessageBox.question(
                self, "Eliminare la pagina?",
                f"La pagina {k + 1} contiene {len(inside)} elementi, che verranno tolti dalla tela.\n"
                "Puoi sempre annullare con Ctrl+Z. Continuare?")
            if answer != QMessageBox.StandardButton.Yes:
                return
        fw = self.scene.frame_w
        for it in inside:
            self.scene.removeItem(it)
        for it in self._all_elements():
            if self._page_of(it) > k:
                it.moveBy(-fw, 0)
        self._seam_added_frames = None
        self._set_frames_silently(n - 1)
        self._update_canvas_count()
        self.statusBar().showMessage(f"Pagina {k + 1} eliminata", 3000)
        self._schedule_commit()

    def _move_page(self, k: int, direction: int):
        j = k + direction
        if not (0 <= k < self.scene.num_frames and 0 <= j < self.scene.num_frames):
            self.statusBar().showMessage("La pagina è già al bordo del carosello", 3000)
            return
        fw = self.scene.frame_w
        for it in self._all_elements():
            page = self._page_of(it)
            if page == k:
                it.moveBy(direction * fw, 0)
            elif page == j:
                it.moveBy(-direction * fw, 0)
        self.statusBar().showMessage(f"Pagina {k + 1} spostata in posizione {j + 1}", 3000)
        self._schedule_commit()

    # ---------- Anteprima carosello ----------
    def _render_page_previews(self, max_side: int = 1200) -> List[QPixmap]:
        fw, fh = self.scene.frame_w, self.scene.frame_h
        scale = max_side / max(fw, fh)
        w, h = max(1, int(fw * scale)), max(1, int(fh * scale))
        pages = []
        self.scene.clean_render = True
        try:
            for i in range(self.scene.num_frames):
                img = QImage(w, h, QImage.Format.Format_ARGB32_Premultiplied)
                img.fill(self.scene.bg_color)
                painter = QPainter(img)
                painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
                painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, True)
                self.scene.render(painter, QRectF(0, 0, w, h), QRectF(i * fw, 0, fw, fh))
                painter.end()
                pages.append(QPixmap.fromImage(img))
        finally:
            self.scene.clean_render = False
            self.scene.update()
        return pages

    def show_carousel_preview(self):
        self._flush_pending_commit()
        QApplication.setOverrideCursor(Qt.CursorShape.WaitCursor)
        try:
            pages = self._render_page_previews()
        finally:
            QApplication.restoreOverrideCursor()
        CarouselPreview(pages, self.scene.frame_w / self.scene.frame_h, self).exec()
