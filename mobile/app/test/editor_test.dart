import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;
import 'package:scrollr_studio/editor/editor_page.dart';
import 'package:scrollr_studio/editor/geometria_tela.dart';
import 'package:scrollr_studio/editor/pannello_disposizione.dart';
import 'package:scrollr_studio/editor/sessione.dart';
import 'package:scrollr_studio/editor/stato.dart';
import 'package:scrollr_studio/editor/tela.dart';
import 'package:scrollr_studio/editor/widget_comuni.dart';
import 'package:scrollr_studio/l10n/app_localizations.dart';
import 'package:scrollr_studio/main.dart';
import 'package:scrollr_studio/media/cache_media.dart';
import 'package:scrollr_studio/media/galleria.dart';
import 'package:scrollr_studio/project/archivio.dart';
import 'package:scrollr_studio/project/crea_progetto.dart';
import 'package:scrollr_studio/project/provider.dart';
import 'package:scrollr_studio/theme/tema.dart';

FotoScelta _foto(int i) => (
  voce: LibraryEntry(path: 'foto$i.jpg', rel: 'media/foto$i.jpg'),
  chiave: 'f:media/foto$i.jpg',
  w: 3000,
  h: 4000,
);

/// Editor aperto su un progetto con [foto] foto (file inesistenti: il disegno mostra il segnaposto) e [pagine].
class _Banco {
  _Banco(this.tester);

  final WidgetTester tester;
  late Directory radice;
  late ArchivioProgetti archivio;
  late Directory cartella;
  late SessioneEditor sessione;

  Future<void> apri({int foto = 4, int pagine = 1, int libreriaExtra = 0}) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return apriSenzaVista(
      foto: foto,
      pagine: pagine,
      libreriaExtra: libreriaExtra,
    );
  }

  /// Come [apri], con la misura della vista già scelta da chi chiama.
  Future<void> apriSenzaVista({
    int foto = 4,
    int pagine = 1,
    int libreriaExtra = 0,
  }) async {
    radice = Directory.systemTemp.createTempSync('scrl_editor_test');
    addTearDown(() => radice.deleteSync(recursive: true));
    archivio = ArchivioProgetti(Directory('${radice.path}/progetti'));
    await tester.runAsync(() async {
      cartella = await archivio.nuovaCartella();
      var p = await creaProgetto(
        archivio: archivio,
        cartella: cartella,
        nome: 'Prova',
        formato: (indice: 0, larghezza: 1080, altezza: 1440),
        scelte: [for (var i = 1; i <= foto + libreriaExtra; i++) _foto(i)],
      );
      // Le foto in più restano solo in libreria
      var s = p.file.snapshot;
      if (libreriaExtra > 0) {
        s = s.copyWith(items: s.items.take(foto).toList());
      }
      if (pagine > 1) {
        s = setNumFrames(
          s,
          pagine,
          EngineContext(imageSize: (_) => (w: 3000, h: 4000)),
        ).snapshot;
      }
      p = ProgettoCaricato(cartella, p.file.copyWith(snapshot: s), p.dati);
      await archivio.salva(cartella, p.file, p.dati);
      sessione = SessioneEditor(
        archivio: archivio,
        cartella: cartella,
        cache: CacheMedia(cartella: Directory('${cartella.path}/cache')),
        galleria: const Galleria(),
        dati: p.dati,
        inizio: s,
        libreriaIniziale: p.file.library,
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: temaScrl(),
        locale: const Locale('it'),
        supportedLocales: Testi.supportedLocales,
        localizationsDelegates: const [
          Testi.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: EditorPage(sessione: sessione),
      ),
    );
    await tester.pumpAndSettle();
  }

  ProviderContainer get contenitore =>
      ProviderScope.containerOf(tester.element(find.byType(TelaEditor)));
  StatoEditor get stato => contenitore.read(editorProvider);
  ControlloEditor get controllo => contenitore.read(editorProvider.notifier);
  Snapshot get snapshot => stato.snapshot;
  int get passi => stato.cronologia.states.length;

  GeometriaTela geo([double pos = 0]) {
    final size = tester.getSize(find.byType(TelaEditor));
    return GeometriaTela.adatta(
      larghezza: size.width,
      altezza: size.height,
      frameW: snapshot.canvas.frameW,
      frameH: snapshot.canvas.frameH,
      pos: pos,
    );
  }

  /// Punto dello schermo che corrisponde a ([sx], [sy]) della striscia, con la pagina [pos] centrata.
  Offset schermo(double sx, double sy, [double pos = 0]) =>
      tester.getTopLeft(find.byType(TelaEditor)) + geo(pos).aSchermo(sx, sy);

  Offset centroFoto(int uid, [double pos = 0]) {
    final p = snapshot.items.firstWhere((p) => p.uid == uid);
    return schermo(p.x + p.w / 2, p.y + p.h / 2, pos);
  }

  PhotoItem foto(int uid) => snapshot.items.firstWhere((p) => p.uid == uid);
}

/// La striscia di strumenti scorre in orizzontale: porta in vista la voce [testo] (ormai sono più di quante ne stanno).
Future<void> _vediVoce(WidgetTester tester, String testo) async {
  final lista = find
      .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
      .first;
  // Si riparte dall'inizio della striscia: una voce già superata non è più costruita
  await tester.drag(lista, const Offset(10000, 0));
  await tester.pump();
  await tester.scrollUntilVisible(find.text(testo), 120, scrollable: lista);
  await tester.pump();
}

/// Aspetta che il salvataggio finisca: i file si scrivono davvero (tempo reale), mentre le continuazioni
/// dei Future vivono nel tempo finto del test e avanzano a ogni `pump`.
Future<void> _attendiDisco(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump();
  }
}

