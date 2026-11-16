/// Elementi della tela: foto (e video), testi, forme. Stessi campi di `get_state` / `set_state`
/// in `scrollr/canvas/*.py`, con gli stessi predefiniti e gli stessi arrotondamenti.
library;

import 'dart:math' as math;

import '../util/py.dart';
import 'argb.dart';
import 'json_read.dart';

/// Riquadro allineato agli assi (come `QRectF`).
class Rect {
  final double x, y, w, h;
  const Rect(this.x, this.y, this.w, this.h);
  double get left => x;
  double get top => y;
  double get right => x + w;
  double get bottom => y + h;
  double get centerX => x + w / 2.0;
  double get centerY => y + h / 2.0;

  /// `QRectF.adjusted(dx1, dy1, dx2, dy2)`.
  Rect adjusted(double dx1, double dy1, double dx2, double dy2) =>
      Rect(x + dx1, y + dy1, w - dx1 + dx2, h - dy1 + dy2);

  /// Ingombro del riquadro (0, 0, w, h) in posizione (x, y) ruotato di [gradi] attorno al suo centro
  /// (`mapRectToScene` con l'origine della trasformazione al centro).
  static Rect rotated(double x, double y, double w, double h, double gradi) {
    if (gradi == 0.0) return Rect(x, y, w, h);
    final t = gradi * math.pi / 180.0;
    final c = math.cos(t).abs(), s = math.sin(t).abs();
    final rw = w * c + h * s, rh = w * s + h * c;
    final cx = x + w / 2.0, cy = y + h / 2.0;
    return Rect(cx - rw / 2.0, cy - rh / 2.0, rw, rh);
  }

  @override
  String toString() => 'Rect($x, $y, $w, $h)';
}

/// Regolazioni neutre (`NEUTRAL_ADJUST` di `scrollr/imaging.py`).
const Map<String, Object?> neutralAdjust = {
  'brightness': 0,
  'contrast': 0,
  'shadows': 0,
  'highlights': 0,
  'saturation': 0,
  'warmth': 0,
  'tint': 0,
  'sharpness': 0,
  'vignette': 0,
  'fade': 0,
  'grain': 0,
  'bw': false,
  'auto': false,
};

/// Ritaglio intero (`FULL_CROP`).
const List<double> fullCrop = [0.0, 0.0, 1.0, 1.0];

/// `clean_crop`: ritaglio valido (dentro la foto, non vuoto); se non lo è, la foto intera.
List<double> cleanCrop(Object? c) {
  if (c is! List || c.length != 4) return fullCrop;
  final v = <double>[];
  for (final x in c) {
    double d;
    if (x is num) {
      d = x.toDouble();
    } else if (x is String && double.tryParse(x) != null) {
      d = double.parse(x);
    } else {
      return fullCrop;
    }
    v.add(math.max(0.0, math.min(1.0, d)));
  }
  if (v[2] - v[0] < 0.005 || v[3] - v[1] < 0.005) return fullCrop;
  return List.unmodifiable(v);
}

/// Riferimento alla galleria del telefono (campo solo mobile `asset`, ignorato dal desktop).
class MediaAsset {
  final String platform;
  final String id;
  final String name;
  final Map<String, Object?> extra;

  MediaAsset({
    required this.platform,
    required this.id,
    this.name = '',
    Map<String, Object?> extra = const {},
  }) : extra = Map.unmodifiable(extra);

  static MediaAsset? fromJson(Object? v) {
    if (v is! Map) return null;
    final m = asMap(v);
    final platform = readStringOrNull(m, 'platform');
    final id = readStringOrNull(m, 'id');
    if (platform == null || id == null) return null;
    return MediaAsset(
      platform: platform,
      id: id,
      name: readString(m, 'name', ''),
      extra: unknownFields(m, const {'platform', 'id', 'name'}),
    );
  }

  Map<String, Object?> toJson() => {
    'platform': platform,
    'id': id,
    'name': name,
    ...extra,
  };
}

