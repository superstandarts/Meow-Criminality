import { test } from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { readFile } from 'node:fs/promises';
import { createHmac } from 'node:crypto';
import { Script } from 'node:vm';
import worker, { generateKey } from '../src/worker.mjs';

const migration = await readFile(new URL('../migrations/0001_keys.sql', import.meta.url), 'utf8');
const START = Date.UTC(2026, 9, 12, 12, 0, 0);
const TOKEN = 'admin-token-for-tests-only-1234567890';
const PEPPER = 'key-pepper-for-tests-only-1234567890';
const invalid = { valid: false, message: 'Invalid or unavailable key.' };

// Execute the real prepared SQL in SQLite, including RETURNING, constraints,
// UPSERT, indexes, and transactional D1 batches. No query-pattern mock replies.
class D1Statement {
  constructor(db, sql, values = []) { this.db = db; this.sql = sql; this.values = values; }
  bind(...values) { return new D1Statement(this.db, this.sql, values); }
  execute(kind) {
    this.db.calls.push({ sql: this.sql, values: this.values });
    const statement = this.db.sqlite.prepare(this.sql);
    if (kind === 'first') return statement.get(...this.values) ?? null;
    if (kind === 'all') {
      const results = statement.all(...this.values);
      const changes = this.db.sqlite.prepare('SELECT changes() AS n').get().n;
      return { success: true, results, meta: { changes } };
    }
    const result = statement.run(...this.values);
    return { success: true, results: [], meta: { changes: result.changes } };
  }
  async first() { return this.execute('first'); }
  async all() { return this.execute('all'); }
  async run() { return this.execute('run'); }
}

class D1Database {
  constructor() {
    this.sqlite = new DatabaseSync(':memory:');
    this.sqlite.exec(migration);
    this.calls = [];
  }
  prepare(sql) { return new D1Statement(this, sql); }
  async batch(statements) {
    this.sqlite.exec('BEGIN');
    try {
      const results = statements.map(statement => statement.execute('all'));
      this.sqlite.exec('COMMIT');
      return results;
    } catch (error) {
      this.sqlite.exec('ROLLBACK');
      throw error;
    }
  }
}

function setup(t) {
  let time = START;
  t.mock.method(Date, 'now', () => time);
  const db = new D1Database();
  const assets = [];
  const pending = [];
  const env = {
    ADMIN_TOKEN: TOKEN, KEY_PEPPER: PEPPER, KEY_DB: db,
    ASSETS: { async fetch(request) {
      assets.push(request);
      const path = new URL(request.url).pathname;
      return new Response(path === '/logo.png' ? new Uint8Array([137, 80, 78, 71]) : 'return "protected script"',
        { headers: { 'Content-Type': 'application/octet-stream', 'Cache-Control': 'public, max-age=86400' } });
    } },
  };
  const context = { waitUntil(promise) { pending.push(promise); } };
  t.after(async () => { await Promise.all(pending); db.sqlite.close(); });
  const call = (path, { method = 'POST', body, raw, admin = false, ip, headers = {} } = {}) => {
    const allHeaders = { ...headers };
    if (admin) allHeaders.Authorization = `Bearer ${TOKEN}`;
    if (ip) allHeaders['CF-Connecting-IP'] = ip;
    const content = raw ?? (body === undefined ? undefined : JSON.stringify(body));
    if (content !== undefined && !Object.hasOwn(allHeaders, 'Content-Type')) allHeaders['Content-Type'] = 'application/json';
    const request = new Request(`https://keys.example${path}`, { method, body: content, headers: allHeaders });
    return worker.fetch(request, env, context);
  };
  const create = async (plan = 'weekly', count = 1) => {
    const response = await call('/admin/keys', { admin: true, body: { plan, count } });
    assert.equal(response.status, 201);
    return (await response.json()).keys;
  };
  return { db, env, assets, pending, call, create, context, setTime(value) { time = value; } };
}

