/// Pannelli dello strumento Forme (piano §4.3 e §6 «Forme»): la scelta della forma nuova dal «＋», Tipo,
/// Riempimento, Bordo, Angoli, Opacità, Ruota. Hanno l'anatomia degli strumenti Foto: ogni cambio si vede subito
/// come **bozza**, `✕` scarta, `✓` la trasforma in un solo passo di cronologia. I numeri e le regole stanno in
/// `scrl_engine` (`forme.dart`); la geometria dei contorni in `render/forme.dart`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'icone_forme.dart';
import 'intelaiatura.dart';
import 'selettore_colore.dart';
import 'stato.dart';
import 'widget_comuni.dart';

/// La forma principale tra quelle selezionate (i cursori ne mostrano i valori; i cambi valgono per tutte).
final _formaPrincipale = Provider.autoDispose<ShapeItem?>((ref) {
  final sel = ref.watch(editorProvider.select((s) => s.elementiSelezionati));
  for (final e in sel) {
    if (e is ShapeItem) return e;
  }
  return null;
}, dependencies: [editorProvider]);

/// Nome del tipo di forma, dai file `.arb`.
String nomeForma(Testi t, String tipo) => switch (tipo) {
  'ellipse' => t.formaEllisse,
  'triangle' => t.formaTriangolo,
  'diamond' => t.formaRombo,
  'star' => t.formaStella,
  'heart' => t.formaCuore,
  'line' => t.formaLinea,
  'arrow' => t.formaFreccia,
  'double_arrow' => t.formaDoppiaFreccia,
  _ => t.formaRettangolo,
};

/// Lavora sulle forme selezionate con [f] (che conosce la pagina, per gli spessori visibili).
void Function(ShapeItem Function(ShapeItem, CanvasState)) _modifica(
  WidgetRef ref,
) {
  final ctrl = ref.read(editorProvider.notifier);
  return (f) => ctrl.modificaFormeSelezionate(
    (x) => f(x, ref.read(editorProvider).snapshot.canvas),
  );
}

/// Le 9 tessere dei tipi di forma: forme piene, poi linee.
List<Widget> _tessereTipi(
  Testi t,
  String? scelto,
  ValueChanged<String> onScelta,
) => [
  for (final tipo in tipiForma)
    Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TesseraScelta(
        disegno: IconaForma(tipo: tipo),
        etichetta: nomeForma(t, tipo),
        scelta: scelto == tipo,
        larghezza: 92,
        altezza: 88,
        onTap: () => onScelta(tipo),
      ),
    ),
];

// ---------------------------------------------------------------- Forma nuova

