# ScrolleR Studio

Desktop editor for building photo collages and carousels for social media (side-by-side pages that scroll).

Videos can go on the canvas too: a page that contains a video is exported as an MP4
(H.264 + AAC, 30 fps), with the rest of the page around it. Each video can be trimmed,
muted and given a cover frame; shorter videos on the same page loop until the longest one ends.
A video always stays inside one page (it cannot straddle two).

Videos can have **subtitles**, written by hand (no automatic transcription): select a video and choose
**Subtitles…**. Write or paste the whole text, one phrase per line (pasted text is split into short phrases, at most
two balanced lines on screen), while the video plays with its sound (Ctrl+Space, even while typing; also at 0.75× or
0.5×). The timing is set automatically from the audio: the phrases are spread over the stretches of speech in
proportion to their length, with the cuts on the pauses. A timeline with the waveform lets you drag the phrase edges
to fix them; a phrase fixed by hand stays put and the others rearrange around it. Each phrase can have a
hand-written translation, drawn smaller under it.
Subtitles are moved and styled like a text (default: bold white with a soft shadow, yellow italic translation, in the
reel safe zone), change frame by frame in the exported MP4, and can be imported or exported as `.srt` files.

A new project is either a **carousel** (one or more pages; videos up to 60 s, the limit of an Instagram carousel
slide) or a **reel** (a single page, 9:16 suggested; videos up to 5 minutes): in **File → New project** the page
formats are grouped by type, so one click picks both. In a reel, the Guides switch also
shows the safe zone that Instagram's interface does not cover. A project can be converted later from the File menu.

At launch a **start window** asks what to work on: recent projects with a thumbnail of their first page (one click
opens them), **Open project…**, and the same formats as File → New project. Closing it without a choice leaves an
empty carousel. It does not appear when the app is opened by double-clicking a project or after recovering unsaved
work. Thumbnails are kept in the app's data folder (`miniature`), not in the `.scrlproj` file: they are written
whenever a project is saved or opened.

Photos can be cut out by hand: in the crop window, **Shape** mode lets you click points around the subject
(or drag to draw freehand) and everything outside becomes transparent, with a soft edge. The cut-out keeps the
original photo untouched, can be edited again at any time, and makes the photo's border and shadow follow the
subject like a sticker. **Save shape as PNG** writes the subject alone, at full resolution, with a transparent background.

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
- Shape cut-out on the phone too: in **Crop → Shape** you draw around the subject with your finger (a magnifier shows
  what your finger covers, two fingers zoom in); **Save PNG** puts the subject alone in the gallery, with a transparent
  background (read from the original at up to 4096 px on the long side).
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
  dialogs.py            new project formats, carousel preview, page order, pages to export, background dialog
  start_dialog.py       start window at launch: recent projects with thumbnails, new project, open project
  crop_dialog.py        "Crop photo" window: crop area with handles and aspect ratios, or a hand-drawn cut-out shape
  captions.py           subtitles without Qt: phrases, splitting the text, balanced lines, .srt, pauses, auto timing
  caption_dialog.py     "Subtitles" window: player with sound, full text, phrase list, timeline
  cutout.py             cut-out shapes: masks with a soft edge, tight crop, point simplification
  canvas/
    photo_item.py       photos on the canvas (crop, cut-out, inner zoom, borders, sticker outline, snapping)
    video_item.py       videos on the canvas: a photo item with trim, cover frame, mute and playback
    text_item.py        text boxes
    caption_item.py     subtitles of a video: a text item whose phrase changes with the video's time
    shape_item.py       shapes, lines and arrows (resize handles, rotate handle, endpoints)
    snap.py             magnetic snapping shared by photos and shapes
    scene.py            pages, background, guides
    view.py             zoom, pan, scroll bars, file drag & drop
    page_grid.py        pages shown as a grid (one view per page of the same canvas)
  window/
    main_window.py      MainWindow: state, canvas format, drag & drop
    ui.py, panels.py    UI construction
    library.py          photo library
    layouts.py          automatic layouts (grid, mosaic, polaroid, film strip, straddle…)
    inspector.py        editing selected items, align and distribute
    text.py, pages.py   carousel texts and pages
    shapes.py           inserting shapes and editing their fill, border and opacity
    history.py          undo / redo
    project.py          save / open, recent files and their thumbnails, start window, autosave
    missing.py          missing photos: placeholders, relinking, collect project into a folder
    export.py           high-resolution export; pages with a video become MP4 files
    video.py            video section of the inspector, playback, keeping videos inside one page
    captions.py         subtitles: blocks on the canvas, their properties, the Subtitles window, .srt files
    updates.py          new-version notice (checks the latest GitHub release)
```

`MainWindow` is composed of mixins, one per area: each method lives in the file for its feature,
but they all share the same `self`.

## License

[MIT](LICENSE)
