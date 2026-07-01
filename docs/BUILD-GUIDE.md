# Build Your Own Personal Operating System

*A markdown-first knowledge base with frictionless capture and AI-agent integration.*

This guide teaches you to build a system like the one it ships with: a **file-based "second brain"** that captures articles, PDFs, and ideas from any device, processes them with an AI agent, and lets you query everything later — including from cloud AI sessions. It's inspired by Karpathy's "LLM-Wiki" pattern: **plain markdown is the source of truth. No database, no embeddings, no RAG.** Anything that can read a text file can read your knowledge base, so it survives whatever AI tool comes next.

> **How to use this guide.** It's built in **layers**. Each layer is self-contained — you can stop after any one and have a working system. Layer 1 alone is a complete, useful knowledge base. Later layers add capture convenience and AI integration. For every component you'll see the same five sections so you can decide what to adopt as-is and what to change:
>
> - **What it does** — the function in one line
> - **Why it exists** — the reasoning, so you can adapt instead of copy
> - **Build the generic version** — the steps anyone can follow
> - **How the reference setup customized it** — what's specific to the original author
> - **Caveats** — the non-obvious things that will bite you
>
> Screenshots are marked `[screenshot: …]` — replace them with your own as you build.
>
> **A note on names.** The reference implementation calls its knowledge base **Brainiac** and its personal assistant **Nolan**. Those are just the author's names — pick your own for both. Wherever you see `<your-kb-name>` or `<your-assistant-name>` (and the derived identifiers like `<kb>-cache` or `$<KB>_ROOT`), that's where your chosen name goes. `setup.sh` prompts for both and fills them in consistently.

---

## Platform support (read this if you're not on a Mac)

**This reference is built on macOS + iOS.** Be honest with yourself about that up front — but it's less limiting than it looks. The *core* of the system is fully cross-platform; only the *capture automation* and *secret storage* are Apple-specific, and each has a direct Windows/Linux equivalent.

Here's exactly what's portable and what isn't:

| Component (layer) | macOS (this reference) | Windows | Linux |
|---|---|---|---|
| KB structure, `/kb` skills, git, Obsidian, Claude Code (**Layers 0–1**) | ✓ | ✓ identical | ✓ identical |
| API-key storage | Keychain (`security`) | Credential Manager / env var / gitignored `.env` | env var / `secret-tool` / `.env` |
| Voice + share-sheet capture (**2.1**) | Apple Shortcuts | iPhone still works¹; else Android (Tasker, HTTP Shortcuts) or a browser bookmarklet | same as Windows |
| Phone→desktop sync bridge (**2.2**) | iCloud "transit vault" + launchd job | OneDrive / Dropbox synced folder — **usually no bridge needed**² | Syncthing / Dropbox — usually no bridge needed |
| Background scheduling (**2.4**) | launchd LaunchAgent | Task Scheduler | cron / systemd timer |
| The macOS TCC caveat (**2.4**) | applies (scripts in `~/.local/bin`, logs in `~/Library/Logs`) | N/A | N/A |
| PDF / DOCX→PDF parser (**2.5**) | Python + LibreOffice | ✓ identical (Python + LibreOffice) | ✓ identical |
| Read-only agent cache (**Layer 3**) | `git clone` | ✓ identical | ✓ identical |
| Dashboard page (**Layer 4**) | self-contained HTML | ✓ identical | ✓ identical |
| Dashboard's Mac-snapshot pipeline (**Layer 4**) | AppleScript + launchd | Outlook/Graph API + Task Scheduler | N/A (or connector + cron) |

¹ If you have an iPhone but a Windows/Linux desktop, the iOS capture (2.1) still works — it just writes into OneDrive/Dropbox instead of iCloud, and the desktop-side automation differs.

² **The Windows/Linux path is often simpler.** The whole "transit vault" indirection (2.2) exists only because iOS apps can't reach an arbitrary folder — they can only see iCloud's own container. OneDrive, Dropbox, and Syncthing mount as ordinary folders on Windows/Linux, so you can point your capture tools **straight at the synced vault folder** and skip the bridge entirely.

**Practical takeaways for a non-Mac build:**
- **Layer 1 is 100% cross-platform** — you can build the entire knowledge base, skills, Obsidian, and git flow on Windows or Linux with zero changes. Start there.
- **`setup.sh` is a bash script.** On Windows, run it under **WSL** or **Git Bash**; its find/replace is platform-neutral. The Keychain and LaunchAgent *reminders* it prints are macOS-specific and clearly labeled.
- Wherever this guide says "LaunchAgent," "launchd," "Keychain," "iCloud," or "Apple Shortcuts," a **`Platform:` tag** on that component points you to the equivalent. If a section has no such tag, it's cross-platform.

