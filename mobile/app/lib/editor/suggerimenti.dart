/// Primo avvio (piano §4.7): al massimo **tre suggerimenti contestuali**, ognuno mostrato una volta sola:
/// tocca una foto, tieni premuto, scorri per cambiare pagina. Compaiono solo al momento giusto (e dopo una breve
/// pausa, se l'utente non sta già facendo quella cosa), non bloccano mai la tela e si chiudono da soli.
///
/// Quali ha già visto l'utente si ricorda nelle preferenze (`hints_visti`); «Rivedi i suggerimenti» in Impostazioni
/// le azzera.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../export/preferenze.dart';
import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'stato.dart';

/// I tre suggerimenti, nell'ordine in cui possono comparire.
enum Suggerimento {
  tocca(Icons.touch_app_outlined),
  premuto(Icons.pan_tool_alt_outlined),
  scorri(Icons.swipe_rounded);

  const Suggerimento(this.icona);
  final IconData icona;
}

/// Chiave delle preferenze con i suggerimenti già mostrati.
const String chiaveSuggerimentiVisti = 'hints_visti';

/// Attesa prima di mostrare un suggerimento, e quanto resta sullo schermo.
const Duration attesaSuggerimento = Duration(milliseconds: 1500);
const Duration durataSuggerimento = Duration(seconds: 7);

/// Cosa si vede nell'editor in questo momento, quanto basta a scegliere il suggerimento.
class ContestoSuggerimenti {
  const ContestoSuggerimenti({
    required this.haElementi,
    required this.haSelezione,
    required this.strumentoAperto,
    required this.pagine,
  });

  final bool haElementi;
  final bool haSelezione;
  final bool strumentoAperto;
  final int pagine;

  @override
  bool operator ==(Object other) =>
      other is ContestoSuggerimenti &&
      other.haElementi == haElementi &&
      other.haSelezione == haSelezione &&
      other.strumentoAperto == strumentoAperto &&
      other.pagine == pagine;

  @override
  int get hashCode =>
      Object.hash(haElementi, haSelezione, strumentoAperto, pagine);
}

/// Il suggerimento giusto adesso, o null. Mai quelli già [visti]; mai con uno strumento aperto.
///
/// - «Tocca una foto»: c'è qualcosa sulla tela e niente è selezionato.
/// - «Tieni premuto»: qualcosa è selezionato (le azioni del menu sono lì).
/// - «Scorri»: il carosello ha più pagine e niente è selezionato.
Suggerimento? suggerimentoGiusto(
  Set<Suggerimento> visti,
  ContestoSuggerimenti c,
) {
  if (c.strumentoAperto) return null;
  if (c.haSelezione) {
    return visti.contains(Suggerimento.premuto) ? null : Suggerimento.premuto;
  }
  if (c.haElementi && !visti.contains(Suggerimento.tocca)) {
    return Suggerimento.tocca;
  }
  if (c.pagine > 1 && !visti.contains(Suggerimento.scorri)) {
    return Suggerimento.scorri;
  }
  return null;
}

/// Testo di un suggerimento (nei file `.arb`).
String testoSuggerimento(Testi t, Suggerimento s) => switch (s) {
  Suggerimento.tocca => t.suggerimentoTocca,
  Suggerimento.premuto => t.suggerimentoPremuto,
  Suggerimento.scorri => t.suggerimentoScorri,
};

/// Suggerimenti già mostrati, letti dalle preferenze.
Future<Set<Suggerimento>> suggerimentiVisti(PreferenzeApp p) async {
  final nomi = await p.leggiTesti(chiaveSuggerimentiVisti);
  return {
    for (final s in Suggerimento.values)
      if (nomi.contains(s.name)) s,
  };
}

/// Rimette tutti i suggerimenti da vedere («Rivedi i suggerimenti» in Impostazioni).
Future<void> azzeraSuggerimenti(PreferenzeApp p) =>
    p.scrivi(chiaveSuggerimentiVisti, null);

/// Il suggerimento sulla tela. Sta nello stack dell'editor, in basso, sopra la tela ma sotto le dita: non
/// intercetta i tocchi se non sul suo stesso riquadro.
class SuggerimentiEditor extends ConsumerStatefulWidget {
  const SuggerimentiEditor({super.key});

  @override
  ConsumerState<SuggerimentiEditor> createState() => _SuggerimentiEditorState();
}

class _SuggerimentiEditorState extends ConsumerState<SuggerimentiEditor> {
  final Set<Suggerimento> _visti = {};
  bool _caricati = false;
  Suggerimento? _mostrato;
  Suggerimento? _inAttesa;
  Timer? _timerAttesa;
  Timer? _timerChiusura;

