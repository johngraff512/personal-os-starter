---
name: kb-update
description: Health check and consolidation pass over the brainiac knowledge base — find orphaned files or index rows, propose folder merges, validate frontmatter. This is the Cowork plugin entry point; it auto-discovers the brainiac data location (same as brainiac:kb), then delegates to the canonical kb-update skill. Read-and-propose only — never mutates. Triggers on "/kb update", "/brainiac:kb-update", "kb health check", "clean up brainiac", "find orphans", "merge folders", "topic drift".
---

# /brainiac:kb-update — Cowork plugin entry point

This skill is the Cowork-distributable version of brainiac's `/kb update`. Same data-location pre-flight as `brainiac:kb`, then delegates to the canonical kb-update logic.

## Step 1 — Locate brainiac data ($BRAINIAC)

Identical to `brainiac:kb` Step 1. Priority:

1. Canonical Mac path (`$BRAINIAC_ROOT/`)
2. Project-local cache (`<cwd-or-ancestor>/.brainiac-cache/`)
3. Shared cache (`$HOME/.brainiac-cache/`)
4. Auto-clone to `$HOME/.brainiac-cache/`

Refresh with `git -C "$BRAINIAC" pull --ff-only` if a clone. Don't fail on pull errors.

## Step 2 — Delegate to canonical skill

Read `$BRAINIAC/.claude/skills/kb-update/SKILL.md` and follow its instructions, substituting `$BRAINIAC/...` for absolute brainiac paths.

The canonical kb-update skill is read-and-propose-only — it never mutates the vault, only reports what it found and what it would change. So even from a Cowork session (where mutating modes are refused), `/brainiac:kb-update` runs to completion and produces a useful report.

## Step 3 — Output

The report goes to the user as a normal chat response. If the user wants to apply any of the proposed changes, they need to do that on the canonical brainiac (your Mac) — the plugin doesn't write anything back.

## Failure modes

Same as `brainiac:kb` Step 1 failure modes. If `$BRAINIAC/.claude/skills/kb-update/SKILL.md` is missing after data location + refresh, refuse and ask the user to verify their setup.
