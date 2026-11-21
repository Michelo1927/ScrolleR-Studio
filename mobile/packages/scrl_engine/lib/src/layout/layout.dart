/// Disposizioni automatiche, portate 1:1 da `scrollr/window/layouts.py` (`LayoutMixin`).
///
/// Le funzioni lavorano su una [Scene] (copia di lavoro) e seguono passo per passo il Python:
/// stesso ordine delle operazioni in virgola mobile, `pyRound` dove il desktop usa `round()`,
/// `pySum` dove usa `sum()`, e lo stesso generatore casuale per Polaroid.
library;

import 'dart:math' as math;

import '../model/canvas_state.dart';
import '../model/context.dart';
import '../model/elements.dart';
import '../model/scene.dart';
import '../project/formato.dart';
import '../util/py.dart';
import '../util/py_random.dart';

/// «A cavallo»: parte minima di pagina che una foto occupa da ogni lato della giunzione.
const double seamKeep = 0.15;

/// Area minima di disposizione (`_safe_rect`).
const double minLayoutArea = 100.0;

/// `apply_auto_layout(mode)`.
void applyAutoLayoutIn(Scene sc, String mode) {
  final photos = sc.layoutPhotos();
  if (photos.isEmpty) return;
  sc.layoutMode = mode;
  final rng = PyRandom(sc.layoutSeed);
  final gap = sc.gap.toDouble();
  final margin = sc.margin.toDouble();

  // Il bordo bianco "Polaroid" aggiunto in automatico (progetti vecchi) e le cornici Polaroid e Pellicola
  // si tolgono: le rimettono quelle disposizioni dove servono
  for (final p in photos) {
    final cur = sc.photo(p.uid);
    if (cur.autoBorder) {
      sc.put(cur.copyWith(borderWidth: 0.0, autoBorder: false));
    }
    final dopo = sc.photo(p.uid);
    if (dopo.frame.isNotEmpty) sc.put(dopo.copyWith(frame: ''));
  }

  final ctx = sc.ctx;
  if (mode == LayoutModes.seam) {
    if (sc.numFrames < 2) {
      // "A cavallo" richiede almeno 2 pagine: le aggiunge e ricorda quante ce n'erano prima
      final frames = math.max(2, pyCeilDiv(photos.length, 4));
      ctx.seamAddedFrames = (sc.numFrames, frames);
      sc.setFramesSilently(frames);
      sc.notice(NoticeKind.seamAddedPages, [frames]);
    }
  } else if (ctx.seamAddedFrames != null) {
    // Si lascia "A cavallo": ripristina il numero di pagine originale, se non è stato cambiato a mano
    final (before, added) = ctx.seamAddedFrames!;
    ctx.seamAddedFrames = null;
    var lockedAfter = false;
    for (var k = before; k < added; k++) {
      if (sc.pageLocked(k)) lockedAfter = true;
    }
    if (sc.numFrames == added && !lockedAfter) {
      sc.setFramesSilently(before);
      sc.notice(NoticeKind.seamRestoredPages, [before]);
    }
  }
  final fw = sc.frameW.toDouble();
  if (mode == LayoutModes.seam) {
    // Tutta la tela «a cavallo», saltando le pagine bloccate
    for (final (run, chunk) in _freeStretches(sc, photos)) {
      final (a, b) = run;
      final area = _safeRect(
        _pagesRect(sc, a, b).adjusted(margin, margin, -margin, -margin),
      );
      _layoutSeam(sc, chunk, area, gap, [
        for (var k = a + 1; k <= b; k++) k * fw,
      ]);
    }
  } else {
    final perPage = sc.perPage;
    if (sc.perFrame && perPage > 0) {
      // Numero fisso di foto per pagina: le pagine si adeguano (tenendo quelle con testi e forme)
      final needed = pagePhotoCounts(sc, photos.length).length;
      final textPages = <int>[
        for (final t in [...sc.canvasTexts(), ...sc.canvasShapes()])
          sc.pageOf(t) + 1,
        for (final p in sc.canvasPhotos())
          if (p.free || p.pageLocked) sc.pageOf(p) + 1,
        for (var k = 0; k < sc.numFrames; k++)
          if (sc.pageLocked(k)) k + 1,
      ];
      final frames = [
        1,
        needed,
        ...textPages.where((p) => p <= pagineMassime),
      ].reduce(math.max);
      if (frames != sc.numFrames) sc.setFramesSilently(frames);
    }
    if (sc.perFrame) {
      final counts = pagePhotoCounts(sc, photos.length);
      if (counts.length > sc.numFrames) {
        // Tutte le pagine bloccate o piene: le foto in più vanno in una pagina nuova
        sc.setFramesSilently(counts.length);
        sc.notice(NoticeKind.addedPageForPhotos);
      }
      final chunks = <List<PhotoItem>>[];
      var start = 0;
      for (final count in counts) {
        chunks.add(
          photos.sublist(
            math.min(start, photos.length),
            math.min(start + count, photos.length),
          ),
        );
        start += count;
      }
      for (final (first, last) in sc.seamGroups()) {
        final chunk = <PhotoItem>[
          for (var f = first; f < math.min(last + 1, chunks.length); f++)
            ...chunks[f],
        ];
        if (chunk.isEmpty) continue;
        final frameRect = Rect(
          first * fw,
          0,
          (last - first + 1) * fw,
          sc.frameH.toDouble(),
        );
        final area = _safeRect(
          frameRect.adjusted(margin, margin, -margin, -margin),
        );
        if (last > first) {
          // Pagine unite «a cavallo»: righe continue che attraversano solo le loro giunzioni
          _layoutSeam(sc, chunk, area, gap, [
            for (var k = first + 1; k <= last; k++) k * fw,
          ]);
          continue;
        }
        // Una pagina può avere la sua disposizione
        final own = first < sc.pageLayouts.length
            ? sc.pageLayouts[first]
            : null;
        if (own != null) {
          _layoutInRect(sc, own.mode, chunk, area, gap, rng, own.style);
        } else {
          _layoutInRect(sc, mode, chunk, area, gap, rng);
        }
      }
    } else {
      // Tela continua, saltando le pagine bloccate
      for (final (run, chunk) in _freeStretches(sc, photos)) {
        final (a, b) = run;
        final area = _safeRect(
          _pagesRect(sc, a, b).adjusted(margin, margin, -margin, -margin),
        );
        _layoutInRect(sc, mode, chunk, area, gap, rng);
      }
    }
  }
}

