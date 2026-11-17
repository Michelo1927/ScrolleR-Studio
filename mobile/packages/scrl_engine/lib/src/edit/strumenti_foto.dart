/// Strumenti Foto dell'editor (Fase 4): filtri, regolazioni, inquadratura, ritaglio, rotazione, cornice, ombra,
/// copia e incolla stile, «Applica a tutte». Portati da `scrollr/window/inspector.py` e `scrollr/canvas/photo_item.py`.
///
/// Sono funzioni pure su [PhotoItem] e [Snapshot] immutabili: l'app le chiama mentre si trascina un cursore (bozza)
/// e a ✓ produce un passo di cronologia (l'equivalente di `_schedule_commit`).
library;

import 'dart:math' as math;

import '../color/colore.dart';
import '../model/elements.dart';
import '../model/snapshot.dart';
import 'geometria_foto.dart';
import 'trasforma.dart';

/// Misura in pixel di un'immagine (null = foto mancante o non ancora misurata).
typedef MisuraImmagine = ({int w, int h});

/// Intervalli dei cursori (come i cursori dell'inspector del desktop).
abstract final class LimitiFoto {
  static const int zoomMin = 100, zoomMax = 400;
  static const int panMin = -100, panMax = 100;
  static const int rotazioneMin = -180, rotazioneMax = 180;
  static const int angoliMax = 200;
  static const int bordoMax = 40;
  static const int opacitaMin = 5, opacitaMax = 100;
  static const int ombraMax = 100;

  /// Regolazioni da −100 a +100 (le altre, da 0 a 100: [soloPositive]).
  static const Set<String> soloPositive = {'sharpness', 'fade', 'grain'};
}

/// Applica [f] alle foto di [s] con questi `uid` (le altre restano come sono).
Snapshot modificaFoto(
  Snapshot s,
  Iterable<int> uids,
  PhotoItem Function(PhotoItem) f,
) {
  final set = uids.toSet();
  return s.copyWith(
    items: [for (final p in s.items) set.contains(p.uid) ? f(p) : p],
  );
}

// ---------------------------------------------------------------- Colori

/// Regolazioni di [p] con [chiave] = [valore] (un intero, come il cursore del desktop).
PhotoItem conRegolazione(PhotoItem p, String chiave, int valore) =>
    p.copyWith(adjust: {...p.adjust, chiave: valore});

/// Interruttori `auto` e `bw`.
PhotoItem conInterruttore(PhotoItem p, String chiave, bool acceso) =>
    p.copyWith(adjust: {...p.adjust, chiave: acceso});

/// `_apply_preset`: le regolazioni di un filtro pronto sostituiscono quelle della foto.
PhotoItem conFiltro(PhotoItem p, String chiave) =>
    p.copyWith(adjust: presetAdjust(chiave));

/// `_reset_colors`.
PhotoItem coloriReimpostati(PhotoItem p) =>
    p.copyWith(adjust: Map<String, Object?>.of(neutralAdjust));

/// `_sync_presets`: la chiave del filtro pronto che corrisponde alle regolazioni, o null se non ne corrisponde nessuno.
String? filtroAttivo(Map<String, Object?> adjust) {
  final attuale = {...neutralAdjust, ...adjust};
  bool uguali(Map<String, Object?> a, Map<String, Object?> b) {
    for (final k in {...a.keys, ...b.keys}) {
      if (adjValue(a, k) != adjValue(b, k)) return false;
    }
    return true;
  }

  for (final preset in presets) {
    if (uguali(presetAdjust(preset.key), attuale)) return preset.key;
  }
  return null;
}

/// `_apply_colors_to_all`: le regolazioni di [primaria] su tutte le foto della tela (le pagine bloccate restano).
Snapshot coloriATutte(Snapshot s, PhotoItem primaria) => s.copyWith(
  items: [
    for (final p in s.items)
      p.pageLocked || p.isVideo ? p : p.copyWith(adjust: primaria.adjust),
  ],
);

// ---------------------------------------------------------------- Inquadratura

PhotoItem conZoomInterno(PhotoItem p, double zoom) =>
    p.copyWith(innerZoom: zoom.clamp(1.0, 4.0));

PhotoItem conPan(PhotoItem p, {double? x, double? y}) =>
    p.copyWith(panX: x?.clamp(-1.0, 1.0), panY: y?.clamp(-1.0, 1.0));

PhotoItem conRotazioneInterna(PhotoItem p, double gradi) =>
    p.copyWith(innerRotation: normalizzaGradi(gradi));

/// `_set_fit_mode`: «Riempi riquadro» (`cover`) o «Foto intera» (`contain`); lo spostamento torna al centro.
PhotoItem conFit(PhotoItem p, String modo) =>
    p.copyWith(fitMode: modo, panX: 0.0, panY: 0.0);

/// `_reset_selected_framing`: zoom 100%, foto centrata e dritta nel riquadro (riquadro e rotazione restano).
PhotoItem inquadraturaReimpostata(PhotoItem p) =>
    p.copyWith(innerZoom: 1.0, panX: 0.0, panY: 0.0, innerRotation: 0.0);

