/// Immagini delle foto e dei video a tre livelli di dettaglio (piano §8.3, §9):
/// - **miniatura** (libreria), **anteprima** (lato lungo 1600 px): salvate su disco in `cache/` del progetto,
///   così il progetto si riapre in fretta e una foto il cui originale è sparito resta visibile;
/// - **alta** risoluzione (fino a 4096 px) su richiesta, quando la foto è ingrandita oltre il 115% dei suoi
///   pixel: solo in memoria, poche alla volta.
///
/// Gli originali non stanno mai in memoria: si decodificano già ridotti, fuori dal thread dell'interfaccia
/// (decodificatore del motore grafico o del sistema). La memoria ha un limite in megabyte e si svuota quando
/// il sistema segnala poca memoria.
library;

import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:scrl_engine/scrl_engine.dart';
import 'package:scrl_video/scrl_video.dart';

import '../render/regolazioni.dart';
import 'galleria.dart';

/// Livelli di dettaglio, col lato lungo in pixel.
enum Dettaglio {
  miniatura(320),
  anteprima(1600),
  alta(4096);

  const Dettaglio(this.lato);
  final int lato;
}

/// Da dove si legge una foto del progetto (risolta con `resolveMedia` del motore).
class SorgenteMedia {
  /// Chiave stabile per la cache: identificativo della galleria oppure percorso nel progetto.
  final String chiave;
  final MediaLocation posizione;
  final bool video;
  const SorgenteMedia(this.chiave, this.posizione, {this.video = false});

  bool get trovata => posizione.source != MediaSource.missing;
}

/// Sorgente di una foto: galleria (stessa piattaforma), poi `rel`, poi `path` (§7 «Percorsi»).
SorgenteMedia sorgenteDi(PhotoItem p, String cartellaProgetto) {
  final pos = resolveMedia(
    path: p.path,
    rel: p.rel,
    asset: p.asset,
    projectDir: cartellaProgetto,
    platform: Galleria.piattaforma,
    fileExists: (f) => File(f).existsSync(),
  );
  return SorgenteMedia(chiaveMedia(p), pos, video: p.isVideo);
}

/// Chiave stabile di una foto, senza toccare il disco: identificativo della galleria oppure percorso nel progetto.
String chiaveMedia(PhotoItem p) {
  final a = p.asset;
  return a != null ? 'a:${a.platform}:${a.id}' : 'f:${p.rel ?? p.path}';
}

/// Immagine caricata e se l'originale manca (si vede l'anteprima salvata).
class ImmagineMedia {
  final ui.Image immagine;
  final bool originaleMancante;
  const ImmagineMedia(this.immagine, {this.originaleMancante = false});
}

class CacheMedia {
  CacheMedia({
    required this.cartella,
    this.galleria = const Galleria(),
    this.latoAnteprima = 1600,
    this.limiteMegabyte = 256,
  });

  /// Cartella `cache/` del progetto.
  final Directory cartella;
  final Galleria galleria;

  /// Lato lungo delle anteprime (meno sui telefoni con poca memoria).
  final int latoAnteprima;
  final int limiteMegabyte;

  /// Immagini in memoria, la più usata in fondo.
  final LinkedHashMap<String, ImmagineMedia> _memoria = LinkedHashMap();
  final Map<String, Future<ImmagineMedia?>> _inCorso = {};
  int _byte = 0;

  /// Versioni in alta risoluzione tenute in memoria (ognuna fino a ~65 MB).
  static const int alteInMemoria = 4;

  int _lato(Dettaglio d) => d == Dettaglio.anteprima ? latoAnteprima : d.lato;

  /// Immagine già in memoria (senza aspettare), o null.
  ImmagineMedia? pronta(SorgenteMedia s, Dettaglio d) {
    final k = '${s.chiave}|${d.name}';
    final v = _memoria.remove(k);
    if (v != null) _memoria[k] = v; // Torna la più recente
    return v;
  }

  /// Carica (una volta sola anche se chiesta più volte insieme) l'immagine al dettaglio [d].
  Future<ImmagineMedia?> carica(SorgenteMedia s, Dettaglio d) {
    final gia = pronta(s, d);
    if (gia != null) return Future.value(gia);
    final k = '${s.chiave}|${d.name}';
    return _inCorso[k] ??= _carica(s, d)
        .then((v) {
          if (v != null) _metti(k, v, d);
          return v;
        })
        // Graffe: con `=> remove(k)` whenComplete aspetterebbe il Future tolto, cioè se stesso, per sempre
        .whenComplete(() {
          _inCorso.remove(k);
        });
  }

