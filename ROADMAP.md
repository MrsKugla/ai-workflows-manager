# Roadmap

Stato verificato il 17/11/2026 sul codice della 0.5.1, su Tern 0.9.26 e sulle 27 skill di `mattpocock/skills` installate in `~/.agents/skills`.

## Fatto

| Fase | Versione | Cosa |
|---|---|---|
| F1 · Workflow | 0.1.0–0.3.0 | Home dei problemi, 11 situazioni, checklist dei passi, copia di `/skill:<nome>` negli appunti, sessione omp collegata, «Configura repo», archivio, problemi in `.ai-workflows/problems.json` |
| Controllo dei segreti | 0.4.0 | Fascia «Possibili segreti» su `.scratch/` e `problems.json`, con «Apri» e «Ignora». Solo avviso: non blocca il commit |
| Pubblicazione | 0.5.0 | Nome `ai-workflows-manager`, cartella `.ai-workflows/`, README con crediti, licenza MIT |

## Prossimi passi, in ordine

### 1. Prova su un repo vero (T3)

In un repo di prova: «Configura repo» → `/skill:setup-matt-pocock-skills` con tracker «Local markdown», poi una spec (`to-spec`) e tre ticket (`to-tickets`). Serve come banco di prova per la F2: oggi nessun repo ha ticket locali.

### 2. Interfaccia nel pane stretto (critica UI della 0.2.0)

Dieci problemi ancora aperti nel pane da 68 colonne; «1 passi» è già corretto nella 0.3.0.

- **Bloccano o confondono (P1)**
  - La barra della Home non ci sta: «Aggiorna» è tagliato.
  - Le colonne Workflow e Sessione spariscono: un problema senza workflow non dice cosa fare.
  - Il prossimo passo da fare non si distingue dagli altri.
  - Nella scelta della situazione la colonna «Quando» è nascosta: restano solo i titoli.
- **Rallentano (P2)**
  - «Apri» primario su ogni riga compete con «Nuovo problema».
  - La testata della Home occupa un terzo del pane.
  - «Collega» sembra l'azione principale del workflow.
  - Il pulsante «Configura repo» nel passo 1 allarga la colonna.
- **Rifiniture (P3)**
  - La data «fatto 2026-11-14 21:01» è troppo lunga.
  - Il pulsante 📋 ha solo l'icona.

### 3. F2 · Ticket e roadmap

Legge il formato del tracker locale delle skill, senza modificarlo:

- un file per ticket in `.scratch/<nome>/issues/NN-<slug>.md`, con le righe `Status:` e `Blocked by:`;
- la mappa in `.scratch/<nome>/map.md` (scritta da `wayfinder`).

Viste:

- **Navigatore**: elenco a sinistra (numero, titolo, stato, blocchi) e dettaglio a destra. Azioni: Modifica (editor di Tern), Stato (cambia la riga `Status:`), Implementa (copia `/skill:implement <file del ticket>`).
- **Roadmap**: calcolata dai ticket, con corsie Bloccati / Pronti / In corso / Fatti e barra di avanzamento.

Con un repo su GitHub il blocco mostra «Tracker: GitHub» e il link alle issue, senza roadmap.

### 4. F3 · Conoscenza

Vista di sola lettura su `docs/adr/` (in ordine di numero) e su `GLOSSARY.md`, con ricerca. Nei repo con più contesti legge `GLOSSARY-MAP.md` e `src/<contesto>/docs/adr/`.

### 5. F4 · Grill interattivo

- Prima si scrive un'istruzione per l'`AGENTS.md` del repo (T6): ogni domanda del grill va anche in `.scratch/<nome>/grill.json`, con domanda, contesto, opzioni, opzione consigliata e figura facoltativa.
- Il blocco mostra una card per domanda, con radio e note.
- «Copia risposte» mette negli appunti il riassunto da incollare all'agente.
- Le figure sono PNG o SVG: la prova T5 conferma che il blocco li mostra.

### 6. F5 · Ticket GitHub in sola lettura

Come la F2, ma legge le issue con `gh`. Richiede l'installazione di `gh`.

## Idee non pianificate

- Scorciatoia da tastiera per aprire il blocco (`tern.bind` in `window.luau`): i tasti sono da scegliere.
- Editor visuale per `.ai-workflows/workflows.json`: oggi si modifica il JSON.
- Blocco dei commit con segreti (hook pre-commit): scartato per ora, il controllo resta un avviso.
