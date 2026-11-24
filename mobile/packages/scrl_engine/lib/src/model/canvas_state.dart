/// Impostazioni della tela: la sezione `canvas` del `.scrlproj` e dello snapshot del desktop
/// (`HistoryMixin._snapshot` / `_restore_snapshot`).
library;

import 'dart:math' as math;

import '../project/formato.dart';
import '../util/py.dart';
import 'argb.dart';
import 'json_read.dart';

/// Disposizione propria di una pagina: `{"mode": ..., "style": ...}`.
class PageLayout {
  final String mode;
  final String? style;
  final Map<String, Object?> extra;

  PageLayout(this.mode, [this.style, Map<String, Object?>? extra])
    : extra = Map<String, Object?>.unmodifiable(
        extra ?? const <String, Object?>{},
      );

  /// `None` per un valore vuoto o non valido (come `if own:` nel desktop).
  static PageLayout? fromJson(Object? v) {
    if (v is! Map || v.isEmpty) return null;
    final m = asMap(v);
    final mode = m['mode'];
    if (mode is! String || mode.isEmpty) return null;
    return PageLayout(
      mode,
      readStringOrNull(m, 'style'),
      unknownFields(m, const {'mode', 'style'}),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'mode': mode,
    'style': style,
    ...extra,
  };

  @override
  bool operator ==(Object other) =>
      other is PageLayout && jsonEquals(toJson(), other.toJson());

  @override
  int get hashCode => Object.hash(mode, style);
}

/// Modi di disposizione del desktop.
abstract final class LayoutModes {
  static const grid = 'grid';
  static const mosaic = 'mosaic';
  static const stripsH = 'strips_h';
  static const stripsV = 'strips_v';
  static const scatter = 'scatter';
  static const film = 'film';
  static const seam = 'scrl_seam';
  static const all = [grid, mosaic, stripsH, stripsV, scatter, film, seam];
}

/// Versi delle strisce di «Pellicola» del desktop (`FILM_STYLES`).
abstract final class FilmStyles {
  static const all = ['auto', 'horizontal', 'vertical'];
}

/// Stili del mosaico del desktop (`MOSAIC_STYLES`).
abstract final class MosaicStyles {
  static const all = [
    'auto',
    'top',
    'bottom',
    'left',
    'right',
    'center',
    'two',
    'masonry',
  ];
}

class CanvasState {
  final int ratioIndex;
  final int customW;
  final int customH;
  final int frameW;
  final int frameH;
  final int numFrames;
  final int bgColor;
  final int gap;
  final int margin;
  final bool perFrame;
  final int perPage;
  final List<int?> pageCounts;
  final List<PageLayout?> pageLayouts;
  final List<bool?> pageSeams;
  final List<bool?> pageLocks;
  final String layoutMode;
  final String mosaicStyle;

  /// Verso delle strisce di «Pellicola» (`film_style`): 'auto', 'horizontal', 'vertical'.
  final String filmStyle;

  /// Ombra (0..100) e rilievo 3D (0..100) dei cartoncini della disposizione Polaroid.
  final int polaroidShadow;
  final int polaroidDepth;
  final int layoutSeed;
  final String bgMode;
  final int bgColor2;
  final String bgDirection;
  final String bgBlurPath;
  final String? bgBlurRel;
  final int bgBlurAmount;
  final int bgDim;
  final bool pageNumbers;
  final String pageNumberFormat;
  final String pageNumberPos;
  final String overlayStyle;
  final bool swipeHint;
  final String swipeText;
  final String swipePos;
  final String exportName;

  /// `project_type`: «carousel» (carosello o foto) o «reel» (una pagina, video fino a 5 minuti).
  final String projectType;

  /// Campi sconosciuti (da un desktop più recente): si riscrivono tali e quali.
  final Map<String, Object?> extra;

