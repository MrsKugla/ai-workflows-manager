# Roadmap

Stato verificato il 18/11/2026 sul codice della 0.6.2, su Tern 0.9.26 e sulle 27 skill di `mattpocock/skills` installate in `~/.agents/skills`.

## Fatto

| Fase | Versione | Cosa |
|---|---|---|
| F1 · Workflow | 0.1.0–0.3.0 | Home dei problemi, 11 situazioni, checklist dei passi, copia di `/skill:<nome>` negli appunti, sessione omp collegata, «Configura repo», archivio, problemi in `.ai-workflows/problems.json` |
| Controllo dei segreti | 0.4.0 | Fascia «Possibili segreti» su `.scratch/` e `problems.json`, con «Apri» e «Ignora». Solo avviso: non blocca il commit |
| Pubblicazione | 0.5.0–0.5.1 | Nome `ai-workflows-manager`, cartella `.ai-workflows/`, README con crediti, licenza MIT, ROADMAP.md; pubblicato su GitHub il 17/11 |
| Prova su un repo vero (T3) | 18/11 | Setup, grill, `to-spec`, `to-tickets` in `Tools/ai-workflows-example`. Risultati: la cartella in `.scratch/` la sceglie la skill anche se il prompt la indica; i ticket hanno `**Blocked by:**` e `**Status:**` in grassetto; `to-tickets` considera approvate le regole aggiunte da `to-spec` se non rispondi |
| Plugin fedele a Matt | 0.6.0 | Controllo una tantum contro i documenti di [mattpocock/skills](https://github.com/mattpocock/skills/tree/main/docs): prompt come li scrive Matt; note, passi e decisioni corretti; indicazioni sulla sessione tra un passo e l'altro (continua, `/clear`, sessione nuova); prossimo passo evidenziato; avviso «rileggi la spec» prima di `to-tickets`; deviazioni durante il grill (`prototype`, `to-questionnaire`, `research`); bivio dopo il grill (una sessione, più sessioni, strada non chiara → `handoff` verso `wayfinder`); cartella `.scratch/` ritrovata dopo il passo; «Configura repo» che copia solo il comando; etichette di riserva per `gh` e `glab` |
| Prossima prova | 0.6.1 | In `Tools/ai-workflows-example`: `implement 01` scrive il codice senza commit (il ticket lo chiudi tu, vedi F2); il bivio «Strada non chiara» passa a `wayfinder` e il passo 2 chiede di leggere prima il file di handoff |
| F2 · Ticket e grafo | 0.7.0 | Schermata «Ticket» dal workflow: grafo SVG (riquadro = `to-tickets`, ovale = `wayfinder`, frecce da `Blocked by:`, colori da `Status:`), elenco e dettaglio. Modifica apre il file; la casella «fatto» scrive `Status: done` e avvisa se restano criteri non spuntati; stati presi da `docs/agents/triage-labels.md`; Implementa copia `/skill:implement NN` e avvisa se il ticket è bloccato; «Implementa tutta la spec». I ticket di wayfinder non hanno Implementa. Legge le righe in grassetto e semplici; scrive solo `Status:` |

## Prossimi passi, in ordine

### 1. F3 · Conoscenza

Vista di sola lettura su `docs/adr/` (in ordine di numero) e su `GLOSSARY.md`, con ricerca. Nei repo con più contesti legge `GLOSSARY-MAP.md` e `src/<contesto>/docs/adr/`; legge anche i vecchi `CONTEXT.md` / `CONTEXT-MAP.md`. Se i file non esistono mostra uno stato vuoto, senza invitare a crearli (Matt: «Don't flag their absence»).

### 2. Interfaccia nel pane stretto (critica UI della 0.2.0)

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
- **Grafo dei ticket (F2)**
  - Titoli tagliati a circa 20 caratteri («Quale formato pe…»). Richiesta del 18/11: il riquadro diventa più alto e il titolo va a capo; se servirebbero più di 3 righe, il riquadro si allarga un po' per stare in 2, al massimo 3.

### 3. GitHub: F5 e prova del tracking

Ultimo passo: per ora le prove si fanno solo con il tracker locale (decisione del 18/11).

- **F5 · Ticket GitHub in sola lettura**: come la F2, ma legge le issue con `gh`. Richiede l'installazione di `gh`.
- `setup` crea le etichette? Se sì, togli dal pulsante di riserva le cinque di triage.
- Con un repo su GitHub il blocco mostra «Tracker: GitHub» e il link alle issue, al posto della schermata «Ticket».

## Idee non pianificate

- Scorciatoia da tastiera per aprire il blocco (`tern.bind` in `window.luau`): i tasti sono da scegliere.
- Editor visuale per `.ai-workflows/workflows.json`: oggi si modifica il JSON.
- Blocco dei commit con segreti (hook pre-commit): scartato per ora, il controllo resta un avviso.

## Idee archiviate

- **Grill interattivo (ex F4, punti C4 e C5)**, archiviato il 17/11/2026: card, `grill.json`, `grill.md` o questionario HTML per rispondere alle domande del grill. Matt Pocock esclude in modo esplicito le interfacce strutturate per il grill ([native-question-tool.md](https://github.com/mattpocock/skills/blob/main/.out-of-scope/native-question-tool.md)): le domande restano testo in chat e le decisioni passano a `to-spec` nella stessa conversazione.
