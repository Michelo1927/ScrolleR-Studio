/// Stato dell'editor in un unico punto (piano §5.1): documento con cronologia, libreria, selezione, pagina
/// corrente e strumento aperto. L'interfaccia legge da qui e chiama i comandi del [ControlloEditor]; la logica
/// sul documento resta in `scrl_engine`.
///
/// Un passo di cronologia nasce alla ✓ di uno strumento, a fine gesto e a ogni comando singolo (l'equivalente
/// di `_schedule_commit` del desktop); mai durante il trascinamento di un cursore o di un elemento: lì c'è la
/// **bozza**, che si vede ma non entra in Annulla.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrl_engine/scrl_engine.dart';

import '../media/cache_media.dart' show chiaveMedia;
import '../media/mancanti.dart' show Ritrovata;
import '../render/caratteri.dart';
import 'sessione.dart';

/// Pannello aperto dal basso. Da `inquadra` a `ruota` sono gli strumenti Foto della foto selezionata, poi quelli del
/// Testo e delle Forme (piano §4.3); il Ritaglio non è un pannello ma una pagina a schermo intero.
enum Strumento {
  nessuno,
  libreria,
  disposizione,
  aggiungi,
  inquadra,
  filtri,
  regola,
  effetti,
  cornice,
  ombra,
  ruota,

  // Testo
  testoModifica,
  testoCarattere,
  testoDimensione,
  testoFormato,
  testoColore,
  testoContorno,
  testoEtichetta,
  testoSpaziatura,
  testoOpacita,
  testoRuota,

  // Forme
  formaNuova,
  formaTipo,
  formaRiempimento,
  formaBordo,
  formaAngoli,
  formaOpacita,
  formaRuota,

  // Pagine e carosello (Fase 6): pannello delle azioni di pagina, Stile e i suoi strumenti
  pagine,
  stile,
  sfondo,
  numeriPagina,
  scorri,

  // Comandi sulla selezione (Fase 6): Disponi (livello, blocco, frecce), Allinea, Distribuisci
  disponi,
  allinea,
  distribuisci,

  // Video (Fase 8): Taglia (inizio e fine) e Copertina del video selezionato
  videoTaglia,
  videoCopertina;

  /// Strumento Foto che lavora sulla foto selezionata.
  bool get eFoto => index >= inquadra.index && index <= ruota.index;

  /// Strumento Testo che lavora sul testo selezionato.
  bool get eTesto => index >= testoModifica.index && index <= testoRuota.index;

  /// Strumento Forme che lavora sulla forma selezionata (la scelta del tipo per una forma nuova non conta).
  bool get eForma => index >= formaTipo.index && index <= formaRuota.index;

  /// Comando sulla selezione (Disponi, Allinea, Distribuisci): agisce subito, a ogni tocco.
  bool get eDisposizione =>
      this == disponi || this == allinea || this == distribuisci;

  /// Strumento Video che lavora sul video selezionato.
  bool get eVideo => this == videoTaglia || this == videoCopertina;

  /// Strumento che lavora sull'elemento selezionato: la selezione resta ferma finché è aperto.
  bool get suElemento => eFoto || eTesto || eForma || eDisposizione || eVideo;

  /// Lo stile scelto con questo strumento diventa quello delle prossime forme (`_remember_shape_style`).
  bool get ricordaStileForma =>
      this == formaRiempimento || this == formaBordo || this == formaAngoli;

  /// Il menu da cui si apre lo strumento: ✓ e ✕ (e il gesto «indietro») ci tornano, invece di chiudere tutto.
  Strumento get genitore => switch (this) {
    sfondo || numeriPagina || scorri => stile,
    formaNuova => aggiungi,
    _ => nessuno,
  };

  /// Strumento che cambia i colori: ha il confronto prima/dopo `◐`.
  bool get eColore =>
      this == Strumento.filtri ||
      this == Strumento.regola ||
      this == Strumento.effetti;
}

/// Un punto della striscia (coordinate del progetto).
typedef Punto = ({double x, double y});

/// Messaggi brevi dell'editor (il testo sta nei file `.arb`).
enum MessaggioEditor {
  fotoAggiunte,
  fotoRicollegate,
  elementoEliminato,
  elementiEliminati,
  elementoDuplicato,
  telaSvuotata,
  fotoLibere,
  fotoInDisposizione,
  paginaAggiunta,
  salvataggioNonRiuscito,
  stileCopiato,
  stileIncollato,
  ritaglioApplicato,
  ritaglioTolto,
  modificaScartata,
  formaAggiunta,
  paginaDuplicata,
  paginaEliminata,
  paginaSpostata,
  paginaBloccata,
  paginaSbloccata,
  paginaUnita,
  paginaSeparata,
  paginaRiordinata,
  raggruppati,
  separati,
  serveDueElementi,
  serveTreElementi,
  nessunGruppo,
  posizioneBloccata,
  posizioneSbloccata,
  portatoDavanti,
  mandatoDietro,
  copiati,
  tagliati,
  incollati,
  nienteDaIncollare,
  fotoSpostate,
  selezionaPiu,
  sfondoSenzaFoto,
  inArrivo,
  videoSenzaAudio,
}

/// Un messaggio da mostrare: [id] cresce a ogni messaggio nuovo, così l'interfaccia riconosce i nuovi.
class Avviso {
  const Avviso(this.id, {this.notice, this.messaggio, this.n = 0});
  final int id;

  /// Avviso del motore (pagina bloccata, massimo di pagine…).
  final Notice? notice;
  final MessaggioEditor? messaggio;
  final int n;

  /// Dopo l'avviso si può tornare indietro con «Annulla».
  bool get annullabile =>
      messaggio == MessaggioEditor.elementoEliminato ||
      messaggio == MessaggioEditor.elementiEliminati ||
      messaggio == MessaggioEditor.elementoDuplicato ||
      messaggio == MessaggioEditor.telaSvuotata ||
      messaggio == MessaggioEditor.stileIncollato ||
      messaggio == MessaggioEditor.ritaglioApplicato ||
      messaggio == MessaggioEditor.ritaglioTolto ||
      messaggio == MessaggioEditor.formaAggiunta ||
      messaggio == MessaggioEditor.paginaDuplicata ||
      messaggio == MessaggioEditor.paginaEliminata ||
      messaggio == MessaggioEditor.paginaSpostata ||
      messaggio == MessaggioEditor.paginaBloccata ||
      messaggio == MessaggioEditor.paginaSbloccata ||
      messaggio == MessaggioEditor.paginaUnita ||
      messaggio == MessaggioEditor.paginaSeparata ||
      messaggio == MessaggioEditor.paginaRiordinata ||
      messaggio == MessaggioEditor.raggruppati ||
      messaggio == MessaggioEditor.separati ||
      messaggio == MessaggioEditor.posizioneBloccata ||
      messaggio == MessaggioEditor.posizioneSbloccata ||
      messaggio == MessaggioEditor.portatoDavanti ||
      messaggio == MessaggioEditor.mandatoDietro ||
      messaggio == MessaggioEditor.tagliati ||
      messaggio == MessaggioEditor.incollati ||
      messaggio == MessaggioEditor.fotoSpostate;

