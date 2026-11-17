import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scrl_engine/scrl_engine.dart';
import 'package:scrollr_studio/project/archivio.dart';
import 'package:scrollr_studio/project/crea_progetto.dart';

FotoScelta _foto(int i) => (
  voce: LibraryEntry(path: 'foto$i.jpg', rel: 'media/foto$i.jpg'),
  chiave: 'f:media/foto$i.jpg',
  w: i.isEven ? 4000 : 3000,
  h: i.isEven ? 3000 : 4000,
);

void main() {
  late Directory radice;
  late ArchivioProgetti archivio;

  setUp(() {
    radice = Directory.systemTemp.createTempSync('scrl_archivio_test');
    archivio = ArchivioProgetti(Directory('${radice.path}/progetti'));
  });
  tearDown(() => radice.deleteSync(recursive: true));

  Future<Directory> crea(String nome, {int foto = 12}) async {
    final c = await archivio.nuovaCartella();
    await creaProgetto(
      archivio: archivio,
      cartella: c,
      nome: nome,
      formato: (indice: 2, larghezza: 1080, altezza: 1350),
      scelte: [for (var i = 1; i <= foto; i++) _foto(i)],
    );
    return c;
  }

  test('il progetto nuovo ha il formato scelto e le foto in griglia', () async {
    final c = await crea('Viaggio');
    final p = await archivio.carica(c);
    final s = p.file.snapshot;
    expect(s.canvas.ratioIndex, 2);
    expect((s.canvas.frameW, s.canvas.frameH), (1080, 1350));
    expect(s.canvas.layoutMode, LayoutModes.grid);
    expect(s.items.length, 12);
    expect(p.file.library.length, 12);
    expect(p.dati.nome, 'Viaggio');
    expect(p.dati.misure['f:media/foto1.jpg'], (w: 3000, h: 4000));
  });

  test('formato personalizzato: misure tenute tra 200 e 6000', () {
    final s = documentoVuoto((
      indice: ratioPersonalizzato,
      larghezza: 9000,
      altezza: 50,
    ));
    expect(s.canvas.ratioIndex, ratioPersonalizzato);
    expect((s.canvas.frameW, s.canvas.frameH), (9000, 50));
    expect((s.canvas.customW, s.canvas.customH), (6000, 200));
  });

  test(
    'salva e riapre senza perdere niente, e non lascia file a metà',
    () async {
      final c = await crea('Uno');
      final p = await archivio.carica(c);
      // Campo sconosciuto in cima al file: si riscrive tale e quale
      final grezzo = jsonDecode(
        archivio.fileProgetto(c).readAsStringSync(),
      ) as Map<String, Object?>;
      grezzo['campo_futuro'] = {'a': 1};
      archivio.fileProgetto(c).writeAsStringSync(jsonEncode(grezzo));
      final letto = await archivio.carica(c);
      await archivio.salva(c, letto.file, letto.dati);
      final dopo = await archivio.carica(c);
      expect(dopo.file.snapshot, p.file.snapshot);
      expect(dopo.file.extra['campo_futuro'], {'a': 1});
      final nomi = c.listSync().map((e) => e.path.split(RegExp(r'[/\\]')).last);
      expect(nomi.where((n) => n.endsWith('.tmp')), isEmpty);
      expect(archivio.fileProgetto(c).existsSync(), isTrue);
    },
  );

  test('un file temporaneo rimasto non rovina il progetto', () async {
    final c = await crea('Due');
    File('${archivio.fileProgetto(c).path}.tmp').writeAsStringSync('{ a metà');
    expect((await archivio.carica(c)).file.snapshot.items.length, 12);
  });

  test('elenco: più recente prima, con nome e pagine', () async {
    final a = await crea('Vecchio', foto: 2);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await crea('Nuovo', foto: 2);
    final l = await archivio.elenco();
    expect(l.map((p) => p.nome), ['Nuovo', 'Vecchio']);
    expect(l.last.id, a.uri.pathSegments.where((s) => s.isNotEmpty).last);
    expect(l.first.pagine, 1);
  });

  test('rinomina, duplica ed elimina', () async {
    final c = await crea('Originale', foto: 3);
    File('${c.path}/miniatura.png').writeAsBytesSync([1, 2, 3]);
    await Directory('${c.path}/media').create();
    File('${c.path}/media/foto1.jpg').writeAsBytesSync([9]);
    Directory('${c.path}/cache').createSync();
    File('${c.path}/cache/x.img').writeAsBytesSync([7]);

    await archivio.rinomina(c, 'Rinominato');
    expect((await archivio.carica(c)).dati.nome, 'Rinominato');

    final copia = await archivio.duplica(c, 'Copia di Rinominato');
    expect(copia.path, isNot(c.path));
    final pc = await archivio.carica(copia);
    expect(pc.dati.nome, 'Copia di Rinominato');
    expect(pc.file.snapshot, (await archivio.carica(c)).file.snapshot);
    expect(File('${copia.path}/media/foto1.jpg').existsSync(), isTrue);
    // La cache si ricostruisce: non si copia
    expect(Directory('${copia.path}/cache').existsSync(), isFalse);

    await archivio.elimina(c);
    expect(c.existsSync(), isFalse);
    expect((await archivio.elenco()).length, 1);
  });

  test('un progetto non leggibile non è un errore dell\'elenco', () async {
    final c = await archivio.nuovaCartella();
    archivio.fileProgetto(c).writeAsStringSync('non è json');
    expect(
      (await archivio.elenco()).single.nome,
      c.uri.pathSegments[c.uri.pathSegments.length - 2],
    );
    expect(() => archivio.carica(c), throwsA(isA<ProjectFormatException>()));
  });
}
