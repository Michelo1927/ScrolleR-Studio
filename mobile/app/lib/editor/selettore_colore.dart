/// Selettore colore (piano §4.6): i 12 campioni rapidi di `SWATCHES`, i colori già usati nel progetto, il
/// contagocce sulla pagina, il selettore completo (tinta, saturazione, luminosità, esadecimale) e la trasparenza
/// dove serve (etichetta del testo). Per le forme il primo campione è «Nessuno».
///
/// È un pannello intero (telaio di [Intelaiatura]): chi lo usa gli dà il colore attuale e riceve ogni nuovo colore
/// come ARGB; la bozza e il ✓ sono quelli dello strumento che lo contiene.
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'intelaiatura.dart';
import 'stato.dart';
import 'widget_comuni.dart';

/// Parametri del selettore completo.
enum _Parametro { tinta, saturazione, luminosita, esadecimale, trasparenza }

class PannelloColore extends ConsumerStatefulWidget {
  const PannelloColore({
    super.key,
    required this.nome,
    required this.colore,
    required this.onColore,
    this.conNessuno = false,
    this.conAlfa = false,
    this.chipsPrima = const [],
    this.chipsDopo = const [],
  });

  final String nome;

  /// Il colore attuale, ARGB (con la sua trasparenza).
  final int colore;

  /// Un colore nuovo (ARGB). Si chiama a ogni cambio, anche mentre si trascina un cursore: è una bozza.
  final ValueChanged<int> onColore;

  /// Il primo campione è «Nessuno» (trasparente): per il riempimento delle forme.
  final bool conNessuno;

  /// C'è il cursore «Trasparenza» (etichetta del testo).
  final bool conAlfa;

  /// Pillole prima e dopo quelle del selettore (le schede dello strumento che lo contiene).
  final List<Widget> chipsPrima;
  final List<Widget> chipsDopo;

  @override
  ConsumerState<PannelloColore> createState() => _PannelloColoreState();
}

class _PannelloColoreState extends ConsumerState<PannelloColore> {
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
        ? _costruisciCompleto(context)
        : _costruisciRapido(context);
  }

  // ---------- Campioni, colori del progetto, contagocce ----------
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
    return Intelaiatura(
      nome: widget.nome,
      chips: [
        ...widget.chipsPrima,
        ChipParametro(
          etichetta: t.azContagocce,
          attivo: contagocce,
          onTap: () => _ctrl.attivaContagocce(!contagocce),
        ),
        ChipParametro(
          etichetta: t.azAltroColore,
          attivo: false,
          onTap: () {
            _ctrl.attivaContagocce(false);
            setState(() {
              _completo = true;
              _parametro = _Parametro.tinta;
            });
          },
        ),
        if (widget.conAlfa)
          ChipParametro(
            etichetta: t.parOpacita,
            valore: '${percentualeAlfa(c)}',
            attivo: false,
            onTap: () {
              _ctrl.attivaContagocce(false);
              setState(() {
                _completo = true;
                _parametro = _Parametro.trasparenza;
              });
            },
          ),
        ...widget.chipsDopo,
      ],
      contenuto: contagocce
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MisureScrl.spazio,
                ),
                child: Text(
                  t.contagocceAiuto,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          : ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: MisureScrl.spazio,
              ),
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
    );
  }

  // ---------- Selettore completo ----------
  Widget _costruisciCompleto(BuildContext context) {
    final t = Testi.of(context);
    final c = widget.colore;
    final hex = formatEsadecimale(c);
    ChipParametro pillola(_Parametro p, String nome, [String? valore]) =>
        ChipParametro(
          etichetta: nome,
          valore: valore,
          attivo: _parametro == p,
          onTap: () => setState(() => _parametro = p),
        );
    final Widget contenuto = switch (_parametro) {
      _Parametro.esadecimale => _CampoEsadecimale(
        valore: hex,
        onValido: (rgb) => _emetti(_conAlfaAttuale(rgb)),
      ),
      _ => Padding(
        padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
        child: Center(child: _cursore(t)),
      ),
    };
    return Intelaiatura(
      nome: widget.nome,
      chips: [
        ChipParametro(
          etichetta: '‹ ${t.azColori}',
          attivo: false,
          onTap: () => setState(() => _completo = false),
        ),
        _Anteprima(colore: c, etichetta: t.coloreEtichetta(hex)),
        pillola(_Parametro.tinta, t.parTintaColore, '${_hsl.h.round() % 360}'),
        pillola(
          _Parametro.saturazione,
          t.parSaturazione,
          '${(_hsl.s * 100).round()}',
        ),
        pillola(
          _Parametro.luminosita,
          t.parLuminosita,
          '${(_hsl.l * 100).round()}',
        ),
        pillola(_Parametro.esadecimale, t.parEsadecimale),
        if (widget.conAlfa)
          pillola(
            _Parametro.trasparenza,
            t.parOpacita,
            '${percentualeAlfa(c)}',
          ),
      ],
      contenuto: contenuto,
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
      _Parametro.tinta => (
        t.parTintaColore,
        _hsl.h.round() % 360,
        0,
        359,
        0,
        '°',
        (int v) => _perHsl(Hsl(v.toDouble(), _hsl.s, _hsl.l)),
      ),
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
        t.parOpacita,
        percentualeAlfa(widget.colore),
        0,
        100,
        100,
        '%',
        (int v) => _emetti(conPercentualeAlfa(widget.colore, v)),
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

/// Filo sottile tra i campioni rapidi e i colori del progetto.
class _Separatore extends StatelessWidget {
  const _Separatore();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: MisureScrl.spazioPiccolo),
    child: VerticalDivider(width: 1, thickness: 1, color: ColoriScrl.bordo),
  );
}

/// Il colore attuale, piccolo e tondo, accanto alle pillole del selettore completo.
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
    return Center(
      child: SizedBox(
        width: 220,
        child: TextField(
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
            prefixText: '#',
            counterText: '',
            hintText: 'RRGGBB',
            labelText: t.parEsadecimale,
            errorText: _errore ? t.esadecimaleNonValido : null,
          ),
          onChanged: _alCambio,
        ),
      ),
    );
  }
}
