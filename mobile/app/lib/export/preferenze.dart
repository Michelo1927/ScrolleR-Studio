/// Preferenze dell'app ricordate tra una sessione e l'altra (piano §11): formato, qualità e scala dell'esportazione.
/// Stanno in un piccolo file JSON nella cartella dei documenti; fuori dal progetto, come `QSettings` sul desktop
/// (il nome dei file invece vale per il progetto e si salva con lui, `export_name`).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrl_engine/scrl_engine.dart';

import 'codifica.dart';

/// Come si esporta: tipo di file, qualità del JPG (100 / 95 / 92 / 85 / 75) e scala (1× / 2×).
class OpzioniEsportazione {
  const OpzioniEsportazione({
    this.formato = FormatoImmagine.png,
    this.qualita = qualitaJpgPredefinita,
    this.scala = scalaEsportazionePredefinita,
  });

  final FormatoImmagine formato;
  final int qualita;
  final int scala;

  OpzioniEsportazione copia({
    FormatoImmagine? formato,
    int? qualita,
    int? scala,
  }) => OpzioniEsportazione(
    formato: formato ?? this.formato,
    qualita: qualita ?? this.qualita,
    scala: scala ?? this.scala,
  );

  Map<String, Object?> toJson() => {
    'format': formato.name,
    'quality': qualita,
    'scale': scala,
  };

  /// Legge le opzioni: ogni campo ha un predefinito e i valori fuori elenco si portano al più vicino valido.
  factory OpzioniEsportazione.fromJson(Object? m) {
    if (m is! Map) return const OpzioniEsportazione();
    final f = m['format'];
    final q = m['quality'];
    final s = m['scale'];
    return OpzioniEsportazione(
      formato: f == 'jpg' ? FormatoImmagine.jpg : FormatoImmagine.png,
      qualita: q is num ? qualitaJpgValida(q.round()) : qualitaJpgPredefinita,
      scala: s is num ? scalaValida(s.round()) : scalaEsportazionePredefinita,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is OpzioniEsportazione &&
      other.formato == formato &&
      other.qualita == qualita &&
      other.scala == scala;

  @override
  int get hashCode => Object.hash(formato, qualita, scala);
}

/// File delle preferenze. Senza [file] vive solo in memoria (prove): niente può sporcare quelle vere.
class PreferenzeApp {
  PreferenzeApp(this.file);
  PreferenzeApp.inMemoria() : file = null;

  final File? file;
  Map<String, Object?> _dati = {};
  bool _lette = false;

  Future<void> _leggi() async {
    if (_lette) return;
    _lette = true;
    final f = file;
    if (f == null || !f.existsSync()) return;
    try {
      final m = jsonDecode(await f.readAsString());
      if (m is Map<String, Object?>) _dati = m;
    } on FormatException {
      // File rovinato: si riparte dai predefiniti
    } on FileSystemException {
      // Non leggibile: idem
    }
  }

  Future<OpzioniEsportazione> esportazione() async {
    await _leggi();
    return OpzioniEsportazione.fromJson(_dati['export']);
  }

  Future<void> salvaEsportazione(OpzioniEsportazione o) =>
      scrivi('export', o.toJson());

  /// Valore ricordato sotto [chiave] (null se manca): le altre preferenze (suggerimenti visti, controllo degli
  /// aggiornamenti) usano questo e [scrivi]. Chiavi sconosciute si conservano.
  Future<Object?> leggi(String chiave) async {
    await _leggi();
    return _dati[chiave];
  }

  /// Interruttore ricordato sotto [chiave], con il suo [predefinito] se manca o non è un booleano.
  Future<bool> leggiBool(String chiave, {required bool predefinito}) async {
    final v = await leggi(chiave);
    return v is bool ? v : predefinito;
  }

  /// Numero intero ricordato sotto [chiave] (null se manca).
  Future<int?> leggiInt(String chiave) async {
    final v = await leggi(chiave);
    return v is num ? v.round() : null;
  }

  /// Elenco di testi ricordato sotto [chiave] (vuoto se manca; gli elementi che non sono testi si scartano).
  Future<List<String>> leggiTesti(String chiave) async {
    final v = await leggi(chiave);
    return v is List ? [for (final e in v) ?(e is String ? e : null)] : [];
  }

  /// Ricorda [valore] sotto [chiave] e riscrive il file (atomico). Con `null` la chiave si toglie.
  Future<void> scrivi(String chiave, Object? valore) async {
    await _leggi();
    _dati = {..._dati};
    if (valore == null) {
      _dati.remove(chiave);
    } else {
      _dati[chiave] = valore;
    }
    final f = file;
    if (f == null) return;
    try {
      await f.parent.create(recursive: true);
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode(_dati), flush: true);
      await tmp.rename(f.path);
    } on FileSystemException {
      // Le preferenze non sono essenziali: restano quelle di questa sessione
    }
  }
}

/// Preferenze dell'app: le fornisce `main()` con la cartella dei documenti.
final preferenzeProvider = Provider<PreferenzeApp>(
  (ref) => PreferenzeApp.inMemoria(),
);
