import assert from 'node:assert/strict';
import * as fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.dirname(fileURLToPath(import.meta.url));
const temp = process.platform === 'win32'
    ? path.join(process.env.LOCALAPPDATA, 'Temp', 'opencode')
    : os.tmpdir();

async function directory(filename) {
    assert((await fs.stat(filename)).isDirectory(), `Not a directory: ${filename}`);
}

function literal(source) {
    let equals = '';
    while (source.includes(`]${equals}]`)) equals += '=';
    return `[${equals}[${source}]${equals}]`;
}

async function main() {
    assert(process.argv.length === 2, 'Usage: node test-movement.mjs (optional LUAU_BIN environment variable)');
    await directory(root);
    await directory(temp);
    let executable = process.env.LUAU_BIN;
    if (!executable && process.platform === 'win32') {
        const names = (await fs.readdir(temp)).filter(name => name.startsWith('luau-0.742-')).sort();
        for (const name of names) {
            const candidate = path.join(temp, name, 'luau.exe');
            try {
                if ((await fs.stat(candidate)).isFile()) {
                    executable = candidate;
                    break;
                }
            } catch (error) {
                if (error.code !== 'ENOENT') throw error;
            }
        }
    }
    executable ??= 'luau';
    const [moduleSource, testSource] = await Promise.all([
        fs.readFile(path.join(root, 'Movement.luau'), 'utf8'),
        fs.readFile(path.join(root, 'movement-tests.luau'), 'utf8'),
    ]);
    for (const source of [moduleSource, testSource]) {
        assert(!/[^\x00-\x7f]/.test(source), 'Luau sources must be ASCII');
        assert(!source.includes('--'), 'Luau sources must be comment-free');
    }
    const scratch = await fs.mkdtemp(path.join(temp, 'movement-tests-'));
    try {
        await directory(scratch);
        const filename = path.join(scratch, 'runner.luau');
        const source = `local moduleSource = ${literal(moduleSource)}\nlocal testSource = ${literal(testSource)}\nlocal tests = assert(loadstring(testSource, "movement-tests.luau"))()\ntests(moduleSource)\n`;
        await fs.writeFile(filename, source, { flag: 'wx' });
        const result = spawnSync(executable, [filename], {
            cwd: scratch, encoding: 'utf8', timeout: 120000, maxBuffer: 4 * 1024 * 1024,
        });
        if (result.stdout) process.stdout.write(result.stdout);
        if (result.stderr) process.stderr.write(result.stderr);
        if (result.error) throw result.error;
        assert.equal(result.status, 0, `Luau failed (${result.signal ?? result.status})`);
        assert.match(result.stdout, /Movement tests: \d+ passed, 0 failed/);
    } finally {
        await fs.rm(scratch, { recursive: true, force: true });
    }
}

try {
    await main();
} catch (error) {
    console.error(`Movement tests failed: ${error.message}`);
    process.exitCode = 1;
}
