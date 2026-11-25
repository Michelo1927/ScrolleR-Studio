/// Sottotitoli: frasi, divisione del testo, righe bilanciate, file .srt, forma d'onda e pause dell'audio.
///
/// Porta 1:1 di `scrollr/captions.py`. Le misure del testo arrivano come funzione `larghezza(testo)`.
/// Una frase ha inizio e fine in secondi del video **originale** (null finché non è sincronizzata), testo e
/// traduzione; `auto` segna i tempi messi dall'app, che si ridistribuiscono quando cambia il testo.
///
/// Le lunghezze dei testi si contano in caratteri Unicode (`runes`), come `len()` di Python.
library;

import 'dart:typed_data';

import '../model/json_read.dart';
import '../util/py.dart';
import '../util/py_difflib.dart';

/// Durata minima di una frase sincronizzata, in secondi (`MIN_PHRASE`).
const double frasMinima = 0.3;

/// Passo della forma d'onda: 10 ms (`ENVELOPE_STEP`).
const double passoInviluppo = 0.01;

/// Frequenza dell'audio mono usato per la forma d'onda e le pause (`LISTEN_RATE` del desktop).
const int frequenzaAscolto = 24000;

/// Parole prima delle quali si spezza volentieri una frase lunga (`_CONJUNCTIONS`).
const Set<String> _congiunzioni = {
  'e', 'ed', 'ma', 'però', 'che', 'perché', 'quando', 'se', 'o', 'oppure', //
  'poi', 'quindi', 'mentre', 'come', 'anche', 'allora', 'cioè', 'dove', //
  'and', 'but', 'or', 'so', 'because', 'when', 'that', 'if',
};

// ---------- Spazi alla Python ----------

/// Caratteri per cui `str.isspace()` di Python è vero (e che `\s` trova nelle espressioni regolari).
const String _classeSpazi = r'[\t\n\x0B\f\r \x1C-\x1F\x85\xA0  -     　]';
final RegExp _spazi = RegExp('$_classeSpazi+');
final RegExp _fineFrase = RegExp('(?<=[.!?…;:])$_classeSpazi+');
final RegExp _fineRiga = RegExp('\r\n|[\n\r\x0B\f\x1C\x1D\x1E\x85  ]');

bool _eSpazio(int c) =>
    c == 0x20 ||
    (c >= 0x09 && c <= 0x0D) ||
    (c >= 0x1C && c <= 0x1F) ||
    c == 0x85 ||
    c == 0xA0 ||
    c == 0x1680 ||
    (c >= 0x2000 && c <= 0x200A) ||
    c == 0x2028 ||
    c == 0x2029 ||
    c == 0x202F ||
    c == 0x205F ||
    c == 0x3000;

/// `len(s)` di Python: caratteri Unicode, non unità UTF-16.
int pyLen(String s) => s.runes.length;

/// `s.strip()` di Python.
String pyStrip(String s) {
  final r = s.runes.toList();
  var i = 0, j = r.length;
  while (i < j && _eSpazio(r[i])) {
    i++;
  }
  while (j > i && _eSpazio(r[j - 1])) {
    j--;
  }
  return String.fromCharCodes(r, i, j);
}

/// `s.strip(caratteri)` di Python.
String _stripCaratteri(String s, String caratteri) {
  final togli = caratteri.runes.toSet();
  final r = s.runes.toList();
  var i = 0, j = r.length;
  while (i < j && togli.contains(r[i])) {
    i++;
  }
  while (j > i && togli.contains(r[j - 1])) {
    j--;
  }
  return String.fromCharCodes(r, i, j);
}

/// `s.split()` di Python: parole separate da spazi qualsiasi, senza pezzi vuoti.
List<String> pySplit(String s) => [
  for (final p in s.split(_spazi))
    if (p.isNotEmpty) p,
];

/// `s.splitlines()` di Python (senza l'ultimo pezzo vuoto).
List<String> _righe(String s) {
  if (s.isEmpty) return const [];
  final r = s.split(_fineRiga);
  if (r.isNotEmpty && r.last.isEmpty) r.removeLast();
  return r;
}

String _normalizza(String s) => pyStrip(s.replaceAll(_spazi, ' '));

/// `str(v)` di Python per i valori letti da un file JSON.
String _pyStr(Object? v) {
  if (v == null) return 'None';
  if (v is bool) return v ? 'True' : 'False';
  if (v is String) return v;
  if (v is double) return _reprFloat(v);
  return v.toString();
}