/// `_relayout_keep`: ridispone con la disposizione attuale, se ci sono foto.
void relayoutKeep(Scene sc) {
  if (sc.photos.isNotEmpty) applyAutoLayoutIn(sc, sc.layoutMode);
}

Rect _pagesRect(Scene sc, int first, int last) {
  final fw = sc.frameW.toDouble();
  return Rect(first * fw, 0, (last - first + 1) * fw, sc.frameH.toDouble());
}

/// Tela continua con pagine bloccate: tratti di pagine libere consecutive, ognuno con la sua parte
/// di foto in proporzione alle pagine (`_free_stretches`).
List<((int, int), List<PhotoItem>)> _freeStretches(
  Scene sc,
  List<PhotoItem> photos,
) {
  final n = sc.numFrames;
  var runs = <(int, int)>[];
  int? start;
  for (var k = 0; k <= n; k++) {
    final free = k < n && !sc.pageLocked(k);
    if (free && start == null) {
      start = k;
    } else if (!free && start != null) {
      runs.add((start, k - 1));
      start = null;
    }
  }
  if (runs.isEmpty) {
    sc.setFramesSilently(n + 1);
    sc.notice(NoticeKind.addedPageForPhotos);
    runs = [(n, n)];
  }
  final total = runs.fold<int>(0, (s, r) => s + r.$2 - r.$1 + 1);
  final out = <((int, int), List<PhotoItem>)>[];
  var first = 0;
  var pages = 0;
  for (final r in runs) {
    pages += r.$2 - r.$1 + 1;
    final end = pyRound(photos.length * pages / total);
    if (end > first) out.add((r, photos.sublist(first, end)));
    first = end;
  }
  return out;
}

