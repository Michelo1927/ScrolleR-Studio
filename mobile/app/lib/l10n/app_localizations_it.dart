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
}