  /// Dopo l'avviso si può rimettere la modifica appena scartata con «Ripristina».
  bool get ripristinabile => messaggio == MessaggioEditor.modificaScartata;
}

class StatoEditor {
  const StatoEditor({
    required this.cronologia,
    required this.libreria,
    this.bozza,
    this.selezione = const {},
    this.pagina = 0,
    this.strumento = Strumento.nessuno,
    this.avviso,
    this.soloRiquadro = false,
    this.stileCopiato,
    this.stiliForma = const StiliForma(),
    this.contagocce = false,
    this.colorePreso,
    this.mostraGuide = true,
    this.aggancioAttivo = true,
    this.selezionePiu = false,
    this.videoInRiproduzione = const {},
  });

  final History cronologia;

  /// Modifica in corso (gesto o anteprima di uno strumento), non ancora in cronologia.
  final Snapshot? bozza;
  final List<LibraryEntry> libreria;
  final Set<RifElemento> selezione;
  final int pagina;
  final Strumento strumento;
  final Avviso? avviso;

  /// Interruttore «Solo riquadro» di Inquadra (lo Shift del desktop): le maniglie sui lati cambiano solo il riquadro
  /// invece di stirare la foto.
  final bool soloRiquadro;

  /// Stile copiato con «Copia stile» (non entra in Annulla né nel progetto, come sul desktop).
  final StileFoto? stileCopiato;

  /// Ultimi stili scelti per le forme piene e per le linee: le forme nuove li riprendono (come `_last_shape_style`,
  /// che sul desktop sta in memoria: non entra in Annulla né nel progetto).
  final StiliForma stiliForma;

  /// Contagocce acceso: il prossimo tocco sulla pagina preleva il colore di quel punto.
  final bool contagocce;

  /// L'ultimo colore prelevato con il contagocce; [n] cresce a ogni prelievo, così il selettore riconosce i nuovi.
  final ({int n, int argb})? colorePreso;

  /// Guide di centro sulla pagina (`show_guides` del desktop): una preferenza di vista, non entra in Annulla né
  /// nel progetto.
  final bool mostraGuide;

  /// Aggancio acceso (`snap_enabled` del desktop): spostando un elemento le sue linee si attaccano a quelle degli altri.
  final bool aggancioAttivo;

  /// Modalità «Seleziona più»: ogni tocco su un elemento lo aggiunge alla selezione o lo toglie.
  final bool selezionePiu;

  /// Video (`uid`) che si stanno riproducendo sulla tela, senza audio e a ripetizione: una preferenza di vista,
  /// non entra in Annulla né nel progetto.
  final Set<int> videoInRiproduzione;

  /// Ciò che si vede: la bozza se c'è, altrimenti l'ultimo passo.
  Snapshot get snapshot => bozza ?? cronologia.current;

  bool get puoAnnullare => bozza == null && cronologia.canUndo;
  bool get puoRipetere => bozza == null && cronologia.canRedo;

  /// Elementi selezionati ancora presenti nel documento.
  List<CanvasElement> get elementiSelezionati =>
      elementiDi(snapshot, selezione);

  StatoEditor copia({
    History? cronologia,
    Snapshot? Function()? bozza,
    List<LibraryEntry>? libreria,
    Set<RifElemento>? selezione,
    int? pagina,
    Strumento? strumento,
    Avviso? avviso,
    bool? soloRiquadro,
    StileFoto? stileCopiato,
    StiliForma? stiliForma,
    bool? contagocce,
    ({int n, int argb})? colorePreso,
    bool? mostraGuide,
    bool? aggancioAttivo,
    bool? selezionePiu,
    Set<int>? videoInRiproduzione,
  }) => StatoEditor(
    cronologia: cronologia ?? this.cronologia,
    bozza: bozza != null ? bozza() : this.bozza,
    libreria: libreria ?? this.libreria,
    selezione: selezione ?? this.selezione,
    pagina: pagina ?? this.pagina,
    strumento: strumento ?? this.strumento,
    avviso: avviso ?? this.avviso,
    soloRiquadro: soloRiquadro ?? this.soloRiquadro,
    stileCopiato: stileCopiato ?? this.stileCopiato,
    stiliForma: stiliForma ?? this.stiliForma,
    contagocce: contagocce ?? this.contagocce,
    colorePreso: colorePreso ?? this.colorePreso,
    mostraGuide: mostraGuide ?? this.mostraGuide,
    aggancioAttivo: aggancioAttivo ?? this.aggancioAttivo,
    selezionePiu: selezionePiu ?? this.selezionePiu,
    videoInRiproduzione: videoInRiproduzione ?? this.videoInRiproduzione,
  );
}

/// Appunti interni dell'app (piano §6 «Comuni a tutti gli elementi»): elementi copiati o tagliati, validi anche in un
/// altro progetto. Stanno fuori dall'editor, così sopravvivono alla chiusura di un progetto e all'apertura di un altro.
class AppuntiApp {
  const AppuntiApp({
    required this.dati,
    required this.cartellaOrigine,
    this.ripetizione = 0,
  });

  final AppuntiElementi dati;

  /// Cartella del progetto da cui vengono: le foto con un file nel progetto (`media/`) si portano nel progetto di
  /// destinazione all'incolla.
  final String? cartellaOrigine;

  /// Quante volte sono già stati incollati nella pagina d'origine (ogni copia si sposta di 30 unità; −1 dopo «Taglia»).
  final int ripetizione;

  AppuntiApp conRipetizione(int r) =>
      AppuntiApp(dati: dati, cartellaOrigine: cartellaOrigine, ripetizione: r);
}

class AppuntiNotifier extends Notifier<AppuntiApp?> {
  @override
  AppuntiApp? build() => null;

  void imposta(AppuntiApp a) => state = a;
  void ripetizione(int r) => state = state?.conRipetizione(r);
}

