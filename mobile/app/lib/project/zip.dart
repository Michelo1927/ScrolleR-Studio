/// Lettura e scrittura di file `.zip` (piano §9 «Scambio»): lo `.zip` di «Condividi progetto» e quelli che arrivano dal PC.
///
/// Scritto a blocchi di 64 KB: le foto e i video non stanno mai in memoria, l'avanzamento è per byte e Annulla si
/// controlla a ogni blocco (così anche un video da centinaia di MB non blocca l'interfaccia). In scrittura i file
/// sono **non compressi** (foto e video sono già compressi) e il CRC si ricopia nell'intestazione a fine file, quindi
/// lo `.zip` si apre ovunque (Esplora risorse, Finder, Python `zipfile`) senza descrittori di dati. In lettura si
/// accetta anche il formato «deflate» che producono Esplora risorse e il desktop. Non gestiti, con un errore chiaro:
/// ZIP64 (oltre 4 GB per file o 65 535 voci) e file protetti da password.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'lavoro.dart';

/// Lo `.zip` non è valido o è rovinato.
class ZipNonValido implements Exception {
  const ZipNonValido(this.messaggio);
  final String messaggio;
  @override
  String toString() => 'ZipNonValido: $messaggio';
}

/// Funzione dello `.zip` che qui non c'è (ZIP64, password, compressione insolita).
class ZipNonSupportato implements Exception {
  const ZipNonSupportato(this.messaggio);
  final String messaggio;
  @override
  String toString() => 'ZipNonSupportato: $messaggio';
}

/// Il disco è pieno: la copia si è interrotta e il file a metà è stato tolto.
class SpazioInsufficiente implements Exception {
  const SpazioInsufficiente();
  @override
  String toString() => 'Spazio insufficiente';
}

/// Errori di disco pieno: ENOSPC su Android/iOS/Linux, ERROR_DISK_FULL / ERROR_HANDLE_DISK_FULL su Windows.
bool eDiscoPieno(Object e) =>
    e is FileSystemException &&
    (e.osError?.errorCode == 28 ||
        e.osError?.errorCode == 112 ||
        e.osError?.errorCode == 39);

const int _blocco = 64 * 1024;
const int _max32 = 0xFFFFFFFF;

// ---------------------------------------------------------------- CRC-32

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

/// CRC-32 (quello dello zip) di [dati], continuando da [crc] (0 per iniziare).
int crc32(List<int> dati, [int crc = 0]) {
  var c = crc ^ _max32;
  for (var i = 0; i < dati.length; i++) {
    c = _tabellaCrc[(c ^ dati[i]) & 0xFF] ^ (c >> 8);
  }
  return c ^ _max32;
}

// ---------------------------------------------------------------- scrittura

/// Una voce da scrivere: [nome] dentro lo zip (con `/`) e il contenuto, da file o già in memoria (cose piccole).
class VoceZip {
  VoceZip.file(this.nome, File this.file) : dati = null;
  VoceZip.dati(this.nome, Uint8List this.dati) : file = null;

  final String nome;
  final File? file;
  final Uint8List? dati;
}

/// Avanzamento in byte della scrittura o dell'estrazione.
typedef ProgressoByte = void Function(int fatti, String nome);

