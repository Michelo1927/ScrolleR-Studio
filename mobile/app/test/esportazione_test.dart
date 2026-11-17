import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart' hide Image;
import 'package:scrl_engine/scrl_engine.dart' hide Rect;
import 'package:scrollr_studio/editor/editor_page.dart';
import 'package:scrollr_studio/editor/sessione.dart';
import 'package:scrollr_studio/editor/stato.dart';
import 'package:scrollr_studio/editor/tela.dart';
import 'package:scrollr_studio/editor/widget_comuni.dart';
import 'package:scrollr_studio/export/codifica.dart';
import 'package:scrollr_studio/export/consegna.dart';
import 'package:scrollr_studio/export/esporta_immagini.dart';
import 'package:scrollr_studio/export/foglio_esporta.dart';
import 'package:scrollr_studio/export/preferenze.dart';
import 'package:scrollr_studio/l10n/app_localizations.dart';
import 'package:scrollr_studio/media/cache_media.dart';
import 'package:scrollr_studio/media/galleria.dart';
import 'package:scrollr_studio/project/archivio.dart';
import 'package:scrollr_studio/project/crea_progetto.dart';
import 'package:scrollr_studio/render/disegno.dart';
import 'package:scrollr_studio/theme/tema.dart';

/// Consegna finta: ricorda che cosa le arriva, senza toccare galleria, condivisione o File.
class ConsegnaFinta implements Consegna {
  final galleria = <({String nome, DateTime data, Uint8List dati})>[];
  final condivisi = <List<String>>[];
  final file = <String>[];
  Exception? errore;
  bool chiudiSelettore = false;

  @override
  Future<void> salvaInGalleria(
    Uint8List dati,
    String nome,
    DateTime data,
  ) async {
    final e = errore;
    if (e != null) throw e;
    galleria.add((nome: nome, data: data, dati: dati));
  }

  @override
  Future<void> condividi(List<File> files, bool jpg) async {
    // I file devono esistere ancora al momento della condivisione
    for (final f in files) {
      expect(f.existsSync(), isTrue, reason: f.path);
    }
    condivisi.add([for (final f in files) f.uri.pathSegments.last]);
  }

  @override
  Future<bool> salvaInFile(String nome, Uint8List dati, String mime) async {
    if (chiudiSelettore) return false;
    file.add(nome);
    return true;
  }
}

const _testi = TestiDisegno(fotoMancante: '', originaleMancante: '', di: '');

FotoScelta _foto(int i) => (
  voce: LibraryEntry(path: 'foto$i.png', rel: 'media/foto$i.png'),
  chiave: 'f:media/foto$i.png',
  w: 60,
  h: 80,
);

/// Foto di prova: un degradé diverso per ogni [i].
void _scriviFoto(String percorso, int i) {
  final im = img.Image(width: 60, height: 80);
  for (var y = 0; y < 80; y++) {
    for (var x = 0; x < 60; x++) {
      im.setPixelRgb(x, y, (x * 4 + i * 40) % 256, (y * 3) % 256, 200 - i * 20);
    }
  }
  File(percorso)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(im));
}

/// Progetto di prova su disco: pagine [larghezza] × [altezza], [foto] foto (file veri se [conFile]).
class _Progetto {
  late Directory radice;
  late Directory cartella;
  late Snapshot snapshot;
  late ArchivioProgetti archivio;
  late ProgettoCaricato caricato;

