import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;
import 'package:scrollr_studio/editor/editor_page.dart';
import 'package:scrollr_studio/editor/geometria_tela.dart';
import 'package:scrollr_studio/editor/sessione.dart';
import 'package:scrollr_studio/editor/stato.dart';
import 'package:scrollr_studio/editor/tela.dart';
import 'package:scrollr_studio/editor/widget_comuni.dart';
import 'package:scrollr_studio/l10n/app_localizations.dart';
import 'package:scrollr_studio/media/cache_media.dart';
import 'package:scrollr_studio/media/galleria.dart';
import 'package:scrollr_studio/project/archivio.dart';
import 'package:scrollr_studio/project/crea_progetto.dart';
import 'package:scrollr_studio/theme/tema.dart';

import 'aiuto_barra.dart';

FotoScelta _foto(int i) => (
  voce: LibraryEntry(path: 'foto$i.jpg', rel: 'media/foto$i.jpg'),
  chiave: 'f:media/foto$i.jpg',
  w: 3000,
  h: 4000,
);

/// Editor aperto su un progetto di prova (file inesistenti: il disegno mostra il segnaposto).
class _Banco {
  _Banco(this.tester);

  final WidgetTester tester;
  late Directory radice;
  late SessioneEditor sessione;

  /// Crea un progetto nuovo con [foto] foto e [pagine] pagine e ne fa la sessione dell'editor.
  Future<SessioneEditor> creaSessione({int foto = 4, int pagine = 1}) async {
    final dir = Directory.systemTemp.createTempSync('scrl_carosello_test');
    radice = dir;
    // Un salvataggio in corso può tenere aperto un file: se la cartella non si toglie ora, resta nei temporanei
    addTearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Niente di grave
      }
    });
    final archivio = ArchivioProgetti(Directory('${radice.path}/progetti'));
    late SessioneEditor s;
    await tester.runAsync(() async {
      final cartella = await archivio.nuovaCartella();
      final p = await creaProgetto(
        archivio: archivio,
        cartella: cartella,
        nome: 'Prova',
        formato: (indice: 0, larghezza: 1080, altezza: 1440),
        scelte: [for (var i = 1; i <= foto; i++) _foto(i)],
      );
      var snap = p.file.snapshot;
      if (pagine > 1) {
        snap = setNumFrames(
          snap,
          pagine,
          EngineContext(imageSize: (_) => (w: 3000, h: 4000)),
        ).snapshot;
      }
      await archivio.salva(cartella, p.file.copyWith(snapshot: snap), p.dati);
      s = SessioneEditor(
        archivio: archivio,
        cartella: cartella,
        cache: CacheMedia(cartella: Directory('${cartella.path}/cache')),
        galleria: const Galleria(),
        dati: p.dati,
        inizio: snap,
        libreriaIniziale: p.file.library,
      );
    });
    return s;
  }

  /// Mostra l'editor di [s] sotto un `ProviderScope` radice (gli appunti stanno lì, fuori dall'editor).
  Future<void> mostra(SessioneEditor s, {Key? chiave}) async {
    sessione = s;
    await tester.pumpWidget(
      ProviderScope(
        key: const ValueKey('radice'),
        child: MaterialApp(
          theme: temaScrl(),
          locale: const Locale('it'),
          supportedLocales: Testi.supportedLocales,
          localizationsDelegates: const [
            Testi.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: EditorPage(key: chiave, sessione: s),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> apri({int foto = 4, int pagine = 1}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await mostra(await creaSessione(foto: foto, pagine: pagine));
  }

  ProviderContainer get contenitore => ProviderScope.containerOf(
    tester.element(find.byType(TelaEditor, skipOffstage: false)),
  );
  StatoEditor get stato => contenitore.read(editorProvider);
  ControlloEditor get controllo => contenitore.read(editorProvider.notifier);
  Snapshot get snapshot => stato.snapshot;
  CanvasState get tela => snapshot.canvas;
  int get passi => stato.cronologia.states.length;

  GeometriaTela geo([double pos = 0]) {
    final size = tester.getSize(find.byType(TelaEditor));
    return GeometriaTela.adatta(
      larghezza: size.width,
      altezza: size.height,
      frameW: tela.frameW,
      frameH: tela.frameH,
      pos: pos,
    );
  }

  Offset schermo(double sx, double sy, [double pos = 0]) =>
      tester.getTopLeft(find.byType(TelaEditor)) + geo(pos).aSchermo(sx, sy);

  Offset centroFoto(int uid, [double pos = 0]) {
    final p = snapshot.items.firstWhere((p) => p.uid == uid);
    return schermo(p.x + p.w / 2, p.y + p.h / 2, pos);
  }

  PhotoItem foto(int uid) => snapshot.items.firstWhere((p) => p.uid == uid);
}

/// Tocca [f] nel pannello aperto (o nella barra), tornando alla griglia delle schede o scorrendo se serve.
Future<void> _tocca(WidgetTester tester, Finder f) =>
    toccaNelPannello(tester, f);

Finder _chiave(String k) => find.byKey(ValueKey(k));
Finder _barra(String testo) => find.widgetWithText(VoceBarra, testo);

void main() {
  group('Pagine', () {
    testWidgets('azioni di pagina: ognuna è un passo con il suo messaggio', (
      tester,
    ) async {
      final b = _Banco(tester);
      await b.apri(foto: 6, pagine: 3);
      await _tocca(tester, _barra('Pagine'));
      expect(b.stato.strumento, Strumento.pagine);
      final passi = b.passi;

      await _tocca(tester, _chiave('azione-duplica'));
      expect(b.tela.numFrames, 4);
      expect(b.stato.pagina, 1);
      expect(b.passi, passi + 1);
      expect(
        find.text('Pagina duplicata: la copia è la pagina 2'),
        findsOneWidget,
      );
      // Il pannello resta aperto per ripetere
      expect(b.stato.strumento, Strumento.pagine);

      await _tocca(tester, _chiave('azione-unisci'));
      expect(b.tela.joined(1), isTrue);
      expect(find.textContaining('unita alla successiva'), findsOneWidget);

      await _tocca(tester, _chiave('azione-blocca'));
      // Una pagina «a cavallo» si blocca con tutto il suo gruppo
      expect(b.tela.pageLocked(1), isTrue);
      expect(b.tela.pageLocked(2), isTrue);
      await _tocca(tester, _chiave('azione-blocca'));
      expect(b.tela.anyPageLocked, isFalse);

      // Il gruppo (pagine 2-3) si sposta insieme, prima della pagina 1
      await _tocca(tester, _chiave('azione-indietro'));
      expect(b.tela.joined(0), isTrue);
      expect(b.stato.pagina, 0);
      expect(find.text('Pagina spostata in posizione 1'), findsOneWidget);

      await _tocca(tester, _chiave('azione-elimina'));
      expect(b.tela.numFrames, 3);

      // Un Annulla alla volta fino all'inizio
      while (b.stato.puoAnnullare) {
        b.controllo.annulla();
      }
      await tester.pump();
      expect(b.tela.numFrames, 3);
      expect(b.snapshot, b.stato.cronologia.states.first);
    });

    testWidgets('prima, dopo, blocco: avvisi del motore e pagina bloccata', (
      tester,
    ) async {
      final b = _Banco(tester);
      await b.apri(foto: 4, pagine: 2);
      await _tocca(tester, _barra('Pagine'));
      await _tocca(tester, _chiave('azione-prima'));
      expect(b.tela.numFrames, 3);
      expect(b.stato.pagina, 0);
      await _tocca(tester, _chiave('azione-dopo'));
      expect(b.tela.numFrames, 4);
      expect(b.stato.pagina, 1);
      // Pagina bloccata: non si elimina e il messaggio dice perché
      await _tocca(tester, _chiave('azione-blocca'));
      final passi = b.passi;
      await _tocca(tester, _chiave('azione-elimina'));
      expect(b.tela.numFrames, 4);
      expect(b.passi, passi);
      expect(find.textContaining('bloccata'), findsWidgets);
    });

    testWidgets('Formato: cambia il formato; con pagine bloccate no', (
      tester,
    ) async {
      final b = _Banco(tester);
      await b.apri(foto: 4, pagine: 2);
      await _tocca(tester, _barra('Pagine'));
      await _tocca(tester, find.text('Formato'));
      await _tocca(tester, _chiave('formato-1'));
      expect(b.tela.ratioIndex, 1);
      expect(b.tela.frameW > b.tela.frameH, isTrue);
      // Con una pagina bloccata il formato non cambia
      b.controllo.bloccaPagina(0);
      await tester.pumpAndSettle();
      final passi = b.passi;
      await _tocca(tester, _chiave('formato-3'));
      expect(b.tela.ratioIndex, 1);
      expect(b.passi, passi);
    });

    testWidgets(
      'Panoramica: tocco = vai, trascinamento = riordina (gruppi uniti)',
      (tester) async {
        final b = _Banco(tester);
        await b.apri(foto: 8, pagine: 4);
        b.controllo.unisciPagina(1); // Pagine 2-3 «a cavallo»
        await tester.pumpAndSettle();
        final ultimaFoto = b.snapshot.items.last.uid;
        await _tocca(tester, find.byIcon(Icons.grid_view_rounded));
        expect(_chiave('pagina-0'), findsOneWidget);
        expect(_chiave('pagina-3'), findsOneWidget);

        // Si trascina la pagina 1 sul gruppo di fondo: finisce dopo la pagina 4
        final da = tester.getCenter(_chiave('pagina-0'));
        final a = tester.getCenter(_chiave('pagina-3'));
        final g = await tester.startGesture(da);
        await g.moveBy(const Offset(30, 0));
        await tester.pump();
        await g.moveTo(a);
        await tester.pump();
        await g.up();
        await tester.pumpAndSettle();
        // Il gruppo 2-3 è ora in testa e resta unito
        expect(b.tela.joined(0), isTrue);
        expect(b.tela.joined(1), isFalse);
        expect(b.tela.joined(2), isFalse);
        expect(find.text('Pagine riordinate'), findsOneWidget);
        // Le foto sono andate con le loro pagine (la foto che stava in fondo ora è a metà)
        final f = b.foto(ultimaFoto);
        expect((f.x / b.tela.frameW).floor(), lessThan(3));

        // Tocco su una pagina = vai a quella pagina e chiude la Panoramica
        await _tocca(tester, _chiave('pagina-2'));
        expect(b.stato.pagina, 2);
        expect(_chiave('pagina-2'), findsNothing);
      },
    );

    testWidgets('Panoramica: pressione lunga = azioni della pagina', (
      tester,
    ) async {
      final b = _Banco(tester);
      await b.apri(foto: 4, pagine: 3);
      await _tocca(tester, find.byIcon(Icons.grid_view_rounded));
      await tester.longPress(_chiave('pagina-1'));
      await tester.pumpAndSettle();
      expect(_chiave('panoramica-azione-duplica'), findsOneWidget);
      await _tocca(tester, _chiave('panoramica-azione-duplica'));
      expect(b.tela.numFrames, 4);
      expect(
        find.text('Pagina duplicata: la copia è la pagina 3'),
        findsOneWidget,
      );
    });

    testWidgets('Anteprima: schermo intero, si scorre di pagina in pagina', (
      tester,
    ) async {
      final b = _Banco(tester);
      await b.apri(foto: 6, pagine: 3);
      b.controllo.seleziona([rifDi(b.snapshot.items.first)]);
      await tester.pump();
      await _tocca(tester, find.byIcon(Icons.play_arrow_rounded));
      expect(_chiave('anteprima-pagine'), findsOneWidget);
      expect(_chiave('anteprima-0'), findsOneWidget);
      await tester.fling(
        _chiave('anteprima-pagine'),
        const Offset(-500, 0),
        1500,
      );
      await tester.pumpAndSettle();
      expect(_chiave('anteprima-1'), findsOneWidget);
      // Pizzico: la pagina si ingrandisce e un dito non cambia più pagina; «Centra» la rimette intera
      expect(_chiave('anteprima-centra'), findsNothing);
      final centro = tester.getCenter(_chiave('anteprima-1'));
      final g1 = await tester.startGesture(centro - const Offset(30, 0));
      final g2 = await tester.startGesture(centro + const Offset(30, 0));
      await tester.pump(); // Due dita: lo scorrimento tra le pagine si ferma
      for (var i = 0; i < 6; i++) {
        await g1.moveBy(const Offset(-20, 0));
        await g2.moveBy(const Offset(20, 0));
        await tester.pump();
      }
      await g1.up();
      await g2.up();
      await tester.pumpAndSettle();
      expect(_chiave('anteprima-centra'), findsOneWidget);
      await tester.fling(
        _chiave('anteprima-pagine'),
        const Offset(-500, 0),
        1500,
      );
      await tester.pumpAndSettle();
      expect(_chiave('anteprima-1'), findsOneWidget);
      expect(_chiave('anteprima-2'), findsNothing);
      await _tocca(tester, _chiave('anteprima-centra'));
      expect(_chiave('anteprima-centra'), findsNothing);
      // Chiude con la ✕ e si torna all'editor, com'era
      await _tocca(tester, find.byIcon(Icons.close_rounded));
      expect(_chiave('anteprima-pagine'), findsNothing);
      expect(b.stato.pagina, 0);
    });
  });

  group('Cronologia', () {
    testWidgets(
      'pressione lunga su Annulla: elenco con nomi, tocco = torna lì',
      (tester) async {
        final b = _Banco(tester);
        await b.apri(foto: 4, pagine: 2);
        b.controllo.aggiungiPagina();
        b.controllo.duplicaPagina(0);
        b.controllo.bloccaPagina(0);
        await tester.pumpAndSettle();
        expect(b.passi, 4);
        await tester.longPress(find.byIcon(Icons.undo_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Cronologia'), findsOneWidget);
        expect(find.text('Progetto aperto'), findsOneWidget);
        expect(find.text('Pagina aggiunta'), findsOneWidget);
        expect(find.text('Pagina duplicata'), findsOneWidget);
        expect(find.text('Lucchetto delle pagine'), findsOneWidget);
        expect(find.text('Attuale'), findsOneWidget);
        // Torna a «Pagina aggiunta» (anche in avanti si può ripartire da qui)
        await _tocca(tester, find.text('Pagina aggiunta'));
        expect(b.tela.numFrames, 3);
        expect(b.stato.cronologia.index, 1);
        expect(b.stato.puoRipetere, isTrue);
        expect(find.text('Cronologia'), findsNothing);
      },
    );
  });

  group('Stile', () {
    testWidgets('Sfondo: sfumatura è un passo solo, ✕ scarta', (tester) async {
      final b = _Banco(tester);
      await b.apri();
      await _tocca(tester, _barra('Stile'));
      await _tocca(tester, _chiave('stile-sfondo'));
      expect(b.stato.strumento, Strumento.sfondo);
      final passi = b.passi;
      await _tocca(tester, _chiave('sfondo-gradient'));
      await _tocca(tester, _chiave('sfondo-scheda-direzione'));
      await _tocca(tester, _chiave('sfondo-dir-diagonal'));
      // Bozza: si vede ma non è ancora un passo
      expect(b.tela.bgMode, 'gradient');
      expect(b.tela.bgDirection, 'diagonal');
      expect(b.passi, passi);
      await _tocca(tester, _chiave('sfondo-colore2'));
      await _tocca(tester, find.byIcon(Icons.check_rounded));
      expect(b.passi, passi + 1);
      expect(b.stato.cronologia.labels.last.kind, ChangeKind.background);
      // ✓ torna al menu Stile
      expect(b.stato.strumento, Strumento.stile);

      // Un altro giro, scartato con ✕: tutto com'era
      await _tocca(tester, _chiave('stile-sfondo'));
      await _tocca(tester, _chiave('sfondo-solid'));
      expect(b.tela.bgMode, 'solid');
      await _tocca(tester, find.byIcon(Icons.close_rounded));
      expect(b.tela.bgMode, 'gradient');
      expect(b.passi, passi + 1);
    });

    testWidgets('Sfondo: foto sfocata sceglie una foto e i cursori', (
      tester,
    ) async {
      final b = _Banco(tester);
      await b.apri();
      await _tocca(tester, _barra('Stile'));
      await _tocca(tester, _chiave('stile-sfondo'));
      await _tocca(tester, _chiave('sfondo-blur'));
      expect(b.tela.bgMode, 'blur');
      expect(b.tela.bgBlurRel, 'media/foto1.jpg');
      await _tocca(tester, find.textContaining('Scurisci'));
      expect(_chiave('sfondo-cursore-Scurisci'), findsOneWidget);
      await _tocca(tester, find.text('Foto'));
      await _tocca(tester, _chiave('sfondo-foto-f:media/foto3.jpg'));
      expect(b.tela.bgBlurRel, 'media/foto3.jpg');
      await _tocca(tester, find.byIcon(Icons.check_rounded));
      expect(b.stato.cronologia.labels.last.kind, ChangeKind.background);
    });

    testWidgets('Numeri di pagina e indicatore «scorri»', (tester) async {
      final b = _Banco(tester);
      await b.apri(foto: 4, pagine: 3);
      await _tocca(tester, _barra('Stile'));
      await _tocca(tester, _chiave('stile-numeri'));
      await _tocca(tester, _chiave('numeri-acceso'));
      expect(b.tela.pageNumbers, isTrue);
      await _tocca(tester, _chiave('tessera-of'));
      expect(b.tela.pageNumberFormat, 'of');
      await _tocca(tester, find.text('Posizione'));
      await _tocca(tester, _chiave('tessera-tr'));
      expect(b.tela.pageNumberPos, 'tr');
      await _tocca(tester, find.byIcon(Icons.check_rounded));
      expect(b.stato.cronologia.labels.last.kind, ChangeKind.pageNumbers);
      expect(b.stato.strumento, Strumento.stile);

      await _tocca(tester, _chiave('stile-scorri'));
      await _tocca(tester, _chiave('scorri-acceso'));
      expect(b.tela.swipeHint, isTrue);
      await tester.enterText(_chiave('scorri-testo'), 'Swipe →');
      await tester.pump();
      expect(b.tela.swipeText, 'Swipe →');
      await _tocca(tester, find.text('Posizione'));
      await _tocca(tester, _chiave('tessera-cr'));
      expect(b.tela.swipePos, 'cr');
      await _tocca(tester, find.byIcon(Icons.check_rounded));
      expect(b.stato.cronologia.labels.last.kind, ChangeKind.swipeHint);
    });

    testWidgets(
      'Guide e Aggancio: interruttori di vista, non entrano in Annulla',
      (tester) async {
        final b = _Banco(tester);
        await b.apri();
        await _tocca(tester, _barra('Stile'));
        expect(b.stato.mostraGuide, isTrue);
        expect(b.stato.aggancioAttivo, isTrue);
        final passi = b.passi;
        await _tocca(tester, _chiave('stile-guide'));
        await _tocca(tester, _chiave('stile-aggancio'));
        expect(b.stato.mostraGuide, isFalse);
        expect(b.stato.aggancioAttivo, isFalse);
        expect(b.passi, passi);
      },
    );
  });

  group('Selezione multipla', () {
    testWidgets('pressione lunga su un elemento: menu e «Seleziona più»', (
      tester,
    ) async {
      final b = _Banco(tester);
      await b.apri(foto: 4);
      await tester.longPressAt(b.centroFoto(1));
      await tester.pumpAndSettle();
      expect(b.stato.selezione, {(tipo: ElementKind.photo, uid: 1)});
      expect(_chiave('menu-copia'), findsOneWidget);
      await _tocca(tester, _chiave('menu-seleziona-piu'));
      expect(b.stato.selezionePiu, isTrue);
      // Ogni tocco aggiunge o toglie
      await tester.tapAt(b.centroFoto(2));
      await tester.pump();
      await tester.tapAt(b.centroFoto(3));
      await tester.pump();
      expect(b.stato.selezione.length, 3);
      await tester.tapAt(b.centroFoto(2));
      await tester.pump();
      expect(b.stato.selezione.length, 2);
      // Il tocco sul vuoto non toglie la selezione (si esce con ✕)
      await tester.tapAt(
        tester.getTopLeft(find.byType(TelaEditor)) + const Offset(8, 700),
      );
      await tester.pump();
      expect(b.stato.selezione.length, 2);
      await _tocca(tester, find.byIcon(Icons.close_rounded));
      expect(b.stato.selezione, isEmpty);
      expect(b.stato.selezionePiu, isFalse);
    });

    testWidgets(
      'raggruppa e separa: il gruppo si seleziona e si sposta intero',
      (tester) async {
        final b = _Banco(tester);
        await b.apri(foto: 4);
        b.controllo.seleziona([
          for (final p in b.snapshot.items.take(2)) rifDi(p),
        ]);
        await tester.pump();
        final passi = b.passi;
        await toccaVoceBarra(tester, 'Raggruppa');
        expect(b.passi, passi + 1);
        expect(b.stato.cronologia.labels.last.kind, ChangeKind.grouped);
        expect(b.foto(1).group, isNot(0));
        expect(b.foto(1).group, b.foto(2).group);
        expect(b.foto(3).group, 0);
        // Un tocco su una foto del gruppo li seleziona entrambe
        b.controllo.deseleziona();
        await tester.pump();
        await tester.tapAt(b.centroFoto(1));
        await tester.pump();
        expect(b.stato.selezione.length, 2);
        await toccaVoceBarra(tester, 'Separa');
        expect(b.foto(1).group, 0);
        expect(b.stato.cronologia.labels.last.kind, ChangeKind.ungrouped);
      },
    );

    testWidgets('allinea, distribuisci, blocca e Disponi dalla barra', (
      tester,
    ) async {
      final b = _Banco(tester);
      await b.apri(foto: 4);
      // Tre forme in posti diversi
      for (final t in ['rect', 'ellipse', 'star']) {
        b.controllo.nuovaForma(t);
      }
      final forme = [for (final f in b.snapshot.shapes) rifDi(f)];
      expect(forme.length, 3);
      b.controllo.selezionaTutto();
      b.controllo.seleziona(forme);
      b.controllo.spostaSelezione(0, 0);
      // Si sparpagliano a mano
      b.controllo.seleziona([forme[0]]);
      b.controllo.spostaSelezione(-100, 40);
      b.controllo.seleziona([forme[2]]);
      b.controllo.spostaSelezione(260, -90);
      b.controllo.seleziona(forme);
      await tester.pump();

      await toccaVoceBarra(tester, 'Allinea');
      expect(b.stato.strumento, Strumento.allinea);
      await _tocca(tester, _chiave('allinea-sinistra'));
      final xs = {for (final f in b.snapshot.shapes) f.x.round()};
      expect(xs.length, 1);
      await _tocca(tester, _chiave('allinea-alto'));
      final ys = {for (final f in b.snapshot.shapes) f.y.round()};
      expect(ys.length, 1);
      await _tocca(tester, find.byIcon(Icons.check_rounded));

      // Distribuisci: spazi uguali in orizzontale (il primo e l'ultimo restano)
      b.controllo.spostaSelezione(0, 0);
      b.controllo.seleziona([forme[1]]);
      b.controllo.spostaSelezione(30, 0);
      b.controllo.seleziona(forme);
      await tester.pump();
      await toccaVoceBarra(tester, 'Distribuisci');
      await _tocca(tester, _chiave('distribuisci-orizzontale'));
      expect(b.stato.cronologia.labels.last.kind, ChangeKind.moved);
      await _tocca(tester, find.byIcon(Icons.check_rounded));

      // Blocca: gli elementi si selezionano ma non si muovono
      await toccaVoceBarra(tester, 'Blocca');
      expect(b.snapshot.shapes.every((f) => f.locked), isTrue);
      expect(find.text('Posizione bloccata'), findsOneWidget);
      final prima = b.snapshot.shapes.first.x;
      b.controllo.spostaSelezione(50, 0);
      expect(b.snapshot.shapes.first.x, prima);
    });

    testWidgets('Disponi: davanti, dietro e frecce di 1 e 10 px', (
      tester,
    ) async {
      final b = _Banco(tester);
      await b.apri(foto: 4);
      b.controllo.seleziona([rifDi(b.foto(1))]);
      await tester.pump();
      final z1 = b.foto(1).z;
      await toccaVoceBarra(tester, 'Livello');
      expect(b.stato.strumento, Strumento.disponi);
      await _tocca(tester, _chiave('disponi-davanti'));
      expect(b.foto(1).z, greaterThan(b.foto(4).z));
      expect(b.foto(1).z, greaterThan(z1));
      await _tocca(tester, _chiave('disponi-dietro'));
      expect(b.foto(1).z, lessThan(b.foto(2).z));
      await _tocca(tester, find.text('Sposta'));
      final x = b.foto(1).x, y = b.foto(1).y;
      await _tocca(tester, _chiave('disponi-destra'));
      expect(b.foto(1).x, x + 1);
      await _tocca(tester, _chiave('disponi-passo-10'));
      await _tocca(tester, _chiave('disponi-giu'));
      expect(b.foto(1).y, y + 10);
      expect(b.stato.strumento, Strumento.disponi);
    });

    testWidgets('Scambia due foto', (tester) async {
      final b = _Banco(tester);
      await b.apri(foto: 4);
      final a = b.foto(1), c = b.foto(2);
      b.controllo.seleziona([rifDi(a), rifDi(c)]);
      await tester.pump();
      await toccaVoceBarra(tester, 'Scambia');
      expect(b.foto(1).x, c.x);
      expect(b.foto(2).x, a.x);
    });
  });

  group('Appunti', () {
    testWidgets('Copia e Incolla qui dal menu; Taglia rimette dov\'era', (
      tester,
    ) async {
      final b = _Banco(tester);
      await b.apri(foto: 4);
      final originale = b.foto(1);
      await tester.longPressAt(b.centroFoto(1));
      await tester.pumpAndSettle();
      await _tocca(tester, _chiave('menu-copia'));
      expect(find.text('1 elemento copiato'), findsOneWidget);
      final passi = b.passi;
      // Pressione lunga sul vuoto (margine della pagina): Incolla qui
      await tester.longPressAt(b.schermo(6, 6));
      await tester.pumpAndSettle();
      await _tocca(tester, _chiave('menu-incolla'));
      await tester.pumpAndSettle();
      expect(b.snapshot.items.length, 5);
      expect(b.passi, passi + 1);
      final nuova = b.stato.elementiSelezionati.single as PhotoItem;
      // Foto incollata: libera e spostata di 30 per non coprire l'originale
      expect(nuova.free, isTrue);
      expect(nuova.x, originale.x + 30);
      expect(nuova.y, originale.y + 30);
      expect(nuova.uid, isNot(1));

      // Taglia: sparisce; Incolla la rimette esattamente dov'era
      b.controllo.seleziona([rifDi(b.foto(2))]);
      final posizione = (b.foto(2).x, b.foto(2).y);
      b.controllo.tagliaSelezione();
      await tester.pump();
      expect(b.snapshot.items.any((p) => p.uid == 2), isFalse);
      await b.controllo.incolla();
      await tester.pump();
      final tornata = b.stato.elementiSelezionati.single as PhotoItem;
      expect((tornata.x, tornata.y), posizione);
    });

    testWidgets('Incolla in un altro progetto: gli appunti sopravvivono', (
      tester,
    ) async {
      final b = _Banco(tester);
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final a = await b.creaSessione(foto: 3);
      await b.mostra(a, chiave: const ValueKey('a'));
      b.controllo.seleziona([rifDi(b.foto(1))]);
      b.controllo.copiaSelezione();
      final lunghezza = b.snapshot.items.length;

      // Si chiude il progetto e se ne apre un altro: gli appunti sono dell'app, non dell'editor
      final altra = await b.creaSessione(foto: 2, pagine: 2);
      await b.mostra(altra, chiave: const ValueKey('b'));
      expect(b.snapshot.items.length, 2);
      expect(b.stato.pagina, 0);
      b.controllo.vaiAPagina(1);
      await tester.pumpAndSettle();
      await b.controllo.incolla();
      await tester.pumpAndSettle();
      expect(b.snapshot.items.length, 3);
      expect(lunghezza, 3);
      final nuova = b.stato.elementiSelezionati.single as PhotoItem;
      // Nella stessa posizione che aveva nella sua pagina, ma nella pagina 2
      expect((nuova.x / b.tela.frameW).floor(), 1);
      expect(nuova.path, 'foto1.jpg');
      // E la foto è anche in libreria
      expect(b.stato.libreria.any((e) => e.rel == 'media/foto1.jpg'), isTrue);
      // I messaggi in corso finiscono mentre l'editor c'è ancora
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('portaMedia copia nel progetto i file di un altro progetto', (
      tester,
    ) async {
      final b = _Banco(tester);
      final a = await b.creaSessione(foto: 2);
      final altra = await b.creaSessione(foto: 1);
      await tester.runAsync(() async {
        final file = File('${a.cartella.path}/media/foto1.jpg');
        await file.parent.create(recursive: true);
        await file.writeAsBytes([1, 2, 3]);
        final snap = a.inizio;
        final appunti = copiaElementi(snap, [rifDi(snap.items.first)], a.ctx)!;
        final voci = await altra.portaMedia(appunti, a.cartella.path);
        expect(voci.single.rel, 'media/foto1.jpg');
        final copiata = File('${altra.cartella.path}/media/foto1.jpg');
        expect(copiata.existsSync(), isTrue);
        expect(copiata.readAsBytesSync(), [1, 2, 3]);
        // Dallo stesso progetto non si copia niente (il file c'è già)
        final stesso = await a.portaMedia(appunti, a.cartella.path);
        expect(stesso.single.rel, 'media/foto1.jpg');
      });
    });

    testWidgets('niente da incollare: un messaggio; pagina bloccata: rifiuta', (
      tester,
    ) async {
      final b = _Banco(tester);
      await b.apri(foto: 4, pagine: 2);
      await b.controllo.incolla();
      await tester.pump();
      expect(find.textContaining('niente da incollare'), findsOneWidget);
      b.controllo.seleziona([rifDi(b.foto(1))]);
      b.controllo.copiaSelezione();
      b.controllo.bloccaPagina(1);
      b.controllo.vaiAPagina(1);
      final passi = b.passi;
      await b.controllo.incolla();
      await tester.pump();
      expect(b.passi, passi);
      expect(find.textContaining('bloccata'), findsWidgets);
    });

    testWidgets('menu sul vuoto: «Aggiungi testo qui» nel punto premuto', (
      tester,
    ) async {
      final b = _Banco(tester);
      await b.apri(foto: 4);
      await tester.longPressAt(b.schermo(6, 6));
      await tester.pumpAndSettle();
      await _tocca(tester, _chiave('menu-testo'));
      final t = b.stato.elementiSelezionati.single as TextItem;
      expect(b.stato.strumento, Strumento.testoModifica);
      final misura = b.sessione.ctx.textSize(t);
      expect(t.x + misura.w / 2, closeTo(6, 1));
      expect(t.y + misura.h / 2, closeTo(6, 1));
    });

    testWidgets('menu sul vuoto: «Aggiungi forma qui» e «Seleziona tutto»', (
      tester,
    ) async {
      final b = _Banco(tester);
      await b.apri(foto: 2);
      await tester.longPressAt(b.schermo(6, 6));
      await tester.pumpAndSettle();
      await _tocca(tester, _chiave('menu-forma'));
      await _tocca(tester, _chiave('menu-forma-ellipse'));
      expect(b.snapshot.shapes.single.kind, 'ellipse');
      b.controllo.deseleziona();
      await tester.pump();
      await tester.longPressAt(b.schermo(1070, 1430));
      await tester.pumpAndSettle();
      await _tocca(tester, _chiave('menu-seleziona-tutto'));
      expect(b.stato.selezione.length, 3);
    });

    testWidgets('sposta in pagina dal menu di una foto', (tester) async {
      final b = _Banco(tester);
      await b.apri(foto: 4, pagine: 2);
      await tester.longPressAt(b.centroFoto(1));
      await tester.pumpAndSettle();
      await _tocca(tester, _chiave('menu-sposta-pagina'));
      await _tocca(tester, _chiave('menu-pagina-1'));
      expect(b.stato.pagina, 1);
      expect((b.foto(1).x + b.foto(1).w / 2) ~/ b.tela.frameW, 1);
    });
  });
}
