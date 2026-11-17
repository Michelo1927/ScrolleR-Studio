import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scrollr_studio/media/importa.dart';

void main() {
  test('nome libero come `_unique_name` del desktop', () {
    final usati = <String>{};
    expect(nomeLibero('foto.jpg', usati), 'foto.jpg');
    // Maiuscole e minuscole: stesso nome
    expect(nomeLibero('Foto.JPG', usati), 'Foto_2.JPG');
    expect(nomeLibero('foto.jpg', usati), 'foto_3.jpg');
    expect(nomeLibero('senza', usati), 'senza');
    expect(nomeLibero('senza', usati), 'senza_2');
    expect(nomeLibero('.nascosto', usati), '.nascosto');
    expect(nomeLibero('.nascosto', usati), '.nascosto_2');
  });

  test('video riconosciuti dall\'estensione', () {
    expect(eVideo('clip.MOV'), isTrue);
    expect(eVideo('clip.webm'), isTrue);
    expect(eVideo('foto.heic'), isFalse);
  });

  test(
    'copia in media/: nomi liberi, percorsi relativi, originali intatti',
    () async {
      final tmp = await Directory.systemTemp.createTemp('importa_');
      try {
        final progetto = Directory('${tmp.path}/progetto');
        Directory('${progetto.path}/media').createSync(recursive: true);
        File('${progetto.path}/media/foto.jpg').writeAsStringSync('vecchia');
        final a = File('${tmp.path}/a.jpg')..writeAsStringSync('A');
        final b = File('${tmp.path}/b.mp4')..writeAsStringSync('B');

        final copiati = await copiaInMedia([
          (percorso: a.path, nome: 'foto.jpg'),
          (percorso: b.path, nome: 'cartella/vi:deo.mp4'),
        ], progetto);

        expect(copiati.map((f) => f.rel), [
          'media/foto_2.jpg',
          'media/vi_deo.mp4',
        ]);
        expect(copiati.map((f) => f.video), [false, true]);
        expect(
          File('${progetto.path}/media/foto.jpg').readAsStringSync(),
          'vecchia',
        );
        expect(
          File('${progetto.path}/media/foto_2.jpg').readAsStringSync(),
          'A',
        );
        expect(
          File('${progetto.path}/media/vi_deo.mp4').readAsStringSync(),
          'B',
        );
        // Le sorgenti non si toccano: le copie temporanee del selettore le elimina scegliECopia
        expect(a.existsSync(), isTrue);
      } finally {
        tmp.deleteSync(recursive: true);
      }
    },
  );
}
