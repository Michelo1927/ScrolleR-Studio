/// Aggancio magnetico, portato da `scrollr/canvas/snap.py` (`snap_selection`): l'elemento trascinato si
/// avvicina a bordi e centri della tela, delle pagine e degli altri elementi entro una distanza in pixel dello
/// schermo. Il motore calcola lo spostamento da aggiungere e le linee da mostrare (magenta); l'aptica spetta all'app.
library;

import '../model/context.dart';
import '../model/elements.dart';
import '../model/scene.dart';
import '../model/snapshot.dart';
import 'elementi.dart';

/// Distanza di aggancio in pixel dello schermo (`SNAP_PX`).
const double aggancioPixel = 8.0;

class Aggancio {
  /// Spostamento da aggiungere per stare sulla linea (0 se non c'è aggancio sull'asse).
  final double dx;
  final double dy;

  /// Linee verticali (x) e orizzontali (y) agganciate, in coordinate della striscia.
  final List<double> lineeX;
  final List<double> lineeY;

  const Aggancio(this.dx, this.dy, this.lineeX, this.lineeY);

  static const nessuno = Aggancio(0, 0, [], []);

  bool get attivo => lineeX.isNotEmpty || lineeY.isNotEmpty;
}

/// Riquadro in scena usato come riferimento dall'aggancio: foto e forme (i testi non agganciano né fanno da
/// riferimento, come sul desktop, dove solo `PhotoItem` e `ShapeItem` hanno `snap_rect`).
Rect? _riquadroAggancio(CanvasElement e) => switch (e) {
  PhotoItem() => e.cellRect,
  ShapeItem() => e.frameRect,
  TextItem() => null,
};

/// Quanto agganciare [riquadro] (l'ingombro dell'elemento trascinato, già nella nuova posizione).
/// [selezione] sono gli elementi che si muovono insieme: non fanno da riferimento. [distanza] è in unità della
/// tela (`aggancioPixel / zoom`).
Aggancio calcolaAggancio(
  Snapshot s,
  Rect riquadro,
  Iterable<RifElemento> selezione,
  double distanza,
) {
  final c = s.canvas;
  final fw = c.frameW.toDouble(), fh = c.frameH.toDouble();
  final bersagliX = <double>[];
  final bersagliY = <double>[0.0, fh / 2.0, fh];
  for (var i = 0; i <= c.numFrames; i++) {
    bersagliX.add(i * fw);
    if (i < c.numFrames) bersagliX.add(i * fw + fw / 2.0);
  }
  final esclusi = selezione.toSet();
  for (final e in s.allElements) {
    if (esclusi.contains(rifDi(e))) continue;
    final r = _riquadroAggancio(e);
    if (r == null) continue;
    bersagliX.addAll([r.left, r.centerX, r.right]);
    bersagliY.addAll([r.top, r.centerY, r.bottom]);
  }

  (double, double)? migliore(List<double> bordi, List<double> bersagli) {
    (double, double)? best;
    for (final e in bordi) {
      for (final t in bersagli) {
        final d = t - e;
        if (d.abs() < distanza && (best == null || d.abs() < best.$1.abs())) {
          best = (d, t);
        }
      }
    }
    return best;
  }

  final bx = migliore([
    riquadro.left,
    riquadro.centerX,
    riquadro.right,
  ], bersagliX);
  final by = migliore([
    riquadro.top,
    riquadro.centerY,
    riquadro.bottom,
  ], bersagliY);
  return Aggancio(bx?.$1 ?? 0.0, by?.$1 ?? 0.0, [?bx?.$2], [?by?.$2]);
}

/// Ingombro di un elemento (rotazione inclusa) per l'aggancio: come `_element_rect`.
Rect ingombroElemento(Snapshot s, CanvasElement e, EngineContext ctx) =>
    Scene(s, ctx).elementRect(e);
