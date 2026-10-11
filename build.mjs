import { createHash } from 'node:crypto';
import * as fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const ORIGINAL = String.raw`C:\Users\skyzl\OneDrive\Documentos\Criminality.luau`;
const FORMAT = 'luau-lexical-v1';
const GUARD = `local environment = (getgenv and getgenv()) or _G
local previousLibrary = environment.__MEOW_CRIMINALITY_LIBRARY
if previousLibrary and not previousLibrary.Unloaded then
    previousLibrary:Unload()
end`;
const OLD_LOADER = `local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(
    game:HttpGet("https://raw.githubusercontent.com/placeholder14331/dependencies/refs/heads/main/ThemeManager")
)()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()`;
const NEW_LOADER = `local WindUI = WindUIFactory()
local Library, ThemeManager, SaveManager = MeowUIFactory(WindUI, MeowConfigFactory)`;
const RUNTIME = 'local Runtime = { Threads = {} }';
const MIT_TERMS = `Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.`;
const STRING_KINDS = new Set(['quoted-string', 'long-string', 'interp-begin', 'interp-mid', 'interp-end', 'interp-simple']);
const OPERATORS = ['...', '..=', '//=', '->', '::', '//', '..', '==', '<=', '>=', '~=', '+=', '-=', '*=', '/=', '%=', '^=', '@['];

function textOf(input) {
    if (typeof input === 'string') return input;
    if (input instanceof Uint8Array) {
        return new TextDecoder('utf-8', { fatal: true, ignoreBOM: true }).decode(input);
    }
    throw new TypeError('Expected UTF-8 bytes or a string');
}

