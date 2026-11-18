import 'dart:io';
import 'dart:typed_data';
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
import 'package:scrollr_studio/render/regolazioni.dart';
import 'package:scrollr_studio/theme/tema.dart';

import 'aiuto_barra.dart';

FotoScelta _foto(int i) => (
  voce: LibraryEntry(path: 'foto$i.jpg', rel: 'media/foto$i.jpg'),
  chiave: 'f:media/foto$i.jpg',
  w: 3000,
  h: 4000,
);

/// Editor aperto su un progetto con [foto] foto. Con [conFile] le foto sono file veri (immagini piccole), così si
/// possono leggere (miniature dei filtri, pagina del ritaglio); senza, il disegno mostra il segnaposto.
class _Banco {
  _Banco(this.tester);

  final WidgetTester tester;
  late Directory radice;
  late Directory cartella;
  late SessioneEditor sessione;

  Future<void> apri({int foto = 3, bool conFile = false}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    radice = Directory.systemTemp.createTempSync('scrl_strumenti_test');
    addTearDown(() {
      try {
        radice.deleteSync(recursive: true);
      } on FileSystemException {
        // Su Windows un file può essere ancora aperto: la cartella temporanea resta, non è un errore
      }
    });
    final archivio = ArchivioProgetti(Directory('${radice.path}/progetti'));
    await tester.runAsync(() async {
      cartella = await archivio.nuovaCartella();
      if (conFile) {
        Directory('${cartella.path}/media').createSync(recursive: true);
        for (var i = 1; i <= foto; i++) {
          await _scriviPng('${cartella.path}/media/foto$i.jpg', i);
        }
      }
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

  /// Foto 60×80 con una sfumatura (formato PNG, anche se il nome dice `.jpg`: il decodificatore lo riconosce).
  static Future<void> _scriviPng(String percorso, int i) async {
    const w = 60, h = 80;
    final px = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final o = (y * w + x) * 4;
        px[o] = (x * 4 + i * 30) % 256;
        px[o + 1] = (y * 3) % 256;
        px[o + 2] = 120;
        px[o + 3] = 255;
      }
    }
    final img = await immagineDaPixel(px, w, h);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File(percorso).writeAsBytesSync(png!.buffer.asUint8List());
  }

  ProviderContainer get contenitore =>
      ProviderScope.containerOf(tester.element(find.byType(TelaEditor)));
  StatoEditor get stato => contenitore.read(editorProvider);
  ControlloEditor get controllo => contenitore.read(editorProvider.notifier);
  Snapshot get snapshot => stato.snapshot;
  int get passi => stato.cronologia.states.length;
  PhotoItem foto(int uid) => snapshot.items.firstWhere((p) => p.uid == uid);

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

  Offset centroFoto(int uid) {
    final p = foto(uid);
    return schermo(p.x + p.w / 2, p.y + p.h / 2);
  }

  /// Seleziona la foto con un tocco.
  Future<void> seleziona(int uid) async {
    await tester.tapAt(centroFoto(uid));
    await tester.pump();
  }

  /// Tocca una scheda, una tessera o un'azione del pannello aperto (tornando alla griglia o scorrendo se serve).
  Future<void> tocca(String testo) =>
      toccaNelPannello(tester, find.textContaining(testo), settle: false);

  /// Aspetta che la pagina del ritaglio abbia letto la foto (file veri: il tempo passa davvero).
  Future<void> attendiRitaglio() async {
    for (var i = 0; i < 30 && find.text('Libera').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Apre uno strumento dalla barra di selezione (entrando nella sua categoria).
  Future<void> apriStrumento(String voce) => toccaVoceBarra(tester, voce);

  /// Porta il cursore grande a [frazione] (0..1 della sua lunghezza): afferra il pollice e lo trascina.
  Future<void> cursore(double frazione) async {
    final r = tester.getRect(find.byType(Slider));
    final sl = tester.widget<Slider>(find.byType(Slider));
    double x(double f) => r.left + 24 + (r.width - 48) * f;
    final ora = (sl.value - sl.min) / (sl.max - sl.min);
    final g = await tester.startGesture(Offset(x(ora), r.center.dy));
    await g.moveTo(Offset(x(frazione), r.center.dy));
    await g.up();
    // Il riconoscitore del doppio tocco tiene un timer di qualche istante
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
}

void main() {
  testWidgets(
    'con una foto selezionata la barra offre tutti gli strumenti Foto',
    (tester) async {
      final b = _Banco(tester);
      await b.apri();
      await b.seleziona(1);
      // Le categorie stanno tutte nello schermo; ogni strumento si raggiunge dalla sua categoria
      final voci = await vociBarra(tester);
      for (final voce in [
        'Ritaglia',
        'Inquadra',
        'Filtri',
        'Regola',
        'Effetti',
        'Cornice',
        'Ombra',
        'Ruota',
        'Copia stile',
        'Incolla stile',
        'Duplica',
        'Elimina',
      ]) {
        expect(voci, contains(voce), reason: voce);
      }
    },
  );

  group('Regola', () {
    testWidgets('il cursore è una bozza: un solo passo di cronologia, con ✓', (
      tester,
    ) async {
      final b = _Banco(tester);
      await b.apri();
      await b.seleziona(1);
      final passiPrima = b.passi;
      await b.apriStrumento('Regola');
      expect(b.stato.strumento, Strumento.regola);
      // Regola si apre sulla griglia dei parametri: Luminosità, cursore da −100 a +100, a tre quarti vale +50
      await b.tocca('Luminosità');
      await b.cursore(0.75);
      expect(valoreRegolazione(b.foto(1), 'brightness'), closeTo(50, 4));
      expect(b.passi, passiPrima, reason: 'finché non c\'è ✓ è solo una bozza');
      expect(b.stato.puoAnnullare, isFalse);
      // Un altro parametro nello stesso passo
      await b.tocca('Contrasto');
      await b.cursore(0.25);
      expect(valoreRegolazione(b.foto(1), 'contrast'), closeTo(-50, 4));
      await b.conferma();
      expect(b.stato.strumento, Strumento.nessuno);
      expect(b.passi, passiPrima + 1);
      expect(valoreRegolazione(b.foto(1), 'brightness'), isNot(0));
      // Le altre foto non cambiano
      expect(adjustmentsActive(b.foto(2).adjust), isFalse);
      // Annulla riporta tutto in un colpo
      b.controllo.annulla();
      await tester.pump();
      expect(adjustmentsActive(b.foto(1).adjust), isFalse);
    });

    testWidgets('✕ scarta la bozza', (tester) async {
      final b = _Banco(tester);
      await b.apri();
      await b.seleziona(1);
      final passiPrima = b.passi;
      await b.apriStrumento('Regola');
      await b.tocca('Luminosità');
      await b.cursore(0.9);
      expect(adjustmentsActive(b.foto(1).adjust), isTrue);
      await b.annullaStrumento();
      expect(b.stato.strumento, Strumento.nessuno);
      expect(adjustmentsActive(b.foto(1).adjust), isFalse);
      expect(b.passi, passiPrima);
    });

    testWidgets('doppio tocco sul cursore: valore iniziale', (tester) async {
      final b = _Banco(tester);
      await b.apri();
      await b.seleziona(1);
      await b.apriStrumento('Regola');
      await b.tocca('Luminosità');
      await b.cursore(0.9);
      expect(valoreRegolazione(b.foto(1), 'brightness'), greaterThan(40));
      final c = tester.getCenter(find.byType(Slider));
      await tester.tapAt(c);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(c);
      await tester.pumpAndSettle();
      expect(valoreRegolazione(b.foto(1), 'brightness'), 0);
    });

    testWidgets('Auto, bianco e nero, Reimposta colori e Applica a tutte', (
      tester,
    ) async {
      final b = _Banco(tester);
      await b.apri();
      await b.seleziona(1);
      await b.apriStrumento('Regola');
      await b.tocca('Auto');
      expect(b.foto(1).adjust['auto'], isTrue);
      await b.tocca('B/N');
      expect(b.foto(1).adjust['bw'], isTrue);
      await b.tocca('Applica a tutte');
      for (final p in b.snapshot.items) {
        expect(p.adjust['bw'], isTrue, reason: 'foto ${p.uid}');
        expect(p.adjust['auto'], isTrue);
      }
      await b.tocca('Reimposta colori');
      expect(adjustmentsActive(b.foto(1).adjust), isFalse);
      expect(
        adjustmentsActive(b.foto(2).adjust),
        isTrue,
      ); // Reimposta vale per la selezione
      await b.conferma();
      expect(b.passi, 2);
    });

    testWidgets(
      'prima/dopo: finché si tiene premuto ◐ le foto non hanno i colori',
      (tester) async {
        final b = _Banco(tester);
        await b.apri();
        await b.seleziona(1);
        await b.apriStrumento('Regola');
        final risorse = b.sessione.risorse;
        expect(risorse.mostraOriginale, isFalse);
        final g = await tester.startGesture(
          tester.getCenter(find.bySemanticsLabel(RegExp('confrontare'))),
        );
        await tester.pump();
        expect(risorse.mostraOriginale, isTrue);
        await g.up();
        await tester.pump();
        expect(risorse.mostraOriginale, isFalse);
        // Anche chiudendo lo strumento col confronto premuto, torna tutto com'era
        final g2 = await tester.startGesture(
          tester.getCenter(find.bySemanticsLabel(RegExp('confrontare'))),
        );
        await tester.pump();
        expect(risorse.mostraOriginale, isTrue);
        b.controllo.chiudiStrumento();
        await tester.pumpAndSettle();
        await g2.up();
        await tester.pumpAndSettle();
        expect(risorse.mostraOriginale, isFalse);
      },
    );
  });

  testWidgets('Effetti: nitidezza, vignettatura, sbiadito e grana', (
    tester,
  ) async {
    final b = _Banco(tester);
    await b.apri();
    await b.seleziona(1);
    await b.apriStrumento('Effetti');
    await b.cursore(1.0);
    expect(valoreRegolazione(b.foto(1), 'sharpness'), 100);
    await b.tocca('Vignettatura');
    await b.cursore(0.0);
    expect(valoreRegolazione(b.foto(1), 'vignette'), -100);
    await b.tocca('Sbiadito');
    await b.cursore(0.4);
    expect(valoreRegolazione(b.foto(1), 'fade'), closeTo(40, 4));
    await b.tocca('Grana');
    await b.cursore(0.2);
    expect(valoreRegolazione(b.foto(1), 'grain'), closeTo(20, 4));
    await b.conferma();
    expect(b.passi, 2);
  });

  group('Filtri', () {
    testWidgets('si sceglie un filtro e si riconosce; ✓ lo conferma', (
      tester,
    ) async {
      final b = _Banco(tester);
      await b.apri(conFile: true);
      await b.seleziona(1);
      await b.apriStrumento('Filtri');
      // Tutti e 9 i filtri hanno la loro tessera
      for (final nome in [
        'Originale',
        'Vivace',
        'Estate',
        'Pellicola',
        'Vintage',
        'B/N contrastato',
        'Freddo',
        'Morbido',
        'Drammatico',
      ]) {
        await b.tocca(
          nome == 'Originale' ? 'Originale' : nome,
        ); // Fa scorrere fin qui
        expect(find.text(nome), findsOneWidget, reason: nome);
      }
      await b.tocca('Vintage');
      expect(b.foto(1).adjust, presetAdjust('vintage'));
      expect(filtroAttivo(b.foto(1).adjust), 'vintage');
      await b.tocca('Freddo');
      expect(b.foto(1).adjust, presetAdjust('cold'));
      await b.conferma();
      expect(b.passi, 2);
      expect(b.foto(1).adjust, presetAdjust('cold'));
      expect(b.foto(2).adjust, neutralAdjust);
    });

    testWidgets('«Originale» toglie filtri e regolazioni', (tester) async {
      final b = _Banco(tester);
      await b.apri();
      await b.seleziona(1);
      await b.apriStrumento('Filtri');
      await b.tocca('Drammatico');
      expect(adjustmentsActive(b.foto(1).adjust), isTrue);
      await b.tocca('Originale');
      expect(b.foto(1).adjust, neutralAdjust);
    });
  });

  group('Inquadra', () {
    testWidgets('cursori di zoom, spostamento e rotazione del contenuto', (
      tester,
    ) async {
      final b = _Banco(tester);
      await b.apri();
      await b.seleziona(1);
      await b.apriStrumento('Inquadra');
      await b.cursore(1.0); // Zoom 100–400 %
      expect(b.foto(1).innerZoom, closeTo(4.0, 0.05));
      await b.tocca('Orizzontale');
      await b.cursore(1.0);
      expect(b.foto(1).panX, closeTo(1.0, 0.02));
      await b.tocca('Ruota contenuto');
      await b.cursore(1.0);
      expect(b.foto(1).innerRotation, closeTo(180, 2));
      await b.conferma();
      expect(b.passi, 2);
    });

    testWidgets('«Reimposta» riporta zoom, posizione e rotazione', (
      tester,
    ) async {
      final b = _Banco(tester);
      await b.apri();
      await b.seleziona(1);
      await b.apriStrumento('Inquadra');
      await b.cursore(0.6);
      expect(b.foto(1).innerZoom, greaterThan(1.1));
      await b.tocca('Reimposta');
      expect(b.foto(1).innerZoom, 1.0);
    });

    testWidgets('«Foto intera» e «Riempi»', (tester) async {
      final b = _Banco(tester);
      await b.apri();
      await b.seleziona(1);
      await b.apriStrumento('Inquadra');
      await b.tocca('Foto intera');
      expect(b.foto(1).fitMode, 'contain');
      await b.tocca('Riempi');
      expect(b.foto(1).fitMode, 'cover');
    });

    testWidgets(
      'un dito sposta la foto dentro il riquadro, due la ingrandiscono: bozza fino a ✓',
      (tester) async {
        final b = _Banco(tester);
        await b.apri();
        await b.seleziona(1);
        await b.apriStrumento('Inquadra');
        final prima = b.foto(1);
        final x = prima.x, y = prima.y, w = prima.w, h = prima.h;
        // La foto è alta e il riquadro largo: si sposta in verticale (in orizzontale non c'è margine)
        await tester.dragFrom(b.centroFoto(1), const Offset(0, 40));
        await tester.pump();
        final dopo = b.foto(1);
        // Il riquadro non si muove, cambia solo l'inquadratura
        expect((dopo.x, dopo.y, dopo.w, dopo.h), (x, y, w, h));
        expect(dopo.panY, isNot(0));
        expect(dopo.panX, 0);
        expect(b.passi, 1);
        // Pizzico con due dita
        final c = b.centroFoto(1);
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
        expect(b.foto(1).innerZoom, greaterThan(dopo.innerZoom));
        expect(b.passi, 1, reason: 'finché non c\'è ✓ è solo una bozza');
        await b.conferma();
        expect(b.passi, 2);
        expect(b.foto(1).innerZoom, greaterThan(1.0));
      },
    );

    testWidgets(
      '«Solo riquadro»: la maniglia di un lato non stira la foto, spento sì',
      (tester) async {
        final b = _Banco(tester);
        await b.apri();
        await b.seleziona(1);
        await b.apriStrumento('Inquadra');
        final p = b.foto(1);
        final lato = b.schermo(p.x + p.w, p.y + p.h / 2); // Maniglia destra
        // Di partenza la foto si stira insieme al riquadro, come sul desktop
        await tester.dragFrom(lato, const Offset(-30, 0));
        await tester.pump();
        expect(b.foto(1).w, lessThan(p.w));
        expect(b.foto(1).stretch, lessThan(1.0));
        // Con «Solo riquadro» il riquadro cambia, lo stiramento resta 1
        b.controllo.anteprima(b.stato.cronologia.current);
        await b.tocca('Solo riquadro');
        expect(b.stato.soloRiquadro, isTrue);
        await tester.dragFrom(lato, const Offset(-30, 0));
        await tester.pump();
        expect(b.foto(1).w, lessThan(p.w));
        expect(b.foto(1).stretch, 1.0);
        // Chiudere lo strumento spegne «Solo riquadro»
        b.controllo.chiudiStrumento();
        await tester.pump();
        expect(b.stato.soloRiquadro, isFalse);
      },
    );

    testWidgets('«Proporzioni foto» e «Riquadro di prima»', (tester) async {
      final b = _Banco(tester);
      await b.apri();
      await b.seleziona(1);
      await b.apriStrumento('Inquadra');
      final prima = b.foto(1);
      await b.tocca('Proporzioni foto');
      expect(b.foto(1).savedCell, isNotNull);
      expect(
        find.textContaining('Riquadro di prima', skipOffstage: false),
        findsOneWidget,
      );
      await b.tocca('Riquadro di prima');
      expect(b.foto(1).savedCell, isNull);
      expect(b.foto(1).w, closeTo(prima.w, 1e-6));
      expect(b.foto(1).h, closeTo(prima.h, 1e-6));
    });
  });

  group('Cornice e Ombra', () {
    testWidgets('angoli, bordo e colore del bordo', (tester) async {
      final b = _Banco(tester);
      await b.apri();
      await b.seleziona(1);
      await b.apriStrumento('Cornice');
      await b.cursore(0.5); // Angoli 0–200
      expect(b.foto(1).borderRadius, closeTo(100, 8));
      await b.tocca('Bordo');
      await b.cursore(0.5); // Bordo 0–40
      expect(b.foto(1).borderWidth, closeTo(20, 2));
      await b.tocca('Colore');
      // Il quarto campione rapido (dopo il contagocce e «Altro»)
      await tester.tap(find.bySemanticsLabel(RegExp(r'^Colore #')).at(3));
      await tester.pump();
      expect(b.foto(1).borderColor, isNot(0xFFFFFFFF));
      await b.conferma();
      expect(b.passi, 2);
      expect(b.foto(1).autoBorder, isFalse);
    });

    testWidgets('«Applica a tutte» copia cornice, opacità e ombra', (
      tester,
    ) async {
      final b = _Banco(tester);
      await b.apri();
      await b.seleziona(1);
      await b.apriStrumento('Cornice');
      await b.cursore(0.25);
      await b.tocca('Applica a tutte');
      final r = b.foto(1).borderRadius;
      expect(r, greaterThan(0));
      for (final p in b.snapshot.items) {
        expect(p.borderRadius, r, reason: 'foto ${p.uid}');
      }
      await b.conferma();
      expect(b.passi, 2);
    });

    testWidgets('ombra e opacità', (tester) async {
      final b = _Banco(tester);
      await b.apri();
      await b.seleziona(1);
      await b.apriStrumento('Ombra');
      await b.cursore(0.6);
      expect(b.foto(1).shadow, closeTo(60, 5));
      await b.tocca('Opacità');
      await b.cursore(0.0);
      expect(b.foto(1).opacity, LimitiFoto.opacitaMin);
      await b.conferma();
      expect(b.foto(1).opacity, 5);
      expect(b.passi, 2);
    });
  });

  group('Ruota', () {
    testWidgets('angolo, 90° a sinistra e a destra, dritta e specchio', (
      tester,
    ) async {
      final b = _Banco(tester);
      await b.apri();
      await b.seleziona(1);
      await b.apriStrumento('Ruota');
      await b.tocca('90° dx');
      expect(b.foto(1).rotation, 90);
      await b.tocca('90° sx');
      await b.tocca('90° sx');
      expect(b.foto(1).rotation, -90);
      await b.tocca('Dritta');
      expect(b.foto(1).rotation, 0);
      await b.cursore(1.0);
      expect(b.foto(1).rotation, closeTo(180, 2));
      await b.tocca('Specchia orizz.');
      await b.tocca('Specchia vert.');
      expect((b.foto(1).flipH, b.foto(1).flipV), (true, true));
      await b.conferma();
      expect(b.passi, 2, reason: 'tutto in un solo passo');
    });
  });

  group('Stile', () {
    testWidgets('copia e incolla stile: un passo, con Annulla', (tester) async {
      final b = _Banco(tester);
      await b.apri();
      await b.seleziona(1);
      // Uno stile riconoscibile sulla foto 1
      b.controllo.modificaFotoSelezionate(
        (p) => conOmbra(conAngoli(conFiltro(p, 'vintage'), 80), 40),
      );
      b.controllo.conferma();
      await tester.pump();
      final passiPrima = b.passi;
      await b.apriStrumento('Copia stile'); // Non apre pannelli: agisce subito
      expect(b.stato.strumento, Strumento.nessuno);
      expect(b.stato.stileCopiato, isNotNull);
      expect(find.textContaining('Stile copiato'), findsOneWidget);
      expect(b.passi, passiPrima, reason: 'copiare non cambia il documento');
      // Altra foto, poi incolla
      b.controllo.seleziona({(tipo: ElementKind.photo, uid: 2)});
      await tester.pump();
      // Il messaggio «Stile copiato» cita lo stesso nome: si tocca la voce della barra
      await toccaVoceBarra(tester, 'Incolla stile', settle: false);
      await tester.pump();
      expect(b.foto(2).borderRadius, 80);
      expect(b.foto(2).shadow, 40);
      expect(b.foto(2).adjust, presetAdjust('vintage'));
      expect(b.passi, passiPrima + 1);
      await tester.pump(
        const Duration(milliseconds: 500),
      ); // Il messaggio sostituisce il precedente
      expect(find.text('Stile incollato'), findsOneWidget);
      b.controllo.annulla();
      await tester.pump();
      expect(b.foto(2).borderRadius, 0);
    });
  });

  group('Indietro e Ripristina', () {
    testWidgets('il gesto indietro scarta e offre «Ripristina»', (
      tester,
    ) async {
      final b = _Banco(tester);
      await b.apri();
      await b.seleziona(1);
      await b.apriStrumento('Regola');
      await b.tocca('Luminosità');
      await b.cursore(0.9);
      final bozza = valoreRegolazione(b.foto(1), 'brightness');
      expect(bozza, greaterThan(40));
      // Gesto «indietro» di sistema: dal dettaglio di Luminosità torna prima alla griglia, poi chiude
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(b.stato.strumento, Strumento.regola);
      expect(find.byKey(const ValueKey('scheda-indietro')), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(b.stato.strumento, Strumento.nessuno);
      expect(valoreRegolazione(b.foto(1), 'brightness'), 0);
      expect(find.text('Modifica scartata'), findsOneWidget);
      expect(find.text('Ripristina'), findsOneWidget);
      // «Ripristina» rimette la modifica come un passo di cronologia
      await tester.tap(find.text('Ripristina'));
      await tester.pumpAndSettle();
      expect(valoreRegolazione(b.foto(1), 'brightness'), bozza);
      expect(b.passi, 2);
    });

    testWidgets('senza modifiche il gesto indietro chiude e basta', (
      tester,
    ) async {
      final b = _Banco(tester);
      await b.apri();
      await b.seleziona(1);
      await b.apriStrumento('Regola');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(b.stato.strumento, Strumento.nessuno);
      expect(find.text('Ripristina'), findsNothing);
    });

    testWidgets(
      '«Ripristina» non vale se nel frattempo il documento è cambiato',
      (tester) async {
        final b = _Banco(tester);
        await b.apri();
        await b.seleziona(1);
        await b.apriStrumento('Regola');
        await b.tocca('Luminosità');
        await b.cursore(0.9);
        b.controllo.chiudiStrumentoDaGesto();
        await tester.pump();
        b.controllo.duplicaSelezione();
        await tester.pump();
        final passi = b.passi;
        b.controllo.ripristinaScartata();
        await tester.pump();
        expect(b.passi, passi);
      },
    );

    testWidgets(
      'il pannello trascinato verso il basso scarta come il gesto indietro',
      (tester) async {
        final b = _Banco(tester);
        await b.apri();
        await b.seleziona(1);
        await b.apriStrumento('Cornice');
        await b.cursore(0.5);
        // Si afferra il bordo alto del pannello (lontano dal cursore) e si trascina verso il basso
        final alto = tester.getTopLeft(find.byType(PannelloBasso));
        await tester.flingFrom(
          alto + const Offset(400, 6),
          const Offset(0, 300),
          1500,
        );
        await tester.pumpAndSettle();
        expect(b.stato.strumento, Strumento.nessuno);
        expect(b.foto(1).borderRadius, 0);
        expect(find.text('Ripristina'), findsOneWidget);
      },
    );
  });

  group('Ritaglio', () {
    testWidgets(
      'pagina a schermo intero: proporzioni, scambio e ✓ applicano il ritaglio',
      (tester) async {
        final b = _Banco(tester);
        await b.apri(conFile: true);
        await b.seleziona(1);
        final prima = b.foto(1);
        await toccaVoceBarra(tester, 'Ritaglia', settle: false);
        await b.attendiRitaglio();
        expect(find.text('Libera'), findsOneWidget);
        for (final r in [
          'Originale',
          'Riquadro',
          '1:1',
          '4:5',
          '3:4',
          '2:3',
          '9:16',
        ]) {
          expect(find.text(r), findsOneWidget, reason: r);
        }
        expect(find.text('Foto intera'), findsOneWidget);
        expect(find.textContaining('Ritaglio:'), findsOneWidget);
        expect(find.text('Adatta il riquadro al ritaglio'), findsOneWidget);
        await b.tocca('1:1');
        // Foto 3:4 in verticale → il quadrato la taglia sopra e sotto
        expect(find.textContaining('3000 × 3000'), findsOneWidget);
        await b.tocca('4:5');
        expect(find.text('5:4'), findsNothing);
        await tester.tap(
          find.bySemanticsLabel('Scambia verticale e orizzontale'),
        );
        await tester.pump();
        expect(find.text('5:4'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Applica il ritaglio'));
        await tester.pumpAndSettle();
        final f = b.foto(1);
        expect(haRitaglio(f), isTrue);
        expect(
          f.crop[2] - f.crop[0],
          closeTo(1.0, 1e-6),
          reason: '5:4 in una foto 3:4: tutta la larghezza',
        );
        expect(b.passi, 2);
        // Il riquadro ha preso la forma del ritaglio (sta dentro quello di prima)
        expect(f.w / f.h, closeTo(5 / 4, 0.02));
        expect(f.w, lessThanOrEqualTo(prima.w + 1e-6));
        expect(find.text('Ritaglio applicato'), findsOneWidget);
        // Annulla riporta la foto intera
        b.controllo.annulla();
        await tester.pump();
        expect(haRitaglio(b.foto(1)), isFalse);
      },
    );

    testWidgets(
      'trascinare un angolo ridimensiona il rettangolo; ✕ chiude senza ritagliare',
      (tester) async {
        final b = _Banco(tester);
        await b.apri(conFile: true);
        await b.seleziona(1);
        await toccaVoceBarra(tester, 'Ritaglia', settle: false);
        await b.attendiRitaglio();
        final area = find.byType(CustomPaint).last;
        final r = tester.getRect(area);
        // Foto 3:4 in un'area larga: sta al centro, alta quanto l'area meno i margini
        final alto = r.height - 48;
        final largo = alto * 60 / 80;
        final sinistra = r.center.dx - largo / 2;
        final destra = r.center.dx + largo / 2;
        final su = r.center.dy - alto / 2;
        final giu = r.center.dy + alto / 2;
        // Angolo in alto a sinistra verso il centro
        await tester.dragFrom(
          Offset(sinistra + 1, su + 1),
          Offset(largo * 0.3, alto * 0.3),
        );
        await tester.pump();
        expect(find.textContaining('Ritaglio:'), findsOneWidget);
        expect(
          find.textContaining('2100'),
          findsNothing,
        ); // Non è più la foto intera
        // Angolo opposto: lo stesso
        await tester.dragFrom(
          Offset(destra - 1, giu - 1),
          Offset(-largo * 0.2, -alto * 0.2),
        );
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Chiudi senza ritagliare'));
        await tester.pumpAndSettle();
        expect(haRitaglio(b.foto(1)), isFalse);
        expect(b.passi, 1);
      },
    );

    testWidgets('una foto che non si legge lo dice', (tester) async {
      final b = _Banco(tester);
      await b.apri();
      await b.seleziona(1);
      await toccaVoceBarra(tester, 'Ritaglia', settle: false);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Non riesco a leggere questa foto'), findsOneWidget);
    });
  });
}
