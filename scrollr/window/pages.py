"""Pagine del carosello e anteprima."""
import math
from typing import List, Optional

from PyQt6.QtCore import Qt, QRectF
from PyQt6.QtGui import QPixmap, QImage, QPainter
from PyQt6.QtWidgets import QApplication, QMenu, QMessageBox

from scrollr.canvas.shape_item import ShapeItem
from scrollr.canvas.text_item import TextItem
from scrollr.dialogs import CarouselPreview, PageOrderDialog
from scrollr.icons import make_icon
from scrollr.keys import kb
from scrollr.theme import THEME


class PagesMixin:
    """Pagine del carosello e anteprima."""

    # ---------- Pagine ----------
    def _page_of(self, it) -> int:
        return int(math.floor(self._element_rect(it).center().x() / self.scene.frame_w))

    def _current_page(self) -> int:
        sel = self._selected_elements()
        x = (self._element_rect(sel[0]).center().x() if sel
             else self._visible_center_scene().x())
        return max(0, min(self.scene.num_frames - 1, int(math.floor(x / self.scene.frame_w))))

    def _insert_page_at(self, i: int):
        """Inserisce una pagina vuota in posizione i (0 = all'inizio): le pagine da i in poi scorrono a destra."""
        n = self.scene.num_frames
        if n >= self.spin_frames.maximum():
            self.statusBar().showMessage(f"Massimo {n} pagine", 4000)
            return
        inside = self.scene.joined(i - 1)  # Pagina nuova in mezzo a un gruppo «a cavallo»: ne fa parte
        fw = self.scene.frame_w
        for it in self._all_elements():
            if self._page_of(it) >= i:
                it.moveBy(fw, 0)
        for values in self._page_lists():
            if i < len(values):
                values.insert(i, None)
        if inside:
            seams = self.scene.page_seams
            seams.extend([None] * (i + 1 - len(seams)))
            seams[i] = True
        if self.get_canvas_photos():
            # La pagina nuova resta vuota (copertina, testo…): il prossimo ridisegno non ci sposta foto
            counts = self.scene.page_counts
            counts.extend([None] * (i + 1 - len(counts)))
            counts[i] = 0
        self._seam_added_frames = None
        self._set_frames_silently(n + 1)
        if inside:
            self._relayout_keep()
            self.statusBar().showMessage(f"Nuova pagina {i + 1} aggiunta alle pagine «a cavallo»", 5000)
        else:
            self.statusBar().showMessage(f"Nuova pagina {i + 1} aggiunta, vuota. Per riempirla di foto: "
                                         "clic destro → Foto in questa pagina → Automatico", 6000)
        self._schedule_commit()

    def _insert_page_after(self, k: int):
        self._insert_page_at(k + 1)

    def _duplicate_page(self, k: int):
        """
        Copia la pagina k subito dopo di lei, con foto, testi, forme e impostazioni della pagina.
        Con una disposizione per ogni pagina le foto copiate restano nella disposizione della pagina nuova;
        con la tela continua diventano foto libere, così la copia resta identica.
        """
        n = self.scene.num_frames
        if not (0 <= k < n):
            return
        if n >= self.spin_frames.maximum():
            self.statusBar().showMessage(f"Massimo {n} pagine", 4000)
            return
        self._flush_pending_commit()
        split = self._pages_split()
        current = self._photo_pages() if split else {}
        inside = [it for it in self._all_elements() if self._page_of(it) == k]
        fw = self.scene.frame_w
        # Le pagine dopo k scorrono a destra; le impostazioni della pagina k valgono anche per la copia
        for it in self._all_elements():
            if self._page_of(it) > k:
                it.moveBy(fw, 0)
        for values in self._page_lists():
            if k < len(values):
                values.insert(k + 1, dict(values[k]) if isinstance(values[k], dict) else values[k])
        self._seam_added_frames = None
        self._set_frames_silently(n + 1)

        first_group = self._new_group_id()
        groups = {}
        copies = []
        for it in sorted(inside, key=lambda x: x.zValue()):
            state = it.get_state()
            if isinstance(it, TextItem):
                dup = self._spawn_text_item()
            elif isinstance(it, ShapeItem):
                dup = self._spawn_shape_item(it.kind)
            else:
                dup = self._spawn_photo_item(it.image_path)
                state.update(layout_index=dup.layout_index, free=it.free or not split)
            if it.group:
                state["group"] = groups.setdefault(it.group, first_group + len(groups))
            state.update(uid=dup.uid, z=self._max_z() + 1.0, x=state["x"] + fw)
            dup.set_state(state)
            copies.append(dup)

        if split:
            # Ordine delle foto per pagina, con le copie nella pagina nuova: ogni pagina fissa le sue
            by_page = [[] for _ in range(n + 1)]
            for p in self._layout_photos():
                if p in copies:
                    by_page[k + 1].append(p)
                else:
                    page = current.get(p.uid, n - 1)
                    by_page[page + 1 if page > k else page].append(p)
            counts = self.scene.page_counts
            counts.extend([None] * (n + 1 - len(counts)))
            counts[k] = len(by_page[k])
            counts[k + 1] = len(by_page[k + 1])
            self._trim_page_lists()
            for i, p in enumerate(p for page in by_page for p in page):
                p.layout_index = i
            self._relayout_keep()
        self.scene.clearSelection()
        self._update_canvas_count()
        self.statusBar().showMessage(f"Pagina {k + 1} duplicata: la copia è la pagina {k + 2}", 4000)
        self._schedule_commit()

    # ---------- Numero di pagina e «scorri» ----------
    def _sync_overlay_widgets(self):
        """Pannello Numeri di pagina allineato alla scena (all'avvio, con Annulla e all'apertura)."""
        if not hasattr(self, "chk_page_numbers"):
            return
        sc = self.scene
        widgets = (self.chk_page_numbers, self.combo_pn_format, self.combo_pn_pos, self.chk_swipe,
                   self.edit_swipe_text, self.combo_swipe_pos, self.combo_overlay_style)
        for w in widgets:
            w.blockSignals(True)
        self.chk_page_numbers.setChecked(sc.page_numbers)
        self.chk_swipe.setChecked(sc.swipe_hint)
        if self.edit_swipe_text.text() != sc.swipe_text:
            self.edit_swipe_text.setText(sc.swipe_text)
        for combo, value in ((self.combo_pn_format, sc.page_number_format), (self.combo_pn_pos, sc.page_number_pos),
                             (self.combo_swipe_pos, sc.swipe_pos), (self.combo_overlay_style, sc.overlay_style)):
            combo.setCurrentIndex(max(0, combo.findData(value)))
        for w in widgets:
            w.blockSignals(False)
        for w in (self.chk_page_numbers, self.chk_swipe):
            w.update()
        self._update_overlay_enabled()

    def _update_overlay_enabled(self):
        self.combo_pn_format.setEnabled(self.scene.page_numbers)
        self.combo_pn_pos.setEnabled(self.scene.page_numbers)
        self.edit_swipe_text.setEnabled(self.scene.swipe_hint)
        self.combo_swipe_pos.setEnabled(self.scene.swipe_hint)
        self.combo_overlay_style.setEnabled(self.scene.page_numbers or self.scene.swipe_hint)

    def _on_overlay_changed(self, *_):
        sc = self.scene
        sc.page_numbers = self.chk_page_numbers.isChecked()
        sc.page_number_format = self.combo_pn_format.currentData()
        sc.page_number_pos = self.combo_pn_pos.currentData()
        sc.swipe_hint = self.chk_swipe.isChecked()
        sc.swipe_text = self.edit_swipe_text.text()
        sc.swipe_pos = self.combo_swipe_pos.currentData()
        sc.overlay_style = self.combo_overlay_style.currentData()
        self._update_overlay_enabled()
        if sc.page_numbers and sc.num_frames < 2:
            self.statusBar().showMessage("Il numero compare quando il carosello ha almeno 2 pagine", 4000)
        sc.update()
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
                kb(f"La pagina {k + 1} contiene {len(inside)} elementi, che verranno tolti dalla tela.\n"
                   "Puoi sempre annullare con Ctrl+Z. Continuare?"))
            if answer != QMessageBox.StandardButton.Yes:
                return
        fw = self.scene.frame_w
        for it in inside:
            self.scene.removeItem(it)
        for it in self._all_elements():
            if self._page_of(it) > k:
                it.moveBy(-fw, 0)
        # La pagina prima resta unita a quella dopo solo se k stava in mezzo a un gruppo «a cavallo»
        seams = self.scene.page_seams
        if 0 < k <= len(seams):
            seams[k - 1] = True if self.scene.joined(k - 1) and self.scene.joined(k) else None
        for values in self._page_lists():
            if k < len(values):
                del values[k]
        self._trim_page_lists()
        self._seam_added_frames = None
        self._set_frames_silently(n - 1)
        self._update_canvas_count()
        self.statusBar().showMessage(f"Pagina {k + 1} eliminata", 3000)
        self._schedule_commit()

    def _move_page(self, k: int, direction: int):
        """Sposta la pagina k di un posto; una pagina «a cavallo» si sposta con tutto il suo gruppo."""
        groups = self.scene.seam_groups()
        g = next((i for i, (a, b) in enumerate(groups) if a <= k <= b), None)
        h = None if g is None else g + direction
        if h is None or not (0 <= h < len(groups)):
            self.statusBar().showMessage("La pagina è già al bordo del carosello", 3000)
            return
        groups[g], groups[h] = groups[h], groups[g]
        order = [p for a, b in groups for p in range(a, b + 1)]
        self._reorder_pages(order)
        a, b = groups[h]
        j = order.index(a)
        if a == b:
            self.statusBar().showMessage(f"Pagina {k + 1} spostata in posizione {j + 1}", 3000)
        else:
            self.statusBar().showMessage(f"Pagine «a cavallo» {a + 1}–{b + 1} spostate nelle posizioni "
                                         f"{j + 1}–{j + b - a + 1}", 4000)

    def _reorder_pages(self, order: List[int]):
        """
        Nuovo ordine delle pagine: order[nuova posizione] = vecchia posizione. Ogni pagina si porta
        dietro foto, testi, disposizione e numero di foto.
        """
        n = self.scene.num_frames
        if sorted(order) != list(range(n)) or order == list(range(n)):
            return
        new_pos = {old: new for new, old in enumerate(order)}
        joined = [self.scene.joined(k) for k in range(n)]
        fw = self.scene.frame_w
        pages = [(it, self._page_of(it)) for it in self._all_elements()]
        for it, page in pages:
            if 0 <= page < n:  # Gli elementi fuori dalla tela restano dove sono
                it.moveBy((new_pos[page] - page) * fw, 0)
        for values in self._page_lists():
            padded = values + [None] * (n - len(values))
            values[:] = [padded[old] for old in order]
        # Due pagine restano «a cavallo» solo se restano vicine e nello stesso ordine
        self.scene.page_seams[:] = [True if joined[order[j]] and order[j + 1] == order[j] + 1 else None
                                    for j in range(n - 1)]
        self._trim_page_lists()
        # L'ordine delle foto segue le pagine: un nuovo ridisegno non le rimette dov'erano
        photos = sorted(self.get_canvas_photos(), key=lambda p: (self._page_of(p), p.layout_index, p.uid))
        for i, p in enumerate(photos):
            p.layout_index = i
        self.scene.update()
        self._schedule_commit()

    def reorder_pages_dialog(self):
        """Pagine → Riordina le pagine: miniature da trascinare nell'ordine voluto."""
        if self.scene.num_frames < 2:
            self.statusBar().showMessage("C'è una sola pagina: non c'è niente da riordinare", 4000)
            return
        self._flush_pending_commit()
        QApplication.setOverrideCursor(Qt.CursorShape.WaitCursor)
        try:
            thumbs = self._render_page_previews(max_side=260)
        finally:
            QApplication.restoreOverrideCursor()
        dialog = PageOrderDialog(thumbs, [self.scene.page_label(i) for i in range(self.scene.num_frames)], self)
        if dialog.exec():
            order = dialog.order()
            if order != list(range(self.scene.num_frames)):
                self._reorder_pages(order)
                self.statusBar().showMessage("Pagine riordinate", 3000)

    # ---------- Impostazioni pagina per pagina (numero di foto, disposizione) ----------
    def _page_lists(self) -> list:
        """Elenchi con un valore per pagina (None = come le altre), da tenere allineati alle pagine."""
        return [self.scene.page_counts, self.scene.page_layouts, self.scene.page_seams]

    def _trim_page_lists(self):
        for values in self._page_lists():
            while values and values[-1] is None:
                values.pop()

    def _apply_page_setting(self):
        """Dopo una scelta su una singola pagina: ridispone, accendendo la divisione per pagina se serve."""
        if self.current_layout_mode == "scrl_seam":
            self.statusBar().showMessage("Con «A cavallo» le scelte per singola pagina non valgono: "
                                         "scegli un'altra disposizione nel pannello", 6000)
        elif not self.chk_per_frame.isChecked():
            self.chk_per_frame.setChecked(True)  # Senza, le foto non si dividono per pagina
        else:
            self._relayout_keep()
        self.scene.update()
        self._schedule_commit()

    def _set_page_joined(self, k: int, on: bool):
        """Unisce (o separa) «a cavallo» la pagina k e la successiva, e ridispone."""
        if not (0 <= k < self.scene.num_frames - 1):
            return
        seams = self.scene.page_seams
        seams.extend([None] * (k + 1 - len(seams)))
        seams[k] = True if on else None
        self._trim_page_lists()
        self._apply_page_setting()
        if self.current_layout_mode != "scrl_seam":
            if on:
                a, b = next(g for g in self.scene.seam_groups() if g[0] <= k <= g[1])
                self.statusBar().showMessage(f"Pagine {a + 1}–{b + 1} unite «a cavallo»: le foto attraversano "
                                             "le loro giunzioni", 5000)
            else:
                self.statusBar().showMessage(f"Pagine {k + 1} e {k + 2} separate", 4000)

    def _toggle_page_joined(self, k: int):
        if k >= self.scene.num_frames - 1:
            self.statusBar().showMessage("È l'ultima pagina: non c'è una pagina dopo da unire", 4000)
            return
        self._set_page_joined(k, not self.scene.joined(k))

    def _fill_page_join_actions(self, menu: QMenu, k: int):
        """Voci "A cavallo con la pagina precedente / successiva" per la pagina k."""
        n = self.scene.num_frames
        for j, text in ((k - 1, "A cavallo con la pagina precedente"), (k, "A cavallo con la pagina successiva")):
            act = menu.addAction(text)
            act.setCheckable(True)
            act.setChecked(self.scene.joined(j))
            act.setEnabled(0 <= j < n - 1)
            act.setToolTip("Le foto di queste pagine si dispongono a righe continue che attraversano la giunzione")
            act.triggered.connect(lambda on, jj=j: self._set_page_joined(jj, on))
        menu.setToolTipsVisible(True)

    def _set_page_layout(self, k: int, mode: Optional[str], style: Optional[str] = None):
        """Disposizione propria della pagina k (None = come le altre) e ridispone."""
        layouts = self.scene.page_layouts
        layouts.extend([None] * (k + 1 - len(layouts)))
        layouts[k] = {"mode": mode, "style": style} if mode else None
        self._trim_page_lists()
        self._apply_page_setting()

    def _fill_page_layout_menu(self, menu: QMenu, k: int):
        """Voci "Come le altre / Griglia / Mosaico (con gli stili) / …" per la pagina k."""
        current = self.scene.page_layouts[k] if k < len(self.scene.page_layouts) else None
        names = dict((m, t) for m, t, _ in self.LAYOUTS)
        if self.scene.joined(k - 1) or self.scene.joined(k):
            note = menu.addAction("(Pagina «a cavallo»: vale quando la separi)")
            note.setEnabled(False)
        same = menu.addAction(f"Come le altre ({names.get(self.current_layout_mode, '')})")
        same.setCheckable(True)
        same.setChecked(current is None)
        same.triggered.connect(lambda: self._set_page_layout(k, None))
        menu.addSeparator()
        for mode, text, tip in self.LAYOUTS:
            if mode == "scrl_seam":
                continue  # Attraversa le pagine: vale solo per tutta la tela
            icon = make_icon(mode, THEME["text"], 16)
            if mode == "mosaic":
                sub = menu.addMenu(icon, text)
                for style, style_text, style_tip in self.MOSAIC_STYLES:
                    act = sub.addAction(make_icon("mosaic_" + style, THEME["text"], 16), style_text)
                    act.setToolTip(style_tip)
                    act.setCheckable(True)
                    act.setChecked(bool(current) and current["mode"] == "mosaic"
                                   and (current.get("style") or "auto") == style)
                    act.triggered.connect(lambda _c=False, s=style: self._set_page_layout(k, "mosaic", s))
                sub.setToolTipsVisible(True)
                continue
            act = menu.addAction(icon, text)
            act.setToolTip(tip)
            act.setCheckable(True)
            act.setChecked(bool(current) and current["mode"] == mode)
            act.triggered.connect(lambda _c=False, m=mode: self._set_page_layout(k, m))
        menu.setToolTipsVisible(True)

    def _rebuild_current_page_layout_menu(self):
        self.menu_page_layout.clear()
        self._fill_page_layout_menu(self.menu_page_layout, self._current_page())

    def _set_page_count(self, k: int, value: Optional[int]):
        """Fissa quante foto vanno nella pagina k (None = automatico) e ridispone."""
        counts = self.scene.page_counts
        counts.extend([None] * (k + 1 - len(counts)))
        counts[k] = value
        self._trim_page_lists()
        self._apply_page_setting()

    def _fill_page_count_menu(self, menu: QMenu, k: int):
        """Voci "Automatico / Nessuna / 1…12" per scegliere quante foto vanno nella pagina k."""
        current = self.scene.page_counts[k] if k < len(self.scene.page_counts) else None
        per_page = self.spin_per_page.value()
        auto = menu.addAction(f"Automatico ({per_page} per pagina)" if per_page else "Automatico (parti uguali)")
        auto.setCheckable(True)
        auto.setChecked(current is None)
        auto.triggered.connect(lambda: self._set_page_count(k, None))
        menu.addSeparator()
        for v in range(0, 13):
            act = menu.addAction("Nessuna foto" if v == 0 else ("1 foto" if v == 1 else f"{v} foto"))
            act.setCheckable(True)
            act.setChecked(current == v)
            act.triggered.connect(lambda _c=False, val=v: self._set_page_count(k, val))

    def _rebuild_current_page_count_menu(self):
        self.menu_page_count.clear()
        self._fill_page_count_menu(self.menu_page_count, self._current_page())

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
