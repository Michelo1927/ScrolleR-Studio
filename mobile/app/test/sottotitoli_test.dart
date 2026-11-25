// Sottotitoli sul telefono (roadmap S2): voce «Sottotitoli» del video, schermata a schermo intero con ✕ / ✓ e
// Annulla suo, casella del testo che fa da elenco, comandi della frase scelta sulla striscia del tempo, barra del
// blocco selezionato (Larghezza, Traduzione, strumenti del testo) e disegno sulla pagina.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;
import 'package:scrl_video/scrl_video.dart';
import 'package:scrollr_studio/editor/editor_page.dart';
import 'package:scrollr_studio/editor/pagina_sottotitoli.dart';
import 'package:scrollr_studio/editor/sessione.dart';
import 'package:scrollr_studio/editor/stato.dart';
import 'package:scrollr_studio/editor/striscia_tempo.dart';
import 'package:scrollr_studio/editor/tela.dart';
import 'package:scrollr_studio/l10n/app_localizations.dart';
import 'package:scrollr_studio/media/cache_media.dart';
import 'package:scrollr_studio/media/galleria.dart';
import 'package:scrollr_studio/media/riproduzione_video.dart';
import 'package:scrollr_studio/project/archivio.dart';
import 'package:scrollr_studio/render/sottotitoli.dart';
import 'package:scrollr_studio/theme/tema.dart';

const _info = InfoVideo(
  larghezza: 64,
  altezza: 48,
  durata: 10,
  fps: 30,
  audio: true,
);

class _LettoreFinto implements LettoreVideo {
  bool chiuso = false;

  @override
  Future<Fotogramma?> a(double t) async {
    final px = Uint8List(4 * 3 * 4);
    for (var i = 3; i < px.length; i += 4) {
      px[i] = 255;
    }
    return Fotogramma(4, 3, px);
  }

  @override
  Future<void> chiudi() async => chiuso = true;
}

PhotoItem _video() => PhotoItem(
  uid: 1,
  path: 'media/v.mp4',
  rel: 'media/v.mp4',
  isVideo: true,
  x: 100,
  y: 100,
  w: 600,
  h: 800,
  z: 1,
);

CaptionItem _blocco(List<Frase> frasi) =>
    CaptionItem.nuovo(uid: 5, videoUid: 1).copyWith(frasi: frasi);