test('all plans: exact format, HMAC-only storage, expiry from creation, exact validation contract', async t => {
  const s = setup(t);
  for (const [plan, days] of [['weekly', 7], ['monthly', 30], ['60days', 60], ['permanent', null]]) {
    const [item] = await s.create(plan);
    assert.match(item.key, /^END-\d{4}-\d{4}-\d{4}-\d{4}$/);
    assert.equal(item.key.length, 23);
    assert.equal(item.last4, item.key.slice(-4));
    const expiresAt = days === null ? false : new Date(START + days * 86400000).toISOString();
    assert.equal(item.expiresAt, expiresAt);
    const row = s.db.sqlite.prepare('SELECT * FROM license_keys WHERE id = ?').get(item.id);
    assert.equal(row.key_hash, createHmac('sha256', PEPPER).update(item.key).digest('hex'));
    assert.equal(row.created_at, START);
    assert.equal(row.expires_at, days === null ? null : START + days * 86400000);
    assert.ok(!JSON.stringify(row).includes(item.key));
    assert.ok(!s.db.calls.some(call => call.values.includes(item.key)));
    const response = await s.call('/v1/validate', { body: { key: item.key, now: '2099-01-01' } });
    assert.equal(response.status, 200);
    assert.equal(response.headers.get('Cache-Control'), 'no-store');
    assert.deepEqual(await response.json(), { valid: true, expiresAt, plan });
  }
  assert.equal(s.assets.length, 0);
  const schema = s.db.sqlite.prepare("SELECT name FROM pragma_table_info('license_keys')").all().map(row => row.name);
  assert.deepEqual(schema, ['id', 'key_hash', 'last4', 'plan', 'created_at', 'expires_at', 'revoked_at']);
  const query = s.db.sqlite.prepare('EXPLAIN QUERY PLAN SELECT plan FROM license_keys WHERE key_hash = ?').all('x');
  assert.match(query[0].detail, /USING INDEX/);
});

test('expiry is inclusive, never slides on use; permanent survives; revocation is idempotent', async t => {
  const s = setup(t);
  const [weekly] = await s.create();
  const [permanent] = await s.create('permanent');
  const expiry = START + 7 * 86400000;
  s.setTime(expiry - 1);
  assert.equal((await s.call('/v1/validate', { body: { key: weekly.key } })).status, 200);
  s.setTime(expiry);
  const expired = await s.call('/v1/validate', { body: { key: weekly.key } });
  assert.equal(expired.status, 403);
  assert.deepEqual(await expired.json(), invalid);
  const list = await (await s.call('/admin/keys', { method: 'GET', admin: true })).json();
  assert.equal(list.keys.find(item => item.id === weekly.id).status, 'expired');
  s.setTime(START + 36500 * 86400000);
  assert.equal((await s.call('/v1/validate', { body: { key: permanent.key } })).status, 200);
  for (let attempt = 0; attempt < 2; attempt++) {
    const response = await s.call('/admin/revoke', { admin: true, body: { id: permanent.id } });
    assert.deepEqual(await response.json(), { revoked: true });
  }
  for (const route of ['/v1/validate', '/v1/script']) {
    const response = await s.call(route, { body: { key: permanent.key } });
    assert.equal(response.status, 403);
    assert.deepEqual(await response.json(), invalid);
  }
  assert.equal(s.assets.length, 0);
});

test('unknown and malformed keys get the same 403 and never call ASSETS; no trimming or case folding', async t => {
  const s = setup(t);
  const [item] = await s.create();
  const cases = [undefined, null, 123, item.key.toLowerCase(), item.key + '\n', ' ' + item.key,
    'END-0000-0000-0000-0000', "' OR 1=1 --", item.key.replace(/\d/, '\u0661')];
  for (let index = 0; index < cases.length; index++) {
    const response = await s.call('/v1/script', { body: { key: cases[index] }, ip: `invalid-${index}` });
    assert.equal(response.status, 403);
    assert.deepEqual(await response.json(), invalid);
  }
  assert.equal(s.assets.length, 0);
});

