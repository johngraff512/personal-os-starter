#!/bin/bash
#
# brainiac — iCloud Web Clipper bridge
#
# Runs every 5 min via ~/Library/LaunchAgents/com.<you>.<kb>.icloud-pull.plist
#
# Why this exists:
#   iPhone/iPad Obsidian can only see vaults inside the iCloud Obsidian
#   namespace. Brainiac vaults live at ~/Documents/AI Development/brainiac/
#   — a git repo with scripts and a venv, which is hostile territory for iCloud.
#   So iOS Web Clipper writes clips to iCloud transit vaults named "personal"
#   and "work", and this bridge ferries them into brainiac for /kb to process.
#
# Important macOS quirks (learned the hard way):
#   1. The script must NOT live in ~/Documents — TCC blocks launchd from
#      executing scripts there. Hence ~/.local/bin/ as runtime location.
#   2. Logs must NOT live in ~/Documents — TCC blocks launchd-spawned bash
#      from appending to files created by Terminal-spawned bash there.
#      Hence ~/Library/Logs/brainiac/ as log location.
#   3. Complex script structures (functions wrapping find -print0 + read -d
#      via process substitution) sometimes return empty results from iCloud
#      directories under launchd. The simple `for f in "$src"/*` glob form
#      always works. Stick with it.
#
# Source-of-truth lives in brainiac/.scripts/bridge-icloud.sh; runtime copy
# at ~/.local/bin/brainiac-icloud-pull.sh (deploy via cp).

ICLOUD_DIR="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents"
BRAINIAC_DIR="$BRAINIAC_ROOT"
LOG_DIR="$HOME/Library/Logs/brainiac"
LOG_FILE="$LOG_DIR/bridge.log"

mkdir -p "$LOG_DIR"

ts() { date '+%Y-%m-%d %H:%M:%S'; }

{
    moved=0
    errors=0

    for vault in personal work; do
        src="$ICLOUD_DIR/$vault/aa-inbox"
        dst="$BRAINIAC_DIR/$vault/aa-inbox"

        if [ ! -d "$src" ]; then
            continue
        fi
        if [ ! -d "$dst" ]; then
            echo "[$(ts)] [error] $vault: destination missing ($dst)"
            errors=$((errors + 1))
            continue
        fi

        # Glob all top-level files. nullglob handles the empty case cleanly.
        shopt -s nullglob
        for src_file in "$src"/*; do
            [ -f "$src_file" ] || continue
            base=$(basename "$src_file")

            # Skip dotfiles and iCloud cloud-only stubs.
            case "$base" in
                .* | *.icloud) continue ;;
            esac

            dst_file="$dst/$base"

            # Collision: never overwrite, never silently drop.
            if [ -e "$dst_file" ]; then
                stem="${base%.*}"
                ext="${base##*.}"
                suffix="conflict-$(date '+%Y%m%dT%H%M%S')"
                if [ "$stem" = "$base" ]; then
                    dst_file="$dst/${base}.${suffix}"
                else
                    dst_file="$dst/${stem}.${suffix}.${ext}"
                fi
                echo "[$(ts)] [conflict] $vault/aa-inbox/$base exists; renamed to $(basename "$dst_file")"
            fi

            if mv "$src_file" "$dst_file"; then
                echo "[$(ts)] [moved] $vault/aa-inbox/$(basename "$dst_file")"
                moved=$((moved + 1))
            else
                echo "[$(ts)] [error] mv failed: $src_file -> $dst_file"
                errors=$((errors + 1))
            fi
        done
        shopt -u nullglob
    done

    if [ "$moved" -gt 0 ] || [ "$errors" -gt 0 ]; then
        echo "[$(ts)] === bridge: $moved moved, $errors errors ==="
    fi
} >> "$LOG_FILE" 2>&1

exit 0
