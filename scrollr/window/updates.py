"""Avviso di nuova versione: controllo leggero dell'ultima release su GitHub."""
import json
import re
import time
from typing import Optional, Tuple

from PyQt6.QtCore import Qt, QUrl
from PyQt6.QtGui import QDesktopServices
from PyQt6.QtNetwork import QNetworkAccessManager, QNetworkReply, QNetworkRequest
from PyQt6.QtWidgets import QMessageBox, QToolButton

from scrollr import __version__
from scrollr.config import REPO_URL
from scrollr.icons import make_icon
from scrollr.theme import THEME

# API pubblica di GitHub: ultima release non bozza e non pre-release
LATEST_API = REPO_URL.replace("https://github.com/", "https://api.github.com/repos/") + "/releases/latest"
CHECK_INTERVAL = 24 * 3600  # All'avvio, al massimo una volta al giorno


def parse_version(text: str) -> Tuple[int, ...]:
    """"v1.2.0" → (1, 2, 0); le parti non numeriche vengono ignorate."""
    return tuple(int(n) for n in re.findall(r"\d+", text)[:3])


class UpdatesMixin:
    """Controllo degli aggiornamenti all'avvio e dal menu ?."""

    def _build_update_notice(self):
        """Pulsante nella barra di stato, visibile solo quando c'è una versione nuova."""
        self._net = QNetworkAccessManager(self)
        self._latest_release: Optional[dict] = None
        self.btn_update = QToolButton()
        self.btn_update.setObjectName("SoftButton")
        self.btn_update.setIcon(make_icon("download", THEME["accent_hover"], 16))
        self.btn_update.setToolButtonStyle(Qt.ToolButtonStyle.ToolButtonTextBesideIcon)
        self.btn_update.clicked.connect(self._show_update_dialog)
        self.btn_update.setVisible(False)
        self.statusBar().addPermanentWidget(self.btn_update)

    def _auto_update_enabled(self) -> bool:
        return self._settings().value("update_check", True, type=bool)

    def _set_auto_update(self, enabled: bool):
        self._settings().setValue("update_check", enabled)

    def check_updates_on_startup(self):
        if not self._auto_update_enabled():
            return
        last = self._settings().value("update_last_check", 0.0, type=float)
        if time.time() - last < CHECK_INTERVAL:
            # Controllato da poco: ripropone l'avviso già noto senza tornare in rete
            cached = self._settings().value("update_latest", "", type=str)
            if cached and parse_version(cached) > parse_version(__version__):
                self._latest_release = {"tag_name": cached, "html_url": REPO_URL + "/releases/latest", "body": ""}
                self._show_update_notice(manual=False)
            return
        self._request_latest(manual=False)

    def check_updates_now(self):
        """Voce di menu: controlla subito e risponde sempre, anche se non c'è niente di nuovo."""
        self.statusBar().showMessage("Controllo degli aggiornamenti…", 3000)
        self._request_latest(manual=True)

    def _request_latest(self, manual: bool):
        req = QNetworkRequest(QUrl(LATEST_API))
        req.setRawHeader(b"Accept", b"application/vnd.github+json")
        req.setRawHeader(b"User-Agent", f"ScrolleR-Studio/{__version__}".encode())
        req.setTransferTimeout(8000)
        reply = self._net.get(req)
        reply.finished.connect(lambda: self._on_latest_reply(reply, manual))

    def _on_latest_reply(self, reply: QNetworkReply, manual: bool):
        reply.deleteLater()
        if reply.error() != QNetworkReply.NetworkError.NoError:
            # Senza rete o con GitHub irraggiungibile all'avvio non si disturba l'utente
            if manual:
                QMessageBox.warning(self, "Aggiornamenti",
                                    "Non è stato possibile controllare gli aggiornamenti.\n"
                                    "Verifica la connessione a internet e riprova.")
            return
        try:
            data = json.loads(bytes(reply.readAll()).decode("utf-8"))
            tag = str(data["tag_name"])
        except (ValueError, KeyError, TypeError):
            if manual:
                QMessageBox.warning(self, "Aggiornamenti", "Risposta inattesa da GitHub: riprova più tardi.")
            return
        self._settings().setValue("update_last_check", time.time())
        self._settings().setValue("update_latest", tag)
        self._latest_release = data
        if parse_version(tag) > parse_version(__version__):
            self._show_update_notice(manual)
        else:
            self.btn_update.setVisible(False)
            if manual:
                QMessageBox.information(self, "Aggiornamenti",
                                        f"Hai già l'ultima versione di ScrolleR Studio ({__version__}).")

    def _show_update_notice(self, manual: bool):
        tag = self._latest_release["tag_name"]
        if not manual and self._settings().value("update_skipped", "", type=str) == tag:
            return  # Versione saltata dall'utente: niente avviso finché non ne esce un'altra
        self.btn_update.setText(f"Versione {tag.lstrip('vV')} disponibile")
        self.btn_update.setToolTip("Scopri le novità e scarica la nuova versione")
        self.btn_update.setVisible(True)
        if manual:
            self._show_update_dialog()
        else:
            self.statusBar().showMessage(f"È disponibile ScrolleR Studio {tag.lstrip('vV')}", 8000)

    def _show_update_dialog(self):
        rel = self._latest_release
        if not rel:
            return
        tag = rel["tag_name"].lstrip("vV")
        notes = (rel.get("body") or "").strip()
        if len(notes) > 900:
            notes = notes[:900].rstrip() + "…"
        box = QMessageBox(self)
        box.setWindowTitle("Nuova versione disponibile")
        box.setIcon(QMessageBox.Icon.Information)
        box.setText(f"È disponibile ScrolleR Studio {tag} (tu hai la {__version__}).")
        box.setInformativeText("Scarica il programma di installazione dalla pagina della release: "
                               "i tuoi progetti e le impostazioni restano come sono.")
        if notes:
            box.setDetailedText(notes)
        btn_download = box.addButton("Scarica", QMessageBox.ButtonRole.AcceptRole)
        btn_skip = box.addButton("Salta questa versione", QMessageBox.ButtonRole.DestructiveRole)
        box.addButton("Più tardi", QMessageBox.ButtonRole.RejectRole)
        box.setDefaultButton(btn_download)
        box.exec()
        clicked = box.clickedButton()
        if clicked is btn_download:
            QDesktopServices.openUrl(QUrl(rel.get("html_url") or REPO_URL + "/releases/latest"))
        elif clicked is btn_skip:
            self._settings().setValue("update_skipped", rel["tag_name"])
            self.btn_update.setVisible(False)
