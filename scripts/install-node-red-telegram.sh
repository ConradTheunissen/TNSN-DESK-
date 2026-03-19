#!/usr/bin/env bash
set -euo pipefail

NODE_RED_DIR="${NODE_RED_DIR:-$HOME/.node-red}"
PACKAGE_NAME="node-red-contrib-telegrambot"

mkdir -p "$NODE_RED_DIR"
cd "$NODE_RED_DIR"

if [ ! -f package.json ]; then
  npm init -y >/dev/null 2>&1
fi

npm install --save "$PACKAGE_NAME"

cat <<MSG
Installed $PACKAGE_NAME into $NODE_RED_DIR.

Next steps:
1. Restart Node-RED.
2. Import node-red/flows/tnsn-telegram-control.json.
3. Open the Telegram bot config node and set token/chat credentials.
MSG
