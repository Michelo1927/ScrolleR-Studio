# ScrolleR Studio Mobile — piano di realizzazione (Android + iOS)

Documento di consegna per chi realizza l'app. Va letto per intero prima di scrivere codice.
Il codice desktop in `scrollr/` è la **fonte di verità** del comportamento: quando questo piano dice
«porta 1:1 da X», la logica va letta in quel file e riprodotta, non reinventata.

Stato di partenza: esiste solo l'app desktop (PyQt6, versione 1.8.1). Non esiste ancora nessun progetto mobile.

---

## 1. Obiettivo

Portare ScrolleR Studio (editor di collage e caroselli di foto/video per i social) su **Android e iOS**, con:

- **quante più funzioni possibili** dell'app desktop (elenco completo al §6);
- un'interfaccia **pensata per il tocco, in stile Snapseed**: una pagina alla volta sullo schermo,
  strumenti che salgono dal basso, pochissimo testo, tutto raggiungibile col pollice;
- progetti **compatibili** con il desktop: un `.scrlproj` fatto sul telefono si apre sul PC e viceversa.

Non è una copia dell'interfaccia desktop: stesse funzioni, organizzazione nuova.

---

## 2. Decisioni

### 2.1 Già prese (non ridiscutere)

| Tema | Decisione |
|---|---|
| Tecnologia | **Flutter** (Dart), un solo codice per Android e iOS |
| App desktop | Resta PyQt, **non si tocca** e non si semplifica |
| Formato | `.scrlproj` (JSON) invariato, `PROJECT_VERSION = 1` invariato |
| Lingua | Interfaccia, commenti e docstring **in italiano**; README in inglese |
| Stile | Snapseed: una pagina alla volta, pannelli dal basso |
| Git | Autore `Michelo1927 <80256452+Michelo1927@users.noreply.github.com>`; commit e push solo su richiesta; messaggi in italiano |

### 2.2 Decise con l'utente per l'app mobile (non ridiscutere)

| Tema | Decisione |
|---|---|
| Posizione del codice | Cartella `mobile/` in questa stessa repo |
| Ordine delle piattaforme | **Prima Android**; iOS si compila e si prova a fine lavoro (Fase 9), senza scrivere nel frattempo codice che lo impedisca |
| Distribuzione | **Gli store non sono l'obiettivo per ora.** L'app Android esce come file `.apk` nelle release GitHub, costruito da GitHub Actions |
| Tag di rilascio | `mobile-vX.Y.Z` (i tag `v*` fanno già partire la build desktop, `.github/workflows/build.yml`) |
| Prezzo | Gratis, senza pubblicità, senza account, senza tracciamento (per ora) |
| Salvataggio | Automatico e continuo, niente pulsante «Salva» |
| Foto e video | **Collegati alla galleria del telefono, non copiati** nel progetto (§9). In più, «Condividi progetto» crea uno `.zip` completo con tutte le foto, da passare al PC |
| Maniglie laterali delle foto | Come sul desktop: stirano la foto insieme al riquadro; l'interruttore «Solo riquadro» di Inquadra (lo Shift del desktop) cambia solo il riquadro |
| Gesto «indietro» con uno strumento aperto | **Scarta** la modifica, come ✕ (come in Snapseed). Per tenerla serve ✓ |
| Schermo | Solo telefono in verticale nella v1; orizzontale e tablet dopo |
| Lingue | Italiano (principale) e inglese |

### 2.3 Scelte tecniche di questo piano (modificabili se emergono motivi)

| Tema | Proposta |
|---|---|
| Versioni minime | Android 8.0 (API 26), iOS 15: da verificare con i requisiti dei pacchetti scelti |
| Identificativo dell'app in sviluppo | Uno provvisorio (es. `io.github.michelo1927.scrollerstudio.dev`). Quello definitivo si decide con l'utente **prima di qualsiasi pubblicazione in uno store**, perché dopo non si cambia più |
| Firma dell'APK | Chiave di firma propria, conservata nei segreti di GitHub Actions: senza la stessa chiave gli aggiornamenti non si installano sopra la versione precedente |

### 2.4 Rimandate (chiedere all'utente quando servono)

1. **Pubblicazione negli store**, identificativo definitivo, account sviluppatore (Google Play 25 $ una tantum,
   Apple Developer 99 $/anno), privacy policy.
2. **iOS**: l'utente lavora su Windows, dove non si può compilare né provare iOS. Alla Fase 9 servono un runner macOS
   (GitHub Actions), un account Apple Developer per firmare e un iPhone vero per le prove.
3. **Modello di prezzo** definitivo.

---

## 3. Principi di progettazione (stile Snapseed)

1. **Il contenuto è il protagonista.** La pagina occupa tutto lo spazio libero; l'interfaccia è scura, neutra e sottile.
2. **Una cosa alla volta.** Una pagina sullo schermo, uno strumento aperto, un parametro regolato.
3. **Tutto sale dal basso.** Nessun menu a tendina, nessun pannello laterale, nessuna finestra al centro
   (tranne le conferme distruttive).
4. **La pagina non viene mai coperta.** Quando un pannello sale, la pagina si rimpicciolisce e si ricentra
   nello spazio rimasto, con animazione. Mentre regoli, vedi sempre il risultato.
5. **Anteprima dal vivo, poi ✓ o ✕.** Ogni strumento mostra subito l'effetto; ✓ conferma (un passo di cronologia),
   ✕ torna com'era.
6. **Niente si perde.** Salvataggio automatico, Annulla sempre visibile, cronologia con i nomi dei passaggi.
7. **Zona del pollice.** Le azioni frequenti stanno nel terzo inferiore; in alto solo ciò che si usa di rado.
8. **Poche parole.** Icona + etichetta di una o due parole. Niente tooltip: i suggerimenti lunghi del desktop
   diventano una riga di aiuto dentro il pannello o un messaggio breve a comparsa.
9. **Stesso risultato del desktop.** Ciò che si vede è ciò che si esporta, e somiglia a ciò che fa il desktop
   con lo stesso progetto.

---

## 4. Interfaccia e interazione

### 4.1 Schermate

```
Home (progetti)
 ├─ Nuovo progetto → Formato → Scelta foto → Editor
 ├─ Progetto esistente → Editor
 ├─ Importa progetto (.zip / .scrlproj)
 └─ Impostazioni

Editor
 ├─ Anteprima carosello (schermo intero)
 ├─ Panoramica pagine (griglia)
 ├─ Ritaglio (schermo intero)
 └─ Esporta (foglio dal basso → avanzamento → fatto)
```

**Home.** Griglia di progetti con miniatura della prima pagina, nome, numero di pagine, data. Pulsante grande
«Nuovo» in basso. Pressione lunga su un progetto: Rinomina, Duplica, Condividi progetto (.zip), Elimina.
Stato vuoto con una sola azione evidente. Sostituisce «Apri recenti», «Salva con nome» e «Raccogli progetto».

**Nuovo progetto.** Due passi: formato (gli 8 formati + Personalizzato, mostrati come sagome proporzionate),
poi la scelta delle foto dalla galleria (§9). Le foto scelte finiscono in libreria e sulla tela con la disposizione Griglia.
Si può saltare la scelta delle foto (tela vuota).

**Editor.** Struttura fissa dall'alto in basso:

