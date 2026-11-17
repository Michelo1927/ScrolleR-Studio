/// Foto mancanti nell'editor (piano §6 e §9): controllo all'apertura, segno sulla tela, elenco, ricollegamento di una
/// foto (scegliendola nella galleria) e ricerca automatica per nome.
///
/// Sul telefono le foto sono solo collegate alla galleria: se una viene cancellata resta sulla tela con l'anteprima
/// salvata e il segno «Originale mancante». Qui si vede quante sono, si ritrovano, e il nuovo riferimento sostituisce
/// il vecchio ovunque ([ControlloEditor.ricollega]).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import '../home/scelta_foto.dart';
import '../l10n/app_localizations.dart';
import '../media/cache_media.dart';
import '../media/galleria.dart';
import '../media/mancanti.dart';
import '../project/crea_progetto.dart';
import '../project/lavoro.dart';
import '../theme/tokens.dart';
import 'sessione.dart';
import 'stato.dart';
import 'widget_comuni.dart';

/// Impronta dei riferimenti alle foto: cambia solo quando cambia un riferimento (ricollegamento, foto aggiunte o
/// tolte), non a ogni gesto sulla tela.
String _impronta(StatoEditor e) => [
  for (final r in elencaRiferimenti(e.cronologia.current, e.libreria)) r.chiave,
].join('|');

/// Foto del progetto che non si trovano più. Si ricalcola quando cambiano i riferimenti; dopo un ritorno da un'altra
/// app si invalida a mano (una foto può essere tornata, o sparita).
final mancantiProvider = FutureProvider.autoDispose<List<FotoMancante>>((
  ref,
) async {
  final s = ref.watch(sessioneProvider);
  if (!s.controllaMancanti) return const [];
  ref.watch(editorProvider.select(_impronta));
  final stato = ref.read(editorProvider);
  return trovaMancanti(
    snapshot: stato.cronologia.current,
    libreria: stato.libreria,
    cartellaProgetto: s.cartella.path,
    galleria: s.galleria,
    misure: s.misure,
  );
}, dependencies: [sessioneProvider, editorProvider]);

/// Apre l'elenco delle foto mancanti a schermo intero. Sta fuori dal `ProviderScope` dell'editor: gli si passa lo
/// stesso contenitore. Con [cercaSubito] parte la ricerca automatica nella galleria.
Future<void> apriMancanti(BuildContext context, {bool cercaSubito = false}) {
  final contenitore = ProviderScope.containerOf(context);
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => UncontrolledProviderScope(
        container: contenitore,
        child: PaginaMancanti(cercaSubito: cercaSubito),
      ),
    ),
  );
}

/// Scelta della foto che sostituisce [m]: la griglia della galleria (una sola foto) o, senza permesso, il selettore di
/// sistema con copia in `media/`. Restituisce il nuovo riferimento, o null se l'utente ha rinunciato.
Future<Ritrovata?> scegliPerRicollegare(
  BuildContext context,
  SessioneEditor sessione,
  FotoMancante m,
) async {
  final scelte = await Navigator.of(context).push<List<FotoScelta>>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => SceltaFotoPage(
        cartellaPerCopie: () async => sessione.cartella,
        singola: true,
        titolo: Testi.of(context).manScegli(m.nome),
        etichettaFatto: (t, n) => t.manRicollega,
      ),
    ),
  );
  if (scelte == null || scelte.isEmpty) return null;
  final s = scelte.first;
  return Ritrovata((
    path: s.voce.path,
    rel: s.voce.rel,
    asset: s.voce.asset,
  ), s.w > 0 && s.h > 0 ? (w: s.w, h: s.h) : null);
}

/// «Ricollega» una foto: sceglie dove si trova ora e la sostituisce ovunque.
Future<bool> ricollegaUna(
  BuildContext context,
  WidgetRef ref,
  FotoMancante m,
) async {
  final sessione = ref.read(sessioneProvider);
  final ctrl = ref.read(editorProvider.notifier);
  final r = await scegliPerRicollegare(context, sessione, m);
  if (r == null) return false;
  ctrl.ricollega({m.chiave: r});
  return true;
}

// ===================================================================== segno sulla tela