String _reprFloat(double v) {
  if (v.isNaN) return 'nan';
  if (v.isInfinite) return v > 0 ? 'inf' : '-inf';
  if (v == v.truncateToDouble() && v.abs() < 1e16) {
    return '${v.toInt()}.0';
  }
  return v.toString();
}

final RegExp _numeroPython = RegExp(
  r'^[+-]?(?:\d(?:_?\d)*(?:\.(?:\d(?:_?\d)*)?)?|\.\d(?:_?\d)*)(?:[eE][+-]?\d(?:_?\d)*)?$',
);

/// `float(testo)` di Python; null dove Python solleva `ValueError`.
double? _pyFloatTesto(String testo) {
  final s = pyStrip(testo);
  final basso = s.toLowerCase();
  final senzaSegno = basso.startsWith('+') || basso.startsWith('-')
      ? basso.substring(1)
      : basso;
  final negativo = basso.startsWith('-');
  if (senzaSegno == 'inf' || senzaSegno == 'infinity') {
    return negativo ? double.negativeInfinity : double.infinity;
  }
  if (senzaSegno == 'nan') return double.nan;
  if (!_numeroPython.hasMatch(s)) return null;
  return double.tryParse(s.replaceAll('_', ''));
}

// ---------- Frasi ----------

/// Frase dei sottotitoli (`make_phrase`): stessa forma salvata nel progetto.
class Frase {
  /// Inizio e fine in secondi del video originale; null se la frase non è sincronizzata.
  final double? inizio;
  final double? fine;
  final String testo;

  /// Traduzione (campo `tr`).
  final String tr;

  /// Tempi messi dall'app (campo `auto`): si ridistribuiscono quando cambia il testo.
  final bool auto;

  /// Tempi delle parole di un motore futuro (campo `words`): si conservano così come sono.
  final List<Object?>? parole;

  const Frase({
    this.testo = '',
    this.inizio,
    this.fine,
    this.tr = '',
    this.auto = false,
    this.parole,
  });

  /// `is_synced`.
  bool get sincronizzata => inizio != null && fine != null;

  /// `is_manual`: tempi fissati a mano (o letti da un .srt), che i tempi automatici non spostano.
  bool get manuale => sincronizzata && !auto;

  static const Object _uguale = Object();

  Frase copyWith({
    Object? inizio = _uguale,
    Object? fine = _uguale,
    String? testo,
    String? tr,
    bool? auto,
    Object? parole = _uguale,
  }) => Frase(
    inizio: identical(inizio, _uguale) ? this.inizio : inizio as double?,
    fine: identical(fine, _uguale) ? this.fine : fine as double?,
    testo: testo ?? this.testo,
    tr: tr ?? this.tr,
    auto: auto ?? this.auto,
    parole: identical(parole, _uguale) ? this.parole : parole as List<Object?>?,
  );

  /// `phrase_state`: forma salvata, tempi arrotondati al millesimo.
  Map<String, Object?> toJson() => <String, Object?>{
    'start': inizio == null ? null : pyRoundTo(inizio!, 3),
    'end': fine == null ? null : pyRoundTo(fine!, 3),
    'text': testo,
    'tr': tr,
    if (parole != null) 'words': parole,
    if (auto && sincronizzata) 'auto': true,
  };

  @override
  bool operator ==(Object other) =>
      other is Frase &&
      other.inizio == inizio &&
      other.fine == fine &&
      other.testo == testo &&
      other.tr == tr &&
      other.auto == auto &&
      jsonEquals(other.parole, parole);

  @override
  int get hashCode => Object.hash(inizio, fine, testo, tr, auto);

  @override
  String toString() =>
      'Frase($inizio–$fine "$testo" tr="$tr"${auto ? ' auto' : ''})';
}