/// Spostamento dell'inquadratura interna con un dito (`mouseMoveEvent`, pan interno): ([dx], [dy]) è lo
/// spostamento del dito in unità della tela; la foto lo segue nel suo sistema ruotato.
/// Se la foto ha già le proporzioni del riquadro serve un po' di zoom per poterla spostare (1,15).
PhotoItem panInterno(PhotoItem p, MisuraImmagine? img, double dx, double dy) {
  if (img == null || img.w <= 0 || img.h <= 0) return p;
  var q = p;
  var (mx, my) = _margini(q, img);
  if (mx < 0.5 && my < 0.5) {
    q = q.copyWith(innerZoom: math.max(q.innerZoom, 1.15));
    (mx, my) = _margini(q, img);
  }
  final t = -(q.rotation + q.innerRotation) * math.pi / 180.0;
  final c = math.cos(t), s = math.sin(t);
  final lx = dx * c - dy * s, ly = dx * s + dy * c;
  final sx = q.flipH ? -1.0 : 1.0, sy = q.flipV ? -1.0 : 1.0;
  return q.copyWith(
    panX: mx > 0.5 ? (q.panX + sx * lx / mx).clamp(-1.0, 1.0) : q.panX,
    panY: my > 0.5 ? (q.panY + sy * ly / my).clamp(-1.0, 1.0) : q.panY,
  );
}

/// `_pan_margins`: di quanto si può spostare la foto dentro il riquadro, nei due assi.
(double, double) _margini(PhotoItem p, MisuraImmagine img) {
  final src = p.cropRect(img.w.toDouble(), img.h.toDouble());
  final g = p.coverGeometry(src.w, src.h);
  final (needW, needH) = p.rotatedCellExtent();
  return (
    math.max(0.0, (g.drawW - needW) / 2.0),
    math.max(0.0, (g.drawH - needH) / 2.0),
  );
}

/// Pizzico a due dita dentro il riquadro: [scala] moltiplica lo zoom (100–400%), [gradi] si somma alla rotazione
/// del contenuto.
PhotoItem pizzicoInterno(
  PhotoItem inizio, {
  required double scala,
  required double gradi,
}) => inizio.copyWith(
  innerZoom: (inizio.innerZoom * scala).clamp(1.0, 4.0),
  innerRotation: normalizzaGradi(inizio.innerRotation + gradi),
);

/// `reset_aspect_to_original`: il riquadro prende le proporzioni della foto restando **dentro** quello attuale,
/// col centro fermo; il riquadro di prima si ricorda in `saved_cell`. Senza la misura dell'immagine non fa niente.
PhotoItem proporzioniFoto(PhotoItem p, MisuraImmagine? img) {
  if (img == null || img.w <= 0 || img.h <= 0) return p;
  final saved =
      p.savedCell ??
      {
        'x': p.x,
        'y': p.y,
        'w': p.w,
        'h': p.h,
        'inner_zoom': p.innerZoom,
        'pan_x': p.panX,
        'pan_y': p.panY,
        'stretch': p.stretch,
      };
  final q = p.copyWith(stretch: 1.0);
  final ratio = q.sourceRatio(img);
  final cx = p.x + p.w / 2.0, cy = p.y + p.h / 2.0;
  final nw = math.min(p.w, p.h * ratio);
  final nh = nw / ratio;
  final r = q.copyWith(w: nw, h: nh, savedCell: () => saved);
  return r.copyWith(
    x: cx - r.w / 2.0,
    y: cy - r.h / 2.0,
    panX: 0.0,
    panY: 0.0,
    innerZoom: 1.0,
  );
}

/// `restore_saved_cell`: torna al riquadro com'era prima di «Proporzioni foto».
PhotoItem riquadroDiPrima(PhotoItem p) {
  final sc = p.savedCell;
  if (sc == null) return p;
  double n(String k, double d) =>
      (sc[k] is num) ? (sc[k]! as num).toDouble() : d;
  return p.copyWith(
    w: n('w', p.w),
    h: n('h', p.h),
    x: n('x', p.x),
    y: n('y', p.y),
    innerZoom: n('inner_zoom', p.innerZoom),
    panX: n('pan_x', p.panX),
    panY: n('pan_y', p.panY),
    stretch: n('stretch', p.stretch),
    savedCell: () => null,
  );
}

/// Il riquadro di prima si può ripristinare.
bool puoRipristinareRiquadro(Iterable<PhotoItem> foto) =>
    foto.isNotEmpty && foto.every((p) => p.savedCell != null);

/// `_restore_selected_original_ratio`: «Proporzioni foto» ⇄ «Riquadro di prima».
PhotoItem alternaProporzioni(PhotoItem p, MisuraImmagine? img) =>
    p.savedCell != null ? riquadroDiPrima(p) : proporzioniFoto(p, img);

/// `has_crop`.
bool haRitaglio(PhotoItem p) {
  for (var i = 0; i < 4; i++) {
    if (p.crop[i] != fullCrop[i]) return true;
  }
  return false;
}