---

## Layer 0 — The mental model (read this first)

Before any setup, understand the loop. Everything else is detail.

```
   CAPTURE              PROCESS                INDEX                QUERY
 (any device)   →   (/kb skill, AI agent)  →  (index.md)   →   (/kb ask, any surface)
 article/PDF/        extract → summarize →    one row per       cited answers from
 idea/URL            rename → file → log      item, plus        index + summaries
                                              topic folders
```

Five principles hold the whole thing together:

1. **Markdown is the source of truth.** No DB, no embeddings. Every item is a plain file you can open in any editor.
2. **Two vaults, shared infrastructure.** A `personal/` vault and a `work/` vault. Same mechanics, different conventions (e.g. work requires formal citations; personal is terse). Use one vault if you don't need the split.
3. **Capture is cheap, processing is batched.** You drop things into an inbox all day from whatever device you're on. Once a day you run one command that turns the pile into clean, filed, indexed entries.
4. **The AI agent reads, you confirm.** Processing proposes filenames, folders, and summaries; you approve in one batch. ~30–60 seconds of human time regardless of how many items.
5. **One index, read directly.** A single `index.md` per vault is the catalog. The agent reads it plus the relevant summaries to answer questions. You can swap to a search server later with zero data migration, because the data is just files.

If a future tool is better, you keep the markdown and throw away everything else. That's the whole bet.

---

## Layer 1 — The foundation (everyone needs this)

**A working knowledge base stops here.** If you only do Layer 1, you have a real, useful system: drop files in, run a command, query later.

### Prerequisites

