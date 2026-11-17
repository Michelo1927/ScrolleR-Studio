/// Controllo degli aggiornamenti (piano §5.4 e Fase 10): l'unico uso della rete dell'app.
///
/// Legge l'elenco delle release di GitHub e **tiene solo i tag `mobile-v*`**: le release del desktop (`v*`) stanno
/// nella stessa repo ma non riguardano il telefono. Le bozze e le pre-release si ignorano. Si controlla all'avvio
/// al massimo una volta al giorno (come il desktop, `updates.py`), si può disattivare in Impostazioni e non si
/// invia niente di personale: solo una richiesta GET anonima.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../export/preferenze.dart';

/// Repo delle release (la stessa del desktop).
const String repoRilasci = 'Michelo1927/ScrolleR-Studio';

/// Prefisso dei tag delle release mobile; i tag `v*` sono del desktop.
const String prefissoTagMobile = 'mobile-v';

/// Al massimo un controllo automatico ogni 24 ore.
const Duration intervalloControllo = Duration(hours: 24);

// Chiavi delle preferenze
const String chiaveControlloAttivo = 'update_check';
const String chiaveUltimoControllo = 'update_last_check';
const String chiaveUltimaTrovata = 'update_latest';
const String chiaveIgnorata = 'update_ignored';

/// Una release mobile più nuova di quella installata.
class NuovaVersione {
  const NuovaVersione({required this.versione, required this.tag});

  /// «1.0.1»
  final String versione;

  /// «mobile-v1.0.1»
  final String tag;

  /// Pagina della release (dove si scarica l'APK).
  Uri get indirizzo =>
      Uri.parse('https://github.com/$repoRilasci/releases/tag/$tag');

  @override
  bool operator ==(Object other) => other is NuovaVersione && other.tag == tag;

  @override
  int get hashCode => tag.hashCode;
}

/// «mobile-v1.2.0» o «v1.2.0» o «1.2.0» → [1, 2, 0]; null se non c'è un numero di versione.
List<int>? analizzaVersione(String testo) {
  final m = RegExp(r'(\d+)(?:\.(\d+))?(?:\.(\d+))?').firstMatch(testo);
  if (m == null) return null;
  return [for (var i = 1; i <= 3; i++) int.tryParse(m.group(i) ?? '') ?? 0];
}

/// [a] è una versione più nuova di [b] (confronto numerico, non alfabetico: «1.10.0» > «1.9.0»).
bool piuNuova(String a, String b) {
  final x = analizzaVersione(a), y = analizzaVersione(b);
  if (x == null || y == null) return false;
  for (var i = 0; i < 3; i++) {
    if (x[i] != y[i]) return x[i] > y[i];
  }
  return false;
}

/// Dall'elenco JSON delle release di GitHub: la release mobile più alta, se è più nuova di [corrente].
/// Ignora i tag che non iniziano per `mobile-v`, le bozze e le pre-release.
NuovaVersione? ultimaMobile(Object? json, String corrente) {
  if (json is! List) return null;
  NuovaVersione? migliore;
  for (final r in json) {
    if (r is! Map) continue;
    final tag = r['tag_name'];
    if (tag is! String || !tag.startsWith(prefissoTagMobile)) continue;
    if (r['draft'] == true || r['prerelease'] == true) continue;
    final versione = tag.substring(prefissoTagMobile.length);
    if (analizzaVersione(versione) == null) continue;
    if (migliore == null || piuNuova(versione, migliore.versione)) {
      migliore = NuovaVersione(versione: versione, tag: tag);
    }
  }
  if (migliore == null || !piuNuova(migliore.versione, corrente)) return null;
  return migliore;
}

/// Risposta di un controllo: la versione nuova (se c'è) e se la rete o la risposta hanno dato errore.
class EsitoControllo {
  const EsitoControllo({this.nuova, this.errore = false});
  final NuovaVersione? nuova;
  final bool errore;
}

/// Scarica il testo dell'indirizzo (null se non riesce). Le prove lo sostituiscono: niente rete vera.
typedef ScaricaTesto = Future<String?> Function(Uri indirizzo);

/// Richiesta GET anonima con un limite di 8 secondi; chiede a GitHub la versione 2022-11-28 dell'API.
Future<String?> scaricaTestoDaRete(
  Uri indirizzo, {
  String versione = '',
}) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8)
    // Nome generico del programma: niente dati dell'utente (regola per le richieste esterne)
    ..userAgent = 'ScrolleR-Studio-Mobile/$versione';
  try {
    final richiesta = await client
        .getUrl(indirizzo)
        .timeout(const Duration(seconds: 8));
    richiesta.headers
      ..set('Accept', 'application/vnd.github+json')
      ..set('X-GitHub-Api-Version', '2022-11-28');
    final risposta = await richiesta.close().timeout(
      const Duration(seconds: 8),
    );
    if (risposta.statusCode != 200) {
      await risposta.drain<void>();
      return null;
    }
    return await risposta
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 8));
  } on Exception {
    // Niente rete, DNS, tempo scaduto: si riprova al prossimo avvio
    return null;
  } finally {
    client.close(force: true);
  }
}

