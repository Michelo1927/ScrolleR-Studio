/// Pannelli dello strumento Testo (piano §4.3 e §6 «Testo»): Modifica, Carattere, Dimensione, Formato, Colore,
/// Contorno, Etichetta, Spaziatura, Opacità, Ruota. (L'ombra è un comando singolo della barra.)
///
/// Hanno tutti l'anatomia degli strumenti Foto: ogni cambio si vede subito sulla pagina come **bozza**, `✕` scarta,
/// `✓` la trasforma in un solo passo di cronologia. I numeri e le regole stanno in `scrl_engine` (`testo.dart`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import '../l10n/app_localizations.dart';
import '../render/caratteri.dart';
import '../theme/tokens.dart';
import 'intelaiatura.dart';
import 'selettore_colore.dart';
import 'stato.dart';
import 'widget_comuni.dart';

/// Il testo principale tra quelli selezionati (i cursori ne mostrano i valori; i cambi valgono per tutti).
final _testoPrincipale = Provider.autoDispose<TextItem?>((ref) {
  final sel = ref.watch(editorProvider.select((s) => s.elementiSelezionati));
  for (final e in sel) {
    if (e is TextItem) return e;
  }
  return null;
}, dependencies: [editorProvider]);

/// Lavora sui testi selezionati con [f]; il motore ricentra il testo se cambia la sua misura.
void Function(TextItem Function(TextItem, EngineContext)) _modifica(
  WidgetRef ref,
) {
  final ctrl = ref.read(editorProvider.notifier);
  return (f) => ctrl.modificaTestiSelezionati((t) => f(t, ctrl.contesto));
}

// ---------------------------------------------------------------- Modifica

/// Modifica: la tastiera per scrivere sul testo selezionato, su più righe. Il testo si aggiorna sulla pagina mentre
/// si scrive. Un testo appena creato ha «Scrivi qui» già selezionato, così basta cominciare a scrivere.
class PannelloModificaTesto extends ConsumerStatefulWidget {
  const PannelloModificaTesto({super.key});

  @override
  ConsumerState<PannelloModificaTesto> createState() =>
      _PannelloModificaTestoState();
}

class _PannelloModificaTestoState extends ConsumerState<PannelloModificaTesto> {
  late final TextEditingController _testo;

  @override
  void initState() {
    super.initState();
    final iniziale = ref.read(_testoPrincipale)?.text ?? '';
    _testo = TextEditingController(text: iniziale);
    // Un testo appena creato ha «Scrivi qui» selezionato; uno già scritto riceve il cursore in fondo
    _testo.selection = iniziale == testoNuovo
        ? TextSelection(baseOffset: 0, extentOffset: iniziale.length)
        : TextSelection.collapsed(offset: iniziale.length);
  }

