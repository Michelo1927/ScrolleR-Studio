/// Pannello «Stile» (piano §4.3) e i suoi strumenti: Sfondo (tinta, sfumatura, foto sfocata), Numeri di pagina e
/// Indicatore «scorri»; in più gli interruttori Guide e Aggancio. Gli strumenti hanno l'anatomia di tutti gli altri:
/// ogni cambio si vede subito come **bozza**, `✕` scarta, `✓` la trasforma in un solo passo di cronologia.
/// Guide e Aggancio sono preferenze di vista: non entrano in Annulla né nel progetto (come sul desktop).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import '../l10n/app_localizations.dart';
import '../media/cache_media.dart';
import '../render/risorse_pagina.dart' show campoSfondoAsset;
import '../theme/tokens.dart';
import 'intelaiatura.dart';
import 'pannello_libreria.dart' show ImmagineVoce;
import 'selettore_colore.dart';
import 'sessione.dart';
import 'stato.dart';
import 'widget_comuni.dart';

// ---------------------------------------------------------------- Menu Stile

/// «Stile»: Sfondo, Numeri di pagina, Indicatore «scorri», Guide, Aggancio.
class PannelloStile extends ConsumerWidget {
  const PannelloStile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final ctrl = ref.read(editorProvider.notifier);
    final guide = ref.watch(editorProvider.select((s) => s.mostraGuide));
    final aggancio = ref.watch(editorProvider.select((s) => s.aggancioAttivo));
    return PannelloBasso(
      onScarta: ctrl.chiudiStrumento,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: MisureScrl.barraInferiore + 24,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(MisureScrl.spazio),
              children: [
                TesseraVoce(
                  key: const ValueKey('stile-sfondo'),
                  icona: Icons.wallpaper_rounded,
                  etichetta: t.stileSfondo,
                  onTap: () => ctrl.apriStrumento(Strumento.sfondo),
                ),
                TesseraVoce(
                  key: const ValueKey('stile-numeri'),
                  icona: Icons.pin_outlined,
                  etichetta: t.stileNumeri,
                  onTap: () => ctrl.apriStrumento(Strumento.numeriPagina),
                ),
                TesseraVoce(
                  key: const ValueKey('stile-scorri'),
                  icona: Icons.swipe_rounded,
                  etichetta: t.stileScorri,
                  onTap: () => ctrl.apriStrumento(Strumento.scorri),
                ),
                TesseraVoce(
                  key: const ValueKey('stile-guide'),
                  icona: Icons.grid_3x3_rounded,
                  etichetta: t.stileGuide,
                  attiva: guide,
                  onTap: ctrl.alternaGuide,
                ),
                TesseraVoce(
                  key: const ValueKey('stile-aggancio'),
                  icona: Icons.border_style_rounded,
                  etichetta: t.stileAggancio,
                  attiva: aggancio,
                  onTap: ctrl.alternaAggancio,
                ),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Sfondo

enum _Param { foto, sfocatura, scurisci }

/// Sfondo: tre schede (Tinta, Sfumatura con due colori e direzione, Foto sfocata con scelta della foto, Sfocatura
/// 0–100 e Scurisci 0–80). Portato da `BackgroundDialog` e `_apply_background` del desktop.
class PannelloSfondo extends ConsumerStatefulWidget {
  const PannelloSfondo({super.key});

  @override
  ConsumerState<PannelloSfondo> createState() => _PannelloSfondoState();
}

class _PannelloSfondoState extends ConsumerState<PannelloSfondo> {
  /// Quale dei due colori della sfumatura si sta scegliendo.
  bool _secondo = false;
  _Param _param = _Param.foto;

  SessioneEditor get _s => ref.read(sessioneProvider);
  ControlloEditor get _ctrl => ref.read(editorProvider.notifier);

  void _modifica(CanvasState Function(CanvasState) f) => _ctrl.modificaTela(f);

  /// `_default_blur_photo`: la foto selezionata, altrimenti la prima della tela o della libreria.
  LibraryEntry? _fotoPredefinita(StatoEditor stato) {
    final sel = stato.elementiSelezionati.whereType<PhotoItem>();
    if (sel.isNotEmpty) return _voceDi(sel.first);
    final foto = stato.snapshot.items;
    if (foto.isNotEmpty) return _voceDi(foto.first);
    return stato.libreria.isEmpty ? null : stato.libreria.first;
  }

  static LibraryEntry _voceDi(PhotoItem p) =>
      LibraryEntry(path: p.path, rel: p.rel, asset: p.asset);

  /// Imposta la foto di sfondo: percorso, `rel` e, se è collegata alla galleria, il campo solo mobile `bg_blur_asset`.
  static CanvasState _conFoto(CanvasState c, LibraryEntry v) {
    final extra = {...c.extra};
    if (v.asset != null) {
      extra[campoSfondoAsset] = v.asset!.toJson();
    } else {
      extra.remove(campoSfondoAsset);
    }
    return c.copyWith(
      bgMode: 'blur',
      bgBlurPath: v.path,
      bgBlurRel: () => v.rel,
      extra: extra,
    );
  }

  void _scegliScheda(String modo, StatoEditor stato) {
    if (modo == 'blur') {
      final c = stato.snapshot.canvas;
      final haFoto = c.bgBlurPath.isNotEmpty || c.bgBlurRel != null;
      final v = haFoto ? null : _fotoPredefinita(stato);
      _modifica((c) => v == null ? c.copyWith(bgMode: 'blur') : _conFoto(c, v));
    } else {
      _modifica((c) => c.copyWith(bgMode: modo));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final stato = ref.watch(editorProvider);
    final c = stato.snapshot.canvas;
    final modo = switch (c.bgMode) {
      'gradient' => 'gradient',
      'blur' => 'blur',
      _ => 'solid',
    };
    final schede = [
      for (final (m, nome) in [
        ('solid', t.sfTinta),
        ('gradient', t.sfSfumatura),
        ('blur', t.sfFotoSfocata),
      ])
        ChipParametro(
          key: ValueKey('sfondo-$m'),
          etichetta: nome,
          attivo: modo == m,
          // La foto sfocata ha bisogno di almeno una foto
          onTap: () {
            if (m == 'blur' && _fotoPredefinita(stato) == null) {
              _ctrl.messaggio(MessaggioEditor.sfondoSenzaFoto);
              return;
            }
            _scegliScheda(m, stato);
          },
        ),
    ];
    switch (modo) {
      case 'gradient':
        return PannelloColore(
          key: const ValueKey('sfondo-colore-sfumatura'),
          nome: t.stileSfondo,
          colore: _secondo ? c.bgColor2 : c.bgColor,
          onColore: (v) => _modifica(
            (c) => _secondo
                ? c.copyWith(bgMode: 'gradient', bgColor2: v)
                : c.copyWith(bgMode: 'gradient', bgColor: v),
          ),
          chipsPrima: [
            ...schede,
            ChipParametro(
              key: const ValueKey('sfondo-colore1'),
              etichetta: t.sfColoreIniziale,
              attivo: !_secondo,
              onTap: () => setState(() => _secondo = false),
            ),
            ChipParametro(
              key: const ValueKey('sfondo-colore2'),
              etichetta: t.sfColoreFinale,
              attivo: _secondo,
              onTap: () => setState(() => _secondo = true),
            ),
            for (final (d, nome) in [
              ('vertical', t.sfDirVerticale),
              ('horizontal', t.sfDirOrizzontale),
              ('diagonal', t.sfDirDiagonale),
            ])
              ChipParametro(
                key: ValueKey('sfondo-dir-$d'),
                etichetta: nome,
                attivo: c.bgDirection == d,
                onTap: () => _modifica((c) => c.copyWith(bgDirection: d)),
              ),
          ],
        );
      case 'blur':
        return Intelaiatura(
          nome: t.stileSfondo,
          chips: [
            ...schede,
            ChipParametro(
              etichetta: t.sfFoto,
              attivo: _param == _Param.foto,
              onTap: () => setState(() => _param = _Param.foto),
            ),
            ChipParametro(
              etichetta: t.sfSfocatura,
              valore: '${c.bgBlurAmount}',
              attivo: _param == _Param.sfocatura,
              onTap: () => setState(() => _param = _Param.sfocatura),
            ),
            ChipParametro(
              etichetta: t.sfScurisci,
              valore: '${c.bgDim}',
              attivo: _param == _Param.scurisci,
              onTap: () => setState(() => _param = _Param.scurisci),
            ),
          ],
          contenuto: switch (_param) {
            _Param.foto => _elencoFoto(stato),
            _Param.sfocatura => _cursore(
              t.sfSfocatura,
              c.bgBlurAmount,
              0,
              100,
              50,
              (v) => _modifica((c) => c.copyWith(bgBlurAmount: v)),
            ),
            _Param.scurisci => _cursore(
              t.sfScurisci,
              c.bgDim,
              0,
              80,
              15,
              (v) => _modifica((c) => c.copyWith(bgDim: v)),
              unita: '%',
            ),
          },
        );
      default:
        return PannelloColore(
          key: const ValueKey('sfondo-colore-tinta'),
          nome: t.stileSfondo,
          colore: c.bgColor,
          onColore: (v) =>
              _modifica((c) => c.copyWith(bgMode: 'solid', bgColor: v)),
          chipsPrima: schede,
        );
    }
  }

  Widget _cursore(
    String nome,
    int valore,
    int minimo,
    int massimo,
    int iniziale,
    ValueChanged<int> onCambia, {
    String unita = '',
  }) => Padding(
    key: ValueKey('sfondo-cursore-$nome'),
    padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
    child: Center(
      child: CursoreGrande(
        etichetta: nome,
        valore: valore.toDouble(),
        minimo: minimo.toDouble(),
        massimo: massimo.toDouble(),
        iniziale: iniziale.toDouble(),
        unita: unita,
        onCambia: onCambia,
        onFine: () {},
      ),
    ),
  );

  /// Le foto della libreria (e quelle della tela) come miniature: un tocco sceglie la foto di sfondo.
  Widget _elencoFoto(StatoEditor stato) {
    final c = stato.snapshot.canvas;
    final voci = <String, LibraryEntry>{};
    for (final e in stato.libreria) {
      voci.putIfAbsent(_s.chiaveVoce(e), () => e);
    }
    for (final p in stato.snapshot.items) {
      voci.putIfAbsent(chiaveMedia(p), () => _voceDi(p));
    }
    final asset = MediaAsset.fromJson(c.extra[campoSfondoAsset]);
    final scelta = chiaveMedia(
      PhotoItem(uid: 0, path: c.bgBlurPath, rel: c.bgBlurRel, asset: asset),
    );
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
      children: [
        for (final e in voci.entries)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              key: ValueKey('sfondo-foto-${e.key}'),
              onTap: () => _modifica((c) => _conFoto(c, e.value)),
              child: Semantics(
                button: true,
                selected: e.key == scelta,
                label: Testi.of(context).sfFoto,
                excludeSemantics: true,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: e.key == scelta
                          ? ColoriScrl.accento
                          : ColoriScrl.bordo,
                      width: e.key == scelta ? 3 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: ImmagineVoce(sessione: _s, voce: e.value),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Numeri di pagina e «scorri»

enum _ParamNumeri { formato, posizione, stile }

/// Mini pagina con un'etichetta nella posizione [pos] (vert + oriz: `b`/`t`/`c` e `l`/`c`/`r`).
class _IconaPosizione extends StatelessWidget {
  const _IconaPosizione(this.pos);

  final String pos;

  @override
  Widget build(BuildContext context) {
    final vert = pos.isNotEmpty ? pos[0] : 'b';
    final oriz = pos.length > 1 ? pos[1] : 'c';
    return Container(
      width: 34,
      height: 44,
      decoration: BoxDecoration(
        border: Border.all(color: ColoriScrl.testoSecondario),
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment(
        switch (oriz) {
          'l' => -0.7,
          'r' => 0.7,
          _ => 0.0,
        },
        switch (vert) {
          't' => -0.8,
          'c' => 0.0,
          _ => 0.8,
        },
      ),
      child: Container(
        width: 14,
        height: 6,
        decoration: BoxDecoration(
          color: ColoriScrl.accento,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

String _nomePosizione(Testi t, String pos) => switch (pos) {
  'br' => t.posBassoDestra,
  'bl' => t.posBassoSinistra,
  'tc' => t.posAltoCentro,
  'tr' => t.posAltoDestra,
  'tl' => t.posAltoSinistra,
  'cr' => t.posCentroDestra,
  _ => t.posBassoCentro,
};

String _nomeStileEtichetta(Testi t, String stile) => switch (stile) {
  'light' => t.ovChiaro,
  'plain' => t.ovSoloTesto,
  _ => t.ovScuro,
};

Widget _tessere<T>(
  Iterable<T> valori,
  T attuale,
  String Function(T) nome,
  Widget Function(T) disegno,
  ValueChanged<T> onScelta, {
  double larghezza = 96,
}) => ListView(
  scrollDirection: Axis.horizontal,
  padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
  children: [
    for (final v in valori)
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: TesseraScelta(
          key: ValueKey('tessera-$v'),
          disegno: disegno(v),
          etichetta: nome(v),
          scelta: v == attuale,
          larghezza: larghezza,
          altezza: 84,
          onTap: () => onScelta(v),
        ),
      ),
  ],
);

const _stiliEtichetta = ['dark', 'light', 'plain'];

Widget _testoTessera(String testo) => Text(
  testo,
  style: const TextStyle(
    fontSize: TestoScrl.grande,
    fontWeight: TestoScrl.marcato,
    color: ColoriScrl.testo,
  ),
);

/// Numeri di pagina: interruttore, formato (4), posizione (6) e stile dell'etichetta (3).
class PannelloNumeriPagina extends ConsumerStatefulWidget {
  const PannelloNumeriPagina({super.key});

  @override
  ConsumerState<PannelloNumeriPagina> createState() =>
      _PannelloNumeriPaginaState();
}

class _PannelloNumeriPaginaState extends ConsumerState<PannelloNumeriPagina> {
  _ParamNumeri _param = _ParamNumeri.formato;

  ControlloEditor get _ctrl => ref.read(editorProvider.notifier);

  void _modifica(CanvasState Function(CanvasState) f) => _ctrl.modificaTela(f);

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final c = ref.watch(editorProvider.select((s) => s.snapshot.canvas));
    final Widget contenuto;
    if (c.pageNumbers && c.numFrames < 2) {
      contenuto = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
          child: Text(
            t.numDuePagine,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    } else {
      contenuto = switch (_param) {
        _ParamNumeri.formato => _tessere<String>(
          const ['slash', 'of', 'padded', 'plain'],
          c.pageNumberFormat,
          (f) => switch (f) {
            'of' => t.numFormatoDi,
            'padded' => '01/05',
            'plain' => '1',
            _ => '1/5',
          },
          (f) => _testoTessera(switch (f) {
            'of' => t.numFormatoDi,
            'padded' => '01/05',
            'plain' => '1',
            _ => '1/5',
          }),
          (f) => _modifica((c) => c.copyWith(pageNumberFormat: f)),
        ),
        _ParamNumeri.posizione => _tessere<String>(
          const ['bc', 'br', 'bl', 'tc', 'tr', 'tl'],
          c.pageNumberPos,
          (p) => _nomePosizione(t, p),
          _IconaPosizione.new,
          (p) => _modifica((c) => c.copyWith(pageNumberPos: p)),
          larghezza: 104,
        ),
        _ParamNumeri.stile => _tessere<String>(
          _stiliEtichetta,
          c.overlayStyle,
          (s) => _nomeStileEtichetta(t, s),
          (s) => _testoTessera('1/5'),
          (s) => _modifica((c) => c.copyWith(overlayStyle: s)),
        ),
      };
    }
    return Intelaiatura(
      nome: t.stileNumeri,
      chips: [
        ChipParametro(
          key: const ValueKey('numeri-acceso'),
          etichetta: t.numAcceso,
          attivo: c.pageNumbers,
          onTap: () =>
              _modifica((c) => c.copyWith(pageNumbers: !c.pageNumbers)),
        ),
        ChipParametro(
          etichetta: t.numFormato,
          attivo: _param == _ParamNumeri.formato,
          onTap: () => setState(() => _param = _ParamNumeri.formato),
        ),
        ChipParametro(
          etichetta: t.numPosizione,
          attivo: _param == _ParamNumeri.posizione,
          onTap: () => setState(() => _param = _ParamNumeri.posizione),
        ),
        ChipParametro(
          etichetta: t.numStile,
          attivo: _param == _ParamNumeri.stile,
          onTap: () => setState(() => _param = _ParamNumeri.stile),
        ),
      ],
      contenuto: contenuto,
    );
  }
}

enum _ParamScorri { testo, posizione, stile }

/// Indicatore «scorri»: interruttore, testo (come «Scorri →»), posizione (2) e stile dell'etichetta (3, lo stesso dei
/// numeri di pagina).
class PannelloScorri extends ConsumerStatefulWidget {
  const PannelloScorri({super.key});

  @override
  ConsumerState<PannelloScorri> createState() => _PannelloScorriState();
}

class _PannelloScorriState extends ConsumerState<PannelloScorri> {
  _ParamScorri _param = _ParamScorri.testo;
  late final TextEditingController _testo = TextEditingController(
    text: ref.read(editorProvider).snapshot.canvas.swipeText,
  );

  ControlloEditor get _ctrl => ref.read(editorProvider.notifier);

  @override
  void dispose() {
    _testo.dispose();
    super.dispose();
  }

  void _modifica(CanvasState Function(CanvasState) f) => _ctrl.modificaTela(f);

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final c = ref.watch(editorProvider.select((s) => s.snapshot.canvas));
    final contenuto = switch (_param) {
      _ParamScorri.testo => Padding(
        padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
        child: Center(
          child: TextField(
            key: const ValueKey('scorri-testo'),
            controller: _testo,
            decoration: InputDecoration(labelText: t.scorriTestoEtichetta),
            onChanged: (v) => _modifica((c) => c.copyWith(swipeText: v)),
          ),
        ),
      ),
      _ParamScorri.posizione => _tessere<String>(
        const ['br', 'cr'],
        c.swipePos,
        (p) => _nomePosizione(t, p),
        _IconaPosizione.new,
        (p) => _modifica((c) => c.copyWith(swipePos: p)),
        larghezza: 104,
      ),
      _ParamScorri.stile => _tessere<String>(
        _stiliEtichetta,
        c.overlayStyle,
        (s) => _nomeStileEtichetta(t, s),
        (s) => _testoTessera(c.swipeText.isEmpty ? '→' : c.swipeText),
        (s) => _modifica((c) => c.copyWith(overlayStyle: s)),
      ),
    };
    return Intelaiatura(
      nome: t.stileScorri,
      chips: [
        ChipParametro(
          key: const ValueKey('scorri-acceso'),
          etichetta: t.scorriAcceso,
          attivo: c.swipeHint,
          onTap: () => _modifica((c) => c.copyWith(swipeHint: !c.swipeHint)),
        ),
        ChipParametro(
          etichetta: t.scorriTesto,
          attivo: _param == _ParamScorri.testo,
          onTap: () => setState(() => _param = _ParamScorri.testo),
        ),
        ChipParametro(
          etichetta: t.numPosizione,
          attivo: _param == _ParamScorri.posizione,
          onTap: () => setState(() => _param = _ParamScorri.posizione),
        ),
        ChipParametro(
          etichetta: t.numStile,
          attivo: _param == _ParamScorri.stile,
          onTap: () => setState(() => _param = _ParamScorri.stile),
        ),
      ],
      contenuto: contenuto,
    );
  }
}
