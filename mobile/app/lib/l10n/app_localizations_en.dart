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
}