- **Claude Code** (the CLI) — this is what runs the `/kb` skill. [screenshot: Claude Code installed and running in a terminal]
- **A markdown editor** — [Obsidian](https://obsidian.md) is recommended (free; opens the folder natively, renders wiki-links, works on iOS/iPad). Any editor works — the data is plain files.
- **git + a GitHub account** — for sync and (later) AI-agent access. A private repo is fine.
- **A folder** to hold it all. The reference setup uses `~/Documents/AI Development/brainiac/`.

### 1.1 The repo structure

**What it does.** Defines where everything lives so both you and the AI agent always know where to look.

**Why it exists.** A predictable, flat-ish structure means the agent can navigate by convention instead of guessing, and *you* can browse it in Finder with no tooling.

**Build the generic version.** Create this skeleton (one vault shown; duplicate for a second):

```
my-kb/                          # repo root
├── README.md                   # what this is
├── CLAUDE.md                   # rules the AI agent reads every session
├── .gitignore
├── personal/                   # a vault
│   ├── CLAUDE.md               # vault-specific rules + summary template
│   ├── index.md                # the catalog — one row per item
│   ├── topics.md               # one line describing each topic folder
│   ├── log.md                  # ingestion log
│   ├── ideas.md                # quick captured thoughts
│   └── aa-inbox/               # drop zone for unprocessed captures
│       └── urls.txt            # one URL per line
└── work/                       # a second vault (same shape), optional
```

The four "spine" files per vault:

- **`index.md`** — the canonical catalog. One row per item: date, title, author/source, topic, link to its summary. This is what the agent reads first when you ask a question.
- **`topics.md`** — one line per topic folder, describing what belongs there. Keeps folders from sprawling.
- **`log.md`** — append-only record of every ingestion (what, when, how processed).
- **`ideas.md`** — a running list of quick thoughts to triage later.

Each processed item becomes **three files** in a topic folder:

```
2026-05-09 Porter. Five Forces in 2026.pdf          # the original
2026-05-09 Porter. Five Forces in 2026_text.md      # faithful extraction
2026-05-09 Porter. Five Forces in 2026_summary.md   # AI-generated summary
```

Naming convention: `YYYY-MM-DD AuthorOrSource. Title.ext`. Companions are `<basename>_text.md` and `<basename>_summary.md`.

**How the reference setup customized it.** Two vaults with different rules: `personal/` is terse and citation-free; `work/` requires APA citations and cross-references institutional knowledge bases via a `crossrefs.md` file. It also keeps a `materials/` convention for raw sensitive docs that are deliberately *never* indexed (a privacy opt-out).

**Caveats.**
- **Never overwrite a `_summary.md`.** Re-processing should create `_summary.v2.md`, never clobber. Summaries are hand-confirmed work.
- **Never delete originals.** Converted files (e.g. DOCX→PDF) go to an archive subfolder, they don't get erased.
- Keep `index.md` as the single catalog. The temptation to add a second index always ends in drift.

### 1.2 The `CLAUDE.md` files

**What it does.** Tells the AI agent the rules of *your* system — the schema, the routing logic, the invariants — so it behaves consistently every session.

**Why it exists.** `CLAUDE.md` is auto-loaded by Claude Code whenever it works in that folder. It's how you turn "an AI that's good at files" into "an AI that runs *my* knowledge base correctly." Per-folder `CLAUDE.md` files let rules cascade: a rule in `work/courses/CLAUDE.md` only applies inside that folder.

**Build the generic version.** Create a root `CLAUDE.md` describing: what the system is, the capture paths, the processing flow, and the invariants (the "never do X" list). Create a per-vault `CLAUDE.md` holding that vault's summary template and conventions. Keep them short and declarative — they're rules, not prose.

**How the reference setup customized it.** The root `CLAUDE.md` encodes the dual-vault routing table ("research/teaching → work; investments/home/health → personal"), the LaunchAgent infrastructure, and a strict invariants list. The work vault's `CLAUDE.md` mandates APA citations on every summary.

**Caveats.** These files are *programmable behavior* — a sentence here changes what every future session does. That's powerful and also a footgun: an over-broad rule ("always do X") fires everywhere. Scope rules to the narrowest folder that needs them.

### 1.3 The `/kb` skill — the engine

**What it does.** A Claude Code **skill** (a packaged, reusable instruction set the agent loads on the `/kb` command) that runs the whole capture→process→index pipeline.

**Why it exists.** You don't want to re-explain the pipeline every day. A skill captures it once: detect each inbox item's type, extract it faithfully, summarize it, propose a filename and folder, update the index/log, commit. You type `/kb`, read a table, type `go`.

**Build the generic version.** A skill is a folder with a `SKILL.md` file at `.claude/skills/kb/SKILL.md` inside your repo (project-level, so it ships with the repo). The `SKILL.md` has frontmatter (name, description, trigger words) and a body that lays out the steps. The reference `/kb` skill in this repo is a working example — read [.claude/skills/kb/SKILL.md](../../.claude/skills/kb/SKILL.md) and adapt the steps to your conventions.

Core modes to implement (start with the first two):

| Mode | What it does |
|---|---|
| `/kb` | Process the inbox: detect type, extract, summarize, propose renames/folders, update index, commit |
| `/kb ask "<q>"` | Answer from index + summaries, with citations |
| `/kb update` | Health check: find orphan files/rows, topic drift, empty folders (read-and-propose only) |
| `/kb ideas` | Triage `ideas.md` lines into rules / notes / writing-seeds / keep |
| `/kb sync` | `git add . && commit && push` |

The daily run, in practice:

```
> /kb
[reads inbox, proposes a table of renames + folder placements + index updates]
> go
[executes moves, updates index.md / topics.md / log.md, commits, pushes]
```

**How the reference setup customized it.** Adds work-vault APA awareness, a Cowork capture-merge step (Layer 3), and an in-house vision-LLM PDF parser (Layer 2). The skill is deliberately project-level so it ships with the repo and is visible to cloud sessions that clone it.

**Caveats.**
- **Make processing idempotent.** If a `_text.md` already exists, skip re-extraction. You'll re-run `/kb` on a partially-processed inbox more than you expect.
- **The skill must be project-level** (`<repo>/.claude/skills/`), not user-level (`~/.claude/skills/`). User-level skills are invisible to cloud agents that clone your repo — this matters a lot in Layer 3.
- Always show a **batch confirmation** before executing moves. Never let the agent file things silently.

### 1.4 Obsidian as the window

**What it does.** Gives you a native, cross-device way to browse, search, and read the vault — and to click the wiki-link citations the agent generates.

**Why it exists.** The data is just files, but a good reader makes it pleasant. Obsidian renders `[[wiki-links]]`, has fast search, and runs on iPhone/iPad.

**Build the generic version.** Install Obsidian, "Open folder as vault," point it at each vault folder. That's it. [screenshot: Obsidian with the vault open]

**How the reference setup customized it.** The `/kb ask` answers cite sources as Obsidian wiki-links (`[[2026-05-09 Porter. Five Forces_summary]]`) so they're clickable in Obsidian.

**Caveats.** Obsidian creates a `.obsidian/` config folder in each vault — gitignore it or commit it deliberately, but decide. On iOS, Obsidian can *only* open vaults stored in its own iCloud container — this constraint drives the whole transit-vault design in Layer 2, so remember it.

---

## Layer 2 — Frictionless capture (adapt to your devices)

Layer 1 works if you manually drop files into `aa-inbox/`. Layer 2 makes capture effortless from your phone, your browser, and your voice. **This is where most device-specific cleverness lives — adapt freely.**

### 2.1 iOS Shortcuts — voice and share-sheet capture

> **Platform: Apple (iOS/iPadOS).** Non-Apple equivalents: Android → Tasker or "HTTP Shortcuts"; any phone → a browser bookmarklet or the Web Clipper (2.3). The *goal* — one-tap append to a synced text file — is what matters; the tool varies.

**What it does.** Two kinds of one-tap capture from any iPhone/iPad app: a **URL drop** (share sheet → appends a line to `urls.txt`) and a **voice idea** ("Hey Siri, capture idea" → appends a timestamped line to `ideas.md`).

**Why it exists.** The highest-leverage capture is the one with zero friction. A thought between meetings → one Siri phrase → saved. A good article → Share → done. No app-switching, no copy-paste.

**Build the generic version.** In Apple's **Shortcuts** app:

- **URL drop shortcut.** New Shortcut → accept input from Share Sheet → "Append to Text File" action → point it at `iCloud Drive → … → <vault>/aa-inbox/urls.txt`. Name it something memorable. Now it appears in every app's Share menu. [screenshot: the Append to Text File action with the path picker]
- **Voice idea shortcut.** New Shortcut → "Dictate Text" (or accept typed input) → prepend a `- HH:MM ` timestamp → "Append to Text File" → `<vault>/ideas.md`. **The shortcut's name is the Siri phrase** (iOS no longer lets you record a custom phrase separately), so name it exactly what you'll say.

Files must live in Obsidian's iCloud container so they sync to your Mac — see 2.2 for why.

**How the reference setup customized it.** Three shortcuts: one URL drop (prompts "Personal or Work?") and two voice shortcuts ("brainiac idea personal" / "brainiac idea work") that write to the matching vault's `ideas.md`.

**Caveats.**
- **The most common breakage** is the "Append to Text File" picker silently dropping the wrong path (e.g. `vault/urls.txt` instead of `vault/aa-inbox/urls.txt`). To fix: open the shortcut → Edit → tap the path → re-navigate the iCloud picker to the exact file. Test by appending one item and watching the file change on your Mac (`tail -f <path>`).
- **URL drops only work for public, fetchable URLs.** Login-gated content (subscriber posts, X.com long-form) can't be fetched server-side later — use the Web Clipper (2.3) for those.

### 2.2 The iCloud transit-vault bridge (the non-obvious part)

> **Platform: macOS + iCloud.** This entire workaround may be **unnecessary on Windows/Linux.** It exists only because iOS apps can't reach an arbitrary folder — see the note below. If your sync layer is OneDrive/Dropbox/Syncthing (which mount as normal folders), point your capture tools straight at the synced vault and skip to 2.3.

**What it does.** Ferries captures made on iOS into your real knowledge base on the Mac, working around a hard iOS limitation.

**Why it exists.** **This is the single most non-obvious workaround in the whole system, so here's the full story.** On iOS, Obsidian (and iOS apps generally, via the Files app) can only reliably reach folders inside Obsidian's own **iCloud container** — `iCloud Drive/iCloud~md~obsidian/Documents/<vault>/`. Your actual knowledge base lives somewhere else (e.g. `~/Documents/.../my-kb/`), which iOS apps *can't* open. So you can't point iOS capture directly at the real vault.

The fix: create **"transit vaults"** — lightweight Obsidian vaults inside the iCloud container, named to mirror your real vaults (`personal`, `work`). iOS captures land there. A small background job on the Mac then **moves** new files from the transit vault's inbox into the real vault's inbox every few minutes. iCloud handles getting the file from phone to Mac; the bridge handles getting it from the transit vault into the real one.

**Build the generic version.**
1. In Obsidian on the Mac, create two vaults inside the iCloud container named `personal` and `work` (or your vault names). Point your iOS Shortcuts and Web Clipper at *these*.
2. Write a small shell script that, for each transit vault, moves new files from its `aa-inbox/` into the real vault's `aa-inbox/`. Schedule it every ~5 minutes (see 2.4 for the scheduling caveats).
3. The script is the "bridge." It's a dozen lines. A reference version lives at [.scripts/bridge-icloud.sh](../../.scripts/bridge-icloud.sh).

**How the reference setup customized it.** A `LaunchAgent` (`com.<you>.<kb>.icloud-pull`) runs the bridge every 5 minutes.

**Caveats.**
- **Use glob loops, not `find`/`while`, to read iCloud paths.** iCloud's placeholder/eviction behavior makes `find` unreliable for not-yet-downloaded files; a simple `for f in dir/*` glob is more robust.
- iCloud sync latency is real (seconds to a minute). The system tolerates it because everything is just files — but don't expect instant.

### 2.3 Obsidian Web Clipper — full article bodies

**What it does.** Captures the full rendered body of a web article (including login-gated pages) as clean markdown directly into an inbox.

**Why it exists.** URL drops only save a link, and links to gated content can't be re-fetched later. The Web Clipper runs *in your logged-in browser*, so it can grab the actual text of subscriber-only or paywalled pages.

**Build the generic version.** Install the **Obsidian Web Clipper** browser extension (Safari/Chrome). In its settings, set the default vault and default folder to your transit vault's `aa-inbox/`. On any article: click the extension → it extracts the body → saves a markdown file with frontmatter. [screenshot: Web Clipper extension popup on an article]

**How the reference setup customized it.** Default folder set to `aa-inbox/` per vault; a documented workaround for the X.com app (which doesn't expose the clipper): Share → Open in Safari → then clip.

**Caveats.**
- Must be invoked **from the browser**, not from an app's in-app webview. Apps that don't expose the clipper need a "share to Safari first" step.
- The clipper defaults to a `Clippings/` folder — change it to `aa-inbox/` or your processing won't pick clips up.

### 2.4 Background automation (scheduling) — and the macOS gotcha

> **Platform: macOS launchd.** Windows → **Task Scheduler** (point a task at the same script via WSL/Git Bash, or rewrite it in PowerShell). Linux → **cron** or a **systemd timer**. The macOS TCC caveat below is Apple-only — Windows/Linux have no equivalent restriction.

**What it does.** Runs the bridge (and optionally nightly inbox processing) automatically, without you remembering to.

**Why it exists.** Capture should be passive. A scheduled job means clips flow from phone to Mac to vault while you sleep.

**Build the generic version.** On macOS, use a **LaunchAgent** (a `.plist` in `~/Library/LaunchAgents/`) that runs a script on a schedule. On Linux, a cron job or systemd timer. The script does the work; the scheduler just triggers it.

**How the reference setup customized it.** Two LaunchAgents — one for the iCloud bridge (every 5 min) and one intended for nightly inbox processing (6:30 AM).

**Caveats — read this before you fight macOS for an hour.**
- **macOS TCC (privacy) blocks `launchd` from running scripts inside `~/Documents/` and from writing logs there.** Symptom: your LaunchAgent "runs" but nothing happens and there's no error. Fix: put the executable scripts in `~/.local/bin/` and write logs to `~/Library/Logs/`. Keep the source-of-truth scripts in your repo (e.g. `.scripts/`) and `cp` them to `~/.local/bin/` after edits.
- Anything touching `~/Documents/` or the iCloud container needs this treatment. This is the #1 reason "my automation silently does nothing" on macOS.
- Processing that calls an AI API needs an API key — **never commit it.** On macOS, store it in the Keychain and read it via `security find-generic-password`. On **Windows** use Credential Manager or a user env var; on **Linux** use `secret-tool` or a gitignored `.env`. The rule is platform-independent (never on disk in the repo); only the vault differs. (More in Layer 3's boundary rules.)

### 2.5 The PDF/DOCX parser (optional but high-value)

**What it does.** Turns PDFs (and DOCX/PPTX, via a LibreOffice→PDF step) into faithful markdown — including tables and charts — using a vision-capable LLM.

**Why it exists.** Most of what's worth saving is in PDFs, and naive text extraction mangles tables and misses chart data. A vision-LLM pass produces a clean `_text.md` you can actually query.

**Build the generic version.** A short Python script (the reference is ~80 lines across three files) that sends each PDF page to a vision model and asks for faithful markdown (HTML tables for merged cells, charts rendered as flat data tables). For DOCX/PPTX, convert to PDF first with `libreoffice --headless --convert-to pdf`. Reference implementation: [.scripts/parser/](../../.scripts/parser/).

**How the reference setup customized it.** Uses the Anthropic SDK with a vision model; falls back to a detailed-summary mode when a famous published work trips a content filter (so you still get a fair-use reference summary).

**Caveats.**
- **Keep the parser tiny and provider-swappable.** It's the one place you're coupled to a specific model — make it trivial to replace.
- Archive originals after DOCX/PPTX conversion; never delete them.

---

## Layer 3 — AI-agent integration (the advanced part)

This is what lets a **cloud AI session** (e.g. Claude's "Cowork" cloud projects, or a separate local project) read your knowledge base and capture back to it — without giving it write access to your real data or your API keys. **This layer has the subtlest design decisions; the rest of this section explains *why* each one exists.**

### 3.1 Why a "cache" instead of direct access

**What it does.** Each consumer project keeps a **read-only clone** of your knowledge base at `<project>/.brainiac-cache/`, refreshed via `git pull` on session start.

**Why it exists — the core constraint.** A cloud AI session can't reach files on your Mac. It runs on its own clone of *some* repo, has no API key, and shouldn't be able to corrupt your canonical data. So you can't just point it at `~/Documents/.../my-kb/`. The solution is a **clone**: the cloud session pulls a read-only copy of your KB into the project, queries that, and sends any new captures *back* through a one-way channel (3.3). Your Mac copy stays the single source of truth.

Three things fall out of this:
- **Read-only by default** — the skill detects it's running from a clone and refuses every mutating command.
- **No secrets travel** — the parser (which needs your API key) never runs in the cloud; only `/kb ask` does.
- **Capture-back is async** — the cloud appends to a handoff file; your Mac merges it on the next local run.

### 3.2 Wiring a new project — the install skill

**What it does.** One command (`/kb-install`) sets up a consumer project: clones the cache, symlinks the skills, updates `.gitignore`, verifies.

**Why it exists.** You'll do this for every project that wants KB access. Automating it means the wiring is identical everywhere, so the read-only boundary holds by construction.

**Build the generic version.** The install skill performs these exact steps (reference: [.claude/skills/kb-install/SKILL.md](../../.claude/skills/kb-install/SKILL.md)):

1. **Confirm the target directory** (`pwd`), so you don't wire the wrong project.
2. **Detect existing setup** — is `.brainiac-cache/` present? Are the symlinks there and pointing to the right place? Is it a git repo? Skip what's already done (idempotent).
3. **Clone or refresh the cache:**
   ```bash
   git clone https://github.com/<you>/<kb-repo>.git .brainiac-cache   # if absent
   git -C .brainiac-cache pull --ff-only                              # if present
   ```
   If the `--ff-only` pull fails (divergent commits), **stop** — that shouldn't happen if boundary rules held, and force-resetting risks losing un-merged captures.
4. **Update `.gitignore`** (git projects only): add `.brainiac-cache/` so you don't commit the whole KB into the consumer repo.
5. **Create project-level skill symlinks** so `/kb ask` works in this project:
   ```bash
   mkdir -p .claude/skills
   ln -s ../../.brainiac-cache/.claude/skills/kb        .claude/skills/kb
   ln -s ../../.brainiac-cache/.claude/skills/kb-update .claude/skills/kb-update
   ```
   (Relative symlinks, two levels up into the cache.)
6. **Verify** — both `SKILL.md` targets resolve; `readlink` shows the expected paths.
7. **Report and suggest a commit** (don't auto-commit):
   ```bash
   git add .gitignore .claude/skills/
   git commit -m "set up KB integration (kb-install)"
   ```

**How the reference setup customized it.** Adds a clear note that mutating modes will be refused from the clone, and special-cases non-git consumers (like the Nolan assistant) by skipping the `.gitignore` step.

**Caveats.**
- **Symlinks, not copies, for the skills** — so a `git pull` of the cache updates the skill logic automatically.
- The skill **must** end up at project level (`.claude/skills/`) in the consumer. User-level skills are invisible to cloud sessions.

### 3.3 Auto-discovery and capture-back

**What it does.** A plugin-distributable version of the skill finds your KB wherever it is, and routes captures from the cloud back to your Mac.

**Why it exists.** Different surfaces have the KB in different places (your Mac, a project cache, a shared cache, or nowhere yet). The skill resolves all of them with one discovery order, then delegates to the canonical skill.

**Build the generic version.** Discovery order (first match wins):

1. **Canonical path** — `~/Documents/.../my-kb/` with a `.git` (you're on your Mac → full mutating modes allowed).
2. **Project cache** — walk up from the current dir looking for an ancestor with `.brainiac-cache/` (you're in a wired consumer project → read-only).
3. **Shared cache** — `~/.brainiac-cache/` (a cloud session with no project context → read-only).
4. **Auto-clone** — if none exist and the repo is private, clone using a read-only token from an env var (`$BRAINIAC_PAT`), failing with a clear "set this token" message if it's missing.

Capture-back: when the cloud session wants to save something, it appends one structured line to `cowork-captures.txt` and commits/pushes:

```
<ISO8601 timestamp> | <source> | <type> | <vault> | <message> [| <optional context>]
2026-05-10T14:23 | projectX | idea | personal | Test the per-folder CLAUDE.md pattern
```

Your next local `/kb` run notices the file is non-empty and proposes merging each line into the right inbox/`ideas.md`. Loop closed.

**How the reference setup customized it.** Ships as a Claude Code *plugin* so it can be installed in cloud sessions; `$BRAINIAC_PAT` is a fine-grained read-only GitHub token; the auto-clone writes the token into the clone's git remote so later pulls work without re-reading the env var.

**Caveats.**
- **`$BRAINIAC_PAT` must be a read-only, fine-grained token**, stored in a gitignored `.env` — never committed. If it's missing, the skill should fail loudly with setup instructions, not silently.
- The cloud session may have no push credentials. If the capture-back push fails, warn the user that the line is saved locally and will be picked up on the next local `/kb` (which pulls before processing) — don't pretend it synced.

### 3.4 The boundary rules (enforced, not optional)

These are enforced *by the skill itself*, so consumers can't opt out:

- **No direct writes** to KB files other than `cowork-captures.txt`.
- **No mutating `/kb` modes** from a clone — `/kb` (process), `/kb update`, `/kb ideas`, `/kb pull`, `/kb sync` all refuse with a clear message.
- **No parser invocation** from the cloud — it needs the Mac Keychain API key, which isn't (and shouldn't be) there.
- **Never delete `cowork-captures.txt`** — it's append-only between merges and must always exist.

**Why this matters:** the boundary is what makes it safe to give many projects access. The canonical copy on your Mac can never be corrupted by a cloud session, because the cloud literally cannot run the commands that would do so.

---

## Layer 4 — The dashboard (optional)

**What it does.** A single "day at a glance" web page that integrates signals from your knowledge base *and* your assistant — recent captures, un-triaged inbox depth, calendar, investments, field news, themes worth exploring — regenerated fresh each morning and on demand.

**Why it exists.** The KB is queryable, but querying is *pull*. A dashboard is *push*: it surfaces what deserves attention without you having to ask. The hard part isn't the cards — it's keeping the dashboard honest and disposable so it never becomes a second source of truth you have to maintain.

There are four design ideas here worth adopting regardless of what your cards show. They're what make a dashboard reliable instead of a thing that rots:

**1. Template + payload split (the renderer is frozen).** Build the page as *one self-contained HTML file* with no server and no build step: all CSS, layout, and the rendering JavaScript live inside it, and the data lives in exactly one block:

```html
<script type="application/json" id="dashboard-data"> … the day's data … </script>
```

Generating the dashboard means copying the template **byte-for-byte** and replacing only the JSON in that block. The `<style>` and renderer `<script>` are never rewritten. The presentation layer is frozen and tested; only the data changes day to day. Ship the template with a complete *sample* payload so it opens and tests standalone.

**2. Derived, disposable, never a source of truth.** The page is regenerated from scratch every time. The markdown files and snapshots it reads stay authoritative — if the dashboard and a source file ever disagree, the *source wins* and you just rebuild. This is the same principle as the whole system: the dashboard is a *read* over your files, never a place state lives. The moment it stores something the files don't have, you've reintroduced the database you were avoiding.

**3. Freshness badges — the honesty signal.** Every card carries a status badge: **fresh** / **stale** / **expired**, computed from how old its underlying data is (e.g. fresh ≤4h, stale 4–24h, expired beyond). The dashboard *never hides how old its data is* — if a data source didn't refresh this morning, the card shows amber rather than silently presenting old data as current. A top banner summarizes ("all sources current" or names what's stale). This one feature is what makes a dashboard trustworthy enough to actually rely on.

**4. Graceful degradation.** Every section renders even when its source is empty or unavailable: a quiet day shows "nothing across the watchlist," an empty inbox shows green zeros, an unavailable source renders an empty card with the right badge rather than breaking the page. A dashboard that crashes when one input is missing won't survive a month of real mornings.

**Build the generic version.** Start small and add cards as you have sources:
1. Write `template.html` — the frozen shell (CSS + a small JS renderer that reads the JSON block and draws cards) + a sample payload.
2. Write a render routine (a skill or briefing step) that assembles the day's real data into the JSON payload and injects it into a copy of the template, producing `dashboard.html`.
3. Trigger it: as the last step of a morning routine, on demand ("refresh my dashboard"), and/or on a schedule.
4. Seed it with KB-derived cards first — newest `index.md` rows, inbox depth, un-promoted `ideas.md` count, an "from the archive" rotation — since those come straight from the markdown. Add calendar/email/news/investment cards as you wire those sources.

**How the reference setup customized it.** The Nolan assistant's dashboard is a ten-card page (top actions, calendar, investment watch, field news, four Brainiac panels, open loops, weekly-review horizon). Notable specifics:
- The four **Brainiac panels** (Recently Added, Key Themes by Role, From the Archive, Capture Health) read directly from the read-only `.brainiac-cache/` clone from Layer 3 — the dashboard is a *consumer* of the KB, exactly like any other Cowork project.
- Calendar/email that can't be reached from the cloud Linux sandbox come from **Mac-side JSON snapshots** — a `launchd` job exports iCloud calendar, recent mail, and an Apple Notes inbox to `~/Nolan/state/` at ~7:50 AM (AppleScript/`icalBuddy` can't run in the sandbox). The same macOS/TCC reasoning as Layer 2. *(Platform-neutral pattern: export the data you can't reach live into a JSON snapshot on a schedule, then read it at render time. On Windows, a Task Scheduler job hitting the Outlook/Graph API does the same job.)*
- It runs in **two contexts** with different fidelity: an interactive Mac run pulls the cache fresh and can verify theme connections against source files; a scheduled sandbox run has no git credentials (Brainiac panels marked stale) and metadata-only confidence. Either way the page renders fully — the badges tell the truth about what's current.
- The "Key Themes" cards are re-derived every run (not carried forward) and each ships a copy-ready "explore prompt" + an "Open claude.ai" link, so a theme pushes straight into a working session that has KB access.

**Caveats.**
- Keep it a *read* over the markdown, never a second source of truth (idea #2 above).
- **Snapshot-backed cards are only as fresh as the last snapshot.** If the Mac was asleep when the export job ran, the badge must go amber — don't compute "fresh" for data you didn't actually refresh.
- Relative-path links into the cache (PDFs, images) only resolve when the page is opened on the machine that has the cache. Web items link to their source URL and travel fine; file-backed items don't.
- State the as-of date on any card showing exported data (e.g. portfolio holdings from a brokerage export) so static figures are never mistaken for live ones.

---

## Appendix — Caveats & workarounds, collected

The non-obvious lessons, in one place. *(Caveats 1–3 are macOS/iOS-specific — see [Platform support](#platform-support-read-this-if-youre-not-on-a-mac) for the Windows/Linux equivalents. The rest are cross-platform.)*

| # | Caveat | Why |
|---|---|---|
| 1 | macOS TCC blocks `launchd` from running scripts in `~/Documents/` or logging there | Put scripts in `~/.local/bin/`, logs in `~/Library/Logs/`; `cp` from your repo after edits |
| 2 | iOS Obsidian can only open vaults in its iCloud container | Hence the "transit vault" mirror + bridge job (2.2) |
| 3 | Use glob loops, not `find`/`while`, for iCloud reads | iCloud placeholder/eviction makes `find` unreliable |
| 4 | URL drops only work for public URLs | Gated content needs the Web Clipper (logged-in browser) |
| 5 | Web Clipper defaults to `Clippings/` | Repoint it to `aa-inbox/` or processing misses clips |
| 6 | Skills must be project-level, not user-level | User-level skills are invisible to cloud sessions |
| 7 | Cloud AI can't reach your Mac and has no API key | Hence the read-only `.brainiac-cache` clone + capture-back channel (3.1) |
| 8 | Never commit secrets | API key in Keychain; `$..._PAT` in a gitignored `.env` |
| 9 | Never overwrite `_summary.md`, never delete originals, never index `materials/` | Hand-confirmed work and privacy opt-outs |
| 10 | Processing must be idempotent | You'll re-run on partial inboxes constantly |

---

*This guide describes a reference implementation. Adopt Layer 1 as-is, adapt Layers 2–3 to your devices and tools, and replace every "How the reference setup customized it" with your own choices.*
