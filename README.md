# ScrolleR Studio

Desktop editor for building photo collages and carousels for social media (side-by-side pages that scroll).

## Download

Open the [latest release](https://github.com/Michelo1927/ScrolleR-Studio/releases/latest) and, under **Assets**, download:

- **Windows:** `ScrolleR-Studio-Setup-<version>.exe` and run it.
  If Windows shows a warning, click "More info" → "Run anyway".
- **Mac** (Apple Silicon, macOS 11 or later): `ScrolleR-Studio-<version>-mac.dmg`, open it and drag
  ScrolleR Studio into Applications. The app is not signed by Apple, so the first time macOS blocks it:
  open **System Settings → Privacy & Security** and click **Open Anyway**.

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

## Mac app (.app and .dmg)

On a Mac the same script builds `dist/ScrolleR Studio.app` and `dist/ScrolleR-Studio-<version>-mac.dmg`:

```
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt pillow-heif pyinstaller
.venv/bin/python packaging/build.py
```

## Releases (GitHub Actions)

`.github/workflows/build.yml` builds both versions on GitHub's Windows and Mac machines:

- push a tag like `v1.1.0` → the release is created with the Windows installer and the Mac `.dmg` attached;
- **Actions → Build → Run workflow** → test build only; the files are downloadable from the run page.

Before tagging, set the same version in `__version__` (`scrollr/__init__.py`) and write the release notes
(in Italian) in `release-notes/v<version>.md`: the release is titled "ScrolleR Studio <version>" and uses that
file as its description, which the app also shows in its new-version notice.
Do not change the `AppId` in `packaging/scrl_studio.iss`: Windows updates rely on it.

## Structure

```
main.py                 quick launcher (F5 in VS Code)
.github/workflows/      automatic Windows + Mac builds and releases
packaging/              app build (PyInstaller; Inno Setup installer on Windows, .dmg on Mac)
scrollr/
  __main__.py           creates the QApplication and the window, opens double-clicked projects
  config.py             supported extensions, project format, optional HEIC
  crashlog.py           error log (errori.log in the app data folder) and error notice instead of a crash
  keys.py               shortcut texts per platform (Ctrl on Windows, ⌘ on Mac)
  theme.py              palette, fonts, QSS stylesheet, Fusion style
  icons.py              code-drawn icons, thumbnails, badges
  imaging.py            photo loading (EXIF, ICC → sRGB), color adjustments, cache
  widgets.py            ToggleSwitch, DropZone, library delegate
  dialogs.py            carousel preview, background dialog
  canvas/
    photo_item.py       photos on the canvas (crop, inner zoom, borders, snapping)
    text_item.py        text boxes
    scene.py            pages, background, guides
    view.py             zoom, pan, scroll bars, file drag & drop
    page_grid.py        pages shown as a grid (one view per page of the same canvas)
  window/
    main_window.py      MainWindow: state, canvas format, drag & drop
    ui.py, panels.py    UI construction
    library.py          photo library
    layouts.py          automatic layouts (grid, mosaic, polaroid, straddle…)
    inspector.py        editing selected items, align and distribute
    text.py, pages.py   carousel texts and pages
    history.py          undo / redo
    project.py          save / open, recent files, autosave
    missing.py          missing photos: placeholders, relinking, collect project into a folder
    export.py           high-resolution export
    updates.py          new-version notice (checks the latest GitHub release)
```

`MainWindow` is composed of mixins, one per area: each method lives in the file for its feature,
but they all share the same `self`.

## License

[MIT](LICENSE)
