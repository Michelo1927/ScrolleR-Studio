/// Tema scuro dell'app, costruito solo dai token di `tokens.dart`.
library;

import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

/// Tema unico della v1 (niente tema chiaro).
ThemeData temaScrl() {
  const schema = ColorScheme.dark(
    primary: ColoriScrl.accento,
    onPrimary: ColoriScrl.suAccento,
    secondary: ColoriScrl.accento,
    onSecondary: ColoriScrl.suAccento,
    error: ColoriScrl.pericolo,
    onError: ColoriScrl.suAccento,
    surface: ColoriScrl.pannello,
    onSurface: ColoriScrl.testo,
    onSurfaceVariant: ColoriScrl.testoSecondario,
    outline: ColoriScrl.bordo,
    outlineVariant: ColoriScrl.separatore,
  );
  const testo = TextTheme(
    titleMedium: TextStyle(
      fontSize: TestoScrl.grande,
      fontWeight: TestoScrl.marcato,
      color: ColoriScrl.testo,
    ),
    bodyMedium: TextStyle(
      fontSize: TestoScrl.normale,
      fontWeight: TestoScrl.regolare,
      color: ColoriScrl.testo,
    ),
    bodySmall: TextStyle(
      fontSize: TestoScrl.piccolo,
      fontWeight: TestoScrl.regolare,
      color: ColoriScrl.testoSecondario,
    ),
    labelMedium: TextStyle(
      fontSize: TestoScrl.piccolo,
      fontWeight: TestoScrl.marcato,
      color: ColoriScrl.testo,
    ),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: schema,
    scaffoldBackgroundColor: ColoriScrl.fondo,
    canvasColor: ColoriScrl.fondo,
    dividerColor: ColoriScrl.separatore,
    textTheme: testo,
    appBarTheme: const AppBarTheme(
      backgroundColor: ColoriScrl.barra,
      foregroundColor: ColoriScrl.testo,
      elevation: 0,
      toolbarHeight: MisureScrl.barraSuperiore,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: ColoriScrl.pannello,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MisureScrl.angoloPannello),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ColoriScrl.accento,
        foregroundColor: ColoriScrl.suAccento,
        minimumSize: const Size(MisureScrl.tocco, MisureScrl.tocco),
        shape: const StadiumBorder(),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: ColoriScrl.rilievo,
      contentTextStyle: TextStyle(color: ColoriScrl.testo),
      actionTextColor: ColoriScrl.accento,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
