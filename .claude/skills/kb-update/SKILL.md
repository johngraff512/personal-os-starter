---
name: kb-update
description: Health check and consolidation pass over the brainiac knowledge base. Use this skill when the user wants to clean up the brainiac vaults, find orphaned files or index rows, propose folder merges, validate frontmatter, or run a "is everything still in order" sweep. Triggers on "/kb update", "kb health check", "clean up brainiac", "find orphans", "merge folders", "topic drift", or related cleanup requests. Narrower toolset than the main /kb skill — this one is read-and-propose only, never ingests new content.
---

# /kb update — Brainiac health check and consolidation

A focused sub-skill of the brainiac `/kb` family. Where the main `/kb` skill *ingests* new content, this one *audits* what's already there.

This is a thin pointer to the canonical implementation. **Read `.claude/skills/kb/SKILL.md` §3 (`/kb update`) for the full spec.** The split exists to keep the toolset narrow: `/kb update` only reads the filesystem and proposes changes — it never invokes the parser, never fetches URLs, never writes new content.

## Quick reference

```
/kb update              # health check + propose fixes (interactive confirmation)
/kb update --full       # also re-validate every _summary.md frontmatter
```

## What it checks

1. **Orphan files** — items with `_summary.md` but no row in `index.md` → propose adding rows.
2. **Orphan rows** — rows in `index.md` whose linked `_summary.md` is gone → propose removal.
3. **Empty folders** — topic folders with no items → propose deletion + cleanup of `topics.md`.
4. **Topic drift** — similar folder names (e.g., `ai/` and `artificial-intelligence/`) → propose merge.
5. **(With `--full`)** Frontmatter validation — required fields per vault template, sane date formats, valid `extraction` values.

## Invariants

- Never delete content without user confirmation. **Read-and-propose** is the rule.
- Never re-process inbox items. That's `/kb`'s job, not `/kb update`'s.
- The skill terminates by appending a one-line summary to the active vault's `log.md`:
  ```
  ## YYYY-MM-DD HH:MM
  - **update sweep:** 3 orphans fixed, 1 merge proposed (pending).
  ```

## Active-vault detection

Same rules as `/kb`:
- `$BRAINIAC_ROOT/personal/...` → personal
- `$BRAINIAC_ROOT/work/...` → work
- `$BRAINIAC_ROOT/` (root) → ask user, or run on both

## See also

- `.claude/skills/kb/SKILL.md` — the full /kb skill (all seven modes including this one)
- `~/.claude/plans/i-am-interested-in-zesty-lovelace.md` — project architecture (user-level, not in this repo)
