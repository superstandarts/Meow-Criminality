import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';

const root = path.dirname(fileURLToPath(import.meta.url));
const parent = process.platform === 'win32' ? path.join(process.env.LOCALAPPDATA, 'Temp', 'opencode') : os.tmpdir();
assert((await fs.stat(parent)).isDirectory());
const { ADMIN_TOKEN } = JSON.parse(await fs.readFile(path.join(parent, 'endhub-operator-secrets.json'), 'utf8'));
const { keyServiceUrl: origin } = JSON.parse(await fs.readFile(path.join(root, '..', 'endhub.config.json'), 'utf8'));
async function admin(route, body) {
  const response = await fetch(origin + route, { method: 'POST', headers: {
    'Content-Type': 'application/json', Authorization: `Bearer ${ADMIN_TOKEN}`,
  }, body: JSON.stringify(body) });
  assert(response.ok, `Admin HTTP ${response.status}`);
  return response.json();
}
async function client(route, key) {
  return fetch(origin + route, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ key }) });
}
assert.equal((await fetch(origin + '/admin')).status, 200);
assert.equal((await fetch(origin + '/Criminality.luau')).status, 404);
assert.equal((await fetch(origin + '/admin/keys')).status, 401);
const logo = await fetch(origin + '/logo.png');
assert.equal(logo.status, 200);
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
assert.equal(hash(Buffer.from(await logo.arrayBuffer())), hash(await fs.readFile(path.join(root, 'public', 'logo.png'))));
const [issued] = (await admin('/admin/keys', { plan: 'weekly', count: 1 })).keys;
const keyfile = path.join(parent, `endhub-test-key-${issued.id}.txt`);
await fs.writeFile(keyfile, issued.key + '\n', { flag: 'wx', mode: 0o600 });
const validation = await client('/v1/validate', issued.key);
assert.equal(validation.status, 200);
assert.equal((await validation.json()).valid, true);
const script = await client('/v1/script', issued.key);
assert.equal(script.status, 200);
assert.equal(hash(Buffer.from(await script.arrayBuffer())), hash(await fs.readFile(path.join(root, 'public', 'Criminality.luau'))));
const [revoked] = (await admin('/admin/keys', { plan: 'permanent', count: 1 })).keys;
await admin('/admin/revoke', { id: revoked.id });
assert.equal((await client('/v1/validate', revoked.key)).status, 403);
assert.equal((await client('/v1/validate', 'INVALID')).status, 403);
console.log('Live verification passed: admin auth, logo, source integrity, valid/invalid/revoked keys, and asset access.');
console.log(`A weekly test key is stored locally: ${keyfile}`);
