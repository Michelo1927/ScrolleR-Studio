/// Impostazioni (piano §4.7 e Fase 10): Gesti, suggerimenti, controllo degli aggiornamenti, registro errori e
/// informazioni. Una pagina a righe, senza menu a tendina: ogni riga è un solo elemento per i lettori di schermo.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../editor/suggerimenti.dart';
import '../export/consegna.dart';
import '../export/preferenze.dart';
import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'aggiornamenti.dart';
import 'gesti_page.dart';
import 'registro_errori.dart';

/// Nome del file che si condivide: il registro ripulito dai percorsi.
const String nomeFileRegistro = 'ScrolleR-Studio-errori.txt';

class ImpostazioniPage extends ConsumerStatefulWidget {
  const ImpostazioniPage({super.key});

  @override
  ConsumerState<ImpostazioniPage> createState() => _ImpostazioniPageState();
}

enum _Controllo { fermo, inCorso, aggiornato, errore, nuova }

class _ImpostazioniPageState extends ConsumerState<ImpostazioniPage> {
  bool _controlloAttivo = true;
  bool _registroPieno = false;
  _Controllo _controllo = _Controllo.fermo;
  NuovaVersione? _nuova;

  @override
  void initState() {
    super.initState();
    unawaited(_carica());
  }

  Future<void> _carica() async {
    final attivo = await ref.read(controlloAggiornamentiProvider).attivo();
    final pieno = await ref.read(registroErroriProvider).haErrori();
    if (!mounted) return;
    setState(() {
      _controlloAttivo = attivo;
      _registroPieno = pieno;
    });
  }

