# Personal OS Starter

A markdown-first **personal operating system**: a file-based "second brain" that captures articles, PDFs, and ideas from any device, processes them with an AI agent, and lets you query everything later — including from cloud AI sessions. **Plain markdown is the source of truth** — no database, no embeddings, no RAG. Anything that can read a text file can read it, so the whole system outlives whatever AI tool comes next.

The loop that holds it together:

```
   CAPTURE              PROCESS                INDEX               QUERY
 (any device)   →   (/kb skill, AI agent)  →  (index.md)   →   (/kb ask, any surface)
 article/PDF/        extract → summarize →    one row per      cited answers from
 idea/URL            rename → file → log      item + folders   index + summaries
```

Capture is cheap and happens all day from whatever device you're on; processing is one batched command that turns the pile into clean, filed, indexed entries (~30–60 seconds of your time). Split into two vaults — **personal** (terse) and **work** (formal citations) — that share infrastructure but differ in convention.

This is a **template**. Click **"Use this template"** → make your own copy → run `setup.sh` → read [`docs/BUILD-GUIDE.md`](docs/BUILD-GUIDE.md).

---

## Works on any OS (built on Mac)

This reference is built on **macOS + iOS**, but the *core* is fully cross-platform. **Layer 1 (the entire knowledge base), the PDF parser, the AI-agent cache, and the dashboard work identically on Windows and Linux.** Only the capture automation (Layer 2) and secret storage are Apple-specific — and each has a direct Windows/Linux equivalent (Task Scheduler/cron for launchd, Credential Manager/`secret-tool` for Keychain, OneDrive/Dropbox for iCloud — often *simpler*, since it removes the need for the iCloud bridge entirely).

Full matrix and per-component equivalents are in [`docs/BUILD-GUIDE.md`](docs/BUILD-GUIDE.md) → **Platform support**. Wherever the guide has no `Platform:` tag, that piece is cross-platform.

---

## ⚠️ First: name your system

This reference calls its **knowledge base "Brainiac"** and its **personal assistant "Nolan."** Those are just the author's names — **pick your own.** They appear throughout the files (and in identifiers like `.brainiac-cache` and `$BRAINIAC_ROOT`).

`setup.sh` prompts you for your two names and your personal details, then rewrites every occurrence consistently. You don't have to hand-edit anything. If you skip `setup.sh`, the system still works — it just stays named "Brainiac"/"Nolan."

---

## Quick start

```bash
# 1. After "Use this template" and cloning your copy:
bash setup.sh          # prompts for your names, paths, GitHub user, etc.
                       # (on Windows, run under WSL or Git Bash)

# 2. Store your AI API key OUTSIDE the repo (macOS example):
security add-generic-password -a "$USER" -s '<your-keychain-entry>' -w

# 3. Open the repo in Claude Code and process the example inbox:
/kb                    # see the pipeline run on the example items
/kb ask "what's in my knowledge base?"
```

Then read [`docs/BUILD-GUIDE.md`](docs/BUILD-GUIDE.md) — it's built in **layers** so you can stop after Layer 1 (a complete working KB) and add capture/agent integration later.

## How it's built — the layers

The build guide is organized so you can stop after any layer and have a working system. In short:

- **Layer 0 — The mental model.** The five principles (markdown as source of truth, two vaults, batched processing, agent-proposes/you-confirm, one index read directly). Read this first; it makes everything else make sense.
- **Layer 1 — The foundation** *(everyone needs this; 100% cross-platform)*. The repo structure, the `CLAUDE.md` rules the agent reads, the `/kb` skill (the engine), Obsidian as the reader, and git. **A complete, useful knowledge base stops here.**
- **Layer 2 — Frictionless capture** *(adapt to your devices)*. One-tap voice + share-sheet capture (iOS Shortcuts), the iCloud "transit-vault" bridge, the Web Clipper for full article bodies, background scheduling, and the vision-LLM PDF/DOCX parser.
- **Layer 3 — AI-agent integration** *(the advanced part)*. A read-only `.brainiac-cache` clone lets cloud AI sessions query your KB and capture back to it — without write access to your data or your API keys. One command (`/kb-install`) wires a new project; the boundary is enforced by the skill itself.
- **Layer 4 — The dashboard** *(optional)*. A single self-contained HTML "day at a glance," regenerated from the vaults (and your assistant) each morning. Built on a frozen template + a fresh data payload, with honesty badges (fresh/stale/expired) and graceful degradation.

## What's in here

```
.
├── docs/BUILD-GUIDE.md     # the layered build-then-adapt guide — start here
├── setup.sh                # one-time: fills in your names + details
├── CLAUDE.md               # rules the AI agent reads every session
├── .claude/
│   ├── skills/             # /kb, /kb-update, /kb-install
│   └── integration/        # the read-only cache integration spec
├── .scripts/               # the iCloud bridge, inbox processor, PDF parser
├── ios-shortcuts/          # (add your exported .shortcut files here)
├── personal/               # example vault — terse, no citations
└── work/                   # example vault — APA-style citations
```

Both vaults ship with **2 example items** so the structure is legible and `/kb ask` has something to answer. Replace them with your own.

## What this is built on

The "LLM-Wiki" pattern (Karpathy) and file-based knowledge-base conventions. The bet: keep the markdown, throw away everything else when a better tool appears.

## Caveats worth knowing up front

The non-obvious workarounds (macOS launchd/TCC limits, the iCloud "transit vault" bridge, why AI-agent access needs a read-only cache) are documented in the BUILD-GUIDE's **Appendix — Caveats & workarounds**. Read it before fighting any of them.

## License

MIT — see [`LICENSE`](LICENSE). Use it, fork it, adapt it.
