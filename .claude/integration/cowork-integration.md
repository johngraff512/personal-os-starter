# Brainiac × Cowork integration — canonical spec

This is the **single source of truth** for how any consumer project (Nolan, a <a-course> class Cowork project, a future research project, etc.) integrates with Brainiac. Other projects' integration files (e.g., `<nolan>/system/brainiac-integration.md`) reference this document.

## The pattern in one paragraph

A consumer project keeps a **read-only clone of the brainiac repo at `<project>/.brainiac-cache/`**, refreshed (`git pull --ff-only`) at session start. The kb skill ships with the clone. A **project-level symlink at `<project>/.claude/skills/kb/`** (pointing into the cache) makes the skill discoverable as a `/kb` slash command. To capture insights back to brainiac, the consumer **only** appends to `<cache>/cowork-captures.txt` and commits + pushes — it never modifies brainiac files directly. you merges accumulated captures during his next interactive `/kb` run on the Mac.

This pattern works in **both** local Claude Code (CLI on the Mac) and Cowork sessions. Cowork operates on the locally-cloned consumer repo, so it can see `.brainiac-cache/` and the symlinks resolve normally.

### Cowork-specific notes (verified May 2026)

- **Cowork loads project skills by keyword, not as slash commands.** Type `kb ask "..."` (no slash) in a Cowork session — Cowork's discovery walks the project tree, finds the kb skill (either at `<project>/.claude/skills/kb/` or nested in `.brainiac-cache/.claude/skills/kb/`), and offers to load it. After confirming, the skill runs. `/kb` as a slash command does NOT work in Cowork for project-level skills — this is a Cowork-wide design choice (same for any project skill), not specific to brainiac.
- **The project-level symlink at `<project>/.claude/skills/kb/` is still recommended** because (a) it makes the skill discoverable at the obvious entry-point for anyone exploring the project, (b) it lets local Claude Code (CLI) on your Mac resolve `/kb` as a slash command, and (c) future Cowork releases may surface project skills as slash commands. The `/kb-install` skill (see Setup below) creates these symlinks automatically.
- **`~/.claude/skills/` is not visible to Cowork sessions.** User-level skill installations on your Mac help local Claude Code (CLI) but do not flow through to Cowork. The kb skill must reach Cowork via the consumer project's `.brainiac-cache/`, or by opening Cowork against the brainiac repo itself.
- **Cowork "New Task" with no project connected has no skills available.** Same constraint as a local Claude Code session with no project context. To use kb from Cowork, open it against (a) the brainiac repo directly, or (b) any consumer project that has `.brainiac-cache/` set up per the steps below.

## Setup — three install modes

### Mode 1: Cowork plugin (recommended for Cowork-heavy users)

Install the **brainiac Cowork plugin** once via Cowork's customize/plugin menu. Once installed, `brainiac:kb` and `brainiac:kb-update` are available in every Cowork session. The plugin auto-discovers brainiac data: it prefers `<cwd>/.brainiac-cache/` if present (so projects wired with `/kb-install` work seamlessly), falls back to the Mac canonical, then to `~/.brainiac-cache/`, and auto-clones if nothing exists.

Source files live in `brainiac/plugin/`. To package: in a Cowork session against the brainiac repo, invoke `/cowork-plugin-management:create-cowork-plugin` and point it at `brainiac/plugin/` as the source. The wizard produces a `.plugin` file; install via Cowork's UI. See `brainiac/plugin/README.md` for the full design.