class ControlloAggiornamenti {
  ControlloAggiornamenti({
    required this.preferenze,
    required this.versione,
    this.scarica,
    DateTime Function()? adesso,
  }) : _adesso = adesso ?? DateTime.now;

  final PreferenzeApp preferenze;

  /// Versione installata («1.0.0»).
  final String versione;

  /// Come si legge la pagina delle release; senza, il controllo non esce mai in rete (prove).
  final ScaricaTesto? scarica;
  final DateTime Function() _adesso;

  static final Uri _elenco = Uri.https(
    'api.github.com',
    '/repos/$repoRilasci/releases',
    {'per_page': '100'},
  );

  Future<bool> attivo() =>
      preferenze.leggiBool(chiaveControlloAttivo, predefinito: true);

  Future<void> imposta({required bool attivo}) =>
      preferenze.scrivi(chiaveControlloAttivo, attivo);

  /// Controllo all'avvio: niente se è disattivato; entro 24 ore dall'ultimo si ripropone l'avviso già noto senza
  /// tornare in rete. Ritorna la versione nuova da annunciare (null se non c'è o se l'utente l'ha già scartata).
  Future<NuovaVersione?> alAvvio() async {
    if (!await attivo()) return null;
    final ultimo = await preferenze.leggiInt(chiaveUltimoControllo) ?? 0;
    final adesso = _adesso().millisecondsSinceEpoch;
    NuovaVersione? nuova;
    if (adesso - ultimo >= intervalloControllo.inMilliseconds ||
        ultimo > adesso) {
      nuova = (await _controlla()).nuova;
    } else {
      final tag = (await preferenze.leggi(chiaveUltimaTrovata)) as String?;
      if (tag != null && tag.startsWith(prefissoTagMobile)) {
        final v = tag.substring(prefissoTagMobile.length);
        if (piuNuova(v, versione)) nuova = NuovaVersione(versione: v, tag: tag);
      }
    }
    if (nuova == null) return null;
    return await preferenze.leggi(chiaveIgnorata) == nuova.tag ? null : nuova;
  }

  /// Controllo chiesto dall'utente: va sempre in rete e risponde sempre, anche se non c'è niente di nuovo.
  /// Funziona anche con il controllo automatico spento (l'ha chiesto lui).
  Future<EsitoControllo> adessoSubito() async {
    final e = await _controlla();
    // Chi lo chiede a mano vuole vedere l'avviso anche se aveva scartato quella versione
    if (e.nuova != null) await preferenze.scrivi(chiaveIgnorata, null);
    return e;
  }

  Future<EsitoControllo> _controlla() async {
    final s = scarica;
    if (s == null) return const EsitoControllo(errore: true);
    final testo = await s(_elenco);
    if (testo == null) return const EsitoControllo(errore: true);
    final Object? json;
    try {
      json = jsonDecode(testo);
    } on FormatException {
      return const EsitoControllo(errore: true);
    }
    if (json is! List) return const EsitoControllo(errore: true);
    final nuova = ultimaMobile(json, versione);
    await preferenze.scrivi(
      chiaveUltimoControllo,
      _adesso().millisecondsSinceEpoch,
    );
    await preferenze.scrivi(chiaveUltimaTrovata, nuova?.tag);
    return EsitoControllo(nuova: nuova);
  }

  /// L'utente chiude l'avviso: quella versione non si riannuncia (una successiva sì).
  Future<void> ignora(NuovaVersione v) =>
      preferenze.scrivi(chiaveIgnorata, v.tag);
}

/// Versione dell'app installata (la legge `main()` dal pacchetto; nelle prove è 0.0.0).
final versioneAppProvider = Provider<String>((ref) => '0.0.0');

/// Come si scarica una pagina: `main()` mette la rete vera, le prove no (nessuna richiesta esce dalle prove).
final scaricaTestoProvider = Provider<ScaricaTesto?>((ref) => null);

final controlloAggiornamentiProvider = Provider<ControlloAggiornamenti>(
  (ref) => ControlloAggiornamenti(
    preferenze: ref.watch(preferenzeProvider),
    versione: ref.watch(versioneAppProvider),
    scarica: ref.watch(scaricaTestoProvider),
  ),
);

/// Versione nuova da annunciare nella Home: un solo controllo per avvio dell'app.
final aggiornamentoDisponibileProvider = FutureProvider<NuovaVersione?>(
  (ref) => ref.watch(controlloAggiornamentiProvider).alAvvio(),
);

/// Apre una pagina web nel browser (le prove lo sostituiscono).
final apriIndirizzoProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (u) => launchUrl(u, mode: LaunchMode.externalApplication),
);