/// `clean_phrases`: frasi lette dal progetto, con i campi mancanti o sbagliati ai valori di partenza.
List<Frase> pulisciFrasi(Object? dati) {
  double? numero(Object? v) {
    double? x;
    if (v == null) return null;
    if (v is bool) {
      x = v ? 1.0 : 0.0;
    } else if (v is num) {
      x = v.toDouble();
    } else if (v is String) {
      x = _pyFloatTesto(v);
    }
    if (x == null) return null;
    return x > 0.0 ? x : 0.0; // max(0.0, x) di Python (anche con nan)
  }

  final out = <Frase>[];
  for (final d in dati is List ? dati : const []) {
    if (d is! Map) continue;
    final m = asMap(d);
    final inizio = numero(m['start']);
    var fine = numero(m['end']);
    if (inizio != null && fine != null && fine < inizio + 0.01) {
      fine = inizio + frasMinima;
    }
    final tr = m['tr'];
    out.add(
      Frase(
        testo: m.containsKey('text') ? _pyStr(m['text']) : '',
        inizio: inizio,
        fine: fine,
        tr: truthy(tr) ? _pyStr(tr) : '',
        parole: m['words'] is List
            ? List<Object?>.of(m['words']! as List)
            : null,
        auto: m['auto'] == true && inizio != null && fine != null,
      ),
    );
  }
  return out;
}

/// `phrase_index_at`: indice della frase da mostrare al secondo [t] (-1 se nessuna); con frasi sovrapposte
/// vince l'ultima iniziata.
int indiceFraseA(List<Frase> frasi, double t) {
  var migliore = -1;
  double? inizioMigliore;
  for (var i = 0; i < frasi.length; i++) {
    final p = frasi[i];
    if (p.sincronizzata &&
        p.inizio! <= t &&
        t < p.fine! &&
        (inizioMigliore == null || p.inizio! >= inizioMigliore)) {
      migliore = i;
      inizioMigliore = p.inizio;
    }
  }
  return migliore;
}

/// `phrase_at`.
Frase? fraseA(List<Frase> frasi, double t) {
  final i = indiceFraseA(frasi, t);
  return i >= 0 ? frasi[i] : null;
}

/// `split_phrase`: divide una frase in due a metà circa (alla parola), con il tempo spartito in proporzione.
(Frase, Frase) dividiFrase(Frase p) {
  final parole = pySplit(p.testo);
  if (parole.length < 2) {
    if (p.sincronizzata) {
      final meta = (p.inizio! + p.fine!) / 2.0;
      return (p.copyWith(fine: meta), Frase(inizio: meta, fine: p.fine));
    }
    return (p, const Frase());
  }
  final meta = pyLen(p.testo) / 2.0;
  var k = 1;
  double? migliore;
  for (var i = 1; i < parole.length; i++) {
    final v =
        (pyLen(parole.sublist(0, i).join(' ')) - meta).abs() -
        (parole[i - 1].endsWith(',') ? 0.2 * meta : 0.0);
    if (migliore == null || v < migliore) {
      migliore = v;
      k = i;
    }
  }
  final ta = parole.sublist(0, k).join(' ');
  final tb = parole.sublist(k).join(' ');
  var a = Frase(testo: ta, tr: p.tr);
  var b = Frase(testo: tb);
  if (p.sincronizzata) {
    final m =
        p.inizio! +
        (p.fine! - p.inizio!) *
            pyLen(ta) /
            (pyLen(ta) + pyLen(tb) > 1 ? pyLen(ta) + pyLen(tb) : 1);
    a = a.copyWith(inizio: p.inizio, fine: pyRoundTo(m, 3));
    b = b.copyWith(inizio: pyRoundTo(m, 3), fine: p.fine);
  }
  return (a, b);
}

/// `join_phrases`: testo e traduzione uno dopo l'altro, tempo dall'inizio della prima alla fine della seconda.
Frase unisciFrasi(Frase a, Frase b) {
  var p = Frase(
    testo: pyStrip('${a.testo} ${b.testo}'),
    tr: pyStrip('${a.tr} ${b.tr}'),
  );
  final sinc = [a, b].where((q) => q.sincronizzata).toList();
  if (sinc.isNotEmpty) {
    var inizio = sinc.first.inizio!, fine = sinc.first.fine!;
    for (final q in sinc.skip(1)) {
      if (q.inizio! < inizio) inizio = q.inizio!;
      if (q.fine! > fine) fine = q.fine!;
    }
    p = p.copyWith(inizio: inizio, fine: fine);
  }
  return p;
}

/// `insert_index`: posto in elenco per una frase che comincia a [inizio].
int indiceInserimento(List<Frase> frasi, double inizio) {
  var idx = 0;
  for (var i = 0; i < frasi.length; i++) {
    final s = frasi[i].inizio;
    if (s != null && s <= inizio) idx = i + 1;
  }
  return idx;
}

// ---------- Divisione del testo in frasi corte ----------

