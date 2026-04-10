#!/bin/bash
set -euo pipefail

# Usage: save-cache <type> <lockfile>
# Example: save-cache node_modules bun.lock
#          save-cache vendor composer.lock

TYPE="${1:?Usage: save-cache <type> <lockfile>}"
LOCKFILE="${2:?Usage: save-cache <type> <lockfile>}"

if [ ! -d "./$TYPE" ]; then
    echo "::warning::Directory './$TYPE' not found, nothing to cache"
    exit 1
fi

HASH=$(sha256sum "$LOCKFILE" | cut -d' ' -f1)
CACHE_DIR="/cache/$TYPE/$HASH"
SHORT_HASH="${HASH:0:12}"

# Already cached
if [ -d "$CACHE_DIR" ]; then
    echo "::notice::Cache already exists for $TYPE (hash: $SHORT_HASH)"
    date +%s > "$CACHE_DIR/.last-used"
    exit 0
fi

# Use flock to prevent concurrent writes from multiple runners
LOCK_FILE="/cache/.locks/${TYPE}-${HASH}.lock"
mkdir -p /cache/.locks

(
    flock -n 200 || {
        echo "::notice::Another runner is saving this cache, skipping"
        exit 0
    }

    # Double-check after acquiring lock
    if [ -d "$CACHE_DIR" ]; then
        echo "::notice::Cache was saved by another runner for $TYPE (hash: $SHORT_HASH)"
        date +%s > "$CACHE_DIR/.last-used"
        exit 0
    fi

    # Write to a temp directory first, then rename atomically
    TEMP_DIR="/cache/$TYPE/.tmp-$HASH"
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"

    cp -a "./$TYPE/." "$TEMP_DIR/"
    date +%s > "$TEMP_DIR/.last-used"

    mv "$TEMP_DIR" "$CACHE_DIR"

    echo "::notice::Cache saved for $TYPE (hash: $SHORT_HASH)"
) 200>"$LOCK_FILE"
