---
name: kb-install
description: Set up brainiac integration in a consumer project — clone the cache, create the project-level symlinks for /kb and /kb-update, update .gitignore, and verify. Run this from inside the consumer project's root directory. Triggers on "/kb-install", "kb-install", "set up brainiac in this project", "wire up brainiac for [project]", "install kb skill here", "add brainiac integration", or any request to bootstrap brainiac in a new consumer project.
---

# /kb-install — Bootstrap a new consumer project for brainiac

This skill automates the setup pattern documented in `brainiac/.claude/integration/cowork-integration.md`. Runs from inside the consumer project's root directory and produces a working `.brainiac-cache/` + project-level symlinks in one batch.

## What this skill does

1. Confirms the current working directory is the intended consumer project.
2. Clones brainiac into `<cwd>/.brainiac-cache/` (or refreshes if already present).
3. Adds `.brainiac-cache/` to `.gitignore` (if `<cwd>` is a git repo and the entry isn't already there).
4. Creates `<cwd>/.claude/skills/kb` and `<cwd>/.claude/skills/kb-update` symlinks pointing into the cache.
5. Verifies the symlinks resolve to real `SKILL.md` files.
6. Prints next-step instructions and a suggested commit (if git repo).

Idempotent — safe to re-run on a project that's already been set up.

## When to invoke

When the user is in a new consumer project (Nolan, <a-course>, executive-panel-simulator, mccombs-research-web, etc.) and wants `/kb` available there. Triggers include the phrases listed in the description, plus any request that boils down to "wire this project up to brainiac."

**Do NOT invoke** when:
- The user is already inside the brainiac repo itself (no cache needed; skill is already at project root).
- The user is in a worktree of brainiac.
- The user explicitly says they want to do the setup manually.

## Step-by-step procedure

### Step 1 — Confirm target directory

Get the current working directory and its basename:

```bash
pwd
basename "$(pwd)"
```

Ask the user: "About to set up brainiac integration in `<basename>` at `<full path>`. Confirm before I proceed?"

Wait for confirmation. If the user names a different project, `cd` there first.

### Step 2 — Detect existing setup

Check what's already in place:

```bash
[ -d .brainiac-cache ] && echo "cache: exists" || echo "cache: missing"
[ -L .claude/skills/kb ] && echo "kb symlink: exists ($(readlink .claude/skills/kb))" || echo "kb symlink: missing"
[ -L .claude/skills/kb-update ] && echo "kb-update symlink: exists ($(readlink .claude/skills/kb-update))" || echo "kb-update symlink: missing"
[ -d .git ] && echo "git: yes" || echo "git: no"
```

Report findings to the user. If everything already exists and resolves correctly (run Step 6's verification), skip to Step 6. Otherwise continue with the missing pieces.

### Step 3 — Clone or refresh the cache

If `.brainiac-cache/` doesn't exist:

```bash
git clone https://github.com/<your-github-user>/brainiac.git .brainiac-cache
```

If it exists, refresh it:

```bash
git -C .brainiac-cache pull --ff-only
```

If the pull fails (`--ff-only` requires fast-forward), it means the cache has divergent commits. Stop and tell the user — this should never happen if the boundary rules are honored, and forcing a reset would risk losing local capture state. Investigate before proceeding.

### Step 4 — Update .gitignore (only if cwd is a git repo)

```bash
git rev-parse --is-inside-work-tree 2>/dev/null
```

If the consumer is a git repo:
- Read `.gitignore` (or treat as empty if missing).
- If `.brainiac-cache/` is not already a line in it (exact match, not substring), append it.
- Otherwise, skip with a note.

If the consumer is NOT a git repo (e.g., Nolan): skip this step entirely, print a note that no `.gitignore` update is needed.

### Step 5 — Create the project-level symlinks

```bash
mkdir -p .claude/skills

# Skip each if it already exists and points to the right target.
[ -L .claude/skills/kb ] || ln -s ../../.brainiac-cache/.claude/skills/kb .claude/skills/kb
[ -L .claude/skills/kb-update ] || ln -s ../../.brainiac-cache/.claude/skills/kb-update .claude/skills/kb-update
```

If a symlink exists but points to the wrong target, ask the user whether to replace it (don't overwrite silently).

### Step 6 — Verify

```bash
ls -la .claude/skills/kb/SKILL.md .claude/skills/kb-update/SKILL.md
readlink .claude/skills/kb
readlink .claude/skills/kb-update
```

Both `SKILL.md` files should resolve. Both `readlink` outputs should be `../../.brainiac-cache/.claude/skills/kb` and `../../.brainiac-cache/.claude/skills/kb-update` respectively.

If either fails, the symlinks are broken — diagnose and fix before declaring success.

### Step 7 — Report and suggest next steps

Print a summary with:

- ✓ what's now in place (cache present, symlinks created, .gitignore updated)
- The two ways to invoke `/kb` going forward:
  - **Local CLI:** `/kb ask "..."` works as a slash command.
  - **Cowork:** `kb ask "..."` (no slash, keyword load) — this is how Cowork loads project skills; not specific to brainiac.
- Mutating modes (`/kb`, `/kb update`, `/kb ideas`, `/kb pull`, `/kb archive scan`, `/kb sync`) will be **refused** because this is a clone of brainiac, not the canonical Mac copy.
- Capture-back path: append to `<cwd>/.brainiac-cache/cowork-captures.txt` per the format in the cowork-integration spec.
- If the consumer is a git repo, propose this commit (don't run it automatically — let the user review):

```bash
git add .gitignore .claude/skills/
git commit -m "set up brainiac kb integration (kb-install)"
```

## Failure modes

- **Network unreachable on clone:** report the error, suggest retry. Don't leave a partial cache.
- **Symlinks unsupported (rare on macOS, common if running over a foreign filesystem):** fall back to `cp -r` of the skill directories with a warning that the user must re-run kb-install after each brainiac update to refresh.
- **Cwd is brainiac itself:** refuse with a clear message — brainiac doesn't need its own integration.
- **Cwd has an existing `.brainiac-cache/` that's not a brainiac clone:** check with `git -C .brainiac-cache config --get remote.origin.url`. If it's not the brainiac GitHub URL, stop and ask the user.

## Why this skill exists

Without it, every consumer project requires manually running ~5 shell commands (clone, gitignore-edit, mkdir, two symlinks, verify), plus knowing which paths to use. Easy to get a step wrong (especially the relative symlink path) and end up with `/kb` returning "unknown skill" with no obvious cause. This skill encodes the working pattern verified in May 2026 with the Nolan consumer.

The source-of-truth for what a "good setup" looks like is in `brainiac/.claude/integration/cowork-integration.md`. If that spec changes, this skill must change to match.
