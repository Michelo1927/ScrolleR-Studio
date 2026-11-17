/// Regole dell'esportazione delle immagini (piano §6 «Esportazione» e §11), portate da `scrollr/window/export.py`:
/// nome dei file, misure di uscita, qualità JPG e limite di pixel del collage.
library;

import '../model/canvas_state.dart';

/// Qualità JPG selezionabili, dalla più alta (`combo_jpg_quality` del desktop).
const List<int> qualitaJpg = [100, 95, 92, 85, 75];

/// Qualità JPG predefinita.
const int qualitaJpgPredefinita = 92;

/// Scale di esportazione: 1× (standard) e 2× (alta definizione, predefinita).
const List<int> scaleEsportazione = [1, 2];
const int scalaEsportazionePredefinita = 2;

/// Pixel oltre i quali il collage intero non si compone più in memoria sul telefono (≈ 160 MB di RGBA).
/// Oltre questo limite si propone 1× o le pagine separate, come fa il desktop quando manca la memoria.
const int pixelMassimiCollage = 40000000;

/// La qualità valida più vicina a [q] (come `combo_jpg_quality` col valore salvato).
int qualitaJpgValida(int q) {
  var migliore = qualitaJpg.first;
  for (final v in qualitaJpg) {
    if ((v - q).abs() < (migliore - q).abs()) migliore = v;
  }
  return migliore;
}

/// La scala valida più vicina a [s]: 1 o 2.
int scalaValida(int s) => s <= 1 ? 1 : 2;

/// `_clean_file_name`: nome usabile come file su Windows e Mac. Niente caratteri vietati, spazi o punti ai bordi,
/// niente estensione `.png`/`.jpg`/`.jpeg` in fondo.
String pulisciNomeFile(String nome) {
  var n = nome.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '');
  n = _senzaBordi(n);
  n = n.replaceFirst(RegExp(r'\.(png|jpe?g)$', caseSensitive: false), '');
  return n.trim();
}

/// `str.strip().strip('.')` di Python.
String _senzaBordi(String s) {
  var t = s.trim();
  var a = 0, b = t.length;
  while (a < b && t[a] == '.') {
    a++;
  }
  while (b > a && t[b - 1] == '.') {
    b--;
  }
  t = t.substring(a, b);
  return t;
}

/// Estensione dei file per il formato scelto.
String estensioneImmagine(bool jpg) => jpg ? '.jpg' : '.png';

/// Tipo MIME dell'immagine esportata.
String mimeImmagine(bool jpg) => jpg ? 'image/jpeg' : 'image/png';

/// `_page_file_name`: «viaggio_01.jpg» col nome scelto, altrimenti «frame_01.jpg».
String nomeFilePagina(String nome, int k, String ext) {
  final base = pulisciNomeFile(nome);
  final num = (k + 1).toString().padLeft(2, '0');
  return '${base.isEmpty ? 'frame' : base}_$num$ext';
}

/// Nome del file del collage intero: il nome scelto, altrimenti `collage_1080x1440_3pagine_6480x2880.png`.
String nomeFileCollage(String nome, CanvasState c, int scala, String ext) {
  final base = pulisciNomeFile(nome);
  if (base.isNotEmpty) return '$base$ext';
  final m = MisureUscita(c, scala);
  final tag = c.numFrames > 1 ? '_${c.numFrames}pagine' : '';
  return 'collage_${c.frameW}x${c.frameH}$tag'
      '_${m.collageW}x${m.collageH}$ext';
}

/// Misure in pixel dell'immagine esportata a [scala] pixel per unità della tela (`int(w * scale)`).
class MisureUscita {
  MisureUscita(CanvasState c, this.scala)
    : paginaW = c.frameW * scala,
      paginaH = c.frameH * scala,
      pagine = c.numFrames;

  final int scala;
  final int paginaW;
  final int paginaH;
  final int pagine;

  int get collageW => paginaW * pagine;
  int get collageH => paginaH;

  /// Pixel dell'immagine di una pagina e del collage intero.
  int get pixelPagina => paginaW * paginaH;
  int get pixelCollage => collageW * collageH;

  /// Il collage intero ci sta nel limite di memoria del telefono.
  bool get collageEntra => pixelCollage <= pixelMassimiCollage;
}