  void _metti(String k, ImmagineMedia v, Dettaglio d) {
    _memoria[k] = v;
    _byte += v.immagine.width * v.immagine.height * 4;
    // Al massimo [alteInMemoria] in alta risoluzione, e in tutto entro il limite in megabyte
    final alte = _memoria.keys.where((c) => c.endsWith('|alta')).toList();
    for (var i = 0; i < alte.length - alteInMemoria; i++) {
      _togli(alte[i]);
    }
    while (_byte > limiteMegabyte * 1024 * 1024 && _memoria.length > 1) {
      _togli(_memoria.keys.first);
    }
  }

  void _togli(String k) {
    final v = _memoria.remove(k);
    if (v != null) _byte -= v.immagine.width * v.immagine.height * 4;
  }

  /// Il sistema segnala poca memoria: si tiene solo ciò che si può ricaricare dal disco.
  void svuota() {
    _memoria.clear();
    _byte = 0;
  }

  /// Toglie dal disco le anteprime delle foto che non sono più nel progetto (tolte dalla tela e dalla libreria):
  /// senza, la cartella `cache/` crescerebbe a ogni foto sostituita. Restano quelle di tutte le foto in uso, anche
  /// se l'originale non c'è più (l'anteprima salvata è proprio ciò che le tiene visibili). Non tocca i file
  /// scritti da meno di [eta]: possono essere di una foto appena aggiunta, che l'elenco non conosce ancora.
  /// Ritorna quanti file ha tolto.
  Future<int> pulisciOrfane(
    Iterable<String> chiaviInUso, {
    Duration eta = const Duration(hours: 1),
  }) async {
    if (!cartella.existsSync()) return 0;
    final usate = {for (final k in chiaviInUso) _hash(k)};
    final limite = DateTime.now().subtract(eta);
    var tolti = 0;
    try {
      await for (final e in cartella.list()) {
        if (e is! File || !e.path.endsWith('.img')) continue;
        final nome = e.uri.pathSegments.last;
        if (usate.contains(nome.split('_').first)) continue;
        if (e.lastModifiedSync().isAfter(limite)) continue;
        try {
          await e.delete();
          tolti++;
        } on FileSystemException {
          // Già sparito o non cancellabile: ci si riprova alla prossima apertura
        }
      }
    } on FileSystemException {
      // Cartella illeggibile: la cache è solo un acceleratore
    }
    return tolti;
  }

  /// File dell'anteprima salvata su disco per [s], o null se non c'è (serve allo `.zip` di «Condividi progetto»
  /// quando l'originale è sparito).
  File? fileAnteprima(SorgenteMedia s) {
    final f = _fileCache(s, Dettaglio.anteprima);
    return f.existsSync() ? f : null;
  }

  File _fileCache(SorgenteMedia s, Dettaglio d) =>
      File('${cartella.path}/${_hash(s.chiave)}_${_lato(d)}.img');

  Future<ImmagineMedia?> _carica(SorgenteMedia s, Dettaglio d) async {
    if (d == Dettaglio.alta) {
      if (!s.trovata) return null;
      final img = await _daOriginale(s, d.lato);
      return img == null ? null : ImmagineMedia(img);
    }
    final f = _fileCache(s, d);
    if (f.existsSync()) {
      final img = await _decodifica(await f.readAsBytes(), null);
      if (img != null) {
        return ImmagineMedia(img, originaleMancante: !await _esiste(s));
      }
    }
    if (!s.trovata) return null;
    final dati = await _ridotta(s, _lato(d));
    if (dati == null) return null;
    final img = await _decodifica(dati, _lato(d));
    if (img == null) return null;
    await cartella.create(recursive: true);
    await f.writeAsBytes(dati, flush: true);
    return ImmagineMedia(img);
  }

  /// L'originale c'è ancora (controllo all'apertura).
  Future<bool> _esiste(SorgenteMedia s) async {
    final p = s.posizione;
    if (p.source == MediaSource.asset) return galleria.esiste(p.asset!);
    return s.trovata;
  }

