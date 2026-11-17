/// Comandi sulla selezione multipla (Fase 6): raggruppa e separa, allinea e distribuisci, «Blocca posizione», livelli
/// (davanti/dietro) e appunti interni (copia, taglia, incolla anche tra progetti).
///
/// Portati da `scrollr/window/inspector.py` (`_group_selected`, `_ungroup_selected`, `_align_selected`,
/// `_distribute_selected`, `_toggle_lock_selected`, `_bring_to_front`, `_send_to_back`, `_copy_selected`,
/// `_paste_elements`). Sono funzioni su uno [Snapshot] immutabile; i messaggi per l'utente li compone l'app.
library;

import 'dart:math' as math;

import '../history/describe.dart' show ElementKind;
import '../model/context.dart';
import '../model/elements.dart';
import '../model/result.dart';
import '../model/scene.dart';
import '../model/snapshot.dart';
import 'elementi.dart';

/// I sei allineamenti di `_align_selected`.
enum Allineamento {
  sinistra,
  centroOrizzontale,
  destra,
  alto,
  centroVerticale,
  basso,
}

/// Elementi di [s] a cui puntano [refs], nell'ordine in cui compaiono nel documento (foto, testi, forme).
List<CanvasElement> _selezionati(Snapshot s, Iterable<RifElemento> refs) {
  final set = refs.toSet();
  return [
    for (final e in s.allElements)
      if (set.contains(rifDi(e))) e,
  ];
}

/// Sostituisce nel documento gli elementi che hanno una nuova versione in [nuovi] (stesso tipo e `uid`).
Snapshot _con(Snapshot s, Iterable<CanvasElement> nuovi) {
  final per = {for (final e in nuovi) rifDi(e): e};
  T sostituisci<T extends CanvasElement>(T e) => (per[rifDi(e)] ?? e) as T;
  return s.copyWith(
    items: [for (final e in s.items) sostituisci(e)],
    texts: [for (final e in s.texts) sostituisci(e)],
    shapes: [for (final e in s.shapes) sostituisci(e)],
  );
}

CanvasElement _conBlocco(CanvasElement e, bool locked) => switch (e) {
  PhotoItem() => e.copyWith(locked: locked),
  TextItem() => e.copyWith(locked: locked),
  ShapeItem() => e.copyWith(locked: locked),
};

// ---------------------------------------------------------------- Gruppi

/// `_group_selected`: gli elementi diventano un gruppo nuovo (si selezionano e si spostano insieme).
/// Null se sono meno di 2.
Snapshot? raggruppa(Snapshot s, Iterable<RifElemento> refs) {
  final sel = _selezionati(s, refs);
  if (sel.length < 2) return null;
  final gid = s.allElements.fold<int>(0, (m, e) => math.max(m, e.group)) + 1;
  return _con(s, [for (final e in sel) e.withGroup(gid)]);
}

/// `_ungroup_selected`: toglie dal gruppo gli elementi selezionati. Null se nessuno era in un gruppo.
Snapshot? separa(Snapshot s, Iterable<RifElemento> refs) {
  final inGruppo = [
    for (final e in _selezionati(s, refs))
      if (e.group != 0) e,
  ];
  if (inGruppo.isEmpty) return null;
  return _con(s, [for (final e in inGruppo) e.withGroup(0)]);
}

/// `_selection_is_one_group`: tutti gli elementi scelti stanno nello stesso gruppo.
bool selezioneEUnGruppo(Snapshot s, Iterable<RifElemento> refs) {
  final gruppi = {for (final e in _selezionati(s, refs)) e.group};
  return gruppi.length == 1 && !gruppi.contains(0);
}

/// Almeno un elemento scelto sta in un gruppo (c'è qualcosa da separare).
bool selezioneHaGruppi(Snapshot s, Iterable<RifElemento> refs) =>
    _selezionati(s, refs).any((e) => e.group != 0);

// ---------------------------------------------------------------- Allinea e distribuisci