/// `apply_crop`: imposta il ritaglio e riparte da un'inquadratura pulita (zoom 100%, centrata). Con [adattaRiquadro]
/// il riquadro prende la forma del ritaglio, col centro fermo: una foto libera mantiene circa la stessa area, una
/// foto nella disposizione resta dentro il suo spazio.
PhotoItem conRitaglio(
  PhotoItem p,
  List<double> ritaglio,
  bool adattaRiquadro,
  MisuraImmagine? img,
) {
  var q = p.copyWith(
    crop: cleanCrop(ritaglio),
    innerZoom: 1.0,
    panX: 0.0,
    panY: 0.0,
    savedCell: () => null,
  );
  if (adattaRiquadro && img != null && img.w > 0 && img.h > 0) {
    final ratio = q.sourceRatio(img);
    final cx = p.x + p.w / 2.0, cy = p.y + p.h / 2.0;
    double nw, nh;
    if (p.free) {
      final area = p.w * p.h;
      nw = math.sqrt(area * ratio);
      nh = math.sqrt(area / ratio);
    } else {
      nw = math.min(p.w, p.h * ratio);
      nh = nw / ratio;
    }
    q = q.copyWith(w: nw, h: nh);
    q = q.copyWith(x: cx - q.w / 2.0, y: cy - q.h / 2.0);
  }
  return q;
}

// ---------------------------------------------------------------- Rotazione e specchio

PhotoItem conRotazione(PhotoItem p, double gradi) =>
    p.copyWith(rotation: gradi);

/// `_rotate_selected_by`: ruota di [delta] gradi, riportando l'angolo tra −180° e 180°.
PhotoItem ruotataDi(PhotoItem p, double delta) =>
    p.copyWith(rotation: ((p.rotation + delta + 180.0) % 360.0) - 180.0);

/// `_flip_selected`.
PhotoItem specchiata(PhotoItem p, {required bool orizzontale}) =>
    orizzontale ? p.copyWith(flipH: !p.flipH) : p.copyWith(flipV: !p.flipV);

// ---------------------------------------------------------------- Cornice, ombra, opacità

PhotoItem conAngoli(PhotoItem p, int v) =>
    p.copyWith(borderRadius: v.toDouble());

/// Lo spessore del bordo a mano spegne il bordo automatico (`_on_inspector_slider`).
PhotoItem conBordo(PhotoItem p, int v) =>
    p.copyWith(borderWidth: v.toDouble(), autoBorder: false);

PhotoItem conColoreBordo(PhotoItem p, int argb) =>
    p.copyWith(borderColor: argb);

PhotoItem conOpacita(PhotoItem p, int v) =>
    p.copyWith(opacity: v.clamp(LimitiFoto.opacitaMin, LimitiFoto.opacitaMax));

PhotoItem conOmbra(PhotoItem p, int v) => p.copyWith(shadow: v);

/// Cornice, opacità, ombra e colori di una foto (`_copy_style`).
class StileFoto {
  const StileFoto({
    required this.borderRadius,
    required this.borderWidth,
    required this.borderColor,
    required this.opacity,
    required this.shadow,
    required this.adjust,
  });

  factory StileFoto.di(PhotoItem p) => StileFoto(
    borderRadius: p.borderRadius,
    borderWidth: p.borderWidth,
    borderColor: p.borderColor,
    opacity: p.opacity,
    shadow: p.shadow,
    adjust: Map<String, Object?>.of(p.adjust),
  );

  final double borderRadius;
  final double borderWidth;
  final int borderColor;
  final int opacity;
  final int shadow;
  final Map<String, Object?> adjust;

  /// `_paste_style`: il bordo non è più automatico.
  PhotoItem su(PhotoItem p) => p.copyWith(
    borderRadius: borderRadius,
    borderWidth: borderWidth,
    borderColor: borderColor,
    autoBorder: false,
    opacity: opacity,
    shadow: shadow,
    adjust: adjust,
  );
}

/// `_paste_style`: lo stile copiato sulle foto con questi `uid`.
Snapshot incollaStile(Snapshot s, Iterable<int> uids, StileFoto stile) =>
    modificaFoto(s, uids, stile.su);

/// `_apply_style_to_all_photos`: angoli, bordo, colore del bordo, opacità e ombra di [primaria] su tutte le foto
/// della tela (le pagine bloccate restano com'erano).
Snapshot stileATutte(Snapshot s, PhotoItem primaria) => s.copyWith(
  items: [
    for (final p in s.items)
      p.pageLocked
          ? p
          : p.copyWith(
              borderRadius: primaria.borderRadius,
              borderWidth: primaria.borderWidth,
              borderColor: primaria.borderColor,
              autoBorder: false,
              opacity: primaria.opacity,
              shadow: primaria.shadow,
            ),
  ],
);

/// Valore intero di un cursore per una regolazione (`int(item.adjust.get(key, 0))`).
int valoreRegolazione(PhotoItem p, String chiave) =>
    adjValue(p.adjust, chiave).toInt();
