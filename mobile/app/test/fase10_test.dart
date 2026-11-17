import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Tristate;

import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;
import 'package:scrollr_studio/editor/editor_page.dart';
import 'package:scrollr_studio/editor/semantica_tela.dart';
import 'package:scrollr_studio/editor/sessione.dart';
import 'package:scrollr_studio/editor/stato.dart';
import 'package:scrollr_studio/editor/suggerimenti.dart';
import 'package:scrollr_studio/editor/tela.dart';
import 'package:scrollr_studio/editor/widget_comuni.dart';
import 'package:scrollr_studio/export/consegna.dart';
import 'package:scrollr_studio/export/preferenze.dart';
import 'package:scrollr_studio/home/home.dart';
import 'package:scrollr_studio/l10n/app_localizations.dart';
import 'package:scrollr_studio/media/cache_media.dart';
import 'package:scrollr_studio/media/galleria.dart';
import 'package:scrollr_studio/media/pulizia.dart';
import 'package:scrollr_studio/project/archivio.dart';
import 'package:scrollr_studio/project/crea_progetto.dart';
import 'package:scrollr_studio/project/provider.dart';
import 'package:scrollr_studio/settings/aggiornamenti.dart';
import 'package:scrollr_studio/settings/gesti_page.dart';
import 'package:scrollr_studio/settings/impostazioni_page.dart';
import 'package:scrollr_studio/settings/registro_errori.dart';
import 'package:scrollr_studio/theme/tema.dart';
import 'package:scrollr_studio/theme/tokens.dart';

// ---------- Utilità ----------

/// Elenco delle release come lo darebbe GitHub: desktop (`v*`) e mobile (`mobile-v*`) mescolati.
String _elencoRelease(List<(String tag, {bool bozza, bool prerelease})> r) =>
    jsonEncode([
      for (final (tag, :bozza, :prerelease) in r)
        {'tag_name': tag, 'draft': bozza, 'prerelease': prerelease},
    ]);

(String, {bool bozza, bool prerelease}) _r(
  String tag, {
  bool bozza = false,
  bool prerelease = false,
}) => (tag, bozza: bozza, prerelease: prerelease);

