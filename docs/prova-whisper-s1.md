# Prova S1 – motore di trascrizione whisper.cpp (PC)

Passo S1 della [roadmap](roadmap.md) (sezione 1 «Sottotitoli automatici»). Prova fatta **fuori dall'app** il 2026-11-25: nessuna modifica a `scrollr/`, `mobile/`, `packaging/`, `main.py` né al `.venv` del progetto.

## In breve

- **small da solo non basta a fare buoni sottotitoli su questo video**: prende il senso ma sbaglia molte parole. **turbo** è chiaramente migliore (frasi intere, punteggiatura, tempi fini), ma su questo PC è lento: circa **100 s per minuto di audio**.
- **I tempi sono 3–5 volte le stime della roadmap.** small: **28–80 s per minuto** di audio (non 10–20 s). Quanto dipende da quante volte whisper deve rifare la decodifica sull'audio difficile.
- **base è inutilizzabile in italiano** su questo video (testo senza senso). Sul telefono quindi serve **small**, non base.
- **Il VAD integrato di whisper.cpp qui peggiora le cose**: più frasi ripetute, e i tempi delle parole restano sbagliati (non vengono riportati sulla linea del tempo originale). Per ora va lasciato spento.
- **Due impostazioni da usare nell'app:** flash attention spenta, così funziona il DTW e i tempi delle parole sono i migliori, e `OPENBLAS_NUM_THREADS=1` prima di importare numpy (risparmia ~480 MB di memoria prenotata).
- Le due anteprime MP4 (small e turbo) le hai ricevute: giudica tu il testo.
- **Aggiunta (stesso giorno): Parakeet TDT 0.6B v3** (NVIDIA, con sherpa-onnx; vedi la sezione in fondo).
  - È **7–9 volte più veloce** di small e turbo (~11 s per minuto di audio) e **non inventa mai**: niente ripetizioni, niente testo nei silenzi.
  - In cambio **salta pezzi**, sbaglia parole anche nei tratti chiari e su questo video **non mette punteggiatura né maiuscole**.
  - Non traduce e usa più memoria di turbo (~1,2 GB).

## Ambiente

| | |
|---|---|
| PC | i5-13500H (4 P-core + 8 E-core, 16 thread), 16 GB RAM, in carica, profilo «Legion Balance Mode» |
| Motore | `pywhispercpp` 1.5.1 (PyPI, ruota cp313 win_amd64) con whisper.cpp **1.8.5** dentro; build CPU AVX2/FMA + OpenMP, senza BLAS né GPU |
| Python | venv nuovo e separato (3.13.14); dipendenze: numpy 2.5.5, requests, tqdm, platformdirs |
| Modelli | `ggml-base-q5_1.bin` (59 707 625 B), `ggml-small-q5_1.bin` (190 085 487 B), `ggml-large-v3-turbo-q5_0.bin` (574 041 195 B), VAD `ggml-silero-v6.2.0.bin` (885 098 B, repo `ggml-org/whisper-vad`); sha256 controllati con quelli di Hugging Face |
| Video | 45,53 s, parlato in italiano all'aperto, due voci; da 43,2 s c'è il cartello finale «INSIEME» senza parlato |
| Audio | estratto con PyAV del `.venv` → WAV 16 kHz mono int16 → array float32 passato a pywhispercpp (niente ffmpeg) |

Ogni prova gira in un **processo nuovo**, una alla volta, senza altri lavori pesanti. Tutta la serie è stata eseguita **due volte** (r1, r2). Le due ripetizioni danno sempre un testo identico: con gli stessi parametri whisper.cpp è deterministico.

Il **riferimento** per la qualità sono i sottotitoli già bruciati nel video, letti dai fotogrammi. Sono montati dall'autore, quindi riassunti e non parola per parola, e tra 33 e 41 s c'è parlato che non hanno. Il WER che ne viene è **approssimato** e serve solo a confrontare i modelli tra loro.

## Parametri esposti da pywhispercpp 1.5.1

Ci sono tutti quelli che servono:
- `language` («it», «auto»), `n_threads`;
- `token_timestamps`, `max_len`, `split_on_word`;
- `temperature_inc`, `no_speech_thold`, `suppress_nst`, `initial_prompt` e gli altri di `whisper_full_params`;
- VAD: `vad`, `vad_model_path` e anche `vad_params` (threshold, min_speech/silence, pad, …). Le funzioni `whisper_vad_*` si possono anche chiamare a parte;
- DTW: si passa con `context_params` (`dtw_token_timestamps`, `dtw_aheads_preset`, `flash_attn`).

L'API di alto livello (`Model.transcribe`) restituisce solo le frasi. I tempi delle parole si leggono dai token con `whisper_full_get_token_data` (campi `t0`, `t1`, `t_dtw`). I byte dei token vanno uniti prima di decodificarli, perché le lettere accentate possono stare a cavallo di due token.

## Tabella delle prove

Tempo = sola trascrizione (r1 / r2), senza caricare il modello. «Al minuto» = (caricamento + trascrizione r2) ÷ durata × 60.
Memoria: **WS picco** = working set di picco, cioè la RAM davvero usata. **Privata picco** = memoria impegnata di picco (commit): comprende anche quella prenotata e non toccata.
Tutte con `OPENBLAS_NUM_THREADS=1` (vedi Problemi).

### Serie principale (flash attention accesa, cioè il default di whisper.cpp 1.8.5)

