# Agent instructions

## Versioning (mandatory)

Every implementation you add or change MUST bump the project version following [Semantic Versioning 2.0.0](https://semver.org) and MUST be recorded in `versioni.txt` in the project root.

### Choosing the bump

Version format: `MAJOR.MINOR.PATCH`.

- **MAJOR**: incompatible changes. Examples: files, data or settings saved by older versions can no longer be read; a public API, command, file format or configuration key is removed or changes meaning; existing user data needs a migration that cannot be undone.
- **MINOR**: new functionality that keeps backward compatibility. Examples: a new feature, view, command, option or setting.
- **PATCH**: backward-compatible bug fixes and small corrections with no new functionality.

Rules:

- Bumping MINOR resets PATCH to 0. Bumping MAJOR resets MINOR and PATCH to 0.
- While MAJOR is `0`, the public contract is still unstable. Use MINOR for breaking changes as well, and PATCH for everything else. Tell the user explicitly when a change breaks compatibility.
- `1.0.0` is released only when the user declares the project stable.
- Use one version per completed implementation or task, not one per edited file. Do not bump for changes that only touch docs or comments: add those to the next real version entry.
- Never reuse or rewrite a version number that is already in `versioni.txt`.
- Explain the chosen bump to the user in one line.

### Where the version lives

- The current version is the first entry of `versioni.txt`.
- Every other place that stores or displays the version MUST contain the same string and be updated together with `versioni.txt`. Typical locations: package manifests (`package.json`, `Cargo.toml`, `pyproject.toml`, `*.csproj`, `build.gradle`, `mod.info`…), app or bundle configuration (`tauri.conf.json`, `AndroidManifest.xml`…), version constants in code, and version numbers shown in the UI or written into exported files.
- If the project has version locations, list them here so they are never missed:
  - `plugin.toml`: campo `version`
  - `host.luau`: costante `VERSION`, mostrata nella riga «Versione» della Home del blocco
- After editing a manifest that has a lock file, let the package manager refresh the lock file instead of editing it by hand.
- If the UI shows the version, check that the displayed `vX.Y.Z` matches.

### Changelog: `versioni.txt`

- Location: `versioni.txt` in the project root. Create it if it is missing.
- Language: **Italian**.
- Order: newest version at the **top**.
- Date: the day the version was completed, in `dd/mm/yyyy` format.
- Content: a short **summary** of what changed for the user or the project, 1–5 lines per version. Describe changes, not files: never start a line with a file name followed by a colon. Merge related edits into one line.
- Files: optionally end a line with the main files involved, in parentheses, as paths relative to the project root (`(file: src/a.ts, src/b.rs)`). List only files that contain substantial source code. Never list generated, build, temporary, lock or binary files (build output folders, `*.lock`, `package-lock.json`, installers, packages), and do not list version-number edits.
- Indentation: 4 spaces before each `- `.
- Leave one blank line between versions.

Exact format:

```text
MAJOR.MINOR.PATCH - [dd/mm/yyyy]
    - riepilogo della modifica x (file: percorso/principale.ext)
    - riepilogo della modifica k
```

Example:

```text
0.2.0 - [08/10/2026]
    - Esportazione dei dati in un file ZIP, con conferma prima di sovrascrivere (file: src/export.ts)
    - Nuova impostazione per scegliere la cartella di destinazione

0.1.1 - [07/10/2026]
    - Corretto l'allineamento della tabella su schermi stretti (file: src/components/Table.svelte)
```

### Git

Git operations (staging, commits, tags, branches, pushes) are performed by the user only. Agents MUST NOT run state-changing Git commands; read-only commands such as `git status`, `git diff` or `git log` are allowed.

### Definition of done

A task is not complete until all of these are true:

1. `versioni.txt` has a new entry at the top for the new version.
2. That entry summarizes every user-visible or structural change in the version.
3. Every version location listed above contains the same version.
4. `ROADMAP.md`, and `docs/roadmap/data.js` when present, reflect the change.

## Roadmap

`ROADMAP.md` is the single source of truth for done and upcoming work. Update it in the same task whenever a step is completed, added, reordered or dropped.

If `docs/roadmap/data.js` exists (local only, `docs/` is git-ignored), it is the visual view of `ROADMAP.md`: update it in the same task with the `roadmap-viewer` skill, flow B, so both say the same thing. Entries in its `changelog` with `synced: false` are the user's edits from the browser: carry them into `ROADMAP.md` first.

`docs/plugin-tern-skill-flow-fattibilita.html` is the archive of the design decisions: it holds no roadmap.