export function scan(input) {
    const source = textOf(input);
    const tokens = [];
    const comments = [];
    const braces = [];
    let cursor = 0;
    const space = ch => ch === ' ' || ch === '\t' || ch === '\v' || ch === '\f' || ch === '\r' || ch === '\n';
    const digit = ch => ch >= '0' && ch <= '9';
    const alpha = ch => (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z');
    const name = ch => alpha(ch) || digit(ch) || ch === '_';
    const fail = (message, offset = cursor) => {
        throw new Error(`${message} at character ${offset}`);
    };
    const emit = (kind, start, end = cursor) => tokens.push({ kind, start, end, value: source.slice(start, end) });
    const longDelimiter = start => {
        if (source[start] !== '[') return null;
        let end = start + 1;
        while (source[end] === '=') end++;
        return source[end] === '[' ? { end: end + 1, close: `]${source.slice(start + 1, end)}]` } : null;
    };
    const escape = () => {
        cursor++;
        if (cursor >= source.length) fail('Unterminated escape');
        if (source[cursor] === 'z') {
            cursor++;
            while (space(source[cursor])) cursor++;
        } else if (source[cursor] === '\r') {
            cursor++;
            if (source[cursor] === '\n') cursor++;
        } else {
            cursor++;
        }
    };
    const interpolation = (start, beginning) => {
        while (cursor < source.length) {
            const ch = source[cursor];
            if (ch === '`') {
                cursor++;
                emit(beginning ? 'interp-simple' : 'interp-end', start);
                return;
            }
            if (ch === '{') {
                if (source[cursor + 1] === '{') fail('Unescaped double brace in interpolated string');
                braces.push(true);
                cursor++;
                emit(beginning ? 'interp-begin' : 'interp-mid', start);
                return;
            }
            if (ch === '\\') {
                if (source[cursor + 1] === 'u' && source[cursor + 2] === '{') cursor += 3;
                else escape();
            } else {
                if (ch === '\r' || ch === '\n') fail('Unescaped newline in interpolated string');
                cursor++;
            }
        }
        fail('Unterminated interpolated string', start);
    };
    if (source.includes('\0')) fail('NUL byte is not valid Luau source', source.indexOf('\0'));
    while (cursor < source.length) {
        const ch = source[cursor];
        if (space(ch)) {
            cursor++;
            continue;
        }
        const start = cursor;
        if (source.startsWith('--', cursor)) {
            cursor += 2;
            const delimiter = longDelimiter(cursor);
            if (delimiter) {
                const end = source.indexOf(delimiter.close, delimiter.end);
                if (end < 0) fail('Unterminated block comment', start);
                cursor = end + delimiter.close.length;
            } else {
                while (cursor < source.length && source[cursor] !== '\r' && source[cursor] !== '\n') cursor++;
            }
            comments.push({ kind: delimiter ? 'block-comment' : 'line-comment', start, end: cursor, value: source.slice(start, cursor) });
            continue;
        }
        if (ch === '"' || ch === "'") {
            cursor++;
            while (cursor < source.length && source[cursor] !== ch) {
                if (source[cursor] === '\\') escape();
                else {
                    if (source[cursor] === '\r' || source[cursor] === '\n') fail('Unescaped newline in quoted string');
                    cursor++;
                }
            }
            if (cursor >= source.length) fail('Unterminated quoted string', start);
            cursor++;
            emit('quoted-string', start);
            continue;
        }
        if (ch === '[') {
            const delimiter = longDelimiter(cursor);
            if (delimiter) {
                const end = source.indexOf(delimiter.close, delimiter.end);
                if (end < 0) fail('Unterminated long string', start);
                cursor = end + delimiter.close.length;
                emit('long-string', start);
                continue;
            }
            if (source[cursor + 1] === '=') fail('Malformed long string delimiter', start);
        }
        if (ch === '`') {
            cursor++;
            interpolation(start, true);
            continue;
        }
        if (ch === '{' && braces.length) braces.push(false);
        if (ch === '}' && braces.length && braces.pop()) {
            cursor++;
            interpolation(start, false);
            continue;
        }
        if (digit(ch) || (ch === '.' && digit(source[cursor + 1]))) {
            if (ch === '.') cursor++;
            do cursor++; while (digit(source[cursor]) || source[cursor] === '.' || source[cursor] === '_');
            if (source[cursor] === 'e' || source[cursor] === 'E') {
                cursor++;
                if (source[cursor] === '+' || source[cursor] === '-') cursor++;
            }
            while (name(source[cursor])) cursor++;
            emit('number', start);
            continue;
        }
        if (alpha(ch) || ch === '_' || (ch === '@' && source[cursor + 1] !== '[')) {
            cursor++;
            if (ch !== '@' || alpha(source[cursor]) || source[cursor] === '_') {
                while (name(source[cursor])) cursor++;
            }
            emit(ch === '@' ? 'attribute' : 'name', start);
            continue;
        }
        if (ch.charCodeAt(0) >= 128) fail('Non-ASCII character outside a string or comment');
        const operator = OPERATORS.find(value => source.startsWith(value, cursor));
        cursor += operator ? operator.length : 1;
        emit('symbol', start);
    }
    if (braces.length) fail('Unterminated interpolation expression');
    return { tokens, comments };
}

export function tokenHash(input) {
    const tokens = Array.isArray(input) ? input : input?.tokens ?? scan(input).tokens;
    const hash = createHash('sha256').update(`${FORMAT}\0`);
    for (const token of tokens) {
        const bytes = Buffer.from(token.value, 'utf8');
        hash.update(`${token.kind.length}:${token.kind}:${bytes.length}:`).update(bytes);
    }
    return hash.digest('hex');
}

export function strip(input) {
    const source = textOf(input);
    const original = scan(source);
    const parts = [];
    let cursor = 0;
    for (const comment of original.comments) {
        parts.push(source.slice(cursor, comment.start), ' ', comment.value.replace(/[^\r\n]/g, ''));
        cursor = comment.end;
    }
    parts.push(source.slice(cursor));
    const result = parts.join('');
    if (tokenHash(original) !== tokenHash(result)) throw new Error('Comment removal changed lexical tokens or string bytes');
    return result;
}

function sha256(input) {
    return createHash('sha256').update(input).digest('hex');
}

function fingerprint(input) {
    const { tokens } = scan(input);
    const strings = tokens.filter(token => STRING_KINDS.has(token.kind));
    return { tokenSha256: tokenHash(tokens), stringSha256: tokenHash(strings), tokenCount: tokens.length, stringCount: strings.length };
}

function equalFingerprint(actual, expected, label) {
    for (const key of ['tokenSha256', 'stringSha256', 'tokenCount', 'stringCount']) {
        if (actual[key] !== expected?.[key]) throw new Error(`${label}: ${key} does not match the imported baseline`);
    }
}

function splitFeatures(source, imported) {
    const { tokens } = scan(source);
    let offset = 0;
    for (const [label, expected] of [['environment/unload guard', GUARD], ['loader', imported ? OLD_LOADER : NEW_LOADER], ['Runtime anchor', RUNTIME]]) {
        for (const token of scan(expected).tokens) {
            const actual = tokens[offset++];
            if (!actual || actual.kind !== token.kind || actual.value !== token.value) {
                throw new Error(`Unrecognized ${label}; refusing to alter feature code`);
            }
        }
    }
    const guardCount = scan(GUARD).tokens.length;
    const loaderCount = scan(imported ? OLD_LOADER : NEW_LOADER).tokens.length;
    return { loaderStart: tokens[guardCount].start, runtimeStart: tokens[guardCount + loaderCount].start };
}

function licensePrefix(license) {
    const normalized = license.replace(/\s+/g, ' ').trim();
    if (!normalized.startsWith('MIT License ') || !/Copyright \(c\) \d{4} \S+/.test(normalized)
        || !normalized.includes(MIT_TERMS.replace(/\s+/g, ' ').trim())) {
        throw new Error('WindUI LICENSE must contain the complete MIT notice and copyright');
    }
    let equals = '=';
    while ((license + `]${equals}]`).indexOf(`]${equals}]`) !== license.length) equals += '=';
    return `local WINDUI_LICENSE = [${equals}[${license}]${equals}]\n`;
}

function windVersion(source) {
    const versions = [];
    for (const token of scan(source).tokens) {
        if (token.kind !== 'long-string' || !token.value.includes('"windui"')) continue;
        const opening = token.value.indexOf('[', 1) + 1;
        try {
            const data = JSON.parse(token.value.slice(opening, -opening));
            if (data.name === 'windui') versions.push(data.version);
        } catch {}
    }
    if (versions.length !== 1 || versions[0] !== '1.6.66') throw new Error('Expected compiled WindUI package metadata for v1.6.66');
}

function assertCommentFree(source, label) {
    const result = scan(source);
    if (result.comments.length) throw new Error(`${label} contains ${result.comments.length} real Luau comments`);
    return result;
}

async function directory(parent) {
    const info = await fs.stat(parent);
    if (!info.isDirectory()) throw new Error(`Parent is not a directory: ${parent}`);
}

async function existing(filename) {
    try {
        return await fs.lstat(filename);
    } catch (error) {
        if (error.code === 'ENOENT') return null;
        throw error;
    }
}

async function writable(filename) {
    await directory(path.dirname(filename));
    const info = await existing(filename);
    if (info && (!info.isFile() || info.isSymbolicLink())) throw new Error(`Refusing to overwrite a non-regular file: ${filename}`);
}

async function write(filename, contents, exclusive = false) {
    await writable(filename);
    await fs.writeFile(filename, contents, { flag: exclusive ? 'wx' : 'w' });
}

function parseArgs(args) {
    const options = {};
    const names = new Set(['import', 'windui', 'license', 'baseline', 'output-copy']);
    for (let index = 0; index < args.length; index++) {
        const flag = args[index];
        if (flag === '--help' && args.length === 1) return { help: true };
        const name = flag.startsWith('--') ? flag.slice(2) : '';
        if (!names.has(name) || Object.hasOwn(options, name)) throw new Error(`Unknown or duplicate argument: ${flag}`);
        const value = args[++index];
        if (!value || value.startsWith('--')) throw new Error(`Missing path for ${flag}`);
        options[name] = value;
    }
    if (options.import && (!options.windui || !options.license || !options.baseline)) {
        throw new Error('--import requires --windui, --license, and a new --baseline directory');
    }
    if (!options.import && (options.windui || options.license)) throw new Error('--windui and --license require --import');
    if (options['output-copy']) {
        const destination = options['output-copy'] === 'original' ? ORIGINAL : options['output-copy'];
        if (!path.win32.isAbsolute(destination) || path.win32.normalize(destination).toLowerCase() !== ORIGINAL.toLowerCase()) {
            throw new Error(`--output-copy is restricted to ${ORIGINAL} (or the alias original)`);
        }
        options['output-copy'] = ORIGINAL;
    }
    return options;
}

function importedComponents(original, rawWind, license) {
    const source = textOf(original);
    const windSource = textOf(rawWind);
    const licenseText = textOf(license);
    const anchors = splitFeatures(source, true);
    windVersion(windSource);
    const features = strip(source.slice(0, anchors.loaderStart) + NEW_LOADER + '\n\n' + source.slice(anchors.runtimeStart));
    const wind = licensePrefix(licenseText) + strip(windSource);
    const featureBody = fingerprint(source.slice(anchors.runtimeStart));
    equalFingerprint(fingerprint(features.slice(splitFeatures(features, false).runtimeStart)), featureBody, 'Imported feature body');
    const manifest = {
        schemaVersion: 1,
        tokenHashFormat: FORMAT,
        windUIVersion: '1.6.66',
        original: { sha256: sha256(original), ...fingerprint(source) },
        featureBody,
        features: fingerprint(features),
        windUI: { rawSha256: sha256(rawWind), ...fingerprint(windSource) },
        license: { sha256: sha256(license) },
    };
    return { features, wind, license, manifest };
}

async function build(options) {
    await directory(ROOT);
    let components;
    const baseline = options.baseline ? path.resolve(options.baseline) : null;
    if (options.import) {
        await directory(path.dirname(baseline));
        if (await existing(baseline)) throw new Error(`Baseline already exists; it will not be overwritten: ${baseline}`);
        const [original, rawWind, license] = await Promise.all([fs.readFile(options.import), fs.readFile(options.windui), fs.readFile(options.license)]);
        components = { ...importedComponents(original, rawWind, license), original, rawWind };
    } else {
        const [features, wind, license, manifest] = await Promise.all([
            fs.readFile(path.join(ROOT, 'Features.luau')),
            fs.readFile(path.join(ROOT, 'WindUI.luau')),
            fs.readFile(path.join(ROOT, 'WINDUI-LICENSE')),
            fs.readFile(path.join(ROOT, 'tokenManifest.json')),
        ]);
        components = { features: textOf(features), wind: textOf(wind), license, manifest: JSON.parse(textOf(manifest)) };
    }
    const { features, wind, license, manifest } = components;
    if (manifest.schemaVersion !== 1 || manifest.tokenHashFormat !== FORMAT || manifest.windUIVersion !== '1.6.66') {
        throw new Error('Unrecognized token manifest');
    }
    if (!options.import && baseline) {
        const [original, rawWind, baselineLicense, baselineManifest] = await Promise.all([
            fs.readFile(path.join(baseline, 'Criminality.luau')),
            fs.readFile(path.join(baseline, 'WindUI.dist.lua')),
            fs.readFile(path.join(baseline, 'WINDUI-LICENSE')),
            fs.readFile(path.join(baseline, 'tokenManifest.json')),
        ]);
        const expected = importedComponents(original, rawWind, baselineLicense).manifest;
        if (JSON.stringify(expected) !== JSON.stringify(JSON.parse(textOf(baselineManifest))) || JSON.stringify(expected) !== JSON.stringify(manifest)) {
            throw new Error('Baseline snapshots or repository manifest have changed');
        }
    }
    const [configBytes, uiBytes] = await Promise.all([fs.readFile(path.join(ROOT, 'MeowConfig.luau')), fs.readFile(path.join(ROOT, 'MeowUI.luau'))]);
    const config = textOf(configBytes);
    const ui = textOf(uiBytes);
    const comments = {};
    for (const [label, source] of [['Features.luau', features], ['WindUI.luau', wind], ['MeowConfig.luau', config], ['MeowUI.luau', ui]]) {
        const result = assertCommentFree(source, label);
        comments[label] = result.comments.length;
        if ((label === 'MeowConfig.luau' || label === 'MeowUI.luau')
            && (result.tokens[0]?.value !== 'return' || result.tokens[1]?.value !== 'function' || result.tokens[2]?.value !== '(' || result.tokens.at(-1)?.value !== 'end')) {
            throw new Error(`${label} must return a factory function`);
        }
    }
    equalFingerprint(fingerprint(features), manifest.features, 'Features.luau');
    const featureBody = features.slice(splitFeatures(features, false).runtimeStart);
    const afterBody = fingerprint(featureBody);
    equalFingerprint(afterBody, manifest.featureBody, 'Feature body');
    if (sha256(license) !== manifest.license.sha256) throw new Error('WindUI license bytes have changed');
    const prefix = licensePrefix(textOf(license));
    if (!wind.startsWith(prefix)) throw new Error('WindUI.luau must start with the exact full MIT license string');
    const windBody = wind.slice(prefix.length);
    windVersion(windBody);
    const afterWind = fingerprint(windBody);
    equalFingerprint(afterWind, manifest.windUI, 'WindUI lexical tokens');
    const windOpening = 'local function WindUIFactory()\n';
    const configOpening = '\nend\n\nlocal MeowConfigFactory = (function()\n';
    const uiOpening = '\nend)()\n\nlocal MeowUIFactory = (function()\n';
    const featuresOpening = '\nend)()\n\n';
    const bundle = windOpening + wind + configOpening + config + uiOpening + ui + featuresOpening + features;
    comments['Criminality.luau'] = assertCommentFree(bundle, 'Criminality.luau').comments.length;
    const expectedTokens = [windOpening, wind, configOpening, config, uiOpening, ui, featuresOpening, features].flatMap(source => scan(source).tokens);
    if (tokenHash(bundle) !== tokenHash(expectedTokens)) throw new Error('Bundle boundaries changed lexical tokens or string bytes');
    const output = path.join(ROOT, 'Criminality.luau');
    const writes = options.import ? ['Features.luau', 'WindUI.luau', 'WINDUI-LICENSE', 'tokenManifest.json'].map(name => path.join(ROOT, name)) : [];
    writes.push(output);
    if (options['output-copy']) writes.push(options['output-copy']);
    for (const filename of writes) await writable(filename);
    const manifestText = JSON.stringify(manifest, null, 2) + '\n';
    if (options.import) {
        await directory(path.dirname(baseline));
        await fs.mkdir(baseline);
        for (const [name, contents] of [['Criminality.luau', components.original], ['WindUI.dist.lua', components.rawWind], ['WINDUI-LICENSE', license], ['tokenManifest.json', manifestText]]) {
            await write(path.join(baseline, name), contents, true);
        }
        for (const [name, contents] of [['Features.luau', features], ['WindUI.luau', wind], ['WINDUI-LICENSE', license], ['tokenManifest.json', manifestText]]) {
            await write(path.join(ROOT, name), contents);
        }
    }
    await write(output, bundle);
    if (options['output-copy']) await write(options['output-copy'], bundle);
    return {
        output,
        outputCopy: options['output-copy'] ?? null,
        baseline,
        featureBody: { before: manifest.featureBody, after: afterBody },
        windUI: { version: '1.6.66', before: manifest.windUI, after: afterWind },
        comments,
        bundleSha256: sha256(bundle),
        compilation: 'not performed',
        execution: 'not performed',
    };
}

if (process.argv[1] && path.resolve(process.argv[1]).toLowerCase() === fileURLToPath(import.meta.url).toLowerCase()) {
    try {
        const options = parseArgs(process.argv.slice(2));
        if (options.help) {
            console.log('Import: node build.mjs --import <original> --windui <dist/main.lua> --license <LICENSE> --baseline <new-directory> [--output-copy original]');
            console.log('Rebuild: node build.mjs [--baseline <existing-directory>] [--output-copy original]');
            console.log(`The only allowed output copy is ${ORIGINAL}. No Luau compilation or execution is performed.`);
        } else {
            console.log(JSON.stringify(await build(options), null, 2));
        }
    } catch (error) {
        console.error(`Build failed: ${error.message}`);
        process.exitCode = 1;
    }
}
