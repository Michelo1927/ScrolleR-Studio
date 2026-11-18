/// Pannelli degli strumenti Foto (piano §4.3, §4.4 e §6 «Foto»): Inquadra, Filtri, Regola, Effetti, Cornice, Ombra,
/// Ruota. Tutti hanno il telaio di [Intelaiatura]: schede dei parametri (sempre nello schermo), **un solo cursore**,
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
import 'intelaiatura.dart';
import 'selettore_colore.dart';
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
          onFine: () =>
              ref.read(sessioneProvider).risorse.qualitaRidotta = false,
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

/// Le schede dei parametri con cursore della foto principale; le azioni stanno sotto.
class _ConParametri extends ConsumerWidget {
  const _ConParametri({
    required this.nome,
    required this.parametri,
    this.azioni = const [],
    this.confronto = false,
  });

  final String nome;
  final List<_Par> parametri;
  final List<AzioneStrumento> azioni;
  final bool confronto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foto = ref.watch(_fotoPrincipale);
    return Intelaiatura(
      nome: nome,
      confronto: confronto ? const PulsanteConfronto() : null,
      azioni: azioni,
      schede: [for (final p in parametri) _scheda(p, foto)],
    );
  }
}

/// La scheda di un parametro della foto: il valore sulla tessera e il cursore.
SchedaStrumento _scheda(_Par p, PhotoItem? foto) {
  final v = foto == null ? null : p.leggi(foto);
  return SchedaStrumento(
    etichetta: p.nome,
    valore: v == null
        ? null
        : '${p.minimo < 0 && v > 0 ? '+' : ''}$v${p.unita.trim()}',
    modificata: v != null && v != p.iniziale,
    contenuto: _Cursore(
      key: ValueKey(p.nome),
      nome: p.nome,
      minimo: p.minimo,
      massimo: p.massimo,
      iniziale: p.iniziale,
      leggi: p.leggi,
      scrivi: p.scrivi,
      unita: p.unita,
    ),
  );
}

/// «Applica a tutte»: lo stesso colore (o stile) a tutte le foto del progetto.
AzioneStrumento _applicaATutte(Testi t, VoidCallback onTap) => AzioneStrumento(
  chiave: const ValueKey('azione-applica-tutte'),
  icona: Icons.library_add_check_outlined,
  etichetta: t.azApplicaATutte,
  onTap: onTap,
);

// ---------------------------------------------------------------- Regola

