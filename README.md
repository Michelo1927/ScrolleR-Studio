# ScrolleR Studio

Desktop editor for building photo collages and carousels for social media (side-by-side pages that scroll).

Videos can go on the canvas too: a page that contains a video is exported as an MP4
(H.264 + AAC, 30 fps, up to 60 s), with the rest of the page around it. Each video can be trimmed,
muted and given a cover frame; shorter videos on the same page loop until the longest one ends.
A video always stays inside one page (it cannot straddle two).

## Download

Open the [latest release](https://github.com/Michelo1927/ScrolleR-Studio/releases/latest) and, under **Assets**, download:

- **Windows:** `ScrolleR-Studio-Setup-<version>.exe` and run it.
  If Windows shows a warning, click "More info" → "Run anyway".
- **Mac** (Apple Silicon, macOS 11 or later): `ScrolleR-Studio-<version>-mac.dmg`, open it and drag
  ScrolleR Studio into Applications. The app is not signed by Apple, so the first time macOS blocks it:
  open **System Settings → Privacy & Security** and click **Open Anyway**.

## Mobile app (Android)

ScrolleR Studio Mobile is the phone version, built with Flutter in [`mobile/`](mobile/). It uses the same
`.scrlproj` project format as the desktop app, so a project made on either one opens on the other
(**Share project** on the phone writes a `.zip` the desktop opens; the desktop's "Collect project" zip opens on the phone).

- One page at a time, tools that rise from the bottom; photos from the gallery are linked, never copied or deleted.
- Layouts, photo tools, texts and shapes, videos, page and carousel actions, export to PNG / JPG / MP4: the same
  results as the desktop app.
- Accessible: labels for screen readers (TalkBack) on every command, AA contrast, text that follows the system size up to 1.3×,
  and it respects "remove animations". **Settings → Gestures** explains the gestures.
- No ads, no tracking, no accounts. The network is only used to look for a new version once a day (it can be turned off in
  Settings). Unexpected errors go to a local log that is only shared if you choose to.

**Download:** on the [Releases](https://github.com/Michelo1927/ScrolleR-Studio/releases) page, pick the release tagged
`mobile-v<version>` ("ScrolleR Studio Mobile <version>") and install `ScrolleR-Studio-Mobile-<version>.apk`.
Mobile releases are never marked as "latest", so the **latest release** above stays the desktop one and the desktop app's
update check is not affected; the mobile app only looks at `mobile-v*` tags. An iPhone version is not available yet.

```
cd mobile/app
flutter pub get
flutter run
```

Checks before a commit: `flutter analyze --fatal-infos` and `flutter test` in `mobile/app` (plus `dart analyze` and
`dart test` in `mobile/packages/scrl_engine`). The app icon is drawn from the desktop logo:
`python mobile/tools/genera_icona.py`. Mobile releases use their own workflow, `.github/workflows/mobile.yml`, which runs only on `mobile-v*`
tags; write the release notes (in Italian) in `release-notes/mobile-v<version>.md` before tagging. The full plan is in
[`docs/piano-app-mobile.md`](docs/piano-app-mobile.md).

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
mobile/                 Flutter app for Android (and iOS): app/ (UI), packages/scrl_engine (pure-Dart engine),
                        packages/scrl_video (video plugin), tools/ (reference data and icon generated from the desktop)
scrollr/
  __main__.py           creates the QApplication and the window, opens double-clicked projects
  config.py             supported extensions, project format, optional HEIC
  crashlog.py           error log (errori.log in the app data folder) and error notice instead of a crash
  keys.py               shortcut texts per platform (Ctrl on Windows, ⌘ on Mac)
  theme.py              palette, fonts, QSS stylesheet, Fusion style
  icons.py              code-drawn icons, thumbnails, badges
  shapes.py             graphic shapes: list and geometry (used by the canvas and the icons)
  imaging.py            photo loading (EXIF, ICC → sRGB), color adjustments, cache
  video.py              videos with PyAV: info, frames, audio, MP4 writing
  widgets.py            ToggleSwitch, DropZone, library delegate
  dialogs.py            carousel preview, page order, pages to export, background dialog
  crop_dialog.py        "Crop photo" window: crop area with handles and ready-made aspect ratios
  canvas/
    photo_item.py       photos on the canvas (crop, inner zoom, borders, snapping)
    video_item.py       videos on the canvas: a photo item with trim, cover frame, mute and playback
    text_item.py        text boxes
    shape_item.py       shapes, lines and arrows (resize handles, rotate handle, endpoints)
    snap.py             magnetic snapping shared by photos and shapes
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
    shapes.py           inserting shapes and editing their fill, border and opacity
    history.py          undo / redo
    project.py          save / open, recent files, autosave
    missing.py          missing photos: placeholders, relinking, collect project into a folder
    export.py           high-resolution export; pages with a video become MP4 files
    video.py            video section of the inspector, playback, keeping videos inside one page
    updates.py          new-version notice (checks the latest GitHub release)
```

`MainWindow` is composed of mixins, one per area: each method lives in the file for its feature,
but they all share the same `self`.

## License

[MIT](LICENSE)
