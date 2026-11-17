/// Provider condivisi dall'app: l'archivio dei progetti e la galleria. Si sostituiscono nelle prove con
/// `ProviderScope(overrides: [...])`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../media/galleria.dart';
import 'archivio.dart';

/// Archivio dei progetti: lo fornisce `main()` con la cartella dei documenti dell'app.
final archivioProvider = Provider<ArchivioProgetti>(
  (ref) => throw UnimplementedError('Manca l\'archivio dei progetti'),
);

/// Galleria del telefono.
final galleriaProvider = Provider<Galleria>((ref) => const Galleria());
