/// Scambio dei progetti dalla Home (piano §6 e Fase 9): «Condividi progetto» (zip), «Importa progetto» (zip o
/// `.scrlproj`) e i file che arrivano da un'altra app («Apri con», «Condividi con»). Ogni lavoro lungo ha la sua pagina
/// con avanzamento e Annulla ([PaginaLavoro]).
library;

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' show ProjectFormatException;
import 'package:share_plus/share_plus.dart';

import '../editor/apri_editor.dart';
import '../export/consegna.dart';
import '../l10n/app_localizations.dart';
import '../project/archivio.dart';
import '../project/lavoro.dart';
import '../project/provider.dart';
import '../project/ricevuti.dart';
import '../project/scambio.dart';
import '../project/zip.dart';
import 'home.dart';
import 'pagina_lavoro.dart';

/// Come si sceglie un file da importare (il selettore di sistema; le prove lo sostituiscono). I file scelti si
/// copiano nella cartella temporanea dell'app, a blocchi.
final selettoreFileProvider =
    Provider<Future<List<FileRicevuto>> Function(String titolo)>((ref) {
      final temp = ref.watch(cartellaTemporaneaProvider);
      return (titolo) async {
        final scelti = await FilePicker.pickFiles(dialogTitle: titolo);
        if (scelti.isEmpty) return const [];
        final cartella = Directory('${(await temp()).path}/importa');
        await cartella.create(recursive: true);
        final out = <FileRicevuto>[];
        for (final f in scelti) {
          final dest = File(
            '${cartella.path}/${DateTime.now().microsecondsSinceEpoch}_${f.name}',
          );
          final sink = dest.openWrite();
          try {
            await sink.addStream(f.readAsByteStream());
          } finally {
            await sink.close();
          }
          out.add(
            FileRicevuto(percorso: dest.path, nome: f.name, temporaneo: true),
          );
        }
        return out;
      };
    });

/// Come si consegna lo `.zip` del progetto (il foglio Condividi di sistema; le prove lo sostituiscono).
final condivisioneProgettoProvider =
    Provider<Future<void> Function(File zip, String nome)>(
      (ref) => (zip, nome) async {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(zip.path, mimeType: 'application/zip')],
            subject: nome,
            title: nome,
          ),
        );
      },
    );

/// Peso leggibile: «3,2 MB», «840 KB».
String formatoDimensione(int byte) {
  if (byte >= 1 << 20) return '${(byte / (1 << 20)).toStringAsFixed(1)} MB';
  return '${(byte / 1024).ceil()} KB';
}

/// Errori dei lavori di scambio, in parole.
EsitoLavoro esitoDaErrore(Testi t, Object e) {
  final String testo;
  if (e is SpazioInsufficiente || eDiscoPieno(e)) {
    testo = t.zipSpazio;
  } else if (e is ImportazioneNonRiuscita) {
    testo = switch (e.motivo) {
      MotivoImportazione.nonRiconosciuto => t.impNonRiconosciuto,
      MotivoImportazione.nessunProgetto => t.impNessunProgetto,
      MotivoImportazione.progettoNonValido => t.impNonValido,
    };
  } else if (e is ZipNonSupportato) {
    testo = t.impZipNonSupportato(e.messaggio);
  } else if (e is ZipNonValido || e is ProjectFormatException) {
    testo = t.impNonValido;
  } else {
    testo = t.impErrore(e.toString());
  }
  return EsitoLavoro(titolo: t.espIncompleta, testo: testo, riuscito: false);
}

// ===================================================================== Condividi progetto

/// «Condividi progetto»: crea lo `.zip` (progetto + originali di tutte le foto e i video in `media/`) e apre il foglio
/// Condividi. Il progetto sul telefono non cambia.
Future<void> condividiProgetto(
  BuildContext context,
  WidgetRef ref,
  InfoProgetto progetto,
) async {
  final archivio = ref.read(archivioProvider);
  final galleria = ref.read(galleriaProvider);
  final condividi = ref.read(condivisioneProgettoProvider);
  final temp = ref.read(cartellaTemporaneaProvider);
  await apriLavoro(
    context,
    titolo: Testi.of(context).condividiProgetto,
    daErrore: esitoDaErrore,
    esegui: (c, avanza, stop) async {
      final t = Testi.of(c);
      avanza(null, t.scambioPreparo);
      final caricato = await archivio.carica(progetto.cartella);
      final piano = await PianoZip.prepara(
        progetto: caricato,
        galleria: galleria,
        annullamento: stop,
      );
      if (piano.haProblemi) {
        if (!c.mounted || !await _confermaZip(c, piano)) {
          throw const LavoroAnnullato();
        }
      }
      final cartella = Directory('${(await temp()).path}/condividi');
      await cartella.create(recursive: true);
      final zip = await piano.scrivi(
        cartella,
        progresso: (f, nome) => avanza(f, t.zipFile(nome)),
        annullamento: stop,
      );
      try {
        avanza(1, t.scambioPreparo);
        await condividi(zip, piano.nome);
      } finally {
        try {
          await zip.delete();
        } on FileSystemException {
          // La cartella temporanea la pulisce il sistema
        }
      }
      return EsitoLavoro(
        titolo: t.zipPronto,
        testo: t.zipPronto2(
          piano.copiati + piano.soloAnteprima.length,
          formatoDimensione(piano.byteTotali),
        ),
      );
    },
  );
}

