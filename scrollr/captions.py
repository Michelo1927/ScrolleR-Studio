"""
Sottotitoli: frasi, divisione del testo, righe bilanciate, file .srt, forma d'onda e pause dell'audio.
Niente Qt qui: le misure del testo arrivano come funzione `width(testo) -> larghezza`.

Una frase è un dizionario {"start", "end", "text", "tr"}: inizio e fine in secondi del video originale
(None finché non è sincronizzata), testo e traduzione. È la stessa forma salvata nel progetto, così un
motore di trascrizione potrà riempirla più avanti (con i tempi delle parole in un campo facoltativo).
Il campo facoltativo "auto" segna i tempi messi da soli dall'audio: si ridistribuiscono quando cambia il
testo, mentre quelli ritoccati a mano restano fermi.
"""
import difflib
import re
from array import array
from typing import Callable, List, Optional, Sequence, Tuple

MIN_PHRASE = 0.3       # Durata minima di una frase sincronizzata, in secondi
ENVELOPE_STEP = 0.01   # Passo della forma d'onda: 10 ms

# Parole prima delle quali si spezza volentieri una frase lunga
_CONJUNCTIONS = {
    "e", "ed", "ma", "però", "che", "perché", "quando", "se", "o", "oppure", "poi", "quindi", "mentre",
    "come", "anche", "allora", "cioè", "dove", "and", "but", "or", "so", "because", "when", "that", "if",
}
_SENTENCE_END = re.compile(r"(?<=[.!?…;:])\s+")


# ---------- Frasi ----------
def make_phrase(text: str = "", start: Optional[float] = None, end: Optional[float] = None, tr: str = "") -> dict:
    return {"start": start, "end": end, "text": text, "tr": tr}


def clean_phrases(data) -> List[dict]:
    """Frasi lette dal progetto: campi mancanti o sbagliati diventano i valori di partenza."""
    out = []
    for d in data if isinstance(data, list) else []:
        if not isinstance(d, dict):
            continue

        def num(v):
            try:
                return None if v is None else max(0.0, float(v))
            except (TypeError, ValueError):
                return None
        start, end = num(d.get("start")), num(d.get("end"))
        if start is not None and end is not None and end < start + 0.01:
            end = start + MIN_PHRASE
        p = make_phrase(str(d.get("text", "")), start, end, str(d.get("tr", "") or ""))
        if isinstance(d.get("words"), list):
            p["words"] = d["words"]  # Tempi delle parole (motore futuro): si conservano così come sono
        if d.get("auto") is True and start is not None and end is not None:
            p["auto"] = True
        out.append(p)
    return out


def phrase_state(p: dict) -> dict:
    """Forma salvata: tempi arrotondati al millesimo."""
    s = {"start": None if p.get("start") is None else round(p["start"], 3),
         "end": None if p.get("end") is None else round(p["end"], 3),
         "text": p.get("text", ""), "tr": p.get("tr", "")}
    if "words" in p:
        s["words"] = p["words"]
    if p.get("auto") and is_synced(p):
        s["auto"] = True
    return s


def is_synced(p: dict) -> bool:
    return p.get("start") is not None and p.get("end") is not None


def is_manual(p: dict) -> bool:
    """Tempi fissati a mano (o letti da un .srt): i tempi automatici non li spostano."""
    return is_synced(p) and not p.get("auto")


def phrase_index_at(phrases: Sequence[dict], t: float) -> int:
    """Indice della frase da mostrare al secondo t (-1 se nessuna): con frasi sovrapposte vince l'ultima iniziata."""
    best, best_start = -1, None
    for i, p in enumerate(phrases):
        if is_synced(p) and p["start"] <= t < p["end"] and (best_start is None or p["start"] >= best_start):
            best, best_start = i, p["start"]
    return best


def phrase_at(phrases: Sequence[dict], t: float) -> Optional[dict]:
    i = phrase_index_at(phrases, t)
    return phrases[i] if i >= 0 else None


