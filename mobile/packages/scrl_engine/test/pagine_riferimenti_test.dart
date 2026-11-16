import 'package:scrl_engine/scrl_engine.dart';
import 'package:test/test.dart';

import 'riferimenti_util.dart';

/// Azioni vere del desktop su pagine e tela (`pagine.jsonl`), rifatte col motore e confrontate.
void main() {
  for (final caso in leggiJsonl('pagine.jsonl')) {
    final id = caso['id']! as String;
    test('pagine $id', () {
      final prima = StatoDesktop.fromJson(
        caso['prima']! as Map<String, Object?>,
      );
      final ctx = prima.contesto();
      var s = prima.snapshot;
      for (final azione in (caso['azioni']! as List).cast<List<Object?>>()) {
        s = esegui(
          s,
          azione[0]! as String,
          (azione[1]! as List).cast<Object?>(),
          ctx,
        ).snapshot;
      }
      final errori = confrontaStati(
        s,
        caso['dopo']! as Map<String, Object?>,
        prima.snapshot,
      );
      expect(errori, isEmpty, reason: '$id\n${errori.take(15).join('\n')}');
    });
  }
}

/// L'operazione del motore che corrisponde all'azione del desktop registrata dallo script.
EngineResult esegui(Snapshot s, String op, List<Object?> a, EngineContext ctx) {
  int i(int k) => a[k]! as int;
  List<int> l(int k) => (a[k]! as List).cast<int>();
  return switch (op) {
    'insert' => insertPageAt(s, i(0), ctx),
    'duplicate' => duplicatePage(s, i(0), ctx),
    'delete' => deletePage(s, i(0), ctx),
    'move' => movePage(s, i(0), i(1), ctx),
    'reorder' => reorderPages(s, l(0), ctx),
    'lock' => setPageLock(s, i(0), a[1]! as bool, ctx),
    'join' => setPageJoined(s, i(0), a[1]! as bool, ctx),
    'page_layout' => setPageLayout(
      s,
      i(0),
      a[1] as String?,
      ctx,
      a.length > 2 ? a[2] as String? : null,
    ),
    'page_count' => setPageCount(s, i(0), a[1] as int?, ctx),
    'frames' => setNumFrames(s, i(0), ctx),
    'ratio' => setAspectRatio(s, i(0), ctx),
    'custom' => setCustomSize(s, i(0), i(1), ctx),
    'per_page' => setPerPage(s, i(0), ctx),
    'per_frame' => setPerFrame(s, a[0]! as bool, ctx),
    'gap' => setSpacing(s, ctx, gap: i(0)),
    'margin' => setSpacing(s, ctx, margin: i(0)),
    'layout' => chooseLayout(s, a[0]! as String, ctx, seed: i(1)),
    'mosaic_style' => setMosaicStyle(s, a[0]! as String, ctx),
    'move_photos' => movePhotosToPage(s, l(0), i(1), ctx),
    'free' => toggleFree(s, l(0), ctx),
    'swap' => swapPhotos(s, i(0), i(1), ctx),
    _ => throw ArgumentError(op),
  };
}