List<String> _spezzaLunga(String frase, bool Function(String) sta) {
  final parole = frase.split(' ');
  if (parole.length < 2 || sta(frase)) return [frase];
  final totale = pyLen(frase);
  var kMigliore = 1;
  double? punteggioMigliore;
  for (var k = 1; k < parole.length; k++) {
    final sinistra = parole.sublist(0, k).join(' ');
    final destra = parole.sublist(k).join(' ');
    var punteggio = (pyLen(sinistra) - pyLen(destra)).abs() / totale;
    final prima = parole[k - 1];
    if (prima.endsWith(',') || prima.endsWith('—') || prima.endsWith('-')) {
      punteggio -= 0.30;
    } else if (_congiunzioni.contains(
      _stripCaratteri(parole[k].toLowerCase(), '«"\'('),
    )) {
      punteggio -= 0.15;
    }
    if (k == 1 || k == parole.length - 1) {
      punteggio += 0.35; // Una parola sola da parte non fa una frase
    }
    if (punteggioMigliore == null || punteggio < punteggioMigliore) {
      kMigliore = k;
      punteggioMigliore = punteggio;
    }
  }
  final sinistra = parole.sublist(0, kMigliore).join(' ');
  final destra = parole.sublist(kMigliore).join(' ');
  return [..._spezzaLunga(sinistra, sta), ..._spezzaLunga(destra, sta)];
}

/// `split_text`: testo libero → frasi corte. Ogni riga resta separata, poi si divide alla punteggiatura di
/// fine frase e infine le frasi troppo lunghe ([sta] falso) a metà circa.
List<String> dividiTesto(String testo, [bool Function(String)? sta]) {
  final f =
      sta ??
      (String s) =>
          pyLen(s) <= 84; // Senza misure: due righe da circa 42 caratteri
  final out = <String>[];
  for (final riga in _righe(testo)) {
    final r = _normalizza(riga);
    if (r.isEmpty) continue;
    for (final frase in r.split(_fineFrase)) {
      final s = pyStrip(frase);
      if (s.isNotEmpty) out.addAll(_spezzaLunga(s, f));
    }
  }
  return out;
}

/// `balance_lines`: una riga se ci sta, altrimenti due righe di larghezza simile (la seconda un po' più
/// lunga, come nei sottotitoli).
List<String> bilanciaRighe(
  String testo,
  double Function(String) larghezza,
  double maxW,
) {
  final t = _normalizza(testo);
  if (t.isEmpty || larghezza(t) <= maxW) return [t];
  final parole = t.split(' ');
  if (parole.length < 2) return [t];
  List<String>? migliore;
  double? punteggioMigliore;
  for (var k = 1; k < parole.length; k++) {
    final a = parole.sublist(0, k).join(' ');
    final b = parole.sublist(k).join(' ');
    final wa = larghezza(a), wb = larghezza(b);
    var punteggio = wa > wb ? wa : wb;
    if (wa > wb) punteggio += 0.03 * maxW;
    final prima = parole[k - 1];
    if (prima.endsWith(',') ||
        prima.endsWith(';') ||
        prima.endsWith(':') ||
        prima.endsWith('—')) {
      punteggio -= 0.08 * maxW;
    }
    if (punteggioMigliore == null || punteggio < punteggioMigliore) {
      migliore = [a, b];
      punteggioMigliore = punteggio;
    }
  }
  return migliore!;
}

/// `fits_two_lines`.
bool staInDueRighe(
  String testo,
  double Function(String) larghezza,
  double maxW,
) => bilanciaRighe(testo, larghezza, maxW).every((r) => larghezza(r) <= maxW);

/// `merge_lines`: le righe della casella di testo tornano frasi senza perdere i tempi. Le righe uguali
/// tengono i loro, una riga divisa o unita si spartisce il tempo in proporzione ai caratteri, le righe
/// nuove restano da sincronizzare.
List<Frase> unisciRighe(List<Frase> vecchie, List<String> righe) {
  final out = <Frase>[];
  final sm = SequenceMatcher<String>([for (final p in vecchie) p.testo], righe);
  for (final op in sm.getOpcodes()) {
    if (op.tag == 'equal') {
      out.addAll(vecchie.sublist(op.i1, op.i2));
      continue;
    }
    final nuove = righe.sublist(op.j1, op.j2);
    if (nuove.isEmpty) continue; // Righe tolte
    final olds = vecchie.sublist(op.i1, op.i2);
    if (olds.length == nuove.length) {
      for (var i = 0; i < olds.length; i++) {
        out.add(
          olds[i].copyWith(testo: nuove[i]),
        ); // Righe corrette una per una
      }
      continue;
    }
    out.addAll(_rimappaRighe(olds, nuove));
  }
  return out;
}