/// Pagina (come riquadro) che contiene il punto orizzontale [x] (`_page_rect_at`).
Rect _paginaIn(Scene sc, double x) {
  final k = (x / sc.frameW).floor().clamp(0, sc.numFrames - 1);
  return Rect(
    k * sc.frameW.toDouble(),
    0,
    sc.frameW.toDouble(),
    sc.frameH.toDouble(),
  );
}

Rect _unione(Rect a, Rect b) {
  final l = math.min(a.left, b.left), t = math.min(a.top, b.top);
  final r = math.max(a.right, b.right), bo = math.max(a.bottom, b.bottom);
  return Rect(l, t, r - l, bo - t);
}

/// `_align_selected`: con un solo elemento si allinea alla sua pagina, con più elementi al loro ingombro comune.
/// Gli elementi con «Blocca posizione» restano dove sono.
Snapshot allinea(
  Snapshot s,
  Iterable<RifElemento> refs,
  Allineamento come,
  EngineContext ctx,
) {
  final sel = _selezionati(s, refs);
  if (sel.isEmpty) return s;
  final sc = Scene(s, ctx);
  var rif = sc.elementRect(sel.first);
  if (sel.length == 1) {
    rif = _paginaIn(sc, rif.centerX);
  } else {
    for (final e in sel.skip(1)) {
      rif = _unione(rif, sc.elementRect(e));
    }
  }
  for (final e in sel) {
    if (e.locked) continue;
    final r = sc.elementRect(e);
    var dx = 0.0, dy = 0.0;
    switch (come) {
      case Allineamento.sinistra:
        dx = rif.left - r.left;
      case Allineamento.centroOrizzontale:
        dx = rif.centerX - r.centerX;
      case Allineamento.destra:
        dx = rif.right - r.right;
      case Allineamento.alto:
        dy = rif.top - r.top;
      case Allineamento.centroVerticale:
        dy = rif.centerY - r.centerY;
      case Allineamento.basso:
        dy = rif.bottom - r.bottom;
    }
    sc.put(e.withPosition(e.x + dx, e.y + dy));
  }
  return sc.toSnapshot();
}

