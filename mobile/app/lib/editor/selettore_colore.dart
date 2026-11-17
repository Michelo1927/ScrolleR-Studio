/// Selettore colore (piano §4.6): i 12 campioni rapidi di `SWATCHES`, i colori già usati nel progetto, il
/// contagocce sulla pagina, il selettore completo (tinta, saturazione, luminosità, esadecimale) e la trasparenza
/// dove serve (etichetta del testo). Per le forme il primo campione è «Nessuno».
///
/// [SelettoreColore] è un contenuto (alto [altezzaContenuto]) da mettere in una scheda di uno strumento:
/// - vista rapida: in testa alla fila il contagocce e «Altro» (il selettore completo), poi i campioni; con la
///   trasparenza, sotto, il suo righello;
/// - selettore completo: ‹ per tornare ai campioni (anche col gesto «indietro»), i segmenti Tinta · Saturazione ·
///   Luminosità · # e, sotto, il righello o il campo esadecimale.
/// Chi lo usa gli dà il colore attuale e riceve ogni nuovo colore come ARGB; la bozza e il ✓ sono quelli dello
/// strumento che lo contiene. [PannelloColore] è lo strumento fatto solo di colore.
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'indietro.dart';
import 'intelaiatura.dart';
import 'stato.dart';
import 'widget_comuni.dart';

/// Parametri del selettore completo.
enum _Parametro { tinta, saturazione, luminosita, esadecimale }

/// Strumento fatto solo di un colore (Colore del testo, Riempimento), con eventuali azioni sotto.
class PannelloColore extends StatelessWidget {
  const PannelloColore({
    super.key,
    required this.nome,
    required this.colore,
    required this.onColore,
    this.conNessuno = false,
    this.conAlfa = false,
    this.azioni = const [],
  });

  final String nome;
  final int colore;
  final ValueChanged<int> onColore;
  final bool conNessuno;
  final bool conAlfa;
  final List<AzioneStrumento> azioni;

  @override
  Widget build(BuildContext context) => Intelaiatura(
    nome: nome,
    azioni: azioni,
    contenuto: SelettoreColore(
      colore: colore,
      onColore: onColore,
      conNessuno: conNessuno,
      conAlfa: conAlfa,
    ),
  );
}

class SelettoreColore extends ConsumerStatefulWidget {
  const SelettoreColore({
    super.key,
    required this.colore,
    required this.onColore,
    this.conNessuno = false,
    this.conAlfa = false,
  });

  /// Il colore attuale, ARGB (con la sua trasparenza).
  final int colore;

  /// Un colore nuovo (ARGB). Si chiama a ogni cambio, anche mentre si trascina un cursore: è una bozza.
  final ValueChanged<int> onColore;

  /// Il primo campione è «Nessuno» (trasparente): per il riempimento delle forme.
  final bool conNessuno;

  /// C'è il righello «Opacità» (etichetta del testo).
  final bool conAlfa;

  @override
  ConsumerState<SelettoreColore> createState() => _SelettoreColoreState();
}

class _SelettoreColoreState extends ConsumerState<SelettoreColore> {
  bool _completo = false;
  _Parametro _parametro = _Parametro.tinta;
  late Hsl _hsl = argbToHsl(widget.colore);
  late final List<int> _delProgetto;

  static final Set<int> _rapidi = {
    for (final c in CampioniScrl.rapidi) c.toARGB32(),
  };

  @override
  void initState() {
    super.initState();
    // I colori del progetto si leggono all'apertura, dall'ultimo stato confermato: così non saltano mentre si sceglie
    _delProgetto = coloriDelProgetto(
      ref.read(editorProvider).cronologia.current,
      escludi: _rapidi,
    );
  }

  ControlloEditor get _ctrl => ref.read(editorProvider.notifier);

  void _emetti(int argb) => widget.onColore(argb);

  /// Un colore scelto a mano tiene la trasparenza attuale; da «Nessuno» (trasparente) riparte pieno.
  int _conAlfaAttuale(int rgb) {
    if (!widget.conAlfa) return 0xFF000000 | (rgb & 0xFFFFFF);
    final a = alfaDi(widget.colore);
    return conAlfa(rgb, a == 0 ? 255 : a);
  }

  /// Dopo un cambio dal di fuori (campione, esadecimale, contagocce) la tinta si rilegge dal colore.
  void _sincronizza() {
    final dalHsl = hslToArgb(_hsl.h, _hsl.s, _hsl.l) & 0xFFFFFF;
    if (dalHsl != (widget.colore & 0xFFFFFF)) _hsl = argbToHsl(widget.colore);
  }

  void _perHsl(Hsl h) {
    setState(() => _hsl = h);
    _emetti(_conAlfaAttuale(hslToArgb(h.h, h.s, h.l)));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(editorProvider.select((s) => s.colorePreso), (prima, dopo) {
      if (dopo == null || dopo == prima) return;
      _emetti(_conAlfaAttuale(dopo.argb));
    });
    _sincronizza();
    return _completo
        ? RitornoLocale(
            onIndietro: () => setState(() => _completo = false),
            child: _costruisciCompleto(context),
          )
        : _costruisciRapido(context);
  }

