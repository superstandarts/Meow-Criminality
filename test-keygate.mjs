import assert from 'node:assert/strict';
import * as fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { scan } from './build.mjs';

const root = path.dirname(fileURLToPath(import.meta.url));
const temp = process.platform === 'win32' ? path.join(process.env.LOCALAPPDATA, 'Temp', 'opencode') : os.tmpdir();

function literal(source) {
    let equals = '';
    while (source.includes(`]${equals}]`)) equals += '=';
    return `[${equals}[${source}]${equals}]`;
}

async function main() {
    assert(process.argv.length === 2, 'Usage: node test-keygate.mjs (optional LUAU_BIN environment variable)');
    for (const directory of [root, temp]) assert((await fs.stat(directory)).isDirectory());
    let executable = process.env.LUAU_BIN;
    if (!executable && process.platform === 'win32') {
        for (const name of (await fs.readdir(temp)).filter(name => name.startsWith('luau-')).sort()) {
            const candidate = path.join(temp, name, 'luau.exe');
            try {
                if ((await fs.stat(candidate)).isFile()) { executable = candidate; break; }
            } catch (error) {
                if (error.code !== 'ENOENT') throw error;
            }
        }
    }
    executable ??= 'luau';
    const [moduleSource, testSource, features] = await Promise.all([
        fs.readFile(path.join(root, 'KeyGate.luau'), 'utf8'),
        fs.readFile(path.join(root, 'keygate-tests.luau'), 'utf8'),
        fs.readFile(path.join(root, 'Features.luau'), 'utf8'),
    ]);
    for (const source of [moduleSource, testSource]) {
        assert(!/[^\x00-\x7f]/.test(source), 'Luau sources must be ASCII');
        assert.equal(scan(source).comments.length, 0, 'Luau sources must be comment-free');
    }
    assert.match(features, /^if not EndHubKeyGate\.Authorize\(\) then return end/);
    assert(features.indexOf('EndHubKeyGate.Authorize()') < features.indexOf('previousLibrary:Unload()'));
    assert(features.indexOf('EndHubKeyGate.Authorize()') < features.indexOf('loadstring('));
    assert.match(features, /Icon = EndHubKeyGate\.Logo\(\)/);
    assert.match(features, /task\.wait\(300\)[\s\S]*EndHubKeyGate\.Validate\(\)/);
    const scratch = await fs.mkdtemp(path.join(temp, 'keygate-tests-'));
    try {
        assert((await fs.stat(scratch)).isDirectory());
        const filename = path.join(scratch, 'runner.luau');
        const source = `local moduleSource = ${literal(moduleSource)}\nlocal tests = assert(loadstring(${literal(testSource)}, "keygate-tests.luau"))()\ntests(moduleSource)\n`;
        await fs.writeFile(filename, source, { flag: 'wx' });
        const result = spawnSync(executable, [filename], { cwd: scratch, encoding: 'utf8', timeout: 120000, maxBuffer: 4 * 1024 * 1024 });
        if (result.stdout) process.stdout.write(result.stdout);
        if (result.stderr) process.stderr.write(result.stderr);
        if (result.error) throw result.error;
        assert.equal(result.status, 0, `Luau failed (${result.signal ?? result.status})`);
        assert.match(result.stdout, /KeyGate tests: \d+ passed, 0 failed/);
    } finally {
        await fs.rm(scratch, { recursive: true, force: true });
    }
}

try {
    await main();
} catch (error) {
    console.error(`KeyGate tests failed: ${error.message}`);
    process.exitCode = 1;
}
