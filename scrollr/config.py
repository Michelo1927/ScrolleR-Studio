"""Costanti dell'applicazione e supporto opzionale ai formati HEIC/HEIF."""
import importlib.util

# Supporto HEIC/HEIF (foto iPhone) opzionale: pip install pillow-heif
try:
    import pillow_heif
    pillow_heif.register_heif_opener()
    HEIF_SUPPORTED = True
except ImportError:
    HEIF_SUPPORTED = False

IMAGE_EXTS = (".jpg", ".jpeg", ".png", ".webp", ".bmp") + ((".heic", ".heif") if HEIF_SUPPORTED else ())

# Video (pip install av): PyAV include FFmpeg, serve a leggerli e a esportare le pagine in MP4
VIDEO_SUPPORTED = importlib.util.find_spec("av") is not None

VIDEO_EXTS = (".mp4", ".mov", ".m4v", ".webm", ".mkv", ".avi") if VIDEO_SUPPORTED else ()
# Tutti i file che si possono mettere sulla tela
MEDIA_EXTS = IMAGE_EXTS + VIDEO_EXTS


def is_video(path: str) -> bool:
    return bool(VIDEO_EXTS) and path.lower().endswith(VIDEO_EXTS)


PROJECT_EXT = ".scrlproj"
# Trascinamento dalla libreria alla tela: percorsi di foto e video, uno per riga (formato interno all'app)
LIBRARY_MIME = "application/x-scrollr-library-paths"
# Foto, testi e forme copiati con Ctrl+C (negli appunti, anche tra due finestre dell'app)
ELEMENTS_MIME = "application/x-scrollr-elements"
PROJECT_VERSION = 1

# Pagina pubblica del progetto (menu ? → Informazioni, Scarica l'ultima versione)
REPO_URL = "https://github.com/Michelo1927/ScrolleR-Studio"
