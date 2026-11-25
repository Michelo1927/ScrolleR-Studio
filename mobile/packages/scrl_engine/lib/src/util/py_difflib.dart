/// `difflib.SequenceMatcher` di Python (con `isjunk=None` e `autojunk=False`), portato riga per riga.
///
/// Serve ai sottotitoli (`merge_lines` di `scrollr/captions.py`): con le stesse sequenze dà gli stessi
/// blocchi uguali e le stesse operazioni del desktop, così i tempi delle frasi si conservano allo stesso modo.
library;

/// Tratto uguale: `a[a..a+size] == b[b..b+size]`.
typedef Corrispondenza = ({int a, int b, int size});

/// Operazione di `get_opcodes`: `tag` è `equal`, `replace`, `delete` o `insert`.
typedef Operazione = ({String tag, int i1, int i2, int j1, int j2});

class SequenceMatcher<T> {
  final List<T> a;
  final List<T> b;
  final Map<T, List<int>> _b2j = {};

  SequenceMatcher(this.a, this.b) {
    for (var i = 0; i < b.length; i++) {
      (_b2j[b[i]] ??= <int>[]).add(i);
    }
  }

  /// `find_longest_match`: il tratto uguale più lungo in `a[alo:ahi]` e `b[blo:bhi]`; a parità il primo in `a`,
  /// poi il primo in `b`.
  Corrispondenza findLongestMatch(int alo, int ahi, int blo, int bhi) {
    var besti = alo, bestj = blo, bestsize = 0;
    var j2len = <int, int>{};
    for (var i = alo; i < ahi; i++) {
      final newj2len = <int, int>{};
      for (final j in _b2j[a[i]] ?? const <int>[]) {
        if (j < blo) continue;
        if (j >= bhi) break;
        final k = newj2len[j] = (j2len[j - 1] ?? 0) + 1;
        if (k > bestsize) {
          besti = i - k + 1;
          bestj = j - k + 1;
          bestsize = k;
        }
      }
      j2len = newj2len;
    }
    // Senza elementi «junk» le estensioni di Python si riducono a queste due
    while (besti > alo && bestj > blo && a[besti - 1] == b[bestj - 1]) {
      besti--;
      bestj--;
      bestsize++;
    }
    while (besti + bestsize < ahi &&
        bestj + bestsize < bhi &&
        a[besti + bestsize] == b[bestj + bestsize]) {
      bestsize++;
    }
    return (a: besti, b: bestj, size: bestsize);
  }

  List<Corrispondenza>? _blocchi;

  /// `get_matching_blocks`: tratti uguali in ordine, uniti se adiacenti, con l'ultimo `(len(a), len(b), 0)`.
  List<Corrispondenza> getMatchingBlocks() {
    final pronti = _blocchi;
    if (pronti != null) return pronti;
    final la = a.length, lb = b.length;
    final coda = <(int, int, int, int)>[(0, la, 0, lb)];
    final trovati = <Corrispondenza>[];
    while (coda.isNotEmpty) {
      final (alo, ahi, blo, bhi) = coda.removeLast();
      final x = findLongestMatch(alo, ahi, blo, bhi);
      final (i, j, k) = (x.a, x.b, x.size);
      if (k > 0) {
        trovati.add(x);
        if (alo < i && blo < j) coda.add((alo, i, blo, j));
        if (i + k < ahi && j + k < bhi) coda.add((i + k, ahi, j + k, bhi));
      }
    }
    trovati.sort((p, q) {
      if (p.a != q.a) return p.a.compareTo(q.a);
      if (p.b != q.b) return p.b.compareTo(q.b);
      return p.size.compareTo(q.size);
    });
    var i1 = 0, j1 = 0, k1 = 0;
    final uniti = <Corrispondenza>[];
    for (final m in trovati) {
      if (i1 + k1 == m.a && j1 + k1 == m.b) {
        k1 += m.size;
      } else {
        if (k1 > 0) uniti.add((a: i1, b: j1, size: k1));
        (i1, j1, k1) = (m.a, m.b, m.size);
      }
    }
    if (k1 > 0) uniti.add((a: i1, b: j1, size: k1));
    uniti.add((a: la, b: lb, size: 0));
    return _blocchi = List.unmodifiable(uniti);
  }

  /// `get_opcodes`: come trasformare `a` in `b`.
  List<Operazione> getOpcodes() {
    var i = 0, j = 0;
    final out = <Operazione>[];
    for (final m in getMatchingBlocks()) {
      var tag = '';
      if (i < m.a && j < m.b) {
        tag = 'replace';
      } else if (i < m.a) {
        tag = 'delete';
      } else if (j < m.b) {
        tag = 'insert';
      }
      if (tag.isNotEmpty) out.add((tag: tag, i1: i, i2: m.a, j1: j, j2: m.b));
      i = m.a + m.size;
      j = m.b + m.size;
      if (m.size > 0) {
        out.add((tag: 'equal', i1: m.a, i2: i, j1: m.b, j2: j));
      }
    }
    return out;
  }
}