  // ---------- Contagocce, «Altro», campioni, colori del progetto ----------
  Widget _costruisciRapido(BuildContext context) {
    final t = Testi.of(context);
    final contagocce = ref.watch(editorProvider.select((s) => s.contagocce));
    final c = widget.colore;
    String etichetta(int argb) => t.coloreEtichetta(formatEsadecimale(argb));
    Widget campione(int argb) => CampioneColore(
      colore: Color(argb),
      scelto: c == argb,
      etichetta: etichetta(argb),
      onTap: () => _emetti(argb),
    );
    final fila = Row(
      children: [
        const SizedBox(width: MisureScrl.spazioPiccolo),
        _Comando(
          chiave: const ValueKey('colore-contagocce'),
          icona: Icons.colorize_rounded,
          etichetta: t.azContagocce,
          attivo: contagocce,
          onTap: () => _ctrl.attivaContagocce(!contagocce),
        ),
        _Comando(
          chiave: const ValueKey('colore-altro'),
          icona: Icons.palette_outlined,
          etichetta: t.azAltroColore,
          onTap: () {
            _ctrl.attivaContagocce(false);
            setState(() {
              _completo = true;
              _parametro = _Parametro.tinta;
            });
          },
        ),
        const _Separatore(),
        Expanded(
          child: contagocce
              ? Padding(
                  padding: const EdgeInsets.only(right: MisureScrl.spazio),
                  child: Text(
                    t.contagocceAiuto,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: MisureScrl.spazio),
                  children: [
                    if (widget.conNessuno)
                      CampioneColore(
                        colore: null,
                        scelto: alfaDi(c) == 0,
                        etichetta: t.nessuno,
                        onTap: () => _emetti(0x00000000),
                      ),
                    for (final k in CampioniScrl.rapidi) campione(k.toARGB32()),
                    if (_delProgetto.isNotEmpty) ...[
                      const _Separatore(),
                      for (final k in _delProgetto) campione(k),
                    ],
                  ],
                ),
        ),
      ],
    );
    if (!widget.conAlfa) {
      return Center(
        child: SizedBox(height: MisureScrl.tocco, child: fila),
      );
    }
    return Column(
      children: [
        SizedBox(height: MisureScrl.tocco, child: fila),
        Expanded(
          child: righelloParametro(
            ParametroCursore(
              nome: t.parOpacita,
              minimo: 0,
              massimo: 100,
              iniziale: 100,
              valore: percentualeAlfa(c),
              unita: '%',
              onCambia: (v) => _emetti(conPercentualeAlfa(widget.colore, v)),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Selettore completo ----------
  Widget _costruisciCompleto(BuildContext context) {
    final t = Testi.of(context);
    final c = widget.colore;
    final hex = formatEsadecimale(c);
    return Column(
      children: [
        SizedBox(
          height: MisureScrl.tocco,
          child: Row(
            children: [
              PulsanteIcona(
                key: const ValueKey('colore-indietro'),
                icona: Icons.arrow_back_rounded,
                etichetta: t.azColori,
                onTap: () => setState(() => _completo = false),
              ),
              Expanded(
                child: ControlloSegmentato<_Parametro>(
                  voci: [
                    VoceSegmento(
                      valore: _Parametro.tinta,
                      etichetta: t.parTintaColore,
                    ),
                    VoceSegmento(
                      valore: _Parametro.saturazione,
                      etichetta: t.parSaturazione,
                    ),
                    VoceSegmento(
                      valore: _Parametro.luminosita,
                      etichetta: t.parLuminosita,
                    ),
                    const VoceSegmento(
                      valore: _Parametro.esadecimale,
                      etichetta: '#',
                      chiave: ValueKey('colore-esadecimale'),
                    ),
                  ],
                  scelto: _parametro,
                  onScelto: (p) => setState(() => _parametro = p),
                ),
              ),
              const SizedBox(width: MisureScrl.spazioPiccolo),
              _Anteprima(colore: c, etichetta: t.coloreEtichetta(hex)),
              const SizedBox(width: MisureScrl.spazio),
            ],
          ),
        ),
        Expanded(
          child: _parametro == _Parametro.esadecimale
              ? _CampoEsadecimale(
                  valore: hex,
                  onValido: (rgb) => _emetti(_conAlfaAttuale(rgb)),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MisureScrl.spazio,
                  ),
                  child: Center(child: _cursore(t)),
                ),
        ),
      ],
    );
  }

  Widget _cursore(Testi t) {
    final (
      nome,
      valore,
      minimo,
      massimo,
      iniziale,
      unita,
      onCambia,
    ) = switch (_parametro) {
      _Parametro.saturazione => (
        t.parSaturazione,
        (_hsl.s * 100).round(),
        0,
        100,
        100,
        '%',
        (int v) => _perHsl(Hsl(_hsl.h, v / 100.0, _hsl.l)),
      ),
      _Parametro.luminosita => (
        t.parLuminosita,
        (_hsl.l * 100).round(),
        0,
        100,
        50,
        '%',
        (int v) => _perHsl(Hsl(_hsl.h, _hsl.s, v / 100.0)),
      ),
      _ => (
        t.parTintaColore,
        _hsl.h.round() % 360,
        0,
        359,
        0,
        '°',
        (int v) => _perHsl(Hsl(v.toDouble(), _hsl.s, _hsl.l)),
      ),
    };
    return CursoreGrande(
      key: ValueKey(_parametro),
      etichetta: nome,
      valore: valore.toDouble(),
      minimo: minimo.toDouble(),
      massimo: massimo.toDouble(),
      iniziale: iniziale.toDouble(),
      unita: unita,
      onCambia: onCambia,
      onFine: () {},
    );
  }
}

/// Comando tondo in testa alla fila dei campioni (contagocce, «Altro»): stessa misura di un campione, con l'icona.
class _Comando extends StatelessWidget {
  const _Comando({
    required this.icona,
    required this.etichetta,
    required this.onTap,
    this.attivo = false,
    this.chiave,
  });

  final IconData icona;
  final String etichetta;
  final VoidCallback onTap;
  final bool attivo;
  final Key? chiave;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    toggled: attivo ? true : null,
    label: etichetta,
    excludeSemantics: true,
    child: GestureDetector(
      key: chiave,
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
              color: attivo ? ColoriScrl.accentoPieno : ColoriScrl.rilievo,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icona,
              size: 20,
              color: attivo ? ColoriScrl.suAccento : ColoriScrl.testo,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Filo sottile tra i comandi, i campioni rapidi e i colori del progetto.
class _Separatore extends StatelessWidget {
  const _Separatore();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(
      horizontal: MisureScrl.spazioPiccolo,
      vertical: 10,
    ),
    child: VerticalDivider(width: 1, thickness: 1, color: ColoriScrl.bordo),
  );
}

/// Il colore attuale, piccolo e tondo, accanto ai segmenti del selettore completo.
class _Anteprima extends StatelessWidget {
  const _Anteprima({required this.colore, required this.etichetta});

  final int colore;
  final String etichetta;

  @override
  Widget build(BuildContext context) => Semantics(
    label: etichetta,
    excludeSemantics: true,
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color(colore),
        border: Border.all(color: ColoriScrl.bordo),
      ),
    ),
  );
}

/// Campo dell'esadecimale `RRGGBB`: si applica appena il testo è valido, con o senza `#`.
class _CampoEsadecimale extends StatefulWidget {
  const _CampoEsadecimale({required this.valore, required this.onValido});

  /// Il colore attuale, `RRGGBB`.
  final String valore;
  final ValueChanged<int> onValido;

  @override
  State<_CampoEsadecimale> createState() => _CampoEsadecimaleState();
}

class _CampoEsadecimaleState extends State<_CampoEsadecimale> {
  late final TextEditingController _testo = TextEditingController(
    text: widget.valore,
  );
  final FocusNode _fuoco = FocusNode();
  bool _errore = false;

  @override
  void didUpdateWidget(_CampoEsadecimale vecchio) {
    super.didUpdateWidget(vecchio);
    // Mentre si scrive il testo è dell'utente; dopo un cambio dal di fuori (cursori, campioni) si aggiorna
    if (!_fuoco.hasFocus && _testo.text != widget.valore) {
      _testo.text = widget.valore;
      _errore = false;
    }
  }

  @override
  void dispose() {
    _testo.dispose();
    _fuoco.dispose();
    super.dispose();
  }

  void _alCambio(String v) {
    final rgb = parseEsadecimale(v);
    setState(() => _errore = rgb == null && v.trim().isNotEmpty);
    if (rgb != null) widget.onValido(rgb);
  }

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    // Il campo e, accanto, l'avviso se il testo non è valido: sotto non c'è spazio (il pannello resta basso)
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 160,
            child: TextField(
              key: const ValueKey('colore-campo-esadecimale'),
              controller: _testo,
              focusNode: _fuoco,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              maxLength: 7,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F#]')),
              ],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: TestoScrl.grande,
                fontWeight: TestoScrl.marcato,
                color: ColoriScrl.testo,
              ),
              decoration: InputDecoration(
                isDense: true,
                prefixText: '#',
                counterText: '',
                hintText: 'RRGGBB',
                // Bordo rosso; il testo dell'avviso sta accanto
                error: _errore ? const SizedBox.shrink() : null,
              ),
              onChanged: _alCambio,
            ),
          ),
          if (_errore) ...[
            const SizedBox(width: MisureScrl.spazioPiccolo),
            Flexible(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  t.esadecimaleNonValido,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: TestoScrl.piccolo,
                    color: ColoriScrl.pericoloTesto,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
