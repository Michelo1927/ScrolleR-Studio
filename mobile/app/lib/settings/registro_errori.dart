/// Registro degli errori locale (piano §12, Fase 10): l'equivalente di `crashlog.py` del desktop.
///
/// Gli errori che nessuno ha gestito (Flutter e codice asincrono) finiscono in `errori.log` nella cartella dei
/// documenti dell'app. Il file **non lascia mai il telefono da solo**: l'utente lo condivide da Impostazioni se
/// vuole segnalare un problema. Niente tracciamento, niente invio automatico.
///
/// Prima di scrivere si tolgono i percorsi del telefono (cartella dell'app, galleria, URI dei contenuti), così
/// chi riceve il file non vede nomi di cartelle o di foto personali.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Oltre questa dimensione il registro vecchio passa a `errori.log.old` (non cresce all'infinito).
const int limiteRegistroByte = 512 * 1024;

/// Voci scritte al massimo in una sessione: un errore che si ripete in ciclo non riempie il telefono.
const int vociMassimeSessione = 200;

class RegistroErrori {
  /// Registro su file. [radice] è la cartella dell'app, che compare nei percorsi e va tolta dal testo.
  RegistroErrori(this.file, {this.versione = '', this.radice});

  /// Registro solo in memoria (prove): niente può toccare un file vero.
  RegistroErrori.inMemoria({this.versione = ''}) : file = null, radice = null;

  final File? file;
  final String versione;
  final String? radice;

  final List<String> _memoria = [];
  int _scritte = 0;

  /// Percorsi del telefono che non devono finire nel registro.
  static final RegExp _percorsi = RegExp(
    r'''(?:content://|file://)[^\s'")]+|/(?:storage|sdcard|data|private|var)/[^\s'")]+''',
  );

  /// Testo senza percorsi personali.
  String ripulisci(String testo) {
    var t = testo;
    final r = radice;
    if (r != null && r.isNotEmpty) t = t.replaceAll(r, '<app>');
    return t.replaceAll(_percorsi, '<percorso>');
  }

  /// Apre la sessione: se il file è troppo grande lo archivia, poi scrive l'intestazione.
  Future<void> avvia() async {
    final f = file;
    if (f == null) return;
    try {
      await f.parent.create(recursive: true);
      if (f.existsSync() && f.lengthSync() > limiteRegistroByte) {
        final vecchio = File('${f.path}.old');
        if (vecchio.existsSync()) vecchio.deleteSync();
        f.renameSync(vecchio.path);
      }
    } on FileSystemException {
      // Il registro è un di più: se non si può preparare, si va avanti senza
    }
    _scrivi('=== Avvio ${_ora()} — ScrolleR Studio Mobile $versione ===');
  }

  /// Aggiunge un errore (con la sua traccia). Non lancia mai: un errore nel registro non deve causarne altri.
  void registra(
    Object errore,
    StackTrace? traccia, {
    String contesto = 'Errore',
  }) {
    if (_scritte >= vociMassimeSessione) return;
    _scritte++;
    _scrivi(
      '--- $contesto ${_ora()} ---\n${ripulisci('$errore')}'
      '${traccia == null ? '' : '\n${ripulisci('$traccia')}'}',
    );
  }

  void _scrivi(String voce) {
    _memoria.add(voce);
    final f = file;
    if (f == null) return;
    try {
      // Sincrono: se l'app sta per chiudersi la riga deve essere già su disco
      f.writeAsStringSync('\n$voce\n', mode: FileMode.append, flush: true);
    } on FileSystemException {
      // Disco pieno o file non scrivibile: resta quello in memoria
    }
  }

  /// Errori registrati da quando l'app è partita (le intestazioni di avvio non contano).
  int get numeroErrori => _memoria.where((v) => v.startsWith('---')).length;

  /// Contenuto del registro: quello su file se c'è, altrimenti quello della sessione.
  Future<String> leggi() async {
    final f = file;
    if (f == null) return _memoria.join('\n\n');
    try {
      return f.existsSync() ? await f.readAsString() : '';
    } on FileSystemException {
      return _memoria.join('\n\n');
    }
  }

  /// Il file esiste e ha qualcosa oltre alle intestazioni di avvio.
  Future<bool> haErrori() async {
    final t = await leggi();
    return RegExp(r'(^|\n)--- ').hasMatch(t);
  }

  /// Svuota il registro (anche il file archiviato) e riparte con una nuova intestazione.
  Future<void> svuota() async {
    _memoria.clear();
    _scritte = 0;
    final f = file;
    if (f != null) {
      try {
        if (f.existsSync()) f.deleteSync();
        final vecchio = File('${f.path}.old');
        if (vecchio.existsSync()) vecchio.deleteSync();
      } on FileSystemException {
        // Non cancellabile: pazienza
      }
    }
    _scrivi(
      '=== Registro svuotato ${_ora()} — ScrolleR Studio Mobile $versione ===',
    );
  }

  static String _ora() {
    final n = DateTime.now();
    String d(int v, [int w = 2]) => v.toString().padLeft(w, '0');
    return '${n.year}-${d(n.month)}-${d(n.day)} ${d(n.hour)}:${d(n.minute)}:${d(n.second)}';
  }
}

/// Registro degli errori: lo fornisce `main()` con il file vero.
final registroErroriProvider = Provider<RegistroErrori>(
  (ref) => RegistroErrori.inMemoria(),
);

/// Manda un file al foglio Condividi di sistema (le prove lo sostituiscono).
final condividiFileProvider = Provider<Future<void> Function(File file)>(
  (ref) =>
      (file) => SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: 'text/plain')]),
      ),
);