final appuntiProvider = NotifierProvider<AppuntiNotifier, AppuntiApp?>(
  AppuntiNotifier.new,
);

/// La sessione del progetto aperto: si fornisce con un `ProviderScope` attorno all'editor.
final sessioneProvider = Provider<SessioneEditor>(
  (ref) => throw UnimplementedError('Manca il ProviderScope della sessione'),
);

final editorProvider =
    NotifierProvider.autoDispose<ControlloEditor, StatoEditor>(
      ControlloEditor.new,
      dependencies: [sessioneProvider],
    );

class ControlloEditor extends Notifier<StatoEditor> {
  late final SessioneEditor _s;
  Timer? _timer;
  int _prossimoAvviso = 1;

  /// Pausa tra l'ultima modifica e il salvataggio (piano §5.3).
  static const ritardoSalvataggio = Duration(seconds: 1);

  @override
  StatoEditor build() {
    _s = ref.watch(sessioneProvider);
    ref.onDispose(() => _timer?.cancel());
    final r = History.reset(_s.inizio, _s.ctx);
    _s.ctx.observe(r.snapshot.allElements);
    // Misure delle foto non ancora note: dopo, per non rallentare l'apertura
    scheduleMicrotask(_completaMisure);
    return StatoEditor(cronologia: r.history, libreria: _s.libreriaIniziale);
  }

  Future<void> _completaMisure() async {
    if (await _s.completaMisure(state.snapshot, state.libreria)) {
      _programmaSalvataggio();
    }
    // Poi, senza fretta, via le anteprime su disco di foto che nel progetto non ci sono più
    await _s.cache.pulisciOrfane([
      for (final p in state.snapshot.items) chiaveMedia(p),
      for (final e in state.libreria) _s.chiaveVoce(e),
    ]);
  }

  // ---------- Selezione e pagina ----------
  void vaiAPagina(int i) {
    final n = state.snapshot.canvas.numFrames;
    final p = i.clamp(0, n - 1);
    if (p != state.pagina) state = state.copia(pagina: p);
  }

  void seleziona(Iterable<RifElemento> refs) =>
      state = state.copia(selezione: refs.toSet());

  /// Toglie la selezione ed esce dalla modalità «Seleziona più».
  void deseleziona() {
    if (state.selezione.isNotEmpty || state.selezionePiu) {
      state = state.copia(selezione: {}, selezionePiu: false);
    }
  }

  void apriStrumento(Strumento s) {
    if (s == state.strumento) return;
    // Copertina: si vede il fotogramma scelto, non quello della riproduzione
    final gira = s == Strumento.videoCopertina
        ? state.videoInRiproduzione.difference({
            for (final p in videoSelezionati) p.uid,
          })
        : null;
    // Una bozza rimasta di un altro strumento non entra in cronologia
    state = state.copia(
      strumento: s,
      bozza: () => null,
      contagocce: false,
      videoInRiproduzione: gira,
    );
  }

  /// La selezione senza gli elementi che nel documento [s] non ci sono (un testo nato solo in bozza e scartato).
  Set<RifElemento> _selezioneIn(Snapshot s) => {
    for (final r in state.selezione)
      if (elementoDi(s, r) != null) r,
  };

  /// ✕: scarta la bozza e chiude il pannello (si torna al menu da cui lo strumento si è aperto, se c'è).
  void chiudiStrumento() => state = state.copia(
    strumento: state.strumento.genitore,
    selezione: _selezioneIn(state.cronologia.current),
    bozza: () => null,
    soloRiquadro: false,
    contagocce: false,
  );

  Snapshot? _scartata;
  Snapshot? _baseScartata;

  /// Gesto «indietro» di sistema o pannello trascinato verso il basso: scarta come ✕; se la modifica scartata
  /// era consistente, un messaggio breve offre «Ripristina» per qualche secondo (piano §4.4).
  void chiudiStrumentoDaGesto() {
    final b = state.bozza;
    if (b != null && b != state.cronologia.current) {
      _scartata = b;
      _baseScartata = state.cronologia.current;
      state = state.copia(
        strumento: state.strumento.genitore,
        selezione: _selezioneIn(state.cronologia.current),
        bozza: () => null,
        soloRiquadro: false,
        contagocce: false,
        avviso: Avviso(
          _prossimoAvviso++,
          messaggio: MessaggioEditor.modificaScartata,
        ),
      );
    } else {
      chiudiStrumento();
    }
  }

  /// «Ripristina»: rimette la modifica scartata col gesto, se nel frattempo il documento non è cambiato.
  void ripristinaScartata() {
    final s = _scartata;
    final base = _baseScartata;
    _scartata = _baseScartata = null;
    if (s == null ||
        base == null ||
        !identical(base, state.cronologia.current)) {
      return;
    }
    _commit(s);
  }

  // ---------- Bozza e cronologia ----------
  /// Mostra [s] senza metterlo in cronologia (trascinamento, cursore, anteprima di uno strumento).
  void anteprima(Snapshot s) => state = state.copia(bozza: () => s);

  /// Fine gesto o ✓: la bozza (o [s]) diventa un passo di cronologia.
  void conferma([Snapshot? s, List<Notice> notice = const []]) {
    final daFare = s ?? state.bozza;
    if (daFare == null) return;
    _commit(daFare, notice: notice);
  }

  void scarta() => state = state.copia(bozza: () => null);

  /// ✓ di uno strumento: la bozza diventa un passo di cronologia e il pannello si chiude.
  void confermaEChiudi([List<Notice> notice = const []]) {
    final b = state.bozza;
    final ricorda = state.strumento.ricordaStileForma;
    if (b != null) _commit(b, notice: notice);
    state = state.copia(
      strumento: state.strumento.genitore,
      soloRiquadro: false,
      contagocce: false,
    );
    if (ricorda) _ricordaStileForma();
  }

  /// Tocco sulla tela su un altro elemento mentre un pannello è aperto: le modifiche restano (come ✓), tutti i
  /// pannelli si chiudono e si seleziona [refs], così compare subito la sua barra.
  void passaAElemento(Iterable<RifElemento> refs) {
    final b = state.bozza;
    if (b != null && b != state.cronologia.current) _commit(b);
    if (state.strumento.ricordaStileForma) _ricordaStileForma();
    state = state.copia(
      strumento: Strumento.nessuno,
      selezione: refs.toSet(),
      selezionePiu: false,
      bozza: () => null,
      soloRiquadro: false,
      contagocce: false,
    );
  }

