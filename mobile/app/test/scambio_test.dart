import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart' show AssetEntity;
import 'package:scrl_engine/scrl_engine.dart';
import 'package:scrollr_studio/media/cache_media.dart';
import 'package:scrollr_studio/media/galleria.dart';
import 'package:scrollr_studio/project/archivio.dart';
import 'package:scrollr_studio/project/crea_progetto.dart';
import 'package:scrollr_studio/project/lavoro.dart';
import 'package:scrollr_studio/project/scambio.dart';
import 'package:scrollr_studio/project/zip.dart';
import 'package:scrollr_studio/render/regolazioni.dart';

/// Galleria finta: gli identificativi puntano a file veri sul disco; quelli senza file sono «cancellati».
class _GalleriaFinta extends Galleria {
  _GalleriaFinta(this.file);
  final Map<String, File> file;

  @override
  Future<AssetEntity?> entita(MediaAsset a) async {
    final f = file[a.id];
    if (a.platform != Galleria.piattaforma || f == null) return null;
    return AssetEntity(id: a.id, typeInt: 1, width: 40, height: 30);
  }

  @override
  Future<File?> originale(AssetEntity e) async {
    final f = file[e.id];
    return f != null && f.existsSync() ? f : null;
  }

  @override
  Future<void> pulisciTemporanei() async {}
}

Future<Uint8List> _png(int w, int h, int r) async {
  final px = Uint8List(w * h * 4);
  for (var i = 0; i < px.length; i += 4) {
    px[i] = r;
    px[i + 1] = (i ~/ 4) % 256;
    px[i + 2] = 80;
    px[i + 3] = 255;
  }
  final img = await immagineDaPixel(px, w, h);
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  return png!.buffer.asUint8List();
}

/// Foto di un progetto confrontabili tra telefono e telefono: tutto tranne i riferimenti al file.
Map<String, Object?> _senzaPercorsi(PhotoItem p) {
  final j = Map<String, Object?>.of(p.toJson());
  for (final k in ['path', 'rel', 'asset']) {
    j.remove(k);
  }
  return j;
}

