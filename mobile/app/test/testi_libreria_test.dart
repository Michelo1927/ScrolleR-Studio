// Testi della libreria con foto e video: conteggi e scelte accordati come sul desktop
// (`media_count` e `selection_text` in `scrollr/window/library.py`).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollr_studio/editor/testi_avvisi.dart';
import 'package:scrollr_studio/l10n/app_localizations.dart';

void main() {
  final it = lookupTesti(const Locale('it'));
  final en = lookupTesti(const Locale('en'));

  test('Conteggio della libreria: foto, video o tutte e due', () {
    expect(it.libreriaTitolo(conteggioMedia(it, 8, 0)), 'Libreria · 8 foto');
    expect(it.libreriaTitolo(conteggioMedia(it, 0, 2)), 'Libreria · 2 video');
    expect(
      it.libreriaTitolo(conteggioMedia(it, 6, 2)),
      'Libreria · 6 foto · 2 video',
    );
    expect(it.libreriaTitolo(conteggioMedia(it, 0, 0)), 'Libreria · 0 foto');
    expect(
      en.libreriaTitolo(conteggioMedia(en, 1, 3)),
      'Library · 1 photo · 3 videos',
    );
  });

  test('Miniature scelte e avviso di aggiunta', () {
    expect(testoScelte(it, 1, 0), '1 foto scelta');
    expect(testoScelte(it, 0, 1), '1 video scelto');
    expect(testoScelte(it, 0, 3), '3 video scelti');
    expect(testoScelte(it, 2, 1), '2 foto · 1 video scelti');
    expect(testoAggiunti(it, 3, 0), '3 foto aggiunte');
    expect(testoAggiunti(it, 0, 1), '1 video aggiunto');
    expect(testoAggiunti(en, 2, 2), '2 photos · 2 videos added');
  });
}
