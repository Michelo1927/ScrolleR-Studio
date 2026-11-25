/// Menu dal basso della pressione lunga (piano §4.5).
///
/// - Su un elemento: in alto Copia, Taglia, Duplica (le azioni rapide, in tre tessere); sotto, in un elenco,
///   Porta davanti, Manda dietro, Libera/In disposizione, Sposta in pagina, Blocca, «Seleziona più»; a parte,
///   in fondo, Elimina.
/// - Sul vuoto: un elenco con Incolla qui, Aggiungi testo qui, Aggiungi forma qui, Seleziona tutto e le azioni
///   della pagina.
///
/// Le voci che aprono un secondo livello (Sposta in pagina, Aggiungi forma) hanno la freccia ›; il secondo livello
/// ha ‹ con il suo nome per tornare indietro.
///
/// Il menu sta sopra l'editor ma fuori dal suo `ProviderScope`: gli si passa lo stesso contenitore.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'icone_forme.dart';
import 'pannelli_forma.dart' show nomeForma;
import 'stato.dart';
import 'widget_comuni.dart';

/// Altezza di una riga dell'elenco (più dell'area toccabile minima, per respirare).
const double _altezzaRiga = 52;

Future<void> _foglio(
  BuildContext context,
  Widget Function(BuildContext) corpo,
) {
  final contenitore = ProviderScope.containerOf(context);
  return showModalBottomSheet<void>(
    context: context,
    sheetAnimationStyle: MotoScrl.foglio(context),
    backgroundColor: ColoriScrl.pannello,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(MisureScrl.angoloPannello),
      ),
    ),
    builder: (sheet) => UncontrolledProviderScope(
      container: contenitore,
      child: SafeArea(
        // Il foglio dà una larghezza libera: senza questo si stringerebbe attorno al contenuto
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              MisureScrl.spazio,
              0,
              MisureScrl.spazio,
              MisureScrl.spazio,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Maniglia(),
                Builder(builder: corpo),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Pressione lunga su un elemento (già selezionato, con tutto il suo gruppo).
///
/// Con [soloPagina] si apre direttamente la scelta della pagina di «Sposta in pagina».
Future<void> mostraMenuElemento(
  BuildContext context, {
  bool soloPagina = false,
}) => _foglio(context, (_) => _MenuElemento(soloPagina: soloPagina));

/// Pressione lunga sul vuoto della pagina [pagina], nel punto [punto] della striscia.
Future<void> mostraMenuVuoto(
  BuildContext context, {
  required int pagina,
  required Punto punto,
}) => _foglio(context, (_) => _MenuVuoto(pagina: pagina, punto: punto));

/// Chiude il menu e poi esegue [azione].
VoidCallback _chiudiE(BuildContext context, VoidCallback azione) => () {
  Navigator.of(context).pop();
  azione();
};

class _MenuElemento extends ConsumerStatefulWidget {
  const _MenuElemento({this.soloPagina = false});

  final bool soloPagina;

  @override
  ConsumerState<_MenuElemento> createState() => _MenuElementoState();
}

class _MenuElementoState extends ConsumerState<_MenuElemento> {
  late bool _scegliPagina = widget.soloPagina;

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final ctrl = ref.read(editorProvider.notifier);
    final stato = ref.watch(editorProvider);
    final sel = stato.elementiSelezionati;
    final foto = sel.whereType<PhotoItem>().toList();
    final bloccati = sel.isNotEmpty && sel.every((e) => e.locked);
    final tutteLibere = foto.isNotEmpty && foto.every((p) => p.free);
    // I sottotitoli non si copiano né si duplicano: ogni video ne ha un blocco solo
    final soloSottotitoli =
        sel.isNotEmpty && sel.every((e) => e is CaptionItem);
    if (_scegliPagina) {
      final n = stato.snapshot.canvas.numFrames;
      return _Livello(
        titolo: t.menuScegliPagina,
        // Aperto da solo (dalla barra della selezione) ‹ chiude; dal menu torna al menu
        onIndietro: widget.soloPagina
            ? () => Navigator.of(context).pop()
            : () => setState(() => _scegliPagina = false),
        child: Wrap(
          spacing: MisureScrl.spazioPiccolo,
          runSpacing: MisureScrl.spazioPiccolo,
          children: [
            for (var k = 0; k < n; k++)
              ChipParametro(
                key: ValueKey('menu-pagina-$k'),
                etichetta: t.menuPaginaNumero(k + 1),
                attivo: k == stato.pagina,
                onTap: _chiudiE(context, () => ctrl.spostaFotoInPagina(k)),
              ),
          ],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!soloSottotitoli) ...[
          _FilaRapida([
            _Rapida(
              chiave: 'copia',
              icona: Icons.copy_rounded,
              etichetta: t.menuCopia,
              onTap: _chiudiE(context, ctrl.copiaSelezione),
            ),
            _Rapida(
              chiave: 'taglia',
              icona: Icons.content_cut_rounded,
              etichetta: t.menuTaglia,
              onTap: _chiudiE(context, ctrl.tagliaSelezione),
            ),
            _Rapida(
              chiave: 'duplica',
              icona: Icons.control_point_duplicate_rounded,
              etichetta: t.duplica,
              onTap: _chiudiE(context, ctrl.duplicaSelezione),
            ),
          ]),
          const SizedBox(height: MisureScrl.spazioPiccolo + 4),
        ],
        _Gruppo([
          _Riga(
            chiave: 'davanti',
            icona: Icons.flip_to_front_rounded,
            etichetta: t.dispDavanti,
            onTap: _chiudiE(context, ctrl.davantiSelezione),
          ),
          _Riga(
            chiave: 'dietro',
            icona: Icons.flip_to_back_rounded,
            etichetta: t.dispDietro,
            onTap: _chiudiE(context, ctrl.dietroSelezione),
          ),
          if (foto.isNotEmpty) ...[
            _Riga(
              chiave: 'libera',
              icona: tutteLibere
                  ? Icons.grid_view_rounded
                  : Icons.open_with_rounded,
              etichetta: tutteLibere ? t.inDisposizione : t.libera,
              onTap: _chiudiE(context, ctrl.liberaSelezione),
            ),
            _Riga(
              chiave: 'sposta-pagina',
              icona: Icons.drive_file_move_outlined,
              etichetta: _senzaPuntini(t.menuSpostaInPagina),
              livello: true,
              onTap: () => setState(() => _scegliPagina = true),
            ),
          ],
          _Riga(
            chiave: 'blocca',
            icona: bloccati ? Icons.lock_open_rounded : Icons.lock_outline,
            etichetta: bloccati ? t.strSblocca : t.strBlocca,
            onTap: _chiudiE(context, ctrl.bloccaSelezione),
          ),
          _Riga(
            chiave: 'seleziona-piu',
            icona: Icons.checklist_rounded,
            etichetta: t.menuSelezionaPiu,
            onTap: _chiudiE(context, () {
              ctrl.impostaSelezionePiu(true);
              ctrl.messaggio(MessaggioEditor.selezionaPiu);
            }),
          ),
        ]),
        const SizedBox(height: MisureScrl.spazioPiccolo + 4),
        _Gruppo([
          _Riga(
            chiave: 'elimina',
            icona: Icons.delete_outline_rounded,
            etichetta: t.elimina,
            colore: ColoriScrl.pericoloTesto,
            onTap: _chiudiE(context, ctrl.eliminaSelezione),
          ),
        ]),
      ],
    );
  }
}

class _MenuVuoto extends ConsumerStatefulWidget {
  const _MenuVuoto({required this.pagina, required this.punto});

  final int pagina;
  final Punto punto;

  @override
  ConsumerState<_MenuVuoto> createState() => _MenuVuotoState();
}

class _MenuVuotoState extends ConsumerState<_MenuVuoto> {
  bool _scegliForma = false;

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final ctrl = ref.read(editorProvider.notifier);
    final haAppunti = ref.watch(appuntiProvider) != null;
    if (_scegliForma) {
      return _Livello(
        titolo: t.menuAggiungiForma,
        onIndietro: () => setState(() => _scegliForma = false),
        child: SizedBox(
          height: 88,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final tipo in tipiForma)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TesseraScelta(
                    key: ValueKey('menu-forma-$tipo'),
                    disegno: IconaForma(tipo: tipo),
                    etichetta: nomeForma(t, tipo),
                    scelta: false,
                    larghezza: 92,
                    altezza: 88,
                    onTap: _chiudiE(
                      context,
                      () => ctrl.nuovaForma(tipo, punto: widget.punto),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return _Gruppo([
      _Riga(
        chiave: 'incolla',
        icona: Icons.content_paste_rounded,
        etichetta: t.menuIncolla,
        spenta: !haAppunti,
        onTap: _chiudiE(
          context,
          () => unawaited(ctrl.incolla(pagina: widget.pagina)),
        ),
      ),
      _Riga(
        chiave: 'testo',
        icona: Icons.title_rounded,
        etichetta: t.menuAggiungiTesto,
        onTap: _chiudiE(context, () => ctrl.nuovoTesto(punto: widget.punto)),
      ),
      _Riga(
        chiave: 'forma',
        icona: Icons.category_outlined,
        etichetta: t.menuAggiungiForma,
        livello: true,
        onTap: () => setState(() => _scegliForma = true),
      ),
      _Riga(
        chiave: 'seleziona-tutto',
        icona: Icons.select_all_rounded,
        etichetta: t.menuSelezionaTutto,
        onTap: _chiudiE(context, ctrl.selezionaTutto),
      ),
      _Riga(
        chiave: 'azioni-pagina',
        icona: Icons.view_carousel_outlined,
        etichetta: t.menuAzioniPagina,
        onTap: _chiudiE(context, () => ctrl.apriStrumento(Strumento.pagine)),
      ),
    ]);
  }
}

/// «Sposta in pagina…» senza i puntini finali: nell'elenco il secondo livello lo dice già la freccia ›.
String _senzaPuntini(String s) =>
    s.endsWith('…') ? s.substring(0, s.length - 1) : s;

/// Lineetta in cima al foglio: dice che si può trascinare giù per chiuderlo.
class _Maniglia extends StatelessWidget {
  const _Maniglia();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 10, bottom: 14),
    child: Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ColoriScrl.bordo,
          borderRadius: BorderRadius.all(Radius.circular(2)),
        ),
        child: SizedBox(width: 36, height: 4),
      ),
    ),
  );
}

