// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class TestiIt extends Testi {
  TestiIt([String locale = 'it']) : super(locale);

  @override
  String get appTitolo => 'ScrolleR Studio';

  @override
  String get homeVuotaTitolo => 'Nessun progetto';

  @override
  String get homeVuotaAiuto => 'Crea il tuo primo carosello';

  @override
  String get nuovoProgetto => 'Nuovo';

  @override
  String get inArrivo => 'In arrivo nelle prossime versioni';

  @override
  String get proveApri => 'Prove';

  @override
  String get proveTitolo => 'Prove della Fase 2';

  @override
  String get proveGalleria => 'Galleria';

  @override
  String get accessoCompleto => 'Accesso a tutte le foto e i video';

  @override
  String get accessoParziale => 'Accesso solo alle foto e ai video scelti';

  @override
  String get accessoNegato => 'Nessun accesso alla galleria';

  @override
  String get accessoDaChiedere =>
      'Le foto restano nella galleria: il progetto le collega senza copiarle.';

  @override
  String get consentiAccesso => 'Consenti accesso';

  @override
  String get scegliAltreFoto => 'Scegli altre foto';

  @override
  String get apriImpostazioni => 'Apri impostazioni';

  @override
  String get scegliDalTelefono => 'Scegli dal telefono';

  @override
  String fileCopiati(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n file copiati nel progetto',
      one: '1 file copiato nel progetto',
    );
    return '$_temp0';
  }

  @override
  String get creaPagina => 'Crea pagina';

  @override
  String get esportaVideo => 'Esporta MP4';

  @override
  String get progettiDiProva => 'Progetti dal computer';

  @override
  String progettiDiProvaAiuto(String cartella) {
    return 'Copia ogni progetto in una sua cartella (con .scrlproj e media/) in: $cartella';
  }

  @override
  String paginaDiTotale(int numero, int totale) {
    return 'Pagina $numero di $totale';
  }

  @override
  String get fotoMancante => 'Foto mancante';

  @override
  String get originaleMancante => 'Originale mancante';

  @override
  String get numeroPaginaDi => 'di';

  @override
  String get esportazioneInCorso => 'Esportazione MP4…';

  @override
  String get annulla => 'Annulla';

  @override
  String videoFatto(int fotogrammi, String ms) {
    return 'MP4 salvato nella galleria: $fotogrammi fotogrammi, $ms ms per fotogramma';
  }

  @override
  String videoErrore(String errore) {
    return 'Esportazione non riuscita: $errore';
  }

  @override
  String get videoAnnullato => 'Esportazione annullata';

  @override
  String get videoNonDisponibile =>
      'I video non sono ancora disponibili su questo telefono';

  @override
  String get scegliUnVideo => 'Scegli almeno un video';

  @override
  String get progettoNonValido => 'Progetto non leggibile';
}