/// Base comune: uid, posizione, rotazione, livello, blocchi, gruppo e campi sconosciuti.
sealed class CanvasElement {
  int get uid;
  double get x;
  double get y;
  double get rotation;
  double get z;
  bool get locked;
  bool get pageLocked;
  int get group;
  Map<String, Object?> get extra;

  Map<String, Object?> toJson();

  CanvasElement withPosition(double x, double y);
  CanvasElement withZ(double z);
  CanvasElement withGroup(int group);
  CanvasElement withPageLocked(bool on);
}

/// Foto o video della tela (`PhotoItem` / `VideoItem`).
class PhotoItem extends CanvasElement {
  @override
  final int uid;

  /// Percorso salvato dal desktop (sul telefono: nome originale o valore relativo in `media/`).
  final String path;

  /// Percorso relativo alla cartella del progetto (con `/`), oppure null.
  final String? rel;

  /// Foto collegata alla galleria del telefono (solo mobile).
  final MediaAsset? asset;
  @override
  final double x;
  @override
  final double y;

  /// Larghezza e altezza della cella (`cell_w`, `cell_h`, minimo 40).
  final double w;
  final double h;
  @override
  final double rotation;
  @override
  final double z;
  final int layoutIndex;
  final double innerZoom;
  final double panX;
  final double panY;
  final double innerRotation;
  final List<double> crop;
  final double stretch;
  final double borderRadius;
  final double borderWidth;
  final int borderColor;
  final bool autoBorder;
  final Map<String, Object?> adjust;
  final bool flipH;
  final bool flipV;
  final String fitMode;
  final int opacity;
  final int shadow;
  @override
  final bool locked;
  @override
  final bool pageLocked;
  final bool free;
  final Map<String, Object?>? savedCell;
  @override
  final int group;

  /// Video (`kind: "video"`): taglio, audio e copertina.
  final bool isVideo;
  final double trimStart;
  final double? trimEnd;
  final bool muted;
  final double poster;
  @override
  final Map<String, Object?> extra;

  static const double minCell = 40.0;

  PhotoItem({
    required this.uid,
    required this.path,
    this.rel,
    this.asset,
    this.x = 0.0,
    this.y = 0.0,
    double w = 400.0,
    double h = 500.0,
    this.rotation = 0.0,
    this.z = 0.0,
    this.layoutIndex = 0,
    this.innerZoom = 1.0,
    this.panX = 0.0,
    this.panY = 0.0,
    this.innerRotation = 0.0,
    List<double> crop = fullCrop,
    double stretch = 1.0,
    this.borderRadius = 0.0,
    this.borderWidth = 0.0,
    this.borderColor = 0xFFFFFFFF,
    this.autoBorder = false,
    Map<String, Object?> adjust = neutralAdjust,
    this.flipH = false,
    this.flipV = false,
    this.fitMode = 'cover',
    this.opacity = 100,
    this.shadow = 0,
    this.locked = false,
    this.pageLocked = false,
    this.free = false,
    Map<String, Object?>? savedCell,
    this.group = 0,
    this.isVideo = false,
    this.trimStart = 0.0,
    this.trimEnd,
    this.muted = false,
    this.poster = 0.0,
    Map<String, Object?> extra = const {},
  }) : w = math.max(minCell, w),
       h = math.max(minCell, h),
       crop = List.unmodifiable(crop),
       stretch = math.min(20.0, math.max(0.05, stretch)),
       adjust =
           jsonFreeze(
                 isVideo
                     ? neutralAdjust
                     : <String, Object?>{...neutralAdjust, ...adjust},
               )!
               as Map<String, Object?>,
       savedCell = savedCell == null || savedCell.isEmpty
           ? null
           : jsonFreeze(savedCell) as Map<String, Object?>,
       extra = jsonFreeze(extra)! as Map<String, Object?>;

