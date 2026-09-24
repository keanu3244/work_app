#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/dist/build/h5"
PUBLIC_PATH="${PUBLIC_PATH:-/work-web/}"
REMOTE_DIR="${DEPLOY_REMOTE_DIR:-/var/www${PUBLIC_PATH%/}}"
REMOTE_TMP_DIR="${DEPLOY_TMP_DIR:-/tmp/work-web-deploy}"
REMOTE_HOST_DEFAULT="ubuntu@43.155.239.210"
REMOTE_HOST="${DEPLOY_HOST:-$REMOTE_HOST_DEFAULT}"
PUBLIC_ORIGIN="${PUBLIC_ORIGIN:-http://43.155.239.210}"
REMOTE_PORT_DEFAULT="22"
REMOTE_PORT="${DEPLOY_PORT:-$REMOTE_PORT_DEFAULT}"
SSH_KEY_PATH_DEFAULT="$HOME/.ssh/ssh-key.pem"
SSH_KEY_PATH="${DEPLOY_SSH_KEY:-$SSH_KEY_PATH_DEFAULT}"
SSH_OPTS=()
SCP_OPTS=()

if [[ -f "$SSH_KEY_PATH" ]]; then
  SSH_OPTS=(-i "$SSH_KEY_PATH" -p "$REMOTE_PORT")
  SCP_OPTS=(-i "$SSH_KEY_PATH" -P "$REMOTE_PORT")
  echo "==> Use SSH key: $SSH_KEY_PATH"
else
  SSH_OPTS=(-p "$REMOTE_PORT")
  SCP_OPTS=(-P "$REMOTE_PORT")
  echo "==> SSH key not found, using default SSH credentials: $REMOTE_HOST"
fi

run_ssh() {
  ssh "${SSH_OPTS[@]}" "$REMOTE_HOST" "$@"
}

run_scp() {
  scp "${SCP_OPTS[@]}" -r "$@"
}

echo "==> Enter project"
cd "$PROJECT_DIR"

if ! grep -q "\"base\": \"$PUBLIC_PATH\"" "$PROJECT_DIR/src/manifest.json"; then
  echo "manifest h5 router base must match PUBLIC_PATH: $PUBLIC_PATH"
  exit 1
fi

echo "==> Build H5"
pnpm build:h5

if [[ ! -d "$BUILD_DIR" ]]; then
  echo "Build output not found: $BUILD_DIR"
  exit 1
fi

echo "==> Prepare remote temp directory"
run_ssh "rm -rf '$REMOTE_TMP_DIR' && mkdir -p '$REMOTE_TMP_DIR'"

echo "==> Upload new files to temp directory"
run_scp "$BUILD_DIR/." "$REMOTE_HOST:$REMOTE_TMP_DIR/"

echo "==> Publish files"
run_ssh "sudo mkdir -p '$REMOTE_DIR' && sudo find '$REMOTE_DIR' -mindepth 1 -maxdepth 1 -exec rm -rf {} + && sudo cp -a '$REMOTE_TMP_DIR/.' '$REMOTE_DIR/' && rm -rf '$REMOTE_TMP_DIR'"

echo "==> Verify remote files"
run_ssh "test -f '$REMOTE_DIR/index.html' && stat '$REMOTE_DIR/index.html' || ls -la '$REMOTE_DIR' | head"

echo "==> Deploy done"
echo "URL: ${PUBLIC_ORIGIN}${PUBLIC_PATH}"