  /// Applica il risultato di un'operazione del motore come passo di cronologia, con i suoi avvisi.
  /// Falso se il motore l'ha rifiutata (il motivo finisce nei messaggi).
  bool applica(EngineResult r, {Set<RifElemento>? selezione}) {
    if (!r.applied) {
      avvisaNotice(r.notices);
      return false;
    }
    _commit(r.snapshot, notice: r.notices, selezione: selezione);
    return true;
  }

  void _commit(
    Snapshot s, {
    List<Notice> notice = const [],
    Set<RifElemento>? selezione,
    MessaggioEditor? messaggio,
    int n = 0,
  }) {
    final c = state.cronologia.commit(s, _s.ctx);
    final tutti = [...notice, ...c.notices];
    final snap = c.snapshot;
    var sel = selezione ?? state.selezione;
    sel = {
      for (final r in sel)
        if (elementoDi(snap, r) != null) r,
    };
    final pagina = state.pagina.clamp(0, snap.canvas.numFrames - 1);
    Avviso? avviso;
    if (messaggio != null) {
      avviso = Avviso(_prossimoAvviso++, messaggio: messaggio, n: n);
    } else if (tutti.isNotEmpty) {
      avviso = Avviso(_prossimoAvviso++, notice: tutti.first);
    }
    state = state.copia(
      cronologia: c.history,
      bozza: () => null,
      selezione: sel,
      pagina: pagina,
      avviso: avviso,
      videoInRiproduzione: _videoPresenti(snap),
    );
    if (c.added) _programmaSalvataggio();
  }

  void avvisaNotice(List<Notice> notice) {
    if (notice.isEmpty) return;
    state = state.copia(
      avviso: Avviso(_prossimoAvviso++, notice: notice.first),
    );
  }

  /// Funzione che arriva con una fase successiva (per esempio «Esporta questa pagina»).
  void inArrivo() => messaggio(MessaggioEditor.inArrivo);

  void messaggio(MessaggioEditor m, {int n = 0}) => state = state.copia(
    avviso: Avviso(_prossimoAvviso++, messaggio: m, n: n),
  );

  void annulla() {
    if (state.puoAnnullare) _vaiA(state.cronologia.undo());
  }

  void ripeti() {
    if (state.puoRipetere) _vaiA(state.cronologia.redo());
  }

  void _vaiA(History h) {
    _s.ctx.resetSession();
    _s.ctx.observe(h.current.allElements);
    state = state.copia(
      cronologia: h,
      bozza: () => null,
      selezione: {
        for (final r in state.selezione)
          if (elementoDi(h.current, r) != null) r,
      },
      pagina: state.pagina.clamp(0, h.current.canvas.numFrames - 1),
      videoInRiproduzione: _videoPresenti(h.current),
    );
    _programmaSalvataggio();
  }

  /// I video in riproduzione che nel documento [s] ci sono ancora (un video eliminato o annullato si ferma).
  Set<int> _videoPresenti(Snapshot s) {
    final r = state.videoInRiproduzione;
    if (r.isEmpty) return r;
    final ci = {
      for (final p in s.items)
        if (p.isVideo && r.contains(p.uid)) p.uid,
    };
    return ci.length == r.length ? r : ci;
  }

  // ---------- Comandi sugli elementi selezionati ----------
  void eliminaSelezione() {
    final sel = state.selezione;
    if (sel.isEmpty) return;
    _commit(
      eliminaElementi(state.snapshot, sel),
      selezione: {},
      messaggio: sel.length == 1
          ? MessaggioEditor.elementoEliminato
          : MessaggioEditor.elementiEliminati,
      n: sel.length,
    );
  }

  void duplicaSelezione() {
    final sel = state.selezione;
    if (sel.isEmpty) return;
    final d = duplicaElementi(state.snapshot, sel, _s.ctx);
    _commit(
      d.snapshot,
      selezione: d.copie.toSet(),
      messaggio: MessaggioEditor.elementoDuplicato,
    );
  }

  /// Foto libera ↔ foto nella disposizione, per le foto selezionate.
  void liberaSelezione() {
    final uids = [
      for (final r in state.selezione)
        if (r.tipo == ElementKind.photo) r.uid,
    ];
    if (uids.isEmpty) return;
    final tutteLibere = elementiDi(
      state.snapshot,
      state.selezione,
    ).whereType<PhotoItem>().every((p) => p.free);
    final r = toggleFree(state.snapshot, uids, _s.ctx);
    if (r.applied) {
      _commit(
        r.snapshot,
        notice: r.notices,
        messaggio: tutteLibere
            ? MessaggioEditor.fotoInDisposizione
            : MessaggioEditor.fotoLibere,
      );
    }
  }

  // ---------- Strumenti Foto (Fase 4) ----------
  /// Le foto selezionate (senza testi e forme), come nel documento che si vede.
  List<PhotoItem> get fotoSelezionate =>
      state.elementiSelezionati.whereType<PhotoItem>().toList();

  /// Applica [f] alle foto selezionate e mostra il risultato come bozza (non entra in Annulla finché non c'è ✓).
  void modificaFotoSelezionate(PhotoItem Function(PhotoItem) f) {
    final uids = [for (final p in fotoSelezionate) p.uid];
    if (uids.isEmpty) return;
    anteprima(modificaFoto(state.snapshot, uids, f));
  }

  /// «Applica a tutte» dei colori: le regolazioni della foto principale su tutte le foto (bozza, poi ✓).
  void coloriATutteLeFoto() {
    final p = fotoSelezionate;
    if (p.isEmpty) return;
    anteprima(coloriATutte(state.snapshot, p.first));
  }

  /// «Applica a tutte» di cornice, opacità e ombra (bozza, poi ✓).
  void stileATutteLeFoto() {
    final p = fotoSelezionate;
    if (p.isEmpty) return;
    anteprima(stileATutte(state.snapshot, p.first));
  }

  void impostaSoloRiquadro(bool v) => state = state.copia(soloRiquadro: v);

  /// Ritaglio a schermo intero confermato: [ritaglio] in frazioni sulla foto originale.
  void applicaRitaglio(List<double> ritaglio, {required bool adattaRiquadro}) {
    final p = fotoSelezionate;
    if (p.isEmpty) return;
    final dopo = modificaFoto(state.snapshot, [
      for (final f in p) f.uid,
    ], (f) => conRitaglio(f, ritaglio, adattaRiquadro, _s.misuraDi(f)));
    final primo = dopo.items.firstWhere((f) => f.uid == p.first.uid);
    _commit(
      dopo,
      messaggio: haRitaglio(primo)
          ? MessaggioEditor.ritaglioApplicato
          : MessaggioEditor.ritaglioTolto,
    );
  }

