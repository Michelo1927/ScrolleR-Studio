/// Piccoli pezzi riusati dall'editor: pulsante a icona, voce della barra, tessera di scelta, cursore e
/// pannello dal basso. Tutti con area toccabile di almeno 48 dp ed etichetta per i lettori di schermo; niente
/// tooltip (piano §3.8 e §14).
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// Pulsante a sola icona, 48 dp, con etichetta per i lettori di schermo. Senza [onTap] è spento.
class PulsanteIcona extends StatelessWidget {
  const PulsanteIcona({
    super.key,
    required this.icona,
    required this.etichetta,
    required this.onTap,
    this.colore,
    this.onLongPress,
  });

  final IconData icona;
  final String etichetta;
  final VoidCallback? onTap;
  final Color? colore;

  /// Pressione lunga (per esempio Annulla → Cronologia).
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final attivo = onTap != null;
    return Semantics(
      button: true,
      enabled: attivo,
      label: etichetta,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        onLongPress: onLongPress,
        radius: MisureScrl.tocco / 2,
        child: SizedBox(
          width: MisureScrl.tocco,
          height: MisureScrl.tocco,
          child: Icon(
            icona,
            size: 24,
            color: attivo
                ? (colore ?? ColoriScrl.testo)
                : ColoriScrl.testoSpento,
          ),
        ),
      ),
    );
  }
}

/// Voce della barra inferiore: icona e una o due parole.
class VoceBarra extends StatelessWidget {
  const VoceBarra({
    super.key,
    required this.icona,
    required this.etichetta,
    required this.onTap,
    this.attiva = false,
    this.spenta = false,
    this.colore,
    this.larghezza,
  });

  final IconData icona;
  final String etichetta;
  final VoidCallback onTap;
  final bool attiva;

  /// Funzione non ancora pronta: si vede ma più chiara, e il tocco spiega che arriva.
  final bool spenta;
  final Color? colore;
  final double? larghezza;

  @override
  Widget build(BuildContext context) {
    final c = spenta
        ? ColoriScrl.testoSpento
        : (colore ?? (attiva ? ColoriScrl.accento : ColoriScrl.testo));
    return Semantics(
      button: true,
      label: etichetta,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: larghezza,
          height: MisureScrl.barraInferiore,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icona, size: 24, color: c),
                const SizedBox(height: 2),
                Text(
                  etichetta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: TestoScrl.piccolo,
                    fontWeight: TestoScrl.marcato,
                    color: c,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tessera larga con icona e nome (96 dp): le azioni dei pannelli Pagine, Stile e Disponi.
class TesseraVoce extends StatelessWidget {
  const TesseraVoce({
    super.key,
    required this.icona,
    required this.etichetta,
    required this.onTap,
    this.attiva = false,
    this.spenta = false,
    this.colore,
    this.larghezza = 96,
  });

  final IconData icona;
  final String etichetta;
  final VoidCallback onTap;
  final bool attiva;
  final bool spenta;
  final Color? colore;
  final double larghezza;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: MisureScrl.spazioPiccolo),
    child: Container(
      width: larghezza,
      decoration: BoxDecoration(
        color: attiva ? ColoriScrl.premuto : ColoriScrl.rilievo,
        borderRadius: BorderRadius.circular(MisureScrl.angoloTessera),
        border: attiva ? Border.all(color: ColoriScrl.accento, width: 2) : null,
      ),
      child: VoceBarra(
        icona: icona,
        etichetta: etichetta,
        onTap: onTap,
        attiva: attiva,
        spenta: spenta,
        colore: colore,
      ),
    ),
  );
}

/// Tessera quadrata (12 dp di angolo) con un disegno e una didascalia: disposizioni, stili, formati.
class TesseraScelta extends StatelessWidget {
  const TesseraScelta({
    super.key,
    required this.disegno,
    required this.etichetta,
    required this.scelta,
    required this.onTap,
    this.larghezza = 84,
    this.altezza = 84,
  });