```
┌──────────────────────────────────────┐
│ ←   ↶  ↷            ▶ Anteprima  ⤴ │  barra superiore (48 dp)
├──────────────────────────────────────┤
│                                      │
│            PAGINA CORRENTE           │  tela: una pagina, adattata allo spazio
│                                      │
├──────────────────────────────────────┤
│        ‹  ● ○ ○ ○ ○  2/5  ›  ⊞      │  striscia pagine (32 dp)
├──────────────────────────────────────┤
│  Foto  Disposizione  ＋  Pagine  Stile │  barra inferiore (64 dp)
└──────────────────────────────────────┘
```

- Barra superiore: indietro (torna alla Home, il progetto è già salvato), Annulla, Ripeti
  (pressione lunga su Annulla = **Cronologia**), Anteprima, Esporta.
- Striscia pagine: puntini o numeri, tocco = vai alla pagina, `⊞` = Panoramica. Lucchetto sulle pagine bloccate,
  trattino tra le pagine unite «a cavallo».
- Barra inferiore: cambia in base alla selezione (§4.3).

### 4.2 La tela: una pagina alla volta

Il modello dati resta quello del desktop: **una striscia unica** larga `frame_w × num_frames`, con gli elementi
in coordinate della striscia. Sul telefono ogni pagina è una **finestra ritagliata** sulla striscia (come la vista
«a scacchiera» del desktop, `scrollr/canvas/page_grid.py`): le foto «a cavallo» appaiono tagliate sul bordo,
come nel carosello vero.

- Le pagine stanno in uno scorrimento orizzontale a scatti, con un piccolo spazio tra l'una e l'altra e un
  lembo (circa 12 dp) della pagina vicina visibile ai lati.
