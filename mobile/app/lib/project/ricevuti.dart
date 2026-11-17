/// File che arrivano da un'altra app: «Apri con ScrolleR Studio» (`.scrlproj`, `.zip`) e «Condividi con ScrolleR Studio»
/// (foto e video dalla galleria). Il codice nativo (Android: `MainActivity.kt`; iOS: `AppDelegate.swift`) copia i file
/// ricevuti nella cartella temporanea dell'app (un `content://` o un file di un'altra app non si possono tenere) e li
/// consegna a Dart su questo canale, una volta sola.
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'scambio.dart';

abstract class Ricevitore {
  /// File con cui l'app è stata aperta (una volta sola: poi l'elenco si svuota).
  Future<List<FileRicevuto>> iniziali();

  /// File arrivati con l'app già aperta.
  void ascolta(void Function(List<FileRicevuto> file) alRicevere);

  void smetti();
}

class RicevitoreCanale implements Ricevitore {
  static const _canale = MethodChannel(
    'io.github.michelo1927.scrollerstudio/ricevuti',
  );

  static List<FileRicevuto> _leggi(Object? dati) => [
    if (dati is List)
      for (final m in dati) ?FileRicevuto.daMappa(m),
  ];

  @override
  Future<List<FileRicevuto>> iniziali() async {
    try {
      return _leggi(await _canale.invokeMethod<Object?>('iniziali'));
    } on MissingPluginException {
      return const []; // Piattaforma senza il codice nativo (computer, prove)
    } on PlatformException {
      return const [];
    }
  }

  @override
  void ascolta(void Function(List<FileRicevuto> file) alRicevere) {
    _canale.setMethodCallHandler((call) async {
      if (call.method == 'nuovi') {
        final l = _leggi(call.arguments);
        if (l.isNotEmpty) alRicevere(l);
      }
    });
  }

  @override
  void smetti() => _canale.setMethodCallHandler(null);
}

/// L'app può ricevere file da fuori: il canale vero; le prove lo sostituiscono.
final ricevitoreProvider = Provider<Ricevitore>((ref) => RicevitoreCanale());