/// Quante foto vanno in ogni pagina, nell'ordine delle pagine (`_page_photo_counts`).
List<int> pagePhotoCounts(Scene sc, int n) {
  final fixed = sc.pageCounts;
  final perPage = sc.perPage;

  int? fixedAt(int i) {
    if (sc.pageLocked(i)) return 0; // Pagina bloccata: non riceve altre foto
    return i < fixed.length ? fixed[i] : null;
  }

  void putExtra(List<int> counts, int extra) {
    // Le foto in più vanno nell'ultima pagina non bloccata, altrimenti in una pagina nuova
    final free = [
      for (var i = 0; i < counts.length; i++)
        if (!sc.pageLocked(i)) i,
    ];
    if (free.isNotEmpty) {
      counts[free.last] += extra;
    } else {
      counts.add(extra);
    }
  }

  if (perPage > 0) {
    final counts = <int>[];
    var left = n;
    while (left > 0 && counts.length < pagineMassime) {
      final f = fixedAt(counts.length);
      final c = math.min(f ?? perPage, left);
      counts.add(c);
      left -= c;
    }
    if (left != 0 && counts.isNotEmpty) {
      putExtra(counts, left); // Raggiunto il massimo di pagine
    }
    return counts;
  }

  final frames = sc.numFrames;
  final counts = List<int?>.filled(frames, null);
  var left = n;
  for (var i = 0; i < frames; i++) {
    final f = fixedAt(i);
    if (f != null) {
      counts[i] = math.min(f, left);
      left -= counts[i]!;
    }
  }
  final free = [
    for (var i = 0; i < frames; i++)
      if (counts[i] == null) i,
  ];
  final out = <int>[];
  if (free.isNotEmpty) {
    // Le prime pagine libere prendono l'eccedenza (divmod di Python)
    final base = (left / free.length).floor();
    final extra = left - base * free.length;
    for (var j = 0; j < free.length; j++) {
      counts[free[j]] = base + (j < extra ? 1 : 0);
    }
    out.addAll(counts.map((c) => c!));
  } else {
    out.addAll(counts.map((c) => c!));
    if (left != 0) putExtra(out, left); // Tutte le pagine sono fissate
  }
  return out;
}

Rect _safeRect(Rect r) =>
    Rect(r.x, r.y, math.max(minLayoutArea, r.w), math.max(minLayoutArea, r.h));

/// `_place`: rotazione, cella (minimo 40), posizione; il riquadro ricordato si dimentica.
void _place(
  Scene sc,
  PhotoItem p,
  double x,
  double y,
  double w,
  double h, [
  double rotation = 0.0,
]) {
  sc.put(
    sc
        .photo(p.uid)
        .copyWith(
          rotation: rotation,
          w: w,
          h: h,
          x: x,
          y: y,
          savedCell: () => null,
        ),
  );
}

void _layoutInRect(
  Scene sc,
  String mode,
  List<PhotoItem> photos,
  Rect area,
  double gap,
  PyRandom rng, [
  String? style,
]) {
  // [style]: stile della disposizione propria di una pagina (mosaico o verso della pellicola)
  final proprio = style != null && style.isNotEmpty ? style : null;
  switch (mode) {
    case LayoutModes.mosaic:
      _layoutMosaic(sc, photos, area, gap, proprio ?? sc.mosaicStyle);
    case LayoutModes.stripsH:
      _layoutStrips(sc, photos, area, gap, horizontal: true);
    case LayoutModes.stripsV:
      _layoutStrips(sc, photos, area, gap, horizontal: false);
    case LayoutModes.scatter:
      _layoutScatter(sc, photos, area, rng);
    case LayoutModes.film:
      _layoutFilm(sc, photos, area, gap, proprio ?? sc.filmStyle);
    default:
      _layoutGrid(sc, photos, area, gap);
  }
}

