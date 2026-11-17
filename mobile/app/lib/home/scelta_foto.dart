/// Scelta delle foto dalla galleria (piano §4.1 e §9): griglia con selezione multipla numerata. Si usa per
/// «Nuovo progetto» e per «Aggiungi dal telefono» della libreria.
///
/// Il permesso si chiede solo qui, e con una riga che spiega perché. Con l'accesso parziale si lavora con le foto
/// concesse e si offre «Scegli altre foto»; con il permesso negato si ripiega sul selettore di sistema, che non
/// chiede permessi e le cui scelte si copiano in `media/` del progetto.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:photo_manager/photo_manager.dart' show ThumbnailSize;
import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import '../l10n/app_localizations.dart';
import '../media/galleria.dart';
import '../media/importa.dart';
import '../project/crea_progetto.dart';
import '../project/provider.dart';
import '../theme/tokens.dart';

class SceltaFoto extends ConsumerStatefulWidget {
  const SceltaFoto({
    super.key,
    required this.cartellaPerCopie,
    required this.onFatto,
    required this.etichettaFatto,
    this.onSalta,
    this.etichettaSalta,
    this.singola = false,
  });

  /// Si sceglie una foto sola (per ricollegare una foto mancante): un tocco su un'altra sposta la scelta.
  final bool singola;

  /// Cartella del progetto dove copiare i file del selettore di sistema (la crea chi chiama, se serve).
  final Future<Directory> Function() cartellaPerCopie;
  final ValueChanged<List<FotoScelta>> onFatto;

  /// Testo del pulsante principale, dato il numero di foto scelte.
  final String Function(Testi t, int n) etichettaFatto;
  final VoidCallback? onSalta;
  final String Function(Testi t)? etichettaSalta;

  @override
  ConsumerState<SceltaFoto> createState() => _SceltaFotoState();
}

