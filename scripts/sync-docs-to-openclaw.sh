#!/usr/bin/env bash
# sync-docs-to-openclaw.sh
# Syncs the untracked homelab/docs/ directory to the OpenClaw server.
# Run from your local machine, from anywhere — the paths are hardcoded.
# Usage: ./scripts/sync-docs-to-openclaw.sh

REMOTE_USER="root"
REMOTE_HOST="openclaw.snorp.dev"
REMOTE_DIR="/root/homelab-docs/"
LOCAL_DIR="$(cd "$(dirname "$0")/.." && pwd)/docs/"

if [ ! -d "$LOCAL_DIR" ]; then
  echo "Error: $LOCAL_DIR does not exist. Run from inside the homelab repo or check the path."
  exit 1
fi

echo "Syncing $LOCAL_DIR → ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}"
rsync -avz --delete "$LOCAL_DIR" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}"
echo "Done."