void _layoutGrid(Scene sc, List<PhotoItem> photos, Rect area, double gap) {
  // Numero ottimale di righe e colonne in base al rapporto dell'area
  final n = photos.length;
  if (n == 0) return;
  final cols = math.min(
    n,
    math.max(1, pyRound(math.sqrt(n * area.w / area.h))),
  );
  final rows = pyCeilDiv(n, cols);
  final rowH = (area.h - gap * (rows - 1)) / rows;
  var idx = 0;
  for (var r = 0; r < rows; r++) {
    final remaining = n - idx;
    final colsInRow = math.min(cols, pyCeilDiv(remaining, rows - r));
    final colW = (area.w - gap * (colsInRow - 1)) / colsInRow;
    for (var c = 0; c < colsInRow; c++) {
      _place(
        sc,
        photos[idx],
        area.x + c * (colW + gap),
        area.y + r * (rowH + gap),
        colW,
        rowH,
      );
      idx++;
    }
  }
}

void _layoutMosaic(
  Scene sc,
  List<PhotoItem> photos,
  Rect area,
  double gap,
  String style,
) {
  // Foto "Hero" in evidenza + griglia per le altre; la posizione dipende dallo stile scelto
  final portrait = area.h >= area.w;
  if (style == 'masonry') {
    _layoutMasonry(sc, photos, area, gap);
    return;
  }
  final hero = photos[0];
  final others = photos.sublist(1);
  if (others.isEmpty) {
    _place(sc, hero, area.x, area.y, area.w, area.h);
    return;
  }
  final x = area.x, y = area.y, w = area.w, h = area.h;

  if (style == 'two' && others.length >= 2) {
    final heroes = photos.sublist(0, 2);
    final restPhotos = photos.sublist(2);
    Rect rest;
    if (portrait) {
      final band = (h - gap) * 0.55;
      final half = (w - gap) / 2.0;
      _place(sc, heroes[0], x, y, half, band);
      _place(sc, heroes[1], x + half + gap, y, half, band);
      rest = Rect(x, y + band + gap, w, h - band - gap);
    } else {
      final band = (w - gap) * 0.55;
      final half = (h - gap) / 2.0;
      _place(sc, heroes[0], x, y, band, half);
      _place(sc, heroes[1], x, y + half + gap, band, half);
      rest = Rect(x + band + gap, y, w - band - gap, h);
    }
    _layoutGrid(sc, restPhotos, rest, gap);
    return;
  }

  if (style == 'center' && others.length >= 2) {
    final k = pyCeilDiv(others.length, 2);
    final first = others.sublist(0, k);
    final second = others.sublist(k);
    if (portrait) {
      final mid = (h - 2 * gap) * 0.56;
      final side = (h - 2 * gap - mid) / 2.0;
      _layoutGrid(sc, first, Rect(x, y, w, side), gap);
      _place(sc, hero, x, y + side + gap, w, mid);
      _layoutGrid(sc, second, Rect(x, y + side + mid + 2 * gap, w, side), gap);
    } else {
      final mid = (w - 2 * gap) * 0.56;
      final side = (w - 2 * gap - mid) / 2.0;
      _layoutGrid(sc, first, Rect(x, y, side, h), gap);
      _place(sc, hero, x + side + gap, y, mid, h);
      _layoutGrid(sc, second, Rect(x + side + mid + 2 * gap, y, side, h), gap);
    }
    return;
  }

  final where = const ['top', 'bottom', 'left', 'right'].contains(style)
      ? style
      : (portrait ? 'top' : 'left');
  Rect rest;
  if (where == 'top' || where == 'bottom') {
    final heroH = (h - gap) * 0.55;
    final restH = h - heroH - gap;
    if (where == 'top') {
      _place(sc, hero, x, y, w, heroH);
      rest = Rect(x, y + heroH + gap, w, restH);
    } else {
      _place(sc, hero, x, y + restH + gap, w, heroH);
      rest = Rect(x, y, w, restH);
    }
  } else {
    final heroW = (w - gap) * 0.55;
    final restW = w - heroW - gap;
    if (where == 'left') {
      _place(sc, hero, x, y, heroW, h);
      rest = Rect(x + heroW + gap, y, restW, h);
    } else {
      _place(sc, hero, x + restW + gap, y, heroW, h);
      rest = Rect(x, y, restW, h);
    }
  }
  _layoutGrid(sc, others, rest, gap);
}

