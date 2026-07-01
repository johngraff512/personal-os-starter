---
name: kb
description: Brainiac knowledge-base operations. Use this skill when the user asks to process the brainiac inbox, ingest a captured article/PDF, query the personal or work knowledge base, promote ideas from ideas.md to permanent locations, pull a file from OneDrive into the work vault, refresh the course-archive index, sync brainiac to GitHub, or any request involving the dual-vault file-based knowledge base at $BRAINIAC_ROOT/. Triggers on "/kb", "/kb ask [question]", "/kb update", "/kb ideas", "/kb pull [path]", "/kb archive scan", "/kb sync", "process my inbox", "what have I bookmarked about X", "promote my ideas", or any brainiac-related request.
---

# /kb — Brainiac knowledge-base operations

Brainiac is a dual-vault file-based knowledge base at `$BRAINIAC_ROOT/`. Plain markdown is the source of truth — no DB, no embeddings, no RAG. This skill provides seven modes that ingest, query, and maintain the vaults.

**Read [the project plan](~/.claude/plans/i-am-interested-in-zesty-lovelace.md) once if you haven't seen it before. It's the canonical architecture document.**

## Critical paths and conventions

| Path | Purpose |
|---|---|
| `$BRAINIAC_ROOT/` | The brainiac root — referred to as `$BRAINIAC` below |
| `$BRAINIAC/CLAUDE.md` | Master schema (already loaded if you're invoked from any vault) |
| `$BRAINIAC/personal/` | Vault 1 — personal-brainiac |
| `$BRAINIAC/work/` | Vault 2 — work-brainiac (APA citations, <your-org>/teaching) |
| `$BRAINIAC/aa-inbox/` | Top-level "I'll route later" drop zone |
| `$BRAINIAC/.scripts/parser/parse_pdf.py` | Vision-LLM PDF parser (Anthropic SDK) |
| `$BRAINIAC/.venv/bin/python` | Python venv with `anthropic` and `pypdf` |
| `~/Library/CloudStorage/OneDrive-*/Teaching/` | OneDrive class library (referenced by `/kb pull` and `/kb archive scan`) |

**Detect the active vault.** Check the user's current working directory:
- `$BRAINIAC/personal/...` → vault is `personal`
- `$BRAINIAC/work/...` → vault is `work`
- `$BRAINIAC/` (root) → both vaults; ask the user to pick or process both

**Detect canonical vs. read-only clone.** Brainiac has exactly one canonical location: `$BRAINIAC_ROOT/` on your Mac. **Any other path** — e.g., `<some-project>/.brainiac-cache/`, or the path returned by `pwd` inside a Cowork session that pulled the brainiac repo — is a **read-only clone**. Detection rule:

- If `$BRAINIAC` resolves to `$BRAINIAC_ROOT/` (or a subdirectory) → **canonical**. All modes available.
- If `$BRAINIAC` is any other path (most reliably: contains `.brainiac-cache/` in its path, but also true of any other filesystem location) → **clone**. **Only `/kb ask` is allowed.** For any mutating mode (`/kb` process inbox, `/kb update`, `/kb ideas`, `/kb pull`, `/kb archive scan`, `/kb sync`), refuse with this message and stop:

  > Read-only clone detected at `<path>`. Mutating modes must run from the canonical brainiac at `$BRAINIAC_ROOT/` on the Mac. From here you can only `/kb ask <question>`. To capture content back to brainiac, use the `cowork-captures.txt` mechanism documented at `<cache>/.claude/integration/cowork-integration.md`.

This prevents accidental writes to a clone (which would diverge from the canonical and either get lost on next `git pull --ff-only` or cause merge conflicts).

## Mode dispatch

The user invokes `/kb [mode] [args...]`. Modes:

| Mode | Args | What it does |
|---|---|---|
| (none) | — | **Process inbox** — most common. See §1. |
| `ask` | `<question>` | Q&A from index + summaries. See §2. |
| `update` | (optional `--full`) | Sync index with disk; health check. See §3. |
| `ideas` | (optional `--auto-only`) | Promote new lines in `ideas.md`. See §4. |
| `pull` | `<external-path>` | Selectively absorb an external file (typically OneDrive). Work vault only. See §5. |
| `archive scan` | (optional `--full`) | Refresh `work/course-archive-index.md`. See §6. |
| `sync` | — | git add/commit/push to private GitHub remote. See §7. |

If the user says `/kb` with no further argument, default to mode (none) — process inbox.

---

## §0 — Detect cowork-captures.txt (canonical brainiac only)

**Goal:** before processing the inbox, check whether any Cowork project (Nolan, <a-course>, etc.) has pushed captures up since the last `/kb` run. If so, merge them first — they may include URLs that should join the inbox processing run, or ideas that belong in `ideas.md`.

This step runs only on the **canonical brainiac**. On a clone, refuse mutating modes per the active-vault detection above.

### Step 0.1 — Pull and check

```bash
cd "$BRAINIAC"
git pull --ff-only 2>&1 | tail -3   # ensures any pushed captures are local
[ -s "$BRAINIAC/cowork-captures.txt" ] && echo "captures pending" || echo "no captures"
```

If `cowork-captures.txt` doesn't exist or is empty, skip to §1.

### Step 0.2 — Parse and propose

Each non-empty line in `cowork-captures.txt` follows this format (pipe-separated, fields stripped of leading/trailing whitespace):

```
<ISO8601 timestamp> | <source> | <type> | <vault> | <message> [| <optional context note>]
```

- `<source>` — short identifier of the originating Cowork project: `nolan`, `projectx`, `research`, etc. Free-form lowercase.
- `<type>` — one of `idea` | `url` | `note`.
- `<vault>` — `personal` | `work`. (If ambiguous, the source project should ask the user before writing the line.)
- `<message>` — for `idea`/`note`: the text. For `url`: the URL itself.
- `<optional context note>` — only present for `url` type when the user added a "why I saved it" note alongside.

Parse each line. **Skip malformed lines** (don't fail the whole batch — collect them and report at the end so the user can fix).

Build a batch confirmation table (same pattern as §1.7) showing proposed merges. Wait for user confirmation. Then route per type:

- `idea` → append to `<vault>/ideas.md` with format: `- HH:MM <message> (via <source>)` under the appropriate date heading. If today's date heading doesn't exist yet, create it.
- `url` → append to `<vault>/aa-inbox/urls.txt` (one URL per line). If a context note is present, **also** create `<vault>/aa-inbox/<YYYY-MM-DD>-<source>-note-<slug>.md` referencing the URL with the context note as body. (`<slug>` is a short snake-case fragment derived from the URL or note.)
- `note` → create `<vault>/aa-inbox/<YYYY-MM-DD>-<source>-note-<slug>.md` with frontmatter `source: cowork-capture; cowork_source: <source>; captured: <date>` and the message as body. (This routes the note through the standard inbox flow on the next `/kb` run; you don't process it twice in this run.)

### Step 0.3 — Truncate and commit

After all proposed merges are executed (and only the successful ones — malformed lines stay in the file for the user to address):

```bash
# If all lines processed, truncate to empty:
> "$BRAINIAC/cowork-captures.txt"

# Commit and push the cleared state plus any vault changes:
git add cowork-captures.txt <vault>/ideas.md <vault>/aa-inbox/
git commit -m "kb: merged N captures from <comma-separated source list>"
git push
```

If any malformed lines are left, leave them in the file with a `# malformed: <reason>` comment line above each so the user sees them on next run. Do **not** truncate.

### Step 0.4 — Proceed to §1

After the captures merge, continue to §1 (process inbox) — it now sees any URLs that were just appended to `urls.txt` and any note files that were just dropped in `aa-inbox/`. Single integrated run.

---

## §1 — `/kb` (process inbox)

**Goal:** drain the active vault's `aa-inbox/` (and the top-level `$BRAINIAC/aa-inbox/` if invoked from root). For each item, produce `_text.md` (faithful) and `_summary.md` (Claude-generated), propose folder placement, rename, move, index, and log.

### Step 1.1 — Enumerate inbox items

```bash
# personal vault inbox (excluding gitignored .processed/ and the .gitkeep marker)
find "$BRAINIAC/personal/aa-inbox" -maxdepth 1 -type f \
  ! -name ".gitkeep" ! -name "urls.txt" -print
```

Repeat for `work/aa-inbox/` if active vault is work or root. For root, also enumerate `$BRAINIAC/aa-inbox/`.

Also read `<vault>/aa-inbox/urls.txt`. Each non-empty line is a URL to ingest.

If both inboxes empty and no URLs queued, report "Inbox empty" and stop.

### Step 1.2 — Per-item flow

For each item, follow the flow in this order:

1. **Detect type** by extension and MIME:
   - `.pdf` → PDF (most common)
   - `.docx`, `.pptx` → Office doc (must be converted to PDF first; see Step 1.3)
   - `.md` → already markdown — skip parsing, treat the file itself as `_text.md` after copying to a date-stamped name
   - `.txt` → plain text — copy as `_text.md`
   - `.png`, `.jpg`, `.jpeg`, `.heic` → image — see Step 1.4
   - URL line in `urls.txt` → web fetch — see Step 1.5
   - Anything else → ask the user

2. **Run the parser** (PDF path; see Step 1.3).
3. **Generate `_summary.md`** using the active vault's template (Step 1.6).
4. **Auto-route** if the item came from `$BRAINIAC/aa-inbox/` (top-level): propose vault + folder. Wait for confirmation.
5. **Propose final filename** in the form `YYYY-MM-DD AuthorOrSource. Title.ext`. Sanitize: strip filesystem-unsafe chars, collapse whitespace.
6. **Propose folder placement.** Read `<vault>/topics.md` for existing folder descriptions. Propose either an existing folder or a new one (e.g., "Looks like a financial-strategy article — create folder `investments/`?").
7. **Batch confirmation.** Don't move anything yet. Present a markdown table of all proposed renames + moves + folder creations across the whole inbox. Wait for user confirmation. Only then execute.
8. **Move + index** (Step 1.7).
9. **Append to `log.md`** (Step 1.8).

### Step 1.3 — PDF / Office doc parsing

**Idempotency check first.** The 6:30 am LaunchAgent (`process-inbox.sh`) often pre-parses PDFs overnight. Before invoking the parser, check whether the PDF already has a `_text.md` companion next to it. If yes, skip parsing — read the existing `_text.md` to determine if it was full-mode or summary-mode (look for the `> **Note — detailed reference summary` callout at the top), and proceed to Step 1.6 (summary generation).

**For PDF (no companion exists):** invoke the parser via the brainiac venv. Use absolute paths because cwd may be the active vault, not `.scripts/`:

```bash
cd "$BRAINIAC/.scripts" && \
  "$BRAINIAC/.venv/bin/python" -m parser.parse_pdf \
    "<absolute-path-to-pdf>" \
    --out "<absolute-path-to-_text.md>"
```

The parser:
- Tries full extraction first (HTML tables for merged cells, charts as flat-header data tables, bracketed image descriptions).
- Auto-falls back to summary mode on Anthropic content-filter block (typical for famous published works). Summary mode produces an APA citation, section-by-section summary preserving technical terminology, tables described with key data extracted, and short load-bearing quotes only — for academic fair-use reference.
- The output's first line will be a `> **Note — detailed reference summary, not verbatim extraction.** ...` callout if the parser fell back to summary mode. **Preserve this note when generating `_summary.md`** — downstream consumers (Q&A, manual review) need to know they're looking at a summary, not the full text.

**Capture the parser's stderr output** — it logs `mode=full` or `mode=summary` plus token usage. Save this for the `log.md` entry.

**For DOCX/PPTX:** convert to PDF first using libreoffice headless. The LaunchAgent's `process-inbox.sh` already does this pre-step; if you're invoked interactively and find a DOCX/PPTX in the inbox, do the conversion yourself before parsing:

```bash
SOFFICE="$(command -v soffice || command -v libreoffice || echo /Applications/LibreOffice.app/Contents/MacOS/soffice)"
"$SOFFICE" --headless --convert-to pdf --outdir "<inbox-dir>" "<original-docx-or-pptx>"
mkdir -p "<inbox-dir>/.processed"
mv "<original>" "<inbox-dir>/.processed/"
```

Then parse the resulting PDF. Never delete the original — `.processed/` is the archive.

**Cost guard.** The parser asks for confirmation if a PDF exceeds 50 pages. In an interactive session this prompt will surface to you; relay it to the user before proceeding.

### Step 1.4 — Image inputs

For an image (`.png`, `.jpg`, etc.), produce a vision-based description and save as `_text.md`. Use the Read tool to view the image, then write a `_text.md` like:

```markdown
# [filename]

**Source:** image
**Captured:** YYYY-MM-DD

[Image: a thorough description of what's in the image — text content if any, charts/data extracted as tables if applicable, key visual elements]
```

If the image is a screenshot of a chart or table, extract the data into HTML `<table>` tags inside `_text.md`, same as the PDF parser would.

### Step 1.5 — URL inputs (urls.txt lines)

For each URL line in `<vault>/aa-inbox/urls.txt`:

1. Use WebFetch (or `curl + readability-style extraction` if WebFetch is unavailable) to retrieve the article body.
2. Save as `<vault>/aa-inbox/<YYYY-MM-DD>-<slug>.md` with a YAML frontmatter block:
   ```markdown
   ---
   source: <URL>
   captured: YYYY-MM-DD
   type: web-article
   ---
   ```
3. The fetched markdown becomes `_text.md` (after rename in Step 1.7); generate `_summary.md` from it.
4. After successful processing, **delete the URL line from `urls.txt`** (the file is "cleared, not moved"). Keep `urls.txt` itself; don't delete the file.

### Step 1.6 — Generate `_summary.md`

Read the active vault's `CLAUDE.md` to determine which template to use:
- **Personal vault** — terse template (TL;DR, why I saved it, key takeaways, optional notes). No formal citation.
- **Work vault** — APA-aware template (full APA citation block, TL;DR, relevance to <your-org>/teaching, key arguments, quotable passages with page refs, connections via `[[wiki-link]]` to related items).

**If `_text.md` was produced by summary-mode parsing** (it begins with the summary-mode note), the `_summary.md` should:
- Include the same APA citation as in `_text.md`.
- Have a TL;DR drawn from the summary's content (not the original prose).
- Note in frontmatter: `extraction: summary` — so future Q&A sessions know this item lacks full-text content.

Always include a frontmatter `extraction: <full|summary|web|image|md|txt>` field so the extraction provenance is queryable.

### Step 1.7 — Rename, move, index

**Rename pattern:** `YYYY-MM-DD AuthorOrSource. Title.ext`

- For PDFs: `YYYY-MM-DD <author-last-or-source>. <title>.pdf`
- For URLs: `YYYY-MM-DD <domain-or-author>. <title>.md` (URL went to a markdown file, not a PDF)
- For images: `YYYY-MM-DD <source-or-context>. <description>.<ext>`

Sanitize:
- Replace `/`, `\`, `:`, `*`, `?`, `"`, `<`, `>`, `|` with `-`
- Collapse multiple spaces to single space
- Truncate to a reasonable length (~120 chars) if the title is huge

**Move:** the original (renamed), `_text.md`, and `_summary.md` all go into the proposed topic folder under the active vault. If the folder doesn't exist, `mkdir` it and append a one-line description to `<vault>/topics.md`.

**Index:** append a row to `<vault>/index.md`. Read the existing table format and match it. Newest items at top (under the header):

```markdown
| Date | Title | Author/Source | Type | Topic | Summary |
|---|---|---|---|---|---|
| 2026-05-09 | Breaking Compromises, Breakaway Growth | Gadiesh & Gilbert | pdf | strategy/ | [link](strategy/2026-05-09 Gadiesh. Breaking Compromises_summary.md) |
```

The `Summary` column links to the relative path of `_summary.md`.

### Step 1.8 — Append to `log.md`

After processing each item, append to `<vault>/log.md`:

```markdown
## YYYY-MM-DD HH:MM

- **Ingested:** `topic/2026-05-09 Author. Title.pdf`
- **Type:** pdf
- **Extraction:** full | summary | web | image
- **Parser:** model=claude-haiku-4-5-20251001, 8421 in / 3204 out tokens, $0.012 (estimate)
- **Source:** original path or URL
```

For batch runs, group by date heading. Token usage and parser model only apply to PDFs.

### Step 1.9 — Invariants

- **Never delete originals.** The renamed PDF stays in the topic folder. `_text.md` and `_summary.md` are companions.
- **Never overwrite an existing `_summary.md`.** If one exists, save the new one as `_summary.v2.md` and warn the user.
- **Never index `materials/` subfolders.** Skip them entirely in folder enumeration. Privacy opt-out for raw sensitive docs.
- **Never write API keys to disk in this repo.** The parser handles its own key from macOS Keychain — you don't need to know the key value.
- **Always batch-confirm moves and renames.** Show a markdown table; wait for the user's "go" before doing any filesystem mutation.

---

## §2 — `/kb ask <question>`

**Goal:** answer the user's question from the active vault, with citations.

### Step 2.1 — Load context

1. Read `<vault>/index.md` (the index of all items in the vault).
2. Read `<vault>/CLAUDE.md` (vault-specific style/citation conventions).
3. If active vault is `work`, read `work/crossrefs.md` (pointers to external KBs) and note that `work/course-archive-index.md` is available for course material questions.

### Step 2.2 — Identify relevant items

From the question + the index, identify candidate items by topic, title, or author. Read those `_summary.md` files. If summaries are insufficient, escalate to reading `_text.md`.

For each item with `extraction: summary` in its frontmatter, note that the full text isn't available — only the structured summary. Cite accordingly.

### Step 2.3 — Consult external surfaces (work vault only)

If the question mentions or implies external knowledge surfaces (<your-research-kb>, OneDrive Teaching, <your-other-kb>, <your-other-kb>):

1. Identify which surface from `crossrefs.md`.
2. **Ask the user before reading from external surfaces** — never read silently. Format: "This question seems to involve [surface]. Should I read from there?"
3. For OneDrive specifically: prefer `course-archive-index.md` (metadata only — fast) before reading individual files on demand.

### Step 2.4 — Compose the answer

- Lead with a direct answer to the question.
- Each substantive claim should cite a source. Format citations as relative-path markdown links: `[Gadiesh & Gilbert (1998)](strategy/2026-05-09 Gadiesh. Breaking Compromises_summary.md)`.
- For work-vault answers, follow APA conventions where possible.
- If sources are summary-mode only, note this: "(reference summary; consult source PDF for verbatim quotation)."
- Don't fabricate. If the vault doesn't have an answer, say so clearly and suggest where else to look (`crossrefs.md` surfaces, the OneDrive archive, or external search).

---

## §3 — `/kb update`

**Goal:** sync the active vault's `index.md` with what's actually on disk, propose folder consolidations, flag orphans.

### Step 3.1 — Health check

1. **Orphan files:** items with `_summary.md` but no row in `index.md` → propose adding rows.
2. **Orphan rows:** rows in `index.md` whose linked `_summary.md` no longer exists → propose removing rows.
3. **Empty folders:** topic folders with no items → propose deletion + removal from `topics.md`.
4. **Topic drift:** folder names that are similar (e.g., `ai/` and `artificial-intelligence/`) → propose merge.
5. *(reserved — formerly stale aa-recents check; aa-recents was dropped)*

### Step 3.2 — Topic drift detection

Read `<vault>/topics.md` and the actual folder list. Compute pairwise similarity (semantic, not string — use your own judgment about whether `ai/` and `artificial-intelligence/` should merge). For each candidate merge, propose:

> Merge `artificial-intelligence/` (3 items) into `ai/` (12 items)? Items would move; index.md links would update.

Wait for user confirmation.

### Step 3.3 — Report

Produce a single markdown report summarizing what was found, what was fixed automatically, and what's pending user confirmation. Append a one-line summary entry to `<vault>/log.md` ("update sweep: 3 orphans fixed, 1 merge proposed").

`--full` flag: also re-validate every `_summary.md` frontmatter for required fields and propose corrections for malformed entries.

---

## §4 — `/kb ideas`

**Goal:** read recent additions to `<vault>/ideas.md` (since last promotion run), propose where each idea should permanently live.

### Step 4.1 — Identify new ideas

Read `<vault>/ideas.md`. Lines marked `→ promoted: <dest>` or `→ kept` have already been processed; skip them. Process only un-marked lines.

### Step 4.2 — Propose promotions

For each new idea, propose one of four destinations based on content:

| Idea pattern | Promote to |
|---|---|
| Rule / convention ("always do X", "for future syllabi…", "never present a case without…") | Append to relevant `<vault>/<folder>/CLAUDE.md` (creating the file if needed) |
| Topic-specific note ("Acme Corp class should open with their AI risk register") | Append to `<vault>/<folder>/notes.md` (creating folder + file if needed) |
| Future writing seed ("blog post idea: ...") | Append to `<vault>/outputs/seeds.md` (creating if needed) |
| Pure memory, no clear action ("interesting that …") | Leave as `→ kept` annotation |

### Step 4.3 — Batch confirmation

Present all proposals as a markdown table. User confirms or edits each row. **`--auto-only` flag** (used by the LaunchAgent): only act on proposals that fall into clearly unambiguous categories (rule with explicit "always/never" verbs, topic note with a folder name explicitly mentioned, blog seed with the word "blog"); leave ambiguous ones untouched for the user to review interactively.

### Step 4.4 — Mark sources

After promoting, edit `ideas.md` in place to annotate each promoted line:

```diff
-- 09:14 For future syllabi, explicitly state attendance policy
+- 09:14 For future syllabi, explicitly state attendance policy → promoted: courses/CLAUDE.md
```

Don't reorder lines, don't delete them. The annotation is the durable record.

---

## §5 — `/kb pull <external-path>`

**Goal:** copy a specific external file (typically from OneDrive Teaching) into the work vault as a first-class indexed item. **Work vault only** — refuse if active vault is personal.

### Step 5.1 — Validate path

1. Confirm the external path exists.
2. Confirm it's not already inside `$BRAINIAC` (would be a no-op).
3. Determine type by extension; route through the same parsing machinery as inbox processing.

### Step 5.2 — Copy, parse, summarize, index

1. Copy (don't move) the file into a target folder in `work/`. Propose the folder if not specified.
2. Run the file through the same Step 1.3–1.7 flow (parse → summary → rename → index).
3. **Stamp `pulled_from` in the frontmatter** of `_summary.md`:
   ```yaml
   pulled_from: ~/Library/CloudStorage/OneDrive-<your-org>/Teaching/<a-course>/Sp25/syllabus.pdf
   ```
   This preserves provenance.
4. Append to `work/log.md` with a `pulled` marker.

The original file in OneDrive is untouched.

---

## §6 — `/kb archive scan`

**Goal:** refresh `work/course-archive-index.md` — a metadata-only index of the OneDrive Faculty/Teaching folder. **No file contents are copied** — only metadata (filename, path, course, semester, type, topic).

### Step 6.1 — Locate the OneDrive folder

Read `work/crossrefs.md` first to get the canonical path. As of 2026-05, your path is:
`~/Library/CloudStorage/OneDrive-<your-org>/Faculty/`

Legacy fallback candidates if `crossrefs.md` is silent:
- `~/Library/CloudStorage/OneDrive-Personal/Teaching/`
- `~/Library/CloudStorage/OneDrive-<your-org>/Teaching/`
- `~/Library/CloudStorage/OneDrive-<your-org>/Faculty/`

If still unclear, ask the user.

### Step 6.2 — Privacy filter (default-on)

Before walking, apply this default-exclude filter. The filter is filename- and path-based — no content reading required, no risk of touching sensitive bytes.

**Excluded extensions (gradebooks, trackers, rosters — almost always sensitive student data):**
- `*.xlsx`, `*.xlsm`, `*.xls`

**Excluded by name pattern (case-insensitive globs against the basename):**
- `*grade*`, `*roster*`, `*participation*`, `*attendance*`
- `*rubric*filled*` (blank rubric templates are still indexed; only completed ones are skipped)

**Excluded by path pattern:**
- Anything under any `materials/` subfolder (existing privacy opt-out, extended from the work-vault side to the OneDrive side)

**Excluded as detritus (never useful):**
- `~$*` (Office lock files), `.DS_Store`, `*.tmp`, `Thumbs.db`, `.~lock.*`

**NOT excluded (counter to first instinct):**
- `Class Evaluations/` and `Peer Reviews/` subfolders — you has confirmed these contain no student PII. They are indexed with `type: evaluation` or `type: peer-review` and tagged `(faculty-confidential)` in `/kb ask` citations, but the metadata flows through normally.
- Filenames containing `evaluation` or `peer review` from inside these confidential-but-PII-free folders.

**`--include-sensitive` flag override:** if the user passes this flag explicitly, skip all the privacy filters above and index everything. Use sparingly — typically for indexing clean grading-template files (no actual student data) or auditing the exclusions.

### Step 6.3 — Walk the folder

The canonical implementation is **`.scripts/archive_scan.py`** in the brainiac repo. Invoke it directly:

```bash
cd "$BRAINIAC" && .venv/bin/python .scripts/archive_scan.py
# Pass --include-sensitive to disable the privacy filter (rare).
```

The script encodes the routing rules and exclusion logic in one place. Modify it (not just the spec) when rules change.

> **Note:** `archive_scan.py` is intentionally **not shipped** in this template — the routing/exclusion rules are specific to how you organize your own cloud store. The section below documents the pattern so you can write your own if you want the `/kb archive scan` mode. Delete this mode from the skill if you don't use an external teaching/reference archive.

**Routing rules baked into the script (example):**
- Top-level subfolder → display course via `COURSE_MAP`:
  - `<Course-Folder-A>/` → `<a-course>`, `<Course-Folder-B>/` → `<a-course>`
  - `<Co-Taught-Class>/` → `<a-course>` (a class co-taught with a colleague, kept as its own identity)
  - `AI/` → `ai-teaching` (so future `/kb pull` lands in the existing `work/ai-teaching/` folder, not a new `courses/` subfolder)
  - All others keep their folder name as the display course; loose root-level files get `course = (general)`.
- **Collapse-to-single-row folders** (`COLLAPSE_TO_SINGLE_ROW`): `Teaching Awards/` collapses to one folder-summary row listing the contents. Add other small reference-only folders here as needed.
- **Do-not-pull folders** (`DO_NOT_PULL`): `Canvas/` rows are tagged `(do-not-pull)` in the Title column. `/kb pull` should refuse these and tell the user to consult the source LMS instead.

**Per-file fields the script emits:**
- `course` — display course from `COURSE_MAP`.
- `semester` — from filename/path regex (`Sp25`, `Fa24`, `Sp26`, etc.); blank if absent.
- `type` — by filename keyword + extension: `syllabus | slides | lesson-plan | case | exercise | exam | handout | paper | pedagogy | evaluation | peer-review | award | research | folder-summary | other`.
- `title` — sanitized filename. Files in DO_NOT_PULL folders get `(do-not-pull)` appended.
- `topic` — best-effort one-liner from sub-folder context; blank if uninferrable.

For genuinely ambiguous metadata in small surrounding folders (`Course Materials/`, `Lectures/`, `Misc/`, etc.), the script falls back to keeping the folder name as the display course. Adjust via `COURSE_MAP` rather than in-place edits to `course-archive-index.md`.

### Step 6.4 — Write the index

```markdown
# work/course-archive-index.md
> Indexed: YYYY-MM-DD | <N> files across <M> courses · <P> semesters
> Source: <onedrive-folder-path>
> Excluded: *.xlsx (gradebooks), *grade*, *roster*, *participation*, *attendance*, ~$*, .DS_Store, materials/
> Privacy filter: default-on (use --include-sensitive to override). Confidential-but-PII-free folders (Class Evaluations/, Peer Reviews/) indexed normally.

| Course | Semester | Type | Title | Topic | Path |
|---|---|---|---|---|---|
| <a-course> | Sp26 | slides | Class 8 Strategy Frameworks | five-forces, value-chain | <relative-path> |
| ...
```

Incremental by default — only re-process files modified since last scan (read the previous `Indexed: YYYY-MM-DD` header). `--full` forces a complete rescan. When `--full` runs, rewrite the entire file rather than merging into the existing rows.

---

## §7 — `/kb sync`

**Goal:** push current state to the private GitHub remote, then fast-forward every consumer `.brainiac-cache/` on this Mac so downstream Cowork sessions see the new content on their next open.

### Step 7.1 — Push canonical

```bash
cd "$BRAINIAC"
git add .
if git diff --cached --quiet; then
    echo "No changes to commit."
    PUSHED=0
else
    git commit -m "kb sync: $(date '+%Y-%m-%d %H:%M')"
    git push
    PUSHED=1
fi
```

### Step 7.2 — Refresh consumer caches on this Mac

Cowork sandboxes are credentialless — they cannot `git pull` against the private brainiac repo from inside the sandbox. The Mac (which has Keychain creds) is the only side that can pull. Every consumer project's `.brainiac-cache/` clone needs to be fast-forwarded on the Mac so the next Cowork session in that project sees current content at session start.

Run after the push (only if the push happened; no point pulling unchanged remotes):

```bash
if [ "$PUSHED" = "1" ]; then
    find ~/Documents -name ".brainiac-cache" -type d -prune 2>/dev/null | while IFS= read -r cache; do
        if git -C "$cache" remote get-url origin 2>/dev/null | grep -q 'brainiac'; then
            before=$(git -C "$cache" rev-parse --short HEAD)
            if git -C "$cache" pull --ff-only --quiet 2>/dev/null; then
                after=$(git -C "$cache" rev-parse --short HEAD)
                if [ "$before" != "$after" ]; then
                    echo "refreshed: $cache ($before → $after)"
                fi
            else
                echo "WARN: could not fast-forward $cache (diverged or no network)"
            fi
        fi
    done
fi

# Also refresh the optional shared cache, if present:
if [ -d "$HOME/.brainiac-cache/.git" ] && [ "$PUSHED" = "1" ]; then
    git -C "$HOME/.brainiac-cache" pull --ff-only --quiet 2>/dev/null && \
        echo "refreshed: ~/.brainiac-cache/"
fi
```

**Invariants:**
- `-prune` on the find so we don't descend into nested caches (no double-pulls).
- Filter by remote URL containing `brainiac` so we only touch our own caches, not unrelated repos.
- `--ff-only` so we never auto-merge — if a cache has local commits (which shouldn't happen per the read-only-clone rule), the pull refuses and we warn instead.
- Skip the refresh entirely when nothing was pushed — saves a noisy walk.

### When to run `/kb sync`

- Manually before opening a Cowork session, so the consumer cache is current.
- The 6:30 AM LaunchAgent already does Step 7.1 automatically as part of `process-inbox.sh`. The LaunchAgent should also run Step 7.2 — if it doesn't yet, that's a follow-up to wire into `.scripts/process-inbox.sh`.

---

## Summary templates (referenced in §1.6)

### Personal vault template

```markdown
---
source: <URL or file path>
captured: YYYY-MM-DD
type: article | pdf | tweet | note | image
extraction: full | summary | web | image | md | txt
---

# <Title>

**TL;DR:** one to two sentences.

## Why I saved it
- one or two bullets

## Key takeaways
- bullet
- bullet

## Notes
free-form, optional
```

### Work vault template

```markdown
---
source: <URL or file path>
captured: YYYY-MM-DD
type: article | pdf | paper | case | slides | exercise | image
extraction: full | summary | web | image | md | txt
authors: <Last, F.M.; Last, F.M.>
year: <YYYY>
publication: <Journal / Outlet / Internal>
---

# <Title>

**Citation (APA):**
> Last, F. M., & Last, F. M. (YYYY). Title. *Publication*, vol(issue), pages. URL or DOI.

**TL;DR:** one to two sentences.

## Relevance to <your-org> / teaching
- which course, which framework, which research question

## Key arguments
- bullet
- bullet
- bullet

## Quotable passages
- "..." (page or paragraph reference)

## Connections
- Related items in this vault: `[[YYYY-MM-DD AuthorOrSource. Title]]`
- Related external: see `crossrefs.md` if it points elsewhere
```

---

## Critical files to read on first invocation

If you don't already have them in context, read these files before acting:

1. `~/.claude/plans/i-am-interested-in-zesty-lovelace.md` — full project plan
2. `$BRAINIAC/CLAUDE.md` — master schema
3. `<active-vault>/CLAUDE.md` — vault-specific rules and templates

When in doubt about a convention, **ask the user** rather than guessing. The system is small enough that a clarifying question is cheap, and the user has strong opinions about file naming, folder structure, and citation conventions.
