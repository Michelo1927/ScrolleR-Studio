import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:photo_manager/photo_manager.dart' show AssetEntity;
import 'package:scrl_engine/scrl_engine.dart' hide Rect;
import 'package:scrollr_studio/editor/stato.dart';
import 'package:scrollr_studio/editor/tela.dart';
import 'package:scrollr_studio/export/consegna.dart';
import 'package:scrollr_studio/home/scambio_ui.dart';
import 'package:scrollr_studio/l10n/app_localizations.dart';
import 'package:scrollr_studio/main.dart';
import 'package:scrollr_studio/media/galleria.dart';
import 'package:scrollr_studio/project/archivio.dart';
import 'package:scrollr_studio/project/crea_progetto.dart';
import 'package:scrollr_studio/project/provider.dart';
import 'package:scrollr_studio/project/ricevuti.dart';
import 'package:scrollr_studio/project/scambio.dart';
import 'package:scrollr_studio/render/regolazioni.dart';

/// Galleria finta: gli identificativi puntano a file veri; quelli senza file sono «cancellati».
class _GalleriaFinta extends Galleria {
  _GalleriaFinta(this.file);
  final Map<String, File> file;

  @override
  Future<AssetEntity?> entita(MediaAsset a) async =>
      a.platform == Galleria.piattaforma && file.containsKey(a.id)
      ? AssetEntity(id: a.id, typeInt: 1, width: 40, height: 30)
      : null;

  @override
  Future<File?> originale(AssetEntity e) async {
    final f = file[e.id];
    return f != null && f.existsSync() ? f : null;
  }

  @override
  Future<Uint8List?> ridotta(AssetEntity e, int lato) async =>
      file[e.id]?.readAsBytesSync();

  @override
  Future<void> pulisciTemporanei() async {}
}

class _RicevitoreFinto implements Ricevitore {
  List<FileRicevuto> iniz = [];
  void Function(List<FileRicevuto>)? arrivo;

  @override
  Future<List<FileRicevuto>> iniziali() async {
    final l = iniz;
    iniz = [];
    return l;
  }

  @override
  void ascolta(void Function(List<FileRicevuto> file) alRicevere) =>
      arrivo = alRicevere;

  @override
  void smetti() => arrivo = null;
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

Future<void> _finoA(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 80 && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsWidgets);
}

