#!/usr/bin/env node
const {
  env,
  readJsonl,
  detectTimestamp,
  detectSummary,
  detectSource,
  detectLink,
  detectSeverity,
  printJson
} = require('./lib');

const args = process.argv.slice(2);
const limitIndex = args.indexOf('--limit');
const limit = limitIndex >= 0 ? Number(args[limitIndex + 1] || '10') : 10;
const signalPath = env('TNSN_SIGNAL_HISTORY_PATH', '/opt/tnsn/logs/signal-history.jsonl');
const rows = readJsonl(signalPath, limit)
  .filter((entry) => !entry._invalid)
  .map((entry) => ({
    time: detectTimestamp(entry),
    severity: detectSeverity(entry),
    summary: detectSummary(entry),
    source: detectSource(entry),
    link: detectLink(entry)
  }));

printJson({
  ok: true,
  count: rows.length,
  limit,
  signals: rows
});
