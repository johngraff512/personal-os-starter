# Brainiac — Cheat Sheet

Quick reference for the dual-vault knowledge base (`personal/`, `work/`).

## The one rule that explains everything

There are two environments, and what you can do depends on which you're in:

| Environment | Where | What it is | What you can do |
|---|---|---|---|
| **Code** | Claude Code on the Mac, run from `~/Documents/AI Development/brainiac/` | The **canonical** brainiac — the source of truth | **Everything** — ingest, query, maintain, sync |
| **Cowork** | A consumer project's `.brainiac-cache/` (Nolan, Atlas Energy, <a-course>, etc.) | A **read-only clone** pulled from GitHub | **Query only** (`kb ask`) — all writing is refused |

Writes only happen in **Code** on the Mac. Cowork reads a copy and can ask questions; to push content *back* to brainiac from Cowork, use the capture-back file (bottom of page).

---

## Commands

### In Code (Mac, canonical) — all modes

| Command | What it does |
|---|---|
| `/kb` | **Process inbox.** Drain `aa-inbox/` — parse each item, write `_text.md` + `_summary.md`, propose folder + filename, index, log. Run from a vault for that vault, or from the root for both. |
| `/kb ask <question>` | Answer from the index + summaries, with citations. |
| `/kb update` | Health check — sync `index.md` with disk, find orphans, propose folder merges. Read-and-propose; you confirm before anything moves. |
| `/kb ideas` | Promote new lines in `ideas.md` to permanent homes (rules, topic notes, blog seeds, or "kept"). |
| `/kb pull <path>` | Copy an external file (typically OneDrive Teaching) into the **work** vault and index it. Original is untouched. |
| `/kb archive scan` | Refresh `work/course-archive-index.md` — a metadata-only index of the OneDrive Faculty/Teaching folder. |
| `/kb sync` | `git add/commit/push` to the private GitHub repo, then fast-forward every `.brainiac-cache/` on the Mac so Cowork projects see the new content. |

### In Cowork (consumer project, clone) — query only

| Command | What it does |
|---|---|
| `kb ask <question>` | Query the KB. (Cowork loads skills by keyword, so **no leading slash** — `kb ask ...`, not `/kb ask ...`.) |
| `kb update` | Runs read-and-propose only; it can *suggest* cleanups but **cannot apply** them from a clone. Carry anything actionable back to Code. |

Any mutating mode (`/kb` process, `ideas`, `pull`, `archive scan`, `sync`) is **refused** in Cowork with a message telling you to run it on the Mac. That's by design — it stops a clone from diverging from the canonical copy.

---

## Add Brainiac to a new Cowork project

**Do the setup on the Mac, not from inside Cowork.** A Cowork sandbox has no GitHub credentials for the private brainiac repo, so it can't clone the cache itself — `/kb-install` run from within Cowork fails, and the plugin's "set a `$BRAINIAC_PAT`" prompt is the unreliable workaround (skip it). The cache must be cloned on the Mac, where your git credentials live. Cowork then sees the cache because it operates on the local project folder.

**Run these from the consumer project's root, in Terminal or local Claude Code on the Mac:**

```bash
cd "/path/to/the consumer project"

# 1. Clone the read-only cache (this is the step that needs Mac git creds)
git clone https://github.com/<your-github-user>/brainiac.git .brainiac-cache

# 2. Expose the skill at project level (makes kb discoverable in Cowork + /kb in local CLI)
mkdir -p .claude/skills
ln -s ../../.brainiac-cache/.claude/skills/kb .claude/skills/kb
ln -s ../../.brainiac-cache/.claude/skills/kb-update .claude/skills/kb-update

# 3. ONLY if the project is its own git repo, keep the cache out of its tracking:
echo ".brainiac-cache/" >> .gitignore
```

(Most of your Cowork projects — Nolan, Atlas — are local-only folders with no `.git`, so step 3 is skipped. The on-disk cache + symlinks are all Cowork needs.)

After this, open the project in Cowork and use `kb ask "..."`. No PAT, no `.env` required.