  void _messaggio(String testo) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(testo)));
  }

  Future<void> _cambiaControllo(bool v) async {
    setState(() => _controlloAttivo = v);
    await ref.read(controlloAggiornamentiProvider).imposta(attivo: v);
  }

  Future<void> _controllaOra() async {
    setState(() => _controllo = _Controllo.inCorso);
    final e = await ref.read(controlloAggiornamentiProvider).adessoSubito();
    if (!mounted) return;
    setState(() {
      _nuova = e.nuova;
      _controllo = e.errore
          ? _Controllo.errore
          : e.nuova == null
          ? _Controllo.aggiornato
          : _Controllo.nuova;
    });
    // Anche con la Home già aperta, l'avviso si rivede alla prossima apertura dell'app
    ref.invalidate(aggiornamentoDisponibileProvider);
  }

  Future<void> _scarica(NuovaVersione v) async {
    final t = Testi.of(context);
    final ok = await ref.read(apriIndirizzoProvider)(v.indirizzo);
    if (!ok && mounted) _messaggio(t.aggNonApribile);
  }

  Future<void> _condividiRegistro() async {
    final t = Testi.of(context);
    try {
      final testo = await ref.read(registroErroriProvider).leggi();
      final cartella = await ref.read(cartellaTemporaneaProvider)();
      final file = File('${cartella.path}/$nomeFileRegistro');
      await file.writeAsString(testo, flush: true);
      await ref.read(condividiFileProvider)(file);
    } on Exception {
      if (mounted) _messaggio(t.regNonCondiviso);
    }
  }

  Future<void> _svuotaRegistro() async {
    final t = Testi.of(context);
    final conferma = await showModalBottomSheet<bool>(
      context: context,
      sheetAnimationStyle: MotoScrl.foglio(context),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(MisureScrl.spazio),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t.regCancellaChiede,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: MisureScrl.spazio),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(t.annulla),
                    ),
                  ),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: ColoriScrl.pericoloPieno,
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(t.regCancella),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (conferma != true || !mounted) return;
    await ref.read(registroErroriProvider).svuota();
    if (!mounted) return;
    setState(() => _registroPieno = false);
    _messaggio(t.regCancellato);
  }

  Future<void> _rivediSuggerimenti() async {
    final t = Testi.of(context);
    await azzeraSuggerimenti(ref.read(preferenzeProvider));
    if (mounted) _messaggio(t.impSuggerimentiRimessi);
  }

  String _statoControllo(Testi t) => switch (_controllo) {
    _Controllo.fermo => '',
    _Controllo.inCorso => t.aggInCorso,
    _Controllo.aggiornato => t.aggAggiornato,
    _Controllo.errore => t.aggErrore,
    _Controllo.nuova => t.aggDisponibile(_nuova?.versione ?? ''),
  };

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final versione = ref.watch(versioneAppProvider);
    final stato = _statoControllo(t);
    return Scaffold(
      appBar: AppBar(title: Text(t.impostazioni)),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('impostazioni-elenco'),
          padding: const EdgeInsets.only(bottom: MisureScrl.spazio),
          children: [
            _Sezione(t.impAiuto),
            _Scheda([
              _Riga(
                chiave: const ValueKey('imp-gesti'),
                icona: Icons.gesture_rounded,
                titolo: t.impGesti,
                sottotitolo: t.impGestiAiuto,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const GestiPage()),
                ),
              ),
              _Riga(
                chiave: const ValueKey('imp-suggerimenti'),
                icona: Icons.lightbulb_outline_rounded,
                titolo: t.impSuggerimenti,
                sottotitolo: t.impSuggerimentiAiuto,
                onTap: _rivediSuggerimenti,
              ),
            ]),
            _Sezione(t.impAggiornamenti),
            _Scheda([
              _RigaInterruttore(
                chiave: const ValueKey('imp-controllo'),
                titolo: t.aggControlla,
                sottotitolo: t.aggControllaAiuto,
                valore: _controlloAttivo,
                onCambia: (v) => unawaited(_cambiaControllo(v)),
              ),
              _Riga(
                chiave: const ValueKey('imp-controlla-ora'),
                icona: Icons.sync_rounded,
                titolo: t.aggControllaOra,
                sottotitolo: stato.isEmpty ? null : stato,
                onTap: _controllo == _Controllo.inCorso
                    ? null
                    : () => unawaited(_controllaOra()),
              ),
              if (_nuova != null && _controllo == _Controllo.nuova)
                _Riga(
                  chiave: const ValueKey('imp-scarica'),
                  icona: Icons.download_rounded,
                  titolo: t.aggScarica,
                  sottotitolo: _nuova!.tag,
                  onTap: () => unawaited(_scarica(_nuova!)),
                ),
            ]),
            _Sezione(t.impRegistro),
            _Testo(t.regAiuto),
            _Scheda([
              _Riga(
                chiave: const ValueKey('imp-registro-condividi'),
                icona: Icons.ios_share_rounded,
                titolo: t.regCondividi,
                sottotitolo: _registroPieno ? t.regPieno : t.regVuoto,
                onTap: _registroPieno
                    ? () => unawaited(_condividiRegistro())
                    : null,
              ),
              _Riga(
                chiave: const ValueKey('imp-registro-svuota'),
                icona: Icons.delete_outline_rounded,
                titolo: t.regCancella,
                onTap: _registroPieno
                    ? () => unawaited(_svuotaRegistro())
                    : null,
              ),
            ]),
            _Sezione(t.impInfo),
            _Scheda([
              _Riga(
                chiave: const ValueKey('imp-versione'),
                icona: Icons.info_outline_rounded,
                titolo: t.appTitolo,
                sottotitolo: t.impVersione(versione),
              ),
              _Riga(
                chiave: const ValueKey('imp-licenze'),
                icona: Icons.description_outlined,
                titolo: t.impLicenze,
                sottotitolo: t.impLicenzeAiuto,
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: t.appTitolo,
                  applicationVersion: versione,
                ),
              ),
            ]),
            _Testo(t.impPrivacy),
          ],
        ),
      ),
    );
  }
}

