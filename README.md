# ScrolleR Studio

Desktop editor for building photo collages and carousels for social media (side-by-side pages that scroll).

## Download

Get the Windows installer from the [Releases](https://github.com/Michelo1927/scrllr/releases/latest) page:
open the latest version and, under **Assets**, click `ScrolleR-Studio-Setup-<version>.exe`.

If Windows shows a warning, click "More info" → "Run anyway".

## Running from source

```
pip install -r requirements.txt
python main.py        # or: python -m scrollr
```

## Windows app (exe and installer)

```
python -m venv .venv
.venv\Scripts\python -m pip install -r requirements.txt pillow-heif pyinstaller
.venv\Scripts\python packaging\build.py
```

- `dist\ScrolleR Studio\ScrolleR Studio.exe`: the ready-to-run app, no Python needed.
- `dist\ScrolleR-Studio-Setup-<version>.exe`: the installer (Start menu, desktop icon, double-click to open `.scrlproj` files).
  Requires Inno Setup 6 (`winget install JRSoftware.InnoSetup`); with `--no-setup` only the folder is built.

The version is `__version__` in `scrollr/__init__.py`. Do not change the `AppId` in `packaging/scrl_studio.iss`: updates rely on it.

## Structure

```
main.py                 quick launcher (F5 in VS Code)
packaging/              Windows app build (PyInstaller + Inno Setup installer)
scrollr/
  __main__.py           creates the QApplication and the window
  config.py             supported extensions, project format, optional HEIC
  theme.py              palette, fonts, QSS stylesheet, Fusion style
  icons.py              code-drawn icons, thumbnails, badges
  imaging.py            photo loading (EXIF, ICC → sRGB), color adjustments, cache
  widgets.py            ToggleSwitch, DropZone, library delegate
  dialogs.py            carousel preview, background dialog
  canvas/
    photo_item.py       photos on the canvas (crop, inner zoom, borders, snapping)
    text_item.py        text boxes
    scene.py            pages, background, guides
    view.py             zoom, pan, file drag & drop
  window/
    main_window.py      MainWindow: state, canvas format, drag & drop
    ui.py, panels.py    UI construction
    library.py          photo library
    layouts.py          automatic layouts (grid, mosaic, polaroid, straddle…)
    inspector.py        editing selected items, align and distribute
    text.py, pages.py   carousel texts and pages
    history.py          undo / redo
    project.py          save / open, recent files, autosave
    export.py           high-resolution export
```

`MainWindow` is composed of mixins, one per area: each method lives in the file for its feature,
but they all share the same `self`.
