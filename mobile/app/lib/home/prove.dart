/// Prove della Fase 2 (piano §12): galleria con i suoi permessi, pagine disegnate in sola lettura (progetti dal
/// computer o creati dalla galleria) e prototipo dell'esportazione MP4. Sparirà quando arriva l'editor (Fase 3).
library;

import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;
import 'package:scrl_video/scrl_video.dart';

import '../editor/vista_pagina.dart';
import '../export/video_pagina.dart';
import '../l10n/app_localizations.dart';
import '../media/cache_media.dart';
import '../media/galleria.dart';
import '../media/importa.dart';
import '../render/forme.dart';
import '../render/risorse_pagina.dart';
import '../render/sottotitoli.dart' show misuraSottotitoli;
import '../render/testo.dart';
import '../theme/tokens.dart';

/// Una foto o un video da mettere nella pagina di prova: collegato alla galleria ([asset]) oppure copiato in
/// `media/` ([rel]), con le misure come appare.
typedef ElementoPagina = ({
  String path,
  String? rel,
  MediaAsset? asset,
  bool video,
  int w,
  int h,
});

ElementoPagina daGalleria(ElementoGalleria e) {
  final s = e.entita.orientatedSize;
  return (
    path: e.riferimento.name,
    rel: null,
    asset: e.riferimento,
    video: e.video,
    w: s.width.round(),
    h: s.height.round(),
  );
}

/// Pagina di prova con gli elementi scelti, disposti a griglia dal motore. Se c'è un video, sopra ci vanno
/// anche un testo e una freccia, per provare gli strati dell'esportazione MP4.
Snapshot paginaDiProva(List<ElementoPagina> scelti) {
  final misure = <int, ({int w, int h})>{};
  final ctx = EngineContext(
    imageSize: (p) => misure[p.uid],
    textSize: misuraTesto,
    captionSize: misuraSottotitoli,
  );
  final sc = Scene(Snapshot.blank(layoutSeed: 1), ctx);
  for (final e in scelti) {
    final p = sc.spawnPhoto(
      e.path,
      rel: e.rel,
      asset: e.asset,
      isVideo: e.video,
    );
    misure[p.uid] = (w: e.w, h: e.h);
  }
  var s = applyAutoLayout(sc.toSnapshot(), LayoutModes.grid, ctx).snapshot;
  if (scelti.any((e) => e.video)) {
    final z = s.items.map((p) => p.z).fold<double>(0, (a, b) => a > b ? a : b);
    s = s.copyWith(
      texts: [
        TextItem(
          uid: 1,
          text: 'ScrolleR',
          x: 140,
          y: 80,
          size: 110,
          z: z + 1,
          box: true,
        ),
      ],
      shapes: [
        ShapeItem(
          uid: 1,
          kind: 'arrow',
          x: 600,
          y: 1250,
          w: 380,
          h: puntaFreccia(14),
          strokeWidth: 14,
          stroke: 0xFFFFD60A,
          z: z + 2,
        ),
      ],
    );
  }
  return s;
}

class ProvePage extends StatefulWidget {
  const ProvePage({super.key});

  @override
  State<ProvePage> createState() => _ProvePageState();
}

class _ProvePageState extends State<ProvePage> with WidgetsBindingObserver {
  final _galleria = const Galleria();
  AccessoGalleria? _accesso;
  List<ElementoGalleria> _elementi = const [];
  final Set<String> _scelti = {};

