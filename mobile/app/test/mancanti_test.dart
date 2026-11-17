import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:photo_manager/photo_manager.dart' show AssetEntity;
import 'package:scrl_engine/scrl_engine.dart' hide Rect;
import 'package:scrollr_studio/editor/editor_page.dart';
import 'package:scrollr_studio/editor/sessione.dart';
import 'package:scrollr_studio/editor/stato.dart';
import 'package:scrollr_studio/editor/tela.dart';
import 'package:scrollr_studio/export/preferenze.dart';
import 'package:scrollr_studio/l10n/app_localizations.dart';
import 'package:scrollr_studio/media/cache_media.dart';
import 'package:scrollr_studio/media/galleria.dart';
import 'package:scrollr_studio/media/mancanti.dart';
import 'package:scrollr_studio/project/archivio.dart';
import 'package:scrollr_studio/project/crea_progetto.dart';
import 'package:scrollr_studio/project/provider.dart';
import 'package:scrollr_studio/render/regolazioni.dart';
import 'package:scrollr_studio/theme/tema.dart';

/// Un elemento della galleria finta.
typedef _Voce = ({String nome, int w, int h, bool video});

/// Galleria finta: `presenti` sono gli elementi che esistono ancora (id → nome e misure).
class _GalleriaFinta extends Galleria {
  _GalleriaFinta(this.presenti, this.png);

  final Map<String, _Voce> presenti;
  final Uint8List png;
  AccessoGalleria accesso = AccessoGalleria.completo;
  int ricerche = 0;

  AssetEntity _e(String id) {
    final v = presenti[id]!;
    return AssetEntity(
      id: id,
      typeInt: v.video ? 2 : 1,
      width: v.w,
      height: v.h,
      title: v.nome,
    );
  }

  @override
  Future<AssetEntity?> entita(MediaAsset a) async =>
      a.platform == Galleria.piattaforma && presenti.containsKey(a.id)
      ? _e(a.id)
      : null;

  @override
  Future<Uint8List?> ridotta(AssetEntity e, int lato) async => png;

  /// Gli originali non servono (nessun file vero): l'alta risoluzione resta quella dell'anteprima.
  @override
  Future<File?> originale(AssetEntity e) async => null;

  @override
  Future<AccessoGalleria> stato() async => accesso;

  @override
  Future<AccessoGalleria> chiedi() async => accesso;

  @override
  Future<List<ElementoGalleria>> elenco({
    int pagina = 0,
    int perPagina = 60,
  }) async => pagina > 0
      ? const []
      : [for (final id in presenti.keys) ElementoGalleria(_e(id))];

  @override
  Future<Map<String, List<ElementoGalleria>>> cercaPerNome(
    Set<String> nomi, {
    int massimo = 50000,
    void Function(int guardati)? progresso,
    bool Function()? annullato,
  }) async {
    ricerche++;
    final cercati = {for (final n in nomi) n.toLowerCase()};
    progresso?.call(presenti.length);
    final out = <String, List<ElementoGalleria>>{};
    for (final id in presenti.keys) {
      final n = presenti[id]!.nome.toLowerCase();
      if (cercati.contains(n)) {
        out.putIfAbsent(n, () => []).add(ElementoGalleria(_e(id)));
      }
    }
    return out;
  }

  @override
  Future<void> pulisciTemporanei() async {}
}

Future<Uint8List> _png() async {
  final px = Uint8List(40 * 30 * 4);
  for (var i = 0; i < px.length; i += 4) {
    px[i] = 200;
    px[i + 1] = 100;
    px[i + 2] = 50;
    px[i + 3] = 255;
  }
  final img = await immagineDaPixel(px, 40, 30);
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  return png!.buffer.asUint8List();
}

MediaAsset _asset(String id, String nome) =>
    MediaAsset(platform: Galleria.piattaforma, id: id, name: nome);

FotoScelta _scelta(String id, String nome) => (
  voce: LibraryEntry(path: nome, asset: _asset(id, nome)),
  chiave: 'a:${Galleria.piattaforma}:$id',
  w: 40,
  h: 30,
);

Future<void> _finoA(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 60 && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsWidgets);
}