  Future<void> crea({
    int pagine = 3,
    int foto = 6,
    bool conFile = true,
    int larghezza = 400,
    int altezza = 500,
  }) async {
    radice = Directory.systemTemp.createTempSync('scrl_esporta_test');
    addTearDown(() {
      try {
        radice.deleteSync(recursive: true);
      } on FileSystemException {
        // Su Windows un file può essere ancora aperto: la cartella temporanea resta, non è un errore
      }
    });
    archivio = ArchivioProgetti(Directory('${radice.path}/progetti'));
    cartella = await archivio.nuovaCartella();
    if (conFile) {
      for (var i = 1; i <= foto; i++) {
        _scriviFoto('${cartella.path}/media/foto$i.png', i);
      }
    }
    final p = await creaProgetto(
      archivio: archivio,
      cartella: cartella,
      nome: 'Prova',
      formato: (
        indice: ratioPersonalizzato,
        larghezza: larghezza,
        altezza: altezza,
      ),
      scelte: [for (var i = 1; i <= foto; i++) _foto(i)],
    );
    var snap = p.file.snapshot;
    if (pagine > 1) {
      snap = setNumFrames(
        snap,
        pagine,
        EngineContext(imageSize: (_) => (w: 60, h: 80)),
      ).snapshot;
    }
    await archivio.salva(cartella, p.file.copyWith(snapshot: snap), p.dati);
    snapshot = snap;
    caricato = ProgettoCaricato(
      cartella,
      p.file.copyWith(snapshot: snap),
      p.dati,
    );
  }

  CacheMedia get cache =>
      CacheMedia(cartella: Directory('${cartella.path}/cache'));

  Directory temporanea() => Directory('${radice.path}/tmp')..createSync();
}

LavoroEsportazione _lavoro(
  _Progetto p,
  ConsegnaFinta consegna, {
  List<int> pagine = const [0],
  bool collage = false,
  OpzioniEsportazione opzioni = const OpzioniEsportazione(scala: 1),
  Destinazione destinazione = Destinazione.galleria,
  String nome = '',
  Directory? temp,
  List<bool>? schermo,
}) => LavoroEsportazione(
  richiesta: RichiestaEsportazione(
    snapshot: p.snapshot,
    pagine: pagine,
    collage: collage,
    opzioni: opzioni,
    nome: nome,
    destinazione: destinazione,
  ),
  cache: p.cache,
  cartellaProgetto: p.cartella.path,
  testi: _testi,
  cartellaTemporanea: temp ?? p.temporanea(),
  consegna: consegna,
  schermoAcceso: (v) async => schermo?.add(v),
);

img.Image _png(Uint8List dati) => img.decodePng(dati)!;

