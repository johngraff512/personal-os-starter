# Brainiac — shared schema and routing

Personal & work knowledge base. Two vaults (`personal/`, `work/`), each with its own `CLAUDE.md`, `index.md`, and inbox. This file holds the rules that apply across both.

## What this is

A file-system knowledge base inspired by Karpathy's LLM-Wiki pattern and built on Ben Bentzin's `knowledge-base` skill conventions. **Plain markdown is the source of truth.** No DB, no embeddings, no RAG. The `/kb` skill ingests, summarizes, and indexes; Claude reads from `index.md` plus the relevant `_summary.md` / `_text.md` files at query time.

## Capture paths (read-only summary — see plan for details)

- `aa-inbox/` (top-level, this folder) — drop zone for "I'll route it later." `/kb` proposes a vault when it processes.
- `personal/aa-inbox/`, `work/aa-inbox/` — direct vault inboxes from Mac Web Clipper (writes here directly), Finder drag-drop, and `/kb pull`.
- `personal/aa-inbox/urls.txt`, `work/aa-inbox/urls.txt` — append-only URL drop targets from iOS Shortcuts (works for open content; gated content requires Web Clipper).
- `personal/ideas.md`, `work/ideas.md` — append-only idea logs from voice-triggered iOS Shortcuts.
- **iOS/iPadOS Web Clipper** → writes to `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/<vault>/aa-inbox/` (iCloud-synced "transit vaults" named `personal` and `work`, mirroring brainiac's vaults). The `com.<you>.<kb>.icloud-pull` LaunchAgent ferries new clips into `<vault>/aa-inbox/` every 5 min. iPhone Obsidian only sees iCloud-namespaced vaults — brainiac itself can't be opened from iOS, so the transit-vault pattern is the bridge.

## LaunchAgent infrastructure

Two LaunchAgents handle background work. **All scripts run from `~/.local/bin/` and log to `~/Library/Logs/brainiac/`** — macOS TCC blocks launchd from executing scripts in `~/Documents/` and from appending to logs there. Source-of-truth scripts live in `.scripts/`; runtime copies are kept in sync via `cp` after edits.

| LaunchAgent | Script source | Runtime path | Schedule | Purpose |
|---|---|---|---|---|
| `com.<you>.<kb>` | `.scripts/process-inbox.sh` | `~/.local/bin/brainiac-process-inbox.sh` | 6:30 AM daily | DOCX/PPTX → PDF, parse PDFs (Anthropic vision), git auto-commit/push |
| `com.<you>.<kb>.icloud-pull` | `.scripts/bridge-icloud.sh` | `~/.local/bin/brainiac-icloud-pull.sh` | Every 5 min | Move iOS Web Clipper output from iCloud transit vaults into brainiac inboxes |

## Processing — `/kb` skill modes

| Mode | What it does |
|---|---|
| `/kb` | Process inbox(es) in the current working vault, or both if run from `brainiac/` |
| `/kb ask <q>` | Answer from index + summaries, with citations. Consults `crossrefs.md` for external KBs |
| `/kb update` | Sync index with disk, health-check, propose topic-drift merges |
| `/kb ideas` | Promote new lines in `ideas.md` to rules / topic notes / blog seeds / kept-as-is |
| `/kb pull <path>` | Selectively copy an external file (e.g. OneDrive) into the work vault and index it |
| `/kb archive scan` | Refresh `work/course-archive-index.md` against the OneDrive Teaching folder |
| `/kb sync` | `git add . && git commit && git push` to the brainiac private repo |

## Per-item flow

1. Detect type (URL / PDF / DOCX / PPTX / MD / image).
2. **Extract → `_text.md`** (faithful):
   - **PDF** → `.scripts/parser/parse_pdf.py` (vision-LLM, HTML tables for merged cells, charts as flat-header tables).
   - **DOCX/PPTX** → `libreoffice --headless --convert-to pdf` first, then PDF path. Originals archived in `aa-inbox/.processed/`.
   - **URL / MD** → fetched/copied as-is.
   - **Image** → vision call, `[Image: description]`.
3. **Summarize → `_summary.md`** using vault-specific template (personal terse; work APA-style).
4. **Auto-route** if from top-level `aa-inbox/`: propose vault + folder, confirm.
5. Rename `YYYY-MM-DD AuthorOrSource. Title.ext`, move into topic folder (proposed if new), append to vault's `index.md`.
6. Append to `log.md` — including parser model + token usage for PDF calls.

## Invariants

- **Never delete originals.** DOCX/PPTX go to `.processed/` after conversion; they don't get erased.
- **Never overwrite an existing `_summary.md`.** Re-processing creates `_summary.v2.md` etc.
- **Never index `materials/` subfolders.** Privacy opt-out for raw sensitive docs.
- **Never write API keys to disk in this repo.** Anthropic key lives in macOS Keychain (entry name: `<your-keychain-entry>`). Parser reads via `security find-generic-password`.
- **Cowork sessions are read-only.** Parsing happens on the Mac LaunchAgent. Cowork has no API key and never invokes the parser.

## File naming

- Captured items: `YYYY-MM-DD AuthorOrSource. Title.ext`
- Companions: `<basename>_text.md` (faithful extraction), `<basename>_summary.md` (Claude-generated)
- Top-level files: `index.md` (per-vault entry index), `topics.md` (folder descriptions), `log.md` (ingestion log), `ideas.md` (random ideas)

## Cross-references

- `work/crossrefs.md` — pointers to `<your-research-kb>/`, `<your-other-kb>/`, `<your-other-kb>/`, OneDrive class library
- `work/course-archive-index.md` — metadata-only index of OneDrive Teaching folder (no file contents copied; built by `/kb archive scan`)
