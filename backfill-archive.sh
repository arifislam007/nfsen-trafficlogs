#!/bin/bash
# One-time backfill: archives + compresses old flat nfcapd flow files that
# predate the daily mikrotik-logs-archive.sh job. Safe to re-run — skips
# already-compressed files and dates that have no remaining flat files.

set -uo pipefail

BASE_DIR="/data/mikrotik-logs"
FLOWS_DIR="$BASE_DIR/flows"
SYSLOG_DIR="$BASE_DIR/syslog"
COMPRESS_CMD="xz -9"
LOG_FILE="$BASE_DIR/archive-backfill.log"
PARALLEL=2

DATES=("2026-08-23" "2026-08-24" "2026-08-25" "2026-08-26")

log() { echo "$(date '+%F %T') $*" >> "$LOG_FILE"; }

log "=== Backfill run started for: ${DATES[*]} ==="

for DATE_DASHED in "${DATES[@]}"; do
    DATE_COMPACT="${DATE_DASHED//-/}"
    DEST_DIR="$FLOWS_DIR/$DATE_DASHED"
    mkdir -p "$DEST_DIR"

    shopt -s nullglob
    FILES=("$FLOWS_DIR"/nfcapd."$DATE_COMPACT"*)
    shopt -u nullglob

    moved=0
    for f in "${FILES[@]}"; do
        [[ "$f" == *".current."* ]] && continue
        mv "$f" "$DEST_DIR/"
        moved=$((moved+1))
    done
    log "[$DATE_DASHED] Moved $moved flow files into $DEST_DIR"

    shopt -s nullglob
    UNCOMPRESSED=("$DEST_DIR"/nfcapd.*)
    shopt -u nullglob
    to_compress=()
    for f in "${UNCOMPRESSED[@]}"; do
        [[ "$f" == *.xz ]] && continue
        to_compress+=("$f")
    done

    if [ ${#to_compress[@]} -gt 0 ]; then
        printf '%s\n' "${to_compress[@]}" | xargs -P "$PARALLEL" -I{} $COMPRESS_CMD {}
        log "[$DATE_DASHED] Compressed ${#to_compress[@]} flow files"
    else
        log "[$DATE_DASHED] Nothing to compress"
    fi

    SYSLOG_FILE=$(find "$SYSLOG_DIR" -maxdepth 2 -type f -name "${DATE_DASHED}.log")
    if [ -n "$SYSLOG_FILE" ]; then
        $COMPRESS_CMD "$SYSLOG_FILE"
        log "[$DATE_DASHED] Compressed syslog file: $SYSLOG_FILE"
    fi
done

log "=== Backfill run finished ==="
