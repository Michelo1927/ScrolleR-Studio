/// Operazioni sugli elementi della tela per l'editor di base (Fase 3): sposta, elimina, duplica, aggiungi foto
/// dalla libreria, svuota. Portate da `scrollr/window/library.py` e `scrollr/window/inspector.py`.
///
/// Sono funzioni su uno [Snapshot] immutabile: l'app le chiama a ogni gesto o comando e, a gesto finito,
/// produce un passo di cronologia (l'equivalente di `_schedule_commit`).
library;

import 'dart:math' as math;

import '../history/describe.dart' show ElementKind;
import '../layout/layout.dart';
import '../layout/layout_ops.dart';
import '../model/context.dart';
import '../model/elements.dart';
import '../model/result.dart';
import '../model/scene.dart';
import '../model/snapshot.dart';

/// Riferimento a un elemento: foto, testi e forme hanno contatori di `uid` separati.
typedef RifElemento = ({ElementKind tipo, int uid});

RifElemento rifDi(CanvasElement e) => (
  tipo: switch (e) {
    PhotoItem() => ElementKind.photo,
    TextItem() => ElementKind.text,
    ShapeItem() => ElementKind.shape,
  },
  uid: e.uid,
);

/// Elemento di [s] a cui punta [r], o null se non c'è più.
CanvasElement? elementoDi(Snapshot s, RifElemento r) {
  final l = switch (r.tipo) {
    ElementKind.photo => s.items,
    ElementKind.text => s.texts,
    ElementKind.shape => s.shapes,
  };
  for (final e in l) {
    if (e.uid == r.uid) return e;
  }
  return null;
}

/// L'elemento con quelli del suo gruppo (un gruppo si seleziona intero); da solo se non è in un gruppo.
List<RifElemento> conGruppo(Snapshot s, CanvasElement e) {
  if (e.group == 0) return [rifDi(e)];
  return [
    for (final x in s.allElements)
      if (x.group == e.group) rifDi(x),
  ];
}

/// Elementi di [s] che stanno in [refs] (quelli spariti si saltano).
List<CanvasElement> elementiDi(Snapshot s, Iterable<RifElemento> refs) => [
  for (final r in refs) ?elementoDi(s, r),
];

/// Sposta gli elementi di ([dx], [dy]) sulla striscia; quelli con «Blocca posizione» restano dove sono.
Snapshot spostaElementi(
  Snapshot s,
  Iterable<RifElemento> refs,
  double dx,
  double dy,
) {
  final set = refs.toSet();
  T muovi<T extends CanvasElement>(T e, RifElemento r) =>
      set.contains(r) && !e.locked
      ? e.withPosition(e.x + dx, e.y + dy) as T
      : e;
  return s.copyWith(
    items: [for (final e in s.items) muovi(e, rifDi(e))],
    texts: [for (final e in s.texts) muovi(e, rifDi(e))],
    shapes: [for (final e in s.shapes) muovi(e, rifDi(e))],
  );
}

/// `_delete_selected`: toglie gli elementi dalla tela (senza ridisporre le altre foto, come il desktop).
Snapshot eliminaElementi(Snapshot s, Iterable<RifElemento> refs) {
  final set = refs.toSet();
  return Snapshot(
    canvas: s.canvas,
    items: [
      for (final e in s.items)
        if (!set.contains(rifDi(e))) e,
    ],
    texts: [
      for (final e in s.texts)
        if (!set.contains(rifDi(e))) e,
    ],
    shapes: [
      for (final e in s.shapes)
        if (!set.contains(rifDi(e))) e,
    ],
  );
}

/// `_duplicate_selected`: copie spostate di 30 unità, davanti a tutto; la copia di un gruppo è un gruppo nuovo.
/// Restituisce lo stato nuovo e i riferimenti delle copie (che diventano la selezione).
({Snapshot snapshot, List<RifElemento> copie}) duplicaElementi(
  Snapshot s,
  Iterable<RifElemento> refs,
  EngineContext ctx,
) {
  final sc = Scene(s, ctx);
  final primoGruppo = sc.newGroupId();
  final gruppi = <int, int>{};
  final copie = <RifElemento>[];
  for (final e in elementiDi(s, refs)) {
    final gruppo = e.group == 0
        ? 0
        : gruppi.putIfAbsent(e.group, () => primoGruppo + gruppi.length);
    final z = sc.maxZ() + 1.0;
    switch (e) {
      case PhotoItem():
        final li = sc.photos.values.fold<int>(
          0,
          (m, p) => math.max(m, p.layoutIndex),
        );
        final d = e.copyWith(
          uid: ctx.newPhotoUid(),
          x: e.x + 30,
          y: e.y + 30,
          z: z,
          layoutIndex: li + 1,
          locked: false,
          group: gruppo,
        );
        sc.put(d);
        copie.add(rifDi(d));
      case TextItem():
        final d = e.copyWith(
          uid: ctx.newTextUid(),
          x: e.x + 30,
          y: e.y + 30,
          z: z,
          locked: false,
          group: gruppo,
        );
        sc.put(d);
        copie.add(rifDi(d));
      case ShapeItem():
        final d = e.copyWith(
          uid: ctx.newShapeUid(),
          x: e.x + 30,
          y: e.y + 30,
          z: z,
          locked: false,
          group: gruppo,
        );
        sc.put(d);
        copie.add(rifDi(d));
    }
  }
  return (snapshot: sc.toSnapshot(), copie: copie);
}

