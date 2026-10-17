"""Avvio dell'applicazione: python -m scrollr"""
import sys

from PyQt6.QtCore import QTimer
from PyQt6.QtWidgets import QApplication

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
    app.setOrganizationName("SCRL")
    app.setApplicationName("SCRL Studio")
    app.setWindowIcon(app_icon())
    apply_app_style(app)
    window = MainWindow()
    window.showMaximized()
    QTimer.singleShot(300, window.offer_recovery)
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
