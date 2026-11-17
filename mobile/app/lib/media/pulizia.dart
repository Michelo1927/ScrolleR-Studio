/// Pulizia all'avvio (Fase 10, memoria e spazio): le cartelle temporanee che un'esportazione, uno scambio o
/// un'importazione interrotti possono aver lasciato. Il sistema le ripulisce da sé, ma solo quando gli pare: qui
/// si tolgono subito quelle vecchie, senza toccare quelle di un lavoro in corso.
library;

import 'dart:io';

/// Cartelle temporanee dell'app (nomi fissi o con un prefisso) e dopo quanto sono da buttare.
const List<String> prefissiTemporanei = [
  'esportazione_',
  'condividi',
  'importa',
];
const Duration etaTemporanei = Duration(hours: 24);

/// Toglie da [temporanea] le voci dell'app più vecchie di [eta]. Ritorna quante ne ha tolte; non lancia mai.
Future<int> puliziaTemporanei(
  Directory temporanea, {
  Duration eta = etaTemporanei,
  DateTime? adesso,
}) async {
  if (!temporanea.existsSync()) return 0;
  final limite = (adesso ?? DateTime.now()).subtract(eta);
  var tolti = 0;
  try {
    await for (final e in temporanea.list()) {
      final nome = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (!prefissiTemporanei.any(nome.startsWith)) continue;
      try {
        if (e.statSync().modified.isAfter(limite)) continue;
        await e.delete(recursive: true);
        tolti++;
      } on FileSystemException {
        // In uso o già sparita: ci si riprova al prossimo avvio
      }
    }
  } on FileSystemException {
    // Cartella illeggibile: niente da fare
  }
  return tolti;
}