/// `clear_canvas_photos`: svuota la tela; le pagine bloccate restano come sono.
Snapshot svuotaTela(Snapshot s) => Snapshot(
  canvas: s.canvas,
  items: [
    for (final e in s.items)
      if (e.pageLocked) e,
  ],
  texts: [
    for (final e in s.texts)
      if (e.pageLocked) e,
  ],
  shapes: [
    for (final e in s.shapes)
      if (e.pageLocked) e,
  ],
);

/// Una foto o un video da mettere sulla tela, preso dalla libreria.
typedef NuovaFoto = ({String path, String? rel, MediaAsset? asset, bool video});

/// Esito di un'aggiunta: lo stato, gli avvisi e gli `uid` delle foto nate.
class AggiuntaFoto {
  final EngineResult risultato;
  final List<int> uids;
  const AggiuntaFoto(this.risultato, this.uids);
}

/// `_put_paths_on_canvas`: sostituisce le foto sulla tela con queste e le dispone con la disposizione attuale
/// (le pagine bloccate restano). Anche per le foto scelte alla creazione del progetto.
AggiuntaFoto mettiFotoSullaTela(
  Snapshot s,
  List<NuovaFoto> foto,
  EngineContext ctx,
) {
  final sc = Scene(s, ctx);
  if (foto.isEmpty) return AggiuntaFoto(EngineResult(s), const []);
  for (final p in sc.canvasPhotos()) {
    if (!p.pageLocked) sc.remove(p);
  }
  final uids = [
    for (final f in foto)
      sc.spawnPhoto(f.path, rel: f.rel, asset: f.asset, isVideo: f.video).uid,
  ];
  relayoutKeep(sc);
  return AggiuntaFoto(EngineResult.done(sc), uids);
}

/// `_place_dropped` / `_add_library_paths_to_canvas`: aggiunge foto tenendo le altre. [pagina] è la pagina dove
/// entrano (in fondo a quella pagina, se le foto si dividono per pagina); [libere] le mette fuori dalla
/// disposizione, grandi il 40% della pagina e al centro.
AggiuntaFoto aggiungiFoto(
  Snapshot s,
  List<NuovaFoto> foto,
  EngineContext ctx, {
  required int pagina,
  bool libere = false,
}) {
  final sc = Scene(s, ctx);
  if (foto.isEmpty) return AggiuntaFoto(EngineResult(s), const []);
  final k = pagina.clamp(0, sc.numFrames - 1);
  if (sc.pageLocked(k)) {
    sc.notice(NoticeKind.pageLocked, [k + 1]);
    return AggiuntaFoto(EngineResult.refused(s, sc), const []);
  }
  final uids = <int>[];
  if (libere) {
    final fw = sc.frameW.toDouble(), fh = sc.frameH.toDouble();
    final lato = math.min(fw, fh) * 0.4;
    for (var i = 0; i < foto.length; i++) {
      final f = foto[i];
      var p = sc.spawnPhoto(
        f.path,
        rel: f.rel,
        asset: f.asset,
        isVideo: f.video,
      );
      final r = sc.sourceRatio(p);
      final w = lato * math.min(1.0, r), h = lato * math.min(1.0, 1.0 / r);
      p = p.copyWith(
        free: true,
        w: w,
        h: h,
        x: k * fw + fw / 2.0 - w / 2.0 + i * 30,
        y: fh / 2.0 - h / 2.0 + i * 30,
      );
      sc.put(p);
      uids.add(p.uid);
    }
    return AggiuntaFoto(EngineResult.done(sc), uids);
  }
  final correnti = pagesSplit(sc) ? photoPages(sc) : null;
  for (final f in foto) {
    uids.add(
      sc.spawnPhoto(f.path, rel: f.rel, asset: f.asset, isVideo: f.video).uid,
    );
  }
  if (correnti != null) {
    insertIntoPageIn(sc, uids, k, correnti);
  } else {
    relayoutKeep(sc);
  }
  return AggiuntaFoto(EngineResult.done(sc), uids);
}
