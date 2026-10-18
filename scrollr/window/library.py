"""Caricamento foto, libreria ed elementi sulla tela."""
import os
from typing import List, Optional, Tuple

from PyQt6.QtCore import Qt, QRectF, QPointF, QSize
from PyQt6.QtGui import QIcon
from PyQt6.QtWidgets import QApplication, QFileDialog, QListWidgetItem, QMessageBox, QMenu, QProgressDialog

from scrollr.canvas.photo_item import PhotoItem
from scrollr.canvas.text_item import TextItem
from scrollr.config import IMAGE_EXTS
from scrollr.icons import make_icon, rounded_thumb
from scrollr.imaging import IMAGE_CACHE, normalize_path
from scrollr.theme import THEME


class LibraryMixin:
    """Caricamento foto, libreria ed elementi sulla tela."""

    # ================= CARICAMENTO E LIBRERIA FOTO =================
    def open_file_dialog(self):
        patterns = " ".join(f"*{ext}" for ext in IMAGE_EXTS)
        paths, _ = QFileDialog.getOpenFileNames(
            self,
            "Scegli le foto",
            "",
            f"Immagini ({patterns})"
        )
        if paths:
            self.load_images_from_paths(paths)

    def _load_into_library(self, paths: List[str], title: str) -> Tuple[List[str], List[str]]:
        """Carica i file nella cache/libreria con barra di avanzamento. Ritorna (caricati, errori)."""
        loaded, errors = [], []
        progress = None
        if len(paths) > 2:
            progress = QProgressDialog(title, "Annulla", 0, len(paths), self)
            progress.setWindowTitle("ScrolleR Studio")
            progress.setWindowModality(Qt.WindowModality.WindowModal)
            progress.setMinimumDuration(300)

        for i, p in enumerate(paths):
            if progress is not None:
                if progress.wasCanceled():
                    break
                progress.setValue(i)
                progress.setLabelText(f"{title}\n{os.path.basename(p)}  ({i + 1} di {len(paths)})")
                QApplication.processEvents()
            p = normalize_path(p)
            try:
                pixmap = IMAGE_CACHE.load(p)
            except Exception as e:
                errors.append(f"{os.path.basename(p)}: {e}")
                continue
            if p not in self.loaded_library:
                self.loaded_library.append(p)
                item = QListWidgetItem(QIcon(rounded_thumb(pixmap, 80)), "")
                item.setData(Qt.ItemDataRole.UserRole, p)
                item.setToolTip(os.path.basename(p))
                item.setSizeHint(QSize(86, 86))
                self.list_library.addItem(item)
            loaded.append(p)

        if progress is not None:
            progress.setValue(len(paths))
        self._update_library_ui()
        return loaded, errors

    def _report_load_errors(self, errors: List[str]):
        if errors:
            shown = "\n".join(errors[:15])
            more = f"\n… e altri {len(errors) - 15}" if len(errors) > 15 else ""
            QMessageBox.warning(self, "Alcune foto non sono state caricate",
                                "Questi file non sono immagini leggibili:\n\n" + shown + more)

    def _update_library_ui(self):
        n = len(self.loaded_library)
        self.lbl_library_count.setText("" if n == 0 else ("1 foto" if n == 1 else f"{n} foto"))
        self.library_stack.setCurrentIndex(1 if n else 0)
        self.btn_add_all.setEnabled(n > 0)
        self._update_library_selection_ui()

    def _on_library_reordered(self, *_):
        """Dopo un trascinamento nella libreria l'ordine delle foto segue quello delle miniature."""
        self.loaded_library = [self.list_library.item(i).data(Qt.ItemDataRole.UserRole)
                               for i in range(self.list_library.count())]

    def _library_selected_paths(self) -> List[str]:
        """Percorsi selezionati nella libreria, nell'ordine della libreria (non in quello dei clic)."""
        items = sorted(self.list_library.selectedItems(), key=self.list_library.row)
        return [it.data(Qt.ItemDataRole.UserRole) for it in items]

    def _update_library_selection_ui(self):
        n_lib = len(self.loaded_library)
        n_sel = len(self.list_library.selectedItems())
        self.library_sel_box.setVisible(n_lib > 0)
        self.library_actions_box.setVisible(n_sel > 0)
        self.btn_library_sel_none.setEnabled(n_sel > 0)
        self.btn_library_sel_all.setEnabled(n_sel < n_lib)
        if n_sel:
            self.lbl_library_sel.setText("1 selezionata" if n_sel == 1 else f"{n_sel} selezionate")
            self.btn_add_all.setText("Metti solo la selezionata" if n_sel == 1 else f"Metti le {n_sel} selezionate")
            self.btn_add_all.setToolTip("Sostituisce le foto sulla tela con quelle selezionate e le dispone")
            self.btn_add_all.setObjectName("Primary")
        else:
            self.lbl_library_sel.setText("Clicca le foto per sceglierle")
            self.btn_add_all.setText("Metti tutte sulla tela")
            self.btn_add_all.setToolTip("Sostituisce le foto sulla tela con tutte quelle della libreria")
            self.btn_add_all.setObjectName("Ghost")
        self.btn_add_all.style().unpolish(self.btn_add_all)
        self.btn_add_all.style().polish(self.btn_add_all)

    def _update_canvas_count(self):
        self._update_tool_states()
        paths = {p.image_path for p in self.get_canvas_photos()}
        if paths != self._canvas_paths:
            self._canvas_paths = paths
            self.list_library.viewport().update()
        n = len(self.get_canvas_photos())
        text = "Tela vuota" if n == 0 else ("1 foto sulla tela" if n == 1 else f"{n} foto sulla tela")
        missing = self._missing_on_canvas()
        if missing:
            text += f"  ·  {missing} mancant" + ("e" if missing == 1 else "i")
        self.lbl_count.setText(text)
        self.btn_clear_canvas.setEnabled(n > 0)

    def load_images_from_paths(self, paths: List[str]):
        loaded, errors = self._load_into_library(paths, "Caricamento foto…")
        for p in loaded:
            self._spawn_photo_item(p)
        if loaded:
            # Dispone automaticamente tutte le foto caricate nel formato selezionato (es. 3:4)
            self._relayout_keep()
            self.fit_canvas_in_view()
            self._schedule_commit()
        self._report_load_errors(errors)

    def _spawn_photo_item(self, path: str, uid: Optional[int] = None) -> PhotoItem:
        photo_item = PhotoItem(path, 400, 500, uid=uid)
        photo_item.snap_enabled = self.chk_snap.isChecked()
        photo_item.geometry_changed.connect(self._on_item_geometry_changed)
        photo_item.edit_finished.connect(self._schedule_commit)
        # Z-index e ordine di layout crescenti
        existing = self.get_canvas_photos()
        photo_item.setZValue(max([it.zValue() for it in existing], default=0.0) + 1.0)
        photo_item.layout_index = max([it.layout_index for it in existing], default=0) + 1
        self.scene.addItem(photo_item)
        return photo_item

    def _on_library_item_double_clicked(self, item: QListWidgetItem):
        self._add_library_paths_to_canvas([item.data(Qt.ItemDataRole.UserRole)])

    def _add_library_paths_to_canvas(self, paths: List[str]):
        # Le nuove foto compaiono al centro della zona visibile della tela
        center = self.view.mapToScene(self.view.viewport().rect().center())
        self.scene.clearSelection()
        for i, path in enumerate(paths):
            if not IMAGE_CACHE.has(path):
                continue
            new_item = self._spawn_photo_item(path)
            new_item.setPos(center - QPointF(new_item.cell_w / 2.0, new_item.cell_h / 2.0) + QPointF(i * 30, i * 30))
            new_item.setSelected(True)
        self._schedule_commit()

    def _show_library_context_menu(self, pos):
        items = self.list_library.selectedItems()
        if not items:
            return
        menu = QMenu(self)
        act_only = menu.addAction(make_icon("grid", THEME["text"], 16), "Metti sulla tela solo queste")
        act_add = menu.addAction(make_icon("plus", THEME["text"], 16), "Aggiungi alla tela (tieni le altre)")
        menu.addSeparator()
        act_remove = menu.addAction(make_icon("trash", THEME["text"], 16), "Rimuovi dalla libreria")
        chosen = menu.exec(self.list_library.mapToGlobal(pos))
        paths = self._library_selected_paths()
        if chosen == act_only:
            self._put_paths_on_canvas(paths)
        elif chosen == act_add:
            self._add_library_paths_to_canvas(paths)
        elif chosen == act_remove:
            self._remove_selected_from_library()

    def _add_selected_library_to_canvas(self):
        paths = [p for p in self._library_selected_paths() if IMAGE_CACHE.has(p)]
        if not paths:
            return
        for path in paths:
            self._spawn_photo_item(path)
        self.list_library.clearSelection()
        self._relayout_keep()
        self._schedule_commit()

    def _remove_selected_from_library(self):
        items = self.list_library.selectedItems()
        for it in items:
            path = it.data(Qt.ItemDataRole.UserRole)
            if path in self.loaded_library:
                self.loaded_library.remove(path)
            self.list_library.takeItem(self.list_library.row(it))
        self._update_library_ui()

    def add_all_library_to_canvas(self):
        # Con delle foto selezionate nella libreria mette solo quelle, altrimenti tutte
        self._put_paths_on_canvas(self._library_selected_paths() or list(self.loaded_library))

    def _put_paths_on_canvas(self, paths: List[str]):
        """Sostituisce le foto sulla tela con queste e le dispone con la disposizione attuale."""
        paths = [p for p in paths if IMAGE_CACHE.has(p)]
        if not paths:
            return
        self._remove_all_photos()
        for path in paths:
            self._spawn_photo_item(path)
        self._relayout_keep()
        self._schedule_commit()

    def _remove_all_photos(self):
        for item in self.get_canvas_photos():
            self.scene.removeItem(item)

    def clear_canvas_photos(self):
        self._remove_all_photos()
        for t in self.get_canvas_texts():
            self.scene.removeItem(t)
        self._update_canvas_count()
        self._schedule_commit()

    def get_canvas_photos(self) -> List[PhotoItem]:
        """Foto sulla tela, nell'ordine di layout (indipendente dai livelli/Z-index)."""
        items = [it for it in self.scene.items() if isinstance(it, PhotoItem)]
        items.sort(key=lambda x: (x.layout_index, x.uid))
        return items

    def _selected_photos(self) -> List[PhotoItem]:
        return [it for it in self.scene.selectedItems() if isinstance(it, PhotoItem)]

    def get_canvas_texts(self) -> List[TextItem]:
        items = [it for it in self.scene.items() if isinstance(it, TextItem)]
        items.sort(key=lambda t: t.uid)
        return items

    def _selected_texts(self) -> List[TextItem]:
        return [it for it in self.scene.selectedItems() if isinstance(it, TextItem)]

    def _selected_elements(self) -> list:
        """Foto e testi selezionati."""
        return [it for it in self.scene.selectedItems() if isinstance(it, (PhotoItem, TextItem))]

    def _all_elements(self) -> list:
        return self.get_canvas_photos() + self.get_canvas_texts()

    @staticmethod
    def _element_rect(it) -> QRectF:
        """Ingombro in scena (rotazione inclusa) di una foto o di un testo."""
        local = it.text_rect() if isinstance(it, TextItem) else QRectF(0, 0, it.cell_w, it.cell_h)
        return it.mapRectToScene(local)

    def _max_z(self) -> float:
        return max([it.zValue() for it in self._all_elements()], default=0.0)
