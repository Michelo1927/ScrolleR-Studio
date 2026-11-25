/// Strumenti comuni alle prove sui dati prodotti da `mobile/tools/genera_riferimenti.py`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:scrl_engine/scrl_engine.dart';

/// Righe di un file `.jsonl` della cartella dei riferimenti.
List<Map<String, Object?>> leggiJsonl(String nome) => [
  for (final r in File('test/riferimenti/$nome').readAsLinesSync())
    if (r.isNotEmpty) jsonDecode(r) as Map<String, Object?>,
];

/// Stato del desktop con le misure di immagini e testi (campi `image` e `text_size`, solo delle prove).
class StatoDesktop {
  final Snapshot snapshot;
  final Map<String, ({int w, int h})> immagini;
  final Map<String, ({double w, double h})> testi;

  /// Misure dei blocchi di sottotitoli per `uid` (campo `caption_size`).
  final Map<int, ({double w, double h})> sottotitoli;
  StatoDesktop(
    this.snapshot,
    this.immagini,
    this.testi, [
    this.sottotitoli = const {},
  ]);

  factory StatoDesktop.fromJson(Map<String, Object?> json) {
    final copia = jsonCopy(json)! as Map<String, Object?>;
    final immagini = <String, ({int w, int h})>{};
    final testi = <String, ({double w, double h})>{};
    for (final it in (copia['items']! as List).cast<Map<String, Object?>>()) {
      final m = it.remove('image') as List?;
      if (m != null) {
        immagini[it['path']! as String] = (w: m[0] as int, h: m[1] as int);
      }
    }
    for (final t
        in (copia['texts'] as List? ?? const []).cast<Map<String, Object?>>()) {
      final m = t.remove('text_size') as List?;
      if (m != null) {
        testi[t['text']! as String] = (
          w: (m[0] as num).toDouble(),
          h: (m[1] as num).toDouble(),
        );
      }
    }
    final sottotitoli = <int, ({double w, double h})>{};
    for (final c
        in (copia['captions'] as List? ?? const [])
            .cast<Map<String, Object?>>()) {
      final m = c.remove('caption_size') as List?;
      if (m != null) {
        sottotitoli[c['uid']! as int] = (
          w: (m[0] as num).toDouble(),
          h: (m[1] as num).toDouble(),
        );
      }
    }
    return StatoDesktop(Snapshot.fromJson(copia), immagini, testi, sottotitoli);
  }

  /// Contesto con le stesse misure del desktop (le copie di una foto hanno lo stesso file).
  EngineContext contesto() => EngineContext(
    imageSize: (p) => immagini[p.path],
    textSize: (t) => testi[t.text] ?? EngineContext.estimateTextSize(t),
    captionSize: (c) =>
        sottotitoli[c.uid] ?? EngineContext.estimateCaptionSize(c),
  );
}

/// Differenze tra lo stato del motore e quello del desktop (vuota = uguali), con tolleranza 0,001.
/// Gli uid degli elementi nuovi si abbinano in ordine: il desktop li prende da un contatore globale.
List<String> confrontaStati(
  Snapshot motore,
  Map<String, Object?> desktop,
  Snapshot prima,
) {
  final errori = <String>[];
  final mio = motore.toJson();
  _confronta(desktop['canvas'], mio['canvas'], 'canvas', errori);
  final primaJson = prima.toJson();
  // uid dei video nuovi del desktop → uid nel motore (i sottotitoli copiati puntano alla copia del video)
  var fotoNuove = <Object?, int>{};
  for (final chiave in ['items', 'texts', 'shapes', 'captions']) {
    final vecchi = {
      for (final s
          in (primaJson[chiave] as List? ?? const [])
              .cast<Map<String, Object?>>())
        s['uid'],
    };
    final atteso = (desktop[chiave] as List? ?? const [])
        .cast<Map<String, Object?>>();
    final trovato = (mio[chiave] as List? ?? const [])
        .cast<Map<String, Object?>>();
    final nuoviA = [
      for (final s in atteso)
        if (!vecchi.contains(s['uid'])) s['uid']! as int,
    ]..sort();
    final nuoviT = [
      for (final s in trovato)
        if (!vecchi.contains(s['uid'])) s['uid']! as int,
    ]..sort();
    if (nuoviA.length != nuoviT.length || atteso.length != trovato.length) {
      errori.add('$chiave: ${atteso.length} attesi, ${trovato.length} trovati');
      continue;
    }
    final abbina = {
      for (var i = 0; i < nuoviA.length; i++) nuoviA[i]: nuoviT[i],
    };
    if (chiave == 'items') fotoNuove = abbina;
    final perUid = {for (final s in trovato) s['uid']: s};
    for (final s in atteso) {
      final uid = abbina[s['uid']] ?? s['uid'];
      final t = perUid[uid];
      if (t == null) {
        errori.add('$chiave: manca uid $uid');
        continue;
      }
      final confrontabile = Map<String, Object?>.of(s)
        ..remove('uid')
        ..remove('image')
        ..remove('text_size')
        ..remove('caption_size')
        ..remove('rel');
      if (chiave == 'captions' && fotoNuove.containsKey(s['video_uid'])) {
        confrontabile['video_uid'] = fotoNuove[s['video_uid']];
      }
      _confronta(confrontabile, t, '$chiave[$uid]', errori);
    }
  }
  return errori;
}

void _confronta(
  Object? atteso,
  Object? trovato,
  String dove,
  List<String> errori,
) {
  if (atteso is Map && trovato is Map) {
    for (final k in atteso.keys) {
      _confronta(atteso[k], trovato[k], '$dove.$k', errori);
    }
  } else if (atteso is List &&
      trovato is List &&
      atteso.length == trovato.length) {
    for (var i = 0; i < atteso.length; i++) {
      _confronta(atteso[i], trovato[i], '$dove[$i]', errori);
    }
  } else if (atteso is num && trovato is num) {
    if ((atteso - trovato).abs() > 0.001) {
      errori.add('$dove: $atteso ≠ $trovato');
    }
  } else if (!jsonEquals(atteso, trovato)) {
    errori.add('$dove: $atteso ≠ $trovato');
  }
}