/// Titolo di un gruppo di righe.
class _Sezione extends StatelessWidget {
  const _Sezione(this.testo);
  final String testo;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        MisureScrl.spazio,
        MisureScrl.spazio + MisureScrl.spazioPiccolo,
        MisureScrl.spazio,
        MisureScrl.spazioPiccolo,
      ),
      child: Text(
        testo,
        style: const TextStyle(
          fontSize: TestoScrl.normale,
          fontWeight: TestoScrl.marcato,
          color: ColoriScrl.testoSecondario,
        ),
      ),
    ),
  );
}

/// Paragrafo di spiegazione tra le righe.
class _Testo extends StatelessWidget {
  const _Testo(this.testo);
  final String testo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: MisureScrl.spazio,
      vertical: MisureScrl.spazioPiccolo,
    ),
    child: Text(
      testo,
      style: const TextStyle(
        fontSize: TestoScrl.normale,
        color: ColoriScrl.testoSecondario,
      ),
    ),
  );
}

/// Riga con icona, titolo e sottotitolo; senza [onTap] è solo informativa o spenta.
class _Riga extends StatelessWidget {
  const _Riga({
    required this.icona,
    required this.titolo,
    this.sottotitolo,
    this.onTap,
    this.chiave,
  }) : super(key: chiave);

  final Key? chiave;
  final IconData icona;
  final String titolo;
  final String? sottotitolo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final attiva = onTap != null;
    final colore = attiva ? ColoriScrl.testo : ColoriScrl.testoSpento;
    return Semantics(
      button: onTap != null,
      enabled: attiva || sottotitolo != null,
      label: sottotitolo == null ? titolo : '$titolo. $sottotitolo',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: MisureScrl.tocco + 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MisureScrl.spazio,
              vertical: MisureScrl.spazioPiccolo,
            ),
            child: Row(
              children: [
                Icon(icona, color: colore),
                const SizedBox(width: MisureScrl.spazio),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titolo,
                        style: TextStyle(
                          fontSize: TestoScrl.grande,
                          color: colore,
                        ),
                      ),
                      if (sottotitolo != null)
                        Text(
                          sottotitolo!,
                          style: const TextStyle(
                            fontSize: TestoScrl.normale,
                            color: ColoriScrl.testoSecondario,
                          ),
                        ),
                    ],
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

/// Riga con un interruttore a destra: tutta la riga è toccabile.
class _RigaInterruttore extends StatelessWidget {
  const _RigaInterruttore({
    required this.titolo,
    required this.sottotitolo,
    required this.valore,
    required this.onCambia,
    this.chiave,
  }) : super(key: chiave);

  final Key? chiave;
  final String titolo;
  final String sottotitolo;
  final bool valore;
  final ValueChanged<bool> onCambia;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: valore,
      label: '$titolo. $sottotitolo',
      excludeSemantics: true,
      onTap: () => onCambia(!valore),
      child: InkWell(
        onTap: () => onCambia(!valore),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: MisureScrl.tocco + 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MisureScrl.spazio,
              vertical: MisureScrl.spazioPiccolo,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titolo,
                        style: const TextStyle(
                          fontSize: TestoScrl.grande,
                          color: ColoriScrl.testo,
                        ),
                      ),
                      Text(
                        sottotitolo,
                        style: const TextStyle(
                          fontSize: TestoScrl.normale,
                          color: ColoriScrl.testoSecondario,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: MisureScrl.spazio),
                ExcludeSemantics(
                  child: IgnorePointer(
                    child: Switch(value: valore, onChanged: onCambia),
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

/// Gruppo di righe in una scheda con gli angoli arrotondati (12 dp), separate da una linea sottile.
class _Scheda extends StatelessWidget {
  const _Scheda(this.figli);
  final List<Widget> figli;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: MisureScrl.spazio),
    child: Material(
      color: ColoriScrl.rilievo,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MisureScrl.angoloTessera),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < figli.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                indent: MisureScrl.spazio,
                endIndent: MisureScrl.spazio,
                color: ColoriScrl.separatore,
              ),
            figli[i],
          ],
        ],
      ),
    ),
  );
}