void main() {
  late Directory radice;
  late _LettoreFinto lettore;

  Future<ProviderContainer> apri(
    WidgetTester tester, {
    List<CaptionItem> sottotitoli = const [],
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    radice = Directory.systemTemp.createTempSync('scrl_sottotitoli_test');
    addTearDown(() {
      try {
        radice.deleteSync(recursive: true);
      } on FileSystemException {
        // Su Windows un file può essere ancora aperto
      }
    });
    final cartella = Directory('${radice.path}/progetto')..createSync();
    File('${cartella.path}/media/v.mp4')
      ..createSync(recursive: true)
      ..writeAsBytesSync([0, 1, 2, 3]);
    lettore = _LettoreFinto();
    late SessioneEditor s;
    await tester.runAsync(() async {
      s = SessioneEditor(
        archivio: ArchivioProgetti(Directory(radice.path)),
        cartella: cartella,
        cache: CacheMedia(cartella: Directory('${cartella.path}/cache')),
        galleria: const Galleria(),
        dati: const DatiAccessori(nome: 'Prova', misure: {}),
        inizio: Snapshot(
          canvas: CanvasState(layoutSeed: 1),
          items: [_video()],
          captions: sottotitoli,
        ),
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
    await tester.runAsync(() => s.risorse.caricaInfoVideo(_video()));
    await tester.pump();
    return ProviderScope.containerOf(tester.element(find.byType(TelaEditor)));
  }

  /// Apre la schermata dalla barra del video e aspetta audio (assente nelle prove) e primo fotogramma.
  Future<void> apriSchermata(WidgetTester tester, ProviderContainer c) async {
    c.read(editorProvider.notifier).seleziona([
      (tipo: ElementKind.photo, uid: 1),
    ]);
    await tester.pump();
    // La barra può essere rimasta nella categoria Video
    if (find.byKey(const ValueKey('voce-sottotitoli')).evaluate().isEmpty) {
      await tester.tap(find.byKey(const ValueKey('cat-video')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('voce-sottotitoli')));
    await tester.pump();
    await attendi(tester);
    expect(find.byType(PaginaSottotitoli), findsOneWidget);
  }

  testWidgets('scrivere, ✓: il blocco nuovo nasce con le frasi in un passo', (
    tester,
  ) async {
    final c = await apri(tester);
    final passi = c.read(editorProvider).cronologia.states.length;
    await apriSchermata(tester, c);
    // Schermata vuota: «Incolla» e «Importa .srt»
    expect(find.byKey(const ValueKey('sottotitoli-incolla')), findsOneWidget);
    // Nelle prove il telefono non ha l'audio: si dice, e i tempi vanno su tutto il video
    expect(
      tester.widget<StrisciaTempo>(find.byType(StrisciaTempo)).avviso,
      startsWith('Audio non leggibile'),
    );
    await tester.enterText(
      find.byKey(const ValueKey('sottotitoli-testo')),
      'Ciao a tutti.\nOggi parliamo di foto.',
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byKey(const ValueKey('sottotitoli-incolla')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('sottotitoli-fatto')));
    await attendi(tester);
    expect(find.byType(PaginaSottotitoli), findsNothing);
    final st = c.read(editorProvider);
    final blocco = st.snapshot.captions.single;
    expect(blocco.videoUid, 1);
    expect(blocco.frasi.map((p) => p.testo), [
      'Ciao a tutti.',
      'Oggi parliamo di foto.',
    ]);
    expect(blocco.frasi.every((p) => p.auto && p.sincronizzata), isTrue);
    expect(blocco.frasi.first.inizio, 0);
    expect(blocco.frasi.last.fine, 10);
    expect(st.cronologia.states.length, passi + 1);
    expect(st.selezione, {(tipo: ElementKind.caption, uid: blocco.uid)});
  });

  testWidgets(
    '✕ con modifiche chiede conferma; un blocco nuovo vuoto non resta',
    (tester) async {
      final c = await apri(tester);
      await apriSchermata(tester, c);
      await tester.enterText(
        find.byKey(const ValueKey('sottotitoli-testo')),
        'Una frase',
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.tap(find.byKey(const ValueKey('sottotitoli-chiudi')));
      await tester.pumpAndSettle();
      expect(
        find.text('Chiudere senza tenere le modifiche ai sottotitoli?'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('sottotitoli-scarta')));
      await attendi(tester);
      expect(find.byType(PaginaSottotitoli), findsNothing);
      expect(c.read(editorProvider).snapshot.captions, isEmpty);
      // Senza modifiche ✓ non crea niente
      await apriSchermata(tester, c);
      await tester.tap(find.byKey(const ValueKey('sottotitoli-fatto')));
      await attendi(tester);
      expect(c.read(editorProvider).snapshot.captions, isEmpty);
    },
  );

  testWidgets(
    'frase scelta sulla striscia: Dividi qui, Annulla della schermata',
    (tester) async {
      final c = await apri(
        tester,
        sottotitoli: [
          _blocco(const [
            Frase(testo: 'uno due tre quattro', inizio: 0, fine: 4),
            Frase(testo: 'cinque sei', inizio: 4, fine: 6),
          ]),
        ],
      );
      final passi = c.read(editorProvider).cronologia.states.length;
      await apriSchermata(tester, c);
      expect(find.byType(StrisciaTempo), findsOneWidget);
      expect(find.byKey(const ValueKey('frase-dividi')), findsNothing);
      // Il blocco della prima frase è sotto la linea di lettura (al centro)
      await tester.tap(find.byType(StrisciaTempo));
      await tester.pump();
      expect(find.byKey(const ValueKey('frase-dividi')), findsOneWidget);
      expect(find.text('0:00,00 – 0:04,00'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('frase-dividi')));
      await tester.pump();
      final testo = tester.widget<TextField>(
        find.byKey(const ValueKey('sottotitoli-testo')),
      );
      // Divisa a metà dei caratteri, alla parola (`split_phrase`)
      expect(testo.controller!.text, 'uno due tre\nquattro\ncinque sei');
      await tester.tap(find.byKey(const ValueKey('sottotitoli-annulla')));
      await tester.pump();
      expect(testo.controller!.text, 'uno due tre quattro\ncinque sei');
      // Unisci e ✓: un solo passo nel progetto
      await tester.tap(find.byType(StrisciaTempo));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('frase-unisci')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('frase-unisci')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('sottotitoli-fatto')));
      await attendi(tester);
      final st = c.read(editorProvider);
      expect(
        st.snapshot.captions.single.frasi.single.testo,
        'uno due tre quattro cinque sei',
      );
      expect(st.cronologia.states.length, passi + 1);
      expect(st.cronologia.labels.last.kind, ChangeKind.captionsEdited);
    },
  );

  testWidgets('traduzione: una riga per frase, con la lingua', (tester) async {
    final c = await apri(
      tester,
      sottotitoli: [
        _blocco(const [Frase(testo: 'Ciao', inizio: 0, fine: 2)]),
      ],
    );
    await apriSchermata(tester, c);
    await tester.tap(find.byKey(const ValueKey('modo-traduzione')));
    await tester.pump();
    expect(find.text('Ciao'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('traduzione-0')), 'Hi');
    await tester.enterText(
      find.byKey(const ValueKey('sottotitoli-lingua')),
      'en',
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.byKey(const ValueKey('sottotitoli-fatto')));
    await attendi(tester);
    final b = c.read(editorProvider).snapshot.captions.single;
    expect(b.frasi.single.tr, 'Hi');
    expect(b.trLang, 'en');
  });

  testWidgets(
    'barra del blocco: niente Duplica, Mostra traduzione in un passo, '
    'strumenti del testo sullo stile',
    (tester) async {
      final c = await apri(
        tester,
        sottotitoli: [
          _blocco(const [Frase(testo: 'Ciao', tr: 'Hi', inizio: 0, fine: 2)]),
        ],
      );
      final ctrl = c.read(editorProvider.notifier);
      ctrl.seleziona([(tipo: ElementKind.caption, uid: 5)]);
      await tester.pump();
      for (final k in [
        'sottotitoli',
        'traduzione',
        'carattere',
        'colore',
        'disponi',
        'altro',
      ]) {
        expect(find.byKey(ValueKey('cat-$k')), findsOneWidget, reason: k);
      }
      await tester.tap(find.byKey(const ValueKey('cat-altro')));
      await tester.pump();
      expect(find.byKey(const ValueKey('voce-duplica')), findsNothing);
      expect(find.byKey(const ValueKey('voce-elimina')), findsOneWidget);
      ctrl.seleziona([(tipo: ElementKind.caption, uid: 5)]);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('barra-indietro')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('cat-traduzione')));
      await tester.pump();
      final passi = c.read(editorProvider).cronologia.states.length;
      await tester.tap(find.byKey(const ValueKey('voce-mostra-traduzione')));
      await tester.pump();
      var st = c.read(editorProvider);
      expect(st.snapshot.captions.single.trShow, isFalse);
      expect(st.cronologia.states.length, passi + 1);
      // Uno strumento del testo cambia lo stile del blocco, che resta centrato
      final prima = st.snapshot.captions.single;
      final centro = prima.x + misuraSottotitoli(prima).w / 2;
      ctrl.modificaTestiSelezionati((t) => t.copyWith(size: 90));
      ctrl.conferma();
      st = c.read(editorProvider);
      final dopo = st.snapshot.captions.single;
      expect(dopo.stile.size, 90);
      expect(dopo.stile.text, '');
      expect(dopo.x + misuraSottotitoli(dopo).w / 2, closeTo(centro, 1e-6));
      // Larghezza: bozza, ✓ = un passo
      ctrl.modificaSottotitoliSelezionati(
        (x, ctx) => conLarghezzaSottotitoli(x, 50, 1080, ctx),
      );
      ctrl.conferma();
      expect(c.read(editorProvider).snapshot.captions.single.wrapW, 540);
    },
  );

  testWidgets('eliminare il video toglie anche i suoi sottotitoli', (
    tester,
  ) async {
    final c = await apri(
      tester,
      sottotitoli: [
        _blocco(const [Frase(testo: 'Ciao', inizio: 0, fine: 2)]),
      ],
    );
    final ctrl = c.read(editorProvider.notifier);
    ctrl.seleziona([(tipo: ElementKind.photo, uid: 1)]);
    ctrl.eliminaSelezione();
    await tester.pump();
    final st = c.read(editorProvider);
    expect(st.snapshot.items, isEmpty);
    expect(st.snapshot.captions, isEmpty);
    expect(st.cronologia.labels.last.kind, ChangeKind.removed);
  });
}

/// Lascia lavorare le parti asincrone vere (fotogrammi, file) e poi disegna.
Future<void> attendi(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
  // I fotogrammi tolti si liberano con un attimo di ritardo
  await tester.pump(const Duration(seconds: 1));
}
