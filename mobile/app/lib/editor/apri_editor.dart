/// Apre un progetto dell'archivio nell'editor: lo legge, prepara la sessione e mostra la schermata.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' show ProjectFormatException;

import '../l10n/app_localizations.dart';
import '../media/cache_media.dart';
import '../project/archivio.dart';
import '../project/provider.dart';
import 'editor_page.dart';
import 'sessione.dart';

/// Sessione di lavoro per un progetto già caricato.
SessioneEditor creaSessione(
  ProgettoCaricato p,
  WidgetRef ref, {
  CacheMedia? cache,
}) => SessioneEditor(
  archivio: ref.read(archivioProvider),
  cartella: p.cartella,
  cache: cache ?? CacheMedia(cartella: Directory('${p.cartella.path}/cache')),
  galleria: ref.read(galleriaProvider),
  dati: p.dati,
  inizio: p.file.snapshot,
  libreriaIniziale: p.file.library,
  extraFile: p.file.extra,
);

/// Apre [cartella] nell'editor e aspetta che si torni alla Home.
Future<void> apriProgetto(
  BuildContext context,
  WidgetRef ref,
  Directory cartella,
) async {
  final archivio = ref.read(archivioProvider);
  final messaggio = ScaffoldMessenger.of(context);
  final testo = Testi.of(context).progettoNonValido;
  final ProgettoCaricato p;
  try {
    p = await archivio.carica(cartella);
  } on ProjectFormatException {
    messaggio.showSnackBar(SnackBar(content: Text(testo)));
    return;
  } on FileSystemException {
    messaggio.showSnackBar(SnackBar(content: Text(testo)));
    return;
  }
  if (!context.mounted) return;
  final sessione = creaSessione(p, ref);
  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => EditorPage(sessione: sessione)),
  );
}