def split_phrase(p: dict) -> Tuple[dict, dict]:
    """Divide una frase in due a metà circa (alla parola), con il tempo spartito in proporzione."""
    words = p.get("text", "").split()
    if len(words) < 2:
        a, b = dict(p), make_phrase("")
        if is_synced(p):
            mid = (p["start"] + p["end"]) / 2.0
            a["end"], b["start"], b["end"] = mid, mid, p["end"]
        return a, b
    half = len(p.get("text", "")) / 2.0
    k = min(range(1, len(words)), key=lambda i: abs(len(" ".join(words[:i])) - half)
            - (0.2 * half if words[i - 1].endswith(",") else 0.0))
    ta, tb = " ".join(words[:k]), " ".join(words[k:])
    a, b = make_phrase(ta, tr=p.get("tr", "")), make_phrase(tb)
    if is_synced(p):
        mid = p["start"] + (p["end"] - p["start"]) * len(ta) / max(1, len(ta) + len(tb))
        a["start"], a["end"], b["start"], b["end"] = p["start"], round(mid, 3), round(mid, 3), p["end"]
    return a, b


def join_phrases(a: dict, b: dict) -> dict:
    """Unisce due frasi: testo e traduzione uno dopo l'altro, tempo dall'inizio della prima alla fine della seconda."""
    p = make_phrase(f"{a.get('text', '')} {b.get('text', '')}".strip(),
                    tr=f"{a.get('tr', '')} {b.get('tr', '')}".strip())
    synced = [q for q in (a, b) if is_synced(q)]
    if synced:
        p["start"] = min(q["start"] for q in synced)
        p["end"] = max(q["end"] for q in synced)
    return p


def insert_index(phrases: Sequence[dict], start: float) -> int:
    """Posto in elenco per una frase che comincia a `start`: dopo le frasi sincronizzate che iniziano prima."""
    idx = 0
    for i, p in enumerate(phrases):
        if p.get("start") is not None and p["start"] <= start:
            idx = i + 1
    return idx


# ---------- Divisione del testo in frasi corte ----------
def _split_long(sentence: str, fits: Callable[[str], bool]) -> List[str]:
    """Spezza una frase che non sta in due righe, vicino al centro, preferendo virgole e congiunzioni."""
    words = sentence.split(" ")
    if len(words) < 2 or fits(sentence):
        return [sentence]
    total = len(sentence)
    best_k, best_score = 1, None
    for k in range(1, len(words)):
        left = " ".join(words[:k])
        right = " ".join(words[k:])
        score = abs(len(left) - len(right)) / total
        if words[k - 1].endswith((",", "—", "-")):
            score -= 0.30
        elif words[k].lower().strip("«\"'(") in _CONJUNCTIONS:
            score -= 0.15
        if k == 1 or k == len(words) - 1:
            score += 0.35  # Una parola sola da parte non fa una frase
        if best_score is None or score < best_score:
            best_k, best_score = k, score
    left = " ".join(words[:best_k])
    right = " ".join(words[best_k:])
    return _split_long(left, fits) + _split_long(right, fits)


def split_text(text: str, fits: Optional[Callable[[str], bool]] = None) -> List[str]:
    """
    Testo libero -> frasi corte, una per elemento: ogni riga resta separata, poi si divide alla
    punteggiatura di fine frase e infine le frasi troppo lunghe (fits falso) a metà circa.
    """
    if fits is None:
        def fits(s):
            return len(s) <= 84  # Senza misure: due righe da circa 42 caratteri
    out = []
    for line in text.splitlines():
        line = re.sub(r"\s+", " ", line).strip()
        if not line:
            continue
        for sentence in _SENTENCE_END.split(line):
            sentence = sentence.strip()
            if sentence:
                out += _split_long(sentence, fits)
    return out


def balance_lines(text: str, width: Callable[[str], float], max_w: float) -> List[str]:
    """
    Una riga se ci sta, altrimenti due righe di larghezza simile (la seconda un po' più lunga, come nei
    sottotitoli). Le righe possono superare max_w solo se la frase è davvero troppo lunga.
    """
    text = re.sub(r"\s+", " ", text).strip()
    if not text or width(text) <= max_w:
        return [text]
    words = text.split(" ")
    if len(words) < 2:
        return [text]
    best, best_score = None, None
    for k in range(1, len(words)):
        a, b = " ".join(words[:k]), " ".join(words[k:])
        wa, wb = width(a), width(b)
        score = max(wa, wb)
        if wa > wb:
            score += 0.03 * max_w
        if words[k - 1].endswith((",", ";", ":", "—")):
            score -= 0.08 * max_w
        if best_score is None or score < best_score:
            best, best_score = [a, b], score
    return best


