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
import '../theme/tokens.dart';
import 'intelaiatura.dart';
import 'pannello_libreria.dart' show ImmagineVoce;
import 'selettore_colore.dart';
import 'sessione.dart';
import 'stato.dart';
import 'widget_comuni.dart';

// ---------------------------------------------------------------- Menu Stile

/// «Stile»: Sfondo, Numeri di pagina, Indicatore «scorri», Guide, Aggancio. Le cinque voci stanno tutte nello
/// schermo; ✕ chiude il menu. Gli strumenti che si aprono da qui (Sfondo, Numeri, «scorri») tornano qui con ✓ e ✕.
class PannelloStile extends ConsumerWidget {
  const PannelloStile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final ctrl = ref.read(editorProvider.notifier);
    final guide = ref.watch(editorProvider.select((s) => s.mostraGuide));
    final aggancio = ref.watch(editorProvider.select((s) => s.aggancioAttivo));
    Widget voce(
      String chiave,
      IconData icona,
      String etichetta,
      VoidCallback onTap, {
      bool attiva = false,
    }) => TesseraVoce(
      key: ValueKey(chiave),
      icona: icona,
      etichetta: etichetta,
      attiva: attiva,
      larghezza: null,
      margine: false,
      onTap: onTap,
    );
    return PannelloBasso(
      onScarta: ctrl.chiudiStrumento,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: MisureScrl.spazio),
          RigaTessere(
            altezza: MisureScrl.barraInferiore + 8,
            children: [
              voce(
                'stile-sfondo',
                Icons.wallpaper_rounded,
                t.stileSfondo,
                () => ctrl.apriStrumento(Strumento.sfondo),
              ),
              voce(
                'stile-numeri',
                Icons.pin_outlined,
                t.stileNumeri,
                () => ctrl.apriStrumento(Strumento.numeriPagina),
              ),
              voce(
                'stile-scorri',
                Icons.swipe_rounded,
                t.stileScorri,
                () => ctrl.apriStrumento(Strumento.scorri),
              ),
              voce(
                'stile-guide',
                Icons.grid_3x3_rounded,
                t.stileGuide,
                ctrl.alternaGuide,
                attiva: guide,
              ),
              voce(
                'stile-aggancio',
                Icons.border_style_rounded,
                t.stileAggancio,
                ctrl.alternaAggancio,
                attiva: aggancio,
              ),
            ],
          ),
          const SizedBox(height: MisureScrl.spazioPiccolo),
          PiedeStrumento(
            nome: t.barraStile,
            etichettaAnnulla: t.chiudi,
            etichettaConferma: t.conferma,
            onAnnulla: ctrl.chiudiStrumento,
            onConferma: null,
          ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Sfondo

/// Sfondo: tre schede (Tinta, Sfumatura con due colori e direzione, Foto sfocata con scelta della foto, Sfocatura
/// 0–100 e Scurisci 0–80). Portato da `BackgroundDialog` e `_apply_background` del desktop.
class PannelloSfondo extends ConsumerStatefulWidget {
  const PannelloSfondo({super.key});

  @override
  ConsumerState<PannelloSfondo> createState() => _PannelloSfondoState();
}

class _PannelloSfondoState extends ConsumerState<PannelloSfondo> {
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
    Widget tesseraTipo(String m, IconData icona, String nome) => TesseraVoce(
      key: ValueKey('sfondo-$m'),
      icona: icona,
      etichetta: nome,
      attiva: modo == m,
      larghezza: null,
      margine: false,
      // La foto sfocata ha bisogno di almeno una foto
      onTap: () {
        if (m == 'blur' && _fotoPredefinita(stato) == null) {
          _ctrl.messaggio(MessaggioEditor.sfondoSenzaFoto);
          return;
        }
        _scegliScheda(m, stato);
      },
    );
    final tipo = SchedaStrumento(
      etichetta: t.strTipo,
      chiave: const ValueKey('sfondo-scheda-tipo'),
      contenuto: RigaTessere(
        children: [
          tesseraTipo('solid', Icons.format_color_fill_rounded, t.sfTinta),
          tesseraTipo('gradient', Icons.gradient_rounded, t.sfSfumatura),
          tesseraTipo('blur', Icons.blur_on_rounded, t.sfFotoSfocata),
        ],
      ),
    );
    final List<SchedaStrumento> proprie = switch (modo) {
      'gradient' => [
        SchedaStrumento(
          etichetta: t.sfColoreIniziale,
          chiave: const ValueKey('sfondo-colore1'),
          contenuto: SelettoreColore(
            key: const ValueKey('sfondo-colore-iniziale'),
            colore: c.bgColor,
            onColore: (v) =>
                _modifica((c) => c.copyWith(bgMode: 'gradient', bgColor: v)),
          ),
        ),
        SchedaStrumento(
          etichetta: t.sfColoreFinale,
          chiave: const ValueKey('sfondo-colore2'),
          contenuto: SelettoreColore(
            key: const ValueKey('sfondo-colore-finale'),
            colore: c.bgColor2,
            onColore: (v) =>
                _modifica((c) => c.copyWith(bgMode: 'gradient', bgColor2: v)),
          ),
        ),
        SchedaStrumento(
          etichetta: t.sfDirezione,
          chiave: const ValueKey('sfondo-scheda-direzione'),
          contenuto: RigaTessere(
            children: [
              for (final (d, nome, icona) in [
                ('vertical', t.sfDirVerticale, Icons.south_rounded),
                ('horizontal', t.sfDirOrizzontale, Icons.east_rounded),
                ('diagonal', t.sfDirDiagonale, Icons.south_east_rounded),
              ])
                TesseraVoce(
                  key: ValueKey('sfondo-dir-$d'),
                  icona: icona,
                  etichetta: nome,
                  attiva: c.bgDirection == d,
                  larghezza: null,
                  margine: false,
                  onTap: () => _modifica((c) => c.copyWith(bgDirection: d)),
                ),
            ],
          ),
        ),
      ],
      'blur' => [
        SchedaStrumento(
          etichetta: t.sfFoto,
          chiave: const ValueKey('sfondo-scheda-foto'),
          contenuto: _elencoFoto(stato),
        ),
        SchedaStrumento(
          etichetta: t.sfSfocatura,
          chiave: const ValueKey('sfondo-scheda-sfocatura'),
          contenuto: _cursore(
            t.sfSfocatura,
            c.bgBlurAmount,
            0,
            100,
            50,
            (v) => _modifica((c) => c.copyWith(bgBlurAmount: v)),
          ),
        ),
        SchedaStrumento(
          etichetta: t.sfScurisci,
          chiave: const ValueKey('sfondo-scheda-scurisci'),
          contenuto: _cursore(
            t.sfScurisci,
            c.bgDim,
            0,
            80,
            15,
            (v) => _modifica((c) => c.copyWith(bgDim: v)),
            unita: '%',
          ),
        ),
      ],
      _ => [
        SchedaStrumento(
          etichetta: t.parColore,
          chiave: const ValueKey('sfondo-scheda-colore'),
          contenuto: SelettoreColore(
            key: const ValueKey('sfondo-colore-tinta'),
            colore: c.bgColor,
            onColore: (v) =>
                _modifica((c) => c.copyWith(bgMode: 'solid', bgColor: v)),
          ),
        ),
      ],
    };
    return Intelaiatura(nome: t.stileSfondo, schede: [tipo, ...proprie]);
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
  ControlloEditor get _ctrl => ref.read(editorProvider.notifier);

  void _modifica(CanvasState Function(CanvasState) f) => _ctrl.modificaTela(f);

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final c = ref.watch(editorProvider.select((s) => s.snapshot.canvas));
    // Con una pagina sola i numeri non si vedono: lo si dice al posto delle scelte
    final soloUna = c.pageNumbers && c.numFrames < 2;
    Widget o(Widget w) => soloUna
        ? Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MisureScrl.spazio,
              ),
              child: Text(
                t.numDuePagine,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          )
        : w;
    String formato(String f) => switch (f) {
      'of' => t.numFormatoDi,
      'padded' => '01/05',
      'plain' => '1',
      _ => '1/5',
    };
    return Intelaiatura(
      nome: t.stileNumeri,
      azioni: [
        AzioneStrumento(
          chiave: const ValueKey('numeri-acceso'),
          icona: Icons.pin_outlined,
          etichetta: t.numAcceso,
          attiva: c.pageNumbers,
          onTap: () =>
              _modifica((c) => c.copyWith(pageNumbers: !c.pageNumbers)),
        ),
      ],
      schede: [
        SchedaStrumento(
          etichetta: t.numFormato,
          contenuto: o(
            _tessere<String>(
              const ['slash', 'of', 'padded', 'plain'],
              c.pageNumberFormat,
              formato,
              (f) => _testoTessera(formato(f)),
              (f) => _modifica((c) => c.copyWith(pageNumberFormat: f)),
            ),
          ),
        ),
        SchedaStrumento(
          etichetta: t.numPosizione,
          contenuto: o(
            _tessere<String>(
              const ['bc', 'br', 'bl', 'tc', 'tr', 'tl'],
              c.pageNumberPos,
              (p) => _nomePosizione(t, p),
              _IconaPosizione.new,
              (p) => _modifica((c) => c.copyWith(pageNumberPos: p)),
              larghezza: 104,
            ),
          ),
        ),
        SchedaStrumento(
          etichetta: t.numStile,
          contenuto: o(
            _tessere<String>(
              _stiliEtichetta,
              c.overlayStyle,
              (s) => _nomeStileEtichetta(t, s),
              (s) => _testoTessera('1/5'),
              (s) => _modifica((c) => c.copyWith(overlayStyle: s)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Indicatore «scorri»: interruttore, testo (come «Scorri →»), posizione (2) e stile dell'etichetta (3, lo stesso dei
/// numeri di pagina).
class PannelloScorri extends ConsumerStatefulWidget {
  const PannelloScorri({super.key});

  @override
  ConsumerState<PannelloScorri> createState() => _PannelloScorriState();
}

class _PannelloScorriState extends ConsumerState<PannelloScorri> {
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
    return Intelaiatura(
      nome: t.stileScorri,
      azioni: [
        AzioneStrumento(
          chiave: const ValueKey('scorri-acceso'),
          icona: Icons.swipe_rounded,
          etichetta: t.scorriAcceso,
          attiva: c.swipeHint,
          onTap: () => _modifica((c) => c.copyWith(swipeHint: !c.swipeHint)),
        ),
      ],
      schede: [
        SchedaStrumento(
          etichetta: t.scorriTesto,
          contenuto: Padding(
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
        ),
        SchedaStrumento(
          etichetta: t.numPosizione,
          contenuto: _tessere<String>(
            const ['br', 'cr'],
            c.swipePos,
            (p) => _nomePosizione(t, p),
            _IconaPosizione.new,
            (p) => _modifica((c) => c.copyWith(swipePos: p)),
            larghezza: 104,
          ),
        ),
        SchedaStrumento(
          etichetta: t.numStile,
          contenuto: _tessere<String>(
            _stiliEtichetta,
            c.overlayStyle,
            (s) => _nomeStileEtichetta(t, s),
            (s) => _testoTessera(c.swipeText.isEmpty ? '→' : c.swipeText),
            (s) => _modifica((c) => c.copyWith(overlayStyle: s)),
          ),
        ),
      ],
    );
  }
}
