/// Colori come nel desktop: interi ARGB, scritti nel file come `#aarrggbb`
/// (`QColor.name(HexArgb)`, minuscolo).
library;

/// Legge un colore `#rgb`, `#rrggbb` o `#aarrggbb` (come `QColor(str)`); altrimenti [predefinito].
int parseArgb(Object? valore, int predefinito) {
  if (valore is! String || !valore.startsWith('#')) return predefinito;
  final h = valore.substring(1);
  final n = int.tryParse(h, radix: 16);
  if (n == null || h.contains(RegExp('[^0-9a-fA-F]'))) return predefinito;
  switch (h.length) {
    case 3:
      final r = (n >> 8) & 0xF, g = (n >> 4) & 0xF, b = n & 0xF;
      return 0xFF000000 | (r * 17) << 16 | (g * 17) << 8 | (b * 17);
    case 6:
      return 0xFF000000 | n;
    case 8:
      return n;
    default:
      return predefinito;
  }
}

/// `#aarrggbb` minuscolo, come lo scrive il desktop.
String formatArgb(int argb) =>
    '#${(argb & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0')}';