| Modello | Lingua | VAD | Thread | Caricam. s | Trascrizione s | Al minuto s | WS picco MB | Privata picco MB | Frasi |
|---|---|---|---|---|---|---|---|---|---|
| base | it | no | 4 | 0,30 | 18,2 / 17,9 | 24,0 | 297 | 749 | 5 |
| base | it | no | 8 | 0,27 | 15,0 / 14,1 | 18,9 | 301 | 750 | 5 |
| base | it | sì | 8 | 0,30 | 8,1 / 7,8 | 10,7 | 339 | 831 | 23 |
| small | it | no | 4 | 0,64 | 80,7 / 80,7 | 107,2 | 557 | 1010 | 2 |
| small | it | no | 8 | 0,63 | 64,5 / 60,6 | 80,7 | 559 | 1012 | 2 |
| small | it | no | 16 | 0,67 | 68,7 / 67,4 | 89,7 | 559 | 1013 | 2 |
| small | auto → **it** (p 0,965) | no | 8 | 0,64 | 70,3 / 68,6 | 91,2 | 555 | 1012 | 2 |
| small | it | sì | 4 | 0,68 | 27,8 / 29,3 | 39,5 | 482 | 982 | 15 |
| small | it | sì | 8 | 0,65 | 40,4 / 37,9 | 50,8 | 596 | 1098 | 13 |
| turbo | it | no | 4 | 1,68 | 96,6 / 110,1 | 147,3 | 854 | 1277 | 20 |
| turbo | it | no | 8 | 1,63 | 73,4 / 74,6 | 100,5 | 855 | 1277 | 20 |
| turbo | it | sì | 8 | 1,66 | 72,1 / 72,2 | 97,3 | 832 | 1364 | 5 |

Nella serie c'erano anche small e turbo «con DTW». Il DTW però **non era attivo**, perché flash attention lo spegne senza avvisare (vedi Problemi): i numeri sono uguali alle righe senza DTW e non li riporto.

### Prove diagnostiche (una esecuzione ciascuna, it, 8 thread, senza VAD salvo dove scritto)

| Prova | Caricam. s | Trascrizione s | Al minuto s | WS picco MB | Privata picco MB | Frasi | Ripieghi |
|---|---|---|---|---|---|---|---|
| small, flash **spenta** | 0,61 | 21,1 | 28,6 | 607 | 1033 | 15 | 0 |
| small, flash spenta + **DTW** | 0,66 | 23,2 | 31,4 | 652 | 1237 | 15 | 0 |
| small, flash spenta + DTW + VAD | 0,61 | 24,1 | 32,6 | 649 | 1323 | 14 | 0 |
| small, flash accesa, senza ripieghi (`temperature_inc=0`) | 0,59 | 25,3 | 34,1 | 449 | 896 | 6 | 0 |
| small, flash accesa, VAD, senza ripieghi | 0,62 | 31,1 | 41,8 | 492 | 983 | 14 | 0 |
| base, flash accesa, senza ripieghi | 0,28 | 5,4 | 7,5 | 264 | 702 | 13 | 0 |
| turbo, flash accesa, senza ripieghi | 1,58 | 71,0 | 95,6 | 854 | 1277 | 20 | 0 |
| turbo, flash spenta + **DTW** | 1,60 | 86,4 | 116,0 | 1121 | 1675 | 24 | 0 |

### Dove va il tempo (tempi interni di whisper.cpp, `whisper_print_timings`)

| | encoder | decoder + decodifica a lotti | ripieghi |
|---|---|---|---|
| small, flash accesa | 12,1 s (2 finestre da 30 s) | 10,7 + **31,9 s** | 3 per logprob, 1 per entropia |
| small, flash spenta | 15,1 s | 4,4 + 0,04 s | 0 |
| turbo, flash accesa | **65,9 s** (33 s a finestra) | 3,7 s | 0 |

- **small**: il tempo dipende soprattutto dai **ripieghi di temperatura**. Quando una finestra viene male, whisper la rifà con 5 candidati, e il tempo triplica. Su questo audio flash accesa ne fa scattare 4 e flash spenta nessuno. È una differenza numerica che cambia il percorso della decodifica, quindi **non** si può dire che flash spenta eviti i ripieghi in generale.
- **turbo**: il tempo è tutto **encoder** (32 strati, CPU senza BLAS). Il decoder è velocissimo. Spegnere i ripieghi non cambia nulla, perché qui non ne fa.
- **Thread**: 8 è il valore giusto. 4 è più lento del 25–45%, 16 è peggio di 8. Attenzione: **cambiare il numero di thread (o flash) cambia il testo** (con il VAD, small a 4 e a 8 thread dà frasi diverse). Lo stesso modello non garantisce lo stesso risultato su PC e telefono.
- **Lingua automatica**: riconosce italiano con p = 0,965 e dà lo stesso testo di «it» forzato, ma costa una passata in più di encoder (circa +8 s con small). Conviene proporre «it» e lasciare «automatica» come scelta.
- **Caricamento**: trascurabile (0,3 / 0,65 / 1,65 s a file già in cache).
- **Memoria reale** (WS): base ~0,3 GB, small ~0,55–0,65 GB, turbo ~0,85 GB (1,1 GB con DTW). Combacia con la stima della roadmap per small.

## Testi completi

