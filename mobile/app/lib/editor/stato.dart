/// Stato dell'editor in un unico punto (piano §5.1): documento con cronologia, libreria, selezione, pagina
/// corrente e strumento aperto. L'interfaccia legge da qui e chiama i comandi del [ControlloEditor]; la logica
/// sul documento resta in `scrl_engine`.
///
/// Un passo di cronologia nasce alla ✓ di uno strumento, a fine gesto e a ogni comando singolo (l'equivalente
/// di `_schedule_commit` del desktop); mai durante il trascinamento di un cursore o di un elemento: lì c'è la
/// **bozza**, che si vede ma non entra in Annulla.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrl_engine/scrl_engine.dart';

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
  formaRuota;

  /// Strumento Foto che lavora sulla foto selezionata.
  bool get eFoto => index >= inquadra.index && index <= ruota.index;

  /// Strumento Testo che lavora sul testo selezionato.
  bool get eTesto => index >= testoModifica.index && index <= testoRuota.index;

  /// Strumento Forme che lavora sulla forma selezionata (la scelta del tipo per una forma nuova non conta).
  bool get eForma => index >= formaTipo.index && index <= formaRuota.index;

  /// Strumento che lavora sull'elemento selezionato: la selezione resta ferma finché è aperto.
  bool get suElemento => eFoto || eTesto || eForma;

  /// Lo stile scelto con questo strumento diventa quello delle prossime forme (`_remember_shape_style`).
  bool get ricordaStileForma =>
      this == formaRiempimento || this == formaBordo || this == formaAngoli;

  /// Strumento che cambia i colori: ha il confronto prima/dopo `◐`.
  bool get eColore =>
      this == Strumento.filtri ||
      this == Strumento.regola ||
      this == Strumento.effetti;
}

/// Messaggi brevi dell'editor (il testo sta nei file `.arb`).
enum MessaggioEditor {
  fotoAggiunte,
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
      messaggio == MessaggioEditor.formaAggiunta;

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
    this.deforma = false,
    this.stileCopiato,
    this.stiliForma = const StiliForma(),
    this.contagocce = false,
    this.colorePreso,
  });

  final History cronologia;

  /// Modifica in corso (gesto o anteprima di uno strumento), non ancora in cronologia.
  final Snapshot? bozza;
  final List<LibraryEntry> libreria;
  final Set<RifElemento> selezione;
  final int pagina;
  final Strumento strumento;
  final Avviso? avviso;

  /// Interruttore «Deforma» di Inquadra: le maniglie sui lati stirano la foto invece di cambiare il riquadro.
  final bool deforma;

  /// Stile copiato con «Copia stile» (non entra in Annulla né nel progetto, come sul desktop).
  final StileFoto? stileCopiato;

  /// Ultimi stili scelti per le forme piene e per le linee: le forme nuove li riprendono (come `_last_shape_style`,
  /// che sul desktop sta in memoria: non entra in Annulla né nel progetto).
  final StiliForma stiliForma;

  /// Contagocce acceso: il prossimo tocco sulla pagina preleva il colore di quel punto.
  final bool contagocce;

  /// L'ultimo colore prelevato con il contagocce; [n] cresce a ogni prelievo, così il selettore riconosce i nuovi.
  final ({int n, int argb})? colorePreso;

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
    bool? deforma,
    StileFoto? stileCopiato,
    StiliForma? stiliForma,
    bool? contagocce,
    ({int n, int argb})? colorePreso,
  }) => StatoEditor(
    cronologia: cronologia ?? this.cronologia,
    bozza: bozza != null ? bozza() : this.bozza,
    libreria: libreria ?? this.libreria,
    selezione: selezione ?? this.selezione,
    pagina: pagina ?? this.pagina,
    strumento: strumento ?? this.strumento,
    avviso: avviso ?? this.avviso,
    deforma: deforma ?? this.deforma,
    stileCopiato: stileCopiato ?? this.stileCopiato,
    stiliForma: stiliForma ?? this.stiliForma,
    contagocce: contagocce ?? this.contagocce,
    colorePreso: colorePreso ?? this.colorePreso,
  );
}

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
  }

  // ---------- Selezione e pagina ----------
  void vaiAPagina(int i) {
    final n = state.snapshot.canvas.numFrames;
    final p = i.clamp(0, n - 1);
    if (p != state.pagina) state = state.copia(pagina: p);
  }

  void seleziona(Iterable<RifElemento> refs) =>
      state = state.copia(selezione: refs.toSet());

  void deseleziona() {
    if (state.selezione.isNotEmpty) state = state.copia(selezione: {});
  }

  void apriStrumento(Strumento s) {
    if (s == state.strumento) return;
    // Una bozza rimasta di un altro strumento non entra in cronologia
    state = state.copia(strumento: s, bozza: () => null, contagocce: false);
  }

  /// La selezione senza gli elementi che nel documento [s] non ci sono (un testo nato solo in bozza e scartato).
  Set<RifElemento> _selezioneIn(Snapshot s) => {
    for (final r in state.selezione)
      if (elementoDi(s, r) != null) r,
  };

  /// ✕: scarta la bozza e chiude il pannello.
  void chiudiStrumento() => state = state.copia(
    strumento: Strumento.nessuno,
    selezione: _selezioneIn(state.cronologia.current),
    bozza: () => null,
    deforma: false,
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
        strumento: Strumento.nessuno,
        selezione: _selezioneIn(state.cronologia.current),
        bozza: () => null,
        deforma: false,
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
      strumento: Strumento.nessuno,
      deforma: false,
      contagocce: false,
    );
    if (ricorda) _ricordaStileForma();
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
    );
    if (c.added) _programmaSalvataggio();
  }

  void avvisaNotice(List<Notice> notice) {
    if (notice.isEmpty) return;
    state = state.copia(
      avviso: Avviso(_prossimoAvviso++, notice: notice.first),
    );
  }

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
    );
    _programmaSalvataggio();
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

  void impostaDeforma(bool v) => state = state.copia(deforma: v);

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

  // ---------- Testo (Fase 5) ----------
  /// I testi selezionati, come nel documento che si vede.
  List<TextItem> get testiSelezionati =>
      state.elementiSelezionati.whereType<TextItem>().toList();

  /// Contesto del motore: misura dei testi (dipende dai caratteri) e contatori degli `uid`.
  EngineContext get contesto => _s.ctx;

  /// «＋ → Testo»: un testo nuovo al centro della pagina corrente, selezionato, con la tastiera pronta a scriverci.
  /// Nasce come **bozza**: con ✓ diventa un solo passo di cronologia (testo compreso), con ✕ non è mai esistito.
  void nuovoTesto() {
    final r = aggiungiTesto(
      state.snapshot,
      _s.ctx,
      pagina: state.pagina,
      carattere: Caratteri.predefinito,
    );
    state = state.copia(
      bozza: () => r.snapshot,
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
  void nuovaForma(String tipo) {
    final r = aggiungiForma(
      state.snapshot,
      _s.ctx,
      kind: tipo,
      pagina: state.pagina,
      stili: state.stiliForma,
    );
    _commit(
      r.snapshot,
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

  // ---------- Pagine (comandi minimi della Fase 3; il resto arriva con la Fase 6) ----------
  void aggiungiPagina() {
    final r = insertPageAfter(state.snapshot, state.pagina, _s.ctx);
    if (!r.applied) {
      avvisaNotice(r.notices);
      return;
    }
    _commit(
      r.snapshot,
      notice: r.notices,
      messaggio: MessaggioEditor.paginaAggiunta,
    );
    state = state.copia(pagina: state.pagina + 1);
  }

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