  PreferenzeApp get _preferenze => ref.read(preferenzeProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_carica());
  }

  Future<void> _carica() async {
    final v = await suggerimentiVisti(_preferenze);
    if (!mounted) return;
    _visti.addAll(v);
    _caricati = true;
    _valuta();
  }

  @override
  void dispose() {
    _timerAttesa?.cancel();
    _timerChiusura?.cancel();
    super.dispose();
  }

  ContestoSuggerimenti _contesto() {
    final s = ref.read(editorProvider);
    return ContestoSuggerimenti(
      haElementi: s.snapshot.allElements.isNotEmpty,
      haSelezione: s.selezione.isNotEmpty || s.selezionePiu,
      strumentoAperto: s.strumento != Strumento.nessuno,
      pagine: s.snapshot.canvas.numFrames,
    );
  }

  /// Rivede cosa mostrare: parte l'attesa del suggerimento giusto, oppure quello in vista si toglie se non è più
  /// il momento (per esempio perché l'utente ha già toccato una foto: l'ha imparato da solo).
  void _valuta() {
    if (!_caricati) return;
    final c = _contesto();
    final m = _mostrato;
    if (m != null) {
      // Quello in vista è già segnato come visto: si chiede se sarebbe ancora il momento giusto
      if (suggerimentoGiusto({..._visti}..remove(m), c) != m) _nascondi();
      return;
    }
    final giusto = suggerimentoGiusto(_visti, c);
    // Chi seleziona da solo ha già imparato «tocca»; chi cambia pagina da solo, «scorri»
    if (c.haSelezione && !_visti.contains(Suggerimento.tocca)) {
      _ricorda(Suggerimento.tocca);
    }
    if (giusto == _inAttesa) return;
    _timerAttesa?.cancel();
    _inAttesa = giusto;
    if (giusto == null) return;
    _timerAttesa = Timer(attesaSuggerimento, () {
      if (!mounted) return;
      // Ricontrollo: in questo secondo e mezzo il contesto può essere cambiato
      if (suggerimentoGiusto(_visti, _contesto()) != giusto) {
        _inAttesa = null;
        _valuta();
        return;
      }
      _mostra(giusto);
    });
  }

  void _ricorda(Suggerimento s) {
    if (!_visti.add(s)) return;
    unawaited(
      _preferenze.scrivi(chiaveSuggerimentiVisti, [
        for (final v in Suggerimento.values)
          if (_visti.contains(v)) v.name,
      ]),
    );
  }

  void _mostra(Suggerimento s) {
    // Una volta sola: lo si segna come visto subito, anche se l'app viene chiusa mentre è sullo schermo
    _ricorda(s);
    _inAttesa = null;
    setState(() => _mostrato = s);
    _timerChiusura?.cancel();
    _timerChiusura = Timer(durataSuggerimento, _nascondi);
  }

  void _nascondi() {
    _timerChiusura?.cancel();
    if (_mostrato == null) return;
    setState(() => _mostrato = null);
    // Può essere il momento di un altro suggerimento (uno alla volta)
    _inAttesa = null;
    _valuta();
  }

  @override
  Widget build(BuildContext context) {
    // Il contesto cambia con la selezione, gli strumenti, le pagine e gli elementi
    ref.listen(
      editorProvider.select(
        (s) => ContestoSuggerimenti(
          haElementi: s.snapshot.allElements.isNotEmpty,
          haSelezione: s.selezione.isNotEmpty || s.selezionePiu,
          strumentoAperto: s.strumento != Strumento.nessuno,
          pagine: s.snapshot.canvas.numFrames,
        ),
      ),
      (_, _) => _valuta(),
    );
    // Cambiare pagina da soli = aver imparato a scorrere
    ref.listen(editorProvider.select((s) => s.pagina), (prima, adesso) {
      if (prima != adesso && _caricati) _ricorda(Suggerimento.scorri);
    });
    final m = _mostrato;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          MisureScrl.spazio,
          0,
          MisureScrl.spazio,
          MisureScrl.spazioPiccolo,
        ),
        child: AnimatedSwitcher(
          duration: MotoScrl.durata(context, MotoScrl.breve),
          child: m == null
              ? const SizedBox.shrink(key: ValueKey('nessun-suggerimento'))
              : _Fumetto(
                  key: ValueKey('suggerimento-${m.name}'),
                  suggerimento: m,
                  onChiudi: _nascondi,
                ),
        ),
      ),
    );
  }
}

class _Fumetto extends StatelessWidget {
  const _Fumetto({
    super.key,
    required this.suggerimento,
    required this.onChiudi,
  });

  final Suggerimento suggerimento;
  final VoidCallback onChiudi;

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final testo = testoSuggerimento(t, suggerimento);
    return Semantics(
      // Il lettore di schermo lo annuncia da solo quando compare
      liveRegion: true,
      button: true,
      label: '$testo. ${t.suggerimentoChiudi}',
      excludeSemantics: true,
      onTap: onChiudi,
      child: GestureDetector(
        onTap: onChiudi,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: MisureScrl.tocco,
            maxWidth: 420,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: ColoriScrl.rilievo,
              borderRadius: BorderRadius.circular(MisureScrl.angoloTessera),
              border: Border.all(color: ColoriScrl.bordo),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MisureScrl.spazio,
                vertical: MisureScrl.spazioPiccolo,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(suggerimento.icona, size: 24, color: ColoriScrl.testo),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      testo,
                      style: const TextStyle(
                        fontSize: TestoScrl.normale,
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
}
