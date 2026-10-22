"""Caricamento immagini (EXIF, profili ICC), regolazioni colore e cache delle anteprime."""
import hashlib
import io
import os
import threading
from collections import OrderedDict
from concurrent.futures import ThreadPoolExecutor
from typing import Dict, List, Optional

from PyQt6.QtCore import QObject, pyqtSignal
from PyQt6.QtGui import QPixmap, QImage
from PIL import Image, ImageOps, ImageCms, ImageEnhance, ImageFilter

from scrollr.config import IMAGE_EXTS


# ================= CARICAMENTO IMMAGINI & CACHE =================
# Rotazione/specchiatura indicata dal tag EXIF "Orientation" (come ImageOps.exif_transpose)
_ORIENTATION = {
    2: Image.Transpose.FLIP_LEFT_RIGHT, 3: Image.Transpose.ROTATE_180, 4: Image.Transpose.FLIP_TOP_BOTTOM,
    5: Image.Transpose.TRANSPOSE, 6: Image.Transpose.ROTATE_270, 7: Image.Transpose.TRANSVERSE,
    8: Image.Transpose.ROTATE_90,
}
# Conversioni di profilo colore già preparate, una per thread (le trasformazioni non vanno condivise)
_icc_local = threading.local()


def _to_srgb(img: Image.Image, icc: bytes, out_mode: str) -> Image.Image:
    """Converte dal profilo ICC della foto a sRGB; la conversione si prepara una volta per profilo."""
    try:
        if img.mode not in ("RGB", "RGBA", "CMYK", "L"):
            img = img.convert(out_mode)
        cache = getattr(_icc_local, "transforms", None)
        if cache is None:
            cache = _icc_local.transforms = {}
        key = (hashlib.sha1(icc).digest(), img.mode, out_mode)
        transform = cache.get(key)
        if transform is None:
            transform = ImageCms.buildTransform(ImageCms.ImageCmsProfile(io.BytesIO(icc)),
                                                ImageCms.createProfile("sRGB"), img.mode, out_mode)
            cache[key] = transform
        return ImageCms.applyTransform(img, transform)
    except Exception:
        return img  # Profilo non valido o non compatibile: si usa l'immagine così com'è


def load_pil_srgb(path: str, max_side: Optional[int] = None, exact: bool = True) -> Image.Image:
    """
    Apre un'immagine applicando rotazione EXIF e conversione del profilo colore ICC in sRGB
    (es. foto iPhone in Display P3). Se max_side è indicato, l'immagine viene ridotta.
    Restituisce sempre un'immagine in modalità RGB o RGBA.

    Per le anteprime la riduzione viene prima di tutto: il JPEG si decodifica già ridotto e
    rotazione e colori si calcolano sulla foto piccola (molto più veloce, risultato uguale).
    """
    with Image.open(path) as src:
        w, h = src.size
        if max_side and max(w, h) > max_side:
            # Decodifica JPEG ridotta: il riquadro richiesto ha le proporzioni della foto, così
            # Pillow può dimezzare (o più) senza scendere sotto max_side sul lato lungo
            k = max_side / max(w, h)
            src.draft("RGB", (max(1, round(w * k)), max(1, round(h * k))))
        icc = src.info.get("icc_profile")
        orientation = src.getexif().get(0x0112, 1)
        src.load()
        img = src.copy()

    has_alpha = img.mode in ("RGBA", "LA", "PA") or (img.mode == "P" and "transparency" in img.info)
    out_mode = "RGBA" if has_alpha else "RGB"
    # exact=False (esportazione): basta che la foto sia almeno max_side; si riduce solo se è molto
    # più grande, così il ricampionamento finale avviene una volta sola, dalla foto più ricca
    if max_side and max(img.size) > (max_side if exact else max_side * 1.5):
        if img.mode not in ("RGB", "RGBA", "L", "CMYK"):
            img = img.convert(out_mode)
        img.thumbnail((max_side, max_side), Image.Resampling.LANCZOS)
    if orientation in _ORIENTATION:
        img = img.transpose(_ORIENTATION[orientation])
    if icc:
        img = _to_srgb(img, icc, out_mode)
    if img.mode != out_mode:
        img = img.convert(out_mode)
    return img