def fits_two_lines(text: str, width: Callable[[str], float], max_w: float) -> bool:
    return all(width(line) <= max_w for line in balance_lines(text, width, max_w))


def merge_lines(old: List[dict], new_lines: List[str]) -> List[dict]:
    """
    Le righe della casella di testo tornano frasi senza perdere i tempi: le righe uguali tengono i loro,
    una riga divisa o unita si spartisce il tempo in proporzione ai caratteri, le righe nuove restano
    da sincronizzare.
    """
    old_lines = [p.get("text", "") for p in old]
    out: List[dict] = []
    sm = difflib.SequenceMatcher(a=old_lines, b=new_lines, autojunk=False)
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag == "equal":
            out += [dict(old[i]) for i in range(i1, i2)]
            continue
        lines = new_lines[j1:j2]
        if not lines:
            continue  # Righe tolte
        olds = old[i1:i2]
        if len(olds) == len(lines):
            for p, line in zip(olds, lines):  # Righe corrette una per una
                out.append(dict(p, text=line))
            continue
        out += _remap_lines(olds, lines)
    return out


def _remap_lines(olds: List[dict], lines: List[str]) -> List[dict]:
    """
    Righe divise, unite o riscritte: ogni lettera del testo vecchio ha un tempo (in proporzione dentro la
    sua frase) e ogni riga nuova prende i tempi delle lettere che le corrispondono. Una riga quasi tutta
    nuova resta da sincronizzare.
    """
    old_text, owner, times = "", [], []
    for k, p in enumerate(olds):
        if old_text:
            old_text += " "
            owner.append(-1)
            times.append(None)
        txt = p.get("text", "")
        for c in range(len(txt)):
            owner.append(k)
            times.append(p["start"] + (p["end"] - p["start"]) * c / max(1, len(txt)) if is_synced(p) else None)
        old_text += txt
    new_text = " ".join(lines)
    mapped = [-1] * len(new_text)
    sm = difflib.SequenceMatcher(a=old_text, b=new_text, autojunk=False)
    for a, b, size in sm.get_matching_blocks():
        for d in range(size):
            mapped[b + d] = a + d
    out = []
    used_tr = set()
    pos = 0
    for line in lines:
        idx = [mapped[i] for i in range(pos, pos + len(line)) if mapped[i] >= 0]
        pos += len(line) + 1
        p = make_phrase(line)
        if len(idx) >= max(1, 0.3 * len(line)):
            owners = [owner[i] for i in idx if owner[i] >= 0]
            ts = [times[i] for i in idx if times[i] is not None]
            if ts:
                last = max(idx)
                k = owner[last]
                end = (olds[k]["start"] + (olds[k]["end"] - olds[k]["start"]) *
                       (last - owner.index(k) + 1) / max(1, len(olds[k].get("text", "")))) \
                    if k >= 0 and is_synced(olds[k]) else max(ts)
                p["start"], p["end"] = round(min(ts), 3), round(max(end, min(ts) + MIN_PHRASE), 3)
            if owners:
                k = max(set(owners), key=owners.count)
                if (k not in used_tr and olds[k].get("tr")
                        and owners.count(k) >= 0.6 * len(olds[k].get("text", ""))):
                    p["tr"] = olds[k]["tr"]
                    used_tr.add(k)
                if any(olds[o].get("auto") for o in set(owners)):
                    p["auto"] = True  # Viene da tempi automatici: si ridistribuisce anche lei
        out.append(p)
    # I pezzi di una frase divisa si toccano: niente buchi brevi né sovrapposizioni tra loro
    for a, b in zip(out, out[1:]):
        if is_synced(a) and is_synced(b) and b["start"] > a["start"] and b["start"] - a["end"] < 0.3:
            a["end"] = b["start"]
    return out


# ---------- Tempi leggibili ----------
def format_clock(t: Optional[float]) -> str:
    """«0:07,25»: minuti, secondi e centesimi. Trattino se il tempo manca."""
    if t is None:
        return "–"
    t = max(0.0, t)
    cs = int(round(t * 100))
    m, cs = divmod(cs, 6000)
    s, cs = divmod(cs, 100)
    return f"{m}:{s:02d},{cs:02d}"