  final Widget disegno;
  final String etichetta;
  final bool scelta;
  final VoidCallback onTap;
  final double larghezza;
  final double altezza;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: scelta,
      label: etichetta,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: larghezza,
          height: altezza,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: scelta ? ColoriScrl.premuto : ColoriScrl.rilievo,
            borderRadius: BorderRadius.circular(MisureScrl.angoloTessera),
            border: Border.all(
              color: scelta ? ColoriScrl.accento : ColoriScrl.bordo,
              width: scelta ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(child: Center(child: disegno)),
              Text(
                etichetta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: TestoScrl.piccolo,
                  color: ColoriScrl.testo,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Parametro di uno strumento (a pillola): ne è attivo uno alla volta.
class ChipParametro extends StatelessWidget {
  const ChipParametro({
    super.key,
    required this.etichetta,
    required this.attivo,
    required this.onTap,
    this.valore,
  });

  final String etichetta;
  final bool attivo;
  final VoidCallback onTap;

  /// Valore corrente, mostrato accanto al nome.
  final String? valore;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: attivo,
      label: valore == null ? etichetta : '$etichetta, $valore',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: attivo ? ColoriScrl.accento : ColoriScrl.rilievo,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            valore == null ? etichetta : '$etichetta  $valore',
            style: TextStyle(
              fontSize: TestoScrl.normale,
              fontWeight: TestoScrl.marcato,
              color: attivo ? ColoriScrl.suAccento : ColoriScrl.testo,
            ),
          ),
        ),
      ),
    );
  }
}

/// Un solo cursore grande con il valore accanto; doppio tocco = valore iniziale (piano §4.4).
/// Se [daCentro] la barra colorata parte dal punto zero (Luminosità, Calore, Angolo…) e il valore ha il segno.
class CursoreGrande extends StatefulWidget {
  const CursoreGrande({
    super.key,
    required this.valore,
    required this.minimo,
    required this.massimo,
    required this.iniziale,
    required this.onCambia,
    required this.onFine,
    required this.etichetta,
    this.daCentro = false,
    this.unita = '',
    this.formato,
  });

  final double valore;
  final double minimo;
  final double massimo;
  final double iniziale;
  final ValueChanged<int> onCambia;
  final VoidCallback onFine;
  final String etichetta;
  final bool daCentro;

  /// Simbolo dopo il valore («%», «°»).
  final String unita;

  /// Testo del valore, se non è un numero semplice (per esempio i decimi di secondo dei video: «0:04,5»).
  final String Function(int valore)? formato;

  @override
  State<CursoreGrande> createState() => _CursoreGrandeState();
}

class _CursoreGrandeState extends State<CursoreGrande> {
  /// Valore sotto il dito mentre si trascina: il pollice lo segue subito, senza aspettare che il documento
  /// (e la pagina) si aggiornino, così non resta mai indietro rispetto al dito.
  double? _locale;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final valore = _locale ?? w.valore;
    final daCentro = w.daCentro;
    return GestureDetector(
      onDoubleTap: () {
        setState(() => _locale = null);
        w.onCambia(w.iniziale.round());
        w.onFine();
      },
      child: Row(
        children: [
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                trackShape: daCentro ? const _TracciaDaCentro() : null,
                activeTrackColor: ColoriScrl.accento,
                inactiveTrackColor: ColoriScrl.rilievo,
                thumbColor: ColoriScrl.suAccento,
                overlayColor: ColoriScrl.accento.withValues(alpha: 0.2),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
              ),
              child: Semantics(
                label: w.etichetta,
                child: Slider(
                  value: valore.clamp(w.minimo, w.massimo),
                  min: w.minimo,
                  max: w.massimo,
                  divisions: (w.massimo - w.minimo).round(),
                  onChanged: (v) {
                    setState(() => _locale = v);
                    w.onCambia(v.round());
                  },
                  onChangeEnd: (_) {
                    setState(() => _locale = null);
                    w.onFine();
                  },
                ),
              ),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              w.formato?.call(valore.round()) ??
                  '${daCentro && valore.round() > 0 ? '+' : ''}${valore.round()}${w.unita}',
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: TestoScrl.grande,
                fontWeight: TestoScrl.marcato,
                color: ColoriScrl.testo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Traccia del cursore che parte dal centro: la parte colorata va dal punto zero fino al pollice.
class _TracciaDaCentro extends SliderTrackShape with BaseSliderTrackShape {
  const _TracciaDaCentro();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
  }) {
    final r = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final raggio = Radius.circular(r.height / 2);
    final canvas = context.canvas;
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, raggio),
      Paint()..color = sliderTheme.inactiveTrackColor ?? ColoriScrl.rilievo,
    );
    final centro = r.center.dx;
    final da = math.min(centro, thumbCenter.dx);
    final a = math.max(centro, thumbCenter.dx);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(da, r.top, a, r.bottom), raggio),
      Paint()..color = sliderTheme.activeTrackColor ?? ColoriScrl.accento,
    );
  }
}

