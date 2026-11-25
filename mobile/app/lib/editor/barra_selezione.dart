/// Barra inferiore con un elemento selezionato (piano §4.3), su **due livelli** perché i comandi non stiano più
/// schiacciati in una striscia lunga:
/// - **categorie** (al massimo sei, tutte nello schermo): per una foto Ritaglia · Colore · Aspetto · Disponi · Altro
///   (più Video per i video), per un testo Modifica · Carattere · Colore · Disponi · Altro, per una forma Tipo · Colore ·
///   Disponi · Altro; con più elementi anche Gruppo;
/// - **strumenti della categoria**, con ‹ (e il nome della categoria) per tornare alle categorie; anche il gesto
///   «indietro» di sistema ci torna. Chiuso uno strumento con ✓ o ✕ si torna qui, nella stessa categoria.
/// La categoria aperta la tiene la zona inferiore dell'editor, così resta mentre uno strumento è aperto.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrl_engine/scrl_engine.dart' hide Rect;

import '../export/consegna.dart';
import '../export/sagoma_png.dart';
import '../l10n/app_localizations.dart';
import '../media/cache_media.dart' show chiaveMedia;
import '../settings/registro_errori.dart';
import '../theme/tokens.dart';
import 'indietro.dart';
import 'mancanti_ui.dart';
import 'menu_pressione_lunga.dart';
import 'pagina_ritaglio.dart';
import 'pagina_sottotitoli.dart';
import 'stato.dart';
import 'widget_comuni.dart';

/// Una categoria della barra: apre i suoi strumenti ([voci]) o, se non ne ha, agisce subito ([onTap]).
class _Categoria {
  const _Categoria(
    this.id,
    this.icona,
    this.etichetta, {
    this.voci = const [],
    this.onTap,
  });

  final String id;
  final IconData icona;
  final String etichetta;
  final List<Widget> voci;
  final VoidCallback? onTap;
}

/// Firma della selezione: quando cambia il tipo di cosa è selezionata, la categoria aperta non vale più.
String tipoSelezione(StatoEditor s) {
  final sel = s.elementiSelezionati;
  if (sel.isEmpty) return '';
  final foto = sel.whereType<PhotoItem>();
  return [
    if (foto.any((p) => !p.isVideo)) 'f',
    if (foto.any((p) => p.isVideo)) 'v',
    if (sel.any((e) => e is TextItem)) 't',
    if (sel.any((e) => e is ShapeItem)) 's',
    if (sel.any((e) => e is CaptionItem)) 'c',
    if (sel.length > 1) 'm',
  ].join();
}

class BarraSelezione extends ConsumerWidget {
  const BarraSelezione({
    super.key,
    required this.categoria,
    required this.onCategoria,
  });

