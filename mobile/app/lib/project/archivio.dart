/// Archivio dei progetti sul telefono: una cartella per progetto dentro `progetti/`, con `progetto.scrlproj`
/// (formato del desktop, invariato), `info.json` (solo mobile: nome, pagine, misure delle foto), `miniatura.png`,
/// `media/` (copie del selettore di sistema) e `cache/` (anteprime, ricostruibili).
///
/// La scrittura è **atomica** (piano §5.3): prima un file temporaneo, poi la rinomina, così un `.scrlproj` non
/// resta mai a metà se l'app viene chiusa mentre salva.
library;

import 'dart:convert';
import 'dart:io';

import 'package:scrl_engine/scrl_engine.dart';

/// Un progetto dell'elenco della Home.
class InfoProgetto {
  const InfoProgetto({
    required this.cartella,
    required this.nome,
    required this.pagine,
    required this.modificato,
  });

  final Directory cartella;
  final String nome;
  final int pagine;
  final DateTime modificato;

  String get id => cartella.uri.pathSegments.where((s) => s.isNotEmpty).last;
}

/// Dati accessori di un progetto, salvati a parte (il `.scrlproj` non cambia).
class DatiAccessori {
  const DatiAccessori({
    required this.nome,
    this.pagine = 1,
    this.misure = const {},
  });

  final String nome;
  final int pagine;

  /// Misura in pixel delle foto, per chiave di sorgente: serve alle disposizioni (proporzioni) senza
  /// ricaricare ogni foto all'apertura.
  final Map<String, ({int w, int h})> misure;

  Map<String, Object?> toJson() => {
    'nome': nome,
    'pagine': pagine,
    'misure': {
      for (final e in misure.entries) e.key: [e.value.w, e.value.h],
    },
  };

  factory DatiAccessori.fromJson(Object? json, String nomePredefinito) {
    if (json is! Map) return DatiAccessori(nome: nomePredefinito);
    final misure = <String, ({int w, int h})>{};
    final m = json['misure'];
    if (m is Map) {
      for (final e in m.entries) {
        final v = e.value;
        if (e.key is String &&
            v is List &&
            v.length == 2 &&
            v[0] is num &&
            v[1] is num) {
          misure[e.key as String] = (
            w: (v[0] as num).toInt(),
            h: (v[1] as num).toInt(),
          );
        }
      }
    }
    final nome = json['nome'];
    final pagine = json['pagine'];
    return DatiAccessori(
      nome: nome is String && nome.isNotEmpty ? nome : nomePredefinito,
      pagine: pagine is int && pagine > 0 ? pagine : 1,
      misure: misure,
    );
  }
}

/// Progetto letto da disco.
class ProgettoCaricato {
  const ProgettoCaricato(this.cartella, this.file, this.dati);
  final Directory cartella;
  final ProjectFile file;
  final DatiAccessori dati;
}

class ArchivioProgetti {
  ArchivioProgetti(this.radice);

  /// Cartella `progetti/` (dentro i documenti dell'app).
  final Directory radice;

  static const nomeFileProgetto = 'progetto.scrlproj';
  static const _nomeInfo = 'info.json';
  static const _nomeMiniatura = 'miniatura.png';

  File fileProgetto(Directory c) => File('${c.path}/$nomeFileProgetto');
  File fileInfo(Directory c) => File('${c.path}/$_nomeInfo');
  File fileMiniatura(Directory c) => File('${c.path}/$_nomeMiniatura');

  /// Progetti dell'elenco, i modificati più di recente per primi.
  Future<List<InfoProgetto>> elenco() async {
    if (!radice.existsSync()) return const [];
    final out = <InfoProgetto>[];
    for (final e in radice.listSync()) {
      if (e is! Directory) continue;
      final f = fileProgetto(e);
      if (!f.existsSync()) continue;
      final id = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
      final dati = await _leggiDati(e, id);
      out.add(
        InfoProgetto(
          cartella: e,
          nome: dati.nome,
          pagine: dati.pagine,
          modificato: f.lastModifiedSync(),
        ),
      );
    }
    out.sort((a, b) => b.modificato.compareTo(a.modificato));
    return out;
  }

  Future<DatiAccessori> _leggiDati(Directory c, String idPredefinito) async {
    try {
      final f = fileInfo(c);
      if (f.existsSync()) {
        return DatiAccessori.fromJson(
          jsonDecode(await f.readAsString()),
          idPredefinito,
        );
      }
    } on FormatException {
      // info.json rovinato: si riparte dal nome della cartella
    } on FileSystemException {
      // illeggibile: idem
    }
    return DatiAccessori(nome: idPredefinito);
  }

  /// Cartella nuova, con un nome libero.
  Future<Directory> nuovaCartella() async {
    await radice.create(recursive: true);
    var n = DateTime.now().millisecondsSinceEpoch;
    while (Directory('${radice.path}/p$n').existsSync()) {
      n++;
    }
    return Directory('${radice.path}/p$n').create();
  }

  /// Legge il progetto in [cartella].
  Future<ProgettoCaricato> carica(Directory cartella) async {
    final file = ProjectFile.parse(await fileProgetto(cartella).readAsString());
    final id = cartella.uri.pathSegments.where((s) => s.isNotEmpty).last;
    return ProgettoCaricato(cartella, file, await _leggiDati(cartella, id));
  }

  /// Scrive progetto e dati accessori in modo atomico.
  Future<void> salva(
    Directory cartella,
    ProjectFile file,
    DatiAccessori dati,
  ) async {
    await _scriviAtomico(fileProgetto(cartella), file.encode());
    await _scriviAtomico(
      fileInfo(cartella),
      jsonEncode(
        DatiAccessori(
          nome: dati.nome,
          pagine: file.snapshot.canvas.numFrames,
          misure: dati.misure,
        ).toJson(),
      ),
    );
  }

  /// File temporaneo accanto a quello vero, poi rinomina: o c'è il file vecchio o il nuovo, mai uno a metà.
  Future<void> _scriviAtomico(File destinazione, String testo) async {
    final tmp = File('${destinazione.path}.tmp');
    await tmp.writeAsString(testo, flush: true);
    await tmp.rename(destinazione.path);
  }

  Future<void> rinomina(Directory cartella, String nome) async {
    final dati = await _leggiDati(cartella, nome);
    await _scriviAtomico(
      fileInfo(cartella),
      jsonEncode(
        DatiAccessori(
          nome: nome,
          pagine: dati.pagine,
          misure: dati.misure,
        ).toJson(),
      ),
    );
  }

  /// Copia l'intero progetto (file, `media/`, miniatura) in una cartella nuova col nome [nome].
  Future<Directory> duplica(Directory cartella, String nome) async {
    final nuova = await nuovaCartella();
    await for (final e in cartella.list(recursive: true)) {
      final rel = e.path.substring(cartella.path.length + 1);
      // La cache si ricostruisce da sola
      if (rel.replaceAll(r'\', '/').startsWith('cache')) continue;
      if (e is Directory) {
        await Directory('${nuova.path}/$rel').create(recursive: true);
      } else if (e is File) {
        await File('${nuova.path}/$rel').parent.create(recursive: true);
        await e.copy('${nuova.path}/$rel');
      }
    }
    await rinomina(nuova, nome);
    return nuova;
  }

  /// Elimina il progetto: la sua cartella e ciò che contiene (le foto della galleria non si toccano mai).
  Future<void> elimina(Directory cartella) async {
    if (cartella.existsSync()) await cartella.delete(recursive: true);
  }
}
