"""
Genera i dati di riferimento per le prove del motore mobile (piano §13) usando l'app desktop vera,
in modalità offscreen.

Uso, dalla root della repo e con l'ambiente Python del desktop:

    python mobile/tools/genera_riferimenti.py [--uscita CARTELLA] [--senza-immagini]
    python mobile/tools/genera_riferimenti.py --verifica CARTELLA
    python mobile/tools/genera_riferimenti.py --verifica-zip FILE.zip
    python mobile/tools/genera_riferimenti.py --crea-zip-desktop [FILE.zip]

La seconda forma non genera niente: apre nel desktop i `.scrlproj` della cartella (per esempio quelli riscritti
dal motore con `dart run tool/riscrivi_progetti.dart`) e controlla che si riaprano identici, con le foto della
galleria del telefono (campo `asset`) mostrate come «Foto mancante».

`--verifica-zip` apre nel desktop vero lo `.zip` di «Condividi progetto» del telefono, estratto come farebbe l'utente sul
PC, e controlla che il progetto si apra identico e con **tutte** le foto trovate (`rel` e `path` verso `media/`).
`--crea-zip-desktop` fa il percorso inverso: costruisce un progetto nel desktop, lo raccoglie con «Raccogli progetto»
(cartella con `.scrlproj` e sottocartella `Foto/`) e lo comprime in uno `.zip` come farebbe l'utente; di partenza lo scrive in
`mobile/app/test/riferimenti/progetto-desktop.zip`, che le prove dell'app importano.

Produce in `mobile/packages/scrl_engine/test/riferimenti/`:
- `disposizioni.jsonl`: un caso per riga. `prima` è lo stato di partenza (tela + foto con le proporzioni
  usate dal desktop), `dopo` è il risultato di `apply_auto_layout`: rettangoli, rotazione, bordo automatico
  e liste per pagina. Le prove Dart confrontano i rettangoli con tolleranza 0,001.
- `colore.json`: tabelle dei toni, livelli automatici, luminosità e grana di `scrollr/imaging.py`.
- `geometria.json`: geometria del disegno delle foto (`_cover_geometry`, `_image_transform`, ombra).
- `casuale.json`: valori di `random.Random(seme)` (Mersenne Twister) per portare il generatore di Python.
- `immagini/`: alcune pagine esportate dal desktop, con il progetto che le ha prodotte.
- `pagine.jsonl`: azioni vere del desktop su pagine e tela (inserisci, duplica, elimina, sposta, riordina,
  blocca, unisci, disposizione e foto di una pagina, numero di pagine, formato…), una sequenza per riga, con lo
  stato completo prima e dopo.
- `selezione.jsonl`: comandi sulla selezione (raggruppa, allinea, distribuisci, blocca, davanti/dietro, copia, taglia,
  incolla), una sequenza per riga, con lo stato completo prima e dopo. Si rigenera da solo con `--solo-selezione`.
- `cronologia.jsonl`: coppie di stati prodotte da singole azioni, con il nome del passaggio (`_describe_change`).
- `progetti/`: progetti salvati dal desktop con tutti i tipi di elemento, da rileggere e riscrivere col motore.
- `indice.json`: versione del desktop, numero di casi e immagini campione.

Le finestre di dialogo non si aprono: le domande rispondono «Sì», gli avvisi si registrano.

Le impostazioni dell'utente (`QSettings("SCRL", "SCRL Studio")`) NON vengono mai toccate: la finestra usa un file
INI temporaneo, il salvataggio automatico è spento e alla fine si controlla che quelle vere siano rimaste uguali.
"""
import argparse
import itertools
import json
import math
import os
import random
import shutil
import sys
import tempfile

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, ROOT)

from PIL import Image  # noqa: E402
from PyQt6.QtCore import QRectF, QSettings  # noqa: E402
from PyQt6.QtGui import QColor  # noqa: E402
from PyQt6.QtWidgets import QApplication, QMessageBox  # noqa: E402

from scrollr import __version__ as APP_VERSION  # noqa: E402
from scrollr.canvas.shape_item import ShapeItem  # noqa: E402
from scrollr.canvas.text_item import TextItem  # noqa: E402
from scrollr.window.main_window import MainWindow  # noqa: E402

USCITA_PREDEFINITA = os.path.join(ROOT, "mobile", "packages", "scrl_engine", "test", "riferimenti")

# Foto di prova: proporzioni varie (verticali, orizzontali, quadrate, panoramiche). Piccole, così l'anteprima
# del desktop coincide con l'originale e le proporzioni registrate sono esatte.
FOTO = [
    (600, 800), (800, 600), (600, 600), (960, 540), (540, 960), (600, 900), (900, 600),
    (1200, 400), (400, 1200), (750, 600), (600, 750), (700, 500), (500, 700), (840, 600),
    (600, 840), (1000, 500), (500, 1000), (640, 640), (900, 700), (700, 900),
]
MODI = ["grid", "mosaic", "strips_h", "strips_v", "scatter", "scrl_seam"]
STILI_MOSAICO = ["auto", "top", "bottom", "left", "right", "center", "two", "masonry"]
FORMATI = [(i, None) for i in range(8)] + [(8, (1000, 2000))]  # 8 = Personalizzato


# ================= ISOLAMENTO DELLE IMPOSTAZIONI =================
def impostazioni_vere() -> dict:
    s = QSettings("SCRL", "SCRL Studio")
    return {k: repr(s.value(k)) for k in s.allKeys()}


def isola_finestra(cartella: str):
    """La finestra legge e scrive solo un INI temporaneo e non salva in automatico."""
    ini = os.path.join(cartella, "impostazioni.ini")
    MainWindow._settings = staticmethod(lambda: QSettings(ini, QSettings.Format.IniFormat))
    MainWindow._autosave = lambda self: None
    MainWindow._remove_autosave = lambda self: None