  /// Categoria aperta (null = le categorie).
  final String? categoria;
  final ValueChanged<String?> onCategoria;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final ctrl = ref.read(editorProvider.notifier);
    final stato = ref.watch(editorProvider);
    final sel = stato.elementiSelezionati;
    if (sel.isEmpty) {
      return SizedBox(
        height: MisureScrl.barraInferiore,
        child: Row(
          children: [
            _Bordo(
              child: PulsanteIcona(
                icona: Icons.close_rounded,
                etichetta: t.deseleziona,
                onTap: ctrl.deseleziona,
              ),
            ),
            Expanded(
              child: Text(
                t.selezionaPiuAiuto,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }
    final categorie = _categorie(context, ref, t, stato);
    final aperta = categorie.where((c) => c.id == categoria).firstOrNull;
    if (aperta == null) {
      return SizedBox(
        height: MisureScrl.barraInferiore,
        child: Row(
          children: [
            _Bordo(
              child: PulsanteIcona(
                icona: Icons.close_rounded,
                etichetta: t.deseleziona,
                onTap: ctrl.deseleziona,
              ),
            ),
            Expanded(
              child: _Riga(
                voci: [
                  for (final c in categorie)
                    VoceBarra(
                      key: ValueKey('cat-${c.id}'),
                      icona: c.icona,
                      etichetta: c.etichetta,
                      onTap: c.onTap ?? () => onCategoria(c.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return RitornoLocale(
      onIndietro: () => onCategoria(null),
      child: SizedBox(
        height: MisureScrl.barraInferiore,
        child: Row(
          children: [
            _Bordo(
              child: _VoceIndietro(
                etichetta: aperta.etichetta,
                indietro: t.indietro,
                onTap: () => onCategoria(null),
              ),
            ),
            Expanded(child: _Riga(voci: aperta.voci)),
          ],
        ),
      ),
    );
  }

  List<_Categoria> _categorie(
    BuildContext context,
    WidgetRef ref,
    Testi t,
    StatoEditor stato,
  ) {
    final ctrl = ref.read(editorProvider.notifier);
    final sel = stato.elementiSelezionati;
    final foto = sel.whereType<PhotoItem>().toList();
    final tutteLibere = foto.isNotEmpty && foto.every((p) => p.free);
    final conColori = foto.any((p) => !p.isVideo);
    final conVideo = foto.any((p) => p.isVideo);
    final videoGira =
        conVideo &&
        foto.any((p) => p.isVideo && stato.videoInRiproduzione.contains(p.uid));
    final testi = sel.whereType<TextItem>().toList();
    final forme = sel.whereType<ShapeItem>().toList();
    final sottotitoli = sel.whereType<CaptionItem>().toList();
    // Gli strumenti di foto, testi e forme valgono quando la selezione è fatta di un solo tipo; con tipi diversi restano
    // i comandi per più elementi (Allinea, Distribuisci, Raggruppa, Blocca…)
    final senzaSottotitoli = sottotitoli.isEmpty;
    final soloFoto =
        testi.isEmpty && forme.isEmpty && senzaSottotitoli && foto.isNotEmpty;
    final soloTesti =
        foto.isEmpty && forme.isEmpty && senzaSottotitoli && testi.isNotEmpty;
    final soloForme =
        foto.isEmpty && testi.isEmpty && senzaSottotitoli && forme.isNotEmpty;
    final soloSottotitoli =
        foto.isEmpty && testi.isEmpty && forme.isEmpty && !senzaSottotitoli;
    // Lo stile su cui lavorano gli strumenti del testo (un testo, o lo stile del blocco di sottotitoli)
    final stileTesto = soloTesti
        ? testi.first
        : (soloSottotitoli ? sottotitoli.first.stile : null);
    // Sottotitoli solo per un video alla volta, e solo dove il telefono sa leggerne l'audio (Android)
    final unVideo = soloFoto && foto.length == 1 && foto.first.isVideo;
    final multi = sel.length > 1;
    // Una foto selezionata che non si trova più: «Ricollega» sta in testa alla barra
    final mancanteSel = ref
        .watch(mancantiProvider)
        .value
        ?.where((m) => foto.any((p) => chiaveMedia(p) == m.chiave))
        .firstOrNull;
    final inGruppi = selezioneHaGruppi(stato.snapshot, stato.selezione);
    final unGruppo = selezioneEUnGruppo(stato.snapshot, stato.selezione);
    final bloccati = sel.isNotEmpty && sel.every((e) => e.locked);
    final tutteLinee = soloForme && forme.every((f) => f.isLine);
    final conAngoli = soloForme && forme.any((f) => f.kind == 'rect');
    void apri(Strumento s) => ctrl.apriStrumento(s);
    VoceBarra voce(
      IconData icona,
      String etichetta,
      VoidCallback onTap, {
      bool attiva = false,
      bool spenta = false,
      Color? colore,
      String? chiave,
    }) => VoceBarra(
      key: chiave == null ? null : ValueKey(chiave),
      icona: icona,
      etichetta: etichetta,
      onTap: onTap,
      attiva: attiva,
      spenta: spenta,
      colore: colore,
    );

    // Disponi: livelli e spostamento, allineamento, distribuzione; per le foto anche Libera e Sposta in pagina
    final disponi = _Categoria(
      'disponi',
      Icons.open_with_rounded,
      t.strDisponi,
      voci: [
        if (soloTesti || soloForme)
          voce(
            Icons.rotate_right_rounded,
            t.strRuota,
            () => apri(soloTesti ? Strumento.testoRuota : Strumento.formaRuota),
          ),
        voce(
          Icons.layers_outlined,
          t.dispLivello,
          () => apri(Strumento.disponi),
          chiave: 'voce-disponi',
        ),
        voce(
          Icons.align_horizontal_left_rounded,
          t.strAllinea,
          () => apri(Strumento.allinea),
          chiave: 'voce-allinea',
        ),
        if (multi)
          voce(
            Icons.horizontal_distribute_rounded,
            t.strDistribuisci,
            () => apri(Strumento.distribuisci),
            chiave: 'voce-distribuisci',
          ),
        if (soloFoto) ...[
          voce(
            tutteLibere ? Icons.grid_view_rounded : Icons.open_with_rounded,
            tutteLibere ? t.inDisposizione : t.libera,
            ctrl.liberaSelezione,
            chiave: 'voce-libera',
          ),
          voce(
            Icons.drive_file_move_outlined,
            t.menuSpostaInPagina,
            () => unawaited(mostraMenuElemento(context, soloPagina: true)),
            chiave: 'voce-sposta-pagina',
          ),
        ],
      ],
    );
    // Gruppo (più elementi): raggruppa o separa, scambia due foto, blocca
    final gruppo = _Categoria(
      'gruppo',
      Icons.workspaces_outline,
      t.catGruppo,
      voci: [
        if (!unGruppo)
          voce(
            Icons.workspaces_outline,
            t.strRaggruppa,
            ctrl.raggruppaSelezione,
            chiave: 'voce-raggruppa',
          ),
        if (inGruppi)
          voce(
            Icons.workspaces_filled,
            t.strSepara,
            ctrl.separaSelezione,
            chiave: 'voce-separa',
          ),
        if (foto.length == 2 && sel.length == 2)
          voce(
            Icons.swap_horiz_rounded,
            t.strScambia,
            ctrl.scambiaFoto,
            chiave: 'voce-scambia',
          ),
        voce(
          bloccati ? Icons.lock_open_rounded : Icons.lock_outline,
          bloccati ? t.strSblocca : t.strBlocca,
          ctrl.bloccaSelezione,
          attiva: bloccati,
          chiave: 'voce-blocca',
        ),
      ],
    );
    // Altro: copia e incolla lo stile (foto), separa (un elemento in un gruppo), duplica, elimina
    final altro = _Categoria(
      'altro',
      Icons.more_horiz_rounded,
      t.catAltro,
      voci: [
        if (soloFoto) ...[
          voce(
            Icons.colorize_rounded,
            t.strCopiaStile,
            ctrl.copiaStile,
            chiave: 'voce-copia-stile',
          ),
          voce(
            Icons.format_paint_rounded,
            t.strIncollaStile,
            ctrl.incollaStileCopiato,
            spenta: stato.stileCopiato == null,
            chiave: 'voce-incolla-stile',
          ),
        ],
        if (!multi && inGruppi)
          voce(
            Icons.workspaces_filled,
            t.strSepara,
            ctrl.separaSelezione,
            chiave: 'voce-separa',
          ),
        // I sottotitoli non si duplicano: ogni video ne ha un blocco solo
        if (!soloSottotitoli)
          voce(
            Icons.copy_rounded,
            t.duplica,
            ctrl.duplicaSelezione,
            chiave: 'voce-duplica',
          ),
        voce(
          Icons.delete_outline_rounded,
          t.elimina,
          ctrl.eliminaSelezione,
          colore: ColoriScrl.pericoloTesto,
          chiave: 'voce-elimina',
        ),
      ],
    );

    return [
      if (soloFoto && mancanteSel != null)
        _Categoria(
          'ricollega',
          Icons.link_rounded,
          t.strRicollega,
          onTap: () => unawaited(ricollegaUna(context, ref, mancanteSel)),
        ),
      if (soloFoto && conVideo)
        _Categoria(
          'video',
          Icons.movie_outlined,
          t.catVideo,
          voci: [
            voce(
              videoGira ? Icons.pause_rounded : Icons.play_arrow_rounded,
              videoGira ? t.videoPausa : t.videoRiproduci,
              ctrl.alternaRiproduzione,
              attiva: videoGira,
              chiave: 'voce-riproduci',
            ),
            voce(
              Icons.content_cut_rounded,
              t.strTaglia,
              () => apri(Strumento.videoTaglia),
              chiave: 'voce-taglia',
            ),
            voce(
              Icons.image_outlined,
              t.strCopertina,
              () => apri(Strumento.videoCopertina),
              chiave: 'voce-copertina',
            ),
            const _VoceAudio(key: ValueKey('voce-audio')),
            if (unVideo && sottotitoliDisponibili)
              voce(
                Icons.subtitles_outlined,
                t.strSottotitoli,
                () => unawaited(apriSottotitoli(context, ref, foto.first.uid)),
                chiave: 'voce-sottotitoli',
              ),
          ],
        ),
      if (soloFoto) ...[
        _Categoria(
          'ritaglia',
          Icons.crop_rounded,
          t.strRitaglia,
          voci: [
            voce(
              Icons.crop_rounded,
              t.strRitaglia,
              () => unawaited(_ritaglia(context, ref)),
              chiave: 'voce-ritaglia',
            ),
            voce(
              Icons.center_focus_strong_outlined,
              t.strInquadra,
              () => apri(Strumento.inquadra),
              chiave: 'voce-inquadra',
            ),
            voce(
              Icons.rotate_right_rounded,
              t.strRuota,
              () => apri(Strumento.ruota),
              chiave: 'voce-ruota',
            ),
            if (foto.length == 1 && haSagoma(foto.first))
              voce(
                Icons.download_rounded,
                t.strSalvaSagoma,
                () => unawaited(_salvaSagoma(context, ref, foto.first)),
                chiave: 'voce-salva-sagoma',
              ),
            if (foto.any(haSagoma))
              voce(
                Icons.hide_image_outlined,
                t.strTogliSagoma,
                ctrl.togliSagoma,
                chiave: 'voce-togli-sagoma',
              ),
          ],
        ),
        if (conColori)
          _Categoria(
            'colore',
            Icons.tune_rounded,
            t.parColore,
            voci: [
              voce(
                Icons.auto_awesome_outlined,
                t.strFiltri,
                () => apri(Strumento.filtri),
                chiave: 'voce-filtri',
              ),
              voce(
                Icons.tune_rounded,
                t.strRegola,
                () => apri(Strumento.regola),
                chiave: 'voce-regola',
              ),
              voce(
                Icons.auto_fix_high_rounded,
                t.strEffetti,
                () => apri(Strumento.effetti),
                chiave: 'voce-effetti',
              ),
            ],
          ),
        _Categoria(
          'aspetto',
          Icons.rounded_corner_rounded,
          t.catAspetto,
          voci: [
            voce(
              Icons.rounded_corner_rounded,
              t.strCornice,
              () => apri(Strumento.cornice),
              chiave: 'voce-cornice',
            ),
            voce(
              Icons.blur_on_rounded,
              t.strOmbra,
              () => apri(Strumento.ombra),
              chiave: 'voce-ombra',
            ),
          ],
        ),
      ],
      if (soloSottotitoli) ...[
        if (sottotitoliDisponibili)
          _Categoria(
            'sottotitoli',
            Icons.subtitles_outlined,
            t.strSottotitoli,
            onTap: () => unawaited(
              apriSottotitoli(context, ref, sottotitoli.first.videoUid),
            ),
          ),
        _Categoria(
          'traduzione',
          Icons.translate_rounded,
          t.sotTraduzione,
          voci: [
            voce(
              Icons.subtitles_outlined,
              t.sotMostraTraduzione,
              () => ctrl.comandoSottotitoli(
                (c, ctx) =>
                    conTraduzioneVisibile(c, !sottotitoli.first.trShow, ctx),
              ),
              attiva: sottotitoli.first.trShow,
              chiave: 'voce-mostra-traduzione',
            ),
            voce(
              Icons.format_color_text_rounded,
              t.parColore,
              () => apri(Strumento.sottotitoliColoreTraduzione),
              chiave: 'voce-colore-traduzione',
            ),
            voce(
              Icons.format_size_rounded,
              t.strDimensione,
              () => apri(Strumento.sottotitoliDimensioneTraduzione),
              chiave: 'voce-dimensione-traduzione',
            ),
            voce(
              Icons.format_italic_rounded,
              t.azCorsivo,
              () => ctrl.comandoSottotitoli(
                (c, _) => conCorsivoTraduzione(c, !sottotitoli.first.trItalic),
              ),
              attiva: sottotitoli.first.trItalic,
              chiave: 'voce-corsivo-traduzione',
            ),
          ],
        ),
      ],
      if (soloTesti)
        _Categoria(
          'modifica',
          Icons.edit_outlined,
          t.strModifica,
          onTap: () => apri(Strumento.testoModifica),
        ),
      if (stileTesto != null) ...[
        _Categoria(
          'carattere',
          Icons.font_download_outlined,
          t.strCarattere,
          voci: [
            if (soloSottotitoli)
              voce(
                Icons.width_normal_outlined,
                t.strLarghezza,
                () => apri(Strumento.sottotitoliLarghezza),
                chiave: 'voce-larghezza',
              ),
            voce(
              Icons.font_download_outlined,
              t.strCarattere,
              () => apri(Strumento.testoCarattere),
              chiave: 'voce-carattere',
            ),
            voce(
              Icons.format_size_rounded,
              t.strDimensione,
              () => apri(Strumento.testoDimensione),
              chiave: 'voce-dimensione',
            ),
            voce(
              Icons.format_bold_rounded,
              t.strFormato,
              () => apri(Strumento.testoFormato),
              chiave: 'voce-formato',
            ),
            voce(
              Icons.format_line_spacing_rounded,
              t.strSpaziatura,
              () => apri(Strumento.testoSpaziatura),
              chiave: 'voce-spaziatura',
            ),
          ],
        ),
        _Categoria(
          'colore',
          Icons.format_color_text_rounded,
          t.parColore,
          voci: [
            voce(
              Icons.format_color_text_rounded,
              t.parColore,
              () => apri(Strumento.testoColore),
              chiave: 'voce-colore',
            ),
            voce(
              Icons.border_color_outlined,
              t.strContorno,
              () => apri(Strumento.testoContorno),
              chiave: 'voce-contorno',
            ),
            voce(
              Icons.label_outline_rounded,
              t.strEtichetta,
              () => apri(Strumento.testoEtichetta),
              attiva: stileTesto.box,
              chiave: 'voce-etichetta',
            ),
            voce(
              Icons.blur_on_rounded,
              t.strOmbra,
              ctrl.alternaOmbraTesto,
              attiva: stileTesto.shadow,
              chiave: 'voce-ombra-testo',
            ),
            voce(
              Icons.opacity_rounded,
              t.parOpacita,
              () => apri(Strumento.testoOpacita),
              chiave: 'voce-opacita',
            ),
          ],
        ),
      ],
      if (soloForme) ...[
        _Categoria(
          'tipo',
          Icons.category_outlined,
          t.strTipo,
          onTap: () => apri(Strumento.formaTipo),
        ),
        _Categoria(
          'colore',
          Icons.format_color_fill_rounded,
          t.parColore,
          voci: [
            if (!tutteLinee)
              voce(
                Icons.format_color_fill_rounded,
                t.strRiempimento,
                () => apri(Strumento.formaRiempimento),
                chiave: 'voce-riempimento',
              ),
            voce(
              Icons.line_weight_rounded,
              tutteLinee ? t.parLinea : t.parBordo,
              () => apri(Strumento.formaBordo),
              chiave: 'voce-bordo',
            ),
            if (conAngoli)
              voce(
                Icons.rounded_corner_rounded,
                t.parAngoli,
                () => apri(Strumento.formaAngoli),
                chiave: 'voce-angoli',
              ),
            voce(
              Icons.opacity_rounded,
              t.parOpacita,
              () => apri(Strumento.formaOpacita),
              chiave: 'voce-opacita',
            ),
          ],
        ),
      ],
      disponi,
      if (multi) gruppo,
      altro,
    ];
  }

  /// Ritaglio a schermo intero: si apre una pagina nuova e, con ✓, il ritaglio entra in cronologia.
  Future<void> _ritaglia(BuildContext context, WidgetRef ref) async {
    final ctrl = ref.read(editorProvider.notifier);
    final s = ref.read(sessioneProvider);
    final foto = ctrl.fotoSelezionate;
    if (foto.isEmpty) return;
    final r = await Navigator.of(context).push<RisultatoRitaglio>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PaginaRitaglio(sessione: s, foto: foto.first),
      ),
    );
    if (r == null) return;
    final sagoma = r.sagoma;
    if (sagoma != null) {
      // La sagoma vale per la foto mostrata nella pagina Ritaglia (come il desktop, una foto alla volta)
      ctrl.applicaSagoma(foto.first.uid, sagoma, r.morbidezza);
    } else {
      ctrl.applicaRitaglio(r.ritaglio, adattaRiquadro: r.adattaRiquadro);
    }
  }

  /// «Salva PNG»: il soggetto scontornato va in Galleria (album «ScrolleR Studio»). Mentre si prepara c'è
  /// un'attesa con «Annulla»; annullando il risultato non si salva.
  Future<void> _salvaSagoma(
    BuildContext context,
    WidgetRef ref,
    PhotoItem foto,
  ) async {
    final ctrl = ref.read(editorProvider.notifier);
    final s = ref.read(sessioneProvider);
    final consegna = ref.read(consegnaProvider);
    final registro = ref.read(registroErroriProvider);
    final navigator = Navigator.of(context);
    var annullato = false;
    var aperta = true;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _AttesaSagoma(
          onAnnulla: () {
            annullato = true;
            Navigator.of(context).pop();
          },
        ),
      ).whenComplete(() => aperta = false),
    );
    try {
      final dati = await pngSagoma(foto, s.cache, s.cartella.path);
      if (annullato) return;
      if (dati == null) {
        ctrl.messaggio(MessaggioEditor.sagomaNonSalvata);
        return;
      }
      await consegna.salvaInGalleria(dati, nomePngSagoma(foto), DateTime.now());
      if (!annullato) ctrl.messaggio(MessaggioEditor.sagomaSalvata);
    } catch (e, traccia) {
      registro.registra(e, traccia, contesto: 'Salva sagoma');
      if (!annullato) ctrl.messaggio(MessaggioEditor.sagomaNonSalvata);
    } finally {
      if (aperta && !annullato) navigator.pop();
    }
  }
}

/// Attesa mentre si prepara il PNG della sagoma, con «Annulla».
class _AttesaSagoma extends StatelessWidget {
  const _AttesaSagoma({required this.onAnnulla});

  final VoidCallback onAnnulla;

  @override
  Widget build(BuildContext context) {
    final t = Testi.of(context);
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: ColoriScrl.pannello,
        content: Row(
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(width: MisureScrl.spazio),
            Expanded(
              child: Text(
                t.sagSalvataggio,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: onAnnulla,
            child: Text(t.sagAnnullaSalvataggio),
          ),
        ],
      ),
    );
  }
}

/// Le voci di un livello della barra: fino a sei stanno tutte nello schermo, di uguale larghezza; oltre scorrono.
class _Riga extends StatelessWidget {
  const _Riga({required this.voci});

  final List<Widget> voci;

  @override
  Widget build(BuildContext context) {
    if (voci.length <= 6) {
      return Row(children: [for (final v in voci) Expanded(child: v)]);
    }
    return ListView(
      scrollDirection: Axis.horizontal,
      children: [for (final v in voci) SizedBox(width: 76, child: v)],
    );
  }
}

/// Primo posto della barra (✕ o ‹), separato dalle voci da un filo sottile.
class _Bordo extends StatelessWidget {
  const _Bordo({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: 64,
    decoration: const BoxDecoration(
      border: Border(right: BorderSide(color: ColoriScrl.bordo)),
    ),
    child: Center(child: child),
  );
}

/// ‹ con sotto il nome della categoria aperta (in colore d'accento): dice dove si è e riporta alle categorie.
class _VoceIndietro extends StatelessWidget {
  const _VoceIndietro({
    required this.etichetta,
    required this.indietro,
    required this.onTap,
  });

  final String etichetta;
  final String indietro;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$indietro, $etichetta',
    excludeSemantics: true,
    child: InkWell(
      key: const ValueKey('barra-indietro'),
      onTap: onTap,
      child: SizedBox(
        width: 64,
        height: MisureScrl.barraInferiore,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.arrow_back_rounded,
              size: 24,
              color: ColoriScrl.testo,
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  etichetta,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: TestoScrl.piccolo,
                    fontWeight: TestoScrl.marcato,
                    color: ColoriScrl.accentoTesto,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// «Audio» del video selezionato (`chk_video_audio`): acceso o spento nell'MP4 esportato, un tocco = un passo.
/// Un video senza traccia audio ha la voce spenta, e il tocco lo dice.
class _VoceAudio extends ConsumerWidget {
  const _VoceAudio({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Testi.of(context);
    final ctrl = ref.read(editorProvider.notifier);
    final risorse = ref.read(sessioneProvider).risorse;
    final video = ref.watch(
      editorProvider.select(
        (s) => s.elementiSelezionati
            .whereType<PhotoItem>()
            .where((p) => p.isVideo)
            .firstOrNull,
      ),
    );
    if (video == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: risorse,
      builder: (context, _) {
        final audio = risorse.infoVideo(video)?.audio ?? false;
        final acceso = audio && !video.muted;
        return VoceBarra(
          icona: acceso ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          etichetta: t.strAudio,
          attiva: acceso,
          spenta: !audio,
          onTap: audio
              ? ctrl.alternaAudioVideo
              : () => ctrl.messaggio(MessaggioEditor.videoSenzaAudio),
        );
      },
    );
  }
}