test('admin authentication cannot be supplied in URL, body, cookies, or incorrect Bearer token', async t => {
  const s = setup(t);
  const variants = [{}, { headers: { Authorization: `Bearer ${TOKEN.slice(0, -1)}x` } },
    { headers: { Authorization: `Basic ${TOKEN}` } }, { headers: { Cookie: `ADMIN_TOKEN=${TOKEN}` } },
    { headers: { Authorization: `Bearer ${TOKEN}extra` } }];
  for (const route of ['/admin/keys', '/admin/revoke', '/admin/rate-limits']) {
    for (const options of variants) {
      const response = await s.call(route + '?token=' + TOKEN, { ...options, body: { token: TOKEN } });
      assert.equal(response.status, 401);
      assert.deepEqual(await response.json(), { message: 'Unauthorized.' });
    }
  }
  assert.equal(s.db.calls.length, 0);
});

test('missing or short secrets and unavailable D1 fail closed without querying or serving script', async t => {
  const s = setup(t);
  for (const name of ['ADMIN_TOKEN', 'KEY_PEPPER']) {
    const saved = s.env[name];
    for (const value of [undefined, '', 'x'.repeat(31), 1234]) {
      s.env[name] = value;
      for (const route of ['/v1/validate', '/v1/script', '/admin/keys', '/admin']) {
        const response = await s.call(route, { body: { key: 'END-0000-0000-0000-0000' }, admin: true });
        assert.equal(response.status, 503);
        assert.equal((await response.json()).valid, false);
      }
    }
    s.env[name] = saved;
  }
  s.env.KEY_DB = undefined;
  assert.equal((await s.call('/v1/script', { body: { key: 'END-0000-0000-0000-0000' } })).status, 503);
  assert.equal(s.db.calls.length, 0);
  assert.equal(s.assets.length, 0);
});

test('D1 exceptions are generic, fail closed, and never leak errors or credentials', async t => {
  const s = setup(t);
  const [item] = await s.create();
  t.mock.method(s.db, 'prepare', () => { throw new Error('database secret ' + item.key + TOKEN); });
  for (const route of ['/v1/validate', '/v1/script', '/admin/keys']) {
    const response = await s.call(route, { body: { key: item.key, plan: 'weekly', count: 1 }, admin: true });
    assert.equal(response.status, 503);
    assert.deepEqual(await response.json(), { valid: false, message: 'Service unavailable.' });
  }
  assert.equal(s.assets.length, 0);
});

test('batch bounds, plan validation, metadata only listing, and ID validation', async t => {
  const s = setup(t);
  for (const body of [{ plan: 'Weekly', count: 1 }, { plan: '__proto__', count: 1 },
    { plan: { toString: null }, count: 1 }, { plan: 'weekly', count: 0 }, { plan: 'weekly', count: 21 },
    { plan: 'weekly', count: 1.5 }, { plan: 'weekly', count: '1' }, { plan: 'weekly' }]) {
    assert.equal((await s.call('/admin/keys', { admin: true, body })).status, 400);
  }
  const created = await s.create('monthly', 20);
  assert.equal(new Set(created.map(item => item.key)).size, 20);
  const response = await s.call('/admin/keys', { method: 'GET', admin: true });
  const text = await response.text();
  assert.ok(!created.some(item => text.includes(item.key)));
  const data = JSON.parse(text);
  assert.equal(data.keys.length, 20);
  assert.equal(data.nextCursor, null);
  assert.deepEqual(Object.keys(data.keys[0]).sort(), ['expiresAt', 'id', 'last4', 'plan', 'status']);
  for (const id of [null, "' OR 1=1 --", created[0].id + '\n']) {
    assert.equal((await s.call('/admin/revoke', { admin: true, body: { id } })).status, 400);
  }
  assert.equal((await s.call('/admin/revoke', { admin: true, body: { id: crypto.randomUUID() } })).status, 404);
});

