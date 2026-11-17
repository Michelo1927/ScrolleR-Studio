// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class TestiEn extends Testi {
  TestiEn([String locale = 'en']) : super(locale);

  @override
  String get appTitolo => 'ScrolleR Studio';

  @override
  String get homeVuotaTitolo => 'No projects';

  @override
  String get homeVuotaAiuto => 'Create your first carousel';

  @override
  String get nuovoProgetto => 'New';

  @override
  String get inArrivo => 'Coming in a future version';

  @override
  String get proveApri => 'Tests';

  @override
  String get proveTitolo => 'Phase 2 tests';

  @override
  String get proveGalleria => 'Gallery';

  @override
  String get accessoCompleto => 'Access to all photos and videos';

  @override
  String get accessoParziale => 'Access to selected photos and videos only';

  @override
  String get accessoNegato => 'No access to the gallery';

  @override
  String get accessoDaChiedere =>
      'Photos stay in your gallery: the project links them without copying.';

  @override
  String get consentiAccesso => 'Allow access';

  @override
  String get scegliAltreFoto => 'Choose more photos';

  @override
  String get apriImpostazioni => 'Open settings';

  @override
  String get scegliDalTelefono => 'Choose from phone';

  @override
  String fileCopiati(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n files copied into the project',
      one: '1 file copied into the project',
    );
    return '$_temp0';
  }

  @override
  String get creaPagina => 'Create page';

  @override
  String get esportaVideo => 'Export MP4';

  @override
  String get progettiDiProva => 'Projects from the computer';

  @override
  String progettiDiProvaAiuto(String cartella) {
    return 'Copy each project into its own folder (with .scrlproj and media/) in: $cartella';
  }

  @override
  String paginaDiTotale(int numero, int totale) {
    return 'Page $numero of $totale';
  }

  @override
  String get fotoMancante => 'Missing photo';

  @override
  String get originaleMancante => 'Original missing';

  @override
  String get numeroPaginaDi => 'of';

  @override
  String get esportazioneInCorso => 'Exporting MP4…';

  @override
  String get annulla => 'Cancel';

  @override
  String videoFatto(int fotogrammi, String ms) {
    return 'MP4 saved to the gallery: $fotogrammi frames, $ms ms per frame';
  }

  @override
  String videoErrore(String errore) {
    return 'Export failed: $errore';
  }

  @override
  String get videoAnnullato => 'Export cancelled';

  @override
  String get videoNonDisponibile =>
      'Videos are not available on this phone yet';

  @override
  String get scegliUnVideo => 'Choose at least one video';

  @override
  String get progettoNonValido => 'Unreadable project';
}
