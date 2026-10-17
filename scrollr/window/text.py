"""Caselle di testo: creazione e proprietà."""
from typing import Optional

from PyQt6.QtCore import QPointF
from PyQt6.QtGui import QColor
from PyQt6.QtWidgets import QColorDialog

from scrollr.canvas.text_item import TextItem
from scrollr.theme import is_light


class TextMixin:
    """Caselle di testo: creazione e proprietà."""

    # ---------- Testo ----------
    def _wire_text(self, t: TextItem):
        t.geometry_changed.connect(self._on_item_geometry_changed)
        t.edit_finished.connect(self._schedule_commit)
        t.edit_requested.connect(self._focus_text_editor)

    def _spawn_text_item(self, uid: Optional[int] = None) -> TextItem:
        t = TextItem(uid=uid)
        self._wire_text(t)
        self.scene.addItem(t)
        return t

    def add_text(self, at: Optional[QPointF] = None):
        t = self._spawn_text_item()
        sc = self.scene
        dark_bg = sc.bg_mode == "blur" or not is_light(sc.bg_color)
        t.color = QColor("#FFFFFF") if dark_bg else QColor("#1A1A1A")
        t.shadow = dark_bg
        # Etichetta in contrasto col testo: scura dietro il testo bianco, chiara dietro quello scuro
        t.box_color = QColor(0, 0, 0, 150) if dark_bg else QColor(255, 255, 255, 215)
        t.font_size = round(sc.frame_w * 0.07)
        t.relayout(keep_center=False)
        t.setZValue(self._max_z() + 1.0)
        if at is None:
            page = self._page_rect_at(self.view.mapToScene(self.view.viewport().rect().center()).x())
            at = page.center()
        t.setPos(at - t.text_rect().center())
        self.scene.clearSelection()
        t.setSelected(True)
        self._schedule_commit()
        self._focus_text_editor(t)

    def _focus_text_editor(self, t: TextItem):
        if not t.isSelected():
            self.scene.clearSelection()
            t.setSelected(True)
        self.text_tabs.setCurrentIndex(0)
        self.edit_text.setFocus()
        self.edit_text.selectAll()

    def _on_text_content_changed(self):
        if self._updating_inspector:
            return
        txt = self.edit_text.toPlainText()
        for t in self._selected_texts():
            t.set_text(txt)
        self._schedule_commit()

    def _on_text_prop(self, prop: str, value):
        if self._updating_inspector:
            return
        for t in self._selected_texts():
            if prop == "font":
                t.font_family = value
            elif prop == "size":
                t.font_size = float(value)
            elif prop == "bold":
                t.bold = bool(value)
            elif prop == "italic":
                t.italic = bool(value)
            elif prop == "align":
                t.align = value
            elif prop == "shadow":
                t.shadow = bool(value)
            elif prop == "box":
                t.box = bool(value)
            elif prop == "opacity":
                t.set_text_opacity(value)
            t.relayout()
        if prop == "box":
            self.btn_box_color.setEnabled(bool(value))
        self._schedule_commit()

    def _pick_text_color(self, which: str):
        texts = self._selected_texts()
        if not texts:
            return
        initial = texts[0].color if which == "color" else texts[0].box_color
        options = QColorDialog.ColorDialogOption.ShowAlphaChannel if which == "box" else QColorDialog.ColorDialogOption(0)
        col = QColorDialog.getColor(initial, self, "Colore del testo" if which == "color" else "Colore dell'etichetta", options)
        if not col.isValid():
            return
        for t in texts:
            if which == "color":
                t.color = col
            else:
                t.box_color = col
                t.box = True
            t.relayout()
        self._sync_inspector_from_item(None)
        self._schedule_commit()
