/// Consegna dei file esportati (piano §11): Galleria (album «ScrolleR Studio»), foglio Condividi di sistema e
/// Salva in File. Sta dietro un'interfaccia così le prove la sostituiscono; il codice di piattaforma vero è in
/// [Galleria] (salvataggio in galleria) e nei pacchetti `share_plus` e `file_picker`.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../media/galleria.dart';
import '../project/provider.dart';

abstract class Consegna {
  /// Salva l'immagine in galleria, nell'album dell'app, con la data di creazione [data].
  Future<void> salvaInGalleria(Uint8List dati, String nome, DateTime data);

  /// Apre il foglio Condividi di sistema con i [file] (nell'ordine dato).
  Future<void> condividi(List<File> file, bool jpg);

  /// Salva un file dove sceglie l'utente. Falso se ha chiuso il selettore senza scegliere.
  Future<bool> salvaInFile(String nome, Uint8List dati, String mime);
}

class ConsegnaTelefono implements Consegna {
  const ConsegnaTelefono(this.galleria);
  final Galleria galleria;

  @override
  Future<void> salvaInGalleria(Uint8List dati, String nome, DateTime data) =>
      galleria.salvaImmagine(dati, nome, data: data);

  @override
  Future<void> condividi(List<File> file, bool jpg) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          for (final f in file)
            XFile(f.path, mimeType: jpg ? 'image/jpeg' : 'image/png'),
        ],
      ),
    );
  }

  @override
  Future<bool> salvaInFile(String nome, Uint8List dati, String mime) async {
    final uri = await FilePicker.saveFile(
      fileName: nome,
      bytes: dati,
      mimeType: mime,
    );
    return uri != null;
  }
}

/// Consegna dei file esportati: il telefono vero; le prove la sostituiscono.
final consegnaProvider = Provider<Consegna>(
  (ref) => ConsegnaTelefono(ref.watch(galleriaProvider)),
);

/// Cartella temporanea dove nascono i file prima della consegna (la fornisce il sistema; le prove usano la loro).
final cartellaTemporaneaProvider = Provider<Future<Directory> Function()>(
  (ref) => getTemporaryDirectory,
);
