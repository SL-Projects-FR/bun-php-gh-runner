#!/bin/bash
set -euo pipefail

# Cleanup cache entries not used in the last 30 days
# Runs daily via cron

CACHE_ROOT="/cache"
EXPIRY_DAYS=30
EXPIRY_SECONDS=$((EXPIRY_DAYS * 24 * 3600))
NOW=$(date +%s)
REMOVED=0
FREED_KB=0

echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting cache cleanup (expiry: ${EXPIRY_DAYS} days)"

for CACHE_DIR in "$CACHE_ROOT"/*/*; do
    # Skip non-directories, locks, and tmp
    [ -d "$CACHE_DIR" ] || continue
    DIRNAME=$(basename "$CACHE_DIR")
    [[ "$DIRNAME" == .locks ]] && continue
    [[ "$DIRNAME" == .tmp-* ]] && continue

    LAST_USED_FILE="$CACHE_DIR/.last-used"

    if [ -f "$LAST_USED_FILE" ]; then
        LAST_USED=$(cat "$LAST_USED_FILE")
        AGE=$((NOW - LAST_USED))
    else
        # No timestamp = treat as expired
        AGE=$((EXPIRY_SECONDS + 1))
    fi

    if [ "$AGE" -gt "$EXPIRY_SECONDS" ]; then
        SIZE_KB=$(du -sk "$CACHE_DIR" 2>/dev/null | cut -f1)
        TYPE=$(basename "$(dirname "$CACHE_DIR")")
        echo "  Removing $TYPE/${DIRNAME:0:12}... (${SIZE_KB}KB, last used $(( AGE / 86400 )) days ago)"
        rm -rf "$CACHE_DIR"
        REMOVED=$((REMOVED + 1))
        FREED_KB=$((FREED_KB + SIZE_KB))
    fi
done

# Clean up stale lock files
find "$CACHE_ROOT/.locks" -name "*.lock" -mtime +1 -delete 2>/dev/null || true

echo "Cleanup complete: removed $REMOVED entries, freed ~$((FREED_KB / 1024))MB"
