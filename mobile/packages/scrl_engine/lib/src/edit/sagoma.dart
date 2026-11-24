/// Sagoma (scontorno a mano): portata da `scrollr/cutout.py`, da `apply_cutout` di `scrollr/canvas/photo_item.py`
/// e dalla parte «Sagoma» di `CropCanvas` (`scrollr/crop_dialog.py`).
///
/// La sagoma è un contorno chiuso di punti in frazioni 0..1 della foto originale (non specchiata, come il ritaglio):
/// dentro si vede la foto, fuori è trasparente; il bordo è sfumato di `cutoutSoft` (0..100, vedi [raggioMorbidezza]).
/// Una sola forma, senza buchi; mai sui video.
library;

import 'dart:math' as math;

import '../model/elements.dart';
import 'geometria_foto.dart';
import 'strumenti_foto.dart';

/// `SOFT_FRACTION`: morbidezza 100 = sfumatura di 1,2% del lato lungo della foto.
const double sagomaFrazioneMorbidezza = 0.012;

/// `has_cutout`.
bool haSagoma(PhotoItem p) => !p.isVideo && p.cutout != null;

/// `soft_radius`: raggio della sfumatura in pixel per una foto di [w] × [h]; proporzionale alla foto, così il
/// bordo è uguale sulla tela (anteprima) e in esportazione (originale).
double raggioMorbidezza(int soft, double w, double h) =>
    math.max(0, soft) / 100.0 * sagomaFrazioneMorbidezza * math.max(w, h);

/// `bounding_crop`: ritaglio stretto attorno alla sagoma, con lo spazio per la sfumatura (frazioni 0..1).
List<double> ritaglioSagoma(
  List<PuntoSagoma> punti,
  int soft,
  double w,
  double h,
) {
  var minX = double.infinity, minY = double.infinity;
  var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
  for (final (x, y) in punti) {
    minX = math.min(minX, x);
    maxX = math.max(maxX, x);
    minY = math.min(minY, y);
    maxY = math.max(maxY, y);
  }
  final r = raggioMorbidezza(soft, w, h) * 1.5;
  final mx = r / math.max(1.0, w), my = r / math.max(1.0, h);
  return [
    math.max(0.0, minX - mx),
    math.max(0.0, minY - my),
    math.min(1.0, maxX + mx),
    math.min(1.0, maxY + my),
  ];
}

/// `simplify`: meno punti con la stessa forma (Ramer-Douglas-Peucker), per i tratti a mano libera.
List<PuntoSagoma> semplificaSagoma(List<PuntoSagoma> punti, double tolleranza) {
  if (punti.length < 3 || tolleranza <= 0) return List.of(punti);
  List<PuntoSagoma> rdp(List<PuntoSagoma> pts) {
    final (ax, ay) = pts.first;
    final (bx, by) = pts.last;
    final dx = bx - ax, dy = by - ay;
    final norm = _hypot(dx, dy);
    var best = -1.0;
    var idx = 0;
    for (var i = 1; i < pts.length - 1; i++) {
      final (px, py) = pts[i];
      final d = norm < 1e-12
          ? _hypot(px - ax, py - ay)
          : (dy * px - dx * py + bx * ay - by * ax).abs() / norm;
      if (d > best) {
        best = d;
        idx = i;
      }
    }
    if (best > tolleranza) {
      final a = rdp(pts.sublist(0, idx + 1));
      return [...a.sublist(0, a.length - 1), ...rdp(pts.sublist(idx))];
    }
    return [pts.first, pts.last];
  }

  return rdp(List.of(punti));
}

/// `math.hypot` di Python (stessa precisione di `QLineF.length` e simili per questi usi).
double _hypot(double x, double y) => math.sqrt(x * x + y * y);

