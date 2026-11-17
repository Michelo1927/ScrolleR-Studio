import 'dart:convert';
import 'dart:io';

import 'package:scrl_engine/scrl_engine.dart';
import 'package:test/test.dart';

/// Geometria del disegno delle foto confrontata con `PhotoItem` del desktop (`test/riferimenti/geometria.json`).
void main() {
  final casi = (jsonDecode(
    File('test/riferimenti/geometria.json').readAsStringSync(),
  ) as List).cast<Map<String, Object?>>();

  PhotoItem foto(Map<String, Object?> c) =>
      PhotoItem.fromJson({'uid': 1, 'path': 'x.jpg', ...c});

  void vicini(List<double> a, List<Object?> b, String perche) {
    expect(a.length, b.length, reason: perche);
    for (var i = 0; i < a.length; i++) {
      expect(
        a[i],
        closeTo((b[i]! as num).toDouble(), 1e-6),
        reason: '$perche [$i]',
      );
    }
  }

  test('cover, trasformazione, parte visibile e ombra come il desktop', () {
    expect(casi, isNotEmpty);
    for (final c in casi) {
      final p = foto((c['foto']! as Map).cast<String, Object?>());
      final im = (c['img']! as List).cast<int>();
      final perche = '${c['foto']} ${c['img']}';
      final g = p.coverFor(im[0], im[1]);
      vicini(
        [g.scale, g.dx, g.dy, g.drawW, g.drawH],
        c['cover']! as List,
        perche,
      );
      final t = p.imageTransform();
      vicini([t.a, t.b, t.c, t.d, t.e, t.f], c['transform']! as List, perche);
      final v = p.visibleImageRect(im[0], im[1]);
      vicini([v.x, v.y, v.w, v.h], c['visibile']! as List, perche);
      final o = c['ombra']! as List;
      expect(p.shadowExtent, closeTo((o[0]! as num).toDouble(), 1e-9));
      if (p.shadow > 0) expect(p.shadowAlpha, o[1]);
    }
  });

  test('taglio dei video (clip_end, clip_length)', () {
    final v = PhotoItem(
      uid: 1,
      path: 'v.mp4',
      isVideo: true,
      trimStart: 2.0,
      trimEnd: 50.0,
    );
    expect(clipEnd(v, 30.0), 30.0);
    expect(clipLength(v, 30.0), 28.0);
    expect(clipEnd(v, 0.0), 50.0);
  });
}
