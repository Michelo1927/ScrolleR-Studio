/// Pagina di avanzamento dei lavori di scambio (zip in uscita, importazione): testo di ciò che si sta facendo, barra,
/// **Annulla**; a lavoro finito l'esito, con «Apri progetto» se è nato un progetto (piano §14: avanzamento e Annulla
/// oltre 1 s). Stesso schema della pagina dell'esportazione immagini.
library;

import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../project/lavoro.dart';
import '../theme/tokens.dart';

/// Com'è andato un lavoro.
class EsitoLavoro {
  const EsitoLavoro({
    required this.titolo,
    this.testo = '',
    this.riuscito = true,
    this.progetto,
  });

  final String titolo;
  final String testo;
  final bool riuscito;

  /// Progetto nato dal lavoro: la pagina offre «Apri progetto».
  final Directory? progetto;
}

typedef EseguiLavoro = Future<EsitoLavoro> Function(
  BuildContext context,
  Avanza avanza,
  Annullamento annullamento,
);

/// Trasforma un errore in un esito comprensibile; chi chiama sa quali errori aspettarsi.
typedef EsitoDaErrore = EsitoLavoro Function(Testi t, Object errore);

/// Apre la pagina e avvia [esegui]. Restituisce il progetto da aprire (se l'utente ha toccato «Apri progetto»).
Future<Directory?> apriLavoro(
  BuildContext context, {
  required String titolo,
  required EseguiLavoro esegui,
  required EsitoDaErrore daErrore,
}) => Navigator.of(context).push<Directory?>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) =>
        PaginaLavoro(titolo: titolo, esegui: esegui, daErrore: daErrore),
  ),
);

class PaginaLavoro extends StatefulWidget {
  const PaginaLavoro({
    super.key,
    required this.titolo,
    required this.esegui,
    required this.daErrore,
  });

  final String titolo;
  final EseguiLavoro esegui;
  final EsitoDaErrore daErrore;

  @override
  State<PaginaLavoro> createState() => _PaginaLavoroState();
}

class _PaginaLavoroState extends State<PaginaLavoro> {
  final _annullamento = Annullamento();
  EsitoLavoro? _esito;
  bool _annullando = false;
  String _testo = '';
  double? _frazione;

  @override
  void initState() {
    super.initState();
    // Dopo il primo disegno: i testi localizzati non si possono leggere in initState
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_avvia()));
  }

  Future<void> _avvia() async {
    EsitoLavoro esito;
    final t = Testi.of(context);
    try {
      esito = await widget.esegui(context, (f, testo) {
        if (!mounted) return;
        setState(() {
          _frazione = f;
          _testo = testo;
        });
      }, _annullamento);
    } on LavoroAnnullato {
      esito = EsitoLavoro(titolo: t.lavoroAnnullato, riuscito: false);
    } on Exception catch (e) {
      esito = widget.daErrore(t, e);
    }
    if (!mounted) return;
    setState(() => _esito = esito);
  }

  void _annulla() {
    if (_annullando) return;
    setState(() => _annullando = true);
    _annullamento.annulla();
  }

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final esito = _esito;
    return PopScope(
      // Durante il lavoro il gesto «indietro» annulla, non esce a metà
      canPop: esito != null,
      onPopInvokedWithResult: (esce, _) {
        if (!esce) _annulla();
      },
      child: Scaffold(
        backgroundColor: ColoriScrl.fondo,
        appBar: AppBar(
          backgroundColor: ColoriScrl.barra,
          automaticallyImplyLeading: false,
          title: Text(widget.titolo),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(MisureScrl.spazio * 1.5),
            child: esito != null
                ? _Esito(esito: esito)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        liveRegion: true,
                        label: _annullando ? t.espAnnullando : _testo,
                        excludeSemantics: true,
                        child: Text(
                          _annullando ? t.espAnnullando : _testo,
                          key: const ValueKey('lavoro-testo'),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: MisureScrl.spazio),
                      LinearProgressIndicator(
                        key: const ValueKey('lavoro-barra'),
                        value: _frazione,
                        color: ColoriScrl.accento,
                        backgroundColor: ColoriScrl.rilievo,
                        minHeight: 6,
                      ),
                      const SizedBox(height: MisureScrl.spazio * 2),
                      Center(
                        child: OutlinedButton(
                          key: const ValueKey('lavoro-annulla'),
                          onPressed: _annullando ? null : _annulla,
                          child: Text(t.annulla),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _Esito extends StatelessWidget {
  const _Esito({required this.esito});

  final EsitoLavoro esito;

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final stili = Theme.of(context).textTheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          esito.riuscito
              ? Icons.check_circle_outline_rounded
              : Icons.info_outline,
          size: 56,
          color: esito.riuscito
              ? ColoriScrl.accento
              : ColoriScrl.testoSecondario,
        ),
        const SizedBox(height: MisureScrl.spazio),
        Semantics(
          liveRegion: true,
          child: Text(
            esito.titolo,
            key: const ValueKey('lavoro-titolo'),
            textAlign: TextAlign.center,
            style: stili.titleMedium,
          ),
        ),
        if (esito.testo.isNotEmpty) ...[
          const SizedBox(height: MisureScrl.spazioPiccolo),
          Text(
            esito.testo,
            key: const ValueKey('lavoro-esito'),
            textAlign: TextAlign.center,
            style: stili.bodyMedium,
          ),
        ],
        const SizedBox(height: MisureScrl.spazio * 2),
        if (esito.progetto != null)
          Center(
            child: FilledButton(
              key: const ValueKey('lavoro-apri'),
              onPressed: () => Navigator.of(context).pop(esito.progetto),
              child: Text(t.impApri),
            ),
          ),
        Center(
          child: esito.progetto != null
              ? TextButton(
                  key: const ValueKey('lavoro-fine'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(t.espFine),
                )
              : FilledButton(
                  key: const ValueKey('lavoro-fine'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(t.espFine),
                ),
        ),
      ],
    );
  }
}
