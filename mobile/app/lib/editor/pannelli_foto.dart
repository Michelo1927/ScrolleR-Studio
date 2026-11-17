/// Pannelli degli strumenti Foto (piano §4.3, §4.4 e §6 «Foto»): Inquadra, Filtri, Regola, Effetti, Cornice, Ombra,
/// Ruota. Tutti hanno la stessa anatomia: parametri a pillola che scorrono in orizzontale, **un solo cursore**,
/// `✕` scarta, `◐` (tenuto premuto) confronta con l'originale, `✓` conferma.
///
/// Ogni cambio si vede subito sulla pagina come **bozza**; la bozza diventa un solo passo di cronologia con `✓`.
/// I numeri e le operazioni stanno in `scrl_engine` (`strumenti_foto.dart`): qui c'è solo l'interfaccia.
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import '../l10n/app_localizations.dart';
import '../media/cache_media.dart';
import '../render/regolazioni.dart';
import '../theme/tokens.dart';
import 'sessione.dart';
import 'stato.dart';
import 'widget_comuni.dart';

/// La foto principale tra quelle selezionate (i cursori ne mostrano i valori; i cambi valgono per tutte).
final _fotoPrincipale = Provider.autoDispose<PhotoItem?>((ref) {
  final sel = ref.watch(editorProvider.select((s) => s.elementiSelezionati));
  for (final e in sel) {
    if (e is PhotoItem) return e;
  }
  return null;
}, dependencies: [editorProvider]);

// ---------------------------------------------------------------- Pezzi comuni

/// Telaio di ogni strumento: pillole dei parametri, contenuto (cursore o tessere), piede con ✕ · nome · ◐ · ✓.
class _Intelaiatura extends ConsumerWidget {
  const _Intelaiatura({
    required this.nome,
    required this.chips,
    required this.contenuto,
    this.confronto = false,
  });

  final String nome;
  final List<Widget> chips;
  final Widget contenuto;

  /// Mostra il pulsante `◐` prima/dopo.
  final bool confronto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final ctrl = ref.read(editorProvider.notifier);
    return PannelloBasso(
      onScarta: ctrl.chiudiStrumentoDaGesto,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: MisureScrl.spazioPiccolo),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
              children: [
                for (final c in chips)
                  Padding(
                    padding: const EdgeInsets.only(right: MisureScrl.spazioPiccolo),
                    child: Center(child: c),
                  ),
              ],
            ),
          ),
          const SizedBox(height: MisureScrl.spazioPiccolo),
          SizedBox(height: 96, child: contenuto),
          PiedeStrumento(
            nome: nome,
            etichettaAnnulla: t.annulla,
            etichettaConferma: t.conferma,
            onAnnulla: ctrl.chiudiStrumento,
            onConferma: ctrl.confermaEChiudi,
            confronto: confronto ? const PulsanteConfronto() : null,
          ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}

/// `◐`: finché è premuto tutte le foto si vedono senza filtri e regolazioni (`scene.show_original`).
class PulsanteConfronto extends ConsumerStatefulWidget {
  const PulsanteConfronto({super.key});

  @override
  ConsumerState<PulsanteConfronto> createState() => _PulsanteConfrontoState();
}

class _PulsanteConfrontoState extends ConsumerState<PulsanteConfronto> {
  late final SessioneEditor _s;
  bool _premuto = false;

  @override
  void initState() {
    super.initState();
    _s = ref.read(sessioneProvider);
  }

  void _imposta(bool v) {
    if (_premuto == v || !mounted) return;
    setState(() => _premuto = v);
    _s.risorse.mostraOriginale = v;
  }