void _layoutMasonry(Scene sc, List<PhotoItem> photos, Rect area, double gap) {
  // Colonne riempite a tutta altezza con foto di altezze diverse e giunzioni sfalsate
  final n = photos.length;
  var cols = math.min(n, math.max(1, pyRound(math.sqrt(n * area.w / area.h))));
  if (n >= 4) cols = math.max(2, cols);
  final colW = (area.w - gap * (cols - 1)) / cols;
  final columns = [for (var i = 0; i < cols; i++) <(PhotoItem, double)>[]];
  final heights = List<double>.filled(cols, 0.0);
  for (final p in photos) {
    final ratio = math.min(1.8, math.max(0.55, 1.0 / sc.sourceRatio(p)));
    final minH = heights.reduce(math.min);
    final c = heights.indexOf(minH);
    columns[c].add((p, ratio));
    heights[c] += ratio;
  }
  for (var c = 0; c < columns.length; c++) {
    final items = columns[c];
    if (items.isEmpty) continue;
    // Alterna foto alte e basse, sfasate tra colonne vicine, così le giunzioni non si allineano mai
    final weights = [
      for (var j = 0; j < items.length; j++)
        items[j].$2 * ((c + j) % 2 == 0 ? 1.3 : 0.77),
    ];
    final avail = area.h - gap * (items.length - 1);
    final total = pySum(weights);
    var cy = area.y;
    final cx = area.x + c * (colW + gap);
    for (var j = 0; j < items.length; j++) {
      final ph = avail * weights[j] / total;
      _place(sc, items[j].$1, cx, cy, colW, ph);
      cy += ph + gap;
    }
  }
}

void _layoutStrips(
  Scene sc,
  List<PhotoItem> photos,
  Rect area,
  double gap, {
  required bool horizontal,
}) {
  final n = photos.length;
  if (horizontal) {
    final rowH = (area.h - gap * (n - 1)) / n;
    for (var i = 0; i < n; i++) {
      _place(sc, photos[i], area.x, area.y + i * (rowH + gap), area.w, rowH);
    }
  } else {
    final colW = (area.w - gap * (n - 1)) / n;
    for (var i = 0; i < n; i++) {
      _place(sc, photos[i], area.x + i * (colW + gap), area.y, colW, area.h);
    }
  }
}

void _layoutScatter(Scene sc, List<PhotoItem> photos, Rect area, PyRandom rng) {
  // Polaroid: cartoncini bianchi con la striscia larga in basso, sparsi e leggermente inclinati
  // (inclinazione e spostamenti riproducibili tramite seed)
  final n = photos.length;
  final cols = math.max(1, math.sqrt(n * area.w / area.h).ceil());
  final rows = pyCeilDiv(n, cols);
  final cellW = area.w / cols;
  final cellH = area.h / rows;
  for (var i = 0; i < n; i++) {
    final r = i ~/ cols, c = i % cols;
    // Il cartoncino ha le proporzioni di una Polaroid (finestra quadrata) e sta nell'88% della cella
    final w = math.min(cellW * 0.88, cellH * 0.88 * polaroidRatio);
    final h = w / polaroidRatio;
    final jitterX = rng.uniform(-cellW * 0.08, cellW * 0.08);
    final jitterY = rng.uniform(-cellH * 0.08, cellH * 0.08);
    final x = area.x + c * cellW + (cellW - w) / 2.0 + jitterX;
    final y = area.y + r * cellH + (cellH - h) / 2.0 + jitterY;
    _place(sc, photos[i], x, y, w, h, rng.uniform(-7.5, 7.5));
    sc.put(sc.photo(photos[i].uid).copyWith(frame: 'polaroid'));
  }
}