- Riquadro di selezione e maniglie si disegnano **sopra**, non ritagliati, così un elemento che sporge resta afferrabile.
- Trascinando un elemento verso il bordo dello schermo la vista passa alla pagina vicina (così si sposta una foto
  da una pagina all'altra, come il trascinamento tra pagine del desktop).
- Etichetta della pagina sopra la tela, come `CollageScene.page_label`: «Pagina 2 · Bloccata · A cavallo 2–4 · 3 foto».
- Guide di centro (ciano) e linee di aggancio (magenta) come sul desktop; l'aggancio dà anche un tocco aptico leggero.
- Pagina vuota: icona e «Tocca ＋ per aggiungere le foto».

### 4.3 Barra inferiore

**Niente selezionato** (5 voci):

| Voce | Apre |
|---|---|
| **Foto** | Libreria: griglia di miniature con segno su quelle già sulla tela; aggiungi dal telefono; selezione multipla; «Aggiungi alla tela», «Come foto libera», «Solo queste», «Rimuovi dalla libreria», «Metti tutte», «Svuota tela»; riordino con pressione lunga + trascinamento |
| **Disposizione** | Le 6 disposizioni come tessere; stile del mosaico (8); ambito «Tutto il carosello / Solo questa pagina»; «Una disposizione per ogni pagina»; Foto per pagina (Auto, 1–20); Foto in questa pagina; Spaziatura 0–80; Margine 0–120; Rimescola |
| **＋** | Testo, Forma (9 tipi), Foto o video, Pagina nuova |
| **Pagine** | Azioni sulla pagina corrente: aggiungi prima/dopo, duplica, sposta, blocca, unisci «a cavallo», esporta questa, elimina; Formato del carosello; Riordina (Panoramica) |
| **Stile** | Sfondo (tinta, sfumatura, foto sfocata); Numeri di pagina; Indicatore «scorri»; Guide; Aggancio |

**Elemento selezionato**: la barra diventa una striscia di strumenti a scorrimento orizzontale, specifica per tipo.
A sinistra una `✕` per togliere la selezione.

- **Foto**: Ritaglia · Inquadra · Filtri · Regola · Effetti · Cornice · Ombra · Ruota · Disponi · Libera/In disposizione ·
  Sposta in pagina · Copia stile · Incolla stile · Duplica · Elimina
- **Video**: come la foto senza Filtri/Regola/Effetti, più Taglia · Copertina · Audio · Riproduci
- **Testo**: Modifica · Carattere · Dimensione · Formato · Colore · Contorno · Ombra · Etichetta · Spaziatura · Opacità ·
  Ruota · Disponi · Duplica · Elimina
- **Forma**: Tipo · Riempimento · Bordo · Angoli · Opacità · Ruota · Disponi · Duplica · Elimina
- **Più elementi**: Allinea · Distribuisci · Raggruppa/Separa · Scambia (solo con 2 foto) · Blocca · Duplica · Elimina
- **Foto mancante**: compare per primo «Ricollega»

### 4.4 Anatomia di uno strumento

```
│              PAGINA (rimpicciolita)            │
├────────────────────────────────────────────────┤
│  Luminosità   Contrasto   Ombre   Luci   …     │  parametri (scorrono in orizzontale)
│  ─────────────●───────────────────   +24       │  un solo cursore grande
│  ✕              Luminosità       ◐          ✓  │  annulla · nome · confronta · conferma
└────────────────────────────────────────────────┘
```

- Un parametro attivo alla volta, un solo cursore. Valore numerico accanto; doppio tocco sul cursore = valore iniziale.
- I parametri con lo zero al centro (Luminosità, Calore, Angolo…) hanno il cursore che parte dal centro.
- `◐` tenuto premuto = prima/dopo (`scene.show_original` del desktop).
- Altezza massima del pannello: circa il 40% dello schermo. Se il contenuto non ci sta, scorre in orizzontale, non in verticale.
- Gesto «indietro» di sistema o trascinamento del pannello verso il basso = **scarta**, come `✕`. Solo `✓` conferma.
  Se la modifica scartata così è consistente, un messaggio breve offre «Ripristina» per qualche secondo.
- Gli strumenti a comando singolo (Duplica, Elimina, Specchia, Davanti/Dietro) non aprono pannelli: agiscono subito
  e mostrano un messaggio breve con «Annulla».

### 4.5 Gesti sulla tela

| Gesto | Effetto |
|---|---|
| Tocco su un elemento | Lo seleziona (un gruppo si seleziona intero) |
| Tocco sul vuoto | Toglie la selezione |
| Trascinamento su elemento selezionato | Lo sposta, con aggancio |
| Trascinamento orizzontale sul vuoto | Cambia pagina |
| Pizzico sul vuoto | Zoom della vista; con due dita si sposta la vista ingrandita; doppio tocco sul vuoto = adatta |
| Pizzico e rotazione su elemento selezionato | Ridimensiona e ruota il riquadro (scatti aptici a 0°, 90° e ogni 15°) |
| Maniglie d'angolo | Ridimensiona mantenendo le proporzioni |
| Maniglie sui lati | Come sul desktop: la foto si stira insieme al riquadro (campo `stretch`). Con l'interruttore «Solo riquadro» nello strumento Inquadra (lo Shift del desktop) cambia solo la forma del riquadro e la foto lo riempie senza deformarsi. (Cambiato il 2026-11-18 su richiesta: prima era il contrario.) |
| Pallino sopra la forma | Ruota |
| Estremi di linee e frecce | Allungano e orientano |
| Doppio tocco su una foto | Apre **Inquadra**: dentro il riquadro, un dito sposta la foto e due dita la ingrandiscono/ruotano (`pan_x`, `pan_y`, `inner_zoom`, `inner_rotation`) |
| Doppio tocco su un testo | Apre la tastiera per scriverci |
| Pressione lunga su un elemento | Menu dal basso: Copia, Taglia, Duplica, Blocca, Porta davanti, Manda dietro, Libera/In disposizione, Sposta in pagina, Elimina |
| Pressione lunga sul vuoto | Menu dal basso: Incolla qui, Aggiungi testo qui, Aggiungi forma qui, azioni della pagina |
| «Seleziona più» (nel menu della pressione lunga) | Modalità selezione multipla: ogni tocco aggiunge o toglie |

Regole: aree toccabili di almeno 44–48 dp anche se la maniglia disegnata è più piccola; su un elemento piccolo vince
la maniglia più vicina al dito (come sul desktop); gli elementi di una pagina bloccata non si selezionano e trascinandoci
sopra si cambia pagina; un elemento con «Blocca posizione» si seleziona ma non si muove e mostra il lucchetto.

### 4.6 Altre viste

- **Panoramica** (`⊞`): tutte le pagine in griglia. Tocco = vai; trascinamento = riordina (un gruppo «a cavallo» si sposta
  insieme); pressione lunga = azioni della pagina. Sostituisce «Pagine a scacchiera» e «Riordina le pagine…».
- **Anteprima** (`▶`): schermo intero, sfondo nero, si scorre come su Instagram, senza guide né selezione
  (`scene.clean_render`). I video partono da soli, senza audio.
- **Ritaglio**: schermo intero. Rettangolo con angoli e lati trascinabili, griglia dei terzi, proporzioni
  Libera · Originale · Riquadro · 1:1 · 4:5 · 3:4 · 2:3 · 9:16, pulsante ⇄, «Foto intera», misure in pixel,
  interruttore «Adatta il riquadro al ritaglio». Riferimento: `scrollr/crop_dialog.py`.
- **Cronologia**: elenco dal basso con il nome di ogni passaggio; tocco = torna a quel punto.
- **Sfondo**: tre schede (Tinta, Sfumatura con due colori e direzione verticale/orizzontale/diagonale,
  Foto sfocata con scelta della foto, Sfocatura 0–100, Scurisci 0–80).
- **Selettore colore**: i 12 campioni rapidi di `SWATCHES`, i colori usati nel progetto, contagocce sulla pagina,
  selettore completo (tinta/saturazione/luminosità + esadecimale) e trasparenza dove serve (etichetta del testo).
  Per le forme il primo campione è «Nessuno».

### 4.7 Design system

- **Colori**: partire da `THEME` in `scrollr/theme.py` e definirli una volta sola in un file di token
  (mai esadecimali sparsi nei widget). Fondo attorno alla pagina `#1E1E1E`, superfici dei pannelli un tono sopra,
  testo `#DADADA`, testo secondario `#A3A3A3`, **un solo accento** `#2680EB`, pericolo `#E34850`,
  guide `#29D5F5`, aggancio `#FF3DCB`. Grigi neutri senza dominanti: servono a giudicare i colori delle foto.
- **Solo tema scuro** nell'editor. Niente tema chiaro nella v1.
- **Tipografia**: font di sistema (Roboto / San Francisco), 3 misure (12, 14, 17) e 2 pesi.
- **Icone**: una sola famiglia a tratto arrotondato per i comandi comuni; le icone di disposizioni, stili del mosaico
  e forme si disegnano a codice portando la geometria da `scrollr/icons.py` e `scrollr/shapes.py`, così sono
  uguali al desktop. Icona dell'app: il logo di `icons.py`.
- **Forme**: pannelli con angoli superiori 16 dp, tessere 12 dp, pulsanti a pillola.
- **Movimento**: pannelli 200–250 ms con decelerazione; la pagina si ridimensiona insieme al pannello; rispettare
  «riduci animazioni» di sistema.
- **Aptica**: tocco leggero su aggancio, scatti di rotazione, zero del cursore, cambio pagina.
- **Messaggi**: brevi, in basso sopra la barra, con azione «Annulla» dove ha senso. Sostituiscono la barra di stato del desktop.
- **Accessibilità**: etichette per i lettori di schermo su ogni comando, contrasto AA, testo che segue la
  dimensione di sistema fino a 1,3×, nessuna informazione affidata al solo colore.
- **Aree sicure**: rispettare tacca, isola e barra dei gesti; la barra inferiore sta sopra l'area dei gesti di sistema.
- **Primo avvio**: tre suggerimenti contestuali al massimo (tocca una foto, tieni premuto, scorri per cambiare pagina),
  ognuno mostrato una volta sola. In Impostazioni c'è «Gesti», la versione mobile di «Scorciatoie da tastiera e mouse».

---

## 5. Architettura tecnica

### 5.1 Struttura

```
mobile/
  packages/
    scrl_engine/          Dart puro, nessuna dipendenza da Flutter: si prova da riga di comando
      lib/src/model/      Canvas, PhotoItem, VideoItem, TextItem, ShapeItem, Snapshot
      lib/src/project/    lettura/scrittura .scrlproj, percorsi, zip
      lib/src/layout/     disposizioni, conteggi per pagina, a cavallo, casuale compatibile
      lib/src/pages/      inserisci, duplica, elimina, sposta, riordina, blocca, unisci
      lib/src/history/    cronologia e nomi dei passaggi
      lib/src/edit/       allinea, distribuisci, gruppi, copia/incolla, stile, aggancio
      lib/src/color/      regolazioni, filtri pronti, tabelle dei toni, livelli automatici
      test/               prove con i dati di riferimento generati dal desktop
    scrl_video/           plugin nativo: informazioni, fotogrammi, audio, scrittura MP4
  app/
    lib/
      theme/              token, stili
      render/             disegno della scena (schermo ed esportazione usano lo stesso codice)
      media/              importazione, miniature, cache, alta risoluzione
      editor/             tela, gesti, selezione, strumenti, pannelli
      home/ export/ settings/
      l10n/               testi (italiano principale, inglese)
  tools/
    genera_riferimenti.py dati di riferimento prodotti dall'app desktop
```

Regole: `scrl_engine` non importa Flutter; l'interfaccia non contiene logica di dominio; un solo flusso
di dati (stato → disegno), stato dell'editor in un unico punto (consigliato Riverpod).

### 5.2 Modello e cronologia

- Lo stato del documento è **uno snapshot immutabile** con la stessa forma di `HistoryMixin._snapshot()`:
  `{canvas, items, texts, shapes}` più la libreria.
- Ogni modifica produce un nuovo snapshot. Annulla/Ripeti = pila di snapshot, limite **100** (`HISTORY_LIMIT`).
- Un passo di cronologia nasce: alla ✓ di uno strumento, alla fine di un gesto diretto, a ogni comando singolo.
  Mai durante il trascinamento di un cursore.
- Prima di ogni passo si esegue `_keep_videos_in_pages` (i video non possono stare a cavallo di due pagine).
- Nome del passaggio: portare `_describe_change` da `scrollr/window/history.py`.
- Stato temporaneo dell'interfaccia (selezione, zoom, strumento aperto) **fuori** dallo snapshot.

### 5.3 Salvataggio

- A ogni passo di cronologia, con un ritardo di circa 1 s, e sempre quando l'app va in secondo piano.
- Scrittura **atomica**: file temporaneo, poi rinomina. Mai lasciare un `.scrlproj` a metà.
- La miniatura della Home si rigenera insieme al salvataggio, a bassa priorità.

### 5.4 Release nella stessa repo del desktop (attenzione)

L'app desktop cerca gli aggiornamenti con `…/releases/latest` e anche il README rimanda a «latest release».
Una release mobile pubblicata normalmente diventerebbe «latest» e romperebbe entrambe le cose. Quindi:

- le release mobile si pubblicano **senza segnarle come «latest»** (nel workflow: `make_latest: false`);
- il workflow mobile è un file separato, parte solo sui tag `mobile-v*`, e non tocca `build.yml`;
- titolo «ScrolleR Studio Mobile X.Y.Z», note in italiano in `release-notes/mobile-vX.Y.Z.md`, scritte prima del tag;
- l'app mobile cerca la propria ultima versione scorrendo l'elenco delle release e tenendo solo i tag `mobile-v*`;
- dopo la prima release mobile, verificare sul desktop che «Controlla aggiornamenti» proponga ancora la versione desktop.

---

## 6. Parità di funzioni: desktop → mobile

Legenda: ✅ da fare uguale · 🔁 da fare in forma diversa · ⛔ non ha senso su telefono.

### Progetto e file

| Desktop | Mobile |
|---|---|
| Nuovo progetto | ✅ Home → Nuovo |
| Apri / Apri recenti | 🔁 Home con miniature |
| Salva / Salva con nome | 🔁 Automatico; «Duplica» e «Rinomina» nella Home |
| Salvataggio automatico e recupero | 🔁 Continuo e atomico: non serve il recupero |
| Raccogli progetto in una cartella | 🔁 «Condividi progetto»: `.zip` completo con il progetto e gli originali di tutte le foto e i video |
| Doppio clic su `.scrlproj` | 🔁 «Apri con ScrolleR Studio» per `.scrlproj` e `.zip` |
| Trascina file sulla finestra | 🔁 «Condividi con ScrolleR Studio» dalla galleria |
| Foto mancanti, ricollega una o tutte, cerca in cartella | ✅ Importante sul telefono, perché le foto sono solo collegate: se una viene cancellata dalla galleria resta sulla tela con l'anteprima salvata e il segno «Originale mancante»; elenco all'apertura; ricollega scegliendo una foto, oppure ricerca automatica per nome in galleria |
| Avviso foto mancanti prima di esportare | ✅ |
| Controllo aggiornamenti | ✅ Serve, perché l'app si installa da APK: avviso «nuova versione» con le novità e il collegamento per scaricare l'APK, con l'interruttore «Controlla all'avvio» come sul desktop (`scrollr/window/updates.py`). Cerca tra le release solo quelle con tag `mobile-v*` (§5.4) |
| Registro errori `errori.log` | 🔁 Registro locale + «Invia registro» in Impostazioni; un errore mostra un avviso, non chiude l'app |
| Informazioni, pagina GitHub | ✅ In Impostazioni |

### Libreria

| Desktop | Mobile |
|---|---|
| Aggiungi foto e video (JPG, PNG, WebP, BMP, HEIC; MP4, MOV, M4V, WebM, MKV, AVI) | ✅ Dalla galleria (collegamento) o da File (copia, §9); i formati non letti dal telefono danno un messaggio chiaro |
| Miniature, segno «già sulla tela», simbolo ▶ per i video, contatore | ✅ |
| Selezione multipla, Tutte / Nessuna | ✅ |
| Aggiungi alla tela / solo queste / come foto libera / rimuovi dalla libreria | ✅ |
| Metti tutte sulla tela / Svuota tela (rispetta le pagine bloccate) | ✅ |
| Riordino: la tela segue l'ordine della libreria | ✅ |
| Trascina una miniatura su una pagina | 🔁 «Aggiungi a questa pagina» (la pagina fissa il suo numero di foto, `_insert_into_page`) |

### Tela, formato, pagine

| Desktop | Mobile |
|---|---|
| 8 formati + Personalizzato (200–6000 px) | ✅ |
| Pagine 1–30 | ✅ Con avviso non bloccante oltre il limite di slide del social scelto |
| Aggiungi pagina all'inizio / prima / dopo / alla fine (resta «Vuota») | ✅ |
| Duplica, elimina, sposta a sinistra/destra, riordina | ✅ |
| Blocca pagina (tutte le regole della 1.6.0) | ✅ |
| Unisci / separa «a cavallo» con la successiva, gruppi di più pagine | ✅ |
| Disposizione propria di una pagina, Foto in questa pagina | ✅ |
| Sfondo: tinta, sfumatura, foto sfocata | ✅ |
| Numeri di pagina (4 formati, 6 posizioni), indicatore «scorri» (testo, 2 posizioni), 3 stili | ✅ |
| Guide, Aggancio | ✅ |
| Pagine in fila / a scacchiera | 🔁 Una pagina alla volta + Panoramica |
| Zoom, adatta, 100%, barre di scorrimento | 🔁 Pizzico, doppio tocco |
| Modalità della rotella, Spazio + trascina, selezione a riquadro | ⛔ |
| Anteprima carosello | ✅ |
| Cronologia con nomi | ✅ |

### Disposizioni

| Desktop | Mobile |
|---|---|
| Griglia, Mosaico (8 stili), Righe, Colonne, Polaroid, A cavallo | ✅ Algoritmi identici |
| Una disposizione per ogni pagina / tela continua | ✅ |
| Foto per pagina Auto o 1–20 (le pagine si calcolano da sole) | ✅ |
| Spaziatura, Margine | ✅ |
| Rimescola, Scambia 2 foto | ✅ |
| Foto libera / rimetti nella disposizione | ✅ |
| Sposta nella pagina N; trascina su un'altra pagina | ✅ |
| «A cavallo» con 1 pagina aggiunge pagine e le toglie tornando indietro | ✅ |

### Foto

| Desktop | Mobile |
|---|---|
| Sposta, ridimensiona, stira, ruota riquadro | ✅ (vedi scelta sulle maniglie laterali, §4.5) |
| Riempi riquadro / Foto intera | ✅ |
| Zoom 100–400, Orizzontale e Verticale ±100, Ruota contenuto ±180 | ✅ Con le dita in Inquadra, più i cursori |
| Ritaglio con proporzioni | ✅ |
| Reimposta inquadratura; Proporzioni foto / Riquadro di prima | ✅ |
| Angolo ±180, 90° sx/dx, Dritta, Specchia orizz./vert. | ✅ |
| 9 filtri con anteprima sulla foto | ✅ |
| Miglioramento automatico, Luminosità, Contrasto, Ombre, Luci, Saturazione, Calore, Tinta, Bianco e nero | ✅ |
| Nitidezza, Vignettatura, Sbiadito, Grana | ✅ |
| Prima / dopo | ✅ |
| Reimposta colori, Applica a tutte | ✅ |
| Angoli 0–200, Bordo 0–40 e colore, Opacità 5–100, Ombra 0–100 | ✅ |
| Copia stile, Incolla stile, Applica a tutte le foto | ✅ |
| Nitidezza piena con lo zoom forte | ✅ (§8.3) |

### Video

| Desktop | Mobile |
|---|---|
| Video sulla tela come una foto (riquadro, ritaglio, bordi, angoli, ombra, disposizioni) | ✅ |
| Etichetta con durata e muto | ✅ |
| Riproduci sulla tela, senza audio, a ripetizione | ✅ |
| Inizio, Fine, Copertina, Audio | ✅ |
| Niente regolazioni colore sui video | ✅ |
| Il video resta dentro una pagina | ✅ |
| Pagine con video esportate in MP4 | ✅ (§10) |

### Testo

| Desktop | Mobile |
|---|---|
| Aggiungi, scrivi su più righe | ✅ |
| Carattere | 🔁 Elenco di font inclusi nell'app (§8.5) |
| Dimensione 12–400, Grassetto, Corsivo, Allineamento | ✅ |
| Interlinea 60–250, Spaziatura lettere −10…60 | ✅ |
| Colore, Contorno 0–40 e colore, Ombra, Etichetta e colore con trasparenza, Opacità 5–100 | ✅ |
| Sposta, ruota | ✅ |

### Forme

| Desktop | Mobile |
|---|---|
| Rettangolo, ellisse, triangolo, rombo, stella, cuore, linea, freccia, doppia freccia | ✅ Geometria da `scrollr/shapes.py` |
| Riempimento (anche Nessuno), Bordo colore / spessore 0–80 / tratto, Angoli 0–300, Opacità, Angolo | ✅ |
| Cambia tipo tenendo stile e posizione; la forma nuova riprende l'ultimo stile | ✅ |

### Comuni a tutti gli elementi

| Desktop | Mobile |
|---|---|
| Copia, Taglia, Incolla (nella pagina corrente, stessa posizione; foto incollate libere; copie ripetute sfalsate) | ✅ Appunti interni all'app, validi anche tra progetti |
| Duplica, Elimina, Seleziona tutte | ✅ |
| Porta davanti, Manda dietro | ✅ |
| Allinea (6), Distribuisci (2, da 3 elementi) | ✅ Stesse regole di `_align_selected` (un solo elemento si allinea alla pagina) |
| Raggruppa, Separa | ✅ |
| Blocca posizione e dimensioni | ✅ |
| Spostamento fine con le frecce (1 e 10 px) | 🔁 Quattro frecce nello strumento Disponi |
| Scorciatoie da tastiera | ⛔ Nella v1 (utile più avanti sui tablet con tastiera) |

### Esportazione

| Desktop | Mobile |
|---|---|
| Collage intero in un'unica immagine | ✅ Con limiti di dimensione (§11) |
| Pagine separate, con scelta dalle miniature | ✅ |
| Esporta questa pagina | ✅ |
| PNG / JPG, qualità JPG in 5 livelli, 1× / 2× | ✅ |
| Nome dei file salvato nel progetto | ✅ |
| Avanzamento con Annulla | ✅ |
| Cartella di destinazione, «Apri cartella» | 🔁 Salva in Galleria (album «ScrolleR Studio»), Condividi, Salva in File |

---

## 7. Formato `.scrlproj` (da rispettare alla lettera)

File JSON UTF-8. Riferimenti: `scrollr/window/project.py`, `scrollr/window/history.py`, e i metodi
`get_state` / `set_state` di `scrollr/canvas/*.py`.

```
{
  "version": 1,
  "canvas":  { … },
  "library": [ {"path": "...", "rel": "..."} ],
  "items":   [ foto e video ],
  "texts":   [ … ],
  "shapes":  [ … ]
}
```

**Regole generali**

- Leggere ogni campo con un valore predefinito (gli stessi di `set_state`): i progetti vecchi devono aprirsi.
- **Conservare i campi sconosciuti** e riscriverli tali e quali: un desktop più recente potrebbe averne aggiunti.
- Colori nel formato `#AARRGGBB`. Coordinate arrotondate come nel desktop (3 decimali; 4 per zoom e pan; 5 per ritaglio e stiramento).
- `uid` interi, con contatori separati per foto, testi e forme. `z` è un numero con la virgola.
- Coordinate nella striscia: pagina di un elemento = `floor(x_centro / frame_w)`.

**`canvas`**

| Campo | Predefinito | Note |
|---|---|---|
| `ratio_index` | 0 | Indice nell'elenco `ASPECT_RATIOS` del desktop, **nello stesso ordine** (8 = Personalizzato). Va scritto coerente con `frame_w`/`frame_h` |
| `custom_w`, `custom_h` | 1080, 1440 | |
| `frame_w`, `frame_h` | 1080, 1440 | |
| `num_frames` | 1 | 1–30 |
| `bg_color` | `#FFFFFFFF` | |
| `gap`, `margin` | 16, 24 | |
| `per_frame` | true | Una disposizione per ogni pagina |
| `per_page` | 0 | 0 = Auto |
| `page_counts` | [] | Per pagina: numero fissato o null |
| `page_layouts` | [] | Per pagina: `{"mode", "style"}` o null |
| `page_seams` | [] | true in k = pagine k e k+1 unite |
| `page_locks` | [] | |
| `layout_mode` | `grid` | `grid`, `mosaic`, `strips_h`, `strips_v`, `scatter`, `scrl_seam` |
| `mosaic_style` | `auto` | `auto`, `top`, `bottom`, `left`, `right`, `center`, `two`, `masonry` |
| `layout_seed` | casuale | Intero sotto 2^30 |
| `bg_mode` | `solid` | `solid`, `gradient`, `blur` |
| `bg_color2` | `#FF2680EB` | |
| `bg_direction` | `vertical` | `vertical`, `horizontal`, `diagonal` |
| `bg_blur_path`, `bg_blur_rel` | "" | |
| `bg_blur_amount`, `bg_dim` | 50, 15 | |
| `page_numbers` | false | |
| `page_number_format` | `slash` | `slash`, `of`, `padded`, `plain` |
| `page_number_pos` | `bc` | `b`/`t` + `l`/`c`/`r` |
| `overlay_style` | `dark` | `dark`, `light`, `plain` |
| `swipe_hint`, `swipe_text`, `swipe_pos` | false, `Scorri →`, `br` | `br` o `cr` |
| `export_name` | "" | |

**Foto (`items`)**: `uid, path, rel, x, y, w, h, rotation, z, layout_index, inner_zoom, pan_x, pan_y, inner_rotation,
crop [sinistra, alto, destra, basso in 0..1], stretch, border_radius, border_width, border_color, auto_border,
adjust {brightness, contrast, shadows, highlights, saturation, warmth, tint, sharpness, vignette, fade, grain, bw, auto},
flip_h, flip_v, fit_mode (cover|contain), opacity, shadow, locked, page_locked, free, saved_cell, group`.

**Video**: come la foto più `kind: "video", trim_start, trim_end (null = fino alla fine), muted, poster`.

**Testi**: `uid, text, x, y, rotation, z, font, size, bold, italic, align, color, shadow, box, box_color, opacity,
outline, outline_color, line_height, letter_spacing, locked, page_locked, group`.

**Forme**: `uid, kind, x, y, w, h, rotation, z, fill, stroke, stroke_width, stroke_style (solid|dash|dot),
radius, opacity, locked, page_locked, group`.

**Percorsi (punto delicato).** Il desktop prova prima `path` (assoluto) e poi `rel` (relativo alla cartella del progetto,
sempre con `/`). Sul telefono una foto può essere di due tipi:

- **collegata alla galleria** (il caso normale): è identificata dall'identificativo della galleria di sistema, non da un percorso.
  Nel file si scrive un campo in più, solo mobile, `asset` (es. `{"platform": "android", "id": "…", "name": "IMG_1234.jpg"}`),
  `rel: null` e in `path` il nome originale del file. Il desktop ignora `asset`, non trova il file e mostra «Foto mancante»
  con il nome giusto, pronta per «Cerca in una cartella…»;
- **dentro il progetto** (progetto arrivato dal PC come `.zip`, oppure file scelto da File): sta in `media/` e si scrive
  lo stesso valore relativo (`media/nome.jpg`) sia in `rel` sia in `path`.

Regole:

- in lettura il mobile prova `asset` (se è della stessa piattaforma), poi **`rel`**, poi `path`, poi dichiara la foto mancante.
  I percorsi assoluti sul telefono non sono affidabili: su iOS la cartella dell'app cambia nome tra un'installazione e l'altra;
- lo `.zip` di «Condividi progetto» contiene una **copia** del progetto in cui ogni foto collegata è stata copiata in `media/`
  e ha `rel` e `path` relativi: estratto sul PC si apre con tutte le foto trovate. Il progetto sul telefono resta collegato alla galleria;
- il desktop, risalvando, perde il campo `asset` (riscrive solo i campi che conosce): è accettato, perché il ritorno
  dal PC al telefono passa dallo `.zip` con `media/`;
- da verificare nella Fase 1 con il desktop vero: apertura dello `.zip` estratto e apertura di un `.scrlproj` con foto collegate.

---

## 8. Motore e disegno

### 8.1 Disposizioni (porta 1:1 da `scrollr/window/layouts.py`)

Da portare: `apply_auto_layout`, `_free_stretches`, `_page_photo_counts`, `_layout_grid`, `_layout_mosaic`,
`_layout_masonry`, `_layout_strips`, `_layout_scatter`, `_layout_seam`, `_split_rows`, `_move_photos_to_page`,
`_insert_into_page`, rimescola e scambia. Costanti: `SEAM_KEEP = 0.15`, area minima 100 px, cella minima 40 px.

Trappole note:

- **Arrotondamento.** `round()` di Python arrotonda al pari (2,5 → 2), quello di Dart no (2,5 → 3). Scrivere una
  funzione `pyRound` e usarla ovunque il Python usa `round()` (colonne della griglia, divisione delle foto tra i tratti).
- **Numeri casuali.** Polaroid usa `random.Random(layout_seed)`. Per avere la stessa disposizione sulle due app,
  portare il generatore di Python (Mersenne Twister, semina da intero, `uniform`) e provarlo contro valori generati dal desktop.
- **Bordo automatico.** Polaroid mette un bordo di 8 px con `auto_border = true`; ogni altra disposizione lo toglie.
- **Pagine bloccate e foto libere** sono escluse dalla disposizione (`_layout_photos`).
- Lo spostamento manuale di una foto in disposizione resta finché non c'è un nuovo ricalcolo, come sul desktop.

### 8.2 Pagine (porta 1:1 da `scrollr/window/pages.py`)

Inserisci, duplica, elimina, sposta, riordina, blocca, unisci: ognuna sposta gli elementi di `frame_w` e tiene
allineate le quattro liste per pagina (`page_counts`, `page_layouts`, `page_seams`, `page_locks`).
Regole da non dimenticare: una pagina bloccata non si elimina; con pagine bloccate non si cambia formato né si tolgono
pagine dalla fine; bloccare una pagina «a cavallo» blocca tutto il gruppo; un gruppo «a cavallo» si sposta insieme.

### 8.3 Disegno

Un solo modulo disegna la scena su una tela `dart:ui`, usato **sia per lo schermo sia per l'esportazione**
(con indicatori `esportazione` e `pulito` come `is_exporting` e `clean_render`). Ordine: sfondo → elementi per `z` →
numeri di pagina e «scorri» → (solo a schermo) guide, giunzioni, aggancio, selezione.

- **Foto**: portare `_cover_geometry`, `_image_transform`, `_crop_rect`, `_paint_shadow`, `_paint_effects`
  (vignettatura e grana sono disegnate sopra la foto) e il bordo interno da `scrollr/canvas/photo_item.py`.
- **Testi e forme**: portare da `text_item.py` e `shape_item.py` (contorno, ombra, etichetta, punte delle frecce, tratteggi).
- **Sfondo e sovrimpressioni**: portare `paint_canvas_background` e `paint_page_overlays` da `scene.py`
  (il carattere dei numeri è il 3% del lato corto della pagina).
- **Livelli di dettaglio**: miniatura (libreria), anteprima (lato lungo circa 1600 px, meno sui telefoni con poca memoria),
  alta risoluzione su richiesta quando la foto è ingrandita oltre il 115% dei suoi pixel (al massimo 4096 px, poche in memoria).
- Le anteprime si decodificano fuori dal thread dell'interfaccia e già ridotte. Si salvano su disco nella cartella
  del progetto per riaprirlo in fretta.

### 8.4 Colore (riferimento: `scrollr/imaging.py`)

Ordine delle operazioni, da rispettare: livelli automatici → luminosità → contrasto → bianco e nero **oppure** saturazione →
tabella dei toni (ombre, luci, sbiadito, calore, tinta) → nitidezza. Vignettatura e grana a parte, sopra la foto.

- Consigliato: uno **shader** per l'anteprima dal vivo e lo stesso shader per l'esportazione, così coincidono.
  Le tabelle (`_tone_lut`, `auto_levels_lut`) si calcolano in Dart con le stesse formule e si passano allo shader come texture 256×1.
- Dettagli che contano: la luminosità di Pillow è una moltiplicazione; il contrasto mescola con il **grigio medio dell'immagine**
  (un numero per foto, da calcolare su una miniatura dopo i passi precedenti); la saturazione mescola con la luminanza 601;
  i livelli automatici si calcolano sulla foto intera ridotta a 400 px scartando lo 0,5% dei pixel per parte;
  il raggio della nitidezza dipende dalla scala (`detail_scale`) perché deve risultare uguale in anteprima e in esportazione.
- I 9 filtri pronti sono combinazioni di regolazioni: copiare i valori di `PRESETS`.
- Tutto deve finire in **sRGB**: provare con una foto iPhone in Display P3 e una con rotazione EXIF.
- Non serve l'identità al pixel con il desktop, ma la differenza non deve vedersi a occhio (§13).

### 8.5 Font

Il desktop usa i font del PC, che sul telefono non ci sono.

- Includere un insieme curato di font con licenza libera (15–25 famiglie: senza grazie, con grazie, da titolo, a mano, monospazio).
- Se un progetto usa un font assente: disegnare con quello predefinito, **lasciare il nome originale nel file** finché
  l'utente non lo cambia, e mostrare una nota nello strumento Carattere.
- Le misure del testo saranno leggermente diverse tra le due app: è accettato.

---

## 9. File e memoria sul telefono

- **Cartella del progetto** nello spazio privato dell'app: `progetti/<id>/progetto.scrlproj`, `cache/` (anteprime e miniature)
  e, solo se servono, `media/`.
- **Foto collegate, non copiate.** Le foto e i video scelti dalla galleria restano dove sono: il progetto ne salva
  l'identificativo di sistema (MediaStore su Android, PHAsset su iOS). Usare un pacchetto mantenuto che dia identificativi
  stabili su entrambe le piattaforme, da verificare prima di sceglierlo.
- **Permesso alla galleria.** Il collegamento stabile richiede il permesso di lettura della galleria. Chiederlo al primo
  «Aggiungi foto», con una riga che spiega il motivo. Gestire bene anche l'accesso **parziale** («solo le foto selezionate»
  di Android 14+ e iOS): l'app funziona con le foto concesse e offre «Scegli altre foto». Se il permesso è negato,
  si ripiega sul selettore di sistema e i file scelti vengono copiati in `media/`.
