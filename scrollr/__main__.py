"""Avvio dell'applicazione: python -m scrollr [progetto.scrlproj]"""
import os
import sys

from PyQt6.QtCore import QTimer
from PyQt6.QtWidgets import QApplication

from scrollr.config import PROJECT_EXT
from scrollr.icons import app_icon
from scrollr.theme import apply_app_style
from scrollr.window.main_window import MainWindow


def main():
    if sys.platform == "win32":
        # Senza un ID proprio Windows mostra l'icona di Python sulla barra delle applicazioni
        try:
            import ctypes
            ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID("SCRL.Studio")
        except Exception:
            pass
    app = QApplication(sys.argv)
    # Nomi interni del vecchio "SCRL Studio": da qui dipendono la cartella del salvataggio automatico
    # (%APPDATA%\SCRL\SCRL Studio) e l'ID della barra delle applicazioni. Non cambiarli.
    app.setOrganizationName("SCRL")
    app.setApplicationName("SCRL Studio")
    app.setWindowIcon(app_icon())
    apply_app_style(app)
    window = MainWindow()
    window.showMaximized()
    # Doppio clic su un progetto in Esplora file: Windows lo passa come argomento
    project = next((a for a in sys.argv[1:] if a.lower().endswith(PROJECT_EXT) and os.path.isfile(a)), None)
    if project:
        QTimer.singleShot(300, lambda: window._load_project_file(project))
    else:
        QTimer.singleShot(300, window.offer_recovery)
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