  @override
  void dispose() {
    final risorse = _s.risorse;
    // Fuori dal momento in cui l'albero si smonta: la pagina torna a mostrare i colori
    scheduleMicrotask(() => risorse.mostraOriginale = false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    return Semantics(
      button: true,
      label: t.confronta,
      excludeSemantics: true,
      child: Listener(
        onPointerDown: (_) => _imposta(true),
        onPointerUp: (_) => _imposta(false),
        onPointerCancel: (_) => _imposta(false),
        child: SizedBox(
          width: MisureScrl.tocco,
          height: MisureScrl.tocco,
          child: Icon(
            Icons.contrast,
            size: 24,
            color: _premuto ? ColoriScrl.accento : ColoriScrl.testo,
          ),
        ),
      ),
    );
  }
}

/// Un cursore per un valore intero della foto principale; il cambio vale per tutte le foto selezionate.
class _Cursore extends ConsumerWidget {
  const _Cursore({
    super.key,
    required this.nome,
    required this.minimo,
    required this.massimo,
    required this.iniziale,
    required this.leggi,
    required this.scrivi,
    this.unita = '',
  });

  final String nome;
  final int minimo, massimo, iniziale;
  final int Function(PhotoItem) leggi;
  final PhotoItem Function(PhotoItem, int) scrivi;
  final String unita;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foto = ref.watch(_fotoPrincipale);
    if (foto == null) return const SizedBox.shrink();
    final ctrl = ref.read(editorProvider.notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
      child: Center(
        child: CursoreGrande(
          etichetta: nome,
          valore: leggi(foto).toDouble(),
          minimo: minimo.toDouble(),
          massimo: massimo.toDouble(),
          iniziale: iniziale.toDouble(),
          daCentro: minimo < 0,
          unita: unita,
          onCambia: (v) {
            // Mentre il dito si muove la pagina si colora su copie ridotte delle foto
            ref.read(sessioneProvider).risorse.qualitaRidotta = true;
            ctrl.modificaFotoSelezionate((p) => scrivi(p, v));
          },
          onFine: () => ref.read(sessioneProvider).risorse.qualitaRidotta = false,
        ),
      ),
    );
  }
}

/// Descrizione di un parametro con cursore.
class _Par {
  const _Par(
    this.nome,
    this.minimo,
    this.massimo,
    this.iniziale,
    this.leggi,
    this.scrivi, {
    this.unita = '',
  });
  final String nome;
  final int minimo, massimo, iniziale;
  final int Function(PhotoItem) leggi;
  final PhotoItem Function(PhotoItem, int) scrivi;
  final String unita;
}

/// Parametro di una regolazione colore (`adjust[chiave]`).
_Par _regolazione(String nome, String chiave, {int minimo = -100}) => _Par(
  nome,
  minimo,
  100,
  0,
  (p) => valoreRegolazione(p, chiave),
  (p, v) => conRegolazione(p, chiave, v),
);

/// Pillole dei parametri + cursore del parametro attivo; le azioni extra seguono le pillole.
class _ConParametri extends ConsumerStatefulWidget {
  const _ConParametri({
    required this.nome,
    required this.parametri,
    this.azioni = const [],
    this.confronto = false,
  });

  final String nome;
  final List<_Par> parametri;
  final List<Widget> azioni;
  final bool confronto;

  @override
  ConsumerState<_ConParametri> createState() => _ConParametriState();
}

class _ConParametriState extends ConsumerState<_ConParametri> {
  int _attivo = 0;

  @override
  Widget build(BuildContext context) {
    final foto = ref.watch(_fotoPrincipale);
    final par = widget.parametri[_attivo];
    return _Intelaiatura(
      nome: widget.nome,
      confronto: widget.confronto,
      chips: [
        for (var i = 0; i < widget.parametri.length; i++)
          ChipParametro(
            etichetta: widget.parametri[i].nome,
            valore: foto == null ? null : '${widget.parametri[i].leggi(foto)}',
            attivo: i == _attivo,
            onTap: () => setState(() => _attivo = i),
          ),
        ...widget.azioni,
      ],
      contenuto: _Cursore(
        key: ValueKey('${widget.nome}/${par.nome}'),
        nome: par.nome,
        minimo: par.minimo,
        massimo: par.massimo,
        iniziale: par.iniziale,
        leggi: par.leggi,
        scrivi: par.scrivi,
        unita: par.unita,
      ),
    );
  }
}

