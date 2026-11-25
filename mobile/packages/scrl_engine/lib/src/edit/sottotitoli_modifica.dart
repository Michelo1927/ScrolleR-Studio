/// Modifiche alle frasi nella schermata Sottotitoli, portate da `scrollr/caption_dialog.py` (`CaptionsDialog`,
/// `TimelineStrip`) e da `scrollr/window/captions.py` (`_translation_from`).
///
/// [ModificaSottotitoli] tiene le frasi in lavorazione con il suo Annulla interno: la schermata la comanda e alla
/// fine (✓) prende [frasiFinali] per un solo passo di cronologia del progetto.
library;

import '../util/py.dart';
import 'sottotitoli.dart';

/// Quale parte di una frase si trascina sulla striscia del tempo.
enum ParteFrase { inizio, fine, corpo }

/// Trascinamento in corso di un bordo (o di un blocco intero) sulla striscia del tempo (`TimelineStrip._drag`).
class TrascinamentoFrase {
  final int indice;
  final ParteFrase parte;

  /// Inizio e fine della frase quando è cominciato.
  final double inizio0, fine0;

  /// Frase vicina ritoccata a mano che condivide il bordo: si sposta insieme.
  final int? compagna;

  /// Limiti: il blocco non scavalca le frasi fissate a mano prima e dopo, e lascia posto alle automatiche.
  final double lo, hi;

  /// Il trascinamento ha già cambiato qualcosa (e messo il passo di Annulla).
  bool mosso = false;

  TrascinamentoFrase._(
    this.indice,
    this.parte,
    this.inizio0,
    this.fine0,
    this.compagna,
    this.lo,
    this.hi,
  );
}

/// Frasi della schermata Sottotitoli con il loro Annulla / Ripeti (fino a 200 passi, come il desktop).
class ModificaSottotitoli {
  /// Durata del video intero e taglio (secondi del video originale).
  final double durata;
  final double inizioTaglio;
  final double fineTaglio;

  List<Frase> frasi;
  String lingua;
  String linguaTraduzione;

  /// Pause trovate nell'audio (vuote finché l'audio non è pronto o se non c'è).
  List<Pausa> pause = const [];

  /// Punti a cui si agganciano i bordi (`snap_points`).
  List<double> punti = const [];

  final List<Frase> _salvate;
  final String _linguaTraduzione0;
  final List<List<Frase>> _indietro = [];
  final List<List<Frase>> _avanti = [];

  static const int _passiMassimi = 200;

  ModificaSottotitoli({
    required List<Frase> frasi,
    required this.durata,
    required this.inizioTaglio,
    required this.fineTaglio,
    this.lingua = 'it',
    this.linguaTraduzione = 'en',
  }) : frasi = List.of(frasi),
       _salvate = List.unmodifiable(frasi),
       _linguaTraduzione0 = linguaTraduzione;

  bool get puoAnnullare => _indietro.isNotEmpty;
  bool get puoRipetere => _avanti.isNotEmpty;

  /// `_changed`: qualcosa è diverso da come era all'apertura.
  bool get cambiato =>
      !_uguali(frasi, _salvate) || linguaTraduzione != _linguaTraduzione0;

  /// Tutto il testo, una frase per riga (la casella del testo).
  String get testo => frasi.map((p) => p.testo).join('\n');

  /// `_push_undo`: il punto a cui torna Annulla.
  void salvaPerAnnulla() {
    _indietro.add(List.of(frasi));
    if (_indietro.length > _passiMassimi) _indietro.removeAt(0);
    _avanti.clear();
  }

  bool annulla() {
    if (_indietro.isEmpty) return false;
    _avanti.add(List.of(frasi));
    frasi = _indietro.removeLast();
    return true;
  }

  bool ripeti() {
    if (_avanti.isEmpty) return false;
    _indietro.add(List.of(frasi));
    frasi = _avanti.removeLast();
    return true;
  }

