/// Home (piano §4.1): griglia dei progetti con miniatura, nome, pagine e data; pulsante grande «Nuovo» in basso;
/// pressione lunga su un progetto per Rinomina, Duplica, Elimina (fogli dal basso, niente finestre al centro).
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../editor/apri_editor.dart';
import '../editor/widget_comuni.dart';
import '../l10n/app_localizations.dart';
import '../project/archivio.dart';
import '../project/provider.dart';
import '../settings/aggiornamenti.dart';
import '../settings/impostazioni_page.dart';
import '../theme/tokens.dart';
import 'nuovo_progetto.dart';
import 'prove.dart';
import 'scambio_ui.dart';

/// Progetti dell'archivio, i più recenti per primi.
final progettiProvider = FutureProvider.autoDispose<List<InfoProgetto>>(
  (ref) => ref.watch(archivioProvider).elenco(),
);

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  Future<void> _nuovo(BuildContext context, WidgetRef ref) async {
    final cartella = await Navigator.of(context).push<Directory>(
      MaterialPageRoute(builder: (_) => const NuovoProgettoPage()),
    );
    if (cartella == null || !context.mounted) return;
    await _apri(context, ref, cartella);
  }

  Future<void> _apri(
    BuildContext context,
    WidgetRef ref,
    Directory cartella,
  ) async {
    await apriProgetto(context, ref, cartella);
    ref.invalidate(progettiProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final progetti = ref.watch(progettiProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.appTitolo),
        actions: [
          PulsanteIcona(
            key: const ValueKey('home-importa'),
            icona: Icons.file_open_outlined,
            etichetta: t.importaProgetto,
            onTap: () => unawaited(scegliEImporta(context, ref)),
          ),
          PulsanteIcona(
            key: const ValueKey('home-impostazioni'),
            icona: Icons.settings_outlined,
            etichetta: t.impostazioni,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ImpostazioniPage()),
            ),
          ),
          // Le prove della Fase 2 restano solo nelle build di sviluppo
          if (kDebugMode)
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ProvePage()),
              ),
              child: Text(t.proveApri),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const _AvvisoAggiornamento(),
            Expanded(
              child: progetti.when(
                data: (l) => l.isEmpty
                    ? const _StatoVuoto()
                    : _Griglia(
                        progetti: l,
                        onApri: (p) => _apri(context, ref, p.cartella),
                        onLungo: (p) => _azioni(context, ref, p),
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const _StatoVuoto(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(MisureScrl.spazio),
          child: FilledButton.icon(
            onPressed: () => _nuovo(context, ref),
            icon: const Icon(Icons.add_rounded),
            label: Text(t.nuovoProgetto),
          ),
        ),
      ),
    );
  }

  /// Foglio dal basso con le azioni del progetto.
  Future<void> _azioni(
    BuildContext context,
    WidgetRef ref,
    InfoProgetto p,
  ) async {
    // Lo spazio si calcola mentre il foglio sale: le azioni si possono già toccare
    final spazio = ref.read(archivioProvider).spazioOccupato(p.cartella);
    final scelta = await showModalBottomSheet<_Azione>(
      context: context,
      sheetAnimationStyle: MotoScrl.foglio(context),
      builder: (context) {
        final t = Testi.of(context);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TestataProgetto(nome: p.nome, spazio: spazio),
              _VoceAzione(Icons.edit_rounded, t.rinomina, _Azione.rinomina),
              _VoceAzione(Icons.copy_rounded, t.duplica, _Azione.duplica),
              _VoceAzione(
                Icons.ios_share_rounded,
                t.condividiProgetto,
                _Azione.condividi,
              ),
              _VoceAzione(
                Icons.delete_outline_rounded,
                t.elimina,
                _Azione.elimina,
                colore: ColoriScrl.pericoloTesto,
              ),
            ],
          ),
        );
      },
    );
    if (scelta == null || !context.mounted) return;
    final archivio = ref.read(archivioProvider);
    switch (scelta) {
      case _Azione.rinomina:
        final nome = await _chiediNome(context, p.nome);
        if (nome != null && nome.trim().isNotEmpty) {
          await archivio.rinomina(p.cartella, nome.trim());
        }
      case _Azione.duplica:
        final t = Testi.of(context);
        await archivio.duplica(p.cartella, t.copiaDi(p.nome));
      case _Azione.condividi:
        await condividiProgetto(context, ref, p);
      case _Azione.elimina:
        if (await _confermaElimina(context, p.nome) ?? false) {
          await archivio.elimina(p.cartella);
        }
    }
    ref.invalidate(progettiProvider);
  }

  Future<String?> _chiediNome(BuildContext context, String attuale) {
    return showModalBottomSheet<String>(
      context: context,
      sheetAnimationStyle: MotoScrl.foglio(context),
      isScrollControlled: true,
      builder: (context) => _FoglioNome(attuale),
    );
  }

  Future<bool?> _confermaElimina(BuildContext context, String nome) {
    return showModalBottomSheet<bool>(
      context: context,
      sheetAnimationStyle: MotoScrl.foglio(context),
      builder: (context) {
        final t = Testi.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(MisureScrl.spazio),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.eliminaProgettoChiede(nome),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: MisureScrl.spazioPiccolo),
                Text(
                  t.eliminaProgettoAiuto,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
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
                        child: Text(t.elimina),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _Azione { rinomina, duplica, condividi, elimina }

/// Testata del foglio delle azioni: il nome del progetto e quanto spazio occupa sul telefono.
class _TestataProgetto extends StatelessWidget {
  const _TestataProgetto({required this.nome, required this.spazio});

  final String nome;
  final Future<int> spazio;

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final stili = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MisureScrl.spazio,
        MisureScrl.spazio,
        MisureScrl.spazio,
        MisureScrl.spazioPiccolo,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(nome, style: stili.titleMedium),
          const SizedBox(height: 4),
          FutureBuilder<int>(
            future: spazio,
            builder: (context, s) {
              final byte = s.data;
              return Row(
                children: [
                  const Icon(
                    Icons.sd_storage_outlined,
                    size: 16,
                    color: ColoriScrl.testoSecondario,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      byte == null
                          ? t.pesoCalcolo
                          : t.pesoProgetto(formatoDimensione(t, byte)),
                      key: const ValueKey('progetto-peso'),
                      style: const TextStyle(
                        fontSize: TestoScrl.normale,
                        color: ColoriScrl.testo,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 2),
          Text(t.pesoNota, style: stili.bodySmall),
        ],
      ),
    );
  }
}

class _VoceAzione extends StatelessWidget {
  const _VoceAzione(this.icona, this.testo, this.azione, {this.colore});

  final IconData icona;
  final String testo;
  final _Azione azione;
  final Color? colore;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => Navigator.of(context).pop(azione),
    child: SizedBox(
      height: MisureScrl.tocco,
      child: Row(
        children: [
          const SizedBox(width: MisureScrl.spazio),
          Icon(icona, color: colore ?? ColoriScrl.testo),
          const SizedBox(width: MisureScrl.spazio),
          Text(
            testo,
            style: TextStyle(
              fontSize: TestoScrl.grande,
              color: colore ?? ColoriScrl.testo,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Foglio con un campo di testo per rinominare (sale con la tastiera).
class _FoglioNome extends StatefulWidget {
  const _FoglioNome(this.attuale);
  final String attuale;

  @override
  State<_FoglioNome> createState() => _FoglioNomeState();
}

class _FoglioNomeState extends State<_FoglioNome> {
  late final _c = TextEditingController(text: widget.attuale);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(MisureScrl.spazio),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _c,
                  autofocus: true,
                  decoration: InputDecoration(labelText: t.nomeProgetto),
                  onSubmitted: (v) => Navigator.of(context).pop(v),
                ),
              ),
              const SizedBox(width: MisureScrl.spazioPiccolo),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_c.text),
                child: Text(t.fatto),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatoVuoto extends StatelessWidget {
  const _StatoVuoto();

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final stili = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.photo_library_outlined,
            size: MisureScrl.tocco,
            color: ColoriScrl.testoSecondario,
          ),
          const SizedBox(height: MisureScrl.spazio),
          Text(t.homeVuotaTitolo, style: stili.titleMedium),
          const SizedBox(height: MisureScrl.spazioPiccolo),
          Text(t.homeVuotaAiuto, style: stili.bodySmall),
        ],
      ),
    );
  }
}

class _Griglia extends StatelessWidget {
  const _Griglia({
    required this.progetti,
    required this.onApri,
    required this.onLungo,
  });

  final List<InfoProgetto> progetti;
  final ValueChanged<InfoProgetto> onApri;
  final ValueChanged<InfoProgetto> onLungo;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(MisureScrl.spazio),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: MisureScrl.spazio,
        crossAxisSpacing: MisureScrl.spazio,
        childAspectRatio: 0.78,
      ),
      itemCount: progetti.length,
      itemBuilder: (context, i) => _Tessera(
        progetto: progetti[i],
        onTap: () => onApri(progetti[i]),
        onLungo: () => onLungo(progetti[i]),
      ),
    );
  }
}

