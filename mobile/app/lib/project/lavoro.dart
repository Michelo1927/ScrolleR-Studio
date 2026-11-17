/// Lavori lunghi (zip, importazione, ricerca nella galleria): avanzamento e Annulla (piano §14: oltre 1 s).
library;

/// L'utente ha annullato il lavoro in corso.
class LavoroAnnullato implements Exception {
  const LavoroAnnullato();
  @override
  String toString() => 'Lavoro annullato';
}

/// Interruttore di Annulla: chi lavora lo controlla tra un blocco e l'altro.
class Annullamento {
  bool _annullato = false;
  bool get annullato => _annullato;
  void annulla() => _annullato = true;

  /// Lancia [LavoroAnnullato] se è stato premuto Annulla.
  void controlla() {
    if (_annullato) throw const LavoroAnnullato();
  }
}

/// Avanzamento di un lavoro: [frazione] da 0 a 1 (null = non misurabile) e il testo di ciò che si sta facendo.
typedef Avanza = void Function(double? frazione, String testo);
