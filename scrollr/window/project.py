"""Salvataggio e apertura progetti, recenti e salvataggio automatico."""
import json
import os
import tempfile
from typing import List

from PyQt6.QtCore import QSettings, QStandardPaths
from PyQt6.QtWidgets import QFileDialog, QMessageBox

from scrollr.config import PROJECT_EXT, PROJECT_VERSION
from scrollr.imaging import IMAGE_CACHE, normalize_path


class ProjectMixin:
    """Salvataggio e apertura progetti, recenti e salvataggio automatico."""

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
        """File → Nuovo progetto: tela, libreria e impostazioni tornano come all'avvio."""
        if not self._confirm_discard_changes():
            return
        self._restore_snapshot(self._blank_snapshot)
        self.loaded_library.clear()
        self.list_library.clear()
        self._missing_library = []
        self._update_library_ui()
        self._reset_history("Nuovo progetto")
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
        self._reset_history("Lavoro recuperato" if recovered else "Progetto aperto")
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
            self._remove_autosave()
            event.accept()
        else:
            event.ignore()