/// `_remap_lines`: ogni lettera del testo vecchio ha un tempo (in proporzione dentro la sua frase) e ogni
/// riga nuova prende i tempi delle lettere che le corrispondono. Una riga quasi tutta nuova resta da
/// sincronizzare.
List<Frase> _rimappaRighe(List<Frase> olds, List<String> righe) {
  final testoVecchio = <int>[];
  final proprietario = <int>[];
  final tempi = <double?>[];
  for (var k = 0; k < olds.length; k++) {
    final p = olds[k];
    if (testoVecchio.isNotEmpty) {
      testoVecchio.add(0x20);
      proprietario.add(-1);
      tempi.add(null);
    }
    final txt = p.testo.runes.toList();
    final n = txt.length > 1 ? txt.length : 1;
    for (var c = 0; c < txt.length; c++) {
      proprietario.add(k);
      tempi.add(
        p.sincronizzata ? p.inizio! + (p.fine! - p.inizio!) * c / n : null,
      );
    }
    testoVecchio.addAll(txt);
  }
  final testoNuovo = righe.join(' ').runes.toList();
  final mappa = List<int>.filled(testoNuovo.length, -1);
  final sm = SequenceMatcher<int>(testoVecchio, testoNuovo);
  for (final m in sm.getMatchingBlocks()) {
    for (var d = 0; d < m.size; d++) {
      mappa[m.b + d] = m.a + d;
    }
  }
  final out = <Frase>[];
  final trUsate = <int>{};
  var pos = 0;
  for (final riga in righe) {
    final lung = pyLen(riga);
    final idx = [
      for (var i = pos; i < pos + lung; i++)
        if (mappa[i] >= 0) mappa[i],
    ];
    pos += lung + 1;
    var p = Frase(testo: riga);
    if (idx.length >= (0.3 * lung > 1 ? 0.3 * lung : 1)) {
      final owners = [
        for (final i in idx)
          if (proprietario[i] >= 0) proprietario[i],
      ];
      final ts = [
        for (final i in idx)
          if (tempi[i] != null) tempi[i]!,
      ];
      if (ts.isNotEmpty) {
        final ultimo = idx.reduce((a, b) => a > b ? a : b);
        final k = proprietario[ultimo];
        final minTs = ts.reduce((a, b) => b < a ? b : a);
        final maxTs = ts.reduce((a, b) => b > a ? b : a);
        double fine;
        if (k >= 0 && olds[k].sincronizzata) {
          final o = olds[k];
          final lt = pyLen(o.testo);
          fine =
              o.inizio! +
              (o.fine! - o.inizio!) *
                  (ultimo - proprietario.indexOf(k) + 1) /
                  (lt > 1 ? lt : 1);
        } else {
          fine = maxTs;
        }
        final minimo = minTs + frasMinima;
        p = p.copyWith(
          inizio: pyRoundTo(minTs, 3),
          fine: pyRoundTo(fine > minimo ? fine : minimo, 3),
        );
      }
      if (owners.isNotEmpty) {
        // max(set(owners), key=owners.count): a parità vince il primo nell'ordine del set (crescente
        // per questi indici piccoli)
        final conteggi = <int, int>{};
        for (final o in owners) {
          conteggi[o] = (conteggi[o] ?? 0) + 1;
        }
        final chiavi = conteggi.keys.toList()..sort();
        var k = chiavi.first;
        for (final c in chiavi) {
          if (conteggi[c]! > conteggi[k]!) k = c;
        }
        if (!trUsate.contains(k) &&
            olds[k].tr.isNotEmpty &&
            conteggi[k]! >= 0.6 * pyLen(olds[k].testo)) {
          p = p.copyWith(tr: olds[k].tr);
          trUsate.add(k);
        }
        if (chiavi.any((o) => olds[o].auto)) {
          p = p.copyWith(
            auto: true,
          ); // Viene da tempi automatici: si ridistribuisce anche lei
        }
      }
    }
    out.add(p);
  }
  // I pezzi di una frase divisa si toccano: niente buchi brevi né sovrapposizioni tra loro
  for (var i = 0; i + 1 < out.length; i++) {
    final a = out[i], b = out[i + 1];
    if (a.sincronizzata &&
        b.sincronizzata &&
        b.inizio! > a.inizio! &&
        b.inizio! - a.fine! < 0.3) {
      out[i] = a.copyWith(fine: b.inizio);
    }
  }
  return out;
}