/// «Pellicola» (`_layout_film`): strisce di fotogrammi attaccati, con le perforazioni, orizzontali o
/// verticali. Sceglie verso e numero di strisce che danno alle finestre le proporzioni più vicine a quelle
/// medie delle foto riempiendo il più possibile l'area; lo spazio tra le foto separa le strisce.
void _layoutFilm(
  Scene sc,
  List<PhotoItem> photos,
  Rect area,
  double gap,
  String style,
) {
  final n = photos.length;
  final target = math.exp(
    pySum([
          for (final p in photos)
            math.log(math.min(2.2, math.max(0.5, sc.sourceRatio(p)))),
        ]) /
        n,
  );
  (double, bool, int, double)? best;
  // [style]: 'horizontal', 'vertical' o 'auto' (sceglie il verso)
  final versi = switch (style) {
    'horizontal' => const [false],
    'vertical' => const [true],
    _ => const [false, true],
  };
  for (final vertical in versi) {
    final length = vertical ? area.h : area.w;
    final across = vertical ? area.w : area.h;
    // Proporzioni volute della finestra misurate lungo la striscia (lunghezza / spessore)
    final want = vertical ? 1.0 / target : target;
    for (var rows = 1; rows <= n; rows++) {
      final cols = pyCeilDiv(n, rows);
      final frameLen = length / cols;
      final avail = (across - gap * (rows - 1)) / rows;
      if (avail <= 0) continue;
      // Spessore della striscia: quello che dà la finestra voluta, se ci sta
      final thick = math.min(
        avail,
        frameLen / (want * (1.0 - 2.0 * filmBand) + 2.0 * filmSide),
      );
      final ratio =
          (frameLen - 2.0 * filmSide * thick) /
          ((1.0 - 2.0 * filmBand) * thick);
      final fill = (rows * thick + gap * (rows - 1)) / across;
      // Fotogrammi che mancano per completare le strisce (le più corte restano centrate)
      final empty = rows * cols - n;
      final score =
          (math.log(ratio / want)).abs() +
          (1.0 - fill) +
          0.5 * empty / (rows * cols);
      if (best == null || score < best.$1) {
        best = (score, vertical, rows, thick);
      }
    }
  }
  if (best == null) {
    _layoutGrid(sc, photos, area, gap);
    return;
  }
  final (_, vertical, rows, thick) = best;
  final length = vertical ? area.h : area.w;
  final across = vertical ? area.w : area.h;
  final cols = pyCeilDiv(n, rows);
  final frameLen = length / cols;
  final start = (across - rows * thick - gap * (rows - 1)) / 2.0;
  var idx = 0;
  for (var r = 0; r < rows; r++) {
    final count = pyCeilDiv(n - idx, rows - r);
    final off = start + r * (thick + gap);
    // Striscia più corta: un pezzo di pellicola centrato
    final lead = (cols - count) * frameLen / 2.0;
    for (var k = 0; k < count; k++) {
      final p = photos[idx];
      idx++;
      final pos = lead + k * frameLen;
      if (vertical) {
        _place(sc, p, area.x + off, area.y + pos, thick, frameLen);
      } else {
        _place(sc, p, area.x + pos, area.y + off, frameLen, thick);
      }
      sc.put(sc.photo(p.uid).copyWith(frame: vertical ? 'film_v' : 'film'));
    }
  }
}

