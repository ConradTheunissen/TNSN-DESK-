#!/usr/bin/env bash
set -euo pipefail

NODE_RED_DIR="${NODE_RED_DIR:-$HOME/.node-red}"
SETTINGS_FILE="$NODE_RED_DIR/settings.js"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$NODE_RED_DIR/backups/credentials-$TIMESTAMP"
FORCE_RESET=0
SECRET="${TNSN_NODE_RED_CREDENTIAL_SECRET:-}"

usage() {
  cat <<USAGE
Usage: $0 [--force-reset] [--secret <value>]

Safely inspects and backs up Node-RED credential files. If --force-reset is supplied,
invalid or undecryptable credential files are moved aside so Node-RED can recreate them.

Options:
  --force-reset     Move existing flow credential files out of the way after backup.
  --secret <value>  Persist this credentialSecret into settings.js before restart.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --force-reset)
      FORCE_RESET=1
      ;;
    --secret)
      shift
      if [ "$#" -eq 0 ]; then
        echo "Missing value for --secret" >&2
        exit 1
      fi
      SECRET="$1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [ ! -d "$NODE_RED_DIR" ]; then
  echo "Node-RED directory not found: $NODE_RED_DIR" >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR"

for file in "$SETTINGS_FILE" "$NODE_RED_DIR"/flows*.json "$NODE_RED_DIR"/flows*_cred.json; do
  if [ -f "$file" ]; then
    cp -p "$file" "$BACKUP_DIR/"
  fi
done

echo "Backed up Node-RED flow/settings files to: $BACKUP_DIR"

if [ -n "$SECRET" ] && [ -f "$SETTINGS_FILE" ]; then
  python - <<'PY' "$SETTINGS_FILE" "$SECRET"
import pathlib, re, sys
settings_path = pathlib.Path(sys.argv[1])
secret = sys.argv[2]
text = settings_path.read_text()
line = f"credentialSecret: process.env.TNSN_NODE_RED_CREDENTIAL_SECRET || '{secret}',"
if re.search(r"^\s*credentialSecret\s*:", text, flags=re.M):
    text = re.sub(r"^\s*credentialSecret\s*:.*$", line, text, flags=re.M)
elif re.search(r"module\.exports\s*=\s*\{", text):
    text = re.sub(r"module\.exports\s*=\s*\{", "module.exports = {\n    " + line, text, count=1)
else:
    raise SystemExit("Could not locate module.exports block in settings.js")
settings_path.write_text(text)
PY
  echo "Updated credentialSecret in $SETTINGS_FILE"
elif [ -n "$SECRET" ]; then
  echo "No settings.js found at $SETTINGS_FILE; credentialSecret was not written" >&2
fi

found_problem=0
for cred_file in "$NODE_RED_DIR"/flows*_cred.json; do
  [ -f "$cred_file" ] || continue

  if node -e "JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));" "$cred_file" >/dev/null 2>&1; then
    echo "Credential file is valid JSON: $cred_file"
  else
    echo "Credential file is not valid JSON: $cred_file" >&2
    found_problem=1
    if [ "$FORCE_RESET" -eq 1 ]; then
      mv "$cred_file" "$cred_file.corrupt-$TIMESTAMP"
      echo "Moved corrupt credential file aside: $cred_file.corrupt-$TIMESTAMP"
    fi
  fi
done

if [ "$FORCE_RESET" -eq 0 ]; then
  cat <<MSG

Inspection complete.
If Node-RED still reports 'Failed to decrypt credentials' after you set a persistent credentialSecret,
re-run this script with --force-reset to move broken flow credential files aside.
That will require re-entering credentials such as the Telegram bot token in Node-RED.
MSG
else
  cat <<MSG

Credential reset complete.
Next steps:
1. Restart Node-RED.
2. Re-enter Telegram bot credentials in the config node.
3. Deploy the flow again.
MSG
fi

if [ "$found_problem" -eq 1 ] && [ "$FORCE_RESET" -eq 0 ]; then
  exit 2
fi