class _SceltaFotoState extends ConsumerState<SceltaFoto>
    with WidgetsBindingObserver {
  AccessoGalleria? _accesso;
  final List<ElementoGalleria> _elementi = [];
  final List<String> _ordine = []; // Identificativi nell'ordine di scelta
  final ScrollController _scorri = ScrollController();
  int _pagina = 0;
  bool _finito = false;
  bool _carico = false;
  bool _occupato = false;

  Galleria get _galleria => ref.read(galleriaProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scorri.addListener(_alloScorrimento);
    _aggiorna();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scorri.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState stato) {
    // Tornando dalle impostazioni o dalla scelta di sistema l'accesso può essere cambiato
    if (stato == AppLifecycleState.resumed) _aggiorna();
  }

  Future<void> _aggiorna() async {
    final a = await _galleria.stato();
    if (!mounted) return;
    setState(() => _accesso = a);
    if (a == AccessoGalleria.completo || a == AccessoGalleria.parziale) {
      _elementi.clear();
      _pagina = 0;
      _finito = false;
      await _caricaAltri();
    }
  }

  Future<void> _chiedi() async {
    final a = await _galleria.chiedi();
    if (!mounted) return;
    setState(() => _accesso = a);
    await _aggiorna();
  }

  Future<void> _caricaAltri() async {
    if (_carico || _finito) return;
    _carico = true;
    final l = await _galleria.elenco(pagina: _pagina);
    _carico = false;
    if (!mounted) return;
    setState(() {
      _elementi.addAll(l);
      _pagina++;
      if (l.length < 60) _finito = true;
    });
  }

  void _alloScorrimento() {
    if (_scorri.hasClients &&
        _scorri.position.pixels > _scorri.position.maxScrollExtent - 600) {
      unawaited(_caricaAltri());
    }
  }

  void _tocca(ElementoGalleria e) {
    final id = e.entita.id;
    setState(() {
      if (widget.singola) {
        final eraScelta = _ordine.contains(id);
        _ordine.clear();
        if (!eraScelta) _ordine.add(id);
      } else if (!_ordine.remove(id)) {
        _ordine.add(id);
      }
    });
  }

  FotoScelta _daElemento(ElementoGalleria e) {
    final s = e.entita.orientatedSize;
    final voce = LibraryEntry(
      path: e.riferimento.name,
      rel: null,
      asset: e.riferimento,
    );
    return (
      voce: voce,
      chiave: 'a:${e.riferimento.platform}:${e.riferimento.id}',
      w: s.width.round(),
      h: s.height.round(),
    );
  }

  Future<void> _conferma() async {
    final scelte = [
      for (final id in _ordine)
        for (final e in _elementi)
          if (e.entita.id == id) _daElemento(e),
    ];
    widget.onFatto(scelte);
  }

  /// Ripiego col permesso negato: selettore di sistema e copia in `media/`.
  Future<void> _dalTelefono() async {
    if (_occupato) return;
    setState(() => _occupato = true);
    try {
      final cartella = await widget.cartellaPerCopie();
      final copiati = await scegliECopia(cartella);
      final scelte = await scelteDaCopie(cartella, copiati);
      if (scelte.isNotEmpty) widget.onFatto(scelte);
    } finally {
      if (mounted) setState(() => _occupato = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final stili = Theme.of(context).textTheme;
    final a = _accesso;
    final conAccesso =
        a == AccessoGalleria.completo || a == AccessoGalleria.parziale;
    return Column(
      children: [
        Expanded(
          child: a == null
              ? const SizedBox.shrink()
              : conAccesso
              ? _griglia(t)
              : _senzaAccesso(t, stili, a),
        ),
        if (a == AccessoGalleria.parziale)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
            child: TextButton(
              onPressed: () async {
                await _galleria.scegliAltre();
                await _aggiorna();
              },
              child: Text(t.scegliAltreFoto),
            ),
          ),
        _piede(t, conAccesso),
      ],
    );
  }

  Widget _senzaAccesso(Testi t, TextTheme stili, AccessoGalleria a) {
    return Padding(
      padding: const EdgeInsets.all(MisureScrl.spazio * 2),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.photo_library_outlined,
              size: MisureScrl.tocco,
              color: ColoriScrl.testoSecondario,
            ),
            const SizedBox(height: MisureScrl.spazio),
            Text(
              a == AccessoGalleria.negato
                  ? t.accessoNegato
                  : t.accessoDaChiedere,
              textAlign: TextAlign.center,
              style: stili.bodyMedium,
            ),
            const SizedBox(height: MisureScrl.spazio),
            if (a == AccessoGalleria.daChiedere)
              FilledButton(onPressed: _chiedi, child: Text(t.consentiAccesso))
            else
              FilledButton(
                onPressed: _dalTelefono,
                child: Text(t.scegliDalTelefono),
              ),
          ],
        ),
      ),
    );
  }

  Widget _griglia(Testi t) {
    return GridView.builder(
      controller: _scorri,
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: _elementi.length,
      itemBuilder: (context, i) {
        final e = _elementi[i];
        final n = _ordine.indexOf(e.entita.id);
        return _TesseraGalleria(
          elemento: e,
          numero: n < 0 ? null : n + 1,
          onTap: () => _tocca(e),
          etichetta: t.fotoNumero(i + 1),
        );
      },
    );
  }

  Widget _piede(Testi t, bool conAccesso) {
    final n = _ordine.length;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(MisureScrl.spazio),
        child: Row(
          children: [
            if (widget.onSalta != null)
              TextButton(
                onPressed: widget.onSalta,
                child: Text(widget.etichettaSalta?.call(t) ?? t.salta),
              ),
            const Spacer(),
            FilledButton(
              onPressed: conAccesso && n > 0 ? _conferma : null,
              child: Text(widget.etichettaFatto(t, n)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Miniatura della galleria con il numero d'ordine se scelta, e il segno dei video.
class _TesseraGalleria extends StatefulWidget {
  const _TesseraGalleria({
    required this.elemento,
    required this.numero,
    required this.onTap,
    required this.etichetta,
  });

  final ElementoGalleria elemento;
  final int? numero;
  final VoidCallback onTap;
  final String etichetta;

  @override
  State<_TesseraGalleria> createState() => _TesseraGalleriaState();
}

class _TesseraGalleriaState extends State<_TesseraGalleria> {
  late final Future<Uint8List?> _dati = widget.elemento.entita
      .thumbnailDataWithSize(const ThumbnailSize.square(240));

  @override
  Widget build(BuildContext context) {
    final scelta = widget.numero != null;
    return Semantics(
      button: true,
      selected: scelta,
      label: widget.etichetta,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<Uint8List?>(
              future: _dati,
              builder: (context, s) => s.data == null
                  ? const ColoredBox(color: ColoriScrl.rilievo)
                  : Image.memory(
                      s.data!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
            ),
            if (widget.elemento.video)
              const Positioned(
                left: 4,
                bottom: 4,
                child: Icon(
                  Icons.videocam_rounded,
                  size: 18,
                  color: ColoriScrl.suAccento,
                ),
              ),
            if (scelta)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: ColoriScrl.accento.withValues(alpha: 0.25),
                  border: Border.all(color: ColoriScrl.accento, width: 3),
                ),
              ),
            if (scelta)
              Positioned(
                top: 6,
                right: 6,
                child: CircleAvatar(
                  radius: 11,
                  backgroundColor: ColoriScrl.accento,
                  child: Text(
                    '${widget.numero}',
                    style: const TextStyle(
                      fontSize: TestoScrl.piccolo,
                      fontWeight: TestoScrl.marcato,
                      color: ColoriScrl.suAccento,
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

/// Schermata intera con la scelta delle foto, per aggiungerne alla libreria di un progetto aperto.
/// Restituisce le foto scelte (nessuna se si torna indietro).
class SceltaFotoPage extends StatelessWidget {
  const SceltaFotoPage({
    super.key,
    required this.cartellaPerCopie,
    this.singola = false,
    this.titolo,
    this.etichettaFatto,
  });

  final Future<Directory> Function() cartellaPerCopie;
  final bool singola;

  /// Titolo della pagina (di partenza «Scegli le foto»).
  final String? titolo;
  final String Function(Testi t, int n)? etichettaFatto;

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(<FotoScelta>[]),
        ),
        title: Text(titolo ?? t.passoFoto),
      ),
      body: SafeArea(
        child: SceltaFoto(
          cartellaPerCopie: cartellaPerCopie,
          singola: singola,
          onFatto: (l) => Navigator.of(context).pop(l),
          etichettaFatto: etichettaFatto ?? (t, n) => t.aggiungiNFoto(n),
        ),
      ),
    );
  }
}
