/// Codifica delle immagini esportate (piano §11): PNG e JPG a partire da pixel RGBA, **fuori dal thread
/// dell'interfaccia**.
///
/// Il motore grafico sa codificare solo l'immagine intera in PNG; qui serve anche il JPG e il collage, che si
/// disegna a pezzi (una pagina alla volta) e si unisce nella codifica: [CodificatoreStriscia] tiene in un isolate la
/// striscia intera e vi riceve le colonne, già disegnate, una alla volta. Così sul thread principale resta al
/// massimo una pagina in memoria.
library;

import 'dart:async';
import 'dart:convert' show ByteConversionSinkBase;
import 'dart:io' show ZLibEncoder;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Formato del file esportato.
enum FormatoImmagine {
  png,
  jpg;

  bool get isJpg => this == jpg;
}

// ---------------- PNG ----------------

final Uint32List _tabellaCrc = () {
  final t = Uint32List(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    t[n] = c;
  }
  return t;
}();

int _crc32(List<int> dati, [int inizio = 0, int? fine]) {
  var c = 0xFFFFFFFF;
  final f = fine ?? dati.length;
  for (var i = inizio; i < f; i++) {
    c = _tabellaCrc[(c ^ dati[i]) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

void _scriviU32(BytesBuilder b, int v) {
  b.add([(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF]);
}

void _blocco(BytesBuilder b, String tipo, List<int> dati) {
  _scriviU32(b, dati.length);
  final corpo = Uint8List(4 + dati.length)
    ..setRange(0, 4, tipo.codeUnits)
    ..setRange(4, 4 + dati.length, dati);
  b.add(corpo);
  _scriviU32(b, _crc32(corpo));
}

/// Righe filtrate (filtro «Sub») per ogni passata del compressore: la memoria in più resta piccola.
const int _righePerPassata = 64;

/// PNG RGBA a 8 bit da [rgba] (pixel non premoltiplicati, `w × h × 4` byte). Compressione moderata: in circa
/// metà tempo di quella massima, come il desktop (`img.save(path, "PNG", 80)`); resta senza perdite.
Uint8List codificaPng(Uint8List rgba, int w, int h) {
  if (rgba.length != w * h * 4) {
    throw ArgumentError('Pixel attesi ${w * h * 4}, ricevuti ${rgba.length}');
  }
  final compressi = BytesBuilder(copy: false);
  final sink = ZLibEncoder(level: 4)
      .startChunkedConversion(_Raccogli(compressi));
  final riga = w * 4;
  final blocco = Uint8List((riga + 1) * _righePerPassata);
  for (var y0 = 0; y0 < h; y0 += _righePerPassata) {
    final n = y0 + _righePerPassata <= h ? _righePerPassata : h - y0;
    for (var r = 0; r < n; r++) {
      final src = (y0 + r) * riga;
      final dst = r * (riga + 1);
      blocco[dst] = 1; // Filtro Sub: ogni byte meno quello del pixel a sinistra
      for (var i = 0; i < riga; i++) {
        final sinistra = i >= 4 ? rgba[src + i - 4] : 0;
        blocco[dst + 1 + i] = (rgba[src + i] - sinistra) & 0xFF;
      }
    }
    sink.add(Uint8List.sublistView(blocco, 0, n * (riga + 1)));
  }
  sink.close();
  final out = BytesBuilder(copy: false)
    ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  final ihdr = BytesBuilder();
  _scriviU32(ihdr, w);
  _scriviU32(ihdr, h);
  ihdr.add(const [
    8,
    6,
    0,
    0,
    0,
  ]); // 8 bit, RGBA, deflate, filtro standard, senza interlacciamento
  _blocco(out, 'IHDR', ihdr.toBytes());
  _blocco(out, 'IDAT', compressi.takeBytes());
  _blocco(out, 'IEND', const []);
  return out.takeBytes();
}

class _Raccogli extends ByteConversionSinkBase {
  _Raccogli(this._b);
  final BytesBuilder _b;
  @override
  void add(List<int> chunk) => _b.add(chunk);
  @override
  void close() {}
}

// ---------------- JPG ----------------

/// JPG da [rgba] con la qualità [qualita] (1–100), senza sottocampionare il colore.
Uint8List codificaJpg(Uint8List rgba, int w, int h, int qualita) {
  if (rgba.length != w * h * 4) {
    throw ArgumentError('Pixel attesi ${w * h * 4}, ricevuti ${rgba.length}');
  }
  final immagine = img.Image.fromBytes(
    width: w,
    height: h,
    bytes: rgba.buffer,
    bytesOffset: rgba.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return img.JpegEncoder(quality: qualita).encode(immagine);
}

/// Codifica [rgba] nel [formato] scelto.
Uint8List codificaImmagine(
  Uint8List rgba,
  int w,
  int h,
  FormatoImmagine formato,
  int qualita,
) => formato.isJpg ? codificaJpg(rgba, w, h, qualita) : codificaPng(rgba, w, h);

// ---------------- Striscia in un isolate ----------------

/// Immagine di [larghezza] × [altezza] pixel che si riempie a colonne (le pagine del collage, già disegnate) e si
/// codifica alla fine, tutto in un isolate. Con una sola colonna serve anche per una pagina singola.
class CodificatoreStriscia {
  CodificatoreStriscia._(this.larghezza, this.altezza);

  final int larghezza;
  final int altezza;

  Isolate? _isolate;
  final ReceivePort _risposte = ReceivePort();
  SendPort? _comandi;
  final Completer<SendPort> _pronto = Completer();
  final Completer<Uint8List> _risultato = Completer();

  /// Avvia l'isolate. L'immagine parte tutta trasparente: ogni colonna aggiunta la sostituisce.
  static Future<CodificatoreStriscia> avvia({
    required int larghezza,
    required int altezza,
    required FormatoImmagine formato,
    required int qualita,
  }) async {
    final c = CodificatoreStriscia._(larghezza, altezza);
    c._risposte.listen(c._alMessaggio);
    c._isolate = await Isolate.spawn(_ingresso, [
      c._risposte.sendPort,
      larghezza,
      altezza,
      formato.index,
      qualita,
    ]);
    c._comandi = await c._pronto.future;
    return c;
  }

  void _alMessaggio(Object? m) {
    if (m is SendPort) {
      _pronto.complete(m);
    } else if (m is List && m.first == 'ok') {
      if (!_risultato.isCompleted) {
        _risultato.complete(
          (m[1] as TransferableTypedData).materialize().asUint8List(),
        );
      }
    } else if (m is List && m.first == 'errore') {
      final e = StateError(m[1] as String);
      if (!_pronto.isCompleted) _pronto.completeError(e);
      if (!_risultato.isCompleted) _risultato.completeError(e);
    }
  }

  /// Mette la colonna di pixel RGBA [rgba] (larghezza [larghezzaColonna] e altezza dell'immagine) a partire da [x].
  void aggiungi(int x, int larghezzaColonna, Uint8List rgba) {
    _comandi!.send([
      'colonna',
      x,
      larghezzaColonna,
      TransferableTypedData.fromList([rgba]),
    ]);
  }

  /// Codifica l'immagine intera e libera l'isolate.
  Future<Uint8List> finisci() async {
    _comandi!.send(const ['fine']);
    try {
      return await _risultato.future;
    } finally {
      chiudi();
    }
  }

  /// Annulla o a lavoro finito: ferma l'isolate e libera tutto.
  void chiudi() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _risposte.close();
  }
}

void _ingresso(List<Object?> avvio) {
  final fuori = avvio[0] as SendPort;
  final w = avvio[1] as int, h = avvio[2] as int;
  final formato = FormatoImmagine.values[avvio[3] as int];
  final qualita = avvio[4] as int;
  final comandi = ReceivePort();
  fuori.send(comandi.sendPort);
  final pixel = Uint8List(w * h * 4);
  comandi.listen((m) {
    try {
      final msg = m as List;
      if (msg.first == 'colonna') {
        final x = msg[1] as int, cw = msg[2] as int;
        final col = (msg[3] as TransferableTypedData)
            .materialize()
            .asUint8List();
        if (x < 0 || cw <= 0 || x + cw > w || col.length != cw * h * 4) {
          throw StateError('Colonna fuori misura');
        }
        for (var y = 0; y < h; y++) {
          pixel.setRange(
            (y * w + x) * 4,
            (y * w + x + cw) * 4,
            col,
            y * cw * 4,
          );
        }
      } else {
        final dati = codificaImmagine(pixel, w, h, formato, qualita);
        fuori.send([
          'ok',
          TransferableTypedData.fromList([dati]),
        ]);
        comandi.close();
      }
    } catch (e) {
      fuori.send(['errore', '$e']);
    }
  });
}