/// Secondo livello del menu: ‹ con il nome, poi il contenuto.
class _Livello extends StatelessWidget {
  const _Livello({
    required this.titolo,
    required this.onIndietro,
    required this.child,
  });

  final String titolo;
  final VoidCallback onIndietro;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // Il bordo sinistro dell'icona in linea con il contenuto sotto
            Transform.translate(
              offset: const Offset(-12, 0),
              child: PulsanteIcona(
                key: const ValueKey('menu-indietro'),
                icona: Icons.chevron_left_rounded,
                etichetta: t.indietro,
                onTap: onIndietro,
              ),
            ),
            Expanded(
              child: Transform.translate(
                offset: const Offset(-12, 0),
                child: Text(
                  titolo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: TestoScrl.grande,
                    fontWeight: TestoScrl.marcato,
                    color: ColoriScrl.testo,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: MisureScrl.spazioPiccolo),
        child,
        const SizedBox(height: MisureScrl.spazioPiccolo),
      ],
    );
  }
}

/// Le azioni rapide: tessere della stessa larghezza su tutta la riga.
class _FilaRapida extends StatelessWidget {
  const _FilaRapida(this.voci);

  final List<Widget> voci;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < voci.length; i++) ...[
        if (i > 0) const SizedBox(width: MisureScrl.spazioPiccolo),
        Expanded(child: voci[i]),
      ],
    ],
  );
}