  /// File scelti col selettore di sistema e copiati in `media/` del progetto di prova (permesso negato).
  final List<ElementoPagina> _importati = [];
  List<Directory> _progetti = const [];
  Directory? _cartellaProve;
  Directory? _documenti;
  CacheMedia? _cacheGalleria;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _avvia();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didHaveMemoryPressure() => _cacheGalleria?.svuota();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Tornando dalle impostazioni o dalla scelta di sistema, l'accesso può essere cambiato
    if (state == AppLifecycleState.resumed) _aggiornaGalleria();
  }

  Future<void> _avvia() async {
    _documenti = await getApplicationDocumentsDirectory();
    _cacheGalleria = CacheMedia(
      cartella: Directory('${_documenti!.path}/progetti/prova/cache'),
    );
    _cartellaProve = Directory(
      '${(await getExternalStorageDirectory() ?? _documenti!).path}/prove',
    );
    await _cartellaProve!.create(recursive: true);
    _progetti =
        _cartellaProve!
            .listSync()
            .whereType<Directory>()
            .where((d) => d.listSync().any((f) => f.path.endsWith('.scrlproj')))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    await _aggiornaGalleria();
  }

  Future<void> _aggiornaGalleria() async {
    final a = await _galleria.stato();
    final elementi =
        a == AccessoGalleria.completo || a == AccessoGalleria.parziale
        ? await _galleria.elenco()
        : const <ElementoGalleria>[];
    if (!mounted) return;
    setState(() {
      _accesso = a;
      _elementi = elementi;
    });
  }

  Future<void> _chiedi() async {
    await _galleria.chiedi();
    await _aggiornaGalleria();
  }

  String get _cartellaProva => '${_documenti!.path}/progetti/prova';

  List<ElementoPagina> get _selezione => [
    for (final e in _elementi)
      if (_scelti.contains(e.entita.id)) daGalleria(e),
    ..._importati,
  ];

  /// Ripiego col permesso negato: selettore di sistema, copia in `media/`, misure dall'anteprima.
  Future<void> _scegliDalTelefono() async {
    final copiati = await scegliECopia(Directory(_cartellaProva));
    final nuovi = <ElementoPagina>[];
    for (final f in copiati) {
      final src = sorgenteDi(
        PhotoItem(uid: 0, path: f.rel, rel: f.rel, isVideo: f.video),
        _cartellaProva,
      );
      final ant = await _cacheGalleria!.carica(src, Dettaglio.anteprima);
      if (ant == null) continue; // File non leggibile: si salta
      nuovi.add((
        path: f.rel,
        rel: f.rel,
        asset: null,
        video: f.video,
        w: ant.immagine.width,
        h: ant.immagine.height,
      ));
    }
    if (!mounted) return;
    setState(() => _importati.addAll(nuovi));
  }

  void _apriPagina() {
    final s = paginaDiProva(_selezione);
    final risorse = RisorsePagina(
      cache: _cacheGalleria!,
      cartellaProgetto: _cartellaProva,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SchermataPagine(
          titolo: Testi.of(context).proveGalleria,
          snapshot: s,
          risorse: risorse,
        ),
      ),
    );
  }

  Future<void> _esportaVideo() async {
    final testi = Testi.of(context);
    final messaggi = ScaffoldMessenger.of(context);
    if (!_selezione.any((e) => e.video)) {
      messaggi.showSnackBar(SnackBar(content: Text(testi.scegliUnVideo)));
      return;
    }
    if (!await ScrlVideo.disponibile()) {
      messaggi.showSnackBar(SnackBar(content: Text(testi.videoNonDisponibile)));
      return;
    }
    if (!mounted) return;
    final s = paginaDiProva(_selezione);
    final percorso =
        '${(await getTemporaryDirectory()).path}/scrollr_prova_01.mp4';
    final avanzamento = ValueNotifier<double>(0);
    var annulla = false;
    if (!mounted) return;
    final testiDis = testiDisegno(context);
    // Avanzamento con Annulla (operazione lunga, piano §14)
    final dialogo = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(testi.esportazioneInCorso),
        content: ValueListenableBuilder<double>(
          valueListenable: avanzamento,
          builder: (_, v, _) => LinearProgressIndicator(value: v),
        ),
        actions: [
          TextButton(
            onPressed: () => annulla = true,
            child: Text(testi.annulla),
          ),
        ],
      ),
    );
    final esito = await esportaPaginaVideo(
      s: s,
      k: 0,
      percorso: percorso,
      cache: _cacheGalleria!,
      cartellaProgetto: _cartellaProva,
      testi: testiDis,
      avanzamento: (f, n) => avanzamento.value = f / n,
      annullato: () => annulla,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    await dialogo;
    avanzamento.dispose();
    String msg;
    if (esito.fatto == true) {
      await PhotoManager.editor.saveVideo(
        File(percorso),
        title: 'scrollr_prova_01.mp4',
      );
      msg = testi.videoFatto(
        esito.fotogrammi,
        esito.msPerFotogramma.toStringAsFixed(0),
      );
    } else if (esito.fatto == null) {
      msg = testi.videoAnnullato;
    } else {
      msg = testi.videoErrore('${esito.errore}');
    }
    messaggi.showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 8)),
    );
  }

  Future<void> _apriProgetto(Directory d) async {
    final testi = Testi.of(context);
    final file = d.listSync().whereType<File>().firstWhere(
      (f) => f.path.endsWith('.scrlproj'),
    );
    try {
      final progetto = ProjectFile.parse(await file.readAsString());
      final nome = d.path.split(Platform.pathSeparator).last;
      final risorse = RisorsePagina(
        cache: CacheMedia(
          cartella: Directory('${_documenti!.path}/progetti/$nome/cache'),
        ),
        cartellaProgetto: d.path,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SchermataPagine(
            titolo: nome,
            snapshot: progetto.snapshot,
            risorse: risorse,
          ),
        ),
      );
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(testi.progettoNonValido)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    final stili = Theme.of(context).textTheme;
    final a = _accesso;
    return Scaffold(
      appBar: AppBar(title: Text(t.proveTitolo)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(MisureScrl.spazio),
          children: [
            Text(t.proveGalleria, style: stili.titleMedium),
            const SizedBox(height: MisureScrl.spazioPiccolo),
            if (a != null)
              Text(switch (a) {
                AccessoGalleria.completo => t.accessoCompleto,
                AccessoGalleria.parziale => t.accessoParziale,
                AccessoGalleria.negato => t.accessoNegato,
                AccessoGalleria.daChiedere => t.accessoDaChiedere,
              }, style: stili.bodySmall),
            const SizedBox(height: MisureScrl.spazioPiccolo),
            Wrap(
              spacing: MisureScrl.spazioPiccolo,
              runSpacing: MisureScrl.spazioPiccolo,
              children: [
                if (a == AccessoGalleria.daChiedere)
                  FilledButton(
                    onPressed: _chiedi,
                    child: Text(t.consentiAccesso),
                  ),
                if (a == AccessoGalleria.parziale)
                  OutlinedButton(
                    onPressed: () async {
                      await _galleria.scegliAltre();
                      await _aggiornaGalleria();
                    },
                    child: Text(t.scegliAltreFoto),
                  ),
                if (a == AccessoGalleria.negato) ...[
                  FilledButton(
                    onPressed: _scegliDalTelefono,
                    child: Text(t.scegliDalTelefono),
                  ),
                  OutlinedButton(
                    onPressed: PhotoManager.openSetting,
                    child: Text(t.apriImpostazioni),
                  ),
                ],
                if (_scelti.isNotEmpty || _importati.isNotEmpty) ...[
                  FilledButton(
                    onPressed: _apriPagina,
                    child: Text(t.creaPagina),
                  ),
                  OutlinedButton(
                    onPressed: _esportaVideo,
                    child: Text(t.esportaVideo),
                  ),
                ],
              ],
            ),
            if (_importati.isNotEmpty)
              Text(t.fileCopiati(_importati.length), style: stili.bodySmall),
            const SizedBox(height: MisureScrl.spazioPiccolo),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              children: [
                for (final e in _elementi)
                  _Miniatura(
                    elemento: e,
                    scelto: _scelti.contains(e.entita.id),
                    onTap: () => setState(() {
                      if (!_scelti.remove(e.entita.id)) {
                        _scelti.add(e.entita.id);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: MisureScrl.spazio),
            Text(t.progettiDiProva, style: stili.titleMedium),
            const SizedBox(height: MisureScrl.spazioPiccolo),
            if (_cartellaProve != null)
              Text(
                t.progettiDiProvaAiuto(_cartellaProve!.path),
                style: stili.bodySmall,
              ),
            for (final d in _progetti)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(d.path.split(Platform.pathSeparator).last),
                onTap: () => _apriProgetto(d),
              ),
          ],
        ),
      ),
    );
  }
}

class _Miniatura extends StatefulWidget {
  const _Miniatura({
    required this.elemento,
    required this.scelto,
    required this.onTap,
  });

  final ElementoGalleria elemento;
  final bool scelto;
  final VoidCallback onTap;

  @override
  State<_Miniatura> createState() => _MiniaturaState();
}

class _MiniaturaState extends State<_Miniatura> {
  // Chiesta una volta sola, non a ogni ridisegno
  late final _dati = widget.elemento.entita.thumbnailDataWithSize(
    const ThumbnailSize.square(240),
  );

  @override
  Widget build(BuildContext context) {
    final elemento = widget.elemento;
    final scelto = widget.scelto;
    final onTap = widget.onTap;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder(
            future: _dati,
            builder: (context, f) => f.data == null
                ? const ColoredBox(color: ColoriScrl.rilievo)
                : Image.memory(
                    f.data!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
          ),
          if (elemento.video)
            const Align(
              alignment: Alignment.bottomLeft,
              child: Icon(
                Icons.play_circle_outline,
                color: ColoriScrl.suAccento,
              ),
            ),
          if (scelto)
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: ColoriScrl.accento, width: 3),
              ),
            ),
        ],
      ),
    );
  }
}
