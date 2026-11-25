/// Semantica della tela per i lettori di schermo (piano §4.7: «etichette su ogni comando»).
///
/// La tela è disegnata (non ha widget): senza aiuto, TalkBack e VoiceOver vedrebbero un solo blocco muto. Qui ogni
/// elemento della pagina corrente diventa un nodo con nome («Foto 2», «Testo: Ciao», «Forma 1»), con le stesse
/// azioni del tocco e della pressione lunga; la tela stessa dice «Pagina 2 di 5» e si può scorrere con le azioni
/// «scorri a sinistra / a destra» del lettore di schermo.
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import '../l10n/app_localizations.dart';
import '../render/disegno.dart' show elementiInOrdine;
import '../theme/tokens.dart';
import 'geometria_tela.dart';

/// Nome parlato di un elemento: «Foto 2», «Video 1», «Testo: Ciao», «Forma 3», con «bloccato» se la pagina lo è.
/// I numeri contano gli elementi dello stesso tipo nell'ordine del documento.
String nomeElemento(Testi t, Snapshot s, CanvasElement e) {
  final nome = switch (e) {
    PhotoItem() =>
      e.isVideo
          ? t.telaVideo(1 + s.items.where((p) => p.isVideo).toList().indexOf(e))
          : t.telaFoto(
              1 + s.items.where((p) => !p.isVideo).toList().indexOf(e),
            ),
    TextItem() => t.telaTesto(_riassunto(e.text)),
    CaptionItem() => t.telaSottotitoli(
      _riassunto(fraseDiEsempio(e)?.testo ?? ''),
    ),
    ShapeItem() => t.telaForma(1 + s.shapes.indexOf(e)),
  };
  return e.pageLocked ? t.telaBloccato(nome) : nome;
}

/// Primo pezzo del testo, su una riga sola, per non far leggere un paragrafo intero.
String _riassunto(String testo) {
  final riga = testo.replaceAll(RegExp(r'\s+'), ' ').trim();
  return riga.length <= 40 ? riga : '${riga.substring(0, 40)}…';
}

/// Elementi della pagina [pagina] (quelli il cui centro cade nella sua parte di striscia), dal più in alto al
/// più in basso, come li toccherebbe un dito.
List<CanvasElement> elementiDellaPagina(
  Snapshot s,
  int pagina,
  TextSizeOf misura,
) {
  final fw = s.canvas.frameW;
  final risultato = <CanvasElement>[];
  for (final e in elementiInOrdine(s).reversed) {
    final d = dimensioniElemento(e, misura);
    final centro = e.x + d.w / 2.0;
    final p = (centro / fw).floor().clamp(0, s.canvas.numFrames - 1);
    if (p == pagina) risultato.add(e);
  }
  return risultato;
}

/// Nodi semantici (invisibili e senza tocchi propri) degli elementi di [pagina], da mettere nello stack della tela.
///
/// [alTocco] è lo stesso gesto del tocco con il dito, [alMenu] quello della pressione lunga.
List<Widget> nodiElementi({
  required BuildContext context,
  required Snapshot snapshot,
  required GeometriaTela geo,
  required int pagina,
  required TextSizeOf misura,
  required Set<RifElemento> selezione,
  required void Function(CanvasElement) alTocco,
  required void Function(CanvasElement) alMenu,
}) {
  final t = Testi.of(context);
  final g = geo.conPos(pagina.toDouble());
  final nodi = <Widget>[];
  for (final e in elementiDellaPagina(snapshot, pagina, misura)) {
    final corners = angoliElemento(e, misura);
    final xs = [for (final c in corners) c.$1];
    final ys = [for (final c in corners) c.$2];
    final centro = g.aSchermo(
      (xs.reduce(math.min) + xs.reduce(math.max)) / 2,
      (ys.reduce(math.min) + ys.reduce(math.max)) / 2,
    );
    // Almeno 48 dp, così il contorno del lettore di schermo è una zona che si vede e si indica
    final w = math.max(
      MisureScrl.tocco,
      (xs.reduce(math.max) - xs.reduce(math.min)) * g.scala,
    );
    final h = math.max(
      MisureScrl.tocco,
      (ys.reduce(math.max) - ys.reduce(math.min)) * g.scala,
    );
    final nome = nomeElemento(t, snapshot, e);
    final selezionato = selezione.contains(rifDi(e));
    nodi.add(
      Positioned(
        left: centro.dx - w / 2,
        top: centro.dy - h / 2,
        width: w,
        height: h,
        // Niente IgnorePointer: toglierebbe anche la semantica. Un SizedBox senza figli non prende i tocchi
        child: Semantics(
          label: nome,
          button: !e.pageLocked,
          selected: selezionato,
          onTap: e.pageLocked ? null : () => alTocco(e),
          onLongPress: e.pageLocked ? null : () => alMenu(e),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
  return nodi;
}
