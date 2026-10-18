"""Annulla/Ripeti tramite snapshot dello stato completo."""
import os

from PyQt6.QtGui import QColor


class HistoryMixin:
    """Annulla/Ripeti tramite snapshot dello stato completo."""

    # ================= ANNULLA / RIPETI =================
    def _snapshot(self) -> dict:
        return {
            "canvas": {
                "ratio_index": self.combo_ratio.currentIndex(),
                "custom_w": self.spin_custom_w.value(),
                "custom_h": self.spin_custom_h.value(),
                "frame_w": self.scene.frame_w,
                "frame_h": self.scene.frame_h,
                "num_frames": self.scene.num_frames,
                "bg_color": self.scene.bg_color.name(QColor.NameFormat.HexArgb),
                "gap": self.slider_gap.value(),
                "margin": self.slider_margin.value(),
                "per_frame": self.chk_per_frame.isChecked(),
                "per_page": self.spin_per_page.value(),
                "page_counts": list(self.scene.page_counts),
                "page_layouts": [dict(x) if x else None for x in self.scene.page_layouts],
                "layout_mode": self.current_layout_mode,
                "mosaic_style": self.mosaic_style,
                "layout_seed": self._layout_seed,
                "bg_mode": self.scene.bg_mode,
                "bg_color2": self.scene.bg_color2.name(QColor.NameFormat.HexArgb),
                "bg_direction": self.scene.bg_direction,
                "bg_blur_path": self.scene.bg_blur_path,
                "bg_blur_amount": self.scene.bg_blur_amount,
                "bg_dim": self.scene.bg_dim,
            },
            "items": [p.get_state() for p in self.get_canvas_photos()],
            "texts": [t.get_state() for t in self.get_canvas_texts()],
        }

    def _restore_snapshot(self, snap: dict):
        self._restoring = True
        self._seam_added_frames = None
        try:
            c = snap["canvas"]
            widgets = (self.combo_ratio, self.spin_custom_w, self.spin_custom_h,
                       self.spin_frames, self.slider_gap, self.slider_margin, self.chk_per_frame,
                       self.spin_per_page)
            for w in widgets:
                w.blockSignals(True)
            self.combo_ratio.setCurrentIndex(c["ratio_index"])
            self.spin_custom_w.setValue(c["custom_w"])
            self.spin_custom_h.setValue(c["custom_h"])
            self.spin_frames.setValue(c["num_frames"])
            self.slider_gap.setValue(c["gap"])
            self.slider_margin.setValue(c["margin"])
            self.chk_per_frame.setChecked(c["per_frame"])
            self.spin_per_page.setValue(c.get("per_page", 0))
            for w in widgets:
                w.blockSignals(False)
            self.chk_per_frame.update()
            self.per_page_box.setEnabled(c["per_frame"])
            self.custom_size_box.setVisible(self.ASPECT_RATIOS.get(self.combo_ratio.currentText()) is None)

            canvas_changed = (self.scene.frame_w, self.scene.frame_h, self.scene.num_frames) != \
                (c["frame_w"], c["frame_h"], c["num_frames"])
            self.scene.frame_w, self.scene.frame_h = c["frame_w"], c["frame_h"]
            self.scene.num_frames = c["num_frames"]
            self.scene.page_counts = list(c.get("page_counts", []))
            self.scene.page_layouts = [dict(x) if x else None for x in c.get("page_layouts", [])]
            self.scene.bg_color = QColor(c["bg_color"])
            self.scene.bg_mode = c.get("bg_mode", "solid")
            self.scene.bg_color2 = QColor(c.get("bg_color2", "#FF2680EB"))
            self.scene.bg_direction = c.get("bg_direction", "vertical")
            self.scene.bg_blur_path = c.get("bg_blur_path", "")
            self.scene.bg_blur_amount = c.get("bg_blur_amount", 50)
            self.scene.bg_dim = c.get("bg_dim", 15)
            self._refresh_bg_swatches()
            self.scene.update_canvas_rect()
            self.current_layout_mode = c["layout_mode"]
            self.mosaic_style = c.get("mosaic_style", "auto")
            self._layout_seed = c["layout_seed"]
            self._sync_layout_tiles()

            existing = {p.uid: p for p in self.get_canvas_photos()}
            wanted = set()
            for s in snap["items"]:
                # Anche le foto non trovate restano, come segnaposto «Foto mancante»
                wanted.add(s["uid"])
                item = existing.get(s["uid"]) or self._spawn_photo_item(s["path"], uid=s["uid"])
                item.set_state(s)
            for uid, item in existing.items():
                if uid not in wanted:
                    self.scene.removeItem(item)
            existing_texts = {t.uid: t for t in self.get_canvas_texts()}
            wanted_texts = set()
            for st in snap.get("texts", []):
                wanted_texts.add(st["uid"])
                t = existing_texts.get(st["uid"]) or self._spawn_text_item(uid=st["uid"])
                t.set_state(st)
            for uid, t in existing_texts.items():
                if uid not in wanted_texts:
                    self.scene.removeItem(t)
            self.scene.update()
            if canvas_changed:
                self.fit_canvas_in_view()
        finally:
            self._restoring = False
        self._refresh_slider_labels()
        self._sync_inspector_from_item(self._get_primary_selected())

    def _refresh_slider_labels(self):
        # Ri-emette il valore per aggiornare le etichette (i relayout sono bloccati da _restoring)
        self._restoring = True
        try:
            for s in (self.slider_gap, self.slider_margin):
                s.valueChanged.emit(s.value())
        finally:
            self._restoring = False

    def _schedule_commit(self):
        if not self._restoring:
            self._commit_timer.start()

    def _commit_history(self):
        self._commit_timer.stop()
        snap = self._snapshot()
        if self._history and self._history[self._history_index] == snap:
            return
        del self._history[self._history_index + 1:]
        self._history.append(snap)
        if len(self._history) > self.HISTORY_LIMIT:
            self._history.pop(0)
        self._history_index = len(self._history) - 1
        self._update_undo_actions()
        self._update_title()
        self._update_canvas_count()

    def _flush_pending_commit(self):
        if self._commit_timer.isActive():
            self._commit_history()

    def undo(self):
        self._flush_pending_commit()
        if self._history_index > 0:
            self._history_index -= 1
            self._restore_snapshot(self._history[self._history_index])
            self._update_undo_actions()
            self._update_title()

    def redo(self):
        self._flush_pending_commit()
        if self._history_index < len(self._history) - 1:
            self._history_index += 1
            self._restore_snapshot(self._history[self._history_index])
            self._update_undo_actions()
            self._update_title()

    def _update_undo_actions(self):
        if hasattr(self, "act_undo"):
            self.act_undo.setEnabled(self._history_index > 0)
            self.act_redo.setEnabled(self._history_index < len(self._history) - 1)

    def _is_dirty(self) -> bool:
        if not self._history:
            return False
        return self._history[self._history_index] != self._saved_snapshot

    def _update_title(self):
        name = os.path.basename(self.project_path) if self.project_path else "Senza titolo"
        star = " •" if self._is_dirty() else ""
        self.setWindowTitle(f"{name}{star} — ScrolleR Studio")
        self._update_doc_tab()
