/// Telaio comune dei pannelli degli strumenti (piano §4.4): pillole dei parametri che scorrono in orizzontale,
/// contenuto (un cursore, tessere o campioni), piede con `✕` scarta · nome · `✓` conferma. Lo usano gli strumenti
/// Foto, Testo e Forme.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'stato.dart';
import 'widget_comuni.dart';

/// Telaio di ogni strumento: pillole dei parametri, contenuto (cursore o tessere), piede con ✕ · nome · ◐ · ✓.
/// Senza [contenuto] (strumenti fatti solo di pillole) o senza [chips] (strumenti fatti solo di tessere) il
/// pannello è più basso.
class Intelaiatura extends ConsumerWidget {
  const Intelaiatura({
    super.key,
    required this.nome,
    required this.chips,
    this.contenuto,
    this.confronto,
  });

  final String nome;
  final List<Widget> chips;
  final Widget? contenuto;

  /// Pulsante `◐` prima/dopo, tra il nome e ✓ (solo per gli strumenti che cambiano i colori).
  final Widget? confronto;

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
          if (chips.isNotEmpty) ...[
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: MisureScrl.spazio,
                ),
                children: [
                  for (final c in chips)
                    Padding(
                      padding: const EdgeInsets.only(
                        right: MisureScrl.spazioPiccolo,
                      ),
                      child: Center(child: c),
                    ),
                ],
              ),
            ),
            const SizedBox(height: MisureScrl.spazioPiccolo),
          ],
          if (contenuto != null) SizedBox(height: 96, child: contenuto),
          PiedeStrumento(
            nome: nome,
            etichettaAnnulla: t.annulla,
            etichettaConferma: t.conferma,
            onAnnulla: ctrl.chiudiStrumento,
            onConferma: ctrl.confermaEChiudi,
            confronto: confronto,
          ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}

/// Campione di colore tondo (48 dp toccabili), con un anello se è quello scelto. Senza [colore] è «Nessuno»:
/// cerchio vuoto barrato.
class CampioneColore extends StatelessWidget {
  const CampioneColore({
    super.key,
    required this.colore,
    required this.scelto,
    required this.onTap,
    required this.etichetta,
  });

  /// Il colore da mostrare; null = «Nessuno» (trasparente).
  final Color? colore;
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
              color: colore ?? ColoriScrl.rilievo,
              shape: BoxShape.circle,
              border: Border.all(
                color: scelto ? ColoriScrl.accento : ColoriScrl.bordo,
                width: scelto ? 3 : 1,
              ),
            ),
            child: colore == null
                ? const Icon(
                    Icons.block_rounded,
                    size: 22,
                    color: ColoriScrl.testoSecondario,
                  )
                : null,
          ),
        ),
      ),
    ),
  );
}

/// Un parametro con cursore: il valore attuale e cosa fare quando cambia. Le pillole e il cursore di
/// [PannelloCursori] si costruiscono da un elenco di questi.
class ParametroCursore {
  const ParametroCursore({
    required this.nome,
    required this.minimo,
    required this.massimo,
    required this.iniziale,
    required this.valore,
    required this.onCambia,
    this.unita = '',
  });

  final String nome;
  final int minimo, massimo, iniziale;

  /// Valore attuale (null se non c'è un elemento).
  final int? valore;
  final ValueChanged<int> onCambia;
  final String unita;
}

/// Pillole dei parametri + cursore del parametro attivo; le azioni extra seguono le pillole.
class PannelloCursori extends StatefulWidget {
  const PannelloCursori({
    super.key,
    required this.nome,
    required this.parametri,
    this.azioni = const [],
    this.chipsPrima = const [],
    this.confronto,
    this.attivoIniziale = 0,
  });

  final String nome;
  final List<ParametroCursore> parametri;
  final List<Widget> azioni;

  /// Pillole che stanno prima dei parametri (per esempio le schede di uno strumento con cursore e colore).
  final List<Widget> chipsPrima;
  final Widget? confronto;
  final int attivoIniziale;

  @override
  State<PannelloCursori> createState() => _PannelloCursoriState();
}

class _PannelloCursoriState extends State<PannelloCursori> {
  late int _attivo = widget.attivoIniziale;

  @override
  Widget build(BuildContext context) {
    final par = widget.parametri[_attivo.clamp(0, widget.parametri.length - 1)];
    return Intelaiatura(
      nome: widget.nome,
      confronto: widget.confronto,
      chips: [
        ...widget.chipsPrima,
        for (var i = 0; i < widget.parametri.length; i++)
          ChipParametro(
            etichetta: widget.parametri[i].nome,
            valore: widget.parametri[i].valore == null
                ? null
                : '${widget.parametri[i].valore}',
            attivo: i == _attivo,
            onTap: () => setState(() => _attivo = i),
          ),
        ...widget.azioni,
      ],
      contenuto: par.valore == null
          ? const SizedBox.shrink()
          : Padding(
              key: ValueKey('${widget.nome}/${par.nome}'),
              padding: const EdgeInsets.symmetric(
                horizontal: MisureScrl.spazio,
              ),
              child: Center(
                child: CursoreGrande(
                  etichetta: par.nome,
                  valore: par.valore!.toDouble(),
                  minimo: par.minimo.toDouble(),
                  massimo: par.massimo.toDouble(),
                  iniziale: par.iniziale.toDouble(),
                  daCentro: par.minimo < 0,
                  unita: par.unita,
                  onCambia: par.onCambia,
                  onFine: () {},
                ),
              ),
            ),
    );
  }
}
