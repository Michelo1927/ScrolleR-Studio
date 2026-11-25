# Roadmap di ScrolleR Studio (PC e telefono)

Scritta il 2026-11-24 dopo il rilascio della Sagoma (desktop 1.10.0, mobile 1.1.0).
Le scelte segnate come **decise** sono state prese con l'autore; le **idee** restano aperte.

## 0. Rilasciato: progetti Carosello e Reel (desktop 1.11.0, mobile 1.2.0)

**Due tipi di progetto** (campo `project_type` della tela: `carousel`, predefinito, o `reel`). I progetti di prima della divisione si aprono come caroselli. `PROJECT_VERSION` non cambia.

| | Carosello o foto | Reel |
|---|---|---|
| Pagine | 1–30 | una sola |
| Formato | libero | libero, proposto 9:16 |
| Video | al massimo 60 s (una slide Instagram) | al massimo 5 minuti |
| Guida «Zona sicura reel» | no | sulle pagine 9:16, con Guide acceso |

- **Scelta del tipo dentro la scelta del formato.** I formati sono divisi in due gruppi, «Carosello o foto» e «Reel»: una tessera sceglie insieme tipo e formato.
  - Carosello: tutti i formati (in cima 4:5, 3:4, 1:1) e il personalizzato. Reel: 9:16 «consigliato», 4:5, 1:1.
  - PC: finestra `NewProjectDialog` (`scrollr/dialogs.py`) a File → Nuovo progetto, carosello a sinistra con il campo Pagine e reel a destra. Gli stessi formati sono nella finestra di avvio (dal 2026-11-25), con i progetti recenti e le loro miniature.
  - Telefono: primo passo di «Nuovo progetto», carosello sopra e reel sotto.
- **Conversione** (un passo di Annulla).
  - PC: File → Converti in reel / in carosello. Telefono: Pagine → Formato.
  - In reel solo con una pagina: altrimenti un avviso chiede di togliere le altre.
  - In carosello i video più lunghi di 60 s usano il primo minuto, dall'inizio del taglio.
- **Durata dei video.** Con Inizio e Fine si sceglie la parte da mostrare: oltre il massimo l'altro estremo segue.
  - Il PC accorcia anche i video aggiunti, e quelli dei progetti vecchi all'apertura.
  - Il telefono accorcia solo con i cursori e nella conversione. Negli altri casi l'MP4 si ferma comunque al massimo, quindi esce identico.
- **Zona sicura.** 11% in alto, 16% in basso e 6% ai lati, più il rientro della colonna dei pulsanti: dal 61% dell'altezza in giù il margine destro è del 21%. Misure prese da una guida diffusa scelta dall'autore, non ufficiali di Meta. Non entra mai nell'esportazione.
  - Prima versione (1.11.0 / mobile 1.2.0): rettangolo con 14% in alto, 35% in basso e 6% ai lati.
  - Codice: `reel_safe_polygon` in `scrollr/canvas/scene.py`, `zonaSicuraReel` nel motore.
- **Riferimenti mobile** rigenerati con `genera_riferimenti.py`: cambiano solo `project_type` e alcuni semi casuali.

**Da provare sul Pixel 7:**
- nuovo reel, conversione nei due sensi, guida;
- esportazione di un video da 5 minuti: l'audio sta tutto in memoria, circa 53 MB per traccia.

## 1. Sottotitoli (deciso, prossimo lavoro)

Sottotitoli **scritti a mano** e sincronizzati dall'utente, prima sul PC e poi sul telefono. Niente trascrizione automatica: la prova S1 ([`prova-whisper-s1.md`](prova-whisper-s1.md)) ha dato testi da correggere quasi frase per frase, attese lunghe e modelli pesanti. Nessun modello, download o dipendenza nuova per la trascrizione.