/// Scrive [voci] in [destinazione]. Se [annullamento] scatta o c'è un errore, il file a metà viene tolto.
Future<void> scriviZip(
  File destinazione,
  List<VoceZip> voci, {
  ProgressoByte? progresso,
  Annullamento? annullamento,
}) async {
  if (voci.length > 0xFFFF) {
    throw const ZipNonSupportato('troppe voci (oltre 65 535)');
  }
  await destinazione.parent.create(recursive: true);
  final out = await destinazione.open(mode: FileMode.write);
  var chiuso = false;
  try {
    final centrale = BytesBuilder(copy: false);
    var posizione = 0;
    var byteFatti = 0;
    final ora = DateTime.now();
    for (final v in voci) {
      annullamento?.controlla();
      final nome = utf8.encode(v.nome);
      if (nome.length > 0xFFFF) {
        throw const ZipNonSupportato('nome di file troppo lungo');
      }
      final dimensione = v.dati?.length ?? await v.file!.length();
      if (dimensione > _max32 || posizione > _max32) {
        throw const ZipNonSupportato('file oltre i 4 GB (ZIP64)');
      }
      final data = v.file != null ? v.file!.lastModifiedSync() : ora;
      final tempo = _tempoDos(data);
      final dataDos = _dataDos(data);

      final inizio = posizione;
      final h = ByteData(30 + nome.length);
      h.setUint32(0, 0x04034b50, Endian.little);
      h.setUint16(4, 20, Endian.little); // Versione necessaria
      h.setUint16(6, 0x0800, Endian.little); // Nomi in UTF-8
      h.setUint16(8, 0, Endian.little); // Senza compressione
      h.setUint16(10, tempo, Endian.little);
      h.setUint16(12, dataDos, Endian.little);
      h.setUint32(14, 0, Endian.little); // CRC: si scrive a fine voce
      h.setUint32(18, dimensione, Endian.little);
      h.setUint32(22, dimensione, Endian.little);
      h.setUint16(26, nome.length, Endian.little);
      h.setUint16(28, 0, Endian.little);
      final intestazione = h.buffer.asUint8List();
      intestazione.setRange(30, 30 + nome.length, nome);
      await out.writeFrom(intestazione);
      posizione += intestazione.length;

      var crc = 0;
      var scritti = 0;
      Future<void> blocco(List<int> b) async {
        annullamento?.controlla();
        crc = crc32(b, crc);
        await out.writeFrom(b);
        scritti += b.length;
        byteFatti += b.length;
        progresso?.call(byteFatti, v.nome);
      }

      if (v.dati != null) {
        for (var i = 0; i < v.dati!.length; i += _blocco) {
          await blocco(
            Uint8List.sublistView(
              v.dati!,
              i,
              math.min(i + _blocco, v.dati!.length),
            ),
          );
        }
      } else {
        await for (final b in v.file!.openRead()) {
          await blocco(b);
        }
      }
      if (scritti != dimensione) {
        throw FileSystemException(
          'Il file è cambiato mentre veniva copiato',
          v.nome,
        );
      }
      posizione += scritti;
      // CRC nell'intestazione, poi si torna in fondo
      final c = ByteData(4)..setUint32(0, crc, Endian.little);
      await out.setPosition(inizio + 14);
      await out.writeFrom(c.buffer.asUint8List());
      await out.setPosition(posizione);

      final e = ByteData(46 + nome.length);
      e.setUint32(0, 0x02014b50, Endian.little);
      e.setUint16(4, 20, Endian.little); // Creato da
      e.setUint16(6, 20, Endian.little); // Versione necessaria
      e.setUint16(8, 0x0800, Endian.little);
      e.setUint16(10, 0, Endian.little);
      e.setUint16(12, tempo, Endian.little);
      e.setUint16(14, dataDos, Endian.little);
      e.setUint32(16, crc, Endian.little);
      e.setUint32(20, dimensione, Endian.little);
      e.setUint32(24, dimensione, Endian.little);
      e.setUint16(28, nome.length, Endian.little);
      e.setUint32(42, inizio, Endian.little);
      final voceCentrale = e.buffer.asUint8List();
      voceCentrale.setRange(46, 46 + nome.length, nome);
      centrale.add(voceCentrale);
    }
    final cd = centrale.takeBytes();
    if (posizione + cd.length > _max32) {
      throw const ZipNonSupportato('archivio oltre i 4 GB (ZIP64)');
    }
    await out.writeFrom(cd);
    final f = ByteData(22);
    f.setUint32(0, 0x06054b50, Endian.little);
    f.setUint16(8, voci.length, Endian.little);
    f.setUint16(10, voci.length, Endian.little);
    f.setUint32(12, cd.length, Endian.little);
    f.setUint32(16, posizione, Endian.little);
    await out.writeFrom(f.buffer.asUint8List());
    await out.flush();
    await out.close();
    chiuso = true;
  } catch (e) {
    if (!chiuso) {
      chiuso = true;
      try {
        await out.close();
      } on FileSystemException {
        // Già chiuso o non scrivibile: resta solo da togliere il file
      }
    }
    try {
      if (destinazione.existsSync()) await destinazione.delete();
    } on FileSystemException {
      // Non si riesce a togliere: pazienza, è nella cartella temporanea
    }
    if (eDiscoPieno(e)) throw const SpazioInsufficiente();
    rethrow;
  }
}

int _tempoDos(DateTime d) => (d.hour << 11) | (d.minute << 5) | (d.second ~/ 2);

int _dataDos(DateTime d) =>
    ((math.max(d.year, 1980) - 1980) << 9) | (d.month << 5) | d.day;

// ---------------------------------------------------------------- lettura

/// Una voce dello `.zip` (dalla directory centrale).
class VoceLetta {
  const VoceLetta({
    required this.nome,
    required this.dimensione,
    required this.compressa,
    required this.metodo,
    required this.crc,
    required this.offset,
  });

  /// Nome con `/` (le `\` di alcuni programmi sono già convertite).
  final String nome;
  final int dimensione;
  final int compressa;
  final int metodo;
  final int crc;
  final int offset;

