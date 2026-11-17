/// Caratteri inclusi nell'app (piano §8.5). Il desktop usa i font del PC, che sul telefono non ci sono: l'app ne
/// porta 20 con licenza libera (SIL OFL e Apache 2.0, i testi sono in `assets/fonts/LICENZE.txt`), ridotti al
/// latino da `tools/prepara_font.py`.
///
/// Un progetto può usare un carattere che qui non c'è (per esempio «Segoe UI Variable Display», il predefinito del
/// desktop): la tela lo disegna con [Caratteri.predefinito] ma **il nome resta nel file** finché l'utente non ne
/// sceglie un altro, così il progetto si riapre sul PC con il suo carattere.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Gruppi in cui si presentano i caratteri nello strumento Carattere.
enum CategoriaCarattere { senzaGrazie, conGrazie, titolo, aMano, monospazio }

class Carattere {
  const Carattere(this.famiglia, this.categoria);

  /// Nome della famiglia, quello che si scrive nel campo `font` del progetto e in `pubspec.yaml`.
  final String famiglia;
  final CategoriaCarattere categoria;
}

abstract final class Caratteri {
  /// Carattere dei testi nuovi e di quelli il cui carattere manca: ha grassetto e corsivo veri.
  static const String predefinito = 'Inter';

  /// I 20 caratteri inclusi, nell'ordine in cui si presentano.
  static const List<Carattere> tutti = [
    Carattere('Inter', CategoriaCarattere.senzaGrazie),
    Carattere('Montserrat', CategoriaCarattere.senzaGrazie),
    Carattere('Poppins', CategoriaCarattere.senzaGrazie),
    Carattere('Nunito', CategoriaCarattere.senzaGrazie),
    Carattere('Raleway', CategoriaCarattere.senzaGrazie),
    Carattere('Playfair Display', CategoriaCarattere.conGrazie),
    Carattere('Lora', CategoriaCarattere.conGrazie),
    Carattere('Merriweather', CategoriaCarattere.conGrazie),
    Carattere('Cormorant Garamond', CategoriaCarattere.conGrazie),
    Carattere('Bebas Neue', CategoriaCarattere.titolo),
    Carattere('Anton', CategoriaCarattere.titolo),
    Carattere('Oswald', CategoriaCarattere.titolo),
    Carattere('Abril Fatface', CategoriaCarattere.titolo),
    Carattere('Alfa Slab One', CategoriaCarattere.titolo),
    Carattere('Pacifico', CategoriaCarattere.aMano),
    Carattere('Dancing Script', CategoriaCarattere.aMano),
    Carattere('Caveat', CategoriaCarattere.aMano),
    Carattere('Permanent Marker', CategoriaCarattere.aMano),
    Carattere('JetBrains Mono', CategoriaCarattere.monospazio),
    Carattere('Space Mono', CategoriaCarattere.monospazio),
  ];

  static final Map<String, Carattere> _perNome = {
    for (final c in tutti) _chiave(c.famiglia): c,
  };

  static String _chiave(String nome) => nome.trim().toLowerCase();

  /// Il carattere incluso con questo nome (senza badare a maiuscole e spazi ai lati), o null.
  static Carattere? trova(String nome) => _perNome[_chiave(nome)];

  /// Il carattere [nome] è incluso nell'app.
  static bool incluso(String nome) => trova(nome) != null;

  /// La famiglia con cui disegnare [nome]: lui stesso se è incluso, altrimenti [predefinito]. Non cambia il
  /// progetto: chi chiama continua a tenere il nome originale.
  static String perDisegno(String nome) => trova(nome)?.famiglia ?? predefinito;

  static List<Carattere> dellaCategoria(CategoriaCarattere c) => [
    for (final x in tutti)
      if (x.categoria == c) x,
  ];

  /// Categoria in cui si apre lo strumento per un testo che usa [nome] (la prima se il carattere manca).
  static CategoriaCarattere categoriaDi(String nome) =>
      trova(nome)?.categoria ?? CategoriaCarattere.senzaGrazie;
}

/// Registra le licenze dei font perché compaiano nella pagina «Licenze» dell'app (le richiede la OFL).
void registraLicenzeCaratteri() {
  LicenseRegistry.addLicense(() async* {
    final testo = await rootBundle.loadString('assets/fonts/LICENZE.txt');
    yield LicenseEntryWithLineBreaks([
      for (final c in Caratteri.tutti) c.famiglia,
    ], testo);
  });
}
