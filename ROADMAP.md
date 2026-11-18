# Roadmap

Stato verificato il 18/11/2026 sul codice della 0.6.0, su Tern 0.9.26 e sulle 27 skill di `mattpocock/skills` installate in `~/.agents/skills`.

## Fatto

| Fase | Versione | Cosa |
|---|---|---|
| F1 · Workflow | 0.1.0–0.3.0 | Home dei problemi, 11 situazioni, checklist dei passi, copia di `/skill:<nome>` negli appunti, sessione omp collegata, «Configura repo», archivio, problemi in `.ai-workflows/problems.json` |
| Controllo dei segreti | 0.4.0 | Fascia «Possibili segreti» su `.scratch/` e `problems.json`, con «Apri» e «Ignora». Solo avviso: non blocca il commit |
| Pubblicazione | 0.5.0–0.5.1 | Nome `ai-workflows-manager`, cartella `.ai-workflows/`, README con crediti, licenza MIT, ROADMAP.md; pubblicato su GitHub il 17/11 |
| Prova su un repo vero (T3) | 18/11 | Setup, grill, `to-spec`, `to-tickets` in `Tools/ai-workflows-example`. Risultati: la cartella in `.scratch/` la sceglie la skill anche se il prompt la indica; i ticket hanno `**Blocked by:**` e `**Status:**` in grassetto; `to-tickets` considera approvate le regole aggiunte da `to-spec` se non rispondi |
| Plugin fedele a Matt | 0.6.0 | Controllo una tantum contro i documenti di [mattpocock/skills](https://github.com/mattpocock/skills/tree/main/docs): prompt come li scrive Matt; note, passi e decisioni corretti; indicazioni sulla sessione tra un passo e l'altro (continua, `/clear`, sessione nuova); prossimo passo evidenziato; avviso «rileggi la spec» prima di `to-tickets`; deviazioni durante il grill (`prototype`, `to-questionnaire`, `research`); bivio dopo il grill (una sessione, più sessioni, strada non chiara → `handoff` verso `wayfinder`); cartella `.scratch/` ritrovata dopo il passo; «Configura repo» che copia solo il comando; etichette di riserva per `gh` e `glab` |

## Prossimi passi, in ordine

### 1. Prossima prova

- Su un repo GitHub: `setup` crea le etichette? Se sì, togli dal pulsante di riserva le cinque di triage.
- Prova il bivio «Strada non chiara»: il testo copiato (`/skill:handoff per continuare con /wayfinder: …`) porta davvero a `wayfinder`? Fatto il 18/11: sì, `handoff` scrive il file in `%TEMP%` e indica `/wayfinder` come passo successivo; il workflow passa a «Iniziativa enorme e incerta». Il buco trovato (il passo `wayfinder` non diceva di leggere il file di handoff) è corretto nella 0.6.1: da verificare copiando il passo 2.
- Prova `implement 01` sui ticket di `ai-workflows-example` (serve `git init` nella cartella). Fatto il 18/11: il codice c'è, senza commit; il ticket 01 l'ha chiuso l'agente per una regola che avevo fatto aggiungere io in `issue-tracker.md`, poi tolta (vedi F2, «Chiudere un ticket»).

### 2. F2 · Ticket e roadmap

Legge il formato del tracker locale delle skill, senza modificarlo:

- un file per ticket in `.scratch/<nome>/issues/NN-<slug>.md`, con le righe `Status:` e `Blocked by:` in tutte e due le forme che le skill scrivono (in grassetto da `to-tickets`, semplici da `wayfinder`), e «None»;
- la mappa in `.scratch/<nome>/map.md` (scritta da `wayfinder`).

Viste:

- **Navigatore**: elenco a sinistra (numero, titolo, stato, blocchi) e dettaglio a destra. Azioni: Modifica (editor di Tern), Stato (valori presi da `docs/agents/triage-labels.md`; sui ticket di `to-tickets` niente `needs-triage`/`needs-info`), Implementa (copia `/skill:implement <NN>`, segnala i ticket bloccati). Sui ticket di wayfinder (riga `Type:`) niente Implementa: sono decisioni. Sulla spec: «Implementa tutta la spec» (`/skill:implement-spec`).
- **Grafo dei ticket** (approvato il 18/11, sostituisce le corsie): un riquadro per ticket, frecce dalle righe `Blocked by:`, colori dalle righe `Status:` (fatto, pronto per l'agente, serve una persona o mancano info, bloccato, wontfix). Immagine SVG nel blocco tramite `cx:blob` (verificato con T5); le azioni stanno nell'elenco accanto. I ticket di wayfinder hanno una forma diversa. Uno stato fuori dall'elenco di Matt si mostra come «stato non standard».
- **Chiudere un ticket** (decisione del 18/11): Matt scrive «implement non chiude il ticket: chiudilo tu e spunta i criteri» ([implement.md](https://github.com/mattpocock/skills/blob/main/docs/engineering/implement.md)), ma per il tracker locale non dice come e non ha uno stato finale. Nel navigatore ogni ticket ha una casella «fatto»: la spunti tu e il plugin scrive `Status: done` nel file. Nessuna regola in `issue-tracker.md`: il ticket non lo chiude l'agente.

Con un repo su GitHub il blocco mostra «Tracker: GitHub» e il link alle issue, senza roadmap.

### 3. F3 · Conoscenza

Vista di sola lettura su `docs/adr/` (in ordine di numero) e su `GLOSSARY.md`, con ricerca. Nei repo con più contesti legge `GLOSSARY-MAP.md` e `src/<contesto>/docs/adr/`; legge anche i vecchi `CONTEXT.md` / `CONTEXT-MAP.md`. Se i file non esistono mostra uno stato vuoto, senza invitare a crearli (Matt: «Don't flag their absence»).

### 4. F5 · Ticket GitHub in sola lettura

Come la F2, ma legge le issue con `gh`. Richiede l'installazione di `gh`.

### 5. Interfaccia nel pane stretto (critica UI della 0.2.0)

In fondo, dopo le fasi che cambiano le schermate (decisione del 18/11): sistemare prima la UI vorrebbe dire rifarla. Restano le correzioni urgenti di struttura, quando servono.

Otto problemi ancora aperti nel pane da 68 colonne. Corretti: «1 passi» (0.3.0), prossimo passo evidenziato e data corta (0.6.0).

- **Bloccano o confondono (P1)**
  - La barra della Home non ci sta: «Aggiorna» e «Archivio» sono tagliati.
  - Le colonne Workflow e Sessione spariscono: un problema senza workflow non dice cosa fare.
  - Nella scelta della situazione la colonna «Quando» è nascosta: restano solo i titoli.
- **Rallentano (P2)**
  - «Apri» primario su ogni riga compete con «Nuovo problema».
  - La testata della Home occupa un terzo del pane.
  - «Collega» sembra l'azione principale del workflow.
  - Il pulsante «Configura repo» nel passo 1 allarga la colonna.
  - In «Configura repo» la scritta «Installate in ~/.agents/skills» va a capo su quattro righe.
- **Rifiniture (P3)**
  - Il pulsante 📋 ha solo l'icona.

## Idee non pianificate

- Scorciatoia da tastiera per aprire il blocco (`tern.bind` in `window.luau`): i tasti sono da scegliere.
- Editor visuale per `.ai-workflows/workflows.json`: oggi si modifica il JSON.
- Blocco dei commit con segreti (hook pre-commit): scartato per ora, il controllo resta un avviso.

## Idee archiviate

- **Grill interattivo (ex F4, punti C4 e C5)**, archiviato il 17/11/2026: card, `grill.json`, `grill.md` o questionario HTML per rispondere alle domande del grill. Matt Pocock esclude in modo esplicito le interfacce strutturate per il grill ([native-question-tool.md](https://github.com/mattpocock/skills/blob/main/.out-of-scope/native-question-tool.md)): le domande restano testo in chat e le decisioni passano a `to-spec` nella stessa conversazione.