/// «A cavallo»: righe giustificate su tutta l'area, con le proporzioni vere delle foto. Nessuno spazio
/// tra due foto cade vicino a una giunzione (`_layout_seam`). [seams] = x delle giunzioni da attraversare.
void _layoutSeam(
  Scene sc,
  List<PhotoItem> photos,
  Rect area,
  double gap, [
  List<double>? seams,
]) {
  final aspects = [
    for (final p in photos) math.min(2.2, math.max(0.5, sc.sourceRatio(p))),
  ];
  final wAvail = area.w, hAvail = area.h;

  // Numero di righe: quello che, a proporzioni intatte, riempie meglio l'altezza della tela
  (double, List<List<int>>, List<double>)? best;
  for (var r = 1; r <= math.min(photos.length, 8); r++) {
    final rows = splitRows(aspects, r);
    final heights = [
      for (final row in rows)
        (wAvail - gap * (row.length - 1)) /
            pySum([for (final i in row) aspects[i]]),
    ];
    final score = math.log((pySum(heights) + gap * (r - 1)) / hAvail).abs();
    if (best == null || score < best.$1) best = (score, rows, heights);
  }
  final (_, rows, heights) = best!;
  final scale = (hAvail - gap * (rows.length - 1)) / pySum(heights);

  final fw = sc.frameW.toDouble();
  seams ??= [for (var k = 1; k < sc.numFrames; k++) k * fw];
  final keep = fw * seamKeep;
  var y = area.y;
  for (var ri = 0; ri < rows.length; ri++) {
    final row = rows[ri];
    final rowH = heights[ri] * scale;
    final totalA = pySum([for (final i in row) aspects[i]]);
    final inner = wAvail - gap * (row.length - 1);
    // Centri degli spazi tra le foto della riga
    final cuts = <double>[];
    var x = area.x;
    for (final i in row.sublist(0, row.length - 1)) {
      x += inner * aspects[i] / totalA;
      cuts.add(x + gap / 2.0);
      x += gap;
    }
    // Sposta gli spazi troppo vicini a una giunzione, senza rendere una foto troppo stretta
    final minW = rowH * 0.45;
    for (var j = 0; j < cuts.length; j++) {
      final c = cuts[j];
      final near = [
        for (final sx in seams)
          if ((c - sx).abs() < keep) sx,
      ];
      if (near.isEmpty) continue;
      final lo = (j > 0 ? cuts[j - 1] : area.x - gap / 2.0) + minW + gap;
      final hi =
          (j + 1 < cuts.length ? cuts[j + 1] : area.right + gap / 2.0) -
          minW -
          gap;
      final options = [
        for (final t in [near[0] - keep, near[0] + keep])
          if (lo <= t &&
              t <= hi &&
              !seams.any((sx) => (t - sx).abs() < keep - 0.5))
            t,
      ];
      if (options.isNotEmpty) {
        // `min(options, key=...)`: a parità vince il primo
        var scelta = options[0];
        for (final t in options.skip(1)) {
          if ((t - c).abs() < (scelta - c).abs()) scelta = t;
        }
        cuts[j] = scelta;
      }
    }
    final edges = [area.x - gap / 2.0, ...cuts, area.right + gap / 2.0];
    for (var k = 0; k < row.length; k++) {
      final left = edges[k] + gap / 2.0, right = edges[k + 1] - gap / 2.0;
      _place(sc, photos[row[k]], left, y, right - left, rowH);
    }
    y += rowH + gap;
  }
}

/// Divide le foto (in ordine) in righe con somme di proporzioni il più possibile uguali (`_split_rows`).
List<List<int>> splitRows(List<double> aspects, int rows) {
  final n = aspects.length;
  final pre = <double>[0.0];
  for (final a in aspects) {
    pre.add(pre.last + a);
  }
  final target = pre.last / rows;
  final cost = [
    for (var k = 0; k <= rows; k++) List<double>.filled(n + 1, double.infinity),
  ];
  final back = [for (var k = 0; k <= rows; k++) List<int>.filled(n + 1, 0)];
  cost[0][0] = 0.0;
  for (var k = 1; k <= rows; k++) {
    for (var i = k; i <= n; i++) {
      for (var j = k - 1; j < i; j++) {
        final d = pre[i] - pre[j] - target;
        final c = cost[k - 1][j] + d * d;
        if (c < cost[k][i]) {
          cost[k][i] = c;
          back[k][i] = j;
        }
      }
    }
  }
  final bounds = <List<int>>[];
  var i = n;
  for (var k = rows; k > 0; k--) {
    final j = back[k][i];
    bounds.add([for (var t = j; t < i; t++) t]);
    i = j;
  }
  return bounds.reversed.toList();
}