Future<bool> _confermaZip(BuildContext context, PianoZip piano) async {
  final t = Testi.of(context);
  final r = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(t.zipAvvisoTitolo),
      content: Text(
        [
          if (piano.soloAnteprima.isNotEmpty)
            t.zipSoloAnteprima(piano.soloAnteprima.length),
          if (piano.mancanti.isNotEmpty) t.zipMancanti(piano.mancanti.length),
        ].join('\n\n'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(d).pop(false),
          child: Text(t.annulla),
        ),
        FilledButton(
          key: const ValueKey('zip-continua'),
          onPressed: () => Navigator.of(d).pop(true),
          child: Text(t.zipContinua),
        ),
      ],
    ),
  );
  return r ?? false;
}

// ===================================================================== Importa

/// «Importa progetto» dalla Home: sceglie un file (`.zip` o `.scrlproj`) e lo importa.
Future<void> scegliEImporta(BuildContext context, WidgetRef ref) async {
  final t = Testi.of(context);
  final scelti = await ref.read(selettoreFileProvider)(t.impScegli);
  if (scelti.isEmpty || !context.mounted) return;
  await importaFile(context, ref, scelti);
}

/// Importa i file [file]: ogni `.zip` / `.scrlproj` diventa un progetto; foto e video (da «Condividi con») finiscono
/// insieme in un progetto nuovo. Chiede di aprire il progetto nato (l'ultimo, se sono più d'uno e l'utente lo vuole).
Future<void> importaFile(
  BuildContext context,
  WidgetRef ref,
  List<FileRicevuto> file,
) async {
  final archivio = ref.read(archivioProvider);
  final progetti = [
    for (final f in file)
      if (f.eProgetto) f,
  ];
  final media = [
    for (final f in file)
      if (f.eMedia) f,
  ];
  Directory? daAprire;
  for (final f in progetti) {
    if (!context.mounted) return;
    final t = Testi.of(context);
    daAprire = await apriLavoro(
      context,
      titolo: t.importaProgetto,
      daErrore: esitoDaErrore,
      esegui: (c, avanza, stop) async {
        final t = Testi.of(c);
        avanza(null, t.impFile(f.nome));
        try {
          final e = await importaProgetto(
            archivio: archivio,
            sorgente: File(f.percorso),
            nomeOriginale: f.nome,
            avanza: (fr, nome) => avanza(fr, t.impFile(nome)),
            annullamento: stop,
          );
          return EsitoLavoro(
            titolo: t.impFatto(e.nome),
            testo: [
              t.impEstratti(e.fileEstratti),
              if (e.altriProgetti > 0) t.impAltriProgetti(e.altriProgetti),
            ].join('\n'),
            progetto: e.cartella,
          );
        } finally {
          if (f.temporaneo) await eliminaTemporaneo(f);
        }
      },
    );
    if (daAprire != null) break;
  }
  if (daAprire == null && media.isNotEmpty && context.mounted) {
    final t = Testi.of(context);
    final numero = (await archivio.elenco()).length + 1;
    if (!context.mounted) return;
    daAprire = await apriLavoro(
      context,
      titolo: t.importaProgetto,
      daErrore: esitoDaErrore,
      esegui: (c, avanza, stop) async {
        final t = Testi.of(c);
        final e = await creaProgettoDaFile(
          archivio: archivio,
          file: media,
          nome: t.nomeProgettoNuovo(numero),
          avanza: avanza,
          annullamento: stop,
        );
        return EsitoLavoro(
          titolo: t.impDaFoto(e.foto),
          testo: e.scartati.isEmpty ? '' : t.impScartati(e.scartati.join(', ')),
          progetto: e.cartella,
        );
      },
    );
  }
  if (progetti.isEmpty && media.isEmpty) {
    for (final f in file) {
      if (f.temporaneo) await eliminaTemporaneo(f);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Testi.of(context).impNonRiconosciuto)),
      );
    }
  }
  if (context.mounted) ref.invalidate(progettiProvider);
  if (daAprire != null && context.mounted) {
    await apriProgetto(context, ref, daAprire);
    if (context.mounted) ref.invalidate(progettiProvider);
  }
}

// ===================================================================== «Apri con» / «Condividi con»

/// Sta sopra la Home e ascolta i file che arrivano da un'altra app: all'avvio (l'app è stata aperta da lì) e mentre è
/// aperta. Se c'è già un editor aperto, ci si torna prima alla Home (l'editor salva da sé quando l'app va in secondo
/// piano e quando si esce).
class AscoltaFileRicevuti extends ConsumerStatefulWidget {
  const AscoltaFileRicevuti({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AscoltaFileRicevuti> createState() =>
      _AscoltaFileRicevutiState();
}

class _AscoltaFileRicevutiState extends ConsumerState<AscoltaFileRicevuti> {
  late final Ricevitore _ricevitore = ref.read(ricevitoreProvider);
  Future<void> _coda = Future.value();

  @override
  void initState() {
    super.initState();
    _ricevitore.ascolta(_arrivati);
    // Dopo il primo disegno: serve un contesto con Navigator e testi
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final l = await _ricevitore.iniziali();
      if (l.isNotEmpty) _arrivati(l);
    });
  }

  @override
  void dispose() {
    _ricevitore.smetti();
    super.dispose();
  }

  /// Un arrivo alla volta: se ne arrivano due di seguito, il secondo aspetta la fine del primo.
  void _arrivati(List<FileRicevuto> file) {
    _coda = _coda.then((_) async {
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
      await importaFile(context, ref, file);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