void main() {
  group('ricerca per nome', () {
    FotoMancante mancante(
      String nome, {
      bool video = false,
      MisuraImmagine? m,
    }) => FotoMancante(
      elencaRiferimenti(
        Snapshot(
          canvas: CanvasState(),
          items: [
            PhotoItem(
              uid: 1,
              path: nome,
              asset: _asset('vecchio-$nome', nome),
              isVideo: video,
            ),
          ],
        ),
        const [],
      ).single,
      m,
    );

    test('nome senza badare alle maiuscole; con più candidati vale la proporzione; i video non si scambiano con le foto', () async {
      final png = Uint8List(0);
      final g = _GalleriaFinta({
        'a': (nome: 'IMG_1.JPG', w: 4000, h: 3000, video: false),
        'b': (nome: 'img_1.jpg', w: 3000, h: 4000, video: false),
        'c': (nome: 'clip.mp4', w: 1920, h: 1080, video: true),
        'd': (nome: 'clip.jpg', w: 100, h: 100, video: false),
      }, png);
      final r = await cercaInGalleria(g, [
        mancante('img_1.jpg', m: (w: 300, h: 400)), // Verticale: la seconda
        mancante('clip.mp4', video: true),
        mancante('clip.jpg'),
        mancante('non-c-e.jpg'),
      ]);
      final ids = {
        for (final e in r.entries) e.key: e.value.collegamento.asset!.id,
      };
      expect(ids.length, 3);
      expect(ids.values, ['b', 'c', 'd']);
      // Il nuovo riferimento: nome della galleria, niente rel
      final c = r.values.first.collegamento;
      expect((c.path, c.rel), ('img_1.jpg', null));
      expect(r.values.first.misura, (w: 3000, h: 4000));
    });
  });

  group('editor con foto mancanti', () {
    late WidgetTester tester;
    late Directory radice;
    late ArchivioProgetti archivio;
    late _GalleriaFinta galleria;
    late SessioneEditor sessione;
    late Directory cartella;

    ProviderContainer contenitore() => ProviderScope.containerOf(
      tester.element(find.byType(TelaEditor, skipOffstage: false)),
    );
    StatoEditor stato() => contenitore().read(editorProvider);

    /// Tre foto della galleria (1 esiste, 2 e 3 sono state cancellate ma ancora in galleria con altro id) e una
    /// libera in libreria.
    Future<void> apri(
      WidgetTester t, {
      bool controlla = true,
      bool conAnteprime = false,
    }) async {
      tester = t;
      t.view.physicalSize = const Size(800, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      radice = Directory.systemTemp.createTempSync('scrl_mancanti_test');
      addTearDown(() => radice.deleteSync(recursive: true));
      archivio = ArchivioProgetti(Directory('${radice.path}/progetti'));
      final png = (await t.runAsync(_png))!;
      galleria = _GalleriaFinta({
        '1': (nome: 'uno.jpg', w: 40, h: 30, video: false),
        // Le due cancellate sono tornate in galleria con un altro identificativo (come dopo un ripristino)
        '22': (nome: 'due.jpg', w: 40, h: 30, video: false),
        '33': (nome: 'tre.jpg', w: 40, h: 30, video: false),
      }, png);
      await t.runAsync(() async {
        cartella = await archivio.nuovaCartella();
        final p = await creaProgetto(
          archivio: archivio,
          cartella: cartella,
          nome: 'Prova',
          formato: (indice: 0, larghezza: 1080, altezza: 1440),
          scelte: [
            _scelta('1', 'uno.jpg'),
            _scelta('2', 'due.jpg'),
            _scelta('3', 'tre.jpg'),
          ],
        );
        if (conAnteprime) {
          // Le due foto che mancheranno hanno già l'anteprima salvata (come dopo averle usate)
          for (final id in ['2', '3']) {
            galleria.presenti[id] = (
              nome: id == '2' ? 'due.jpg' : 'tre.jpg',
              w: 40,
              h: 30,
              video: false,
            );
          }
        }
        sessione = SessioneEditor(
          archivio: archivio,
          cartella: cartella,
          cache: CacheMedia(
            cartella: Directory('${cartella.path}/cache'),
            galleria: galleria,
          ),
          galleria: galleria,
          dati: p.dati,
          inizio: p.file.snapshot,
          libreriaIniziale: p.file.library,
          controllaMancanti: controlla,
        );
        if (conAnteprime) {
          for (final id in ['2', '3']) {
            final nome = galleria.presenti[id]!.nome;
            await sessione.cache.carica(
              sorgenteDi(
                PhotoItem(uid: 0, path: nome, asset: _asset(id, nome)),
                cartella.path,
              ),
              Dettaglio.anteprima,
            );
            galleria.presenti.remove(id); // Ora sono «cancellate»
          }
        }
      });
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            archivioProvider.overrideWithValue(archivio),
            galleriaProvider.overrideWithValue(galleria),
            preferenzeProvider.overrideWithValue(PreferenzeApp.inMemoria()),
          ],
          child: MaterialApp(
            theme: temaScrl(),
            locale: const Locale('it'),
            supportedLocales: Testi.supportedLocales,
            localizationsDelegates: const [
              Testi.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            home: EditorPage(sessione: sessione),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    Set<String> asset() => {
      for (final p in stato().snapshot.items) p.asset!.id,
    };

    testWidgets(
      'all\'apertura avvisa, poi l\'elenco e la ricerca ricollegano tutto',
      (t) async {
        await apri(t);
        await _finoA(t, find.byKey(const ValueKey('mancanti-piu-tardi')));
        expect(find.text('Foto non trovate'), findsOneWidget);
        expect(
          find.textContaining('2 foto del progetto non si trovano più'),
          findsOneWidget,
        );
        // L'avviso è dato una volta sola, e il segno resta sulla tela
        await t.tap(find.byKey(const ValueKey('mancanti-piu-tardi')));
        await t.pumpAndSettle();
        expect(find.byKey(const ValueKey('badge-mancanti')), findsOneWidget);
        expect(find.text('2 foto mancanti'), findsOneWidget);

        // Un passo di cronologia in più: il ricollegamento riscrive anche quelli vecchi
        final ctrl = contenitore().read(editorProvider.notifier);
        ctrl.conferma(
          stato().snapshot.copyWith(
            items: [
              for (final p in stato().snapshot.items) p.copyWith(x: p.x + 1),
            ],
          ),
        );
        await t.pumpAndSettle();
        expect(stato().cronologia.states.length, 2);

        await t.tap(find.byKey(const ValueKey('badge-mancanti')));
        await t.pumpAndSettle();
        expect(find.text('Foto mancanti'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('mancante-a:${'android'}:2')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('mancante-a:${'android'}:3')),
          findsOneWidget,
        );
        expect(find.text('due.jpg'), findsOneWidget);

        await t.tap(find.byKey(const ValueKey('mancanti-cerca-galleria')));
        await _finoA(t, find.byKey(const ValueKey('mancanti-tutte')));
        expect(find.text('Ritrovate 2 su 2'), findsOneWidget);
        expect(galleria.ricerche, 1);
        // Ovunque: tela, cronologia, libreria
        expect(asset(), {'1', '22', '33'});
        for (final s in stato().cronologia.states) {
          expect({for (final p in s.items) p.asset!.id}, {'1', '22', '33'});
        }
        expect(
          {for (final e in stato().libreria) e.asset!.id},
          {'1', '22', '33'},
        );
        // Annulla non rimette una foto mancante
        ctrl.annulla();
        expect(asset(), {'1', '22', '33'});
        // Misure ricordate per i nuovi riferimenti
        expect(sessione.misure['a:android:22'], (w: 40, h: 30));
        // Salvato: il file ha i nuovi riferimenti
        await t.runAsync(() async {
          await ctrl.salvaOra(conMiniatura: false);
          final p = await archivio.carica(cartella);
          expect(
            {for (final i in p.file.snapshot.items) i.asset!.id},
            {'1', '22', '33'},
          );
        });
        // Il segno è sparito
        await t.tap(find.text('Fine'));
        await t.pumpAndSettle();
        expect(find.byKey(const ValueKey('badge-mancanti')), findsNothing);
      },
    );

    testWidgets('ricerca subito dall\'avviso; senza permesso lo dice', (
      t,
    ) async {
      await apri(t);
      galleria.accesso = AccessoGalleria.negato;
      await _finoA(t, find.byKey(const ValueKey('mancanti-cerca')));
      await t.tap(find.byKey(const ValueKey('mancanti-cerca')));
      await _finoA(t, find.byKey(const ValueKey('mancanti-senza-accesso')));
      expect(galleria.ricerche, 0);
      expect(asset(), {'1', '2', '3'});
      // Con il permesso, di nuovo «Cerca»
      galleria.accesso = AccessoGalleria.completo;
      await t.tap(find.byKey(const ValueKey('mancanti-cerca-galleria')));
      await _finoA(t, find.byKey(const ValueKey('mancanti-tutte')));
      expect(asset(), {'1', '22', '33'});
    });

    testWidgets('ricollega una foto scegliendola nella galleria', (t) async {
      await apri(t);
      await _finoA(t, find.byKey(const ValueKey('mancanti-elenco')));
      await t.tap(find.byKey(const ValueKey('mancanti-elenco')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('ricollega-a:android:2')));
      await t.pumpAndSettle();
      expect(find.text('Dov\'è ora «due.jpg»?'), findsOneWidget);
      // Griglia della galleria: tre elementi; si sceglie il secondo (due.jpg, id 22)
      final tessere = find.bySemanticsLabel(RegExp(r'^Foto \d'));
      await _finoA(t, tessere);
      await t.tap(tessere.at(1));
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'Ricollega'));
      await t.pumpAndSettle();
      expect(asset(), {'1', '22', '3'});
      // Resta da ricollegare una sola foto
      expect(
        find.byKey(const ValueKey('mancante-a:android:3')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('mancante-a:android:2')), findsNothing);
    });

    testWidgets('una foto selezionata che manca ha «Ricollega» nella barra', (
      t,
    ) async {
      await apri(t);
      await _finoA(t, find.byKey(const ValueKey('mancanti-piu-tardi')));
      await t.tap(find.byKey(const ValueKey('mancanti-piu-tardi')));
      await t.pumpAndSettle();
      final ctrl = contenitore().read(editorProvider.notifier);
      final uno = stato().snapshot.items.firstWhere((p) => p.asset!.id == '1');
      final due = stato().snapshot.items.firstWhere((p) => p.asset!.id == '2');
      ctrl.seleziona([(tipo: ElementKind.photo, uid: uno.uid)]);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('cat-ricollega')), findsNothing);
      ctrl.seleziona([(tipo: ElementKind.photo, uid: due.uid)]);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('cat-ricollega')), findsOneWidget);
    });

    testWidgets(
      'prima di esportare avvisa degli originali mancanti e propone di ricollegarli',
      (t) async {
        await apri(t, conAnteprime: true);
        await _finoA(t, find.byKey(const ValueKey('mancanti-piu-tardi')));
        await t.tap(find.byKey(const ValueKey('mancanti-piu-tardi')));
        await t.pumpAndSettle();
        // Con l'anteprima salvata le foto restano visibili: «Originale mancante», non «Foto mancante»
        final risorse = sessione.risorse;
        for (final p in stato().snapshot.items) {
          expect(risorse.mancante(p), isFalse, reason: p.path);
        }
        await t.tap(find.bySemanticsLabel('Esporta'));
        await t.pumpAndSettle();
        await t.tap(find.text('Galleria'));
        await _finoA(t, find.byKey(const ValueKey('esporta-ricollega')));
        expect(
          find.textContaining("2 foto hanno l'originale mancante"),
          findsOneWidget,
        );
        expect(find.textContaining("qualità dell'anteprima"), findsOneWidget);
        // «Ricollega» porta all'elenco e non esporta
        await t.tap(find.byKey(const ValueKey('esporta-ricollega')));
        await t.pumpAndSettle();
        expect(find.text('Foto mancanti'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('mancante-a:android:2')),
          findsOneWidget,
        );
      },
    );

    testWidgets('senza controllo (prove) niente avviso né segno', (t) async {
      await apri(t, controlla: false);
      expect(find.byKey(const ValueKey('mancanti-piu-tardi')), findsNothing);
      expect(find.byKey(const ValueKey('badge-mancanti')), findsNothing);
    });
  });
}
