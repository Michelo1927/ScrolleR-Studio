/// La tela dell'editor: una pagina alla volta con scorrimento a scatti, selezione, spostamento con aggancio,
/// ridimensionamento con le maniglie, pizzico e rotazione (piano §4.2 e §4.5).
///
/// Qui c'è solo l'interazione: ogni numero (aggancio, nuove misure, rotazione con scatti) lo calcola il motore.
/// I gesti producono una **bozza** durante il movimento e un passo di cronologia alla fine.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;
import 'package:scrl_engine/scrl_engine.dart' as motore show Rect;

import '../l10n/app_localizations.dart';
import '../media/riproduzione_video.dart';
import '../render/campiona.dart';
import '../render/disegno.dart';
import '../render/risorse_pagina.dart';
import '../theme/tokens.dart';
import 'geometria_tela.dart';
import 'menu_pressione_lunga.dart';
import 'semantica_tela.dart';
import 'sessione.dart';
import 'stato.dart';
import 'vista_pagina.dart';
import 'widget_comuni.dart';

enum _Modo {
  nessuno,
  scorri,
  sposta,
  maniglia,
  manigliaForma,
  pizzica,
  inquadra,

  /// Zoom e spostamento della vista (non cambia il documento).
  vista,
}

/// Ingrandimento massimo della vista con il pizzico.
const double _zoomMassimo = 6;

/// Distanza in dp tra il lato alto di una forma e il suo pallino di rotazione.
const double _distanzaPallino = 32;

/// Cosa si è afferrato di una forma selezionata: una maniglia di lato o d'angolo, un estremo di linea o il pallino.
class _PresaForma {
  const _PresaForma.lato(Maniglia this.lato) : estremo = null;
  const _PresaForma.estremo(EstremoLinea this.estremo) : lato = null;
  const _PresaForma.pallino() : lato = null, estremo = null;

  final Maniglia? lato;
  final EstremoLinea? estremo;
  bool get pallino => lato == null && estremo == null;
}

/// Due tocchi sullo stesso testo entro questo tempo e questa distanza (dp) aprono la tastiera.
const Duration _doppioTocco = Duration(milliseconds: 300);
const double _distanzaDoppioTocco = 40;

/// Raggio dell'area toccabile di una maniglia (area di 48 dp, piano §4.5: almeno 44).
const double _raggioTocco = MisureScrl.tocco / 2;

/// Fascia ai lati dello schermo che, trascinando un elemento, porta alla pagina vicina, e attesa prima del cambio.
const double _fasciaBordo = 36;
const Duration _attesaBordo = Duration(milliseconds: 450);

class TelaEditor extends ConsumerStatefulWidget {
  const TelaEditor({super.key});

  @override
  ConsumerState<TelaEditor> createState() => _TelaEditorState();
}