test('metadata pagination is bounded, ordered, non-overlapping, and parameterized', async t => {
  const s = setup(t);
  for (let index = 0; index < 6; index++) await s.create('permanent', 20);
  const page1 = await (await s.call('/admin/keys', { method: 'GET', admin: true })).json();
  assert.equal(page1.keys.length, 100);
  assert.equal(page1.nextCursor, page1.keys.at(-1).id);
  const page2 = await (await s.call('/admin/keys?cursor=' + page1.nextCursor, { method: 'GET', admin: true })).json();
  assert.equal(page2.keys.length, 20);
  assert.equal(page2.nextCursor, null);
  assert.equal(new Set([...page1.keys, ...page2.keys].map(item => item.id)).size, 120);
  for (const cursor of ["' OR 1=1 --", page1.nextCursor + '\n']) {
    const response = await s.call('/admin/keys?cursor=' + encodeURIComponent(cursor), { method: 'GET', admin: true });
    assert.equal(response.status, 400);
  }
});

test('8 attempts/minute: atomic UPSERT, shared validation/script counter, IP separation, fixed local fallback', async t => {
  const s = setup(t);
  const [item] = await s.create();
  const responses = await Promise.all(Array.from({ length: 12 }, (_, index) => s.call(
    index % 2 ? '/v1/validate' : '/v1/script', { body: { key: item.key }, ip: '203.0.113.10' }
  )));
  assert.equal(responses.filter(response => response.status === 200).length, 8);
  assert.equal(responses.filter(response => response.status === 429).length, 4);
  for (const response of responses.filter(response => response.status === 429)) {
    assert.equal(response.headers.get('Retry-After'), '60');
    assert.equal((await response.json()).valid, false);
  }
  assert.equal(s.db.sqlite.prepare('SELECT attempts FROM rate_limits').get().attempts, 9);
  assert.equal((await s.call('/v1/validate', { body: { key: item.key }, ip: '203.0.113.11' })).status, 200);
  s.setTime(START + 59999);
  const limited = await s.call('/v1/validate', { body: { key: item.key }, ip: '203.0.113.10' });
  assert.equal(limited.headers.get('Retry-After'), '1');
  s.setTime(START + 60000);
  assert.equal((await s.call('/v1/validate', { body: { key: item.key }, ip: '203.0.113.10' })).status, 200);
  for (let attempt = 0; attempt < 8; attempt++) {
    assert.equal((await s.call('/v1/validate', { body: { key: 'bad' }, headers: { 'X-Forwarded-For': String(attempt) } })).status, 403);
  }
  assert.equal((await s.call('/v1/validate', { body: { key: item.key } })).status, 429);
  const stored = JSON.stringify(s.db.sqlite.prepare('SELECT * FROM rate_limits').all());
  assert.ok(!stored.includes('203.0.113.10'));
  assert.ok(!stored.includes('local'));
});

test('malformed JSON is bounded and counted; arrays, null, and incorrect media type fail', async t => {
  const s = setup(t);
  for (const raw of ['{', 'null', '[]', '"key"', '0', '', '{"key":']) {
    assert.equal((await s.call('/v1/validate', { raw })).status, 400);
  }
  assert.equal((await s.call('/v1/validate', { raw: '{}' })).status, 403);
  assert.equal((await s.call('/v1/validate', { raw: '{' })).status, 429);
  const calls = s.db.calls.length;
  assert.equal((await s.call('/v1/validate', { raw: '{}', headers: { 'Content-Type': 'text/plain' } })).status, 415);
  for (const length of ['4097', '-1', 'x']) {
    assert.equal((await s.call('/v1/validate', { raw: '{}', headers: { 'Content-Length': length } })).status, 413);
  }
  assert.equal((await s.call('/v1/validate', { raw: ' '.repeat(4097), headers: { 'Content-Length': '2' } })).status, 413);
  assert.equal((await s.call('/v1/validate', { raw: '\u00e9'.repeat(2049) })).status, 413);
  assert.equal(s.db.calls.length, calls, 'oversized/unsupported bodies must not access D1');
});