**Cowork auth limitation — per-project `$BRAINIAC_PAT` requirement.** Cowork sandboxes have **no ambient GitHub credentials**, not even via the GitHub connector (which only authenticates Cowork's backend, not shell `git`). The plugin's auto-clone fallback therefore requires a Personal Access Token in env var `$BRAINIAC_PAT`, supplied per consumer project. Verified May 2026.

Per-project setup (one-time per Cowork project where you want `/kb ask` to work):

1. **Generate a fine-grained PAT once** (reuse across all projects): GitHub → Settings → Developer settings → Personal access tokens → Fine-grained → repository access = `<your-github-user>/brainiac` only, permissions = Contents: Read-only, expiration = 1 year. Store the token securely (e.g., 1Password) — GitHub won't show it again.

2. **In a Cowork session against the project**, at project root:
   ```bash
   echo "BRAINIAC_PAT=ghp_your_token_here" > .env
   grep -qxF '.env' .gitignore 2>/dev/null || echo '.env' >> .gitignore
   git add .gitignore && git commit -m "gitignore .env for brainiac PAT" && git push
   ```
   The token appears in Cowork chat history once for that project. Cowork preserves the working tree across sessions, so `.env` persists.

3. **Test:** `/kb ask "..."` — plugin's auto-clone reads `$BRAINIAC_PAT`, clones brainiac into `~/.brainiac-cache/` inside the sandbox, answers.

Rotation: when the PAT expires, generate a new one and update `.env` in each project. (Or use the plugin's `/kb-install`-via-Cowork future enhancement if/when added.)

Failure modes:
- **`$BRAINIAC_PAT` unset:** plugin refuses to attempt the clone (private repo would fail anyway). User sees the message in `plugin/skills/kb/SKILL.md` Step 1 case 4.
- **PAT expired/wrong-scope:** plugin shows the git error verbatim. Fix by regenerating in GitHub with correct scope.
- **`.env` not auto-loaded by Cowork:** rare; verify the file is at the project root, syntax is `KEY=value` (no quotes, no spaces around `=`), and Cowork hasn't disabled .env scanning in account settings.

### Mode 2: Per-project setup via `/kb-install`

Invoke `/kb-install` from inside the consumer project root. It does the per-project steps automatically and idempotently — clone `.brainiac-cache/`, update `.gitignore` (if git repo), create the project-level symlinks, verify, and propose a commit. See `brainiac/.claude/skills/kb-install/SKILL.md` for what it runs.

Useful when (a) you don't have the plugin installed, (b) you want a project-local cache for capture-back specificity, or (c) you also use local Claude Code CLI in that project and want `/kb` as a slash command.

### Mode 3: Manual setup

(Equivalent to what `/kb-install` does, in case you want to script it yourself.)

```bash
# From the consumer project root:
git clone https://github.com/<your-github-user>/brainiac.git .brainiac-cache
echo ".brainiac-cache/" >> .gitignore   # do not nest brainiac inside the consumer's own git tracking

# Expose the kb skill at project level. Useful for discoverability and for
# local CLI slash-command resolution; Cowork loads project skills by keyword
# regardless, so the symlink isn't strictly required for Cowork to work.
mkdir -p .claude/skills
ln -s ../../.brainiac-cache/.claude/skills/kb .claude/skills/kb
ln -s ../../.brainiac-cache/.claude/skills/kb-update .claude/skills/kb-update
# If the consumer is a git repo: git add .claude/skills/ && commit && push.
# If the consumer is local-only (e.g., Nolan): the symlinks just live on disk;
# Cowork sees them because it operates on the local working copy.
```

## Session-start hook

At the start of every consumer session (local CLI or Cowork), run:

```bash
git -C .brainiac-cache pull --ff-only
```

If the pull fails (`--ff-only` requires fast-forward), it means the cache has divergent local commits — should not happen if the boundary rules are honored. Investigate before doing anything else.

## Querying brainiac — `/kb ask`

Inside the consumer session, with cwd at the project root or anywhere inside `.brainiac-cache/`:

```
/kb ask "What did I bookmark about LLM evaluation?"
```

The skill (loaded from `.brainiac-cache/.claude/skills/kb/SKILL.md`) reads the cloned vault's `index.md`, `_summary.md` files, and `crossrefs.md`, and returns a cited answer. Citations use relative paths under `.brainiac-cache/` so they resolve correctly inside the consumer session.

The skill detects it's running against a clone (not the canonical brainiac on your Mac) and **refuses any mutating mode**:

- `/kb` (process inbox) — refused
- `/kb update` — refused
- `/kb ideas` — refused
- `/kb pull` — refused
- `/kb archive scan` — refused
- `/kb sync` — refused
- `/kb ask` — **allowed**

## Capture-back — `cowork-captures.txt`

When the consumer wants to capture an idea, URL, or note back to brainiac, append a single line to `<cache>/cowork-captures.txt` and commit + push the cache. Format (pipe-separated, one capture per line):

```
<ISO8601 timestamp> | <source> | <type> | <vault> | <message> [| <optional context note>]
```

Fields:
- **`<ISO8601 timestamp>`** — `YYYY-MM-DDTHH:MM` (local time fine). Used for the `ideas.md` HH:MM annotation on merge.
- **`<source>`** — short lowercase identifier of the consumer project. Examples: `nolan`, `projectx`, `research`, `general`. The merge step uses this to annotate `ideas.md` entries `(via <source>)` so you can see provenance.
- **`<type>`** — exactly one of:
  - `idea` — a one-line thought. Routes to `<vault>/ideas.md`.
  - `url` — a URL to ingest. Routes to `<vault>/aa-inbox/urls.txt` (then processed on next `/kb` run via the URL-fetch flow).
  - `note` — a structured note longer than one line. Routes to `<vault>/aa-inbox/<date>-<source>-note-<slug>.md` for the next `/kb` run to summarize and index.
- **`<vault>`** — `personal` or `work`. If ambiguous, the consumer **must ask you** before writing the line.
- **`<message>`** — the text (for `idea`/`note`) or the URL (for `url`).
- **`<optional context note>`** — only used for `url` type when there's a "why I saved it" note attached.

Examples:

```
2026-05-10T14:23 | nolan       | idea | personal | Should test Karpathy's per-folder CLAUDE.md pattern
2026-05-10T14:25 | projectx      | url  | work     | https://example.com/llm-evaluation-paper | Possible Class 4 reading
2026-05-10T16:02 | research    | note | work     | Acme Corp AI risk register: implementation could become a teaching case
```

After appending, commit and push the cache:

```bash
cd .brainiac-cache
git add cowork-captures.txt
git commit -m "capture: <source> — <short summary>"
git push
```

## Round trip — when do captures actually land in brainiac?

Captures pushed to GitHub from a consumer project are pulled by your Mac during his **next interactive `/kb` run**. The `kb` skill's §0 (Detect cowork-captures.txt) runs at the start of every `/kb` invocation on the canonical brainiac:

1. `git pull --ff-only` to fetch any pushed captures.
2. Parse `cowork-captures.txt`.
3. Propose merges in a batch table.
4. After you confirms, route per type, truncate the file, and push the cleared state.

Latency: at minimum, the time between when you push and when you next runs `/kb`. In practice that's typically the same morning or evening.

## Boundary rules (what the consumer can NEVER do)

- **Never modify brainiac files directly.** Not in `personal/`, not in `work/`, not in `index.md`, not in `topics.md`, not in `log.md`. Only `cowork-captures.txt` is writable.
- **Never run mutating `/kb` modes from the clone.** The skill enforces this; consumers shouldn't try to bypass.
- **Never invoke the parser** (`<cache>/.scripts/parser/parse_pdf.py`). The parser needs an Anthropic API key from your macOS Keychain that isn't (and shouldn't be) available in Cowork. PDF parsing is a Mac-side responsibility.
- **Never run `/kb sync`** from the clone. The clone has no GitHub credentials beyond the read-only-pull pattern; pushes from consumers go only via the `cowork-captures.txt` route.
- **Never delete `cowork-captures.txt`.** Append-only between merges. The file must always exist (even if empty) at the cache root.

## Per-project customization (the only thing that varies)

The trigger phrases and skill names that the consumer's CLAUDE.md uses to invoke this integration. Examples:

- **Nolan**: triggers like `"What did I bookmark about X?"`, `"Capture this for brainiac"`, `"Save the idea: ..."`. Implemented as a `save-to-brainiac` skill in Nolan's `skills/` directory.
- **<a-course>**: triggers like `"What past Acme Corp materials do I have?"`, `"Save this PDF for class 4"`. Implemented inline in the project's CLAUDE.md as instructions to the agent.
- **Research project**: triggers tailored to research workflow; same underlying mechanism.

Everything else (cache path, file format, skill behavior, git operations) is identical across consumers.

## Verification (per-consumer)

After wiring a consumer:

1. **Read access works.** From a session in the consumer's repo (local CLI or Cowork): `/kb ask "test"` returns either a real answer or "vault is empty / no relevant items" — not "unknown skill" and not an error. If you get "unknown skill" in Cowork specifically, the project-level symlinks at `<project>/.claude/skills/kb` and `kb-update` are missing or broken.
2. **Read-only refusal works.** Try `/kb update` from the consumer session → refused with the canonical-only message.
3. **Capture round trip works.** Capture an idea via the consumer's trigger → check the cache's `cowork-captures.txt` has the new line → push → on Mac, run `/kb` and verify §0 detects the line, proposes the merge, and after confirmation the line appears in `<vault>/ideas.md` annotated `(via <source>)`.

## Maintaining this document

This doc is the canonical reference. When something changes (new field in `cowork-captures.txt`, new boundary rule, new mutating mode added to brainiac), update **here first**, then update the consumer-specific files (`<nolan>/system/brainiac-integration.md`, the <a-course> CLAUDE.md block, etc.) to match. Don't let consumer files drift from this spec.
