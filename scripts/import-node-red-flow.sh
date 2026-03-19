#!/usr/bin/env bash
set -euo pipefail

FLOW_FILE="${1:-node-red/flows/tnsn-telegram-control.json}"
NODE_RED_API="${TNSN_NODE_RED_API:-http://127.0.0.1:1880}"

if [ ! -f "$FLOW_FILE" ]; then
  echo "Flow file not found: $FLOW_FILE" >&2
  exit 1
fi

curl -fsS \
  -H 'Content-Type: application/json' \
  -X POST \
  --data-binary "@$FLOW_FILE" \
  "$NODE_RED_API/flows"

echo
printf 'Imported %s into %s/flows\n' "$FLOW_FILE" "$NODE_RED_API"