def pil_to_qimage(pil_img: Image.Image) -> QImage:
    if pil_img.mode == "RGBA":
        fmt, bpp = QImage.Format.Format_RGBA8888, 4
    else:
        pil_img = pil_img.convert("RGB") if pil_img.mode != "RGB" else pil_img
        fmt, bpp = QImage.Format.Format_RGB888, 3
    data = pil_img.tobytes("raw", pil_img.mode)
    qimg = QImage(data, pil_img.width, pil_img.height, pil_img.width * bpp, fmt)
    return qimg.copy()


def qimage_to_pil(img: QImage) -> Image.Image:
    img = img.convertToFormat(QImage.Format.Format_RGBA8888)
    ptr = img.constBits()
    ptr.setsize(img.sizeInBytes())
    return Image.frombuffer("RGBA", (img.width(), img.height()), bytes(ptr), "raw", "RGBA", img.bytesPerLine(), 1)


# Regolazioni colore di una foto (0 = nessuna modifica). Valori da -100 a +100, oppure da 0 a 100
# per nitidezza, sbiadito e grana. Vignettatura e grana si disegnano sopra la foto (vedi PhotoItem).
NEUTRAL_ADJUST = {
    "brightness": 0, "contrast": 0, "shadows": 0, "highlights": 0, "saturation": 0, "warmth": 0, "tint": 0,
    "sharpness": 0, "vignette": 0, "fade": 0, "grain": 0, "bw": False, "auto": False,
}
# Regolazioni che cambiano i pixel della foto (le altre sono effetti disegnati sopra)
PIXEL_ADJUST = ("brightness", "contrast", "shadows", "highlights", "saturation", "warmth", "tint",
                "sharpness", "fade", "bw", "auto")

# Filtri pronti: combinazioni di regolazioni, ritoccabili dopo averle applicate
PRESETS = [
    ("original", "Originale", {}),
    ("vivid", "Vivace", {"contrast": 15, "saturation": 35, "sharpness": 30}),
    ("summer", "Estate", {"warmth": 35, "saturation": 15, "shadows": 15, "vignette": -15}),
    ("film", "Pellicola", {"fade": 35, "contrast": -10, "saturation": -15, "warmth": 10, "grain": 25}),
    ("vintage", "Vintage", {"fade": 40, "warmth": 40, "tint": 10, "saturation": -30, "vignette": -35, "grain": 30}),
    ("bw_contrast", "B/N contrastato", {"bw": True, "contrast": 35, "vignette": -20, "grain": 15}),
    ("cold", "Freddo", {"warmth": -35, "contrast": 10, "highlights": -10}),
    ("soft", "Morbido", {"fade": 20, "contrast": -15, "highlights": -20, "shadows": 20}),
    ("dramatic", "Drammatico", {"contrast": 30, "shadows": -15, "highlights": -25, "saturation": -10,
                                 "sharpness": 40, "vignette": -40}),
]


def preset_adjust(key: str) -> dict:
    """Regolazioni complete di un filtro pronto (le voci che non usa tornano a zero)."""
    values = next((v for k, _, v in PRESETS if k == key), {})
    return dict(NEUTRAL_ADJUST, **values)


def adjustments_active(adj: dict) -> bool:
    return any(adj.get(k) for k in PIXEL_ADJUST)


def auto_levels_lut(img: Image.Image) -> List[int]:
    """
    Livelli automatici calcolati sulla foto intera (si ignora lo 0,5% di pixel più scuri e più chiari):
    la stessa tabella vale per l'anteprima e per l'esportazione, che ricampiona solo una parte della foto.
    """
    rgb = img.convert("RGB")
    rgb.thumbnail((400, 400))
    lut: List[int] = []
    hist = rgb.histogram()
    for c in range(3):
        h = hist[c * 256:(c + 1) * 256]
        total = sum(h)
        cut = total * 0.005
        lo, acc = 0, 0
        while lo < 255 and acc + h[lo] <= cut:
            acc += h[lo]
            lo += 1
        hi, acc = 255, 0
        while hi > 0 and acc + h[hi] <= cut:
            acc += h[hi]
            hi -= 1
        if hi <= lo:
            lut += list(range(256))
        else:
            scale = 255.0 / (hi - lo)
            lut += [max(0, min(255, round((v - lo) * scale))) for v in range(256)]
    return lut