  /// «Copia stile»: cornice, opacità, ombra e colori della foto principale.
  void copiaStile() {
    final p = fotoSelezionate;
    if (p.isEmpty) return;
    state = state.copia(
      stileCopiato: StileFoto.di(p.first),
      avviso: Avviso(
        _prossimoAvviso++,
        messaggio: MessaggioEditor.stileCopiato,
      ),
    );
  }

  /// «Incolla stile» sulle foto selezionate.
  void incollaStileCopiato() {
    final stile = state.stileCopiato;
    final uids = [for (final p in fotoSelezionate) p.uid];
    if (stile == null || uids.isEmpty) return;
    _commit(
      incollaStile(state.snapshot, uids, stile),
      messaggio: MessaggioEditor.stileIncollato,
    );
  }

  // ---------- Video (Fase 8) ----------
  /// I video selezionati, come nel documento che si vede.
  List<PhotoItem> get videoSelezionati =>
      fotoSelezionate.where((p) => p.isVideo).toList();

  /// Durata del video [p] in secondi (0 finché non si conosce).
  double durataVideo(PhotoItem p) => _s.risorse.durataVideo(p);

  /// Applica [f] (con la durata di ciascun video) ai video selezionati, come bozza: con ✓ diventa un passo.
  void modificaVideoSelezionati(PhotoItem Function(PhotoItem, double) f) {
    final uids = [for (final p in videoSelezionati) p.uid];
    if (uids.isEmpty) return;
    anteprima(modificaFoto(state.snapshot, uids, (p) => f(p, durataVideo(p))));
  }

  /// «Audio»: acceso o spento nell'MP4 esportato, per tutti i video selezionati (un tocco = un passo).
  void alternaAudioVideo() {
    final v = videoSelezionati;
    if (v.isEmpty) return;
    final acceso = !(v.first.muted);
    _commit(
      modificaFoto(state.snapshot, [
        for (final p in v) p.uid,
      ], (p) => conAudio(p, !acceso)),
    );
  }

  /// «Riproduci» / «Pausa» (`_toggle_video_play`): se uno dei video selezionati gira si fermano tutti, altrimenti
  /// partono tutti.
  void alternaRiproduzione() {
    final v = {for (final p in videoSelezionati) p.uid};
    if (v.isEmpty) return;
    final r = state.videoInRiproduzione;
    state = state.copia(
      videoInRiproduzione: v.any(r.contains) ? r.difference(v) : r.union(v),
    );
  }

  /// Il video [uid] non si può riprodurre (file mancante o illeggibile): si ferma.
  void fermaVideo(int uid) {
    final r = state.videoInRiproduzione;
    if (r.contains(uid)) {
      state = state.copia(videoInRiproduzione: {...r}..remove(uid));
    }
  }

  /// Ferma tutti i video (esportazione, app in secondo piano), come `_stop_all_videos`.
  void fermaTuttiVideo() {
    if (state.videoInRiproduzione.isNotEmpty) {
      state = state.copia(videoInRiproduzione: const {});
    }
  }

  // ---------- Testo (Fase 5) ----------
  /// I testi selezionati, come nel documento che si vede.
  List<TextItem> get testiSelezionati =>
      state.elementiSelezionati.whereType<TextItem>().toList();

  /// Contesto del motore: misura dei testi (dipende dai caratteri) e contatori degli `uid`.
  EngineContext get contesto => _s.ctx;

  /// L'elemento [r] con il centro in [punto] (della striscia), se c'è; altrimenti dov'è (al centro della pagina).
  Snapshot _centratoIn(Snapshot s, RifElemento r, Punto? punto) {
    final e = elementoDi(s, r);
    if (punto == null || e == null) return s;
    final c = Scene(s, _s.ctx).elementRect(e);
    return spostaElementi(s, [r], punto.x - c.centerX, punto.y - c.centerY);
  }

  /// «＋ → Testo»: un testo nuovo al centro della pagina corrente, selezionato, con la tastiera pronta a scriverci.
  /// Nasce come **bozza**: con ✓ diventa un solo passo di cronologia (testo compreso), con ✕ non è mai esistito.
  void nuovoTesto({Punto? punto}) {
    final r = aggiungiTesto(
      state.snapshot,
      _s.ctx,
      pagina: state.pagina,
      carattere: Caratteri.predefinito,
    );
    state = state.copia(
      bozza: () => _centratoIn(r.snapshot, r.ref, punto),
      selezione: {r.ref},
      strumento: Strumento.testoModifica,
      contagocce: false,
    );
  }

  /// Applica [f] ai testi selezionati e mostra il risultato come bozza (non entra in Annulla finché non c'è ✓).
  void modificaTestiSelezionati(TextItem Function(TextItem) f) {
    final uids = [for (final t in testiSelezionati) t.uid];
    if (uids.isEmpty) return;
    anteprima(modificaTesti(state.snapshot, uids, f));
  }

  /// Comando singolo: ombra del testo accesa o spenta, subito, in un passo di cronologia.
  void alternaOmbraTesto() {
    final t = testiSelezionati;
    if (t.isEmpty) return;
    final acceso = !t.first.shadow;
    _commit(
      modificaTesti(state.snapshot, [
        for (final x in t) x.uid,
      ], (x) => conOmbraTesto(x, acceso)),
    );
  }

  // ---------- Forme (Fase 5) ----------
  /// Le forme selezionate, come nel documento che si vede.
  List<ShapeItem> get formeSelezionate =>
      state.elementiSelezionati.whereType<ShapeItem>().toList();

  /// «＋ → Forma → tipo»: una forma nuova al centro della pagina corrente, con l'ultimo stile usato, selezionata.
  void nuovaForma(String tipo, {Punto? punto}) {
    final r = aggiungiForma(
      state.snapshot,
      _s.ctx,
      kind: tipo,
      pagina: state.pagina,
      stili: state.stiliForma,
    );
    _commit(
      _centratoIn(r.snapshot, r.ref, punto),
      selezione: {r.ref},
      messaggio: MessaggioEditor.formaAggiunta,
    );
    state = state.copia(strumento: Strumento.nessuno);
  }

