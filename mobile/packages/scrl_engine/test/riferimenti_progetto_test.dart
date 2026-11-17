import 'dart:convert';

import 'package:scrl_engine/scrl_engine.dart';
import 'package:test/test.dart';

MediaAsset _asset(String id, String nome, {String platform = 'android'}) =>
    MediaAsset(platform: platform, id: id, name: nome);

/// Progetto con una foto della galleria, una dentro il progetto, un video, una foto del PC con `rel`, una voce di
/// libreria in più e la foto di sfondo sfocato collegata alla galleria. Una foto ha un campo sconosciuto.
ProjectFile _progetto() {
  final galleria = PhotoItem(
    uid: 1,
    path: 'IMG_1.jpg',
    asset: _asset('11', 'IMG_1.jpg'),
    extra: const {'campo_futuro': 7},
  );
  final media = PhotoItem(uid: 2, path: 'media/b.jpg', rel: 'media/b.jpg');
  final video = PhotoItem(
    uid: 3,
    path: 'clip.mp4',
    asset: _asset('33', 'clip.mp4'),
    isVideo: true,
  );
  final pc = PhotoItem(uid: 4, path: r'C:\Foto\d.jpg', rel: 'Foto/d.jpg');
  final canvas = CanvasState(
    bgMode: 'blur',
    bgBlurPath: 'IMG_1.jpg',
    extra: {campoSfondoAsset: _asset('11', 'IMG_1.jpg').toJson()},
  );
  return ProjectFile(
    snapshot: Snapshot(canvas: canvas, items: [galleria, media, video, pc]),
    library: [
      LibraryEntry(path: 'IMG_1.jpg', asset: _asset('11', 'IMG_1.jpg')),
      LibraryEntry(
        path: 'solo-libreria.jpg',
        asset: _asset('55', 'solo-libreria.jpg'),
      ),
      LibraryEntry(path: 'media/b.jpg', rel: 'media/b.jpg'),
    ],
    extra: const {'altro': true},
  );
}