/// Azione rapida: icona sopra il nome, su una tessera.
class _Rapida extends StatelessWidget {
  const _Rapida({
    required this.chiave,
    required this.icona,
    required this.etichetta,
    required this.onTap,
  });

  final String chiave;
  final IconData icona;
  final String etichetta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: etichetta,
    excludeSemantics: true,
    child: Material(
      color: ColoriScrl.rilievo,
      borderRadius: BorderRadius.circular(MisureScrl.angoloTessera),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('menu-$chiave'),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icona, size: 24, color: ColoriScrl.testo),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    etichetta,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: TestoScrl.piccolo,
                      color: ColoriScrl.testo,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Righe raccolte in un blocco con gli angoli arrotondati, separate da una linea sottile.
class _Gruppo extends StatelessWidget {
  const _Gruppo(this.righe);

  final List<Widget> righe;

  @override
  Widget build(BuildContext context) => Material(
    color: ColoriScrl.rilievo,
    borderRadius: BorderRadius.circular(MisureScrl.angoloTessera),
    clipBehavior: Clip.antiAlias,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < righe.length; i++) ...[
          if (i > 0)
            const Padding(
              // La linea parte dal testo, non dall'icona
              padding: EdgeInsets.only(left: 56),
              child: SizedBox(
                height: 1,
                child: ColoredBox(color: ColoriScrl.pannello),
              ),
            ),
          righe[i],
        ],
      ],
    ),
  );
}

/// Una voce dell'elenco: icona, nome e, se apre un secondo livello, la freccia ›.
class _Riga extends StatelessWidget {
  const _Riga({
    required this.chiave,
    required this.icona,
    required this.etichetta,
    required this.onTap,
    this.colore,
    this.livello = false,
    this.spenta = false,
  });

  final String chiave;
  final IconData icona;
  final String etichetta;
  final VoidCallback onTap;
  final Color? colore;

  /// Apre un secondo livello del menu.
  final bool livello;

  /// Si vede più chiara (per esempio Incolla con gli appunti vuoti).
  final bool spenta;

  @override
  Widget build(BuildContext context) {
    final c = spenta ? ColoriScrl.testoSpento : (colore ?? ColoriScrl.testo);
    return Semantics(
      button: true,
      label: etichetta,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('menu-$chiave'),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _altezzaRiga),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
            child: Row(
              children: [
                Icon(icona, size: 22, color: c),
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    etichetta,
                    style: TextStyle(fontSize: TestoScrl.normale, color: c),
                  ),
                ),
                if (livello)
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: ColoriScrl.testo,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
