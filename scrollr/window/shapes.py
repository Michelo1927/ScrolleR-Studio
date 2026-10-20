"""Forme grafiche: inserimento e proprietà (riempimento, bordo, opacità)."""
from typing import Optional

from PyQt6.QtCore import QPointF
from PyQt6.QtGui import QColor
from PyQt6.QtWidgets import QMenu

from scrollr.canvas.shape_item import ShapeItem
from scrollr.icons import make_icon
from scrollr.shapes import LINE_KINDS, SHAPE_KINDS, SHAPE_NAMES
from scrollr.theme import THEME


class ShapesMixin:
    """Forme grafiche: inserimento e proprietà (riempimento, bordo, opacità)."""

    # Stile di partenza di una forma nuova; poi vale l'ultimo usato (per forme piene e per linee)
    SHAPE_DEFAULTS = {
        "box": {"fill": "#FFFF3B30", "stroke": "#FFFFFFFF", "stroke_width": 0.0, "stroke_style": "solid", "radius": 0.0},
        "line": {"fill": "#00000000", "stroke": "#FFFF3B30", "stroke_width": None, "stroke_style": "solid", "radius": 0.0},
    }

    # ---------- Creazione ----------
    def _wire_shape(self, sh: ShapeItem):
        sh.snap_enabled = self.chk_snap.isChecked()
        sh.geometry_changed.connect(self._on_item_geometry_changed)
        sh.edit_finished.connect(self._schedule_commit)

    def _spawn_shape_item(self, kind: str = "rect", uid: Optional[int] = None) -> ShapeItem:
        sh = ShapeItem(kind, uid=uid)
        self._wire_shape(sh)
        self.scene.addItem(sh)
        return sh

    def _fill_shape_menu(self, menu: QMenu, at: Optional[QPointF] = None):
        """Voci Rettangolo / Ellisse / … / Freccia: un clic inserisce la forma (al centro o nel punto `at`)."""
        for kind, name in SHAPE_KINDS:
            if kind == LINE_KINDS[0]:
                menu.addSeparator()
            menu.addAction(make_icon("shape_" + kind, THEME["text"], 16), name,
                           lambda _c=False, k=kind: self.add_shape(k, at))

    def add_shape(self, kind: str = "rect", at: Optional[QPointF] = None):
        if not isinstance(at, QPointF):
            at = None
        sc = self.scene
        base = min(sc.frame_w, sc.frame_h) * 0.3
        sh = self._spawn_shape_item(kind)
        family = "line" if kind in LINE_KINDS else "box"
        style = dict(self.SHAPE_DEFAULTS[family], **self._last_shape_style.get(family, {}))
        sh.fill_color = QColor(style["fill"])
        sh.stroke_color = QColor(style["stroke"])
        sh.stroke_width = style["stroke_width"] if style["stroke_width"] is not None \
            else float(max(2, round(min(sc.frame_w, sc.frame_h) * 0.01)))
        sh.stroke_style = style["stroke_style"]
        sh.corner_radius = style["radius"]
        if family == "line":
            sh.set_size(base * 1.4, 1.0)
            sh.refresh_geometry()
        else:
            sh.set_size(base * (1.3 if kind == "rect" else 1.0), base)
        sh.setZValue(self._max_z() + 1.0)
        if at is None:
            at = self._page_rect_at(self._visible_center_scene().x()).center()
        sh.setPos(at - QPointF(sh.w / 2.0, sh.h / 2.0))
        self.scene.clearSelection()
        sh.setSelected(True)
        self.statusBar().showMessage(
            "Forma aggiunta: tira gli estremi per allungarla e orientarla (Shift: scatti di 15°)" if family == "line"
            else "Forma aggiunta: tira gli angoli per ridimensionarla, il pallino in alto per ruotarla", 6000)
        self._schedule_commit()

    # ---------- Proprietà dal pannello ----------
    def _remember_shape_style(self, sh: ShapeItem):
        """Le prossime forme dello stesso tipo (piene o linee) nascono con questo stile."""
        self._last_shape_style["line" if sh.is_line else "box"] = {
            "fill": sh.fill_color.name(QColor.NameFormat.HexArgb),
            "stroke": sh.stroke_color.name(QColor.NameFormat.HexArgb),
            "stroke_width": sh.stroke_width,
            "stroke_style": sh.stroke_style,
            "radius": sh.corner_radius,
        }

    def _visible_stroke_width(self) -> float:
        return float(max(2, round(min(self.scene.frame_w, self.scene.frame_h) * 0.008)))

    def _set_shape_color(self, which: str, color: QColor):
        if self._updating_inspector:
            return
        shapes = self._selected_shapes()
        for sh in shapes:
            if which == "fill" and not sh.is_line:
                sh.fill_color = QColor(color)
                if color.alpha() == 0 and sh.stroke_width <= 0:
                    # Senza riempimento né bordo la forma sparirebbe: resta il contorno
                    sh.stroke_width = self._visible_stroke_width()
            elif which == "stroke":
                sh.stroke_color = QColor(color)
                if sh.stroke_width <= 0 and not sh.is_line:
                    sh.stroke_width = self._visible_stroke_width()  # Scegliere il colore del bordo lo mostra
            sh.update()
        if shapes:
            self._remember_shape_style(shapes[0])
            self._sync_inspector_from_item(None)
            self._schedule_commit()

    def _on_shape_prop(self, prop: str, value):
        if self._updating_inspector:
            return
        shapes = self._selected_shapes()
        for sh in shapes:
            if prop == "kind":
                was_line = sh.is_line
                sh.kind = value
                if sh.is_line != was_line:
                    # Da forma piena a linea (o viceversa): stessa larghezza, altezza adatta al nuovo tipo
                    center = sh.mapToScene(QPointF(sh.w / 2.0, sh.h / 2.0))
                    if sh.is_line:
                        sh.stroke_width = max(sh.stroke_width, self._visible_stroke_width())
                    sh.set_size(sh.w, sh.w * 0.75 if not sh.is_line else 1.0)
                    sh.setPos(center - QPointF(sh.w / 2.0, sh.h / 2.0))
                sh.refresh_geometry()
            elif prop == "stroke_width":
                sh.stroke_width = float(value)
                sh.refresh_geometry()
            elif prop == "stroke_style":
                sh.stroke_style = value
            elif prop == "radius":
                sh.corner_radius = float(value)
            elif prop == "opacity":
                sh.set_shape_opacity(value)
            elif prop == "rotation":
                sh.setRotation(float(value))
            sh.update()
        if shapes:
            if prop in ("stroke_width", "stroke_style", "radius"):
                self._remember_shape_style(shapes[0])
            if prop == "kind":
                self._sync_inspector_from_item(None)
            self._schedule_commit()

    def _sync_shape_inspector(self, sh: ShapeItem, count: int):
        self.lbl_shape_title.setText(SHAPE_NAMES.get(sh.kind, "Forma") if count == 1 else f"{count} forme selezionate")
        self.lbl_shape_icon.setPixmap(make_icon("shape_" + sh.kind, THEME["text"], 28).pixmap(28, 28))
        self.lbl_shape_info.setText(
            "Tira gli estremi per allungarla e orientarla" if sh.is_line
            else f"{int(sh.w)} × {int(sh.h)} px  ·  pallino in alto per ruotare")
        idx = self.combo_shape_kind.findData(sh.kind)
        if idx >= 0:
            self.combo_shape_kind.setCurrentIndex(idx)
        self.shape_fill_box.setVisible(not sh.is_line)
        self.shape_radius_box.setVisible(sh.kind == "rect")
        self.lbl_shape_stroke.setText("Linea" if sh.is_line else "Bordo")
        self.shape_fill_row.set_color(sh.fill_color)
        self.shape_stroke_row.set_color(sh.stroke_color)
        self.slider_shape_stroke.setValue(round(sh.stroke_width))
        idx = self.combo_shape_dash.findData(sh.stroke_style)
        if idx >= 0:
            self.combo_shape_dash.setCurrentIndex(idx)
        self.slider_shape_radius.setValue(round(sh.corner_radius))
        self.slider_shape_opacity.setValue(sh.shape_opacity)
        self.slider_shape_rotation.setValue(round(sh.rotation()))