void main() {
  group('chiavi e elenco', () {
    test('la chiave distingue galleria e file, e per i file vale rel', () {
      expect(
        chiaveRiferimento('x.jpg', null, _asset('9', 'x.jpg')),
        'a:android:9',
      );
      expect(
        chiaveRiferimento('media/b.jpg', 'media/b.jpg', null),
        'f:media/b.jpg',
      );
      expect(chiaveRiferimento('b.jpg', null, null), 'f:b.jpg');
    });

    test('elenca ogni file una volta, con dove è usato', () {
      final l = elencaRiferimenti(_progetto().snapshot, _progetto().library);
      final per = {for (final r in l) r.chiave: r};
      expect(per.keys, {
        'a:android:11',
        'f:media/b.jpg',
        'a:android:33',
        'f:Foto/d.jpg',
        'a:android:55',
      });
      expect(per['a:android:11']!.usiSullaTela, 1);
      expect(per['a:android:11']!.nellaLibreria, isTrue);
      expect(per['a:android:11']!.comeSfondo, isTrue);
      expect(per['a:android:33']!.video, isTrue);
      expect(per['a:android:55']!.usiSullaTela, 0);
      expect(per['a:android:55']!.nome, 'solo-libreria.jpg');
      expect(per['f:Foto/d.jpg']!.nome, 'd.jpg');
    });
  });

  group('preparaPerCondivisione', () {
    test('punta alle copie in media/ e toglie ogni asset', () {
      final f = preparaPerCondivisione(_progetto(), {
        'a:android:11': 'media/IMG_1.jpg',
        'f:media/b.jpg': 'media/b.jpg',
        'a:android:33': 'media/clip.mp4',
      });
      final it = {for (final p in f.snapshot.items) p.uid: p};
      expect(
        (it[1]!.path, it[1]!.rel, it[1]!.asset),
        ('media/IMG_1.jpg', 'media/IMG_1.jpg', null),
      );
      expect(
        (it[3]!.path, it[3]!.rel, it[3]!.asset),
        ('media/clip.mp4', 'media/clip.mp4', null),
      );
      // Non copiata e senza asset: com'era
      expect((it[4]!.path, it[4]!.rel), (r'C:\Foto\d.jpg', 'Foto/d.jpg'));
      // Sfondo e libreria seguono
      expect(f.snapshot.canvas.bgBlurPath, 'media/IMG_1.jpg');
      expect(f.snapshot.canvas.bgBlurRel, 'media/IMG_1.jpg');
      expect(f.snapshot.canvas.extra.containsKey(campoSfondoAsset), isFalse);
      expect(f.library[0].rel, 'media/IMG_1.jpg');
      expect(f.library[0].asset, isNull);
      // Campi sconosciuti conservati
      expect(it[1]!.extra['campo_futuro'], 7);
      expect(f.extra['altro'], true);
      final json = jsonDecode(f.encode()) as Map<String, Object?>;
      expect(jsonEncode(json).contains('"asset"'), isFalse);
    });

    test('un file non copiato (mancante) resta col nome e senza asset', () {
      final f = preparaPerCondivisione(_progetto(), {});
      final p = f.snapshot.items.firstWhere((p) => p.uid == 1);
      expect((p.path, p.rel, p.asset), ('IMG_1.jpg', null, null));
      expect(f.library[1].path, 'solo-libreria.jpg');
      expect(f.library[1].asset, isNull);
    });

    test('il progetto di partenza non cambia', () {
      final p = _progetto();
      preparaPerCondivisione(p, {'a:android:11': 'media/IMG_1.jpg'});
      expect(p.snapshot.items.first.asset, isNotNull);
    });
  });

  group('senzaCollegamenti', () {
    test('toglie asset, tiene nome e rel', () {
      final f = senzaCollegamenti(_progetto());
      for (final p in f.snapshot.items) {
        expect(p.asset, isNull);
      }
      final it = {for (final p in f.snapshot.items) p.uid: p};
      expect(it[1]!.path, 'IMG_1.jpg');
      expect(it[2]!.rel, 'media/b.jpg');
      expect(it[4]!.rel, 'Foto/d.jpg');
      expect(f.library.every((e) => e.asset == null), isTrue);
      expect(f.snapshot.canvas.extra.containsKey(campoSfondoAsset), isFalse);
    });

    test('un progetto senza asset resta uguale', () {
      final f = senzaCollegamenti(_progetto());
      final dinuovo = senzaCollegamenti(f);
      expect(dinuovo.encode(), f.encode());
    });
  });

  group('riscrittura e cronologia', () {
    test('ricollegare cambia tela, libreria, sfondo e ogni passo', () {
      final p = _progetto();
      final ctx = EngineContext(imageSize: (_) => (w: 800, h: 600));
      final r = History.reset(p.snapshot, ctx);
      final h2 = r.history.commit(
        p.snapshot.copyWith(
          items: [
            for (final i in p.snapshot.items) i.uid == 2 ? i.copyWith(x: 5) : i,
          ],
        ),
        ctx,
      );
      expect(h2.history.states.length, 2);
      final nuovo = _asset('99', 'IMG_1.jpg');
      Collegamento fn(Collegamento c) => chiaveDi(c) == 'a:android:11'
          ? (path: 'IMG_1.jpg', rel: null, asset: nuovo)
          : c;
      final h = h2.history.riscritta((s) => riscriviSnapshot(s, fn));
      expect(h.index, 1);
      expect(h.labels, h2.history.labels);
      for (final s in h.states) {
        expect(s.items.firstWhere((i) => i.uid == 1).asset!.id, '99');
        expect(collegamentoSfondo(s.canvas)!.asset!.id, '99');
      }
      expect(riscriviLibreria(p.library, fn)[0].asset!.id, '99');
      // Le altre non si toccano
      expect(h.current.items.firstWhere((i) => i.uid == 3).asset!.id, '33');
      expect(
        h.current.items.firstWhere((i) => i.uid == 1).extra['campo_futuro'],
        7,
      );
    });

    test('niente da riscrivere: stesso oggetto', () {
      final s = _progetto().snapshot;
      expect(identical(riscriviSnapshot(s, (c) => c), s), isTrue);
    });
  });
}
