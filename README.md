# ai-workflows-manager

Plugin per [Tern](https://tern.sh) che guida l'uso delle skill di Matt Pocock in un repository: scegli la situazione, segui i passi del workflow, copia le invocazioni `/skill:<nome>` nel pane dell'agente e tieni traccia dei problemi aperti. Il plugin ripropone solo le indicazioni e le opzioni di Matt: non aggiunge un suo processo.

## Cosa fa

- **Problemi**: titolo, nome breve e descrizione, salvati in `.ai-workflows/problems.json` nel repo. La cartella in `.scratch/` la sceglie la skill; il blocco la ritrova dopo il passo e la collega al problema.
- **Workflow**: 11 situazioni predefinite (`workflows.json`); una copia in `.ai-workflows/workflows.json` del repo le sostituisce.
- **Passi**: la casella segna il passo fatto; il pulsante 📋 copia l'invocazione come la scrive Matt. Il prossimo passo è evidenziato.
- **Guida al flusso**: tra un passo e l'altro le indicazioni di Matt sulla sessione (continua, `/clear`, sessione nuova); il bivio dopo il grill (una sessione, più sessioni, strada non chiara); le deviazioni durante il grill (`prototype`, `to-questionnaire`, `research`); l'avviso «rileggi la spec» prima di `to-tickets`.
- **Sessione collegata**: sceglie un agente omp aperto in Tern, o ne apre uno nuovo nella cartella.
- **Configura repo**: copia `/skill:setup-matt-pocock-skills` e, per GitHub o GitLab, i comandi per le etichette che il setup non crea.
- **Controllo dei segreti**: avvisa se `.scratch/` o `problems.json` contengono password, token o chiavi. Non blocca il commit.

Il plugin non esegue comandi git e non crea cartelle in `.scratch/`: quelle le scrivono le skill.

## Installazione

1. Installa le skill: `npx skills@latest add mattpocock/skills -g -a codex`.
2. Collega il plugin: `tern plugin link <cartella del plugin>`.
3. In Tern apri la palette e scegli «AI Workflows: apri».

Le versioni sono in `versioni.txt`; i prossimi passi in `ROADMAP.md`.

## Crediti

Questo plugin guida l'uso delle skill di Matt Pocock
(https://github.com/mattpocock/skills, licenza MIT, © 2026 Matt Pocock)
e segue il flusso descritto su https://www.aihero.dev/skills.
I testi di `workflows.json` sono riassunti in italiano di quelle fonti.

Progetto indipendente: non è affiliato né approvato da Matt Pocock o AI Hero.