- **File fuori dalla galleria** (File, Drive, Download): non si possono collegare in modo stabile, quindi si copiano in `media/`.
- **Anteprima sempre salvata.** Di ogni foto collegata si tiene in `cache/` l'anteprima: se l'originale viene cancellato
  o spostato, la foto resta visibile sulla tela con il segno «Originale mancante». L'esportazione avvisa che quella foto
  uscirà alla qualità dell'anteprima, e propone il ricollegamento.
- **Controllo all'apertura.** Aprendo un progetto si verifica che ogni collegamento esista ancora; quelli rotti finiscono
  nell'elenco delle foto mancanti (§6).
- **Spazio**: i progetti pesano poco (solo anteprime). Mostrare comunque lo spazio occupato nella Home; eliminare un progetto
  elimina cache e `media/`, **mai** le foto della galleria. Avviso se lo spazio libero non basta per esportare o creare lo `.zip`.
- **Formati**: HEIC e i video dipendono dai decodificatori del telefono. Un file non leggibile non blocca gli altri:
  elenco degli scartati a fine importazione (come `_report_load_errors`).
- **Memoria**: mai tenere in memoria gli originali; una foto da 12 MP decodificata occupa circa 48 MB. Cache con limite
  in megabyte, svuotata quando il sistema segnala poca memoria.