def parse_clock(text: str) -> Optional[float]:
    """Legge «1:02,5», «62.5», «0:01:02,500»; None se non è un tempo."""
    text = text.strip().replace(",", ".")
    if not text:
        return None
    try:
        parts = [float(x) for x in text.split(":")]
    except ValueError:
        return None
    if len(parts) > 3 or any(x < 0 for x in parts):
        return None
    t = 0.0
    for x in parts:
        t = t * 60 + x
    return t


# ---------- File .srt ----------
def _srt_time(t: float) -> str:
    ms = int(round(max(0.0, t) * 1000))
    h, ms = divmod(ms, 3_600_000)
    m, ms = divmod(ms, 60_000)
    s, ms = divmod(ms, 1000)
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"


def to_srt(phrases: Sequence[dict], field: str = "text") -> str:
    """Frasi sincronizzate (con testo nel campo scelto: «text» o «tr») in formato SubRip."""
    blocks = []
    rows = sorted((p for p in phrases if is_synced(p) and p.get(field, "").strip()), key=lambda p: p["start"])
    for n, p in enumerate(rows, 1):
        blocks.append(f"{n}\n{_srt_time(p['start'])} --> {_srt_time(p['end'])}\n{p[field].strip()}\n")
    return "\n".join(blocks)


_SRT_TIME = re.compile(r"(\d+):(\d{1,2}):(\d{1,2})[,.](\d{1,3})")


def parse_srt(text: str) -> List[dict]:
    """File .srt -> frasi (le righe di un sottotitolo diventano una frase sola, senza i tag <i>, {\\an8}…)."""
    text = text.replace("﻿", "").replace("\r\n", "\n").replace("\r", "\n")
    out = []
    for block in re.split(r"\n\s*\n", text):
        lines = [ln for ln in block.split("\n") if ln.strip()]
        idx = next((i for i, ln in enumerate(lines) if "-->" in ln), None)
        if idx is None:
            continue
        times = _SRT_TIME.findall(lines[idx])
        if len(times) < 2:
            continue

        def sec(g):
            h, m, s, ms = g
            return int(h) * 3600 + int(m) * 60 + int(s) + int(ms.ljust(3, "0")) / 1000.0
        body = " ".join(lines[idx + 1:])
        body = re.sub(r"<[^>]+>|\{[^}]*\}", "", body)
        body = re.sub(r"\s+", " ", body).strip()
        start, end = sec(times[0]), sec(times[1])
        out.append(make_phrase(body, start, max(end, start + MIN_PHRASE)))
    return out


