"""Testi delle scorciatoie da tastiera adattati al sistema (Ctrl su Windows, ⌘ su Mac)."""
import re
import sys

IS_MAC = sys.platform == "darwin"

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