  /// Versione ridotta da salvare su disco: JPEG dal sistema per la galleria, PNG per i file del progetto.
  Future<Uint8List?> _ridotta(SorgenteMedia s, int lato) async {
    final p = s.posizione;
    if (p.source == MediaSource.asset) {
      final e = await galleria.entita(p.asset!);
      return e == null ? null : galleria.ridotta(e, lato);
    }
    final img = await _daOriginale(s, lato);
    if (img == null) return null;
    try {
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      return png?.buffer.asUint8List();
    } finally {
      img.dispose();
    }
  }

  /// Originale decodificato già ridotto al lato lungo [lato] (null = misura vera).
  Future<ui.Image?> _daOriginale(SorgenteMedia s, int? lato) async {
    final p = s.posizione;
    if (s.video) {
      final sorgente = p.source == MediaSource.asset
          ? await _sorgenteVideoGalleria(p.asset!)
          : p.file;
      if (sorgente == null) return null;
      try {
        final f = await ScrlVideo.fotogramma(
          sorgente,
          0,
          latoMassimo: lato ?? 1 << 14,
        );
        return await immagineDaPixel(f.rgba, f.larghezza, f.altezza);
      } on Exception {
        // Video illeggibile (o telefono senza video): come una foto che non si decodifica, non blocca le altre
        return null;
      }
    }
    File? file;
    if (p.source == MediaSource.asset) {
      final e = await galleria.entita(p.asset!);
      if (e == null) return null;
      file = await galleria.originale(e);
    } else if (p.file != null) {
      file = File(p.file!);
    }
    if (file == null) return null;
    return _decodifica(await file.readAsBytes(), lato);
  }

  Future<String?> _sorgenteVideoGalleria(MediaAsset a) async {
    final e = await galleria.entita(a);
    return e == null ? null : galleria.sorgenteVideo(e);
  }

  /// Sorgente da passare a `scrl_video` per un video del progetto.
  Future<String?> sorgenteVideo(SorgenteMedia s) async {
    final p = s.posizione;
    if (p.source == MediaSource.asset) return _sorgenteVideoGalleria(p.asset!);
    return p.file;
  }

  /// Originale per l'esportazione, letto almeno a [lato] px sul lato lungo (non resta in memoria).
  Future<ui.Image?> perEsportazione(SorgenteMedia s, int lato) async {
    if (!s.trovata) return null;
    return _daOriginale(s, lato);
  }

  /// Decodifica (rotazione EXIF e profilo colore in sRGB a carico del decodificatore) col lato lungo
  /// al massimo [lato]: il formato compresso si decodifica già ridotto.
  static Future<ui.Image?> _decodifica(Uint8List dati, int? lato) async {
    try {
      final buf = await ui.ImmutableBuffer.fromUint8List(dati);
      final codec = await ui.instantiateImageCodecWithSize(
        buf,
        getTargetSize: (w, h) {
          if (lato == null || (w <= lato && h <= lato)) {
            return const ui.TargetImageSize();
          }
          return w >= h
              ? ui.TargetImageSize(width: lato)
              : ui.TargetImageSize(height: lato);
        },
      );
      try {
        final img = (await codec.getNextFrame()).image;
        if (lato == null) return img;
        // Con la rotazione EXIF il decodificatore può aver ridotto l'altro lato: si rifinisce qui
        final r = await ridimensiona(img, lato);
        if (!identical(r, img)) img.dispose();
        return r;
      } finally {
        codec.dispose();
      }
    } catch (_) {
      return null; // File non leggibile: non blocca gli altri
    }
  }

  /// FNV-1a a 64 bit in esadecimale: nome del file in cache.
  static String _hash(String s) {
    var h = 0xcbf29ce484222325;
    for (final b in s.codeUnits) {
      h ^= b;
      h *= 0x100000001b3; // Gli interi a 64 bit si riavvolgono da soli
    }
    // Le due metà a 32 bit: toRadixString di un intero a 64 bit con segno darebbe un «-» davanti
    String meta(int v) => v.toRadixString(16).padLeft(8, '0');
    return meta((h >> 32) & 0xFFFFFFFF) + meta(h & 0xFFFFFFFF);
  }
}