  /// `_retime`: tempi automatici sulle pause trovate.
  void ridistribuisciTempi({bool azzera = false}) {
    frasi = ridistribuisci(
      frasi,
      pause,
      inizioTaglio,
      fineTaglio,
      azzera: azzera,
    );
  }

  /// L'audio è pronto: le frasi scritte prima prendono i tempi veri.
  void impostaPause(List<Pausa> p) {
    pause = p;
    punti = puntiAggancio(p);
    ridistribuisciTempi();
  }

  /// `_apply_text_box`: il testo della casella (una frase per riga, le righe vuote non contano) diventa le
  /// frasi, conservando tempi e traduzioni delle righe rimaste uguali o quasi. Falso se non cambia niente.
  bool applicaTesto(String testo) {
    final righe = [
      for (final r in testo.split('\n'))
        if (pyStrip(r).isNotEmpty) pyStrip(r),
    ];
    if (_ugualiTesti(righe)) return false;
    salvaPerAnnulla();
    frasi = unisciRighe(frasi, righe);
    ridistribuisciTempi();
    return true;
  }

  /// «Tempi dall'audio» (`_auto_all`): tutte le frasi tornano automatiche e si ridistribuiscono.
  bool tempiDallAudio() {
    if (frasi.isEmpty) return false;
    salvaPerAnnulla();
    ridistribuisciTempi(azzera: true);
    return true;
  }

  /// Traduzione di una frase. Falso se è uguale a prima.
  bool impostaTraduzione(int i, String tr) {
    if (i < 0 || i >= frasi.length || frasi[i].tr == tr) return false;
    salvaPerAnnulla();
    frasi = [...frasi]..[i] = frasi[i].copyWith(tr: tr);
    return true;
  }

  /// «Dividi qui» (`_split_selected`): il testo si divide a metà circa (alla parola). Se [t] cade dentro la
  /// frase, il taglio del tempo va lì e le due metà restano dove si è scelto (diventano manuali).
  bool dividi(int i, [double? t]) {
    if (i < 0 || i >= frasi.length) return false;
    salvaPerAnnulla();
    final p = frasi[i];
    var (a, b) = dividiFrase(p);
    if (t != null &&
        p.sincronizzata &&
        t >= p.inizio! + frasMinima &&
        t <= p.fine! - frasMinima) {
      final m = pyRoundTo(t, 3);
      a = a.copyWith(inizio: p.inizio, fine: m, auto: false);
      b = b.copyWith(inizio: m, fine: p.fine, auto: false);
    } else if (!p.manuale) {
      a = a.copyWith(auto: true);
      b = b.copyWith(auto: true);
    }
    frasi = [...frasi]..replaceRange(i, i + 1, [a, b]);
    ridistribuisciTempi();
    return true;
  }

  /// «Unisci alla successiva» (`_join_selected`).
  bool unisci(int i) {
    if (i < 0 || i + 1 >= frasi.length) return false;
    salvaPerAnnulla();
    final a = frasi[i], b = frasi[i + 1];
    var p = unisciFrasi(a, b);
    if (!(a.manuale || b.manuale)) p = p.copyWith(auto: true);
    frasi = [...frasi]..replaceRange(i, i + 2, [p]);
    ridistribuisciTempi();
    return true;
  }

  /// «Elimina» (`_delete_selected`): le automatiche vicine si riprendono il tempo.
  bool elimina(int i) {
    if (i < 0 || i >= frasi.length) return false;
    salvaPerAnnulla();
    frasi = [...frasi]..removeAt(i);
    ridistribuisciTempi();
    return true;
  }

