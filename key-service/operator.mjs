import { randomBytes } from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = path.dirname(fileURLToPath(import.meta.url));
const parent = process.platform === 'win32' ? path.join(process.env.LOCALAPPDATA, 'Temp', 'opencode') : os.tmpdir();
if (!(await fs.stat(parent)).isDirectory()) throw new Error('Operator storage directory is unavailable.');
const filename = path.join(parent, 'endhub-operator-secrets.json');
let secrets;
try {
  secrets = JSON.parse(await fs.readFile(filename, 'utf8'));
} catch (error) {
  if (error.code !== 'ENOENT') throw error;
  secrets = { ADMIN_TOKEN: randomBytes(32).toString('hex'), KEY_PEPPER: randomBytes(32).toString('hex') };
  await fs.writeFile(filename, JSON.stringify(secrets, null, 2) + '\n', { flag: 'wx', mode: 0o600 });
}
if (typeof secrets.ADMIN_TOKEN !== 'string' || typeof secrets.KEY_PEPPER !== 'string' ||
    secrets.ADMIN_TOKEN.length < 32 || secrets.KEY_PEPPER.length < 32) throw new Error('Invalid stored operator credentials.');

const cli = path.join(root, 'node_modules', 'wrangler', 'bin', 'wrangler.js');
const result = spawnSync(process.execPath, [cli, 'secret', 'bulk'], {
  cwd: root, input: JSON.stringify(secrets), encoding: 'utf8', timeout: 120000,
});
if (result.status !== 0 || result.error) throw new Error('Secret upload failed; stored credentials were retained for retry.');
console.log(`Operator secrets uploaded. Local credentials: ${filename}`);