/// Segno sulla tela: «3 foto mancanti». Un tocco apre l'elenco. Sparisce con un pannello aperto e quando non manca niente.
class BadgeMancanti extends ConsumerWidget {
  const BadgeMancanti({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(mancantiProvider).value?.length ?? 0;
    final libero = ref.watch(
      editorProvider.select((s) => s.strumento == Strumento.nessuno),
    );
    if (n == 0 || !libero) return const SizedBox.shrink();
    final t = Testi.of(context);
    return Semantics(
      button: true,
      label: t.manBadge(n),
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('badge-mancanti'),
        onTap: () => unawaited(apriMancanti(context)),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
          decoration: BoxDecoration(
            color: ColoriScrl.veloEtichetta,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: ColoriScrl.pericolo),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: ColoriScrl.pericolo,
              ),
              const SizedBox(width: MisureScrl.spazioPiccolo),
              Text(
                t.manBadge(n),
                style: const TextStyle(
                  fontSize: TestoScrl.normale,
                  color: ColoriScrl.testo,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avviso all'apertura del progetto: dice quante foto non si trovano e propone di cercarle nella galleria.
Future<void> avvisaMancantiAllApertura(BuildContext context, int quante) async {
  final t = Testi.of(context);
  final scelta = await showDialog<_SceltaApertura>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(t.manAperturaTitolo),
      content: Text(t.manApertura(quante)),
      actions: [
        TextButton(
          key: const ValueKey('mancanti-piu-tardi'),
          onPressed: () => Navigator.of(d).pop(_SceltaApertura.piuTardi),
          child: Text(t.manPiuTardi),
        ),
        TextButton(
          key: const ValueKey('mancanti-elenco'),
          onPressed: () => Navigator.of(d).pop(_SceltaApertura.elenco),
          child: Text(t.manVediElenco),
        ),
        FilledButton(
          key: const ValueKey('mancanti-cerca'),
          onPressed: () => Navigator.of(d).pop(_SceltaApertura.cerca),
          child: Text(t.manCerca),
        ),
      ],
    ),
  );
  if (!context.mounted ||
      scelta == null ||
      scelta == _SceltaApertura.piuTardi) {
    return;
  }
  await apriMancanti(context, cercaSubito: scelta == _SceltaApertura.cerca);
}

enum _SceltaApertura { piuTardi, elenco, cerca }

// ===================================================================== elenco

class PaginaMancanti extends ConsumerStatefulWidget {
  const PaginaMancanti({super.key, this.cercaSubito = false});

  final bool cercaSubito;

  @override
  ConsumerState<PaginaMancanti> createState() => _PaginaMancantiState();
}

class _PaginaMancantiState extends ConsumerState<PaginaMancanti> {
  Annullamento? _ricerca;
  int _guardati = 0;
  String? _esito;
  bool _senzaAccesso = false;

  @override
  void initState() {
    super.initState();
    if (widget.cercaSubito) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_cerca()));
    }
  }

  @override
  void dispose() {
    _ricerca?.annulla();
    super.dispose();
  }