  /// «Inizia qui» / «Finisci qui» (`_mark`): il bordo della frase va al secondo [t] e la frase diventa manuale.
  bool segna(int i, ParteFrase parte, double t) {
    if (i < 0 || i >= frasi.length || parte == ParteFrase.corpo) return false;
    t = pyRoundTo(t, 3);
    salvaPerAnnulla();
    final f = [...frasi];
    var p = f[i].copyWith(auto: false);
    if (parte == ParteFrase.inizio) {
      final vecchio = p.inizio;
      var fine = p.fine;
      if (fine == null || fine < t + frasMinima) {
        fine = pyRoundTo(_min(durata, t + 2.0), 3);
      }
      p = p.copyWith(inizio: t, fine: fine);
      // La frase fissata prima che finiva dove cominciava questa la segue
      for (var j = 0; j < f.length; j++) {
        final q = f[j];
        if (j != i &&
            q.manuale &&
            vecchio != null &&
            (q.fine! - vecchio).abs() < 0.01) {
          f[j] = q.copyWith(fine: _max(q.inizio! + frasMinima, t));
        }
      }
    } else {
      p = p.copyWith(fine: _max(t, (p.inizio ?? 0.0) + frasMinima));
      if (p.inizio == null) {
        p = p.copyWith(inizio: pyRoundTo(_max(0.0, t - 2.0), 3));
      }
    }
    f[i] = p;
    frasi = f;
    ridistribuisciTempi();
    return true;
  }

  /// −0,1 s / +0,1 s su un bordo: come un piccolo trascinamento, senza aggancio.
  bool spostaBordo(int i, ParteFrase parte, double dt) {
    if (i < 0 || i >= frasi.length || !frasi[i].sincronizzata) return false;
    final g = iniziaTrascinamento(i, parte);
    trascina(g, dt);
    return g.mosso;
  }

  /// `TimelineStrip.mousePressEvent`: prepara il trascinamento della frase [i] (null se non ha tempi).
  TrascinamentoFrase iniziaTrascinamento(int i, ParteFrase parte) {
    final ph = frasi[i];
    // Bordo condiviso con la frase vicina ritoccata a mano: si spostano insieme
    int? compagna;
    if (parte == ParteFrase.inizio &&
        i > 0 &&
        frasi[i - 1].manuale &&
        (frasi[i - 1].fine! - ph.inizio!).abs() < 0.01) {
      compagna = i - 1;
    } else if (parte == ParteFrase.fine &&
        i + 1 < frasi.length &&
        frasi[i + 1].manuale &&
        (frasi[i + 1].inizio! - ph.fine!).abs() < 0.01) {
      compagna = i + 1;
    }
    double? lo, hi;
    var posto = 0;
    for (var j = i - 1; j >= 0; j--) {
      if (j != compagna && frasi[j].manuale) {
        lo = frasi[j].fine;
        break;
      }
      if (j != compagna) posto++;
    }
    lo = (lo ?? (posto > 0 ? inizioTaglio : 0.0)) + frasMinima * posto;
    posto = 0;
    for (var j = i + 1; j < frasi.length; j++) {
      if (j != compagna && frasi[j].manuale) {
        hi = frasi[j].inizio;
        break;
      }
      if (j != compagna) posto++;
    }
    hi = (hi ?? (posto > 0 ? fineTaglio : durata)) - frasMinima * posto;
    if (compagna != null) {
      final q = frasi[compagna];
      if (parte == ParteFrase.inizio) {
        lo = _max(lo, q.inizio! + frasMinima);
      } else {
        hi = _min(hi, q.fine! - frasMinima);
      }
    }
    return TrascinamentoFrase._(
      i,
      parte,
      ph.inizio!,
      ph.fine!,
      compagna,
      _min(lo, ph.inizio!),
      _max(hi, ph.fine!),
    );
  }