  CanvasState({
    this.ratioIndex = 0,
    this.customW = 1080,
    this.customH = 1440,
    this.frameW = 1080,
    this.frameH = 1440,
    this.numFrames = 1,
    this.bgColor = 0xFFFFFFFF,
    this.gap = 16,
    this.margin = 24,
    this.perFrame = true,
    this.perPage = 0,
    List<int?> pageCounts = const [],
    List<PageLayout?> pageLayouts = const [],
    List<bool?> pageSeams = const [],
    List<bool?> pageLocks = const [],
    this.layoutMode = LayoutModes.grid,
    this.mosaicStyle = 'auto',
    String filmStyle = 'auto',
    int polaroidShadow = 0,
    int polaroidDepth = 0,
    int? layoutSeed,
    this.bgMode = 'solid',
    this.bgColor2 = 0xFF2680EB,
    this.bgDirection = 'vertical',
    this.bgBlurPath = '',
    this.bgBlurRel,
    this.bgBlurAmount = 50,
    this.bgDim = 15,
    this.pageNumbers = false,
    this.pageNumberFormat = 'slash',
    this.pageNumberPos = 'bc',
    this.overlayStyle = 'dark',
    this.swipeHint = false,
    this.swipeText = 'Scorri →',
    this.swipePos = 'br',
    this.exportName = '',
    String projectType = 'carousel',
    Map<String, Object?> extra = const {},
  }) : filmStyle = FilmStyles.all.contains(filmStyle) ? filmStyle : 'auto',
       projectType = projectType == 'reel' ? 'reel' : 'carousel',
       polaroidShadow = polaroidShadow.clamp(0, 100),
       polaroidDepth = polaroidDepth.clamp(0, 100),
       layoutSeed = layoutSeed ?? newLayoutSeed(),
       pageCounts = List.unmodifiable(pageCounts),
       pageLayouts = List.unmodifiable(pageLayouts),
       pageSeams = List.unmodifiable(pageSeams),
       pageLocks = List.unmodifiable(pageLocks),
       extra = Map.unmodifiable(extra);

  /// Seme nuovo come `random.randrange(1 << 30)` del desktop.
  static int newLayoutSeed([math.Random? rng]) =>
      (rng ?? math.Random()).nextInt(1 << 30);

  static const _noti = {
    'ratio_index',
    'custom_w',
    'custom_h',
    'frame_w',
    'frame_h',
    'num_frames',
    'bg_color',
    'gap',
    'margin',
    'per_frame',
    'per_page',
    'page_counts',
    'page_layouts',
    'page_seams',
    'page_locks',
    'layout_mode',
    'mosaic_style',
    'film_style',
    'polaroid_shadow',
    'polaroid_depth',
    'layout_seed',
    'bg_mode',
    'bg_color2',
    'bg_direction',
    'bg_blur_path',
    'bg_blur_rel',
    'bg_blur_amount',
    'bg_dim',
    'page_numbers',
    'page_number_format',
    'page_number_pos',
    'overlay_style',
    'swipe_hint',
    'swipe_text',
    'swipe_pos',
    'export_name',
    'project_type',
  };