### Scelte decise
- **Un blocco di sottotitoli per video.** Elemento `CaptionItem`, sottoclasse di `TextItem`, collegato al video: si sposta e si stila come un testo.
- **Frasi corte, una per riga**, al massimo due righe bilanciate a schermo. Ogni frase ha inizio, fine, testo e traduzione, nei tempi del video originale (non del taglio).
- **Formato pronto per un motore futuro.** Le frasi sono una lista semplice: un motore (whisper.cpp o Parakeet) potrà riempirla più avanti, anche con i tempi delle singole parole in un campo facoltativo. Ora quel campo non si scrive.
- **Nel progetto:** chiave `captions` accanto a `texts`, scritta solo se ci sono sottotitoli (il telefono 1.2.0 conserva le chiavi che non conosce). Ogni blocco ha lo stato di un testo più `video_uid`, `lang`, `tr_lang`, `wrap_w`, `tr_color`, `tr_size` (% della frase), `tr_italic`, `tr_show` e `phrases: [{start, end, text, tr, auto}]`, con `start`/`end` a `null` per le frasi senza tempi e `auto: true` (scritto solo se vero) per i tempi messi dall'app.
- **Si scrive tutto il testo, con il video che gira.** Una casella con tutto il testo, una frase per riga: quello incollato si divide da solo in frasi corte. Il video si avvia e si ferma anche mentre si scrive (Ctrl+Spazio), anche a 0,75× o 0,5×, e la riga della frase a schermo si colora. Niente sincronizzazione «dal vivo» a tasti (provata il 2026-11-25 e scartata dall'autore: poco intuitiva).
- **Tempi automatici dall'audio.** L'app trova i tratti di parlato dal volume e ci distribuisce le frasi in proporzione alla lunghezza, con gli stacchi spostati sulle pause vicine. Si ridistribuiscono a ogni modifica del testo. Una frase ritoccata a mano (bordi trascinati, tempo scritto nell'elenco, Invio) resta ferma e le automatiche si sistemano intorno; «Tempi dall'audio» rende di nuovo tutto automatico.
- **Ritocco.** Elenco delle frasi sincronizzato col video (clic = salta lì; modifica, dividi, unisci, aggiungi, elimina, traduzione) e striscia del tempo con la forma d'onda dell'audio. Le frasi sono blocchi (tratteggiati se automatici) a cui si trascinano i bordi, che si agganciano alle pause trovate dal volume.
- **Traduzione manuale.** Per ogni frase una seconda colonna (per esempio inglese), disegnata sotto la frase.
- **Stile predefinito**, come i reel sui social:
  - frase bianca, grassetto, ombra morbida scura (non un contorno spesso), centrata, due righe bilanciate;
  - traduzione sotto, più piccola, gialla e corsiva;
  - verso il centro-basso dentro la zona sicura reel sulle pagine 9:16.
- **Sulla tela** si vede la frase della copertina o quella del momento durante la riproduzione.
- **Nell'MP4 i sottotitoli sono dentro l'immagine**: il testo cambia fotogramma per fotogramma. Import ed export `.srt`.

### Passi
1. **S1 – Desktop** (fatto il 2026-11-25, da provare nell'app vera). Modello dati e `CaptionItem`, finestra «Sottotitoli» con testo, video, tempi automatici e ritocco, audio nella riproduzione, esportazione MP4, `.srt`.
   - Tasti. Anche mentre si scrive: Ctrl+Spazio avvia/ferma, Alt+←/→ indietro/avanti di 3 s, Esc = pausa. Fuori dalla casella: Spazio avvia/ferma, ←/→ un fotogramma, Invio/Shift+Invio = inizio/fine della frase scelta.
   - La finestra ha un Annulla suo; con «Fatto» le modifiche diventano un solo passo di Annulla del progetto.
   - Audio solo nella finestra (`QAudioSink` con il PCM di PyAV; 0,75× e 0,5× col filtro atempo). Sulla tela la riproduzione resta muta, ma la frase cambia. La build toglie il plugin FFmpeg di Qt Multimedia (~20 MB), che non serve.
2. **S2 – Telefono** (progettato e fatto il 2026-11-25, da provare sul Pixel 7). Stesso formato letto e scritto dal motore (`scrl_engine`), confrontato col desktop con i riferimenti; disegno in `disegno.dart` ed esportazione MP4. Scelte:
   - **Schermata intera «Sottotitoli»**, come il Ritaglio: ✕ / ✓ in alto e Annulla interno. Con ✓ le modifiche diventano un solo passo di Annulla del progetto; ✕ o «indietro» con modifiche chiedono conferma.
   - **Creazione.** Con un video selezionato, la sua striscia di strumenti ha la voce «Sottotitoli»: crea il blocco, se manca, e apre la schermata.
     - Il blocco si posiziona come `_place_new_caption` del desktop: centro-basso, 80% della pagina, dentro la zona sicura sulle pagine 9:16.
     - La striscia del blocco selezionato ha: Sottotitoli (riapre la schermata), Larghezza, Traduzione (mostra, colore, dimensione, corsivo), poi gli strumenti del testo (Carattere, Dimensione, Colore, Ombra, Disponi, Elimina).
   - **Due disposizioni, che seguono la tastiera.**
     - Tastiera aperta = si scrive: video piccolo in alto, con la frase del momento, e casella del testo sotto.
     - Tastiera chiusa = si ritocca: video più grande, striscia del tempo e comandi della frase scelta.
     - Schermata vuota: «Scrivi o incolla il testo, una frase per riga», con i pulsanti «Incolla» e «Importa .srt».
   - **Barra sopra la tastiera:** ↺ 3 s · ▶/⏸ grande · 3 s ↻ · velocità 1× / 0,75× / 0,5× (un tocco cambia).
     - Il video continua mentre si scrive e la riga della frase a schermo si colora.
     - Tocco sul video = avvia/ferma. Tocco su una riga a video fermo = salta all'inizio della frase.
   - **Striscia del tempo** come negli editor video per telefono:
     - la linea di lettura è fissa al centro e la striscia con la forma d'onda scorre sotto il dito;
     - pizzico = zoom, con circa 8 s visibili all'inizio;
     - tocco su un blocco = sceglie la frase e mostra due maniglie grandi (≥ 48 dp). Le maniglie si agganciano alle pause con uno scatto aptico e la frase diventa manuale.
     - Con una frase scelta: «Inizia qui» / «Finisci qui» (il bordo va sulla linea di lettura), «Dividi qui», «Unisci alla successiva», «Elimina».
     - Tocco sul tempo della frase (`0:12,4 – 0:15,1`): −0,1 s / +0,1 s per inizio e fine. Sostituisce i tempi scritti in cifre del desktop.
   - **Niente elenco a parte: la casella del testo fa da elenco.** Andare a capo divide o aggiunge una frase, cancellare l'a capo unisce, cancellare la riga elimina. Tempi e traduzioni restano con `merge_lines`.
   - **Traduzione:** interruttore Testo | Traduzione in alto. Ogni frase è una riga: sopra l'originale in grigio, sotto il campo della traduzione.
   - **SRT subito:** pulsante «SRT» nella barra in alto, con un foglio dal basso che offre «Importa .srt» e «Condividi .srt». Importare sopra un testo esistente chiede conferma.
   - **Audio nativo nel plugin `scrl_video`, senza pacchetti nuovi.**
     - Il PCM viene da `LettoreAudio.kt` e va a un `AudioTrack`; 0,75× e 0,5× con `setPlaybackParams`, che non cambia il tono.
     - L'audio fa da orologio e i fotogrammi lo seguono.
     - Lettura in sottofondo («Lettura dell'audio…»): si scrive subito e i tempi arrivano quando l'audio è pronto.
     - Video senza audio: avviso, e i tempi si distribuiscono su tutto il taglio.
   - **Motore e prove.** `captions.py` si porta in `scrl_engine` così com'è, con le prove scritte prima.
     - `genera_riferimenti.py` si estende con: disegno di una frase, due righe bilanciate, `retime` sulle stesse pause, fotogrammi dell'MP4.
     - Un progetto con `captions` deve uscire identico dopo lettura e riscrittura.
   - **Solo Android**, come le altre funzioni nuove: su iOS la voce non compare.
3. **S3 – Prova sul Pixel 7 e rilascio** (desktop 1.12.0, mobile 1.3.0).

## 2. Musica di sottofondo (deciso, dopo i sottotitoli)

Una traccia audio per la pagina video: si sceglie un file (mp3, m4a, wav).
- Regolazioni: taglio, volume, dissolvenza in entrata e in uscita.
- Si mescola con l'audio dei video non muti, con un volume per ciascuno.
- Lettura con PyAV sul PC e con `MediaExtractor` sul telefono, già usati per l'audio dei video.

## 3. Idee aperte (da decidere)

- **Linea del tempo** (clip una dopo l'altra). Più avanti, senza posto fisso. È un lavoro grande.
- **Sagoma automatica** con l'AI: propone i punti, l'utente li corregge.
- **Rifinitura grafica mobile**: `docs/brief-grafico-app-mobile.md`.
- **Sottotitoli automatici** (whisper.cpp o Parakeet), vedi [`prova-whisper-s1.md`](prova-whisper-s1.md).
  - Il motore riempirebbe le frasi dei sottotitoli manuali, con i tempi delle parole nel campo facoltativo.
  - Dalla prova: small 30–80 s per minuto di video sul PC, turbo ~100 s, Parakeet ~11 s ma 1,2 GB di RAM e niente punteggiatura; testo da correggere quasi frase per frase.
  - Modello da scaricare alla prima trascrizione da una release dedicata (per esempio `modelli-whisper-1`, mai `v*` né `mobile-v*`, mai «latest»), non nell'installer.
  - Restano da fare: download con avanzamento e Annulla, build PyInstaller su Windows e Mac, motore sul telefono (whisper.cpp nel plugin `scrl_video`, audio a 16 kHz da `LettoreAudio.kt`).

## 4. Fermo

- **iOS.** Compila in CI (mobile 1.0.1 e 1.0.2) ma non è mai stato provato su un iPhone. Le funzioni nuove sono solo per Android e PC.
- Il job `ios` sui tag a volte viene annullato perché GitHub non assegna una macchina macOS. Si rilancia con «Re-run failed jobs».
