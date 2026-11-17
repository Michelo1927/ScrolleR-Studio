import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:scrollr_studio/project/lavoro.dart';
import 'package:scrollr_studio/project/zip.dart';

/// Python del computer, se c'è: serve a provare che gli `.zip` si leggono a vicenda (CI senza Python: prove saltate).
String? _python() {
  for (final nome in ['python', 'python3']) {
    try {
      final r = Process.runSync(nome, ['--version']);
      if (r.exitCode == 0) return nome;
    } on ProcessException {
      // Prossimo
    }
  }
  return null;
}

Uint8List _casuali(int n, int seme) {
  final b = Uint8List(n);
  var x = seme;
  for (var i = 0; i < n; i++) {
    x = (x * 1103515245 + 12345) & 0x7FFFFFFF;
    b[i] = x >> 16;
  }
  return b;
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('scrl_zip_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('CRC-32 come quello dello zip', () {
    expect(crc32(utf8.encode('123456789')), 0xCBF43926);
    expect(crc32(utf8.encode('6789'), crc32(utf8.encode('12345'))), 0xCBF43926);
  });

  test(
    'scrive e rilegge: file grandi a blocchi, vuoti, nomi accentati',
    () async {
      final grande = _casuali(300 * 1024 + 17, 1);
      final f = File('${tmp.path}/grande.bin')..writeAsBytesSync(grande);
      final vuoto = File('${tmp.path}/vuoto.txt')..writeAsBytesSync([]);
      final zip = File('${tmp.path}/a.zip');
      final visti = <int>[];
      await scriviZip(zip, [
        VoceZip.dati('Viaggio è bello.scrlproj', utf8.encode('{"a": "è"}')),
        VoceZip.file('media/grande.bin', f),
        VoceZip.file('media/vuoto.txt', vuoto),
      ], progresso: (fatti, _) => visti.add(fatti));
      expect(visti.last, grande.length + utf8.encode('{"a": "è"}').length);
      expect(visti, orderedEquals([...visti]..sort())); // Cresce sempre

      final l = await LettoreZip.apri(zip);
      addTearDown(l.chiudi);
      expect(l.voci.map((v) => v.nome), [
        'Viaggio è bello.scrlproj',
        'media/grande.bin',
        'media/vuoto.txt',
      ]);
      final testo = await l.leggiInMemoria(l.voci[0]);
      expect(utf8.decode(testo), '{"a": "è"}');
      final dest = File('${tmp.path}/fuori/grande.bin');
      final blocchi = <int>[];
      await l.estrai(l.voci[1], dest, progresso: blocchi.add);
      expect(dest.readAsBytesSync(), grande);
      expect(blocchi.length, greaterThan(3));
      await l.estrai(l.voci[2], File('${tmp.path}/fuori/vuoto.txt'));
      expect(File('${tmp.path}/fuori/vuoto.txt').lengthSync(), 0);
    },
  );

  test('Annulla toglie lo zip a metà', () async {
    final f = File('${tmp.path}/g.bin')..writeAsBytesSync(_casuali(500000, 2));
    final zip = File('${tmp.path}/b.zip');
    final stop = Annullamento();
    await expectLater(
      scriviZip(
        zip,
        [VoceZip.file('g.bin', f)],
        progresso: (fatti, _) {
          if (fatti > 100000) stop.annulla();
        },
        annullamento: stop,
      ),
      throwsA(isA<LavoroAnnullato>()),
    );
    expect(zip.existsSync(), isFalse);
  });

  test(
    'un byte cambiato si scopre dal CRC e il file a metà sparisce',
    () async {
      final zip = File('${tmp.path}/c.zip');
      await scriviZip(zip, [
        VoceZip.dati('x.bin', Uint8List.fromList(List.filled(1000, 7))),
      ]);
      final b = zip.readAsBytesSync();
      b[30 + 5 + 10] ^= 0xFF; // Dentro i dati
      zip.writeAsBytesSync(b);
      final l = await LettoreZip.apri(zip);
      addTearDown(l.chiudi);
      final dest = File('${tmp.path}/x.bin');
      await expectLater(
        l.estrai(l.voci.first, dest),
        throwsA(isA<ZipNonValido>()),
      );
      expect(dest.existsSync(), isFalse);
    },
  );

  test('file che non è uno zip, troncato o con ZIP64: errori chiari', () async {
    final no = File('${tmp.path}/no.zip')
      ..writeAsStringSync('non sono uno zip, davvero');
    await expectLater(LettoreZip.apri(no), throwsA(isA<ZipNonValido>()));
    final piccolo = File('${tmp.path}/p.zip')..writeAsBytesSync([1, 2, 3]);
    await expectLater(LettoreZip.apri(piccolo), throwsA(isA<ZipNonValido>()));
    final zip = File('${tmp.path}/t.zip');
    await scriviZip(zip, [VoceZip.dati('a.txt', utf8.encode('ciao'))]);
    final b = zip.readAsBytesSync();
    zip.writeAsBytesSync(b.sublist(0, b.length - 5)); // Senza la fine
    await expectLater(LettoreZip.apri(zip), throwsA(isA<ZipNonValido>()));
  });

  test('nomi pericolosi e scarti di sistema', () {
    expect(nomeSicuro('media/a.jpg'), 'media/a.jpg');
    expect(nomeSicuro(r'Foto\a.jpg'), 'Foto/a.jpg');
    expect(nomeSicuro('../fuori.txt'), isNull);
    expect(nomeSicuro('a/../../fuori.txt'), isNull);
    expect(nomeSicuro('/etc/passwd'), isNull);
    expect(nomeSicuro('C:/Windows/x'), isNull);
    expect(nomeSicuro(r'..\x'), isNull);
    expect(eScartoDiSistema('__MACOSX/._a'), isTrue);
    expect(eScartoDiSistema('Foto/.DS_Store'), isTrue);
    expect(eScartoDiSistema('Foto/a.jpg'), isFalse);
  });

  final py = _python();
  group('con Python (zipfile)', () {
    test('uno zip scritto qui si apre in Python, con CRC giusti', () async {
      final f = File('${tmp.path}/g.bin')
        ..writeAsBytesSync(_casuali(200000, 3));
      final zip = File('${tmp.path}/d.zip');
      await scriviZip(zip, [
        VoceZip.dati('Progetto è.scrlproj', utf8.encode('{"version": 1}')),
        VoceZip.file('media/g.bin', f),
      ]);
      final r = Process.runSync(py!, [
        '-I',
        '-c',
        'import sys, json, zipfile; z = zipfile.ZipFile(sys.argv[1]); '
            'assert z.testzip() is None; '
            'print(json.dumps([[i.filename, i.file_size] for i in z.infolist()]))',
        zip.path,
      ]);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(jsonDecode((r.stdout as String).trim()), [
        ['Progetto è.scrlproj', 14],
        ['media/g.bin', 200000],
      ]);
    }, skip: py == null ? 'Python non trovato' : false);

    test('uno zip di Python (deflate, cartelle) si legge qui', () async {
      final zip = File('${tmp.path}/e.zip');
      final r = Process.runSync(py!, [
        '-I',
        '-c',
        'import sys, zipfile\n'
            'z = zipfile.ZipFile(sys.argv[1], "w", zipfile.ZIP_DEFLATED)\n'
            'z.writestr("Cartella/", b"")\n'
            'z.writestr("Cartella/prova è.scrlproj", b"x" * 100000 + b"fine")\n'
            'z.writestr("Cartella/Foto/a.txt", "ciao")\n'
            'z.writestr("Cartella/Foto/vuoto.txt", b"")\n'
            'z.close()',
        zip.path,
      ]);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      final l = await LettoreZip.apri(zip);
      addTearDown(l.chiudi);
      final per = {for (final v in l.voci) v.nome: v};
      expect(
        per.keys,
        containsAll(['Cartella/Foto/a.txt', 'Cartella/prova è.scrlproj']),
      );
      expect(per['Cartella/']!.eCartella, isTrue);
      expect(per['Cartella/prova è.scrlproj']!.metodo, 8);
      final grande = await l.leggiInMemoria(per['Cartella/prova è.scrlproj']!);
      expect(grande.length, 100004);
      expect(utf8.decode(grande.sublist(100000)), 'fine');
      expect(
        utf8.decode(await l.leggiInMemoria(per['Cartella/Foto/a.txt']!)),
        'ciao',
      );
      final dest = File('${tmp.path}/o/a.txt');
      await l.estrai(per['Cartella/Foto/a.txt']!, dest);
      expect(dest.readAsStringSync(), 'ciao');
      await l.estrai(
        per['Cartella/Foto/vuoto.txt']!,
        File('${tmp.path}/o/v.txt'),
      );
    }, skip: py == null ? 'Python non trovato' : false);
  });
}