  /// Applica [f] alle forme selezionate e mostra il risultato come bozza (non entra in Annulla finché non c'è ✓).
  void modificaFormeSelezionate(ShapeItem Function(ShapeItem) f) {
    final uids = [for (final x in formeSelezionate) x.uid];
    if (uids.isEmpty) return;
    anteprima(modificaForme(state.snapshot, uids, f));
  }

  /// Le prossime forme dello stesso tipo (piene o linee) nascono con lo stile della prima forma selezionata.
  void _ricordaStileForma() {
    final f = formeSelezionate;
    if (f.isEmpty) return;
    state = state.copia(stiliForma: state.stiliForma.ricorda(f.first));
  }

  // ---------- Selettore colore ----------
  /// Accende o spegne il contagocce: da acceso, il prossimo tocco sulla pagina preleva il colore.
  void attivaContagocce(bool acceso) {
    if (state.contagocce != acceso) state = state.copia(contagocce: acceso);
  }

  /// La tela ha prelevato [argb] dal punto toccato: il contagocce si spegne e il selettore riceve il colore.
  void coloreCampionato(int argb) => state = state.copia(
    contagocce: false,
    colorePreso: (n: (state.colorePreso?.n ?? 0) + 1, argb: argb),
  );

  // ---------- Pagine (Fase 6) ----------
  /// Applica il risultato di un comando di pagina: un passo di cronologia con il suo messaggio (gli avvisi del motore
  /// hanno la precedenza) e, se serve, la vista passa a [vaiA]. Falso se il motore l'ha rifiutato.
  bool _comandoPagina(
    EngineResult r, {
    MessaggioEditor? messaggio,
    int n = 0,
    int? vaiA,
  }) {
    if (!r.applied) {
      avvisaNotice(r.notices);
      return false;
    }
    _commit(
      r.snapshot,
      notice: r.notices,
      messaggio: r.notices.isEmpty ? messaggio : null,
      n: n,
    );
    if (vaiA != null) {
      final ultima = state.snapshot.canvas.numFrames - 1;
      state = state.copia(pagina: vaiA.clamp(0, ultima));
    }
    return true;
  }

  /// «Pagina nuova» dopo la corrente.
  void aggiungiPagina() => inserisciPagina(state.pagina + 1);

  /// Pagina vuota in posizione [posizione] (0 = all'inizio); la vista passa alla pagina nuova.
  void inserisciPagina(int posizione) => _comandoPagina(
    insertPageAt(state.snapshot, posizione, _s.ctx),
    messaggio: MessaggioEditor.paginaAggiunta,
    vaiA: posizione,
  );

  void duplicaPagina([int? k]) {
    final p = k ?? state.pagina;
    _comandoPagina(
      duplicatePage(state.snapshot, p, _s.ctx),
      messaggio: MessaggioEditor.paginaDuplicata,
      n: p + 2,
      vaiA: p + 1,
    );
  }

  void eliminaPagina([int? k]) {
    final p = k ?? state.pagina;
    _comandoPagina(
      deletePage(state.snapshot, p, _s.ctx),
      messaggio: MessaggioEditor.paginaEliminata,
      n: p + 1,
      vaiA: math.min(p, state.snapshot.canvas.numFrames - 2),
    );
  }

  /// Sposta la pagina [k] di un posto ([direzione] −1 o +1); un gruppo «a cavallo» si sposta intero.
  void spostaPagina(int direzione, [int? k]) {
    final p = k ?? state.pagina;
    final ordine = ordineSpostaPagina(state.snapshot.canvas, p, direzione);
    if (ordine == null) {
      avvisaNotice(const [Notice(NoticeKind.pageAtEdge)]);
      return;
    }
    final nuova = ordine.indexOf(p);
    _comandoPagina(
      reorderPages(state.snapshot, ordine, _s.ctx),
      messaggio: MessaggioEditor.paginaSpostata,
      n: nuova + 1,
      vaiA: nuova,
    );
  }

  /// Riordina le pagine (Panoramica): `ordine[nuova posizione] = vecchia posizione`. La vista segue la pagina corrente.
  void riordinaPagine(List<int> ordine) => _comandoPagina(
    reorderPages(state.snapshot, ordine, _s.ctx),
    messaggio: MessaggioEditor.paginaRiordinata,
    vaiA: ordine.indexOf(state.pagina),
  );

  /// Blocca o sblocca la pagina [k] (un gruppo «a cavallo» si blocca intero).
  void bloccaPagina([int? k]) {
    final p = k ?? state.pagina;
    final r = togglePageLock(state.snapshot, p, _s.ctx);
    _comandoPagina(
      r,
      messaggio: r.snapshot.canvas.pageLocked(p)
          ? MessaggioEditor.paginaBloccata
          : MessaggioEditor.paginaSbloccata,
      n: p + 1,
    );
  }

  /// Unisce «a cavallo» la pagina [k] con la successiva, o le separa.
  void unisciPagina([int? k]) {
    final p = k ?? state.pagina;
    final r = togglePageJoined(state.snapshot, p, _s.ctx);
    _comandoPagina(
      r,
      messaggio: r.snapshot.canvas.joined(p)
          ? MessaggioEditor.paginaUnita
          : MessaggioEditor.paginaSeparata,
      n: p + 1,
    );
  }

  /// Formato del carosello scelto dall'elenco (8 = Personalizzato, con le ultime misure personalizzate).
  void impostaFormato(int indice) =>
      _comandoPagina(setAspectRatio(state.snapshot, indice, _s.ctx));

  /// Misure del formato Personalizzato (200–6000 px).
  void impostaMisure(int larghezza, int altezza) =>
      _comandoPagina(setCustomSize(state.snapshot, larghezza, altezza, _s.ctx));

  // ---------- Selezione multipla e comandi sulla selezione (Fase 6) ----------
  /// «Seleziona più»: da ora ogni tocco su un elemento lo aggiunge alla selezione o lo toglie.
  void impostaSelezionePiu(bool acceso) {
    if (state.selezionePiu == acceso) return;
    state = state.copia(selezionePiu: acceso);
  }

  /// In «Seleziona più»: aggiunge [e] (con tutto il suo gruppo) alla selezione o lo toglie.
  void alternaInSelezione(CanvasElement e) {
    final refs = conGruppo(state.snapshot, e);
    final sel = {...state.selezione};
    if (sel.contains(rifDi(e))) {
      sel.removeAll(refs);
    } else {
      sel.addAll(refs);
    }
    state = state.copia(selezione: sel);
  }

  /// Seleziona tutti gli elementi (tranne quelli delle pagine bloccate, che non si selezionano).
  void selezionaTutto() => state = state.copia(
    selezione: {
      for (final e in state.snapshot.allElements)
        if (!e.pageLocked) rifDi(e),
    },
  );