/// `apply_cutout`: imposta la sagoma ([punti] null la toglie). Con una sagoma il ritaglio si stringe attorno
/// al soggetto e il riquadro ne prende la forma, come con «Ritaglia»; la foto passa a «contain» (il soggetto
/// entra sempre tutto nel riquadro, qualunque forma gli dia la disposizione), togliendola torna a «cover».
PhotoItem conSagoma(
  PhotoItem p,
  List<PuntoSagoma>? punti,
  int soft,
  MisuraImmagine? img,
) {
  final aveva = p.cutout != null;
  final sagoma = p.isVideo ? null : cleanCutout(punti);
  final morbidezza = cleanSoft(soft);
  var q = p.copyWith(
    cutout: () => sagoma,
    cutoutSoft: morbidezza,
    fitMode: sagoma != null
        ? 'contain'
        : aveva
        ? 'cover'
        : p.fitMode,
  );
  if (sagoma != null) {
    final valida = img != null && img.w > 0 && img.h > 0;
    final w = valida ? img.w.toDouble() : 1000.0;
    final h = valida ? img.h.toDouble() : 1000.0;
    q = conRitaglio(q, ritaglioSagoma(sagoma, morbidezza, w, h), true, img);
  }
  return q;
}

/// `_remove_cutout_selected`: la foto torna intera, con il riquadro nella forma della foto (e la morbidezza
/// predefinita, come `apply_cutout(None)`).
PhotoItem senzaSagoma(PhotoItem p, MisuraImmagine? img) =>
    conRitaglio(conSagoma(p, null, sagomaMorbidezza, img), fullCrop, true, img);

/// Stato della sagoma che si disegna: punti (in pixel dell'immagine mostrata) e se è chiusa.
typedef StatoSagoma = (List<PuntoSagoma>, bool);

/// Disegno della sagoma nella pagina Ritaglia (la parte «Sagoma» di `CropCanvas`), senza Flutter.
///
/// Lavora sulla foto **come appare** (specchiata se lo è), in pixel dell'immagine; le distanze «sullo schermo»
/// (prese, passo del tratto) usano [scala] = pixel dello schermo per pixel dell'immagine, che l'app passa con lo
/// zoom attuale. [risultato] dà la sagoma sulla foto originale, come la vuole [conSagoma].
class ModelloSagoma {
  ModelloSagoma({
    required double larghezza,
    required double altezza,
    List<PuntoSagoma>? sagoma,
    this.flipH = false,
    this.flipV = false,
  }) : imgW = math.max(1.0, larghezza),
       imgH = math.max(1.0, altezza) {
    final iniziale = cleanCutout(sagoma);
    if (iniziale != null) {
      punti = [
        for (final (x, y) in _specchia(iniziale)) _limita((x * imgW, y * imgH)),
      ];
      chiusa = punti.length >= sagomaPuntiMinimi;
    }
  }

  final double imgW, imgH;
  final bool flipH, flipV;

  /// Punti in pixel dell'immagine mostrata.
  List<PuntoSagoma> punti = [];
  bool chiusa = false;

  /// Tratto a mano libera in corso (pixel dell'immagine), non ancora nei punti.
  List<PuntoSagoma> tratto = [];

  static const int massimoAnnulla = 200;
  final List<StatoSagoma> _annulla = [], _ripeti = [];
  List<PuntoSagoma>? _inizioSposta;
  bool _trascinamentoSalvato = false;

  // ---------- Coordinate ----------
  List<PuntoSagoma> _specchia(List<PuntoSagoma> pts) => [
    for (final (x, y) in pts) (flipH ? 1.0 - x : x, flipV ? 1.0 - y : y),
  ];

  PuntoSagoma _limita(PuntoSagoma q) => (
    math.min(math.max(0.0, q.$1), imgW),
    math.min(math.max(0.0, q.$2), imgH),
  );

  static double _dist(PuntoSagoma a, PuntoSagoma b, double scala) =>
      _hypot(a.$1 - b.$1, a.$2 - b.$2) * scala;

  // ---------- Annulla / Ripeti ----------
  StatoSagoma _stato() => (List.of(punti), chiusa);