class _TelaEditorState extends ConsumerState<TelaEditor>
    with TickerProviderStateMixin {
  late final AnimationController _scorrimento;

  /// Riporta la vista a zoom 1 e al centro (pulsante «Centra la pagina»).
  late final AnimationController _animVista;
  late final SessioneEditor _sessione;
  late final RiproduzioneVideo _riproduzione;
  final ValueNotifier<Aggancio> _aggancio = ValueNotifier(Aggancio.nessuno);
  GeometriaTela? _geo;

  /// La pagina intera nello spazio libero, prima dello zoom della vista.
  GeometriaTela? _geoBase;

  /// Zoom della vista (1 = pagina intera) e spostamento del centro della pagina, in dp.
  double _zoom = 1;
  Offset _pan = Offset.zero;
  double _zoomRif = 1, _scalaVistaRif = 1;
  Offset _panRif = Offset.zero, _focaleVistaRif = Offset.zero;
  double _zoomDa = 1;
  Offset _panDa = Offset.zero;

  /// Il riferimento dello zoom si prende al primo aggiornamento: quando il riconoscitore parte, le dita si sono
  /// già mosse (e la scala non vale più 1), e ancorarsi all'inizio farebbe saltare la vista.
  bool _vistaDaAncorare = false;

  /// Il gesto è ripartito con dita già appoggiate: Flutter chiude il gesto e ne apre un altro quando un dito si
  /// alza o si aggiunge, e allora il punto giusto è quello delle dita di adesso, non quello del primo tocco.
  bool _dopoRilascio = false;
  Timer? _timerPrepara;
  Timer? _timerBordo;

  // Stato del gesto in corso
  _Modo _modo = _Modo.nessuno;
  int _punti = 1;
  Snapshot? _base;
  Offset _focaleUltima = Offset.zero;
  (double, double) _stripInizio = (0, 0);
  CanvasElement? _primario;
  Maniglia? _maniglia;
  PhotoItem? _fotoBase;

  /// Forma con la sua maniglia (o estremo, o pallino) afferrata, com'era al tocco.
  ShapeItem? _formaBase;
  _PresaForma? _presa;

  /// L'elemento (foto, testo o forma) che il pizzico ridimensiona e ruota, com'era all'inizio.
  CanvasElement? _elBase;
  double _scalaRif = 1, _rotRif = 0;
  Offset _focaleRif = Offset.zero;
  bool _agganciataRotazione = false;

  /// Inquadra: la foto com'è durante il gesto e i valori di pizzico e rotazione dell'aggiornamento precedente.
  PhotoItem? _inqFoto;
  double _scalaUlt = 1, _rotUlt = 0;
  int _paginaInizio = 0;
  bool _bordoArmato = true;

  /// Dove il primo dito ha toccato: il riconoscitore parte solo dopo un piccolo spostamento, ma per sapere
  /// cosa si è toccato (e per non perdere quei pixel) conta il punto del contatto.
  Offset _posGiu = Offset.zero;
  Duration _tsGiu = Duration.zero;
  int _dita = 0;

  /// Ultimo tocco su un elemento (quando, dove e quale), per riconoscere il doppio tocco su un testo.
  Duration? _tsUltimoTocco;
  Offset _posUltimoTocco = Offset.zero;
  RifElemento? _rifUltimoTocco;

  ControlloEditor get _ctrl => ref.read(editorProvider.notifier);
  StatoEditor get _stato => ref.read(editorProvider);

  @override
  void initState() {
    super.initState();
    _sessione = ref.read(sessioneProvider);
    _scorrimento = AnimationController.unbounded(
      vsync: this,
      value: _stato.pagina.toDouble(),
    )..addListener(_alloScorrimento);
    _animVista = AnimationController(vsync: this)..addListener(_alPassoVista);
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepara());
    _sessione.risorse.ripristinaQualita = _prepara;
    _riproduzione = RiproduzioneVideo(
      risorse: _sessione.risorse,
      cache: _sessione.cache,
      cartellaProgetto: _sessione.cartella.path,
      apriLettore: _sessione.apriLettoreVideo,
      onErrore: (uid) {
        if (mounted) _ctrl.fermaVideo(uid);
      },
    );
  }

  @override
  void dispose() {
    _riproduzione.chiudi();
    _sessione.risorse.ripristinaQualita = null;
    _timerPrepara?.cancel();
    _timerBordo?.cancel();
    _scorrimento.dispose();
    _animVista.dispose();
    _aggancio.dispose();
    super.dispose();
  }

  double get _pos => _scorrimento.value;

  // ---------- Risorse ----------
  void _preparaConRitardo() {
    if (_stato.strumento.eFoto || _stato.strumento.eVideo) {
      // Con uno strumento Foto aperto un cursore in movimento cambia il documento a ogni istante: non si aspetta
      // che il dito si fermi (come per il ritardo normale) ma si colora a ritmo costante, sull'ultimo valore.
      if (_timerPrepara?.isActive ?? false) return;
      _timerPrepara = Timer(const Duration(milliseconds: 16), _prepara);
      return;
    }
    _timerPrepara?.cancel();
    _timerPrepara = Timer(const Duration(milliseconds: 120), _prepara);
  }

  void _prepara() {
    if (!mounted) return;
    final g = _geo;
    final s = _stato.snapshot;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final k = _stato.pagina;
    for (var i = k - 1; i <= k + 1; i++) {
      if (i < 0 || i >= s.canvas.numFrames) continue;
      unawaited(
        _sessione.risorse.prepara(s, i, pixelPerUnita: (g?.scala ?? 0.3) * dpr),
      );
    }
  }

  // ---------- Scorrimento a scatti ----------
  void _alloScorrimento() {
    if (_modo == _Modo.sposta) _aggiornaSposta(_focaleUltima);
  }

  bool get _senzaAnimazioni => MediaQuery.disableAnimationsOf(context);

  void _animaA(int pagina) {
    final n = _stato.snapshot.canvas.numFrames;
    final p = pagina.clamp(0, n - 1);
    if (_senzaAnimazioni) {
      _scorrimento.value = p.toDouble();
    } else {
      unawaited(
        _scorrimento.animateTo(
          p.toDouble(),
          duration: MotoScrl.pannello,
          curve: MotoScrl.curva,
        ),
      );
    }
    if (p != _stato.pagina) {
      HapticFeedback.selectionClick();
      _ctrl.vaiAPagina(p);
    }
  }

  // ---------- Ricerca degli elementi ----------
  CanvasElement? _elementoSotto(Offset p) {
    final g = _geo;
    if (g == null) return null;
    final (sx, sy) = g.daSchermo(p);
    final ordine = elementiInOrdine(_stato.snapshot).reversed;
    for (final e in ordine) {
      if (e.pageLocked) continue; // Le pagine bloccate non si selezionano
      if (colpisceElemento(e, sx, sy, _sessione.ctx.textSize, g.scala)) {
        return e;
      }
    }
    return null;
  }

  /// La sola foto selezionata, se si può ridimensionare (non bloccata).
  PhotoItem? _fotoSingola() {
    final el = _stato.elementiSelezionati;
    if (el.length != 1) return null;
    final e = el.first;
    return e is PhotoItem && !e.locked ? e : null;
  }

  /// La sola foto selezionata, anche se ha «Blocca posizione» (l'inquadratura interna non la sposta).
  PhotoItem? _fotoInquadrabile() {
    final el = _stato.elementiSelezionati;
    return el.length == 1 && el.first is PhotoItem
        ? el.first as PhotoItem
        : null;
  }

  /// La sola forma selezionata, se si può ridimensionare (non bloccata).
  ShapeItem? _formaSingola() {
    final el = _stato.elementiSelezionati;
    if (el.length != 1) return null;
    final e = el.first;
    return e is ShapeItem && !e.locked ? e : null;
  }

  /// L'unico elemento selezionato (foto, testo o forma) se si può ridimensionare e ruotare con due dita.
  CanvasElement? _pizzicabile() {
    final el = _stato.elementiSelezionati;
    return el.length == 1 && !el.first.locked ? el.first : null;
  }

  /// La maniglia, l'estremo o il pallino di una forma selezionata sotto il dito: il più vicino, entro l'area
  /// toccabile (su una forma piccola vince quello più vicino al dito).
  _PresaForma? _presaFormaSotto(Offset punto) {
    final f = _formaSingola();
    final g = _geo;
    if (f == null || g == null) return null;
    Offset schermo((double, double) p) => g.aSchermo(p.$1, p.$2);
    final candidati = <(Offset, _PresaForma)>[
      if (f.isLine)
        for (final e in EstremoLinea.values)
          (schermo(estremoInScena(f, e)), _PresaForma.estremo(e))
      else ...[
        for (final m in Maniglia.values)
          (
            schermo(formaInScena(f, m.frazione.$1 * f.w, m.frazione.$2 * f.h)),
            _PresaForma.lato(m),
          ),
        (
          schermo(pallinoRotazione(f, _distanzaPallino / g.scala)),
          const _PresaForma.pallino(),
        ),
      ],
    ];
    _PresaForma? migliore;
    var dist = double.infinity;
    for (final (c, presa) in candidati) {
      final d = (c - punto).distance;
      if (d <= _raggioTocco && d < dist) {
        dist = d;
        migliore = presa;
      }
    }
    return migliore;
  }

  Offset _posManiglia(PhotoItem p, Maniglia m) {
    final (fx, fy) = m.frazione;
    final (sx, sy) = localeInScena(p, fx * p.w, fy * p.h);
    return _geo!.aSchermo(sx, sy);
  }

  Maniglia? _maniglieSotto(Offset punto) {
    final p = _fotoSingola();
    if (p == null || _geo == null) return null;
    Maniglia? migliore;
    var dist = double.infinity;
    for (final m in Maniglia.values) {
      final d = (_posManiglia(p, m) - punto).distance;
      // Su un elemento piccolo vince la maniglia più vicina al dito
      if (d <= _raggioTocco && d < dist) {
        dist = d;
        migliore = m;
      }
    }
    return migliore;
  }

  // ---------- Tocco ----------
  void _alTocco(TapUpDetails d) {
    // Contagocce acceso: il tocco preleva il colore di quel punto della pagina
    if (_stato.contagocce) {
      unawaited(_prelevaColore(d.localPosition));
      return;
    }
    // Con uno strumento aperto la selezione non cambia: si lavora sull'elemento scelto
    if (_stato.strumento.suElemento) return;
    final e = _elementoSotto(d.localPosition);
    // «Seleziona più»: ogni tocco su un elemento lo aggiunge alla selezione o lo toglie (con tutto il suo gruppo)
    if (_stato.selezionePiu) {
      if (e != null) {
        _ctrl.alternaInSelezione(e);
        HapticFeedback.selectionClick();
      }
      return;
    }
    final ts = _tsGiu;
    final prima = _tsUltimoTocco;
    final rif = e == null ? null : rifDi(e);
    // Doppio tocco su un testo: apre la tastiera per scriverci
    final doppio =
        e is TextItem &&
        prima != null &&
        rif == _rifUltimoTocco &&
        ts - prima <= _doppioTocco &&
        (d.localPosition - _posUltimoTocco).distance <= _distanzaDoppioTocco;
    _tsUltimoTocco = doppio ? null : ts;
    _posUltimoTocco = d.localPosition;
    _rifUltimoTocco = rif;
    if (e == null) {
      _ctrl.deseleziona();
    } else if (doppio && !e.locked) {
      _ctrl.seleziona([rif!]);
      _ctrl.apriStrumento(Strumento.testoModifica);
    } else {
      _ctrl.seleziona(conGruppo(_stato.snapshot, e));
      HapticFeedback.selectionClick();
    }
  }

  /// Pressione lunga: su un elemento il menu dell'elemento (lo seleziona, con tutto il suo gruppo), sul vuoto quello
  /// della pagina (incolla, aggiungi testo o forma qui, seleziona tutto, azioni della pagina).
  void _allaPressioneLunga(LongPressStartDetails d) {
    // Con uno strumento aperto, o il contagocce, la pressione lunga non apre menu
    if (_stato.strumento != Strumento.nessuno || _stato.contagocce) return;
    final g = _geo?.conPos(_pos);
    if (g == null) return;
    final e = _elementoSotto(d.localPosition);
    unawaited(HapticFeedback.mediumImpact());
    if (e != null) {
      if (!_stato.selezione.contains(rifDi(e))) {
        _ctrl.seleziona(conGruppo(_stato.snapshot, e));
      }
      unawaited(mostraMenuElemento(context));
      return;
    }
    final (sx, sy) = g.daSchermo(d.localPosition);
    final n = _stato.snapshot.canvas.numFrames;
    final pagina = (sx / _stato.snapshot.canvas.frameW).floor().clamp(0, n - 1);
    _ctrl.vaiAPagina(pagina);
    unawaited(mostraMenuVuoto(context, pagina: pagina, punto: (x: sx, y: sy)));
  }

  /// Contagocce: legge il colore del disegno nel punto toccato (se cade dentro una pagina).
  Future<void> _prelevaColore(Offset punto) async {
    final g = _geo?.conPos(_pos);
    if (g == null) return;
    final s = _stato.snapshot;
    final (sx, sy) = g.daSchermo(punto);
    final pagina = (sx / s.canvas.frameW).floor();
    if (pagina < 0 || pagina >= s.canvas.numFrames) return;
    final argb = await coloreNelPunto(
      s,
      pagina,
      _sessione.risorse,
      testiDisegno(context),
      sx - pagina * s.canvas.frameW,
      sy,
    );
    if (!mounted || argb == null) return;
    unawaited(HapticFeedback.selectionClick());
    _ctrl.coloreCampionato(argb);
  }

  // ---------- Gesto ----------
  void _inizioGesto(ScaleStartDetails d) {
    if (_geo == null) return;
    _scorrimento.stop();
    _punti = d.pointerCount;
    final punto = d.pointerCount == 1 && !_dopoRilascio
        ? _posGiu
        : d.localFocalPoint;
    _dopoRilascio = false;
    _focaleUltima = punto;
    _paginaInizio = _pos.round();
    _base = _stato.snapshot;
    _modo = _Modo.nessuno;
    _bordoArmato = true;
    // Col contagocce acceso un trascinamento serve solo a cambiare pagina: niente si sposta
    if (_stato.contagocce) {
      _scorriOVista(d.pointerCount, punto, 1);
      return;
    }
    final sel = _stato.selezione;
    if (sel.isNotEmpty) {
      final m = d.pointerCount == 1 ? _maniglieSotto(punto) : null;
      if (m != null) {
        _modo = _Modo.maniglia;
        _maniglia = m;
        _fotoBase = _fotoSingola();
        return;
      }
      final presa = d.pointerCount == 1 ? _presaFormaSotto(punto) : null;
      if (presa != null) {
        _modo = _Modo.manigliaForma;
        _presa = presa;
        _formaBase = _formaSingola();
        _agganciataRotazione = false;
        return;
      }
      final e = _elementoSotto(punto);
      if (_stato.strumento.suElemento) {
        // Strumento Foto aperto: in Inquadra le dita muovono la foto dentro il riquadro; altrimenti si scorre
        if (_stato.strumento == Strumento.inquadra &&
            e != null &&
            sel.contains(rifDi(e)) &&
            _fotoInquadrabile() != null) {
          _iniziaInquadra(d.pointerCount);
          return;
        }
        _scorriOVista(d.pointerCount, punto, 1);
        return;
      }
      if (e != null && sel.contains(rifDi(e)) && !e.locked) {
        _primario = e;
        _iniziaSposta(punto);
        if (d.pointerCount >= 2 && _pizzicabile() != null) {
          _iniziaPizzica(null);
        }
        return;
      }
    }
    _scorriOVista(d.pointerCount, punto, 1);
  }

  void _iniziaInquadra(int dita) {
    _modo = _Modo.inquadra;
    _base = _stato.snapshot;
    _inqFoto = _fotoInquadrabile();
    _scalaUlt = 1;
    _rotUlt = 0;
    _punti = dita;
  }

  void _iniziaSposta(Offset focale) {
    _modo = _Modo.sposta;
    _base = _stato.snapshot;
    _stripInizio = _geo!.daSchermo(focale);
  }

  void _iniziaPizzica(ScaleUpdateDetails? d) {
    _modo = _Modo.pizzica;
    _base = _stato.snapshot;
    _elBase = _pizzicabile();
    _scalaRif = d?.scale ?? 1;
    _rotRif = d?.rotation ?? 0;
    _focaleRif = d?.localFocalPoint ?? _focaleUltima;
    _agganciataRotazione = false;
    _aggancio.value = Aggancio.nessuno;
  }

  void _aggiornaGesto(ScaleUpdateDetails d) {
    if (_geo == null || _modo == _Modo.nessuno) return;
    if (_modo == _Modo.inquadra && d.pointerCount != _punti) {
      // Un dito in più o in meno: il punto focale salta, si riparte da qui senza muovere la foto
      _punti = d.pointerCount;
      _scalaUlt = d.scale;
      _rotUlt = d.rotation;
      _focaleUltima = d.localFocalPoint;
      return;
    }
    if (d.pointerCount != _punti) {
      _punti = d.pointerCount;
      // Un secondo dito su una foto selezionata: da spostamento a pizzico (e viceversa)
      if (_modo == _Modo.sposta && _punti >= 2 && _pizzicabile() != null) {
        _iniziaPizzica(d);
      } else if (_modo == _Modo.pizzica && _punti < 2) {
        _iniziaSposta(d.localFocalPoint);
      } else if (_modo == _Modo.scorri && _punti >= 2) {
        // Un secondo dito mentre si scorre: diventa zoom, e la pagina torna al suo posto
        _scorrimento.value = _paginaInizio.toDouble();
        _iniziaVista(d.localFocalPoint, d.scale);
      } else if (_modo == _Modo.vista) {
        // Il punto focale salta: si riparte da qui senza far saltare la vista
        _iniziaVista(d.localFocalPoint, d.scale);
      }
    }
    final precedente = _focaleUltima;
    _focaleUltima = d.localFocalPoint;
    switch (_modo) {
      case _Modo.scorri:
        _aggiornaScorri(d.localFocalPoint.dx - precedente.dx);
      case _Modo.sposta:
        _aggiornaSposta(d.localFocalPoint);
        _controllaBordo(d.localFocalPoint);
      case _Modo.maniglia:
        _aggiornaManiglia(d.localFocalPoint);
      case _Modo.manigliaForma:
        _aggiornaManigliaForma(d.localFocalPoint);
      case _Modo.pizzica:
        _aggiornaPizzica(d);
      case _Modo.inquadra:
        _aggiornaInquadra(d, precedente);
      case _Modo.vista:
        _aggiornaVista(d);
      case _Modo.nessuno:
        break;
    }
  }

  void _aggiornaScorri(double spostamento) {
    final n = _stato.snapshot.canvas.numFrames;
    final g = _geo!;
    // Un po' di elasticità oltre la prima e l'ultima pagina
    _scorrimento.value = (_pos - spostamento / g.passo).clamp(
      -0.2,
      n - 1 + 0.2,
    );
  }

  void _aggiornaSposta(Offset focale) {
    final g = _geo?.conPos(_pos);
    final base = _base;
    if (g == null || base == null) return;
    final (sx, sy) = g.daSchermo(focale);
    var dx = sx - _stripInizio.$1;
    var dy = sy - _stripInizio.$2;
    final p = _primario;
    var agg = Aggancio.nessuno;
    if (p != null &&
        _stato.aggancioAttivo &&
        (p is PhotoItem || p is ShapeItem)) {
      final r = ingombroElemento(base, p, _sessione.ctx);
      agg = calcolaAggancio(
        base,
        motore.Rect(r.x + dx, r.y + dy, r.w, r.h),
        _stato.selezione,
        aggancioPixel / g.scala,
      );
      dx += agg.dx;
      dy += agg.dy;
    }
    final prima = _aggancio.value;
    _aggancio.value = agg;
    if (agg.attivo &&
        (agg.lineeX.join() != prima.lineeX.join() ||
            agg.lineeY.join() != prima.lineeY.join())) {
      HapticFeedback.selectionClick();
    }
    _ctrl.anteprima(spostaElementi(base, _stato.selezione, dx, dy));
  }

  void _aggiornaManiglia(Offset focale) {
    final g = _geo?.conPos(_pos);
    final base = _base, foto = _fotoBase, m = _maniglia;
    if (g == null || base == null || foto == null || m == null) return;
    final (sx, sy) = g.daSchermo(focale);
    // «Deforma» (strumento Inquadra): le maniglie sui lati stirano la foto invece di cambiare solo il riquadro
    final deforma = _stato.deforma && _stato.strumento == Strumento.inquadra;
    _ctrl.anteprima(
      _con(base, ridimensionaFoto(foto, m, sx, sy, deforma: deforma)),
    );
  }

  /// Inquadra: un dito sposta la foto dentro il riquadro, due la ingrandiscono e la ruotano
  /// (`pan_x`, `pan_y`, `inner_zoom`, `inner_rotation`). Ogni passo parte dal precedente.
  void _aggiornaInquadra(ScaleUpdateDetails d, Offset precedente) {
    final g = _geo?.conPos(_pos);
    final base = _base;
    var foto = _inqFoto;
    if (g == null || base == null || foto == null) return;
    if (d.pointerCount >= 2) {
      foto = pizzicoInterno(
        foto,
        scala: d.scale / _scalaUlt,
        gradi: (d.rotation - _rotUlt) * 180.0 / math.pi,
      );
    }
    _scalaUlt = d.scale;
    _rotUlt = d.rotation;
    final a = g.daSchermo(precedente), b = g.daSchermo(d.localFocalPoint);
    foto = panInterno(foto, _sessione.misuraDi(foto), b.$1 - a.$1, b.$2 - a.$2);
    _inqFoto = foto;
    _ctrl.anteprima(_con(base, foto));
  }

  /// Maniglia, estremo di linea o pallino di una forma: la forma segue il dito (bozza fino a fine gesto).
  void _aggiornaManigliaForma(Offset focale) {
    final g = _geo?.conPos(_pos);
    final base = _base, forma = _formaBase, presa = _presa;
    if (g == null || base == null || forma == null || presa == null) return;
    final (sx, sy) = g.daSchermo(focale);
    ShapeItem nuova;
    var agganciata = false;
    final estremo = presa.estremo;
    if (estremo != null) {
      final r = spostaEstremo(forma, estremo, sx, sy);
      nuova = r.forma;
      agganciata = r.agganciata;
    } else if (presa.pallino) {
      final r = ruotaConPallino(forma, sx, sy);
      nuova = r.forma;
      agganciata = r.agganciata;
    } else {
      nuova = ridimensionaForma(forma, presa.lato!, sx, sy);
    }
    if (agganciata && !_agganciataRotazione) HapticFeedback.selectionClick();
    _agganciataRotazione = agganciata;
    _ctrl.anteprima(_conForma(base, nuova));
  }

  void _aggiornaPizzica(ScaleUpdateDetails d) {
    final g = _geo?.conPos(_pos);
    final base = _base, el = _elBase;
    if (g == null || base == null || el == null) return;
    final scala = d.scale / _scalaRif;
    final gradi = (d.rotation - _rotRif) * 180.0 / math.pi;
    // Con le dita che si spostano, l'elemento le segue
    final a = g.daSchermo(_focaleRif), b = g.daSchermo(d.localFocalPoint);
    final dx = b.$1 - a.$1, dy = b.$2 - a.$2;
    bool agganciata;
    Snapshot nuovo;
    switch (el) {
      case PhotoItem():
        final r = trasformaFoto(el, scala: scala, gradi: gradi);
        agganciata = r.agganciata;
        nuovo = _con(base, r.foto.copyWith(x: r.foto.x + dx, y: r.foto.y + dy));
      case ShapeItem():
        final r = trasformaForma(el, scala: scala, gradi: gradi);
        agganciata = r.agganciata;
        nuovo = _conForma(
          base,
          r.forma.copyWith(x: r.forma.x + dx, y: r.forma.y + dy),
        );
      case TextItem():
        final r = trasformaTesto(el, _sessione.ctx, scala: scala, gradi: gradi);
        agganciata = r.agganciata;
        nuovo = _conTesto(
          base,
          r.testo.copyWith(x: r.testo.x + dx, y: r.testo.y + dy),
        );
    }
    if (agganciata && !_agganciataRotazione) HapticFeedback.selectionClick();
    _agganciataRotazione = agganciata;
    _ctrl.anteprima(nuovo);
  }

  /// [base] con la foto [nuova] al posto di quella con lo stesso `uid`.
  Snapshot _con(Snapshot base, PhotoItem nuova) => base.copyWith(
    items: [for (final p in base.items) p.uid == nuova.uid ? nuova : p],
  );

  Snapshot _conForma(Snapshot base, ShapeItem nuova) => base.copyWith(
    shapes: [for (final f in base.shapes) f.uid == nuova.uid ? nuova : f],
  );

  Snapshot _conTesto(Snapshot base, TextItem nuovo) => base.copyWith(
    texts: [for (final t in base.texts) t.uid == nuovo.uid ? nuovo : t],
  );

  // ---------- Zoom della vista ----------
  /// La vista è ingrandita o spostata: si mostra il pulsante per rimettere la pagina al centro.
  bool get _vistaCambiata => _zoom > 1.001 || _pan != Offset.zero;

  /// Due dita fuori da un elemento selezionato ingrandiscono la vista; con la vista ingrandita un dito la sposta
  /// (invece di cambiare pagina). Altrimenti un dito scorre tra le pagine.
  void _scorriOVista(int dita, Offset focale, double scala) {
    if (dita >= 2 || _zoom > 1.001) {
      _iniziaVista(focale, scala);
    } else {
      _modo = _Modo.scorri;
    }
  }

  void _iniziaVista(Offset focale, double scala) {
    _animVista.stop();
    _modo = _Modo.vista;
    _zoomRif = _zoom;
    _panRif = _pan;
    _focaleVistaRif = focale;
    _scalaVistaRif = scala;
    _vistaDaAncorare = true;
  }

  /// Il punto della pagina sotto le dita all'inizio resta sotto le dita: lo zoom va da 1 a [_zoomMassimo].
  void _aggiornaVista(ScaleUpdateDetails d) {
    final base = _geoBase;
    if (base == null) return;
    if (_vistaDaAncorare) {
      _vistaDaAncorare = false;
      _focaleVistaRif = d.localFocalPoint;
      _scalaVistaRif = d.scale;
      return;
    }
    final z = (_zoomRif * d.scale / _scalaVistaRif).clamp(1.0, _zoomMassimo);
    final centro = _centroPagina(base);
    final v = (_focaleVistaRif - centro - _panRif) / _zoomRif;
    final pan = d.localFocalPoint - centro - v * z;
    setState(() {
      _zoom = z;
      _pan = _limitaPan(base, z, pan);
    });
  }

  /// Dito alzato. Se era l'ultimo e lo zoom è rimasto appena sopra 1, la pagina torna intera.
  void _ditoAlzato() {
    _dita = math.max(0, _dita - 1);
    if (_dita == 0 &&
        _modo == _Modo.nessuno &&
        _vistaCambiata &&
        _zoom < 1.05) {
      _centraVista();
    }
  }

  void _fineVista() {
    // Quasi senza zoom: torna esattamente alla pagina intera
    if (_zoom < 1.05) {
      _centraVista();
    } else {
      _preparaConRitardo();
    }
  }

  Offset _centroPagina(GeometriaTela base) =>
      Offset(base.x0 + base.pw / 2, base.y0 + base.ph / 2);

  /// Fin dove si può spostare la pagina ingrandita: abbastanza da portarne ogni bordo in vista, non di più.
  Offset _limitaPan(GeometriaTela base, double z, Offset pan) {
    if (z <= 1.001) return Offset.zero;
    double limite(double lato, double spazio) =>
        math.max((lato * z - lato) / 2, (lato * z - spazio) / 2 + 48);
    final lx = limite(base.pw, base.larghezza);
    final ly = limite(base.ph, base.altezza - altezzaEtichetta);
    return Offset(pan.dx.clamp(-lx, lx), pan.dy.clamp(-ly, ly));
  }

  /// Toglie lo zoom e rimette la pagina al centro (animato, se le animazioni non sono ridotte).
  void _centraVista() {
    _animVista.stop();
    if (_senzaAnimazioni) {
      setState(() {
        _zoom = 1;
        _pan = Offset.zero;
      });
      _preparaConRitardo();
      return;
    }
    _zoomDa = _zoom;
    _panDa = _pan;
    _animVista
      ..duration = MotoScrl.pannello
      ..forward(from: 0).whenComplete(_preparaConRitardo);
  }

  void _alPassoVista() {
    final t = MotoScrl.curva.transform(_animVista.value);
    setState(() {
      _zoom = _zoomDa + (1 - _zoomDa) * t;
      _pan = Offset.lerp(_panDa, Offset.zero, t)!;
    });
  }

  // ---------- Cambio pagina trascinando un elemento ----------
  void _controllaBordo(Offset focale) {
    final g = _geo;
    if (g == null) return;
    final aSinistra = focale.dx < _fasciaBordo;
    final aDestra = focale.dx > g.larghezza - _fasciaBordo;
    if (!aSinistra && !aDestra) {
      _timerBordo?.cancel();
      _timerBordo = null;
      _bordoArmato = true;
      return;
    }
    if (_timerBordo != null || !_bordoArmato) return;
    _timerBordo = Timer(_attesaBordo, () {
      _timerBordo = null;
      if (_modo != _Modo.sposta) return;
      _bordoArmato = false;
      _animaA(_stato.pagina + (aSinistra ? -1 : 1));
    });
  }

  void _fineGesto(ScaleEndDetails d) {
    _timerBordo?.cancel();
    _timerBordo = null;
    // Un dito è ancora giù: il gesto riparte subito con le dita rimaste
    _dopoRilascio = _dita > 0;
    final modo = _modo;
    _modo = _Modo.nessuno;
    _aggancio.value = Aggancio.nessuno;
    final g = _geo;
    switch (modo) {
      case _Modo.scorri:
        if (g == null) return;
        final v = d.velocity.pixelsPerSecond.dx;
        // A scatti: al massimo una pagina per gesto, decisa da dove si è arrivati e dalla spinta
        var t = (_pos - v * 0.12 / g.passo).round();
        t = t.clamp(_paginaInizio - 1, _paginaInizio + 1);
        _animaA(t);
      case _Modo.sposta:
        _concludiSposta();
      case _Modo.maniglia || _Modo.manigliaForma || _Modo.pizzica:
        // Con uno strumento aperto la modifica resta bozza fino a ✓
        if (!_stato.strumento.suElemento) _ctrl.conferma();
      case _Modo.vista:
        // Con un dito ancora giù si continua a spostare: si ricentra solo quando tutte le dita sono alzate
        if (_dopoRilascio) {
          _preparaConRitardo();
        } else {
          _fineVista();
        }
      case _Modo.inquadra || _Modo.nessuno:
        break;
    }
    _base = null;
    _primario = null;
    _inqFoto = null;
    _formaBase = null;
    _presa = null;
    _elBase = null;
  }

  /// Fine dello spostamento: le foto rilasciate su un'altra pagina passano a quella pagina (`photosDropped`).
  void _concludiSposta() {
    final bozza = _stato.bozza;
    if (bozza == null) return;
    final uids = [
      for (final r in _stato.selezione)
        if (r.tipo == ElementKind.photo) r.uid,
    ];
    if (uids.isEmpty) {
      _ctrl.conferma();
      return;
    }
    final r = photosDropped(bozza, uids, _sessione.ctx);
    _ctrl.conferma(r.snapshot, r.notices);
    // La pagina può essere cambiata (foto rilasciata su un'altra pagina): la vista la segue
    _animaA(_pos.round());
  }

  void _annullaGesto() {
    _timerBordo?.cancel();
    _modo = _Modo.nessuno;
    _aggancio.value = Aggancio.nessuno;
    _ctrl.scarta();
  }

  /// Selezione fatta da un lettore di schermo (doppio tocco sul nodo dell'elemento): come il tocco con il dito.
  void _selezionaDaLettore(CanvasElement e) {
    if (_stato.strumento.suElemento || e.pageLocked) return;
    if (_stato.selezionePiu) {
      _ctrl.alternaInSelezione(e);
    } else {
      _ctrl.seleziona(conGruppo(_stato.snapshot, e));
    }
  }

  // ---------- Costruzione ----------
  @override
  Widget build(BuildContext context) {
    final stato = ref.watch(editorProvider);
    ref.listen(editorProvider.select((s) => s.pagina), (prima, pagina) {
      if (_modo == _Modo.scorri) return;
      if ((_pos - pagina).abs() > 0.01) _animaA(pagina);
      _preparaConRitardo();
    });
    ref.listen(editorProvider.select((s) => s.snapshot), (_, _) {
      _preparaConRitardo();
    });
    // Video in riproduzione: partono, si fermano e seguono il taglio (anche quello in bozza)
    ref.listen(
      editorProvider.select((s) => (s.snapshot, s.videoInRiproduzione)),
      (_, v) => _riproduzione.sincronizza(v.$1, v.$2),
    );
    final s = stato.snapshot;
    final testi = testiDisegno(context);
    return LayoutBuilder(
      builder: (context, vincoli) {
        final base = GeometriaTela.adatta(
          larghezza: vincoli.maxWidth,
          altezza: vincoli.maxHeight,
          frameW: s.canvas.frameW,
          frameH: s.canvas.frameH,
          pos: _pos,
        );
        _geoBase = base;
        // Lo spazio può essere cambiato (pannello aperto o chiuso): lo spostamento resta nei limiti
        _pan = _limitaPan(base, _zoom, _pan);
        final geo = base.conVista(_zoom, _pan);
        _geo = geo;
        final t = Testi.of(context);
        return Semantics(
          label: t.tela,
          value: t.telaPagina(stato.pagina + 1, s.canvas.numFrames),
          // Azioni per i lettori di schermo: scorrere fra le pagine senza il gesto di trascinamento
          onScrollLeft: stato.pagina < s.canvas.numFrames - 1
              ? () => _ctrl.vaiAPagina(stato.pagina + 1)
              : null,
          onScrollRight: stato.pagina > 0
              ? () => _ctrl.vaiAPagina(stato.pagina - 1)
              : null,
          explicitChildNodes: true,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (e) {
              if (_dita == 0) {
                _posGiu = e.localPosition;
                _tsGiu = e.timeStamp;
                _dopoRilascio = false;
              }
              _dita++;
            },
            onPointerUp: (_) => _ditoAlzato(),
            onPointerCancel: (_) => _ditoAlzato(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: _alTocco,
              onLongPressStart: _allaPressioneLunga,
              onScaleStart: _inizioGesto,
              onScaleUpdate: _aggiornaGesto,
              onScaleEnd: _fineGesto,
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: [
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _scorrimento,
                      _sessione.risorse,
                    ]),
                    builder: (context, _) => CustomPaint(
                      painter: _PitturaPagine(
                        s,
                        geo.conPos(_pos),
                        _sessione.risorse,
                        testi,
                        _sessione.risorse.versione,
                        stato.mostraGuide,
                      ),
                    ),
                  ),
                  _Etichetta(
                    geo: geo,
                    pos: _scorrimento,
                    snapshot: s,
                    sessione: _sessione,
                  ),
                  IgnorePointer(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_scorrimento, _aggancio]),
                      builder: (context, _) => CustomPaint(
                        painter: _PitturaSelezione(
                          snapshot: s,
                          selezione: stato.elementiSelezionati,
                          geo: geo.conPos(_pos),
                          misura: _sessione.ctx.textSize,
                          aggancio: _aggancio.value,
                          maniglie:
                              _fotoSingola() != null || _formaSingola() != null,
                        ),
                      ),
                    ),
                  ),
                  // Un nodo per elemento della pagina corrente, solo per i lettori di schermo
                  ...nodiElementi(
                    context: context,
                    snapshot: s,
                    geo: geo,
                    pagina: stato.pagina,
                    misura: _sessione.ctx.textSize,
                    selezione: stato.selezione,
                    alTocco: _selezionaDaLettore,
                    alMenu: (e) {
                      _selezionaDaLettore(e);
                      unawaited(mostraMenuElemento(context));
                    },
                  ),
                  // Con la vista ingrandita: un tocco rimette la pagina intera al centro
                  if (_vistaCambiata)
                    Positioned(
                      right: MisureScrl.spazioPiccolo,
                      bottom: MisureScrl.spazioPiccolo,
                      child: Material(
                        color: ColoriScrl.veloEtichetta,
                        shape: const CircleBorder(),
                        child: PulsanteIcona(
                          key: const ValueKey('tela-centra'),
                          icona: Icons.fit_screen_rounded,
                          etichetta: t.vistaCentra,
                          onTap: _centraVista,
                          colore: ColoriScrl.suAccento,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void deactivate() {
    if (_modo != _Modo.nessuno) _annullaGesto();
    super.deactivate();
  }
}

/// Disegna le pagine visibili con lo stesso modulo dell'esportazione, più le guide di centro.
class _PitturaPagine extends CustomPainter {
  _PitturaPagine(
    this.s,
    this.geo,
    this.risorse,
    this.testi,
    this.versione,
    this.mostraGuide,
  );

  final Snapshot s;
  final GeometriaTela geo;
  final RisorsePagina risorse;
  final TestiDisegno testi;

  /// Versione delle risorse: cambia quando arriva una foto colorata o si preme il confronto prima/dopo.
  final int versione;

  /// Linee di centro leggere (`show_guides`): si accendono e spengono da Stile.
  final bool mostraGuide;

  @override
  void paint(Canvas canvas, Size size) {
    final haElementi = s.allElements.isNotEmpty;
    for (final i in geo.pagineVisibili(s.canvas.numFrames)) {
      canvas.save();
      canvas.translate(geo.sinistraPagina(i), geo.y0);
      canvas.clipRect(Rect.fromLTWH(0, 0, geo.pw, geo.ph));
      disegnaPagina(
        canvas,
        s,
        i,
        risorse,
        OpzioniDisegno(testi: testi),
        scala: geo.scala,
      );
      if (haElementi && mostraGuide) _guide(canvas);
      canvas.restore();
    }
  }

  /// Linee di centro leggere, tratteggiate (`show_guides` del desktop).
  void _guide(Canvas canvas) {
    final p = Paint()
      ..color = ColoriScrl.guida.withAlpha(130)
      ..strokeWidth = 1;
    const tratto = 5.0, vuoto = 4.0;
    for (var y = 0.0; y < geo.ph; y += tratto + vuoto) {
      canvas.drawLine(
        Offset(geo.pw / 2, y),
        Offset(geo.pw / 2, math.min(y + tratto, geo.ph)),
        p,
      );
    }
    for (var x = 0.0; x < geo.pw; x += tratto + vuoto) {
      canvas.drawLine(
        Offset(x, geo.ph / 2),
        Offset(math.min(x + tratto, geo.pw), geo.ph / 2),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_PitturaPagine old) =>
      old.s != s ||
      old.geo.pos != geo.pos ||
      old.geo.scala != geo.scala ||
      old.mostraGuide != mostraGuide ||
      old.versione != versione;
}

/// Riquadro di selezione, maniglie, lucchetto e linee di aggancio: sopra la pagina, non ritagliati.
class _PitturaSelezione extends CustomPainter {
  _PitturaSelezione({
    required this.snapshot,
    required this.selezione,
    required this.geo,
    required this.misura,
    required this.aggancio,
    required this.maniglie,
  });

  final Snapshot snapshot;
  final List<CanvasElement> selezione;
  final GeometriaTela geo;
  final TextSizeOf misura;
  final Aggancio aggancio;
  final bool maniglie;

  @override
  void paint(Canvas canvas, Size size) {
    final linea = Paint()
      ..color = ColoriScrl.accento
      ..style = PaintingStyle.stroke
      ..strokeWidth = selezione.length > 1 ? 1.5 : 2;
    for (final e in selezione) {
      final a = [
        for (final (x, y) in angoliElemento(e, misura)) geo.aSchermo(x, y),
      ];
      canvas.drawPath(Path()..addPolygon(a, true), linea);
      if (e.locked) _lucchetto(canvas, a.first);
    }
    if (maniglie && selezione.length == 1) {
      final e = selezione.first;
      if (e is PhotoItem) _disegnaManiglie(canvas, e);
      if (e is ShapeItem) _disegnaManigliaForma(canvas, e);
    }
    _linee(canvas);
  }

  void _disegnaManiglie(Canvas canvas, PhotoItem p) {
    final riempi = Paint()..color = ColoriScrl.suAccento;
    final bordo = Paint()
      ..color = ColoriScrl.accento
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final m in Maniglia.values) {
      final (fx, fy) = m.frazione;
      final (sx, sy) = localeInScena(p, fx * p.w, fy * p.h);
      final c = geo.aSchermo(sx, sy);
      final r = m.angolo ? 8.0 : 6.0;
      canvas.drawCircle(c, r, riempi);
      canvas.drawCircle(c, r, bordo);
    }
  }

  /// Forma piena: otto maniglie e il pallino di rotazione sopra il lato alto, unito da un filo. Linea o freccia: i due
  /// estremi, che la allungano e la orientano.
  void _disegnaManigliaForma(Canvas canvas, ShapeItem f) {
    final riempi = Paint()..color = ColoriScrl.suAccento;
    final bordo = Paint()
      ..color = ColoriScrl.accento
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    Offset schermo((double, double) p) => geo.aSchermo(p.$1, p.$2);
    void tondo(Offset c, double r) {
      canvas.drawCircle(c, r, riempi);
      canvas.drawCircle(c, r, bordo);
    }

    if (f.isLine) {
      for (final e in EstremoLinea.values) {
        tondo(schermo(estremoInScena(f, e)), 9);
      }
      return;
    }
    final alto = schermo(formaInScena(f, f.w / 2, 0));
    final pallino = schermo(pallinoRotazione(f, _distanzaPallino / geo.scala));
    canvas.drawLine(alto, pallino, bordo);
    for (final m in Maniglia.values) {
      final (fx, fy) = m.frazione;
      tondo(schermo(formaInScena(f, fx * f.w, fy * f.h)), m.angolo ? 8 : 6);
    }
    tondo(pallino, 9);
    // Freccia curva dentro il pallino: dice che serve a ruotare
    canvas.drawArc(
      Rect.fromCircle(center: pallino, radius: 4),
      -math.pi * 0.2,
      math.pi * 1.5,
      false,
      bordo,
    );
  }

  /// Lucchetto piccolo, in alto a sinistra di un elemento con «Blocca posizione».
  void _lucchetto(Canvas canvas, Offset angolo) {
    final c = angolo + const Offset(10, 10);
    final fondo = Paint()..color = ColoriScrl.accento;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c + const Offset(0, 2), width: 11, height: 8),
        const Radius.circular(2),
      ),
      fondo,
    );
    canvas.drawArc(
      Rect.fromCenter(center: c + const Offset(0, -2), width: 7, height: 8),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = ColoriScrl.accento
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  void _linee(Canvas canvas) {
    if (!aggancio.attivo) return;
    final p = Paint()
      ..color = ColoriScrl.aggancio
      ..strokeWidth = 1.2;
    for (final x in aggancio.lineeX) {
      canvas.drawLine(
        geo.aSchermo(x, 0),
        geo.aSchermo(x, geo.frameH.toDouble()),
        p,
      );
    }
    for (final y in aggancio.lineeY) {
      final a = geo.aSchermo(geo.pos.round() * geo.frameW.toDouble(), y);
      canvas.drawLine(Offset(0, a.dy), Offset(geo.larghezza, a.dy), p);
    }
  }

  @override
  bool shouldRepaint(_PitturaSelezione old) => true;
}

/// Etichetta sopra la pagina («Pagina 2 · Bloccata · A cavallo 2–4 · 3 foto») e invito se la pagina è vuota.
class _Etichetta extends StatelessWidget {
  const _Etichetta({
    required this.geo,
    required this.pos,
    required this.snapshot,
    required this.sessione,
  });

  final GeometriaTela geo;
  final Animation<double> pos;
  final Snapshot snapshot;
  final SessioneEditor sessione;

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final stili = Theme.of(context).textTheme;
    return AnimatedBuilder(
      animation: pos,
      builder: (context, _) {
        final c = snapshot.canvas;
        final k = pos.value.round().clamp(0, c.numFrames - 1);
        final parti = <String>[t.etichettaPagina(k + 1)];
        if (c.pageLocked(k)) parti.add(t.etichettaBloccata);
        final g = c.seamGroups().firstWhere((g) => g.$1 <= k && k <= g.$2);
        if (g.$2 > g.$1) parti.add(t.etichettaACavallo(g.$1 + 1, g.$2 + 1));
        final foto = RisorsePagina.fotoDellaPagina(snapshot, k).length;
        parti.add(t.etichettaFoto(foto));
        final vuota = _paginaVuota(snapshot, k);
        return Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: altezzaEtichetta,
              child: Center(
                child: Text(
                  parti.join(' · '),
                  style: stili.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (vuota)
              Positioned(
                left: geo.x0,
                top: geo.y0,
                width: geo.pw,
                height: geo.ph,
                // Su una pagina piccola (pannello alto, schermo basso, testo grande) il segno si rimpicciolisce
                child: IgnorePointer(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: MisureScrl.tocco,
                          color: ColoriScrl.testoSpento,
                        ),
                        const SizedBox(height: MisureScrl.spazioPiccolo),
                        Text(
                          t.paginaVuota,
                          style: stili.bodySmall?.copyWith(
                            color: ColoriScrl.testoSpento,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  bool _paginaVuota(Snapshot s, int k) {
    final fw = s.canvas.frameW.toDouble();
    bool tocca(CanvasElement e) {
      final a = angoliElemento(e, sessione.ctx.textSize);
      final xs = a.map((p) => p.$1);
      return xs.reduce(math.max) > k * fw && xs.reduce(math.min) < (k + 1) * fw;
    }

    return !s.allElements.any(tocca);
  }
}
