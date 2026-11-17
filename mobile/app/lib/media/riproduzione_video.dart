/// Riproduzione dei video sulla tela (piano §10, `VideoItem.play` del desktop): fotogrammi leggeri (lato lungo
/// 960 px) letti in sequenza dentro il riquadro, senza audio, a ripetizione tra `trim_start` e `trim_end`.
///
/// Quali video sono in riproduzione lo decide lo stato dell'editor; qui c'è solo chi legge i fotogrammi e li passa
/// alle [RisorsePagina], così il disegno resta quello di sempre (ritaglio, angoli, rotazione compresi).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:scrl_engine/scrl_engine.dart';
import 'package:scrl_video/scrl_video.dart';

import '../render/regolazioni.dart';
import '../render/risorse_pagina.dart';
import 'cache_media.dart';

/// Ciò che la riproduzione chiede a un lettore di fotogrammi (le prove lo sostituiscono).
abstract class LettoreVideo {
  /// L'ultimo fotogramma con tempo ≤ [t] secondi.
  Future<Fotogramma?> a(double t);
  Future<void> chiudi();
}

class _LettoreDiSistema implements LettoreVideo {
  _LettoreDiSistema(this._l);
  final LettoreFotogrammi _l;
  @override
  Future<Fotogramma?> a(double t) => _l.a(t);
  @override
  Future<void> chiudi() => _l.chiudi();
}

/// Apre un lettore di fotogrammi per la riproduzione.
typedef ApriLettore = Future<LettoreVideo> Function(String sorgente);

/// Il lettore del telefono (`scrl_video`), con fotogrammi leggeri.
Future<LettoreVideo> apriLettoreDiSistema(String sorgente) async =>
    _LettoreDiSistema(
      await LettoreFotogrammi.apri(
        sorgente,
        latoMassimo: RiproduzioneVideo.latoGioco,
      ),
    );

class _Giocatore {
  _Giocatore(this.video);

  PhotoItem video;
  LettoreVideo? lettore;
  final Stopwatch orologio = Stopwatch();
  bool occupato = false;
  bool fermo = false;
  double trimStart = 0;
  double? trimEnd;
}

class RiproduzioneVideo {
  RiproduzioneVideo({
    required this.risorse,
    required this.cache,
    required this.cartellaProgetto,
    this.apriLettore = apriLettoreDiSistema,
    this.onErrore,
  });

  final RisorsePagina risorse;
  final CacheMedia cache;
  final String cartellaProgetto;
  final ApriLettore apriLettore;

  /// Il video [uid] non si può riprodurre (file mancante o illeggibile): lo stato dell'editor lo toglie.
  final void Function(int uid)? onErrore;

  /// `PLAY_SIDE`: fotogrammi leggeri, bastano per guardare.
  static const int latoGioco = 960;

  /// Un fotogramma ogni 33 ms (`QTimer.setInterval(33)`).
  static const Duration passo = Duration(milliseconds: 33);

  final Map<int, _Giocatore> _attivi = {};
  Timer? _timer;
  bool _chiusa = false;

  /// Video in riproduzione adesso.
  Set<int> get attivi => _attivi.keys.toSet();

  /// Allinea la riproduzione allo stato: parte per i video in [uids] che ci sono in [s], si ferma per gli altri
  /// (eliminati, annullati, tolti dalla selezione). Un cambio di taglio fa ripartire da capo, come `set_trim`.
  void sincronizza(Snapshot s, Set<int> uids) {
    if (_chiusa) return;
    final video = {
      for (final p in s.items)
        if (p.isVideo && uids.contains(p.uid)) p.uid: p,
    };
    for (final uid in _attivi.keys.toList()) {
      if (!video.containsKey(uid)) _ferma(uid);
    }
    for (final p in video.values) {
      final g = _attivi[p.uid];
      if (g == null) {
        _avvia(p);
      } else {
        if (g.trimStart != p.trimStart || g.trimEnd != p.trimEnd) {
          g.trimStart = p.trimStart;
          g.trimEnd = p.trimEnd;
          g.orologio.reset();
          g.orologio.start();
        }
        g.video = p;
      }
    }
    if (_attivi.isEmpty) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(passo, (_) => _avanza());
    }
  }

  void _avvia(PhotoItem p) {
    final g = _Giocatore(p)
      ..trimStart = p.trimStart
      ..trimEnd = p.trimEnd;
    _attivi[p.uid] = g;
    risorse.segnaRiproduzione(p.uid);
    unawaited(_apri(g));
  }

  Future<void> _apri(_Giocatore g) async {
    final uid = g.video.uid;
    try {
      final src = await cache.sorgenteVideo(
        sorgenteDi(g.video, cartellaProgetto),
      );
      if (src == null) throw const ErroreVideo('mancante');
      final l = await apriLettore(src);
      if (g.fermo || _chiusa) {
        await l.chiudi();
        return;
      }
      g.lettore = l;
      await risorse.caricaInfoVideo(g.video);
      g.orologio.start();
      unawaited(_fotogramma(g));
    } on Exception catch (e) {
      debugPrint('Riproduzione del video $uid: $e');
      if (!g.fermo && !_chiusa) {
        _ferma(uid);
        onErrore?.call(uid);
      }
    }
  }

  void _avanza() {
    for (final g in _attivi.values) {
      if (!g.occupato && g.lettore != null) unawaited(_fotogramma(g));
    }
  }

  /// `_tick`: il fotogramma del momento; se il precedente non è ancora pronto si salta un giro.
  Future<void> _fotogramma(_Giocatore g) async {
    final l = g.lettore;
    if (l == null || g.occupato) return;
    g.occupato = true;
    try {
      final durata = risorse.durataVideo(g.video);
      final t = tempoInRiproduzione(
        g.video,
        durata,
        g.orologio.elapsedMicroseconds / 1e6,
      );
      final f = await l.a(t);
      if (f == null || g.fermo || _chiusa) return;
      final img = await immagineDaPixel(f.rgba, f.larghezza, f.altezza);
      if (g.fermo || _chiusa) {
        img.dispose();
        return;
      }
      risorse.impostaFotogramma(g.video.uid, img);
    } on Exception catch (e) {
      debugPrint('Fotogramma del video ${g.video.uid}: $e');
      if (!g.fermo && !_chiusa) {
        final uid = g.video.uid;
        _ferma(uid);
        onErrore?.call(uid);
      }
    } finally {
      g.occupato = false;
    }
  }

  void _ferma(int uid) {
    final g = _attivi.remove(uid);
    if (g == null) return;
    g.fermo = true;
    g.orologio.stop();
    final l = g.lettore;
    g.lettore = null;
    if (l != null) unawaited(_chiudi(l));
    risorse.togliFotogramma(uid);
  }

  static Future<void> _chiudi(LettoreVideo l) async {
    try {
      await l.chiudi();
    } on Exception {
      // Già chiuso
    }
  }

  /// Ferma tutto (editor chiuso, app in secondo piano).
  void chiudi() {
    for (final uid in _attivi.keys.toList()) {
      _ferma(uid);
    }
    _timer?.cancel();
    _timer = null;
    _chiusa = true;
  }
}