/// Meno, valore e più: per i valori interi con pochi passi (foto per pagina, pagine).
class Contatore extends StatelessWidget {
  const Contatore({
    super.key,
    required this.testo,
    required this.onMeno,
    required this.onPiu,
    required this.etichettaMeno,
    required this.etichettaPiu,
  });

  final String testo;
  final VoidCallback? onMeno;
  final VoidCallback? onPiu;
  final String etichettaMeno;
  final String etichettaPiu;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        PulsanteIcona(
          icona: Icons.remove_rounded,
          etichetta: etichettaMeno,
          onTap: onMeno,
        ),
        SizedBox(
          width: 110,
          child: Text(
            testo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: TestoScrl.grande,
              fontWeight: TestoScrl.marcato,
              color: ColoriScrl.testo,
            ),
          ),
        ),
        PulsanteIcona(
          icona: Icons.add_rounded,
          etichetta: etichettaPiu,
          onTap: onPiu,
        ),
      ],
    );
  }
}

/// Pannello che sale dal basso: angoli superiori di 16 dp, altezza massima il 40% dello schermo, contenuto
/// che scorre solo in orizzontale. Trascinandolo verso il basso si scarta (come ✕).
class PannelloBasso extends StatelessWidget {
  const PannelloBasso({
    super.key,
    required this.child,
    required this.onScarta,
    this.altezza,
  });

  final Widget child;
  final VoidCallback onScarta;

  /// Altezza fissa del contenuto (se manca, quella che serve, fino al 40% dello schermo).
  final double? altezza;

  @override
  Widget build(BuildContext context) {
    final massimo =
        MediaQuery.sizeOf(context).height * MisureScrl.pannelloMassimo;
    return GestureDetector(
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 400) onScarta();
      },
      child: Container(
        constraints: BoxConstraints(maxHeight: math.max(massimo, 220)),
        height: altezza,
        decoration: const BoxDecoration(
          color: ColoriScrl.pannello,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(MisureScrl.angoloPannello),
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Riga in fondo a uno strumento: annulla (✕), nome e conferma (✓).
class PiedeStrumento extends StatelessWidget {
  const PiedeStrumento({
    super.key,
    required this.nome,
    required this.onAnnulla,
    required this.onConferma,
    required this.etichettaAnnulla,
    required this.etichettaConferma,
    this.confronto,
  });

  final String nome;
  final VoidCallback onAnnulla;
  final VoidCallback onConferma;
  final String etichettaAnnulla;
  final String etichettaConferma;

  /// Pulsante `◐` prima/dopo, tra il nome e ✓ (solo per gli strumenti che cambiano i colori).
  final Widget? confronto;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MisureScrl.tocco,
      child: Row(
        children: [
          PulsanteIcona(
            icona: Icons.close_rounded,
            etichetta: etichettaAnnulla,
            onTap: onAnnulla,
          ),
          Expanded(
            child: Text(
              nome,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ?confronto,
          PulsanteIcona(
            icona: Icons.check_rounded,
            etichetta: etichettaConferma,
            onTap: onConferma,
            colore: ColoriScrl.accento,
          ),
        ],
      ),
    );
  }
}
