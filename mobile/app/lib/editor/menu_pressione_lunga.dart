/// Menu dal basso della pressione lunga (piano §4.5).
///
/// - Su un elemento: Copia, Taglia, Duplica, Blocca, Porta davanti, Manda dietro, Libera/In disposizione, Sposta in
///   pagina, «Seleziona più», Elimina.
/// - Sul vuoto: Incolla qui, Aggiungi testo qui, Aggiungi forma qui, Seleziona tutto e le azioni della pagina.
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

Future<void> _foglio(
  BuildContext context,
  Widget Function(BuildContext) corpo,
) {
  final contenitore = ProviderScope.containerOf(context);
  return showModalBottomSheet<void>(
    context: context,
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
        child: Padding(
          padding: const EdgeInsets.all(MisureScrl.spazio),
          child: Builder(builder: corpo),
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

Widget _tessere(List<Widget> voci) =>
    Wrap(runSpacing: MisureScrl.spazioPiccolo, children: voci);

Widget _voce(
  BuildContext context,
  String chiave,
  IconData icona,
  String etichetta,
  VoidCallback azione, {
  bool attiva = false,
  bool spenta = false,
  bool pericolo = false,
}) => SizedBox(
  height: MisureScrl.barraInferiore,
  child: TesseraVoce(
    key: ValueKey('menu-$chiave'),
    icona: icona,
    etichetta: etichetta,
    attiva: attiva,
    spenta: spenta,
    colore: pericolo ? ColoriScrl.pericolo : null,
    onTap: () {
      Navigator.of(context).pop();
      azione();
    },
  ),
);

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
    if (_scegliPagina) {
      final n = stato.snapshot.canvas.numFrames;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.menuScegliPagina,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: MisureScrl.spazioPiccolo),
          Wrap(
            spacing: MisureScrl.spazioPiccolo,
            runSpacing: MisureScrl.spazioPiccolo,
            children: [
              for (var k = 0; k < n; k++)
                ChipParametro(
                  key: ValueKey('menu-pagina-$k'),
                  etichetta: t.menuPaginaNumero(k + 1),
                  attivo: k == stato.pagina,
                  onTap: () {
                    Navigator.of(context).pop();
                    ctrl.spostaFotoInPagina(k);
                  },
                ),
            ],
          ),
        ],
      );
    }
    return _tessere([
      _voce(
        context,
        'copia',
        Icons.copy_rounded,
        t.menuCopia,
        ctrl.copiaSelezione,
      ),
      _voce(
        context,
        'taglia',
        Icons.content_cut_rounded,
        t.menuTaglia,
        ctrl.tagliaSelezione,
      ),
      _voce(
        context,
        'duplica',
        Icons.control_point_duplicate_rounded,
        t.duplica,
        ctrl.duplicaSelezione,
      ),
      _voce(
        context,
        'blocca',
        bloccati ? Icons.lock_open_rounded : Icons.lock_outline,
        bloccati ? t.strSblocca : t.strBlocca,
        ctrl.bloccaSelezione,
        attiva: bloccati,
      ),
      _voce(
        context,
        'davanti',
        Icons.flip_to_front_rounded,
        t.dispDavanti,
        ctrl.davantiSelezione,
      ),
      _voce(
        context,
        'dietro',
        Icons.flip_to_back_rounded,
        t.dispDietro,
        ctrl.dietroSelezione,
      ),
      if (foto.isNotEmpty) ...[
        _voce(
          context,
          'libera',
          tutteLibere ? Icons.grid_view_rounded : Icons.open_with_rounded,
          tutteLibere ? t.inDisposizione : t.libera,
          ctrl.liberaSelezione,
        ),
        SizedBox(
          height: MisureScrl.barraInferiore,
          child: TesseraVoce(
            key: const ValueKey('menu-sposta-pagina'),
            icona: Icons.drive_file_move_outlined,
            etichetta: t.menuSpostaInPagina,
            onTap: () => setState(() => _scegliPagina = true),
          ),
        ),
      ],
      _voce(
        context,
        'seleziona-piu',
        Icons.checklist_rounded,
        t.menuSelezionaPiu,
        () {
          ctrl.impostaSelezionePiu(true);
          ctrl.messaggio(MessaggioEditor.selezionaPiu);
        },
      ),
      _voce(
        context,
        'elimina',
        Icons.delete_outline_rounded,
        t.elimina,
        ctrl.eliminaSelezione,
        pericolo: true,
      ),
    ]);
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
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.menuAggiungiForma,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: MisureScrl.spazioPiccolo),
          SizedBox(
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
                      onTap: () {
                        Navigator.of(context).pop();
                        ctrl.nuovaForma(tipo, punto: widget.punto);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }
    return _tessere([
      _voce(
        context,
        'incolla',
        Icons.content_paste_rounded,
        t.menuIncolla,
        () => unawaited(ctrl.incolla(pagina: widget.pagina)),
        spenta: !haAppunti,
      ),
      _voce(
        context,
        'testo',
        Icons.title_rounded,
        t.menuAggiungiTesto,
        () => ctrl.nuovoTesto(punto: widget.punto),
      ),
      SizedBox(
        height: MisureScrl.barraInferiore,
        child: TesseraVoce(
          key: const ValueKey('menu-forma'),
          icona: Icons.category_outlined,
          etichetta: t.menuAggiungiForma,
          onTap: () => setState(() => _scegliForma = true),
        ),
      ),
      _voce(
        context,
        'seleziona-tutto',
        Icons.select_all_rounded,
        t.menuSelezionaTutto,
        ctrl.selezionaTutto,
      ),
      _voce(
        context,
        'azioni-pagina',
        Icons.view_carousel_outlined,
        t.menuAzioniPagina,
        () => ctrl.apriStrumento(Strumento.pagine),
      ),
    ]);
  }
}
