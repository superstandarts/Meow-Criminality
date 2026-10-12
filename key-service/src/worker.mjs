import { adminPage } from './admin.mjs';

const PLANS = Object.freeze({ weekly: 7, monthly: 30, '60days': 60, permanent: null });
const KEY_FORMAT = /^END-\d{4}-\d{4}-\d{4}-\d{4}$/;
const UUID_FORMAT = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const INVALID = { valid: false, message: 'Invalid or unavailable key.' };
const encoder = new TextEncoder();
let rateCalls = 0;

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

function json(value, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(value), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
      ...extraHeaders,
    },
  });
}

function configured(env) {
  return typeof env.ADMIN_TOKEN === 'string' && env.ADMIN_TOKEN.length >= 32 &&
    typeof env.KEY_PEPPER === 'string' && env.KEY_PEPPER.length >= 32 && env.KEY_DB;
}

async function authorized(request, token) {
  const header = request.headers.get('Authorization') ?? '';
  const supplied = header.startsWith('Bearer ') && header.length <= 4103 ? header.slice(7) : '';
  const [actual, expected] = await Promise.all([
    crypto.subtle.digest('SHA-256', encoder.encode(supplied)),
    crypto.subtle.digest('SHA-256', encoder.encode(token)),
  ]);
  const a = new Uint8Array(actual);
  const b = new Uint8Array(expected);
  let difference = 0;
  // Always compare every byte of equal-length digests; no early-return secret comparison.
  for (let index = 0; index < a.length; index++) difference |= a[index] ^ b[index];
  return difference === 0;
}

