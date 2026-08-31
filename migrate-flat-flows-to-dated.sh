#!/bin/bash
# One-time migration: moves pre-existing flat nfcapd.* files in
# flows/live/mikrotik/ into the YYYY/MM/DD/ subdirectory layout that
# nfsen-ng's importer requires (see -S "%Y/%m/%d" in docker-compose.yaml).
#
# Run this ONCE after pulling the updated docker-compose.yaml, before (or
# right after) `docker compose up -d` recreates the nfcapd container with
# the new -S flag. Safe to re-run — skips files already sorted into a
# dated subdirectory and never touches the actively-written nfcapd.current.*.

set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLOWS_LIVE_DIR="$BASE_DIR/flows/live/mikrotik"

shopt -s nullglob
FILES=("$FLOWS_LIVE_DIR"/nfcapd.*)
shopt -u nullglob

if [ ${#FILES[@]} -eq 0 ]; then
    echo "No flat nfcapd files found directly under $FLOWS_LIVE_DIR — nothing to migrate."
    exit 0
fi

moved=0
skipped=0
for f in "${FILES[@]}"; do
    base=$(basename "$f")

    [[ "$base" == *".current."* ]] && { skipped=$((skipped+1)); continue; }

    if [[ "$base" =~ ^nfcapd\.([0-9]{4})([0-9]{2})([0-9]{2})[0-9]{4}$ ]]; then
        year="${BASH_REMATCH[1]}"
        month="${BASH_REMATCH[2]}"
        day="${BASH_REMATCH[3]}"
        dest_dir="$FLOWS_LIVE_DIR/$year/$month/$day"
        mkdir -p "$dest_dir"
        mv "$f" "$dest_dir/"
        moved=$((moved+1))
    else
        echo "Skipping unrecognized file name: $base"
        skipped=$((skipped+1))
    fi
done

echo "Migrated $moved file(s) into dated subdirectories, skipped $skipped."
echo "After this, re-run nfsen-ng's Admin -> Initial Import (or Force Rescan) to pick up the migrated data."