  /// `TimelineStrip.mouseMoveEvent`: il bordo si sposta di [dt] secondi da dove era all'inizio, agganciato
  /// (entro [tolleranza]) alle pause, ai bordi delle frasi manuali e al punto [lettura]. La frase diventa
  /// manuale; le automatiche intorno si sistemano. Il primo movimento mette il passo di Annulla.
  void trascina(
    TrascinamentoFrase g,
    double dt, {
    double tolleranza = 0.0,
    double? lettura,
  }) {
    if (!g.mosso) {
      g.mosso = true;
      salvaPerAnnulla();
    }
    final i = g.indice, s0 = g.inizio0, e0 = g.fine0;
    final pts = [
      ...punti,
      for (var j = 0; j < frasi.length; j++)
        if (j != i && j != g.compagna && frasi[j].manuale) ...[
          frasi[j].inizio!,
          frasi[j].fine!,
        ],
      ?lettura,
    ];
    final f = [...frasi];
    var ph = f[i].copyWith(auto: false);
    switch (g.parte) {
      case ParteFrase.inizio:
        var t = aggancia(
          _max(g.lo, _min(e0 - frasMinima, s0 + dt)),
          pts,
          tolleranza,
        );
        t = _max(g.lo, _min(e0 - frasMinima, t));
        ph = ph.copyWith(inizio: pyRoundTo(t, 3));
        final c = g.compagna;
        if (c != null) {
          final q = f[c];
          f[c] = q.copyWith(
            fine: pyRoundTo(_max(q.inizio! + frasMinima, t), 3),
          );
        }
      case ParteFrase.fine:
        var t = aggancia(
          _max(s0 + frasMinima, _min(g.hi, e0 + dt)),
          pts,
          tolleranza,
        );
        t = _max(s0 + frasMinima, _min(g.hi, t));
        ph = ph.copyWith(fine: pyRoundTo(t, 3));
        final c = g.compagna;
        if (c != null) {
          final q = f[c];
          f[c] = q.copyWith(
            inizio: pyRoundTo(_min(q.fine! - frasMinima, t), 3),
          );
        }
      case ParteFrase.corpo:
        final durataFrase = e0 - s0;
        var t = aggancia(
          _max(g.lo, _min(g.hi - durataFrase, s0 + dt)),
          pts,
          tolleranza,
        );
        t = _max(g.lo, _min(g.hi - durataFrase, t));
        ph = ph.copyWith(
          inizio: pyRoundTo(t, 3),
          fine: pyRoundTo(t + durataFrase, 3),
        );
    }
    f[i] = ph;
    frasi = f;
    ridistribuisciTempi();
  }

  /// Importa le frasi di un .srt: al posto di quelle che ci sono, o come loro traduzione.
  void importaSrt(List<Frase> lette, {bool comeTraduzione = false}) {
    salvaPerAnnulla();
    frasi = comeTraduzione
        ? traduzioneDa(frasi, lette)
        : pulisciFrasi([for (final p in lette) p.toJson()]);
    ridistribuisciTempi();
  }

  /// `accept`: le frasi da tenere, senza quelle vuote (le automatiche si riprendono il loro tempo).
  List<Frase> frasiFinali() {
    final tenute = [
      for (final p in frasi)
        if (pyStrip(p.testo).isNotEmpty || pyStrip(p.tr).isNotEmpty) p,
    ];
    if (tenute.length == frasi.length) return frasi;
    return ridistribuisci(tenute, pause, inizioTaglio, fineTaglio);
  }

  bool _ugualiTesti(List<String> righe) {
    if (righe.length != frasi.length) return false;
    for (var i = 0; i < righe.length; i++) {
      if (righe[i] != frasi[i].testo) return false;
    }
    return true;
  }
}

/// `_translation_from`: la traduzione di ogni frase è il testo delle frasi di [altre] che la coprono di più nel
/// tempo (a parità, la prima).
List<Frase> traduzioneDa(List<Frase> frasi, List<Frase> altre) => [
  for (final p in frasi) _tradotta(p, altre),
];

Frase _tradotta(Frase p, List<Frase> altre) {
  if (!p.sincronizzata || altre.isEmpty) return p;
  double sovrapposto(Frase o) =>
      _min(p.fine!, o.fine ?? 0) - _max(p.inizio!, o.inizio ?? 0);
  var migliore = altre.first;
  for (final o in altre.skip(1)) {
    if (sovrapposto(o) > sovrapposto(migliore)) migliore = o;
  }
  return sovrapposto(migliore) > 0 ? p.copyWith(tr: migliore.testo) : p;
}

bool _uguali(List<Frase> a, List<Frase> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

double _min(double a, double b) => a < b ? a : b;
double _max(double a, double b) => a > b ? a : b;
