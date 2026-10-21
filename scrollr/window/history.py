"""Annulla/Ripeti tramite snapshot dello stato completo, con il pannello Cronologia."""
import os
from typing import Optional

from PyQt6.QtCore import Qt
from PyQt6.QtGui import QColor, QFont
from PyQt6.QtWidgets import QDialog, QHBoxLayout, QLabel, QListWidget, QListWidgetItem, QPushButton, QVBoxLayout

from scrollr.icons import make_icon
from scrollr.keys import kb
from scrollr.theme import THEME

# Nome, genere (per l'accordo: spostata/spostato) e plurale degli elementi della tela
_KINDS = {"items": ("Foto", "f", "foto"), "texts": ("Testo", "m", "testi"), "shapes": ("Forma", "f", "forme")}


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
                "page_numbers": self.scene.page_numbers,
                "page_number_format": self.scene.page_number_format,
                "page_number_pos": self.scene.page_number_pos,
                "overlay_style": self.scene.overlay_style,
                "swipe_hint": self.scene.swipe_hint,
                "swipe_text": self.scene.swipe_text,
                "swipe_pos": self.scene.swipe_pos,
                "export_name": self.export_name,
            },
            "items": [p.get_state() for p in self.get_canvas_photos()],
            "texts": [t.get_state() for t in self.get_canvas_texts()],
            "shapes": [sh.get_state() for sh in self.get_canvas_shapes()],
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
            self.scene.page_numbers = c.get("page_numbers", False)
            self.scene.page_number_format = c.get("page_number_format", "slash")
            self.scene.page_number_pos = c.get("page_number_pos", "bc")
            self.scene.overlay_style = c.get("overlay_style", "dark")
            self.scene.swipe_hint = c.get("swipe_hint", False)
            self.scene.swipe_text = c.get("swipe_text", "Scorri →")
            self.scene.swipe_pos = c.get("swipe_pos", "br")
            self.export_name = c.get("export_name", "")
            self._sync_overlay_widgets()
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
            existing_shapes = {sh.uid: sh for sh in self.get_canvas_shapes()}
            wanted_shapes = set()
            for ss in snap.get("shapes", []):
                wanted_shapes.add(ss["uid"])
                sh = existing_shapes.get(ss["uid"]) or self._spawn_shape_item(ss.get("kind", "rect"), uid=ss["uid"])
                sh.set_state(ss)
            for uid, sh in existing_shapes.items():
                if uid not in wanted_shapes:
                    self.scene.removeItem(sh)
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
        if self._history:
            label = self._describe_change(self._history[self._history_index], snap)
        else:
            label = self._history_start_label
        del self._history[self._history_index + 1:]
        del self._history_labels[self._history_index + 1:]
        self._history.append(snap)
        self._history_labels.append(label)
        if len(self._history) > self.HISTORY_LIMIT:
            self._history.pop(0)
            self._history_labels.pop(0)
        self._history_index = len(self._history) - 1
        self._update_undo_actions()
        self._update_title()
        self._update_canvas_count()
        self._refresh_history_panel()

    def _reset_history(self, label: str):
        """Cronologia nuova (progetto aperto o nuovo): il primo passaggio è lo stato attuale."""
        self._history = []
        self._history_labels = []
        self._history_index = -1
        self._history_start_label = label
        self._commit_history()

    def _flush_pending_commit(self):
        if self._commit_timer.isActive():
            self._commit_history()

    def undo(self):
        self._flush_pending_commit()
        if self._history_index > 0:
            self._go_to_history(self._history_index - 1)

    def redo(self):
        self._flush_pending_commit()
        if self._history_index < len(self._history) - 1:
            self._go_to_history(self._history_index + 1)

    def _go_to_history(self, index: int):
        """Torna (o va avanti) a un passaggio qualsiasi della cronologia, anche di molti passi."""
        self._flush_pending_commit()
        if not (0 <= index < len(self._history)) or index == self._history_index:
            return
        self._history_index = index
        self._restore_snapshot(self._history[index])
        self._update_undo_actions()
        self._update_title()
        self._update_canvas_count()
        self._refresh_history_panel()

    # ---------- Descrizione dei passaggi ----------
    @staticmethod
    def _agree(gender: str, word: str) -> str:
        """Participio accordato: «spostat» → spostata (Foto, Forma) o spostato (Testo)."""
        return word + ("a" if gender == "f" else "o")

    def _describe_change(self, a: dict, b: dict) -> str:
        """Nome breve della modifica tra due stati, per il pannello Cronologia."""
        ca, cb = a["canvas"], b["canvas"]
        added, removed, changed = [], [], []
        for key in _KINDS:
            before = {s["uid"]: s for s in a.get(key, [])}
            after = {s["uid"]: s for s in b.get(key, [])}
            added += [key] * len(after.keys() - before.keys())
            removed += [key] * len(before.keys() - after.keys())
            for uid in before.keys() & after.keys():
                diff = {k for k in set(before[uid]) | set(after[uid]) if before[uid].get(k) != after[uid].get(k)}
                if diff:
                    changed.append((key, diff, after[uid]))

        fa, fb = ca["num_frames"], cb["num_frames"]
        if fb == fa + 1:
            return "Pagina duplicata" if added else "Pagina aggiunta"
        if fb == fa - 1:
            return "Pagina eliminata"

        def count_label(kinds, verb: str) -> str:
            if len(set(kinds)) > 1:
                return f"{len(kinds)} elementi {verb}i"
            name, gender, plural = _KINDS[kinds[0]]
            if len(kinds) == 1:
                return f"{name} {self._agree(gender, verb)}"
            return f"{len(kinds)} {plural} {verb}" + ("e" if gender == "f" else "i")

        if added and removed:
            return "Foto sostituite" if set(added) == set(removed) == {"items"} else "Elementi cambiati"
        if added:
            return count_label(added, "aggiunt")
        if removed:
            return count_label(removed, "eliminat")

        if fb != fa:
            return f"Pagine: {fa} → {fb}"
        canvas_diff = {k for k in set(ca) | set(cb) if ca.get(k) != cb.get(k)}
        canvas_names = [
            ({"ratio_index", "frame_w", "frame_h", "custom_w", "custom_h"}, "Formato della pagina"),
            ({"layout_mode"}, f"Disposizione: {self.scene.layout_names.get(cb['layout_mode'], cb['layout_mode'])}"),
            ({"mosaic_style"}, "Stile mosaico"),
            ({"layout_seed"}, "Foto rimescolate"),
            ({"page_layouts"}, "Disposizione della pagina"),
            ({"per_frame", "per_page", "page_counts"}, "Foto per pagina"),
            ({"gap"}, "Spaziatura"),
            ({"margin"}, "Margine"),
            ({"bg_color", "bg_mode", "bg_color2", "bg_direction", "bg_blur_path", "bg_blur_amount", "bg_dim"}, "Sfondo"),
            ({"page_numbers", "page_number_format", "page_number_pos", "overlay_style"}, "Numeri di pagina"),
            ({"swipe_hint", "swipe_text", "swipe_pos"}, "Indicatore «scorri»"),
            ({"export_name"}, "Nome dei file"),
        ]
        for keys, name in canvas_names:
            if canvas_diff & keys:
                return name

        if not changed:
            return "Modifica"
        all_keys = set().union(*(d for _, d, _ in changed))
        if all_keys == {"group"}:
            return "Elementi raggruppati" if all(s.get("group") for _, _, s in changed) else "Gruppo separato"
        if all_keys <= {"layout_index"}:
            return "Ordine delle foto"
        if all_keys <= {"z"}:
            return "Livello cambiato"
        if all_keys <= {"locked"}:
            return "Blocco della posizione"
        moved = all_keys <= {"x", "y"}
        if len(changed) > 1:
            if moved:
                return f"{len(changed)} elementi spostati"
            if all_keys & {"w", "h"} and all_keys <= {"x", "y", "w", "h", "rotation", "layout_index"}:
                return "Disposizione aggiornata"
            return f"{len(changed)} elementi modificati"
        key, diff, _ = changed[0]
        name, gender, _ = _KINDS[key]
        if moved:
            return f"{name} {self._agree(gender, 'spostat')}"
        if diff <= {"x", "y", "w", "h"}:
            return f"{name} {self._agree(gender, 'ridimensionat')}"
        if diff <= {"x", "y", "rotation"}:
            return f"{name} {self._agree(gender, 'ruotat')}"
        if diff & {"text"}:
            return "Testo modificato"
        if diff & {"adjust"}:
            return "Colori della foto"
        if diff <= {"inner_zoom", "pan_x", "pan_y", "inner_rotation"}:
            return "Inquadratura della foto"
        if diff & {"free"}:
            return "Foto libera" if any(s.get("free") for s in b.get("items", [])) else "Foto nella disposizione"
        return {"items": "Stile della foto", "texts": "Stile del testo", "shapes": "Stile della forma"}[key]

    # ---------- Pannello Cronologia ----------
    def show_history_panel(self):
        """Finestrella con l'elenco delle modifiche: un clic su un passaggio ci torna."""
        if self._history_panel is None:
            dlg = QDialog(self, Qt.WindowType.Tool)
            dlg.setWindowTitle("Cronologia")
            dlg.resize(280, 420)
            lay = QVBoxLayout(dlg)
            lay.setContentsMargins(12, 12, 12, 10)
            lay.setSpacing(8)
            hint = QLabel("Clicca un passaggio per tornarci. I passaggi dopo restano in grigio: "
                          "puoi ancora tornare avanti finché non fai una modifica nuova.")
            hint.setObjectName("Hint")
            hint.setWordWrap(True)
            lay.addWidget(hint)
            self._history_list = QListWidget()
            self._history_list.itemClicked.connect(
                lambda it: self._go_to_history(it.data(Qt.ItemDataRole.UserRole)))
            lay.addWidget(self._history_list, 1)
            row = QHBoxLayout()
            for text, icon, tip, slot in (("Annulla", "rot_left", kb("Un passo indietro (Ctrl+Z)"), self.undo),
                                          ("Ripeti", "rot_right", kb("Un passo avanti (Ctrl+Y)"), self.redo)):
                b = QPushButton(text)
                b.setIcon(make_icon(icon, THEME["text"], 16))
                b.setToolTip(tip)
                b.clicked.connect(slot)
                row.addWidget(b)
            lay.addLayout(row)
            self._history_panel = dlg
            self._refresh_history_panel()
        self._history_panel.show()
        self._history_panel.raise_()
        self._history_panel.activateWindow()

    def _refresh_history_panel(self):
        panel: Optional[QDialog] = getattr(self, "_history_panel", None)
        if panel is None:
            return
        lst = self._history_list
        lst.clear()
        muted = QColor(THEME["muted"])
        for i, label in enumerate(self._history_labels):
            item = QListWidgetItem(label)
            item.setData(Qt.ItemDataRole.UserRole, i)
            if i > self._history_index:
                item.setForeground(muted)
                font = QFont(lst.font())
                font.setItalic(True)
                item.setFont(font)
            lst.addItem(item)
        if 0 <= self._history_index < lst.count():
            lst.setCurrentRow(self._history_index)
            lst.scrollToItem(lst.currentItem())

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
