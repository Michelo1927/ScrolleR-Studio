/// Costanti del formato `.scrlproj`, identiche a quelle del desktop (`scrollr/config.py`,
/// `MainWindow.ASPECT_RATIOS`, `HISTORY_LIMIT`).
library;

/// Versione del formato dei progetti. Non cambiarla: il desktop la usa per aprire i file.
const int progettoVersione = 1;

/// Estensione dei file di progetto.
const String progettoEstensione = '.scrlproj';

/// Numero massimo di pagine di un carosello (come lo spin «Pagine» del desktop).
const int pagineMassime = 30;

/// Passi massimi di Annulla/Ripeti (`HISTORY_LIMIT` del desktop).
const int cronologiaLimite = 100;

/// Formati della pagina nello stesso ordine di `ASPECT_RATIOS` del desktop: `ratio_index` è l'indice
/// in questo elenco. L'ultimo (8) è «Personalizzato» e non ha misure fisse.
const List<(int, int)?> aspectRatios = [
  (1080, 1440), // 3:4 verticale
  (1440, 1080), // 4:3 orizzontale
  (1080, 1350), // 4:5 ritratto Instagram
  (1080, 1080), // 1:1 quadrato
  (1080, 1920), // 9:16 storia
  (1920, 1080), // 16:9 panoramico
  (1080, 1620), // 2:3 foto verticale
  (1620, 1080), // 3:2 foto orizzontale
  null, // Personalizzato
];

/// Indice di «Personalizzato» in [aspectRatios].
const int ratioPersonalizzato = 8;

/// Estensioni video del desktop (`VIDEO_EXTS`).
const List<String> estensioniVideo = [
  '.mp4',
  '.mov',
  '.m4v',
  '.webm',
  '.mkv',
  '.avi',
];