def _tone_lut(adj: dict) -> Optional[List[int]]:
    """Ombre, luci, sbiadito, calore e tinta in un'unica tabella per canale (un solo passaggio sui pixel)."""
    shadows = adj.get("shadows", 0) / 100.0
    highlights = adj.get("highlights", 0) / 100.0
    fade = adj.get("fade", 0) / 100.0 * 0.25
    warm = adj.get("warmth", 0) / 100.0 * 0.18
    tint = adj.get("tint", 0) / 100.0 * 0.12
    if not (shadows or highlights or fade or warm or tint):
        return None
    tone = []
    for v in range(256):
        x = v / 255.0
        # Ombre agiscono sui toni scuri (picco a 1/3), luci su quelli chiari (picco a 2/3)
        x += shadows * 1.6 * x * (1.0 - x) ** 2 + highlights * 1.6 * x * x * (1.0 - x)
        x = fade + x * (1.0 - fade)  # Sbiadito: i neri diventano grigi scuri, effetto pellicola
        tone.append(min(1.0, max(0.0, x)))
    # Calore: più rosso e meno blu. Tinta: + magenta (meno verde), − verde
    gains = (1.0 + warm + tint * 0.5, 1.0 - tint, 1.0 - warm + tint * 0.5)
    return [max(0, min(255, round(t * 255.0 * g))) for g in gains for t in tone]


def apply_adjustments(img: Image.Image, adj: dict, detail_scale: Optional[float] = None,
                      auto_lut: Optional[List[int]] = None) -> Image.Image:
    """
    Applica le regolazioni che cambiano i pixel. `detail_scale` = larghezza della foto intera in pixel / 1000
    in questa immagine (serve alla nitidezza, che deve risultare uguale in anteprima e in esportazione);
    `auto_lut` = livelli automatici calcolati sulla foto intera.
    """
    if not adjustments_active(adj):
        return img
    alpha = img.getchannel("A") if img.mode == "RGBA" else None
    rgb = img.convert("RGB")
    if adj.get("auto"):
        rgb = rgb.point(auto_lut if auto_lut else auto_levels_lut(rgb))
    if adj.get("brightness"):
        rgb = ImageEnhance.Brightness(rgb).enhance(1.0 + adj["brightness"] / 100.0)
    if adj.get("contrast"):
        rgb = ImageEnhance.Contrast(rgb).enhance(1.0 + adj["contrast"] / 100.0)
    if adj.get("bw"):
        rgb = ImageOps.grayscale(rgb).convert("RGB")
    elif adj.get("saturation"):
        rgb = ImageEnhance.Color(rgb).enhance(1.0 + adj["saturation"] / 100.0)
    lut = _tone_lut(adj)
    if lut is not None:
        rgb = rgb.point(lut)
    if adj.get("sharpness"):
        scale = detail_scale if detail_scale else rgb.width / 1000.0
        radius = max(0.6, 1.4 * scale)
        rgb = rgb.filter(ImageFilter.UnsharpMask(radius=radius, percent=round(adj["sharpness"] * 1.6), threshold=2))
    if alpha is not None:
        rgb.putalpha(alpha)
    return rgb


class HiresNotifier(QObject):
    """Avvisa il thread principale che la versione nitida di una foto è pronta."""
    ready = pyqtSignal(str, QImage)