/// Regola: miglioramento automatico, luminosità, contrasto, ombre, luci, saturazione, calore, tinta, bianco e nero.
class PannelloRegola extends ConsumerWidget {
  const PannelloRegola({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final ctrl = ref.read(editorProvider.notifier);
    final foto = ref.watch(_fotoPrincipale);
    bool acceso(String k) => foto != null && adjOn(foto.adjust, k);
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
        AzioneStrumento(
          icona: Icons.auto_fix_high_rounded,
          etichetta: t.auto,
          attiva: acceso('auto'),
          onTap: () => ctrl.modificaFotoSelezionate(
            (p) => conInterruttore(p, 'auto', !adjOn(p.adjust, 'auto')),
          ),
        ),
        AzioneStrumento(
          icona: Icons.filter_b_and_w_rounded,
          etichetta: t.azBiancoNero,
          attiva: acceso('bw'),
          onTap: () => ctrl.modificaFotoSelezionate(
            (p) => conInterruttore(p, 'bw', !adjOn(p.adjust, 'bw')),
          ),
        ),
        AzioneStrumento(
          icona: Icons.restart_alt_rounded,
          etichetta: t.azReimpostaColori,
          onTap: () => ctrl.modificaFotoSelezionate(coloriReimpostati),
        ),
        _applicaATutte(t, ctrl.coloriATutteLeFoto),
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
      azioni: [_applicaATutte(t, ctrl.coloriATutteLeFoto)],
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
      fatte.add(await r.applica(base, presetAdjust(p.key), detailScale: 0.4));
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
    return Intelaiatura(
      nome: t.strFiltri,
      confronto: const PulsanteConfronto(),
      azioni: [_applicaATutte(t, ctrl.coloriATutteLeFoto)],
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
/// con le dita (un dito sposta, due ingrandiscono e ruotano). Più «Riempi / Foto intera», «Solo riquadro» e proporzioni.
class PannelloInquadra extends ConsumerWidget {
  const PannelloInquadra({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final ctrl = ref.read(editorProvider.notifier);
    final s = ref.read(sessioneProvider);
    final soloRiquadro = ref.watch(
      editorProvider.select((x) => x.soloRiquadro),
    );
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
        AzioneStrumento(
          icona: Icons.crop_free_rounded,
          etichetta: t.azRiempi,
          attiva: foto != null && foto.fitMode != 'contain',
          onTap: () => ctrl.modificaFotoSelezionate((p) => conFit(p, 'cover')),
        ),
        AzioneStrumento(
          icona: Icons.fit_screen_rounded,
          etichetta: t.azFotoIntera,
          attiva: foto != null && foto.fitMode == 'contain',
          onTap: () =>
              ctrl.modificaFotoSelezionate((p) => conFit(p, 'contain')),
        ),
        AzioneStrumento(
          icona: Icons.crop_rounded,
          etichetta: t.azSoloRiquadro,
          attiva: soloRiquadro,
          onTap: () => ctrl.impostaSoloRiquadro(!soloRiquadro),
        ),
        AzioneStrumento(
          icona: Icons.aspect_ratio_rounded,
          etichetta: riquadroDiPrima
              ? t.azRiquadroDiPrima
              : t.azProporzioniFoto,
          onTap: () => ctrl.modificaFotoSelezionate(
            (p) => alternaProporzioni(p, s.misuraDi(p)),
          ),
        ),
        AzioneStrumento(
          icona: Icons.restart_alt_rounded,
          etichetta: t.azReimposta,
          onTap: () => ctrl.modificaFotoSelezionate(inquadraturaReimpostata),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Cornice

/// Cornice: angoli arrotondati, spessore e colore del bordo.
class PannelloCornice extends ConsumerWidget {
  const PannelloCornice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final ctrl = ref.read(editorProvider.notifier);
    final foto = ref.watch(_fotoPrincipale);
    return Intelaiatura(
      nome: t.strCornice,
      azioni: [_applicaATutte(t, ctrl.stileATutteLeFoto)],
      schede: [
        _scheda(
          _Par(
            t.parAngoli,
            0,
            LimitiFoto.angoliMax,
            0,
            (p) => p.borderRadius.round(),
            conAngoli,
            unita: ' px',
          ),
          foto,
        ),
        _scheda(
          _Par(
            t.parBordo,
            0,
            LimitiFoto.bordoMax,
            0,
            (p) => p.borderWidth.round(),
            conBordo,
            unita: ' px',
          ),
          foto,
        ),
        SchedaStrumento(
          etichetta: t.parColore,
          contenuto: foto == null
              ? const SizedBox.shrink()
              : SelettoreColore(
                  colore: foto.borderColor,
                  onColore: (c) =>
                      ctrl.modificaFotoSelezionate((p) => conColoreBordo(p, c)),
                ),
        ),
      ],
    );
  }
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
      azioni: [_applicaATutte(t, ctrl.stileATutteLeFoto)],
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
    return Intelaiatura(
      nome: t.strRuota,
      azioni: [
        ...azioniRotazione(
          t,
          sinistra: () =>
              ctrl.modificaFotoSelezionate((p) => ruotataDi(p, -90)),
          destra: () => ctrl.modificaFotoSelezionate((p) => ruotataDi(p, 90)),
          dritta: () => ctrl.modificaFotoSelezionate((p) => conRotazione(p, 0)),
        ),
        AzioneStrumento(
          icona: Icons.flip_rounded,
          etichetta: t.azSpecchiaOrizz,
          attiva: foto?.flipH ?? false,
          onTap: () => ctrl.modificaFotoSelezionate(
            (p) => specchiata(p, orizzontale: true),
          ),
        ),
        AzioneStrumento(
          icona: Icons.swap_vert_rounded,
          etichetta: t.azSpecchiaVert,
          attiva: foto?.flipV ?? false,
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
