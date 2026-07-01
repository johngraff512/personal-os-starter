# Personal OS Starter

A markdown-first **personal operating system**: a file-based knowledge base with frictionless capture (iOS Shortcuts, web clipper, voice) and read-only AI-agent integration. Plain markdown is the source of truth — no database, no embeddings, no RAG. Anything that can read a text file can read it, so it outlives any single AI tool.

This is a **template**. Click **"Use this template"** → make your own private copy → run `setup.sh` → read [`docs/BUILD-GUIDE.md`](docs/BUILD-GUIDE.md).

---

## ⚠️ First: name your system

This reference implementation calls its **knowledge base "Brainiac"** and its **personal assistant "Nolan."** Those are just the author's names — **pick your own.** They appear throughout the files (and in identifiers like `.brainiac-cache` and `$BRAINIAC_ROOT`).

`setup.sh` prompts you for your two names and your personal details, then rewrites every occurrence consistently. You don't have to hand-edit anything. If you skip `setup.sh`, the system still works — it just stays named "Brainiac"/"Nolan."

---

## Quick start

```bash
# 1. After "Use this template" and cloning your copy:
bash setup.sh          # prompts for your names, paths, GitHub user, etc.

# 2. Store your AI API key in the macOS Keychain (never in the repo):
security add-generic-password -a "$USER" -s '<your-keychain-entry>' -w

# 3. Open the repo in Claude Code and process the example inbox:
/kb                    # see the pipeline run on the example items
/kb ask "what's in my knowledge base?"
```

Then read [`docs/BUILD-GUIDE.md`](docs/BUILD-GUIDE.md) — it's built in **layers** so you can stop after Layer 1 (a complete working KB) and add capture/agent integration later.

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
