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

/// Ordine in cui si mostrano i formati di `aspectRatios`: prima i [formatiInstagram] più usati (4:5, 9:16, 3:4),
/// poi gli altri, «Personalizzato» per ultimo.
const List<int> ordineFormati = [2, 4, 0, 3, 1, 5, 6, 7, 8];

/// Quanti formati, all'inizio di [ordineFormati], sono quelli di Instagram.
const int formatiInstagram = 3;

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
    if (!mounted) return;
    // Solo se questa schermata è ancora in cima: un `pop` in più chiuderebbe la Home
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      Navigator.of(context).pop(cartella);
    }
  }

  void _indietro() {
    // Si sta creando il progetto: si aspetta che finisca
    if (_creando) return;
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
      canPop: _passo == 0 && !_creando,
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

  /// Formati in una sola schermata (scorre in giù solo se lo schermo è piccolo): in cima i più usati, quelli di
  /// Instagram, poi gli altri; «Continua» resta sempre in fondo.
  Widget _formati(Testi t) {
    final stili = Theme.of(context).textTheme;
    Widget tessera(int i, {String? uso}) => _TesseraFormato(
      key: ValueKey('nuovo-formato-$i'),
      nome: nomeFormato(t, i),
      uso: uso,
      proporzione: _proporzione(i),
      scelto: _formato == i,
      onTap: () => setState(() => _formato = i),
    );
    final altri = ordineFormati.skip(formatiInstagram).toList();
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(MisureScrl.spazio),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TitoloSezione(
                  icona: Icons.star_rounded,
                  titolo: t.formatiPiuUsati,
                  descrizione: t.formatiPiuUsatiDesc,
                ),
                const SizedBox(height: MisureScrl.spazio),
                _RigaTessere([
                  tessera(2, uso: t.usoFormato45),
                  tessera(4, uso: t.usoFormato916),
                  tessera(0, uso: t.usoFormato34),
                ]),
                const SizedBox(height: MisureScrl.spazio * 2),
                _TitoloSezione(titolo: t.formatiAltri),
                const SizedBox(height: MisureScrl.spazio),
                for (var r = 0; r < altri.length; r += 3) ...[
                  _RigaTessere([
                    for (final i in altri.skip(r).take(3)) tessera(i),
                  ]),
                  const SizedBox(height: MisureScrl.spazioPiccolo),
                ],
                if (_formato == ratioPersonalizzato) ...[
                  const SizedBox(height: MisureScrl.spazio),
                  Row(
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
                ],
              ],
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: ColoriScrl.bordo)),
          ),
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

/// Titolo di una sezione dei formati, con una riga di spiegazione facoltativa.
class _TitoloSezione extends StatelessWidget {
  const _TitoloSezione({required this.titolo, this.descrizione, this.icona});

  final String titolo;
  final String? descrizione;
  final IconData? icona;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icona != null) ...[
              Icon(icona, size: 18, color: ColoriScrl.accento),
              const SizedBox(width: 6),
            ],
            Text(
              titolo,
              style: const TextStyle(
                fontSize: TestoScrl.grande,
                fontWeight: TestoScrl.marcato,
                color: ColoriScrl.testo,
              ),
            ),
          ],
        ),
        if (descrizione != null) ...[
          const SizedBox(height: 2),
          Text(
            descrizione!,
            style: const TextStyle(
              fontSize: TestoScrl.piccolo,
              color: ColoriScrl.testoSecondario,
            ),
          ),
        ],
      ],
    ),
  );
}

/// Una riga di tre tessere della stessa larghezza e altezza (le caselle in più restano vuote).
class _RigaTessere extends StatelessWidget {
  const _RigaTessere(this.tessere);

  final List<Widget> tessere;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: MisureScrl.spazioPiccolo),
          Expanded(
            child: i < tessere.length ? tessere[i] : const SizedBox.shrink(),
          ),
        ],
      ],
    ),
  );
}

/// Sagoma proporzionata del formato, con il nome e (per i più usati) a cosa serve.
class _TesseraFormato extends StatelessWidget {
  const _TesseraFormato({
    super.key,
    required this.nome,
    required this.proporzione,
    required this.scelto,
    required this.onTap,
    this.uso,
  });

  final String nome;
  final String? uso;
  final double proporzione;
  final bool scelto;
  final VoidCallback onTap;

  /// Lato del riquadro in cui sta la sagoma.
  static const double _box = 64;

  @override
  Widget build(BuildContext context) {
    final w = proporzione >= 1 ? _box : _box * proporzione;
    final h = proporzione >= 1 ? _box / proporzione : _box;
    return Semantics(
      button: true,
      selected: scelto,
      label: uso == null ? nome : '$nome, $uso',
      excludeSemantics: true,
      child: Material(
        color: scelto ? ColoriScrl.rilievo : ColoriScrl.pannello,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MisureScrl.angoloTessera),
          side: BorderSide(
            color: scelto ? ColoriScrl.accento : ColoriScrl.bordo,
            width: scelto ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MisureScrl.spazioPiccolo,
              vertical: 12,
            ),
            child: Column(
              children: [
                SizedBox(
                  width: _box,
                  height: _box,
                  child: Center(
                    child: AnimatedContainer(
                      duration: MotoScrl.durata(context, MotoScrl.breve),
                      width: w,
                      height: h,
                      decoration: BoxDecoration(
                        color: scelto
                            ? ColoriScrl.accento.withAlpha(60)
                            : ColoriScrl.rilievo,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: scelto ? ColoriScrl.accento : ColoriScrl.bordo,
                          width: scelto ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: MisureScrl.spazioPiccolo),
                Text(
                  nome,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: TestoScrl.normale,
                    fontWeight: scelto ? TestoScrl.marcato : TestoScrl.regolare,
                    color: ColoriScrl.testo,
                  ),
                ),
                if (uso != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    uso!,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: TestoScrl.piccolo,
                      color: scelto
                          ? ColoriScrl.accentoTesto
                          : ColoriScrl.testoSecondario,
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
