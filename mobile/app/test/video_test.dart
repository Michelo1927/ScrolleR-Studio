// Fase 8 (video completo): riproduzione sulla tela, strumenti Video (Taglia, Copertina, Audio, Riproduci),
// etichetta con durata e muto, pagine con video esportate in MP4 (con file a metà eliminati).
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;
import 'package:scrl_video/scrl_video.dart';
import 'package:scrollr_studio/editor/editor_page.dart';
import 'package:scrollr_studio/editor/sessione.dart';
import 'package:scrollr_studio/editor/stato.dart';
import 'package:scrollr_studio/editor/tela.dart';
import 'package:scrollr_studio/editor/widget_comuni.dart';
import 'package:scrollr_studio/export/consegna.dart';
import 'package:scrollr_studio/export/esporta_immagini.dart';
import 'package:scrollr_studio/export/preferenze.dart';
import 'package:scrollr_studio/export/video_pagina.dart';
import 'package:scrollr_studio/l10n/app_localizations.dart';
import 'package:scrollr_studio/media/cache_media.dart';
import 'package:scrollr_studio/media/galleria.dart';
import 'package:scrollr_studio/media/riproduzione_video.dart';
import 'package:scrollr_studio/project/archivio.dart';
import 'package:scrollr_studio/render/disegno.dart';
import 'package:scrollr_studio/render/risorse_pagina.dart';
import 'package:scrollr_studio/theme/tema.dart';

import 'aiuto_barra.dart';

const _info = InfoVideo(
  larghezza: 64,
  altezza: 48,
  durata: 10,
  fps: 30,
  audio: true,
);

const _testi = TestiDisegno(
  fotoMancante: '',
  originaleMancante: '',
  di: '',
  muto: 'muto',
);

/// Lettore finto: fotogrammi 4 × 3 di un colore che dipende dal tempo; ricorda i tempi chiesti.
class _LettoreFinto implements LettoreVideo {
  final tempi = <double>[];
  bool chiuso = false;

  @override
  Future<Fotogramma?> a(double t) async {
    tempi.add(t);
    final px = Uint8List(4 * 3 * 4);
    for (var i = 0; i < px.length; i += 4) {
      px[i] = (t * 20).round() % 256;
      px[i + 3] = 255;
    }
    return Fotogramma(4, 3, px);
  }

  @override
  Future<void> chiudi() async => chiuso = true;
}

/// Progetto su disco con un video (file finto, ma presente) e una foto mancante sulla seconda pagina.
class _Progetto {
  late Directory radice;
  late Directory cartella;

  void crea() {
    radice = Directory.systemTemp.createTempSync('scrl_video_test');
    addTearDown(() {
      try {
        radice.deleteSync(recursive: true);
      } on FileSystemException {
        // Su Windows un file può essere ancora aperto
      }
    });
    cartella = Directory('${radice.path}/progetto')..createSync();
    File('${cartella.path}/media/v.mp4')
      ..createSync(recursive: true)
      ..writeAsBytesSync([0, 1, 2, 3]);
  }

  CacheMedia get cache =>
      CacheMedia(cartella: Directory('${cartella.path}/cache'));
}

PhotoItem _video({int uid = 1, double x = 100}) => PhotoItem(
  uid: uid,
  path: 'media/v.mp4',
  rel: 'media/v.mp4',
  isVideo: true,
  x: x,
  y: 100,
  w: 600,
  h: 800,
  z: 1,
);

Snapshot _documento() => Snapshot(
  canvas: CanvasState(numFrames: 2, layoutSeed: 1),
  items: [
    _video(),
    PhotoItem(
      uid: 2,
      path: 'media/foto.jpg',
      rel: 'media/foto.jpg',
      x: 1180,
      y: 100,
      w: 600,
      h: 800,
    ),
  ],
);

/// Consegna finta che ricorda i nomi.
class _Consegna implements Consegna {
  final galleria = <String>[];
  final video = <String>[];
  final mimeFile = <String>[];

  @override
  Future<void> salvaInGalleria(Uint8List d, String nome, DateTime t) async =>
      galleria.add(nome);