  /// Letto con i predefiniti di `_restore_snapshot` e i limiti dei controlli del desktop.
  factory CanvasState.fromJson(Object? json) {
    final m = asMap(json);
    final seme = m['layout_seed'];
    return CanvasState(
      ratioIndex: readInt(
        m,
        'ratio_index',
        0,
      ).clamp(0, aspectRatios.length - 1),
      customW: readInt(m, 'custom_w', 1080).clamp(200, 6000),
      customH: readInt(m, 'custom_h', 1440).clamp(200, 6000),
      frameW: math.max(1, readInt(m, 'frame_w', 1080)),
      frameH: math.max(1, readInt(m, 'frame_h', 1440)),
      numFrames: readInt(m, 'num_frames', 1).clamp(1, pagineMassime),
      bgColor: parseArgb(m['bg_color'], 0xFFFFFFFF),
      gap: readInt(m, 'gap', 16).clamp(0, 80),
      margin: readInt(m, 'margin', 24).clamp(0, 120),
      perFrame: readBool(m, 'per_frame', true),
      perPage: readInt(m, 'per_page', 0).clamp(0, 20),
      pageCounts: [
        for (final v in asList(m['page_counts'])) v is num ? v.toInt() : null,
      ],
      pageLayouts: [
        for (final v in asList(m['page_layouts'])) PageLayout.fromJson(v),
      ],
      pageSeams: [
        for (final v in asList(m['page_seams'])) v == null ? null : truthy(v),
      ],
      pageLocks: [
        for (final v in asList(m['page_locks'])) v == null ? null : truthy(v),
      ],
      layoutMode: readString(m, 'layout_mode', LayoutModes.grid),
      mosaicStyle: readString(m, 'mosaic_style', 'auto'),
      filmStyle: readString(m, 'film_style', 'auto'),
      polaroidShadow: readInt(m, 'polaroid_shadow', 0),
      polaroidDepth: readInt(m, 'polaroid_depth', 0),
      layoutSeed: seme is num ? seme.toInt() : null,
      bgMode: readString(m, 'bg_mode', 'solid'),
      bgColor2: parseArgb(m['bg_color2'], 0xFF2680EB),
      bgDirection: readString(m, 'bg_direction', 'vertical'),
      bgBlurPath: readString(m, 'bg_blur_path', ''),
      bgBlurRel: readStringOrNull(m, 'bg_blur_rel'),
      bgBlurAmount: readInt(m, 'bg_blur_amount', 50),
      bgDim: readInt(m, 'bg_dim', 15),
      pageNumbers: readBool(m, 'page_numbers', false),
      pageNumberFormat: readString(m, 'page_number_format', 'slash'),
      pageNumberPos: readString(m, 'page_number_pos', 'bc'),
      overlayStyle: readString(m, 'overlay_style', 'dark'),
      swipeHint: readBool(m, 'swipe_hint', false),
      swipeText: readString(m, 'swipe_text', 'Scorri →'),
      swipePos: readString(m, 'swipe_pos', 'br'),
      exportName: readString(m, 'export_name', ''),
      projectType: readString(m, 'project_type', 'carousel'),
      extra: unknownFields(m, _noti),
    );
  }

  /// Stessi campi e stesso ordine di `_snapshot()["canvas"]`; `bg_blur_rel` solo nel file, se c'è.
  Map<String, Object?> toJson({bool withRel = true}) => <String, Object?>{
    'ratio_index': ratioIndex,
    'custom_w': customW,
    'custom_h': customH,
    'frame_w': frameW,
    'frame_h': frameH,
    'num_frames': numFrames,
    'bg_color': formatArgb(bgColor),
    'gap': gap,
    'margin': margin,
    'per_frame': perFrame,
    'per_page': perPage,
    'page_counts': List<int?>.of(pageCounts),
    'page_layouts': [for (final l in pageLayouts) l?.toJson()],
    'page_seams': List<bool?>.of(pageSeams),
    'page_locks': List<bool?>.of(pageLocks),
    'layout_mode': layoutMode,
    'mosaic_style': mosaicStyle,
    'film_style': filmStyle,
    'polaroid_shadow': polaroidShadow,
    'polaroid_depth': polaroidDepth,
    'layout_seed': layoutSeed,
    'bg_mode': bgMode,
    'bg_color2': formatArgb(bgColor2),
    'bg_direction': bgDirection,
    'bg_blur_path': bgBlurPath,
    'bg_blur_amount': bgBlurAmount,
    'bg_dim': bgDim,
    'page_numbers': pageNumbers,
    'page_number_format': pageNumberFormat,
    'page_number_pos': pageNumberPos,
    'overlay_style': overlayStyle,
    'swipe_hint': swipeHint,
    'swipe_text': swipeText,
    'swipe_pos': swipePos,
    'export_name': exportName,
    'project_type': projectType,
    if (withRel && bgBlurRel != null) 'bg_blur_rel': bgBlurRel,
    ...extra,
  };

  // ---------- Pagine (CollageScene) ----------
  /// La pagina k è unita «a cavallo» alla successiva.
  bool joined(int k) =>
      0 <= k &&
      k < numFrames - 1 &&
      k < pageSeams.length &&
      (pageSeams[k] ?? false);