/// Contrasto WCAG tra due colori opachi.
double _contrasto(Color a, Color b) {
  double lum(Color c) {
    double f(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
    return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
  }

  final la = lum(a), lb = lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Widget _casa({
  required Widget child,
  PreferenzeApp? preferenze,
  List<Override> overrides = const [],
  double scalaTesto = 1.0,
  bool senzaAnimazioni = false,
  Locale lingua = const Locale('it'),
}) {
  return ProviderScope(
    overrides: [
      preferenzeProvider.overrideWithValue(
        preferenze ?? PreferenzeApp.inMemoria(),
      ),
      ...overrides,
    ],
    child: MaterialApp(
      theme: temaScrl(),
      locale: lingua,
      supportedLocales: Testi.supportedLocales,
      localizationsDelegates: const [
        Testi.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          // Come fa l'app: segue il sistema fino a 1,3×
          textScaler: TextScaler.linear(
            math.min(scalaTesto, TestoScrl.scalaMassima),
          ),
          disableAnimations: senzaAnimazioni,
        ),
        child: c!,
      ),
      home: child,
    ),
  );
}

FotoScelta _foto(int i) => (
  voce: LibraryEntry(path: 'foto$i.jpg', rel: 'media/foto$i.jpg'),
  chiave: 'f:media/foto$i.jpg',
  w: 3000,
  h: 4000,
);

/// Editor aperto su un progetto con [foto] foto finte e [pagine] pagine.
Future<SessioneEditor> _apriEditor(
  WidgetTester tester, {
  int foto = 4,
  int pagine = 1,
  PreferenzeApp? preferenze,
  double scalaTesto = 1.0,
  bool senzaAnimazioni = false,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final radice = Directory.systemTemp.createTempSync('scrl_fase10_test');
  addTearDown(() => radice.deleteSync(recursive: true));
  final archivio = ArchivioProgetti(Directory('${radice.path}/progetti'));
  late SessioneEditor sessione;
  await tester.runAsync(() async {
    final cartella = await archivio.nuovaCartella();
    var p = await creaProgetto(
      archivio: archivio,
      cartella: cartella,
      nome: 'Prova',
      formato: (indice: 0, larghezza: 1080, altezza: 1440),
      scelte: [for (var i = 1; i <= foto; i++) _foto(i)],
    );
    var s = p.file.snapshot;
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
    _casa(
      preferenze: preferenze,
      scalaTesto: scalaTesto,
      senzaAnimazioni: senzaAnimazioni,
      child: EditorPage(sessione: sessione),
    ),
  );
  await tester.pumpAndSettle();
  return sessione;
}

ProviderContainer _contenitore(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(TelaEditor)));

void main() {
  // ---------- Controllo degli aggiornamenti ----------
  group('versioni', () {
    test('analizzaVersione legge tag e versioni', () {
      expect(analizzaVersione('mobile-v1.2.3'), [1, 2, 3]);
      expect(analizzaVersione('v1.8'), [1, 8, 0]);
      expect(analizzaVersione('2'), [2, 0, 0]);
      expect(analizzaVersione('boh'), isNull);
    });

    test('il confronto è numerico, non alfabetico', () {
      expect(piuNuova('1.10.0', '1.9.0'), isTrue);
      expect(piuNuova('1.0.1', '1.0.0'), isTrue);
      expect(piuNuova('1.0.0', '1.0.0'), isFalse);
      expect(piuNuova('0.9.9', '1.0.0'), isFalse);
      expect(piuNuova('boh', '1.0.0'), isFalse);
    });
  });

  group('ultimaMobile', () {
    test('tiene solo i tag mobile-v*: le release del desktop non contano', () {
      final json = jsonDecode(
        _elencoRelease([
          _r('v9.0.0'), // Desktop, più alta: va ignorata
          _r('mobile-v1.0.1'),
          _r('v1.8.1'),
          _r('mobile-v1.0.0'),
        ]),
      );
      final n = ultimaMobile(json, '1.0.0');
      expect(n?.tag, 'mobile-v1.0.1');
      expect(n?.versione, '1.0.1');
      expect(
        n?.indirizzo.toString(),
        'https://github.com/Michelo1927/ScrolleR-Studio/releases/tag/mobile-v1.0.1',
      );
    });

    test('nessun avviso se si è già all\'ultima o più avanti', () {
      final json = jsonDecode(_elencoRelease([_r('mobile-v1.0.0')]));
      expect(ultimaMobile(json, '1.0.0'), isNull);
      expect(ultimaMobile(json, '1.1.0'), isNull);
    });

    test('bozze, pre-release e tag strani si ignorano', () {
      final json = jsonDecode(
        _elencoRelease([
          _r('mobile-v2.0.0', bozza: true),
          _r('mobile-v1.5.0', prerelease: true),
          _r('mobile-vx'),
          _r('mobile-v1.0.1'),
        ]),
      );
      expect(ultimaMobile(json, '1.0.0')?.tag, 'mobile-v1.0.1');
    });

    test('risposte inattese non lanciano', () {
      expect(ultimaMobile(null, '1.0.0'), isNull);
      expect(ultimaMobile({'message': 'rate limit'}, '1.0.0'), isNull);
      expect(ultimaMobile(<Object?>[1, 'a', null], '1.0.0'), isNull);
    });
  });

  group('ControlloAggiornamenti', () {
    late PreferenzeApp pref;
    late List<Uri> richieste;
    late DateTime ora;
    String? risposta;

    ControlloAggiornamenti controllo({String versione = '1.0.0'}) =>
        ControlloAggiornamenti(
          preferenze: pref,
          versione: versione,
          scarica: (u) async {
            richieste.add(u);
            return risposta;
          },
          adesso: () => ora,
        );

    setUp(() {
      pref = PreferenzeApp.inMemoria();
      richieste = [];
      ora = DateTime(2026, 11, 17, 9);
      risposta = _elencoRelease([_r('v1.9.0'), _r('mobile-v1.0.1')]);
    });

    test(
      'all\'avvio trova la versione nuova e chiede solo le release',
      () async {
        final n = await controllo().alAvvio();
        expect(n?.versione, '1.0.1');
        expect(richieste, hasLength(1));
        expect(richieste.single.host, 'api.github.com');
        expect(
          richieste.single.path,
          '/repos/Michelo1927/ScrolleR-Studio/releases',
        );
      },
    );

    test('entro 24 ore non torna in rete e ripropone l\'avviso noto', () async {
      await controllo().alAvvio();
      ora = ora.add(const Duration(hours: 5));
      final n = await controllo().alAvvio();
      expect(n?.versione, '1.0.1');
      expect(richieste, hasLength(1));
      ora = ora.add(const Duration(hours: 20));
      await controllo().alAvvio();
      expect(richieste, hasLength(2));
    });

    test('disattivato: nessuna richiesta, nessun avviso', () async {
      await controllo().imposta(attivo: false);
      expect(await controllo().alAvvio(), isNull);
      expect(richieste, isEmpty);
    });

    test('«Controlla adesso» va in rete anche da disattivato', () async {
      await controllo().imposta(attivo: false);
      final e = await controllo().adessoSubito();
      expect(e.nuova?.versione, '1.0.1');
      expect(richieste, hasLength(1));
    });

    test(
      'chiudere l\'avviso nasconde quella versione, non le successive',
      () async {
        final n = (await controllo().alAvvio())!;
        await controllo().ignora(n);
        ora = ora.add(const Duration(days: 2));
        expect(await controllo().alAvvio(), isNull);
        risposta = _elencoRelease([_r('mobile-v1.0.2')]);
        ora = ora.add(const Duration(days: 2));
        expect((await controllo().alAvvio())?.versione, '1.0.2');
      },
    );

    test(
      'errori di rete: esito con errore, niente avviso, niente blocchi',
      () async {
        risposta = null;
        expect((await controllo().adessoSubito()).errore, isTrue);
        risposta = 'non è json';
        expect((await controllo().adessoSubito()).errore, isTrue);
        expect(await controllo().alAvvio(), isNull);
      },
    );

    test('senza rete configurata (prove) non esce mai', () async {
      final c = ControlloAggiornamenti(preferenze: pref, versione: '1.0.0');
      expect((await c.adessoSubito()).errore, isTrue);
      expect(await c.alAvvio(), isNull);
    });

    test('aggiornata: nessuna versione nuova e nessun errore', () async {
      final e = await controllo(versione: '1.0.1').adessoSubito();
      expect(e.nuova, isNull);
      expect(e.errore, isFalse);
    });
  });

  // ---------- Registro errori ----------
  group('RegistroErrori', () {
    late Directory radice;
    setUp(() => radice = Directory.systemTemp.createTempSync('scrl_log_test'));
    tearDown(() => radice.deleteSync(recursive: true));

    test('scrive l\'avvio e gli errori, senza percorsi del telefono', () async {
      final r = RegistroErrori(
        File('${radice.path}/errori.log'),
        versione: '1.0.0',
        radice: radice.path,
      );
      await r.avvia();
      expect(await r.haErrori(), isFalse);
      r.registra(
        'Impossibile leggere ${radice.path}/progetti/x/media/foto.jpg e '
        'content://media/external/images/media/42 e /storage/emulated/0/DCIM/a.jpg',
        StackTrace.fromString('#0 f (package:scrollr_studio/a.dart:1:1)'),
        contesto: 'Flutter',
      );
      final t = await r.leggi();
      expect(t, contains('ScrolleR Studio Mobile 1.0.0'));
      expect(t, contains('--- Flutter'));
      expect(t, contains('package:scrollr_studio/a.dart'));
      expect(t, isNot(contains(radice.path)));
      expect(t, isNot(contains('content://')));
      expect(t, isNot(contains('/storage/')));
      expect(t, contains('<app>'));
      expect(await r.haErrori(), isTrue);
      expect(r.numeroErrori, 1);
    });

    test('un registro troppo grande passa a .old', () async {
      final f = File('${radice.path}/errori.log')
        ..writeAsStringSync('x' * (limiteRegistroByte + 10));
      final r = RegistroErrori(f, versione: '1');
      await r.avvia();
      expect(File('${f.path}.old').existsSync(), isTrue);
      expect(f.lengthSync(), lessThan(1000));
    });

    test('non scrive più di vociMassimeSessione errori', () async {
      final r = RegistroErrori(File('${radice.path}/errori.log'));
      await r.avvia();
      for (var i = 0; i < vociMassimeSessione + 50; i++) {
        r.registra('e$i', null);
      }
      expect(r.numeroErrori, vociMassimeSessione);
    });

    test('svuota toglie tutto e riparte', () async {
      final f = File('${radice.path}/errori.log');
      final r = RegistroErrori(f);
      await r.avvia();
      r.registra('boom', null);
      await r.svuota();
      expect(await r.haErrori(), isFalse);
      expect(await r.leggi(), contains('Registro svuotato'));
    });

    test('un file illeggibile non fa lanciare nulla', () async {
      final r = RegistroErrori(
        File('${radice.path}/cartella-inesistente/x/errori.log'),
      );
      r.registra('boom', null); // Senza avvia() e senza cartella
      expect(r.numeroErrori, 1);
    });
  });

  // ---------- Pulizia ----------
  group('pulizia', () {
    late Directory radice;
    setUp(() => radice = Directory.systemTemp.createTempSync('scrl_pulizia'));
    tearDown(() => radice.deleteSync(recursive: true));

    test(
      'anteprime orfane: via solo quelle di foto non più in uso e vecchie',
      () async {
        final cache = CacheMedia(cartella: Directory('${radice.path}/cache'));
        const inUso = SorgenteMedia(
          'f:media/in-uso.jpg',
          MediaLocation(MediaSource.missing, name: 'in-uso.jpg'),
        );
        cache.cartella.createSync(recursive: true);
        // Nomi dei file come li costruisce la cache: <hash>_<lato>.img
        final nomi = <String>[];
        for (final chiave in ['f:media/in-uso.jpg', 'f:media/tolta.jpg']) {
          for (final lato in [320, 1600]) {
            nomi.add('${_hashCache(chiave)}_$lato.img');
          }
        }
        for (final n in nomi) {
          final f = File('${cache.cartella.path}/$n')..writeAsBytesSync([1]);
          f.setLastModifiedSync(
            DateTime.now().subtract(const Duration(days: 3)),
          );
        }
        // Una foto «tolta» ma scritta pochi secondi fa (può essere appena aggiunta): non si tocca
        final recente = File(
          '${cache.cartella.path}/${_hashCache('f:media/nuova.jpg')}_320.img',
        )..writeAsBytesSync([1]);
        File('${cache.cartella.path}/altro.txt').writeAsStringSync('non è mia');

        final tolti = await cache.pulisciOrfane([inUso.chiave]);
        expect(tolti, 2); // Le due misure della foto tolta
        final restano = cache.cartella
            .listSync()
            .map((e) => e.uri.pathSegments.last)
            .toSet();
        expect(
          restano,
          contains('${_hashCache('f:media/in-uso.jpg')}_320.img'),
        );
        expect(
          restano,
          contains('${_hashCache('f:media/in-uso.jpg')}_1600.img'),
        );
        expect(restano, contains(recente.uri.pathSegments.last));
        expect(restano, contains('altro.txt'));
        expect(restano, hasLength(4));
      },
    );

    test('temporanei: via solo le cartelle dell\'app e vecchie', () async {
      final vecchie = ['esportazione_1', 'condividi', 'importa'];
      for (final n in vecchie) {
        final d = Directory('${radice.path}/$n')..createSync();
        File('${d.path}/a.bin').writeAsBytesSync([1, 2, 3]);
      }
      Directory('${radice.path}/esportazione_2').createSync(); // Di adesso
      Directory('${radice.path}/di-un-altro').createSync();
      final tolti = await puliziaTemporanei(
        radice,
        adesso: DateTime.now().add(const Duration(days: 2)),
        eta: const Duration(hours: 24),
      );
      // Con «adesso» fra due giorni sono tutte vecchie, ma solo quelle dell'app si toccano
      expect(tolti, 4);
      expect(Directory('${radice.path}/di-un-altro').existsSync(), isTrue);
      expect(Directory('${radice.path}/condividi').existsSync(), isFalse);
      // Una vera «di adesso» resta
      Directory('${radice.path}/esportazione_3').createSync();
      expect(await puliziaTemporanei(radice), 0);
      expect(Directory('${radice.path}/esportazione_3').existsSync(), isTrue);
    });
  });

  // ---------- Suggerimenti del primo avvio ----------
  group('suggerimentoGiusto', () {
    const vuoto = ContestoSuggerimenti(
      haElementi: false,
      haSelezione: false,
      strumentoAperto: false,
      pagine: 1,
    );
    ContestoSuggerimenti c({
      bool elementi = true,
      bool selezione = false,
      bool strumento = false,
      int pagine = 1,
    }) => ContestoSuggerimenti(
      haElementi: elementi,
      haSelezione: selezione,
      strumentoAperto: strumento,
      pagine: pagine,
    );

    test('tre soli suggerimenti', () {
      expect(Suggerimento.values, hasLength(3));
    });

    test('tocca → premuto → scorri, ognuno al suo momento', () {
      expect(suggerimentoGiusto({}, vuoto), isNull);
      expect(suggerimentoGiusto({}, c()), Suggerimento.tocca);
      expect(suggerimentoGiusto({}, c(selezione: true)), Suggerimento.premuto);
      expect(
        suggerimentoGiusto({Suggerimento.tocca}, c(pagine: 3)),
        Suggerimento.scorri,
      );
      expect(suggerimentoGiusto({}, c(pagine: 3)), Suggerimento.tocca);
    });

    test('mai due volte e mai con uno strumento aperto', () {
      expect(
        suggerimentoGiusto({Suggerimento.tocca}, c()),
        isNull,
        reason: 'già visto',
      );
      expect(
        suggerimentoGiusto({Suggerimento.premuto}, c(selezione: true)),
        isNull,
      );
      expect(suggerimentoGiusto({}, c(strumento: true)), isNull);
      expect(
        suggerimentoGiusto({...Suggerimento.values}, c(pagine: 4)),
        isNull,
      );
    });
  });

  testWidgets('suggerimenti nell\'editor: uno alla volta, una volta sola', (
    tester,
  ) async {
    final pref = PreferenzeApp.inMemoria();
    await _apriEditor(tester, pagine: 2, preferenze: pref);
    final t = Testi.of(tester.element(find.byType(TelaEditor)));
    // Subito dopo l'apertura non c'è niente: prima una breve pausa
    expect(find.text(t.suggerimentoTocca), findsNothing);
    await tester.pump(attesaSuggerimento + const Duration(milliseconds: 100));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text(t.suggerimentoTocca), findsOneWidget);
    expect(await pref.leggiTesti(chiaveSuggerimentiVisti), ['tocca']);

    // Toccare una foto = averlo imparato: il suggerimento sparisce, e arriva «tieni premuto»
    final ctrl = _contenitore(tester).read(editorProvider.notifier);
    ctrl.seleziona([
      rifDi(_contenitore(tester).read(editorProvider).snapshot.items.first),
    ]);
    await tester.pump();
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text(t.suggerimentoTocca), findsNothing);
    await tester.pump(attesaSuggerimento + const Duration(milliseconds: 100));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text(t.suggerimentoPremuto), findsOneWidget);

    // Il fumetto si chiude toccandolo
    await tester.tap(find.text(t.suggerimentoPremuto));
    await tester.pumpAndSettle();
    expect(find.text(t.suggerimentoPremuto), findsNothing);
    ctrl.deseleziona();
    await tester.pump();
    // Resta «scorri» (due pagine)
    await tester.pump(attesaSuggerimento + const Duration(milliseconds: 100));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text(t.suggerimentoScorri), findsOneWidget);
    // Si chiude da solo
    await tester.pump(durataSuggerimento + const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text(t.suggerimentoScorri), findsNothing);
    expect((await pref.leggiTesti(chiaveSuggerimentiVisti)).toSet(), {
      'tocca',
      'premuto',
      'scorri',
    });

    // Riaprendo l'editor non torna più nessuno
    await tester.pumpWidget(const SizedBox());
    await _apriEditor(tester, pagine: 2, preferenze: pref);
    await tester.pump(attesaSuggerimento * 3);
    await tester.pumpAndSettle();
    final t2 = Testi.of(tester.element(find.byType(TelaEditor)));
    for (final s in Suggerimento.values) {
      expect(find.text(testoSuggerimento(t2, s)), findsNothing);
    }
  });

  testWidgets('chi cambia pagina da solo non vede «scorri»', (tester) async {
    final pref = PreferenzeApp.inMemoria();
    await pref.scrivi(chiaveSuggerimentiVisti, ['tocca', 'premuto']);
    await _apriEditor(tester, pagine: 3, preferenze: pref);
    final ctrl = _contenitore(tester).read(editorProvider.notifier);
    await tester.pump(const Duration(milliseconds: 500));
    ctrl.vaiAPagina(1);
    await tester.pump(attesaSuggerimento * 3);
    await tester.pumpAndSettle();
    final t = Testi.of(tester.element(find.byType(TelaEditor)));
    expect(find.text(t.suggerimentoScorri), findsNothing);
    expect(await pref.leggiTesti(chiaveSuggerimentiVisti), contains('scorri'));
  });

  // ---------- Impostazioni e Gesti ----------
  group('Impostazioni', () {
    List<Override> rete(
      List<String> aperti,
      List<File> condivisi,
      Directory tmp,
    ) => [
      scaricaTestoProvider.overrideWithValue(
        (_) async => _elencoRelease([_r('v2.0.0'), _r('mobile-v1.0.1')]),
      ),
      versioneAppProvider.overrideWithValue('1.0.0'),
      apriIndirizzoProvider.overrideWithValue((u) async {
        aperti.add(u.toString());
        return true;
      }),
      condividiFileProvider.overrideWithValue((f) async {
        condivisi.add(File(f.path)..readAsStringSync());
      }),
      cartellaTemporaneaProvider.overrideWithValue(() async => tmp),
    ];

    testWidgets('la Home apre le Impostazioni e queste i Gesti', (
      tester,
    ) async {
      final radice = Directory.systemTemp.createTempSync('scrl_imp_test');
      addTearDown(() => radice.deleteSync(recursive: true));
      await tester.pumpWidget(
        _casa(
          overrides: [
            archivioProvider.overrideWithValue(ArchivioProgetti(radice)),
          ],
          child: const HomePage(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-impostazioni')));
      await tester.pumpAndSettle();
      expect(find.text('Impostazioni'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('imp-gesti')));
      await tester.pumpAndSettle();
      expect(find.byType(GestiPage), findsOneWidget);
      expect(find.text('Sulla tela'), findsOneWidget);
      expect(find.text('Tieni premuto su un elemento'), findsOneWidget);
      expect(
        find.text('Doppio tocco su un cursore', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('interruttore aggiornamenti e controllo a mano', (
      tester,
    ) async {
      final aperti = <String>[];
      final pref = PreferenzeApp.inMemoria();
      await tester.pumpWidget(
        _casa(
          preferenze: pref,
          overrides: rete(aperti, [], Directory.systemTemp),
          child: const ImpostazioniPage(),
        ),
      );
      await tester.pumpAndSettle();
      // Acceso di partenza
      expect(
        await pref.leggiBool(chiaveControlloAttivo, predefinito: true),
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('imp-controllo')));
      await tester.pumpAndSettle();
      expect(
        await pref.leggiBool(chiaveControlloAttivo, predefinito: true),
        isFalse,
      );
      // «Controlla adesso» funziona comunque e annuncia la versione mobile, non quella del desktop
      await tester.tap(find.byKey(const ValueKey('imp-controlla-ora')));
      await tester.pumpAndSettle();
      expect(find.textContaining('1.0.1'), findsWidgets);
      expect(find.textContaining('2.0.0'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('imp-scarica')));
      await tester.pumpAndSettle();
      expect(aperti, [
        'https://github.com/Michelo1927/ScrolleR-Studio/releases/tag/mobile-v1.0.1',
      ]);
    });

    testWidgets('registro: condividi e svuota', (tester) async {
      // Schermo alto: tutta la pagina in vista, senza scorrere
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tmp = Directory.systemTemp.createTempSync('scrl_reg_ui');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final registro = RegistroErrori.inMemoria(versione: '1.0.0');
      final condivisi = <File>[];
      await tester.pumpWidget(
        _casa(
          overrides: [
            ...rete([], condivisi, tmp),
            registroErroriProvider.overrideWithValue(registro),
          ],
          child: const ImpostazioniPage(),
        ),
      );
      await tester.pumpAndSettle();
      // Vuoto: le due voci sono spente
      expect(find.text('Nessun errore registrato'), findsOneWidget);
      registro.registra('boom', StackTrace.fromString('#0 f'));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        _casa(
          overrides: [
            ...rete([], condivisi, tmp),
            registroErroriProvider.overrideWithValue(registro),
          ],
          child: const ImpostazioniPage(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ci sono errori registrati'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('imp-registro-condividi')));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(condivisi, hasLength(1));
      expect(condivisi.single.path, endsWith(nomeFileRegistro));
      expect(condivisi.single.readAsStringSync(), contains('boom'));

      await tester.tap(find.byKey(const ValueKey('imp-registro-svuota')));
      await tester.pumpAndSettle();
      expect(find.text('Svuotare il registro degli errori?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Svuota il registro'));
      await tester.pumpAndSettle();
      expect(await registro.haErrori(), isFalse);
      expect(find.text('Nessun errore registrato'), findsOneWidget);
    });

    testWidgets('«Rivedi i suggerimenti» li rimette tutti da vedere', (
      tester,
    ) async {
      final pref = PreferenzeApp.inMemoria();
      await pref.scrivi(chiaveSuggerimentiVisti, [
        'tocca',
        'premuto',
        'scorri',
      ]);
      await tester.pumpWidget(
        _casa(preferenze: pref, child: const ImpostazioniPage()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('imp-suggerimenti')));
      await tester.pumpAndSettle();
      expect(await pref.leggiTesti(chiaveSuggerimentiVisti), isEmpty);
    });

    testWidgets('l\'avviso nella Home: scarica e nascondi', (tester) async {
      final radice = Directory.systemTemp.createTempSync('scrl_home_agg');
      addTearDown(() => radice.deleteSync(recursive: true));
      final aperti = <String>[];
      final pref = PreferenzeApp.inMemoria();
      await tester.pumpWidget(
        _casa(
          preferenze: pref,
          overrides: [
            archivioProvider.overrideWithValue(ArchivioProgetti(radice)),
            ...rete(aperti, [], Directory.systemTemp),
          ],
          child: const HomePage(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('È disponibile la versione 1.0.1'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('home-aggiornamento-scarica')),
      );
      await tester.pumpAndSettle();
      expect(aperti, hasLength(1));
      await tester.tap(
        find.byKey(const ValueKey('home-aggiornamento-nascondi')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('È disponibile'), findsNothing);
      expect(await pref.leggi(chiaveIgnorata), 'mobile-v1.0.1');
    });

    testWidgets('con il controllo spento la Home non mostra né chiede nulla', (
      tester,
    ) async {
      final radice = Directory.systemTemp.createTempSync('scrl_home_off');
      addTearDown(() => radice.deleteSync(recursive: true));
      final pref = PreferenzeApp.inMemoria();
      await pref.scrivi(chiaveControlloAttivo, false);
      var richieste = 0;
      await tester.pumpWidget(
        _casa(
          preferenze: pref,
          overrides: [
            archivioProvider.overrideWithValue(ArchivioProgetti(radice)),
            versioneAppProvider.overrideWithValue('1.0.0'),
            scaricaTestoProvider.overrideWithValue((_) async {
              richieste++;
              return null;
            }),
          ],
          child: const HomePage(),
        ),
      );
      await tester.pumpAndSettle();
      expect(richieste, 0);
      expect(find.textContaining('È disponibile'), findsNothing);
    });
  });

  // ---------- Accessibilità ----------
  group('accessibilità', () {
    test('contrasto AA (4,5:1) delle coppie di colori con testo', () {
      const superfici = {
        'fondo': ColoriScrl.fondo,
        'barra': ColoriScrl.barra,
        'pannello': ColoriScrl.pannello,
        'rilievo': ColoriScrl.rilievo,
      };
      void minimo(String nome, Color fg, Color bg, [double soglia = 4.5]) {
        final c = _contrasto(fg, bg);
        expect(
          c,
          greaterThanOrEqualTo(soglia),
          reason: '$nome: ${c.toStringAsFixed(2)}',
        );
      }

      for (final e in superfici.entries) {
        minimo('testo su ${e.key}', ColoriScrl.testo, e.value);
        minimo('accentoTesto su ${e.key}', ColoriScrl.accentoTesto, e.value);
        minimo('pericoloTesto su ${e.key}', ColoriScrl.pericoloTesto, e.value);
      }
      // Il testo secondario sta su fondo, barre e pannelli (non sulle tessere `rilievo`)
      for (final k in ['fondo', 'barra', 'pannello']) {
        minimo(
          'testoSecondario su $k',
          ColoriScrl.testoSecondario,
          superfici[k]!,
        );
      }
      // Tessera selezionata (`premuto`): testo e testo con l'accento schiarito
      minimo('testo su premuto', ColoriScrl.testo, ColoriScrl.premuto);
      minimo(
        'accentoTesto su premuto',
        ColoriScrl.accentoTesto,
        ColoriScrl.premuto,
      );
      // Testo bianco su riempimenti
      minimo(
        'bianco su accentoPieno',
        ColoriScrl.suAccento,
        ColoriScrl.accentoPieno,
      );
      minimo(
        'bianco su pericoloPieno',
        ColoriScrl.suAccento,
        ColoriScrl.pericoloPieno,
      );
      // L'accento «vero» (cursori, bordi, icone) è un elemento grafico: almeno 3:1 sul pannello e sulla barra
      minimo('accento su pannello', ColoriScrl.accento, ColoriScrl.pannello, 3);
      minimo('accento su barra', ColoriScrl.accento, ColoriScrl.barra, 3);
    });

    testWidgets(
      'testo grande 1,3×: Home, Impostazioni e Gesti senza sbordare',
      (tester) async {
        tester.view.physicalSize = const Size(
          360 * 2,
          640 * 2,
        ); // Telefono piccolo
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        final radice = Directory.systemTemp.createTempSync('scrl_scala');
        addTearDown(() => radice.deleteSync(recursive: true));
        for (final pagina in <Widget>[
          const HomePage(),
          const ImpostazioniPage(),
          const GestiPage(),
        ]) {
          for (final lingua in const [Locale('it'), Locale('en')]) {
            await tester.pumpWidget(
              _casa(
                scalaTesto: 2.0, // Il sistema chiede 2×: l'app si ferma a 1,3×
                lingua: lingua,
                overrides: [
                  archivioProvider.overrideWithValue(ArchivioProgetti(radice)),
                ],
                child: pagina,
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: '$pagina $lingua');
            final scala = MediaQuery.textScalerOf(
              tester.element(find.byType(Scaffold).first),
            ).scale(10);
            expect(scala, closeTo(13, 0.01));
          }
        }
      },
    );

    testWidgets(
      'editor a 1,3× (telefono piccolo): barra e pannelli senza sbordare',
      (tester) async {
        tester.view.physicalSize = const Size(360 * 2, 640 * 2);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        final radice = Directory.systemTemp.createTempSync('scrl_scala_ed');
        addTearDown(() => radice.deleteSync(recursive: true));
        final archivio = ArchivioProgetti(Directory('${radice.path}/progetti'));
        late SessioneEditor sessione;
        await tester.runAsync(() async {
          final cartella = await archivio.nuovaCartella();
          final p = await creaProgetto(
            archivio: archivio,
            cartella: cartella,
            nome: 'Prova',
            formato: (indice: 0, larghezza: 1080, altezza: 1440),
            scelte: [for (var i = 1; i <= 3; i++) _foto(i)],
          );
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
          _casa(scalaTesto: 1.3, child: EditorPage(sessione: sessione)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final ctrl = _contenitore(tester).read(editorProvider.notifier);
        for (final s in [
          Strumento.libreria,
          Strumento.disposizione,
          Strumento.pagine,
          Strumento.stile,
          Strumento.aggiungi,
        ]) {
          ctrl.apriStrumento(s);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$s a 1,3×');
          ctrl.chiudiStrumentoDaGesto();
          await tester.pumpAndSettle();
        }
      },
    );

    testWidgets(
      '«riduci animazioni»: il pannello compare subito, senza animare',
      (tester) async {
        await _apriEditor(tester, senzaAnimazioni: true);
        final ctrl = _contenitore(tester).read(editorProvider.notifier);
        expect(find.byType(AnimatedSize), findsNothing);
        ctrl.apriStrumento(Strumento.disposizione);
        // Un solo frame: nessuna animazione da attendere, nessuna asserzione di layout
        await tester.pump();
        expect(tester.takeException(), isNull);
        final contesto = tester.element(find.byType(TelaEditor));
        expect(MotoScrl.durata(contesto, MotoScrl.pannello), Duration.zero);
        expect(MotoScrl.foglio(contesto), AnimationStyle.noAnimation);
        // Con le animazioni normali, invece, il pannello si anima
        await tester.pumpWidget(const SizedBox());
        await _apriEditor(tester);
        expect(find.byType(AnimatedSize), findsOneWidget);
      },
    );

    testWidgets(
      'semantica della tela: pagina corrente, elementi e scorrimento',
      (tester) async {
        final semantica = tester.ensureSemantics();
        await _apriEditor(tester, pagine: 2);
        final c = _contenitore(tester);
        final stato = c.read(editorProvider);
        expect(stato.snapshot.items, isNotEmpty);
        // «Pagina 1 di 2» sulla tela
        expect(find.bySemanticsLabel(RegExp(r'^Tela')), findsOneWidget);
        final tela = tester.semantics.find(
          find.bySemanticsLabel(RegExp(r'^Tela')),
        );
        expect(tela.value, 'Pagina 1 di 2');
        expect(
          tela.getSemanticsData().hasAction(SemanticsAction.scrollLeft),
          isTrue,
        );
        expect(
          tela.getSemanticsData().hasAction(SemanticsAction.scrollRight),
          isFalse,
          reason: 'sulla prima pagina non si torna indietro',
        );
        // Un nodo per ogni elemento della prima pagina, con nome parlato
        final sulla = elementiDellaPagina(
          stato.snapshot,
          0,
          c.read(sessioneProvider).ctx.textSize,
        );
        expect(sulla, isNotEmpty);
        expect(find.bySemanticsLabel('Foto 1'), findsOneWidget);

        // Doppio tocco del lettore di schermo sul nodo = selezione, come con il dito
        final nodo = tester.semantics.find(find.bySemanticsLabel('Foto 1'));
        expect(nodo.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        expect(
          nodo.getSemanticsData().hasAction(SemanticsAction.longPress),
          isTrue,
        );
        tester.semantics.tap(find.semantics.byLabel('Foto 1'));
        await tester.pump();
        final scelta = c.read(editorProvider).elementiSelezionati;
        expect(scelta, hasLength(1));
        expect(
          (scelta.single as PhotoItem).uid,
          stato.snapshot.items.first.uid,
        );
        await tester.pumpAndSettle();
        expect(
          tester.semantics
              .find(find.bySemanticsLabel('Foto 1'))
              .flagsCollection
              .isSelected,
          Tristate.isTrue,
        );

        // L'azione «scorri a sinistra» del lettore di schermo porta alla pagina dopo
        c.read(editorProvider.notifier).deseleziona();
        await tester.pump();
        tester.semantics.scrollLeft(
          scrollable: find.semantics.byLabel(RegExp(r'^Tela')),
        );
        await tester.pumpAndSettle();
        expect(c.read(editorProvider).pagina, 1);
        expect(
          tester.semantics.find(find.bySemanticsLabel(RegExp(r'^Tela'))).value,
          'Pagina 2 di 2',
        );
        semantica.dispose();
      },
    );

    testWidgets(
      'ogni comando della barra superiore e inferiore ha un\'etichetta',
      (tester) async {
        final semantica = tester.ensureSemantics();
        await _apriEditor(tester);
        // Ogni pulsante a icona e ogni voce della barra: bottone con etichetta non vuota
        final senzaEtichetta = <String>[];
        for (final tipo in [PulsanteIcona, VoceBarra]) {
          for (final e in find.byType(tipo).evaluate()) {
            final nodo = tester.semantics.find(find.byWidget(e.widget));
            final dati = nodo.getSemanticsData();
            if (dati.label.trim().isEmpty) senzaEtichetta.add('$tipo');
            expect(
              dati.flagsCollection.isButton,
              isTrue,
              reason: '$tipo ${dati.label} deve essere un bottone',
            );
          }
        }
        expect(senzaEtichetta, isEmpty);
        for (final etichetta in ['Indietro', 'Annulla', 'Ripeti', 'Esporta']) {
          expect(
            find.bySemanticsLabel(etichetta),
            findsWidgets,
            reason: etichetta,
          );
        }
        semantica.dispose();
      },
    );
  });

  test(
    'la versione dell\'app compare in pubspec e le note di rilascio esistono',
    () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final m = RegExp(
        r'^version:\s*(\d+\.\d+\.\d+)\+\d+',
        multiLine: true,
      ).firstMatch(pubspec);
      expect(m, isNotNull);
      final versione = m!.group(1)!;
      final note = File('../../release-notes/mobile-v$versione.md');
      expect(
        note.existsSync(),
        isTrue,
        reason: 'mancano le note di mobile-v$versione',
      );
      expect(
        note.readAsStringSync(),
        contains('ScrolleR Studio Mobile $versione'),
      );
    },
  );
}

/// Come `CacheMedia._hash`: serve a costruire i nomi dei file di cache (FNV-1a a 64 bit in esadecimale).
String _hashCache(String s) {
  var h = 0xcbf29ce484222325;
  for (final b in s.codeUnits) {
    h ^= b;
    h *= 0x100000001b3;
  }
  String meta(int v) => v.toRadixString(16).padLeft(8, '0');
  return meta((h >> 32) & 0xFFFFFFFF) + meta(h & 0xFFFFFFFF);
}
