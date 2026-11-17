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
        : (colore ?? (attiva ? ColoriScrl.accentoTesto : ColoriScrl.testo));
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
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icona, size: 24, color: c),
                const SizedBox(height: 2),
                // Mai tagliata con i puntini: se non c'è spazio (schermo stretto, testo grande) si rimpicciolisce
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    etichetta,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: TestoScrl.piccolo,
                      fontWeight: attiva
                          ? TestoScrl.marcato
                          : TestoScrl.regolare,
                      color: c,
                    ),
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
    this.margine = true,
  });

  final IconData icona;
  final String etichetta;
  final VoidCallback onTap;
  final bool attiva;
  final bool spenta;
  final Color? colore;

  /// Larghezza fissa (null = quella che dà il genitore, per le righe che stanno tutte nello schermo).
  final double? larghezza;

  /// Spazio a destra, per le file che scorrono.
  final bool margine;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(right: margine ? MisureScrl.spazioPiccolo : 0),
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
            color: attivo ? ColoriScrl.accentoPieno : ColoriScrl.rilievo,
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

  /// Ultimo valore intero mandato durante il trascinamento: il documento si aggiorna solo quando cambia.
  int? _ultimoMandato;

  /// Testo del valore: «+12», «-5», «40%», o quello scelto da [CursoreGrande.formato].
  String _testo(double valore) {
    final w = widget;
    final v = valore.round();
    return w.formato?.call(v) ??
        '${w.daCentro && v > 0 ? '+' : ''}$v${w.unita}';
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final valore = (_locale ?? w.valore).clamp(w.minimo, w.massimo);
    final intervallo = w.massimo - w.minimo;
    final frazione = intervallo == 0 ? 0.0 : (valore - w.minimo) / intervallo;
    final zero = intervallo == 0
        ? 0.0
        : ((0 - w.minimo) / intervallo).clamp(0.0, 1.0);
    return GestureDetector(
      onDoubleTap: () {
        setState(() => _locale = null);
        w.onCambia(w.iniziale.round());
        w.onFine();
      },
      child: SizedBox(
        height: _altezzaRighello,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  trackShape: _TracciaRighello(
                    passi: intervallo.round(),
                    daCentro: w.daCentro,
                    frazioneZero: zero,
                  ),
                  tickMarkShape: SliderTickMarkShape.noTickMark,
                  thumbColor: ColoriScrl.accento,
                  thumbShape: const _MarcatoreRighello(),
                  // Il bordo di 24 dp ai lati resta (l'area di presa è la stessa di sempre), ma senza alone
                  overlayColor: Colors.transparent,
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 24,
                  ),
                ),
                child: Semantics(
                  label: w.etichetta,
                  child: Slider(
                    value: valore,
                    min: w.minimo,
                    max: w.massimo,
                    // Niente `divisions`: con i passi lo Slider anima il marcatore verso ogni valore nuovo e resta
                    // indietro rispetto al dito. Così segue il dito; il valore si arrotonda solo quando si manda.
                    semanticFormatterCallback: _testo,
                    onChanged: (v) {
                      setState(() => _locale = v);
                      final r = v.round();
                      if (r != _ultimoMandato) {
                        _ultimoMandato = r;
                        w.onCambia(r);
                      }
                    },
                    onChangeStart: (_) => _ultimoMandato = null,
                    onChangeEnd: (_) {
                      setState(() => _locale = null);
                      w.onFine();
                    },
                  ),
                ),
              ),
            ),
            // Il valore sta sopra il marcatore e lo segue
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, vincoli) {
                  final x = 24 + (vincoli.maxWidth - 48) * frazione;
                  return IgnorePointer(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: x - 40,
                          width: 80,
                          bottom: _altezzaRighello - 16,
                          child: Text(
                            _testo(valore),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: TestoScrl.normale,
                              fontWeight: TestoScrl.marcato,
                              color: ColoriScrl.testo,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Altezza del righello: il valore sta sopra il marcatore, le tacche sotto.
const double _altezzaRighello = 48;

/// Tacche del righello: una per passo (o una ogni pochi passi, se sono tanti), più alta ogni cinque e allo zero.
/// Le tacche tra l'origine e il marcatore sono piene, le altre più spente.
class _TracciaRighello extends SliderTrackShape with BaseSliderTrackShape {
  const _TracciaRighello({
    required this.passi,
    required this.daCentro,
    required this.frazioneZero,
  });

  final int passi;
  final bool daCentro;
  final double frazioneZero;

  /// Distanza minima tra due tacche, in dp.
  static const double _distanza = 7;

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
    if (passi <= 0) return;
    final canvas = context.canvas;
    final salto = math.max(1, (passi / (r.width / _distanza)).ceil());
    final origine = r.left + r.width * (daCentro ? frazioneZero : 0);
    final da = math.min(origine, thumbCenter.dx);
    final a = math.max(origine, thumbCenter.dx);
    final piena = Paint()..color = ColoriScrl.testo;
    final spenta = Paint()..color = ColoriScrl.testoSecondario.withAlpha(150);
    final cy = r.center.dy;
    final indiceZero = (passi * frazioneZero).round();
    for (var i = 0; i <= passi; i += salto) {
      final x = r.left + r.width * i / passi;
      final grande = i % (salto * 5) == 0 || (daCentro && i == indiceZero);
      final mezza = grande ? 8.0 : 5.0;
      final attiva = x >= da - 0.5 && x <= a + 0.5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x - 1, cy + 14 - mezza, x + 1, cy + 14 + mezza),
          const Radius.circular(1),
        ),
        attiva ? piena : spenta,
      );
    }
  }
}

