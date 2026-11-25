/// Schermata «Sottotitoli» (roadmap S2, `scrollr/caption_dialog.py` del desktop): si scrivono le frasi di un video,
/// si sincronizzano con la voce e si traducono. Si apre a schermo intero come il Ritaglio: ✕ / ✓ in alto e un
/// Annulla tutto suo; con ✓ le modifiche diventano un solo passo di Annulla del progetto.
///
/// Due disposizioni, che seguono la tastiera: aperta = si scrive (video piccolo e casella del testo), chiusa = si
/// ritocca (video più grande, striscia del tempo e comandi della frase scelta). La casella del testo fa da elenco:
/// una frase per riga. L'audio lo suona il telefono (`Ascolto` di `scrl_video`) e fa da orologio; i fotogrammi lo
/// seguono. Tutte le regole sulle frasi sono nel motore (`ModificaSottotitoli`).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;
import 'package:scrl_video/scrl_video.dart';
import 'package:share_plus/share_plus.dart';

import '../export/consegna.dart';
import '../home/scambio_ui.dart' show selettoreFileProvider;
import '../l10n/app_localizations.dart';
import '../media/cache_media.dart';
import '../media/riproduzione_video.dart';
import '../render/regolazioni.dart' show immagineDaPixel;
import '../render/risorse_pagina.dart';
import '../render/sottotitoli.dart';
import '../theme/tokens.dart';
import 'sessione.dart';
import 'stato.dart';
import 'striscia_tempo.dart';
import 'vista_pagina.dart';
import 'widget_comuni.dart';

/// I sottotitoli ci sono dove il telefono sa leggere e suonare l'audio dei video (per ora Android).
bool get sottotitoliDisponibili =>
    defaultTargetPlatform == TargetPlatform.android;

/// Velocità di riproduzione: un tocco passa alla successiva.
const List<double> _velocita = [1.0, 0.75, 0.5];

/// ↺ / ↻: secondi indietro o avanti.
const double _salto = 3.0;

/// Esito della schermata confermata con ✓.
class RisultatoSottotitoli {
  const RisultatoSottotitoli(this.frasi, this.linguaTraduzione);
  final List<Frase> frasi;
  final String linguaTraduzione;
}

/// Apre la schermata per il video [videoUid]: crea il blocco se manca (entra nel progetto solo con ✓ e qualche
/// frase) e, con ✓, mette frasi e lingua nel blocco in un solo passo di cronologia.
Future<void> apriSottotitoli(
  BuildContext context,
  WidgetRef ref,
  int videoUid,
) async {
  final ctrl = ref.read(editorProvider.notifier);
  final p = ctrl.preparaSottotitoli(videoUid);
  if (p == null) return;
  final video = p.snapshot.items.firstWhere((x) => x.uid == videoUid);
  final r = await Navigator.of(context).push<RisultatoSottotitoli>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PaginaSottotitoli(
        sessione: ref.read(sessioneProvider),
        snapshot: p.snapshot,
        sottotitoli: p.sottotitoli,
        video: video,
      ),
    ),
  );
  if (r == null) return;
  ctrl.applicaSottotitoli(videoUid, r.frasi, r.linguaTraduzione);
}

enum _Audio { lettura, pronto, assente, illeggibile }

/// Inviluppo e pause dell'audio, calcolati fuori dal thread dell'interfaccia.
({List<double> inviluppo, List<Pausa> pause}) _analizza(Uint8List pcm) {
  final inv = inviluppo(pcm, Ascolto.frequenza);
  return (inviluppo: inv, pause: trovaPause(inv));
}

class PaginaSottotitoli extends ConsumerStatefulWidget {
  const PaginaSottotitoli({
    super.key,
    required this.sessione,
    required this.snapshot,
    required this.sottotitoli,
    required this.video,
  });

  final SessioneEditor sessione;

  /// Il documento con il blocco (anche nuovo): serve all'anteprima della pagina.
  final Snapshot snapshot;
  final CaptionItem sottotitoli;
  final PhotoItem video;

  @override
  ConsumerState<PaginaSottotitoli> createState() => _PaginaSottotitoliState();
}

