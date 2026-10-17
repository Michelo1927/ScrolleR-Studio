"""Inspector e modifica degli elementi selezionati."""
import math
import os
from typing import Optional

from PyQt6.QtCore import Qt, QRectF
from PyQt6.QtGui import QColor, QFont
from PyQt6.QtWidgets import QColorDialog, QMenu

from scrollr.canvas.photo_item import PhotoItem
from scrollr.canvas.text_item import TextItem
from scrollr.icons import make_icon, rounded_thumb, swatch_icon
from scrollr.imaging import NEUTRAL_ADJUST
from scrollr.keys import kb
from scrollr.theme import THEME


class InspectorMixin:
    """Inspector e modifica degli elementi selezionati."""

    # ================= INSPECTOR & CONTROLLI FOTO SINGOLA =================
    def _get_primary_selected(self) -> Optional[PhotoItem]:
        selected = self._selected_photos()
        return selected[0] if selected else None

    def _on_selection_changed(self):
        self._sync_inspector_from_item(self._get_primary_selected())

    def _on_item_geometry_changed(self, item: PhotoItem):
        if item is self._get_primary_selected():
            self._sync_inspector_from_item(item)

    def _sync_inspector_from_item(self, item: Optional[PhotoItem]):
        self._updating_inspector = True
        count = len(self._selected_photos())
        texts = self._selected_texts()
        if item is None and texts:
            self.insp_stack.setCurrentIndex(2)
            self._sync_text_inspector(texts[0], len(texts))
            self.lbl_hint.setText("Trascina il testo per spostarlo.   Doppio clic: modifica il testo.   "
                                  "Frecce: sposta di 1 px (Shift: 10 px).")
        else:
            self.insp_stack.setCurrentIndex(0 if item is None else 1)
        if item is None and not texts:
            self.lbl_hint.setText("Clicca una foto per selezionarla.   Rotella: zoom della vista.   "
                                  "Tasto centrale + trascina: sposta la vista.")
        elif item is not None:
            self.lbl_selection_thumb.setPixmap(rounded_thumb(item.display_pixmap(), 40, 2))
            if count > 1:
                self.lbl_selection_name.setText(f"{count} foto selezionate")
                self.lbl_selection_info.setText("Le modifiche valgono per tutte")
            else:
                self.lbl_selection_name.setText(self.fontMetrics().elidedText(
                    os.path.basename(item.image_path), Qt.TextElideMode.ElideMiddle, 190))
                info = f"Riquadro {int(item.cell_w)} × {int(item.cell_h)} px"
                self.lbl_selection_info.setText(info + ("  ·  bloccata" if item.locked else ""))
            self.lbl_hint.setText(kb("Alt + trascina: sposta l'inquadratura.   Ctrl + rotella: zoom nella foto.   "
                                     "Shift sulle maniglie: mantieni le proporzioni."))
            self.btn_border_color.setIcon(swatch_icon(item.border_color))
            self.btn_fit_cover.setChecked(item.fit_mode != "contain")
            self.btn_fit_contain.setChecked(item.fit_mode == "contain")
            self.slider_inner_zoom.setValue(round(item.inner_zoom * 100))
            self.slider_pan_x.setValue(round(item.pan_x * 100))
            self.slider_pan_y.setValue(round(item.pan_y * 100))
            self.slider_inner_rot.setValue(round(item.inner_rotation))
            self.slider_rotation.setValue(round(item.rotation()))
            self.slider_radius.setValue(round(item.border_radius))
            self.slider_border.setValue(round(item.border_width))
            for key, slider in self.adjust_sliders.items():
                slider.setValue(int(item.adjust.get(key, 0)))
            self.chk_bw.setChecked(bool(item.adjust.get("bw")))
            self.slider_opacity.setValue(item.photo_opacity)
            self.slider_shadow.setValue(item.shadow)
            self.btn_paste_style.setEnabled(self._style_clipboard is not None)
            self._update_ratio_button()
        primary = item if item is not None else (texts[0] if texts else None)
        if primary is not None:
            for sw in self._lock_switches:
                sw.setChecked(primary.locked)
        self._update_align_ui()
        self._update_canvas_count()
        self._updating_inspector = False

    def _sync_text_inspector(self, t: TextItem, count: int):
        self.lbl_text_title.setText("Testo" if count == 1 else f"{count} testi selezionati")
        if self.edit_text.toPlainText() != t.text:
            self.edit_text.setPlainText(t.text)
        self.combo_font.setCurrentFont(QFont(t.font_family))
        self.slider_text_size.setValue(round(t.font_size))
        self.btn_text_bold.setChecked(t.bold)
        self.btn_text_italic.setChecked(t.italic)
        self.text_align_buttons.get(t.align, self.text_align_buttons["center"]).setChecked(True)
        self.btn_text_color.setIcon(swatch_icon(t.color))
        self.btn_box_color.setIcon(swatch_icon(t.box_color))
        self.btn_box_color.setEnabled(t.box)
        self.chk_text_shadow.setChecked(t.shadow)
        self.chk_text_box.setChecked(t.box)
        self.slider_text_opacity.setValue(t.text_opacity)

    def _update_align_ui(self):
        n = len(self._selected_elements())
        text = ("Allinea alla pagina in cui si trova." if n <= 1
                else f"Allinea i {n} elementi selezionati tra loro.")
        for hint in self._align_hints:
            hint.setText(text)
        for b in self._distribute_buttons:
            b.setEnabled(n >= 3)

    def _on_inspector_slider(self, prop: str, value: int):
        if self._updating_inspector:
            return
        for item in self._selected_photos():
            if prop == "zoom":
                item.inner_zoom = value / 100.0
            elif prop == "pan_x":
                item.pan_x = value / 100.0
            elif prop == "pan_y":
                item.pan_y = value / 100.0
            elif prop == "inner_rotation":
                item.inner_rotation = float(value)
            elif prop == "rotation":
                item.setRotation(float(value))
            elif prop == "radius":
                item.border_radius = float(value)
            elif prop == "border":
                item.border_width = float(value)
                item.auto_border = False
            elif prop in ("brightness", "contrast", "saturation", "warmth"):
                item.adjust[prop] = int(value)
            elif prop == "opacity":
                item.set_photo_opacity(value)
            elif prop == "shadow":
                item.set_shadow(value)
            item.update()
        if prop in ("brightness", "contrast", "saturation", "warmth"):
            self._refresh_selection_thumb()
        self._schedule_commit()

    def _refresh_selection_thumb(self):
        item = self._get_primary_selected()
        if item is not None:
            self.lbl_selection_thumb.setPixmap(rounded_thumb(item.display_pixmap(), 40, 2))

    # ---------- Foto: riempimento, specchio, colori, stile ----------
    def _set_fit_mode(self, mode: str):
        if self._updating_inspector:
            return
        for item in self._selected_photos():
            item.fit_mode = mode
            item.pan_x = item.pan_y = 0.0
            item.update()
        self._sync_inspector_from_item(self._get_primary_selected())
        self._schedule_commit()

    def _flip_selected(self, axis: str):
        selected = self._selected_photos()
        for item in selected:
            if axis == "h":
                item.flip_h = not item.flip_h
            else:
                item.flip_v = not item.flip_v
            item.update()
        if selected:
            self._schedule_commit()

    def _set_bw(self, checked: bool):
        if self._updating_inspector:
            return
        for item in self._selected_photos():
            item.adjust["bw"] = bool(checked)
            item.update()
        self._refresh_selection_thumb()
        self._schedule_commit()

    def _reset_colors(self):
        for item in self._selected_photos():
            item.adjust = dict(NEUTRAL_ADJUST)
            item.update()
        self._sync_inspector_from_item(self._get_primary_selected())
        self._schedule_commit()

    def _apply_colors_to_all(self):
        primary = self._get_primary_selected()
        if primary is None:
            return
        for p in self.get_canvas_photos():
            p.adjust = dict(primary.adjust)
            p.update()
        self.statusBar().showMessage("Regolazioni colore applicate a tutte le foto", 3000)
        self._schedule_commit()

    def _copy_style(self):
        item = self._get_primary_selected()
        if item is None:
            self.statusBar().showMessage("Seleziona prima la foto da cui copiare lo stile", 4000)
            return
        self._style_clipboard = {
            "border_radius": item.border_radius,
            "border_width": item.border_width,
            "border_color": QColor(item.border_color),
            "opacity": item.photo_opacity,
            "shadow": item.shadow,
            "adjust": dict(item.adjust),
        }
        self.btn_paste_style.setEnabled(True)
        self.statusBar().showMessage(kb("Stile copiato: seleziona altre foto e usa «Incolla stile» (Ctrl+Shift+V)"), 5000)

    def _paste_style(self):
        st = self._style_clipboard
        selected = self._selected_photos()
        if st is None or not selected:
            self.statusBar().showMessage("Copia prima uno stile, poi seleziona le foto su cui incollarlo", 4000)
            return
        for p in selected:
            p.border_radius = st["border_radius"]
            p.border_width = st["border_width"]
            p.border_color = QColor(st["border_color"])
            p.auto_border = False
            p.set_photo_opacity(st["opacity"])
            p.set_shadow(st["shadow"])
            p.adjust = dict(st["adjust"])
            p.update()
        self._sync_inspector_from_item(self._get_primary_selected())
        self._schedule_commit()

    # ---------- Blocco ----------
    def _set_lock_selected(self, locked: bool):
        if self._updating_inspector:
            return
        for it in self._selected_elements():
            it.set_locked(locked)
        self._sync_inspector_from_item(self._get_primary_selected())
        self._schedule_commit()

    def _toggle_lock_selected(self):
        sel = self._selected_elements()
        if sel:
            target = not all(it.locked for it in sel)
            for it in sel:
                it.set_locked(target)
            self.statusBar().showMessage("Posizione bloccata" if target else "Posizione sbloccata", 3000)
            self._sync_inspector_from_item(self._get_primary_selected())
            self._schedule_commit()

    # ---------- Allinea e distribuisci ----------
    def _page_rect_at(self, x: float) -> QRectF:
        k = max(0, min(self.scene.num_frames - 1, int(math.floor(x / self.scene.frame_w))))
        return QRectF(k * self.scene.frame_w, 0, self.scene.frame_w, self.scene.frame_h)

    def _align_selected(self, how: str):
        selected = self._selected_elements()
        if not selected:
            return
        if len(selected) == 1:
            ref = self._page_rect_at(self._element_rect(selected[0]).center().x())
        else:
            ref = self._element_rect(selected[0])
            for it in selected[1:]:
                ref = ref.united(self._element_rect(it))
        for it in selected:
            if it.locked:
                continue
            r = self._element_rect(it)
            dx = dy = 0.0
            if how == "left":
                dx = ref.left() - r.left()
            elif how == "hcenter":
                dx = ref.center().x() - r.center().x()
            elif how == "right":
                dx = ref.right() - r.right()
            elif how == "top":
                dy = ref.top() - r.top()
            elif how == "vcenter":
                dy = ref.center().y() - r.center().y()
            elif how == "bottom":
                dy = ref.bottom() - r.bottom()
            it.moveBy(dx, dy)
        self._schedule_commit()

    def _distribute_selected(self, horizontal: bool):
        selected = self._selected_elements()
        if len(selected) < 3:
            self.statusBar().showMessage("Seleziona almeno 3 elementi per distribuirli a spazi uguali", 4000)
            return
        rects = {id(it): self._element_rect(it) for it in selected}
        key = (lambda it: rects[id(it)].left()) if horizontal else (lambda it: rects[id(it)].top())
        ordered = sorted(selected, key=key)
        first, last = rects[id(ordered[0])], rects[id(ordered[-1])]
        if horizontal:
            span = last.right() - first.left()
            sizes = sum(rects[id(it)].width() for it in ordered)
        else:
            span = last.bottom() - first.top()
            sizes = sum(rects[id(it)].height() for it in ordered)
        gap = (span - sizes) / (len(ordered) - 1)
        cursor = first.left() if horizontal else first.top()
        for it in ordered:
            r = rects[id(it)]
            if not it.locked:
                if horizontal:
                    it.moveBy(cursor - r.left(), 0)
                else:
                    it.moveBy(0, cursor - r.top())
            cursor += (r.width() if horizontal else r.height()) + gap
        self._schedule_commit()

    def _reset_selected_framing(self):
        """Annulla zoom interno e spostamento X/Y delle foto selezionate (riquadro e rotazione restano)."""
        selected = self._selected_photos()
        if not selected:
            return
        for item in selected:
            item.inner_zoom = 1.0
            item.pan_x = 0.0
            item.pan_y = 0.0
            item.inner_rotation = 0.0
            item.update()
        self._sync_inspector_from_item(self._get_primary_selected())
        self._schedule_commit()

    def _rotate_selected_by(self, delta_deg: float):
        for item in self._selected_elements():
            item.setRotation(((item.rotation() + delta_deg + 180) % 360) - 180)
        self._sync_inspector_from_item(self._get_primary_selected())
        self._schedule_commit()

    def _set_selected_rotation(self, angle: float):
        for item in self._selected_elements():
            item.setRotation(angle)
        self._sync_inspector_from_item(self._get_primary_selected())
        self._schedule_commit()

    def _pick_photo_border_color(self):
        item = self._get_primary_selected()
        initial = item.border_color if item else QColor("#FFFFFF")
        col = QColorDialog.getColor(initial, self, "Colore del bordo")
        if col.isValid():
            for sel in self._selected_photos():
                sel.border_color = col
                sel.update()
            self.btn_border_color.setIcon(swatch_icon(col))
            self._schedule_commit()

    def _apply_style_to_all_photos(self):
        radius = float(self.slider_radius.value())
        border_w = float(self.slider_border.value())
        primary = self._get_primary_selected()
        border_col = primary.border_color if primary else QColor("#FFFFFF")
        for p in self.get_canvas_photos():
            p.border_radius = radius
            p.border_width = border_w
            p.border_color = border_col
            p.auto_border = False
            if primary is not None:
                p.set_photo_opacity(primary.photo_opacity)
                p.set_shadow(primary.shadow)
            p.update()
        self._schedule_commit()

    def _ratio_can_restore(self) -> bool:
        selected = self._selected_photos()
        return bool(selected) and all(sel.saved_cell is not None for sel in selected)

    def _ratio_button_text(self, long: bool = False) -> str:
        if self._ratio_can_restore():
            return "Torna al riquadro di prima" if long else "Riquadro di prima"
        return "Usa le proporzioni della foto" if long else "Proporzioni foto"

    def _update_ratio_button(self):
        restore = self._ratio_can_restore()
        self.btn_ratio.setText(self._ratio_button_text())
        self.btn_ratio.setIcon(make_icon("reset" if restore else "ratio", THEME["text"]))
        self.btn_ratio.setToolTip(
            "Torna al riquadro com'era prima di «Proporzioni foto»" if restore else
            "Usa le proporzioni della foto:\nadatta il riquadro alla forma originale dello scatto,\n"
            "restando dentro lo spazio attuale. Puoi sempre tornare indietro.")

    def _restore_selected_original_ratio(self):
        """Interruttore: proporzioni originali della foto ⇄ riquadro com'era prima."""
        selected = self._selected_photos()
        if selected and all(sel.saved_cell is not None for sel in selected):
            for sel in selected:
                sel.restore_saved_cell()
            self.statusBar().showMessage("Riquadro ripristinato com'era prima", 3000)
        else:
            for sel in selected:
                sel.reset_aspect_to_original()
            if selected:
                self.statusBar().showMessage("Proporzioni della foto applicate. "
                                             "Clicca «Riquadro di prima» per tornare indietro.", 5000)
        self._sync_inspector_from_item(self._get_primary_selected())
        self._schedule_commit()

    def _bring_to_front(self):
        selected = sorted(self._selected_elements(), key=lambda p: p.zValue())
        if selected:
            max_z = self._max_z()
            for i, item in enumerate(selected):
                item.setZValue(max_z + 1.0 + i)
            self._schedule_commit()

    def _send_to_back(self):
        selected = sorted(self._selected_elements(), key=lambda p: p.zValue(), reverse=True)
        if selected:
            min_z = min([it.zValue() for it in self._all_elements()], default=0.0)
            for i, item in enumerate(selected):
                item.setZValue(min_z - 1.0 - i)
            self._schedule_commit()

    def _duplicate_selected(self):
        selected = self._selected_elements()
        if not selected:
            return
        duplicates = []
        for item in selected:
            state = item.get_state()
            if isinstance(item, TextItem):
                dup = self._spawn_text_item()
                state.update(uid=dup.uid, z=self._max_z() + 1.0, x=state["x"] + 30, y=state["y"] + 30, locked=False)
            else:
                dup = self._spawn_photo_item(item.image_path)
                # Copia tutto (incluso zoom/pan interni) tranne identità, livello e ordine
                state.update(uid=dup.uid, z=dup.zValue(), layout_index=dup.layout_index,
                             x=state["x"] + 30, y=state["y"] + 30, locked=False)
            dup.set_state(state)
            duplicates.append(dup)
        self.scene.clearSelection()
        for dup in duplicates:
            dup.setSelected(True)
        self._schedule_commit()

    def _delete_selected(self):
        selected = self._selected_elements()
        for sel in selected:
            self.scene.removeItem(sel)
        if selected:
            self._update_canvas_count()
            self._schedule_commit()

    def _select_all(self):
        for p in self._all_elements():
            p.setSelected(True)

    def _nudge_selected(self, dx: float, dy: float):
        selected = [it for it in self._selected_elements() if not it.locked]
        for p in selected:
            p.moveBy(dx, dy)
        if selected:
            self._sync_inspector_from_item(self._get_primary_selected())
            self._schedule_commit()

    def _show_canvas_context_menu(self, pos):
        # Il clic destro su un elemento non selezionato lo seleziona (come in ogni editor grafico)
        clicked = next((it for it in self.view.items(pos) if isinstance(it, (PhotoItem, TextItem))), None)
        if clicked is not None and not clicked.isSelected():
            self.scene.clearSelection()
            clicked.setSelected(True)

        scene_pt = self.view.mapToScene(pos)
        n_photos = len(self._selected_photos())
        has_photo = n_photos > 0
        elements = self._selected_elements()
        has_el = bool(elements)
        locked = has_el and all(it.locked for it in elements)
        menu = QMenu(self)
        entries = [
            ("text", "Aggiungi un testo qui", lambda: self.add_text(scene_pt), True),
            None,
            ("front", "Porta davanti", self._bring_to_front, has_el),
            ("back", "Manda dietro", self._send_to_back, has_el),
            ("lock", "Sblocca posizione" if locked else "Blocca posizione", self._toggle_lock_selected, has_el),
            None,
            ("swap", "Scambia le 2 foto selezionate", self.swap_two_selected_photos, n_photos == 2),
            ("reset", "Reimposta zoom e posizione", self._reset_selected_framing, has_photo),
            ("ratio", self._ratio_button_text(long=True), self._restore_selected_original_ratio, has_photo),
            ("flip_h", "Specchia orizzontalmente", lambda: self._flip_selected("h"), has_photo),
            ("flip_v", "Specchia verticalmente", lambda: self._flip_selected("v"), has_photo),
            ("duplicate", "Copia stile", self._copy_style, n_photos >= 1),
            ("plus", "Incolla stile", self._paste_style, has_photo and self._style_clipboard is not None),
            ("duplicate", "Duplica", self._duplicate_selected, has_el),
            None,
            ("trash", "Elimina", self._delete_selected, has_el),
        ]
        for entry in entries:
            if entry is None:
                menu.addSeparator()
                continue
            icon, text, slot, enabled = entry
            act = menu.addAction(make_icon(icon, THEME["text"], 16), text)
            act.setEnabled(enabled)
            act.triggered.connect(slot)

        # Gestione della pagina sotto il cursore
        k = max(0, min(self.scene.num_frames - 1, int(math.floor(scene_pt.x() / self.scene.frame_w))))
        n = self.scene.num_frames
        menu.addSeparator()
        page_menu = menu.addMenu(make_icon("page", THEME["text"], 16), f"Pagina {k + 1}")
        page_menu.addAction("Aggiungi una pagina dopo questa", lambda: self._insert_page_after(k))
        a = page_menu.addAction("Sposta a sinistra", lambda: self._move_page(k, -1))
        a.setEnabled(k > 0)
        a = page_menu.addAction("Sposta a destra", lambda: self._move_page(k, 1))
        a.setEnabled(k < n - 1)
        page_menu.addSeparator()
        self._fill_page_count_menu(page_menu.addMenu("Foto in questa pagina"), k)
        page_menu.addSeparator()
        a = page_menu.addAction("Elimina questa pagina…", lambda: self._delete_page(k))
        a.setEnabled(n > 1)
        menu.exec(self.view.mapToGlobal(pos))