void main() {
  group('Codifica', () {
    Uint8List pixel(int w, int h) {
      final px = Uint8List(w * h * 4);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final o = (y * w + x) * 4;
          px[o] = (x * 7) % 256;
          px[o + 1] = (y * 11) % 256;
          px[o + 2] = (x + y) % 256;
          px[o + 3] = 255;
        }
      }
      return px;
    }

    test('PNG: si rilegge identico, senza perdite', () {
      final px = pixel(97, 131); // Misure dispari e più righe di una passata
      final png = codificaPng(px, 97, 131);
      expect(png.sublist(0, 8), [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]);
      final im = _png(png);
      expect((im.width, im.height), (97, 131));
      expect(im.getBytes(order: img.ChannelOrder.rgba), px);
    });

    test(
      'JPG: misure giuste e colori vicini; la qualità più bassa pesa meno',
      () {
        final px = pixel(64, 48);
        final alto = codificaJpg(px, 64, 48, 100);
        final basso = codificaJpg(px, 64, 48, 75);
        expect(alto.sublist(0, 2), [0xFF, 0xD8]);
        expect(basso.length, lessThan(alto.length));
        final im = img.decodeJpg(alto)!;
        expect((im.width, im.height), (64, 48));
        final p = im.getPixel(10, 10);
        expect(p.r.toInt(), closeTo(70, 12));
        expect(p.g.toInt(), closeTo(110, 12));
      },
    );

    test('striscia: le colonne vanno al loro posto, in un isolate', () async {
      const w = 30, h = 20;
      final c = await CodificatoreStriscia.avvia(
        larghezza: w * 3,
        altezza: h,
        formato: FormatoImmagine.png,
        qualita: 92,
      );
      Uint8List colonna(int r, int g, int b) {
        final px = Uint8List(w * h * 4);
        for (var i = 0; i < w * h; i++) {
          px.setRange(i * 4, i * 4 + 4, [r, g, b, 255]);
        }
        return px;
      }

      // Fuori ordine: conta la posizione, non l'ordine d'arrivo
      c.aggiungi(w * 2, w, colonna(0, 0, 255));
      c.aggiungi(0, w, colonna(255, 0, 0));
      c.aggiungi(w, w, colonna(0, 255, 0));
      final im = _png(await c.finisci());
      expect((im.width, im.height), (90, 20));
      for (final (x, r, g, b) in [
        (0, 255, 0, 0),
        (29, 255, 0, 0),
        (30, 0, 255, 0),
        (59, 0, 255, 0),
        (60, 0, 0, 255),
        (89, 0, 0, 255),
      ]) {
        final p = im.getPixel(x, 7);
        expect((p.r, p.g, p.b), (r, g, b), reason: 'x=$x');
      }
    });

    test(
      'striscia: una colonna fuori misura è un errore, non un file rotto',
      () async {
        final c = await CodificatoreStriscia.avvia(
          larghezza: 10,
          altezza: 10,
          formato: FormatoImmagine.jpg,
          qualita: 92,
        );
        c.aggiungi(5, 10, Uint8List(10 * 10 * 4)); // Esce dal bordo destro
        await expectLater(c.finisci(), throwsA(isA<StateError>()));
      },
    );
  });

  group('Preferenze', () {
    test('si ricordano tra una sessione e l\'altra', () async {
      final dir = Directory.systemTemp.createTempSync('scrl_pref_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final f = File('${dir.path}/impostazioni.json');
      final a = PreferenzeApp(f);
      expect(await a.esportazione(), const OpzioniEsportazione());
      expect(const OpzioniEsportazione().formato, FormatoImmagine.png);
      expect(const OpzioniEsportazione().qualita, 92);
      expect(const OpzioniEsportazione().scala, 2);
      const scelte = OpzioniEsportazione(
        formato: FormatoImmagine.jpg,
        qualita: 75,
        scala: 1,
      );
      await a.salvaEsportazione(scelte);
      expect(await PreferenzeApp(f).esportazione(), scelte);
    });

    test(
      'valori strani o file rovinato: predefiniti e valori validi',
      () async {
        final dir = Directory.systemTemp.createTempSync('scrl_pref_test');
        addTearDown(() => dir.deleteSync(recursive: true));
        final f = File('${dir.path}/impostazioni.json')
          ..writeAsStringSync(
            '{"export":{"format":"gif","quality":90,"scale":5}}',
          );
        final o = await PreferenzeApp(f).esportazione();
        expect(o.formato, FormatoImmagine.png);
        expect(o.qualita, 92);
        expect(o.scala, 2);
        f.writeAsStringSync('non è json');
        expect(
          await PreferenzeApp(f).esportazione(),
          const OpzioniEsportazione(),
        );
      },
    );

    test('le altre preferenze del file si conservano', () async {
      final dir = Directory.systemTemp.createTempSync('scrl_pref_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final f = File('${dir.path}/impostazioni.json')
        ..writeAsStringSync('{"altro":42}');
      await PreferenzeApp(f).salvaEsportazione(const OpzioniEsportazione());
      expect(f.readAsStringSync(), contains('"altro":42'));
    });
  });

  group('Esportazione di un progetto vero', () {
    testWidgets(
      'pagine separate in Galleria: dimensioni, nomi, ordine e schermo acceso',
      (tester) async {
        final p = _Progetto();
        final consegna = ConsegnaFinta();
        final schermo = <bool>[];
        late EsitoEsportazione e;
        await tester.runAsync(() async {
          await p.crea();
          e = await _lavoro(
            p,
            consegna,
            pagine: [0, 2],
            opzioni: const OpzioniEsportazione(scala: 2),
            nome: 'viaggio',
            schermo: schermo,
          ).esegui();
        });
        expect(e.stato, StatoEsito.fatto);
        expect((e.larghezza, e.altezza), (800, 1000));
        expect(e.salvati, ['viaggio_01.png', 'viaggio_03.png']);
        expect([for (final g in consegna.galleria) g.nome], e.salvati);
        // Date crescenti: nella galleria le pagine restano in sequenza
        expect(
          consegna.galleria[1].data.isAfter(consegna.galleria[0].data),
          isTrue,
        );
        for (final g in consegna.galleria) {
          final im = _png(g.dati);
          expect((im.width, im.height), (800, 1000));
          // C'è qualcosa oltre allo sfondo: le foto sono state disegnate
          final colori = {
            for (var x = 0; x < 800; x += 40)
              for (var y = 0; y < 1000; y += 40) im.getPixel(x, y).toString(),
          };
          expect(colori.length, greaterThan(3));
        }
        // Lo schermo resta acceso durante il lavoro e si rilascia alla fine
        expect(schermo, [true, false]);
      },
    );

    testWidgets('collage PNG = pagine PNG affiancate, pixel per pixel', (
      tester,
    ) async {
      final p = _Progetto();
      final consegna = ConsegnaFinta();
      late EsitoEsportazione pagine;
      late EsitoEsportazione collage;
      final salvati = <String, Uint8List>{};
      late Uint8List dati;
      await tester.runAsync(() async {
        await p.crea();
        pagine = await _lavoro(p, consegna, pagine: [0, 1, 2]).esegui();
        final c2 = ConsegnaFinta();
        collage = await _lavoro(p, c2, collage: true).esegui();
        dati = c2.galleria.single.dati;
        for (final g in consegna.galleria) {
          salvati[g.nome] = g.dati;
        }
        expect(c2.galleria.single.nome, 'collage_400x500_3pagine_1200x500.png');
      });
      expect(pagine.stato, StatoEsito.fatto);
      expect(collage.stato, StatoEsito.fatto);
      final grande = _png(dati);
      expect((grande.width, grande.height), (1200, 500));
      final bytesGrande = grande.getBytes(order: img.ChannelOrder.rgba);
      for (var k = 0; k < 3; k++) {
        final pagina = _png(salvati['frame_0${k + 1}.png']!);
        final b = pagina.getBytes(order: img.ChannelOrder.rgba);
        for (var y = 0; y < 500; y++) {
          final a = ((y * 1200) + k * 400) * 4;
          expect(
            bytesGrande.sublist(a, a + 400 * 4),
            b.sublist(y * 400 * 4, (y + 1) * 400 * 4),
            reason: 'pagina ${k + 1}, riga $y',
          );
        }
      }
    });

    testWidgets(
      'JPG: file leggero della qualità scelta; Condividi e Salva in File',
      (tester) async {
        final p = _Progetto();
        final consegna = ConsegnaFinta();
        late EsitoEsportazione condiviso;
        late EsitoEsportazione file;
        await tester.runAsync(() async {
          await p.crea();
          condiviso = await _lavoro(
            p,
            consegna,
            pagine: [0, 1],
            opzioni: const OpzioniEsportazione(
              formato: FormatoImmagine.jpg,
              qualita: 85,
              scala: 1,
            ),
            destinazione: Destinazione.condividi,
          ).esegui();
          file = await _lavoro(
            p,
            consegna,
            collage: true,
            opzioni: const OpzioniEsportazione(
              formato: FormatoImmagine.jpg,
              qualita: 75,
              scala: 1,
            ),
            destinazione: Destinazione.file,
          ).esegui();
        });
        expect(condiviso.stato, StatoEsito.fatto);
        expect(consegna.condivisi, [
          ['frame_01.jpg', 'frame_02.jpg'],
        ]);
        expect(file.stato, StatoEsito.fatto);
        expect(consegna.file, ['collage_400x500_3pagine_1200x500.jpg']);
      },
    );

    testWidgets(
      'Annulla: niente consegnato, cartella temporanea vuota, schermo rilasciato',
      (tester) async {
        final p = _Progetto();
        final consegna = ConsegnaFinta();
        final schermo = <bool>[];
        late EsitoEsportazione e;
        late Directory temp;
        await tester.runAsync(() async {
          await p.crea();
          temp = p.temporanea();
          final lavoro = _lavoro(
            p,
            consegna,
            pagine: [0, 1, 2],
            temp: temp,
            schermo: schermo,
          );
          // Annulla mentre si disegna la seconda pagina
          lavoro.avanzamento.addListener(() {
            final a = lavoro.avanzamento.value;
            if (a.fase == FaseEsportazione.pagina && a.indice == 2) {
              lavoro.annulla();
            }
          });
          e = await lavoro.esegui();
        });
        expect(e.stato, StatoEsito.annullato);
        expect(consegna.galleria, isEmpty);
        expect(temp.listSync(), isEmpty);
        expect(schermo, [true, false]);
      },
    );

    testWidgets(
      'Salva in File: se si chiude il selettore si smette, il resto resta dov\'è',
      (tester) async {
        final p = _Progetto();
        final consegna = ConsegnaFinta()..chiudiSelettore = true;
        late EsitoEsportazione e;
        await tester.runAsync(() async {
          await p.crea();
          e = await _lavoro(
            p,
            consegna,
            pagine: [0, 1],
            destinazione: Destinazione.file,
          ).esegui();
        });
        expect(e.stato, StatoEsito.annullato);
        expect(consegna.file, isEmpty);
      },
    );

    testWidgets('Galleria negata: errore chiaro, niente di salvato', (
      tester,
    ) async {
      final p = _Progetto();
      final consegna = ConsegnaFinta()..errore = const AccessoGalleriaNegato();
      late EsitoEsportazione e;
      await tester.runAsync(() async {
        await p.crea();
        e = await _lavoro(p, consegna).esegui();
      });
      expect(e.stato, StatoEsito.errore);
      expect(e.errore, isA<AccessoGalleriaNegato>());
    });

    testWidgets(
      'foto mancanti: si esporta lo stesso, senza segnaposto, e si contano',
      (tester) async {
        final p = _Progetto();
        final consegna = ConsegnaFinta();
        late EsitoEsportazione e;
        late int mancanti;
        late int mancantiPagina1;
        await tester.runAsync(() async {
          await p.crea(conFile: false);
          final s = SessioneEditor(
            archivio: p.archivio,
            cartella: p.cartella,
            cache: p.cache,
            galleria: const Galleria(),
            dati: p.caricato.dati,
            inizio: p.snapshot,
          );
          mancanti = await contaFotoMancanti(s, p.snapshot, const []);
          mancantiPagina1 = await contaFotoMancanti(s, p.snapshot, const [1]);
          e = await _lavoro(p, consegna).esegui();
        });
        expect(mancanti, 6);
        expect(mancantiPagina1, lessThan(mancanti));
        expect(e.stato, StatoEsito.fatto);
        final im = _png(consegna.galleria.single.dati);
        // Solo sfondo: nessun segnaposto «Foto mancante» nell'immagine esportata
        final colori = {
          for (var x = 0; x < 400; x += 20)
            for (var y = 0; y < 500; y += 20) im.getPixel(x, y).toString(),
        };
        expect(colori.length, 1);
      },
    );
  });

  group('Foglio Esporta', () {
    /// Editor aperto con consegna e preferenze finte.
    Future<
      ({
        _Progetto p,
        ConsegnaFinta consegna,
        PreferenzeApp pref,
        ProviderContainer Function() contenitore,
      })
    >
    apri(
      WidgetTester tester, {
      int pagine = 3,
      bool conFile = false,
      int larghezza = 400,
      int altezza = 500,
    }) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final p = _Progetto();
      late SessioneEditor s;
      await tester.runAsync(() async {
        await p.crea(
          pagine: pagine,
          conFile: conFile,
          larghezza: larghezza,
          altezza: altezza,
        );
        s = SessioneEditor(
          archivio: p.archivio,
          cartella: p.cartella,
          cache: p.cache,
          galleria: const Galleria(),
          dati: p.caricato.dati,
          inizio: p.snapshot,
          libreriaIniziale: p.caricato.file.library,
        );
      });
      final consegna = ConsegnaFinta();
      final pref = PreferenzeApp.inMemoria();
      final temp = p.temporanea();
      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('radice'),
          overrides: [
            consegnaProvider.overrideWithValue(consegna),
            preferenzeProvider.overrideWithValue(pref),
            cartellaTemporaneaProvider.overrideWithValue(() async => temp),
          ],
          child: MaterialApp(
            theme: temaScrl(),
            locale: const Locale('it'),
            supportedLocales: Testi.supportedLocales,
            localizationsDelegates: const [
              Testi.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            home: EditorPage(sessione: s),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (
        p: p,
        consegna: consegna,
        pref: pref,
        contenitore: () => ProviderScope.containerOf(
          tester.element(find.byType(TelaEditor, skipOffstage: false)),
        ),
      );
    }

    Future<void> apriFoglio(WidgetTester tester) async {
      await tester.tap(find.bySemanticsLabel('Esporta'));
      await tester.pumpAndSettle();
    }

    Future<void> attendi(WidgetTester tester, Finder f) async {
      for (var i = 0; i < 100 && f.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      expect(f, findsOneWidget);
    }

    testWidgets(
      'l\'icona Esporta apre il foglio: pagine tutte scelte, PNG 2× di partenza',
      (tester) async {
        await apri(tester);
        await apriFoglio(tester);
        for (var k = 0; k < 3; k++) {
          expect(find.byKey(ValueKey('esporta-pagina-$k')), findsOneWidget);
        }
        expect(find.text('Pagine separate'), findsOneWidget);
        expect(find.text('Questa pagina'), findsOneWidget);
        expect(find.text('Collage intero'), findsOneWidget);
        expect(find.text('Galleria'), findsOneWidget);
        expect(find.text('Condividi'), findsOneWidget);
        expect(find.text('Salva in File'), findsOneWidget);
        final info = tester.widget<Text>(
          find.byKey(const ValueKey('esporta-info')),
        );
        expect(info.data, contains('Esempio: frame_01.png'));
        expect(info.data, contains('800×1000 px'));
        // La qualità JPG compare solo con il JPG
        expect(find.byKey(const ValueKey('esporta-q92')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('esporta-jpg')));
        await tester.pump();
        expect(find.byKey(const ValueKey('esporta-q92')), findsOneWidget);
        for (final q in [100, 95, 85, 75]) {
          expect(find.byKey(ValueKey('esporta-q$q')), findsOneWidget);
        }
      },
    );

    testWidgets('su uno schermo stretto i nomi dei pulsanti non vanno a capo', (
      tester,
    ) async {
      await apri(tester);
      tester.view.physicalSize = const Size(720, 1600); // 360 dp di larghezza
      tester.view.devicePixelRatio = 2;
      await tester.pumpAndSettle();
      await apriFoglio(tester);
      for (final nome in ['Galleria', 'Condividi', 'Salva in File']) {
        // Una sola riga: l'altezza del testo è quella di una riga (14 dp circa, mai il doppio)
        expect(
          tester.getSize(find.text(nome)).height,
          lessThan(24),
          reason: nome,
        );
      }
    });

    testWidgets(
      'formato, qualità e scala si ricordano; nessuna pagina = destinazioni spente',
      (tester) async {
        final b = await apri(tester);
        await apriFoglio(tester);
        await tester.tap(find.byKey(const ValueKey('esporta-jpg')));
        await tester.pump(); // Compare la riga della qualità
        await tester.tap(find.byKey(const ValueKey('esporta-q75')));
        await tester.tap(find.byKey(const ValueKey('esporta-x1')));
        await tester.pump();
        final o = await tester.runAsync(b.pref.esportazione);
        expect(
          o,
          const OpzioniEsportazione(
            formato: FormatoImmagine.jpg,
            qualita: 75,
            scala: 1,
          ),
        );
        var info = tester.widget<Text>(
          find.byKey(const ValueKey('esporta-info')),
        );
        expect(info.data, contains('frame_01.jpg'));
        expect(info.data, contains('400×500 px'));
        // «Nessuna»: non si può esportare
        await tester.tap(find.byKey(const ValueKey('esporta-nessuna')));
        await tester.pump();
        info = tester.widget<Text>(find.byKey(const ValueKey('esporta-info')));
        expect(info.data, 'Scegli almeno una pagina');
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('esporta-galleria')),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.byKey(const ValueKey('esporta-tutte')));
        await tester.pump();
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('esporta-galleria')),
              )
              .onPressed,
          isNotNull,
        );
      },
    );

    testWidgets(
      'foto mancanti: avviso, poi avanzamento, esito e consegna in Galleria',
      (tester) async {
        final b = await apri(tester);
        final passi = b
            .contenitore()
            .read(editorProvider)
            .cronologia
            .states
            .length;
        await apriFoglio(tester);
        // Si toglie la pagina 2, si dà un nome ai file e si sceglie il JPG
        await tester.tap(find.byKey(const ValueKey('esporta-pagina-1')));
        await tester.pump();
        await tester.enterText(
          find.byKey(const ValueKey('esporta-nome')),
          'viaggio',
        );
        await tester.tap(find.byKey(const ValueKey('esporta-jpg')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('esporta-galleria')));
        await tester.pumpAndSettle();
        expect(find.text('Foto mancanti'), findsOneWidget);
        expect(find.textContaining('resteranno vuote'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('esporta-conferma')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await attendi(tester, find.byKey(const ValueKey('esportazione-fine')));
        expect(find.text('Esportazione completata'), findsOneWidget);
        expect(find.textContaining('album «ScrolleR Studio»'), findsOneWidget);
        expect(
          [for (final g in b.consegna.galleria) g.nome],
          ['viaggio_01.jpg', 'viaggio_03.jpg'],
        );
        // Il nome dei file vale per il progetto ed è un passo di cronologia
        final c = b.contenitore();
        expect(c.read(editorProvider).snapshot.canvas.exportName, 'viaggio');
        expect(c.read(editorProvider).cronologia.states.length, passi + 1);
        await tester.tap(find.byKey(const ValueKey('esportazione-fine')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('esportazione-fine')), findsNothing);
      },
    );

    testWidgets(
      'tela senza foto: avviso «Tela vuota»; Annulla non esporta niente',
      (tester) async {
        final b = await apri(tester, pagine: 1);
        b.contenitore().read(editorProvider.notifier).svuotaLaTela();
        await tester.pump();
        await apriFoglio(tester);
        await tester.tap(find.byKey(const ValueKey('esporta-condividi')));
        await tester.pumpAndSettle();
        expect(find.text('Tela vuota'), findsOneWidget);
        await tester.tap(find.text('Annulla').last);
        await tester.pumpAndSettle();
        expect(b.consegna.condivisi, isEmpty);
        expect(find.byKey(const ValueKey('esportazione-fine')), findsNothing);
      },
    );

    testWidgets('collage troppo grande a 2×: si propone 1×', (tester) async {
      final b = await apri(tester, pagine: 2, larghezza: 3000, altezza: 3000);
      await apriFoglio(tester);
      await tester.tap(find.byKey(const ValueKey('esporta-modo-collage')));
      await tester.pump();
      // Le miniature non servono più: si sceglie il collage intero
      expect(find.byKey(const ValueKey('esporta-pagina-0')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('esporta-galleria')));
      await tester.pumpAndSettle();
      expect(find.text('Collage troppo grande'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('12000×6000'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('esporta-usa-1x')));
      await tester.pumpAndSettle();
      // Passato a 1× si prosegue: le foto qui non ci sono, quindi arriva l'avviso successivo
      expect(find.text('Foto mancanti'), findsOneWidget);
      final o = await tester.runAsync(b.pref.esportazione);
      expect(o!.scala, 1);
      await tester.tap(find.text('Annulla').last);
      await tester.pumpAndSettle();
      expect(b.consegna.galleria, isEmpty);
    });

    testWidgets(
      '«Esporta questa» del pannello Pagine apre il foglio su una sola pagina',
      (tester) async {
        final b = await apri(tester);
        b.contenitore().read(editorProvider.notifier).vaiAPagina(1);
        await tester.pump();
        await tester.tap(find.widgetWithText(VoceBarra, 'Pagine'));
        await tester.pumpAndSettle();
        final tessera = find.byKey(const ValueKey('azione-esporta'));
        await tester.ensureVisible(tessera);
        await tester.tap(tessera);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('esporta-pagina-1')), findsOneWidget);
        expect(find.byKey(const ValueKey('esporta-pagina-0')), findsNothing);
        final info = tester.widget<Text>(
          find.byKey(const ValueKey('esporta-info')),
        );
        expect(info.data, contains('frame_02.png'));
      },
    );
  });
}
