#!/usr/bin/env bash
set -euo pipefail

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

cat > "$TMPDIR/signals.jsonl" <<'EOF'
{"timestamp":"2026-03-19T10:00:00Z","severity":"high","summary":"Alpha event","source":"GDELT","link":"https://example.com/a"}
{"timestamp":"2026-03-19T11:00:00Z","score":55,"title":"Beta event","feed":"RSS","url":"https://example.com/b"}
EOF

cat > "$TMPDIR/audit.jsonl" <<'EOF'
{"timestamp":"2026-03-19T12:00:00Z","actor":"operator","action":"fetch_signals","status":"ok","details":"Fetched 2 signals"}
{"timestamp":"2026-03-19T12:05:00Z","user":"system","command":"health","ok":true,"message":"healthy"}
EOF

node scripts/telegram-operator/status.js > "$TMPDIR/status.json"
node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));" "$TMPDIR/status.json"

node scripts/telegram-operator/system.js > "$TMPDIR/system.json"
node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));" "$TMPDIR/system.json"

TNSN_SIGNAL_HISTORY_PATH="$TMPDIR/signals.jsonl" node scripts/telegram-operator/signals.js --limit 10 > "$TMPDIR/signals.json"
node -e "const data=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')); if(data.count!==2) process.exit(1);" "$TMPDIR/signals.json"

TNSN_AUDIT_LOG_PATH="$TMPDIR/audit.jsonl" node scripts/telegram-operator/audit.js --limit 20 > "$TMPDIR/audit.json"
node -e "const data=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')); if(data.count!==2) process.exit(1);" "$TMPDIR/audit.json"

TNSN_SIGNAL_HISTORY_PATH="$TMPDIR/missing-signals.jsonl" node scripts/telegram-operator/signals.js --limit 10 > "$TMPDIR/signals-missing.json"
node -e "const data=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')); if(!data.degraded || data.count!==0) process.exit(1);" "$TMPDIR/signals-missing.json"

TNSN_AUDIT_LOG_PATH="$TMPDIR/missing-audit.jsonl" node scripts/telegram-operator/audit.js --limit 20 > "$TMPDIR/audit-missing.json"
node -e "const data=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')); if(!data.degraded || data.count!==0) process.exit(1);" "$TMPDIR/audit-missing.json"

PORT=19881 node - <<'NODE' &
const http = require('http');
const server = http.createServer((req,res)=>{
  let body='';
  req.on('data', chunk => body += chunk);
  req.on('end', ()=>{
    res.writeHead(200, {'content-type':'application/json'});
    res.end(JSON.stringify({count: 3, message: 'fetch complete', received: JSON.parse(body)}));
  });
});
server.listen(19881, '127.0.0.1');
setTimeout(()=>server.close(()=>process.exit(0)), 10000);
NODE
SERVER_PID=$!
sleep 1
TNSN_SIGNAL_FETCH_URL="http://127.0.0.1:19881" node scripts/telegram-operator/fetch.js > "$TMPDIR/fetch.json"
wait "$SERVER_PID"
node -e "const data=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')); if(!data.ok || data.count!==3) process.exit(1);" "$TMPDIR/fetch.json"

TNSN_SIGNAL_FETCH_URL="http://127.0.0.1:19999" node scripts/telegram-operator/fetch.js > "$TMPDIR/fetch-missing.json" || true
node -e "const data=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')); if(data.ok || !data.degraded) process.exit(1);" "$TMPDIR/fetch-missing.json"

echo 'PASS: helper script smoke tests completed'


TMP_NODE_RED_HOME="$TMPDIR/home"
TMP_NODE_RED_DIR="$TMP_NODE_RED_HOME/.node-red"
TMP_BIN_DIR="$TMPDIR/bin"
mkdir -p "$TMP_NODE_RED_DIR/node_modules/node-red-contrib-telegrambot" "$TMPDIR/logs" "$TMP_BIN_DIR"
cat > "$TMP_BIN_DIR/node-red" <<'EOF'
#!/usr/bin/env bash
echo "stub node-red"
EOF
chmod +x "$TMP_BIN_DIR/node-red"
cat > "$TMP_NODE_RED_DIR/settings.js" <<'EOF'
module.exports = {
    credentialSecret: process.env.TNSN_NODE_RED_CREDENTIAL_SECRET || 'demo-secret',
};
EOF
cat > "$TMP_NODE_RED_DIR/package.json" <<'EOF'
{"name":"node-red-user-dir"}
EOF
cat > "$TMP_NODE_RED_DIR/flows_cred.json" <<'EOF'
{}
EOF
: > "$TMPDIR/logs/signal-history.jsonl"
: > "$TMPDIR/logs/audit.jsonl"

PORT=19882 node - <<'NODE' &
const http = require('http');
const server = http.createServer((req,res)=>{
  res.writeHead(200, {'content-type':'application/json'});
  res.end(JSON.stringify({ok: true}));
});
server.listen(19882, '127.0.0.1');
setTimeout(()=>server.close(()=>process.exit(0)), 10000);
NODE
PREFLIGHT_SERVER_PID=$!
sleep 1
PATH="$TMP_BIN_DIR:$PATH" \
HOME="$TMP_NODE_RED_HOME" \
NODE_RED_DIR="$TMP_NODE_RED_DIR" \
TNSN_REPO_ROOT="$(pwd)" \
TNSN_SIGNAL_HISTORY_PATH="$TMPDIR/logs/signal-history.jsonl" \
TNSN_AUDIT_LOG_PATH="$TMPDIR/logs/audit.jsonl" \
TNSN_NODE_RED_API="http://127.0.0.1:19882" \
TNSN_SIGNAL_FETCH_URL="http://127.0.0.1:19882" \
TNSN_ALLOWED_COMMANDS="/start,/menu,/help,/status,/signals,/fetch,/audit,/system" \
TNSN_NODE_RED_CREDENTIAL_SECRET="demo-secret" \
./scripts/preflight-telegram-operator.sh --strict > "$TMPDIR/preflight.txt"
wait "$PREFLIGHT_SERVER_PID"
rg -n "READY  Local checks passed cleanly" "$TMPDIR/preflight.txt"