  void _ricorda() {
    _annulla.add(_stato());
    if (_annulla.length > massimoAnnulla) {
      _annulla.removeRange(0, _annulla.length - massimoAnnulla);
    }
    _ripeti.clear();
  }

  bool get puoAnnullare => _annulla.isNotEmpty;
  bool get puoRipetere => _ripeti.isNotEmpty;

  void _ripristina(StatoSagoma s) {
    punti = List.of(s.$1);
    chiusa = s.$2;
    tratto = [];
    _inizioSposta = null;
  }

  bool annulla() {
    if (_annulla.isEmpty) return false;
    _ripeti.add(_stato());
    _ripristina(_annulla.removeLast());
    return true;
  }

  bool ripeti() {
    if (_ripeti.isEmpty) return false;
    _annulla.add(_stato());
    _ripristina(_ripeti.removeLast());
    return true;
  }

  /// Riapre la sagoma chiusa: si continua ad aggiungere punti dall'ultimo.
  bool riapri() {
    if (!chiusa) return false;
    _ricorda();
    chiusa = false;
    return true;
  }

  // ---------- Modifiche ----------
  /// `clear_shape`.
  void cancella() {
    if (punti.isNotEmpty) _ricorda();
    punti = [];
    chiusa = false;
    tratto = [];
    _inizioSposta = null;
  }

  /// `close_shape`.
  bool chiudi() {
    if (chiusa || punti.length < sagomaPuntiMinimi) return false;
    _ricorda();
    chiusa = true;
    return true;
  }

  /// `_add_point` (un tocco con la sagoma aperta).
  void aggiungiPunto(PuntoSagoma q, double scala) {
    q = _limita(q);
    if (punti.isNotEmpty && _dist(punti.last, q, scala) < 2.0) return;
    _ricorda();
    punti.add(q);
  }

  /// Toglie l'ultimo punto della sagoma aperta (Backspace); con la sagoma chiusa prima la riapre.
  bool togliUltimo() {
    if (chiusa) return riapri();
    if (punti.isEmpty) return false;
    _ricorda();
    punti.removeLast();
    return true;
  }

  /// Toglie il punto [i] della sagoma chiusa (ne restano almeno 3).
  bool togliPunto(int i) {
    if (!chiusa || i < 0 || i >= punti.length) return false;
    if (punti.length <= sagomaPuntiMinimi) return false;
    _ricorda();
    punti.removeAt(i);
    return true;
  }

  /// Aggiunge un punto sul lato che segue il punto [dopo] (doppio clic su un lato).
  void inserisciPunto(int dopo, PuntoSagoma q) {
    _ricorda();
    punti.insert(dopo + 1, _limita(q));
  }

  // ---------- Ricerche ----------
  /// `_vertex_at`: il punto più vicino entro [presa] pixel dello schermo.
  int? verticeVicino(PuntoSagoma pos, double scala, double presa) {
    int? best;
    var bestD = presa;
    for (var i = 0; i < punti.length; i++) {
      final d = _dist(pos, punti[i], scala);
      if (d <= bestD) {
        best = i;
        bestD = d;
      }
    }
    return best;
  }

  /// `_near_first`.
  bool vicinoAlPrimo(PuntoSagoma pos, double scala, double presa) =>
      punti.isNotEmpty && _dist(pos, punti.first, scala) <= presa;

  /// `_edge_at`: il lato vicino a [pos] (indice del punto che lo precede, punto sul lato).
  (int, PuntoSagoma)? latoVicino(PuntoSagoma pos, double scala, double presa) {
    final n = punti.length;
    (int, PuntoSagoma)? best;
    var bestD = presa;
    for (var i = 0; i < n; i++) {
      final a = punti[i], b = punti[(i + 1) % n];
      final dx = b.$1 - a.$1, dy = b.$2 - a.$2;
      final den = dx * dx + dy * dy;
      final t = den < 1e-18
          ? 0.0
          : math.min(
              1.0,
              math.max(
                0.0,
                ((pos.$1 - a.$1) * dx + (pos.$2 - a.$2) * dy) / den,
              ),
            );
      final p = (a.$1 + t * dx, a.$2 + t * dy);
      final d = _dist(pos, p, scala);
      if (d <= bestD) {
        bestD = d;
        best = (i, _limita(p));
      }
    }
    return best;
  }