  void raggruppaSelezione() {
    final r = raggruppa(state.snapshot, state.selezione);
    if (r == null) {
      messaggio(MessaggioEditor.serveDueElementi);
      return;
    }
    _commit(
      r,
      messaggio: MessaggioEditor.raggruppati,
      n: state.selezione.length,
    );
  }

  void separaSelezione() {
    final r = separa(state.snapshot, state.selezione);
    if (r == null) {
      messaggio(MessaggioEditor.nessunGruppo);
      return;
    }
    _commit(r, messaggio: MessaggioEditor.separati);
  }

  /// «Blocca posizione e dimensioni»: se non sono tutti bloccati si bloccano tutti, altrimenti si sbloccano.
  void bloccaSelezione() {
    final r = alternaBloccoPosizione(state.snapshot, state.selezione);
    if (r == null) return;
    _commit(
      r.snapshot,
      messaggio: r.bloccati
          ? MessaggioEditor.posizioneBloccata
          : MessaggioEditor.posizioneSbloccata,
    );
  }

  void davantiSelezione() {
    if (state.selezione.isEmpty) return;
    _commit(
      portaDavanti(state.snapshot, state.selezione),
      messaggio: MessaggioEditor.portatoDavanti,
    );
  }

  void dietroSelezione() {
    if (state.selezione.isEmpty) return;
    _commit(
      mandaDietro(state.snapshot, state.selezione),
      messaggio: MessaggioEditor.mandatoDietro,
    );
  }

  void allineaSelezione(Allineamento come) {
    if (state.selezione.isEmpty) return;
    _commit(allinea(state.snapshot, state.selezione, come, _s.ctx));
  }

  void distribuisciSelezione({required bool orizzontale}) {
    final r = distribuisci(
      state.snapshot,
      state.selezione,
      orizzontale: orizzontale,
      ctx: _s.ctx,
    );
    if (r == null) {
      messaggio(MessaggioEditor.serveTreElementi);
      return;
    }
    _commit(r);
  }

  /// Spostamento fine con le quattro frecce dello strumento Disponi (gli elementi bloccati restano fermi).
  void spostaSelezione(double dx, double dy) {
    if (state.selezione.isEmpty) return;
    _commit(spostaElementi(state.snapshot, state.selezione, dx, dy));
  }

  /// «Scambia» le due foto selezionate (con altro numero di foto il motore rifiuta e dice perché).
  void scambiaFoto() {
    final uids = [for (final p in fotoSelezionate) p.uid];
    if (uids.length != 2) {
      avvisaNotice(const [Notice(NoticeKind.swapNeedsTwo)]);
      return;
    }
    applica(swapPhotos(state.snapshot, uids[0], uids[1], _s.ctx));
  }

  /// «Sposta in pagina N»: le foto selezionate passano a quella pagina (`_move_photos_to_page`).
  void spostaFotoInPagina(int pagina) {
    final uids = [for (final p in fotoSelezionate) p.uid];
    if (uids.isEmpty) return;
    final r = movePhotosToPage(state.snapshot, uids, pagina, _s.ctx);
    if (_comandoPagina(
      r,
      messaggio: MessaggioEditor.fotoSpostate,
      n: pagina + 1,
    )) {
      vaiAPagina(pagina);
    }
  }

  // ---------- Appunti interni (Fase 6) ----------
  /// «Copia»: foto, testi e forme selezionati negli appunti dell'app (validi anche in un altro progetto).
  void copiaSelezione() {
    final a = copiaElementi(state.snapshot, state.selezione, _s.ctx);
    if (a == null) return;
    ref
        .read(appuntiProvider.notifier)
        .imposta(AppuntiApp(dati: a, cartellaOrigine: _s.cartella.path));
    messaggio(MessaggioEditor.copiati, n: a.numero);
  }

  /// «Taglia»: copia e toglie dalla tela; il primo «Incolla» li rimette dov'erano.
  void tagliaSelezione() {
    final a = copiaElementi(state.snapshot, state.selezione, _s.ctx);
    if (a == null) return;
    ref
        .read(appuntiProvider.notifier)
        .imposta(
          AppuntiApp(
            dati: a,
            cartellaOrigine: _s.cartella.path,
            ripetizione: -1,
          ),
        );
    _commit(
      eliminaElementi(state.snapshot, state.selezione),
      selezione: {},
      messaggio: MessaggioEditor.tagliati,
      n: a.numero,
    );
  }

  /// «Incolla» nella pagina [pagina] (di partenza la corrente), nella stessa posizione che gli elementi avevano nella
  /// loro pagina; nella stessa pagina ogni copia si sposta di 30 unità. Le foto incollate sono libere. Le foto
  /// copiate da un altro progetto portano con sé il loro file (`media/`) e finiscono anche nella libreria.
  Future<void> incolla({int? pagina}) async {
    final ap = ref.read(appuntiProvider);
    if (ap == null) {
      messaggio(MessaggioEditor.nienteDaIncollare);
      return;
    }
    final voci = await _s.portaMedia(ap.dati, ap.cartellaOrigine);
    final k = pagina ?? state.pagina;
    final stessa = k == ap.dati.pagina;
    final rip = stessa ? ap.ripetizione + 1 : ap.ripetizione;
    final r = incollaElementi(state.snapshot, ap.dati, k, rip, _s.ctx);
    if (!r.risultato.applied) {
      avvisaNotice(r.risultato.notices);
      return;
    }
    ref.read(appuntiProvider.notifier).ripetizione(rip);
    if (voci.isNotEmpty) aggiungiAllaLibreria(voci);
    _commit(
      r.risultato.snapshot,
      notice: r.risultato.notices,
      selezione: r.incollati.toSet(),
      messaggio: MessaggioEditor.incollati,
      n: r.incollati.length,
    );
    if (voci.isNotEmpty) unawaited(_completaMisure());
  }

  // ---------- Stile, Sfondo, Numeri di pagina (Fase 6) ----------
  /// Cambia le impostazioni della tela e mostra il risultato come bozza (Sfondo, Numeri di pagina, «scorri»):
  /// ✓ lo conferma come un solo passo di cronologia, ✕ torna com'era.
  void modificaTela(CanvasState Function(CanvasState) f) =>
      anteprima(state.snapshot.copyWith(canvas: f(state.snapshot.canvas)));

  void alternaGuide() => state = state.copia(mostraGuide: !state.mostraGuide);