/// `_distribute_selected`: spazi uguali tra gli elementi, in orizzontale o in verticale. Servono almeno 3 elementi
/// (altrimenti null). Il primo e l'ultimo restano dove sono; i bloccati non si muovono ma occupano il loro posto.
Snapshot? distribuisci(
  Snapshot s,
  Iterable<RifElemento> refs, {
  required bool orizzontale,
  required EngineContext ctx,
}) {
  final sel = _selezionati(s, refs);
  if (sel.length < 3) return null;
  final sc = Scene(s, ctx);
  final rect = {for (final e in sel) rifDi(e): sc.elementRect(e)};
  double chiave(CanvasElement e) =>
      orizzontale ? rect[rifDi(e)]!.left : rect[rifDi(e)]!.top;
  // Ordinamento stabile (a parità vale l'ordine di partenza), come `sorted` di Python
  final indicati = [for (var i = 0; i < sel.length; i++) (i, sel[i])]
    ..sort((a, b) {
      final c = chiave(a.$2).compareTo(chiave(b.$2));
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
  final ordinati = [for (final x in indicati) x.$2];
  final primo = rect[rifDi(ordinati.first)]!,
      ultimo = rect[rifDi(ordinati.last)]!;
  final campata = orizzontale
      ? ultimo.right - primo.left
      : ultimo.bottom - primo.top;
  final misure = ordinati.fold<double>(
    0,
    (somma, e) => somma + (orizzontale ? rect[rifDi(e)]!.w : rect[rifDi(e)]!.h),
  );
  final spazio = (campata - misure) / (ordinati.length - 1);
  var cursore = orizzontale ? primo.left : primo.top;
  for (final e in ordinati) {
    final r = rect[rifDi(e)]!;
    if (!e.locked) {
      sc.put(
        orizzontale
            ? e.withPosition(e.x + cursore - r.left, e.y)
            : e.withPosition(e.x, e.y + cursore - r.top),
      );
    }
    cursore += (orizzontale ? r.w : r.h) + spazio;
  }
  return sc.toSnapshot();
}

// ---------------------------------------------------------------- Blocco e livelli

/// `_toggle_lock_selected`: se non sono tutti bloccati si bloccano tutti, altrimenti si sbloccano.
/// Restituisce lo stato nuovo e se ora sono bloccati; null se la selezione è vuota.
({Snapshot snapshot, bool bloccati})? alternaBloccoPosizione(
  Snapshot s,
  Iterable<RifElemento> refs,
) {
  final sel = _selezionati(s, refs);
  if (sel.isEmpty) return null;
  final bloccati = !sel.every((e) => e.locked);
  return (
    snapshot: _con(s, [for (final e in sel) _conBlocco(e, bloccati)]),
    bloccati: bloccati,
  );
}

/// `_bring_to_front`: gli elementi scelti passano davanti a tutto, mantenendo il loro ordine.
Snapshot portaDavanti(Snapshot s, Iterable<RifElemento> refs) {
  final sel = _selezionati(s, refs)..sort((a, b) => a.z.compareTo(b.z));
  if (sel.isEmpty) return s;
  final maxZ = s.allElements.fold<double>(
    sel.first.z,
    (m, e) => math.max(m, e.z),
  );
  return _con(s, [
    for (var i = 0; i < sel.length; i++) sel[i].withZ(maxZ + 1.0 + i),
  ]);
}

/// `_send_to_back`: gli elementi scelti passano dietro a tutto, mantenendo il loro ordine.
Snapshot mandaDietro(Snapshot s, Iterable<RifElemento> refs) {
  final sel = _selezionati(s, refs)..sort((a, b) => b.z.compareTo(a.z));
  if (sel.isEmpty) return s;
  final minZ = s.allElements.fold<double>(
    sel.first.z,
    (m, e) => math.min(m, e.z),
  );
  return _con(s, [
    for (var i = 0; i < sel.length; i++) sel[i].withZ(minZ - 1.0 - i),
  ]);
}

// ---------------------------------------------------------------- Appunti

/// Elementi copiati: stesso formato dei dati negli appunti del desktop (`ELEMENTS_MIME`), con la pagina da cui
/// vengono e, per ogni elemento, tipo e stato (`get_state`). Valgono anche per un altro progetto.
class AppuntiElementi {
  const AppuntiElementi({required this.pagina, required this.voci});

  /// Pagina da cui sono stati copiati (gli incolli in un'altra pagina conservano la posizione nella pagina).
  final int pagina;
  final List<({ElementKind tipo, Map<String, Object?> stato})> voci;

  int get numero => voci.length;

  Map<String, Object?> toJson() => {
    'page': pagina,
    'elements': [
      for (final v in voci)
        {
          'type': switch (v.tipo) {
            ElementKind.photo => 'photo',
            ElementKind.text => 'text',
            ElementKind.shape => 'shape',
          },
          'state': v.stato,
        },
    ],
  };

  /// Null se i dati non sono validi o non contengono elementi.
  static AppuntiElementi? fromJson(Object? json) {
    if (json is! Map) return null;
    final el = json['elements'];
    if (el is! List || el.isEmpty) return null;
    final voci = <({ElementKind tipo, Map<String, Object?> stato})>[];
    for (final e in el) {
      if (e is! Map || e['state'] is! Map) return null;
      final tipo = switch (e['type']) {
        'text' => ElementKind.text,
        'shape' => ElementKind.shape,
        _ => ElementKind.photo,
      };
      voci.add((
        tipo: tipo,
        stato: Map<String, Object?>.from(e['state'] as Map),
      ));
    }
    final p = json['page'];
    return AppuntiElementi(pagina: p is num ? p.toInt() : 0, voci: voci);
  }
}

/// `_copy_selected`: copia foto, testi e forme (in ordine di livello). Null se la selezione è vuota.
AppuntiElementi? copiaElementi(
  Snapshot s,
  Iterable<RifElemento> refs,
  EngineContext ctx,
) {
  final sel = _selezionati(s, refs);
  if (sel.isEmpty) return null;
  final sc = Scene(s, ctx);
  var r = sc.elementRect(sel.first);
  for (final e in sel.skip(1)) {
    r = _unione(r, sc.elementRect(e));
  }
  final pagina = (_paginaIn(sc, r.centerX).left / sc.frameW).round();
  final ordinati = [for (var i = 0; i < sel.length; i++) (i, sel[i])]
    ..sort((a, b) {
      final c = a.$2.z.compareTo(b.$2.z);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
  return AppuntiElementi(
    pagina: pagina,
    voci: [
      for (final (_, e) in ordinati)
        (
          tipo: rifDi(e).tipo,
          // Copia profonda: gli stati degli appunti non cambiano se poi cambia il documento
          stato: Map<String, Object?>.from(e.toJson()),
        ),
    ],
  );
}

/// Esito di [incollaElementi]: il documento, gli avvisi e i riferimenti degli elementi nati (che restano selezionati).
typedef Incollati = ({EngineResult risultato, List<RifElemento> incollati});

/// `_paste_elements`: incolla nella pagina [pagina], nella stessa posizione che gli elementi avevano nella loro
/// pagina. Nella stessa pagina si spostano di 30 unità per [ripetizione] (1 al primo incolla, 2 al secondo…), così la
/// copia non copre l'originale; con [ripetizione] 0 tornano esattamente dov'erano (dopo «Taglia»). Le foto incollate
/// sono foto libere: restano dove sono. Una pagina bloccata rifiuta l'incolla.
Incollati incollaElementi(
  Snapshot s,
  AppuntiElementi appunti,
  int pagina,
  int ripetizione,
  EngineContext ctx,
) {
  final sc = Scene(s, ctx);
  final k = pagina.clamp(0, sc.numFrames - 1);
  if (sc.pageLocked(k)) {
    sc.notice(NoticeKind.pageLocked, [k + 1]);
    return (risultato: EngineResult.refused(s, sc), incollati: const []);
  }
  final fw = sc.frameW.toDouble();
  var dx = (k - appunti.pagina) * fw;
  var dy = 0.0;
  if (k == appunti.pagina) {
    dx = dy = 30.0 * ripetizione;
  }
  final primoGruppo = sc.newGroupId();
  final gruppi =
      <int, int>{}; // Gruppi copiati → gruppi nuovi, separati dagli originali
  final nuovi = <RifElemento>[];
  for (final v in appunti.voci) {
    final stato = v.stato;
    final gOrig = stato['group'];
    final gruppoOrig = gOrig is num ? gOrig.toInt() : 0;
    final gruppo = gruppoOrig != 0
        ? gruppi.putIfAbsent(gruppoOrig, () => primoGruppo + gruppi.length)
        : 0;
    switch (v.tipo) {
      case ElementKind.text:
        final dup = TextItem(uid: ctx.newTextUid());
        sc.put(dup);
        final t = TextItem.fromJson(stato);
        final nuovo = t.copyWith(
          uid: dup.uid,
          z: sc.maxZ() + 1.0,
          x: t.x + dx,
          y: t.y + dy,
          locked: false,
          pageLocked: false,
          group: gruppo,
        );
        sc.put(nuovo);
        nuovi.add(rifDi(nuovo));
      case ElementKind.shape:
        final f = ShapeItem.fromJson(stato);
        final dup = ShapeItem(uid: ctx.newShapeUid(), kind: f.kind);
        sc.put(dup);
        final nuovo = f.copyWith(
          uid: dup.uid,
          z: sc.maxZ() + 1.0,
          x: f.x + dx,
          y: f.y + dy,
          locked: false,
          pageLocked: false,
          group: gruppo,
        );
        sc.put(nuovo);
        nuovi.add(rifDi(nuovo));
      case ElementKind.photo:
        final p = PhotoItem.fromJson(stato);
        final dup = sc.spawnPhoto(
          p.path,
          rel: p.rel,
          asset: p.asset,
          isVideo: p.isVideo,
        );
        final nuovo = p.copyWith(
          uid: dup.uid,
          layoutIndex: dup.layoutIndex,
          free: true,
          z: sc.maxZ() + 1.0,
          x: p.x + dx,
          y: p.y + dy,
          locked: false,
          pageLocked: false,
          group: gruppo,
        );
        sc.put(nuovo);
        nuovi.add(rifDi(nuovo));
    }
  }
  return (risultato: EngineResult.done(sc), incollati: nuovi);
}
