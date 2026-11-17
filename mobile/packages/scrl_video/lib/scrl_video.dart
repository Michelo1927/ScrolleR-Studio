/// Video con i codificatori del telefono (piano §10): informazioni sul file, fotogrammi in sequenza,
/// audio in PCM e scrittura dell'MP4 (H.264 + AAC). Su Android usa MediaExtractor, MediaCodec e MediaMuxer;
/// su iOS (AVFoundation) arriverà con la Fase 9: fino ad allora ogni chiamata dà [VideoNonDisponibile].
///
/// I file si indicano con una «sorgente»: un percorso o un URI `content://` / `file://`.
library;

import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Regole dei video, uguali al desktop (`scrollr/video.py`).
abstract final class RegoleVideo {
  static const int fps = 30;
  static const double secondiMassimi = 60.0;
  static const int latoMassimo = 1920;
  static const int frequenzaAudio = 44100;

  /// Byte per campione audio: s16 stereo.
  static const int bytePerCampione = 4;

  /// `output_size`: misure dell'MP4 per una pagina w × h (lato lungo ≤ 1920, misure pari per H.264).
  static ({int w, int h}) misuraUscita(double w, double h) {
    final k = (latoMassimo / (w > h ? w : h)).clamp(0.0, 1.0);
    int pari(double v) => (v * k).floor() ~/ 2 * 2;
    final ow = pari(w), oh = pari(h);
    return (w: ow < 2 ? 2 : ow, h: oh < 2 ? 2 : oh);
  }
}

/// Il telefono non sa fare questa operazione (piattaforma non ancora supportata).
class VideoNonDisponibile implements Exception {
  const VideoNonDisponibile();
  @override
  String toString() => 'VideoNonDisponibile';
}

/// Errore della parte nativa (file illeggibile, codificatore assente…), con il messaggio di sistema.
class ErroreVideo implements Exception {
  final String codice;
  final String? messaggio;
  const ErroreVideo(this.codice, [this.messaggio]);
  @override
  String toString() => 'ErroreVideo($codice: $messaggio)';
}

/// Informazioni su un video: misure come appare (rotazione già applicata), durata e audio.
class InfoVideo {
  final int larghezza;
  final int altezza;
  final double durata;
  final double fps;
  final bool audio;
  const InfoVideo({
    required this.larghezza,
    required this.altezza,
    required this.durata,
    required this.fps,
    required this.audio,
  });
}

/// Un fotogramma RGBA (non premoltiplicato) di [larghezza] × [altezza] pixel.
class Fotogramma {
  final int larghezza;
  final int altezza;
  final Uint8List rgba;
  const Fotogramma(this.larghezza, this.altezza, this.rgba);
}

const MethodChannel _canale = MethodChannel('scrl_video');

Future<T?> _chiama<T>(String metodo, Map<String, Object?> argomenti) async {
  try {
    return await _canale.invokeMethod<T>(metodo, argomenti);
  } on MissingPluginException {
    throw const VideoNonDisponibile();
  } on PlatformException catch (e) {
    throw ErroreVideo(e.code, e.message);
  }
}

abstract final class ScrlVideo {
  /// Il telefono supporta i video (vero su Android; su iOS dalla Fase 9).
  static Future<bool> disponibile() async {
    try {
      return await _chiama<bool>('disponibile', const {}) ?? false;
    } on VideoNonDisponibile {
      return false;
    }
  }

  static Future<InfoVideo> info(String sorgente) async {
    final m = (await _chiama<Map<Object?, Object?>>('info', {
      'sorgente': sorgente,
    }))!;
    return InfoVideo(
      larghezza: m['larghezza']! as int,
      altezza: m['altezza']! as int,
      durata: (m['durata']! as num).toDouble(),
      fps: (m['fps']! as num).toDouble(),
      audio: m['audio']! as bool,
    );
  }

  /// Un fotogramma al secondo [t] (copertina, anteprima), con il lato lungo al massimo [latoMassimo].
  static Future<Fotogramma> fotogramma(
    String sorgente,
    double t, {
    int latoMassimo = 1600,
  }) async {
    final lettore = await LettoreFotogrammi.apri(
      sorgente,
      latoMassimo: latoMassimo,
    );
    try {
      final f = await lettore.a(t);
      if (f == null) throw const ErroreVideo('vuoto', 'Nessun fotogramma');
      return f;
    } finally {
      await lettore.chiudi();
    }
  }

