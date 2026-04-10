#!/bin/bash
set -euo pipefail

# Usage: restore-cache <type> <lockfile> [target_dir]
# Example: restore-cache node_modules bun.lock
#          restore-cache vendor composer.lock
#          restore-cache playwright .pw-version /opt/playwright-browsers

TYPE="${1:?Usage: restore-cache <type> <lockfile> [target_dir]}"
LOCKFILE="${2:?Usage: restore-cache <type> <lockfile> [target_dir]}"
TARGET_DIR="${3:-./$TYPE}"

if [ ! -f "$LOCKFILE" ]; then
    echo "::warning::Lock file '$LOCKFILE' not found"
    exit 1
fi

HASH=$(sha256sum "$LOCKFILE" | cut -d' ' -f1)
CACHE_DIR="/cache/$TYPE/$HASH"
SHORT_HASH="${HASH:0:12}"

if [ -d "$CACHE_DIR" ]; then
    echo "::notice::Cache hit for $TYPE (hash: $SHORT_HASH)"
    mkdir -p "$TARGET_DIR"
    cp -a "$CACHE_DIR/." "$TARGET_DIR/"
    date +%s > "$CACHE_DIR/.last-used"
    exit 0
else
    echo "::notice::Cache miss for $TYPE (hash: $SHORT_HASH)"
    exit 1
fi
