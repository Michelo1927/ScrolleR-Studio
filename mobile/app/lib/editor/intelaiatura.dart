/// Telaio comune dei pannelli degli strumenti (piano §4.4), rifatto perché nulla esca dallo schermo e ci sia sempre la
/// strada per tornare indietro:
/// - **poche schede** (fino a 4): una barra a segmenti che sta tutta nello schermo, il contenuto della scheda sotto;
/// - **tante schede** (Regola, Disposizione…): una griglia di tessere col nome e il valore attuale (quelle cambiate
///   hanno il valore colorato); un tocco apre il **dettaglio** del parametro, con ‹ per tornare alla griglia (anche il
///   gesto «indietro» di sistema ci torna);
/// - le **azioni** (interruttori e comandi: Auto, Applica a tutte, 90°…) stanno in una riga fissa di voci con icona;
/// - in fondo il piede con `✕` scarta · nome · `◐` · `✓` conferma.
/// L'altezza resta la stessa passando da una scheda o da un livello all'altro: la pagina sopra non salta.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'indietro.dart';
import 'stato.dart';
import 'widget_comuni.dart';

/// Altezza normale del contenuto di uno strumento (un righello, una fila di tessere, i campioni di colore).
const double altezzaContenuto = 96;

/// Una scheda di uno strumento: un parametro (col suo valore) o un gruppo di scelte.
class SchedaStrumento {
  const SchedaStrumento({
    required this.etichetta,
    required this.contenuto,
    this.valore,
    this.modificata = false,
    this.altezza = altezzaContenuto,
    this.intestazione,
    this.chiave,
  });

  final String etichetta;

  /// Il contenuto quando la scheda è aperta (un cursore, tessere, campioni…).
  final Widget contenuto;

  /// Valore attuale, scritto sulla tessera della griglia («+12», «Griglia», «Auto»).
  final String? valore;

  /// Il valore non è quello di partenza: nella griglia si vede colorato.
  final bool modificata;

  /// Altezza del contenuto.
  final double altezza;

  /// Nel dettaglio, al posto del nome: un comando legato al contenuto (per esempio «Tutto il carosello / Solo questa
  /// pagina» sopra le disposizioni).
  final Widget? intestazione;

  /// Chiave della tessera o del segmento (per le prove).
  final Key? chiave;
}

/// Un'azione di uno strumento: un comando che agisce subito o un interruttore ([attiva]).
class AzioneStrumento {
  const AzioneStrumento({
    required this.icona,
    required this.etichetta,
    required this.onTap,
    this.attiva = false,
    this.spenta = false,
    this.chiave,
  });

  final IconData icona;
  final String etichetta;
  final VoidCallback onTap;
  final bool attiva;
  final bool spenta;
  final Key? chiave;
}

/// Telaio di ogni strumento. Senza [schede] mostra solo [contenuto]; [azioni] stanno sotto, in una riga.
class Intelaiatura extends ConsumerStatefulWidget {
  const Intelaiatura({
    super.key,
    required this.nome,
    this.schede = const [],
    this.azioni = const [],
    this.contenuto,
    this.altezza = altezzaContenuto,
    this.confronto,
    this.schedaIniziale = 0,
    this.apriDettaglio = false,
    this.onScheda,
    this.segmentiMassimi = 4,
    this.onConferma,
  });

  final String nome;
  final List<SchedaStrumento> schede;
  final List<AzioneStrumento> azioni;

  /// Contenuto dello strumento senza schede.
  final Widget? contenuto;

  /// Altezza di [contenuto].
  final double altezza;

  /// Pulsante `◐` prima/dopo, tra il nome e ✓ (solo per gli strumenti che cambiano i colori).
  final Widget? confronto;

  /// Scheda scelta all'apertura.
  final int schedaIniziale;

  /// Con tante schede, apre subito il dettaglio di [schedaIniziale] invece della griglia (Disposizione: si sceglie
  /// la disposizione al primo tocco, le altre impostazioni sono dietro ‹).
  final bool apriDettaglio;

  /// Avvisa quando cambia la scheda aperta (null = la griglia).
  final ValueChanged<int?>? onScheda;

  /// Fino a quante schede si usa la barra a segmenti; oltre, la griglia (i filtri di una sola lista, come le
  /// categorie dei caratteri, restano segmenti anche se sono cinque).
  final int segmentiMassimi;

