import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:photo_manager/photo_manager.dart' show AssetEntity;
import 'package:scrl_engine/scrl_engine.dart' hide Rect;
import 'package:scrollr_studio/editor/stato.dart';
import 'package:scrollr_studio/editor/tela.dart';
import 'package:scrollr_studio/main.dart';
import 'package:scrollr_studio/media/galleria.dart';
import 'package:scrollr_studio/project/archivio.dart';
import 'package:scrollr_studio/project/provider.dart';

/// Galleria finta: nessun canale di piattaforma, tre foto in ordine.
class _GalleriaFinta extends Galleria {
  AccessoGalleria accesso = AccessoGalleria.daChiedere;
  int richieste = 0;

  @override
  Future<AccessoGalleria> stato() async => accesso;

  @override
  Future<AccessoGalleria> chiedi() async {
    richieste++;
    return accesso = AccessoGalleria.completo;
  }

  @override
  Future<List<ElementoGalleria>> elenco({
    int pagina = 0,
    int perPagina = 60,
  }) async {
    if (accesso != AccessoGalleria.completo || pagina > 0) return const [];
    return [
      for (var i = 1; i <= 3; i++)
        ElementoGalleria(
          AssetEntity(
            id: 'id$i',
            typeInt: 1,
            width: i == 2 ? 4000 : 3000,
            height: i == 2 ? 3000 : 4000,
            title: 'IMG_000$i.jpg',
          ),
        ),
    ];
  }
}

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
  testWidgets(
    'Nuovo progetto: formato, permesso, foto numerate nell\'ordine di scelta, editor',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final radice = Directory.systemTemp.createTempSync('scrl_nuovo_test');
      addTearDown(() => radice.deleteSync(recursive: true));
      final archivio = ArchivioProgetti(Directory('${radice.path}/progetti'));
      final galleria = _GalleriaFinta();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            archivioProvider.overrideWithValue(archivio),
            galleriaProvider.overrideWithValue(galleria),
          ],
          child: const ScrollerStudioApp(lingua: Locale('it')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nessun progetto'), findsOneWidget);

      // Passo 1: formato 4:5
      await tester.tap(find.text('Nuovo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4:5 Instagram'));
      await tester.pump();
      await tester.tap(find.text('Continua'));
      await tester.pumpAndSettle();

      // Passo 2: il permesso si chiede solo ora, con la riga che spiega perché
      expect(find.text('Scegli le foto'), findsWidgets);
      expect(galleria.richieste, 0);
      expect(find.textContaining('collega senza copiarle'), findsOneWidget);
      await tester.tap(find.text('Consenti accesso'));
      await _finoA(tester, find.bySemanticsLabel('Foto 1'));
      expect(galleria.richieste, 1);

      // Si scelgono la 3, la 1 e la 2 (in quest'ordine): i numeri seguono la scelta
      await tester.tap(find.bySemanticsLabel('Foto 3'));
      await tester.tap(find.bySemanticsLabel('Foto 1'));
      await tester.pump();
      expect(find.text('Crea con 2 foto'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Foto 2'));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Foto 2')); // La toglie
      await tester.pump();
      expect(find.text('Crea con 2 foto'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Foto 2'));
      await tester.pump();
      expect(find.text('Crea con 3 foto'), findsOneWidget);

      await tester.tap(find.text('Crea con 3 foto'));
      await _finoA(tester, find.byType(TelaEditor));
      await tester.pumpAndSettle();

      final stato = ProviderScope.containerOf(
        tester.element(find.byType(TelaEditor)),
      ).read(editorProvider);
      final s = stato.snapshot;
      expect((s.canvas.frameW, s.canvas.frameH), (1080, 1350));
      expect(s.canvas.layoutMode, LayoutModes.grid);
      // Le foto della galleria sono collegate, mai copiate
      expect(s.items.length, 3);
      expect(s.items.every((p) => p.asset != null && p.rel == null), isTrue);
      expect(s.items.map((p) => p.asset!.id), ['id3', 'id1', 'id2']);
      expect(stato.libreria.map((e) => e.asset!.name), [
        'IMG_0003.jpg',
        'IMG_0001.jpg',
        'IMG_0002.jpg',
      ]);
      // Nessuna copia nella cartella del progetto
      final cartella = archivio.radice.listSync().whereType<Directory>().single;
      expect(Directory('${cartella.path}/media').existsSync(), isFalse);
      // Il progetto è già su disco
      expect(archivio.fileProgetto(cartella).existsSync(), isTrue);
    },
  );

  testWidgets('Nuovo progetto: «Salta» crea una tela vuota', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final radice = Directory.systemTemp.createTempSync('scrl_nuovo_test');
    addTearDown(() => radice.deleteSync(recursive: true));
    final archivio = ArchivioProgetti(Directory('${radice.path}/progetti'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          archivioProvider.overrideWithValue(archivio),
          galleriaProvider.overrideWithValue(_GalleriaFinta()),
        ],
        child: const ScrollerStudioApp(lingua: Locale('it')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nuovo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continua'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salta'));
    await _finoA(tester, find.byType(TelaEditor));
    await tester.pumpAndSettle();
    final stato = ProviderScope.containerOf(
      tester.element(find.byType(TelaEditor)),
    ).read(editorProvider);
    expect(stato.snapshot.items, isEmpty);
    expect(
      (stato.snapshot.canvas.frameW, stato.snapshot.canvas.frameH),
      (1080, 1440),
    );
    expect(find.text('Tocca ＋ per aggiungere le foto'), findsOneWidget);
  });

  testWidgets('Nuovo progetto: tornando indietro non resta niente su disco', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final radice = Directory.systemTemp.createTempSync('scrl_nuovo_test');
    addTearDown(() => radice.deleteSync(recursive: true));
    final archivio = ArchivioProgetti(Directory('${radice.path}/progetti'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          archivioProvider.overrideWithValue(archivio),
          galleriaProvider.overrideWithValue(_GalleriaFinta()),
        ],
        child: const ScrollerStudioApp(lingua: Locale('it')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nuovo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continua'));
    await tester.pumpAndSettle();
    // Indietro dal secondo passo torna al primo, poi alla Home
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Continua'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Nessun progetto'), findsOneWidget);
    expect(await archivio.elenco(), isEmpty);
  });
}