  /// Il punto è dentro la sagoma (regola «winding», come la maschera).
  bool contiene(PuntoSagoma q) {
    if (punti.length < sagomaPuntiMinimi) return false;
    var giri = 0;
    final (x, y) = q;
    for (var i = 0; i < punti.length; i++) {
      final (x0, y0) = punti[i];
      final (x1, y1) = punti[(i + 1) % punti.length];
      final lato = (x1 - x0) * (y - y0) - (x - x0) * (y1 - y0);
      if (y0 <= y) {
        if (y1 > y && lato > 0) giri++;
      } else if (y1 <= y && lato < 0) {
        giri--;
      }
    }
    return giri != 0;
  }

  // ---------- Trascinamenti ----------
  /// Inizio di un trascinamento di un punto o della sagoma intera: lo stato si salva al primo movimento.
  void iniziaTrascinamento() {
    _trascinamentoSalvato = false;
    _inizioSposta = List.of(punti);
  }

  void _salvaTrascinamento() {
    if (_trascinamentoSalvato) return;
    // Lo stato di prima è quello all'inizio del trascinamento
    final ora = punti;
    punti = _inizioSposta ?? List.of(punti);
    _ricorda();
    punti = ora;
    _trascinamentoSalvato = true;
  }

  /// Sposta il punto [i] in [q].
  void spostaVertice(int i, PuntoSagoma q) {
    if (i < 0 || i >= punti.length) return;
    _salvaTrascinamento();
    punti[i] = _limita(q);
  }

  /// Sposta la sagoma intera di ([dx], [dy]) dal punto in cui è iniziato il trascinamento, senza uscire dalla foto.
  void spostaSagoma(double dx, double dy) {
    final start = _inizioSposta;
    if (start == null || start.isEmpty) return;
    _salvaTrascinamento();
    var minX = double.infinity, minY = double.infinity;
    var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final (x, y) in start) {
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }
    final ddx = math.min(math.max(dx, -minX), imgW - maxX);
    final ddy = math.min(math.max(dy, -minY), imgH - maxY);
    punti = [for (final (x, y) in start) (x + ddx, y + ddy)];
  }

  void fineTrascinamento() {
    _inizioSposta = null;
    _trascinamentoSalvato = false;
  }

  /// Annulla il trascinamento in corso (per esempio arriva un secondo dito per lo zoom): i punti tornano come
  /// all'inizio e nella cronologia non resta niente.
  void annullaTrascinamento() {
    final start = _inizioSposta;
    if (_trascinamentoSalvato && start != null) {
      punti = List.of(start);
      _annulla.removeLast();
    }
    fineTrascinamento();
  }

  // ---------- Tratto a mano libera ----------
  /// Passo minimo (pixel dello schermo) tra due punti campionati (`STEP_PX`).
  static const double passoTratto = 3.0;

  void iniziaTratto(PuntoSagoma q) => tratto = [_limita(q)];

  void continuaTratto(PuntoSagoma q, double scala) {
    q = _limita(q);
    if (tratto.isEmpty) {
      tratto = [q];
    } else if (_dist(tratto.last, q, scala) >= passoTratto) {
      tratto.add(q);
    }
  }

  /// `_finish_stroke`: il tratto si semplifica e si unisce ai punti; se torna vicino al primo punto (entro
  /// [presa] pixel dello schermo, dopo essersene allontanato) la sagoma si chiude.
  void finisciTratto(double scala, double presa) {
    final stroke = tratto;
    tratto = [];
    if (stroke.isEmpty) return;
    var nuovi = semplificaSagoma(stroke, 1.0 / scala);
    if (punti.isNotEmpty && _dist(punti.last, nuovi.first, scala) < 2.0) {
      nuovi = nuovi.sublist(1);
    }
    var insieme = [...punti, ...nuovi];
    var chiudere = false;
    if (insieme.length >= sagomaPuntiMinimi + 1) {
      final primo = insieme.first;
      var lontano = 0.0;
      for (final q in insieme) {
        lontano = math.max(lontano, _dist(primo, q, scala));
      }
      if (_dist(primo, insieme.last, scala) <= presa && lontano > 3 * presa) {
        insieme = insieme.sublist(0, insieme.length - 1);
        chiudere = true;
      }
    }
    _ricorda();
    punti = insieme;
    chiusa = chiudere && insieme.length >= sagomaPuntiMinimi;
  }

  // ---------- Risultato ----------
  /// I punti della sagoma chiusa in frazioni dell'immagine mostrata; null se non è chiusa.
  List<PuntoSagoma>? get frazioni =>
      chiusa ? [for (final (x, y) in punti) (x / imgW, y / imgH)] : null;

  /// `CropDialog.cutout`: la sagoma chiusa sulla foto originale non specchiata, pulita; null se non c'è.
  List<PuntoSagoma>? risultato() {
    final f = frazioni;
    return f == null ? null : cleanCutout(_specchia(f));
  }
}

