import 'package:scrl_engine/scrl_engine.dart';
import 'package:test/test.dart';

import 'riferimenti_util.dart';

/// Nomi dei passaggi dati dal desktop (`cronologia.jsonl`) contro [describeChange] del motore.
///
/// Il motore restituisce un nome strutturato; qui lo si compone in italiano con le stesse parole di
/// `_describe_change`, solo per il confronto (nell'app i testi vengono dai file `.arb`).
void main() {
  for (final caso in leggiJsonl('cronologia.jsonl')) {
    test('cronologia ${caso['id']}', () {
      final a = StatoDesktop.fromJson(caso['prima']! as Map<String, Object?>)
          .snapshot;
      final b = StatoDesktop.fromJson(caso['dopo']! as Map<String, Object?>)
          .snapshot;
      expect(italiano(describeChange(a, b)), caso['nome']);
    });
  }
}

const _nomi = {
  ElementKind.photo: ('Foto', 'f', 'foto'),
  ElementKind.text: ('Testo', 'm', 'testi'),
  ElementKind.shape: ('Forma', 'f', 'forme'),
  ElementKind.caption: ('Sottotitoli', 'mp', 'sottotitoli'),
};

const _disposizioni = {
  'grid': 'Griglia',
  'mosaic': 'Mosaico',
  'strips_h': 'Righe',
  'strips_v': 'Colonne',
  'scatter': 'Polaroid',
  'scrl_seam': 'A cavallo',
};

String italiano(ChangeLabel l) {
  String accorda(ElementKind e, String parola) =>
      '${_nomi[e]!.$1} $parola${switch (_nomi[e]!.$2) {
        'f' => 'a',
        'mp' => 'i',
        _ => 'o',
      }}';
  String quanti(String verbo) {
    final e = l.element;
    if (e == null) return '${l.count} elementi ${verbo}i';
    if (l.count == 1) return accorda(e, verbo);
    return '${l.count} ${_nomi[e]!.$3} $verbo${_nomi[e]!.$2 == 'f' ? 'e' : 'i'}';
  }

  return switch (l.kind) {
    ChangeKind.start => l.text ?? '',
    ChangeKind.pageDuplicated => 'Pagina duplicata',
    ChangeKind.pageAdded => 'Pagina aggiunta',
    ChangeKind.pageDeleted => 'Pagina eliminata',
    ChangeKind.photosReplaced => 'Foto sostituite',
    ChangeKind.elementsChanged => 'Elementi cambiati',
    ChangeKind.added => quanti('aggiunt'),
    ChangeKind.removed => quanti('eliminat'),
    ChangeKind.pagesCount => 'Pagine: ${l.from} → ${l.to}',
    ChangeKind.pageFormat => 'Formato della pagina',
    ChangeKind.layout =>
      'Disposizione: ${_disposizioni[l.layoutMode] ?? l.layoutMode}',
    ChangeKind.mosaicStyle => 'Stile mosaico',
    ChangeKind.filmStyle => 'Verso della pellicola',
    ChangeKind.polaroidShadow => 'Ombra delle Polaroid',
    ChangeKind.polaroidDepth => 'Rilievo delle Polaroid',
    ChangeKind.photosShuffled => 'Foto rimescolate',
    ChangeKind.pageLocks => 'Lucchetto delle pagine',
    ChangeKind.pageSeams => 'Pagine a cavallo',
    ChangeKind.pageLayout => 'Disposizione della pagina',
    ChangeKind.photosPerPage => 'Foto per pagina',
    ChangeKind.spacing => 'Spaziatura',
    ChangeKind.margin => 'Margine',
    ChangeKind.background => 'Sfondo',
    ChangeKind.pageNumbers => 'Numeri di pagina',
    ChangeKind.swipeHint => 'Indicatore «scorri»',
    ChangeKind.exportName => 'Nome dei file',
    ChangeKind.convertedToReel => 'Convertito in reel',
    ChangeKind.convertedToCarousel => 'Convertito in carosello',
    ChangeKind.modified => 'Modifica',
    ChangeKind.grouped => 'Elementi raggruppati',
    ChangeKind.ungrouped => 'Gruppo separato',
    ChangeKind.photoOrder => 'Ordine delle foto',
    ChangeKind.levelChanged => 'Livello cambiato',
    ChangeKind.positionLock => 'Blocco della posizione',
    ChangeKind.movedMany => '${l.count} elementi spostati',
    ChangeKind.layoutUpdated => 'Disposizione aggiornata',
    ChangeKind.modifiedMany => '${l.count} elementi modificati',
    ChangeKind.moved => accorda(l.element!, 'spostat'),
    ChangeKind.resized => accorda(l.element!, 'ridimensionat'),
    ChangeKind.rotated => accorda(l.element!, 'ruotat'),
    ChangeKind.textEdited => 'Testo modificato',
    ChangeKind.captionsEdited => 'Sottotitoli modificati',
    ChangeKind.photoColors => 'Colori della foto',
    ChangeKind.videoTrim => 'Taglio del video',
    ChangeKind.videoPoster => 'Copertina del video',
    ChangeKind.videoAudio => 'Audio del video',
    ChangeKind.photoFraming => 'Inquadratura della foto',
    ChangeKind.photoFree => 'Foto libera',
    ChangeKind.photoInLayout => 'Foto nella disposizione',
    ChangeKind.style => switch (l.element!) {
      ElementKind.photo => 'Stile della foto',
      ElementKind.text => 'Stile del testo',
      ElementKind.shape => 'Stile della forma',
      ElementKind.caption => 'Stile dei sottotitoli',
    },
  };
}
