# ScrolleR Studio

Editor desktop per creare collage e caroselli di foto per i social (pagine affiancate che si scorrono).

## Download

Scarica l'installer per Windows dalla pagina [Releases](https://github.com/Michelo1927/scrllr/releases/latest):
apri l'ultima versione e, in **Assets**, clicca `ScrolleR-Studio-Setup-<versione>.exe`.

Se Windows mostra un avviso, clicca «Ulteriori informazioni» → «Esegui comunque».

## Avvio dal codice

```
pip install -r requirements.txt
python main.py        # oppure: python -m scrollr
```

## App Windows (exe e installer)

```
python -m venv .venv
.venv\Scripts\python -m pip install -r requirements.txt pillow-heif pyinstaller
.venv\Scripts\python packaging\build.py
```

- `dist\ScrolleR Studio\ScrolleR Studio.exe`: l'app pronta, senza bisogno di Python.
- `dist\ScrolleR-Studio-Setup-<versione>.exe`: l'installer (menu Start, icona sul desktop, apertura dei `.scrlproj` con doppio clic).
  Richiede Inno Setup 6 (`winget install JRSoftware.InnoSetup`); con `--no-setup` si crea solo la cartella.

La versione è `__version__` in `scrollr/__init__.py`. L'`AppId` in `packaging/scrl_studio.iss` non va cambiato, perché serve agli aggiornamenti.

## Struttura

```
main.py                 avvio rapido (F5 in VS Code)
packaging/              build dell'app Windows (PyInstaller + installer Inno Setup)
scrollr/
  __main__.py           creazione di QApplication e della finestra
  config.py             estensioni supportate, formato progetto, HEIC opzionale
  theme.py              palette, font, foglio di stile QSS, stile Fusion
  icons.py              icone disegnate a codice, miniature, badge
  imaging.py            caricamento foto (EXIF, ICC → sRGB), regolazioni colore, cache
  widgets.py            ToggleSwitch, DropZone, delegate della libreria
  dialogs.py            anteprima carosello, finestra sfondo
  canvas/
    photo_item.py       foto sulla tela (ritaglio, zoom interno, bordi, snap)
    text_item.py        caselle di testo
    scene.py            pagine, sfondo, guide
    view.py             zoom, pan, trascinamento file
  window/
    main_window.py      MainWindow: stato, formato tela, drag & drop
    ui.py, panels.py    costruzione dell'interfaccia
    library.py          libreria foto
    layouts.py          disposizioni automatiche (griglia, mosaico, polaroid, a cavallo…)
    inspector.py        modifica degli elementi selezionati, allinea e distribuisci
    text.py, pages.py   testi e pagine del carosello
    history.py          annulla / ripeti
    project.py          salva / apri, recenti, salvataggio automatico
    export.py           esportazione ad alta risoluzione
```

`MainWindow` è composta da mixin, uno per area: un metodo si trova nel file della sua funzione,
ma tutti condividono lo stesso `self`.