  bool get eCartella => nome.endsWith('/');
}

/// Nome di una voce senza insidie: niente `..`, percorsi assoluti o lettere di unità (zip-slip). Null se non è sicuro.
String? nomeSicuro(String nome) {
  final n = nome.replaceAll(r'\', '/');
  if (n.isEmpty || n.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(n)) {
    return null;
  }
  final parti = n.split('/').where((p) => p.isNotEmpty && p != '.').toList();
  if (parti.isEmpty || parti.contains('..')) return null;
  if (parti.any((p) => p.contains('\x00'))) return null;
  return parti.join('/') + (n.endsWith('/') ? '/' : '');
}

/// Voci che i sistemi aggiungono da soli e che non sono del progetto (`__MACOSX/`, `.DS_Store`, `Thumbs.db`).
bool eScartoDiSistema(String nome) {
  final p = nome.split('/');
  return p.first == '__MACOSX' ||
      p.last == '.DS_Store' ||
      p.last.toLowerCase() == 'thumbs.db' ||
      p.last.toLowerCase() == 'desktop.ini';
}

class LettoreZip {
  LettoreZip._(this._file, this.voci);

  final RandomAccessFile _file;
  final List<VoceLetta> voci;

  /// Apre [file] e legge la directory centrale.
  static Future<LettoreZip> apri(File file) async {
    final raf = await file.open();
    try {
      final lunghezza = await raf.length();
      if (lunghezza < 22) throw const ZipNonValido('file troppo corto');
      final cerca = math.min(lunghezza, 22 + 0xFFFF);
      await raf.setPosition(lunghezza - cerca);
      final coda = await raf.read(cerca);
      var eocd = -1;
      for (var i = coda.length - 22; i >= 0; i--) {
        if (coda[i] == 0x50 &&
            coda[i + 1] == 0x4b &&
            coda[i + 2] == 0x05 &&
            coda[i + 3] == 0x06) {
          eocd = i;
          break;
        }
      }
      if (eocd < 0) throw const ZipNonValido('non è un file .zip');
      final f = ByteData.sublistView(coda, eocd);
      final totale = f.getUint16(10, Endian.little);
      final dimCd = f.getUint32(12, Endian.little);
      final offCd = f.getUint32(16, Endian.little);
      if (totale == 0xFFFF || dimCd == _max32 || offCd == _max32) {
        throw const ZipNonSupportato('ZIP64');
      }
      if (offCd + dimCd > lunghezza) {
        throw const ZipNonValido('directory centrale fuori dal file');
      }
      await raf.setPosition(offCd);
      final cd = await raf.read(dimCd);
      if (cd.length != dimCd) throw const ZipNonValido('file troncato');
      final b = ByteData.sublistView(cd);
      final voci = <VoceLetta>[];
      var p = 0;
      for (var i = 0; i < totale; i++) {
        if (p + 46 > cd.length || b.getUint32(p, Endian.little) != 0x02014b50) {
          throw const ZipNonValido('directory centrale rovinata');
        }
        final flag = b.getUint16(p + 8, Endian.little);
        final metodo = b.getUint16(p + 10, Endian.little);
        final crc = b.getUint32(p + 16, Endian.little);
        final compressa = b.getUint32(p + 20, Endian.little);
        final dimensione = b.getUint32(p + 24, Endian.little);
        final lNome = b.getUint16(p + 28, Endian.little);
        final lExtra = b.getUint16(p + 30, Endian.little);
        final lCommento = b.getUint16(p + 32, Endian.little);
        final offset = b.getUint32(p + 42, Endian.little);
        if (p + 46 + lNome > cd.length) {
          throw const ZipNonValido('directory centrale rovinata');
        }
        final grezzo = cd.sublist(p + 46, p + 46 + lNome);
        if (flag & 1 != 0) {
          throw const ZipNonSupportato('protetto da password');
        }
        if (compressa == _max32 || dimensione == _max32 || offset == _max32) {
          throw const ZipNonSupportato('ZIP64');
        }
        if (metodo != 0 && metodo != 8) {
          throw ZipNonSupportato('compressione $metodo');
        }
        String nome;
        try {
          nome = utf8.decode(grezzo);
        } on FormatException {
          nome = latin1.decode(
            grezzo,
          ); // Programmi vecchi: pagina di codice locale
        }
        voci.add(
          VoceLetta(
            nome: nome.replaceAll(r'\', '/'),
            dimensione: dimensione,
            compressa: compressa,
            metodo: metodo,
            crc: crc,
            offset: offset,
          ),
        );
        p += 46 + lNome + lExtra + lCommento;
      }
      return LettoreZip._(raf, voci);
    } catch (_) {
      await raf.close();
      rethrow;
    }
  }

  Future<void> chiudi() => _file.close();

  /// Legge la voce [v] a blocchi e li passa a [scrivi]. Controlla CRC e dimensione dichiarati.
  Future<void> _leggi(
    VoceLetta v,
    Future<void> Function(Uint8List blocco) scrivi,
    Annullamento? annullamento,
  ) async {
    await _file.setPosition(v.offset);
    final h = await _file.read(30);
    if (h.length < 30 ||
        ByteData.sublistView(h).getUint32(0, Endian.little) != 0x04034b50) {
      throw ZipNonValido('voce «${v.nome}» rovinata');
    }
    final bd = ByteData.sublistView(h);
    final inizio =
        v.offset +
        30 +
        bd.getUint16(26, Endian.little) +
        bd.getUint16(28, Endian.little);
    await _file.setPosition(inizio);
    var crc = 0;
    var scritti = 0;
    Future<void> esce(Uint8List b) async {
      scritti += b.length;
      if (scritti > v.dimensione) {
        throw ZipNonValido('voce «${v.nome}» più grande del dichiarato');
      }
      crc = crc32(b, crc);
      await scrivi(b);
    }

    var restano = v.compressa;
    if (v.metodo == 0) {
      while (restano > 0) {
        annullamento?.controlla();
        final b = await _file.read(math.min(_blocco, restano));
        if (b.isEmpty) throw const ZipNonValido('file troncato');
        restano -= b.length;
        await esce(b);
      }
    } else {
      final pronti = <Uint8List>[];
      // Il decodificatore consegna a un sink sincrono: si raccolgono i blocchi e si scrivono dopo ogni lettura
      final decodificatore = _Inflate(pronti.add);
      try {
        while (restano > 0) {
          annullamento?.controlla();
          final b = await _file.read(math.min(_blocco, restano));
          if (b.isEmpty) throw const ZipNonValido('file troncato');
          restano -= b.length;
          decodificatore.aggiungi(b);
          for (final o in pronti) {
            await esce(o);
          }
          pronti.clear();
        }
        decodificatore.chiudi();
        for (final o in pronti) {
          await esce(o);
        }
      } on FormatException {
        throw ZipNonValido('voce «${v.nome}» non decomprimibile');
      }
    }
    if (scritti != v.dimensione || crc != v.crc) {
      throw ZipNonValido('voce «${v.nome}» rovinata (CRC)');
    }
  }

  /// Estrae [v] in [destinazione]. Un errore o Annulla tolgono il file a metà.
  /// [progresso] riceve i byte scritti di questa voce.
  Future<void> estrai(
    VoceLetta v,
    File destinazione, {
    void Function(int byteVoce)? progresso,
    Annullamento? annullamento,
  }) async {
    await destinazione.parent.create(recursive: true);
    final out = await destinazione.open(mode: FileMode.write);
    var fatti = 0;
    try {
      await _leggi(v, (b) async {
        await out.writeFrom(b);
        fatti += b.length;
        progresso?.call(fatti);
      }, annullamento);
      await out.close();
    } catch (e) {
      try {
        await out.close();
        await destinazione.delete();
      } on FileSystemException {
        // Resta un file a metà in una cartella che l'importazione toglierà
      }
      if (eDiscoPieno(e)) throw const SpazioInsufficiente();
      rethrow;
    }
  }

  /// Contenuto di [v] in memoria (solo per file piccoli, come il `.scrlproj`): oltre [massimo] byte si rifiuta.
  Future<Uint8List> leggiInMemoria(
    VoceLetta v, {
    int massimo = 64 << 20,
  }) async {
    if (v.dimensione > massimo) {
      throw ZipNonValido('voce «${v.nome}» troppo grande');
    }
    final b = BytesBuilder(copy: false);
    await _leggi(v, (x) async => b.add(x), null);
    return b.takeBytes();
  }
}

/// Decompressione «deflate» grezza a blocchi, con i risultati in un elenco (la conversione di `dart:io` è sincrona).
class _Inflate {
  _Inflate(void Function(Uint8List) aOutput) {
    _sink = ZLibDecoder(raw: true)
        .startChunkedConversion(ByteConversionSink.from(_Raccogli(aOutput)));
  }

  late final Sink<List<int>> _sink;

  void aggiungi(List<int> dati) => _sink.add(dati);
  void chiudi() => _sink.close();
}

class _Raccogli implements Sink<List<int>> {
  _Raccogli(this._aOutput);
  final void Function(Uint8List) _aOutput;

  @override
  void add(List<int> dati) => _aOutput(Uint8List.fromList(dati));

  @override
  void close() {}
}