  @override
  void dispose() {
    _testo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final ctrl = ref.read(editorProvider.notifier);
    final modifica = _modifica(ref);
    return PannelloBasso(
      onScarta: ctrl.chiudiStrumentoDaGesto,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MisureScrl.spazio,
              MisureScrl.spazio,
              MisureScrl.spazio,
              MisureScrl.spazioPiccolo,
            ),
            child: TextField(
              controller: _testo,
              autofocus: true,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              minLines: 1,
              maxLines: 4,
              style: const TextStyle(
                fontSize: TestoScrl.grande,
                color: ColoriScrl.testo,
              ),
              decoration: InputDecoration(
                hintText: t.testoSuggerimento,
                labelText: t.strModifica,
              ),
              onChanged: (v) => modifica((x, c) => conScritto(x, v, c)),
            ),
          ),
          PiedeStrumento(
            nome: t.strModifica,
            etichettaAnnulla: t.annulla,
            etichettaConferma: t.conferma,
            onAnnulla: ctrl.chiudiStrumento,
            onConferma: ctrl.confermaEChiudi,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Carattere

String _nomeCategoria(Testi t, CategoriaCarattere c) => switch (c) {
  CategoriaCarattere.senzaGrazie => t.catSenzaGrazie,
  CategoriaCarattere.conGrazie => t.catConGrazie,
  CategoriaCarattere.titolo => t.catTitolo,
  CategoriaCarattere.aMano => t.catAMano,
  CategoriaCarattere.monospazio => t.catMonospazio,
};

/// Carattere: i 20 caratteri inclusi nell'app, in cinque gruppi, ognuno mostrato con la sua «Aa». Se il testo usa un
/// carattere che sul telefono non c'è, una nota lo dice: la pagina lo disegna con quello predefinito ma il nome nel
/// progetto resta com'è finché non se ne sceglie un altro.
class PannelloCarattere extends ConsumerStatefulWidget {
  const PannelloCarattere({super.key});

  @override
  ConsumerState<PannelloCarattere> createState() => _PannelloCarattereState();
}

class _PannelloCarattereState extends ConsumerState<PannelloCarattere> {
  late CategoriaCarattere _categoria = Caratteri.categoriaDi(
    ref.read(_testoPrincipale)?.font ?? Caratteri.predefinito,
  );

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final testo = ref.watch(_testoPrincipale);
    final modifica = _modifica(ref);
    final nome = testo?.font;
    final mancante = nome != null && !Caratteri.incluso(nome);
    final scelto = nome == null ? null : Caratteri.trova(nome)?.famiglia;
    return Intelaiatura(
      nome: t.strCarattere,
      chips: [
        for (final c in CategoriaCarattere.values)
          ChipParametro(
            etichetta: _nomeCategoria(t, c),
            attivo: c == _categoria,
            onTap: () => setState(() => _categoria = c),
          ),
      ],
      contenuto: Column(
        children: [
          if (mancante)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MisureScrl.spazio,
              ),
              child: Text(
                t.avvisoCarattereMancante(nome, Caratteri.predefinito),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: MisureScrl.spazio,
                vertical: 4,
              ),
              children: [
                for (final c in Caratteri.dellaCategoria(_categoria))
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TesseraScelta(
                      disegno: Text(
                        'Aa',
                        style: TextStyle(
                          fontFamily: c.famiglia,
                          fontSize: 26,
                          color: ColoriScrl.testo,
                        ),
                      ),
                      etichetta: c.famiglia,
                      scelta: scelto == c.famiglia,
                      larghezza: 104,
                      altezza: double.infinity,
                      onTap: () => modifica(
                        (x, ctx) => conCarattere(x, c.famiglia, ctx),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Dimensione, Spaziatura, Opacità

/// Dimensione: il carattere da 12 a 400 px.
class PannelloDimensione extends ConsumerWidget {
  const PannelloDimensione({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final testo = ref.watch(_testoPrincipale);
    final modifica = _modifica(ref);
    return PannelloCursori(
      nome: t.strDimensione,
      parametri: [
        ParametroCursore(
          nome: t.strDimensione,
          minimo: LimitiTesto.dimensioneMin,
          massimo: LimitiTesto.dimensioneMax,
          iniziale: 72,
          valore: testo?.size.round(),
          onCambia: (v) => modifica((x, c) => conDimensione(x, v, c)),
          unita: ' px',
        ),
      ],
    );
  }
}

/// Spaziatura: interlinea (60–250%) e spaziatura tra le lettere (−10…60%).
class PannelloSpaziatura extends ConsumerWidget {
  const PannelloSpaziatura({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final testo = ref.watch(_testoPrincipale);
    final modifica = _modifica(ref);
    return PannelloCursori(
      nome: t.strSpaziatura,
      parametri: [
        ParametroCursore(
          nome: t.parInterlinea,
          minimo: LimitiTesto.interlineaMin,
          massimo: LimitiTesto.interlineaMax,
          iniziale: 100,
          valore: testo?.lineHeight,
          onCambia: (v) => modifica((x, c) => conInterlinea(x, v, c)),
          unita: '%',
        ),
        ParametroCursore(
          nome: t.parSpaziaturaLettere,
          minimo: LimitiTesto.spaziaturaMin,
          massimo: LimitiTesto.spaziaturaMax,
          iniziale: 0,
          valore: testo?.letterSpacing,
          onCambia: (v) => modifica((x, c) => conSpaziatura(x, v, c)),
          unita: '%',
        ),
      ],
    );
  }
}

/// Opacità del testo, da 5 a 100%.
class PannelloOpacitaTesto extends ConsumerWidget {
  const PannelloOpacitaTesto({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final testo = ref.watch(_testoPrincipale);
    final modifica = _modifica(ref);
    return PannelloCursori(
      nome: t.parOpacita,
      parametri: [
        ParametroCursore(
          nome: t.parOpacita,
          minimo: LimitiTesto.opacitaMin,
          massimo: LimitiTesto.opacitaMax,
          iniziale: 100,
          valore: testo?.opacity,
          onCambia: (v) => modifica((x, c) => conOpacitaTesto(x, v)),
          unita: '%',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Formato

/// Formato: grassetto, corsivo e allineamento delle righe.
class PannelloFormato extends ConsumerWidget {
  const PannelloFormato({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final testo = ref.watch(_testoPrincipale);
    final modifica = _modifica(ref);
    ChipParametro allineamento(String chiave, String nome) => ChipParametro(
      etichetta: nome,
      attivo: testo?.align == chiave,
      onTap: () => modifica((x, _) => conAllineamento(x, chiave)),
    );
    return Intelaiatura(
      nome: t.strFormato,
      chips: [
        ChipParametro(
          etichetta: t.azGrassetto,
          attivo: testo?.bold ?? false,
          onTap: () => modifica((x, c) => conGrassetto(x, !x.bold, c)),
        ),
        ChipParametro(
          etichetta: t.azCorsivo,
          attivo: testo?.italic ?? false,
          onTap: () => modifica((x, c) => conCorsivo(x, !x.italic, c)),
        ),
        allineamento('left', t.azSinistra),
        allineamento('center', t.azCentro),
        allineamento('right', t.azDestra),
      ],
    );
  }
}

// ---------------------------------------------------------------- Colore, Contorno, Etichetta

/// Colore del testo.
class PannelloColoreTesto extends ConsumerWidget {
  const PannelloColoreTesto({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final testo = ref.watch(_testoPrincipale);
    final modifica = _modifica(ref);
    return PannelloColore(
      nome: t.parColore,
      colore: testo?.color ?? 0xFFFFFFFF,
      onColore: (c) => modifica((x, _) => conColoreTesto(x, c)),
    );
  }
}

/// Contorno: spessore (0–40 px) e colore. Scegliere il colore fa vedere subito il contorno.
class PannelloContornoTesto extends ConsumerStatefulWidget {
  const PannelloContornoTesto({super.key});

  @override
  ConsumerState<PannelloContornoTesto> createState() =>
      _PannelloContornoTestoState();
}

class _PannelloContornoTestoState extends ConsumerState<PannelloContornoTesto> {
  bool _colore = false;

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final testo = ref.watch(_testoPrincipale);
    final modifica = _modifica(ref);
    if (_colore) {
      return PannelloColore(
        nome: t.strContorno,
        colore: testo?.outlineColor ?? 0xFF000000,
        onColore: (c) => modifica((x, ctx) => conColoreContorno(x, c, ctx)),
        chipsPrima: [
          ChipParametro(
            etichetta: t.parSpessore,
            attivo: false,
            onTap: () => setState(() => _colore = false),
          ),
        ],
      );
    }
    return PannelloCursori(
      nome: t.strContorno,
      parametri: [
        ParametroCursore(
          nome: t.parSpessore,
          minimo: LimitiTesto.contornoMin,
          massimo: LimitiTesto.contornoMax,
          iniziale: 0,
          valore: testo?.outline.round(),
          onCambia: (v) => modifica((x, c) => conContorno(x, v, c)),
          unita: ' px',
        ),
      ],
      azioni: [
        ChipParametro(
          etichetta: t.parColore,
          attivo: false,
          onTap: () => setState(() => _colore = true),
        ),
      ],
    );
  }
}

/// Etichetta: il riquadro dietro al testo, acceso o spento, con il suo colore e la sua trasparenza.
class PannelloEtichetta extends ConsumerWidget {
  const PannelloEtichetta({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final testo = ref.watch(_testoPrincipale);
    final modifica = _modifica(ref);
    return PannelloColore(
      nome: t.strEtichetta,
      colore: testo?.boxColor ?? 0x96000000,
      conAlfa: true,
      onColore: (c) => modifica((x, ctx) => conColoreEtichetta(x, c, ctx)),
      chipsPrima: [
        ChipParametro(
          etichetta: t.strEtichetta,
          attivo: testo?.box ?? false,
          onTap: () => modifica((x, c) => conEtichetta(x, !x.box, c)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Ruota

/// Ruota: angolo del testo da −180° a 180°, 90° a sinistra e a destra, «Dritto».
class PannelloRuotaTesto extends ConsumerWidget {
  const PannelloRuotaTesto({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final testo = ref.watch(_testoPrincipale);
    final modifica = _modifica(ref);
    return PannelloCursori(
      nome: t.strRuota,
      parametri: [
        ParametroCursore(
          nome: t.parAngolo,
          minimo: LimitiTesto.rotazioneMin,
          massimo: LimitiTesto.rotazioneMax,
          iniziale: 0,
          valore: testo?.rotation.round(),
          onCambia: (v) => modifica((x, _) => conRotazioneTesto(x, v)),
          unita: '°',
        ),
      ],
      azioni: [
        ChipParametro(
          etichetta: t.azSinistra90,
          attivo: false,
          onTap: () => modifica(
            (x, _) =>
                conRotazioneTesto(x, normalizzaGradi(x.rotation - 90).round()),
          ),
        ),
        ChipParametro(
          etichetta: t.azDestra90,
          attivo: false,
          onTap: () => modifica(
            (x, _) =>
                conRotazioneTesto(x, normalizzaGradi(x.rotation + 90).round()),
          ),
        ),
        ChipParametro(
          etichetta: t.azDritta,
          attivo: false,
          onTap: () => modifica((x, _) => conRotazioneTesto(x, 0)),
        ),
      ],
    );
  }
}
