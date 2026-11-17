/// Foto e video scelti con il selettore di sistema e **copiati** in `media/` del progetto (piano §9): è il ripiego
/// quando il permesso alla galleria è negato. Il selettore di sistema (Photo Picker su Android, PHPicker su iOS)
/// non chiede permessi; i file scelti non si possono collegare in modo stabile, quindi si copiano.
library;

import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:scrl_engine/scrl_engine.dart' show estensioniVideo;

/// Un file copiato nel progetto: `rel` (= `path`) è relativo alla cartella del progetto, es. `media/foto.jpg`.
class FileImportato {
  final String rel;
  final bool video;
  const FileImportato(this.rel, {required this.video});
}

/// Il file è un video (estensioni del desktop, `VIDEO_EXTS`).
bool eVideo(String nome) {
  final l = nome.toLowerCase();
  return estensioniVideo.any(l.endsWith);
}

/// Nome libero nella cartella (`_unique_name` del desktop): con due file omonimi aggiunge `_2`, `_3`…;
/// [usati] contiene i nomi già presi in minuscolo e riceve quello scelto.
String nomeLibero(String nome, Set<String> usati) {
  final punto = nome.lastIndexOf('.');
  final radice = punto > 0 ? nome.substring(0, punto) : nome;
  final estensione = punto > 0 ? nome.substring(punto) : '';
  var candidato = nome;
  var n = 2;
  while (usati.contains(candidato.toLowerCase())) {
    candidato = '${radice}_$n$estensione';
    n++;
  }
  usati.add(candidato.toLowerCase());
  return candidato;
}

/// Copia [sorgenti] in `media/` di [cartellaProgetto] con nomi liberi. La copia passa dal disco (niente originali
/// in memoria); le copie temporanee del selettore si eliminano.
Future<List<FileImportato>> copiaInMedia(
  List<({String percorso, String nome})> sorgenti,
  Directory cartellaProgetto,
) async {
  final media = Directory('${cartellaProgetto.path}/media');
  await media.create(recursive: true);
  final usati = {
    for (final f in media.listSync().whereType<File>())
      f.uri.pathSegments.last.toLowerCase(),
  };
  final out = <FileImportato>[];
  for (final s in sorgenti) {
    final nome = nomeLibero(nomePulito(s.nome), usati);
    await File(s.percorso).copy('${media.path}/$nome');
    out.add(FileImportato('media/$nome', video: eVideo(nome)));
  }
  return out;
}

/// Nome di file senza cartelle né caratteri vietati su Windows (il progetto può tornare al PC).
String nomePulito(String nome) {
  final base = nome.split(RegExp(r'[/\\]')).last.trim();
  final p = base.replaceAll(RegExp(r'[<>:"|?*\x00-\x1F]'), '_');
  return p.isEmpty ? 'media' : p;
}

/// Apre il selettore di sistema (foto e video, più di uno) e copia i file scelti nel progetto.
/// Lista vuota se l'utente chiude il selettore senza scegliere.
Future<List<FileImportato>> scegliECopia(Directory cartellaProgetto) async {
  final scelti = await ImagePicker().pickMultipleMedia(
    requestFullMetadata: false,
  );
  try {
    return await copiaInMedia([
      for (final x in scelti) (percorso: x.path, nome: x.name),
    ], cartellaProgetto);
  } finally {
    for (final x in scelti) {
      try {
        await File(x.path).delete();
      } on FileSystemException {
        // Copia temporanea già sparita: niente da fare
      }
    }
  }
}
