#!/bin/bash
set -euo pipefail

# ─── Validate required env vars ───────────────────────────────────────────────
: "${GITHUB_URL:?GITHUB_URL is required}"
: "${RUNNER_NAME:?RUNNER_NAME is required}"

RUNNER_LABELS="${RUNNER_LABELS:-self-hosted,linux,x64}"
RUNNER_WORKDIR="${RUNNER_WORKDIR:-/home/runner/_work}"
RUNNER_GROUP="${RUNNER_GROUP:-Default}"

CONFIG_DIR="/home/runner/runner-config"
RUNNER_DIR="/home/runner/actions-runner"

# ─── Ensure directories exist with correct ownership ─────────────────────────
mkdir -p /cache/node_modules /cache/vendor /cache/playwright /cache/.locks
sudo mkdir -p "$RUNNER_WORKDIR" "$PLAYWRIGHT_BROWSERS_PATH"
sudo chown -R runner:runner "$RUNNER_WORKDIR" "$PLAYWRIGHT_BROWSERS_PATH"

# ─── Start cron for cache cleanup ─────────────────────────────────────────────
sudo service cron start

# ─── Link persisted config files into runner directory ─────────────────────────
# Config files are stored in a persistent volume so credentials survive restarts.
# Runner binaries stay in the image layer and get updated on image rebuild.
CONFIG_FILES=(.credentials .credentials_rsaparams .runner .env)
for f in "${CONFIG_FILES[@]}"; do
    if [ -f "$CONFIG_DIR/$f" ]; then
        ln -sf "$CONFIG_DIR/$f" "$RUNNER_DIR/$f"
    fi
done

# ─── Configure the runner (first time only) ───────────────────────────────────
cd "$RUNNER_DIR"

if [ ! -f "$CONFIG_DIR/.credentials" ]; then
    : "${RUNNER_TOKEN:?RUNNER_TOKEN is required for first-time registration}"

    ./config.sh \
        --url "$GITHUB_URL" \
        --token "$RUNNER_TOKEN" \
        --name "$RUNNER_NAME" \
        --labels "$RUNNER_LABELS" \
        --work "$RUNNER_WORKDIR" \
        --runnergroup "$RUNNER_GROUP" \
        --unattended \
        --replace \
        --disableupdate

    # Move generated config files to persistent volume
    for f in "${CONFIG_FILES[@]}"; do
        if [ -f "$RUNNER_DIR/$f" ] && [ ! -L "$RUNNER_DIR/$f" ]; then
            mv "$RUNNER_DIR/$f" "$CONFIG_DIR/$f"
            ln -sf "$CONFIG_DIR/$f" "$RUNNER_DIR/$f"
        fi
    done

    echo "Runner configured successfully."
else
    echo "Runner already configured, skipping registration."
fi

# ─── Graceful shutdown (no deregistration) ────────────────────────────────────
cleanup() {
    echo "Shutting down runner (staying registered)..."
    kill -TERM "$RUNNER_PID" 2>/dev/null || true
    wait "$RUNNER_PID" 2>/dev/null || true
    exit 0
}
trap cleanup SIGTERM SIGINT SIGQUIT

# ─── Start the runner ─────────────────────────────────────────────────────────
echo "Starting runner: $RUNNER_NAME"
./run.sh &
RUNNER_PID=$!
wait $RUNNER_PID
