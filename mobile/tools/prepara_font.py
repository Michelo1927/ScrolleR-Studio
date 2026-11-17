"""Prepara i font inclusi nell'app mobile (piano §8.5): scarica da `google/fonts` le famiglie con licenza libera,
ricava le istanze statiche (Regular, Bold, Italic, Bold Italic dove esistono), le riduce al latino e le scrive in
`mobile/app/assets/fonts/`, insieme a `LICENZE.txt` (testi delle licenze) e al blocco `fonts:` per `pubspec.yaml`.

Serve `fonttools` (`pip install fonttools`). Si lancia da un ambiente con quel pacchetto:

    python -I mobile/tools/prepara_font.py --origine CARTELLA_NUOVA --destinazione mobile/app/assets/fonts

I file scaricati sono dati non fidati: la cartella di origine è nuova e vuota, e lo script gira con `-I`.
I TTF e `LICENZE.txt` generati stanno nel repo; lo script serve solo a rifarli o ad aggiungere famiglie.
"""

from __future__ import annotations

import argparse
import io
import sys
import urllib.parse
import urllib.request
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

BASE = "https://raw.githubusercontent.com/google/fonts/main"

# Latino di base ed esteso A (italiano, inglese, francese, spagnolo, tedesco…), punteggiatura tipografica, euro.
UNICODI = (
    list(range(0x0020, 0x007F))
    + list(range(0x00A0, 0x0180))
    + [0x0192, 0x02C6, 0x02DC, 0x2013, 0x2014, 0x2018, 0x2019, 0x201A, 0x201C, 0x201D, 0x201E, 0x2020, 0x2021]
    + [0x2022, 0x2026, 0x2030, 0x2039, 0x203A, 0x20AC, 0x2122, 0x2190, 0x2191, 0x2192, 0x2193, 0x2212]
)

# (famiglia, cartella nel repo google/fonts, licenza, categoria, file) — il file è `variabile` se contiene `[`.
# `file` = (diritto, corsivo); corsivo None se la famiglia non ne ha (lo si sintetizza).
FAMIGLIE = [
    ("Inter", "ofl/inter", "OFL.txt", "senzaGrazie", ("Inter[opsz,wght].ttf", "Inter-Italic[opsz,wght].ttf")),
    ("Montserrat", "ofl/montserrat", "OFL.txt", "senzaGrazie", ("Montserrat[wght].ttf", "Montserrat-Italic[wght].ttf")),
    ("Poppins", "ofl/poppins", "OFL.txt", "senzaGrazie",
     ("Poppins-Regular.ttf|Poppins-Bold.ttf", "Poppins-Italic.ttf|Poppins-BoldItalic.ttf")),
    ("Nunito", "ofl/nunito", "OFL.txt", "senzaGrazie", ("Nunito[wght].ttf", "Nunito-Italic[wght].ttf")),
    ("Raleway", "ofl/raleway", "OFL.txt", "senzaGrazie", ("Raleway[wght].ttf", "Raleway-Italic[wght].ttf")),
    ("Playfair Display", "ofl/playfairdisplay", "OFL.txt", "conGrazie",
     ("PlayfairDisplay[wght].ttf", "PlayfairDisplay-Italic[wght].ttf")),
    ("Lora", "ofl/lora", "OFL.txt", "conGrazie", ("Lora[wght].ttf", "Lora-Italic[wght].ttf")),
    ("Merriweather", "ofl/merriweather", "OFL.txt", "conGrazie",
     ("Merriweather[opsz,wdth,wght].ttf", "Merriweather-Italic[opsz,wdth,wght].ttf")),
    ("Cormorant Garamond", "ofl/cormorantgaramond", "OFL.txt", "conGrazie",
     ("CormorantGaramond[wght].ttf", "CormorantGaramond-Italic[wght].ttf")),
    ("Bebas Neue", "ofl/bebasneue", "OFL.txt", "titolo", ("BebasNeue-Regular.ttf", None)),
    ("Anton", "ofl/anton", "OFL.txt", "titolo", ("Anton-Regular.ttf", None)),
    ("Oswald", "ofl/oswald", "OFL.txt", "titolo", ("Oswald[wght].ttf", None)),
    ("Abril Fatface", "ofl/abrilfatface", "OFL.txt", "titolo", ("AbrilFatface-Regular.ttf", None)),
    ("Alfa Slab One", "ofl/alfaslabone", "OFL.txt", "titolo", ("AlfaSlabOne-Regular.ttf", None)),
    ("Pacifico", "ofl/pacifico", "OFL.txt", "aMano", ("Pacifico-Regular.ttf", None)),
    ("Dancing Script", "ofl/dancingscript", "OFL.txt", "aMano", ("DancingScript[wght].ttf", None)),
    ("Caveat", "ofl/caveat", "OFL.txt", "aMano", ("Caveat[wght].ttf", None)),
    ("Permanent Marker", "apache/permanentmarker", "LICENSE.txt", "aMano", ("PermanentMarker-Regular.ttf", None)),
    ("JetBrains Mono", "ofl/jetbrainsmono", "OFL.txt", "monospazio",
     ("JetBrainsMono[wght].ttf", "JetBrainsMono-Italic[wght].ttf")),
    ("Space Mono", "ofl/spacemono", "OFL.txt", "monospazio",
     ("SpaceMono-Regular.ttf|SpaceMono-Bold.ttf", "SpaceMono-Italic.ttf|SpaceMono-BoldItalic.ttf")),
]


