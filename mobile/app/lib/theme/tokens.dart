/// Token del design system (piano §4.7): l'unico posto dove compaiono colori, misure e durate.
///
/// I colori partono da `THEME` di `scrollr/theme.py`: grigi neutri senza dominanti (servono a giudicare
/// i colori delle foto) e **un solo accento**. Nei widget non si scrivono mai esadecimali: si usano questi token.
library;

import 'package:flutter/widgets.dart';

/// Colori dell'interfaccia (solo tema scuro nella v1).
abstract final class ColoriScrl {
  /// Fondo attorno alla pagina (`backdrop` del desktop).
  static const Color fondo = Color(0xFF1E1E1E);

  /// Barre superiore e inferiore (`frame` del desktop).
  static const Color barra = Color(0xFF252525);

  /// Superficie dei pannelli che salgono dal basso, un tono sopra il fondo (`panel`).
  static const Color pannello = Color(0xFF323232);

  /// Pulsanti e tessere (`raised`).
  static const Color rilievo = Color(0xFF3D3D3D);

  /// Elemento premuto o evidenziato (`hover`).
  static const Color premuto = Color(0xFF4A4A4A);

  /// Separatori sottili (`line`).
  static const Color separatore = Color(0xFF181818);

  /// Contorni di campi e tessere (`edge`).
  static const Color bordo = Color(0xFF4F4F4F);

  /// Testo principale (`text`).
  static const Color testo = Color(0xFFDADADA);

  /// Testo secondario (`muted`).
  static const Color testoSecondario = Color(0xFFA3A3A3);

  /// Testo disattivato (`faint`).
  static const Color testoSpento = Color(0xFF696969);

  /// L'unico accento: azioni principali e selezione.
  static const Color accento = Color(0xFF2680EB);

  /// Testo sopra l'accento (`accent_ink`).
  static const Color suAccento = Color(0xFFFFFFFF);

  /// Azioni distruttive.
  static const Color pericolo = Color(0xFFE34850);

  // Tinte derivate per il contrasto AA (4,5:1 sul testo piccolo, piano §4.7). L'accento resta uno solo, `accento`:
  // selezioni, cursori, bordi e icone. Queste sono la stessa tinta schiarita o scurita quanto basta, e servono
  // solo dove c'è del TESTO: testo colorato sui pannelli e testo bianco su un riempimento.

  /// Accento schiarito: testo e icone colorati con l'accento sui pannelli e sulle tessere (≥ 4,5:1 fino a `premuto`).
  static const Color accentoTesto = Color(0xFF8CBCFA);

  /// Accento scurito: riempimento (pulsanti, pillole) con testo bianco `suAccento` (≥ 4,5:1).
  static const Color accentoPieno = Color(0xFF1F6FD0);

  /// Pericolo schiarito, per testo e icone di azioni distruttive sui pannelli.
  static const Color pericoloTesto = Color(0xFFFF868C);

  /// Pericolo scurito, per i pulsanti distruttivi con testo bianco.
  static const Color pericoloPieno = Color(0xFFC4333C);

  /// Guide di centro.
  static const Color guida = Color(0xFF29D5F5);

  /// Linee di aggancio.
  static const Color aggancio = Color(0xFFFF3DCB);

  /// Fondo scuro semitrasparente delle etichette sopra le foto (durata dei video).
  static const Color veloEtichetta = Color(0xA6000000);

  /// Scacchiera della trasparenza (risultato della sagoma), come `checker_light` / `checker_dark` del desktop.
  static const Color scacchiChiari = Color(0xFFCACACA);
  static const Color scacchiScuri = Color(0xFF9C9C9C);

  /// Velo sulla parte della foto esclusa dal ritaglio o dalla sagoma.
  static const Color veloEscluso = Color(0x96000000);
}

/// Tipografia: font di sistema (Roboto / San Francisco), 3 misure e 2 pesi.
abstract final class TestoScrl {
  static const double piccolo = 12;
  static const double normale = 14;
  static const double grande = 17;

  static const FontWeight regolare = FontWeight.w400;
  static const FontWeight marcato = FontWeight.w600;

  /// Ingrandimento massimo del testo di sistema che l'interfaccia segue.
  static const double scalaMassima = 1.3;
}

/// Misure in dp.
abstract final class MisureScrl {
  static const double barraSuperiore = 48;
  static const double strisciaPagine = 32;
  static const double barraInferiore = 64;

  /// Area toccabile minima, anche quando il disegno è più piccolo.
  static const double tocco = 48;

  /// Angoli superiori dei pannelli che salgono dal basso.
  static const double angoloPannello = 16;

  /// Angoli delle tessere.
  static const double angoloTessera = 12;

  /// Altezza massima di un pannello, in frazione dello schermo.
  static const double pannelloMassimo = 0.4;

  /// Lembo della pagina vicina visibile ai lati della tela.
  static const double lemboPagina = 12;

  static const double spazioPiccolo = 8;
  static const double spazio = 16;
}

/// Movimento: pannelli tra 200 e 250 ms con decelerazione.
abstract final class MotoScrl {
  static const Duration pannello = Duration(milliseconds: 220);
  static const Duration breve = Duration(milliseconds: 150);
  static const Curve curva = Curves.easeOutCubic;

  /// [d] oppure zero se il sistema chiede «riduci animazioni» (piano §4.7).
  static Duration durata(BuildContext context, Duration d) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;

  /// Animazione dei fogli dal basso: nessuna se il sistema chiede di ridurre il movimento.
  static AnimationStyle? foglio(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
      ? AnimationStyle.noAnimation
      : null;
}

/// Colori rapidi per i contenuti del collage (bordi, forme, testi): `SWATCHES` del desktop. Non sono colori
/// dell'interfaccia, per questo stanno fuori da [ColoriScrl].
abstract final class CampioniScrl {
  static const List<Color> rapidi = [
    Color(0xFFFFFFFF),
    Color(0xFF000000),
    Color(0xFF8E8E93),
    Color(0xFFFF3B30),
    Color(0xFFFF9500),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF00C7BE),
    Color(0xFF007AFF),
    Color(0xFF5856D6),
    Color(0xFFAF52DE),
    Color(0xFFFF2D55),
  ];
}