  static const _noti = {
    'uid',
    'path',
    'rel',
    'asset',
    'x',
    'y',
    'w',
    'h',
    'rotation',
    'z',
    'layout_index',
    'inner_zoom',
    'pan_x',
    'pan_y',
    'inner_rotation',
    'crop',
    'stretch',
    'border_radius',
    'border_width',
    'border_color',
    'auto_border',
    'adjust',
    'flip_h',
    'flip_v',
    'fit_mode',
    'opacity',
    'shadow',
    'locked',
    'page_locked',
    'free',
    'saved_cell',
    'group',
    'kind',
    'trim_start',
    'trim_end',
    'muted',
    'poster',
  };

  factory PhotoItem.fromJson(Object? json) {
    final s = asMap(json);
    final isVideo = s['kind'] == 'video';
    final trimStart = math.max(0.0, readDouble(s, 'trim_start', 0.0));
    final fine = s['trim_end'];
    final adjust = s['adjust'];
    final saved = s['saved_cell'];
    return PhotoItem(
      uid: readInt(s, 'uid', 0),
      path: readString(s, 'path', ''),
      rel: readStringOrNull(s, 'rel'),
      asset: MediaAsset.fromJson(s['asset']),
      x: readDouble(s, 'x', 0.0),
      y: readDouble(s, 'y', 0.0),
      w: readDouble(s, 'w', 400.0),
      h: readDouble(s, 'h', 500.0),
      rotation: readDouble(s, 'rotation', 0.0),
      z: readDouble(s, 'z', 0.0),
      layoutIndex: readInt(s, 'layout_index', 0),
      innerZoom: readDouble(s, 'inner_zoom', 1.0),
      panX: readDouble(s, 'pan_x', 0.0),
      panY: readDouble(s, 'pan_y', 0.0),
      innerRotation: readDouble(s, 'inner_rotation', 0.0),
      crop: cleanCrop(s['crop'] ?? fullCrop),
      stretch: readDouble(s, 'stretch', 1.0),
      borderRadius: readDouble(s, 'border_radius', 0.0),
      borderWidth: readDouble(s, 'border_width', 0.0),
      borderColor: parseArgb(s['border_color'], 0xFFFFFFFF),
      autoBorder: readBool(s, 'auto_border', false),
      adjust: adjust is Map ? asMap(adjust) : neutralAdjust,
      flipH: readBool(s, 'flip_h', false),
      flipV: readBool(s, 'flip_v', false),
      fitMode: readString(s, 'fit_mode', 'cover'),
      opacity: readInt(s, 'opacity', 100),
      shadow: readInt(s, 'shadow', 0),
      locked: readBool(s, 'locked', false),
      pageLocked: readBool(s, 'page_locked', false),
      free: readBool(s, 'free', false),
      savedCell: saved is Map && saved.isNotEmpty ? asMap(saved) : null,
      group: readInt(s, 'group', 0),
      isVideo: isVideo,
      trimStart: trimStart,
      // Senza la durata del video (nota solo all'app) si applica la parte di `set_trim` che non ne dipende
      trimEnd: fine is num ? math.max(trimStart + 0.1, fine.toDouble()) : null,
      muted: readBool(s, 'muted', false),
      poster: math.max(0.0, readDouble(s, 'poster', 0.0)),
      extra: unknownFields(s, _noti),
    );
  }

