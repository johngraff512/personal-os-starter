#!/usr/bin/env bash
#
# brainiac — daily inbox processor (LaunchAgent entry point)
#
# Runs at 6:30 am via ~/Library/LaunchAgents/com.example.brainiac.plist.
# Pure file I/O + Anthropic API + git.
#
# IMPORTANT — script must NOT live in ~/Documents at runtime: macOS TCC blocks
# launchd from EXECUTING script files there (separate from FDA on bash itself).
# The source-of-truth is here in brainiac/.scripts/process-inbox.sh; the
# runtime copy at ~/.local/bin/brainiac-process-inbox.sh is what the
# LaunchAgent invokes. Re-deploy with:
#     cp "$BRAINIAC_DIR/.scripts/process-inbox.sh" \
#        "$HOME/.local/bin/brainiac-process-inbox.sh"
# Logs go to ~/Library/Logs/brainiac/ for the same TCC reason (file-provenance
# blocks launchd-spawned bash from appending to Terminal-created log files
# inside ~/Documents).
#
# Scope: this script does the autonomous *parser pre-step* — convert DOCX/PPTX
# to PDF, run the vision-LLM parser on each PDF in any inbox, write a _text.md
# companion next to the original. It DOES NOT move files into topic folders or
# update index.md — those are user-confirmation steps that belong in the
# interactive `/kb` skill, run by you in the morning.
#
# Order:
#   1. DOCX/PPTX → PDF pre-step (libreoffice headless)
#   2. Parse PDFs (vision-LLM via Anthropic SDK; idempotent — skips if _text.md exists)
#   3. git add/commit/push (only if there are changes)
#

set -euo pipefail

# PATH setup — LaunchAgent gives us a minimal PATH; ensure we can find
# claude (~/.local/bin), homebrew binaries (/opt/homebrew/bin), and git.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

BRAINIAC_DIR="${BRAINIAC_DIR:-$BRAINIAC_ROOT}"
LOG_DIR="${BRAINIAC_LOG_DIR:-$HOME/Library/Logs/brainiac}"
LOG_FILE="$LOG_DIR/process-inbox.log"
PARSER_PY="$BRAINIAC_DIR/.venv/bin/python"
PARSER_DIR="$BRAINIAC_DIR/.scripts"

mkdir -p "$LOG_DIR"

cd "$BRAINIAC_DIR"

{
    echo "=== brainiac process-inbox: $(date) ==="

    # ---------------------------------------------------------------------
    # 1. DOCX/PPTX → PDF pre-step
    # ---------------------------------------------------------------------
    SOFFICE="$(command -v soffice || command -v libreoffice || true)"
    if [ -z "$SOFFICE" ] && [ -x "/Applications/LibreOffice.app/Contents/MacOS/soffice" ]; then
        SOFFICE="/Applications/LibreOffice.app/Contents/MacOS/soffice"
    fi
    if [ -z "$SOFFICE" ]; then
        echo "[warn] libreoffice/soffice not found; DOCX/PPTX inputs will be skipped."
    fi

    for vault in personal work aa-inbox; do
        inbox="$BRAINIAC_DIR/$vault/aa-inbox"
        # the top-level aa-inbox/ is at $BRAINIAC_DIR/aa-inbox, no per-vault subfolder
        if [ "$vault" = "aa-inbox" ]; then
            inbox="$BRAINIAC_DIR/aa-inbox"
        fi
        [ -d "$inbox" ] || continue
        processed="$inbox/.processed"
        mkdir -p "$processed"

        shopt -s nullglob
        for f in "$inbox"/*.docx "$inbox"/*.pptx; do
            if [ -z "$SOFFICE" ]; then
                echo "[skip] $f (libreoffice missing)"
                continue
            fi
            echo "[convert] $f"
            "$SOFFICE" --headless --convert-to pdf --outdir "$inbox" "$f"
            mv "$f" "$processed/"
        done
        shopt -u nullglob
    done

    # ---------------------------------------------------------------------
    # 2. Parse PDFs — write _text.md companion next to each
    #    Idempotent: skips PDFs that already have a companion _text.md.
    # ---------------------------------------------------------------------
    if [ ! -x "$PARSER_PY" ]; then
        echo "[warn] venv Python not at $PARSER_PY; skipping parser step"
    else
        for vault in personal work aa-inbox; do
            inbox="$BRAINIAC_DIR/$vault/aa-inbox"
            if [ "$vault" = "aa-inbox" ]; then
                inbox="$BRAINIAC_DIR/aa-inbox"
            fi
            [ -d "$inbox" ] || continue

            shopt -s nullglob
            for pdf in "$inbox"/*.pdf; do
                base="${pdf%.pdf}"
                text_md="${base}_text.md"
                if [ -e "$text_md" ]; then
                    echo "[skip-parsed] $pdf (already has _text.md)"
                    continue
                fi
                echo "[parse] $pdf"
                # Run from .scripts/ so the `parser` package import works.
                ( cd "$PARSER_DIR" && "$PARSER_PY" -m parser.parse_pdf "$pdf" --out "$text_md" ) \
                    || echo "[warn] parser failed on $pdf"
            done
            shopt -u nullglob
        done
    fi

    # ---------------------------------------------------------------------
    # 3. git commit/push (only if there are changes)
    # ---------------------------------------------------------------------
    if [ -d "$BRAINIAC_DIR/.git" ]; then
        git add .
        if ! git diff --cached --quiet; then
            git commit -m "auto: $(date '+%Y-%m-%d %H:%M') — overnight parse pre-step"
            git push || echo "[warn] git push failed (offline?)"
        else
            echo "[git] no changes to commit"
        fi
    else
        echo "[warn] not a git repo yet; skipping commit/push"
    fi

    echo "=== done: $(date) ==="
} >> "$LOG_FILE" 2>&1
