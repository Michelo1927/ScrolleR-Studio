import 'package:scrl_engine/scrl_engine.dart';
import 'package:test/test.dart';

/// Modifiche della schermata Sottotitoli (`CaptionsDialog` e `TimelineStrip` del desktop).
void main() {
  ModificaSottotitoli nuova(List<Frase> frasi, {List<Pausa>? pause}) {
    final m = ModificaSottotitoli(
      frasi: frasi,
      durata: 20,
      inizioTaglio: 1,
      fineTaglio: 19,
    );
    if (pause != null) m.impostaPause(pause);
    return m;
  }

  test('testo della casella: frasi, tempi automatici, Annulla e Ripeti', () {
    final m = nuova(const []);
    expect(m.cambiato, isFalse);
    expect(
      m.applicaTesto('Ciao a tutti.\n\n  Oggi parliamo di foto.  \n'),
      isTrue,
    );
    expect(m.frasi.map((p) => p.testo), [
      'Ciao a tutti.',
      'Oggi parliamo di foto.',
    ]);
    expect(m.frasi.every((p) => p.auto && p.sincronizzata), isTrue);
    expect(m.frasi.first.inizio, 1);
    expect(m.frasi.last.fine, 19);
    expect(m.cambiato, isTrue);
    // Stesso testo: nessun passo nuovo
    expect(m.applicaTesto('Ciao a tutti.\nOggi parliamo di foto.'), isFalse);
    expect(m.annulla(), isTrue);
    expect(m.frasi, isEmpty);
    expect(m.cambiato, isFalse);
    expect(m.ripeti(), isTrue);
    expect(m.frasi, hasLength(2));
    expect(m.testo, 'Ciao a tutti.\nOggi parliamo di foto.');
  });

  test('una riga cambiata tiene la traduzione', () {
    final m = nuova(const [
      Frase(testo: 'Ciao a tutti', tr: 'Hi all', inizio: 2, fine: 4),
      Frase(testo: 'Seconda frase', tr: 'Second', inizio: 4, fine: 6),
    ]);
    m.applicaTesto('Ciao a tutti!\nSeconda frase');
    expect(m.frasi.first.tr, 'Hi all');
    expect(m.frasi.first.manuale, isTrue);
    expect(m.frasi.last.tr, 'Second');
  });

  test('dividi qui: il tempo si taglia al punto scelto', () {
    final m = nuova(const [
      Frase(testo: 'uno due tre quattro', inizio: 2, fine: 6, auto: true),
    ]);
    expect(m.dividi(0, 5), isTrue);
    expect(m.frasi, hasLength(2));
    expect(m.frasi[0].fine, 5);
    expect(m.frasi[1].inizio, 5);
    expect(m.frasi.every((p) => p.manuale), isTrue);
    // Fuori dalla frase: le due metà restano automatiche e si ridistribuiscono
    final a = nuova(const [
      Frase(testo: 'uno due tre quattro', inizio: 2, fine: 6, auto: true),
    ]);
    a.dividi(0, 10);
    expect(a.frasi.every((p) => p.auto), isTrue);
    expect(a.frasi.first.inizio, 1);
  });

  test('unisci ed elimina', () {
    final m = nuova(const [
      Frase(testo: 'a', inizio: 2, fine: 3),
      Frase(testo: 'b', inizio: 3, fine: 5),
      Frase(testo: 'c', inizio: 5, fine: 7),
    ]);
    expect(m.unisci(2), isFalse);
    expect(m.unisci(0), isTrue);
    expect(m.frasi.first.testo, 'a b');
    expect(m.frasi.first.inizio, 2);
    expect(m.frasi.first.fine, 5);
    expect(m.elimina(1), isTrue);
    expect(m.frasi, hasLength(1));
    m.annulla();
    m.annulla();
    expect(m.frasi, hasLength(3));
  });

  test('inizia qui trascina la fine della frase fissata prima', () {
    final m = nuova(const [
      Frase(testo: 'a', inizio: 2, fine: 4),
      Frase(testo: 'b', inizio: 4, fine: 6),
    ]);
    m.segna(1, ParteFrase.inizio, 3.5);
    expect(m.frasi[1].inizio, 3.5);
    expect(m.frasi[0].fine, 3.5);
    m.segna(1, ParteFrase.fine, 3.6);
    expect(m.frasi[1].fine, closeTo(3.5 + frasMinima, 1e-9));
    // Frase senza tempi: «Finisci qui» la fa partire 2 s prima
    final n = nuova(const [Frase(testo: 'x')]);
    n.segna(0, ParteFrase.fine, 10);
    expect(n.frasi.single.inizio, 8);
    expect(n.frasi.single.fine, 10);
  });

  test(
    'trascinamento: limiti, compagna, aggancio e un solo passo di Annulla',
    () {
      final m = nuova(const [
        Frase(testo: 'a', inizio: 2, fine: 4),
        Frase(testo: 'b', inizio: 4, fine: 6),
        Frase(testo: 'c', inizio: 8, fine: 9),
      ]);
      final g = m.iniziaTrascinamento(1, ParteFrase.inizio);
      expect(g.compagna, 0);
      m.trascina(g, -0.5);
      m.trascina(g, -1.0);
      expect(m.frasi[1].inizio, 3);
      expect(m.frasi[0].fine, 3);
      // Non scavalca la frase prima: si ferma a 0,3 s dal suo inizio
      m.trascina(g, -5);
      expect(m.frasi[1].inizio, closeTo(2 + frasMinima, 1e-9));
      m.annulla();
      expect(m.frasi[1].inizio, 4);
      expect(m.puoAnnullare, isFalse);
      // La fine si aggancia al punto di lettura vicino
      final f = m.iniziaTrascinamento(1, ParteFrase.fine);
      expect(f.compagna, isNull);
      expect(f.hi, 8);
      m.trascina(f, 1.0, tolleranza: 0.2, lettura: 7.1);
      expect(m.frasi[1].fine, 7.1);
      m.trascina(f, 5.0);
      expect(m.frasi[1].fine, 8);
    },
  );

  test('±0,1 s su un bordo', () {
    final m = nuova(const [Frase(testo: 'a', inizio: 2, fine: 4, auto: true)]);
    expect(m.spostaBordo(0, ParteFrase.fine, 0.1), isTrue);
    expect(m.frasi.single.fine, 4.1);
    expect(m.frasi.single.manuale, isTrue);
  });

  test('frasi finali senza quelle vuote; traduzione da un .srt', () {
    final m = nuova(const [
      Frase(testo: 'uno', inizio: 1, fine: 3, auto: true),
      Frase(testo: ' ', inizio: 3, fine: 5, auto: true),
      Frase(testo: 'tre', inizio: 5, fine: 19, auto: true),
    ]);
    final fin = m.frasiFinali();
    expect(fin.map((p) => p.testo), ['uno', 'tre']);
    final tr = traduzioneDa(m.frasi, const [
      Frase(testo: 'one', inizio: 0.5, fine: 2.5),
      Frase(testo: 'three', inizio: 4.5, fine: 12),
    ]);
    expect(tr.map((p) => p.tr), ['one', 'three', 'three']);
    m.importaSrt(const [Frase(testo: 'nuova', inizio: 2, fine: 3)]);
    expect(m.frasi.single.testo, 'nuova');
    expect(m.frasi.single.manuale, isTrue);
  });
}
