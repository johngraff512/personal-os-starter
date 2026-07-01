# brainiac Cowork plugin

This directory holds the source files for the `brainiac` Cowork plugin — a packaged form of the brainiac kb skill that you installs via Cowork's customize menu so it's available globally across all Cowork sessions. (One-time-per-project `.env` with `BRAINIAC_PAT` is required for the auto-clone fallback to work — see Cowork auth notes below.)

## What this plugin provides

Two skills, namespaced under `brainiac:`:

- `brainiac:kb` — query the brainiac knowledge base from any Cowork session. Read-only (mutating modes refused).
- `brainiac:kb-update` — health-check and propose cleanups. Read-and-propose only.

## How it differs from the canonical `kb` skill

The canonical kb skill (in `<brainiac>/.claude/skills/kb/`) assumes brainiac data is reachable from cwd or canonical paths. This plugin version adds a **pre-flight step** that locates the brainiac data dynamically:

1. Canonical Mac path (`$BRAINIAC_ROOT/`) — preferred; full mutating modes available IF cwd is also under there.
2. Project-local cache (`<cwd>/.brainiac-cache/` or any ancestor up to `/`) — for Cowork sessions running inside a consumer project that has the cache.
3. Shared cache (`~/.brainiac-cache/`) — fallback for Cowork sessions with no project context (e.g., New Task).
4. Auto-clone to `~/.brainiac-cache/` if none of the above exist — **requires `$BRAINIAC_PAT` env var** (fine-grained GitHub PAT, read-only on `<your-github-user>/brainiac`). In Cowork this comes from a per-project `.env` file; see `brainiac/.claude/integration/cowork-integration.md` Mode 1.

After locating brainiac, the plugin skill **delegates to the canonical SKILL.md** (`<brainiac>/.claude/skills/kb/SKILL.md`) for actual operational logic. This avoids divergence — when the canonical kb skill is updated, the plugin picks it up automatically on the next refresh-pull. Only the pre-flight logic lives in the plugin.

## Cowork auth — why `$BRAINIAC_PAT` is needed

Cowork sandboxes have **no ambient GitHub credentials**. The GitHub connector (Customize → Connectors) authenticates Cowork's backend (UI repo selection, Projects sync) but does NOT propagate to shell `git` inside the sandbox. Verified May 2026 by running `git ls-remote https://github.com/<your-github-user>/brainiac.git` in a Cowork session — fails with `could not read Username for 'https://github.com'` even with the connector enabled.

Since brainiac is a private repo, the auto-clone fallback in case 4 above requires explicit auth. Cowork supports per-project `.env` files (auto-loaded into the sandbox environment), so the chosen pattern is: generate a fine-grained PAT once, drop it in `.env` per consumer project, plugin's auto-clone uses `${BRAINIAC_PAT}` in the clone URL. See `cowork-integration.md` Mode 1 for the exact per-project setup steps.

## Why a plugin (vs. the per-project `.brainiac-cache/` + symlinks pattern)

Both work. The per-project pattern (`/kb-install` in each consumer project) is what you has on disk today. The plugin gives "install once via Cowork customize menu, available in every Cowork session" UX, matching how other plugin-distributed skills behave. Both can coexist — the plugin uses `<cwd>/.brainiac-cache/` if present (matching the per-project pattern's data location), so a project set up with `/kb-install` will work the same under the plugin.

See `brainiac/.claude/integration/cowork-integration.md` for the full integration design.

## Files in this directory

```
plugin/
├── README.md                          # this file (not packaged; dev docs only)
├── .claude-plugin/
│   └── plugin.json                    # plugin manifest (Cowork-required location)
└── skills/
    ├── kb/
    │   └── SKILL.md                   # /brainiac:kb — pre-flight + delegate
    └── kb-update/
        └── SKILL.md                   # /brainiac:kb-update — pre-flight + delegate
```

The `.claude-plugin/plugin.json` location is what Cowork's plugin loader expects — manifest in a `.claude-plugin/` subdirectory at the plugin root, NOT a `plugin.json` at the root itself.

## Packaging — make a `.zip`

Cowork accepts plugins as `.zip` archives whose root contains the plugin directory structure (`.claude-plugin/`, `skills/`, optional `commands/` etc.). Build with:

```bash
cd "<brainiac>/plugin"   # cd into THIS directory
rm -f ../brainiac-fixed.plugin
zip -r ../brainiac-fixed.plugin .claude-plugin skills -x "*.DS_Store"
```

Output goes to `<brainiac>/brainiac-fixed.plugin` (gitignored). The `.plugin` extension is what Cowork's UI labels the file type as; mechanically it's a zip archive — Cowork accepts `.zip` too.

To verify the archive structure before uploading:

```bash
unzip -l ../brainiac-fixed.plugin
# Should show:
#   .claude-plugin/plugin.json
#   skills/kb/SKILL.md
#   skills/kb-update/SKILL.md
# (no leading "plugin/" prefix; the contents are at the zip root)
```

## Installation in Cowork

Two ways:

**A. Direct upload via Cowork's customize/plugin UI.** Drag the `.zip` into the plugin install panel. Cowork unpacks it and registers the plugin. Use this if the wizard isn't necessary.

**B. Via `/cowork-plugin-management:create-cowork-plugin` wizard.** Open a Cowork session against the brainiac repo and invoke the wizard. Point it at `<brainiac>/plugin/` as the source directory. It produces the `.zip` (or its own `.plugin` wrapper) and may handle install in one step.

After install, `brainiac:kb` and `brainiac:kb-update` show in the available skills list of every Cowork session, alongside your other plugin-installed skills.

## Maintenance

- **Canonical kb skill changes** (in `<brainiac>/.claude/skills/kb/`): no plugin re-package needed — the plugin delegates and picks up changes via cache refresh on each invocation.
- **Pre-flight logic changes** (in this directory's `skills/*/SKILL.md` files): re-package and re-install the plugin.
- **`.claude-plugin/plugin.json` changes** (version bump, metadata edit): re-package and re-install.

Bump the `version` field in `.claude-plugin/plugin.json` whenever the plugin source changes (so Cowork knows it's an upgrade rather than a re-install of the same version).