test('a delayed previous-minute UPSERT cannot reset a newer exhausted window', async t => {
  const s = setup(t);
  let signal;
  let release;
  let delay = true;
  const entered = new Promise(resolve => { signal = resolve; });
  const barrier = new Promise(resolve => { release = resolve; });
  const prepare = s.db.prepare.bind(s.db);
  t.mock.method(s.db, 'prepare', sql => {
    const statement = prepare(sql);
    if (!sql.startsWith('INSERT INTO rate_limits')) return statement;
    const bind = statement.bind.bind(statement);
    statement.bind = (...values) => {
      const bound = bind(...values);
      const first = bound.first.bind(bound);
      bound.first = async () => {
        if (delay) { delay = false; signal(); await barrier; }
        return first();
      };
      return bound;
    };
    return statement;
  });
  const previous = s.call('/v1/validate', { body: { key: 'bad' }, ip: 'delayed-ip' });
  await entered;
  s.setTime(START + 60000);
  for (let index = 0; index < 8; index++) {
    assert.equal((await s.call('/v1/validate', { body: { key: 'bad' }, ip: 'delayed-ip' })).status, 403);
  }
  release();
  const response = await previous;
  assert.equal(response.status, 429);
  assert.equal(response.headers.get('Retry-After'), '60');
  const row = s.db.sqlite.prepare('SELECT * FROM rate_limits').get();
  assert.equal(row.window_start, START + 60000);
  assert.equal(row.expires_at, START + 120000);
  assert.equal(row.attempts, 9);
});

test('stream size is enforced before D1, including absent Content-Length and UTF-8 byte size', async t => {
  const s = setup(t);
  let cancelled = false;
  const body = new ReadableStream({
    start(controller) { controller.enqueue(new Uint8Array(2048)); controller.enqueue(new Uint8Array(2049)); },
    cancel() { cancelled = true; },
  });
  const request = new Request('https://keys.example/v1/script', {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body, duplex: 'half',
  });
  const response = await worker.fetch(request, s.env, s.context);
  assert.equal(response.status, 413);
  assert.equal(cancelled, true);
  assert.equal(s.db.calls.length, 0);
  assert.equal(s.assets.length, 0);
  const badUtf8 = new Request('https://keys.example/v1/validate', {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: new Uint8Array([255]),
  });
  assert.equal((await worker.fetch(badUtf8, s.env, s.context)).status, 400);
  assert.equal(s.db.calls.length, 0);
});

test('server time is checked after a streamed body, not taken from client or stale request start', async t => {
  const s = setup(t);
  const [item] = await s.create();
  const expiry = START + 7 * 86400000;
  s.setTime(expiry - 1);
  const body = new ReadableStream({ pull(controller) {
    s.setTime(expiry);
    controller.enqueue(new TextEncoder().encode(JSON.stringify({ key: item.key, now: START })));
    controller.close();
  } });
  const request = new Request('https://keys.example/v1/script', {
    method: 'POST', body, headers: { 'Content-Type': 'application/json' }, duplex: 'half',
  });
  assert.equal((await worker.fetch(request, s.env, s.context)).status, 403);
  assert.equal(s.assets.length, 0);
});