// ---------- Tempi leggibili ----------

/// `format_clock`: «0:07,25» (minuti, secondi e centesimi); trattino se il tempo manca.
String formatoOrologio(double? t) {
  if (t == null) return '–';
  final cs0 = pyRound(t > 0.0 ? t * 100 : 0.0);
  final m = cs0 ~/ 6000;
  final s = (cs0 % 6000) ~/ 100;
  final cs = cs0 % 100;
  return '$m:${s.toString().padLeft(2, '0')},${cs.toString().padLeft(2, '0')}';
}

/// `parse_clock`: legge «1:02,5», «62.5», «0:01:02,500»; null se non è un tempo.
double? leggiOrologio(String testo) {
  final t = pyStrip(testo).replaceAll(',', '.');
  if (t.isEmpty) return null;
  final parti = <double>[];
  for (final x in t.split(':')) {
    final v = _pyFloatTesto(x);
    if (v == null) return null;
    parti.add(v);
  }
  if (parti.length > 3 || parti.any((x) => x < 0)) return null;
  var r = 0.0;
  for (final x in parti) {
    r = r * 60 + x;
  }
  return r;
}

// ---------- File .srt ----------

String _tempoSrt(double t) {
  var ms = pyRound(t > 0.0 ? t * 1000 : 0.0);
  final h = ms ~/ 3600000;
  ms %= 3600000;
  final m = ms ~/ 60000;
  ms %= 60000;
  final s = ms ~/ 1000;
  ms %= 1000;
  String d(int v, int n) => v.toString().padLeft(n, '0');
  return '${d(h, 2)}:${d(m, 2)}:${d(s, 2)},${d(ms, 3)}';
}

/// `to_srt`: frasi sincronizzate (con testo nel campo scelto) in formato SubRip.
String inSrt(List<Frase> frasi, {bool traduzione = false}) {
  String campo(Frase p) => traduzione ? p.tr : p.testo;
  final scelte = [
    for (final p in frasi)
      if (p.sincronizzata && pyStrip(campo(p)).isNotEmpty) p,
  ];
  // `List.sort` di Dart non è stabile: a pari inizio resta l'ordine dell'elenco, come `sorted` di Python
  final ordine = List<int>.generate(scelte.length, (i) => i)
    ..sort((i, j) {
      final c = scelte[i].inizio!.compareTo(scelte[j].inizio!);
      return c != 0 ? c : i.compareTo(j);
    });
  final righe = [for (final i in ordine) scelte[i]];
  final blocchi = <String>[];
  for (var n = 0; n < righe.length; n++) {
    final p = righe[n];
    blocchi.add(
      '${n + 1}\n${_tempoSrt(p.inizio!)} --> ${_tempoSrt(p.fine!)}\n${pyStrip(campo(p))}\n',
    );
  }
  return blocchi.join('\n');
}

final RegExp _tempoSrtRe = RegExp(r'(\d+):(\d{1,2}):(\d{1,2})[,.](\d{1,3})');
final RegExp _bloccoSrt = RegExp('\n$_classeSpazi*\n');
final RegExp _etichetteSrt = RegExp(r'<[^>]+>|\{[^}]*\}');

