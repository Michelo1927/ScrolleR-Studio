/// Nuovo progetto in due passi (piano §4.1): il formato, mostrato come sagome proporzionate, poi la scelta
/// delle foto dalla galleria (si può saltare: tela vuota). Alla fine torna alla Home con la cartella del
/// progetto creato, che la Home apre nell'editor.
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import '../l10n/app_localizations.dart';
import '../project/crea_progetto.dart';
import '../project/provider.dart';
import '../theme/tokens.dart';
import 'scelta_foto.dart';

/// Nome del formato [i] di `aspectRatios` (8 = Personalizzato).
String nomeFormato(Testi t, int i) => switch (i) {
  0 => t.formato0,
  1 => t.formato1,
  2 => t.formato2,
  3 => t.formato3,
  4 => t.formato4,
  5 => t.formato5,
  6 => t.formato6,
  7 => t.formato7,
  _ => t.formato8,
};

class NuovoProgettoPage extends ConsumerStatefulWidget {
  const NuovoProgettoPage({super.key});

  @override
  ConsumerState<NuovoProgettoPage> createState() => _NuovoProgettoPageState();
}

class _NuovoProgettoPageState extends ConsumerState<NuovoProgettoPage> {
  int _passo = 0;
  int _formato = 0; // Di partenza 3:4, come il desktop
  final _larghezza = TextEditingController(text: '1080');
  final _altezza = TextEditingController(text: '1440');
  Directory? _cartella;
  bool _usata = false;
  bool _creando = false;

  @override
  void dispose() {
    _larghezza.dispose();
    _altezza.dispose();
    // Cartella nata per le copie del selettore di sistema ma mai usata: si toglie
    final c = _cartella;
    if (c != null && !_usata && c.existsSync()) {
      c.deleteSync(recursive: true);
    }
    super.dispose();
  }

  int _misura(TextEditingController c) =>
      (int.tryParse(c.text) ?? 1080).clamp(200, 6000);

  FormatoScelto get _formatoScelto => (
    indice: _formato,
    larghezza: _misura(_larghezza),
    altezza: _misura(_altezza),
  );

  Future<Directory> _cartellaPerCopie() async =>
      _cartella ??= await ref.read(archivioProvider).nuovaCartella();

  Future<void> _crea(List<FotoScelta> scelte) async {
    if (_creando) return;
    setState(() => _creando = true);
    final archivio = ref.read(archivioProvider);
    final t = Testi.of(context);
    final numero = (await archivio.elenco()).length + 1;
    final cartella = await _cartellaPerCopie();
    await creaProgetto(
      archivio: archivio,
      cartella: cartella,
      nome: t.nomeProgettoNuovo(numero),
      formato: _formatoScelto,
      scelte: scelte,
    );
    _usata = true;
    if (mounted) Navigator.of(context).pop(cartella);
  }

  void _indietro() {
    if (_passo == 1) {
      setState(() => _passo = 0);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    return PopScope(
      canPop: _passo == 0,
      onPopInvokedWithResult: (esce, _) {
        if (!esce) _indietro();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _indietro,
          ),
          title: Text(_passo == 0 ? t.passoFormato : t.passoFoto),
        ),
        body: SafeArea(
          child: _creando
              ? const Center(child: CircularProgressIndicator())
              : _passo == 0
              ? _formati(t)
              : SceltaFoto(
                  cartellaPerCopie: _cartellaPerCopie,
                  onFatto: _crea,
                  onSalta: () => _crea(const []),
                  etichettaFatto: (t, n) => t.creaConFoto(n),
                ),
        ),
      ),
    );
  }

  Widget _formati(Testi t) {
    final stili = Theme.of(context).textTheme;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(MisureScrl.spazio),
            child: Row(
              children: [
                for (var i = 0; i < aspectRatios.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: MisureScrl.spazio),
                    child: _TesseraFormato(
                      nome: nomeFormato(t, i),
                      proporzione: _proporzione(i),
                      scelto: _formato == i,
                      onTap: () => setState(() => _formato = i),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_formato == ratioPersonalizzato)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
            child: Row(
              children: [
                Expanded(
                  child: _Misura(
                    t.larghezzaPixel,
                    _larghezza,
                    () => setState(() {}),
                  ),
                ),
                const SizedBox(width: MisureScrl.spazio),
                Expanded(
                  child: _Misura(
                    t.altezzaPixel,
                    _altezza,
                    () => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(MisureScrl.spazio),
          child: Row(
            children: [
              Expanded(child: Text(t.formatoAiuto, style: stili.bodySmall)),
              const SizedBox(width: MisureScrl.spazio),
              FilledButton(
                onPressed: () => setState(() => _passo = 1),
                child: Text(t.continua),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Larghezza / altezza del formato [i] (per il personalizzato, quella digitata).
  double _proporzione(int i) {
    final m = aspectRatios[i];
    if (m != null) return m.$1 / m.$2;
    return _misura(_larghezza) / _misura(_altezza);
  }
}

class _Misura extends StatelessWidget {
  const _Misura(this.etichetta, this.controllo, this.onCambia);

  final String etichetta;
  final TextEditingController controllo;
  final VoidCallback onCambia;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controllo,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    onChanged: (_) => onCambia(),
    decoration: InputDecoration(labelText: etichetta),
  );
}

/// Sagoma proporzionata del formato, con il nome sotto.
class _TesseraFormato extends StatelessWidget {
  const _TesseraFormato({
    required this.nome,
    required this.proporzione,
    required this.scelto,
    required this.onTap,
  });

  final String nome;
  final double proporzione;
  final bool scelto;
  final VoidCallback onTap;

  static const double _box = 120;

  @override
  Widget build(BuildContext context) {
    final w = proporzione >= 1 ? _box : _box * proporzione;
    final h = proporzione >= 1 ? _box / proporzione : _box;
    return Semantics(
      button: true,
      selected: scelto,
      label: nome,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: _box + 16,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: _box,
                height: _box,
                child: Center(
                  child: AnimatedContainer(
                    duration: MotoScrl.breve,
                    width: w,
                    height: h,
                    decoration: BoxDecoration(
                      color: ColoriScrl.rilievo,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: scelto ? ColoriScrl.accento : ColoriScrl.bordo,
                        width: scelto ? 3 : 1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: MisureScrl.spazioPiccolo),
              Text(
                nome,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: TestoScrl.normale,
                  fontWeight: scelto ? TestoScrl.marcato : TestoScrl.regolare,
                  color: scelto ? ColoriScrl.testo : ColoriScrl.testoSecondario,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
