"""
Crea l'app di ScrolleR Studio per il sistema su cui gira (Windows o Mac).

Windows:
    .venv\\Scripts\\python packaging\\build.py            # exe + installer
    .venv\\Scripts\\python packaging\\build.py --no-setup # solo la cartella con l'exe
    -> dist\\ScrolleR Studio\\ScrolleR Studio.exe          app pronta da avviare
    -> dist\\ScrolleR-Studio-Setup-<versione>.exe         installer (richiede Inno Setup 6)

Mac:
    .venv/bin/python packaging/build.py                 # .app + .dmg
    -> dist/ScrolleR Studio.app                         app pronta da avviare
    -> dist/ScrolleR-Studio-<versione>-mac.dmg          immagine disco da distribuire
"""
import io
import os
import plistlib
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HERE = os.path.join(ROOT, "packaging")
BUILD = os.path.join(ROOT, "build")
DIST = os.path.join(ROOT, "dist")
APP_NAME = "ScrolleR Studio"
BUNDLE_ID = "io.github.michelo1927.scrollr-studio"
IS_MAC = sys.platform == "darwin"

sys.path.insert(0, ROOT)
from scrollr import __version__  # noqa: E402
from scrollr.config import PROJECT_EXT  # noqa: E402


def icon_images(sizes, margin: float = 0.0):
    """Icona disegnata a codice, come immagini Pillow delle dimensioni richieste."""
    os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
    from PyQt6.QtCore import QBuffer, QIODevice
    from PyQt6.QtWidgets import QApplication
    from PIL import Image

    from scrollr.icons import app_icon_pixmap

    app = QApplication.instance() or QApplication([])
    images = []
    for size in sizes:
        buf = QBuffer()
        buf.open(QIODevice.OpenModeFlag.WriteOnly)
        app_icon_pixmap(size, margin).toImage().save(buf, "PNG")
        images.append(Image.open(io.BytesIO(bytes(buf.data()))).convert("RGBA"))
    del app
    return images


def make_ico(path: str):
    """File .ico per Windows, una risoluzione per ogni formato."""
    images = icon_images((256, 128, 64, 48, 40, 32, 24, 20, 16))
    images[0].save(path, format="ICO", sizes=[im.size for im in images], append_images=images[1:])


def make_icns(path: str):
    """File .icns per Mac: Pillow ricava le varie risoluzioni dall'immagine a 1024 px."""
    icon_images((1024,), margin=0.1)[0].save(path, format="ICNS")


def make_version_file(path: str):
    """Informazioni mostrate in Proprietà → Dettagli dell'exe (solo Windows)."""
    nums = tuple(int(n) for n in (__version__.split(".") + ["0"] * 4)[:4])
    text = f"""VSVersionInfo(
  ffi=FixedFileInfo(filevers={nums}, prodvers={nums}),
  kids=[
    StringFileInfo([StringTable('041004B0', [
      StringStruct('CompanyName', 'ScrolleR'),
      StringStruct('FileDescription', '{APP_NAME}'),
      StringStruct('FileVersion', '{__version__}'),
      StringStruct('InternalName', '{APP_NAME}'),
      StringStruct('OriginalFilename', '{APP_NAME}.exe'),
      StringStruct('ProductName', '{APP_NAME}'),
      StringStruct('ProductVersion', '{__version__}')])]),
    VarFileInfo([VarStruct('Translation', [0x0410, 1200])])
  ]
)
"""
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def run_pyinstaller(icon: str, extra: list):
    cmd = [
        sys.executable, "-m", "PyInstaller",
        "--noconfirm", "--clean", "--windowed",
        "--name", APP_NAME,
        "--icon", icon,
        "--workpath", os.path.join(BUILD, "pyinstaller"),
        "--specpath", BUILD,
        "--distpath", DIST,
        "--collect-submodules", "scrollr",
        "--hidden-import", "pillow_heif",
        *extra,
        os.path.join(ROOT, "main.py"),
    ]
    subprocess.run(cmd, check=True, cwd=ROOT)