Riferimento (sottotitoli dell'autore, riassunti):

> Che ogni zona, ogni quartiere... Serve a sensibilizzare, esatto. Se ogni zona, ogni quartiere avesse il proprio presidio di persone che, pur non conoscendosi, si incontrano... e fanno amicizia pulendo. Sarebbe il futuro. Immagina... Sai quante volte trovi palazzi con 20-30 persone e nessuno si conosce? Vai dal vicino di casa e gli dici: «Senti, puliamo 10 metri sotto il palazzo.» È un po' un'utopia. Utopia, certo, però piano piano... Oggi il vicino di casa non ti chiede neanche il sale. È la verità. Grazie!

Come leggere i testi qui sotto: in **grassetto** le parole diverse dal riferimento o in più, ~~barrate~~ quelle del riferimento che mancano. L'allineamento è automatico, parola per parola: a volte segna in grassetto una frase giusta che il riferimento ha una volta sola. Il WER è indicativo, perché il riferimento è riassunto e salta il tratto 33–41 s.

#### base (it, 8 thread, flash accesa, senza VAD) – WER ≈ 91%
> **è** **un'izona,** **un'icqua** **sia** **la** **sezz'io** **di** **creizzare** **la** **buona.** **è** **un'izona,** **un'icqua** **sia** **di** **avessi,** **è** proprio presidio di persone che ~~pur~~ non ~~conoscendosi,~~ **conosciando** **se** **sono** **cuocere.** **Vanno** **qui?** **e** **qui** **sono?** **C'è** **qui,** **sono** **i** **tuoi,** **sono** **i** **tuoi.** **Sì,** **ma** **ti?** **C'è** **la** **quantità** **volte** **trovi** di ~~casa~~ ~~e~~ ~~gli~~ ~~dici:~~ ~~«Senti,~~ ~~puliamo~~ ~~10~~ ~~metri~~ ~~sotto~~ ~~il~~ ~~palazzo.»~~ **balazzi,** **come** **20,** **30** **persone,** **nessuno** **si** **conosce.** **Non** **si** **al** **bicino** di casa, ~~non~~ **gli** **i** **disatti,** **vogliamo** **10** **metri** **sotto** **il** **piacere.**

Si ferma a 34 s: perde l'ultimo terzo.

#### small (it, 8 thread, flash accesa, senza VAD) – WER ≈ 85%
> **e** ogni zona, ogni quartiere, **serva** **sensibilizzata** a **quella...** **serva** **sensibilizzata** **ad** ogni zona, ogni quartiere, avesse il proprio presidio di persone che **non** **conosciano** **essi** **sul** **culto,** **ma** **non** **mi** **sento** **che** **pulisco...** **c'è** **questo...** **immagino...** **cioè** **stai** quante volte trovi **i** **palazzi,** 20-30 persone, ~~e~~ nessuno si conosce? **Sì,** **io** **ho** **visto,** **adesso** **sempre** **con** **come** **vuoi.** **Pussi** **al** vicino di casa, ~~e~~ gli **10,** senti, puliamo 10 metri sotto il **calcio,** **questo** palazzo. **Facile...** È un po' **un** **utopia.** Utopia, certo, però... **All'albicino** **di** **casa,** **ve** **lo** **diamo** **un** **po'** **che** **del** **sale.** **Grazie,** **grazie.** **Adesso** **la** **vedita.** **Grazie.** Non **mi** **riponisco** **più** **che** **del** sale... **Però,** **che** **non** è **vero.** **Grazie.** **Grazie.** Grazie.

Solo **2 frasi**: una da 0 a 19,4 s e una da 19,4 a 42,9 s. Inutilizzabili come sottotitoli senza spezzarle con i tempi delle parole.

#### small (it, 8 thread, flash spenta, senza VAD) – WER ≈ 78% – *usato per l'anteprima*
> **e** ogni zona, ogni quartiere, **serva** **sensibilizzare** **la** **pulizia** **serva** sensibilizzare **la** **risa,** ogni zona, ogni quartiere, avesse ~~il~~ proprio presidio di persone che ~~pur~~ non **conosciano** **essi** **sul** **culto** fanno, **mi** **c'è** **un** **c\*\*\*o** **che** **pulisco,** **c'è** **questo...** **immagino,** **cioè** **stai** quante volte trovi **i** palazzi, **come** 20-30 persone, e nessuno si conosce? **adesso** **sempre** **con** **cui...** **Pussi** **al** vicino di casa, ~~e~~ gli ~~dici:~~ **decisanti,** puliamo 10 metri sotto il palazzo è un po' un'utopia **è** **un'utopia,** certo, però... **Grazie,** **ragazzi,** **noi** **abbiamo** **un** **po'** **che** **da** **uscire,** **è** **una** **vita...** **...ma** **io** non **ho** **più** **che** **da** **uscire,** **però...** **...ma** **io** **lo** **diamo...** **...ma** **se** **lo** **trovi...** Grazie...

#### turbo (it, 8 thread, flash accesa, senza VAD) – WER ≈ 69%
> **E** ogni zona, ogni quartiere... **Ma** serve a sensibilizzare **la** **puregata.** **Serve** **a** **sensibilizzare,** **esatto.** Ogni zona, ogni quartiere avesse il proprio presidio di persone che ~~pur~~ non **conoscevano** **se** **si** **infolprano.** Fanno ~~amicizia~~ **vicini** **e** **puliscono.** **Immagini.** **Cioè** sai quante volte trovi **i** palazzi con 20-30 persone e nessuno si conosce? **Io,** **adesso** **sempre** **più** **comune.** **Tu** **sei** **al** vicino di casa e gli dici, senti, puliamo 10 metri sotto il palazzo. **Facile.** È un po' un'utopia. **Un'utopia,** certo, però... ~~piano~~ ~~piano...~~ ~~Oggi~~ **Al** vicino di casa, **oggi,** **noi** **abbiamo** **un** **po'** **che** **restate.** È la verità. **Piano** **piano.** **Non** **abbiamo** **un** **po'** **che** **restate.** **Però,** **prima** **o** **prima.** **Però,** **basta** **di** **prendere.** Grazie. **Buon** **gusto.**

#### turbo (it, 8 thread, flash spenta + DTW, senza VAD) – WER ≈ 80% – *usato per l'anteprima*
> **E** ogni zona, ogni quartiere... **Ma** serve a sensibilizzare **la** **puregata.** **Serve** **a** **sensibilizzare,** **esatto.** Ogni zona, ogni quartiere avesse il proprio presidio di persone che **non** **conoscevano** **se** si **infolprano.** **Fanno** **vicini** **a** e **puliscono.** **C'è** **questo.** **Oh,** **tu.** **Immagini.** **Cioè** sai quante volte trovi **i** palazzi con 20-30 persone e nessuno si conosce? **Io,** **proprio.** **Adesso** **è** **sempre** **più** **comune.** **Tu** **sei** **al** vicino di casa e gli dici, senti, puliamo 10 metri **sotto** **il** **palazzo.** Sotto il palazzo. **Facile.** È un po' un'utopia. **Un'utopia,** certo, però... **All'utopia,** **non** **ci** **vogliamo** **più** **che** **del** **sale.** **E'** **la** **verità.** Piano piano. **Non** **ci** **vogliamo** **più** **che** **del** **sale.** **Però,** **più** **o** **più** **o** **più.** **Però,** **basta** **di** **prendere.** Grazie. **Buon** **gusto.**

Il WER è più alto di quello con flash accesa soprattutto perché trascrive anche brevi interventi della seconda voce («C'è questo», «Sotto il palazzo»), che il riferimento non ha. Ci sono anche un «Oh, tu.» in un tratto senza parlato e un asterisco da censura («Fanno vicini a \*\*\* e puliscono»).

<details>
<summary>Varianti con il VAD (base, small 4/8 thread, small flash spenta, turbo)</summary>

#### base (VAD) – WER ≈ 114%
> **e** ogni zona, ogni **quale** **è?** **Se** **vassa** **il** **zanzia** **di** **direzza** **alla** **pubblica** **Serva** il **zanzia** **di** **direzza** **alla** **pubblica** **D'un** **zanzia** **di** **direzza** **alla** **pubblica** **D'un** **zanzia** **di** **direzza** **alla** **pubblica** **E'** proprio **per** **i** **siti** **o** di persone **E'** **non** **conosciando** **se** si **è** **fuori** **quando** **mi** **ci** **sono?** **E'** **qui?** **C'è** **qui?** **C'è** **qui?** **C'è** **la** **quantità** volte trovi **i** **balazzi,** **come** **20** **per** persone e nessuno si ~~conosce?~~ **conosci** **Viene** **voluto?** **Viene** **su** **sempre** **con** **cui?** **Sì** **al** **vicino** **di** **casa** **e** **i** **vicini** **antichi,** **voliamo** **10** **cm** **sotto** **il** **piatto** **Tutta** **la...** **Va,** **è** **un** **po'** **un'uto** **più** **Allie,** **è** **certo,** **però...** **Vi** **ho** **visto?** Grazie

#### small (VAD, 8 thread) – WER ≈ 79%
> **e** ogni zona, ogni **quattiere,** **serva** **sensibilizzata** **per** **una** **cosa** **serva** **sensibilizzarizzata,** ogni zona, ogni ~~quartiere~~ **quattiere,** **havesse** proprio presidio di persone che **non** **conosciano** **e** **si** **sono** **fatti** **"quando** non **mi** **ce** **n'è** **un** **c\*\*\*o** **che** **pulisco"** **"cio'** **questa** **t\*\*\*a** **di** **immagini"** **cioè** **stai** **quanti** volte trovi **i** palazzi, **come** 20-30 persone, ~~e~~ nessuno si conosce **"di** **nuovo,** **adesso** **sempre** **con** **come?"** **"siamo** **al** vicino di casa, ~~e~~ gli ~~dici:~~ **decisanti,** puliamo 10 metri sotto il palazzo" **"di** **faccia"** **"e'** un po' un'utopia" "utopia, certo, però..." ~~piano~~ ~~piano...~~ ~~Oggi~~ ~~il~~ **"di** **faccia,** **noi** **li** **dobbiamo** **fare** **un** **po'** **di** **testare"** **"di** **faccia,** grazie"

#### small (VAD, 4 thread) – WER ≈ 94%
Uguale a 8 thread fino a «però...», poi «"di faccia, noi ci dobbiamo un po' che le stavano"» **ripetuto 3 volte** (34,6–41,4 s).

#### small (VAD, flash spenta + DTW) – WER ≈ 100%
Simile fino a «certo, però...», poi «grazie, grazie, dobbiamo vedere un po' che deliziale, vi dico da...» **ripetuto 4 volte** (29,3–41,4 s).

#### turbo (VAD) – WER ≈ 52%
> ~~Che~~ ogni zona ogni quartiere serve a sensibilizzare ~~esatto.~~ ~~Se~~ ogni zona ogni quartiere avesse il proprio presidio di persone che ~~pur~~ non **conoscevano** **se** **si** **fulprano** fanno ~~amicizia~~ **vicino** **e** **puliscono** **immagini** **cioè** sai quante volte trovi **i** palazzi **come** **20** **30** **persone** nessuno si conosce **adesso** **sempre** **più** **comune** **tu** **sei** **al** vicino di casa ~~e~~ gli dici senti puliamo 10 metri sotto il palazzo è un po un'utopia ~~Utopia,~~ certo però ~~piano~~ ~~piano...~~ ~~Oggi~~ ~~il~~ ~~vicino~~ ~~di~~ ~~casa~~ ~~non~~ ~~ti~~ ~~chiede~~ ~~neanche~~ ~~il~~ ~~sale.~~ ~~È~~ ~~la~~ ~~verità.~~ grazie

Il WER basso è ingannevole: **perde tutta la punteggiatura e le maiuscole**, fa solo 5 frasi lunghe (l'ultima è «grazie» da 29,1 a 42,2 s) e **salta** tutto il tratto 29–41 s.

</details>

Cosa si vede:
- **base** non è utilizzabile: parole inventate («un'izona, un'icqua», «zanzia di direzza»).
- **small** coglie il senso delle frasi chiare (0–29 s) ma sbaglia molte parole («conosciano», «Pussi al vicino di casa, gli decisanti»). Inventa nel tratto confuso 29–41 s e mette asterischi da censura (`c***o`, `t***a`), un'abitudine presa dai sottotitoli su cui è stato addestrato.
- **turbo** dà frasi intere e leggibili, con punteggiatura e maiuscole. Nelle parti chiare sbaglia poco («infolprano» al posto di «si incontrano», «Immagini» al posto di «Immagina»).
- Nessun modello capisce bene il tratto 29–41 s, dove la seconda voce si sovrappone: è la parte difficile del video.

## Tempi delle parole

Unico riferimento oggettivo senza ascoltare: le parole dovrebbero cominciare dentro i tratti di parlato trovati dal VAD (tolleranza 0,2 s).

| Prova | Parole | Durata nulla | < 50 ms | > 1,5 s | Sovrapposte / all'indietro | Inizio dentro il parlato |
|---|---|---|---|---|---|---|
| base, senza VAD | 72 | 0 | 1 | 3 | 0 / 0 | 86% |
| small, flash accesa | 128 | 0 | 11 | 1 | 0 / 0 | 90% |
| small, flash spenta, `t0` dei token | 107 | 9 | 2 | 3 | 0 / 0 | 89% |
| small, flash spenta, **DTW** | 107 | – | – | – | 0 all'indietro | **98%** |
| turbo, flash accesa | 112 | 12 | 6 | 0 | 0 / 0 | 95% |
| turbo, flash spenta, `t0` dei token | 123 | 15 | 6 | 0 | 0 / 0 | 91% |
| turbo, flash spenta, **DTW** | 123 | – | – | – | 0 all'indietro | **98%** |

- **Tempi dei token** (`token_timestamps`): mai sovrapposti né all'indietro. Però il 10–12% delle parole ha **durata nulla** (attaccata alla parola dopo), e qualche parola dura 1,5–2 s perché si prende la pausa che la precede («immagino,» 2,1 s).
- **DTW**: un solo istante per token (niente fine: la fine di una parola è l'inizio della successiva). In media differisce di 0,32 s dai tempi dei token (massimo 1,45 s) e cade nel parlato nel 98% dei casi. È il migliore e **costa poco**: +10% di tempo con small, +45 MB di RAM.
- **Tempi delle frasi di small/base**: cadono a **secondi interi** (0,000 → 3,000 → 7,000…), perché il modello piccolo emette timestamp grossolani. turbo invece ha passi da 20 ms. Per i sottotitoli le frasi corte vanno quindi costruite **dai tempi delle parole**, non dalle frasi di whisper (è quello che fa lo script delle anteprime).
- **Con il VAD i tempi delle parole sono sbagliati**: whisper.cpp 1.8.5 riporta sulla linea del tempo originale le frasi ma non i token, né `t0`/`t1` né il DTW. Le parole restano sulla linea «compressa» (solo parlato): 53–83 parole cadono fuori dalla loro frase e l'ultima parola finisce a 35 s su 42. Rimappandole con la tabella del VAD (che whisper scrive solo nel log) tornano tutte dentro la loro frase (0 fuori). Quindi la correzione funziona, ma pywhispercpp **non espone la tabella**: se servirà il VAD, l'app dovrà farlo da sé (vedi raccomandazioni).

## Allucinazioni

| | senza VAD | con VAD |
|---|---|---|
| «Sottotitoli creati dalla comunità Amara.org», «Iscriviti», «Grazie per la visione» e simili | **mai** | **mai** |
| Testo dopo la fine del parlato (42,24 s) o sul cartello finale 43–45,5 s | **mai** | **mai** |
| Frasi ripetute | small flash accesa: «Grazie.» ×5 in coda; small senza ripieghi: «fanno, fanno, …» ×50 (ciclo) | base: «zanzia di direzza alla pubblica» ×4 e «C'è qui?» ×3; small 4 thread: frase ×3; small flash spenta: frase ×4 |
| Frasi in tratti senza parlato | turbo flash spenta: «Oh, tu.» (12,4–13,3 s, il VAD lì non sente parlato) | – (il VAD li toglie) |
| Testo inventato nel tratto confuso 29–41 s | tutti, meno turbo | tutti; turbo salta il tratto |
| Stranezze di formato | `c***o`, `t***a` (small) | virgolette in ogni frase (small), niente punteggiatura né maiuscole (turbo) |

Spegnere i ripieghi (`temperature_inc=0`) è peggio: small entra nel classico ciclo di ripetizione. I ripieghi vanno lasciati.

**VAD spento e acceso a confronto:** su questo video il VAD toglie il rischio di testo nei silenzi, che però qui non c'era. In cambio aumenta le **ripetizioni** (whisper riceve il parlato incollato senza pause e perde il filo nei pezzi corti), con turbo toglie la punteggiatura e un'intera frase, e rompe i tempi delle parole. Risparmia tempo con small/base (−35–65%) ma non con turbo, perché il parlato (35,9 s) occupa comunque 2 finestre da 30 s. **Per ora non conviene.** Andrà riprovato su un video con musica o silenzi lunghi (un reel da 5 minuti), fatto a modo nostro (vedi sotto).

## Raccomandazioni

### PC, di serie: **small q5_1**
- Impostazioni: `language="it"` (con «Automatica» come scelta), `n_threads = min(8, os.cpu_count())`, `token_timestamps=True`, `context_params={"flash_attn": False, "dtw_token_timestamps": True, "dtw_aheads_preset": WHISPER_AHEADS_SMALL}`, **VAD spento**, ripieghi lasciati al default.
- Cosa aspettarsi su questo PC: **30–80 s per minuto di video** (30 se non scattano ripieghi, fino a 80 sull'audio difficile), ~0,65 GB di RAM, 190 MB di download.
- Perché small: è l'unico compromesso realistico tra qualità e attesa. Su questo video però il testo è **appena sufficiente**: andrà corretto a mano quasi frase per frase. Il giudizio finale spetta a te guardando l'anteprima. Prima di chiudere la scelta proverei **un secondo video più pulito** (una voce, senza rumore), per vedere se small va bene almeno sul caso tipico.

### PC, «Qualità alta»: **large-v3-turbo q5_0**
- Stesse impostazioni con `WHISPER_AHEADS_LARGE_V3_TURBO`.
- Cosa aspettarsi: **~100 s per minuto** di video (~115 con DTW), quindi un reel da 5 minuti richiede circa 8–10 minuti. Servono ~0,85–1,1 GB di RAM e 574 MB di download.
- Perché: testo chiaramente migliore, con frasi intere, punteggiatura e tempi fini. Va bene come scelta esplicita, con avanzamento e Annulla. Il collo di bottiglia è l'encoder sulla CPU, e su un PC più vecchio sarà proporzionalmente più lento.

### Telefono: **small**, non base
- base dà testo senza senso in italiano anche sul PC, quindi non va bene nemmeno come «veloce».
- Stima da confermare in S4 (Pixel 7, 4 thread NEON): encoder di small 2–3 volte più lento di questo PC, quindi **circa 1–2,5 minuti per minuto di video**. È più della stima della roadmap (40–90 s), perché anche le misure sul PC sono 3–5 volte le stime. La RAM (~0,65 GB) va bene su 8 GB, ma la trascrizione deve stare in primo piano o in un servizio in primo piano, altrimenti Android la può chiudere.
- «Stesso modello, stesso risultato» vale solo in parte: già sul PC il testo cambia con il numero di thread e con flash attention. Ci si può aspettare un risultato **simile**, non identico.

### Se servirà il VAD
Va fatto a modo nostro: le funzioni `whisper_vad_*` sono esposte. Si trovano i tratti di parlato, si trascrive ogni tratto (o gruppi di tratti) con il suo offset e si sommano i tempi. Così i tempi delle parole restano giusti e si evita di incollare il parlato.

### Numeri da aggiornare nella roadmap
Non ho modificato la roadmap; dimmi tu se aggiornarla.
- PC, 60 s di video con small: **30–80 s** (non 10–20).
- Turbo: ~100 s.
- Telefono: da misurare.

## Problemi incontrati e cosa serve per la build

1. **numpy e OpenBLAS**: importando numpy su una CPU a 16 thread, OpenBLAS **prenota ~480 MB** di memoria privata (non usata, ma conta nel commit). Prima di importare numpy va impostato `os.environ["OPENBLAS_NUM_THREADS"] = "1"` (numpy qui serve solo a passare l'array). In tutte le prove della tabella è impostato.
2. **flash attention spegne il DTW senza dirlo**: in whisper.cpp 1.8.5 `flash_attn` è acceso di default e il DTW viene disattivato (`dtw = 0` nel log, `t_dtw = -1`). Va passato `flash_attn=False`. Sul nostro audio flash spenta è stata anche più veloce (nessun ripiego), ma con l'encoder un po' più lento (7,5 contro 6,0 s a finestra).
3. **VAD integrato**: i tempi delle parole non vengono rimappati (vedi sopra).
4. **Frasi di small a secondi interi**: le frasi corte vanno costruite dai tempi delle parole.
5. **Dipendenze**:
   - `pywhispercpp.model` importa `requests`, `tqdm`, `platformdirs`, che servono solo al suo download dei modelli. Usando direttamente il modulo nativo `_pywhispercpp` (come faccio già per token e DTW) basta **numpy**.
   - Il `.venv` del progetto oggi **non ha numpy**: è peso nuovo, ~55 MB installato (34 MB numpy + 21 MB OpenBLAS), più di quanto stimato nella roadmap (+25–35 MB installata). Il resto: pywhispercpp 0,4 MB + DLL whisper/ggml/msvcp/vcomp ~3,3 MB.
   - Se il peso preoccupa, un'alternativa è un piccolo involucro `ctypes` sull'API C di `whisper.dll` (si passa un `array('f')`, senza numpy).
6. **PyInstaller (Windows)**:
   - La ruota è fatta con delvewheel. Le DLL hanno nomi con hash (`whisper-<hash>.dll`, `ggml-*.dll`, `msvcp140-<hash>.dll`, `vcomp140-<hash>.dll`) e stanno nella **radice di site-packages**, non nel pacchetto. Il `__init__` di pywhispercpp aggiunge quella cartella con `os.add_dll_directory`.
   - PyInstaller di solito trova le DLL dipendenti di un `.pyd`. Va però **verificato in S3** che finiscano accanto a `_pywhispercpp*.pyd` in `_internal`. Se usiamo `_pywhispercpp` senza importare `pywhispercpp`, il patch di delvewheel non gira: le DLL devono stare nella stessa cartella del `.pyd`, o va chiamato `os.add_dll_directory` noi.
7. **Mac**: per cp313 c'è solo la ruota **macosx arm64**. Va bene con `macos-latest` della CI (arm64), ma i Mac Intel resterebbero esclusi.
8. **CPU vecchie**: la DLL `ggml-cpu` è compilata con AVX2/FMA, quindi su una CPU senza AVX2 il processo si chiuderebbe di colpo (istruzione illegale). Serve un controllo prima di caricare, oppure la trascrizione in un **processo separato**: protegge anche l'app da crash del motore e libera tutta la memoria alla fine.
9. **App senza console**: con PyInstaller «windowed» `sys.stderr` è `None`, mentre whisper.cpp scrive i log sullo stderr C e pywhispercpp può reindirizzarlo. È da provare nella build: non l'ho potuto verificare qui.
10. **Download dei modelli**: Hugging Face dà lo sha256 nell'header `X-Linked-ETag`. Conviene salvare gli sha256 dei file messi nella release `modelli-whisper-1` e controllarli dopo il download. Sono questi:
    - base `422f1ae4…`
    - small `ae85e4a9…`
    - turbo `39422170…`
    - silero 6.2.0 `2aa269b7…`
11. Annullamento: pywhispercpp accetta `abort_callback`, quindi l'Annulla durante la trascrizione è possibile.

## Aggiunta: Parakeet TDT 0.6B v3 (stesso video)

Motore diverso da whisper: un «transducer» invece di un modello che genera il testo come una continuazione, quindi in teoria non può inventare frasi.
- Libreria: `sherpa-onnx` 2.0.3 (PyPI: `sherpa_onnx` 2,5 MB + `sherpa_onnx_core` 17,2 MB, che contiene `onnxruntime.dll`; installata pesa 29 MB). Unica dipendenza dichiarata: `sherpa-onnx-core`, quindi niente numpy obbligatorio.
- Modello: `sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8.tar.bz2`, 487 MB da scaricare (release `asr-models` di k2-fsa/sherpa-onnx), 670 MB estratto (encoder 652 MB). 25 lingue europee, italiano compreso.
- Stesse condizioni della serie whisper: WAV 16 kHz, un processo per prova, una alla volta, serie ripetuta due volte (testo identico tra r1 e r2), `OPENBLAS_NUM_THREADS=1`.

### Misure

| Decodifica | Thread | Caricam. s | Trascrizione s (r1 / r2) | Al minuto s | WS picco MB | Privata picco MB | Frasi |
|---|---|---|---|---|---|---|---|
| greedy | 4 | 5,7 | 9,0 / 9,5 | 20,0 | 1223 | 1799 | 8 |
| greedy | **8** | 5,9 | **8,1 / 8,1** | **18,4** | 1224 | 1798 | 8 |
| greedy | 16 | 5,7 | 11,8 / 11,8 | 23,0 | 1232 | 1808 | 8 |
| a fascio (`modified_beam_search`) | 8 | 6,1 | 10,7 / 11,0 | 22,6 | 1226 | 1803 | 8 |

- Velocità: **~11 s di trascrizione per minuto di audio**. Small sta tra 28 e 80 s, turbo intorno a 100.
- Caricamento: ~6 s ogni volta, contro 0,6 s di small. Con video brevi pesa: in totale sono 18 s al minuto.
- Memoria: **~1,2 GB di RAM**, più di turbo (0,85 GB). Sul telefono è parecchio.
- Thread: 8 è il migliore e 16 è peggio, come con whisper. Il testo **non cambia** con 4, 8 o 16 thread: a differenza di whisper, risultati stabili.
- Lingua: si riconosce da sola e **non si può forzare**. Il risultato non dice quale lingua ha riconosciuto (`lang` vuoto).

### Testo (greedy, 8 thread) – WER ≈ 51%
> **e** ogni zona ogni quartiere **sensibilizzare** **la** **prima** **serva** **sensibilizzare** ogni zona ogni quartiere avesse il proprio presidio di persone che ~~pur~~ non **conosciamo** si ~~incontrano...~~ ~~e~~ fanno ~~amicizia~~ ~~pulendo.~~ **mis** **e** **pulismo** **immagino** **cioè** quante volte **provi** **i** **palazzi** 2030 persone e nessuno **ti** conosce **tu** **sei** **al** vicino di casa e gli dici senti puliamo 10 metri ~~sotto~~ ~~il~~ **su** è un po' un'utopia ~~Utopia,~~ certo però ~~piano~~ ~~piano...~~ ~~Oggi~~ ~~il~~ **comunque** **che** **del** **stare** **la** **verità** **che** **del** sale ~~È~~ ~~la~~ ~~verità.~~ grazie

La ricerca a fascio (WER ≈ 49%) cambia poco: corregge «sai quante volte» e «sotto», ma perde del tutto il tratto 9–13 s.

**Il WER più basso di turbo (51% contro 69%) inganna.** Parakeet sbaglia di più dove si sente bene e semplicemente tace dove whisper inventa: 1 sola parola in più contro 32 di turbo, ma 15–22 parole mancanti. Nei tratti chiari turbo è più preciso:

| Riferimento | turbo | Parakeet |
|---|---|---|
| Sai quante volte trovi palazzi con 20-30 persone e nessuno si conosce? | Cioè sai quante volte trovi i palazzi con 20-30 persone e nessuno si conosce? | immagino cioè quante volte **provi** i palazzi **2030** persone e nessuno **ti** conosce |
| «Senti, puliamo 10 metri sotto il palazzo.» | …gli dici, senti, puliamo 10 metri sotto il palazzo. | …gli dici senti puliamo 10 metri **su** |
| Serve a sensibilizzare, esatto. | Serve a sensibilizzare, esatto. | **sensibilizzare la prima serva sensibilizzare** |

Inoltre **niente punteggiatura né maiuscole** su tutto il video. Sul campione francese incluso nel modello le mette, quindi probabilmente le toglie quando l'audio è incerto. Per i sottotitoli andrebbero aggiunte a mano, o almeno la maiuscola a inizio frase.

### Tempi delle parole e allucinazioni
- **I tempi migliori di tutte le prove**: inizio dentro il parlato nel 99% dei casi, nessuna durata nulla, nessuna sovrapposizione, inizio e fine per ogni token (passo di 80 ms). Non serve il DTW né la rimappatura.
- **Allucinazioni: nessuna.** Niente ripetizioni, niente testo nei silenzi o sul cartello finale. Nel tratto confuso 29–41 s scrive poco («che del sale», «grazie») invece di inventare frasi intere.
- Le frasi le ho costruite io: alla punteggiatura (qui assente), a pause > 0,8 s o oltre 12 s. Sono uscite 8.

### Traduzione in inglese
Parakeet **non traduce**. Le strade possibili, nessuna provata:
- **whisper small o large-v3** con `translate=True`: traduce solo verso l'inglese e richiede una seconda passata, quindi il doppio del tempo. turbo non è adatto, perché non è stato addestrato a tradurre.
- **Canary-1B v2** di NVIDIA, della stessa famiglia di Parakeet: trascrive e traduce tra l'inglese e le lingue europee. Da verificare se esiste per sherpa-onnx e quanto pesa.
- Un **modello di traduzione testo→testo** separato (italiano→inglese) applicato alle frasi già corrette. Tradurre il testo corretto a mano dà un risultato migliore che tradurre l'audio.

### Cosa ne penso
- **Parakeet non risolve la qualità su questo video.** Toglie le invenzioni e i problemi di tempi, ma sbaglia e salta più parole di turbo nelle parti chiare, e senza punteggiatura il testo va comunque ripreso.
- I suoi pregi sono reali:
  - velocità: 7–9 volte small/turbo;
  - stabilità: stesso testo con qualsiasi numero di thread;
  - tempi delle parole perfetti;
  - nessuna allucinazione;
  - un solo motore già pronto per PC, Mac (arm64 e Intel) e Android.
- Il difetto pesante, oltre alla punteggiatura, è la memoria: 1,2 GB.
- La scelta dipende da cosa conta di più:
  - meno lavoro di correzione nelle parti chiare: turbo, con attesa lunga;
  - attesa breve e niente frasi inventate: Parakeet, con le parole sbagliate da correggere.
- Un secondo video più pulito direbbe molto: con una voce sola Parakeet potrebbe anche mettere la punteggiatura.

## File della prova

**Cancellata il 2026-11-25** dopo la decisione di fare i sottotitoli manuali: dei file elencati qui sotto resta solo questo resoconto. Per rifare la prova bastano i nomi dei file e i parametri scritti sopra.

Cartella di lavoro (fuori dal repo): `C:\Users\fontm\AppData\Local\Temp\claude\43c298288992fbb1\d544d1e1-8576-4f6e-a4a1-74d5d241dc81\scratchpad\whisper-s1`
- `out\prove\` – serie principale: per ogni prova `.srt` (frasi), `.json` (frasi, parole con tempi e probabilità, misure), `.log`;
- `out\diag\` – prove diagnostiche, stessi file con i tempi interni di whisper nel `.log`;
- `out\anteprime\` – le due anteprime MP4 e le frasi corte usate (`*_frasi.txt`);
- `out\riferimento\` – fogli con i sottotitoli bruciati del video, ritagliati ogni 0,8 s;
- `out\parakeet\` – prove Parakeet (`.srt`, `.json`, `.log`); anteprima in `out\anteprime\anteprima_parakeet.mp4`;
- `models\parakeet\` – modello Parakeet estratto (670 MB);
- `scripts\` – `estrai_audio.py`, `trascrivi.py`, `trascrivi_parakeet.py`, `esegui_prove.sh`, `esegui_diag.sh`, `esegui_parakeet.sh`, `analizza.py`, `tempi_parole.py`, `confronta_testi.py`, `anteprima.py`.