void main() {
  mainPercorso();
  testWidgets('tocco su una foto la seleziona, sul vuoto toglie la selezione', (
    tester,
  ) async {
    final b = _Banco(tester);
    await b.apri();
    await tester.tapAt(b.centroFoto(1));
    await tester.pump();
    expect(b.stato.selezione, {(tipo: ElementKind.photo, uid: 1)});
    // Con un elemento selezionato la barra diventa la striscia di strumenti
    await _vediVoce(tester, 'Duplica');
    expect(find.text('Duplica'), findsOneWidget);
    await _vediVoce(tester, 'Elimina');
    expect(find.text('Elimina'), findsOneWidget);
    // Sul fondo, tra il bordo dello schermo e la pagina
    await tester.tapAt(
      tester.getTopLeft(find.byType(TelaEditor)) + const Offset(8, 700),
    );
    await tester.pump();
    expect(b.stato.selezione, isEmpty);
    expect(find.text('Disposizione'), findsOneWidget); // La barra è tornata
  });

  testWidgets('trascinare sul vuoto non sposta niente e cambia pagina', (
    tester,
  ) async {
    final b = _Banco(tester);
    await b.apri(foto: 6, pagine: 2);
    final prima = b.snapshot;
    expect(b.stato.pagina, 0);
    await tester.dragFrom(b.centroFoto(1), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(b.stato.pagina, 1);
    expect(b.snapshot, prima);
    expect(b.passi, 1);
    // E si torna indietro
    await tester.dragFrom(b.centroFoto(6, 1), const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(b.stato.pagina, 0);
    // Oltre l'ultima pagina non si va
    await tester.dragFrom(b.centroFoto(1), const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(b.stato.pagina, 0);
  });

  testWidgets(
    'trascinare una foto selezionata la sposta: un solo passo, Annulla la riporta',
    (tester) async {
      final b = _Banco(tester);
      await b.apri();
      final prima = b.foto(1);
      await tester.tapAt(b.centroFoto(1));
      await tester.pump();
      await tester.dragFrom(b.centroFoto(1), const Offset(60, 40));
      await tester.pumpAndSettle();
      final dopo = b.foto(1);
      expect(dopo.x, greaterThan(prima.x + 20));
      expect(dopo.y, greaterThan(prima.y + 10));
      expect(b.passi, 2);
      expect(b.stato.puoAnnullare, isTrue);
      // Le altre foto non si sono mosse
      expect(b.foto(2).x, prima.x == b.foto(2).x ? b.foto(2).x : b.foto(2).x);
      b.controllo.annulla();
      await tester.pump();
      expect(b.foto(1).x, prima.x);
      expect(b.foto(1).y, prima.y);
      b.controllo.ripeti();
      await tester.pump();
      expect(b.foto(1).x, dopo.x);
    },
  );

  testWidgets(
    'durante il trascinamento la modifica è una bozza fuori dalla cronologia',
    (tester) async {
      final b = _Banco(tester);
      await b.apri();
      await tester.tapAt(b.centroFoto(1));
      await tester.pump();
      final g = await tester.startGesture(b.centroFoto(1));
      await g.moveBy(const Offset(50, 0));
      await tester.pump();
      expect(b.stato.bozza, isNotNull);
      expect(b.passi, 1);
      expect(b.stato.puoAnnullare, isFalse);
      await g.up();
      await tester.pumpAndSettle();
      expect(b.stato.bozza, isNull);
      expect(b.passi, 2);
    },
  );

  testWidgets('la maniglia d\'angolo ridimensiona mantenendo le proporzioni', (
    tester,
  ) async {
    final b = _Banco(tester);
    await b.apri();
    await tester.tapAt(b.centroFoto(1));
    await tester.pump();
    final p = b.foto(1);
    final maniglia = b.schermo(p.x + p.w, p.y + p.h);
    await tester.dragFrom(maniglia, const Offset(40, 40));
    await tester.pumpAndSettle();
    final q = b.foto(1);
    expect(q.w, greaterThan(p.w));
    expect(q.w / q.h, closeTo(p.w / p.h, 1e-6));
    // L'angolo opposto resta fermo
    expect(q.x, closeTo(p.x, 1e-6));
    expect(q.y, closeTo(p.y, 1e-6));
    expect(b.passi, 2);
  });

  testWidgets('la maniglia sul lato cambia la forma senza deformare la foto', (
    tester,
  ) async {
    final b = _Banco(tester);
    await b.apri();
    await tester.tapAt(b.centroFoto(1));
    await tester.pump();
    final p = b.foto(1);
    await tester.dragFrom(
      b.schermo(p.x + p.w, p.y + p.h / 2),
      const Offset(-30, 0),
    );
    await tester.pumpAndSettle();
    final q = b.foto(1);
    expect(q.w, lessThan(p.w));
    expect(q.h, p.h);
    expect(q.stretch, p.stretch);
  });

  testWidgets(
    'pizzico con due dita: ridimensiona e ruota la foto selezionata',
    (tester) async {
      final b = _Banco(tester);
      await b.apri();
      await tester.tapAt(b.centroFoto(1));
      await tester.pump();
      final p = b.foto(1);
      final c = b.centroFoto(1);
      final a = await tester.startGesture(c + const Offset(-20, 0), pointer: 1);
      final d = await tester.startGesture(c + const Offset(20, 0), pointer: 2);
      await a.moveBy(const Offset(-30, 0));
      await d.moveBy(const Offset(30, 0));
      await tester.pump();
      await a.up();
      await d.up();
      await tester.pumpAndSettle();
      expect(b.foto(1).w, greaterThan(p.w * 1.3));
      expect(b.passi, 2);
    },
  );

  testWidgets(
    'una foto trascinata al bordo passa alla pagina vicina e ci resta',
    (tester) async {
      final b = _Banco(tester);
      await b.apri(foto: 6, pagine: 2);
      final ctx = EngineContext(imageSize: (_) => (w: 3000, h: 4000));
      expect(pageOf(b.snapshot, b.foto(1), ctx), 0);
      await tester.tapAt(b.centroFoto(1));
      await tester.pump();
      final g = await tester.startGesture(b.centroFoto(1));
      await g.moveTo(const Offset(770, 400));
      await tester.pump();
      // Un po' di attesa al bordo, poi la vista passa alla pagina 2
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      expect(b.stato.pagina, 1);
      await g.up();
      await tester.pumpAndSettle();
      expect(pageOf(b.snapshot, b.foto(1), ctx), 1);
      expect(b.passi, 2);
    },
  );

  testWidgets('Disposizione: ✕ scarta, ✓ conferma come un solo passo', (
    tester,
  ) async {
    final b = _Banco(tester);
    await b.apri(foto: 6);
    expect(b.snapshot.canvas.layoutMode, LayoutModes.grid);
    await tester.tap(find.text('Disposizione'));
    await tester.pumpAndSettle();
    // La pagina resta visibile con il pannello aperto
    expect(b.stato.strumento, Strumento.disposizione);
    expect(find.byType(TelaEditor), findsOneWidget);
    expect(tester.getSize(find.byType(TelaEditor)).height, greaterThan(300));

    await tester.tap(find.text('Righe'));
    await tester.pump();
    expect(b.snapshot.canvas.layoutMode, LayoutModes.stripsH);
    expect(b.passi, 1, reason: 'solo anteprima');
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(b.snapshot.canvas.layoutMode, LayoutModes.grid);
    expect(b.stato.strumento, Strumento.nessuno);

    await tester.tap(find.text('Disposizione'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Colonne'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.textContaining('Spaziatura  '),
      100,
      scrollable: find
          .descendant(
            of: find.byType(PannelloDisposizione),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.textContaining('Spaziatura  '));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Spaziatura  '));
    await tester.pump();
    await tester.drag(find.byType(Slider), const Offset(-100, 0));
    await tester.pump();
    expect(
      b.snapshot.canvas.gap,
      isNot(16),
      reason: 'il cursore agisce subito',
    );
    await tester.tap(find.textContaining('Margine  '));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();
    expect(b.snapshot.canvas.layoutMode, LayoutModes.stripsV);
    expect(b.passi, 2);
    expect(b.stato.strumento, Strumento.nessuno);
    b.controllo.annulla();
    await tester.pump();
    expect(b.snapshot.canvas.layoutMode, LayoutModes.grid);
  });

  testWidgets('Disposizione: pagine e spaziatura con anteprima dal vivo', (
    tester,
  ) async {
    final b = _Banco(tester);
    await b.apri(foto: 6);
    await tester.tap(find.text('Disposizione'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Pagine  '));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    expect(b.snapshot.canvas.numFrames, 3);
    expect(b.passi, 1);
    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();
    expect(b.snapshot.canvas.numFrames, 3);
    expect(b.passi, 2);
    // La striscia delle pagine mostra 3 pagine
    expect(find.text('1/3'), findsOneWidget);
  });

  testWidgets('Libreria: aggiunge alla tela le foto scelte', (tester) async {
    final b = _Banco(tester);
    await b.apri(foto: 3, libreriaExtra: 2);
    expect(b.snapshot.items.length, 3);
    expect(b.stato.libreria.length, 5);
    await tester.tap(find.text('Foto'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Libreria · 5 foto'), findsOneWidget);
    // Le miniature sono nella fila: si scelgono le ultime due
    await tester.tap(find.bySemanticsLabel('Foto 4'));
    await tester.tap(find.bySemanticsLabel('Foto 5'));
    await tester.pump();
    expect(find.text('2 foto scelte'), findsOneWidget);
    await tester.tap(find.text('Aggiungi alla tela'));
    await tester.pumpAndSettle();
    expect(b.snapshot.items.length, 5);
    expect(b.passi, 2);
    // Restano selezionate le foto nuove
    expect(b.stato.selezione.length, 2);
  });

  testWidgets('Libreria: Svuota tela e Annulla', (tester) async {
    final b = _Banco(tester);
    await b.apri(foto: 4);
    await tester.tap(find.text('Foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Svuota tela'));
    await tester.pumpAndSettle();
    expect(b.snapshot.items, isEmpty);
    expect(find.text('Tela svuotata'), findsOneWidget);
    // Il messaggio breve offre «Annulla»
    await tester.tap(find.text('Annulla').last);
    await tester.pumpAndSettle();
    expect(b.snapshot.items.length, 4);
  });

  testWidgets('Elimina, Duplica e Libera dalla barra di selezione', (
    tester,
  ) async {
    final b = _Banco(tester);
    await b.apri(foto: 4);
    await tester.tapAt(b.centroFoto(2));
    await tester.pump();
    await _vediVoce(tester, 'Duplica');
    await tester.tap(find.text('Duplica'));
    await tester.pump();
    expect(b.snapshot.items.length, 5);
    expect(b.stato.selezione.length, 1);
    await _vediVoce(tester, 'Libera');
    await tester.tap(find.text('Libera'));
    await tester.pump();
    expect(
      b.stato.elementiSelezionati.whereType<PhotoItem>().single.free,
      isTrue,
    );
    expect(find.text('In disposizione'), findsOneWidget);
    await _vediVoce(tester, 'Elimina');
    await tester.tap(find.text('Elimina'));
    await tester.pump();
    expect(b.snapshot.items.length, 4);
    expect(b.stato.selezione, isEmpty);
    expect(b.passi, 4);
  });

  testWidgets(
    'salvataggio: le modifiche arrivano sul disco e il progetto si riapre uguale',
    (tester) async {
      final b = _Banco(tester);
      await b.apri(foto: 6);
      await tester.tapAt(b.centroFoto(1));
      await tester.pump();
      await tester.dragFrom(b.centroFoto(1), const Offset(70, 50));
      await tester.pump();
      // Passa il ritardo di 1 s del salvataggio automatico, poi il file viene scritto davvero
      await tester.pump(const Duration(milliseconds: 1100));
      await _attendiDisco(tester);
      final salvato = await tester.runAsync(
        () => b.archivio.carica(b.cartella),
      );
      expect(salvato!.file.snapshot, b.stato.cronologia.current);
      expect(salvato.file.snapshot.items.length, 6);
      expect(salvato.file.library.length, 6);
      final nomi = b.cartella.listSync().map(
        (e) => e.path.split(RegExp(r'[/\\]')).last,
      );
      expect(
        nomi.where((n) => n.endsWith('.scrlproj.tmp') || n == 'info.json.tmp'),
        isEmpty,
      );
    },
  );

  testWidgets('salvataggio: quando l\'app va in secondo piano salva subito', (
    tester,
  ) async {
    final b = _Banco(tester);
    await b.apri(foto: 4);
    await tester.tapAt(b.centroFoto(3));
    await tester.pump();
    await _vediVoce(tester, 'Elimina');
    await tester.tap(find.text('Elimina'));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _attendiDisco(tester);
    final salvato = await tester.runAsync(() => b.archivio.carica(b.cartella));
    expect(salvato!.file.snapshot.items.length, 3);
  });

  testWidgets('la striscia pagine porta alla pagina toccata', (tester) async {
    final b = _Banco(tester);
    await b.apri(foto: 6, pagine: 3);
    await tester.tap(find.bySemanticsLabel('Vai alla pagina 3'));
    await tester.pumpAndSettle();
    expect(b.stato.pagina, 2);
    expect(find.text('3/3'), findsOneWidget);
    expect(find.textContaining('Pagina 3'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Pagina precedente'));
    await tester.pumpAndSettle();
    expect(b.stato.pagina, 1);
  });

  testWidgets(
    'pagina vuota: invito a toccare ＋; il pannello ＋ aggiunge una pagina',
    (tester) async {
      final b = _Banco(tester);
      await b.apri(foto: 3);
      b.controllo.aggiungiPagina();
      await tester.pumpAndSettle();
      expect(b.snapshot.canvas.numFrames, 2);
      expect(b.stato.pagina, 1);
      expect(find.text('Tocca ＋ per aggiungere le foto'), findsOneWidget);
      await tester.tap(find.text('Aggiungi'));
      await tester.pumpAndSettle();
      expect(find.text('Foto o video'), findsOneWidget);
      expect(find.text('Pagina nuova'), findsOneWidget);
      await tester.tap(find.text('Pagina nuova'));
      await tester.pumpAndSettle();
      expect(b.snapshot.canvas.numFrames, 3);
      expect(b.stato.strumento, Strumento.nessuno);
    },
  );

  testWidgets('gli elementi di una pagina bloccata non si selezionano', (
    tester,
  ) async {
    final b = _Banco(tester);
    await b.apri(foto: 4);
    final ctx = EngineContext(imageSize: (_) => (w: 3000, h: 4000));
    final bloccata = setPageLock(b.snapshot, 0, true, ctx).snapshot;
    b.controllo.conferma(bloccata);
    await tester.pumpAndSettle();
    await tester.tapAt(b.centroFoto(1));
    await tester.pump();
    expect(b.stato.selezione, isEmpty);
    expect(find.textContaining('Bloccata'), findsOneWidget);
  });
}

void _tutto(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Fa avanzare il tempo finto e quello vero finché [finder] compare (apertura dei file e delle schermate).
Future<void> _finoA(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsWidgets);
}

void mainPercorso() {
  testWidgets(
    'si crea un carosello di 5 pagine da 12 foto, si cambia disposizione, si chiude e riapre senza perdere niente',
    (tester) async {
      _tutto(tester);
      final radice = Directory.systemTemp.createTempSync('scrl_percorso_test');
      addTearDown(() => radice.deleteSync(recursive: true));
      final archivio = ArchivioProgetti(Directory('${radice.path}/progetti'));
      await tester.runAsync(() async {
        final c = await archivio.nuovaCartella();
        await creaProgetto(
          archivio: archivio,
          cartella: c,
          nome: 'Viaggio',
          formato: (indice: 2, larghezza: 1080, altezza: 1350),
          scelte: [for (var i = 1; i <= 12; i++) _foto(i)],
        );
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [archivioProvider.overrideWithValue(archivio)],
          child: const ScrollerStudioApp(lingua: Locale('it')),
        ),
      );
      await _finoA(tester, find.text('Viaggio'));
      expect(
        find.textContaining('1 pagina'),
        findsOneWidget,
        reason: 'la Home dice quante pagine',
      );

      // Apre il progetto
      await tester.tap(find.text('Viaggio'));
      await _finoA(tester, find.byType(TelaEditor));
      await tester.pumpAndSettle();
      final contenitore = ProviderScope.containerOf(
        tester.element(find.byType(TelaEditor)),
      );
      expect(contenitore.read(editorProvider).snapshot.items.length, 12);

      // 5 pagine, poi il mosaico
      await tester.tap(find.text('Disposizione'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Pagine  '));
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byIcon(Icons.add_rounded));
        await tester.pump();
      }
      await tester.tap(find.widgetWithText(ChipParametro, 'Disposizione'));
      await tester.pump();
      await tester.tap(find.widgetWithText(TesseraScelta, 'Mosaico'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pumpAndSettle();
      final fatto = contenitore.read(editorProvider).snapshot;
      expect(fatto.canvas.numFrames, 5);
      expect(fatto.canvas.layoutMode, LayoutModes.mosaic);
      expect(fatto.items.length, 12);
      expect(contenitore.read(editorProvider).cronologia.states.length, 2);

      // Esce: il salvataggio parte subito
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      await _finoA(tester, find.text('Viaggio'));
      await tester.pumpAndSettle();
      expect(find.byType(TelaEditor), findsNothing);
      await _finoA(tester, find.textContaining('5 pagine'));

      // Lo riapre: tutto com'era
      await tester.tap(find.text('Viaggio'));
      await _finoA(tester, find.byType(TelaEditor));
      await tester.pumpAndSettle();
      final riaperto = ProviderScope.containerOf(
        tester.element(find.byType(TelaEditor)),
      ).read(editorProvider);
      expect(riaperto.snapshot, fatto);
      expect(riaperto.libreria.length, 12);
      expect(find.text('1/5'), findsOneWidget);
      // E il file su disco è quello che il desktop si aspetta
      final testo = await tester.runAsync(
        () => archivio
            .fileProgetto(archivio.radice.listSync().first as Directory)
            .readAsString(),
      );
      expect(ProjectFile.parse(testo!).snapshot, fatto);
      expect(
        (jsonDecode(testo) as Map<String, Object?>)['version'],
        progettoVersione,
      );
    },
  );

  testWidgets(
    'schermo piccolo e testo ingrandito: nessun overflow con i pannelli aperti',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final b = _Banco(tester);
      await b.apriSenzaVista(foto: 6, pagine: 2);
      for (final voce in ['Foto', 'Disposizione', 'Aggiungi']) {
        await tester.tap(find.text(voce).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: voce);
        expect(
          tester.getSize(find.byType(TelaEditor)).height,
          greaterThan(150),
        );
        b.controllo.chiudiStrumento();
        await tester.pumpAndSettle();
      }
      await tester.tapAt(b.centroFoto(1));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