  /// Come `get_state()` (più `kind`/taglio per i video), poi `rel` e `asset` come nel file, poi i campi sconosciuti.
  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'uid': uid,
    'path': path,
    'x': pyRoundTo(x, 3),
    'y': pyRoundTo(y, 3),
    'w': pyRoundTo(w, 3),
    'h': pyRoundTo(h, 3),
    'rotation': pyRoundTo(rotation, 3),
    'z': z,
    'layout_index': layoutIndex,
    'inner_zoom': pyRoundTo(innerZoom, 4),
    'pan_x': pyRoundTo(panX, 4),
    'pan_y': pyRoundTo(panY, 4),
    'inner_rotation': pyRoundTo(innerRotation, 3),
    'crop': [for (final v in crop) pyRoundTo(v, 5)],
    'stretch': pyRoundTo(stretch, 5),
    'border_radius': borderRadius,
    'border_width': borderWidth,
    'border_color': formatArgb(borderColor),
    'auto_border': autoBorder,
    'adjust': jsonCopy(adjust),
    'flip_h': flipH,
    'flip_v': flipV,
    'fit_mode': fitMode,
    'opacity': opacity,
    'shadow': shadow,
    'locked': locked,
    'page_locked': pageLocked,
    'free': free,
    'saved_cell': savedCell == null ? null : jsonCopy(savedCell),
    'group': group,
    if (isVideo) ...{
      'kind': 'video',
      'trim_start': pyRoundTo(trimStart, 3),
      'trim_end': trimEnd == null ? null : pyRoundTo(trimEnd!, 3),
      'muted': muted,
      'poster': pyRoundTo(poster, 3),
    },
    'rel': rel,
    if (asset != null) 'asset': asset!.toJson(),
    ...extra,
  };

  /// Proporzioni della foto ritagliata e stirata (`source_ratio`), data la misura dell'immagine
  /// (null = foto mancante → 1,0).
  double sourceRatio(({int w, int h})? immagine) {
    if (immagine == null || immagine.w <= 0 || immagine.h <= 0) return 1.0;
    final srcW = (crop[2] - crop[0]) * immagine.w;
    final srcH = (crop[3] - crop[1]) * immagine.h;
    return srcH > 0 ? srcW * stretch / srcH : 1.0;
  }

  Rect get cellRect => Rect.rotated(x, y, w, h, rotation);

  @override
  PhotoItem withPosition(double x, double y) => copyWith(x: x, y: y);
  @override
  PhotoItem withZ(double z) => copyWith(z: z);
  @override
  PhotoItem withGroup(int group) => copyWith(group: group);
  @override
  PhotoItem withPageLocked(bool on) => copyWith(pageLocked: on);

  PhotoItem copyWith({
    int? uid,
    String? path,
    String? Function()? rel,
    MediaAsset? Function()? asset,
    double? x,
    double? y,
    double? w,
    double? h,
    double? rotation,
    double? z,
    int? layoutIndex,
    double? innerZoom,
    double? panX,
    double? panY,
    double? innerRotation,
    List<double>? crop,
    double? stretch,
    double? borderRadius,
    double? borderWidth,
    int? borderColor,
    bool? autoBorder,
    Map<String, Object?>? adjust,
    bool? flipH,
    bool? flipV,
    String? fitMode,
    int? opacity,
    int? shadow,
    bool? locked,
    bool? pageLocked,
    bool? free,
    Map<String, Object?>? Function()? savedCell,
    int? group,
    bool? isVideo,
    double? trimStart,
    double? Function()? trimEnd,
    bool? muted,
    double? poster,
    Map<String, Object?>? extra,
  }) => PhotoItem(
    uid: uid ?? this.uid,
    path: path ?? this.path,
    rel: rel != null ? rel() : this.rel,
    asset: asset != null ? asset() : this.asset,
    x: x ?? this.x,
    y: y ?? this.y,
    w: w ?? this.w,
    h: h ?? this.h,
    rotation: rotation ?? this.rotation,
    z: z ?? this.z,
    layoutIndex: layoutIndex ?? this.layoutIndex,
    innerZoom: innerZoom ?? this.innerZoom,
    panX: panX ?? this.panX,
    panY: panY ?? this.panY,
    innerRotation: innerRotation ?? this.innerRotation,
    crop: crop ?? this.crop,
    stretch: stretch ?? this.stretch,
    borderRadius: borderRadius ?? this.borderRadius,
    borderWidth: borderWidth ?? this.borderWidth,
    borderColor: borderColor ?? this.borderColor,
    autoBorder: autoBorder ?? this.autoBorder,
    adjust: adjust ?? this.adjust,
    flipH: flipH ?? this.flipH,
    flipV: flipV ?? this.flipV,
    fitMode: fitMode ?? this.fitMode,
    opacity: opacity ?? this.opacity,
    shadow: shadow ?? this.shadow,
    locked: locked ?? this.locked,
    pageLocked: pageLocked ?? this.pageLocked,
    free: free ?? this.free,
    savedCell: savedCell != null ? savedCell() : this.savedCell,
    group: group ?? this.group,
    isVideo: isVideo ?? this.isVideo,
    trimStart: trimStart ?? this.trimStart,
    trimEnd: trimEnd != null ? trimEnd() : this.trimEnd,
    muted: muted ?? this.muted,
    poster: poster ?? this.poster,
    extra: extra ?? this.extra,
  );
}

