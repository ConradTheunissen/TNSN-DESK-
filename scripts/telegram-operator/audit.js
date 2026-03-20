#!/usr/bin/env node
const {
  env,
  readJsonl,
  detectTimestamp,
  printJson
} = require('./lib');

const args = process.argv.slice(2);
const limitIndex = args.indexOf('--limit');
const limit = limitIndex >= 0 ? Number(args[limitIndex + 1] || '20') : 20;
const auditPath = env('TNSN_AUDIT_LOG_PATH', '/opt/tnsn/logs/audit.jsonl');
const rows = readJsonl(auditPath, limit)
  .filter((entry) => !entry._invalid)
  .map((entry) => ({
    time: detectTimestamp(entry),
    actor: entry.actor || entry.user || entry.who || 'system',
    action: entry.action || entry.command || entry.tool || entry.event || 'unknown',
    status: entry.status || (entry.ok === true ? 'ok' : entry.ok === false ? 'error' : 'unknown'),
    details: entry.details || entry.result || entry.message || entry.summary || ''
  }));

printJson({
  ok: true,
  count: rows.length,
  limit,
  entries: rows
});
