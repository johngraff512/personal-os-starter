#!/usr/bin/env bash
#
# setup.sh — first-run configuration for the Personal OS starter kit.
# Copy this into the public template repo root. It replaces the placeholder
# tokens shipped in the template with the adopter's real values.
#
# Run once, from the repo root, after "Use this template" → clone:
#     bash setup.sh
#
# It edits files in place (a .bak of each changed file is left behind; delete
# them once you've confirmed things look right).

set -euo pipefail

echo "=== Personal OS starter — first-run setup ==="
echo "This rewrites placeholder values throughout the repo. Press Ctrl-C to abort."
echo

# --- 1. Collect the adopter's values -----------------------------------------
# The reference implementation names its knowledge base "Brainiac" and its
# personal assistant "Nolan". Those are NOT part of the design — pick your own.
echo "First, name your system (the reference calls these Brainiac and Nolan):"
read -r -p "  Name for your KNOWLEDGE BASE (e.g. Brainiac): " KB_NAME
read -r -p "  Name for your PERSONAL ASSISTANT (e.g. Nolan), or leave blank if none: " ASSIST_NAME
echo
read -r -p "Absolute path where your KB will live (e.g. \$HOME/Documents/my-kb): " KB_ROOT
read -r -p "Your GitHub username: " GH_USER
read -r -p "Your KB repo name (e.g. my-kb): " GH_REPO
read -r -p "Your name (for commit/author fields): " FULL_NAME
read -r -p "Your email: " EMAIL
read -r -p "macOS Keychain entry name for your AI API key (e.g. my-kb-api-key): " KEYCHAIN_ENTRY
read -r -p "LaunchAgent label prefix (reverse-DNS, e.g. com.you.kb): " LA_PREFIX

# Expand a leading $HOME / ~ in the path the user typed.
KB_ROOT="${KB_ROOT/#\~/$HOME}"
KB_ROOT="$(eval echo "$KB_ROOT")"

# Derive lowercase identifier forms from the KB name (e.g. "Brainiac" -> "brainiac").
KB_LOWER="$(echo "$KB_NAME" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')"
KB_UPPER="$(echo "$KB_LOWER" | tr '[:lower:]' '[:upper:]')"
ASSIST_NAME="${ASSIST_NAME:-your-assistant}"

echo
echo "About to replace:"
echo "  <your-kb-name>             -> $KB_NAME       (identifiers: $KB_LOWER / \$$KB_UPPER)"
echo "  <your-assistant-name>      -> $ASSIST_NAME"
echo "  \$BRAINIAC_ROOT             -> $KB_ROOT"
echo "  <your-github-user>/<repo>  -> $GH_USER/$GH_REPO"
echo "  <your-name>                -> $FULL_NAME"
echo "  <your-email>               -> $EMAIL"
echo "  <your-keychain-entry>      -> $KEYCHAIN_ENTRY"
echo "  com.<you>.<kb>             -> $LA_PREFIX"
echo
read -r -p "Proceed? [y/N] " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }

# --- 2. Rewrite placeholders across the tree ---------------------------------
# Skip .git, this script, and the PUBLISHING doc (which intentionally lists
# placeholders). Edits are made in place with a .bak backup.
find . \
  -type f \
  \( -name '*.md' -o -name '*.sh' -o -name '*.plist' -o -name '*.py' -o -name '*.txt' \) \
  -not -path './.git/*' \
  -not -name 'setup.sh' \
  -not -name 'PUBLISHING.md' \
  -print0 |
while IFS= read -r -d '' f; do
  sed -i.bak \
    -e "s|<your-kb-name>|$KB_NAME|g" \
    -e "s|<your-assistant-name>|$ASSIST_NAME|g" \
    -e "s|\$BRAINIAC_ROOT|$KB_ROOT|g" \
    -e "s|<your-github-user>/<your-kb-repo>|$GH_USER/$GH_REPO|g" \
    -e "s|<your-github-user>|$GH_USER|g" \
    -e "s|<your-kb-repo>|$GH_REPO|g" \
    -e "s|<your-name>|$FULL_NAME|g" \
    -e "s|<your-email>|$EMAIL|g" \
    -e "s|<your-keychain-entry>|$KEYCHAIN_ENTRY|g" \
    -e "s|com\.<you>\.<kb>|$LA_PREFIX|g" \
    -e "s|\.brainiac-cache|.${KB_LOWER}-cache|g" \
    -e "s|BRAINIAC_ROOT|${KB_UPPER}_ROOT|g" \
    -e "s|BRAINIAC_PAT|${KB_UPPER}_PAT|g" \
    "$f"
done

# launchd does NOT expand environment variables inside plist <string> values, so
# any $HOME left in a LaunchAgent plist must become an absolute path. ($BRAINIAC_ROOT
# was already resolved to an absolute path above.) macOS only — harmless elsewhere.
find . -name '*.plist' -not -path './.git/*' -print0 |
while IFS= read -r -d '' f; do
  sed -i.bak -e "s|\$HOME|$HOME|g" "$f"
done

echo
echo "=== Placeholders replaced. .bak backups left next to each changed file. ==="
echo
echo "NOTE: this script's placeholder substitution is cross-platform, but the manual"
echo "steps below assume macOS. On Windows/Linux the KB core, skills, and parser work"
echo "the same — only secret storage and scheduling differ. See docs/BUILD-GUIDE.md"
echo "'Platform support' for the Windows/Linux equivalents."
echo
echo "Next steps (manual — these involve secrets and accounts):"
echo
echo "  1. Create your private GitHub repo:"
echo "       gh repo create $GH_REPO --private --source=. --push"
echo
echo "  2. Store your AI API key OUTSIDE the repo:"
echo "       macOS:   security add-generic-password -a \"\$USER\" -s '$KEYCHAIN_ENTRY' -w"
echo "       Windows: setx ${KB_UPPER}_API_KEY \"<key>\"   (or use Credential Manager)"
echo "       Linux:   store in a gitignored .env or 'secret-tool store'"
echo
echo "  3. (Optional, for cloud-agent auto-clone) create a gitignored .env with a"
echo "     read-only fine-grained GitHub PAT:"
echo "       echo '${KB_UPPER}_PAT=ghp_xxx' > .env   # .env is already gitignored"
echo
echo "  4. (Optional) install background scheduling for capture/processing:"
echo "       macOS:   load the .plist LaunchAgents (see docs/BUILD-GUIDE.md §2.4)"
echo "       Windows: create Task Scheduler tasks; Linux: cron or a systemd timer"
echo
echo "  5. Read docs/BUILD-GUIDE.md and run your first '/kb' in Claude Code."
echo
echo "Once everything looks right, remove the backups:  find . -name '*.bak' -delete"
