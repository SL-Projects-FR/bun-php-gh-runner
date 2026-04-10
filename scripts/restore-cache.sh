#!/bin/bash
set -euo pipefail

# Usage: restore-cache <type> <lockfile>
# Example: restore-cache node_modules bun.lock
#          restore-cache vendor composer.lock

TYPE="${1:?Usage: restore-cache <type> <lockfile>}"
LOCKFILE="${2:?Usage: restore-cache <type> <lockfile>}"

if [ ! -f "$LOCKFILE" ]; then
    echo "::warning::Lock file '$LOCKFILE' not found"
    exit 1
fi

HASH=$(sha256sum "$LOCKFILE" | cut -d' ' -f1)
CACHE_DIR="/cache/$TYPE/$HASH"
SHORT_HASH="${HASH:0:12}"

if [ -d "$CACHE_DIR" ]; then
    echo "::notice::Cache hit for $TYPE (hash: $SHORT_HASH)"
    cp -a "$CACHE_DIR/." "./$TYPE/"
    date +%s > "$CACHE_DIR/.last-used"
    exit 0
else
    echo "::notice::Cache miss for $TYPE (hash: $SHORT_HASH)"
    exit 1
fi