# ---------- Forma d'onda e pause ----------
def envelope(pcm: bytes, rate: int, step: float = ENVELOPE_STEP) -> List[float]:
    """Picco del volume (0–1) ogni `step` secondi di audio mono s16."""
    a = array("h")
    a.frombytes(pcm[:len(pcm) // 2 * 2])
    n = max(1, int(rate * step))
    out = []
    for i in range(0, len(a), n):
        s = a[i:i + n]
        out.append(max(max(s), -min(s)) / 32768.0)
    return out


def find_pauses(env: Sequence[float], step: float = ENVELOPE_STEP, min_len: float = 0.25) -> List[Tuple[float, float]]:
    """
    Tratti di silenzio (inizio, fine) lunghi almeno min_len: la soglia sta poco sopra il rumore di fondo,
    stimata dai valori bassi e alti del volume.
    """
    if not env:
        return []
    ordered = sorted(env)
    noise = ordered[int(len(ordered) * 0.10)]
    loud = ordered[min(len(ordered) - 1, int(len(ordered) * 0.90))]
    thr = max(0.01, noise + (loud - noise) * 0.12)
    pauses = []
    run = None
    for i, v in enumerate(list(env) + [1.0]):
        if v < thr:
            if run is None:
                run = i
        elif run is not None:
            if (i - run) * step >= min_len:
                pauses.append((run * step, i * step))
            run = None
    return pauses


def snap_points(pauses: Sequence[Tuple[float, float]]) -> List[float]:
    """Punti a cui si agganciano i bordi delle frasi: dove una pausa comincia e dove finisce."""
    pts = []
    for a, b in pauses:
        pts += [a, b]
    return pts


def snap(t: float, points: Sequence[float], tol: float) -> float:
    best = min(points, key=lambda p: abs(p - t), default=None)
    return best if best is not None and abs(best - t) <= tol else t


# ---------- Tempi automatici dall'audio ----------
def speech_spans(pauses: Sequence[Tuple[float, float]], lo: float, hi: float) -> List[Tuple[float, float]]:
    """Tratti di parlato tra lo e hi: quello che resta togliendo le pause."""
    spans, t = [], lo
    for a, b in sorted(pauses):
        if a >= hi:
            break
        if b <= t:
            continue
        if a > t:
            spans.append((t, a))
        t = max(t, min(b, hi))
    if hi > t:
        spans.append((t, hi))
    return spans


def auto_times(weights: Sequence[float], pauses: Sequence[Tuple[float, float]], lo: float,
               hi: float) -> List[Tuple[float, float]]:
    """
    Inizio e fine di n frasi tra lo e hi: il tempo di parlato si spartisce in proporzione ai pesi (la
    lunghezza delle frasi), poi ogni stacco tra due frasi si sposta sulla pausa vicina, se ce n'è una:
    la frase prima finisce dove la voce tace, la successiva comincia dove riprende.
    """
    n = len(weights)
    if n == 0 or hi <= lo:
        return []
    spans = speech_spans(pauses, lo, hi)
    total = sum(b - a for a, b in spans)
    if total < MIN_PHRASE * n:  # Quasi tutto silenzio: si usa l'intero tratto
        spans, total = [(lo, hi)], hi - lo
    lens = [b - a for a, b in spans]
    gaps, acc = [], 0.0  # (posizione nel parlato, inizio della pausa, fine della pausa)
    for k in range(len(spans) - 1):
        acc += lens[k]
        gaps.append((acc, spans[k][1], spans[k + 1][0]))

    def real(s: float) -> float:
        for (a, b), length in zip(spans, lens):
            if s <= length + 1e-9:
                return a + s
            s -= length
        return spans[-1][1]

    w_total = float(sum(weights)) or 1.0
    tol = 0.35 * total / n
    starts, ends = [spans[0][0]], []
    acc, prev, gi = 0.0, 0.0, 0
    for w in weights[:-1]:
        acc += w
        cut = total * acc / w_total
        best = None
        for j in range(gi, len(gaps)):
            pos = gaps[j][0]
            if pos > cut + tol:
                break
            if pos - prev >= MIN_PHRASE and abs(pos - cut) <= tol and \
                    (best is None or abs(pos - cut) < abs(gaps[best][0] - cut)):
                best = j
        if best is not None:
            ends.append(gaps[best][1])
            starts.append(gaps[best][2])
            prev, gi = gaps[best][0], best + 1
        else:
            t = real(cut)
            ends.append(t)
            starts.append(t)
            prev = cut
            while gi < len(gaps) and gaps[gi][0] <= cut:
                gi += 1
    ends.append(spans[-1][1])
    return [(round(a, 3), round(max(b, a + 0.05), 3)) for a, b in zip(starts, ends)]


def phrase_weight(p: dict) -> float:
    """Quanto dura a voce una frase, a occhio: i caratteri più un piccolo fisso per frase."""
    return len(p.get("text", "").strip()) + 8.0


def retime(phrases: List[dict], pauses: Sequence[Tuple[float, float]], lo: float, hi: float,
           reset: bool = False) -> None:
    """
    Tempi automatici per le frasi senza tempi fissati a mano: ogni gruppo di frasi di seguito si
    distribuisce tra la frase fissata prima e quella dopo (o i bordi del taglio del video). Con reset
    si ridistribuisce tutto. Se non c'è posto, le frasi restano da sincronizzare.
    """
    if reset:
        for p in phrases:
            p["auto"] = True
    n, i = len(phrases), 0
    while i < n:
        if is_manual(phrases[i]):
            i += 1
            continue
        j = i
        while j < n and not is_manual(phrases[j]):
            j += 1
        a = max(lo, phrases[i - 1]["end"]) if i > 0 else lo
        b = min(hi, phrases[j]["start"]) if j < n else hi
        run = phrases[i:j]
        if b - a >= MIN_PHRASE * len(run):
            for p, (s, e) in zip(run, auto_times([phrase_weight(p) for p in run], pauses, a, b)):
                p["start"], p["end"], p["auto"] = s, e, True
        else:
            for p in run:
                p["start"] = p["end"] = None
                p.pop("auto", None)
        i = j