  /// ✓ diverso dal solito (per esempio con gli avvisi del motore da mostrare).
  final VoidCallback? onConferma;

  @override
  ConsumerState<Intelaiatura> createState() => _IntelaiaturaState();
}

class _IntelaiaturaState extends ConsumerState<Intelaiatura> {
  late int _scelta = widget.schedaIniziale;

  /// Con tante schede: dettaglio aperto (true) o griglia (false).
  late bool _dettaglio = widget.apriDettaglio;

  bool get _aGriglia => widget.schede.length > widget.segmentiMassimi;

  void _scegli(int i) {
    setState(() {
      _scelta = i;
      _dettaglio = true;
    });
    widget.onScheda?.call(i);
  }

  void _allaGriglia() {
    setState(() => _dettaglio = false);
    widget.onScheda?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final ctrl = ref.read(editorProvider.notifier);
    final strumento = ref.watch(editorProvider.select((s) => s.strumento));
    final schede = widget.schede;
    final scelta = schede.isEmpty ? 0 : _scelta.clamp(0, schede.length - 1);
    final Widget corpo;
    if (schede.isEmpty) {
      corpo = widget.contenuto == null
          ? const SizedBox.shrink()
          : SizedBox(height: widget.altezza, child: widget.contenuto);
    } else if (schede.length == 1) {
      corpo = SizedBox(
        height: schede.first.altezza,
        child: schede.first.contenuto,
      );
    } else if (!_aGriglia) {
      corpo = _segmenti(schede, scelta);
    } else {
      corpo = _griglia(t, schede, scelta);
    }
    final genitore = strumento.genitore;
    return PannelloBasso(
      onScarta: ctrl.chiudiStrumentoDaGesto,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: MisureScrl.spazioPiccolo),
          // Su uno schermo basso (o col testo grande) è il contenuto a cedere qualche punto, mai il piede o le azioni
          Flexible(child: corpo),
          if (widget.azioni.isNotEmpty) RigaAzioni(azioni: widget.azioni),
          PiedeStrumento(
            nome: widget.nome,
            percorso: genitore == Strumento.nessuno
                ? null
                : nomeMenu(t, genitore),
            etichettaAnnulla: t.annulla,
            etichettaConferma: t.conferma,
            onAnnulla: ctrl.chiudiStrumento,
            onConferma: widget.onConferma ?? ctrl.confermaEChiudi,
            confronto: widget.confronto,
          ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }

  /// Poche schede: barra a segmenti (tutta nello schermo) e, sotto, il contenuto della scheda scelta. L'altezza è
  /// quella della scheda più alta, così cambiando scheda il pannello non cambia misura.
  Widget _segmenti(List<SchedaStrumento> schede, int scelta) {
    final alta = schede.map((s) => s.altezza).reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: MisureScrl.tocco + MisureScrl.spazioPiccolo + alta,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
            child: ControlloSegmentato<int>(
              voci: [
                for (var i = 0; i < schede.length; i++)
                  VoceSegmento(
                    valore: i,
                    etichetta: schede[i].etichetta,
                    chiave: schede[i].chiave,
                  ),
              ],
              scelto: scelta,
              onScelto: (i) {
                setState(() => _scelta = i);
                widget.onScheda?.call(i);
              },
            ),
          ),
          const SizedBox(height: MisureScrl.spazioPiccolo),
          Expanded(
            child: KeyedSubtree(
              key: ValueKey('scheda-$scelta'),
              child: schede[scelta].contenuto,
            ),
          ),
        ],
      ),
    );
  }

  /// Tante schede: la griglia delle tessere o il dettaglio di una, con la stessa altezza.
  Widget _griglia(Testi t, List<SchedaStrumento> schede, int scelta) {
    final righe = (schede.length / _colonne).ceil();
    final altezzaGriglia =
        righe * _altezzaTessera + (righe - 1) * MisureScrl.spazioPiccolo;
    final altaDettaglio = schede
        .map((s) => s.altezza)
        .reduce((a, b) => a > b ? a : b);
    final altezza = [
      altezzaGriglia,
      MisureScrl.tocco + altaDettaglio,
    ].reduce((a, b) => a > b ? a : b);
    final Widget livello;
    if (_dettaglio) {
      final s = schede[scelta];
      livello = RitornoLocale(
        key: const ValueKey('dettaglio'),
        onIndietro: _allaGriglia,
        child: Column(
          children: [
            SizedBox(
              height: MisureScrl.tocco,
              child: Row(
                children: [
                  PulsanteIcona(
                    key: const ValueKey('scheda-indietro'),
                    icona: Icons.arrow_back_rounded,
                    etichetta: t.tutteLeOpzioni,
                    onTap: _allaGriglia,
                  ),
                  Expanded(
                    child:
                        s.intestazione ??
                        Text(
                          s.etichetta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: TestoScrl.normale,
                            fontWeight: TestoScrl.marcato,
                            color: ColoriScrl.testo,
                          ),
                        ),
                  ),
                  if (s.intestazione == null && s.valore != null)
                    Padding(
                      padding: const EdgeInsets.only(right: MisureScrl.spazio),
                      child: Text(
                        s.valore!,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: TestoScrl.normale,
                          color: s.modificata
                              ? ColoriScrl.accentoTesto
                              : ColoriScrl.testoSecondario,
                        ),
                      ),
                    )
                  else if (s.intestazione != null)
                    const SizedBox(width: MisureScrl.spazio),
                ],
              ),
            ),
            Expanded(
              child: KeyedSubtree(
                key: ValueKey('scheda-$scelta'),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(height: s.altezza, child: s.contenuto),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      livello = Padding(
        key: const ValueKey('griglia'),
        padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
        child: Column(
          children: [
            for (var r = 0; r < righe; r++) ...[
              if (r > 0) const SizedBox(height: MisureScrl.spazioPiccolo),
              Expanded(
                child: Row(
                  children: [
                    for (var c = 0; c < _colonne; c++) ...[
                      if (c > 0)
                        const SizedBox(width: MisureScrl.spazioPiccolo),
                      Expanded(
                        child: r * _colonne + c < schede.length
                            ? _TesseraScheda(
                                scheda: schede[r * _colonne + c],
                                onTap: () => _scegli(r * _colonne + c),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }
    return SizedBox(height: altezza, child: livello);
  }

  static const int _colonne = 4;
  static const double _altezzaTessera = 56;
}

/// Tessera di una scheda nella griglia: il nome e, sotto, il valore (colorato se cambiato).
class _TesseraScheda extends StatelessWidget {
  const _TesseraScheda({required this.scheda, required this.onTap});

  final SchedaStrumento scheda;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final valore = scheda.valore;
    return Semantics(
      button: true,
      label: valore == null ? scheda.etichetta : '${scheda.etichetta}, $valore',
      excludeSemantics: true,
      child: Material(
        color: ColoriScrl.rilievo,
        borderRadius: BorderRadius.circular(MisureScrl.angoloTessera),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: scheda.chiave,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    scheda.etichetta,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: TestoScrl.piccolo,
                      color: ColoriScrl.testo,
                    ),
                  ),
                ),
                if (valore != null) ...[
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      valore,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: TestoScrl.normale,
                        fontWeight: TestoScrl.marcato,
                        color: scheda.modificata
                            ? ColoriScrl.accentoTesto
                            : ColoriScrl.testo,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Riga fissa delle azioni di uno strumento: voci di uguale larghezza (icona in una pillola, nome sotto); gli
/// interruttori accesi hanno la pillola piena. Oltre le sei voci la riga scorre.
class RigaAzioni extends StatelessWidget {
  const RigaAzioni({super.key, required this.azioni});

  final List<AzioneStrumento> azioni;

  @override
  Widget build(BuildContext context) {
    final voci = [for (final a in azioni) VoceAzione(azione: a)];
    return SizedBox(
      height: MisureScrl.barraInferiore,
      child: azioni.length <= 6
          ? Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MisureScrl.spazioPiccolo,
              ),
              child: Row(children: [for (final v in voci) Expanded(child: v)]),
            )
          : ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: MisureScrl.spazioPiccolo,
              ),
              children: [for (final v in voci) SizedBox(width: 76, child: v)],
            ),
    );
  }
}

/// Voce di [RigaAzioni].
class VoceAzione extends StatelessWidget {
  const VoceAzione({super.key, required this.azione});

  final AzioneStrumento azione;

  @override
  Widget build(BuildContext context) {
    final a = azione;
    final colore = a.spenta
        ? ColoriScrl.testoSpento
        : a.attiva
        ? ColoriScrl.suAccento
        : ColoriScrl.testo;
    return Semantics(
      button: true,
      toggled: a.attiva ? true : null,
      label: a.etichetta,
      excludeSemantics: true,
      child: InkWell(
        key: a.chiave,
        borderRadius: BorderRadius.circular(MisureScrl.angoloTessera),
        onTap: a.onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: MotoScrl.durata(context, MotoScrl.breve),
              width: 44,
              height: 28,
              decoration: BoxDecoration(
                color: a.attiva ? ColoriScrl.accentoPieno : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(a.icona, size: 22, color: colore),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  a.etichetta,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: TestoScrl.piccolo,
                    color: a.spenta
                        ? ColoriScrl.testoSpento
                        : a.attiva
                        ? ColoriScrl.accentoTesto
                        : ColoriScrl.testo,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Azioni di rotazione comuni a foto, testi e forme: 90° a sinistra e a destra, «Dritta».
List<AzioneStrumento> azioniRotazione(
  Testi t, {
  required VoidCallback sinistra,
  required VoidCallback destra,
  required VoidCallback dritta,
}) => [
  AzioneStrumento(
    icona: Icons.rotate_90_degrees_ccw_rounded,
    etichetta: t.azSinistra90,
    onTap: sinistra,
  ),
  AzioneStrumento(
    icona: Icons.rotate_90_degrees_cw_rounded,
    etichetta: t.azDestra90,
    onTap: destra,
  ),
  AzioneStrumento(
    icona: Icons.straighten_rounded,
    etichetta: t.azDritta,
    onTap: dritta,
  ),
];

/// Nome di un menu da cui si aprono altri strumenti (per il percorso «Stile › Sfondo» nel piede).
String nomeMenu(Testi t, Strumento s) => switch (s) {
  Strumento.stile => t.barraStile,
  Strumento.aggiungi => t.barraAggiungi,
  _ => '',
};

/// Riga di tessere della stessa larghezza, che stanno tutte nello schermo (niente scorrimento).
class RigaTessere extends StatelessWidget {
  const RigaTessere({super.key, required this.children, this.altezza = 72});

  final List<Widget> children;
  final double altezza;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
    child: Center(
      child: SizedBox(
        height: altezza,
        child: Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: MisureScrl.spazioPiccolo),
              Expanded(child: children[i]),
            ],
          ],
        ),
      ),
    ),
  );
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

/// Un parametro con cursore: il valore attuale e cosa fare quando cambia. Le schede e il cursore di
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

/// Il righello di un parametro, col margine di sempre ai lati.
Widget righelloParametro(ParametroCursore par, {Key? key}) => Padding(
  key: key,
  padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
  child: Center(
    child: par.valore == null
        ? const SizedBox.shrink()
        : CursoreGrande(
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
);

/// La scheda di un parametro con cursore.
SchedaStrumento schedaCursore(ParametroCursore par, {String? prefissoChiave}) =>
    SchedaStrumento(
      etichetta: par.nome,
      valore: par.valore == null ? null : '${par.valore}${par.unita.trim()}',
      modificata: par.valore != null && par.valore != par.iniziale,
      contenuto: righelloParametro(
        par,
        key: ValueKey('${prefissoChiave ?? ''}/${par.nome}'),
      ),
    );

/// Strumento fatto di cursori: uno solo (si vede subito) o più (schede); le azioni stanno sotto.
class PannelloCursori extends StatelessWidget {
  const PannelloCursori({
    super.key,
    required this.nome,
    required this.parametri,
    this.azioni = const [],
    this.schedePrima = const [],
    this.schedeDopo = const [],
    this.confronto,
    this.attivoIniziale = 0,
  });

  final String nome;
  final List<ParametroCursore> parametri;
  final List<AzioneStrumento> azioni;

  /// Schede che stanno prima dei cursori (per esempio il colore di uno strumento con cursore e colore).
  final List<SchedaStrumento> schedePrima;

  /// Schede dopo i cursori (il colore del contorno, dopo lo spessore).
  final List<SchedaStrumento> schedeDopo;
  final Widget? confronto;
  final int attivoIniziale;

  @override
  Widget build(BuildContext context) {
    final schede = [
      ...schedePrima,
      for (final p in parametri) schedaCursore(p, prefissoChiave: nome),
      ...schedeDopo,
    ];
    return Intelaiatura(
      nome: nome,
      confronto: confronto,
      schedaIniziale: attivoIniziale,
      azioni: azioni,
      schede: schede,
    );
  }
}