- **Scambio**: «Condividi progetto» crea uno `.zip` completo (progetto + originali copiati in `media/`, vedi §7), con avanzamento
  e Annulla; l'importazione accetta `.zip` (le foto restano in `media/` dentro il progetto) o un `.scrlproj` da solo
  (in quel caso le foto risultano mancanti e parte il ricollegamento).
- **Permessi**: lettura della galleria e salvataggio nella galleria, chiesti solo quando servono.
- **Rete**: usata solo per il controllo degli aggiornamenti su GitHub (disattivabile). Nessun dato dell'utente esce dal telefono.

---

## 10. Video

È la parte più rischiosa: va **provata con un prototipo nella Fase 2**, prima di costruirci sopra.

- **Sulla tela**: copertina come immagine (fotogramma a `poster`); con Riproduci, i fotogrammi del video dentro il riquadro,
  con ritaglio, angoli e rotazione, senza audio, a ripetizione tra `trim_start` e `trim_end`.
- **Regole**: `VIDEO_FPS = 30`, `VIDEO_MAX_SECONDS = 60`, lato lungo massimo 1920 e misure pari (`output_size`),
  H.264 + AAC, audio 44,1 kHz stereo. La pagina dura quanto il video più lungo; i più corti ripartono; gli audio accesi si sommano.