// ---------------------------------------------------------------- Disegno

/// Contorno della sagoma nelle coordinate della cella, così come si vede (ritaglio, zoom, rotazione, specchio),
/// per un'immagine di [imgW] × [imgH] pixel; null se la foto non ha sagoma. È la parte poligonale di
/// `silhouette_path` (l'app la taglia poi col riquadro dagli angoli arrotondati).
List<PuntoSagoma>? sagomaNellaCella(PhotoItem p, int imgW, int imgH) {
  final punti = p.cutout;
  if (!haSagoma(p) || punti == null || imgW <= 0 || imgH <= 0) return null;
  final src = p.cropRect(imgW.toDouble(), imgH.toDouble());
  final g = p.coverGeometry(src.w, src.h);
  final x0 = p.crop[0], y0 = p.crop[1];
  final kx = g.drawW / math.max(1e-9, p.crop[2] - x0);
  final ky = g.drawH / math.max(1e-9, p.crop[3] - y0);
  final t = p.imageTransform();
  return [
    for (final (u, v) in punti)
      t.map(g.dx + (u - x0) * kx, g.dy + (v - y0) * ky),
  ];
}

/// Sfumatura del bordo della sagoma come deviazione standard di una sfocatura gaussiana, in unità della cella
/// (`mask_image`: `GaussianBlur(raggio / 2)` sui pixel della foto, poi la foto si disegna nella cella).
double sfumaturaSagoma(PhotoItem p, int imgW, int imgH) {
  if (imgW <= 0 || imgH <= 0) return 0.0;
  final src = p.cropRect(imgW.toDouble(), imgH.toDouble());
  final g = p.coverGeometry(src.w, src.h);
  final k =
      (g.drawW / math.max(1e-9, src.w) + g.drawH / math.max(1e-9, src.h)) / 2.0;
  return raggioMorbidezza(p.cutoutSoft, imgW.toDouble(), imgH.toDouble()) *
      k /
      2.0;
}

/// Ombra che segue la sagoma (`_paint_sticker_shadow`): spostamento in basso, sfocatura e opacità (0..1)
/// della forma sfumata.
({double spostamento, double sfocatura, double opacita}) ombraSagoma(
  PhotoItem p,
) {
  final ext = p.shadowExtent;
  return (
    spostamento: ext * 0.35,
    sfocatura: ext * 0.25,
    opacita: 1.0 - math.pow(1.0 - 0.075 * p.shadow / 100.0, 12).toDouble(),
  );
}
