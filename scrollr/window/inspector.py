"""Inspector e modifica degli elementi selezionati."""
import json
import math
import os
from typing import Optional

from PyQt6.QtCore import Qt, QMimeData, QPointF, QRectF
from PyQt6.QtGui import QBrush, QColor, QFont, QIcon, QPainter, QPixmap, QRadialGradient
from PyQt6.QtWidgets import QApplication, QColorDialog, QMenu

from scrollr.canvas.photo_item import PhotoItem
from scrollr.canvas.shape_item import ShapeItem
from scrollr.canvas.text_item import TextItem
from scrollr.config import ELEMENTS_MIME
from scrollr.icons import make_icon, rounded_thumb, swatch_icon
from scrollr.imaging import (
    IMAGE_CACHE, NEUTRAL_ADJUST, PRESETS, apply_adjustments, pil_to_qimage, preset_adjust, qimage_to_pil
)
from scrollr.keys import kb
from scrollr.theme import THEME


class InspectorMixin:
    """Inspector e modifica degli elementi selezionati."""

    # ================= INSPECTOR & CONTROLLI FOTO SINGOLA =================
    def _get_primary_selected(self) -> Optional[PhotoItem]:
        selected = self._selected_photos()
        return selected[0] if selected else None

    def _on_selection_changed(self):
        if self._expanding_groups:
            return
        self._expand_group_selection()
        self._sync_inspector_from_item(self._get_primary_selected())

    # ---------- Gruppi ----------
    def _expand_group_selection(self):
        """
        Gli elementi di un gruppo si selezionano tutti insieme (e quindi si spostano insieme).
        Se ne viene tolto uno dalla selezione (Ctrl+clic) si toglie l'intero gruppo.
        """
        now = set(self._selected_elements())
        removed = set()
        # Col tasto premuto si sta disegnando il riquadro di selezione: lì si aggiunge soltanto,
        # altrimenti un gruppo toccato solo in parte si accenderebbe e spegnerebbe a ogni movimento
        if not QApplication.mouseButtons() & Qt.MouseButton.LeftButton:
            removed = {it.group for it in self._prev_selection - now if it.group and it.scene() is self.scene}
        added = {it.group for it in now if it.group} - removed
        if removed or added:
            self._expanding_groups = True
            try:
                for it in self._all_elements():
                    if it.group in removed:
                        it.setSelected(False)
                    elif it.group in added:
                        it.setSelected(True)
            finally:
                self._expanding_groups = False
        self._prev_selection = set(self._selected_elements())

    def _new_group_id(self) -> int:
        return max([it.group for it in self._all_elements()], default=0) + 1

    def _group_selected(self):
        selected = self._selected_elements()
        if len(selected) < 2:
            self.statusBar().showMessage("Seleziona almeno 2 elementi da raggruppare (Ctrl+clic)", 4000)
            return
        gid = self._new_group_id()
        for it in selected:
            it.group = gid
        self.statusBar().showMessage(kb(f"{len(selected)} elementi raggruppati: si selezionano e si spostano insieme "
                                        "(Ctrl+Shift+G per separarli)"), 5000)
        self._update_align_ui()
        self._schedule_commit()

    def _ungroup_selected(self):
        grouped = [it for it in self._selected_elements() if it.group]
        if not grouped:
            self.statusBar().showMessage("Nessun gruppo selezionato", 3000)
            return
        for it in grouped:
            it.group = 0
        self.statusBar().showMessage("Gruppo separato: ora gli elementi si spostano uno per uno", 4000)
        self._update_align_ui()
        self._schedule_commit()

    def _selection_is_one_group(self) -> bool:
        groups = {it.group for it in self._selected_elements()}
        return len(groups) == 1 and 0 not in groups

    # ---------- Copia, taglia e incolla elementi ----------
    def _copy_selected(self) -> bool:
        """Copia foto, testi e forme selezionati negli appunti (vale anche tra due progetti)."""
        selected = self._selected_elements()
        if not selected:
            self.statusBar().showMessage("Seleziona prima gli elementi da copiare", 3000)
            return False
        entries = []
        for it in sorted(selected, key=lambda x: x.zValue()):
            kind = "text" if isinstance(it, TextItem) else "shape" if isinstance(it, ShapeItem) else "photo"
            entries.append({"type": kind, "state": it.get_state()})
        rect = self._element_rect(selected[0])
        for it in selected[1:]:
            rect = rect.united(self._element_rect(it))
        page = round(self._page_rect_at(rect.center().x()).left() / self.scene.frame_w)
        mime = QMimeData()
        mime.setData(ELEMENTS_MIME, json.dumps({"page": page, "elements": entries}).encode("utf-8"))
        QApplication.clipboard().setMimeData(mime)
        self._paste_serial = 0
        n = len(entries)
        self.statusBar().showMessage("1 elemento copiato" if n == 1 else f"{n} elementi copiati", 3000)
        return True

    def _cut_selected(self):
        if self._copy_selected():
            self._delete_selected()
            self._paste_serial = -1  # L'originale non c'è più: il primo Incolla lo rimette dov'era

    @staticmethod
    def _clipboard_elements() -> Optional[dict]:
        mime = QApplication.clipboard().mimeData()
        if mime is None or not mime.hasFormat(ELEMENTS_MIME):
            return None
        try:
            data = json.loads(bytes(mime.data(ELEMENTS_MIME)).decode("utf-8"))
        except ValueError:
            return None
        return data if isinstance(data, dict) and data.get("elements") else None

    def _paste_elements(self, page: Optional[int] = None):
        """
        Incolla gli elementi copiati nella pagina indicata (di base l'ultima pagina cliccata,
        altrimenti quella al centro della vista),
        nella stessa posizione che avevano nella loro pagina. Nella stessa pagina si spostano un po',
        così la copia non copre l'originale. Le foto incollate sono foto libere: restano dove sono.
        """
        data = self._clipboard_elements()
        if data is None:
            self.statusBar().showMessage("Non c'è niente da incollare: copia prima foto, testi o forme", 4000)
            return
        if not isinstance(page, int) or isinstance(page, bool):
            page = self.scene.last_click_page
        if page is None or not (0 <= page < self.scene.num_frames):
            page = round(self._page_rect_at(self._visible_center_scene().x()).left() / self.scene.frame_w)
        src = int(data.get("page", 0))
        dx = (page - src) * self.scene.frame_w
        dy = 0.0
        if page == src:
            self._paste_serial += 1
            dx = dy = 30.0 * self._paste_serial
        # Foto copiate da un altro progetto: entrano anche nella libreria
        paths = [e["state"]["path"] for e in data["elements"] if e["type"] == "photo"]
        new_paths = [p for p in dict.fromkeys(paths) if not IMAGE_CACHE.has(p) and os.path.isfile(p)]
        if new_paths:
            self._load_into_library(new_paths, "Caricamento foto…")
        first_group = self._new_group_id()
        groups = {}  # Gruppi copiati → gruppi nuovi, separati dagli originali
        pasted = []
        for e in data["elements"]:
            state = dict(e["state"])
            if e["type"] == "text":
                item = self._spawn_text_item()
            elif e["type"] == "shape":
                item = self._spawn_shape_item(state.get("kind", "rect"))
            else:
                item = self._spawn_photo_item(state["path"])
                state.update(layout_index=item.layout_index, free=True)
            if state.get("group"):
                groups.setdefault(state["group"], first_group + len(groups))
            state.update(uid=item.uid, z=self._max_z() + 1.0, x=state["x"] + dx, y=state["y"] + dy,
                         locked=False, group=groups.get(state.get("group"), 0))
            item.set_state(state)
            pasted.append(item)
        self.scene.clearSelection()
        for item in pasted:
            item.setSelected(True)
        self._update_canvas_count()
        n = len(pasted)
        self.statusBar().showMessage(("1 elemento incollato" if n == 1 else f"{n} elementi incollati")
                                     + f" nella pagina {page + 1}", 3000)
        self._schedule_commit()

    def _on_item_geometry_changed(self, item):
        primary = self._get_primary_selected()
        if item is primary or (primary is None and isinstance(item, ShapeItem) and item.isSelected()):
            self._sync_inspector_from_item(primary)

    def _sync_inspector_from_item(self, item: Optional[PhotoItem]):
        self._updating_inspector = True
        count = len(self._selected_photos())
        texts = self._selected_texts()
        shapes = self._selected_shapes()
        if item is None and texts:
            self.insp_stack.setCurrentIndex(2)
            self._sync_text_inspector(texts[0], len(texts))
            self.lbl_hint.setText("Trascina il testo per spostarlo.   Doppio clic: modifica il testo.   "
                                  "Frecce: sposta di 1 px (Shift: 10 px).")
        elif item is None and shapes:
            self.insp_stack.setCurrentIndex(3)
            self._sync_shape_inspector(shapes[0], len(shapes))
            self.lbl_hint.setText("Maniglie: ridimensiona (Shift sugli angoli: proporzioni).   Pallino in alto: ruota "
                                  "(Shift: 15°).   Frecce: sposta di 1 px (Shift: 10 px).")
        else:
            self.insp_stack.setCurrentIndex(0 if item is None else 1)
        if item is None and not texts and not shapes:
            self.lbl_hint.setText(kb("Trascina sul vuoto: sposta la vista.   Shift + trascina: seleziona più elementi.   "
                                     "Rotella: zoom · due dita: sposta.   F1: tutte le scorciatoie."))
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
            self.lbl_hint.setText(kb("Alt + trascina: sposta l'inquadratura.   Alt + rotella: zoom nella foto.   "
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
            self.chk_auto.setChecked(bool(item.adjust.get("auto")))
            self._sync_presets(item)
            self.slider_opacity.setValue(item.photo_opacity)
            self.slider_shadow.setValue(item.shadow)
            self.btn_paste_style.setEnabled(self._style_clipboard is not None)
            self._update_ratio_button()
        primary = item if item is not None else (texts[0] if texts else (shapes[0] if shapes else None))
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
        self.slider_text_outline.setValue(round(t.outline))
        self.btn_outline_color.setIcon(swatch_icon(t.outline_color))
        self.slider_line_height.setValue(t.line_height)
        self.slider_letter_spacing.setValue(t.letter_spacing)

    def _update_align_ui(self):
        n = len(self._selected_elements())
        one_group = self._selection_is_one_group()
        for b in self._group_buttons:
            b.setEnabled(n >= 2 and not one_group)
        for b in self._ungroup_buttons:
            b.setEnabled(any(it.group for it in self._selected_elements()))
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
            elif prop in NEUTRAL_ADJUST:
                item.adjust[prop] = int(value)
            elif prop == "opacity":
                item.set_photo_opacity(value)
            elif prop == "shadow":
                item.set_shadow(value)
            item.update()
        if prop in NEUTRAL_ADJUST:
            self._refresh_selection_thumb()
            self._sync_presets(self._get_primary_selected())
        self._schedule_commit()

    # ---------- Filtri pronti, automatico e prima/dopo ----------
    def _sync_presets(self, item: Optional[PhotoItem]):
        """Miniature dei filtri con la foto selezionata; si accende il filtro che corrisponde alle regolazioni."""
        if item is None:
            return
        current = dict(NEUTRAL_ADJUST, **item.adjust)
        for key, button in self.preset_buttons.items():
            button.setChecked(preset_adjust(key) == current)
        source = (item.image_path, item.pixmap.cacheKey())
        if getattr(self, "_preset_thumbs_for", None) == source:
            return
        self._preset_thumbs_for = source
        pm = item.pixmap
        if pm.isNull():
            for button in self.preset_buttons.values():
                button.setIcon(QIcon())
            return
        side = min(pm.width(), pm.height())
        square = pm.copy((pm.width() - side) // 2, (pm.height() - side) // 2, side, side).scaled(
            108, 108, Qt.AspectRatioMode.IgnoreAspectRatio, Qt.TransformationMode.SmoothTransformation)
        base = qimage_to_pil(square.toImage())
        for key, button in self.preset_buttons.items():
            adj = preset_adjust(key)
            thumb = QPixmap.fromImage(pil_to_qimage(apply_adjustments(base, adj, detail_scale=0.4)))
            if adj.get("vignette"):
                self._paint_thumb_vignette(thumb, adj["vignette"])
            button.setIcon(QIcon(rounded_thumb(thumb, 54, 3)))

    @staticmethod
    def _paint_thumb_vignette(pm: QPixmap, vignette: int):
        """Vignettatura sulla miniatura del filtro (sulla tela la disegna la foto stessa)."""
        painter = QPainter(pm)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        grad = QRadialGradient(QPointF(pm.width() / 2.0, pm.height() / 2.0), pm.width() / 2.0 * math.sqrt(2.0))
        base = QColor(0, 0, 0) if vignette < 0 else QColor(255, 255, 255)
        for stop, k in ((0.0, 0.0), (0.42, 0.0), (0.72, 0.38), (1.0, 0.9)):
            c = QColor(base)
            c.setAlphaF(min(1.0, abs(vignette) / 100.0) * k)
            grad.setColorAt(stop, c)
        painter.fillRect(pm.rect(), QBrush(grad))
        painter.end()

    def _apply_preset(self, key: str):
        selected = self._selected_photos()
        if not selected:
            return
        for item in selected:
            item.adjust = preset_adjust(key)
            item.update()
        name = next(n for k, n, _ in PRESETS if k == key)
        self.statusBar().showMessage(
            "Foto riportata all'originale" if key == "original" else
            f"Filtro «{name}» applicato: puoi ritoccarlo con le regolazioni qui sotto "
            "o usarlo su tutte le foto con «Applica a tutte»", 5000)
        self._sync_inspector_from_item(self._get_primary_selected())
        self._schedule_commit()

    def _set_adjust_flag(self, key: str, checked: bool):
        if self._updating_inspector:
            return
        for item in self._selected_photos():
            item.adjust[key] = bool(checked)
            item.update()
        self._refresh_selection_thumb()
        self._sync_presets(self._get_primary_selected())
        self._schedule_commit()

    def _show_original(self, on: bool):
        """Prima/dopo: finché il pulsante è premuto tutte le foto si vedono senza filtri e regolazioni."""
        self.scene.show_original = bool(on)
        for p in self.get_canvas_photos():
            p.update()

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
        self._set_adjust_flag("bw", checked)

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
        first_group = self._new_group_id()
        groups = {}  # La copia di un gruppo diventa un gruppo nuovo, separato dall'originale
        for item in selected:
            state = item.get_state()
            if item.group:
                state["group"] = groups.setdefault(item.group, first_group + len(groups))
            if isinstance(item, TextItem):
                dup = self._spawn_text_item()
                state.update(uid=dup.uid, z=self._max_z() + 1.0, x=state["x"] + 30, y=state["y"] + 30, locked=False)
            elif isinstance(item, ShapeItem):
                dup = self._spawn_shape_item(item.kind)
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

    def _show_canvas_context_menu(self, pos, view=None):
        view = view or self.view  # Con le pagine a scacchiera arriva la vista della pagina cliccata
        # Il clic destro su un elemento non selezionato lo seleziona (come in ogni editor grafico)
        clicked = next((it for it in view.items(pos) if isinstance(it, (PhotoItem, TextItem, ShapeItem))), None)
        if clicked is not None and not clicked.isSelected():
            self.scene.clearSelection()
            clicked.setSelected(True)

        scene_pt = view.mapToScene(pos)
        n_photos = len(self._selected_photos())
        has_photo = n_photos > 0
        elements = self._selected_elements()
        has_el = bool(elements)
        locked = has_el and all(it.locked for it in elements)
        k = max(0, min(self.scene.num_frames - 1, int(math.floor(scene_pt.x() / self.scene.frame_w))))
        menu = QMenu(self)
        act = menu.addAction(make_icon("duplicate", THEME["text"], 16), "Copia", self._copy_selected)
        act.setEnabled(has_el)
        act = menu.addAction(make_icon("plus", THEME["text"], 16), "Incolla qui", lambda: self._paste_elements(k))
        act.setEnabled(self._clipboard_elements() is not None)
        if len(elements) >= 2 and not self._selection_is_one_group():
            menu.addAction(make_icon("group", THEME["text"], 16), "Raggruppa", self._group_selected)
        if any(it.group for it in elements):
            menu.addAction(make_icon("ungroup", THEME["text"], 16), "Separa il gruppo", self._ungroup_selected)
        menu.addSeparator()
        menu.addAction(make_icon("text", THEME["text"], 16), "Aggiungi un testo qui", lambda: self.add_text(scene_pt))
        self._fill_shape_menu(menu.addMenu(make_icon("shape", THEME["text"], 16), "Aggiungi una forma qui"), scene_pt)
        entries = [
            None,
            *([("image", "Ricollega foto…", self._relink_selected_photo, True), None]
              if any(p.is_missing for p in self._selected_photos()) else []),
            ("front", "Porta davanti", self._bring_to_front, has_el),
            ("back", "Manda dietro", self._send_to_back, has_el),
            ("lock", "Sblocca posizione" if locked else "Blocca posizione", self._toggle_lock_selected, has_el),
            None,
            ("scatter", "Rimetti nella disposizione" if has_photo and all(p.free for p in self._selected_photos())
             else "Rendi foto libera (fuori dalla disposizione)", self._toggle_free_selected, has_photo),
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
        n = self.scene.num_frames
        movable = [p for p in self._selected_photos() if not p.free]
        if movable and self._pages_split():
            current = self._photo_pages()
            here = {current.get(p.uid) for p in movable}
            move_menu = menu.addMenu(make_icon("page", THEME["text"], 16), "Sposta nella pagina")
            for f in range(n):
                act = move_menu.addAction(f"Pagina {f + 1}")
                act.setEnabled(here != {f})
                act.triggered.connect(lambda _c=False, t=f: self._move_photos_to_page(
                    [p for p in self._selected_photos() if not p.free], t))
        menu.addSeparator()
        page_menu = menu.addMenu(make_icon("page", THEME["text"], 16), f"Pagina {k + 1}")
        page_menu.addAction("Aggiungi una pagina prima di questa", lambda: self._insert_page_at(k))
        page_menu.addAction("Aggiungi una pagina dopo questa", lambda: self._insert_page_after(k))
        page_menu.addAction(make_icon("duplicate", THEME["text"], 16), "Duplica questa pagina",
                            lambda: self._duplicate_page(k))
        a = page_menu.addAction("Sposta a sinistra", lambda: self._move_page(k, -1))
        a.setEnabled(k > 0)
        a = page_menu.addAction("Sposta a destra", lambda: self._move_page(k, 1))
        a.setEnabled(k < n - 1)
        a = page_menu.addAction("Riordina le pagine…", self.reorder_pages_dialog)
        a.setEnabled(n > 1)
        page_menu.addSeparator()
        self._fill_page_layout_menu(page_menu.addMenu("Disposizione di questa pagina"), k)
        self._fill_page_count_menu(page_menu.addMenu("Foto in questa pagina"), k)
        page_menu.addSeparator()
        page_menu.addAction(make_icon("export", THEME["text"], 16), "Esporta questa pagina…",
                            lambda: self.export_split_frames([k]))
        page_menu.addSeparator()
        a = page_menu.addAction("Elimina questa pagina…", lambda: self._delete_page(k))
        a.setEnabled(n > 1)
        menu.exec(view.mapToGlobal(pos))
