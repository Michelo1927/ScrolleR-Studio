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
  - PC: finestra `NewProjectDialog` (`scrollr/dialogs.py`) a File → Nuovo progetto, carosello a sinistra con il campo Pagine e reel a destra. All'avvio l'app apre un carosello, come prima.
  - Telefono: primo passo di «Nuovo progetto», carosello sopra e reel sotto.
- **Conversione** (un passo di Annulla).
  - PC: File → Converti in reel / in carosello. Telefono: Pagine → Formato.
  - In reel solo con una pagina: altrimenti un avviso chiede di togliere le altre.
  - In carosello i video più lunghi di 60 s usano il primo minuto, dall'inizio del taglio.
- **Durata dei video.** Con Inizio e Fine si sceglie la parte da mostrare: oltre il massimo l'altro estremo segue.
  - Il PC accorcia anche i video aggiunti, e quelli dei progetti vecchi all'apertura.
  - Il telefono accorcia solo con i cursori e nella conversione. Negli altri casi l'MP4 si ferma comunque al massimo, quindi esce identico.
- **Zona sicura.** Fasce del 14% in alto, 35% in basso e 6% ai lati: misure diffuse, non ufficiali di Meta. Non entra mai nell'esportazione.
  - Codice: `reel_safe_rect` in `scrollr/canvas/scene.py`, `zonaSicuraReel` nel motore.
- **Riferimenti mobile** rigenerati con `genera_riferimenti.py`: cambiano solo `project_type` e alcuni semi casuali.

**Da provare sul Pixel 7:**
- nuovo reel, conversione nei due sensi, guida;
- esportazione di un video da 5 minuti: l'audio sta tutto in memoria, circa 53 MB per traccia.

## 1. Sottotitoli automatici (deciso, prossimo lavoro)

Trascrizione **offline** con **whisper.cpp**, la stessa su PC e telefono: stesso modello, stesso risultato, audio mai fuori dal dispositivo.

### Scelte decise
- **Stile della prima versione:** frasi corte, una o due righe che cambiano. I tempi delle singole parole si salvano già, per poter aggiungere più avanti lo stile «parola evidenziata».
- **Lingua:** italiano proposto, ma si può sceglierne un'altra o lasciarla riconoscere al modello.
- **Modello:** scaricato alla prima trascrizione da una release GitHub di questa repo, non incluso nell'installer.
  - Tag dedicato, per esempio `modelli-whisper-1`: mai `v*` né `mobile-v*`.
  - Release mai segnata «latest»: il desktop cerca gli aggiornamenti su `releases/latest`.
- **Modello predefinito:** `ggml-small-q5_1.bin` (190 MB). Pulsante per cancellarlo.
- **Un blocco di sottotitoli per video.** Si sposta e si stila come un testo.
- **Nell'MP4 i sottotitoli sono dentro l'immagine.** Import ed export `.srt` come extra.

### Numeri (stime da verificare nella prova S1)
| | PC (i5-13500H) | Pixel 7 |
|---|---|---|
| Peso aggiunto all'app | +8–12 MB installer, +25–35 MB installata | +3–5 MB APK |
| Modello small | 190 MB su disco, ~0,5–0,8 GB di memoria mentre trascrive | uguale |
| 60 s di video | ~10–20 s | ~40–90 s (con «base» ~15–30 s) |

### Passi
1. **S1 – Prova del motore (PC).**
   - Fuori dall'app, `pywhispercpp` + modello small su un video italiano dell'autore.
   - Misurare qualità, tempi e memoria.
   - Decidere se «small» basta.
2. **S2 – Desktop.**
   - Elemento `CaptionItem`, sottoclasse di `TextItem`, collegato al video: frasi con inizio, fine e testo, più i tempi delle parole, nei tempi del video originale.
   - Sulla tela mostra la frase della copertina o della riproduzione.
   - Finestra «Sottotitoli» per correggere testo e tempi, unire, dividere, aggiungere e togliere frasi.
   - Nell'esportazione MP4 il testo cambia fotogramma per fotogramma: va ridisegnato con lo strato di mezzo in `_export_video_page`.
   - Posizione predefinita: in basso dentro la zona sicura reel sulle pagine 9:16.
   - `get_state`/`set_state` con default; Annulla/Ripeti.
3. **S3 – Download del modello e build.**
   - Download con avanzamento e annullamento.
   - Controllo della build con PyInstaller, su Windows e Mac.
4. **S4 – Telefono, motore.**
   - whisper.cpp compilato nel plugin `scrl_video` (CMake/NDK, arm64 prima di tutto).
   - Audio a 16 kHz mono da `LettoreAudio.kt`.
   - Modello dati nel motore, confrontato col desktop con i riferimenti.
5. **S5 – Telefono, interfaccia.**
   - Strumento Sottotitoli in stile Snapseed, modifica delle frasi, disegno in `disegno.dart`, esportazione MP4.
6. **S6 – Prova sul Pixel 7 e rilascio** (desktop 1.12.0, mobile 1.3.0).

## 2. Musica di sottofondo (deciso, dopo i sottotitoli)

Una traccia audio per la pagina video: si sceglie un file (mp3, m4a, wav).
- Regolazioni: taglio, volume, dissolvenza in entrata e in uscita.
- Si mescola con l'audio dei video non muti, con un volume per ciascuno.
- Lettura con PyAV sul PC e con `MediaExtractor` sul telefono, già usati per l'audio dei video.

## 3. Idee aperte (da decidere)

- **Linea del tempo** (clip una dopo l'altra). Più avanti, senza posto fisso. È un lavoro grande.
- **Sagoma automatica** con l'AI: propone i punti, l'utente li corregge.
- **Rifinitura grafica mobile**: `docs/brief-grafico-app-mobile.md`.

## 4. Fermo

- **iOS.** Compila in CI (mobile 1.0.1 e 1.0.2) ma non è mai stato provato su un iPhone. Le funzioni nuove sono solo per Android e PC.
- Il job `ios` sui tag a volte viene annullato perché GitHub non assegna una macchina macOS. Si rilancia con «Re-run failed jobs».
