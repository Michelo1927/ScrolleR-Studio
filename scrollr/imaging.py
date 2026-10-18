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
from PIL import Image, ImageOps, ImageCms, ImageEnhance

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


# Regolazioni colore di una foto (0 = nessuna modifica)
NEUTRAL_ADJUST = {"brightness": 0, "contrast": 0, "saturation": 0, "warmth": 0, "bw": False}


def adjustments_active(adj: dict) -> bool:
    return any(adj.get(k) for k in NEUTRAL_ADJUST)


def apply_adjustments(img: Image.Image, adj: dict) -> Image.Image:
    """Applica luminosità, contrasto, saturazione, calore e bianco e nero (valori da -100 a +100)."""
    if not adjustments_active(adj):
        return img
    alpha = img.getchannel("A") if img.mode == "RGBA" else None
    rgb = img.convert("RGB")
    if adj.get("brightness"):
        rgb = ImageEnhance.Brightness(rgb).enhance(1.0 + adj["brightness"] / 100.0)
    if adj.get("contrast"):
        rgb = ImageEnhance.Contrast(rgb).enhance(1.0 + adj["contrast"] / 100.0)
    if adj.get("bw"):
        rgb = ImageOps.grayscale(rgb).convert("RGB")
    elif adj.get("saturation"):
        rgb = ImageEnhance.Color(rgb).enhance(1.0 + adj["saturation"] / 100.0)
    if adj.get("warmth"):
        # Caldo = più rosso e meno blu; freddo il contrario (su una foto in bianco e nero dà un viraggio)
        k = adj["warmth"] / 100.0 * 0.18
        r, g, b = rgb.split()
        r = r.point(lambda v: max(0, min(255, int(v * (1.0 + k)))))
        b = b.point(lambda v: max(0, min(255, int(v * (1.0 - k)))))
        rgb = Image.merge("RGB", (r, g, b))
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
