/// Nuovo progetto in due passi (piano §4.1): il formato, mostrato come sagome proporzionate e diviso tra
/// carosello e reel (la tessera sceglie anche il tipo di progetto), poi la scelta
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

/// Ordine in cui si mostrano i formati di `aspectRatios` (Pagine → Formato): prima i più usati su Instagram
/// (4:5, 9:16, 3:4), poi gli altri, «Personalizzato» per ultimo.
const List<int> ordineFormati = [2, 4, 0, 3, 1, 5, 6, 7, 8];

/// Formati del gruppo «Carosello o foto» di Nuovo progetto, a righe di tre: in cima i post (4:5, 3:4) e il quadrato.
const List<List<int>> _righeCarosello = [
  [2, 0, 3],
  [4, 1, 5],
  [6, 7, 8],
];

/// Formati del gruppo «Reel»: il 9:16 proposto, poi i due che Instagram accetta senza bande.
const List<int> _formatiReel = [4, 2, 3];

class NuovoProgettoPage extends ConsumerStatefulWidget {
  const NuovoProgettoPage({super.key});

  @override
  ConsumerState<NuovoProgettoPage> createState() => _NuovoProgettoPageState();
}

class _NuovoProgettoPageState extends ConsumerState<NuovoProgettoPage> {
  int _passo = 0;
  int _formato = 0; // Di partenza 3:4, come il desktop
  String _tipo =
      'carousel'; // «carousel» o «reel»: lo sceglie la tessera del formato
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
      tipo: _tipo,
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

  /// Formati divisi per tipo di progetto, in una sola schermata (scorre in giù solo se lo schermo è piccolo):
  /// sopra quelli del carosello, sotto quelli del reel. Una tessera sceglie insieme tipo e formato.
  /// «Continua» resta sempre in fondo.
  Widget _formati(Testi t) {
    final stili = Theme.of(context).textTheme;
    Widget tessera(String tipo, int i, {String? uso}) {
      final reel = tipo == 'reel';
      return _TesseraFormato(
        key: ValueKey(reel ? 'nuovo-reel-$i' : 'nuovo-formato-$i'),
        // Nel gruppo Reel basta la proporzione («9:16»): il gruppo dice già a cosa serve
        nome: reel ? nomeFormato(t, i).split(' ').first : nomeFormato(t, i),
        uso: uso,
        gruppo: reel ? t.tipoReel : t.tipoCarosello,
        proporzione: _proporzione(i),
        scelto: _tipo == tipo && _formato == i,
        onTap: () => setState(() {
          _tipo = tipo;
          _formato = i;
        }),
      );
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(MisureScrl.spazio),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TitoloSezione(
                  icona: Icons.view_carousel_rounded,
                  titolo: t.tipoCarosello,
                  descrizione: t.tipoCaroselloDesc,
                ),
                const SizedBox(height: MisureScrl.spazio),
                for (final riga in _righeCarosello) ...[
                  _RigaTessere([
                    for (final i in riga)
                      tessera(
                        'carousel',
                        i,
                        uso: switch (i) {
                          2 => t.usoFormato45,
                          0 => t.usoFormato34,
                          4 => t.usoFormato916,
                          _ => null,
                        },
                      ),
                  ]),
                  const SizedBox(height: MisureScrl.spazioPiccolo),
                ],
                if (_formato == ratioPersonalizzato) ...[
                  const SizedBox(height: MisureScrl.spazioPiccolo),
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
                const SizedBox(height: MisureScrl.spazio * 2),
                _TitoloSezione(
                  icona: Icons.movie_rounded,
                  titolo: t.tipoReel,
                  descrizione: t.tipoReelDesc,
                ),
                const SizedBox(height: MisureScrl.spazio),
                _RigaTessere([
                  for (final i in _formatiReel)
                    tessera(
                      'reel',
                      i,
                      uso: i == 4 ? t.usoFormatoConsigliato : null,
                    ),
                ]),
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
              Expanded(
                child: Text(
                  _tipo == 'reel' ? t.formatoAiutoReel : t.formatoAiuto,
                  style: stili.bodySmall,
                ),
              ),
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

/// Sagoma proporzionata del formato, con il nome e (per alcuni) a cosa serve.
class _TesseraFormato extends StatelessWidget {
  const _TesseraFormato({
    super.key,
    required this.nome,
    required this.proporzione,
    required this.scelto,
    required this.onTap,
    this.uso,
    this.gruppo,
  });

  final String nome;
  final String? uso;

  /// Tipo di progetto del gruppo (letto dai lettori di schermo prima del formato).
  final String? gruppo;
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
      label: [
        if (gruppo != null) gruppo,
        nome,
        if (uso != null) uso,
      ].join(', '),
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