/// Testo della tela (`TextItem`).
class TextItem extends CanvasElement {
  /// Carattere del desktop su Windows quando il file non lo indica (`font_family("display")`).
  static const String defaultFont = 'Segoe UI Variable Display';

  @override
  final int uid;
  final String text;
  @override
  final double x;
  @override
  final double y;
  @override
  final double rotation;
  @override
  final double z;
  final String font;
  final double size;
  final bool bold;
  final bool italic;
  final String align;
  final int color;
  final bool shadow;
  final bool box;
  final int boxColor;
  final int opacity;
  final double outline;
  final int outlineColor;
  final int lineHeight;
  final int letterSpacing;
  @override
  final bool locked;
  @override
  final bool pageLocked;
  @override
  final int group;
  @override
  final Map<String, Object?> extra;

  TextItem({
    required this.uid,
    this.text = 'Scrivi qui',
    this.x = 0.0,
    this.y = 0.0,
    this.rotation = 0.0,
    this.z = 0.0,
    this.font = defaultFont,
    this.size = 72.0,
    this.bold = true,
    this.italic = false,
    this.align = 'center',
    this.color = 0xFFFFFFFF,
    this.shadow = true,
    this.box = false,
    this.boxColor = 0x96000000,
    this.opacity = 100,
    this.outline = 0.0,
    this.outlineColor = 0xFF000000,
    this.lineHeight = 100,
    this.letterSpacing = 0,
    this.locked = false,
    this.pageLocked = false,
    this.group = 0,
    Map<String, Object?> extra = const {},
  }) : extra = jsonFreeze(extra)! as Map<String, Object?>;

  static const _noti = {
    'uid',
    'text',
    'x',
    'y',
    'rotation',
    'z',
    'font',
    'size',
    'bold',
    'italic',
    'align',
    'color',
    'shadow',
    'box',
    'box_color',
    'opacity',
    'outline',
    'outline_color',
    'line_height',
    'letter_spacing',
    'locked',
    'page_locked',
    'group',
  };

  factory TextItem.fromJson(Object? json) {
    final s = asMap(json);
    return TextItem(
      uid: readInt(s, 'uid', 0),
      text: readString(s, 'text', ''),
      x: readDouble(s, 'x', 0.0),
      y: readDouble(s, 'y', 0.0),
      rotation: readDouble(s, 'rotation', 0.0),
      z: readDouble(s, 'z', 0.0),
      font: readString(s, 'font', defaultFont),
      size: readDouble(s, 'size', 72.0),
      bold: readBool(s, 'bold', true),
      italic: readBool(s, 'italic', false),
      align: readString(s, 'align', 'center'),
      color: parseArgb(s['color'], 0xFFFFFFFF),
      shadow: readBool(s, 'shadow', true),
      box: readBool(s, 'box', false),
      boxColor: parseArgb(s['box_color'], 0x96000000),
      opacity: readInt(s, 'opacity', 100),
      outline: readDouble(s, 'outline', 0.0),
      outlineColor: parseArgb(s['outline_color'], 0xFF000000),
      lineHeight: readInt(s, 'line_height', 100),
      letterSpacing: readInt(s, 'letter_spacing', 0),
      locked: readBool(s, 'locked', false),
      pageLocked: readBool(s, 'page_locked', false),
      group: readInt(s, 'group', 0),
      extra: unknownFields(s, _noti),
    );
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'uid': uid,
    'text': text,
    'x': pyRoundTo(x, 3),
    'y': pyRoundTo(y, 3),
    'rotation': pyRoundTo(rotation, 3),
    'z': z,
    'font': font,
    'size': size,
    'bold': bold,
    'italic': italic,
    'align': align,
    'color': formatArgb(color),
    'shadow': shadow,
    'box': box,
    'box_color': formatArgb(boxColor),
    'opacity': opacity,
    'outline': outline,
    'outline_color': formatArgb(outlineColor),
    'line_height': lineHeight,
    'letter_spacing': letterSpacing,
    'locked': locked,
    'page_locked': pageLocked,
    'group': group,
    ...extra,
  };