def scarica(origine: Path, cartella: str, nome: str) -> bytes:
    """Scarica un file (una sola volta: poi si legge da `origine`)."""
    locale = origine / cartella.replace("/", "_") / nome
    if locale.exists():
        return locale.read_bytes()
    url = f"{BASE}/{cartella}/{urllib.parse.quote(nome)}"
    print("scarico", url, file=sys.stderr)
    with urllib.request.urlopen(url, timeout=60) as r:  # noqa: S310 (URL fisso, https)
        dati = r.read()
    locale.parent.mkdir(parents=True, exist_ok=True)
    locale.write_bytes(dati)
    return dati


def istanza(dati: bytes, peso: int) -> TTFont:
    """Font variabile → istanza statica al peso dato (gli altri assi restano al valore predefinito)."""
    font = TTFont(io.BytesIO(dati))
    if "fvar" not in font:
        return font
    assi = {}
    for a in font["fvar"].axes:
        assi[a.axisTag] = max(a.minValue, min(a.maxValue, peso)) if a.axisTag == "wght" else a.defaultValue
    return instancer.instantiateVariableFont(font, assi, inplace=False)


def riduci(font: TTFont, destinazione: Path) -> None:
    opzioni = subset.Options()
    opzioni.layout_features = ["*"]
    opzioni.hinting = False
    opzioni.notdef_outline = True
    opzioni.name_IDs = [0, 1, 2, 3, 4, 5, 6, 13, 14]
    opzioni.drop_tables += ["STAT", "DSIG"]
    sub = subset.Subsetter(opzioni)
    sub.populate(unicodes=UNICODI)
    sub.subset(font)
    destinazione.parent.mkdir(parents=True, exist_ok=True)
    font.save(destinazione)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--origine", type=Path, required=True, help="cartella nuova per i file scaricati")
    ap.add_argument("--destinazione", type=Path, required=True)
    args = ap.parse_args()
    args.origine.mkdir(parents=True, exist_ok=True)
    args.destinazione.mkdir(parents=True, exist_ok=True)

    yaml = ["  fonts:"]
    licenze = [
        "Font inclusi in ScrolleR Studio Mobile. Ogni famiglia ha la sua licenza (SIL Open Font License 1.1 o",
        "Apache 2.0); i testi seguono, con l'avviso di copyright di ciascuna.",
        "Prodotti da `mobile/tools/prepara_font.py`: istanze statiche ridotte al latino, senza altre modifiche.",
        "",
    ]
    for famiglia, cartella, licenza, _categoria, (diritto, corsivo) in FAMIGLIE:
        base = famiglia.replace(" ", "")
        voci: list[tuple[str, int, bool]] = []  # (file scritto, peso, corsivo)
        for e_corsivo, spec in ((False, diritto), (True, corsivo)):
            if spec is None:
                continue
            if "|" in spec:  # Due file statici: normale e grassetto
                for peso, nome in zip((400, 700), spec.split("|")):
                    suffisso = {(400, False): "Regular", (700, False): "Bold", (400, True): "Italic", (700, True): "BoldItalic"}[
                        (peso, e_corsivo)
                    ]
                    font = TTFont(io.BytesIO(scarica(args.origine, cartella, nome)))
                    riduci(font, args.destinazione / f"{base}-{suffisso}.ttf")
                    voci.append((f"{base}-{suffisso}.ttf", peso, e_corsivo))
                continue
            dati = scarica(args.origine, cartella, spec)
            pesi = (400, 700) if "[" in spec else (400,)
            for peso in pesi:
                suffisso = {(400, False): "Regular", (700, False): "Bold", (400, True): "Italic", (700, True): "BoldItalic"}[
                    (peso, e_corsivo)
                ]
                riduci(istanza(dati, peso), args.destinazione / f"{base}-{suffisso}.ttf")
                voci.append((f"{base}-{suffisso}.ttf", peso, e_corsivo))
        yaml.append(f"    - family: {famiglia}")
        yaml.append("      fonts:")
        for nome, peso, e_corsivo in voci:
            yaml.append(f"        - asset: assets/fonts/{nome}")
            if peso != 400:
                yaml.append(f"          weight: {peso}")
            if e_corsivo:
                yaml.append("          style: italic")
        testo = scarica(args.origine, cartella, licenza).decode("utf-8", errors="replace").strip()
        licenze += ["=" * 78, famiglia, "=" * 78, testo, ""]
    (args.destinazione / "LICENZE.txt").write_text("\n".join(licenze), encoding="utf-8", newline="\n")
    print("\n".join(yaml))
    return 0


if __name__ == "__main__":
    sys.exit(main())
