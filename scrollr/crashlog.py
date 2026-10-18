"""Registro degli errori: traccia dei crash in errori.log e avviso invece della chiusura improvvisa."""
import datetime
import faulthandler
import os
import sys
import tempfile
import traceback

from PyQt6.QtCore import QStandardPaths
from PyQt6.QtWidgets import QApplication, QMessageBox

from scrollr import __version__

_log_file = None  # Resta aperto: faulthandler ci scrive anche durante un crash del processo


def log_path() -> str:
    """%APPDATA%\\SCRL\\SCRL Studio\\errori.log (accanto al salvataggio automatico)."""
    base = QStandardPaths.writableLocation(QStandardPaths.StandardLocation.AppDataLocation) or tempfile.gettempdir()
    os.makedirs(base, exist_ok=True)
    return os.path.join(base, "errori.log")


def install():
    """Da chiamare dopo aver impostato organizzazione e nome dell'applicazione."""
    global _log_file
    path = log_path()
    try:
        if os.path.isfile(path) and os.path.getsize(path) > 512 * 1024:
            os.replace(path, path + ".old")  # Il registro non cresce all'infinito
        _log_file = open(path, "a", encoding="utf-8")
        _log_file.write(f"\n=== Avvio {datetime.datetime.now():%Y-%m-%d %H:%M:%S} — ScrolleR Studio {__version__} ===\n")
        _log_file.flush()
        # Crash nativi (es. dentro Qt): stack Python di tutti i thread nel registro
        faulthandler.enable(_log_file, all_threads=True)
    except OSError:
        _log_file = None
    # Con un excepthook proprio PyQt non chiude l'app su un errore Python dentro un'azione
    sys.excepthook = _on_exception


def _on_exception(exc_type, exc, tb):
    text = "".join(traceback.format_exception(exc_type, exc, tb))
    if _log_file is not None:
        try:
            _log_file.write(f"\n--- Errore {datetime.datetime.now():%H:%M:%S} ---\n{text}")
            _log_file.flush()
        except OSError:
            pass
    if sys.__stderr__ is not None:  # Nell'app impacchettata (senza console) non c'è
        sys.__stderr__.write(text)
    if QApplication.instance() is None:
        return
    box = QMessageBox(QApplication.activeWindow())
    box.setWindowTitle("Si è verificato un errore")
    box.setIcon(QMessageBox.Icon.Warning)
    box.setText("Qualcosa non ha funzionato, ma puoi continuare a lavorare.\n"
                "Se qualcosa sembra strano, usa Annulla o salva il progetto con un altro nome.")
    box.setInformativeText(f"I dettagli sono nel registro degli errori:\n{log_path()}")
    box.setDetailedText(text)
    box.exec()