> **Equivalent shortcut, Mac only:** running `/kb-install` from **local Claude Code on the Mac** (not Cowork) does steps 1–3 automatically and idempotently. The manual commands above are the fallback and the thing to use when you're not sure.

### ⚠️ Never host the cache in a OneDrive-synced folder

Don't put `.brainiac-cache/` inside an OneDrive folder (e.g. `OneDrive .../Faculty/<course>/`). OneDrive would sync the **entire brainiac repo — including your `personal/` vault and all `.git` internals — up to UT Austin's cloud.** That's a privacy/data-governance problem and it spams OneDrive with thousands of git objects. There's also no clean way on macOS to exclude one subfolder from OneDrive upload. The cache belongs in a **local** folder under `~/Documents/Claude/Projects/`, which is also where `/kb sync`'s auto-refresh looks.

### Course projects that use OneDrive materials (the two-folder pattern)

A Cowork project can be pointed at **more than one folder**. For a course where the materials live in OneDrive but you still want brainiac, split them:

| Folder attached to the Cowork project | Holds | Synced to UT cloud? |
|---|---|---|
| `~/Documents/Claude/Projects/<Course>/` | `.brainiac-cache/` + the `.claude/skills` symlinks | No — local only ✅ |
| `~/Library/CloudStorage/OneDrive-.../Faculty/<Course>/` | Class documents (slides, readings, etc.) | Yes (already lives there) |

This is the verified setup for **<a-course>** (validated 2026-06-04): brainiac cache in the local project folder, OneDrive `Faculty/<a-course>/` attached as a second folder for class docs. `kb ask` resolves the skill from the local cache; Cowork can read the OneDrive docs in the same session. Best of both, with no personal-vault data leaking to OneDrive.

> To pull a specific OneDrive course file *into* the brainiac work vault as an indexed item, use `/kb pull "<onedrive-path>"` from Code on the Mac. The OneDrive `Faculty/` tree is also picked up by `/kb archive scan` for `course-archive-index.md`.

### Keeping a project's cache fresh

The cache is a snapshot from clone time. To pull new brainiac content into a consumer project, on the Mac:

```bash
git -C "/path/to/the consumer project/.brainiac-cache" pull --ff-only
```

`/kb sync` on the Mac does this automatically for **every** `.brainiac-cache/` it finds under `~/Documents` after a successful push — so the normal refresh flow is just: capture/process in Code → `/kb sync` → every Cowork project is current.

---

## Capture content back from Cowork → Brainiac

Cowork can't write to brainiac directly. To send an idea, URL, or note back, append a line to `<project>/.brainiac-cache/cowork-captures.txt`:

```
<ISO8601 timestamp> | <source> | <type> | <vault> | <message> [| <optional note>]
```

- `<source>` — short project id: `nolan`, `research-x`, `projectx`, …
- `<type>` — `idea` | `url` | `note`
- `<vault>` — `personal` | `work`

The next `/kb` run on the Mac detects these, proposes how to merge them, and clears the file.

---

## Where things live

| Path | What |
|---|---|
| `~/Documents/AI Development/brainiac/` | Canonical brainiac (Mac) |
| `personal/`, `work/` | The two vaults — each has its own `CLAUDE.md`, `index.md`, `topics.md`, `log.md`, `ideas.md`, `aa-inbox/` |
| `aa-inbox/` (top level) | "Route it later" drop zone — `/kb` proposes a vault |
| `<vault>/aa-inbox/urls.txt` | Append URLs here (iOS Shortcut target) |
| `<vault>/ideas.md` | Append raw ideas here; `/kb ideas` promotes them |
| `work/crossrefs.md` | Pointers to external KBs (<your-research-kb>, OneDrive, etc.) |
| `work/course-archive-index.md` | Metadata index of the OneDrive Teaching folder |

**Background automation (no command needed):** a 6:30 AM LaunchAgent pre-parses PDFs and auto-commits; another runs every 5 min to ferry iOS Web Clipper clips from iCloud into the vault inboxes.