async function digest(value, pepper) {
  const key = await crypto.subtle.importKey('raw', encoder.encode(pepper),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const bytes = new Uint8Array(await crypto.subtle.sign('HMAC', key, encoder.encode(value)));
  return Array.from(bytes, byte => byte.toString(16).padStart(2, '0')).join('');
}

export function generateKey() {
  let digits = '';
  while (digits.length < 16) {
    const bytes = crypto.getRandomValues(new Uint8Array(32));
    // 250 is a multiple of 10: rejecting 250..255 avoids modulo bias.
    for (const byte of bytes) {
      if (byte < 250) digits += String(byte % 10);
      if (digits.length === 16) break;
    }
  }
  return `END-${digits.match(/.{4}/g).join('-')}`;
}

async function boundedBody(request) {
  const length = request.headers.get('Content-Length');
  if (length !== null && (!/^\d+$/.test(length) || Number(length) > 4096)) {
    throw new HttpError(413, 'Request body exceeds 4096 bytes.');
  }
  if (!/^application\/json(?:\s*;|$)/i.test(request.headers.get('Content-Type') ?? '')) {
    throw new HttpError(415, 'Use application/json.');
  }
  if (!request.body) return '';
  const reader = request.body.getReader();
  const chunks = [];
  let size = 0;
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > 4096) {
        await reader.cancel();
        throw new HttpError(413, 'Request body exceeds 4096 bytes.');
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  try {
    return new TextDecoder('utf-8', { fatal: true }).decode(bytes);
  } catch {
    throw new HttpError(400, 'Malformed JSON.');
  }
}

function payload(text) {
  let data;
  try { data = JSON.parse(text); } catch { throw new HttpError(400, 'Malformed JSON.'); }
  if (!data || typeof data !== 'object' || Array.isArray(data)) {
    throw new HttpError(400, 'Expected a JSON object.');
  }
  return data;
}

async function pruneRates(db, now) {
  return db.prepare(`DELETE FROM rate_limits WHERE ip_hash IN (
    SELECT ip_hash FROM rate_limits WHERE expires_at <= ? ORDER BY expires_at LIMIT 256
  )`).bind(now).run();
}

async function rateLimit(request, env, now, context) {
  const start = Math.floor(now / 60000) * 60000;
  const ip = request.headers.get('CF-Connecting-IP') || 'local';
  const ipHash = await digest(`rate:${ip}`, env.KEY_PEPPER);
  const row = await env.KEY_DB.prepare(`INSERT INTO rate_limits (ip_hash, window_start, expires_at, attempts)
    VALUES (?, ?, ?, 1)
    ON CONFLICT(ip_hash) DO UPDATE SET
      attempts = CASE WHEN rate_limits.window_start >= excluded.window_start
        THEN MIN(rate_limits.attempts + 1, 9) ELSE 1 END,
      window_start = MAX(rate_limits.window_start, excluded.window_start),
      expires_at = MAX(rate_limits.expires_at, excluded.expires_at)
    RETURNING attempts, expires_at`).bind(ipHash, start, start + 60000).first();
  // Per-isolate, amortized cleanup; each indexed sweep deletes at most 256 rows.
  if (++rateCalls % 100 === 0) {
    const cleanup = pruneRates(env.KEY_DB, now).catch(() => {});
    if (context?.waitUntil) context.waitUntil(cleanup);
    else await cleanup;
  }
  if (!row || !Number.isInteger(row.attempts) || row.attempts < 1) throw new Error('Rate limit unavailable');
  return row.attempts <= 8 ? null : json({ valid: false, message: 'Too many attempts. Try again later.' },
    429, { 'Retry-After': String(Math.max(1, Math.ceil((row.expires_at - Date.now()) / 1000))) });
}

function metadata(row, now) {
  return {
    id: row.id,
    last4: row.last4,
    plan: row.plan,
    expiresAt: row.expires_at === null ? false : new Date(row.expires_at).toISOString(),
    status: row.revoked_at !== null ? 'revoked' :
      row.expires_at !== null && row.expires_at <= now ? 'expired' : 'active',
  };
}

async function createKeys(env, data, now) {
  if (typeof data.plan !== 'string' || !Object.hasOwn(PLANS, data.plan) ||
      !Number.isInteger(data.count) || data.count < 1 || data.count > 20) {
    throw new HttpError(400, 'Choose a valid plan and an integer count from 1 to 20.');
  }
  const expires = PLANS[data.plan] === null ? null : now + PLANS[data.plan] * 86400000;
  const created = [];
  try {
    // Each round is an atomic D1 batch. Retry only ignored hash collisions, at most five rounds.
    for (let round = 0; created.length < data.count && round < 5; round++) {
      const candidates = [];
      for (let index = created.length; index < data.count; index++) {
        const key = generateKey();
        candidates.push({ key, id: crypto.randomUUID(), hash: await digest(key, env.KEY_PEPPER) });
      }
      const results = await env.KEY_DB.batch(candidates.map(candidate => env.KEY_DB.prepare(
        `INSERT OR IGNORE INTO license_keys (id, key_hash, last4, plan, created_at, expires_at)
         VALUES (?, ?, ?, ?, ?, ?) RETURNING id`
      ).bind(candidate.id, candidate.hash, candidate.key.slice(-4), data.plan, now, expires)));
      for (let index = 0; index < candidates.length; index++) {
        if (results[index].results.length === 0) continue;
        const candidate = candidates[index];
        created.push({ key: candidate.key, ...metadata({ id: candidate.id, last4: candidate.key.slice(-4),
          plan: data.plan, expires_at: expires, revoked_at: null }, now) });
      }
    }
    if (created.length !== data.count) throw new Error('Key generation exhausted');
    return json({ keys: created }, 201);
  } catch (error) {
    if (created.length) {
      await env.KEY_DB.batch(created.map(item => env.KEY_DB.prepare('DELETE FROM license_keys WHERE id = ?').bind(item.id)));
    }
    throw error;
  }
}

async function asset(env, request, path, contentType, privateResponse) {
  if (!env.ASSETS) throw new Error('Assets unavailable');
  // Do not forward keys, Authorization, request bodies, queries, or client headers to ASSETS.
  const result = await env.ASSETS.fetch(new Request(new URL(path, request.url)));
  if (result.status !== 200) return json({ message: 'Asset unavailable.' }, 404);
  return new Response(result.body, {
    headers: {
      'Content-Type': contentType,
      'Cache-Control': privateResponse ? 'private, no-store' : 'public, max-age=3600',
      'X-Content-Type-Options': 'nosniff',
    },
  });
}

export default {
  async fetch(request, env, context) {
    const url = new URL(request.url);
    const path = url.pathname;
    const publicAPI = path === '/v1/validate' || path === '/v1/script';
    const adminAPI = path === '/admin/keys' || path === '/admin/revoke' || path === '/admin/rate-limits';
    try {
      if (path === '/logo.png' && request.method === 'GET') {
        return await asset(env, request, '/logo.png', 'image/png', false);
      }
      if (!(publicAPI || adminAPI || path === '/admin')) return json({ message: 'Not found.' }, 404);
      if (!configured(env)) return json({ valid: false, message: 'Service unavailable.' }, 503);
      if (path === '/admin') {
        if (request.method !== 'GET') return json({ message: 'Method not allowed.' }, 405, { Allow: 'GET' });
        const nonce = crypto.randomUUID().replaceAll('-', '');
        return new Response(adminPage(nonce), { headers: {
          'Content-Type': 'text/html; charset=utf-8',
          'Cache-Control': 'no-store',
          'X-Content-Type-Options': 'nosniff',
          'Referrer-Policy': 'no-referrer',
          'Content-Security-Policy': `default-src 'none'; script-src 'nonce-${nonce}'; style-src 'nonce-${nonce}'; connect-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'`,
        } });
      }
      if (adminAPI && !await authorized(request, env.ADMIN_TOKEN)) {
        return json({ message: 'Unauthorized.' }, 401, { 'WWW-Authenticate': 'Bearer' });
      }
      const now = Date.now();
      if (publicAPI) {
        if (request.method !== 'POST') return json({ message: 'Method not allowed.' }, 405, { Allow: 'POST' });
        const text = await boundedBody(request);
        const limited = await rateLimit(request, env, Date.now(), context);
        if (limited) return limited;
        const data = payload(text);
        if (typeof data.key !== 'string' || data.key.length !== 23 || !KEY_FORMAT.test(data.key)) return json(INVALID, 403);
        const row = await env.KEY_DB.prepare(
          'SELECT plan, expires_at, revoked_at FROM license_keys WHERE key_hash = ?'
        ).bind(await digest(data.key, env.KEY_PEPPER)).first();
        if (!row || !Object.hasOwn(PLANS, row.plan) || row.revoked_at !== null ||
            (row.plan === 'permanent' ? row.expires_at !== null :
              !Number.isSafeInteger(row.expires_at) || row.expires_at <= Date.now())) return json(INVALID, 403);
        if (path === '/v1/script') {
          return await asset(env, request, '/Criminality.luau', 'text/plain; charset=utf-8', true);
        }
        return json({ valid: true, expiresAt: row.expires_at === null ? false :
          new Date(row.expires_at).toISOString(), plan: row.plan });
      }
      if (path === '/admin/keys' && request.method === 'GET') {
        const cursor = url.searchParams.get('cursor') ?? '';
        if (cursor && (cursor.length !== 36 || !UUID_FORMAT.test(cursor))) throw new HttpError(400, 'Invalid cursor.');
        const { results } = await env.KEY_DB.prepare(
          'SELECT id, last4, plan, expires_at, revoked_at FROM license_keys WHERE id > ? ORDER BY id LIMIT 101'
        ).bind(cursor).all();
        const page = results.slice(0, 100);
        return json({ keys: page.map(row => metadata(row, now)),
          nextCursor: results.length > 100 ? page.at(-1).id : null });
      }
      if (path === '/admin/keys' && request.method === 'POST') {
        const data = payload(await boundedBody(request));
        return await createKeys(env, data, Date.now());
      }
      if (path === '/admin/revoke' && request.method === 'POST') {
        const data = payload(await boundedBody(request));
        if (typeof data.id !== 'string' || data.id.length !== 36 || !UUID_FORMAT.test(data.id)) {
          throw new HttpError(400, 'Invalid key ID.');
        }
        const row = await env.KEY_DB.prepare(
          'UPDATE license_keys SET revoked_at = COALESCE(revoked_at, ?) WHERE id = ? RETURNING id'
        ).bind(Date.now(), data.id).first();
        return row ? json({ revoked: true }) : json({ message: 'Key not found.' }, 404);
      }
      if (path === '/admin/rate-limits' && request.method === 'DELETE') {
        const result = await pruneRates(env.KEY_DB, now);
        return json({ deleted: result.meta.changes });
      }
      const allow = path === '/admin/keys' ? 'GET, POST' : path === '/admin/revoke' ? 'POST' : 'DELETE';
      return json({ message: 'Method not allowed.' }, 405, { Allow: allow });
    } catch (error) {
      // Never log errors or requests: they can contain plaintext keys or credentials.
      return json({ valid: false, message: error instanceof HttpError ? error.message : 'Service unavailable.' },
        error instanceof HttpError ? error.status : 503);
    }
  },
};
