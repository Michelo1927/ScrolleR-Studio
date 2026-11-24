"""Salvataggio e apertura progetti, recenti e salvataggio automatico."""
import json
import os
import tempfile
from typing import List

from PyQt6.QtCore import QSettings, QStandardPaths
from PyQt6.QtWidgets import QFileDialog, QMessageBox

from scrollr.config import PROJECT_EXT, PROJECT_VERSION
from scrollr.dialogs import NewProjectDialog
from scrollr.imaging import IMAGE_CACHE, normalize_path


class ProjectMixin:
    """Salvataggio e apertura progetti, recenti e salvataggio automatico."""

    MAX_PAGES = 30  # Pagine di un carosello (un reel ne ha una sola)

    # ================= TIPO DI PROGETTO: CAROSELLO O REEL =================
    def _apply_project_type_ui(self):
        """Il reel ha una sola pagina e la guida della zona sicura; il carosello fino a MAX_PAGES pagine."""
        reel = self.project_type == "reel"
        self.scene.is_reel = reel
        self.spin_frames.setMaximum(1 if reel else self.MAX_PAGES)
        for w in (self.spin_frames, self.btn_frames_less, self.btn_frames_more):
            w.setEnabled(not reel)
            w.setToolTip("Un reel ha una sola pagina" if reel else "")
        if not reel:
            self.spin_frames.setToolTip("1 = un solo collage nel formato scelto.\n"
                                        "2 o più = carosello continuo da pubblicare a pagine.")
            self.btn_frames_less.setToolTip("Una pagina in meno")
            self.btn_frames_more.setToolTip("Una pagina in più")
        act = getattr(self, "act_convert_type", None)
        if act is not None:
            act.setText("Converti in carosello" if reel else "Converti in reel")
        self.scene.update()

    def _page_limit_message(self) -> str:
        if self.project_type == "reel":
            return "Un reel ha una sola pagina"
        return f"Massimo {self.MAX_PAGES} pagine"

    def toggle_project_type(self):
        """File → Converti in reel / in carosello. Un passo di Annulla."""
        self._flush_pending_commit()
        if self.project_type == "carousel":
            if self.scene.num_frames > 1:
                QMessageBox.information(self, "Converti in reel",
                                        "Un reel ha una sola pagina: togli le altre pagine, poi converti il progetto.")
                return
            self.project_type = "reel"
            self._apply_project_type_ui()
            message = "Progetto convertito in reel: i video arrivano a 5 minuti"
        else:
            self.project_type = "carousel"
            self._apply_project_type_ui()
            if self._keep_videos_in_limit():
                message = ("Progetto convertito in carosello: i video più lunghi di 60 s usano il primo minuto. "
                           "Scegli la parte con Inizio e Fine.")
            else:
                message = "Progetto convertito in carosello"
        sel = self._get_primary_selected()
        if sel is not None and sel in self.get_canvas_videos():
            self._update_video_info(sel)  # La durata massima è cambiata
        self._commit_history()
        self.statusBar().showMessage(message, 8000)

    # ================= PROGETTO (SALVA / APRI) =================
    def save_project(self) -> bool:
        if not self.project_path:
            return self.save_project_as()
        return self._write_project(self.project_path)

    def save_project_as(self) -> bool:
        path, _ = QFileDialog.getSaveFileName(
            self, "Salva progetto", self.project_path or f"collage{PROJECT_EXT}",
            f"Progetto ScrolleR (*{PROJECT_EXT})"
        )
        if not path:
            return False
        if not path.lower().endswith(PROJECT_EXT):
            path += PROJECT_EXT
        return self._write_project(path)

    def _project_data(self, snap: dict, base_dir: str) -> dict:
        def rel(p):
            try:
                # Con "/" il percorso relativo vale sia su Windows sia su Mac
                return os.path.relpath(p, base_dir).replace(os.sep, "/")
            except ValueError:  # Unità diversa su Windows
                return None

        canvas = dict(snap["canvas"])
        if canvas.get("bg_blur_path"):
            canvas["bg_blur_rel"] = rel(canvas["bg_blur_path"])
        return {
            "version": PROJECT_VERSION,
            "canvas": canvas,
            "library": [{"path": p, "rel": rel(p)} for p in self.loaded_library + self._missing_library],
            "items": [dict(s, rel=rel(s["path"])) for s in snap["items"]],
            "texts": snap.get("texts", []),
            "shapes": snap.get("shapes", []),
        }

    def _write_project(self, path: str) -> bool:
        self._flush_pending_commit()
        snap = self._history[self._history_index]
        data = self._project_data(snap, os.path.dirname(os.path.abspath(path)))
        try:
            with open(path, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=1)
        except OSError as e:
            QMessageBox.critical(self, "Progetto non salvato", f"Impossibile scrivere il file:\n{e}")
            return False
        self.project_path = path
        self._saved_snapshot = snap
        self._update_title()
        self._add_recent(path)
        self._remove_autosave()
        self.statusBar().showMessage(f"Progetto salvato: {os.path.basename(path)}", 3000)
        return True

    def new_project(self):
        """File → Nuovo progetto: si sceglie il formato, che dice anche se è un carosello o un reel."""
        if not self._confirm_discard_changes():
            return
        c = self._blank_snapshot["canvas"]
        dlg = NewProjectDialog(self.ASPECT_RATIOS, (c["frame_w"], c["frame_h"]), (c["custom_w"], c["custom_h"]),
                               c["num_frames"], self.MAX_PAGES, self)
        if dlg.exec():
            self._start_new_project(dlg.kind(), dlg.ratio_index(), dlg.frame_size(), dlg.pages())

    def _start_new_project(self, kind: str, ratio_index: int, size: tuple, pages: int):
        """Tela, libreria e impostazioni come all'avvio, con il tipo, il formato e le pagine scelti."""
        snap = json.loads(json.dumps(self._blank_snapshot))  # Copia: il punto di partenza non si tocca
        c = snap["canvas"]
        c["project_type"] = kind
        c["num_frames"] = 1 if kind == "reel" else max(1, min(self.MAX_PAGES, pages))
        c["ratio_index"] = ratio_index
        c["frame_w"], c["frame_h"] = size
        if list(self.ASPECT_RATIOS.values())[ratio_index] is None:
            c["custom_w"], c["custom_h"] = size
        self._restore_snapshot(snap)
        self.loaded_library.clear()
        self.list_library.clear()
        self._missing_library = []
        self._update_library_ui()
        self._reset_history("Nuovo progetto")
        self._forget_preview_pages()
        self.project_path = None
        self._saved_snapshot = self._history[-1]
        self._remove_autosave()
        self._update_title()
        self.fit_canvas_in_view()
        self._update_canvas_count()
        self.statusBar().showMessage("Nuovo progetto", 3000)

    def open_project(self):
        if not self._confirm_discard_changes():
            return
        path, _ = QFileDialog.getOpenFileName(self, "Apri progetto", "", f"Progetto ScrolleR (*{PROJECT_EXT})")
        if path:
            self._load_project_file(path)

    def _load_project_file(self, path: str, recovered: bool = False) -> bool:
        try:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
            canvas = data["canvas"]
            items = data["items"]
            texts = data.get("texts", [])
            shapes = data.get("shapes", [])
            library = data.get("library", [])
        except (OSError, ValueError, KeyError) as e:
            QMessageBox.critical(self, "Progetto non aperto", f"Il file non è un progetto valido:\n{e}")
            return False

        base_dir = os.path.dirname(os.path.abspath(path))

        def resolve(entry) -> str:
            # Prova il percorso assoluto, poi quello relativo al progetto (cartella spostata)
            if os.path.isfile(entry["path"]):
                return normalize_path(entry["path"])
            if entry.get("rel"):
                candidate = os.path.join(base_dir, entry["rel"].replace("\\", "/"))  # Anche progetti salvati su Windows
                if os.path.isfile(candidate):
                    return normalize_path(candidate)
            return normalize_path(entry["path"])

        for s in items:
            s["path"] = resolve(s)
        if canvas.get("bg_blur_path"):
            canvas["bg_blur_path"] = resolve({"path": canvas["bg_blur_path"], "rel": canvas.get("bg_blur_rel")})
        lib_paths = [resolve(e) for e in library]
        all_paths = list(dict.fromkeys(lib_paths + [s["path"] for s in items]))

        self._remove_all_photos()
        for t in self.get_canvas_texts() + self.get_canvas_shapes():
            self.scene.removeItem(t)
        self.loaded_library.clear()
        self.list_library.clear()
        # Le foto non trovate (spostate o rinominate) non si perdono: restano come segnaposto
        found = [p for p in all_paths if os.path.isfile(p)]
        for p in all_paths:
            if p not in found:
                IMAGE_CACHE.forget(p)
        self._missing_library = [p for p in dict.fromkeys(lib_paths) if not os.path.isfile(p)]
        _, errors = self._load_into_library(found, "Apertura progetto…")

        self._restore_snapshot({"canvas": canvas, "items": items, "texts": texts, "shapes": shapes})
        # Progetti di prima della divisione carosello/reel: sono caroselli, i video oltre 60 s usano il primo minuto
        trimmed = self._keep_videos_in_limit()
        self._reset_history("Lavoro recuperato" if recovered else "Progetto aperto")
        self._forget_preview_pages()
        if recovered:
            # Lavoro recuperato: resta "da salvare", con il nome del progetto originale se c'era
            original = data.get("original_path")
            self.project_path = original if original and os.path.isfile(original) else None
            self._saved_snapshot = None
        else:
            self.project_path = path
            self._saved_snapshot = self._history[-1]
            self._add_recent(path)
        self._update_title()
        self.fit_canvas_in_view()
        self._update_canvas_count()
        self._report_load_errors(errors)
        if trimmed:
            self.statusBar().showMessage("Carosello: i video più lunghi di 60 s usano il primo minuto. "
                                         "Scegli la parte con Inizio e Fine, o converti il progetto in reel.", 10000)
        missing = self._missing_paths()
        if missing:
            self._offer_relink(missing)
        return True

    # ---------- Progetti recenti ----------
    @staticmethod
    def _settings() -> QSettings:
        return QSettings("SCRL", "SCRL Studio")

    def _recent_projects(self) -> List[str]:
        value = self._settings().value("recent_projects", [])
        if isinstance(value, str):
            value = [value]
        return [p for p in (value or []) if isinstance(p, str)]

    def _add_recent(self, path: str):
        path = os.path.abspath(path)
        recent = [p for p in self._recent_projects() if os.path.normcase(p) != os.path.normcase(path)]
        self._settings().setValue("recent_projects", [path] + recent[:7])

    def _rebuild_recent_menu(self):
        menu = self.menu_recent
        menu.clear()
        paths = [p for p in self._recent_projects() if os.path.isfile(p)]
        if not paths:
            empty = menu.addAction("Nessun progetto recente")
            empty.setEnabled(False)
            return
        for i, path in enumerate(paths):
            act = menu.addAction(f"{i + 1}.  {os.path.basename(path)}")
            act.setToolTip(path)
            act.triggered.connect(lambda _c=False, q=path: self._open_recent(q))
        menu.addSeparator()
        menu.addAction("Svuota l'elenco").triggered.connect(lambda: self._settings().setValue("recent_projects", []))

    def _open_recent(self, path: str):
        if self._confirm_discard_changes():
            self._load_project_file(path)

    # ---------- Salvataggio automatico ----------
    @staticmethod
    def _autosave_path() -> str:
        base = QStandardPaths.writableLocation(QStandardPaths.StandardLocation.AppDataLocation) or tempfile.gettempdir()
        os.makedirs(base, exist_ok=True)
        return os.path.join(base, "salvataggio_automatico" + PROJECT_EXT)

    def _autosave(self):
        self._flush_pending_commit()
        if not self._history or not self._is_dirty() or not self._all_elements():
            return
        path = self._autosave_path()
        data = self._project_data(self._history[self._history_index], os.path.dirname(path))
        data["original_path"] = self.project_path
        try:
            with open(path, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False)
        except OSError:
            pass

    def _remove_autosave(self):
        try:
            os.remove(self._autosave_path())
        except OSError:
            pass

    def offer_recovery(self):
        """All'avvio: se l'app si era chiusa senza salvare, propone di recuperare il lavoro."""
        path = self._autosave_path()
        if not os.path.isfile(path):
            return
        answer = QMessageBox.question(
            self, "Recuperare il lavoro?",
            "L'ultima volta ScrolleR Studio si è chiuso senza salvare.\n"
            "Vuoi recuperare il collage su cui stavi lavorando?")
        if answer == QMessageBox.StandardButton.Yes:
            self._load_project_file(path, recovered=True)
        self._remove_autosave()

    def _confirm_discard_changes(self) -> bool:
        self._flush_pending_commit()
        if not self._is_dirty() or not self._all_elements():
            return True
        answer = QMessageBox.question(
            self, "Modifiche non salvate",
            "Il collage ha modifiche non salvate. Vuoi salvare il progetto?",
            QMessageBox.StandardButton.Save | QMessageBox.StandardButton.Discard | QMessageBox.StandardButton.Cancel,
        )
        if answer == QMessageBox.StandardButton.Save:
            return self.save_project()
        return answer == QMessageBox.StandardButton.Discard

    def closeEvent(self, event):
        if self._confirm_discard_changes():
            self._save_panel_widths()
            self._remove_autosave()
            event.accept()
        else:
            event.ignore()