void main() {
  test('peso leggibile con i decimali della lingua', () {
    final it = lookupTesti(const Locale('it'));
    final en = lookupTesti(const Locale('en'));
    expect(formatoDimensione(it, 840 * 1024), '840 KB');
    expect(formatoDimensione(it, (3.25 * (1 << 20)).round()), '3,3 MB');
    expect(formatoDimensione(en, (3.25 * (1 << 20)).round()), '3.3 MB');
    expect(formatoDimensione(it, (1.5 * (1 << 30)).round()), '1,5 GB');
  });

  late Directory radice;
  late ArchivioProgetti archivio;
  late _GalleriaFinta galleria;
  late _RicevitoreFinto ricevitore;
  late List<({File zip, bool esisteva, int byte})> condivisi;
  late Uint8List png1;
  late Uint8List png2;

  setUp(() {
    radice = Directory.systemTemp.createTempSync('scrl_scambio_ui_test');
    archivio = ArchivioProgetti(Directory('${radice.path}/progetti'));
    ricevitore = _RicevitoreFinto();
    condivisi = [];
  });
  tearDown(() {
    try {
      radice.deleteSync(recursive: true);
    } on FileSystemException {
      // Su Windows un file può restare aperto un attimo di più: è solo la cartella temporanea
    }
  });

  Future<void> avvia(
    WidgetTester tester, {
    List<List<FileRicevuto>> selezioni = const [],
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final prossime = [...selezioni];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          archivioProvider.overrideWithValue(archivio),
          galleriaProvider.overrideWithValue(galleria),
          ricevitoreProvider.overrideWithValue(ricevitore),
          cartellaTemporaneaProvider.overrideWithValue(
            () async => Directory('${radice.path}/tmp')..createSync(),
          ),
          condivisioneProgettoProvider.overrideWithValue((zip, nome) async {
            condivisi.add((
              zip: zip,
              esisteva: zip.existsSync(),
              byte: zip.existsSync() ? zip.lengthSync() : 0,
            ));
          }),
          selettoreFileProvider.overrideWithValue(
            (titolo) async =>
                prossime.isEmpty ? const [] : prossime.removeAt(0),
          ),
        ],
        child: const ScrollerStudioApp(lingua: Locale('it')),
      ),
    );
    await tester.pump();
  }

  /// Progetto sul telefono con due foto della galleria; la seconda può essere già stata cancellata.
  Future<Directory> creaProgettoTelefono(
    WidgetTester tester, {
    bool cancellaDue = false,
  }) async {
    late Directory c;
    await tester.runAsync(() async {
      png1 = await _png(40, 30, 10);
      png2 = await _png(30, 40, 20);
      final f1 = File('${radice.path}/IMG_1.jpg')..writeAsBytesSync(png1);
      final f2 = File('${radice.path}/IMG_2.jpg')..writeAsBytesSync(png2);
      galleria = _GalleriaFinta({'1': f1, '2': f2});
      c = await archivio.nuovaCartella();
      MediaAsset a(String id, String n) =>
          MediaAsset(platform: Galleria.piattaforma, id: id, name: n);
      await creaProgetto(
        archivio: archivio,
        cartella: c,
        nome: 'Viaggio',
        formato: (indice: 2, larghezza: 1080, altezza: 1350),
        scelte: [
          (
            voce: LibraryEntry(path: 'IMG_1.jpg', asset: a('1', 'IMG_1.jpg')),
            chiave: 'a:${Galleria.piattaforma}:1',
            w: 40,
            h: 30,
          ),
          (
            voce: LibraryEntry(path: 'IMG_2.jpg', asset: a('2', 'IMG_2.jpg')),
            chiave: 'a:${Galleria.piattaforma}:2',
            w: 30,
            h: 40,
          ),
        ],
      );
      if (cancellaDue) f2.deleteSync();
    });
    return c;
  }

  testWidgets(
    'Condividi progetto: avanzamento, zip con originali, foglio di sistema, temporaneo tolto',
    (tester) async {
      final cartellaTelefono = await creaProgettoTelefono(tester);
      await avvia(tester);
      await _finoA(tester, find.text('Viaggio'));
      await tester.longPress(find.text('Viaggio'));
      await tester.pumpAndSettle();
      // Il foglio dice quanto occupa il progetto (la cartella intera; le foto della galleria no)
      final byte = await tester.runAsync(
        () => archivio.spazioOccupato(cartellaTelefono),
      );
      await _finoA(tester, find.textContaining('sul telefono'));
      final peso = tester.widget<Text>(
        find.byKey(const ValueKey('progetto-peso')),
      );
      expect(peso.data, startsWith('Occupa '));
      expect(
        peso.data,
        byte! >= 1 << 20
            ? contains(',')
            : 'Occupa ${(byte / 1024).ceil()} KB sul telefono',
      );
      expect(
        find.textContaining('foto della galleria non sono contate'),
        findsOneWidget,
      );
      await tester.tap(find.text('Condividi progetto'));
      await tester.pump();
      await _finoA(tester, find.byKey(const ValueKey('lavoro-titolo')));
      expect(find.text('Progetto pronto'), findsOneWidget);
      expect(find.textContaining('2 file copiati'), findsOneWidget);
      // Il foglio Condividi ha ricevuto uno zip vero, poi tolto
      expect(condivisi, hasLength(1));
      expect(condivisi.single.esisteva, isTrue);
      expect(condivisi.single.byte, greaterThan(png1.length + png2.length));
      expect(condivisi.single.zip.existsSync(), isFalse);
      await tester.tap(find.byKey(const ValueKey('lavoro-fine')));
      await tester.pumpAndSettle();
      expect(find.text('Viaggio'), findsOneWidget);
    },
  );

  testWidgets(
    'Condividi progetto con un originale cancellato: avvisa e si può annullare',
    (tester) async {
      await creaProgettoTelefono(tester, cancellaDue: true);
      await avvia(tester);
      await _finoA(tester, find.text('Viaggio'));
      await tester.longPress(find.text('Viaggio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Condividi progetto'));
      await tester.pump();
      await _finoA(tester, find.byKey(const ValueKey('zip-continua')));
      expect(find.text('Foto senza originale'), findsOneWidget);
      expect(find.textContaining('1 file non c'), findsOneWidget);
      // Annulla: niente zip, né condivisione
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Annulla'),
        ),
      );
      await _finoA(tester, find.text('Operazione annullata'));
      expect(condivisi, isEmpty);
      await tester.tap(find.byKey(const ValueKey('lavoro-fine')));
      await tester.pumpAndSettle();
      // Di nuovo, e «Crea comunque»
      await tester.longPress(find.text('Viaggio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Condividi progetto'));
      await tester.pump();
      await _finoA(tester, find.byKey(const ValueKey('zip-continua')));
      await tester.tap(find.byKey(const ValueKey('zip-continua')));
      await _finoA(tester, find.text('Progetto pronto'));
      expect(condivisi, hasLength(1));
      expect(find.textContaining('1 file copiato'), findsOneWidget);
    },
  );

  testWidgets(
    'Importa dalla Home: zip del telefono → progetto → si apre nell\'editor',
    (tester) async {
      final c = await creaProgettoTelefono(tester);
      late File zip;
      await tester.runAsync(() async {
        final p = await archivio.carica(c);
        final piano = await PianoZip.prepara(progetto: p, galleria: galleria);
        zip = await piano.scrivi(radice);
        await archivio.elimina(c); // Come se arrivasse da un altro telefono
      });
      await avvia(
        tester,
        selezioni: [
          [
            FileRicevuto(
              percorso: zip.path,
              nome: 'Viaggio.zip',
              temporaneo: true,
            ),
          ],
        ],
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const ValueKey('home-importa')));
      await tester.pump();
      await _finoA(tester, find.byKey(const ValueKey('lavoro-apri')));
      expect(find.text('«Viaggio» è stato importato'), findsOneWidget);
      expect(find.textContaining('2 foto e video importati'), findsOneWidget);
      // Il file temporaneo si toglie
      expect(zip.existsSync(), isFalse);
      await tester.tap(find.byKey(const ValueKey('lavoro-apri')));
      await _finoA(tester, find.byType(TelaEditor));
      await tester.pumpAndSettle();
      final contenitore = ProviderScope.containerOf(
        tester.element(find.byType(TelaEditor)),
      );
      expect(contenitore.read(editorProvider).snapshot.items.length, 2);
    },
  );

  testWidgets('file non valido: messaggio chiaro e niente progetto', (
    tester,
  ) async {
    await creaProgettoTelefono(tester);
    final strano = File('${radice.path}/strano.zip')
      ..writeAsStringSync('non sono uno zip');
    await avvia(
      tester,
      selezioni: [
        [FileRicevuto(percorso: strano.path, nome: 'strano.zip')],
      ],
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('home-importa')));
    await tester.pump();
    await _finoA(tester, find.byKey(const ValueKey('lavoro-esito')));
    expect(find.textContaining('rovinato'), findsOneWidget);
    expect(strano.existsSync(), isTrue); // Un file dell'utente non si tocca mai
    await tester.tap(find.byKey(const ValueKey('lavoro-fine')));
    await tester.pumpAndSettle();
    expect((await tester.runAsync(archivio.elenco))!.length, 1);
  });

  testWidgets(
    '«Apri con»: lo zip con cui l\'app si avvia viene importato da solo',
    (tester) async {
      final c = await creaProgettoTelefono(tester);
      late File zip;
      await tester.runAsync(() async {
        zip = await (await PianoZip.prepara(
          progetto: await archivio.carica(c),
          galleria: galleria,
        )).scrivi(radice);
      });
      ricevitore.iniz = [
        FileRicevuto(
          percorso: zip.path,
          nome: 'Dal PC.zip',
          mime: 'application/zip',
          temporaneo: true,
        ),
      ];
      await avvia(tester);
      await _finoA(tester, find.byKey(const ValueKey('lavoro-apri')));
      expect(find.text('«Viaggio» è stato importato'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('lavoro-fine')));
      await tester.pumpAndSettle();
      expect((await tester.runAsync(archivio.elenco))!.length, 2);
    },
  );

  testWidgets(
    '«Condividi con»: foto arrivate con l\'app aperta diventano un progetto nuovo',
    (tester) async {
      await creaProgettoTelefono(tester);
      await avvia(tester);
      await _finoA(tester, find.text('Viaggio'));
      late List<FileRicevuto> arrivate;
      await tester.runAsync(() async {
        final a = File('${radice.path}/r1.png')..writeAsBytesSync(png1);
        final b = File('${radice.path}/r2.png')..writeAsBytesSync(png2);
        arrivate = [
          FileRicevuto(
            percorso: a.path,
            nome: 'r1.png',
            mime: 'image/png',
            temporaneo: true,
          ),
          FileRicevuto(
            percorso: b.path,
            nome: 'r2.png',
            mime: 'image/png',
            temporaneo: true,
          ),
        ];
      });
      ricevitore.arrivo!(arrivate);
      await _finoA(tester, find.byKey(const ValueKey('lavoro-apri')));
      expect(find.text('Progetto creato con 2 foto'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('lavoro-apri')));
      await _finoA(tester, find.byType(TelaEditor));
      await tester.pumpAndSettle();
      final c = ProviderScope.containerOf(
        tester.element(find.byType(TelaEditor)),
      );
      expect(c.read(editorProvider).snapshot.items.map((p) => p.rel), [
        'media/r1.png',
        'media/r2.png',
      ]);
    },
  );
}