  /// Ricerca automatica per nome in tutta la galleria (chiede il permesso solo ora, con la scelta già fatta).
  Future<void> _cerca() async {
    if (_ricerca != null) return;
    final t = Testi.of(context);
    final sessione = ref.read(sessioneProvider);
    final ctrl = ref.read(editorProvider.notifier);
    final mancanti = ref.read(mancantiProvider).value ?? const [];
    if (mancanti.isEmpty) return;
    final galleria = sessione.galleria;
    var accesso = await galleria.stato();
    if (accesso == AccessoGalleria.daChiedere) {
      accesso = await galleria.chiedi();
    }
    if (!mounted) return;
    if (accesso == AccessoGalleria.negato) {
      setState(() {
        _senzaAccesso = true;
        _esito = null;
      });
      return;
    }
    final stop = Annullamento();
    setState(() {
      _ricerca = stop;
      _guardati = 0;
      _esito = null;
      _senzaAccesso = false;
    });
    String esito;
    try {
      final trovate = await cercaInGalleria(
        galleria,
        mancanti,
        progresso: (n) {
          if (mounted) setState(() => _guardati = n);
        },
        annullamento: stop,
      );
      if (trovate.isNotEmpty) ctrl.ricollega(trovate);
      esito = trovate.isEmpty
          ? t.manNessunaTrovata
          : t.manRitrovate(trovate.length, mancanti.length);
    } on LavoroAnnullato {
      esito = t.lavoroAnnullato;
    }
    if (!mounted) return;
    setState(() {
      _ricerca = null;
      _esito = esito;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final stili = Theme.of(context).textTheme;
    final mancanti = ref.watch(mancantiProvider);
    final lista = mancanti.value ?? const <FotoMancante>[];
    final cercando = _ricerca != null;
    return Scaffold(
      backgroundColor: ColoriScrl.fondo,
      appBar: AppBar(
        backgroundColor: ColoriScrl.barra,
        automaticallyImplyLeading: false,
        leading: PulsanteIcona(
          icona: Icons.close_rounded,
          etichetta: t.chiudi,
          onTap: cercando ? null : () => Navigator.of(context).pop(),
        ),
        title: Text(t.manTitolo),
      ),
      body: SafeArea(
        child: mancanti.isLoading && lista.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : lista.isEmpty && !cercando
            ? Padding(
                padding: const EdgeInsets.all(MisureScrl.spazio * 1.5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 56,
                      color: ColoriScrl.accento,
                    ),
                    const SizedBox(height: MisureScrl.spazio),
                    Text(
                      _esito ?? t.manTutte,
                      key: const ValueKey('mancanti-tutte'),
                      textAlign: TextAlign.center,
                      style: stili.titleMedium,
                    ),
                    const SizedBox(height: MisureScrl.spazio * 2),
                    Center(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(t.espFine),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(MisureScrl.spazio),
                    child: Text(t.manIntro, style: stili.bodyMedium),
                  ),
                  if (cercando)
                    _Ricerca(guardati: _guardati, onAnnulla: _ricerca!.annulla)
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MisureScrl.spazio,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const ValueKey('mancanti-cerca-galleria'),
                          onPressed: _cerca,
                          icon: const Icon(Icons.search_rounded),
                          label: Text(t.manCerca),
                        ),
                      ),
                    ),
                  if (_esito != null)
                    Padding(
                      padding: const EdgeInsets.all(MisureScrl.spazio),
                      child: Text(
                        _esito!,
                        key: const ValueKey('mancanti-esito'),
                        style: stili.bodyMedium,
                      ),
                    ),
                  if (_senzaAccesso)
                    Padding(
                      padding: const EdgeInsets.all(MisureScrl.spazio),
                      child: Text(
                        t.manSenzaAccesso,
                        key: const ValueKey('mancanti-senza-accesso'),
                        style: stili.bodyMedium,
                      ),
                    ),
                  const SizedBox(height: MisureScrl.spazioPiccolo),
                  Expanded(
                    child: ListView.builder(
                      itemCount: lista.length,
                      itemBuilder: (context, i) => _Riga(
                        key: ValueKey('mancante-${lista[i].chiave}'),
                        foto: lista[i],
                        occupato: cercando,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Ricerca extends StatelessWidget {
  const _Ricerca({required this.guardati, required this.onAnnulla});

  final int guardati;
  final VoidCallback onAnnulla;

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(
                    t.manRicerca(guardati),
                    key: const ValueKey('mancanti-ricerca'),
                  ),
                ),
                const SizedBox(height: MisureScrl.spazioPiccolo),
                const LinearProgressIndicator(
                  color: ColoriScrl.accento,
                  backgroundColor: ColoriScrl.rilievo,
                  minHeight: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: MisureScrl.spazio),
          OutlinedButton(
            key: const ValueKey('mancanti-annulla-ricerca'),
            onPressed: onAnnulla,
            child: Text(t.annulla),
          ),
        ],
      ),
    );
  }
}

class _Riga extends ConsumerWidget {
  const _Riga({super.key, required this.foto, required this.occupato});

  final FotoMancante foto;
  final bool occupato;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final stili = Theme.of(context).textTheme;
    final sessione = ref.read(sessioneProvider);
    final anteprima = sessione.cache.fileAnteprima(
      sorgenteDi(foto.comeFoto, sessione.cartella.path),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MisureScrl.spazio,
        vertical: MisureScrl.spazioPiccolo,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56,
              height: 56,
              child: anteprima == null
                  ? const ColoredBox(
                      color: ColoriScrl.rilievo,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: ColoriScrl.testoSpento,
                      ),
                    )
                  : Image.file(
                      anteprima,
                      fit: BoxFit.cover,
                      cacheWidth: 160,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: ColoriScrl.rilievo,
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: ColoriScrl.testoSpento,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: MisureScrl.spazio),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  foto.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: stili.titleMedium?.copyWith(
                    fontSize: TestoScrl.normale,
                  ),
                ),
                Text(
                  [
                    t.manUsi(foto.usiSullaTela),
                    if (anteprima != null) t.manAnteprima,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: stili.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: MisureScrl.spazioPiccolo),
          OutlinedButton(
            key: ValueKey('ricollega-${foto.chiave}'),
            onPressed: occupato
                ? null
                : () => unawaited(ricollegaUna(context, ref, foto)),
            child: Text(t.manRicollega),
          ),
        ],
      ),
    );
  }
}
