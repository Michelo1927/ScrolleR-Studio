"""Caricamento immagini (EXIF, profili ICC), regolazioni colore e cache delle anteprime."""
import io
import os
from collections import OrderedDict
from typing import Dict, List, Optional

from PyQt6.QtGui import QPixmap, QImage
from PIL import Image, ImageOps, ImageCms, ImageEnhance

from scrollr.config import IMAGE_EXTS


# ================= CARICAMENTO IMMAGINI & CACHE =================
def load_pil_srgb(path: str, max_side: Optional[int] = None) -> Image.Image:
    """
    Apre un'immagine applicando rotazione EXIF e conversione del profilo colore ICC in sRGB
    (es. foto iPhone in Display P3). Se max_side è indicato, l'immagine viene ridotta.
    Restituisce sempre un'immagine in modalità RGB o RGBA.
    """
    with Image.open(path) as src:
        if max_side:
            src.draft("RGB", (max_side, max_side))  # Decodifica JPEG ridotta e veloce
        icc = src.info.get("icc_profile")
        img = ImageOps.exif_transpose(src)
        img.load()

    has_alpha = img.mode in ("RGBA", "LA", "PA") or (img.mode == "P" and "transparency" in img.info)
    out_mode = "RGBA" if has_alpha else "RGB"

    if icc:
        try:
            if img.mode not in ("RGB", "RGBA", "CMYK", "L"):
                img = img.convert(out_mode)
            src_profile = ImageCms.ImageCmsProfile(io.BytesIO(icc))
            dst_profile = ImageCms.createProfile("sRGB")
            img = ImageCms.profileToProfile(img, src_profile, dst_profile, outputMode=out_mode)
        except Exception:
            pass  # Profilo non valido o non compatibile: si usa l'immagine così com'è

    if img.mode != out_mode:
        img = img.convert(out_mode)
    if max_side and max(img.size) > max_side:
        img.thumbnail((max_side, max_side), Image.Resampling.LANCZOS)
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


class ImageCache:
    """
    Tiene in memoria una sola anteprima ridotta per ogni file (condivisa da tutte le copie
    sulla tela). La piena risoluzione viene letta dal disco solo durante l'esportazione,
    con una piccola cache LRU, così anche centinaia di foto non saturano la RAM.
    """
    PREVIEW_MAX_SIDE = 1600
    FULL_CACHE_SIZE = 3

    def __init__(self):
        self._previews: Dict[str, QPixmap] = {}
        self._full: "OrderedDict[str, Image.Image]" = OrderedDict()

    def load(self, path: str) -> QPixmap:
        if path not in self._previews:
            preview = load_pil_srgb(path, self.PREVIEW_MAX_SIDE)
            self._previews[path] = QPixmap.fromImage(pil_to_qimage(preview))
        return self._previews[path]

    def preview(self, path: str) -> QPixmap:
        pm = self._previews.get(path)
        return pm if pm is not None else QPixmap()

    def has(self, path: str) -> bool:
        return path in self._previews

    def forget(self, path: str):
        """Il file non esiste più (spostato o rinominato con l'app aperta): non va più mostrato."""
        self._previews.pop(path, None)
        self._full.pop(path, None)

    def alias(self, old: str, new: str):
        """Il file `new` è una copia identica di `old` (raccolta del progetto): riusa l'anteprima."""
        if old in self._previews:
            self._previews[new] = self._previews[old]

    def full(self, path: str) -> Optional[Image.Image]:
        if path in self._full:
            self._full.move_to_end(path)
            return self._full[path]
        try:
            img = load_pil_srgb(path)
        except Exception:
            return None
        self._full[path] = img
        while len(self._full) > self.FULL_CACHE_SIZE:
            self._full.popitem(last=False)
        return img

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