test('protected script asset and public logo; every other asset path is denied without ASSETS call', async t => {
  const s = setup(t);
  const [item] = await s.create();
  for (const path of ['/Criminality.luau', '/public/Criminality.luau', '/%43riminality.luau', '/Criminality.luau?key=' + item.key,
    '/', '/admin.mjs', '/logo.png/']) {
    assert.equal((await s.call(path, { method: 'GET' })).status, 404);
  }
  assert.equal(s.assets.length, 0);
  const script = await s.call('/v1/script?extra=1', { body: { key: item.key }, admin: true });
  assert.equal(script.status, 200);
  assert.equal(script.headers.get('Cache-Control'), 'private, no-store');
  assert.equal(script.headers.get('Content-Type'), 'text/plain; charset=utf-8');
  assert.equal(await script.text(), 'return "protected script"');
  const sent = s.assets[0];
  assert.equal(sent.url, 'https://keys.example/Criminality.luau');
  assert.equal(sent.method, 'GET');
  assert.equal(sent.headers.get('Authorization'), null);
  assert.equal(sent.body, null);
  const logo = await s.call('/logo.png?unused=1', { method: 'GET' });
  assert.equal(logo.status, 200);
  assert.equal(logo.headers.get('Content-Type'), 'image/png');
  assert.equal(s.assets[1].url, 'https://keys.example/logo.png');
  t.mock.method(s.env.ASSETS, 'fetch', async () => new Response('missing', { status: 404 }));
  assert.equal((await s.call('/v1/script', { body: { key: item.key } })).status, 404);
});

test('routes enforce methods and keys in GET parameters never activate script retrieval', async t => {
  const s = setup(t);
  for (const [path, method, allow] of [['/v1/validate', 'GET', 'POST'], ['/v1/script', 'GET', 'POST'],
    ['/admin', 'POST', 'GET'], ['/admin/keys', 'DELETE', 'GET, POST'],
    ['/admin/revoke', 'GET', 'POST'], ['/admin/rate-limits', 'GET', 'DELETE']]) {
    const response = await s.call(path, { method, admin: true });
    assert.equal(response.status, 405);
    assert.equal(response.headers.get('Allow'), allow);
  }
  assert.equal(s.assets.length, 0);
});

test('rejection sampling discards biased bytes and produces exactly sixteen decimal digits', t => {
  let calls = 0;
  t.mock.method(crypto, 'getRandomValues', bytes => {
    calls++;
    bytes.fill(255);
    if (calls > 1) bytes.set([250, 251, 252, 253, 254, 255, 249, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]);
    return bytes;
  });
  assert.equal(generateKey(), 'END-9012-3456-7890-1234');
  assert.equal(calls, 2);
});

test('INSERT OR IGNORE retries collisions within budget and leaves no partial batch on exhaustion', async t => {
  const s = setup(t);
  let random = 0;
  t.mock.method(crypto, 'getRandomValues', bytes => { bytes.fill(random); return bytes; });
  const [original] = await s.create('permanent');
  let call = 0;
  crypto.getRandomValues.mock.mockImplementation(bytes => { bytes.fill(call++ === 0 ? 0 : 1); return bytes; });
  const [second] = await s.create();
  assert.notEqual(second.key, original.key);
  assert.equal(call, 2);
  call = 0;
  crypto.getRandomValues.mock.mockImplementation(bytes => { bytes.fill(call++ === 0 ? 2 : 0); return bytes; });
  const response = await s.call('/admin/keys', { admin: true, body: { plan: 'weekly', count: 2 } });
  assert.equal(response.status, 503);
  assert.equal(s.db.sqlite.prepare('SELECT COUNT(*) AS n FROM license_keys').get().n, 2);
  assert.equal(call, 6, 'one successful candidate plus five ignored collisions, bounded');
});

test('D1 facade batches roll back actual SQL failures', async t => {
  const s = setup(t);
  await assert.rejects(s.db.batch([
    s.db.prepare('INSERT INTO rate_limits VALUES (?, ?, ?, ?)').bind('x', START, START + 60000, 1),
    s.db.prepare('INSERT INTO rate_limits VALUES (?, ?, ?, ?)').bind('y', START, START + 60000, 10),
  ]));
  assert.equal(s.db.sqlite.prepare('SELECT COUNT(*) AS n FROM rate_limits').get().n, 0);
});

