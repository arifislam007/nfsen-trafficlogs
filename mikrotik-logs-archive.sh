#!/bin/bash
# Archives previous day's nfcapd flow files + syslog files into per-day
# folders, compresses them, and prunes anything older than the retention period.

set -euo pipefail

BASE_DIR="/data/mikrotik-logs"
FLOWS_DIR="$BASE_DIR/flows"
FLOWS_LIVE_DIR="$FLOWS_DIR/live/mikrotik"   # nfsen-ng's active source tree; keep archived files out of it
SYSLOG_DIR="$BASE_DIR/syslog"
RETENTION_DAYS=180
COMPRESS_CMD="xz -9"          # max compression
LOG_FILE="$BASE_DIR/archive.log"

TARGET_DATE=$(date -d "yesterday" +%Y%m%d)          # e.g. 20260827
TARGET_DATE_DASHED=$(date -d "yesterday" +%Y-%m-%d) # e.g. 2026-08-27

log() { echo "$(date '+%F %T') $*" >> "$LOG_FILE"; }

log "=== Archive run started for $TARGET_DATE_DASHED ==="

### 1. Archive & compress NetFlow (nfcapd) files ###
DEST_DIR="$FLOWS_DIR/$TARGET_DATE_DASHED"
mkdir -p "$DEST_DIR"

shopt -s nullglob
FILES=("$FLOWS_LIVE_DIR"/nfcapd."$TARGET_DATE"*)
shopt -u nullglob

if [ ${#FILES[@]} -eq 0 ]; then
    log "No new nfcapd files to move for $TARGET_DATE"
else
    moved=0
    for f in "${FILES[@]}"; do
        [[ "$f" == *".current."* ]] && continue   # never touch the actively-written file
        mv "$f" "$DEST_DIR/"
        moved=$((moved+1))
    done
    log "Moved $moved flow files into $DEST_DIR"
fi

# Compression always runs over whatever is in DEST_DIR, independent of the
# move step above, so a re-run after a partial failure finishes the job.
shopt -s nullglob
UNCOMPRESSED=("$DEST_DIR"/nfcapd.*)
shopt -u nullglob
compressed=0
for f in "${UNCOMPRESSED[@]}"; do
    [[ "$f" == *.xz ]] && continue
    $COMPRESS_CMD "$f"
    compressed=$((compressed+1))
done
log "Compressed $compressed flow files in $DEST_DIR"

### 2. Compress syslog files (already one file per day, per host) ###
find "$SYSLOG_DIR" -maxdepth 2 -type f -name "${TARGET_DATE_DASHED}.log" | while read -r f; do
    $COMPRESS_CMD "$f"
    log "Compressed syslog file: $f"
done

### 3. Retention: delete anything older than RETENTION_DAYS ###
find "$FLOWS_DIR" -maxdepth 1 -type d -regextype posix-extended -regex '.*/[0-9]{4}-[0-9]{2}-[0-9]{2}' -mtime +"$RETENTION_DAYS" -print -exec rm -rf {} \; >> "$LOG_FILE" 2>&1

find "$SYSLOG_DIR" -type f -name '*.log.xz' -mtime +"$RETENTION_DAYS" -print -delete >> "$LOG_FILE" 2>&1

log "=== Archive run finished ==="