class _Tessera extends ConsumerWidget {
  const _Tessera({
    required this.progetto,
    required this.onTap,
    required this.onLungo,
  });

  final InfoProgetto progetto;
  final VoidCallback onTap;
  final VoidCallback onLungo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final stili = Theme.of(context).textTheme;
    final miniatura = ref
        .read(archivioProvider)
        .fileMiniatura(progetto.cartella);
    final data = MaterialLocalizations.of(context)
        .formatMediumDate(progetto.modificato);
    return Semantics(
      button: true,
      label: '${progetto.nome}, ${t.numeroPagine(progetto.pagine)}, $data',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLungo,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: ColoriScrl.rilievo,
                  borderRadius: BorderRadius.circular(MisureScrl.angoloTessera),
                ),
                clipBehavior: Clip.antiAlias,
                child: miniatura.existsSync()
                    ? Image.file(
                        miniatura,
                        fit: BoxFit.contain,
                        // Cambia a ogni salvataggio: la chiave la rilegge
                        key: ValueKey(miniatura.lastModifiedSync()),
                      )
                    : const Icon(
                        Icons.photo_library_outlined,
                        color: ColoriScrl.testoSpento,
                      ),
              ),
            ),
            const SizedBox(height: MisureScrl.spazioPiccolo),
            Text(
              progetto.nome,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: stili.titleMedium?.copyWith(fontSize: TestoScrl.normale),
            ),
            Text(
              '${t.numeroPagine(progetto.pagine)} · $data',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: stili.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Avviso «È disponibile la versione X» in cima alla Home: «Scarica» apre la pagina della release nel browser,
/// ✕ lo nasconde (quella versione non si riannuncia). Senza versione nuova, o con il controllo spento, non c'è.
class _AvvisoAggiornamento extends ConsumerStatefulWidget {
  const _AvvisoAggiornamento();

  @override
  ConsumerState<_AvvisoAggiornamento> createState() =>
      _AvvisoAggiornamentoState();
}

class _AvvisoAggiornamentoState extends ConsumerState<_AvvisoAggiornamento> {
  bool _nascosto = false;

  @override
  Widget build(BuildContext context) {
    final nuova = ref.watch(aggiornamentoDisponibileProvider).value;
    if (nuova == null || _nascosto) return const SizedBox.shrink();
    final t = Testi.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MisureScrl.spazio,
        MisureScrl.spazioPiccolo,
        MisureScrl.spazio,
        0,
      ),
      child: Semantics(
        liveRegion: true,
        container: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: ColoriScrl.rilievo,
            borderRadius: BorderRadius.circular(MisureScrl.angoloTessera),
          ),
          child: Row(
            children: [
              const SizedBox(width: MisureScrl.spazio),
              const Icon(Icons.system_update_rounded, color: ColoriScrl.testo),
              const SizedBox(width: MisureScrl.spazioPiccolo + 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: MisureScrl.spazioPiccolo,
                  ),
                  child: Text(
                    t.aggDisponibile(nuova.versione),
                    style: const TextStyle(
                      fontSize: TestoScrl.normale,
                      color: ColoriScrl.testo,
                    ),
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('home-aggiornamento-scarica'),
                onPressed: () async {
                  final ok = await ref.read(apriIndirizzoProvider)(
                    nuova.indirizzo,
                  );
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(t.aggNonApribile)));
                  }
                },
                child: Text(t.aggScarica),
              ),
              PulsanteIcona(
                key: const ValueKey('home-aggiornamento-nascondi'),
                icona: Icons.close_rounded,
                etichetta: t.aggChiudi,
                onTap: () {
                  setState(() => _nascosto = true);
                  unawaited(
                    ref.read(controlloAggiornamentiProvider).ignora(nuova),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