  bool pageLocked(int k) =>
      0 <= k &&
      k < numFrames &&
      k < pageLocks.length &&
      (pageLocks[k] ?? false);

  bool get anyPageLocked =>
      [for (var k = 0; k < numFrames; k++) pageLocked(k)].any((v) => v);

  /// Pagine raggruppate (prima, ultima); una pagina non unita è un gruppo da sola.
  List<(int, int)> seamGroups() {
    final groups = <(int, int)>[];
    var start = 0;
    for (var k = 0; k < numFrames; k++) {
      if (!joined(k)) {
        groups.add((start, k));
        start = k + 1;
      }
    }
    return groups;
  }

  double get canvasWidth => (frameW * numFrames).toDouble();

  CanvasState copyWith({
    int? ratioIndex,
    int? customW,
    int? customH,
    int? frameW,
    int? frameH,
    int? numFrames,
    int? bgColor,
    int? gap,
    int? margin,
    bool? perFrame,
    int? perPage,
    List<int?>? pageCounts,
    List<PageLayout?>? pageLayouts,
    List<bool?>? pageSeams,
    List<bool?>? pageLocks,
    String? layoutMode,
    String? mosaicStyle,
    String? filmStyle,
    int? polaroidShadow,
    int? polaroidDepth,
    int? layoutSeed,
    String? bgMode,
    int? bgColor2,
    String? bgDirection,
    String? bgBlurPath,
    String? Function()? bgBlurRel,
    int? bgBlurAmount,
    int? bgDim,
    bool? pageNumbers,
    String? pageNumberFormat,
    String? pageNumberPos,
    String? overlayStyle,
    bool? swipeHint,
    String? swipeText,
    String? swipePos,
    String? exportName,
    String? projectType,
    Map<String, Object?>? extra,
  }) => CanvasState(
    ratioIndex: ratioIndex ?? this.ratioIndex,
    customW: customW ?? this.customW,
    customH: customH ?? this.customH,
    frameW: frameW ?? this.frameW,
    frameH: frameH ?? this.frameH,
    numFrames: numFrames ?? this.numFrames,
    bgColor: bgColor ?? this.bgColor,
    gap: gap ?? this.gap,
    margin: margin ?? this.margin,
    perFrame: perFrame ?? this.perFrame,
    perPage: perPage ?? this.perPage,
    pageCounts: pageCounts ?? this.pageCounts,
    pageLayouts: pageLayouts ?? this.pageLayouts,
    pageSeams: pageSeams ?? this.pageSeams,
    pageLocks: pageLocks ?? this.pageLocks,
    layoutMode: layoutMode ?? this.layoutMode,
    mosaicStyle: mosaicStyle ?? this.mosaicStyle,
    filmStyle: filmStyle ?? this.filmStyle,
    polaroidShadow: polaroidShadow ?? this.polaroidShadow,
    polaroidDepth: polaroidDepth ?? this.polaroidDepth,
    layoutSeed: layoutSeed ?? this.layoutSeed,
    bgMode: bgMode ?? this.bgMode,
    bgColor2: bgColor2 ?? this.bgColor2,
    bgDirection: bgDirection ?? this.bgDirection,
    bgBlurPath: bgBlurPath ?? this.bgBlurPath,
    bgBlurRel: bgBlurRel != null ? bgBlurRel() : this.bgBlurRel,
    bgBlurAmount: bgBlurAmount ?? this.bgBlurAmount,
    bgDim: bgDim ?? this.bgDim,
    pageNumbers: pageNumbers ?? this.pageNumbers,
    pageNumberFormat: pageNumberFormat ?? this.pageNumberFormat,
    pageNumberPos: pageNumberPos ?? this.pageNumberPos,
    overlayStyle: overlayStyle ?? this.overlayStyle,
    swipeHint: swipeHint ?? this.swipeHint,
    swipeText: swipeText ?? this.swipeText,
    swipePos: swipePos ?? this.swipePos,
    exportName: exportName ?? this.exportName,
    projectType: projectType ?? this.projectType,
    extra: extra ?? this.extra,
  );
}
