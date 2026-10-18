"""Avvio dell'applicazione: python -m scrollr [progetto.scrlproj]"""
import os
import sys
from typing import Optional

from PyQt6.QtCore import QEvent, QTimer
from PyQt6.QtWidgets import QApplication

from scrollr import crashlog
from scrollr.config import PROJECT_EXT
from scrollr.icons import app_icon
from scrollr.theme import apply_app_style
from scrollr.window.main_window import MainWindow


class ScrollerApp(QApplication):
    """
    Su Mac il doppio clic su un progetto nel Finder non passa il file come argomento:
    arriva un QFileOpenEvent, anche prima che la finestra esista.
    """

    def __init__(self, argv):
        super().__init__(argv)
        self.window: Optional[MainWindow] = None
        self.pending_project: Optional[str] = None

    def event(self, e):
        if e.type() == QEvent.Type.FileOpen:
            path = e.file()
            if path.lower().endswith(PROJECT_EXT):
                if self.window is None:
                    self.pending_project = path
                else:
                    self.window._open_recent(path)
            return True
        return super().event(e)


def main():
    if sys.platform == "win32":
        # Senza un ID proprio Windows mostra l'icona di Python sulla barra delle applicazioni
        try:
            import ctypes
            ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID("SCRL.Studio")
        except Exception:
            pass
    app = ScrollerApp(sys.argv)
    # Nomi interni del vecchio "SCRL Studio": da qui dipendono la cartella del salvataggio automatico
    # (%APPDATA%\SCRL\SCRL Studio) e l'ID della barra delle applicazioni. Non cambiarli.
    app.setOrganizationName("SCRL")
    app.setApplicationName("SCRL Studio")
    crashlog.install()
    app.setWindowIcon(app_icon())
    apply_app_style(app)
    window = MainWindow()
    window.showMaximized()

    def open_startup_project():
        app.window = window
        # Doppio clic su un progetto: Windows lo passa come argomento, il Mac con un QFileOpenEvent
        project = app.pending_project or next(
            (a for a in sys.argv[1:] if a.lower().endswith(PROJECT_EXT) and os.path.isfile(a)), None)
        if project:
            window._load_project_file(project)
        else:
            window.offer_recovery()
        window.check_updates_on_startup()

    QTimer.singleShot(300, open_startup_project)
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