test('rate cleanup is indexed, bounded to 256, admin-authenticated, and amortized per 100 calls', async t => {
  const s = setup(t);
  const insert = s.db.sqlite.prepare('INSERT INTO rate_limits VALUES (?, ?, ?, ?)');
  for (let index = 0; index < 600; index++) insert.run(`old-${index}`, START - 60000, START, 1);
  insert.run('live', START, START + 60000, 1);
  assert.equal((await s.call('/admin/rate-limits', { method: 'DELETE' })).status, 401);
  const manual = await s.call('/admin/rate-limits', { method: 'DELETE', admin: true });
  assert.deepEqual(await manual.json(), { deleted: 256 });
  const before = s.db.calls.filter(call => call.sql.startsWith('DELETE FROM rate_limits')).length;
  for (let index = 0; index < 100; index++) {
    await s.call('/v1/validate', { body: { key: 'bad' }, ip: 'cleanup-test' });
  }
  await Promise.all(s.pending);
  const after = s.db.calls.filter(call => call.sql.startsWith('DELETE FROM rate_limits')).length;
  assert.equal(after - before, 1);
  assert.equal(s.db.sqlite.prepare('SELECT COUNT(*) AS n FROM rate_limits WHERE expires_at <= ?').get(START).n, 88);
  assert.ok(s.db.sqlite.prepare('SELECT * FROM rate_limits WHERE ip_hash = ?').get('live'));
  const query = s.db.sqlite.prepare('EXPLAIN QUERY PLAN SELECT ip_hash FROM rate_limits WHERE expires_at <= ? ORDER BY expires_at LIMIT 256').all(START);
  assert.match(query[0].detail, /rate_limits_expiry/);
});

test('admin HTML uses matching nonce CSP, English responsive UI, password field and memory-only token', async t => {
  const s = setup(t);
  const response = await s.call('/admin', { method: 'GET' });
  assert.equal(response.status, 200);
  const html = await response.text();
  const csp = response.headers.get('Content-Security-Policy');
  const nonce = csp.match(/script-src 'nonce-([a-f0-9]+)'/)[1];
  assert.ok(csp.includes(`style-src 'nonce-${nonce}'`));
  assert.ok(csp.includes("default-src 'none'"));
  assert.ok(csp.includes("frame-ancestors 'none'"));
  assert.ok(csp.includes("connect-src 'self'"));
  assert.equal((html.match(new RegExp(`nonce="${nonce}"`, 'g')) ?? []).length, 2);
  assert.match(html, /<html lang="en">/);
  assert.match(html, /type="password"/);
  assert.match(html, /readonly aria-label="New keys"/);
  assert.match(html, /@media/);
  assert.match(html, /Authorization: 'Bearer ' \+ token/);
  assert.doesNotMatch(html, /localStorage|sessionStorage|https?:\/\/|document\.cookie|innerHTML|console\./);
  const script = html.match(/<script nonce="[a-f0-9]+">([\s\S]*?)<\/script>/)[1];
  assert.doesNotThrow(() => new Script(script));
  assert.equal(response.headers.get('Cache-Control'), 'no-store');
  const another = await s.call('/admin', { method: 'GET' });
  assert.notEqual(another.headers.get('Content-Security-Policy'), csp);
});

test('Wrangler forces Worker-first assets and contains no embedded secrets', async () => {
  const config = await readFile(new URL('../wrangler.jsonc', import.meta.url), 'utf8');
  assert.match(config, /"run_worker_first": true/);
  assert.match(config, /"binding": "ASSETS"/);
  assert.match(config, /"binding": "KEY_DB"/);
  assert.doesNotMatch(config, /ADMIN_TOKEN|KEY_PEPPER/);
  const source = await readFile(new URL('../src/worker.mjs', import.meta.url), 'utf8');
  assert.doesNotMatch(source, /console\.|Math\.random|request\.text\(/);
});
