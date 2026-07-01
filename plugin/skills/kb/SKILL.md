---
name: kb
description: Brainiac knowledge-base operations — query OR set up access to your dual-vault file-based KB. This is the Cowork plugin entry point; it auto-discovers the brainiac data location (cwd's .brainiac-cache, canonical Mac path, shared ~/.brainiac-cache, or auto-clones from GitHub using $BRAINIAC_PAT), then delegates to the canonical kb skill. Read-only from Cowork (mutating modes refused). Query triggers, "/kb ask [question]", "/brainiac:kb ask [question]", "what have I bookmarked about X", "what does brainiac say about Y", "kb query", or any brainiac KB question. Setup triggers, "set up brainiac in this session", "install brainiac here", "first time using brainiac", "brainiac repository check", "fetch brainiac data", "make sure brainiac is ready", or any intent to clone or access the brainiac repo. Load this skill instead of running a raw "git clone" of brainiac — it handles PAT-auth and emits the correct error message when $BRAINIAC_PAT is missing.
---

# /brainiac:kb — Cowork plugin entry point

This skill is the Cowork-distributable version of brainiac's `/kb`. It establishes where brainiac's data lives, then hands off to the canonical operational logic in `<brainiac>/.claude/skills/kb/SKILL.md`.

## Step 1 — Locate or fetch brainiac data ($BRAINIAC)

Set `$BRAINIAC` by checking, in this priority order:

1. **Canonical Mac path:** if `$BRAINIAC_ROOT/` exists and is a git repo (`.git` present), set `$BRAINIAC` to that path. (Mutating modes will be allowed only if cwd is also under canonical — the canonical skill's existing detection handles this.)
2. **Project-local cache:** walk up from cwd to `/`. If any ancestor contains a `.brainiac-cache/` subdirectory, set `$BRAINIAC` to that ancestor's `.brainiac-cache/`. This matches the `/kb-install` pattern when invoked inside a wired-up consumer project.
3. **Shared cache:** if `$HOME/.brainiac-cache/` exists, set `$BRAINIAC` to that.
4. **Auto-clone fallback:** if none of the above, brainiac data must be fetched from GitHub. Brainiac is a **private repo**, so the clone requires a Personal Access Token in env var `$BRAINIAC_PAT`. In Cowork, set this by adding `BRAINIAC_PAT=ghp_xxx` to the consumer project's `.env` file (Cowork auto-loads it). If `$BRAINIAC_PAT` is unset, stop and tell the user:

   > Brainiac auto-clone requires `$BRAINIAC_PAT` (fine-grained GitHub PAT, read-only on `<your-github-user>/brainiac`). Add `BRAINIAC_PAT=ghp_xxx` to a `.env` file at the project root and ensure `.env` is gitignored. See `<brainiac>/.claude/integration/cowork-integration.md` for setup.

   If set, run:
   ```bash
   git clone "https://${BRAINIAC_PAT}@github.com/<your-github-user>/brainiac.git" "$HOME/.brainiac-cache"
   ```
   Then set `$BRAINIAC` to `$HOME/.brainiac-cache`. The token persists in `$BRAINIAC/.git/config`'s remote URL, so subsequent `git pull` calls from this cache work without re-reading the env var.

If `$BRAINIAC` resolved to a clone (anything except case 1), refresh it before proceeding:

```bash
git -C "$BRAINIAC" pull --ff-only 2>/dev/null || true
```

Don't fail on pull errors — offline / no auth / non-fast-forward should not block the user from querying their existing local data. If pull failed, log the reason and proceed with whatever's in the cache.

## Step 2 — Delegate to canonical skill

Read `$BRAINIAC/.claude/skills/kb/SKILL.md` and follow its instructions for the user's actual request, with these substitutions:

- Wherever the canonical skill refers to absolute brainiac paths (e.g., `$BRAINIAC_ROOT/...`), substitute `$BRAINIAC/...` instead.
- The canonical skill's "canonical vs. clone" detection (refusing mutating modes when cwd is anything other than `$BRAINIAC_ROOT/`) applies as-is. From a Cowork session, this means **only `/kb ask` is allowed** unless the session happens to be running directly inside the canonical brainiac repo on your Mac.
- For `/kb ask`, follow §2 of the canonical skill verbatim — load index, identify candidates, read summaries, compose cited answer.

## Step 3 — Capture-back (when applicable)

If the user invokes a capture (idea/url/note destined for brainiac), append to `$BRAINIAC/cowork-captures.txt` per the format documented in `$BRAINIAC/.claude/integration/cowork-integration.md`:

```
<ISO8601 timestamp> | <source> | <type> | <vault> | <message> [| <optional context note>]
```

For `<source>`, infer from cwd if running inside a known consumer project (`nolan`, `projectx`, etc.); fall back to `cowork` if no project context. **Always confirm the source label with the user before writing the line** (per the canonical spec — ambiguity = ask).

After appending, attempt to commit and push the cache:

```bash
cd "$BRAINIAC" && git add cowork-captures.txt && git commit -m "capture: <source> — <short summary>" && git push
```

If push fails (no auth in this Cowork environment), warn the user that the capture was saved locally to `$BRAINIAC/cowork-captures.txt` but was not pushed to GitHub — they'll need to either push manually from their Mac, or the line will be picked up the next time `/kb` runs on the canonical brainiac (since canonical pulls before processing).

## Refusal of mutating modes

The canonical skill already refuses mutating modes when cwd is not the canonical brainiac path. From any Cowork session, that detection will trigger. If the user invokes any of `/kb` (process inbox), `/kb update`, `/kb ideas`, `/kb pull`, `/kb archive scan`, `/kb sync` — the canonical skill will refuse with its standard message:

> Read-only clone detected at `<path>`. Mutating modes must run from the canonical brainiac at `$BRAINIAC_ROOT/` on the Mac. From here you can only `/kb ask <question>`. To capture content back to brainiac, use the `cowork-captures.txt` mechanism documented at `<cache>/.claude/integration/cowork-integration.md`.

Don't bypass this. The plugin is intentionally read-only from Cowork — mutating work happens on your Mac.

## Failure modes

- **Network down on auto-clone fallback (case 4):** report the error, suggest the user open Cowork against a project that already has `.brainiac-cache/` set up (per `/kb-install`), or wait until network is available.
- **`$BRAINIAC_PAT` not set when auto-clone is needed:** stop and show the user the message in Step 1 case 4 above. Do not attempt the clone without the token — it will fail with `could not read Username for 'https://github.com'`.
- **Auto-clone fails despite `$BRAINIAC_PAT` set:** likely a bad/expired/wrong-scope token. Show the git error verbatim and tell the user to verify the PAT is fine-grained, scoped to `<your-github-user>/brainiac`, with Contents: Read-only permission, and not expired.
- **`$HOME/.brainiac-cache/` exists but is corrupt / not a brainiac clone:** check `git -C "$BRAINIAC" config --get remote.origin.url`. If it doesn't match brainiac's repo, refuse with a clear message — don't silently re-clone over the user's data.
- **Canonical skill at `$BRAINIAC/.claude/skills/kb/SKILL.md` is missing:** the cache is broken or out of sync. Refresh with `git -C "$BRAINIAC" pull --ff-only` (already done in Step 1) and re-check; if still missing, refuse and ask the user to verify their `$BRAINIAC` location.