void main() {
  late Directory radice;
  late ArchivioProgetti telefono;
  late ArchivioProgetti altro;
  late Directory cartellaTelefono;
  late _GalleriaFinta galleria;
  late Map<String, Uint8List> originali;

  setUp(() async {
    radice = Directory.systemTemp.createTempSync('scrl_scambio_test');
    telefono = ArchivioProgetti(Directory('${radice.path}/telefono'));
    altro = ArchivioProgetti(Directory('${radice.path}/altro'));
    Directory('${radice.path}/galleria').createSync();
    originali = {
      'IMG_1.jpg': await _png(40, 30, 10),
      'IMG_2.jpg': await _png(30, 40, 20),
      'c.png': await _png(36, 24, 30),
    };
    final f1 = File('${radice.path}/galleria/IMG_1.jpg')
      ..writeAsBytesSync(originali['IMG_1.jpg']!);
    // IMG_2 è stata cancellata dalla galleria: non c'è nessun file
    galleria = _GalleriaFinta({
      '11': f1,
      '22': File('${radice.path}/galleria/IMG_2.jpg'),
    });

    // Progetto sul telefono: due foto della galleria (una poi cancellata e senza anteprima) e una dentro il
    // progetto; di quest'ultima l'originale sparisce ma l'anteprima salvata resta
    cartellaTelefono = await telefono.nuovaCartella();
    MediaAsset asset(String id, String nome) =>
        MediaAsset(platform: Galleria.piattaforma, id: id, name: nome);
    await creaProgetto(
      archivio: telefono,
      cartella: cartellaTelefono,
      nome: 'Viaggio è bello',
      formato: (indice: 2, larghezza: 1080, altezza: 1350),
      scelte: [
        (
          voce: LibraryEntry(
            path: 'IMG_1.jpg',
            asset: asset('11', 'IMG_1.jpg'),
          ),
          chiave: 'a:${Galleria.piattaforma}:11',
          w: 40,
          h: 30,
        ),
        (
          voce: LibraryEntry(
            path: 'IMG_2.jpg',
            asset: asset('22', 'IMG_2.jpg'),
          ),
          chiave: 'a:${Galleria.piattaforma}:22',
          w: 30,
          h: 40,
        ),
        (
          voce: LibraryEntry(path: 'media/c.png', rel: 'media/c.png'),
          chiave: 'f:media/c.png',
          w: 36,
          h: 24,
        ),
      ],
    );
    Directory('${cartellaTelefono.path}/media').createSync();
    File('${cartellaTelefono.path}/media/c.png')
        .writeAsBytesSync(originali['c.png']!);
  });

  tearDown(() => radice.deleteSync(recursive: true));

  Future<PianoZip> piano() async => PianoZip.prepara(
    progetto: await telefono.carica(cartellaTelefono),
    galleria: galleria,
  );

  test('piano: originali della galleria e del progetto copiati, il resto segnalato', () async {
    final p = await piano();
    // IMG_2 è sparita e non ha anteprima: manca; le altre due si copiano
    expect(p.mancanti, ['IMG_2.jpg']);
    expect(p.soloAnteprima, isEmpty);
    expect(p.copiati, 2);
    expect(p.haProblemi, isTrue);
    expect(p.voci.map((v) => v.nome), [
      'Viaggio è bello.scrlproj',
      'media/IMG_1.jpg',
      'media/c.png',
    ]);
    expect(
      p.byteTotali,
      greaterThan(originali['IMG_1.jpg']!.length + originali['c.png']!.length),
    );
  });

  test(
    'foto senza originale ma con anteprima: va l\'anteprima, col nome giusto',
    () async {
      // L'anteprima di c.png si crea quando l'originale c'è ancora
      final cache = CacheMedia(
        cartella: Directory('${cartellaTelefono.path}/cache'),
      );
      final foto = PhotoItem(uid: 0, path: 'media/c.png', rel: 'media/c.png');
      await cache.carica(
        sorgenteDi(foto, cartellaTelefono.path),
        Dettaglio.anteprima,
      );
      File('${cartellaTelefono.path}/media/c.png').deleteSync();
      final p = await piano();
      expect(p.soloAnteprima, ['c.png']);
      expect(p.mancanti, ['IMG_2.jpg']);
      expect(p.voci.map((v) => v.nome), contains('media/c.png'));
      final zip = await p.scrivi(radice);
      final l = await LettoreZip.apri(zip);
      addTearDown(l.chiudi);
      final v = l.voci.firstWhere((v) => v.nome == 'media/c.png');
      final dest = File('${radice.path}/c-da-anteprima.png');
      await l.estrai(v, dest);
      // È un'immagine vera (PNG), non vuota
      expect(dest.readAsBytesSync().sublist(1, 4), [0x50, 0x4E, 0x47]);
    },
  );

  test('round trip telefono → zip → altro telefono', () async {
    final prima = await telefono.carica(cartellaTelefono);
    final zip = await (await piano()).scrivi(radice);
    expect(zip.path.endsWith('Viaggio è bello.zip'), isTrue);

    // Il progetto sul telefono non è cambiato: resta collegato alla galleria
    final dopoEsportazione = await telefono.carica(cartellaTelefono);
    expect(dopoEsportazione.file.encode(), prima.file.encode());
    expect(
      dopoEsportazione.file.snapshot.items.where((p) => p.asset != null),
      hasLength(2),
    );

    final avanzamenti = <double?>[];
    final esito = await importaProgetto(
      archivio: altro,
      sorgente: zip,
      avanza: (f, _) => avanzamenti.add(f),
    );
    expect(esito.nome, 'Viaggio è bello');
    expect(esito.fileEstratti, 2);
    expect(avanzamenti, isNotEmpty);

    final p = await altro.carica(esito.cartella);
    expect(p.dati.nome, 'Viaggio è bello');
    expect(p.dati.pagine, prima.dati.pagine);
    // Stesso documento, tranne i riferimenti ai file
    final a = prima.file.snapshot;
    final b = p.file.snapshot;
    expect(b.canvas.toJson(), a.canvas.toJson());
    expect(
      [for (final i in b.items) _senzaPercorsi(i)],
      [for (final i in a.items) _senzaPercorsi(i)],
    );
    expect(b.items.map((i) => i.asset), everyElement(isNull));
    // Percorsi relativi: gli stessi in rel e path, dentro media/
    final rel = {for (final i in b.items) i.uid: i.rel};
    expect(rel.values.where((r) => r != null), isNotEmpty);
    for (final i in b.items) {
      final r = i.rel;
      if (r == null) {
        // La foto cancellata: resta col nome, il desktop la mostra come «Foto mancante»
        expect(i.path, 'IMG_2.jpg');
        continue;
      }
      expect(r.startsWith('media/'), isTrue);
      expect(i.path, r);
      expect(sorgenteDi(i, esito.cartella.path).trovata, isTrue);
    }
    // Contenuto identico agli originali
    expect(
      File('${esito.cartella.path}/media/IMG_1.jpg').readAsBytesSync(),
      originali['IMG_1.jpg'],
    );
    expect(
      File('${esito.cartella.path}/media/c.png').readAsBytesSync(),
      originali['c.png'],
    );
    // Libreria coerente
    expect(p.file.library.every((e) => e.asset == null), isTrue);

    // E di nuovo: dall'altro telefono allo zip e a un terzo (i nomi non cambiano)
    final zip2 = await (await PianoZip.prepara(
      progetto: p,
      galleria: galleria,
    )).scrivi(radice);
    final l = await LettoreZip.apri(zip2);
    addTearDown(l.chiudi);
    expect(l.voci.map((v) => v.nome).toSet(), {
      'Viaggio è bello.scrlproj',
      'media/IMG_1.jpg',
      'media/c.png',
    });
  });

  test('il .scrlproj dentro lo zip si apre senza asset', () async {
    final zip = await (await piano()).scrivi(radice);
    final l = await LettoreZip.apri(zip);
    addTearDown(l.chiudi);
    final json = utf8.decode(await l.leggiInMemoria(l.voci.first));
    expect(json.contains('"asset"'), isFalse);
    final f = ProjectFile.parse(json);
    expect(f.version, 1);
    expect(f.snapshot.items.length, 3);
  });

  test('Annulla durante la scrittura non lascia lo zip', () async {
    final p = await piano();
    final stop = Annullamento()..annulla();
    await expectLater(
      p.scrivi(radice, annullamento: stop),
      throwsA(isA<LavoroAnnullato>()),
    );
    expect(radice.listSync().where((e) => e.path.endsWith('.zip')), isEmpty);
  });

  group('importazione', () {
    test('.scrlproj da solo: foto non trovate, asset scartati, nessuna cartella a metà se fallisce', () async {
      final f = File('${radice.path}/Mio progetto.scrlproj')
        ..writeAsStringSync(
          (await telefono.carica(cartellaTelefono)).file.encode(),
        );
      final esito = await importaProgetto(archivio: altro, sorgente: f);
      expect(esito.nome, 'Mio progetto');
      final p = await altro.carica(esito.cartella);
      expect(p.file.snapshot.items, hasLength(3));
      expect(p.file.snapshot.items.every((i) => i.asset == null), isTrue);
      // Le foto della galleria di un altro telefono ora sono mancanti, col loro nome
      final s = sorgenteDi(
        p.file.snapshot.items.firstWhere((i) => i.path == 'IMG_1.jpg'),
        esito.cartella.path,
      );
      expect(s.trovata, isFalse);

      final rotto = File('${radice.path}/rotto.scrlproj')
        ..writeAsStringSync('{"non": "un progetto"}');
      await expectLater(
        importaProgetto(archivio: altro, sorgente: rotto),
        throwsA(
          isA<ImportazioneNonRiuscita>().having(
            (e) => e.motivo,
            'motivo',
            MotivoImportazione.progettoNonValido,
          ),
        ),
      );
      final testo = File('${radice.path}/testo.txt')..writeAsStringSync('ciao');
      await expectLater(
        importaProgetto(archivio: altro, sorgente: testo),
        throwsA(isA<ImportazioneNonRiuscita>()),
      );
      // Solo il progetto importato prima: niente cartelle a metà
      expect((await altro.elenco()).length, 1);
    });

    test('zip fatto a mano: cartella in cima, scarti di sistema, nomi pericolosi, più progetti', () async {
      final progetto = (await telefono.carica(cartellaTelefono)).file;
      final json = utf8.encode(
        preparaPerCondivisione(progetto, {
          'a:${Galleria.piattaforma}:11': 'Foto/IMG_1.jpg',
        }).encode(),
      );
      final zip = File('${radice.path}/a-mano.zip');
      await scriviZip(zip, [
        VoceZip.dati('Viaggio/Viaggio.scrlproj', Uint8List.fromList(json)),
        VoceZip.dati('Viaggio/Foto/IMG_1.jpg', originali['IMG_1.jpg']!),
        VoceZip.dati('__MACOSX/Viaggio/._Viaggio.scrlproj', Uint8List(8)),
        VoceZip.dati('Viaggio/.DS_Store', Uint8List(8)),
        VoceZip.dati('../fuori.txt', Uint8List.fromList([1])),
        VoceZip.dati('Viaggio/../../fuori2.txt', Uint8List.fromList([1])),
        VoceZip.dati('Altro/Sotto/Altro.scrlproj', Uint8List.fromList(json)),
      ]);
      final esito = await importaProgetto(archivio: altro, sorgente: zip);
      expect(esito.nome, 'Viaggio');
      expect(esito.altriProgetti, 1);
      expect(esito.fileEstratti, 1);
      expect(
        File('${esito.cartella.path}/Foto/IMG_1.jpg').existsSync(),
        isTrue,
      );
      expect(File('${esito.cartella.path}/.DS_Store').existsSync(), isFalse);
      expect(File('${radice.path}/altro/fuori.txt').existsSync(), isFalse);
      expect(File('${radice.path}/fuori2.txt').existsSync(), isFalse);
      // Il rel `Foto/IMG_1.jpg` (come scrive il desktop) si trova
      final p = await altro.carica(esito.cartella);
      final i = p.file.snapshot.items.firstWhere(
        (i) => i.rel == 'Foto/IMG_1.jpg',
      );
      expect(sorgenteDi(i, esito.cartella.path).trovata, isTrue);
    });

    test(
      'zip senza progetto e Annulla: errore chiaro e nessuna cartella a metà',
      () async {
        final zip = File('${radice.path}/vuoto.zip');
        await scriviZip(zip, [
          VoceZip.dati('foto.jpg', originali['IMG_1.jpg']!),
        ]);
        await expectLater(
          importaProgetto(archivio: altro, sorgente: zip),
          throwsA(
            isA<ImportazioneNonRiuscita>().having(
              (e) => e.motivo,
              'motivo',
              MotivoImportazione.nessunProgetto,
            ),
          ),
        );
        final buono = await (await piano()).scrivi(radice);
        final stop = Annullamento()..annulla();
        await expectLater(
          importaProgetto(archivio: altro, sorgente: buono, annullamento: stop),
          throwsA(isA<LavoroAnnullato>()),
        );
        expect(await altro.elenco(), isEmpty);
        expect(
          altro.radice.existsSync()
              ? altro.radice.listSync().whereType<Directory>()
              : <Object>[],
          isEmpty,
        );
      },
    );
  });

  group('con il desktop vero', () {
    /// Se c'è la variabile SCRL_ZIP_USCITA gli zip prodotti qui si copiano in quella cartella: li apre
    /// `python mobile/tools/genera_riferimenti.py --verifica-zip` con il desktop vero.
    void consegna(File zip, String nome) {
      final uscita = Platform.environment['SCRL_ZIP_USCITA'];
      if (uscita == null) return;
      Directory(uscita).createSync(recursive: true);
      zip.copySync('$uscita/$nome');
    }

    test('PC → telefono: lo zip di «Raccogli progetto» del desktop si importa con tutte le foto', () async {
      final esito = await importaProgetto(
        archivio: altro,
        sorgente: File('test/riferimenti/progetto-desktop.zip'),
      );
      // Lo zip contiene la cartella intera: Progetto/Progetto.scrlproj + Progetto/Foto/*.png
      expect(esito.nome, 'Progetto');
      expect(esito.fileEstratti, 4);
      final p = await altro.carica(esito.cartella);
      final s = p.file.snapshot;
      expect(s.items, hasLength(4));
      expect(s.texts, hasLength(1));
      expect(s.shapes, hasLength(1));
      expect(s.canvas.numFrames, 2);
      expect(s.canvas.ratioIndex, 2);
      for (final i in s.items) {
        // `rel` come lo scrive il desktop; il `path` assoluto del PC non esiste sul telefono e non serve
        expect(i.rel, startsWith('Foto/'));
        expect(i.asset, isNull);
        expect(
          sorgenteDi(i, esito.cartella.path).trovata,
          isTrue,
          reason: i.path,
        );
        expect(
          sorgenteDi(i, esito.cartella.path).posizione.source,
          MediaSource.relative,
        );
      }
      // E di ritorno sul PC: stesse foto, stessi percorsi relativi
      final zip2 = await (await PianoZip.prepara(
        progetto: p,
        galleria: galleria,
      )).scrivi(radice);
      consegna(zip2, 'desktop-telefono.zip');
      final l = await LettoreZip.apri(zip2);
      addTearDown(l.chiudi);
      expect(l.voci.map((v) => v.nome).toSet(), {
        'Progetto.scrlproj',
        for (var i = 1; i <= 4; i++) 'Foto/Foto di viaggio $i.png',
      });
      final json = ProjectFile.parse(
        utf8.decode(await l.leggiInMemoria(l.voci.first)),
      );
      expect(json.snapshot.items.map((i) => i.rel), s.items.map((i) => i.rel));
    });

    test('telefono → PC: zip completo con foto della galleria (per la verifica col desktop)', () async {
      // Tutte le foto sono ancora in galleria
      File('${radice.path}/galleria/IMG_2.jpg')
          .writeAsBytesSync(originali['IMG_2.jpg']!);
      final p = await piano();
      expect(p.haProblemi, isFalse);
      final zip = await p.scrivi(radice);
      consegna(zip, 'telefono.zip');
      final l = await LettoreZip.apri(zip);
      addTearDown(l.chiudi);
      expect(l.voci.map((v) => v.nome).toSet(), {
        'Viaggio è bello.scrlproj',
        'media/IMG_1.jpg',
        'media/IMG_2.jpg',
        'media/c.png',
      });
    });
  });

  group('file ricevuti', () {
    test('classificazione per estensione e tipo MIME', () {
      FileRicevuto f(String n, [String? m]) =>
          FileRicevuto(percorso: '/x/$n', nome: n, mime: m);
      expect(f('a.zip').eProgetto, isTrue);
      expect(f('a.SCRLPROJ').eProgetto, isTrue);
      expect(f('qualcosa', 'application/zip').eProgetto, isTrue);
      expect(f('a.jpg').eMedia, isTrue);
      expect(f('a.HEIC').eMedia, isTrue);
      expect(f('clip.mp4').eMedia, isTrue);
      expect(f('x', 'image/png').eMedia, isTrue);
      expect(f('a.pdf').eMedia, isFalse);
      expect(f('a.zip').eMedia, isFalse);
    });

    test(
      'foto e video mandati da un\'altra app diventano un progetto',
      () async {
        final a = File('${radice.path}/ricevuta1.png')
          ..writeAsBytesSync(originali['IMG_1.jpg']!);
        final b = File('${radice.path}/ricevuta2.png')
          ..writeAsBytesSync(originali['c.png']!);
        final rotta = File('${radice.path}/rotta.jpg')
          ..writeAsStringSync('non sono un\'immagine');
        final esito = await creaProgettoDaFile(
          archivio: altro,
          nome: 'Progetto 1',
          file: [
            for (final f in [a, b, rotta])
              FileRicevuto(
                percorso: f.path,
                nome: f.uri.pathSegments.last,
                temporaneo: true,
              ),
          ],
        );
        expect(esito.foto, 2);
        expect(esito.scartati, ['rotta.jpg']);
        final p = await altro.carica(esito.cartella);
        expect(p.file.snapshot.items, hasLength(2));
        expect(p.file.snapshot.items.map((i) => i.rel), [
          'media/ricevuta1.png',
          'media/ricevuta2.png',
        ]);
        // Misure note: non servono letture all'apertura
        expect(p.dati.misure.length, 2);
        // I temporanei si tolgono
        expect(a.existsSync() || b.existsSync() || rotta.existsSync(), isFalse);
      },
    );
  });
}