class _PaginaSottotitoliState extends ConsumerState<PaginaSottotitoli>
    with SingleTickerProviderStateMixin {
  ModificaSottotitoli? _m;
  late final _CasellaFrasi _testo = _CasellaFrasi();
  final FocusNode _fuocoTesto = FocusNode();
  Timer? _attesaTesto;
  bool _aggiornando = false;

  _Audio _audio = _Audio.lettura;
  Ascolto? _ascolto;
  List<double> _inviluppo = const [];

  LettoreVideo? _lettore;
  bool _occupato = false;
  double? _daLeggere;

  late final Ticker _ticker = createTicker(_tick);
  bool _chiedendo = false;
  final Stopwatch _orologio = Stopwatch();
  double _tOrologio = 0;
  bool _gira = false;
  double _tempo = 0;
  int _velocitaScelta = 0;

  int _scelta = -1;
  bool _traduzione = false;
  final Map<int, TextEditingController> _traduzioni = {};
  Timer? _attesaTraduzione;

  Snapshot? _anteprima;
  List<Frase>? _frasiAnteprima;
  late final ImpaginazioneSottotitoli _misure = ImpaginazioneSottotitoli.di(
    widget.sottotitoli,
  );
  bool _chiuso = false;

  int get _uid => widget.video.uid;
  RisorsePagina get _risorse => widget.sessione.risorse;

  @override
  void initState() {
    super.initState();
    _testo.addListener(_testoCambiato);
    // Il video della pagina è «in riproduzione» finché la schermata è aperta: niente frase di esempio sopra.
    // Dopo il primo disegno, perché avvisa anche la tela dell'editor che sta sotto
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chiuso) _risorse.segnaRiproduzione(_uid);
    });
    unawaited(_prepara());
  }

  @override
  void dispose() {
    _chiuso = true;
    _ticker.dispose();
    _attesaTesto?.cancel();
    _attesaTraduzione?.cancel();
    _testo.dispose();
    _fuocoTesto.dispose();
    for (final c in _traduzioni.values) {
      c.dispose();
    }
    final a = _ascolto;
    if (a != null) unawaited(_senzaErrori(a.chiudi()));
    final l = _lettore;
    if (l != null) unawaited(_senzaErrori(l.chiudi()));
    // Torna la copertina; dopo lo smontaggio, perché avvisa anche la tela dell'editor
    final risorse = _risorse, uid = _uid;
    scheduleMicrotask(() => risorse.togliFotogramma(uid));
    super.dispose();
  }

  static Future<void> _senzaErrori(Future<void> f) async {
    try {
      await f;
    } on Exception {
      // Già chiuso
    }
  }

  // ---------------------------------------------------------------- Apertura

  Future<void> _prepara() async {
    final v = widget.video;
    final info = await _risorse.caricaInfoVideo(v);
    if (_chiuso) return;
    final durata = (info?.durata ?? 0) > 0
        ? info!.durata
        : (v.trimEnd ?? v.trimStart + 1.0);
    final fine = (v.trimEnd ?? durata).clamp(v.trimStart, durata).toDouble();
    final c = widget.sottotitoli;
    final m = ModificaSottotitoli(
      frasi: c.frasi,
      durata: durata,
      inizioTaglio: v.trimStart,
      fineTaglio: fine,
      lingua: c.lang,
      linguaTraduzione: c.trLang,
    );
    setState(() {
      _m = m;
      _tempo = v.trimStart;
      _riempiTesto();
    });
    final src = await widget.sessione.cache.sorgenteVideo(
      sorgenteDi(v, widget.sessione.cartella.path),
    );
    if (_chiuso) return;
    if (src == null) {
      setState(() => _audio = _Audio.illeggibile);
      return;
    }
    unawaited(_apriLettore(src));
    await _apriAudio(src, info?.audio ?? true);
  }

  Future<void> _apriLettore(String src) async {
    try {
      final l = await widget.sessione.apriLettoreVideo(src);
      if (_chiuso) {
        await l.chiudi();
        return;
      }
      _lettore = l;
      _chiediFotogramma(_tempo);
    } on Exception catch (e) {
      debugPrint('Sottotitoli, fotogrammi: $e');
    }
  }

  /// Lettura dell'audio in sottofondo: intanto si scrive; quando è pronto le frasi prendono i tempi veri.
  Future<void> _apriAudio(String src, bool haAudio) async {
    if (!haAudio) {
      setState(() => _audio = _Audio.assente);
      return;
    }
    try {
      final a = await Ascolto.apri(src);
      if (_chiuso) {
        if (a != null) await a.chiudi();
        return;
      }
      if (a == null) {
        setState(() => _audio = _Audio.assente);
        return;
      }
      final r = await compute(_analizza, a.pcm);
      if (_chiuso) {
        await a.chiudi();
        return;
      }
      // Se si sta già guardando in silenzio, si continua con l'audio dallo stesso punto
      final giraGia = _gira;
      if (giraGia) _fermaOrologio();
      setState(() {
        _ascolto = a;
        _inviluppo = r.inviluppo;
        _audio = _Audio.pronto;
        _applicaTesto();
        _m!.impostaPause(r.pause);
        _dopoModifica(riempi: false);
      });
      if (giraGia) await _avvia(_tempo);
    } on Exception catch (e) {
      debugPrint('Sottotitoli, audio: $e');
      if (!_chiuso) setState(() => _audio = _Audio.illeggibile);
    }
  }

  // ---------------------------------------------------------------- Riproduzione

  double get _vel => _velocita[_velocitaScelta];

  Future<void> _alterna() => _gira ? _pausa() : _riproduci();

  Future<void> _riproduci() async {
    final m = _m;
    if (m == null) return;
    var t = _tempo;
    if (t >= m.durata - 0.05) t = m.inizioTaglio;
    await _avvia(t);
  }

  Future<void> _avvia(double t) async {
    final a = _ascolto;
    if (a != null) {
      await a.suona(t, velocita: _vel);
    } else {
      _tOrologio = t;
      _orologio
        ..reset()
        ..start();
    }
    if (_chiuso) return;
    setState(() {
      _gira = true;
      _tempo = t;
    });
    if (!_ticker.isActive) unawaited(_ticker.start());
  }

  void _fermaOrologio() {
    _tOrologio += _orologio.elapsedMicroseconds / 1e6 * _vel;
    _orologio.stop();
  }

  Future<void> _pausa() async {
    if (!_gira) return;
    _ticker.stop();
    final a = _ascolto;
    var t = _tempo;
    if (a != null) {
      t = await a.ferma();
    } else {
      _fermaOrologio();
      t = _tOrologio;
    }
    if (_chiuso) return;
    setState(() {
      _gira = false;
      _tempo = t.clamp(0.0, _m!.durata);
    });
    _chiediFotogramma(_tempo);
  }

  Future<void> _vaiA(double t) async {
    final m = _m;
    if (m == null) return;
    t = t.clamp(0.0, m.durata);
    if (_gira) {
      final a = _ascolto;
      if (a != null) {
        await a.suona(t, velocita: _vel);
      } else {
        _tOrologio = t;
        _orologio
          ..reset()
          ..start();
      }
    }
    if (_chiuso) return;
    setState(() => _tempo = t);
    _chiediFotogramma(t);
  }

  Future<void> _cambiaVelocita() async {
    if (!_gira) {
      setState(
        () => _velocitaScelta = (_velocitaScelta + 1) % _velocita.length,
      );
      return;
    }
    if (_ascolto == null) _fermaOrologio();
    setState(() => _velocitaScelta = (_velocitaScelta + 1) % _velocita.length);
    final a = _ascolto;
    if (a != null) {
      await a.velocita(_vel);
    } else {
      _orologio
        ..reset()
        ..start();
    }
  }

  Future<void> _tick(Duration _) async {
    final m = _m;
    if (!_gira || m == null || _chiedendo) return;
    final a = _ascolto;
    double t;
    var finito = false;
    if (a != null) {
      _chiedendo = true;
      try {
        final r = await a.tempo();
        t = r.t;
        finito = !r.suona;
      } on Exception {
        return;
      } finally {
        _chiedendo = false;
      }
    } else {
      t = _tOrologio + _orologio.elapsedMicroseconds / 1e6 * _vel;
      finito = t >= m.durata;
    }
    if (_chiuso || !_gira) return;
    if (finito) {
      await _pausa();
      if (!_chiuso) setState(() => _tempo = m.durata);
      return;
    }
    setState(() => _tempo = t.clamp(0.0, m.durata));
    _chiediFotogramma(_tempo);
  }

  /// Il fotogramma del secondo [t]; se il precedente non è pronto si tiene solo l'ultima richiesta.
  void _chiediFotogramma(double t) {
    final l = _lettore;
    if (l == null) return;
    if (_occupato) {
      _daLeggere = t;
      return;
    }
    _occupato = true;
    unawaited(() async {
      try {
        final f = await l.a(t);
        if (f == null || _chiuso) return;
        final img = await immagineDaPixel(f.rgba, f.larghezza, f.altezza);
        if (_chiuso) {
          img.dispose();
          return;
        }
        _risorse.impostaFotogramma(_uid, img, tempo: t);
      } on Exception catch (e) {
        debugPrint('Sottotitoli, fotogramma: $e');
      } finally {
        _occupato = false;
        final dopo = _daLeggere;
        _daLeggere = null;
        if (dopo != null && !_chiuso) _chiediFotogramma(dopo);
      }
    }());
  }

  // ---------------------------------------------------------------- Testo

  /// Una frase sta in due righe del blocco (per dividere il testo incollato).
  bool _sta(String s) =>
      staInDueRighe(s, _misure.larghezzaFrase, widget.sottotitoli.wrapW);

  void _riempiTesto() {
    final m = _m;
    if (m == null) return;
    final testo = m.testo;
    if (_testo.text == testo) return;
    _aggiornando = true;
    _attesaTesto?.cancel();
    final cursore = _testo.selection.baseOffset;
    _testo.value = TextEditingValue(
      text: testo,
      selection: TextSelection.collapsed(
        offset: cursore < 0 ? testo.length : cursore.clamp(0, testo.length),
      ),
    );
    _aggiornando = false;
  }

  String _ultimoTesto = '';

  void _testoCambiato() {
    final nuovo = _testo.text;
    if (_aggiornando || nuovo == _ultimoTesto) {
      _ultimoTesto = nuovo;
      return;
    }
    final vecchio = _ultimoTesto;
    _ultimoTesto = nuovo;
    // Testo incollato (più righe o lungo): si divide da solo in frasi corte, come `PhraseEdit`
    final inserito = _inserito(vecchio, nuovo);
    if (inserito != null &&
        inserito.testo.length > 1 &&
        (inserito.testo.contains('\n') || inserito.testo.length > 60)) {
      final diviso = dividiTesto(inserito.testo, _sta).join('\n');
      final testo = nuovo.replaceRange(
        inserito.inizio,
        inserito.inizio + inserito.testo.length,
        diviso,
      );
      _aggiornando = true;
      _testo.value = TextEditingValue(
        text: testo,
        selection: TextSelection.collapsed(
          offset: inserito.inizio + diviso.length,
        ),
      );
      _ultimoTesto = testo;
      _aggiornando = false;
    }
    _attesaTesto?.cancel();
    _attesaTesto = Timer(const Duration(milliseconds: 600), () {
      if (!_chiuso) setState(_applicaTesto);
    });
  }

  /// Il pezzo aggiunto tra [prima] e [dopo] (null se si è anche tolto qualcosa).
  static ({int inizio, String testo})? _inserito(String prima, String dopo) {
    if (dopo.length <= prima.length) return null;
    var a = 0;
    while (a < prima.length && prima.codeUnitAt(a) == dopo.codeUnitAt(a)) {
      a++;
    }
    var b = 0;
    while (b < prima.length - a &&
        prima.codeUnitAt(prima.length - 1 - b) ==
            dopo.codeUnitAt(dopo.length - 1 - b)) {
      b++;
    }
    if (a + b != prima.length) return null;
    return (inizio: a, testo: dopo.substring(a, dopo.length - b));
  }

  /// `_apply_text_box`: la casella diventa le frasi (subito, prima di ogni altro comando).
  void _applicaTesto() {
    _attesaTesto?.cancel();
    final m = _m;
    if (m == null || _traduzione) return;
    if (m.applicaTesto(_testo.text)) _dopoModifica(riempi: false);
  }

  /// Tocco su una riga a video fermo: si salta all'inizio della frase.
  void _toccoTesto() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final m = _m;
      if (m == null || _gira || _chiuso) return;
      final pos = _testo.selection.baseOffset;
      if (pos < 0) return;
      final righe = _testo.text.substring(0, pos).split('\n');
      if (righe.last.trim().isEmpty) return;
      final i = righe.where((r) => r.trim().isNotEmpty).length - 1;
      if (i < 0 || i >= m.frasi.length) return;
      setState(() => _scelta = i);
      final inizio = m.frasi[i].inizio;
      if (inizio != null) unawaited(_vaiA(inizio));
    });
  }

  /// Dopo un comando: la casella, la scelta e l'anteprima seguono le frasi nuove.
  void _dopoModifica({bool riempi = true}) {
    final m = _m!;
    if (riempi) _riempiTesto();
    if (_scelta >= m.frasi.length) _scelta = -1;
    for (final e in _traduzioni.entries) {
      if (e.key < m.frasi.length && e.value.text != m.frasi[e.key].tr) {
        e.value.text = m.frasi[e.key].tr;
      }
    }
  }

  void _comando(bool Function(ModificaSottotitoli m) f) {
    final m = _m;
    if (m == null) return;
    _applicaTesto();
    setState(() {
      if (f(m)) _dopoModifica();
    });
  }

  // ---------------------------------------------------------------- Traduzione

  TextEditingController _traduzioneDi(int i, String tr) =>
      _traduzioni.putIfAbsent(i, () => TextEditingController(text: tr));

  void _traduzioneCambiata(int i, String v) {
    _attesaTraduzione?.cancel();
    _attesaTraduzione = Timer(const Duration(milliseconds: 600), () {
      if (!_chiuso) setState(() => _m?.impostaTraduzione(i, v));
    });
  }

  void _applicaTraduzioni() {
    _attesaTraduzione?.cancel();
    final m = _m;
    if (m == null) return;
    for (final e in _traduzioni.entries) {
      if (e.key < m.frasi.length) m.impostaTraduzione(e.key, e.value.text);
    }
  }

  void _cambiaModo(bool traduzione) {
    if (traduzione == _traduzione) return;
    setState(() {
      if (traduzione) {
        _applicaTesto();
      } else {
        _applicaTraduzioni();
        _riempiTesto();
      }
      for (final c in _traduzioni.values) {
        c.dispose();
      }
      _traduzioni.clear();
      _traduzione = traduzione;
    });
    FocusManager.instance.primaryFocus?.unfocus();
  }

  // ---------------------------------------------------------------- File .srt

  Future<void> _foglioSrt() async {
    final t = Testi.of(context);
    final scelta = await showModalBottomSheet<int>(
      context: context,
      sheetAnimationStyle: MotoScrl.foglio(context),
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('srt-importa'),
              leading: const Icon(Icons.file_open_outlined),
              title: Text(t.sotImportaSrt),
              onTap: () => Navigator.of(c).pop(0),
            ),
            ListTile(
              key: const ValueKey('srt-condividi'),
              leading: const Icon(Icons.share_outlined),
              title: Text(t.sotCondividiSrt),
              onTap: () => Navigator.of(c).pop(1),
            ),
          ],
        ),
      ),
    );
    if (scelta == 0) await _importaSrt();
    if (scelta == 1) await _condividiSrt();
  }

  void _avvisa(String testo) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(testo)));
  }

  Future<void> _importaSrt() async {
    final t = Testi.of(context);
    final m = _m;
    if (m == null) return;
    _applicaTesto();
    _applicaTraduzioni();
    final scelti = await ref.read(selettoreFileProvider)(t.sotImportaSrt);
    if (scelti.isEmpty || !mounted) return;
    final file = File(scelti.first.percorso);
    String testo;
    try {
      final dati = await file.readAsBytes();
      try {
        testo = utf8.decode(dati);
      } on FormatException {
        testo = latin1.decode(dati); // Vecchi .srt di Windows
      }
      if (testo.startsWith('﻿')) testo = testo.substring(1);
    } on FileSystemException {
      _avvisa(t.sotSrtVuoto);
      return;
    } finally {
      if (scelti.first.temporaneo) {
        unawaited(file.delete().then((_) {}, onError: (_) {}));
      }
    }
    final lette = leggiSrt(testo);
    if (lette.isEmpty) {
      _avvisa(t.sotSrtVuoto);
      return;
    }
    var comeTraduzione = false;
    if (m.frasi.isNotEmpty) {
      if (!mounted) return;
      final r = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(t.sotImportaSrt),
          content: Text(t.sotImportaDomanda(lette.length)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(d).pop(),
              child: Text(t.annulla),
            ),
            TextButton(
              key: const ValueKey('srt-come-traduzione'),
              onPressed: () => Navigator.of(d).pop(true),
              child: Text(t.sotComeTraduzione),
            ),
            FilledButton(
              key: const ValueKey('srt-sostituisci'),
              onPressed: () => Navigator.of(d).pop(false),
              child: Text(t.sotSostituisci),
            ),
          ],
        ),
      );
      if (r == null) return;
      comeTraduzione = r;
    }
    if (!mounted) return;
    setState(() {
      m.importaSrt(lette, comeTraduzione: comeTraduzione);
      _scelta = -1;
      _dopoModifica();
    });
  }

  Future<void> _condividiSrt() async {
    final t = Testi.of(context);
    final m = _m;
    if (m == null) return;
    _applicaTesto();
    _applicaTraduzioni();
    if (!m.frasi.any((p) => p.sincronizzata && pyStrip(p.testo).isNotEmpty)) {
      _avvisa(t.sotSrtNiente);
      return;
    }
    final cartella = Directory(
      '${(await ref.read(cartellaTemporaneaProvider)()).path}/srt',
    );
    await cartella.create(recursive: true);
    final base = _nomeBase();
    // Le righe del .srt vanno a capo alla maniera di Windows, come scrive il desktop
    String crlf(String s) => s.replaceAll('\n', '\r\n');
    final file = [
      File('${cartella.path}/$base.${m.lingua.isEmpty ? 'it' : m.lingua}.srt')
        ..writeAsStringSync(crlf(inSrt(m.frasi))),
      if (m.frasi.any((p) => pyStrip(p.tr).isNotEmpty))
        File(
          '${cartella.path}/$base.${m.linguaTraduzione.isEmpty ? 'tr' : m.linguaTraduzione}.srt',
        )..writeAsStringSync(crlf(inSrt(m.frasi, traduzione: true))),
    ];
    await SharePlus.instance.share(
      ShareParams(
        files: [
          for (final f in file) XFile(f.path, mimeType: 'application/x-subrip'),
        ],
      ),
    );
  }

  /// Nome del file del video senza estensione (`_srt_base_name`), o «sottotitoli».
  String _nomeBase() {
    final nome = widget.video.path.split(RegExp(r'[\\/]')).last;
    final punto = nome.lastIndexOf('.');
    final base = punto > 0 ? nome.substring(0, punto) : nome;
    return base.trim().isEmpty ? 'sottotitoli' : base;
  }

  Future<void> _incolla() async {
    final dati = await Clipboard.getData(Clipboard.kTextPlain);
    final testo = dati?.text ?? '';
    if (testo.trim().isEmpty || !mounted) return;
    final diviso = dividiTesto(testo, _sta).join('\n');
    _aggiornando = true;
    _testo.value = TextEditingValue(
      text: diviso,
      selection: TextSelection.collapsed(offset: diviso.length),
    );
    _ultimoTesto = diviso;
    _aggiornando = false;
    setState(_applicaTesto);
  }

  // ---------------------------------------------------------------- Chiusura

  Future<void> _chiudi() async {
    final m = _m;
    if (m == null) {
      Navigator.of(context).pop();
      return;
    }
    _applicaTesto();
    _applicaTraduzioni();
    if (m.cambiato) {
      final t = Testi.of(context);
      final scarta = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          content: Text(t.sotScartaDomanda),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: Text(t.sotContinua),
            ),
            FilledButton(
              key: const ValueKey('sottotitoli-scarta'),
              onPressed: () => Navigator.of(d).pop(true),
              child: Text(t.sotScarta),
            ),
          ],
        ),
      );
      if (scarta != true || !mounted) return;
    }
    await _pausa();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _conferma() async {
    final m = _m;
    if (m == null) return;
    _applicaTesto();
    _applicaTraduzioni();
    await _pausa();
    if (!mounted) return;
    Navigator.of(context)
        .pop(RisultatoSottotitoli(m.frasiFinali(), m.linguaTraduzione));
  }

  // ---------------------------------------------------------------- Disegno

  Snapshot _documento(ModificaSottotitoli m) {
    if (_anteprima == null || !identical(_frasiAnteprima, m.frasi)) {
      _frasiAnteprima = m.frasi;
      _anteprima = modificaSottotitoli(widget.snapshot, [
        widget.sottotitoli.uid,
      ], (c) => c.copyWith(frasi: m.frasi));
    }
    return _anteprima!;
  }

  String? _avvisoAudio(Testi t) => switch (_audio) {
    _Audio.lettura => t.sotLetturaAudio,
    _Audio.assente => t.sotSenzaAudio,
    _Audio.illeggibile => t.sotAudioIlleggibile,
    _Audio.pronto => null,
  };

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final m = _m;
    final scrive = MediaQuery.viewInsetsOf(context).bottom > 0;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (fatto, _) {
        if (!fatto) unawaited(_chiudi());
      },
      child: Scaffold(
        backgroundColor: ColoriScrl.fondo,
        body: SafeArea(
          child: Column(
            children: [
              _barraAlta(t, m),
              if (m == null)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, vincoli) =>
                        _corpo(t, m, scrive, vincoli.maxHeight),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barraAlta(Testi t, ModificaSottotitoli? m) => SizedBox(
    height: MisureScrl.tocco,
    child: Row(
      children: [
        PulsanteIcona(
          key: const ValueKey('sottotitoli-chiudi'),
          icona: Icons.close_rounded,
          etichetta: t.sotChiudi,
          onTap: () => unawaited(_chiudi()),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: ControlloSegmentato<bool>(
              voci: [
                VoceSegmento(
                  valore: false,
                  etichetta: t.sotTesto,
                  chiave: const ValueKey('modo-testo'),
                ),
                VoceSegmento(
                  valore: true,
                  etichetta: t.sotTraduzione,
                  chiave: const ValueKey('modo-traduzione'),
                ),
              ],
              scelto: _traduzione,
              onScelto: m == null ? (_) {} : _cambiaModo,
            ),
          ),
        ),
        PulsanteIcona(
          key: const ValueKey('sottotitoli-annulla'),
          icona: Icons.undo_rounded,
          etichetta: t.annulla,
          onTap: m != null && (m.puoAnnullare || _testo.text != m.testo)
              ? () => _comando((m) {
                  final r = m.annulla();
                  if (r) _scelta = -1;
                  return r;
                })
              : null,
        ),
        Semantics(
          button: true,
          label: t.sotFileSrt,
          excludeSemantics: true,
          child: InkResponse(
            key: const ValueKey('sottotitoli-srt'),
            onTap: m == null ? null : () => unawaited(_foglioSrt()),
            radius: MisureScrl.tocco / 2,
            child: const SizedBox(
              width: MisureScrl.tocco,
              height: MisureScrl.tocco,
              child: Center(
                child: Text(
                  'SRT',
                  style: TextStyle(
                    fontSize: TestoScrl.piccolo,
                    fontWeight: TestoScrl.marcato,
                    color: ColoriScrl.testo,
                  ),
                ),
              ),
            ),
          ),
        ),
        PulsanteIcona(
          key: const ValueKey('sottotitoli-fatto'),
          icona: Icons.check_rounded,
          etichetta: t.sotFatto,
          onTap: m == null ? null : () => unawaited(_conferma()),
          colore: ColoriScrl.accento,
        ),
      ],
    ),
  );

  Widget _corpo(Testi t, ModificaSottotitoli m, bool scrive, double alto) {
    final avviso = _avvisoAudio(t);
    return Column(
      children: [
        SizedBox(
          height: alto * (scrive ? 0.30 : 0.34),
          child: GestureDetector(
            key: const ValueKey('sottotitoli-video'),
            behavior: HitTestBehavior.opaque,
            onTap: () => unawaited(_alterna()),
            child: VistaPagina(
              snapshot: _documento(m),
              pagina: Scene(
                widget.snapshot,
                widget.sessione.ctx,
              ).pageOf(widget.video),
              risorse: _risorse,
            ),
          ),
        ),
        _trasporto(t, m),
        if (avviso != null && (scrive || _audio == _Audio.assente))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
            child: Text(
              avviso,
              key: const ValueKey('sottotitoli-avviso-audio'),
              style: const TextStyle(
                fontSize: TestoScrl.piccolo,
                color: ColoriScrl.testoSecondario,
              ),
            ),
          ),
        if (!scrive) ...[
          SizedBox(
            height: 92,
            child: StrisciaTempo(
              key: const ValueKey('sottotitoli-striscia'),
              modifica: m,
              tempo: _tempo,
              inviluppo: _inviluppo,
              scelta: _scelta,
              etichetta: t.sotStrisciaTempo,
              avviso: avviso,
              onScorri: (v) {
                if (_gira) unawaited(_pausa());
                setState(() => _tempo = v);
                _chiediFotogramma(v);
              },
              onScorriFine: () {},
              onScegli: (i) {
                _applicaTesto();
                setState(() => _scelta = i);
              },
              onModificata: () => setState(_dopoModifica),
            ),
          ),
          _comandiFrase(t, m),
        ],
        Expanded(child: _traduzione ? _elencoTraduzioni(t, m) : _casella(t, m)),
      ],
    );
  }

  Widget _trasporto(Testi t, ModificaSottotitoli m) => SizedBox(
    height: MisureScrl.tocco,
    child: Row(
      children: [
        _Salto(
          key: const ValueKey('sottotitoli-indietro'),
          avanti: false,
          etichetta: t.sotIndietro3,
          onTap: () => unawaited(_vaiA(_tempo - _salto)),
        ),
        Semantics(
          button: true,
          label: _gira ? t.videoPausa : t.videoRiproduci,
          excludeSemantics: true,
          child: InkResponse(
            key: const ValueKey('sottotitoli-riproduci'),
            onTap: () => unawaited(_alterna()),
            radius: 28,
            child: SizedBox(
              width: 56,
              height: MisureScrl.tocco,
              child: Icon(
                _gira ? Icons.pause_circle_filled : Icons.play_circle_fill,
                size: 40,
                color: ColoriScrl.accento,
              ),
            ),
          ),
        ),
        _Salto(
          key: const ValueKey('sottotitoli-avanti'),
          avanti: true,
          etichetta: t.sotAvanti3,
          onTap: () => unawaited(_vaiA(_tempo + _salto)),
        ),
        const SizedBox(width: MisureScrl.spazioPiccolo),
        ChipParametro(
          key: const ValueKey('sottotitoli-velocita'),
          etichetta: t.sotVelocita(_formatoVelocita(_vel)),
          attivo: _velocitaScelta != 0,
          onTap: () => unawaited(_cambiaVelocita()),
        ),
        Expanded(
          child: Text(
            '${formatoOrologio(_tempo)} / ${formatoOrologio(m.durata)}',
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: const TextStyle(
              fontSize: TestoScrl.piccolo,
              color: ColoriScrl.testoSecondario,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: MisureScrl.spazio),
      ],
    ),
  );

  static String _formatoVelocita(double v) =>
      v == 1.0 ? '1' : v.toString().replaceAll('.', ',');

  Widget _comandiFrase(Testi t, ModificaSottotitoli m) {
    final i = _scelta;
    final scelta = i >= 0 && i < m.frasi.length ? m.frasi[i] : null;
    Widget chip(String chiave, String etichetta, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(right: MisureScrl.spazioPiccolo),
      child: ChipParametro(
        key: ValueKey(chiave),
        etichetta: etichetta,
        attivo: false,
        onTap: onTap,
      ),
    );
    return SizedBox(
      height: 56,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: MisureScrl.spazio,
          vertical: 8,
        ),
        child: Row(
          children: scelta == null
              ? [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(right: MisureScrl.spazio),
                      child: Text(
                        t.sotScegliFrase,
                        style: const TextStyle(
                          fontSize: TestoScrl.piccolo,
                          color: ColoriScrl.testoSecondario,
                        ),
                      ),
                    ),
                  ),
                  if (m.frasi.isNotEmpty)
                    chip(
                      'frase-tempi-audio',
                      t.sotTempiAudio,
                      () => _comando((m) => m.tempiDallAudio()),
                    ),
                ]
              : [
                  chip(
                    'frase-tempi',
                    scelta.sincronizzata
                        ? '${formatoOrologio(scelta.inizio)} – ${formatoOrologio(scelta.fine)}'
                        : '–',
                    () => unawaited(_foglioTempi()),
                  ),
                  chip(
                    'frase-inizia',
                    t.sotIniziaQui,
                    () =>
                        _comando((m) => m.segna(i, ParteFrase.inizio, _tempo)),
                  ),
                  chip(
                    'frase-finisci',
                    t.sotFinisciQui,
                    () => _comando((m) => m.segna(i, ParteFrase.fine, _tempo)),
                  ),
                  chip(
                    'frase-dividi',
                    t.sotDividiQui,
                    () => _comando((m) => m.dividi(i, _tempo)),
                  ),
                  if (i + 1 < m.frasi.length)
                    chip(
                      'frase-unisci',
                      t.sotUnisci,
                      () => _comando((m) => m.unisci(i)),
                    ),
                  chip(
                    'frase-elimina',
                    t.elimina,
                    () => _comando((m) {
                      _scelta = -1;
                      return m.elimina(i);
                    }),
                  ),
                ],
        ),
      ),
    );
  }

  /// Tocco sul tempo della frase: −0,1 s / +0,1 s per inizio e fine.
  Future<void> _foglioTempi() async {
    final t = Testi.of(context);
    await showModalBottomSheet<void>(
      context: context,
      sheetAnimationStyle: MotoScrl.foglio(context),
      builder: (c) => StatefulBuilder(
        builder: (c, aggiorna) {
          final m = _m!;
          final i = _scelta;
          if (i < 0 || i >= m.frasi.length) return const SizedBox.shrink();
          final p = m.frasi[i];
          Widget riga(String nome, ParteFrase parte, double? valore) => Row(
            children: [
              const SizedBox(width: MisureScrl.spazio),
              Expanded(
                child: Text(
                  '$nome  ${formatoOrologio(valore)}',
                  style: const TextStyle(
                    fontSize: TestoScrl.normale,
                    color: ColoriScrl.testo,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              for (final (dt, etichetta, chiave) in [
                (-0.1, t.sotMeno01, 'meno'),
                (0.1, t.sotPiu01, 'piu'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: MisureScrl.spazio),
                  child: ChipParametro(
                    key: ValueKey('tempo-${parte.name}-$chiave'),
                    etichetta: etichetta,
                    attivo: false,
                    onTap: () {
                      _comando((m) => m.spostaBordo(i, parte, dt));
                      aggiorna(() {});
                    },
                  ),
                ),
            ],
          );
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: MisureScrl.spazio),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  riga(t.sotInizio, ParteFrase.inizio, p.inizio),
                  const SizedBox(height: MisureScrl.spazioPiccolo),
                  riga(t.sotFine, ParteFrase.fine, p.fine),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Indice della frase che si sente ora (-1 fuori dalle frasi).
  int _fraseOra(ModificaSottotitoli m) => indiceFraseA(m.frasi, _tempo);

  Widget _casella(Testi t, ModificaSottotitoli m) {
    _testo.evidenziata = _fraseOra(m);
    final vuota = m.frasi.isEmpty && _testo.text.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MisureScrl.spazio,
        MisureScrl.spazioPiccolo,
        MisureScrl.spazio,
        MisureScrl.spazioPiccolo,
      ),
      child: Column(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('sottotitoli-testo'),
              controller: _testo,
              focusNode: _fuocoTesto,
              expands: true,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              textAlignVertical: TextAlignVertical.top,
              onTap: _toccoTesto,
              style: const TextStyle(
                fontSize: TestoScrl.grande,
                height: 1.4,
                color: ColoriScrl.testo,
              ),
              decoration: InputDecoration(
                hintText: t.sotVuoto,
                hintMaxLines: 3,
              ),
            ),
          ),
          if (vuota)
            Padding(
              padding: const EdgeInsets.only(top: MisureScrl.spazioPiccolo),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('sottotitoli-incolla'),
                      onPressed: () => unawaited(_incolla()),
                      icon: const Icon(Icons.content_paste_rounded),
                      label: Text(t.sotIncolla),
                    ),
                  ),
                  const SizedBox(width: MisureScrl.spazioPiccolo),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('sottotitoli-importa'),
                      onPressed: () => unawaited(_importaSrt()),
                      icon: const Icon(Icons.file_open_outlined),
                      label: Text(t.sotImportaSrt),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _elencoTraduzioni(Testi t, ModificaSottotitoli m) {
    final ora = _fraseOra(m);
    return ListView.builder(
      key: const ValueKey('sottotitoli-traduzioni'),
      padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
      itemCount: m.frasi.length + 1,
      itemBuilder: (context, k) {
        if (k == 0) {
          return Row(
            children: [
              Expanded(
                child: Text(
                  t.sotLinguaTraduzione,
                  style: const TextStyle(
                    fontSize: TestoScrl.normale,
                    color: ColoriScrl.testoSecondario,
                  ),
                ),
              ),
              SizedBox(
                width: 72,
                child: TextFormField(
                  key: const ValueKey('sottotitoli-lingua'),
                  initialValue: m.linguaTraduzione,
                  maxLength: 8,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(counterText: ''),
                  onChanged: (v) =>
                      setState(() => m.linguaTraduzione = v.trim()),
                ),
              ),
            ],
          );
        }
        final i = k - 1;
        final p = m.frasi[i];
        return Container(
          margin: const EdgeInsets.only(top: MisureScrl.spazioPiccolo),
          padding: const EdgeInsets.all(MisureScrl.spazioPiccolo),
          decoration: BoxDecoration(
            color: i == ora ? ColoriScrl.rilievo : ColoriScrl.barra,
            borderRadius: BorderRadius.circular(MisureScrl.angoloTessera),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: p.inizio == null
                    ? null
                    : () => unawaited(_vaiA(p.inizio!)),
                child: Text(
                  p.testo,
                  style: const TextStyle(
                    fontSize: TestoScrl.normale,
                    color: ColoriScrl.testoSecondario,
                  ),
                ),
              ),
              TextField(
                key: ValueKey('traduzione-$i'),
                controller: _traduzioneDi(i, p.tr),
                minLines: 1,
                maxLines: 3,
                style: const TextStyle(
                  fontSize: TestoScrl.grande,
                  color: ColoriScrl.testo,
                ),
                decoration: InputDecoration(
                  hintText: t.sotTraduzione,
                  isDense: true,
                ),
                onChanged: (v) => _traduzioneCambiata(i, v),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Casella del testo, una frase per riga: la riga della frase che si sente si colora (le righe vuote non contano).
class _CasellaFrasi extends TextEditingController {
  int evidenziata = -1;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (evidenziata < 0 || value.composing.isValid) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final righe = text.split('\n');
    final figli = <TextSpan>[];
    var k = -1;
    for (var j = 0; j < righe.length; j++) {
      final r = righe[j];
      if (r.trim().isNotEmpty) k++;
      final accesa = r.trim().isNotEmpty && k == evidenziata;
      figli.add(
        TextSpan(
          text: j < righe.length - 1 ? '$r\n' : r,
          style: accesa
              ? const TextStyle(
                  color: ColoriScrl.accentoTesto,
                  fontWeight: TestoScrl.marcato,
                )
              : null,
        ),
      );
    }
    return TextSpan(style: style, children: figli);
  }
}

/// ↺ 3 s / 3 s ↻: la freccia circolare con il numero dei secondi dentro.
class _Salto extends StatelessWidget {
  const _Salto({
    super.key,
    required this.avanti,
    required this.etichetta,
    required this.onTap,
  });

  final bool avanti;
  final String etichetta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: etichetta,
    excludeSemantics: true,
    child: InkResponse(
      onTap: onTap,
      radius: MisureScrl.tocco / 2,
      child: SizedBox(
        width: MisureScrl.tocco,
        height: MisureScrl.tocco,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.flip(
              flipX: avanti,
              child: const Icon(
                Icons.replay_rounded,
                size: 30,
                color: ColoriScrl.testo,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                '${_salto.round()}',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: TestoScrl.marcato,
                  color: ColoriScrl.testo,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