/// Marcatore del righello: un triangolo sopra le tacche e una tacca più alta, con l'accento.
class _MarcatoreRighello extends SliderComponentShape {
  const _MarcatoreRighello();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(2, 2);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final colore = Paint()..color = ColoriScrl.accento;
    final triangolo = Path()
      ..moveTo(center.dx - 5, center.dy - 6)
      ..lineTo(center.dx + 5, center.dy - 6)
      ..lineTo(center.dx, center.dy + 2)
      ..close();
    canvas.drawPath(triangolo, colore);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          center.dx - 1.5,
          center.dy + 5,
          center.dx + 1.5,
          center.dy + 23,
        ),
        const Radius.circular(1.5),
      ),
      colore,
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

/// Riga in fondo a uno strumento: annulla (✕), nome e conferma (✓). Uno strumento aperto da un menu (Stile › Sfondo)
/// ha davanti al nome il menu a cui ✓ e ✕ riportano. Senza [onConferma] (i menu) c'è solo ✕ per chiudere.
class PiedeStrumento extends StatelessWidget {
  const PiedeStrumento({
    super.key,
    required this.nome,
    required this.onAnnulla,
    required this.onConferma,
    required this.etichettaAnnulla,
    required this.etichettaConferma,
    this.confronto,
    this.percorso,
    this.iconaAnnulla = Icons.close_rounded,
  });

  final String nome;
  final VoidCallback onAnnulla;
  final VoidCallback? onConferma;
  final String etichettaAnnulla;
  final String etichettaConferma;

  /// Pulsante `◐` prima/dopo, tra il nome e ✓ (solo per gli strumenti che cambiano i colori).
  final Widget? confronto;

  /// Il menu da cui si è aperto lo strumento.
  final String? percorso;
  final IconData iconaAnnulla;

  @override
  Widget build(BuildContext context) {
    final stile = Theme.of(context).textTheme.titleMedium;
    return SizedBox(
      height: MisureScrl.tocco,
      child: Row(
        children: [
          PulsanteIcona(
            icona: iconaAnnulla,
            etichetta: etichettaAnnulla,
            onTap: onAnnulla,
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(
                  children: [
                    if (percorso != null && percorso!.isNotEmpty)
                      TextSpan(
                        text: '$percorso  ›  ',
                        style: stile?.copyWith(
                          color: ColoriScrl.testoSecondario,
                          fontWeight: TestoScrl.regolare,
                        ),
                      ),
                    TextSpan(text: nome),
                  ],
                ),
                maxLines: 1,
                textAlign: TextAlign.center,
                style: stile,
              ),
            ),
          ),
          ?confronto,
          if (onConferma != null)
            _PulsanteConferma(etichetta: etichettaConferma, onTap: onConferma!)
          else
            const SizedBox(width: MisureScrl.tocco),
        ],
      ),
    );
  }
}

/// ✓ di uno strumento: un cerchio pieno con l'accento (l'azione principale), dentro un'area toccabile di 48 dp.
class _PulsanteConferma extends StatelessWidget {
  const _PulsanteConferma({required this.etichetta, required this.onTap});

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
      child: const SizedBox(
        width: MisureScrl.tocco,
        height: MisureScrl.tocco,
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: ColoriScrl.accentoPieno,
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: 34,
              height: 34,
              child: Icon(
                Icons.check_rounded,
                size: 22,
                color: ColoriScrl.suAccento,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Una scelta di un [ControlloSegmentato].
class VoceSegmento<T> {
  const VoceSegmento({
    required this.valore,
    required this.etichetta,
    this.chiave,
  });

  final T valore;
  final String etichetta;

  /// Chiave del segmento (per le prove).
  final Key? chiave;
}

/// Scelta di una sola voce tra poche, in un'unica pillola: la voce scelta si riempie con l'accento. Sostituisce le
/// file di pillole separate dove le scelte si escludono a vicenda (formato, scala, che cosa esportare).
class ControlloSegmentato<T> extends StatelessWidget {
  const ControlloSegmentato({
    super.key,
    required this.voci,
    required this.scelto,
    required this.onScelto,
  });

  final List<VoceSegmento<T>> voci;
  final T scelto;
  final ValueChanged<T> onScelto;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MisureScrl.tocco,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ColoriScrl.barra,
        borderRadius: BorderRadius.circular(MisureScrl.tocco / 2),
      ),
      child: Row(
        children: [
          for (final v in voci)
            Expanded(
              child: Semantics(
                button: true,
                selected: v.valore == scelto,
                label: v.etichetta,
                excludeSemantics: true,
                child: GestureDetector(
                  key: v.chiave,
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onScelto(v.valore),
                  child: AnimatedContainer(
                    duration: MotoScrl.durata(context, MotoScrl.breve),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: v.valore == scelto
                          ? ColoriScrl.accentoPieno
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        v.etichetta,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: TestoScrl.normale,
                          fontWeight: v.valore == scelto
                              ? TestoScrl.marcato
                              : TestoScrl.regolare,
                          color: v.valore == scelto
                              ? ColoriScrl.suAccento
                              : ColoriScrl.testo,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
