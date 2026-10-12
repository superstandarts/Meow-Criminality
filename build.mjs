import { createHash } from 'node:crypto';
import * as fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const ORIGINAL = String.raw`C:\Users\skyzl\OneDrive\Documentos\Criminality.luau`;
const FORMAT = 'luau-lexical-v1';
const KEY_GUARD = 'if not EndHubKeyGate.Authorize() then return end';
const GUARD = `local environment = (getgenv and getgenv()) or _G
local previousLibrary = environment.__ENDHUB_CRIMINALITY_LIBRARY or environment.__MEOW_CRIMINALITY_LIBRARY
if previousLibrary and not previousLibrary.Unloaded then
    previousLibrary:Unload()
end
environment.__MEOW_CRIMINALITY_LIBRARY = nil`;
const LOADER = `local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(
    game:HttpGet("https://raw.githubusercontent.com/placeholder14331/dependencies/refs/heads/main/ThemeManager")
)()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()`;
const RUNTIME = 'local Runtime = { Threads = {} }';
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

function splitFeatures(source) {
    const { tokens } = scan(source);
    let offset = 0;
    for (const [label, expected] of [['key gate', KEY_GUARD], ['environment/unload guard', GUARD], ['Obsidian loader', LOADER], ['Runtime anchor', RUNTIME]]) {
        for (const token of scan(expected).tokens) {
            const actual = tokens[offset++];
            if (!actual || actual.kind !== token.kind || actual.value !== token.value) {
                throw new Error(`Unrecognized ${label}; refusing to alter feature code`);
            }
        }
    }
    const guardCount = scan(KEY_GUARD).tokens.length + scan(GUARD).tokens.length;
    const loaderCount = scan(LOADER).tokens.length;
    return { loaderStart: tokens[guardCount].start, runtimeStart: tokens[guardCount + loaderCount].start };
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

async function write(filename, contents) {
    await writable(filename);
    await fs.writeFile(filename, contents);
}

function parseArgs(args) {
    const options = {};
    const names = new Set(['output-copy']);
    for (let index = 0; index < args.length; index++) {
        const flag = args[index];
        if (flag === '--help' && args.length === 1) return { help: true };
        const name = flag.startsWith('--') ? flag.slice(2) : '';
        if (!names.has(name) || Object.hasOwn(options, name)) throw new Error(`Unknown or duplicate argument: ${flag}`);
        const value = args[++index];
        if (!value || value.startsWith('--')) throw new Error(`Missing path for ${flag}`);
        options[name] = value;
    }
    if (options['output-copy']) {
        const destination = options['output-copy'] === 'original' ? ORIGINAL : options['output-copy'];
        if (!path.win32.isAbsolute(destination) || path.win32.normalize(destination).toLowerCase() !== ORIGINAL.toLowerCase()) {
            throw new Error(`--output-copy is restricted to ${ORIGINAL} (or the alias original)`);
        }
        options['output-copy'] = ORIGINAL;
    }
    return options;
}

async function build(options) {
    await directory(ROOT);
    const features = await fs.readFile(path.join(ROOT, 'Features.luau'));
    const source = textOf(features);
    const result = assertCommentFree(source, 'Features.luau');
    const featureBody = source.slice(splitFeatures(source).runtimeStart);
    const config = JSON.parse(await fs.readFile(path.join(ROOT, 'endhub.config.json'), 'utf8'));
    const serviceUrl = config.keyServiceUrl;
    if (typeof serviceUrl !== 'string' || (serviceUrl && !/^https:\/\/[a-zA-Z0-9.-]+\/?$/.test(serviceUrl))) {
        throw new Error('keyServiceUrl must be an HTTPS origin or empty while deployment is pending');
    }
    const modules = await Promise.all(['KeyGate', 'Movement', 'FreeCam'].map(async name => {
        const body = await fs.readFile(path.join(ROOT, `${name}.luau`), 'utf8');
        assertCommentFree(body, `${name}.luau`);
        return `local EndHub${name} = (function()\n${body}\nend)()\n`;
    }));
    const bundle = Buffer.from(`local ENDHUB_SERVICE_URL = ${JSON.stringify(serviceUrl)}\n${modules.join('\n')}\n${source}`, 'utf8');
    assertCommentFree(bundle, 'Criminality.luau');
    const output = path.join(ROOT, 'Criminality.luau');
    const writes = [output];
    if (options['output-copy']) writes.push(options['output-copy']);
    for (const filename of writes) await writable(filename);
    for (const filename of writes) {
        await write(filename, bundle);
        if (!bundle.equals(await fs.readFile(filename))) throw new Error(`Output bytes differ: ${filename}`);
    }
    const publicRoot = path.join(ROOT, 'key-service', 'public');
    await directory(publicRoot);
    const logoPath = path.join(publicRoot, 'logo.png');
    const logoSource = String.raw`C:\Users\skyzl\Downloads\endhubbbb.png`;
    const logo = await fs.readFile(logoSource).catch(async error => {
        if (error.code !== 'ENOENT') throw error;
        return fs.readFile(logoPath);
    });
    if (!logo.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))) throw new Error('EndHub logo must be a PNG');
    await write(logoPath, logo);
    await write(path.join(publicRoot, 'Criminality.luau'), bundle);
    return {
        output,
        outputCopy: options['output-copy'] ?? null,
        uiLibrary: 'Obsidian',
        features: fingerprint(source),
        featureBody: fingerprint(featureBody),
        comments: { 'Features.luau': result.comments.length, 'Criminality.luau': result.comments.length },
        bundleSha256: sha256(bundle),
        keyServiceConfigured: serviceUrl !== '',
        compilation: 'not performed',
        execution: 'not performed',
    };
}

if (process.argv[1] && path.resolve(process.argv[1]).toLowerCase() === fileURLToPath(import.meta.url).toLowerCase()) {
    try {
        const options = parseArgs(process.argv.slice(2));
        if (options.help) {
            console.log('Build: node build.mjs [--output-copy original]');
            console.log(`The only allowed output copy is ${ORIGINAL}. No Luau compilation or execution is performed.`);
        } else {
            console.log(JSON.stringify(await build(options), null, 2));
        }
    } catch (error) {
        console.error(`Build failed: ${error.message}`);
        process.exitCode = 1;
    }
}