  /// Audio da [inizio] a [fine] secondi in PCM s16 stereo a 44,1 kHz (`read_audio`), completato col silenzio
  /// se più corto; null se il video non ha audio.
  static Future<Uint8List?> leggiAudio(
    String sorgente,
    double inizio,
    double fine,
  ) => _chiama<Uint8List>('leggiAudio', {
    'sorgente': sorgente,
    'inizio': inizio,
    'fine': fine,
  });
}

/// Lettura in sequenza (`FrameReader` del desktop): [a] va avanti decodificando e torna indietro (o salta
/// lontano) con una ricerca. Restituisce l'ultimo fotogramma con tempo ≤ t.
class LettoreFotogrammi {
  final int _id;
  final int larghezza;
  final int altezza;
  LettoreFotogrammi._(this._id, this.larghezza, this.altezza);

  /// Con [misura] i fotogrammi escono esattamente a quella misura (come appaiono, rotazione inclusa);
  /// altrimenti col lato lungo al massimo [latoMassimo] (null = misura vera).
  static Future<LettoreFotogrammi> apri(
    String sorgente, {
    ({int w, int h})? misura,
    int? latoMassimo,
  }) async {
    final m = (await _chiama<Map<Object?, Object?>>('apriLettore', {
      'sorgente': sorgente,
      'larghezza': misura?.w,
      'altezza': misura?.h,
      'latoMassimo': latoMassimo,
    }))!;
    return LettoreFotogrammi._(
      m['id']! as int,
      m['larghezza']! as int,
      m['altezza']! as int,
    );
  }

  Future<Fotogramma?> a(double t) async {
    final dati = await _chiama<Uint8List>('fotogramma', {'id': _id, 't': t});
    return dati == null ? null : Fotogramma(larghezza, altezza, dati);
  }

  Future<void> chiudi() => _chiama<void>('chiudiLettore', {'id': _id});
}

/// Scrittura di un MP4 H.264 + AAC (`Mp4Writer`): i fotogrammi arrivano in ordine, l'audio (già mescolato)
/// tutto insieme all'apertura. Se qualcosa va storto o si annulla, il file a metà si elimina.
class ScrittoreMp4 {
  final int _id;
  ScrittoreMp4._(this._id);

  static Future<ScrittoreMp4> apri(
    String percorso,
    int larghezza,
    int altezza, {
    int fps = RegoleVideo.fps,
    Uint8List? audio,
  }) async {
    final id = await _chiama<int>('apriScrittore', {
      'percorso': percorso,
      'larghezza': larghezza,
      'altezza': altezza,
      'fps': fps,
      'audio': audio,
    });
    return ScrittoreMp4._(id!);
  }

  /// Aggiunge un fotogramma RGBA (larghezza × altezza × 4 byte, non premoltiplicato).
  Future<void> aggiungi(Uint8List rgba) =>
      _chiama<void>('aggiungiFotogramma', {'id': _id, 'rgba': rgba});

  /// Chiude il file: dopo questa chiamata l'MP4 è completo.
  Future<void> chiudi() => _chiama<void>('chiudiScrittore', {'id': _id});

  /// Interrompe e cancella il file a metà.
  Future<void> annulla() => _chiama<void>('annullaScrittore', {'id': _id});
}

/// Audio: ripete la traccia fino a [secondi] (i video più corti ricominciano da capo, `loop_audio`).
Uint8List ripetiAudio(Uint8List pcm, double secondi) {
  final serve =
      (secondi * RegoleVideo.frequenzaAudio).round() *
      RegoleVideo.bytePerCampione;
  final out = Uint8List(serve);
  if (pcm.isEmpty) return out;
  for (var i = 0; i < serve; i += pcm.length) {
    out.setRange(i, i + pcm.length > serve ? serve : i + pcm.length, pcm);
  }
  return out;
}

/// Audio: somma più tracce della stessa lunghezza (s16), tagliando i picchi che sforano (`mix_audio`).
Uint8List mescolaAudio(List<Uint8List> tracce) {
  if (tracce.length == 1) return tracce.first;
  final n = tracce.first.length ~/ 2;
  final out = Int16List(n);
  final viste = [
    for (final t in tracce)
      // Le viste a 16 bit vogliono un inizio allineato: altrimenti si copia
      (t.offsetInBytes.isEven ? t : Uint8List.fromList(t)).buffer.asInt16List(
        t.offsetInBytes.isEven ? t.offsetInBytes : 0,
        n,
      ),
  ];
  for (var i = 0; i < n; i++) {
    var s = 0;
    for (final v in viste) {
      s += v[i];
    }
    out[i] = s < -32768 ? -32768 : (s > 32767 ? 32767 : s);
  }
  return out.buffer.asUint8List();
}
