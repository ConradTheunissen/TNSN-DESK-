#!/usr/bin/env node
const {
  env,
  readJsonl,
  detectTimestamp,
  fileExists,
  runJsonMain
} = require('./lib');

runJsonMain(async () => {
  const args = process.argv.slice(2);
  const limitIndex = args.indexOf('--limit');
  const limit = limitIndex >= 0 ? Number(args[limitIndex + 1] || '20') : 20;
  const auditPath = env('TNSN_AUDIT_LOG_PATH', '/opt/tnsn/logs/audit.jsonl');
  const exists = fileExists(auditPath);
  const rows = exists
    ? readJsonl(auditPath, limit)
        .filter((entry) => !entry._invalid)
        .map((entry) => ({
          time: detectTimestamp(entry),
          actor: entry.actor || entry.user || entry.who || 'system',
          action: entry.action || entry.command || entry.tool || entry.event || 'unknown',
          status: entry.status || (entry.ok === true ? 'ok' : entry.ok === false ? 'error' : 'unknown'),
          details: entry.details || entry.result || entry.message || entry.summary || ''
        }))
    : [];

  return {
    ok: true,
    degraded: !exists,
    reason: exists ? '' : `audit history missing at ${auditPath}`,
    count: rows.length,
    limit,
    entries: rows
  };
});
