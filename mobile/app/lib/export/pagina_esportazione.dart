/// Schermata di avanzamento dell'esportazione (piano §11): fase e pagina in corso, barra, **Annulla**; a lavoro finito
/// mostra com'è andata. Lo schermo resta acceso finché si lavora (lo fa [LavoroEsportazione]).
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../media/galleria.dart';
import '../theme/tokens.dart';
import 'esporta_immagini.dart';

/// Apre la schermata di avanzamento e avvia [lavoro]; si chiude da sé con «Fine» (o «Annulla»).
Future<EsitoEsportazione?> apriAvanzamento(
  NavigatorState navigator,
  LavoroEsportazione lavoro,
) => navigator.push<EsitoEsportazione>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => PaginaEsportazione(lavoro: lavoro),
  ),
);

/// Testo della fase in corso.
String testoFase(Testi t, Avanzamento a, Destinazione d, bool collage) {
  switch (a.fase) {
    case FaseEsportazione.foto:
      return t.espFaseFoto(a.pagina, a.indice, a.totale);
    case FaseEsportazione.pagina:
      return t.espFasePagina(a.pagina, a.indice, a.totale);
    case FaseEsportazione.video:
      return t.espFaseVideo(
        a.pagina,
        a.indice,
        a.totale,
        a.fotogramma,
        a.fotogrammi,
      );
    case FaseEsportazione.composizione:
      return t.espFaseComposizione;
    case FaseEsportazione.consegna:
      return switch (d) {
        Destinazione.galleria => t.espFaseGalleria(a.indice, a.totale),
        Destinazione.condividi => t.espFaseCondividi,
        Destinazione.file => t.espFaseFile(a.indice, a.totale),
      };
  }
}

/// Titolo e testo dell'esito.
({String titolo, String testo, bool riuscita}) testoEsito(
  Testi t,
  EsitoEsportazione e,
) {
  final n = e.salvati.length;
  String salvato() => switch (e.destinazione) {
    Destinazione.galleria => t.espSalvatoGalleria(n),
    Destinazione.condividi => t.espSalvatoCondiviso(n),
    Destinazione.file => t.espSalvatoFile(n),
  };
  // Misure delle immagini e, se ci sono, degli MP4 (`n_mp4` del desktop)
  final soloVideo = e.mp4 > 0 && e.mp4 == n;
  final misure = [
    if (!soloVideo) '${e.larghezza}×${e.altezza} px',
    if (e.mp4 > 0) t.espVideoSalvati(e.mp4, e.videoLarghezza, e.videoAltezza),
  ].join('\n');
  switch (e.stato) {
    case StatoEsito.fatto:
      return (
        titolo: t.espFatto,
        testo: '${salvato()}\n$misure',
        riuscita: true,
      );
    case StatoEsito.parziale:
      final righe = [
        salvato(),
        if (e.falliti.isNotEmpty) t.espNonSalvate(e.falliti.join(', ')),
        if (e.falliti.isEmpty) t.espInterrotta,
        misure,
      ];
      return (
        titolo: t.espIncompleta,
        testo: righe.join('\n'),
        riuscita: false,
      );
    case StatoEsito.annullato:
      return (titolo: t.espAnnullata, testo: '', riuscita: false);
    case StatoEsito.errore:
      final err = e.errore;
      return (
        titolo: t.espIncompleta,
        testo: err is AccessoGalleriaNegato
            ? t.espGalleriaNegata
            : t.espErrore(err?.toString() ?? ''),
        riuscita: false,
      );
  }
}

class PaginaEsportazione extends StatefulWidget {
  const PaginaEsportazione({super.key, required this.lavoro});

  final LavoroEsportazione lavoro;

  @override
  State<PaginaEsportazione> createState() => _PaginaEsportazioneState();
}

class _PaginaEsportazioneState extends State<PaginaEsportazione> {
  EsitoEsportazione? _esito;
  bool _annullando = false;

  @override
  void initState() {
    super.initState();
    unawaited(_avvia());
  }

  Future<void> _avvia() async {
    final e = await widget.lavoro.esegui();
    if (!mounted) return;
    setState(() => _esito = e);
  }

  void _annulla() {
    if (_annullando) return;
    setState(() => _annullando = true);
    widget.lavoro.annulla();
  }

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final finito = _esito != null;
    return PopScope(
      // Durante il lavoro il gesto «indietro» annulla, non esce a metà
      canPop: finito,
      onPopInvokedWithResult: (esce, _) {
        if (!esce) _annulla();
      },
      child: Scaffold(
        backgroundColor: ColoriScrl.fondo,
        appBar: AppBar(
          backgroundColor: ColoriScrl.barra,
          automaticallyImplyLeading: false,
          title: Text(t.espTitoloAvanzamento),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(MisureScrl.spazio * 1.5),
            child: finito ? _Esito(esito: _esito!) : _InCorso(stato: this),
          ),
        ),
      ),
    );
  }
}

class _InCorso extends StatelessWidget {
  const _InCorso({required this.stato});

  final _PaginaEsportazioneState stato;

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final lavoro = stato.widget.lavoro;
    return ValueListenableBuilder<Avanzamento>(
      valueListenable: lavoro.avanzamento,
      builder: (context, a, _) {
        final testo = stato._annullando
            ? t.espAnnullando
            : testoFase(
                t,
                a,
                lavoro.richiesta.destinazione,
                lavoro.richiesta.collage,
              );
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              label: testo,
              excludeSemantics: true,
              child: Text(
                testo,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: MisureScrl.spazio),
            LinearProgressIndicator(
              key: const ValueKey('esportazione-barra'),
              value: a.frazione,
              color: ColoriScrl.accento,
              backgroundColor: ColoriScrl.rilievo,
              minHeight: 6,
            ),
            const SizedBox(height: MisureScrl.spazio * 2),
            Center(
              child: OutlinedButton(
                key: const ValueKey('esportazione-annulla'),
                onPressed: stato._annullando ? null : stato._annulla,
                child: Text(t.annulla),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Esito extends StatelessWidget {
  const _Esito({required this.esito});

  final EsitoEsportazione esito;

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final r = testoEsito(t, esito);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          r.riuscita ? Icons.check_circle_outline_rounded : Icons.info_outline,
          size: 56,
          color: r.riuscita ? ColoriScrl.accento : ColoriScrl.testoSecondario,
        ),
        const SizedBox(height: MisureScrl.spazio),
        Semantics(
          liveRegion: true,
          child: Text(
            r.titolo,
            key: const ValueKey('esportazione-titolo'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (r.testo.isNotEmpty) ...[
          const SizedBox(height: MisureScrl.spazioPiccolo),
          Text(
            r.testo,
            key: const ValueKey('esportazione-esito'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: MisureScrl.spazio * 2),
        Center(
          child: FilledButton(
            key: const ValueKey('esportazione-fine'),
            onPressed: () => Navigator.of(context).pop(esito),
            child: Text(t.espFine),
          ),
        ),
      ],
    );
  }
}