  @override
  Future<void> salvaVideoInGalleria(File f, String nome, DateTime t) async {
    expect(f.existsSync(), isTrue);
    video.add(nome);
  }

  @override
  Future<void> condividi(List<File> file, bool jpg) async {}

  @override
  Future<bool> salvaInFile(String nome, Uint8List dati, String mime) async {
    mimeFile.add('$nome $mime');
    return true;
  }
}

void main() {
  group('Riproduzione sulla tela', () {
    testWidgets('parte, segue il taglio, si ferma e torna la copertina', (
      tester,
    ) async {
      final p = _Progetto()..crea();
      final risorse = RisorsePagina(
        cache: p.cache,
        cartellaProgetto: p.cartella.path,
        leggiInfo: (_) async => _info,
      );
      final lettore = _LettoreFinto();
      final errori = <int>[];
      final r = RiproduzioneVideo(
        risorse: risorse,
        cache: p.cache,
        cartellaProgetto: p.cartella.path,
        apriLettore: (_) async => lettore,
        onErrore: errori.add,
      );
      final v = conTaglio(_video(), 2, 5, 10);
      final s = Snapshot(canvas: CanvasState(layoutSeed: 1), items: [v]);
      await tester.runAsync(() async {
        r.sincronizza(s, {1});
        expect(risorse.etichettaVideo(v)!.inRiproduzione, isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      expect(r.attivi, {1});
      expect(risorse.fotogrammi.containsKey(1), isTrue);
      expect(risorse.foto(v)!.immagine.width, 4);
      // Sempre dentro il taglio 2–5 s, dall'inizio
      expect(lettore.tempi.first, closeTo(2.0, 0.05));
      expect(lettore.tempi.every((t) => t >= 2.0 && t < 5.0), isTrue);
      // Il video sparisce dal documento (eliminato, annullato…): si ferma
      r.sincronizza(s.copyWith(items: []), {1});
      expect(r.attivi, isEmpty);
      expect(risorse.fotogrammi, isEmpty);
      expect(risorse.etichettaVideo(v)!.inRiproduzione, isFalse);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      expect(lettore.chiuso, isTrue);
      expect(errori, isEmpty);
      r.chiudi();
      await tester.pump(const Duration(seconds: 1)); // Fotogramma liberato
    });

    testWidgets('un video che non si apre si ferma e lo dice', (tester) async {
      final p = _Progetto()..crea();
      final risorse = RisorsePagina(
        cache: p.cache,
        cartellaProgetto: p.cartella.path,
      );
      final errori = <int>[];
      final r = RiproduzioneVideo(
        risorse: risorse,
        cache: p.cache,
        cartellaProgetto: p.cartella.path,
        apriLettore: (_) async => throw const ErroreVideo('rotto'),
        onErrore: errori.add,
      );
      await tester.runAsync(() async {
        r.sincronizza(
          Snapshot(canvas: CanvasState(layoutSeed: 1), items: [_video()]),
          {1},
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      expect(errori, [1]);
      expect(r.attivi, isEmpty);
      r.chiudi();
    });
  });

  test('etichetta: durata del taglio e muto', () {
    final p = _Progetto()..crea();
    final risorse = RisorsePagina(
      cache: p.cache,
      cartellaProgetto: p.cartella.path,
    );
    final v = conTaglio(_video(), 1, 4.5, 10);
    expect(risorse.etichettaVideo(v)!.muto, isTrue); // Audio ancora non noto
    risorse.ricordaInfoVideo(v, _info);
    final e = risorse.etichettaVideo(v)!;
    expect(e.durata, closeTo(3.5, 1e-9));
    expect(e.muto, isFalse);
    expect(formatoTempo(e.durata), '0:03,5');
    expect(risorse.etichettaVideo(conAudio(v, false))!.muto, isTrue);
    expect(risorse.etichettaVideo(PhotoItem(uid: 3, path: 'a.jpg')), isNull);
  });

  group('Strumenti Video nell\'editor', () {
    late _Progetto progetto;
    late _LettoreFinto lettore;

    Future<ProviderContainer> apri(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      progetto = _Progetto()..crea();
      lettore = _LettoreFinto();
      late SessioneEditor s;
      await tester.runAsync(() async {
        final archivio = ArchivioProgetti(Directory(progetto.radice.path));
        s = SessioneEditor(
          archivio: archivio,
          cartella: progetto.cartella,
          cache: progetto.cache,
          galleria: const Galleria(),
          dati: const DatiAccessori(nome: 'Prova', misure: {}),
          inizio: _documento(),
          leggiInfoVideo: (_) async => _info,
          apriLettoreVideo: (_) async => lettore,
        );
      });
      await tester.pumpWidget(
        ProviderScope(
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
      // Durata e audio del video letti (sotto carico la lettura può arrivare dopo la prima pagina disegnata)
      await tester.runAsync(() => s.risorse.caricaInfoVideo(_video()));
      await tester.pump();
      return ProviderScope.containerOf(tester.element(find.byType(TelaEditor)));
    }

    testWidgets('barra del video: Riproduci, Taglia, Copertina, Audio; '
        'niente colori', (tester) async {
      final c = await apri(tester);
      final ctrl = c.read(editorProvider.notifier);
      ctrl.seleziona([(tipo: ElementKind.photo, uid: 1)]);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('cat-video')));
      await tester.pump();
      for (final k in ['riproduci', 'taglia', 'copertina', 'audio']) {
        expect(find.byKey(ValueKey('voce-$k')), findsOneWidget, reason: k);
      }
      final voci = await vociBarra(tester);
      expect(voci, isNot(contains('Filtri')));
      expect(voci, isNot(contains('Regola')));
      // La foto da sola non ha gli strumenti Video
      ctrl.seleziona([(tipo: ElementKind.photo, uid: 2)]);
      await tester.pump();
      expect(find.byKey(const ValueKey('cat-video')), findsNothing);
    });

    testWidgets('Audio: un tocco = un passo, con il nome giusto', (
      tester,
    ) async {
      final c = await apri(tester);
      final ctrl = c.read(editorProvider.notifier);
      ctrl.seleziona([(tipo: ElementKind.photo, uid: 1)]);
      await tester.pump();
      final passi = c.read(editorProvider).cronologia.states.length;
      await tester.tap(find.byKey(const ValueKey('cat-video')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('voce-audio')));
      await tester.pump();
      final st = c.read(editorProvider);
      expect(st.snapshot.items.first.muted, isTrue);
      expect(st.cronologia.states.length, passi + 1);
      expect(st.cronologia.labels.last.kind, ChangeKind.videoAudio);
    });

    testWidgets('Taglia: bozza mentre si scorre, un passo con ✓', (
      tester,
    ) async {
      final c = await apri(tester);
      final ctrl = c.read(editorProvider.notifier);
      ctrl.seleziona([(tipo: ElementKind.photo, uid: 1)]);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('cat-video')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('voce-taglia')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('video-inizio')), findsOneWidget);
      // Fine = durata: la scheda Fine mostra il cursore a fondo
      await tester.tap(find.byKey(const ValueKey('video-fine')));
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(CursoreGrande),
          matching: find.textContaining('0:10'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Durata 0:10'), findsOneWidget);
      final passi = c.read(editorProvider).cronologia.states.length;
      ctrl.modificaVideoSelezionati((p, d) => conInizio(p, 2.5, d));
      ctrl.modificaVideoSelezionati((p, d) => conFine(p, 6, d));
      await tester.pump();
      expect(c.read(editorProvider).bozza, isNotNull);
      expect(c.read(editorProvider).cronologia.states.length, passi);
      ctrl.confermaEChiudi();
      await tester.pumpAndSettle();
      final st = c.read(editorProvider);
      final v = st.snapshot.items.first;
      expect((v.trimStart, v.trimEnd), (2.5, 6.0));
      expect(st.cronologia.states.length, passi + 1);
      expect(st.cronologia.labels.last.kind, ChangeKind.videoTrim);
      // La Fine a fondo torna «fino alla fine» (null), come set_trim
      ctrl.modificaVideoSelezionati((p, d) => conFine(p, 10, d));
      ctrl.conferma();
      expect(c.read(editorProvider).snapshot.items.first.trimEnd, isNull);
    });

    testWidgets('Copertina: il secondo scelto entra con ✓ e ferma la '
        'riproduzione', (tester) async {
      final c = await apri(tester);
      final ctrl = c.read(editorProvider.notifier);
      ctrl.seleziona([(tipo: ElementKind.photo, uid: 1)]);
      ctrl.alternaRiproduzione();
      expect(c.read(editorProvider).videoInRiproduzione, {1});
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('cat-video')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('voce-copertina')));
      await tester.pumpAndSettle();
      expect(c.read(editorProvider).videoInRiproduzione, isEmpty);
      ctrl.modificaVideoSelezionati((p, d) => conCopertina(p, 3.4, d));
      ctrl.confermaEChiudi();
      await tester.pumpAndSettle();
      final st = c.read(editorProvider);
      expect(st.snapshot.items.first.poster, 3.4);
      expect(st.cronologia.labels.last.kind, ChangeKind.videoPoster);
    });

    testWidgets('Riproduci / Pausa; un video eliminato si ferma', (
      tester,
    ) async {
      final c = await apri(tester);
      final ctrl = c.read(editorProvider.notifier);
      ctrl.seleziona([(tipo: ElementKind.photo, uid: 1)]);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('cat-video')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('voce-riproduci')));
      await tester.pump();
      expect(c.read(editorProvider).videoInRiproduzione, {1});
      expect(find.text('Pausa'), findsOneWidget);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();
      expect(lettore.tempi, isNotEmpty);
      // Riproduzione e Pausa non sono passi di cronologia
      expect(c.read(editorProvider).puoAnnullare, isFalse);
      ctrl.eliminaSelezione();
      await tester.pump();
      expect(c.read(editorProvider).videoInRiproduzione, isEmpty);
      // Annulla: il video torna, fermo
      ctrl.annulla();
      await tester.pump();
      expect(c.read(editorProvider).videoInRiproduzione, isEmpty);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      expect(lettore.chiuso, isTrue);
      await tester.pump(const Duration(seconds: 1)); // Fotogrammi liberati
    });

    testWidgets('a ogni passo il video rientra in una sola pagina', (
      tester,
    ) async {
      final c = await apri(tester);
      final ctrl = c.read(editorProvider.notifier);
      final s = c.read(editorProvider).snapshot;
      // Spostato a cavallo tra pagina 1 e 2: 420 unità nella seconda, 180 nella prima
      ctrl.conferma(
        s.copyWith(
          items: [s.items.first.copyWith(x: 900, free: true), s.items.last],
        ),
      );
      await tester.pump();
      final v = c.read(editorProvider).snapshot.items.first;
      expect(v.cellRect.left, greaterThanOrEqualTo(1080));
      expect(v.cellRect.right, lessThanOrEqualTo(2160));
      expect(
        c.read(editorProvider).avviso?.notice?.kind,
        NoticeKind.videoKeptInPage,
      );
    });
  });

  group('Esportazione MP4', () {
    var ultimeFasi = <FaseEsportazione>[];
    Future<EsitoEsportazione> esporta(
      WidgetTester tester,
      _Consegna consegna, {
      required EsportaPaginaVideo video,
      bool disponibile = true,
      List<int> pagine = const [0, 1],
      Destinazione destinazione = Destinazione.galleria,
    }) async {
      final p = _Progetto()..crea();
      final temp = Directory('${p.radice.path}/tmp')..createSync();
      final lavoro = LavoroEsportazione(
        richiesta: RichiestaEsportazione(
          snapshot: _documento(),
          pagine: pagine,
          collage: false,
          opzioni: const OpzioniEsportazione(scala: 1),
          nome: 'viaggio',
          destinazione: destinazione,
        ),
        cache: p.cache,
        cartellaProgetto: p.cartella.path,
        testi: _testi,
        cartellaTemporanea: temp,
        consegna: consegna,
        schermoAcceso: (_) async {},
        esportaVideo: video,
        videoDisponibile: () async => disponibile,
      );
      final fasi = <FaseEsportazione>[];
      lavoro.avanzamento.addListener(
        () => fasi.add(lavoro.avanzamento.value.fase),
      );
      final e = (await tester.runAsync(lavoro.esegui))!;
      ultimeFasi = fasi;
      // La cartella temporanea si svuota sempre
      expect(temp.listSync(), isEmpty);
      return e;
    }

    /// MP4 finto: scrive il file e segnala qualche fotogramma.
    Future<EsitoVideo> mp4Finto({
      required Snapshot s,
      required int k,
      required String percorso,
      required CacheMedia cache,
      required String cartellaProgetto,
      required TestiDisegno testi,
      void Function(int fatti, int totale)? avanzamento,
      bool Function()? annullato,
    }) async {
      File(percorso).writeAsBytesSync([1, 2, 3]);
      for (var i = 1; i <= 3; i++) {
        avanzamento?.call(i, 3);
      }
      return const EsitoVideo(true, fotogrammi: 3);
    }

    testWidgets('la pagina con video diventa MP4, le altre immagini, in '
        'ordine', (tester) async {
      final consegna = _Consegna();
      final e = await esporta(tester, consegna, video: mp4Finto);
      expect(e.stato, StatoEsito.fatto);
      expect(ultimeFasi, contains(FaseEsportazione.video));
      expect(e.salvati, ['viaggio_01.mp4', 'viaggio_02.png']);
      expect(consegna.video, ['viaggio_01.mp4']);
      expect(consegna.galleria, ['viaggio_02.png']);
      expect(e.mp4, 1);
      expect((e.videoLarghezza, e.videoAltezza), (1080, 1440));
    });

    testWidgets('Salva in File: l\'MP4 con il suo tipo', (tester) async {
      final consegna = _Consegna();
      await esporta(
        tester,
        consegna,
        video: mp4Finto,
        pagine: const [0],
        destinazione: Destinazione.file,
      );
      expect(consegna.mimeFile, ['viaggio_01.mp4 video/mp4']);
    });

    testWidgets('annullata a metà: niente MP4 a metà, niente consegna', (
      tester,
    ) async {
      final consegna = _Consegna();
      String? scritto;
      final e = await esporta(
        tester,
        consegna,
        video:
            ({
              required s,
              required k,
              required percorso,
              required cache,
              required cartellaProgetto,
              required testi,
              avanzamento,
              annullato,
            }) async {
              scritto = percorso;
              File(percorso).writeAsBytesSync([9, 9]); // File a metà
              avanzamento?.call(1, 300);
              return const EsitoVideo(null, fotogrammi: 1);
            },
      );
      expect(e.stato, StatoEsito.annullato);
      expect(consegna.video, isEmpty);
      expect(consegna.galleria, isEmpty);
      expect(File(scritto!).existsSync(), isFalse);
    });

    testWidgets('MP4 non riuscito: tra le non salvate, file eliminato, '
        'le altre pagine vanno avanti', (tester) async {
      final consegna = _Consegna();
      String? scritto;
      final e = await esporta(
        tester,
        consegna,
        video:
            ({
              required s,
              required k,
              required percorso,
              required cache,
              required cartellaProgetto,
              required testi,
              avanzamento,
              annullato,
            }) async {
              scritto = percorso;
              File(percorso).writeAsBytesSync([9]);
              return EsitoVideo(false, errore: StateError('codificatore'));
            },
      );
      expect(e.stato, StatoEsito.parziale);
      expect(e.falliti, ['viaggio_01.mp4']);
      expect(e.salvati, ['viaggio_02.png']);
      expect(File(scritto!).existsSync(), isFalse);
    });

    testWidgets('telefono senza MP4: la pagina esce come immagine', (
      tester,
    ) async {
      final consegna = _Consegna();
      final e = await esporta(
        tester,
        consegna,
        video: mp4Finto,
        disponibile: false,
      );
      expect(e.salvati, ['viaggio_01.png', 'viaggio_02.png']);
      expect(e.mp4, 0);
    });
  });
}
