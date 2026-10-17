# SCRL Studio

Editor desktop per creare collage e caroselli di foto per i social (pagine affiancate che si scorrono).

## Avvio

```
pip install -r requirements.txt
python main.py        # oppure: python -m scrollr
```

## Struttura

```
main.py                 avvio rapido (F5 in VS Code)
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