# ================= WINDOWS =================
def find_iscc() -> str:
    candidates = [
        shutil.which("ISCC"),
        os.path.join(os.environ.get("ProgramFiles(x86)", ""), "Inno Setup 6", "ISCC.exe"),
        os.path.join(os.environ.get("ProgramFiles", ""), "Inno Setup 6", "ISCC.exe"),
        os.path.join(os.environ.get("LOCALAPPDATA", ""), "Programs", "Inno Setup 6", "ISCC.exe"),
    ]
    return next((c for c in candidates if c and os.path.isfile(c)), "")


def run_inno_setup(icon: str):
    iscc = find_iscc()
    if not iscc:
        print("\nInno Setup 6 non trovato: creata solo la cartella dell'app."
              "\nPer l'installer: winget install JRSoftware.InnoSetup")
        return
    subprocess.run([
        iscc, "/Qp",
        f"/DAppVersion={__version__}",
        f"/DSourceDir={os.path.join(DIST, APP_NAME)}",
        f"/DOutputDir={DIST}",
        f"/DIconFile={icon}",
        os.path.join(HERE, "scrl_studio.iss"),
    ], check=True)


def build_windows():
    icon = os.path.join(BUILD, "scrl_studio.ico")
    version_file = os.path.join(BUILD, "version_info.txt")
    make_ico(icon)
    make_version_file(version_file)
    run_pyinstaller(icon, ["--version-file", version_file])
    if "--no-setup" not in sys.argv:
        run_inno_setup(icon)
    print(f"\nFatto. App: {os.path.join(DIST, APP_NAME, APP_NAME + '.exe')}")


# ================= MAC =================
def patch_info_plist(app: str):
    """Versione, supporto Retina e apertura dei progetti .scrlproj con doppio clic nel Finder."""
    path = os.path.join(app, "Contents", "Info.plist")
    with open(path, "rb") as f:
        info = plistlib.load(f)
    uti = BUNDLE_ID + ".project"
    info.update({
        "CFBundleDisplayName": APP_NAME,
        "CFBundleShortVersionString": __version__,
        "CFBundleVersion": __version__,
        "NSHighResolutionCapable": True,
        "LSMinimumSystemVersion": "11.0",
        "UTExportedTypeDeclarations": [{
            "UTTypeIdentifier": uti,
            "UTTypeDescription": "Progetto ScrolleR Studio",
            "UTTypeConformsTo": ["public.json", "public.data"],
            "UTTypeTagSpecification": {"public.filename-extension": [PROJECT_EXT.lstrip(".")]},
        }],
        "CFBundleDocumentTypes": [{
            "CFBundleTypeName": "Progetto ScrolleR Studio",
            "CFBundleTypeRole": "Editor",
            "LSHandlerRank": "Owner",
            "LSItemContentTypes": [uti],
        }],
    })
    with open(path, "wb") as f:
        plistlib.dump(info, f)


def make_dmg(app: str) -> str:
    """Immagine disco con l'app e il collegamento ad Applicazioni, da trascinare per installare."""
    staging = os.path.join(BUILD, "dmg")
    shutil.rmtree(staging, ignore_errors=True)
    os.makedirs(staging)
    shutil.copytree(app, os.path.join(staging, os.path.basename(app)), symlinks=True)
    os.symlink("/Applications", os.path.join(staging, "Applications"))
    dmg = os.path.join(DIST, f"ScrolleR-Studio-{__version__}-mac.dmg")
    if os.path.exists(dmg):
        os.remove(dmg)
    subprocess.run(["hdiutil", "create", "-volname", APP_NAME, "-srcfolder", staging,
                    "-ov", "-format", "UDZO", dmg], check=True)
    return dmg


def build_mac():
    icon = os.path.join(BUILD, "scrl_studio.icns")
    make_icns(icon)
    run_pyinstaller(icon, ["--osx-bundle-identifier", BUNDLE_ID])
    app = os.path.join(DIST, APP_NAME + ".app")
    patch_info_plist(app)
    # Info.plist modificato: va rifirmata (firma "ad hoc", senza certificato Apple)
    subprocess.run(["codesign", "--force", "--deep", "--sign", "-", app], check=True)
    dmg = make_dmg(app)
    print(f"\nFatto. App: {app}\nImmagine disco: {dmg}")


def main():
    os.makedirs(BUILD, exist_ok=True)
    if IS_MAC:
        build_mac()
    else:
        build_windows()


if __name__ == "__main__":
    main()
