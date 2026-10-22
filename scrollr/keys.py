"""Testi delle scorciatoie da tastiera adattati al sistema (Ctrl su Windows, ⌘ su Mac)."""
import re
import sys

IS_MAC = sys.platform == "darwin"
# Cronologia: su Mac ⌘H è riservato dal sistema (nasconde l'app), lì si usa ⇧⌘H
HISTORY_KEY = "Ctrl+Shift+H" if IS_MAC else "Ctrl+H"

# Su Mac Qt associa le scorciatoie "Ctrl" al tasto ⌘ e i clic con Ctrl a ⌘+clic:
# i testi scritti per Windows vanno tradotti nei simboli che l'utente vede sulla tastiera.
_MAC_RULES = [
    (re.compile(r"Ctrl\+Shift\+(\S)"), r"⇧⌘\1"),
    (re.compile(r"Ctrl\+(?!clic)(\S)"), r"⌘\1"),
    (re.compile(r"\bCtrl\b"), "⌘"),
    (re.compile(r"\bAlt\b"), "⌥"),
    (re.compile(r"\(Canc\)"), "(⌫)"),
]


def kb(text: str) -> str:
    """Restituisce il testo con le scorciatoie scritte come sul sistema in uso."""
    if not IS_MAC:
        return text
    for pattern, repl in _MAC_RULES:
        text = pattern.sub(repl, text)
    return text


# Guida → Scorciatoie da tastiera e mouse (F1): (sezione, [(tasti, cosa fanno)]), scritte per Windows
# e tradotte da kb() per il Mac. Da aggiornare quando si aggiunge una scorciatoia nei menu.
SHORTCUTS = [
    ("Progetto", [
        ("Ctrl+N", "Nuovo progetto"),
        ("Ctrl+Shift+O", "Apri progetto"),
        ("Ctrl+S", "Salva progetto"),
        ("Ctrl+Shift+S", "Salva progetto con nome"),
        ("Ctrl+O", "Aggiungi foto"),
        ("Ctrl+E", "Esporta il collage intero"),
        ("Ctrl+Shift+E", "Esporta le pagine separate"),
    ]),
    ("Modifica", [
        ("Ctrl+Z", "Annulla"),
        ("Ctrl+Y  ·  Ctrl+Shift+Z", "Ripeti"),
        (HISTORY_KEY, "Cronologia delle modifiche"),
        ("Ctrl+X  ·  Ctrl+C  ·  Ctrl+V", "Taglia, copia e incolla foto, testi e forme"),
        ("Ctrl+D", "Duplica"),
        ("⌫" if IS_MAC else "Canc", "Elimina"),
        ("Ctrl+A", "Seleziona tutto"),
        ("Ctrl+G  ·  Ctrl+Shift+G", "Raggruppa · separa il gruppo"),
        ("Ctrl+L", "Blocca o sblocca la posizione"),
        ("Ctrl+Shift+C  ·  Ctrl+Shift+V", "Copia e incolla lo stile di una foto"),
        ("Ctrl+R", "Reimposta zoom, posizione e rotazione della foto"),
        ("Frecce", "Sposta di 1 px"),
        ("Shift + frecce", "Sposta di 10 px"),
        ("Ctrl+T", "Aggiungi un testo"),
    ]),
    ("Vista", [
        ("Ctrl++  ·  Ctrl+-", "Zoom avanti · indietro"),
        ("Ctrl+1", "Dimensioni reali (100%)"),
        ("Ctrl+0", "Adatta alla finestra"),
        ("F5", "Anteprima del carosello (frecce ← → per scorrere, Esc per chiudere)"),
        ("F1", "Questa guida"),
    ]),
    ("Mouse sulla tela", [
        ("Trascina sul vuoto", "Sposta la vista (anche col tasto centrale)"),
        ("Shift + trascina sul vuoto", "Seleziona più elementi con un riquadro (con Ctrl si aggiungono)"),
        ("Clic sul vuoto", "Toglie la selezione"),
        ("Ctrl + clic", "Aggiunge o toglie un elemento dalla selezione"),
        ("Rotella", "Zoom verso il punto sotto il mouse (si può cambiare in Vista → Rotella del mouse)"),
        ("Due dita sul trackpad", "Sposta la vista in tutte le direzioni"),
        ("Pizzico  ·  Ctrl + rotella", "Zoom verso il punto sotto le dita o il mouse"),
        ("Doppio clic su un testo", "Modifica il testo"),
        ("Alt + trascina su una foto", "Sposta l'inquadratura dentro la foto"),
        ("Alt + rotella su una foto", "Zoom dentro la foto selezionata"),
        ("Shift sulle maniglie", "Mantiene le proporzioni"),
        ("Shift sul pallino di rotazione", "Ruota a scatti di 15°"),
        ("Clic destro", "Menu con le azioni dell'elemento e della pagina"),
    ]),
    ("Libreria", [
        ("Doppio clic su una miniatura", "Mette la foto sulla tela"),
        ("Trascina una miniatura su una pagina", "Mette la foto in quella pagina"),
        ("Trascina le miniature tra loro", "Cambia l'ordine delle foto"),
    ]),
]