  void alternaAggancio() =>
      state = state.copia(aggancioAttivo: !state.aggancioAttivo);

  // ---------- Esportazione (Fase 7) ----------
  /// Nome dei file esportati (`_set_export_name`): vale per il progetto e si salva con lui; entra in Annulla.
  void impostaNomeEsportazione(String nome) {
    final n = pulisciNomeFile(nome);
    final s = state.cronologia.current;
    if (n == s.canvas.exportName) return;
    _commit(s.copyWith(canvas: s.canvas.copyWith(exportName: n)));
  }

  // ---------- Cronologia (Fase 6) ----------
  /// Torna al passaggio [i] della cronologia (anche in avanti): come Annulla/Ripeti ripetuti.
  void vaiAPassaggio(int i) => _vaiA(state.cronologia.goTo(i));

  // ---------- Libreria ----------
  /// Aggiunge alla libreria le foto scelte (senza duplicati). La libreria non entra in Annulla, come sul desktop.
  void aggiungiAllaLibreria(Iterable<LibraryEntry> voci) {
    final gia = {for (final e in state.libreria) _s.chiaveVoce(e)};
    final nuove = <LibraryEntry>[];
    for (final v in voci) {
      if (gia.add(_s.chiaveVoce(v))) nuove.add(v);
    }
    if (nuove.isEmpty) return;
    state = state.copia(libreria: [...state.libreria, ...nuove]);
    _programmaSalvataggio();
  }

  void rimuoviDallaLibreria(Iterable<LibraryEntry> voci) {
    final chiavi = {for (final v in voci) _s.chiaveVoce(v)};
    state = state.copia(
      libreria: [
        for (final e in state.libreria)
          if (!chiavi.contains(_s.chiaveVoce(e))) e,
      ],
    );
    _programmaSalvataggio();
  }

  /// Riordina la libreria (pressione lunga + trascinamento).
  void riordinaLibreria(int da, int a) {
    final l = [...state.libreria];
    if (da < 0 || da >= l.length) return;
    final v = l.removeAt(da);
    l.insert(a.clamp(0, l.length), v);
    state = state.copia(libreria: l);
    _programmaSalvataggio();
  }

  static NuovaFoto _nuova(LibraryEntry e) => (
    path: e.path,
    rel: e.rel,
    asset: e.asset,
    video: Scene.isVideoPath(e.path),
  );

  /// «Aggiungi alla tela» / «Come foto libera»: le foto entrano nella pagina corrente e restano selezionate.
  void aggiungiATela(List<LibraryEntry> voci, {bool libere = false}) {
    if (voci.isEmpty) return;
    final a = aggiungiFoto(
      state.snapshot,
      [for (final v in voci) _nuova(v)],
      _s.ctx,
      pagina: state.pagina,
      libere: libere,
    );
    if (!a.risultato.applied) {
      avvisaNotice(a.risultato.notices);
      return;
    }
    _commit(
      a.risultato.snapshot,
      notice: a.risultato.notices,
      selezione: {for (final u in a.uids) (tipo: ElementKind.photo, uid: u)},
      messaggio: MessaggioEditor.fotoAggiunte,
      n: a.uids.length,
    );
  }

  /// «Solo queste» e «Metti tutte»: sostituisce le foto della tela con queste e le dispone.
  void mettiSullaTela(List<LibraryEntry> voci) {
    if (voci.isEmpty) return;
    final a = mettiFotoSullaTela(state.snapshot, [
      for (final v in voci) _nuova(v),
    ], _s.ctx);
    _commit(
      a.risultato.snapshot,
      notice: a.risultato.notices,
      selezione: {},
      messaggio: MessaggioEditor.fotoAggiunte,
      n: a.uids.length,
    );
  }

  void svuotaLaTela() {
    _commit(
      svuotaTela(state.snapshot),
      selezione: {},
      messaggio: MessaggioEditor.telaSvuotata,
    );
  }

  // ---------- Foto mancanti (Fase 9) ----------
  /// Ricollega foto mancanti: [perChiave] dice, per ogni foto (chiave), dove si trova ora. Il nuovo riferimento
  /// sostituisce il vecchio ovunque (tela, libreria, sfondo e **tutta la cronologia**, come `_remap_paths` del
  /// desktop): Annulla non rimette una foto mancante. Non è un passo di cronologia a sé.
  void ricollega(Map<String, Ritrovata> perChiave) {
    if (perChiave.isEmpty) return;
    Collegamento fn(Collegamento c) =>
        perChiave[chiaveDi(c)]?.collegamento ?? c;
    for (final e in perChiave.entries) {
      final nuova = e.value;
      final misura = nuova.misura ?? _s.misure[e.key];
      if (misura != null) {
        _s.ricordaMisura(chiaveDi(nuova.collegamento), misura.w, misura.h);
      }
    }
    final visti = <String>{};
    final libreria = [
      for (final e in riscriviLibreria(state.libreria, fn))
        if (visti.add(chiaveRiferimento(e.path, e.rel, e.asset))) e,
    ];
    final bozza = state.bozza;
    state = state.copia(
      cronologia: state.cronologia.riscritta((s) => riscriviSnapshot(s, fn)),
      bozza: () => bozza == null ? null : riscriviSnapshot(bozza, fn),
      libreria: libreria,
    );
    messaggio(MessaggioEditor.fotoRicollegate, n: perChiave.length);
    _programmaSalvataggio();
  }

  // ---------- Salvataggio ----------
  void _programmaSalvataggio() {
    _timer?.cancel();
    _timer = Timer(ritardoSalvataggio, () => unawaited(salvaOra()));
  }

  /// Salva subito (app in secondo piano, uscita dall'editor) e aggiorna la miniatura; all'uscita
  /// ([attendiMiniatura]) la aspetta, così la Home la mostra già aggiornata.
  Future<void> salvaOra({
    bool conMiniatura = true,
    bool attendiMiniatura = false,
  }) async {
    _timer?.cancel();
    final snap = state.cronologia.current;
    try {
      await _s.salva(snap, state.libreria);
    } on Exception {
      // Disco pieno o file non scrivibile: ci si riprova alla prossima modifica
      messaggio(MessaggioEditor.salvataggioNonRiuscito);
      return;
    }
    if (!conMiniatura) return;
    final miniatura = _s.aggiornaMiniatura(snap, subito: attendiMiniatura);
    if (attendiMiniatura) {
      await miniatura;
    } else {
      unawaited(miniatura);
    }
  }
}
