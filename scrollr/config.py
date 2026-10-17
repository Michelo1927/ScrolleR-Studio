"""Costanti dell'applicazione e supporto opzionale ai formati HEIC/HEIF."""

# Supporto HEIC/HEIF (foto iPhone) opzionale: pip install pillow-heif
try:
    import pillow_heif
    pillow_heif.register_heif_opener()
    HEIF_SUPPORTED = True
except ImportError:
    HEIF_SUPPORTED = False

IMAGE_EXTS = (".jpg", ".jpeg", ".png", ".webp", ".bmp") + ((".heic", ".heif") if HEIF_SUPPORTED else ())
PROJECT_EXT = ".scrlproj"
PROJECT_VERSION = 1

# Pagina pubblica del progetto (menu ? → Informazioni, Scarica l'ultima versione)
REPO_URL = "https://github.com/Michelo1927/ScrolleR-Studio"