  /// Margine interno del riquadro del testo (`relayout`).
  double get pad => size * (box ? 0.35 : 0.08) + outline;

  @override
  TextItem withPosition(double x, double y) => copyWith(x: x, y: y);
  @override
  TextItem withZ(double z) => copyWith(z: z);
  @override
  TextItem withGroup(int group) => copyWith(group: group);
  @override
  TextItem withPageLocked(bool on) => copyWith(pageLocked: on);

  TextItem copyWith({
    int? uid,
    String? text,
    double? x,
    double? y,
    double? rotation,
    double? z,
    String? font,
    double? size,
    bool? bold,
    bool? italic,
    String? align,
    int? color,
    bool? shadow,
    bool? box,
    int? boxColor,
    int? opacity,
    double? outline,
    int? outlineColor,
    int? lineHeight,
    int? letterSpacing,
    bool? locked,
    bool? pageLocked,
    int? group,
    Map<String, Object?>? extra,
  }) => TextItem(
    uid: uid ?? this.uid,
    text: text ?? this.text,
    x: x ?? this.x,
    y: y ?? this.y,
    rotation: rotation ?? this.rotation,
    z: z ?? this.z,
    font: font ?? this.font,
    size: size ?? this.size,
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    align: align ?? this.align,
    color: color ?? this.color,
    shadow: shadow ?? this.shadow,
    box: box ?? this.box,
    boxColor: boxColor ?? this.boxColor,
    opacity: opacity ?? this.opacity,
    outline: outline ?? this.outline,
    outlineColor: outlineColor ?? this.outlineColor,
    lineHeight: lineHeight ?? this.lineHeight,
    letterSpacing: letterSpacing ?? this.letterSpacing,
    locked: locked ?? this.locked,
    pageLocked: pageLocked ?? this.pageLocked,
    group: group ?? this.group,
    extra: extra ?? this.extra,
  );
}

/// Linee e frecce (`LINE_KINDS`): l'altezza è lo spessore, minimo 1.
const List<String> lineKinds = ['line', 'arrow', 'double_arrow'];

/// Forma della tela (`ShapeItem`).
class ShapeItem extends CanvasElement {
  static const double minSize = 8.0;

  @override
  final int uid;
  final String kind;
  @override
  final double x;
  @override
  final double y;
  final double w;
  final double h;
  @override
  final double rotation;
  @override
  final double z;
  final int fill;
  final int stroke;
  final double strokeWidth;
  final String strokeStyle;
  final double radius;
  final int opacity;
  @override
  final bool locked;
  @override
  final bool pageLocked;
  @override
  final int group;
  @override
  final Map<String, Object?> extra;

  ShapeItem({
    required this.uid,
    this.kind = 'rect',
    this.x = 0.0,
    this.y = 0.0,
    double w = 300.0,
    double h = 300.0,
    this.rotation = 0.0,
    this.z = 0.0,
    this.fill = 0xFFFF3B30,
    this.stroke = 0xFFFFFFFF,
    this.strokeWidth = 0.0,
    this.strokeStyle = 'solid',
    this.radius = 0.0,
    this.opacity = 100,
    this.locked = false,
    this.pageLocked = false,
    this.group = 0,
    Map<String, Object?> extra = const {},
  }) : w = math.max(minSize, w),
       h = lineKinds.contains(kind) ? math.max(1.0, h) : math.max(minSize, h),
       extra = jsonFreeze(extra)! as Map<String, Object?>;