# ================= FOTO DI PROVA =================
def crea_foto(cartella: str) -> list:
    percorsi = []
    for i, (w, h) in enumerate(FOTO):
        img = Image.new("RGB", (w, h))
        # Sfumatura diversa per ogni foto: utile nelle immagini esportate
        r0, g0, b0 = (37 * i) % 256, (91 * i + 60) % 256, (151 * i + 120) % 256
        px = img.load()
        for y in range(h):
            for x in range(w):
                px[x, y] = ((r0 + x * 255 // w) % 256, (g0 + y * 255 // h) % 256, b0)
        p = os.path.join(cartella, f"foto_{i + 1:02d}.png")
        img.save(p)
        percorsi.append(p)
    return percorsi


# ================= CASI =================
def tela(ratio_index=0, custom=None, frames=1, mode="grid", style="auto", gap=16, margin=24, per_frame=True,
         per_page=0, counts=None, layouts=None, seams=None, locks=None, seed=12345) -> dict:
    sizes = list(MainWindow.ASPECT_RATIOS.values())
    w, h = custom or sizes[ratio_index]
    return {
        "ratio_index": ratio_index, "custom_w": w if custom else 1080, "custom_h": h if custom else 1440,
        "frame_w": w, "frame_h": h, "num_frames": frames, "bg_color": "#FFFFFFFF", "gap": gap, "margin": margin,
        "per_frame": per_frame, "per_page": per_page, "page_counts": counts or [], "page_layouts": layouts or [],
        "page_seams": seams or [], "page_locks": locks or [], "layout_mode": mode, "mosaic_style": style,
        "layout_seed": seed,
    }


def casi() -> list:
    """Combinazioni da provare: (id, tela, numero di foto, modifiche prima della disposizione)."""
    out = []
    seme = random.Random(2026)

    def add(nome, c, n, **extra):
        c["layout_seed"] = seme.randrange(1 << 30)
        out.append((nome, c, n, extra))

    # Base: tutti i formati × tutte le disposizioni × varie quantità, su 1 e 3 pagine
    for (ri, custom), mode, n, frames in itertools.product(FORMATI, MODI, (1, 2, 3, 5, 8, 13, 20), (1, 3)):
        add(f"base-f{ri}-{mode}-n{n}-p{frames}", tela(ri, custom, frames, mode), n)
    # Tutti gli stili del mosaico, da 1 a 20 foto
    for style, n in itertools.product(STILI_MOSAICO, range(1, 21)):
        add(f"mosaico-{style}-n{n}", tela(0, None, 1, "mosaic", style), n)
    # Griglia da 1 a 20 foto su formato verticale e panoramico
    for ri, n in itertools.product((0, 5), range(1, 21)):
        add(f"griglia-f{ri}-n{n}", tela(ri, None, 1, "grid"), n)
    # Tela continua (non una disposizione per pagina)
    for mode, n, frames in itertools.product(MODI, (4, 9, 15), (2, 4)):
        add(f"continua-{mode}-n{n}-p{frames}", tela(0, None, frames, mode, per_frame=False), n)
    # Foto per pagina fissate: le pagine si calcolano da sole
    for per_page, mode, n in itertools.product((1, 2, 3, 4, 6), ("grid", "mosaic", "strips_h"), (7, 12)):
        add(f"perpagina{per_page}-{mode}-n{n}", tela(0, None, 1, mode, per_page=per_page), n)
    # Spaziatura e margine
    for (gap, margin), mode in itertools.product(((0, 0), (80, 120), (40, 60), (5, 0)), MODI):
        add(f"spazi-g{gap}-m{margin}-{mode}", tela(4, None, 2, mode, gap=gap, margin=margin), 6)
    # Foto fissate per pagina e disposizione propria di una pagina
    for mode in MODI[:5]:
        add(f"conteggi-{mode}", tela(0, None, 3, mode, counts=[2, None, 5]), 12)
        add(f"proprie-{mode}", tela(2, None, 3, mode, layouts=[{"mode": "strips_v", "style": None}, None,
                                                                {"mode": "mosaic", "style": "two"}]), 11)
    # Pagine unite «a cavallo»
    for seams, mode, n in itertools.product(([True], [True, False, False], [True, True, False], [False, True]),
                                            ("grid", "mosaic", "scatter"), (5, 10)):
        frames = max(2, len(seams) + 1)
        add(f"unite-{'-'.join('u' if s else 's' for s in seams)}-{mode}-n{n}", tela(0, None, frames, mode, seams=seams), n)
    # Pagine bloccate (con le loro foto ferme), una disposizione per pagina e tela continua
    for per_frame, mode in itertools.product((True, False), MODI):
        add(f"bloccate-{'pp' if per_frame else 'cont'}-{mode}",
            tela(0, None, 3, mode, per_frame=per_frame, locks=[None, True, None]), 9, bloccate={1: 2})
    add("bloccate-tutte-grid", tela(0, None, 2, "grid", locks=[True, True]), 5, bloccate={0: 1, 1: 1})
    # Foto libere (escluse dalla disposizione)
    for mode in MODI:
        add(f"libere-{mode}", tela(0, None, 2, mode), 8, libere=[2, 5])
    # Ritaglio e stiramento cambiano le proporzioni usate dalle disposizioni
    for mode in ("grid", "mosaic", "strips_h", "strips_v", "scrl_seam"):
        add(f"ritaglio-{mode}", tela(0, None, 2, mode), 7, ritagli={0: [0.1, 0.0, 0.9, 0.5], 3: [0.0, 0.2, 1.0, 0.8]},
            stirate={1: 1.6, 4: 0.5})
    # Bordo «Polaroid» automatico che va tolto passando a un'altra disposizione
    for mode in MODI:
        if mode != "scatter":
            add(f"dopo-polaroid-{mode}", tela(0, None, 2, mode), 6, prima_scatter=True)
    # «Pellicola» (aggiunta dopo: i casi qui sopra tengono i loro semi)
    for (ri, custom), n, frames in itertools.product(FORMATI, (1, 2, 3, 5, 8, 13, 20), (1, 3)):
        add(f"base-f{ri}-film-n{n}-p{frames}", tela(ri, custom, frames, "film"), n)
    for n, frames in itertools.product((4, 9, 15), (2, 4)):
        add(f"continua-film-n{n}-p{frames}", tela(0, None, frames, "film", per_frame=False), n)
    for gap, margin in ((0, 0), (80, 120), (40, 60), (5, 0)):
        add(f"spazi-g{gap}-m{margin}-film", tela(4, None, 2, "film", gap=gap, margin=margin), 6)
    add("conteggi-film", tela(0, None, 3, "film", counts=[2, None, 5]), 12)
    add("proprie-film", tela(2, None, 3, "grid", layouts=[{"mode": "film", "style": None}, None,
                                                         {"mode": "scatter", "style": None}]), 11)
    for per_frame in (True, False):
        add(f"bloccate-{'pp' if per_frame else 'cont'}-film",
            tela(0, None, 3, "film", per_frame=per_frame, locks=[None, True, None]), 9, bloccate={1: 2})
    add("libere-film", tela(0, None, 2, "film"), 8, libere=[2, 5])
    add("ritaglio-film", tela(0, None, 2, "film"), 7, ritagli={0: [0.1, 0.0, 0.9, 0.5], 3: [0.0, 0.2, 1.0, 0.8]},
        stirate={1: 1.6, 4: 0.5})
    add("dopo-polaroid-film", tela(0, None, 2, "film"), 6, prima_scatter=True)
    for mode in MODI:
        add(f"dopo-pellicola-{mode}", tela(0, None, 2, mode), 6, prima="film")
    # Verso delle strisce scelto (tutta la tela e pagina con la sua Pellicola)
    for (ri, custom), verso, n in itertools.product(FORMATI, ("horizontal", "vertical"), (1, 3, 7, 12)):
        add(f"pellicola-{verso}-f{ri}-n{n}", dict(tela(ri, custom, 1, "film"), film_style=verso), n)
    for verso in ("horizontal", "vertical"):
        add(f"pellicola-continua-{verso}", dict(tela(0, None, 3, "film", per_frame=False), film_style=verso), 9)
        add(f"pellicola-propria-{verso}", tela(2, None, 3, "grid", layouts=[{"mode": "film", "style": verso}, None,
                                                                          {"mode": "film", "style": None}]), 11)
    return out


# ================= ESECUZIONE =================
def stato_foto(p, nome: str) -> dict:
    return {
        "uid": p.uid, "rel": nome, "x": p.pos().x(), "y": p.pos().y(), "w": p.cell_w, "h": p.cell_h,
        "rotation": p.rotation(), "z": p.zValue(), "layout_index": p.layout_index, "crop": list(p.crop),
        "stretch": p.stretch, "free": p.free, "page_locked": p.page_locked, "border_width": p.border_width,
        "auto_border": p.auto_border, "frame": p.frame, "image": [p.pixmap.width(), p.pixmap.height()], "ratio": p.source_ratio(),
    }


def stato_tela(win) -> dict:
    snap = win._snapshot()["canvas"]
    return {k: snap[k] for k in ("frame_w", "frame_h", "num_frames", "page_counts", "page_layouts", "page_seams",
                                 "page_locks", "layout_mode")}


def arrotonda(v):
    """6 decimali bastano per la tolleranza di 0,001 delle prove e dimezzano il file."""
    if isinstance(v, float):
        return round(v, 6)
    if isinstance(v, list):
        return [arrotonda(x) for x in v]
    if isinstance(v, dict):
        return {k: arrotonda(x) for k, x in v.items()}
    return v


def esegui_caso(win, foto: list, nome: str, c: dict, n: int, extra: dict) -> dict:
    win._restore_snapshot({"canvas": dict(c, page_counts=list(c["page_counts"]), page_layouts=list(c["page_layouts"]),
                                          page_seams=list(c["page_seams"]), page_locks=list(c["page_locks"])),
                           "items": [], "texts": [], "shapes": []})
    items = [win._spawn_photo_item(foto[i % len(foto)]) for i in range(n)]
    fw, fh = c["frame_w"], c["frame_h"]
    if extra.get("prima_scatter"):
        win.apply_auto_layout("scatter")
    if extra.get("prima"):
        win.apply_auto_layout(extra["prima"])
    # Foto ferme nelle pagine bloccate: le ultime della lista, posate dentro la loro pagina
    coda = list(reversed(items))
    for page, quante in extra.get("bloccate", {}).items():
        for j in range(quante):
            p = coda.pop(0)
            p.setPos(page * fw + 40 + j * 60, 40 + j * 60)
            p.set_page_locked(True)
    for i in extra.get("libere", []):
        items[i].set_free(True)
        items[i].set_cell_size(300, 200)
        items[i].setPos(fw * 0.5 + 10 * i, fh * 0.3)
    for i, crop in extra.get("ritagli", {}).items():
        items[i].crop = list(crop)
    for i, s in extra.get("stirate", {}).items():
        items[i].stretch = s
    for i, (punti, morbidezza) in extra.get("sagome", {}).items():
        items[i].apply_cutout(punti, morbidezza)
    nomi = {p.uid: os.path.basename(p.image_path) for p in items}
    prima = {"canvas": win._snapshot()["canvas"], "items": [stato_foto(p, nomi[p.uid]) for p in items]}
    prima["canvas"].pop("export_name", None)
    win.apply_auto_layout(c["layout_mode"])
    for i, (bordo, colore, ombra) in extra.get("adesivi", {}).items():
        items[i].border_width = bordo
        items[i].border_color = QColor(colore)
        items[i].shadow = ombra
    dopo = {"canvas": stato_tela(win),
            "items": [{k: v for k, v in stato_foto(p, nomi[p.uid]).items()
                       if k in ("uid", "x", "y", "w", "h", "rotation", "border_width", "auto_border", "frame")}
                      for p in win.get_canvas_photos()]}
    return arrotonda({"id": nome, "prima": prima, "dopo": dopo})


def casuale() -> dict:
    out = []
    for seed in (0, 1, 42, 12345, 987654321, (1 << 30) - 1):
        r = random.Random(seed)
        bits = [r.getrandbits(32) for _ in range(8)]
        r = random.Random(seed)
        rnd = [r.random() for _ in range(20)]
        r = random.Random(seed)
        uni = [r.uniform(-7.5, 7.5) for _ in range(20)]
        r = random.Random(seed)
        rng = [r.randrange(1 << 30) for _ in range(5)]
        out.append({"seed": seed, "getrandbits32": bits, "random": rnd, "uniform_-7.5_7.5": uni,
                    "randrange_2^30": rng})
    return {"python": sys.version.split()[0], "semi": out}


def colore() -> dict:
    """Tabelle del colore (`scrollr/imaging.py`) e grana: le prove Dart del modulo `color` le confrontano."""
    import zlib
    from PIL import Image, ImageEnhance, ImageStat
    from scrollr.imaging import NEUTRAL_ADJUST, PRESETS, _tone_lut, auto_levels_lut
    casi_toni = [{"shadows": 40}, {"highlights": -30, "fade": 20}, {"warmth": 35, "tint": -12},
                 dict(NEUTRAL_ADJUST, **PRESETS[4][2])]
    rnd = random.Random(7)
    w, h = 37, 23
    px = bytes(rnd.randrange(30, 220) for _ in range(w * h * 3))
    img = Image.frombytes("RGB", (w, h), px)
    chiara = ImageEnhance.Brightness(img).enhance(1.25)
    grana = random.Random(20261022).randbytes(256 * 256)
    return {"tone": [{"adj": c, "lut": _tone_lut(c)} for c in casi_toni],
            "img": {"w": w, "h": h, "rgb": list(px)},
            "auto": auto_levels_lut(img),
            "brightness_mean": int(ImageStat.Stat(chiara.convert("L")).mean[0] + 0.5),
            "brightness_px": list(chiara.tobytes()[:30]),
            "grain_head": list(grana[:16]), "grain_crc": zlib.crc32(grana),
            "presets": [{"key": k, "adj": dict(NEUTRAL_ADJUST, **v)} for k, _n, v in PRESETS],
            "regolate": regolate()}


def regolate() -> dict:
    """`apply_adjustments` su una foto sintetica 64×48 (come `crea_foto`, n. 4): lo shader dell'app la confronta."""
    from PIL import Image
    from scrollr.imaging import NEUTRAL_ADJUST, PRESETS, apply_adjustments, auto_levels_lut
    w, h, i = 64, 48, 3
    img = Image.new("RGB", (w, h))
    r0, g0, b0 = (37 * i) % 256, (91 * i + 60) % 256, (151 * i + 120) % 256
    px = img.load()
    for y in range(h):
        for x in range(w):
            px[x, y] = ((r0 + x * 255 // w) % 256, (g0 + y * 255 // h) % 256, b0)
    casi = [{"brightness": 25}, {"contrast": 40}, {"saturation": -60}, {"bw": True, "contrast": 20},
            {"shadows": 50, "warmth": -30}, {"auto": True}, {"sharpness": 60},
            {"highlights": -45}, {"tint": 35}, {"fade": 50}, {"auto": True, "brightness": -20, "contrast": 25}]
    # Tutti i filtri pronti dell'app (anche «Originale», che deve restare invariata)
    casi += [dict(v) for _k, _, v in PRESETS]
    lut = auto_levels_lut(img)
    out = []
    for c in casi:
        adj = dict(NEUTRAL_ADJUST, **c)
        res = apply_adjustments(img, adj, detail_scale=w / 1000.0, auto_lut=lut)
        out.append({"adj": adj, "rgb": list(res.convert("RGB").tobytes())})
    return {"w": w, "h": h, "foto": i, "casi": out}


def ritaglio() -> dict:
    """Ritaglio a schermo intero (`scrollr/crop_dialog.py`): trascinamenti sul `CropCanvas` e scelte nel `CropDialog`."""
    from PyQt6.QtCore import QEvent, QPointF, QRectF, Qt
    from PyQt6.QtGui import QMouseEvent, QPixmap
    from scrollr.crop_dialog import CropCanvas, CropDialog

    def evento(tipo, p):
        b = Qt.MouseButton.LeftButton
        return QMouseEvent(tipo, QPointF(p[0], p[1]), b, b, Qt.KeyboardModifier.NoModifier)

    trascinamenti = []
    immagini = [(400, 300), (300, 500), (1000, 1000)]
    forme = [None, 4 / 5, 1.0, 16 / 9, 9 / 16]
    for (iw, ih) in immagini:
        c = CropCanvas(QPixmap(iw, ih))
        c.resize(800, 600)
        s, o = c._scale(), c._origin()
        riquadri = [(0, 0, iw, ih), (iw * 0.2, ih * 0.15, iw * 0.5, ih * 0.6)]
        for r in riquadri:
            for ratio in forme:
                rr = c._to_widget(QRectF(*r))
                prese = {"tl": (rr.left(), rr.top()), "tr": (rr.right(), rr.top()), "bl": (rr.left(), rr.bottom()),
                         "br": (rr.right(), rr.bottom()), "l": (rr.left(), rr.center().y()),
                         "r": (rr.right(), rr.center().y()), "t": (rr.center().x(), rr.top()),
                         "b": (rr.center().x(), rr.bottom()), "sposta": (rr.center().x(), rr.center().y()),
                         "nuovo": (o.x() + 12, o.y() + 12)}
                for nome, w0 in prese.items():
                    for (dx, dy) in ((-0.31, -0.22), (0.27, 0.19), (0.8, 0.9), (-2.0, 1.5)):
                        c.rect_img = QRectF(*r)
                        c.ratio = ratio
                        premi = (w0[0] + 3.0, w0[1] + 2.0) if nome != "sposta" else w0
                        c.mousePressEvent(evento(QEvent.Type.MouseButtonPress, premi))
                        presa = c._drag
                        p_img = c._to_image(QPointF(*premi))
                        muovi = (premi[0] + dx * iw * s, premi[1] + dy * ih * s)
                        c.mouseMoveEvent(evento(QEvent.Type.MouseMove, muovi))
                        c.mouseReleaseEvent(evento(QEvent.Type.MouseButtonRelease, muovi))
                        m_img = c._to_image(QPointF(*muovi))
                        q = c.rect_img
                        trascinamenti.append({
                            "img": [iw, ih], "rect": list(r), "ratio": ratio, "scala": s, "presa": presa,
                            "premi": [p_img.x(), p_img.y()], "muovi": [m_img.x(), m_img.y()],
                            "schermo": abs(muovi[0] - premi[0]) + abs(muovi[1] - premi[1]),
                            "risultato": [q.x(), q.y(), q.width(), q.height()]})

    scelte = []
    copioni = [[], [("ratio", "4:5")], [("ratio", "4:5"), ("swap",)], [("ratio", "original")], [("ratio", "cell")],
               [("ratio", "1:1"), ("whole",)], [("ratio", "9:16"), ("swap",), ("whole",)]]
    avvii = [((0.0, 0.0, 1.0, 1.0), False, False, 1.0), ((0.1, 0.2, 0.7, 0.9), True, False, 0.8),
             ((0.25, 0.0, 0.75, 1.0), False, True, 1.5), ((0.0, 0.1, 0.8, 0.9), True, True, 1.0)]
    for (iw, ih) in immagini[:2]:
        for crop, fh, fv, cella in avvii:
            for copione in copioni:
                dlg = CropDialog(QPixmap(iw, ih), crop, fh, fv, cella, "")
                inizio = {"chiave": dlg._current_key(), "scambiata": dlg._swapped, "crop": list(dlg.crop())}
                passi = []
                for op in copione:
                    if op[0] == "ratio":
                        dlg._set_ratio_key(op[1])
                    elif op[0] == "swap":
                        dlg._swap()
                    else:
                        dlg._whole()
                    passi.append({"chiave": dlg._current_key(), "scambiata": dlg._swapped, "crop": list(dlg.crop()),
                                  "etichetta_4_5": dlg.ratio_buttons["4:5"].text(), "scambia": dlg.btn_swap.isEnabled()})
                scelte.append({"img": [iw, ih], "crop": list(crop), "flip_h": fh, "flip_v": fv, "cella": cella,
                               "copione": [list(x) for x in copione], "inizio": inizio, "passi": passi})
                dlg.deleteLater()
    return {"trascinamenti": trascinamenti, "scelte": scelte}


def strumenti_foto() -> list:
    """`reset_aspect_to_original`, `restore_saved_cell` e `apply_crop` di `PhotoItem` su foto con la misura dell'anteprima."""
    from PyQt6.QtGui import QPixmap
    from scrollr.canvas.photo_item import PhotoItem
    from scrollr.imaging import IMAGE_CACHE
    out = []
    base = [dict(x=100.0, y=50.0, w=400.0, h=500.0), dict(x=-20.0, y=30.0, w=300.0, h=300.0, rotation=25.0),
            dict(x=10.0, y=10.0, w=520.0, h=260.0, free=True, inner_zoom=1.7, pan_x=0.4, pan_y=-0.2, stretch=1.3),
            dict(x=0.0, y=0.0, w=350.0, h=420.0, crop=(0.1, 0.2, 0.7, 0.9), stretch=0.8)]
    crops = [(0.0, 0.0, 1.0, 1.0), (0.1, 0.2, 0.7, 0.9), (0.25, 0.0, 0.75, 1.0), (0.0, 0.3, 1.0, 0.7)]
    for i, c in enumerate(base):
        for img_w, img_h in ((1600, 1200), (900, 1600)):
            path = f"prova_{i}_{img_w}.jpg"
            IMAGE_CACHE._previews[path] = QPixmap(img_w, img_h)

            def nuova():
                p = PhotoItem(path, c["w"], c["h"])
                p.setPos(c["x"], c["y"])
                p.setRotation(c.get("rotation", 0.0))
                p.free = c.get("free", False)
                for k in ("inner_zoom", "pan_x", "pan_y", "stretch"):
                    if k in c:
                        setattr(p, k, c[k])
                if "crop" in c:
                    p.crop = c["crop"]
                return p

            def stato(p):
                return {"x": p.pos().x(), "y": p.pos().y(), "w": p.cell_w, "h": p.cell_h, "inner_zoom": p.inner_zoom,
                        "pan_x": p.pan_x, "pan_y": p.pan_y, "stretch": p.stretch, "crop": list(p.crop),
                        "saved": dict(p.saved_cell) if p.saved_cell else None}
            caso = {"foto": c, "img": [img_w, img_h]}
            p = nuova()
            p.reset_aspect_to_original()
            caso["proporzioni"] = stato(p)
            p.reset_aspect_to_original()  # Il riquadro di prima si ricorda una volta sola
            caso["proporzioni_due_volte"] = stato(p)
            p.restore_saved_cell()
            caso["ripristino"] = stato(p)
            caso["ritagli"] = []
            for crop in crops:
                for fit in (True, False):
                    q = nuova()
                    q.apply_crop(crop, fit)
                    caso["ritagli"].append({"crop": list(crop), "fit": fit, "dopo": stato(q)})
            out.append(caso)
    return out


def _stella(cx, cy, r1, r2, n=7):
    return [(cx + (r1 if k % 2 == 0 else r2) * math.cos(k * math.pi / n - math.pi / 2),
             cy + (r1 if k % 2 == 0 else r2) * math.sin(k * math.pi / n - math.pi / 2)) for k in range(2 * n)]


STELLA = _stella(0.5, 0.52, 0.42, 0.2)
GOCCIA = [(0.5 + 0.38 * math.sin(a) * (1 - 0.3 * math.cos(a)), 0.5 - 0.42 * math.cos(a))
          for a in (k * 2 * math.pi / 24 for k in range(24))]


def sagoma() -> dict:
    """Sagoma (`scrollr/cutout.py`, `apply_cutout`, la parte «Sagoma» di `CropCanvas` e `CropDialog`)."""
    from PyQt6.QtCore import QPointF
    from PyQt6.QtGui import QPixmap
    from scrollr import cutout as cu
    from scrollr.canvas.photo_item import PhotoItem
    from scrollr.crop_dialog import MODE_CUT, CropCanvas, CropDialog
    from scrollr.imaging import IMAGE_CACHE
    rnd = random.Random(2026)

    def nuvola(n, cx=0.5, cy=0.5, r=0.4):
        return [(cx + r * rnd.uniform(0.3, 1.0) * math.cos(a), cy + r * rnd.uniform(0.3, 1.0) * math.sin(a))
                for a in sorted(rnd.uniform(0, 2 * math.pi) for _ in range(n))]

    # Pulizia: punti e morbidezza come arrivano dal file (anche sbagliati)
    pulizia = []
    for v in [None, [], [[0.1, 0.1], [0.9, 0.1]], [[0.1, 0.1], [0.9, 0.1], [0.5, 0.9]],
              [[-0.2, 0.5], [1.4, 0.5], [0.5, 2.0], [0.5, -1]], [[0.1, 0.1], [0.5, 0.5], [0.9, 0.9]],
              [[0.1, 0.1], [0.2, 0.2], [0.3, 0.3], [0.4, 0.4]], [[0.1, "0.2"], [0.9, 0.1], [0.5, True]],
              [[0.1, 0.1], [0.9, None], [0.5, 0.9]], [[0.1, 0.1, 0.3], [0.9, 0.1], [0.5, 0.9]],
              [[0.1, 0.1], [0.9, "x"], [0.5, 0.9]], [[0, 0], [1, 0], [1, 1], [0, 1]],
              [[0.5, 0.5], [0.5004, 0.5], [0.5, 0.5004]]]:
        pulizia.append({"punti": v, "pulita": cu.clean_cutout(v)})
    morbidezze = []
    for v in [None, 0, 15, 15.5, 16.5, -3, 250, "40", "x", True, 99.5, 100.4, 7.49]:
        morbidezze.append({"valore": v, "pulita": cu.clean_soft(v)})

    # Funzioni: raggio, ritaglio stretto, semplificazione
    funzioni = []
    for (w, h) in ((600, 800), (1600, 1200), (300, 3000)):
        for soft in (0, 15, 60, 100):
            pts = nuvola(rnd.randint(3, 30))
            funzioni.append({"img": [w, h], "soft": soft, "punti": pts, "raggio": cu.soft_radius(soft, w, h),
                             "ritaglio": list(cu.bounding_crop(pts, soft, w, h))})
    semplifica = []
    for n in (2, 3, 10, 60, 200):
        tratto = [(200 + 150 * math.cos(t) + rnd.uniform(-2, 2), 300 + 90 * math.sin(2 * t) + rnd.uniform(-2, 2))
                  for t in (k * 2 * math.pi / n for k in range(n))]
        for tol in (0.0, 0.5, 1.7, 6.0):
            semplifica.append({"punti": tratto, "tolleranza": tol, "risultato": cu.simplify(tratto, tol)})

    # apply_cutout su foto con la misura dell'anteprima (e togliere la sagoma)
    applica = []
    base = [dict(w=400.0, h=500.0), dict(w=300.0, h=300.0, rotation=25.0, free=True),
            dict(w=520.0, h=260.0, inner_zoom=1.7, pan_x=0.4, crop=(0.1, 0.2, 0.7, 0.9), stretch=1.3),
            dict(w=350.0, h=420.0, fit_mode="contain")]
    for i, c in enumerate(base):
        for img_w, img_h in ((1600, 1200), (900, 1600)):
            path = f"sagoma_{i}_{img_w}.jpg"
            IMAGE_CACHE._previews[path] = QPixmap(img_w, img_h)
            for punti, soft in ((STELLA, 15), (GOCCIA, 0), (nuvola(9, 0.3, 0.7, 0.25), 100), ([[0.1, 0.1]], 15)):
                q = PhotoItem(path, c["w"], c["h"])
                q.setPos(100.0, 50.0)
                q.setRotation(c.get("rotation", 0.0))
                q.free = c.get("free", False)
                for k in ("inner_zoom", "pan_x", "stretch", "fit_mode"):
                    if k in c:
                        setattr(q, k, c[k])
                if "crop" in c:
                    q.crop = c["crop"]
                prima = q.get_state()
                q.apply_cutout(punti, soft)
                dopo = q.get_state()
                q.apply_cutout(None)
                q.apply_crop((0.0, 0.0, 1.0, 1.0), fit_cell=True)
                applica.append({"img": [img_w, img_h], "prima": prima, "punti": punti, "soft": soft,
                                "dopo": dopo, "tolta": q.get_state()})

    # Tratti a mano libera nella finestra Ritaglia (fine del tratto: semplificato, unito, chiuso)
    tratti = []
    for (iw, ih) in ((1200, 800), (500, 900)):
        c = CropCanvas(QPixmap(iw, ih))
        c.resize(800, 600)
        c.set_mode(MODE_CUT)
        for zoom in (1.0, 2.5):
            c._zoom = zoom
            scala = c._scale()
            for prima in ([], [(100.0, 100.0), (300.0, 120.0)], [(50.0, 60.0), (400.0, 80.0), (420.0, 500.0)]):
                for chiude in (False, True):
                    n = rnd.randint(8, 80)
                    a0 = rnd.uniform(0, 1)
                    tratto = [(iw / 2 + iw * 0.3 * math.cos(a0 + t), ih / 2 + ih * 0.3 * math.sin(a0 + t))
                              for t in (k * (2 * math.pi if chiude else 3.5) / n for k in range(n + 1))]
                    if prima and chiude:
                        tratto = tratto + [prima[0]]
                    c.set_shape([QPointF(*q) for q in prima], False)
                    c._stroke = [QPointF(*q) for q in tratto]
                    c._finish_stroke()
                    tratti.append({"img": [iw, ih], "scala": scala, "presa": c.GRAB, "prima": prima,
                                   "tratto": tratto, "punti": [(q.x(), q.y()) for q in c.pts], "chiusa": c.closed})

    # Finestra Ritaglia con una sagoma e lo specchio: punti mostrati e sagoma restituita
    specchi = []
    for fh in (False, True):
        for fv in (False, True):
            dlg = CropDialog(QPixmap(900, 600), (0.0, 0.0, 1.0, 1.0), fh, fv, 1.0, "", cutout=STELLA, cutout_soft=33)
            specchi.append({"flip_h": fh, "flip_v": fv, "mostrati": [(q.x(), q.y()) for q in dlg.canvas.pts],
                            "chiusa": dlg.canvas.closed, "sagoma": dlg.cutout(), "soft": dlg.cutout_soft()})
            dlg.deleteLater()
    return {"stella": STELLA, "goccia": GOCCIA, "pulizia": pulizia, "morbidezze": morbidezze,
            "funzioni": funzioni, "semplifica": semplifica, "applica": applica, "tratti": tratti,
            "specchi": specchi}


# Larghezze finte dei caratteri per le prove dei sottotitoli: le stesse in Dart (`sottotitoli.json`, chiave `larghezze`)
LARGHEZZE_PROVA = {" ": 5, "i": 4, "l": 4, ".": 4, ",": 4, "!": 4, "'": 3, "m": 15, "w": 14, "M": 16, "W": 18}

TESTI_SOTTOTITOLI = [
    "Ciao a tutti! Oggi vi porto a vedere il mare.",
    "Questa è una frase molto lunga che non sta assolutamente in due righe di sottotitoli e va spezzata, "
    "magari vicino a una virgola oppure prima di una congiunzione come ma o perché.",
    "Prima riga\nSeconda riga\r\n\r\nTerza   riga con   spazi\tstrani",
    "«Allora», disse lui, «andiamo?» Sì… andiamo; ma piano: piano!",
    "Parole parole parole parole parole parole parole parole parole parole parole parole parole parole",
    "Una frase con emoji 😀 e accenti àèìòù che deve restare intera.",
    "",
    "   ",
    "Uno.",
    "Supercalifragilistichespiralidosoeancoradipiùsenzaspazi",
    "And this is English, but we still want short lines so that people can read them when they scroll fast.",
    "Primo pezzo — secondo pezzo — terzo pezzo — quarto pezzo — quinto pezzo — sesto pezzo — settimo",
    "Il sole era alto e il mare calmo e noi eravamo felici e stanchi e pieni di sabbia fino alle orecchie.",
]


def _larghezza_prova(s: str) -> float:
    return float(sum(LARGHEZZE_PROVA.get(c, 10) for c in s))


def sottotitoli() -> dict:
    """
    Funzioni di `scrollr/captions.py` (frasi, divisione del testo, righe bilanciate, merge_lines, tempi
    automatici, .srt, forma d'onda e pause) su casi fissi e casuali, per il motore mobile.
    """
    import base64
    import copy
    from array import array

    from scrollr import captions as C

    rnd = random.Random(20261125)
    out = {"larghezze": LARGHEZZE_PROVA}

    # ---- Divisione del testo e righe ----
    split = []
    for testo in TESTI_SOTTOTITOLI:
        split.append({"testo": testo, "limite": None, "frasi": C.split_text(testo)})
        for limite in (200, 320, 500):
            split.append({"testo": testo, "limite": limite, "frasi": C.split_text(
                testo, lambda s, m=limite: C.fits_two_lines(s, _larghezza_prova, m))})
    out["split_text"] = split
    righe = []
    for testo in TESTI_SOTTOTITOLI + [f for t in TESTI_SOTTOTITOLI for f in C.split_text(t)]:
        for max_w in (80, 150, 260, 400, 900):
            righe.append({"testo": testo, "max_w": max_w,
                          "righe": C.balance_lines(testo, _larghezza_prova, max_w),
                          "stanno": C.fits_two_lines(testo, _larghezza_prova, max_w)})
    out["balance_lines"] = righe

    # ---- Frasi ----
    def frase_casuale(i):
        parole = rnd.choice(TESTI_SOTTOTITOLI[:6] + TESTI_SOTTOTITOLI[10:]).split()
        a = rnd.randrange(0, max(1, len(parole) - 1))
        testo = " ".join(parole[a:a + rnd.randint(1, 7)]) or f"frase {i}"
        p = C.make_phrase(testo, tr=rnd.choice(["", "", f"translation {i}"]))
        return p

    def frasi_casuali(n, lo=0.0, hi=30.0):
        ps = [frase_casuale(i) for i in range(n)]
        t = lo + rnd.random() * 2
        for p in ps:
            r = rnd.random()
            if r < 0.25:
                continue  # Senza tempi
            d = 0.4 + rnd.random() * 3
            p["start"], p["end"] = round(t, 3), round(min(hi, t + d), 3)
            if r < 0.7:
                p["auto"] = True
            t += d + rnd.random() * 0.8
        return ps

    sporche = [
        {"start": "1.5", "end": 2, "text": "testo", "tr": None},
        {"start": 3, "end": 2.995, "text": 5},
        {"start": -1, "end": None, "text": "neg"},
        {"start": None, "end": 4, "auto": True},
        {"start": 1, "end": 2, "auto": True, "words": [{"w": "ciao", "s": 1.0}]},
        {"start": 1, "end": 2, "auto": "si"},
        {"text": None},
        "non una frase",
        {"start": True, "end": "x", "text": "bool"},
        {"start": 1.23456789, "end": 9.87654321, "text": "arrotonda", "tr": "round"},
    ]
    out["clean_phrases"] = {"dati": sporche, "frasi": C.clean_phrases(sporche),
                            "stato": [C.phrase_state(p) for p in C.clean_phrases(sporche)]}

    dividi, unisci, indici, posti = [], [], [], []
    for k in range(60):
        ps = frasi_casuali(rnd.randint(1, 8))
        p = ps[0]
        if k % 7 == 0:
            p["text"] = rnd.choice(["parola", "", "due parole", "uno, due tre quattro", "a, b"])
        a, b = C.split_phrase(copy.deepcopy(p))
        dividi.append({"frase": p, "a": a, "b": b})
        if len(ps) > 1:
            unisci.append({"a": ps[0], "b": ps[1], "frase": C.join_phrases(ps[0], ps[1])})
        for t in (0.0, rnd.random() * 30, rnd.random() * 30, 15.0):
            indici.append({"frasi": ps, "t": t, "indice": C.phrase_index_at(ps, t)})
            posti.append({"frasi": ps, "start": t, "indice": C.insert_index(ps, t)})
    out["split_phrase"], out["join_phrases"] = dividi, unisci
    out["phrase_index_at"], out["insert_index"] = indici, posti

    # ---- merge_lines: la casella di testo riscritta ----
    def varia(righe):
        r = list(righe)
        op = rnd.choice(["uguale", "correggi", "dividi", "unisci", "togli", "aggiungi", "riscrivi", "scambia",
                         "dividi2", "unisci3"])
        if not r:
            return ["nuova riga"]
        i = rnd.randrange(len(r))
        if op == "correggi":
            r[i] = r[i] + rnd.choice([" ok", "!", " e poi"])
        elif op in ("dividi", "dividi2"):
            parole = r[i].split()
            if len(parole) > 1:
                k = rnd.randrange(1, len(parole))
                r[i:i + 1] = [" ".join(parole[:k]), " ".join(parole[k:])]
        elif op == "unisci" and i + 1 < len(r):
            r[i:i + 2] = [r[i] + " " + r[i + 1]]
        elif op == "unisci3" and i + 2 < len(r):
            r[i:i + 3] = [" ".join(r[i:i + 3])]
        elif op == "togli":
            del r[i]
        elif op == "aggiungi":
            r.insert(i, "riga del tutto nuova")
        elif op == "riscrivi":
            r[i] = "completamente diverso"
        elif op == "scambia" and i + 1 < len(r):
            r[i], r[i + 1] = r[i + 1], r[i]
        return r

    fusioni = []
    for k in range(150):
        vecchie = frasi_casuali(rnd.randint(0, 9))
        righe_n = [p["text"] for p in vecchie]
        for _ in range(rnd.randint(1, 3)):
            righe_n = varia(righe_n)
        fusioni.append({"vecchie": vecchie, "righe": righe_n,
                        "frasi": C.merge_lines(copy.deepcopy(vecchie), righe_n)})
    out["merge_lines"] = fusioni

    # ---- Tempi leggibili e .srt ----
    out["format_clock"] = [[t, C.format_clock(t)] for t in
                           (None, 0.0, -3.0, 0.004, 0.005, 0.015, 7.25, 59.995, 61.5, 3599.999, 3600.5, 12.345)]
    out["parse_clock"] = [[s, C.parse_clock(s)] for s in
                          ("1:02,5", "62.5", "0:01:02,500", "", "  ", "abc", "1:2:3:4", "-1", "1:-2",
                           "  3,25 ", "1:00:00", "0,1", "1e2", "1:")]
    srt_frasi = [frasi_casuali(rnd.randint(0, 8)) for _ in range(15)]
    out["to_srt"] = [{"frasi": ps, "campo": campo, "srt": C.to_srt(ps, campo)}
                     for ps in srt_frasi for campo in ("text", "tr")]
    srt_testi = [C.to_srt(ps) for ps in srt_frasi] + [
        "﻿1\r\n00:00:01,000 --> 00:00:02,500\r\n<i>Ciao</i> {\\an8}a tutti\r\nseconda riga\r\n\r\n"
        "2\r\n00:00:03.2 --> 00:00:03,30\r\nbreve\r\n",
        "1\n00:00:05,000 --> 00:00:04,000\nal contrario\n\n\n\nsenza tempi\n\n3\n1:2:3,4 --> 1:2:4,5\nore\n",
        "solo testo senza nulla",
        "",
        "1\n00:00:01,000 --> \nmezza riga\n",
    ]
    out["parse_srt"] = [{"srt": s, "frasi": C.parse_srt(s)} for s in srt_testi]

    # ---- Forma d'onda e pause ----
    inviluppi = []
    for k in range(6):
        rate = rnd.choice([2000, 2400, 3000])
        n = rnd.randint(0, rate * 2)
        a = array("h", [0] * n)
        for i in range(n):
            forte = (i // (rate // 4)) % 3 != 0
            v = int(rnd.gauss(0, 9000 if forte else 120)) if forte or rnd.random() < 0.9 else 0
            a[i] = max(-32768, min(32767, v))
        if n and k == 0:
            a[0], a[-1] = -32768, 32767
        pcm = a.tobytes() + (b"\x01" if k == 1 else b"")
        inviluppi.append({"pcm": base64.b64encode(pcm).decode("ascii"), "rate": rate,
                          "env": C.envelope(pcm, rate)})
    out["envelope"] = inviluppi

    pause = []
    for k in range(40):
        n = rnd.randint(0, 900)
        env, i = [], 0
        while i < n:
            tratto = rnd.randint(5, 120)
            silenzio = rnd.random() < 0.4
            env += [rnd.random() * (0.02 if silenzio else 0.9) for _ in range(tratto)]
            i += tratto
        env = env[:n]
        min_len = rnd.choice([0.25, 0.25, 0.1, 0.5])
        pause.append({"env": env, "min_len": min_len, "pause": C.find_pauses(env, min_len=min_len)})
    out["find_pauses"] = pause

    def pause_casuali(lo, hi):
        ps, t = [], lo + rnd.random() * 0.5
        while t < hi:
            d = rnd.choice([0.1, 0.3, 0.5, 0.9, 1.5])
            if rnd.random() < 0.6:
                ps.append((round(t, 2), round(min(hi + 1, t + d), 2)))
            t += d + rnd.random() * 3
        return ps

    aggancio, parlato, automatici, ridistribuiti = [], [], [], []
    for k in range(80):
        lo = rnd.choice([0.0, 0.0, round(rnd.random() * 5, 2)])
        hi = lo + rnd.choice([0.2, 2.0, 10.0, 30.0, 60.0, 300.0]) * (0.5 + rnd.random())
        ps = pause_casuali(lo - 1, hi)
        punti = C.snap_points(ps)
        for _ in range(3):
            t, tol = lo + rnd.random() * (hi - lo), rnd.choice([0.05, 0.2, 1.0])
            aggancio.append({"t": t, "punti": punti, "tol": tol, "r": C.snap(t, punti, tol)})
        parlato.append({"pause": ps, "lo": lo, "hi": hi, "tratti": C.speech_spans(ps, lo, hi)})
        pesi = [C.phrase_weight(frase_casuale(i)) for i in range(rnd.randint(0, 14))]
        automatici.append({"pesi": pesi, "pause": ps, "lo": lo, "hi": hi, "tempi": C.auto_times(pesi, ps, lo, hi)})
        frasi = frasi_casuali(rnd.randint(0, 12), lo, hi)
        reset = k % 5 == 0
        dopo = copy.deepcopy(frasi)
        C.retime(dopo, ps, lo, hi, reset)
        ridistribuiti.append({"frasi": frasi, "pause": ps, "lo": lo, "hi": hi, "reset": reset, "dopo": dopo})
    out["snap"], out["speech_spans"] = aggancio, parlato
    out["auto_times"], out["retime"] = automatici, ridistribuiti
    out["phrase_weight"] = [[t, C.phrase_weight({"text": t})] for t in TESTI_SOTTOTITOLI]
    return out


def scrivi_sottotitoli(uscita: str):
    os.makedirs(uscita, exist_ok=True)
    with open(os.path.join(uscita, "sottotitoli.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(sottotitoli(), f, ensure_ascii=False)
    print(f"sottotitoli.json in {os.path.relpath(uscita, ROOT)}")


def scrivi_sottotitoli_tela(win, foto: list, tmp: str, uscita: str, aggiorna_indice: bool = False) -> dict:
    """Scrive `sottotitoli_tela.jsonl` e `progetti/sottotitoli.scrlproj`; restituisce il progetto."""
    progetto, casi = sottotitoli_tela(win, foto, crea_video(tmp))
    with open(os.path.join(uscita, "sottotitoli_tela.jsonl"), "w", encoding="utf-8", newline="\n") as f:
        for caso in casi:
            f.write(json.dumps(caso, ensure_ascii=False, separators=(",", ":")) + "\n")
    cartella = os.path.join(uscita, "progetti")
    os.makedirs(cartella, exist_ok=True)
    with open(os.path.join(cartella, "sottotitoli.scrlproj"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(progetto, f, ensure_ascii=False, indent=1)
    if aggiorna_indice:
        percorso = os.path.join(uscita, "indice.json")
        with open(percorso, encoding="utf-8") as f:
            indice = json.load(f)
        indice["progetti"] = sorted(set(indice["progetti"]) | {"sottotitoli.scrlproj"})
        with open(percorso, "w", encoding="utf-8", newline="\n") as f:
            json.dump(indice, f, ensure_ascii=False, indent=1)
    print(f"{len(casi)} casi di sottotitoli sulla tela e il progetto sottotitoli.scrlproj")
    return progetto


def geometria() -> list:
    """Geometria del disegno di `PhotoItem` (cover/contain, ritaglio, rotazione, ombra, lato da leggere)."""
    from scrollr.canvas.photo_item import PhotoItem
    out = []
    casi_foto = [
        dict(w=400, h=500), dict(w=300, h=300, inner_zoom=1.6, pan_x=0.5, pan_y=-0.3),
        dict(w=520, h=260, inner_rotation=17.0, flip_h=True), dict(w=350, h=420, fit_mode="contain", inner_rotation=-30.0),
        dict(w=600, h=400, crop=(0.1, 0.2, 0.7, 0.9), stretch=1.4, flip_v=True, shadow=60, border_radius=30.0),
        # Cornici Polaroid e Pellicola: la foto si adatta alla finestra
        dict(w=339, h=408, frame="polaroid"), dict(w=420, h=300, frame="polaroid", inner_rotation=12.0),
        dict(w=516, h=508, frame="film", inner_zoom=1.3, pan_x=0.4, pan_y=-0.6),
        dict(w=300, h=520, frame="film_v", fit_mode="contain"), dict(w=1032, h=200, frame="film", flip_h=True),
    ]
    for i, c in enumerate(casi_foto):
        for img_w, img_h in ((1600, 1200), (900, 1600)):
            p = PhotoItem("x.jpg", c["w"], c["h"])
            for k in ("inner_zoom", "pan_x", "pan_y", "inner_rotation", "flip_h", "flip_v", "fit_mode", "stretch",
                      "shadow", "border_radius", "frame"):
                if k in c:
                    setattr(p, k, c[k])
            if "crop" in c:
                p.crop = c["crop"]
            src = p._crop_rect(img_w, img_h)
            g = p._cover_geometry(src.width(), src.height())
            t = p._image_transform()
            win = p.window_rect()
            vis = t.mapRect(QRectF(g[1], g[2], g[3], g[4])).intersected(win)
            out.append({"foto": {k: (list(v) if isinstance(v, tuple) else v) for k, v in c.items()},
                        "img": [img_w, img_h], "cover": list(g),
                        "transform": [t.m11(), t.m12(), t.m21(), t.m22(), t.dx(), t.dy()],
                        "visibile": [vis.x(), vis.y(), vis.width(), vis.height()],
                        "ombra": [p._shadow_extent(), max(1, min(255, round(255 * (p.shadow / 100.0) * 0.075)))],
                        "finestra": [win.x(), win.y(), win.width(), win.height()],
                        "fori": [[r.x(), r.y(), r.width(), r.height()] for r in p.film_holes()]})
    return out


def esporta_immagini(win, foto: list, cartella: str) -> list:
    os.makedirs(cartella, exist_ok=True)
    campioni = [("immagine-griglia", tela(0, None, 2, "grid"), 6, {}),
                ("immagine-polaroid", tela(2, None, 1, "scatter", seed=777), 5, {}),
                ("immagine-unite", tela(3, None, 3, "mosaic", seams=[True, False]), 9, {}),
                ("immagine-pellicola", tela(0, None, 2, "film"), 7, {}),
                ("immagine-polaroid-rilievo", dict(tela(0, None, 1, "scatter", seed=4242), bg_color="#FFE9E4DC",
                                                   polaroid_shadow=60, polaroid_depth=85), 5, {}),
                ("immagine-pellicola-verticale", dict(tela(2, None, 1, "film"), film_style="vertical"), 5, {}),
                ("immagine-sagoma", tela(0, None, 1, "grid"), 4,
                 {"sagome": {0: (STELLA, 15), 1: (GOCCIA, 0), 2: (STELLA, 60), 3: (GOCCIA, 100)},
                  "adesivi": {0: (8.0, "#FFFFFFFF", 0), 1: (0.0, "#FFFFFFFF", 60),
                              2: (6.0, "#FF202020", 45), 3: (0.0, "#FFFFFFFF", 0)}})]
    fatti = []
    for nome, c, n, extra in campioni:
        caso = esegui_caso(win, foto, nome, c, n, extra)
        progetto = win._snapshot()
        progetto["version"] = 1
        progetto["library"] = []
        for s in progetto["items"]:
            s["rel"] = s["path"] = os.path.basename(s["path"])
        with open(os.path.join(cartella, f"{nome}.json"), "w", encoding="utf-8") as f:
            json.dump({"caso": caso, "progetto": progetto}, f, ensure_ascii=False, indent=1)
        fw, fh = c["frame_w"], c["frame_h"]
        for k in range(win.scene.num_frames):
            win.scene.clearSelection()
            win.scene.is_exporting = True
            img = win._render_region(QRectF(k * fw, 0, fw, fh), fw, fh)
            win.scene.is_exporting = False
            file = f"{nome}_{k + 1:02d}.png"
            img.save(os.path.join(cartella, file), "PNG")
            fatti.append(file)
    return fatti


# ================= DIALOGHI (nessuna finestra modale in offscreen) =================
DIALOGHI: list = []  # Avvisi che il desktop avrebbe mostrato: (tipo, titolo) o ("ricollega", [percorsi])


def neutralizza_dialoghi():
    """Le domande rispondono «Sì», gli avvisi si registrano, l'offerta di ricollegare le foto si registra."""
    QMessageBox.question = staticmethod(lambda *a, **k: QMessageBox.StandardButton.Yes)
    for tipo in ("warning", "information", "critical"):
        setattr(QMessageBox, tipo, staticmethod(
            lambda parent=None, title="", *a, _t=tipo, **k: DIALOGHI.append((_t, title)) or QMessageBox.StandardButton.Ok))
    MainWindow._offer_relink = lambda self, missing: DIALOGHI.append(("ricollega", [os.path.basename(p) for p in missing]))


# ================= STATO COMPLETO (pagine, cronologia, progetti) =================
def stato_completo(win) -> dict:
    """`_snapshot()` con percorsi ridotti al nome del file, misura delle immagini e dei testi (per le prove Dart)."""
    snap = win._snapshot()
    foto = {p.uid: p for p in win.get_canvas_photos()}
    for s in snap["items"]:
        p = foto[s["uid"]]
        s["path"] = s["rel"] = os.path.basename(s["path"])
        s["image"] = [p.pixmap.width(), p.pixmap.height()]
    testi = {t.uid: t for t in win.get_canvas_texts()}
    for s in snap["texts"]:
        r = testi[s["uid"]].text_rect()
        s["text_size"] = [r.width(), r.height()]
    blocchi = {c.uid: c for c in win.get_canvas_captions()}
    for s in snap.get("captions", []):
        r = blocchi[s["uid"]].text_rect()
        s["caption_size"] = [r.width(), r.height()]
    return arrotonda(snap)


def tela_iniziale(win, foto: list, c: dict, n: int, testi=(), forme=(), libere=(), bloccate=(), unite=(),
                  proprie=None):
    """Tela con n foto disposte, testi e forme (pagina, x, y), foto libere, pagine unite e bloccate (vere azioni)."""
    win._restore_snapshot({"canvas": dict(c, page_counts=[], page_layouts=[], page_seams=[], page_locks=[]),
                           "items": [], "texts": [], "shapes": []})
    items = [win._spawn_photo_item(foto[i % len(foto)]) for i in range(n)]
    fw = c["frame_w"]
    for i in libere:
        items[i].set_free(True)
        items[i].set_cell_size(300, 200)
        items[i].setPos(fw * 0.4 + 15 * i, 300)
    win.apply_auto_layout(c["layout_mode"])
    for j, (page, x, y) in enumerate(testi):
        t = win._spawn_text_item()
        t.set_text(f"Testo {j + 1}")
        t.setPos(page * fw + x, y)
    for j, (page, x, y) in enumerate(forme):
        sh = win._spawn_shape_item(("rect", "ellipse", "line")[j % 3])
        sh.setPos(page * fw + x, y)
    for k, mode in (proprie or {}).items():
        win._set_page_layout(k, mode, "two" if mode == "mosaic" else None)
    for k in unite:
        win._set_page_joined(k, True)
    for k in bloccate:
        win._set_page_lock(k, True)
    win._flush_pending_commit()


def seleziona(win, uids):
    win.scene.clearSelection()
    for p in win.get_canvas_photos():
        if p.uid in uids:
            p.setSelected(True)


def uid_di(win, indici) -> list:
    """Uid delle foto in quelle posizioni dell'ordine di disposizione (gli uid del desktop sono un contatore globale)."""
    foto = win.get_canvas_photos()
    return [foto[i % len(foto)].uid for i in indici]


def applica(win, op: str, args: list) -> list:
    """Esegue un'azione del desktop come la farebbe l'utente; restituisce gli argomenti da registrare."""
    if op == "insert":
        win._insert_page_at(*args)
    elif op == "duplicate":
        win._duplicate_page(*args)
    elif op == "delete":
        win._delete_page(*args)
    elif op == "move":
        win._move_page(*args)
    elif op == "reorder":
        win._reorder_pages(list(args[0]))
    elif op == "lock":
        win._set_page_lock(*args)
    elif op == "join":
        win._set_page_joined(*args)
    elif op == "page_layout":
        win._set_page_layout(*args)
    elif op == "page_count":
        win._set_page_count(*args)
    elif op == "frames":
        win.spin_frames.setValue(args[0])
    elif op == "ratio":
        win.combo_ratio.setCurrentIndex(args[0])
    elif op == "custom":
        win.spin_custom_w.setValue(args[0])
        win.spin_custom_h.setValue(args[1])
        win._apply_custom_ratio()
    elif op == "per_page":
        win.spin_per_page.setValue(args[0])
    elif op == "per_frame":
        win.chk_per_frame.setChecked(args[0])
    elif op == "gap":
        win.slider_gap.setValue(args[0])
    elif op == "margin":
        win.slider_margin.setValue(args[0])
    elif op == "layout":
        win._on_layout_button(args[0])
        args = [args[0], win._layout_seed]  # Seme casuale scelto dal desktop: lo usa anche il motore
    elif op == "mosaic_style":
        win.combo_mosaic.setCurrentIndex(win.combo_mosaic.findData(args[0]))
    elif op == "move_photos":
        idx, target = args
        uids = uid_di(win, idx)
        win._move_photos_to_page([p for p in win.get_canvas_photos() if p.uid in uids], target)
        args = [uids, target]
    elif op == "free":
        seleziona(win, uid_di(win, args[0]))
        args = [[p.uid for p in win._selected_photos()]]  # Ordine della selezione di Qt: decide i livelli
        win._toggle_free_selected()
    elif op == "swap":
        uids = uid_di(win, args)
        seleziona(win, uids)
        win.swap_two_selected_photos()
        args = uids
    else:
        raise ValueError(op)
    win._flush_pending_commit()
    return args


def casi_pagine() -> list:
    """(id, tela, foto, opzioni della tela iniziale, azioni) per le prove di pagine e impostazioni della tela."""
    out = []
    t3 = [(0, 100, 100), (1, 300, 900), (2, 50, 1200)]
    f3 = [(1, 500, 200), (2, 700, 700)]
    base = [("p3", tela(0, None, 3, "grid"), 9, {"testi": t3, "forme": f3}),
            ("p4m", tela(2, None, 4, "mosaic"), 10, {"testi": t3}),
            ("p3cont", tela(0, None, 3, "grid", per_frame=False), 8, {"forme": f3}),
            ("p4unite", tela(0, None, 4, "grid"), 10, {"unite": [1], "testi": t3}),
            ("p4bloc", tela(0, None, 4, "grid"), 10, {"bloccate": [2], "testi": t3}),
            ("p3libere", tela(0, None, 3, "strips_h"), 8, {"libere": [1, 4]}),
            ("p3proprie", tela(3, None, 3, "grid"), 9, {"proprie": {0: "mosaic", 2: "strips_v"}})]
    for nome, c, n, opz in base:
        frames = c["num_frames"]
        azioni = []
        azioni += [(f"insert{i}", [["insert", [i]]]) for i in range(frames + 1)]
        azioni += [(f"duplicate{k}", [["duplicate", [k]]]) for k in range(frames)]
        azioni += [(f"delete{k}", [["delete", [k]]]) for k in range(frames)]
        azioni += [(f"move{k}{'+' if d > 0 else '-'}", [["move", [k, d]]]) for k in range(frames) for d in (-1, 1)]
        azioni += [("reorder-rev", [["reorder", [list(range(frames))[::-1]]]]),
                   ("reorder-rot", [["reorder", [list(range(1, frames)) + [0]]]])]
        azioni += [(f"lock{k}", [["lock", [k, True]]]) for k in range(frames)]
        azioni += [(f"lock{k}-unlock", [["lock", [k, True]], ["gap", [40]], ["lock", [k, False]]]) for k in (0, 1)]
        azioni += [(f"join{k}", [["join", [k, True]]]) for k in range(frames - 1)]
        azioni += [("join0-split", [["join", [0, True]], ["join", [0, False]]])]
        azioni += [(f"layout{k}", [["page_layout", [k, "strips_v", None]]]) for k in range(frames)]
        azioni += [("layout1-mosaic-left", [["page_layout", [1, "mosaic", "left"]]]),
                   ("layout0-none", [["page_layout", [0, None]]])]
        azioni += [(f"count{k}-{v}", [["page_count", [k, v]]]) for k in (0, frames - 1) for v in (0, 1, 4)]
        azioni += [("count0-none", [["page_count", [0, 2]], ["page_count", [0, None]]])]
        azioni += [(f"frames{v}", [["frames", [v]]]) for v in (1, 2, frames + 2)]
        azioni += [(f"ratio{i}", [["ratio", [i]]]) for i in (1, 3, 5)]
        azioni += [("custom", [["ratio", [8]], ["custom", [1000, 2000]]])]
        azioni += [("perpage2", [["per_page", [2]]]), ("perpage3-frames", [["per_page", [3]], ["frames", [2]]])]
        azioni += [("perframe-off" if c["per_frame"] else "perframe-on", [["per_frame", [not c["per_frame"]]]])]
        azioni += [("gap-margin", [["gap", [50]], ["margin", [90]]])]
        azioni += [("seam-and-back", [["frames", [1]], ["layout", ["scrl_seam"]], ["layout", ["grid"]]]),
                   ("seam-manual", [["layout", ["scrl_seam"]], ["frames", [frames + 1]], ["layout", ["mosaic"]]]),
                   ("scatter", [["layout", ["scatter"]]]),
                   ("mosaic-styles", [["layout", ["mosaic"]], ["mosaic_style", ["center"]], ["mosaic_style", ["masonry"]]])]
        azioni += [(f"movephotos-{t}", [["move_photos", [[0, 1], t]]]) for t in range(frames)]
        azioni += [("free", [["free", [[2]]]]), ("free-back", [["free", [[2, 3]]], ["free", [[2, 3]]]]),
                   ("swap", [["swap", [0, n - 1]]])]
        azioni += [("combo", [["insert", [1]], ["join", [1, True]], ["duplicate", [0]], ["move", [3, -1]],
                              ["lock", [0, True]], ["delete", [2]], ["page_count", [1, 3]], ["lock", [0, False]]])]
        for nome_az, ops in azioni:
            out.append((f"{nome}-{nome_az}", c, n, opz, ops))
    return out


def esegui_caso_pagine(win, foto: list, nome: str, c: dict, n: int, opz: dict, ops: list) -> dict:
    tela_iniziale(win, foto, c, n, **opz)
    # Stato salvato e riaperto (come il motore, che parte da uno snapshot): niente stato nascosto della finestra
    win._restore_snapshot(win._snapshot())
    prima = stato_completo(win)
    fatte = [[op, applica(win, op, list(args))] for op, args in ops]
    return {"id": nome, "prima": prima, "azioni": fatte, "dopo": stato_completo(win)}


def casi_cronologia(win, foto: list) -> list:
    """Coppie di stati prodotte da singole azioni dell'utente, con il nome che il desktop dà al passaggio."""
    out = []

    def passo(nome, azione):
        a = win._snapshot()
        azione()
        win._flush_pending_commit()
        b = win._snapshot()
        out.append({"id": nome, "nome": win._describe_change(a, b), "prima": _ridotto(win, a),
                    "dopo": _ridotto(win, b)})

    tela_iniziale(win, foto, tela(0, None, 2, "grid"), 6, testi=[(0, 100, 100)], forme=[(1, 300, 300)])
    win._restore_snapshot(win._snapshot())
    ph = win.get_canvas_photos
    tx = win.get_canvas_texts
    sh = win.get_canvas_shapes
    passo("foto-spostata", lambda: ph()[0].moveBy(30, 10))
    passo("foto-ridimensionata", lambda: ph()[1].set_cell_size(200, 260))
    passo("foto-ruotata", lambda: ph()[2].setRotation(12))
    passo("foto-livello", lambda: ph()[0].setZValue(99))
    passo("foto-blocco", lambda: ph()[0].set_locked(True))
    passo("foto-colori", lambda: setattr(ph()[1], "adjust", dict(ph()[1].adjust, brightness=20)))
    passo("foto-inquadratura", lambda: setattr(ph()[1], "inner_zoom", 1.5))
    passo("foto-stile", lambda: setattr(ph()[1], "border_width", 6.0))
    passo("foto-libera", lambda: (seleziona(win, [ph()[3].uid]), win._toggle_free_selected()))
    passo("foto-disposizione", lambda: (seleziona(win, [p.uid for p in ph() if p.free]), win._toggle_free_selected()))
    passo("foto-ordine", lambda: [setattr(p, "layout_index", 100 - i) for i, p in enumerate(ph()[:2])])
    passo("elementi-spostati", lambda: [p.moveBy(5, 0) for p in ph()[:3]])
    passo("disposizione-aggiornata", lambda: win.slider_gap.setValue(30))
    passo("margine", lambda: win.slider_margin.setValue(60))
    passo("raggruppati", lambda: (seleziona(win, [ph()[0].uid, ph()[1].uid]), win._group_selected()))
    passo("testo-modificato", lambda: tx()[0].set_text("Ciao"))
    passo("testo-spostato", lambda: tx()[0].moveBy(0, 40))
    passo("testo-stile", lambda: setattr(tx()[0], "bold", False))
    passo("forma-ruotata", lambda: sh()[0].setRotation(30))
    passo("forma-stile", lambda: setattr(sh()[0], "stroke_width", 4.0))
    passo("testo-aggiunto", lambda: win._spawn_text_item())
    passo("forme-aggiunte", lambda: (win._spawn_shape_item("rect"), win._spawn_shape_item("ellipse")))
    passo("elementi-aggiunti", lambda: (win._spawn_shape_item("rect"), win._spawn_text_item()))
    passo("forma-eliminata", lambda: win.scene.removeItem(sh()[-1]))
    passo("foto-eliminate", lambda: [win.scene.removeItem(p) for p in ph()[-2:]])
    passo("foto-sostituite", lambda: (win.scene.removeItem(ph()[0]), win._spawn_photo_item(foto[7])))
    passo("elementi-cambiati", lambda: (win.scene.removeItem(tx()[-1]), win._spawn_photo_item(foto[8])))
    passo("disposizione", lambda: win._on_layout_button("mosaic"))
    passo("stile-mosaico", lambda: win.combo_mosaic.setCurrentIndex(win.combo_mosaic.findData("left")))
    passo("rimescolate", lambda: setattr(win, "_layout_seed", win._layout_seed + 1))
    passo("formato", lambda: win.combo_ratio.setCurrentIndex(3))
    passo("pagine-uno-in-piu", lambda: win.spin_frames.setValue(3))
    passo("pagine-due-in-piu", lambda: win.spin_frames.setValue(5))
    passo("pagina-eliminata", lambda: win._delete_page(4))
    passo("pagina-duplicata", lambda: win._duplicate_page(0))
    passo("lucchetto", lambda: win._set_page_lock(3, True))
    passo("a-cavallo", lambda: win._set_page_joined(0, True))
    passo("disposizione-pagina", lambda: win._set_page_layout(2, "strips_h"))
    passo("foto-per-pagina", lambda: win._set_page_count(2, 1))
    passo("sfondo", lambda: setattr(win.scene, "bg_mode", "gradient"))
    passo("numeri", lambda: setattr(win.scene, "page_numbers", True))
    passo("scorri", lambda: setattr(win.scene, "swipe_text", "Avanti"))
    passo("nome-file", lambda: setattr(win, "export_name", "vacanze"))
    passo("niente", lambda: None)
    return out


# ================= SOTTOTITOLI SULLA TELA =================
def crea_video(cartella: str) -> str:
    """Video di prova di 4 s (320×240, 30 fps) con l'audio: voce finta a tratti, separati da silenzi."""
    import av
    from array import array
    path = os.path.join(cartella, "video_prova.mp4")
    with av.open(path, "w") as c:
        v = c.add_stream("libx264", rate=30)
        v.width, v.height, v.pix_fmt = 320, 240, "yuv420p"
        a = c.add_stream("aac", rate=44100)
        a.layout = "mono"
        for i in range(120):
            img = Image.new("RGB", (320, 240), ((i * 2) % 256, 120, 200 - i))
            for pkt in v.encode(av.VideoFrame.from_image(img)):
                c.mux(pkt)
        n = 1024
        for k in range(0, 44100 * 4, n):
            campioni = array("h", [int(12000 * math.sin(2 * math.pi * 220 * (k + j) / 44100.0))
                                   if ((k + j) / 44100.0) % 1.0 < 0.7 else 0 for j in range(n)])
            fr = av.AudioFrame(format="s16", layout="mono", samples=n)
            fr.planes[0].update(campioni.tobytes())
            fr.sample_rate = 44100
            fr.pts = k
            for pkt in a.encode(fr):
                c.mux(pkt)
        for pkt in list(v.encode()) + list(a.encode()):
            c.mux(pkt)
    return path


FRASI_PROVA = [
    {"start": 0.0, "end": 0.7, "text": "Ciao a tutti!", "tr": "Hi everyone!", "auto": True},
    {"start": 1.0, "end": 1.7, "text": "Oggi vi porto al mare", "tr": ""},
    {"start": 2.0, "end": 2.7, "text": "e vi faccio vedere una spiaggia bellissima, lunga e piena di sole",
     "tr": "and I show you a beach", "auto": True, "words": [{"w": "e", "s": 2.0, "e": 2.1}]},
    {"start": None, "end": None, "text": "Frase senza tempi", "tr": ""},
]


def sottotitoli_tela(win, foto: list, video: str) -> tuple:
    """
    Un video con il suo blocco di sottotitoli: il progetto salvato (da rileggere identico col motore) e azioni
    vere del desktop con lo stato prima e dopo e il nome del passaggio.
    """
    import copy
    casi = []

    def prepara():
        tela_iniziale(win, foto, tela(0, None, 2, "grid"), 2)
        v = win._spawn_photo_item(video)
        v.set_free(True)
        v.set_cell_size(540, 720)
        v.setPos(1080 + 270, 300)
        v.set_trim(0.5, 3.5)
        c = win._spawn_caption_item(v.uid)
        win._place_new_caption(c, v)
        c.setZValue(win._max_z() + 1.0)
        c.set_phrases(copy.deepcopy(FRASI_PROVA))
        c.tr_lang = "en"
        win._flush_pending_commit()
        win._restore_snapshot(win._snapshot())
        return v, c

    def passo(nome, azione, op=None):
        prepara()
        a = stato_completo(win)
        azione()
        win._flush_pending_commit()
        win._commit_history()
        b = stato_completo(win)
        casi.append({"id": nome, "nome": None, "op": op, "prima": a, "dopo": b})

    cap = win.get_canvas_captions
    passo("sottotitoli-spostati", lambda: cap()[0].moveBy(0, -40), None)
    passo("sottotitoli-modificati", lambda: cap()[0].set_phrases(FRASI_PROVA[:2]), None)
    passo("sottotitoli-stile", lambda: (setattr(cap()[0], "tr_size", 55), cap()[0].relayout()), None)
    passo("sottotitoli-larghezza", lambda: (setattr(cap()[0], "wrap_w", 600.0), cap()[0].relayout()), None)
    passo("pagina-duplicata", lambda: win._duplicate_page(1), ["duplica_pagina", 1])
    passo("pagina-eliminata", lambda: win._delete_page(1), ["elimina_pagina", 1])
    passo("video-eliminato", lambda: win.scene.removeItem(win.get_canvas_videos()[0]), ["elimina_video"])
    passo("tela-svuotata", lambda: win.clear_canvas_photos(), ["svuota"])
    for caso in casi:
        caso["nome"] = win._describe_change(_senza_misure(caso["prima"]), _senza_misure(caso["dopo"]))

    prepara()
    c = cap()[0]
    c.tr_color = QColor("#80FF0000")
    c.tr_italic, c.tr_show, c.lang = False, True, "it"
    c.font_size, c.box, c.outline = 64.0, True, 2.0
    c.relayout()
    win._flush_pending_commit()
    data = win._project_data(win._snapshot(), os.path.dirname(foto[0]))
    for s in data["items"]:
        s["path"] = s["rel"] = os.path.basename(s["path"])
    data["library"] = []
    return json.loads(json.dumps(data)), casi


def _senza_misure(stato: dict) -> dict:
    """Stato completo senza i campi delle prove (`image`, `text_size`, `caption_size`), per `_describe_change`."""
    s = json.loads(json.dumps(stato))
    for k, campo in (("items", "image"), ("texts", "text_size"), ("captions", "caption_size")):
        for e in s.get(k, []):
            e.pop(campo, None)
    return s


# ================= SELEZIONE MULTIPLA, APPUNTI, LIVELLI =================
def tipo_el(it) -> str:
    return "text" if isinstance(it, TextItem) else "shape" if isinstance(it, ShapeItem) else "photo"


def seleziona_el(win, indici) -> list:
    """Seleziona gli elementi in quelle posizioni di `_all_elements()` (un gruppo si seleziona intero) e restituisce
    i loro riferimenti [tipo, uid]: la selezione vera, dopo l'espansione dei gruppi."""
    els = win._all_elements()
    win.scene.clearSelection()
    for i in indici:
        els[i % len(els)].setSelected(True)
    return [[tipo_el(it), it.uid] for it in win._selected_elements()]


def applica_selezione(win, op: str, args: list) -> list:
    """Esegue un comando sulla selezione come lo farebbe l'utente; restituisce gli argomenti da registrare."""
    if op in ("paste",):
        win._paste_elements(args[0])
        args = [args[0]]
    else:
        refs = seleziona_el(win, args[0])
        if op == "group":
            win._group_selected()
        elif op == "ungroup":
            win._ungroup_selected()
        elif op == "align":
            win._align_selected(args[1])
        elif op == "distribute":
            win._distribute_selected(args[1])
        elif op == "toggle_lock":
            win._toggle_lock_selected()
        elif op == "front":
            win._bring_to_front()
        elif op == "back":
            win._send_to_back()
        elif op == "copy":
            win._copy_selected()
        elif op == "cut":
            win._cut_selected()
        else:
            raise ValueError(op)
        args = [refs] + list(args[1:])
    win._flush_pending_commit()
    return args


def casi_selezione(win, foto: list) -> list:
    """(id, stato iniziale, azioni, stato finale): comandi sulla selezione, gli appunti e i livelli."""
    out = []
    t3 = [(0, 100, 100), (1, 300, 900), (2, 50, 1200)]
    f3 = [(1, 500, 200), (2, 700, 700)]
    basi = [("s3", tela(0, None, 3, "grid"), 9, {"testi": t3, "forme": f3}),
            ("s3libere", tela(0, None, 3, "strips_h"), 8, {"libere": [1, 4], "testi": t3, "forme": f3})]
    # Posizioni in `_all_elements()`: foto, poi testi, poi forme
    sel = {"foto3": [0, 1, 2], "colonna": [0, 3, 6], "testi": None, "misti": None, "una": [4], "forme": None,
           "tutti": None, "quattro": [2, 5, 8, 11]}
    for nome, c, n, opz in basi:
        nf = n
        sel["testi"] = [nf, nf + 1, nf + 2]
        sel["misti"] = [0, nf, nf + 3]
        sel["forme"] = [nf + 3, nf + 4]
        sel["tutti"] = list(range(nf + 5))
        sel["quattro"] = [2, 5, nf, nf + 4]
        azioni = []
        for sn, idx in sel.items():
            azioni += [(f"{sn}-group", [["group", [idx]]]),
                       (f"{sn}-group-ungroup", [["group", [idx]], ["ungroup", [idx]]]),
                       (f"{sn}-lock", [["toggle_lock", [idx]]]),
                       (f"{sn}-lock-lock", [["toggle_lock", [idx]], ["toggle_lock", [idx]]]),
                       (f"{sn}-front", [["front", [idx]]]),
                       (f"{sn}-back", [["back", [idx]]]),
                       (f"{sn}-copy-paste", [["copy", [idx]], ["paste", [0]], ["paste", [0]]]),
                       (f"{sn}-copy-paste1", [["copy", [idx]], ["paste", [1]]]),
                       (f"{sn}-cut-paste", [["cut", [idx]], ["paste", [0]]]),
                       (f"{sn}-cut-paste2", [["cut", [idx]], ["paste", [2]]])]
            azioni += [(f"{sn}-align-{how}", [["align", [idx, how]]])
                       for how in ("left", "hcenter", "right", "top", "vcenter", "bottom")]
            azioni += [(f"{sn}-distribute-{'h' if h else 'v'}", [["distribute", [idx, h]]]) for h in (True, False)]
        azioni += [("lock-then-align", [["toggle_lock", [[1]]], ["align", [[0, 1, 2], "left"]]]),
                   ("lock-then-distribute", [["toggle_lock", [[1]]], ["distribute", [[0, 1, 2, 3], True]]]),
                   ("group-then-front", [["group", [[0, 1]]], ["front", [[0]]]]),
                   ("group-then-copy", [["group", [[0, 1]]], ["copy", [[1]]], ["paste", [1]]]),
                   ("group-lock-paste", [["toggle_lock", [[0]]], ["copy", [[0, 1]]], ["paste", [0]]])]
        for nome_az, ops in azioni:
            out.append((f"{nome}-{nome_az}", c, n, opz, ops))
    return out


def esegui_caso_selezione(win, foto: list, nome: str, c: dict, n: int, opz: dict, ops: list) -> dict:
    tela_iniziale(win, foto, c, n, **opz)
    # Un po' di rotazione: l'ingombro di un elemento ruotato è diverso dal suo riquadro
    els = win._all_elements()
    els[1].setRotation(20)
    els[len(win.get_canvas_photos())].setRotation(-30)
    # A parità di livello o di posizione l'ordine della selezione di Qt non è definito (`selectedItems()` è un
    # insieme): livelli e posizioni tutti diversi, così il risultato del desktop non dipende da quell'ordine
    for i, it in enumerate(els):
        it.moveBy(i * 7, i * 11)
        if tipo_el(it) != "photo":
            it.setZValue(20 + i)
    win._flush_pending_commit()
    win._restore_snapshot(win._snapshot())
    prima = stato_completo(win)
    fatte = [[op, applica_selezione(win, op, list(args))] for op, args in ops]
    return {"id": nome, "prima": prima, "azioni": fatte, "dopo": stato_completo(win)}



def _ridotto(win, snap: dict) -> dict:
    snap = json.loads(json.dumps(snap))
    for s in snap["items"]:
        s["path"] = os.path.basename(s["path"])
    return snap


def progetti_desktop(win, foto: list) -> dict:
    """Progetti salvati dal desktop con tutti i tipi di elemento e impostazione: {nome: dati del file}."""
    out = {}

    def salva(nome):
        win._flush_pending_commit()
        data = win._project_data(win._snapshot(), os.path.dirname(foto[0]))
        for s in data["items"]:
            s["path"] = s["rel"] = os.path.basename(s["path"])
        data["library"] = [{"path": os.path.basename(p), "rel": os.path.basename(p)} for p in foto[:4]]
        out[nome] = json.loads(json.dumps(data))

    tela_iniziale(win, foto, tela(2, None, 4, "mosaic", style="two"), 14, testi=[(0, 80, 90), (3, 200, 1000)],
                  forme=[(1, 100, 100), (2, 400, 500), (3, 10, 10)], libere=[5], unite=[1], bloccate=[3],
                  proprie={0: "strips_v"})
    p = win.get_canvas_photos()
    p[0].apply_crop([0.1, 0.0, 0.8, 0.9])
    p[1].stretch = 1.4
    p[2].adjust = dict(p[2].adjust, brightness=15, warmth=-10, bw=True)
    p[2].flip_h = True
    p[3].fit_mode = "contain"
    p[3].set_photo_opacity(70)
    p[3].set_shadow(40)
    p[4].border_radius, p[4].border_width = 12.0, 5.0
    p[4].inner_zoom, p[4].pan_x, p[4].inner_rotation = 1.8, 0.3, 7.5
    p[6].reset_aspect_to_original()
    p[7].apply_cutout(STELLA, 22)
    p[7].border_width, p[7].shadow = 4.0, 25
    p[0].group = p[1].group = 1
    t = win.get_canvas_texts()[0]
    t.set_text("Due righe\ncon accenti: è à ò")
    t.box, t.outline, t.letter_spacing, t.line_height = True, 3.0, 10, 120
    s = win.get_canvas_shapes()[0]
    s.stroke_width, s.stroke_style, s.corner_radius = 4.0, "dash", 20.0
    sc = win.scene
    sc.bg_mode, sc.bg_direction, sc.page_numbers, sc.page_number_format = "gradient", "diagonal", True, "of"
    sc.swipe_hint, sc.swipe_text, sc.overlay_style = True, "Scorri ⟶", "light"
    win.export_name = "prova"
    salva("completo")
    tela_iniziale(win, foto, tela(4, None, 1, "scatter"), 5)
    salva("polaroid")
    tela_iniziale(win, foto, tela(8, (1000, 2000), 3, "scrl_seam"), 11)
    salva("a-cavallo")
    return out


# ================= VERIFICA: il desktop riapre i progetti scritti dal motore =================
def confronta(atteso, trovato, dove: str, errori: list):
    if isinstance(atteso, dict) and isinstance(trovato, dict):
        for k, v in atteso.items():
            if k in trovato:
                confronta(v, trovato[k], f"{dove}.{k}", errori)
    elif isinstance(atteso, list) and isinstance(trovato, list) and len(atteso) == len(trovato):
        for i, (a, b) in enumerate(zip(atteso, trovato)):
            confronta(a, b, f"{dove}[{i}]", errori)
    elif isinstance(atteso, (int, float)) and isinstance(trovato, (int, float)) and not isinstance(atteso, bool):
        if abs(atteso - trovato) > 0.001:
            errori.append(f"{dove}: {atteso} ≠ {trovato}")
    elif atteso != trovato:
        errori.append(f"{dove}: {atteso!r} ≠ {trovato!r}")


def verifica_progetto(win, path: str) -> list:
    """Apre il progetto nel desktop e lo confronta con il file. Restituisce gli errori trovati."""
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    DIALOGHI.clear()
    if not win._load_project_file(path):
        return [f"non aperto: {DIALOGHI}"]
    errori = [f"avviso del desktop: {d}" for d in DIALOGHI if d[0] != "ricollega"]
    snap = win._snapshot()
    tela_file = dict(data["canvas"])
    tela_file.pop("bg_blur_rel", None)
    confronta({k: v for k, v in tela_file.items() if k in snap["canvas"]}, snap["canvas"], "canvas", errori)
    attesi_mancanti = set()
    per_uid = {s["uid"]: s for s in snap["items"]}
    items = {p.uid: p for p in win.get_canvas_photos()}
    if set(per_uid) != {s["uid"] for s in data["items"]}:
        errori.append(f"foto diverse: {sorted(per_uid)}")
    for s in data["items"]:
        trovato = per_uid.get(s["uid"])
        if trovato is None:
            continue
        noti = {k: v for k, v in s.items() if k in trovato and k != "path"}
        confronta(noti, trovato, f"items[{s['uid']}]", errori)
        p = items[s["uid"]]
        if "asset" in s:
            # Foto della galleria del telefono: sul PC è «Foto mancante», col nome originale
            attesi_mancanti.add(s["asset"]["name"])
            if not p.is_missing or os.path.basename(p.image_path) != s["asset"]["name"]:
                errori.append(f"items[{s['uid']}]: asset non mostrato come «{p.MISSING_LABEL}»")
        elif p.is_missing:
            errori.append(f"items[{s['uid']}]: foto non trovata ({s.get('rel')})")
    for chiave in ("texts", "shapes"):
        trovati = {s["uid"]: s for s in snap[chiave]}
        for s in data.get(chiave, []):
            confronta({k: v for k, v in s.items() if k in trovati.get(s["uid"], {})}, trovati.get(s["uid"], {}),
                      f"{chiave}[{s['uid']}]", errori)
        if set(trovati) != {s["uid"] for s in data.get(chiave, [])}:
            errori.append(f"{chiave} diversi")
    ricollega = [d[1] for d in DIALOGHI if d[0] == "ricollega"]
    proposti = set(ricollega[0]) if ricollega else set()
    if not attesi_mancanti <= proposti:
        errori.append(f"«Ricollega foto» non propone {attesi_mancanti - proposti}")
    # Risalvato dal desktop: il campo `asset` si perde (accettato dal piano), il resto resta
    out = os.path.join(os.path.dirname(path), "risalvato.scrlproj")
    if not win._write_project(out):
        errori.append("non risalvato")
    return errori


def verifica(cartella: str) -> int:
    """Copia i progetti accanto alle foto di prova (anche in `media/`) e li apre uno per uno nel desktop."""
    progetti = sorted(f for f in os.listdir(cartella) if f.endswith(".scrlproj"))
    if not progetti:
        raise SystemExit(f"Nessun progetto in {cartella}")
    tmp = tempfile.mkdtemp(prefix="scrl_verifica_")
    falliti = 0
    try:
        isola_finestra(tmp)
        crea_foto(tmp)
        os.makedirs(os.path.join(tmp, "media"))
        for f in os.listdir(tmp):
            if f.endswith(".png"):
                shutil.copy(os.path.join(tmp, f), os.path.join(tmp, "media", f))
        win = MainWindow()
        win._autosave_timer.stop()
        for nome in progetti:
            shutil.copy(os.path.join(cartella, nome), os.path.join(tmp, nome))
            errori = verifica_progetto(win, os.path.join(tmp, nome))
            print(("OK      " if not errori else "ERRORE  ") + nome)
            for e in errori[:20]:
                print("        " + e)
            falliti += bool(errori)
        win.close()
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    print(f"{len(progetti) - falliti} di {len(progetti)} progetti riaperti identici dal desktop")
    return 1 if falliti else 0


# ================= SCAMBIO .ZIP (Fase 9) =================
def estrai_zip(percorso_zip: str, cartella: str) -> str:
    """Estrae lo zip come farebbe l'utente sul PC e restituisce il percorso del `.scrlproj` più vicino alla radice."""
    import zipfile
    with zipfile.ZipFile(percorso_zip) as z:
        if z.testzip() is not None:
            raise SystemExit("lo zip ha un file rovinato")
        z.extractall(cartella)
        progetti = sorted((n for n in z.namelist() if n.lower().endswith(".scrlproj")),
                          key=lambda n: (n.count("/"), n))
    if not progetti:
        raise SystemExit("nello zip non c'è nessun .scrlproj")
    return os.path.join(cartella, *progetti[0].split("/"))


def verifica_zip(percorso_zip: str) -> int:
    """Telefono → PC: lo zip estratto si apre nel desktop identico al file e con tutte le foto trovate."""
    tmp = tempfile.mkdtemp(prefix="scrl_verifica_zip_")
    try:
        isola_finestra(tmp)
        scrlproj = estrai_zip(percorso_zip, os.path.join(tmp, "estratto"))
        with open(scrlproj, encoding="utf-8") as f:
            dati = json.load(f)
        win = MainWindow()
        win._autosave_timer.stop()
        errori = verifica_progetto(win, scrlproj)
        # Nessun `asset` deve essere rimasto: sul PC non avrebbe senso
        if '"asset"' in json.dumps(dati):
            errori.append("il progetto nello zip contiene ancora il campo `asset`")
        for s in dati["items"]:
            rel = s.get("rel")
            if not rel or s.get("path") != rel or not os.path.isfile(os.path.join(os.path.dirname(scrlproj), rel)):
                errori.append(f"items[{s['uid']}]: percorso relativo mancante o file assente ({rel!r}, {s.get('path')!r})")
        n = len(dati["items"])
        win.close()
        print(("OK      " if not errori else "ERRORE  ") + f"{os.path.basename(percorso_zip)}: {n} foto aperte dal desktop")
        for e in errori[:20]:
            print("        " + e)
        return 1 if errori else 0
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def crea_zip_desktop(uscita: str) -> int:
    """PC → telefono: progetto vero del desktop, raccolto con «Raccogli progetto» e zippato come farebbe l'utente."""
    import zipfile
    from PyQt6.QtWidgets import QFileDialog
    tmp = tempfile.mkdtemp(prefix="scrl_zip_desktop_")
    try:
        isola_finestra(tmp)
        # Foto piccole (poche migliaia di byte): lo zip finisce tra i dati di riferimento della repo
        misure = [(90, 120), (120, 90), (100, 100), (128, 72)]
        foto = []
        for i, (w, h) in enumerate(misure):
            img = Image.new("RGB", (w, h))
            px = img.load()
            for y in range(h):
                for x in range(w):
                    px[x, y] = ((60 * i + x * 160 // w) % 256, (90 * i + 40 + y * 160 // h) % 256, 80 + 40 * i)
            p = os.path.join(tmp, f"Foto di viaggio {i + 1}.png")
            img.save(p)
            foto.append(p)
        win = MainWindow()
        win._autosave_timer.stop()
        loaded, errors = win._load_into_library(foto, "Foto di prova")
        if errors or len(loaded) != len(foto):
            raise SystemExit(f"Foto di prova non caricate: {errors}")
        c = tela(ratio_index=2, frames=2, mode="grid", seed=4242)
        tela_iniziale(win, foto, c, 4, testi=[(0, 120, 200)], forme=[(1, 100, 300)])
        win._schedule_commit()  # Il salvataggio scrive l'ultimo passo della cronologia
        win._flush_pending_commit()
        genitore = os.path.join(tmp, "Documenti")
        os.makedirs(genitore)
        QFileDialog.getExistingDirectory = staticmethod(lambda *a, **k: genitore)
        QMessageBox.exec = lambda self: 0  # «Progetto raccolto»: nessuno preme «Ok»
        win.collect_project()
        raccolti = [d for d in os.listdir(genitore) if os.path.isdir(os.path.join(genitore, d))]
        if len(raccolti) != 1:
            raise SystemExit(f"«Raccogli progetto» non ha creato la cartella: {os.listdir(genitore)}")
        cartella = os.path.join(genitore, raccolti[0])
        os.makedirs(os.path.dirname(uscita), exist_ok=True)
        # Come «Invia a → Cartella compressa»: lo zip contiene la cartella intera
        with zipfile.ZipFile(uscita, "w", zipfile.ZIP_DEFLATED) as z:
            for radice, _dirs, files in os.walk(cartella):
                for f in sorted(files):
                    pieno = os.path.join(radice, f)
                    nome = os.path.join(raccolti[0], os.path.relpath(pieno, cartella)).replace(os.sep, "/")
                    if f.endswith(".scrlproj"):
                        # I percorsi assoluti del desktop non devono rivelare la cartella temporanea di chi genera
                        with open(pieno, encoding="utf-8") as fp:
                            testo = fp.read().replace(json.dumps(genitore)[1:-1],
                                                      json.dumps("C:\\Users\\utente\\Documenti")[1:-1])
                        z.writestr(nome, testo.encode("utf-8"))
                    else:
                        z.write(pieno, nome)
        win.close()
        with zipfile.ZipFile(uscita) as z:
            print(f"{os.path.relpath(uscita, ROOT)}: " + ", ".join(z.namelist()))
        return 0
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--uscita", default=USCITA_PREDEFINITA, help="cartella dei dati di riferimento")
    ap.add_argument("--senza-immagini", action="store_true", help="non esporta le pagine campione")
    ap.add_argument("--solo-selezione", action="store_true",
                    help="scrive soltanto selezione.jsonl (gli altri dati di riferimento restano com'erano)")
    ap.add_argument("--solo-sottotitoli", action="store_true",
                    help="scrive soltanto sottotitoli.json (gli altri dati di riferimento restano com'erano)")
    ap.add_argument("--verifica", metavar="CARTELLA",
                    help="invece di generare: apre nel desktop i .scrlproj della cartella e li confronta col file")
    ap.add_argument("--verifica-zip", metavar="FILE.zip",
                    help="apre nel desktop lo .zip di «Condividi progetto» del telefono e controlla le foto")
    ap.add_argument("--crea-zip-desktop", metavar="FILE.zip", nargs="?",
                    const=os.path.join(ROOT, "mobile", "app", "test", "riferimenti", "progetto-desktop.zip"),
                    help="crea lo .zip di un progetto raccolto dal desktop (di partenza tra i riferimenti dell'app)")
    args = ap.parse_args()

    app = QApplication(sys.argv)
    # Nomi diversi da quelli veri: anche percorsi standard e cache restano separati
    app.setOrganizationName("SCRL-riferimenti")
    app.setApplicationName("genera_riferimenti")
    vere_prima = impostazioni_vere()
    neutralizza_dialoghi()

    if args.verifica_zip or args.crea_zip_desktop:
        esito = (verifica_zip(os.path.abspath(args.verifica_zip)) if args.verifica_zip
                 else crea_zip_desktop(os.path.abspath(args.crea_zip_desktop)))
        if impostazioni_vere() != vere_prima:
            raise SystemExit("ERRORE: le impostazioni vere di ScrolleR Studio sono cambiate")
        raise SystemExit(esito)

    if args.verifica:
        esito = verifica(os.path.abspath(args.verifica))
        if impostazioni_vere() != vere_prima:
            raise SystemExit("ERRORE: le impostazioni vere di ScrolleR Studio sono cambiate durante la verifica")
        raise SystemExit(esito)

    tmp = tempfile.mkdtemp(prefix="scrl_riferimenti_")
    try:
        isola_finestra(tmp)
        foto = crea_foto(tmp)
        win = MainWindow()
        win._autosave_timer.stop()
        loaded, errors = win._load_into_library(foto, "Foto di prova")
        if errors or len(loaded) != len(foto):
            raise SystemExit(f"Foto di prova non caricate: {errors}")

        os.makedirs(args.uscita, exist_ok=True)
        if args.solo_sottotitoli:
            scrivi_sottotitoli(args.uscita)
            scrivi_sottotitoli_tela(win, foto, tmp, args.uscita, aggiorna_indice=True)
            win.close()
            return
        if args.solo_selezione:
            selezione = casi_selezione(win, foto)
            with open(os.path.join(args.uscita, "selezione.jsonl"), "w", encoding="utf-8", newline="\n") as f:
                for nome, c, n, opz, ops in selezione:
                    caso = esegui_caso_selezione(win, foto, nome, c, n, opz, ops)
                    f.write(json.dumps(caso, ensure_ascii=False, separators=(",", ":")) + "\n")
            win.close()
            print(f"{len(selezione)} casi di selezione in {os.path.relpath(args.uscita, ROOT)}")
            return
        elenco = casi()
        with open(os.path.join(args.uscita, "disposizioni.jsonl"), "w", encoding="utf-8", newline="\n") as f:
            for nome, c, n, extra in elenco:
                caso = esegui_caso(win, foto, nome, c, n, extra)
                f.write(json.dumps(caso, ensure_ascii=False, separators=(",", ":")) + "\n")
        with open(os.path.join(args.uscita, "casuale.json"), "w", encoding="utf-8", newline="\n") as f:
            json.dump(casuale(), f, indent=1)
        with open(os.path.join(args.uscita, "colore.json"), "w", encoding="utf-8", newline="\n") as f:
            json.dump(colore(), f)
        with open(os.path.join(args.uscita, "geometria.json"), "w", encoding="utf-8", newline="\n") as f:
            json.dump(geometria(), f, indent=1)
        with open(os.path.join(args.uscita, "ritaglio.json"), "w", encoding="utf-8", newline="\n") as f:
            json.dump(ritaglio(), f)
        with open(os.path.join(args.uscita, "strumenti_foto.json"), "w", encoding="utf-8", newline="\n") as f:
            json.dump(strumenti_foto(), f)
        with open(os.path.join(args.uscita, "sagoma.json"), "w", encoding="utf-8", newline="\n") as f:
            json.dump(sagoma(), f)
        scrivi_sottotitoli(args.uscita)
        immagini = []
        if not args.senza_immagini:
            immagini = esporta_immagini(win, foto, os.path.join(args.uscita, "immagini"))
        pagine = casi_pagine()
        with open(os.path.join(args.uscita, "pagine.jsonl"), "w", encoding="utf-8", newline="\n") as f:
            for nome, c, n, opz, ops in pagine:
                caso = esegui_caso_pagine(win, foto, nome, c, n, opz, ops)
                f.write(json.dumps(caso, ensure_ascii=False, separators=(",", ":")) + "\n")
        cronologia = casi_cronologia(win, foto)
        with open(os.path.join(args.uscita, "cronologia.jsonl"), "w", encoding="utf-8", newline="\n") as f:
            for caso in cronologia:
                f.write(json.dumps(caso, ensure_ascii=False, separators=(",", ":")) + "\n")
        cartella_progetti = os.path.join(args.uscita, "progetti")
        os.makedirs(cartella_progetti, exist_ok=True)
        progetti = progetti_desktop(win, foto)
        progetti["sottotitoli"] = scrivi_sottotitoli_tela(win, foto, tmp, args.uscita)
        for nome, data in progetti.items():
            with open(os.path.join(cartella_progetti, f"{nome}.scrlproj"), "w", encoding="utf-8", newline="\n") as f:
                json.dump(data, f, ensure_ascii=False, indent=1)
        with open(os.path.join(args.uscita, "indice.json"), "w", encoding="utf-8", newline="\n") as f:
            json.dump({"desktop": APP_VERSION, "casi_disposizioni": len(elenco), "immagini": immagini,
                       "casi_pagine": len(pagine), "casi_cronologia": len(cronologia),
                       "progetti": sorted(f"{n}.scrlproj" for n in progetti),
                       "foto": [[os.path.basename(p), w, h] for p, (w, h) in zip(foto, FOTO)]},
                      f, ensure_ascii=False, indent=1)
        win.close()
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    if impostazioni_vere() != vere_prima:
        raise SystemExit("ERRORE: le impostazioni vere di ScrolleR Studio sono cambiate durante la generazione")
    print(f"{len(elenco)} casi di disposizione, {len(pagine)} di pagine, {len(cronologia)} di cronologia, "
          f"{len(progetti)} progetti, {len(immagini)} immagini in {os.path.relpath(args.uscita, ROOT)}")


if __name__ == "__main__":
    main()
