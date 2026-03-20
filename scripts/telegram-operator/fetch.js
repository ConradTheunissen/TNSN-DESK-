#!/usr/bin/env node
const { env, httpJson, runJsonMain } = require('./lib');

runJsonMain(async () => {
  const fetchUrl = env('TNSN_SIGNAL_FETCH_URL') || env('TNSN_C2_URL', 'http://127.0.0.1:1880/api/c2');
  const body = {
    action: 'fetch_signals',
    source: 'telegram_ui',
    requestedAt: new Date().toISOString()
  };

  try {
    const response = await httpJson(fetchUrl, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body),
      timeoutMs: 10000
    });

    const payload = response.json || {};
    const count =
      payload.count ??
      payload.fetched ??
      payload.total ??
      (Array.isArray(payload.signals) ? payload.signals.length : undefined) ??
      (Array.isArray(payload.items) ? payload.items.length : undefined) ??
      0;

    return {
      ok: response.ok,
      degraded: !response.ok,
      status: response.status,
      statusText: response.statusText,
      count,
      fetchUrl,
      payload: response.json || response.text || ''
    };
  } catch (error) {
    return {
      ok: false,
      degraded: true,
      status: 0,
      statusText: error.message,
      count: 0,
      fetchUrl,
      payload: ''
    };
  }
});
