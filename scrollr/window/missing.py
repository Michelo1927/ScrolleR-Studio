"""Foto mancanti (spostate o rinominate): ricollegamento e raccolta del progetto in una cartella."""
import os
import shutil
from typing import Dict, List

from PyQt6.QtCore import Qt, QUrl
from PyQt6.QtGui import QDesktopServices
from PyQt6.QtWidgets import QApplication, QFileDialog, QMessageBox, QProgressDialog

from scrollr.config import IMAGE_EXTS, PROJECT_EXT
from scrollr.imaging import IMAGE_CACHE, normalize_path

MAX_SCAN_FILES = 50_000  # Limite di sicurezza nella ricerca dentro una cartella (es. un disco intero)


class MissingMixin:
    """Foto mancanti: segnaposto sulla tela, ricollegamento e raccolta del progetto."""

    # ---------- Quali foto mancano ----------
    def _missing_paths(self) -> List[str]:
        """Foto del progetto che non sono caricate: sulla tela, nella libreria o come sfondo sfocato."""
        paths = [p.image_path for p in self.get_canvas_photos()] + list(self._missing_library)
        if self.scene.bg_blur_path:
            paths.append(self.scene.bg_blur_path)
        return [p for p in dict.fromkeys(paths) if not IMAGE_CACHE.has(p)]

    def _missing_on_canvas(self) -> int:
        return sum(1 for p in self.get_canvas_photos() if p.is_missing)

    def _project_dir(self) -> str:
        return os.path.dirname(self.project_path) if self.project_path else ""

    def _offer_relink(self, missing: List[str]):
        """All'apertura di un progetto: avvisa delle foto non trovate e propone di cercarle."""
        n = len(missing)
        box = QMessageBox(self)
        box.setWindowTitle("Foto non trovate")
        box.setIcon(QMessageBox.Icon.Warning)
        box.setText("1 foto del progetto non è stata trovata." if n == 1
                    else f"{n} foto del progetto non sono state trovate.")
        box.setInformativeText(
            "Forse sono state spostate o rinominate. Restano sulla tela come «Foto mancante», con la loro "
            "posizione e le loro impostazioni, e non si perdono salvando.\n\n"
            "Indica la cartella dove si trovano ora: le cerco per nome, anche nelle sottocartelle.")
        box.setDetailedText("\n".join(missing))
        btn_search = box.addButton("Cerca in una cartella…", QMessageBox.ButtonRole.AcceptRole)
        box.addButton("Più tardi", QMessageBox.ButtonRole.RejectRole)
        box.setDefaultButton(btn_search)
        box.exec()
        if box.clickedButton() is btn_search:
            self.relink_missing_photos()

    # ---------- Ricollegamento ----------
    def relink_missing_photos(self):
        """File → Ricollega foto mancanti: cerca le foto per nome in una cartella scelta."""
        missing = self._missing_paths()
        if not missing:
            QMessageBox.information(self, "Foto mancanti", "Tutte le foto del progetto sono al loro posto.")
            return
        folder = QFileDialog.getExistingDirectory(
            self, "Dove si trovano ora le foto?", self._project_dir() or os.path.dirname(missing[0]))
        if not folder:
            return
        mapping = self._search_in_folder(folder, missing)
        self._apply_relink(mapping, len(missing))

    def _relink_selected_photo(self):
        """Clic destro su una foto mancante → Ricollega foto…: si sceglie il file a mano."""
        photo = next((p for p in self._selected_photos() if p.is_missing), None)
        if photo is None:
            return
        old = photo.image_path
        exts = " ".join("*" + e for e in IMAGE_EXTS)
        path, _ = QFileDialog.getOpenFileName(
            self, f"Dov'è ora «{os.path.basename(old)}»?", self._project_dir(), f"Immagini ({exts})")
        if not path:
            return
        mapping = {old: normalize_path(path)}
        # Le altre foto mancanti spesso sono finite nella stessa cartella: le cerca lì
        others = [m for m in self._missing_paths() if m != old]
        if others:
            mapping.update(self._search_in_folder(os.path.dirname(path), others))
        self._apply_relink(mapping, len(others) + 1)

    def _search_in_folder(self, folder: str, missing: List[str]) -> Dict[str, str]:
        """Cerca per nome (senza maiuscole/minuscole) le foto mancanti dentro `folder` e sottocartelle."""
        wanted: Dict[str, List[str]] = {}
        for m in missing:
            wanted.setdefault(os.path.basename(m).lower(), []).append(m)
        found: Dict[str, List[str]] = {}
        QApplication.setOverrideCursor(Qt.CursorShape.WaitCursor)
        try:
            scanned = 0
            for root, _dirs, files in os.walk(folder):
                for f in files:
                    if f.lower() in wanted:
                        found.setdefault(f.lower(), []).append(os.path.join(root, f))
                scanned += len(files)
                if scanned > MAX_SCAN_FILES:
                    break
        finally:
            QApplication.restoreOverrideCursor()

        mapping: Dict[str, str] = {}
        for name, olds in wanted.items():
            candidates = found.get(name, [])
            for old in olds:
                if not candidates:
                    continue
                # Con più file dallo stesso nome preferisce quello nella cartella con lo stesso nome di prima
                parent = os.path.basename(os.path.dirname(old)).lower()
                best = next((c for c in candidates if os.path.basename(os.path.dirname(c)).lower() == parent),
                            candidates[0])
                mapping[old] = normalize_path(best)
        return mapping

    def _apply_relink(self, mapping: Dict[str, str], wanted: int):
        """Carica i file ritrovati e sostituisce i vecchi percorsi ovunque (tela, libreria, cronologia)."""
        loaded, errors = self._load_into_library(list(dict.fromkeys(mapping.values())), "Ricollegamento foto…")
        mapping = {old: new for old, new in mapping.items() if new in loaded}
        self._remap_paths(mapping)
        self._report_load_errors(errors)

        still = self._missing_paths()
        if not mapping:
            msg = "Nessuna delle foto mancanti è stata trovata in quella cartella."
        else:
            msg = ("Ho ricollegato 1 foto." if len(mapping) == 1 else f"Ho ricollegato {len(mapping)} foto.")
            msg += " Salva il progetto per ricordare i nuovi percorsi."
        if still:
            msg += ("\n\nManca ancora 1 foto: " if len(still) == 1 else f"\n\nMancano ancora {len(still)} foto: ")
            msg += "puoi cercarla in un'altra cartella con File → Ricollega foto mancanti." if len(still) == 1 \
                else "puoi cercarle in un'altra cartella con File → Ricollega foto mancanti."
        QMessageBox.information(self, "Ricollega foto", msg)

    def _remap_paths(self, mapping: Dict[str, str]):
        """Sostituisce i percorsi delle foto ovunque: tela, sfondo, libreria e cronologia Annulla/Ripeti."""
        if not mapping:
            return
        for p in self.get_canvas_photos():
            if p.image_path in mapping:
                p.image_path = mapping[p.image_path]
                p._adjusted_cache = {}
                p.update()
        if self.scene.bg_blur_path in mapping:
            self.scene.bg_blur_path = mapping[self.scene.bg_blur_path]
        self._missing_library = [p for p in self._missing_library if p not in mapping]

        # Libreria: il nuovo percorso prende il posto del vecchio (o si aggiunge, se era mancante)
        for row in range(self.list_library.count()):
            item = self.list_library.item(row)
            old = item.data(Qt.ItemDataRole.UserRole)
            if old in mapping:
                new = mapping[old]
                item.setData(Qt.ItemDataRole.UserRole, new)
                item.setToolTip(os.path.basename(new))
        seen = set()
        library = []
        for p in self.loaded_library:
            p = mapping.get(p, p)
            if p not in seen:
                seen.add(p)
                library.append(p)
        self.loaded_library[:] = library
        # Doppioni nati dalla sostituzione (la stessa foto ritrovata due volte): resta la prima
        seen, duplicates = set(), []
        for row in range(self.list_library.count()):
            path = self.list_library.item(row).data(Qt.ItemDataRole.UserRole)
            if path in seen:
                duplicates.append(row)
            seen.add(path)
        for row in reversed(duplicates):
            self.list_library.takeItem(row)

        def remap_snap(snap: dict) -> dict:
            canvas = dict(snap["canvas"])
            if canvas.get("bg_blur_path") in mapping:
                canvas["bg_blur_path"] = mapping[canvas["bg_blur_path"]]
            return {"canvas": canvas,
                    "items": [dict(s, path=mapping.get(s["path"], s["path"])) for s in snap["items"]],
                    "texts": snap.get("texts", [])}

        # Copie nuove degli snapshot: quello salvato resta diverso, così il progetto risulta da salvare
        self._history = [remap_snap(s) for s in self._history]
        self.scene._blur_cache = None
        self.scene.update()
        self._update_library_ui()
        self._update_canvas_count()
        self._update_title()

    # ---------- Raccolta del progetto ----------
    def collect_project(self):
        """
        File → Raccogli progetto: copia il progetto e tutte le sue foto in una cartella nuova
        (progetto + sottocartella «Foto»), comoda da spostare, archiviare o passare a qualcuno.
        """
        self._flush_pending_commit()
        sources = [p for p in dict.fromkeys(
            list(self.loaded_library) + [p.image_path for p in self.get_canvas_photos()]
            + ([self.scene.bg_blur_path] if self.scene.bg_blur_path else [])) if os.path.isfile(p)]
        if not sources:
            QMessageBox.information(self, "Raccogli progetto", "Non ci sono foto da raccogliere.")
            return
        parent = QFileDialog.getExistingDirectory(
            self, "Dove creo la cartella del progetto?", self._project_dir())
        if not parent:
            return
        stem = os.path.splitext(os.path.basename(self.project_path))[0] if self.project_path else "Progetto"
        target = self._unique_path(os.path.join(parent, stem))
        photos_dir = os.path.join(target, "Foto")

        progress = QProgressDialog("Copia delle foto…", "Annulla", 0, len(sources), self)
        progress.setWindowTitle("Raccogli progetto")
        progress.setWindowModality(Qt.WindowModality.WindowModal)
        progress.setMinimumDuration(300)
        mapping: Dict[str, str] = {}
        try:
            os.makedirs(photos_dir)
            used = set()
            for i, src in enumerate(sources):
                if progress.wasCanceled():
                    break
                progress.setValue(i)
                progress.setLabelText(f"Copia delle foto…\n{os.path.basename(src)}  ({i + 1} di {len(sources)})")
                QApplication.processEvents()
                dst = self._unique_name(photos_dir, os.path.basename(src), used)
                shutil.copy2(src, dst)
                mapping[src] = normalize_path(dst)
        except OSError as e:
            progress.close()
            QMessageBox.critical(self, "Raccogli progetto", f"Copia non riuscita:\n{e}")
            return
        progress.setValue(len(sources))
        if len(mapping) < len(sources):
            QMessageBox.information(self, "Raccogli progetto",
                                    f"Copia annullata. Le foto già copiate sono in:\n{target}")
            return

        for old, new in mapping.items():
            IMAGE_CACHE.alias(old, new)
        self._remap_paths(mapping)
        project_file = os.path.join(target, os.path.basename(target) + PROJECT_EXT)
        if not self._write_project(project_file):
            return

        missing = self._missing_paths()
        box = QMessageBox(self)
        box.setWindowTitle("Progetto raccolto")
        box.setIcon(QMessageBox.Icon.Information)
        box.setText(f"Progetto e {len(mapping)} foto copiati in:\n{target}")
        info = "Da ora stai lavorando sulla copia raccolta: puoi spostare o copiare la cartella intera."
        if missing:
            info += (f"\n\n{len(missing)} foto mancanti non sono state copiate: "
                     "ricollegale e raccogli di nuovo.")
        box.setInformativeText(info)
        btn_open = box.addButton("Apri cartella", QMessageBox.ButtonRole.ActionRole)
        box.addButton(QMessageBox.StandardButton.Ok)
        box.exec()
        if box.clickedButton() is btn_open:
            QDesktopServices.openUrl(QUrl.fromLocalFile(target))

    @staticmethod
    def _unique_path(path: str) -> str:
        """`path`, oppure `path (2)`, `path (3)`… se esiste già."""
        candidate, n = path, 2
        while os.path.exists(candidate):
            candidate = f"{path} ({n})"
            n += 1
        return candidate

    @staticmethod
    def _unique_name(folder: str, name: str, used: set) -> str:
        """Nome libero nella cartella: con due foto omonime da cartelle diverse aggiunge _2, _3…"""
        stem, ext = os.path.splitext(name)
        candidate, n = name, 2
        while candidate.lower() in used:
            candidate = f"{stem}_{n}{ext}"
            n += 1
        used.add(candidate.lower())
        return os.path.join(folder, candidate)