/// Pillola che attiva o spegne qualcosa della foto principale.
class _Interruttore extends ConsumerWidget {
  const _Interruttore({
    required this.nome,
    required this.acceso,
    required this.onTap,
  });

  final String nome;
  final bool Function(PhotoItem) acceso;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foto = ref.watch(_fotoPrincipale);
    return ChipParametro(
      etichetta: nome,
      attivo: foto != null && acceso(foto),
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------- Regola

/// Regola: miglioramento automatico, luminosità, contrasto, ombre, luci, saturazione, calore, tinta, bianco e nero.
class PannelloRegola extends ConsumerWidget {
  const PannelloRegola({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final ctrl = ref.read(editorProvider.notifier);
    return _ConParametri(
      nome: t.strRegola,
      confronto: true,
      parametri: [
        _regolazione(t.parLuminosita, 'brightness'),
        _regolazione(t.parContrasto, 'contrast'),
        _regolazione(t.parOmbre, 'shadows'),
        _regolazione(t.parLuci, 'highlights'),
        _regolazione(t.parSaturazione, 'saturation'),
        _regolazione(t.parCalore, 'warmth'),
        _regolazione(t.parTinta, 'tint'),
      ],
      azioni: [
        _Interruttore(
          nome: t.auto,
          acceso: (p) => adjOn(p.adjust, 'auto'),
          onTap: () => ctrl.modificaFotoSelezionate(
            (p) => conInterruttore(p, 'auto', !adjOn(p.adjust, 'auto')),
          ),
        ),
        _Interruttore(
          nome: t.azBiancoNero,
          acceso: (p) => adjOn(p.adjust, 'bw'),
          onTap: () => ctrl.modificaFotoSelezionate(
            (p) => conInterruttore(p, 'bw', !adjOn(p.adjust, 'bw')),
          ),
        ),
        ChipParametro(
          etichetta: t.azReimpostaColori,
          attivo: false,
          onTap: () => ctrl.modificaFotoSelezionate(coloriReimpostati),
        ),
        ChipParametro(
          etichetta: t.azApplicaATutte,
          attivo: false,
          onTap: ctrl.coloriATutteLeFoto,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Effetti

/// Effetti: nitidezza, vignettatura, sbiadito, grana.
class PannelloEffetti extends ConsumerWidget {
  const PannelloEffetti({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final ctrl = ref.read(editorProvider.notifier);
    return _ConParametri(
      nome: t.strEffetti,
      confronto: true,
      parametri: [
        _regolazione(t.parNitidezza, 'sharpness', minimo: 0),
        _regolazione(t.parVignettatura, 'vignette'),
        _regolazione(t.parSbiadito, 'fade', minimo: 0),
        _regolazione(t.parGrana, 'grain', minimo: 0),
      ],
      azioni: [
        ChipParametro(
          etichetta: t.azApplicaATutte,
          attivo: false,
          onTap: ctrl.coloriATutteLeFoto,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Filtri

String _nomeFiltro(Testi t, String chiave) => switch (chiave) {
  'vivid' => t.filtroVivace,
  'summer' => t.filtroEstate,
  'film' => t.filtroPellicola,
  'vintage' => t.filtroVintage,
  'bw_contrast' => t.filtroBnContrastato,
  'cold' => t.filtroFreddo,
  'soft' => t.filtroMorbido,
  'dramatic' => t.filtroDrammatico,
  _ => t.filtroOriginale,
};

/// Filtri: i 9 filtri pronti come tessere con la foto selezionata già filtrata. Poi si possono ritoccare con Regola.
class PannelloFiltri extends ConsumerStatefulWidget {
  const PannelloFiltri({super.key});

  @override
  ConsumerState<PannelloFiltri> createState() => _PannelloFiltriState();
}

class _PannelloFiltriState extends ConsumerState<PannelloFiltri> {
  /// Miniatura di ogni filtro (null finché non è pronta o se la foto non si legge).
  List<ui.Image>? _miniature;
  ui.Image? _base;
  bool _chiuso = false;

  @override
  void initState() {
    super.initState();
    unawaited(_prepara());
  }

  @override
  void dispose() {
    _chiuso = true;
    _libera();
    super.dispose();
  }

  void _libera() {
    for (final i in _miniature ?? const <ui.Image>[]) {
      if (!identical(i, _base)) i.dispose();
    }
    _miniature = null;
  }

  /// Miniature fatte una sola volta con lo stesso programma che colora la foto sulla pagina.
  Future<void> _prepara() async {
    final s = ref.read(sessioneProvider);
    final foto = ref.read(editorProvider.notifier).fotoSelezionate;
    if (foto.isEmpty) return;
    final img = await s.cache.carica(
      sorgenteDi(foto.first, s.cartella.path),
      Dettaglio.miniatura,
    );
    if (img == null || _chiuso) return;
    final r = await Regolazioni.carica();
    final base = await ridimensiona(img.immagine, 108);
    final fatte = <ui.Image>[];
    for (final p in presets) {
      fatte.add(
        await r.applica(base, presetAdjust(p.key), detailScale: 0.4),
      );
    }
    if (_chiuso) {
      for (final i in fatte) {
        if (!identical(i, base)) i.dispose();
      }
      return;
    }
    setState(() {
      _base = base;
      _miniature = fatte;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final ctrl = ref.read(editorProvider.notifier);
    final foto = ref.watch(_fotoPrincipale);
    final attivo = foto == null ? null : filtroAttivo(foto.adjust);
    return _Intelaiatura(
      nome: t.strFiltri,
      confronto: true,
      chips: [
        ChipParametro(
          etichetta: t.azApplicaATutte,
          attivo: false,
          onTap: ctrl.coloriATutteLeFoto,
        ),
      ],
      contenuto: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
        children: [
          for (var i = 0; i < presets.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TesseraScelta(
                disegno: _MiniaturaFiltro(
                  immagine: _miniature?[i],
                  vignettatura: adjValue(presets[i].values, 'vignette'),
                ),
                etichetta: _nomeFiltro(t, presets[i].key),
                scelta: attivo == presets[i].key,
                larghezza: 84,
                altezza: 96,
                onTap: () {
                  final k = presets[i].key;
                  ctrl.modificaFotoSelezionate((p) => conFiltro(p, k));
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Foto già filtrata (quadrata, angoli arrotondati) con la vignettatura del filtro disegnata sopra.
class _MiniaturaFiltro extends StatelessWidget {
  const _MiniaturaFiltro({required this.immagine, required this.vignettatura});

  final ui.Image? immagine;
  final double vignettatura;

  @override
  Widget build(BuildContext context) {
    final forza = (vignettatura.abs() / 100.0).clamp(0.0, 1.0);
    final base = vignettatura < 0 ? Colors.black : Colors.white;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 60,
        height: 60,
        child: immagine == null
            ? const ColoredBox(color: ColoriScrl.rilievo)
            : Stack(
                fit: StackFit.expand,
                children: [
                  RawImage(image: immagine, fit: BoxFit.cover),
                  if (vignettatura != 0)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          radius: 0.7071,
                          colors: [
                            base.withValues(alpha: 0),
                            base.withValues(alpha: 0),
                            base.withValues(alpha: forza * 0.38),
                            base.withValues(alpha: forza * 0.9),
                          ],
                          stops: const [0.0, 0.42, 0.72, 1.0],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Inquadra

/// Inquadra: zoom, spostamento e rotazione del contenuto dentro il riquadro, con i cursori e, sulla pagina,
/// con le dita (un dito sposta, due ingrandiscono e ruotano). Più «Riempi / Foto intera», «Deforma» e proporzioni.
class PannelloInquadra extends ConsumerWidget {
  const PannelloInquadra({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final ctrl = ref.read(editorProvider.notifier);
    final s = ref.read(sessioneProvider);
    final deforma = ref.watch(editorProvider.select((x) => x.deforma));
    final foto = ref.watch(_fotoPrincipale);
    final riquadroDiPrima = puoRipristinareRiquadro(ctrl.fotoSelezionate);
    return _ConParametri(
      nome: t.strInquadra,
      parametri: [
        _Par(
          t.parZoom,
          LimitiFoto.zoomMin,
          LimitiFoto.zoomMax,
          100,
          (p) => (p.innerZoom * 100).round(),
          (p, v) => conZoomInterno(p, v / 100.0),
          unita: '%',
        ),
        _Par(
          t.parOrizzontale,
          LimitiFoto.panMin,
          LimitiFoto.panMax,
          0,
          (p) => (p.panX * 100).round(),
          (p, v) => conPan(p, x: v / 100.0),
        ),
        _Par(
          t.parVerticale,
          LimitiFoto.panMin,
          LimitiFoto.panMax,
          0,
          (p) => (p.panY * 100).round(),
          (p, v) => conPan(p, y: v / 100.0),
        ),
        _Par(
          t.parRuotaContenuto,
          LimitiFoto.rotazioneMin,
          LimitiFoto.rotazioneMax,
          0,
          (p) => p.innerRotation.round(),
          (p, v) => conRotazioneInterna(p, v.toDouble()),
          unita: '°',
        ),
      ],
      azioni: [
        ChipParametro(
          etichetta: t.azRiempi,
          attivo: foto != null && foto.fitMode != 'contain',
          onTap: () => ctrl.modificaFotoSelezionate((p) => conFit(p, 'cover')),
        ),
        ChipParametro(
          etichetta: t.azFotoIntera,
          attivo: foto != null && foto.fitMode == 'contain',
          onTap: () => ctrl.modificaFotoSelezionate((p) => conFit(p, 'contain')),
        ),
        ChipParametro(
          etichetta: t.azDeforma,
          attivo: deforma,
          onTap: () => ctrl.impostaDeforma(!deforma),
        ),
        ChipParametro(
          etichetta: t.azReimposta,
          attivo: false,
          onTap: () => ctrl.modificaFotoSelezionate(inquadraturaReimpostata),
        ),
        ChipParametro(
          etichetta: riquadroDiPrima
              ? t.azRiquadroDiPrima
              : t.azProporzioniFoto,
          attivo: false,
          onTap: () => ctrl.modificaFotoSelezionate(
            (p) => alternaProporzioni(p, s.misuraDi(p)),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Cornice

/// Cornice: angoli arrotondati, spessore e colore del bordo.
class PannelloCornice extends ConsumerStatefulWidget {
  const PannelloCornice({super.key});

  @override
  ConsumerState<PannelloCornice> createState() => _PannelloCorniceState();
}

class _PannelloCorniceState extends ConsumerState<PannelloCornice> {
  int _attivo = 0; // 0 angoli, 1 bordo, 2 colore

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final ctrl = ref.read(editorProvider.notifier);
    final foto = ref.watch(_fotoPrincipale);
    final Widget contenuto = switch (_attivo) {
      0 => _Cursore(
        key: const ValueKey('angoli'),
        nome: t.parAngoli,
        minimo: 0,
        massimo: LimitiFoto.angoliMax,
        iniziale: 0,
        leggi: (p) => p.borderRadius.round(),
        scrivi: conAngoli,
        unita: ' px',
      ),
      1 => _Cursore(
        key: const ValueKey('bordo'),
        nome: t.parBordo,
        minimo: 0,
        massimo: LimitiFoto.bordoMax,
        iniziale: 0,
        leggi: (p) => p.borderWidth.round(),
        scrivi: conBordo,
        unita: ' px',
      ),
      _ => ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
        children: [
          for (final c in CampioniScrl.rapidi)
            _Campione(
              colore: c,
              scelto: foto != null && foto.borderColor == c.toARGB32(),
              onTap: () => ctrl.modificaFotoSelezionate(
                (p) => conColoreBordo(p, c.toARGB32()),
              ),
              etichetta: t.parColore,
            ),
        ],
      ),
    };
    return _Intelaiatura(
      nome: t.strCornice,
      chips: [
        ChipParametro(
          etichetta: t.parAngoli,
          valore: foto == null ? null : '${foto.borderRadius.round()}',
          attivo: _attivo == 0,
          onTap: () => setState(() => _attivo = 0),
        ),
        ChipParametro(
          etichetta: t.parBordo,
          valore: foto == null ? null : '${foto.borderWidth.round()}',
          attivo: _attivo == 1,
          onTap: () => setState(() => _attivo = 1),
        ),
        ChipParametro(
          etichetta: t.parColore,
          attivo: _attivo == 2,
          onTap: () => setState(() => _attivo = 2),
        ),
        ChipParametro(
          etichetta: t.azApplicaATutte,
          attivo: false,
          onTap: ctrl.stileATutteLeFoto,
        ),
      ],
      contenuto: contenuto,
    );
  }
}

/// Campione di colore tondo (48 dp toccabili), con un anello se è quello scelto.
class _Campione extends StatelessWidget {
  const _Campione({
    required this.colore,
    required this.scelto,
    required this.onTap,
    required this.etichetta,
  });

  final Color colore;
  final bool scelto;
  final VoidCallback onTap;
  final String etichetta;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: scelto,
    label: etichetta,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: MisureScrl.tocco,
        height: MisureScrl.tocco,
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colore,
              shape: BoxShape.circle,
              border: Border.all(
                color: scelto ? ColoriScrl.accento : ColoriScrl.bordo,
                width: scelto ? 3 : 1,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------- Ombra

/// Ombra: ombra morbida sotto la foto e opacità della foto.
class PannelloOmbra extends ConsumerWidget {
  const PannelloOmbra({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final ctrl = ref.read(editorProvider.notifier);
    return _ConParametri(
      nome: t.strOmbra,
      parametri: [
        _Par(
          t.strOmbra,
          0,
          LimitiFoto.ombraMax,
          0,
          (p) => p.shadow,
          conOmbra,
          unita: '%',
        ),
        _Par(
          t.parOpacita,
          LimitiFoto.opacitaMin,
          LimitiFoto.opacitaMax,
          100,
          (p) => p.opacity,
          conOpacita,
          unita: '%',
        ),
      ],
      azioni: [
        ChipParametro(
          etichetta: t.azApplicaATutte,
          attivo: false,
          onTap: ctrl.stileATutteLeFoto,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Ruota

/// Ruota: angolo del riquadro, 90° a sinistra e a destra, «Dritta», specchio orizzontale e verticale.
class PannelloRuota extends ConsumerWidget {
  const PannelloRuota({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final ctrl = ref.read(editorProvider.notifier);
    final foto = ref.watch(_fotoPrincipale);
    return _Intelaiatura(
      nome: t.strRuota,
      chips: [
        ChipParametro(
          etichetta: t.azSinistra90,
          attivo: false,
          onTap: () => ctrl.modificaFotoSelezionate((p) => ruotataDi(p, -90)),
        ),
        ChipParametro(
          etichetta: t.azDestra90,
          attivo: false,
          onTap: () => ctrl.modificaFotoSelezionate((p) => ruotataDi(p, 90)),
        ),
        ChipParametro(
          etichetta: t.azDritta,
          attivo: false,
          onTap: () => ctrl.modificaFotoSelezionate((p) => conRotazione(p, 0)),
        ),
        ChipParametro(
          etichetta: t.azSpecchiaOrizz,
          attivo: foto?.flipH ?? false,
          onTap: () => ctrl.modificaFotoSelezionate(
            (p) => specchiata(p, orizzontale: true),
          ),
        ),
        ChipParametro(
          etichetta: t.azSpecchiaVert,
          attivo: foto?.flipV ?? false,
          onTap: () => ctrl.modificaFotoSelezionate(
            (p) => specchiata(p, orizzontale: false),
          ),
        ),
      ],
      contenuto: _Cursore(
        nome: t.parAngolo,
        minimo: LimitiFoto.rotazioneMin,
        massimo: LimitiFoto.rotazioneMax,
        iniziale: 0,
        leggi: (p) => p.rotation.round(),
        scrivi: (p, v) => conRotazione(p, v.toDouble()),
        unita: '°',
      ),
    );
  }
}
