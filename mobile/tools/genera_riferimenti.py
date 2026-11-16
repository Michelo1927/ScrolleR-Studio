"""
Genera i dati di riferimento per le prove del motore mobile (piano §13) usando l'app desktop vera,
in modalità offscreen.

Uso, dalla root della repo e con l'ambiente Python del desktop:

    python mobile/tools/genera_riferimenti.py [--uscita CARTELLA] [--senza-immagini]
    python mobile/tools/genera_riferimenti.py --verifica CARTELLA

La seconda forma non genera niente: apre nel desktop i `.scrlproj` della cartella (per esempio quelli riscritti
dal motore con `dart run tool/riscrivi_progetti.dart`) e controlla che si riaprano identici, con le foto della
galleria del telefono (campo `asset`) mostrate come «Foto mancante».

Produce in `mobile/packages/scrl_engine/test/riferimenti/`:
- `disposizioni.jsonl`: un caso per riga. `prima` è lo stato di partenza (tela + foto con le proporzioni
  usate dal desktop), `dopo` è il risultato di `apply_auto_layout`: rettangoli, rotazione, bordo automatico
  e liste per pagina. Le prove Dart confrontano i rettangoli con tolleranza 0,001.
- `casuale.json`: valori di `random.Random(seme)` (Mersenne Twister) per portare il generatore di Python.
- `immagini/`: alcune pagine esportate dal desktop, con il progetto che le ha prodotte.
- `pagine.jsonl`: azioni vere del desktop su pagine e tela (inserisci, duplica, elimina, sposta, riordina,
  blocca, unisci, disposizione e foto di una pagina, numero di pagine, formato…), una sequenza per riga, con lo
  stato completo prima e dopo.
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
from PyQt6.QtWidgets import QApplication, QMessageBox  # noqa: E402

from scrollr import __version__ as APP_VERSION  # noqa: E402
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
    return out


# ================= ESECUZIONE =================
def stato_foto(p, nome: str) -> dict:
    return {
        "uid": p.uid, "rel": nome, "x": p.pos().x(), "y": p.pos().y(), "w": p.cell_w, "h": p.cell_h,
        "rotation": p.rotation(), "z": p.zValue(), "layout_index": p.layout_index, "crop": list(p.crop),
        "stretch": p.stretch, "free": p.free, "page_locked": p.page_locked, "border_width": p.border_width,
        "auto_border": p.auto_border, "image": [p.pixmap.width(), p.pixmap.height()], "ratio": p.source_ratio(),
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
    nomi = {p.uid: os.path.basename(p.image_path) for p in items}
    prima = {"canvas": win._snapshot()["canvas"], "items": [stato_foto(p, nomi[p.uid]) for p in items]}
    prima["canvas"].pop("export_name", None)
    win.apply_auto_layout(c["layout_mode"])
    dopo = {"canvas": stato_tela(win),
            "items": [{k: v for k, v in stato_foto(p, nomi[p.uid]).items()
                       if k in ("uid", "x", "y", "w", "h", "rotation", "border_width", "auto_border")}
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


def esporta_immagini(win, foto: list, cartella: str) -> list:
    os.makedirs(cartella, exist_ok=True)
    campioni = [("immagine-griglia", tela(0, None, 2, "grid"), 6, {}),
                ("immagine-polaroid", tela(2, None, 1, "scatter", seed=777), 5, {}),
                ("immagine-unite", tela(3, None, 3, "mosaic", seams=[True, False]), 9, {})]
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


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--uscita", default=USCITA_PREDEFINITA, help="cartella dei dati di riferimento")
    ap.add_argument("--senza-immagini", action="store_true", help="non esporta le pagine campione")
    ap.add_argument("--verifica", metavar="CARTELLA",
                    help="invece di generare: apre nel desktop i .scrlproj della cartella e li confronta col file")
    args = ap.parse_args()

    app = QApplication(sys.argv)
    # Nomi diversi da quelli veri: anche percorsi standard e cache restano separati
    app.setOrganizationName("SCRL-riferimenti")
    app.setApplicationName("genera_riferimenti")
    vere_prima = impostazioni_vere()
    neutralizza_dialoghi()

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
        elenco = casi()
        with open(os.path.join(args.uscita, "disposizioni.jsonl"), "w", encoding="utf-8", newline="\n") as f:
            for nome, c, n, extra in elenco:
                caso = esegui_caso(win, foto, nome, c, n, extra)
                f.write(json.dumps(caso, ensure_ascii=False, separators=(",", ":")) + "\n")
        with open(os.path.join(args.uscita, "casuale.json"), "w", encoding="utf-8", newline="\n") as f:
            json.dump(casuale(), f, indent=1)
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