  bool get isLine => lineKinds.contains(kind);

  static const _noti = {
    'uid',
    'kind',
    'x',
    'y',
    'w',
    'h',
    'rotation',
    'z',
    'fill',
    'stroke',
    'stroke_width',
    'stroke_style',
    'radius',
    'opacity',
    'locked',
    'page_locked',
    'group',
  };

  factory ShapeItem.fromJson(Object? json) {
    final s = asMap(json);
    return ShapeItem(
      uid: readInt(s, 'uid', 0),
      kind: readString(s, 'kind', 'rect'),
      x: readDouble(s, 'x', 0.0),
      y: readDouble(s, 'y', 0.0),
      w: readDouble(s, 'w', 300.0),
      h: readDouble(s, 'h', 300.0),
      rotation: readDouble(s, 'rotation', 0.0),
      z: readDouble(s, 'z', 0.0),
      fill: parseArgb(s['fill'], 0xFFFF3B30),
      stroke: parseArgb(s['stroke'], 0xFFFFFFFF),
      strokeWidth: readDouble(s, 'stroke_width', 0.0),
      strokeStyle: readString(s, 'stroke_style', 'solid'),
      radius: readDouble(s, 'radius', 0.0),
      opacity: readInt(s, 'opacity', 100),
      locked: readBool(s, 'locked', false),
      pageLocked: readBool(s, 'page_locked', false),
      group: readInt(s, 'group', 0),
      extra: unknownFields(s, _noti),
    );
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'uid': uid,
    'kind': kind,
    'x': pyRoundTo(x, 3),
    'y': pyRoundTo(y, 3),
    'w': pyRoundTo(w, 3),
    'h': pyRoundTo(h, 3),
    'rotation': pyRoundTo(rotation, 3),
    'z': z,
    'fill': formatArgb(fill),
    'stroke': formatArgb(stroke),
    'stroke_width': strokeWidth,
    'stroke_style': strokeStyle,
    'radius': radius,
    'opacity': opacity,
    'locked': locked,
    'page_locked': pageLocked,
    'group': group,
    ...extra,
  };

  Rect get frameRect => Rect.rotated(x, y, w, h, rotation);

  @override
  ShapeItem withPosition(double x, double y) => copyWith(x: x, y: y);
  @override
  ShapeItem withZ(double z) => copyWith(z: z);
  @override
  ShapeItem withGroup(int group) => copyWith(group: group);
  @override
  ShapeItem withPageLocked(bool on) => copyWith(pageLocked: on);

  ShapeItem copyWith({
    int? uid,
    String? kind,
    double? x,
    double? y,
    double? w,
    double? h,
    double? rotation,
    double? z,
    int? fill,
    int? stroke,
    double? strokeWidth,
    String? strokeStyle,
    double? radius,
    int? opacity,
    bool? locked,
    bool? pageLocked,
    int? group,
    Map<String, Object?>? extra,
  }) => ShapeItem(
    uid: uid ?? this.uid,
    kind: kind ?? this.kind,
    x: x ?? this.x,
    y: y ?? this.y,
    w: w ?? this.w,
    h: h ?? this.h,
    rotation: rotation ?? this.rotation,
    z: z ?? this.z,
    fill: fill ?? this.fill,
    stroke: stroke ?? this.stroke,
    strokeWidth: strokeWidth ?? this.strokeWidth,
    strokeStyle: strokeStyle ?? this.strokeStyle,
    radius: radius ?? this.radius,
    opacity: opacity ?? this.opacity,
    locked: locked ?? this.locked,
    pageLocked: pageLocked ?? this.pageLocked,
    group: group ?? this.group,
    extra: extra ?? this.extra,
  );
}