- **Esportazione** (stesso schema di `_export_video_page`): lo strato sotto i video e quello sopra si disegnano una volta;
  a ogni fotogramma si ridisegnano solo i video e ciò che sta in mezzo, con lo **stesso modulo di disegno** dell'app;
  i fotogrammi vanno al codificatore del telefono.
- **Parte nativa** (`scrl_video`): informazioni sul file, lettura dei fotogrammi in sequenza, lettura dell'audio in PCM,
  scrittura dell'MP4 con i codificatori di sistema (MediaCodec su Android, AVFoundation su iOS).
  Prima di scriverla da zero, verificare se esistono pacchetti mantenuti che coprono i singoli pezzi;
  non affidarsi a pacchetti FFmpeg senza averne controllato stato e licenza.
- Se l'MP4 fallisce o viene annullato, il file a metà si elimina.
- Se a fine Fase 2 il prototipo non regge, **fermarsi e riferire all'utente** con le alternative: non degradare la funzione in silenzio.

---

## 11. Esportazione

- **Pagine separate**: scelta delle pagine dalle miniature, nome dei file (`nome_01.jpg`, predefinito `frame_01`),
  PNG o JPG, qualità 100 / 95 / 92 / 85 / 75 (predefinita 92), 1× o 2× (predefinito 2×). Le pagine con video diventano MP4.