/// `parse_srt`: file .srt → frasi (le righe di un sottotitolo diventano una frase sola, senza i tag).
List<Frase> leggiSrt(String testo) {
  final t = testo
      .replaceAll('﻿', '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  final out = <Frase>[];
  for (final blocco in t.split(_bloccoSrt)) {
    final righe = [
      for (final r in blocco.split('\n'))
        if (pyStrip(r).isNotEmpty) r,
    ];
    final idx = righe.indexWhere((r) => r.contains('-->'));
    if (idx < 0) continue;
    final tempi = _tempoSrtRe.allMatches(righe[idx]).toList();
    if (tempi.length < 2) continue;
    double sec(RegExpMatch g) =>
        (int.parse(g[1]!) * 3600 + int.parse(g[2]!) * 60 + int.parse(g[3]!)) +
        int.parse(g[4]!.padRight(3, '0')) / 1000.0;
    var corpo = righe.sublist(idx + 1).join(' ');
    corpo = _normalizza(corpo.replaceAll(_etichetteSrt, ''));
    final inizio = sec(tempi[0]), fine = sec(tempi[1]);
    final minimo = inizio + frasMinima;
    out.add(
      Frase(testo: corpo, inizio: inizio, fine: fine > minimo ? fine : minimo),
    );
  }
  return out;
}

// ---------- Forma d'onda e pause ----------

/// `envelope`: picco del volume (0–1) ogni [passo] secondi di audio mono s16 (little endian).
List<double> inviluppo(
  Uint8List pcm,
  int frequenza, [
  double passo = passoInviluppo,
]) {
  final campioni = pcm.lengthInBytes ~/ 2;
  final dati = ByteData.sublistView(pcm, 0, campioni * 2);
  final calcolato = (frequenza * passo).toInt();
  final n = calcolato > 1 ? calcolato : 1;
  final out = <double>[];
  for (var i = 0; i < campioni; i += n) {
    var alto = -32768, basso = 32767;
    final fine = i + n < campioni ? i + n : campioni;
    for (var j = i; j < fine; j++) {
      final v = dati.getInt16(j * 2, Endian.little);
      if (v > alto) alto = v;
      if (v < basso) basso = v;
    }
    out.add((alto > -basso ? alto : -basso) / 32768.0);
  }
  return out;
}

/// Pausa nell'audio: da [inizio] a [fine] secondi.
typedef Pausa = (double inizio, double fine);

/// `find_pauses`: tratti di silenzio lunghi almeno [minimo]; la soglia sta poco sopra il rumore di fondo,
/// stimata dai valori bassi e alti del volume.
List<Pausa> trovaPause(
  List<double> inv, {
  double passo = passoInviluppo,
  double minimo = 0.25,
}) {
  if (inv.isEmpty) return const [];
  final ordinati = List<double>.of(inv)..sort();
  final rumore = ordinati[(ordinati.length * 0.10).toInt()];
  final iForte = (ordinati.length * 0.90).toInt();
  final forte =
      ordinati[iForte < ordinati.length - 1 ? iForte : ordinati.length - 1];
  final soglia0 = rumore + (forte - rumore) * 0.12;
  final soglia = soglia0 > 0.01 ? soglia0 : 0.01;
  final pause = <Pausa>[];
  int? corsa;
  for (var i = 0; i <= inv.length; i++) {
    final v = i < inv.length ? inv[i] : 1.0;
    if (v < soglia) {
      corsa ??= i;
    } else if (corsa != null) {
      if ((i - corsa) * passo >= minimo) {
        pause.add((corsa * passo, i * passo));
      }
      corsa = null;
    }
  }
  return pause;
}

/// `snap_points`: dove una pausa comincia e dove finisce.
List<double> puntiAggancio(List<Pausa> pause) => [
  for (final (a, b) in pause) ...[a, b],
];

/// `snap`: il punto più vicino a [t] entro [tolleranza], altrimenti [t].
double aggancia(double t, List<double> punti, double tolleranza) {
  double? migliore;
  for (final p in punti) {
    if (migliore == null || (p - t).abs() < (migliore - t).abs()) {
      migliore = p;
    }
  }
  return migliore != null && (migliore - t).abs() <= tolleranza ? migliore : t;
}

// ---------- Tempi automatici dall'audio ----------

int _confrontaPause(Pausa p, Pausa q) {
  final c = p.$1.compareTo(q.$1);
  return c != 0 ? c : p.$2.compareTo(q.$2);
}

/// `speech_spans`: tratti di parlato tra [lo] e [hi], cioè quello che resta togliendo le pause.
List<Pausa> trattiParlato(List<Pausa> pause, double lo, double hi) {
  final spans = <Pausa>[];
  var t = lo;
  for (final (a, b) in List<Pausa>.of(pause)..sort(_confrontaPause)) {
    if (a >= hi) break;
    if (b <= t) continue;
    if (a > t) spans.add((t, a));
    final m = b < hi ? b : hi;
    if (m > t) t = m;
  }
  if (hi > t) spans.add((t, hi));
  return spans;
}

/// `auto_times`: inizio e fine di n frasi tra [lo] e [hi]. Il tempo di parlato si spartisce in proporzione ai
/// pesi, poi ogni stacco tra due frasi si sposta sulla pausa vicina, se ce n'è una.
List<Pausa> tempiAutomatici(
  List<double> pesi,
  List<Pausa> pause,
  double lo,
  double hi,
) {
  final n = pesi.length;
  if (n == 0 || hi <= lo) return const [];
  var spans = trattiParlato(pause, lo, hi);
  var totale = pySum([for (final (a, b) in spans) b - a]);
  if (totale < frasMinima * n) {
    spans = [(lo, hi)]; // Quasi tutto silenzio: si usa l'intero tratto
    totale = hi - lo;
  }
  final lens = [for (final (a, b) in spans) b - a];
  // (posizione nel parlato, inizio della pausa, fine della pausa)
  final stacchi = <(double, double, double)>[];
  var acc = 0.0;
  for (var k = 0; k < spans.length - 1; k++) {
    acc += lens[k];
    stacchi.add((acc, spans[k].$2, spans[k + 1].$1));
  }

  double reale(double s) {
    for (var k = 0; k < spans.length; k++) {
      if (s <= lens[k] + 1e-9) return spans[k].$1 + s;
      s -= lens[k];
    }
    return spans.last.$2;
  }

  final somma = pySum(pesi);
  final wTotale = somma != 0.0 ? somma : 1.0;
  final tol = 0.35 * totale / n;
  final inizi = <double>[spans.first.$1];
  final fini = <double>[];
  acc = 0.0;
  var prima = 0.0;
  var gi = 0;
  for (final w in pesi.sublist(0, n - 1)) {
    acc += w;
    final taglio = totale * acc / wTotale;
    int? migliore;
    for (var j = gi; j < stacchi.length; j++) {
      final pos = stacchi[j].$1;
      if (pos > taglio + tol) break;
      if (pos - prima >= frasMinima &&
          (pos - taglio).abs() <= tol &&
          (migliore == null ||
              (pos - taglio).abs() < (stacchi[migliore].$1 - taglio).abs())) {
        migliore = j;
      }
    }
    if (migliore != null) {
      fini.add(stacchi[migliore].$2);
      inizi.add(stacchi[migliore].$3);
      prima = stacchi[migliore].$1;
      gi = migliore + 1;
    } else {
      final t = reale(taglio);
      fini.add(t);
      inizi.add(t);
      prima = taglio;
      while (gi < stacchi.length && stacchi[gi].$1 <= taglio) {
        gi++;
      }
    }
  }
  fini.add(spans.last.$2);
  return [
    for (var i = 0; i < inizi.length; i++)
      (
        pyRoundTo(inizi[i], 3),
        pyRoundTo(fini[i] > inizi[i] + 0.05 ? fini[i] : inizi[i] + 0.05, 3),
      ),
  ];
}

/// `phrase_weight`: quanto dura a voce una frase, a occhio (i caratteri più un piccolo fisso).
double pesoFrase(Frase p) => pyLen(pyStrip(p.testo)) + 8.0;

/// `retime`: tempi automatici per le frasi senza tempi fissati a mano. Ogni gruppo di frasi di seguito si
/// distribuisce tra la frase fissata prima e quella dopo (o i bordi del taglio del video); con [azzera] si
/// ridistribuisce tutto. Se non c'è posto, le frasi restano da sincronizzare.
List<Frase> ridistribuisci(
  List<Frase> frasi,
  List<Pausa> pause,
  double lo,
  double hi, {
  bool azzera = false,
}) {
  final f = [for (final p in frasi) azzera ? p.copyWith(auto: true) : p];
  final n = f.length;
  var i = 0;
  while (i < n) {
    if (f[i].manuale) {
      i++;
      continue;
    }
    var j = i;
    while (j < n && !f[j].manuale) {
      j++;
    }
    final a = i > 0 ? (f[i - 1].fine! > lo ? f[i - 1].fine! : lo) : lo;
    final b = j < n ? (f[j].inizio! < hi ? f[j].inizio! : hi) : hi;
    final gruppo = f.sublist(i, j);
    if (b - a >= frasMinima * gruppo.length) {
      final tempi = tempiAutomatici(
        [for (final p in gruppo) pesoFrase(p)],
        pause,
        a,
        b,
      );
      for (var k = 0; k < gruppo.length; k++) {
        f[i + k] = gruppo[k].copyWith(
          inizio: tempi[k].$1,
          fine: tempi[k].$2,
          auto: true,
        );
      }
    } else {
      for (var k = 0; k < gruppo.length; k++) {
        f[i + k] = gruppo[k].copyWith(inizio: null, fine: null, auto: false);
      }
    }
    i = j;
  }
  return f;
}
