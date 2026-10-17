"""
Crea l'app Windows di ScrolleR Studio.

    .venv\\Scripts\\python packaging\\build.py            # exe + installer
    .venv\\Scripts\\python packaging\\build.py --no-setup # solo la cartella con l'exe

Risultati:
    dist\\ScrolleR Studio\\ScrolleR Studio.exe       app pronta da avviare
    dist\\ScrolleR-Studio-Setup-<versione>.exe      installer (richiede Inno Setup 6)
"""
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HERE = os.path.join(ROOT, "packaging")
BUILD = os.path.join(ROOT, "build")
DIST = os.path.join(ROOT, "dist")
APP_NAME = "ScrolleR Studio"

sys.path.insert(0, ROOT)
from scrollr import __version__  # noqa: E402


def make_icon(path: str):
    """Ricava il file .ico dall'icona disegnata a codice, una risoluzione per ogni formato."""
    os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
    from PyQt6.QtCore import QBuffer, QIODevice
    from PyQt6.QtWidgets import QApplication
    from PIL import Image
    import io

    from scrollr.icons import app_icon

    app = QApplication.instance() or QApplication([])
    icon = app_icon()
    images = []
    for size in (256, 128, 64, 48, 40, 32, 24, 20, 16):
        buf = QBuffer()
        buf.open(QIODevice.OpenModeFlag.WriteOnly)
        icon.pixmap(size, size).toImage().save(buf, "PNG")
        img = Image.open(io.BytesIO(bytes(buf.data()))).convert("RGBA")
        if img.size != (size, size):
            img = img.resize((size, size), Image.Resampling.LANCZOS)
        images.append(img)
    images[0].save(path, format="ICO", sizes=[im.size for im in images], append_images=images[1:])
    del app


def make_version_file(path: str):
    """Informazioni mostrate in Proprietà → Dettagli dell'exe."""
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


def run_pyinstaller(icon: str, version_file: str):
    cmd = [
        sys.executable, "-m", "PyInstaller",
        "--noconfirm", "--clean", "--windowed",
        "--name", APP_NAME,
        "--icon", icon,
        "--version-file", version_file,
        "--workpath", os.path.join(BUILD, "pyinstaller"),
        "--specpath", BUILD,
        "--distpath", DIST,
        "--collect-submodules", "scrollr",
        "--hidden-import", "pillow_heif",
        os.path.join(ROOT, "main.py"),
    ]
    subprocess.run(cmd, check=True, cwd=ROOT)


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


def main():
    os.makedirs(BUILD, exist_ok=True)
    icon = os.path.join(BUILD, "scrl_studio.ico")
    version_file = os.path.join(BUILD, "version_info.txt")
    make_icon(icon)
    make_version_file(version_file)
    run_pyinstaller(icon, version_file)
    if "--no-setup" not in sys.argv:
        run_inno_setup(icon)
    print(f"\nFatto. App: {os.path.join(DIST, APP_NAME, APP_NAME + '.exe')}")


if __name__ == "__main__":
    main()