- **Collage intero**: tutta la striscia in un'immagine; i video compaiono con la copertina.
  Le texture del telefono hanno un lato massimo: disegnare **a pezzi** (una pagina alla volta) e unirli nella codifica.
  Se l'immagine supera un limite ragionevole di pixel, proporre 1× o le pagine separate, come fa il desktop quando manca memoria.
- **Originali**: si leggono solo grandi quanto serve all'uscita, pochi alla volta, e si liberano subito (`_prefetch_originals`, `release_full`).
- **Avanzamento** con fasi (preparazione foto, pagina N di M, video) e Annulla; lo schermo resta acceso durante l'esportazione.
- **Destinazione**: Galleria (album «ScrolleR Studio»), foglio Condividi di sistema, Salva in File.
  Le pagine si salvano in ordine, così nella galleria restano in sequenza per il carosello.
- **Avvisi prima di partire**: foto mancanti, tela vuota.
- Preferenze ricordate tra una sessione e l'altra: formato, qualità, scala.

---

## 12. Fasi di lavoro

Ogni fase finisce con qualcosa che si può provare su un telefono Android vero, installando l'APK. Non iniziare una fase
se i criteri della precedente non sono soddisfatti. iOS si compila e si prova dalla Fase 9, ma **niente codice specifico
Android fuori dai punti previsti** (plugin video, accesso e salvataggio in galleria).

**Fase 0 — Fondamenta.** Progetto Flutter in `mobile/`, struttura del §5.1, analisi statica severa, tema e token,
testi localizzati (italiano e inglese), CI che esegue analisi e prove e, sui tag `mobile-v*`, costruisce l'APK firmato
e lo allega alla release GitHub. Script `tools/genera_riferimenti.py` che usa l'app desktop in
modalità `QT_QPA_PLATFORM=offscreen` per produrre i dati di riferimento (§13).
*Fatto quando:* l'app vuota si installa su Android dall'APK della release; la CI è verde; i dati di riferimento esistono.

**Fase 1 — Motore.** Modello, lettura/scrittura `.scrlproj`, disposizioni, pagine, cronologia, tutto in `scrl_engine`.
*Fatto quando:* le prove sulle disposizioni passano contro i riferimenti; un progetto desktop letto e riscritto dal motore
si riapre sul desktop identico; i campi sconosciuti sopravvivono.

**Fase 2 — Disegno, media e prototipo video.** Collegamento alla galleria con i suoi permessi, miniature, anteprime, disegno di una pagina in sola lettura
con foto, testi, forme, sfondo, sovrimpressioni. In parallelo il prototipo del §10: una pagina con un video esportata in MP4.
*Fatto quando:* un progetto desktop di prova si vede sul telefono come sul PC; il prototipo MP4 funziona su un telefono di fascia media
oppure l'utente è stato informato dell'esito.

**Fase 3 — Editor di base.** Home, nuovo progetto, tela a pagine, selezione, sposta/ridimensiona/ruota, aggancio,
Annulla/Ripeti, salvataggio automatico, libreria, pannello Disposizione.
*Fatto quando:* si crea un carosello di 5 pagine da 12 foto, si cambia disposizione, si chiude e riapre l'app senza perdere nulla.

**Fase 4 — Strumenti foto.** Inquadra, Ritaglio, Filtri, Regola, Effetti, Cornice, Ombra, Ruota, prima/dopo,
copia/incolla stile, applica a tutte.
*Fatto quando:* i cursori scorrono fluidi su una foto da 12 MP e il confronto con i riferimenti colore passa.

**Fase 5 — Testi e forme.** Tutti gli strumenti dei §6 «Testo» e «Forme», font inclusi, selettore colore.

**Fase 6 — Pagine e carosello.** Azioni di pagina, blocco, «a cavallo», Panoramica con riordino, sfondo,
numeri di pagina, «scorri», Anteprima, Cronologia, copia/incolla, gruppi, allinea e distribuisci, selezione multipla.

**Fase 7 — Esportazione immagini.** Pagine separate, collage intero, galleria, condivisione, avanzamento.
*Fatto quando:* la stessa pagina esportata da telefono e da PC ha le stesse dimensioni e nessuna differenza visibile.

**Fase 8 — Video completo.** Video sulla tela, Taglia, Copertina, Audio, pagine MP4, regola «dentro una pagina».

