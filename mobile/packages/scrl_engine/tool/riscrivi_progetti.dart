/// Riscrive con il motore i progetti salvati dal desktop, per controllare che il desktop li riapra identici.
///
/// Uso, dalla cartella del pacchetto:
///
///     dart run tool/riscrivi_progetti.dart USCITA [PROGETTI] [INDICE]
///     python mobile/tools/genera_riferimenti.py --verifica USCITA     (dalla root, ambiente del desktop)
///
/// Per ogni progetto di PROGETTI (predefinito `test/riferimenti/progetti`) scrive in USCITA:
/// - `NOME-riscritto.scrlproj`: letto e riscritto così com'è;
/// - `NOME-modificato.scrlproj`: dopo alcune operazioni del motore (pagine, disposizione, spaziatura),
///   passate dalla cronologia come farebbe l'app;
/// - `mobile-galleria.scrlproj`: un progetto come lo salva il telefono, con foto collegate alla galleria
///   (campo `asset`, che il desktop deve mostrare come «Foto mancante»), una foto dentro `media/` e campi
///   sconosciuti a ogni livello.
library;

import 'dart:convert';
import 'dart:io';

import 'package:scrl_engine/scrl_engine.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Uso: dart run tool/riscrivi_progetti.dart USCITA [PROGETTI] [INDICE]',
    );
    exitCode = 64;
    return;
  }
  final uscita = Directory(args[0])..createSync(recursive: true);
  final progetti = Directory(
    args.length > 1 ? args[1] : 'test/riferimenti/progetti',
  );
  final indice = jsonDecode(
    File(args.length > 2 ? args[2] : 'test/riferimenti/indice.json')
        .readAsStringSync(),
  ) as Map<String, Object?>;
  final misure = <String, ({int w, int h})>{
    for (final f in (indice['foto']! as List).cast<List<Object?>>())
      f[0]! as String: (w: f[1]! as int, h: f[2]! as int),
  };
  ({int w, int h})? misura(PhotoItem p) => misure[baseName(p.rel ?? p.path)];

  final file =
      progetti
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith(progettoEstensione))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in file) {
    final nome = baseName(f.path).replaceAll(progettoEstensione, '');
    final progetto = ProjectFile.parse(f.readAsStringSync());
    _scrivi(uscita, '$nome-riscritto', progetto);

    final ctx = EngineContext(imageSize: misura);
    var h = History.reset(progetto.snapshot, ctx).history;
    Snapshot passo(EngineResult r) {
      h = h.commit(r.snapshot, ctx).history;
      return h.current;
    }

    var s = h.current;
    s = passo(setSpacing(s, ctx, gap: 30, margin: 40));
    s = passo(insertPageAt(s, s.canvas.numFrames, ctx));
    s = passo(duplicatePage(s, 0, ctx));
    s = passo(movePage(s, s.canvas.numFrames - 1, -1, ctx));
    s = passo(setPageLayout(s, s.canvas.numFrames - 1, 'mosaic', ctx, 'right'));
    _scrivi(uscita, '$nome-modificato', progetto.copyWith(snapshot: s));
  }

  // Progetto come lo salva il telefono
  final completo = ProjectFile.parse(
    File('${progetti.path}/completo.scrlproj').readAsStringSync(),
  );
  final foto = completo.snapshot.items;
  final galleria = [
    for (var i = 0; i < foto.length; i++)
      switch (i) {
        0 || 1 => linkToGallery(
          foto[i],
          MediaAsset(
            platform: 'android',
            id: '${1000 + i}',
            name: 'IMG_000$i.jpg',
          ),
        ).copyWith(extra: {'campo_futuro': i}),
        2 => placeInProject(foto[i], 'media/${baseName(foto[i].path)}'),
        _ => foto[i],
      },
  ];
  final mobile = ProjectFile(
    snapshot: completo.snapshot.copyWith(
      canvas: completo.snapshot.canvas.copyWith(
        extra: {'opzione_futura': true},
      ),
      items: galleria,
      texts: [
        for (final t in completo.snapshot.texts)
          t.copyWith(extra: {'effetto': 'neon'}),
      ],
    ),
    library: [
      ...completo.library,
      LibraryEntry(
        path: 'IMG_0000.jpg',
        asset: MediaAsset(
          platform: 'android',
          id: '1000',
          name: 'IMG_0000.jpg',
        ),
      ),
    ],
    extra: {'creato_da': 'ScrolleR Studio Mobile'},
  );
  _scrivi(uscita, 'mobile-galleria', mobile);
}

void _scrivi(Directory cartella, String nome, ProjectFile p) {
  File('${cartella.path}/$nome$progettoEstensione')
      .writeAsStringSync(p.encode());
  stdout.writeln('scritto $nome$progettoEstensione');
}
