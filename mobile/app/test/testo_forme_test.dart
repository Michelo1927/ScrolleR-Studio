import 'dart:io';
import 'dart:ui' as ui;

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
import 'package:scrollr_studio/render/campiona.dart';
import 'package:scrollr_studio/render/caratteri.dart';
import 'package:scrollr_studio/render/disegno.dart';
import 'package:scrollr_studio/render/testo.dart';
import 'package:scrollr_studio/theme/tema.dart';
import 'package:scrollr_studio/theme/tokens.dart';

FotoScelta _foto(int i) => (
  voce: LibraryEntry(path: 'foto$i.jpg', rel: 'media/foto$i.jpg'),
  chiave: 'f:media/foto$i.jpg',
  w: 3000,
  h: 4000,
);

/// Editor aperto su un progetto con [foto] foto (file inesistenti: il disegno mostra il segnaposto).
class _Banco {
  _Banco(this.tester);

  final WidgetTester tester;
  late Directory radice;
  late SessioneEditor sessione;

  Future<void> apri({int foto = 1}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    radice = Directory.systemTemp.createTempSync('scrl_testo_forme_test');
    addTearDown(() {
      try {
        radice.deleteSync(recursive: true);
      } on FileSystemException {
        // Su Windows un file può essere ancora aperto: la cartella temporanea resta, non è un errore
      }
    });
    final archivio = ArchivioProgetti(Directory('${radice.path}/progetti'));
    await tester.runAsync(() async {
      final cartella = await archivio.nuovaCartella();
      final p = await creaProgetto(
        archivio: archivio,
        cartella: cartella,
        nome: 'Prova',
        formato: (indice: 0, larghezza: 1080, altezza: 1440),
        scelte: [for (var i = 1; i <= foto; i++) _foto(i)],
      );
      await archivio.salva(cartella, p.file, p.dati);
      sessione = SessioneEditor(
        archivio: archivio,
        cartella: cartella,
        cache: CacheMedia(cartella: Directory('${cartella.path}/cache')),
        galleria: const Galleria(),
        dati: p.dati,
        inizio: p.file.snapshot,
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
  TextItem get testo => snapshot.texts.single;
  ShapeItem get forma => snapshot.shapes.last;
  EngineContext get ctx => sessione.ctx;

  GeometriaTela get geo {
    final size = tester.getSize(find.byType(TelaEditor));
    return GeometriaTela.adatta(
      larghezza: size.width,
      altezza: size.height,
      frameW: snapshot.canvas.frameW,
      frameH: snapshot.canvas.frameH,
      pos: 0,
    );
  }

  Offset schermo(double sx, double sy) =>
      tester.getTopLeft(find.byType(TelaEditor)) + geo.aSchermo(sx, sy);

  Offset get centroTesto {
    final t = testo;
    final m = ctx.textSize(t);
    return schermo(t.x + m.w / 2, t.y + m.h / 2);
  }

  Offset get centroForma {
    final f = forma;
    return schermo(f.x + f.w / 2, f.y + f.h / 2);
  }

  /// «＋ → Testo»: il testo nasce in bozza con la tastiera pronta.
  Future<void> aggiungiTesto() async {
    controllo.apriStrumento(Strumento.aggiungi);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Testo'));
    await tester.pumpAndSettle();
  }

  /// Un testo già confermato, con [scrivi] come contenuto, selezionato e senza pannelli aperti.
  Future<void> testoPronto([String scrivi = 'Ciao']) async {
    await aggiungiTesto();
    await tester.enterText(find.byType(TextField), scrivi);
    await tester.pump();
    await conferma();
  }

  /// «＋ → Forma → [nome]».
  Future<void> aggiungiForma(String nome) async {
    controllo.apriStrumento(Strumento.aggiungi);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forma'));
    await tester.pumpAndSettle();
    await faiVedere(nome);
    await tester.tap(find.text(nome));
    await tester.pumpAndSettle();
  }

  Future<void> vediVoce(String voce) async {
    final lista = find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(find.text(voce), 120, scrollable: lista);
    await tester.pump();
  }

  Future<void> apriStrumento(String voce) async {
    await vediVoce(voce);
    await tester.tap(find.text(voce));
    await tester.pumpAndSettle();
  }

  /// Fa scorrere le righe del pannello aperto finché [testo] si vede (parte dall'inizio di ogni riga).
  Future<void> faiVedere(String testo) async {
    final f = find.textContaining(testo);
    final liste = find.descendant(
      of: find.byType(PannelloBasso),
      matching: find.byType(Scrollable),
    );
    final n = liste.evaluate().length;
    for (var i = 0; i < n && f.evaluate().isEmpty; i++) {
      final l = liste.at(i);
      await tester.drag(l, const Offset(2000, 0));
      await tester.pumpAndSettle();
      try {
        await tester.scrollUntilVisible(f, 80, scrollable: l, maxScrolls: 40);
      } on StateError {
        // Non è in questa riga: si prova con la successiva
      }
    }
    await tester.ensureVisible(f.first);
    await tester.pumpAndSettle();
  }

  /// Tocca una pillola o una tessera del pannello aperto, facendo scorrere la riga se serve.
  Future<void> tocca(String testo) async {
    await faiVedere(testo);
    await tester.tap(find.textContaining(testo).first);
    await tester.pump();
  }

  /// Un campione di colore del pannello, dal suo nome per i lettori di schermo («Colore #FF3B30»).
  Future<void> campione(String esa) async {
    final f = find.bySemanticsLabel('Colore #$esa');
    await tester.ensureVisible(f.first);
    await tester.pumpAndSettle();
    await tester.tap(f.first);
    await tester.pump();
  }

  /// Porta il cursore grande a [frazione] (0..1 della sua lunghezza): afferra il pollice e lo trascina.
  Future<void> cursore(double frazione) async {
    final r = tester.getRect(find.byType(Slider));
    final sl = tester.widget<Slider>(find.byType(Slider));
    double x(double f) => r.left + 24 + (r.width - 48) * f;
    final ora = (sl.value - sl.min) / (sl.max - sl.min);
    final g = await tester.startGesture(Offset(x(ora), r.center.dy));
    await g.moveTo(Offset(x(frazione), r.center.dy));
    await g.up();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> conferma() async {
    await tester.tap(find.bySemanticsLabel('Conferma'));
    await tester.pumpAndSettle();
  }

  Future<void> annullaStrumento() async {
    await tester.tap(find.bySemanticsLabel('Annulla').last);
    await tester.pumpAndSettle();
  }

  /// Aspetta il lavoro vero (il contagocce disegna e legge un'immagine, che non avanza col tempo finto).
  Future<void> attendiLavoro() async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
  }
}

class _RisorseVuote implements RisorseDisegno {
  @override
  FotoPronta? foto(PhotoItem p) => null;

  @override
  bool mancante(PhotoItem p) => false;

  @override
  ui.Image? get sfondoSfocato => null;

  @override
  ui.Image? get grana => null;

  @override
  bool get mostraOriginale => false;
}

void main() {
  group('caratteri inclusi', () {
    test('sono tra 15 e 25, in cinque gruppi, con nomi tutti diversi', () {
      expect(Caratteri.tutti.length, inInclusiveRange(15, 25));
      expect(Caratteri.tutti.length, 20);
      expect(
        {for (final c in Caratteri.tutti) c.famiglia}.length,
        Caratteri.tutti.length,
      );
      for (final c in CategoriaCarattere.values) {
        expect(Caratteri.dellaCategoria(c), isNotEmpty, reason: '$c');
      }
      expect(Caratteri.incluso(Caratteri.predefinito), isTrue);
    });

    test(
      'ogni carattere è dichiarato in pubspec.yaml e i suoi file esistono',
      () {
        final pubspec = File('pubspec.yaml').readAsStringSync();
        final dichiarate = RegExp(
          r'^\s*- family: (.+)$',
          multiLine: true,
        ).allMatches(pubspec).map((m) => m.group(1)!.trim()).toSet();
        expect(dichiarate, {for (final c in Caratteri.tutti) c.famiglia});
        final file = RegExp(r'asset: (assets/fonts/\S+\.ttf)')
            .allMatches(pubspec)
            .map((m) => m.group(1)!)
            .toList();
        expect(file.length, greaterThanOrEqualTo(Caratteri.tutti.length));
        for (final f in file) {
          expect(File(f).existsSync(), isTrue, reason: f);
        }
        // Le licenze viaggiano con i font
        expect(File('assets/fonts/LICENZE.txt').existsSync(), isTrue);
        expect(pubspec, contains('assets/fonts/LICENZE.txt'));
      },
    );

    test('un carattere mancante si disegna con il predefinito, senza toccare il nome', () {
      const desktop = 'Segoe UI Variable Display';
      expect(Caratteri.incluso(desktop), isFalse);
      expect(Caratteri.perDisegno(desktop), Caratteri.predefinito);
      expect(Caratteri.perDisegno(''), Caratteri.predefinito);
      // Maiuscole e spazi non contano; il nome che si disegna è quello della famiglia
      expect(Caratteri.perDisegno('  lora '), 'Lora');
      expect(Caratteri.perDisegno('PLAYFAIR DISPLAY'), 'Playfair Display');
      // Il testo conserva il suo nome: la misura è quella del predefinito
      final t = TextItem(uid: 1, font: desktop, text: 'Ciao');
      expect(t.font, desktop);
      final m = misuraTesto(t);
      final p = misuraTesto(t.copyWith(font: Caratteri.predefinito));
      expect((m.w, m.h), (p.w, p.h));
      expect(TextItem.fromJson(t.toJson()).font, desktop);
    });
  });

  group('contagocce', () {
    const testi = TestiDisegno(fotoMancante: '', originaleMancante: '', di: '');

    test(
      'legge il colore vero della pagina: sfondo, forme e pagine successive',
      () async {
        var s = Snapshot(
          canvas: CanvasState(numFrames: 2, bgColor: 0xFF336699),
          shapes: [
            ShapeItem(uid: 1, x: 100, y: 100, w: 200, h: 200, fill: 0xFFFF3B30),
            ShapeItem(
              uid: 2,
              x: 1180,
              y: 300,
              w: 100,
              h: 100,
              fill: 0xFF34C759,
            ),
          ],
        );
        final r = _RisorseVuote();
        Future<int?> a(int pagina, double x, double y) =>
            coloreNelPunto(s, pagina, r, testi, x, y);
        expect(await a(0, 10, 10), 0xFF336699);
        expect(await a(0, 200, 200), 0xFFFF3B30);
        expect(await a(1, 150, 350), 0xFF34C759);
        expect(await a(1, 10, 10), 0xFF336699);
        // Sopra la forma, il colore è quello che si vede: una forma semitrasparente lo mescola
        s = s.copyWith(shapes: [s.shapes.first.copyWith(opacity: 50)]);
        final misto = (await a(0, 200, 200))!;
        expect(misto, isNot(0xFFFF3B30));
        expect(misto, isNot(0xFF336699));
        expect(misto >>> 24, 0xFF);
        // Fuori dalla pagina non c'è niente da prelevare
        expect(await a(0, -1, 10), isNull);
        expect(await a(0, 10, 1440), isNull);
        expect(await a(0, 1080, 10), isNull);
      },
    );
  });

  group('testo', () {
    testWidgets(
      '＋ → Testo: nasce in bozza con la tastiera; ✓ è un solo passo, ✕ non lascia niente',
      (tester) async {
        final b = _Banco(tester);
        await b.apri();
        expect(b.passi, 1);
        await b.aggiungiTesto();
        // Il testo c'è e si vede, selezionato, ma non è ancora in cronologia
        expect(b.stato.strumento, Strumento.testoModifica);
        expect(b.testo.text, 'Scrivi qui');
        expect(b.testo.font, Caratteri.predefinito);
        expect(b.stato.selezione, hasLength(1));
        expect(b.passi, 1);
        expect(b.stato.puoAnnullare, isFalse);
        // «Scrivi qui» è già selezionato: scrivere lo sostituisce
        final campo = tester.widget<TextField>(find.byType(TextField));
        expect(campo.controller!.selection.isCollapsed, isFalse);
        await tester.enterText(find.byType(TextField), 'Ciao\nmondo');
        // Con una riga in più il pannello si allunga: il ✓ torna al suo posto a fine animazione
        await tester.pumpAndSettle();
        expect(b.testo.text, 'Ciao\nmondo');
        expect(b.passi, 1, reason: 'mentre si scrive è solo una bozza');
        await b.conferma();
        expect(b.stato.strumento, Strumento.nessuno);
        expect(b.passi, 2);
        expect(b.testo.text, 'Ciao\nmondo');
        // Resta selezionato e la barra offre gli strumenti del testo
        expect(b.stato.selezione, hasLength(1));
        for (final voce in [
          'Modifica',
          'Carattere',
          'Dimensione',
          'Formato',
          'Colore',
          'Contorno',
          'Ombra',
          'Etichetta',
          'Spaziatura',
          'Opacità',
          'Ruota',
          'Duplica',
          'Elimina',
        ]) {
          await b.vediVoce(voce);
          expect(find.text(voce), findsOneWidget, reason: voce);
        }
        // Annulla porta via il testo e il testo non lascia la selezione
        b.controllo.annulla();
        await tester.pump();
        expect(b.snapshot.texts, isEmpty);
      },
    );

    testWidgets(
      '✕ su un testo appena creato: non è mai esistito e la selezione si svuota',
      (tester) async {
        final b = _Banco(tester);
        await b.apri();
        await b.aggiungiTesto();
        await tester.enterText(find.byType(TextField), 'Provvisorio');
        await tester.pump();
        await b.annullaStrumento();
        expect(b.stato.strumento, Strumento.nessuno);
        expect(b.snapshot.texts, isEmpty);
        expect(b.stato.selezione, isEmpty);
        expect(b.passi, 1);
        // La barra torna quella con niente selezionato
        expect(find.text('Disposizione'), findsOneWidget);
      },
    );

    testWidgets(
      'il testo nasce al centro della pagina corrente con i colori in contrasto',
      (tester) async {
        final b = _Banco(tester);
        await b.apri();
        await b.aggiungiTesto();
        final t = b.testo;
        final m = b.ctx.textSize(t);
        expect(t.x + m.w / 2, closeTo(1080 / 2, 1e-6));
        expect(t.y + m.h / 2, closeTo(1440 / 2, 1e-6));
        expect(t.size, 76); // round(1080 · 0,07)
        // Sfondo chiaro: testo scuro, senza ombra
        expect((t.color, t.shadow), (0xFF1A1A1A, false));
      },
    );

    testWidgets(
      'doppio tocco su un testo apre la tastiera; due tocchi su testi diversi no',
      (tester) async {
        final b = _Banco(tester);
        await b.apri();
        await b.testoPronto('Uno');
        final primo = b.centroTesto;
        b.controllo.deseleziona();
        await tester.pump();
        await tester.tapAt(primo);
        await tester.pump();
        expect(b.stato.selezione, hasLength(1));
        expect(b.stato.strumento, Strumento.nessuno);
        await tester.tapAt(primo);
        await tester.pumpAndSettle();
        expect(b.stato.strumento, Strumento.testoModifica);
        expect(find.byType(TextField), findsOneWidget);
        await b.annullaStrumento();
        // Un secondo testo altrove: toccare prima uno e poi l'altro seleziona, non apre
        b.controllo.nuovoTesto();
        await tester.pump();
        b.controllo.modificaTestiSelezionati(
          (t) => t.copyWith(x: t.x - 400, y: t.y - 500),
        );
        b.controllo.confermaEChiudi();
        await tester.pump();
        final altro = b.snapshot.texts.last;
        final m = b.ctx.textSize(altro);
        final posAltro = b.schermo(altro.x + m.w / 2, altro.y + m.h / 2);
        b.controllo.deseleziona();
        await tester.pump();
        await tester.tapAt(primo);
        await tester.pump();
        await tester.tapAt(posAltro);
        await tester.pumpAndSettle();
        expect(b.stato.strumento, Strumento.nessuno);
        expect(b.stato.selezione.single.uid, altro.uid);
      },
    );

    testWidgets(
      'Dimensione 12–400 px: il centro del testo resta fermo; ✓ un passo',
      (tester) async {
        final b = _Banco(tester);
        await b.apri();
        await b.testoPronto();
        final prima = b.testo;
        final m0 = b.ctx.textSize(prima);
        await b.apriStrumento('Dimensione');
        await b.cursore(1.0);
        expect(b.testo.size, 400);
        final m1 = b.ctx.textSize(b.testo);
        expect(b.testo.x + m1.w / 2, closeTo(prima.x + m0.w / 2, 1e-6));
        expect(b.testo.y + m1.h / 2, closeTo(prima.y + m0.h / 2, 1e-6));
        await b.cursore(0.0);
        expect(b.testo.size, 12);
        // Doppio tocco sul cursore: 72, come sul desktop
        final c = tester.getCenter(find.byType(Slider));
        await tester.tapAt(c);
        await tester.pump(const Duration(milliseconds: 60));
        await tester.tapAt(c);
        await tester.pumpAndSettle();
        expect(b.testo.size, 72);
        final passi = b.passi;
        await b.conferma();
        expect(b.passi, passi + 1);
      },
    );

    testWidgets('Formato: grassetto, corsivo e allineamento', (tester) async {
      final b = _Banco(tester);
      await b.apri();
      await b.testoPronto();
      expect(
        (b.testo.bold, b.testo.italic, b.testo.align),
        (true, false, 'center'),
      );
      await b.apriStrumento('Formato');
      await b.tocca('Grassetto');
      await b.tocca('Corsivo');
      await b.tocca('Sinistra');
      expect(
        (b.testo.bold, b.testo.italic, b.testo.align),
        (false, true, 'left'),
      );
      await b.tocca('Destra');
      expect(b.testo.align, 'right');
      final passi = b.passi;
      await b.conferma();
      expect(b.passi, passi + 1, reason: 'tutto in un solo passo');
    });

    testWidgets('Spaziatura: interlinea 60–250% e lettere −10…60%', (
      tester,
    ) async {
      final b = _Banco(tester);
      await b.apri();
      await b.testoPronto();
      await b.apriStrumento('Spaziatura');
      await b.cursore(1.0);
      expect(b.testo.lineHeight, 250);
      await b.cursore(0.0);
      expect(b.testo.lineHeight, 60);
      await b.tocca('Lettere');
      await b.cursore(1.0);
      expect(b.testo.letterSpacing, 60);
      await b.cursore(0.0);
      expect(b.testo.letterSpacing, -10);
      await b.conferma();
      expect(b.passi, 3);
    });

    testWidgets('Opacità 5–100% e Ruota', (tester) async {
      final b = _Banco(tester);
      await b.apri();
      await b.testoPronto();
      await b.apriStrumento('Opacità');
      await b.cursore(0.0);
      expect(b.testo.opacity, 5);
      await b.conferma();
      await b.apriStrumento('Ruota');
      await b.tocca('90° dx');
      expect(b.testo.rotation, 90);
      await b.tocca('90° sx');
      await b.tocca('90° sx');
      expect(b.testo.rotation, -90);
      await b.tocca('Dritta');
      expect(b.testo.rotation, 0);
      await b.cursore(1.0);
      expect(b.testo.rotation, closeTo(180, 2));
      await b.conferma();
      expect(b.passi, 4);
    });

    testWidgets(
      'Ombra è un comando singolo: si accende e si spegne subito, un passo ciascuno',
      (tester) async {
        final b = _Banco(tester);
        await b.apri();
        await b.testoPronto();
        expect(b.testo.shadow, isFalse);
        final passi = b.passi;
        await b.apriStrumento('Ombra');
        expect(
          b.stato.strumento,
          Strumento.nessuno,
          reason: 'non apre pannelli',
        );
        expect(b.testo.shadow, isTrue);
        expect(b.passi, passi + 1);
        await b.apriStrumento('Ombra');
        expect(b.testo.shadow, isFalse);
        expect(b.passi, passi + 2);
      },
    );
  });

  group('carattere', () {
    testWidgets('si sceglie tra i gruppi; ✓ conferma e ✕ no', (tester) async {
      final b = _Banco(tester);
      await b.apri();
      await b.testoPronto();
      await b.apriStrumento('Carattere');
      // Si apre sul gruppo del carattere attuale
      expect(find.text('Inter'), findsOneWidget);
      expect(find.textContaining('non c'), findsNothing);
      for (final (gruppo, carattere) in [
        ('Con grazie', 'Lora'),
        ('Titolo', 'Bebas Neue'),
        ('A mano', 'Caveat'),
        ('Monospazio', 'Space Mono'),
        ('Senza grazie', 'Montserrat'),
      ]) {
        await b.tocca(gruppo);
        await b.tocca(carattere);
        expect(b.testo.font, carattere);
      }
      await b.annullaStrumento();
      expect(b.testo.font, Caratteri.predefinito);
      await b.apriStrumento('Carattere');
      await b.tocca('Con grazie');
      await b.tocca('Playfair Display');
      final passi = b.passi;
      await b.conferma();
      expect(b.testo.font, 'Playfair Display');
      expect(b.passi, passi + 1);
    });

    testWidgets(
      'un carattere mancante resta nel file finché non se ne sceglie un altro',
      (tester) async {
        const desktop = 'Segoe UI Variable Display';
        final b = _Banco(tester);
        await b.apri();
        await b.testoPronto();
        b.controllo.modificaTestiSelezionati((t) => t.copyWith(font: desktop));
        b.controllo.conferma();
        await tester.pump();
        await b.apriStrumento('Carattere');
        // La nota lo dice, e nessun carattere risulta scelto
        expect(find.textContaining('«$desktop»'), findsOneWidget);
        expect(
          find.textContaining('«${Caratteri.predefinito}»'),
          findsOneWidget,
        );
        // Chiudere e fare altro non cambia il nome
        await b.annullaStrumento();
        expect(b.testo.font, desktop);
        await b.apriStrumento('Dimensione');
        await b.cursore(0.5);
        await b.conferma();
        await b.apriStrumento('Colore');
        await b.campione('FF3B30');
        await b.conferma();
        expect(
          b.testo.font,
          desktop,
          reason: 'gli altri strumenti non toccano il carattere',
        );
        // Il file lo riscrive uguale
        final json = b.testo.toJson();
        expect(json['font'], desktop);
        // Scegliere un carattere incluso lo sostituisce, e la nota sparisce
        await b.apriStrumento('Carattere');
        await tester.tap(find.text('Inter'));
        await tester.pump();
        await b.conferma();
        expect(b.testo.font, 'Inter');
        await b.apriStrumento('Carattere');
        expect(find.textContaining('non c'), findsNothing);
      },
    );
  });

  group('selettore colore', () {
    testWidgets(
      '12 campioni rapidi, e «Nessuno» solo per il riempimento delle forme',
      (tester) async {
        final b = _Banco(tester);
        await b.apri();
        await b.testoPronto();
        await b.apriStrumento('Colore');
        for (final c in CampioniScrl.rapidi) {
          final esa = (c.toARGB32() & 0xFFFFFF)
              .toRadixString(16)
              .toUpperCase()
              .padLeft(6, '0');
          expect(
            find.bySemanticsLabel('Colore #$esa'),
            findsOneWidget,
            reason: esa,
          );
        }
        expect(find.bySemanticsLabel('Nessuno'), findsNothing);
        await b.campione('007AFF');
        expect(b.testo.color, 0xFF007AFF);
        await b.campione('FFFFFF');
        expect(b.testo.color, 0xFFFFFFFF);
        final passi = b.passi;
        await b.conferma();
        expect(b.passi, passi + 1);
        // Per una forma il primo campione è «Nessuno»
        await b.aggiungiForma('Ellisse');
        await b.apriStrumento('Riempimento');
        expect(find.bySemanticsLabel('Nessuno'), findsOneWidget);
      },
    );

    testWidgets('i colori usati nel progetto compaiono accanto ai campioni', (
      tester,
    ) async {
      final b = _Banco(tester);
      await b.apri();
      await b.testoPronto('Uno');
      b.controllo.modificaTestiSelezionati(
        (t) => t.copyWith(color: 0xFF123456),
      );
      b.controllo.conferma();
      await tester.pump();
      b.controllo.deseleziona();
      await b.aggiungiTesto();
      await b.conferma();
      await b.apriStrumento('Colore');
      // Il colore del primo testo non è un campione ma è nel progetto
      expect(find.bySemanticsLabel('Colore #123456'), findsOneWidget);
      await b.campione('123456');
      expect(b.snapshot.texts.last.color, 0xFF123456);
    });

    testWidgets(
      'selettore completo: tinta, saturazione, luminosità, esadecimale',
      (tester) async {
        final b = _Banco(tester);
        await b.apri();
        await b.testoPronto();
        await b.apriStrumento('Colore');
        await b.campione('FF3B30');
        await b.tocca('Altro');
        // Tinta da 0 a 359: a metà è il ciano, e le altre due misure restano
        final prima = argbToHsl(0xFFFF3B30);
        await b.cursore(0.5);
        var h = argbToHsl(b.testo.color);
        expect(h.h, closeTo(180, 3));
        expect(h.s, closeTo(prima.s, 0.03));
        expect(h.l, closeTo(prima.l, 0.03));
        // Luminosità tutta in giù: nero, e la tinta non si perde risalendo
        await b.tocca('Luminosità');
        await b.cursore(0.0);
        expect(b.testo.color & 0xFFFFFF, 0);
        await b.cursore(0.5);
        h = argbToHsl(b.testo.color);
        expect(
          h.h,
          closeTo(180, 3),
          reason: 'la tinta resta anche passando dal nero',
        );
        await b.tocca('Saturazione');
        await b.cursore(0.0);
        h = argbToHsl(b.testo.color);
        expect(h.s, 0);
        // Esadecimale: con o senza #, e un testo non valido non cambia niente
        await b.tocca('Esadecimale');
        await tester.enterText(find.byType(TextField), '00FF00');
        await tester.pump();
        expect(b.testo.color, 0xFF00FF00);
        await tester.enterText(find.byType(TextField), '#ff3b3');
        await tester.pump();
        expect(b.testo.color, 0xFF00FF00);
        expect(find.text('Scrivi 6 cifre, da 0 a F'), findsOneWidget);
        await tester.enterText(find.byType(TextField), '#ff3b30');
        await tester.pump();
        expect(b.testo.color, 0xFFFF3B30);
        // Si torna ai campioni
        await b.tocca('‹ Colori');
        expect(find.bySemanticsLabel('Colore #FF3B30'), findsWidgets);
        await b.conferma();
        expect(b.testo.color, 0xFFFF3B30);
      },
    );

    testWidgets(
      'contagocce: il tocco sulla pagina preleva il colore di quel punto',
      (tester) async {
        final b = _Banco(tester);
        await b.apri();
        await b.testoPronto();
        // Sfondo di un colore riconoscibile
        b.controllo.conferma(
          b.snapshot.copyWith(
            canvas: b.snapshot.canvas.copyWith(bgColor: 0xFF336699),
          ),
        );
        await tester.pump();
        await b.apriStrumento('Colore');
        await b.tocca('Contagocce');
        expect(b.stato.contagocce, isTrue);
        expect(
          find.textContaining('Tocca un punto della pagina'),
          findsOneWidget,
        );
        // Un trascinamento non sposta niente col contagocce acceso
        final prima = b.testo;
        await tester.dragFrom(b.centroTesto, const Offset(0, 30));
        await tester.pump();
        expect((b.testo.x, b.testo.y), (prima.x, prima.y));
        // Un angolo della pagina, nel margine senza foto
        await tester.tapAt(b.schermo(6, 6));
        await b.attendiLavoro();
        expect(b.stato.contagocce, isFalse);
        expect(b.testo.color, 0xFF336699);
        // Si può rifare e si spegne con un secondo tocco sulla pillola
        await b.tocca('Contagocce');
        expect(b.stato.contagocce, isTrue);
        await b.tocca('Contagocce');
        expect(b.stato.contagocce, isFalse);
        await b.conferma();
        expect(b.testo.color, 0xFF336699);
      },
    );

    testWidgets(
      'con il contagocce acceso il pannello non lascia la selezione e ✕ lo spegne',
      (tester) async {
        final b = _Banco(tester);
        await b.apri();
        await b.testoPronto();
        await b.apriStrumento('Colore');
        await b.tocca('Contagocce');
        expect(b.stato.contagocce, isTrue);
        // Il tocco su un'altra zona non cambia la selezione
        await tester.tapAt(b.schermo(1000, 1300));
        await b.attendiLavoro();
        expect(b.stato.selezione, hasLength(1));
        await b.tocca('Contagocce');
        await b.annullaStrumento();
        expect(b.stato.contagocce, isFalse);
      },
    );
  });

  group('contorno, etichetta', () {
    testWidgets('Contorno: spessore 0–40 px e colore (che lo fa vedere)', (
      tester,
    ) async {
      final b = _Banco(tester);
      await b.apri();
      await b.testoPronto();
      expect(b.testo.outline, 0);
      await b.apriStrumento('Contorno');
      await b.cursore(1.0);
      expect(b.testo.outline, 40);
      await b.cursore(0.0);
      expect(b.testo.outline, 0);
      await b.tocca('Colore');
      await b.campione('FF3B30');
      expect(b.testo.outlineColor, 0xFFFF3B30);
      expect(
        b.testo.outline,
        greaterThanOrEqualTo(2),
        reason: 'scelto il colore, il contorno si vede',
      );
      await b.tocca('Spessore');
      expect(find.byType(Slider), findsOneWidget);
      final passi = b.passi;
      await b.conferma();
      expect(b.passi, passi + 1);
    });

    testWidgets('Etichetta: si accende col suo colore e la sua trasparenza', (
      tester,
    ) async {
      final b = _Banco(tester);
      await b.apri();
      await b.testoPronto();
      expect(b.testo.box, isFalse);
      await b.apriStrumento('Etichetta');
      await b.tocca('Etichetta');
      expect(b.testo.box, isTrue);
      await b.tocca('Etichetta');
      expect(b.testo.box, isFalse);
      // Scegliere un colore accende l'etichetta
      await b.campione('34C759');
      expect(b.testo.box, isTrue);
      expect(b.testo.boxColor, 0xFF34C759);
      // La trasparenza: mezzo trasparente
      await b.tocca('Opacità');
      await b.cursore(0.5);
      expect(alfaDi(b.testo.boxColor), closeTo(128, 4));
      expect(b.testo.boxColor & 0xFFFFFF, 0x34C759);
      await b.tocca('Esadecimale');
      await tester.enterText(find.byType(TextField), '0000FF');
      await tester.pump();
      expect(
        alfaDi(b.testo.boxColor),
        closeTo(128, 4),
        reason: 'il colore nuovo tiene la trasparenza',
      );
      expect(b.testo.boxColor & 0xFFFFFF, 0x0000FF);
      await b.conferma();
      expect(b.testo.box, isTrue);
    });
  });

  group('forme', () {
    testWidgets(
      '＋ → Forma: le 9 forme, un tocco la aggiunge al centro e la seleziona',
      (tester) async {
        final b = _Banco(tester);
        await b.apri();
        b.controllo.apriStrumento(Strumento.aggiungi);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Forma'));
        await tester.pumpAndSettle();
        expect(b.stato.strumento, Strumento.formaNuova);
        for (final nome in [
          'Rettangolo',
          'Ellisse',
          'Triangolo',
          'Rombo',
          'Stella',
          'Cuore',
          'Linea',
          'Freccia',
          'Doppia freccia',
        ]) {
          await b.faiVedere(nome);
          expect(find.text(nome), findsOneWidget, reason: nome);
        }
        final passi = b.passi;
        await tester.tap(find.text('Stella'));
        await tester.pumpAndSettle();
        expect(b.stato.strumento, Strumento.nessuno);
        expect(b.passi, passi + 1);
        expect(b.forma.kind, 'star');
        expect(b.stato.selezione, hasLength(1));
        expect(b.forma.x + b.forma.w / 2, closeTo(540, 1e-6));
        expect(b.forma.y + b.forma.h / 2, closeTo(720, 1e-6));
        expect(find.text('Forma aggiunta'), findsOneWidget);
        // «Annulla» del messaggio toglie la forma
        await tester.tap(find.text('Annulla'));
        await tester.pumpAndSettle();
        expect(b.snapshot.shapes, isEmpty);
      },
    );

    testWidgets(
      'la barra della forma: Angoli solo per il rettangolo, niente Riempimento per le linee',
      (tester) async {
        final b = _Banco(tester);
        await b.apri();
        await b.aggiungiForma('Rettangolo');
        for (final voce in [
          'Tipo',
          'Riempimento',
          'Bordo',
          'Angoli',
          'Opacità',
          'Ruota',
          'Duplica',
          'Elimina',
        ]) {
          await b.vediVoce(voce);
          expect(find.text(voce), findsOneWidget, reason: voce);
        }
        await b.aggiungiForma('Stella');
        await b.vediVoce('Bordo');
        expect(find.text('Angoli'), findsNothing);
        expect(find.text('Riempimento'), findsOneWidget);
        await b.aggiungiForma('Freccia');
        await b.vediVoce('Tipo');
        expect(find.text('Riempimento'), findsNothing);
        expect(find.text('Angoli'), findsNothing);
        expect(
          find.text('Linea'),
          findsOneWidget,
          reason: 'il bordo di una linea si chiama Linea',
        );
        expect(find.text('Bordo'), findsNothing);
      },
    );

    testWidgets(
      'Tipo: cambia la forma tenendo stile e posizione, in un solo passo',
      (tester) async {
        final b = _Banco(tester);
        await b.apri();
        await b.aggiungiForma('Rettangolo');
        b.controllo.modificaFormeSelezionate(
          (f) => f.copyWith(
            fill: 0xFF5856D6,
            strokeWidth: 6,
            stroke: 0xFF00C7BE,
            rotation: 20,
          ),
        );
        b.controllo.conferma();
        await tester.pump();
        final prima = b.forma;
        final passi = b.passi;
        await b.apriStrumento('Tipo');
        for (final (nome, kind) in [
          ('Ellisse', 'ellipse'),
          ('Triangolo', 'triangle'),
          ('Rombo', 'diamond'),
          ('Stella', 'star'),
          ('Cuore', 'heart'),
        ]) {
          await b.tocca(nome);
          final f = b.forma;
          expect(f.kind, kind);
          expect(
            (f.fill, f.stroke, f.strokeWidth, f.rotation),
            (0xFF5856D6, 0xFF00C7BE, 6.0, 20.0),
          );
          expect(f.x + f.w / 2, closeTo(prima.x + prima.w / 2, 1e-6));
          expect(f.y + f.h / 2, closeTo(prima.y + prima.h / 2, 1e-6));
        }
        expect(b.passi, passi, reason: 'finché non c\'è ✓ è una bozza');
        // Da forma piena a freccia: stessa larghezza, altezza della punta; poi di nuovo piena
        await b.tocca('Freccia');
        expect(b.forma.kind, 'arrow');
        expect(b.forma.w, prima.w);
        expect(b.forma.h, dimensionePunta(b.forma.strokeWidth));
        await b.tocca('Rettangolo');
        expect(b.forma.kind, 'rect');
        expect(b.forma.h, closeTo(prima.w * 0.75, 1e-6));
        await b.conferma();
        expect(b.passi, passi + 1);
      },
    );

    testWidgets(
      'Riempimento: «Nessuno» lascia il contorno; un colore lo riempie',
      (tester) async {
        final b = _Banco(tester);
        await b.apri();
        await b.aggiungiForma('Rettangolo');
        expect(b.forma.strokeWidth, 0);
        await b.apriStrumento('Riempimento');
        await tester.tap(find.bySemanticsLabel('Nessuno'));
        await tester.pump();
        expect(b.forma.fill >>> 24, 0);
        expect(
          b.forma.strokeWidth,
          greaterThan(0),
          reason: 'senza riempimento né bordo la forma sparirebbe',
        );
        await b.campione('34C759');
        expect(b.forma.fill, 0xFF34C759);
        await b.conferma();
        expect(b.forma.fill, 0xFF34C759);
      },
    );

    testWidgets('Bordo: spessore 0–80 px, colore e tratto', (tester) async {
      final b = _Banco(tester);
      await b.apri();
      await b.aggiungiForma('Ellisse');
      await b.apriStrumento('Bordo');
      await b.cursore(1.0);
      expect(b.forma.strokeWidth, 80);
      await b.cursore(0.0);
      expect(b.forma.strokeWidth, 0);
      await b.tocca('Colore');
      await b.campione('000000');
      expect(b.forma.stroke, 0xFF000000);
      expect(
        b.forma.strokeWidth,
        greaterThan(0),
        reason: 'scegliere il colore del bordo lo mostra',
      );
      await b.tocca('Tratto');
      await b.tocca('Tratteggiato');
      expect(b.forma.strokeStyle, 'dash');
      await b.tocca('A puntini');
      expect(b.forma.strokeStyle, 'dot');
      await b.tocca('Continuo');
      expect(b.forma.strokeStyle, 'solid');
      await b.tocca('Spessore');
      await b.cursore(0.25);
      expect(b.forma.strokeWidth, closeTo(20, 2));
      final passi = b.passi;
      await b.conferma();
      expect(b.passi, passi + 1);
    });

    testWidgets('Angoli 0–300 px, Opacità 5–100%, Ruota', (tester) async {
      final b = _Banco(tester);
      await b.apri();
      await b.aggiungiForma('Rettangolo');
      await b.apriStrumento('Angoli');
      await b.cursore(1.0);
      expect(b.forma.radius, 300);
      await b.conferma();
      await b.apriStrumento('Opacità');
      await b.cursore(0.0);
      expect(b.forma.opacity, 5);
      await b.conferma();
      await b.apriStrumento('Ruota');
      await b.tocca('90° dx');
      expect(b.forma.rotation, 90);
      await b.tocca('Dritta');
      expect(b.forma.rotation, 0);
      await b.cursore(0.0);
      expect(b.forma.rotation, closeTo(-180, 2));
      await b.conferma();
      expect(b.passi, 5);
    });

    testWidgets(
      'la forma nuova riprende l\'ultimo stile, separato per forme piene e linee',
      (tester) async {
        final b = _Banco(tester);
        await b.apri();
        await b.aggiungiForma('Ellisse');
        // Stile scelto con Riempimento e Bordo e confermato
        await b.apriStrumento('Riempimento');
        await b.campione('34C759');
        await b.conferma();
        await b.apriStrumento('Bordo');
        await b.cursore(0.25);
        await b.tocca('Colore');
        await b.campione('000000');
        await b.conferma();
        final stile = b.forma;
        b.controllo.deseleziona();
        await tester.pump();
        await b.aggiungiForma('Stella');
        expect(b.forma.kind, 'star');
        expect(
          (b.forma.fill, b.forma.stroke, b.forma.strokeWidth),
          (stile.fill, stile.stroke, stile.strokeWidth),
        );
        // Una linea parte col suo stile, non con quello delle forme piene
        b.controllo.deseleziona();
        await tester.pump();
        await b.aggiungiForma('Linea');
        expect(b.forma.stroke, 0xFFFF3B30);
        expect(b.forma.fill >>> 24, 0);
        // …e dopo averlo cambiato, le linee lo riprendono
        await b.apriStrumento('Linea');
        await b.tocca('Colore');
        await b.campione('007AFF');
        await b.conferma();
        b.controllo.deseleziona();
        await tester.pump();
        await b.aggiungiForma('Freccia');
        expect(b.forma.stroke, 0xFF007AFF);
        // Un cambio scartato con ✕ non diventa lo stile di partenza
        await b.apriStrumento('Tipo');
        await b.annullaStrumento();
        b.controllo.deseleziona();
        await tester.pump();
        await b.aggiungiForma('Rettangolo');
        await b.apriStrumento('Riempimento');
        await b.campione('FF9500');
        await b.annullaStrumento();
        b.controllo.deseleziona();
        await tester.pump();
        await b.aggiungiForma('Cuore');
        expect(
          b.forma.fill,
          stile.fill,
          reason: 'l\'arancione era solo una bozza scartata',
        );
      },
    );

    testWidgets(
      'un progetto con forme e testi si riscrive uguale (campi sconosciuti compresi)',
      (tester) async {
        final b = _Banco(tester);
        await b.apri();
        await b.testoPronto();
        await b.aggiungiForma('Doppia freccia');
        final s = b.snapshot;
        expect(Snapshot.fromJson(s.toJson()), s);
        final t = b.testo.toJson()..['campo_nuovo'] = 7;
        expect(TextItem.fromJson(t).toJson()['campo_nuovo'], 7);
      },
    );
  });

  group('gesti', () {
    testWidgets(
      'trascinare l\'angolo di una forma la ridimensiona mantenendo le proporzioni',
      (tester) async {
        final b = _Banco(tester);
        await b.apri();
        await b.aggiungiForma('Rettangolo');
        final prima = b.forma;
        final passi = b.passi;
        final angolo = b.schermo(prima.x + prima.w, prima.y + prima.h);
        await tester.dragFrom(angolo, const Offset(50, 30));
        await tester.pump();
        final f = b.forma;
        expect(f.w, greaterThan(prima.w));
        expect(f.w / f.h, closeTo(prima.w / prima.h, 1e-6));
        // L'angolo opposto resta dov'era
        expect((f.x, f.y), (prima.x, prima.y));
        expect(
          b.passi,
          passi + 1,
          reason: 'a fine gesto è un passo di cronologia',
        );
      },
    );

    testWidgets('la maniglia di un lato cambia una sola misura', (
      tester,
    ) async {
      final b = _Banco(tester);
      await b.apri();
      await b.aggiungiForma('Rettangolo');
      final prima = b.forma;
      await tester.dragFrom(
        b.schermo(prima.x + prima.w, prima.y + prima.h / 2),
        const Offset(-40, 0),
      );
      await tester.pump();
      expect(b.forma.w, lessThan(prima.w));
      expect(b.forma.h, prima.h);
    });

    testWidgets('il pallino sopra la forma la ruota, con lo scatto a 90°', (
      tester,
    ) async {
      final b = _Banco(tester);
      await b.apri();
      await b.aggiungiForma('Rettangolo');
      final f = b.forma;
      final scala = b.geo.scala;
      final p = pallinoRotazione(f, 32 / scala);
      final centro = b.schermo(f.x + f.w / 2, f.y + f.h / 2);
      await tester.dragFrom(
        b.schermo(p.$1, p.$2),
        centro + const Offset(120, 0) - b.schermo(p.$1, p.$2),
      );
      await tester.pump();
      expect(b.forma.rotation, closeTo(90, 1e-6));
      expect(b.passi, 3);
    });

    testWidgets('gli estremi di una linea la allungano e la orientano', (
      tester,
    ) async {
      final b = _Banco(tester);
      await b.apri();
      await b.aggiungiForma('Linea');
      final prima = b.forma;
      final inizio = estremoInScena(prima, EstremoLinea.inizio);
      await tester.dragFrom(
        b.schermo(prima.x + prima.w, prima.y + prima.h / 2),
        const Offset(0, 60),
      );
      await tester.pump();
      final f = b.forma;
      expect(f.rotation, isNot(0));
      final dopo = estremoInScena(f, EstremoLinea.inizio);
      expect(
        dopo.$1,
        closeTo(inizio.$1, 1e-6),
        reason: 'l\'altro estremo resta fermo',
      );
      expect(dopo.$2, closeTo(inizio.$2, 1e-6));
    });

    testWidgets(
      'pizzico su un testo: dimensione e rotazione, un passo a fine gesto',
      (tester) async {
        final b = _Banco(tester);
        await b.apri();
        await b.testoPronto();
        final prima = b.testo;
        final passi = b.passi;
        final c = b.centroTesto;
        final d1 = await tester.startGesture(
          c + const Offset(-20, 0),
          pointer: 1,
        );
        final d2 = await tester.startGesture(
          c + const Offset(20, 0),
          pointer: 2,
        );
        await tester.pump();
        for (var i = 1; i <= 6; i++) {
          await d1.moveTo(c + Offset(-20.0 - i * 10, 0));
          await d2.moveTo(c + Offset(20.0 + i * 10, 0));
          await tester.pump();
        }
        await d1.up();
        await d2.up();
        await tester.pump();
        expect(b.testo.size, greaterThan(prima.size));
        expect(b.passi, passi + 1);
      },
    );

    testWidgets('pizzico su una forma: la ingrandisce attorno al centro', (
      tester,
    ) async {
      final b = _Banco(tester);
      await b.apri();
      await b.aggiungiForma('Cuore');
      final prima = b.forma;
      final c = b.centroForma;
      final d1 = await tester.startGesture(
        c + const Offset(-20, 0),
        pointer: 1,
      );
      final d2 = await tester.startGesture(c + const Offset(20, 0), pointer: 2);
      await tester.pump();
      for (var i = 1; i <= 6; i++) {
        await d1.moveTo(c + Offset(-20.0 - i * 10, 0));
        await d2.moveTo(c + Offset(20.0 + i * 10, 0));
        await tester.pump();
      }
      await d1.up();
      await d2.up();
      await tester.pump();
      final f = b.forma;
      expect(f.w, greaterThan(prima.w));
      expect(f.x + f.w / 2, closeTo(prima.x + prima.w / 2, 15));
    });

    testWidgets(
      'con uno strumento di testo aperto la selezione non cambia e un trascinamento non sposta',
      (tester) async {
        final b = _Banco(tester);
        await b.apri(foto: 2);
        await b.testoPronto();
        await b.apriStrumento('Dimensione');
        final prima = b.testo;
        await tester.dragFrom(b.centroTesto, const Offset(0, 40));
        await tester.pump();
        expect((b.testo.x, b.testo.y), (prima.x, prima.y));
        await tester.tapAt(b.schermo(5, 5));
        await tester.pump();
        expect(b.stato.selezione, hasLength(1));
        expect(b.stato.strumento, Strumento.testoDimensione);
      },
    );

    testWidgets(
      'si sposta un testo trascinandolo; Duplica ed Elimina valgono per testi e forme',
      (tester) async {
        final b = _Banco(tester);
        await b.apri();
        await b.testoPronto();
        final prima = b.testo;
        await tester.dragFrom(b.centroTesto, const Offset(0, 60));
        await tester.pump();
        expect(b.testo.y, greaterThan(prima.y));
        await b.apriStrumento('Duplica');
        expect(b.snapshot.texts, hasLength(2));
        await b.apriStrumento('Elimina');
        expect(b.snapshot.texts, hasLength(1));
      },
    );
  });
}