**Fase 9 — Scambio progetti e iOS.** Zip in entrata e in uscita, «Apri con», «Condividi con», foto mancanti e ricollegamento.
Poi iOS: build in CI, prove su iPhone (chiedere prima all'utente ciò che serve, §2.4).
*Fatto quando:* un progetto fatto sul telefono si apre sul PC dallo `.zip` e viceversa.

**Fase 10 — Rifinitura e rilascio.** Prestazioni, memoria, accessibilità, primo avvio, registro errori, icona,
avviso di nuova versione,
note di rilascio in italiano, release GitHub `mobile-v1.0.0` con l'APK, sezione nel `README.md`.
La pubblicazione negli store è fuori da questo piano finché l'utente non la chiede.

---

## 13. Prove

- **Riferimenti dal desktop.** Lo script della Fase 0 produce, per molte combinazioni (1–20 foto, tutti i formati,
  tutte le disposizioni e gli stili del mosaico, spaziature e margini diversi, pagine bloccate, pagine unite, foto libere),
  i rettangoli risultanti in JSON e alcune immagini esportate. Le prove Dart confrontano i rettangoli con tolleranza 0,001.
  **Attenzione:** le prove offscreen del desktop devono isolare `QSettings` (in passato hanno sporcato le impostazioni vere dell'utente).
- **Andata e ritorno del formato.** Progetti desktop reali → motore → file → desktop: nessuna differenza. Includere progetti vecchi senza i campi recenti.
- **Colore.** Per ogni filtro pronto e per ogni regolazione ai valori estremi: immagine del telefono contro quella del desktop,
  con soglia sulla differenza media.
- **Immagini campione dell'interfaccia** per i pannelli principali, a due larghezze di schermo.
- **Telefoni di prova.** Almeno un Android di fascia bassa (3–4 GB di RAM), uno recente, uno schermo piccolo, un iPhone.
- **Casi limite da provare a mano:** 60 foto in 10 pagine; foto da 48 MP; foto panoramica; PNG trasparente; HEIC in P3;
  video verticale con rotazione nei metadati; video senza audio; due video con audio sulla stessa pagina; app messa in secondo piano
  durante l'esportazione; spazio esaurito; telefonata durante l'esportazione; progetto con font e foto mancanti;
  foto cancellata dalla galleria con il progetto chiuso e con il progetto aperto; permesso alla galleria negato, parziale, revocato.
- **Obiettivi di prestazione:** apertura di un progetto da 30 foto sotto i 2 secondi con cache; gesti a 60 fps;
  risposta di un cursore colore sotto i 50 ms; esportazione di 10 pagine 2× sotto i 20 secondi su un telefono recente.

---

## 14. Da fare e da non fare

### Da fare

- Leggere il file Python di riferimento prima di scrivere ogni funzione del motore.
- Tenere il motore in Dart puro e provarlo senza interfaccia.
- Usare lo stesso codice di disegno per schermo ed esportazione.
- Dare a ogni campo letto un valore predefinito e conservare i campi sconosciuti.
- Creare un passo di cronologia per ogni modifica dell'utente (l'equivalente di `_schedule_commit`).
- Aggiungere ogni stato nuovo sia in lettura sia in scrittura, con valore predefinito.
- Prendere i colori solo dai token del tema.
- Scrivere testi dell'interfaccia, commenti e documentazione del codice in italiano, passando dai file di localizzazione.
- Mostrare avanzamento e Annulla per ogni operazione più lunga di un secondo.
- Tenere la pagina sempre visibile quando un pannello è aperto.
- Aggiornare il `README.md` (in inglese) con la sezione sull'app mobile.
- Controllare `git status` prima dei lavori grandi: un'altra sessione può lavorare sugli stessi file.
- Segnalare subito all'utente ogni funzione che non si riesce a portare, con le alternative.

### Da non fare

- **Non modificare** il codice in `scrollr/`, `packaging/`, `main.py` né il workflow desktop, salvo richiesta esplicita.
- **Non cambiare** `PROJECT_VERSION`, l'estensione `.scrlproj`, i nomi o il significato dei campi esistenti.
- **Non aggiungere campi obbligatori** al formato: tutto ciò che il mobile aggiunge deve essere ignorabile dal desktop.
- Non usare tag `v*` per i rilasci mobile.
- Non usare l'email dell'account Claude nei commit; non fare commit o push senza richiesta.
- Non copiare l'interfaccia desktop: niente pannelli laterali, menu a tendina, tooltip, finestre al centro.
- Non mettere scorrimento verticale dentro i pannelli degli strumenti.
- Non usare più di un colore d'accento, né colori scritti a mano nei widget.
- Non mettere logica di dominio nei widget.
- Non decodificare immagini o fare calcoli pesanti nel thread dell'interfaccia.
- Non tenere gli originali in memoria; non caricare tutte le pagine ad alta risoluzione insieme.
- Non fidarsi dei percorsi assoluti sul telefono.
- Non chiedere permessi non indispensabili né prima che servano; la rete serve solo al controllo degli aggiornamenti.
- Non pubblicare una release mobile come «latest» (§5.4).
- Non copiare nel progetto le foto della galleria (solo collegamento), e non cancellare mai nulla dalla galleria.
- Non preparare nulla per gli store (schede, identificativo definitivo, acquisti) finché l'utente non lo chiede.
- Non inserire pubblicità, tracciamento o account.
- Non togliere o ridurre una funzione in silenzio per farla stare nei tempi.
- Non dichiarare finita una fase senza averla provata su un telefono vero.
- Non scegliere un pacchetto esterno senza controllarne manutenzione, licenza e supporto a entrambe le piattaforme.

---

## 15. Rischi

| Rischio | Effetto | Contromisura |
|---|---|---|
| Esportazione MP4 lenta o instabile | La funzione video slitta | Prototipo in Fase 2; fase video separata (8) che può uscire in un aggiornamento |
| Colori diversi dal desktop | Progetti che cambiano aspetto tra le app | Formule portate alla lettera, prove con riferimenti, soglia concordata |
| Memoria insufficiente con tante foto | Chiusure improvvise | Livelli di dettaglio, cache con limite, prova su telefono di fascia bassa già in Fase 3 |
| Limite di dimensione delle texture | Collage intero impossibile | Disegno a pezzi, limite con proposta di alternativa |
| iOS non provabile su Windows | Difetti scoperti tardi | CI macOS dalla Fase 9, codice di piattaforma ridotto al minimo, iPhone di prova |
| Font diversi tra le app | Testi che si spostano | Font inclusi, nome originale conservato, differenza accettata e dichiarata |
| Troppe funzioni per uno schermo piccolo | Interfaccia confusa | Barra contestuale, un parametro alla volta, prova con utenti reali a fine Fase 4 e 6 |
| Foto collegate cancellate o spostate dalla galleria | Progetti con foto mancanti | Anteprima sempre salvata, controllo all'apertura, ricollegamento per nome, avviso prima di esportare |
| Permesso alla galleria negato o parziale | Impossibile collegare le foto | Spiegazione prima della richiesta, accesso parziale gestito, ripiego sulla copia in `media/` |
| Identificativi della galleria diversi tra telefoni | Un progetto non si sposta da un telefono all'altro col solo `.scrlproj` | Lo scambio passa sempre dallo `.zip` completo |

---

## 16. Dopo la v1

Pubblicazione su Google Play e App Store; tablet e orizzontale con pannelli laterali; tastiera fisica con le scorciatoie del desktop; tema chiaro;
sincronizzazione tra dispositivi; modelli di carosello pronti; apertura dello `.zip` direttamente dal desktop
(richiede una modifica al desktop, da concordare).
