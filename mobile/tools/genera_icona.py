"""
Genera l'icona dell'app mobile dal logo del desktop (`scrollr/icons.py`), senza file immagine di partenza.

Uso, dalla root della repo e con l'ambiente Python del desktop:

    python mobile/tools/genera_icona.py

Il disegno è quello vero del desktop (`icon_pixmap("logo", ...)` e `app_icon_pixmap`), in modalità offscreen:
non si copia e non si ridisegna niente. Scrive, dentro `mobile/app/`:

- Android, tutte le densità: `ic_launcher.png` (icona quadrata arrotondata, per Android < 8) e, per Android 8+,
  l'icona adattiva: primo piano `ic_launcher_foreground.png` (il logo blu, dentro la zona sicura di 66 dp),
  monocromatica `ic_launcher_monochrome.png` (per le icone a tema di Android 13+) e il colore di fondo
  `values/ic_launcher_background.xml` (lo stesso scuro del desktop).
- iOS: tutte le misure di `AppIcon.appiconset` (quadrate e senza trasparenza: è iOS ad arrotondarle).

Il desktop non si modifica: lo script lo importa e basta (come `genera_riferimenti.py`).
"""

import json
import os
import sys

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

RADICE = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, RADICE)

from PyQt6.QtCore import QRectF, Qt  # noqa: E402
from PyQt6.QtGui import QColor, QGuiApplication, QPainter, QPixmap  # noqa: E402

from scrollr.icons import app_icon_pixmap, icon_pixmap  # noqa: E402
from scrollr.theme import THEME  # noqa: E402

APP = os.path.join(RADICE, "mobile", "app")
RES = os.path.join(APP, "android", "app", "src", "main", "res")
IOS = os.path.join(APP, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")

# Densità Android: nome → fattore rispetto a mdpi (48 dp per l'icona, 108 dp per l'adattiva)
DENSITA = {"mdpi": 1.0, "hdpi": 1.5, "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0}

# Il logo occupa 21×17 unità su 24: in un riquadro di 58 dp la diagonale è ~65 dp: sta dentro la zona sicura (cerchio da 66 dp)
LATO_LOGO_DP = 58.0


def salva(pm, percorso):
    os.makedirs(os.path.dirname(percorso), exist_ok=True)
    if not pm.save(percorso, "PNG"):
        raise RuntimeError(f"Non riesco a scrivere {percorso}")


def logo_su_tela(lato_tela: int, lato_logo: float, colore: str) -> QPixmap:
    """Il logo del desktop al centro di una tela trasparente quadrata."""
    pm = QPixmap(lato_tela, lato_tela)
    pm.fill(Qt.GlobalColor.transparent)
    lato = int(round(lato_logo))
    # `icon_pixmap` restituisce un pixmap a doppia risoluzione: si disegna in un riquadro di `lato` pixel veri
    logo = icon_pixmap("logo", colore, lato)
    p = QPainter(pm)
    p.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, True)
    x = (lato_tela - lato) / 2
    p.drawPixmap(QRectF(x, x, lato, lato), logo, QRectF(logo.rect()))
    p.end()
    return pm


def icona_ios(lato: int) -> QPixmap:
    """Quadrata, senza trasparenza: lo scuro del desktop a tutto campo con il logo blu (margine come `app_icon_pixmap`)."""
    pm = QPixmap(lato, lato)
    pm.fill(QColor(THEME["header"]))
    interno = int(round(lato * 0.84))
    logo = icon_pixmap("logo", THEME["accent"], interno)
    p = QPainter(pm)
    p.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, True)
    x = (lato - interno) / 2
    p.drawPixmap(QRectF(x, x, interno, interno), logo, QRectF(logo.rect()))
    p.end()
    return pm


def android():
    for nome, f in DENSITA.items():
        cartella = os.path.join(RES, f"mipmap-{nome}")
        # Android < 8: l'icona del desktop, quadrato scuro arrotondato con il logo
        salva(app_icon_pixmap(int(round(48 * f))), os.path.join(cartella, "ic_launcher.png"))
        lato = int(round(108 * f))
        logo = LATO_LOGO_DP * f
        salva(logo_su_tela(lato, logo, THEME["accent"]), os.path.join(cartella, "ic_launcher_foreground.png"))
        salva(logo_su_tela(lato, logo, "#FFFFFF"), os.path.join(cartella, "ic_launcher_monochrome.png"))
    adattiva = os.path.join(RES, "mipmap-anydpi-v26", "ic_launcher.xml")
    os.makedirs(os.path.dirname(adattiva), exist_ok=True)
    with open(adattiva, "w", encoding="utf-8", newline="\n") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@color/ic_launcher_background"/>\n'
            '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
            '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>\n'
            "</adaptive-icon>\n"
        )
    sfondo = os.path.join(RES, "values", "ic_launcher_background.xml")
    with open(sfondo, "w", encoding="utf-8", newline="\n") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            "<resources>\n"
            "    <!-- Lo scuro dell'icona del desktop (`THEME[\"header\"]` in scrollr/theme.py): generato da tools/genera_icona.py -->\n"
            f'    <color name="ic_launcher_background">{THEME["header"]}</color>\n'
            "</resources>\n"
        )


def ios():
    with open(os.path.join(IOS, "Contents.json"), encoding="utf-8") as f:
        contenuto = json.load(f)
    for img in contenuto["images"]:
        nome = img.get("filename")
        if not nome:
            continue
        lato = int(round(float(img["size"].split("x")[0]) * int(img["scale"].rstrip("x"))))
        salva(icona_ios(lato), os.path.join(IOS, nome))


_APP = None  # L'applicazione Qt deve restare viva finché si disegna


def main():
    global _APP
    _APP = QGuiApplication.instance() or QGuiApplication(sys.argv[:1])  # Serve a QPixmap, anche offscreen
    android()
    ios()
    print("Icone scritte in", os.path.relpath(APP, RADICE))


if __name__ == "__main__":
    main()