class ImageCache:
    """
    Tiene in memoria una sola anteprima ridotta per ogni file (condivisa da tutte le copie
    sulla tela). La piena risoluzione viene letta dal disco solo durante l'esportazione,
    con una piccola cache LRU, così anche centinaia di foto non saturano la RAM.
    """
    PREVIEW_MAX_SIDE = 1600
    HIRES_MAX_SIDE = 4096   # Zoom forte sulla tela: versione nitida (copre le foto da 12 MP)
    HIRES_CACHE_SIZE = 4    # Poche alla volta: ognuna occupa fino a ~65 MB

    def __init__(self):
        self._previews: Dict[str, QPixmap] = {}
        # Originali per l'esportazione: {percorso: (lato richiesto o None = intera, immagine)}.
        # Si leggono solo grandi quanto serve all'uscita e si liberano a fine esportazione
        self._full: Dict[str, tuple] = {}
        self._hires: "OrderedDict[str, QPixmap]" = OrderedDict()
        self._hires_pending: set = set()
        self._hires_pool: Optional[ThreadPoolExecutor] = None
        self._notifier: Optional[HiresNotifier] = None

    # ---------- Anteprime ----------
    @classmethod
    def decode_preview(cls, path: str) -> QImage:
        """Lettura dell'anteprima, utilizzabile da più thread insieme (QImage sì, QPixmap no)."""
        return pil_to_qimage(load_pil_srgb(path, cls.PREVIEW_MAX_SIDE))

    def store_preview(self, path: str, image: QImage) -> QPixmap:
        """Solo nel thread principale: trasforma l'anteprima letta in QPixmap e la conserva."""
        pm = QPixmap.fromImage(image)
        self._previews[path] = pm
        return pm

    def load(self, path: str) -> QPixmap:
        if path not in self._previews:
            self.store_preview(path, self.decode_preview(path))
        return self._previews[path]

    # ---------- Alta risoluzione per lo zoom ----------
    def hires_notifier(self) -> "HiresNotifier":
        """Segnale «versione nitida pronta» (creato al primo uso, quando l'app Qt esiste già)."""
        if self._notifier is None:
            self._notifier = HiresNotifier()
            self._notifier.ready.connect(self._on_hires_ready)
        return self._notifier

    def hires(self, path: str) -> Optional[QPixmap]:
        pm = self._hires.get(path)
        if pm is not None:
            self._hires.move_to_end(path)
        return pm

    def request_hires(self, path: str):
        """Chiede in sottofondo la versione nitida; quando è pronta la tela si ridisegna da sola."""
        if path in self._hires or path in self._hires_pending or path not in self._previews:
            return
        notifier = self.hires_notifier()
        if self._hires_pool is None:
            self._hires_pool = ThreadPoolExecutor(max_workers=2, thread_name_prefix="nitida")
        self._hires_pending.add(path)
        self._hires_pool.submit(self._decode_hires, path, notifier)

    def _decode_hires(self, path: str, notifier: "HiresNotifier"):
        try:
            image = pil_to_qimage(load_pil_srgb(path, self.HIRES_MAX_SIDE))
        except Exception:
            image = QImage()
        notifier.ready.emit(path, image)  # Arriva nel thread principale (connessione in coda)

    def _on_hires_ready(self, path: str, image: QImage):
        self._hires_pending.discard(path)
        if image.isNull() or path not in self._previews:
            return
        self._hires[path] = QPixmap.fromImage(image)
        while len(self._hires) > self.HIRES_CACHE_SIZE:
            self._hires.popitem(last=False)

    def preview(self, path: str) -> QPixmap:
        pm = self._previews.get(path)
        return pm if pm is not None else QPixmap()

    def has(self, path: str) -> bool:
        return path in self._previews

    def forget(self, path: str):
        """Il file non esiste più (spostato o rinominato con l'app aperta): non va più mostrato."""
        self._previews.pop(path, None)
        self._full.pop(path, None)
        self._hires.pop(path, None)

    def alias(self, old: str, new: str):
        """Il file `new` è una copia identica di `old` (raccolta del progetto): riusa l'anteprima."""
        if old in self._previews:
            self._previews[new] = self._previews[old]

    @staticmethod
    def decode_full(path: str, side: Optional[int] = None) -> Image.Image:
        """
        Originale letto a `side` px sul lato lungo (None = intero). Usabile da più thread: così il
        grosso del ridimensionamento avviene in parallelo e il disegno deve solo rifinire.
        """
        return load_pil_srgb(path, side) if side else load_pil_srgb(path)

    def _full_fits(self, path: str, side: Optional[int]) -> bool:
        entry = self._full.get(path)
        return entry is not None and (entry[0] is None or (side is not None and entry[0] >= side))

    def store_full(self, path: str, side: Optional[int], img: Image.Image):
        if not self._full_fits(path, side):
            self._full[path] = (side, img)

    def full(self, path: str, side: Optional[int] = None) -> Optional[Image.Image]:
        """Originale per l'esportazione, letto almeno a `side` px (già pronto se preletto in parallelo)."""
        if not self._full_fits(path, side):
            try:
                self.store_full(path, side, self.decode_full(path, side))
            except Exception:
                return None
        return self._full[path][1]

    def release_full(self):
        self._full.clear()


IMAGE_CACHE = ImageCache()


def normalize_path(p: str) -> str:
    return os.path.normpath(os.path.abspath(p))


def image_paths_from_mime(mime) -> List[str]:
    paths = []
    if mime.hasUrls():
        for url in mime.urls():
            local_path = url.toLocalFile()
            if os.path.isfile(local_path) and local_path.lower().endswith(IMAGE_EXTS):
                paths.append(local_path)
    return paths