/// «＋ → Forma»: le 9 forme come tessere; un tocco aggiunge la forma al centro della pagina con l'ultimo stile
/// usato e chiude il pannello.
class PannelloNuovaForma extends ConsumerWidget {
  const PannelloNuovaForma({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final ctrl = ref.read(editorProvider.notifier);
    return PannelloBasso(
      onScarta: ctrl.chiudiStrumento,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: MisureScrl.spazio),
          SizedBox(
            height: 88,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: MisureScrl.spazio,
              ),
              children: _tessereTipi(t, null, ctrl.nuovaForma),
            ),
          ),
          PiedeStrumento(
            nome: t.forma,
            percorso: t.barraAggiungi,
            etichettaAnnulla: t.indietro,
            etichettaConferma: t.conferma,
            iconaAnnulla: Icons.arrow_back_rounded,
            onAnnulla: ctrl.chiudiStrumento,
            onConferma: null,
          ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Tipo

/// Tipo: cambia la forma tenendo stile e posizione. Da forma piena a linea l'altezza si adatta al tipo nuovo.
class PannelloTipoForma extends ConsumerWidget {
  const PannelloTipoForma({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final forma = ref.watch(_formaPrincipale);
    final modifica = _modifica(ref);
    return Intelaiatura(
      nome: t.strTipo,
      contenuto: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
        children: _tessereTipi(
          t,
          forma?.kind,
          (tipo) => modifica((x, c) => conTipoForma(x, tipo, c)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Riempimento

/// Riempimento: il colore della forma piena; il primo campione è «Nessuno» (resta solo il bordo).
class PannelloRiempimento extends ConsumerWidget {
  const PannelloRiempimento({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final forma = ref.watch(_formaPrincipale);
    final modifica = _modifica(ref);
    return PannelloColore(
      nome: t.strRiempimento,
      colore: forma?.fill ?? 0xFFFF3B30,
      conNessuno: true,
      onColore: (c) => modifica((x, canvas) => conRiempimento(x, c, canvas)),
    );
  }
}

// ---------------------------------------------------------------- Bordo

/// Bordo di una forma piena o linea di una linea: spessore (0–80 px), colore e tratto (continuo, tratteggiato,
/// a puntini). Scegliere il colore del bordo lo fa vedere subito.
class PannelloBordo extends ConsumerWidget {
  const PannelloBordo({super.key});

  String _nomeTratto(Testi t, String stile) => switch (stile) {
    'dash' => t.trattoTratteggiato,
    'dot' => t.trattoPuntini,
    _ => t.trattoContinuo,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final forma = ref.watch(_formaPrincipale);
    final modifica = _modifica(ref);
    final linea = forma?.isLine ?? false;
    return PannelloCursori(
      nome: linea ? t.parLinea : t.parBordo,
      parametri: [
        ParametroCursore(
          nome: t.parSpessore,
          minimo: LimitiForma.spessoreMin,
          massimo: LimitiForma.spessoreMax,
          iniziale: 0,
          valore: forma?.strokeWidth.round(),
          onCambia: (v) => modifica((x, _) => conSpessoreForma(x, v)),
          unita: ' px',
        ),
      ],
      schedeDopo: [
        SchedaStrumento(
          etichetta: t.parColore,
          chiave: const ValueKey('bordo-colore'),
          contenuto: SelettoreColore(
            colore: forma?.stroke ?? 0xFFFFFFFF,
            onColore: (c) =>
                modifica((x, canvas) => conColoreTratto(x, c, canvas)),
          ),
        ),
        SchedaStrumento(
          etichetta: t.parTratto,
          chiave: const ValueKey('bordo-tratto'),
          contenuto: RigaTessere(
            altezza: 80,
            children: [
              for (final stile in stiliTratto)
                TesseraScelta(
                  disegno: IconaTratto(stile: stile),
                  etichetta: _nomeTratto(t, stile),
                  scelta: forma?.strokeStyle == stile,
                  larghezza: double.infinity,
                  altezza: 80,
                  onTap: () => modifica((x, _) => conTratto(x, stile)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Angoli, Opacità, Ruota

/// Angoli: gli angoli arrotondati del rettangolo, da 0 a 300 px.
class PannelloAngoliForma extends ConsumerWidget {
  const PannelloAngoliForma({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final forma = ref.watch(_formaPrincipale);
    final modifica = _modifica(ref);
    return PannelloCursori(
      nome: t.parAngoli,
      parametri: [
        ParametroCursore(
          nome: t.parAngoli,
          minimo: LimitiForma.angoliMin,
          massimo: LimitiForma.angoliMax,
          iniziale: 0,
          valore: forma?.radius.round(),
          onCambia: (v) => modifica((x, _) => conAngoliForma(x, v)),
          unita: ' px',
        ),
      ],
    );
  }
}

/// Opacità della forma intera, da 5 a 100%.
class PannelloOpacitaForma extends ConsumerWidget {
  const PannelloOpacitaForma({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final forma = ref.watch(_formaPrincipale);
    final modifica = _modifica(ref);
    return PannelloCursori(
      nome: t.parOpacita,
      parametri: [
        ParametroCursore(
          nome: t.parOpacita,
          minimo: LimitiForma.opacitaMin,
          massimo: LimitiForma.opacitaMax,
          iniziale: 100,
          valore: forma?.opacity,
          onCambia: (v) => modifica((x, _) => conOpacitaForma(x, v)),
          unita: '%',
        ),
      ],
    );
  }
}

/// Ruota: angolo della forma da −180° a 180°, 90° a sinistra e a destra, «Dritta».
class PannelloRuotaForma extends ConsumerWidget {
  const PannelloRuotaForma({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final forma = ref.watch(_formaPrincipale);
    final modifica = _modifica(ref);
    return PannelloCursori(
      nome: t.strRuota,
      parametri: [
        ParametroCursore(
          nome: t.parAngolo,
          minimo: LimitiForma.rotazioneMin,
          massimo: LimitiForma.rotazioneMax,
          iniziale: 0,
          valore: forma?.rotation.round(),
          onCambia: (v) => modifica((x, _) => conRotazioneForma(x, v)),
          unita: '°',
        ),
      ],
      azioni: azioniRotazione(
        t,
        sinistra: () => modifica(
          (x, _) =>
              conRotazioneForma(x, normalizzaGradi(x.rotation - 90).round()),
        ),
        destra: () => modifica(
          (x, _) =>
              conRotazioneForma(x, normalizzaGradi(x.rotation + 90).round()),
        ),
        dritta: () => modifica((x, _) => conRotazioneForma(x, 0)),
      ),
    );
  }
}
