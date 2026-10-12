# EndHub Key Service

Standalone Cloudflare Workers + D1 service, compatible with the free tiers. No paid KV, rate-limit binding, external authentication, third-party admin resources, HWID checks, or obfuscation service. All code and UI are English. This folder does not change the main project, feature code, builder, Logo, KeyGate, or runtime.

## Local Verification

Requires Node 22.13+ with `node:sqlite` (Node 24 recommended). Tests use Node's built-in test runner and an in-memory SQLite database executing the actual migration and prepared SQL. No npm dependencies are needed for tests.

From the project root:

```powershell
node --test key-service/test/*.test.mjs
```

From `key-service/`:

```powershell
npm install
npm test
npm run dry-run
```

Wrangler is the only development dependency. A dry run bundles locally; it does not deploy or authenticate. The included `public/.gitkeep` allows bundling before the main builder stages assets. Do not deploy an empty asset directory.

On Windows PowerShell with script execution disabled, use `npm.cmd` and `npx.cmd` instead of `npm` and `npx`; no execution-policy change is needed.

## Cloudflare Setup

The service is deployed at `https://endhub-key-service.ragerdtkeys.workers.dev`. D1 is configured and migrated. Admin access is at `/admin`; the local operator file is `C:\Users\skyzl\AppData\Local\Temp\opencode\endhub-operator-secrets.json`. Use only its `ADMIN_TOKEN` in the panel. `KEY_PEPPER` is a server secret and must never be distributed to script users. The commands below are for setting up a different deployment.

Run these from `key-service/` when you choose to set up the service:

```powershell
npx.cmd wrangler d1 create endhub-keys
```

For a new account, replace the existing database ID in `wrangler.jsonc` with the new create result. Keep `binding` as `KEY_DB`.

```powershell
npx.cmd wrangler d1 migrations apply endhub-keys --remote
npx.cmd wrangler secret put ADMIN_TOKEN
npx.cmd wrangler secret put KEY_PEPPER
npm.cmd run deploy
```

Supply two different, high-entropy secrets of at least 32 characters through Wrangler's interactive secret prompts. Do not put them in source, command arguments, URLs, browser storage, or logs. Missing/short secrets or a missing D1 binding return 503 for all key/admin routes, with no bypass. Rotating `KEY_PEPPER` invalidates every existing key hash; keys cannot be rehashed because plaintext is not stored. Rotating `ADMIN_TOKEN` changes panel access without changing keys.

For local development only, provide the same two secret names in an untracked `.dev.vars` inside this folder and initialize local D1:

```powershell
npx.cmd wrangler d1 migrations apply endhub-keys --local
npm run dev
```

Local mode still requires real secrets and successful D1 checks. There is no mock activation or development bypass. Requests without Cloudflare's IP header all share the fixed `local` rate-limit bucket.

## Main Integration

The main builder owns creation of `key-service/public/logo.png` and `key-service/public/Criminality.luau`. Stage its final generated Luau bytes and logo there before deployment. The service does not regenerate, execute, modify, or fetch the main script. No placeholder Luau or fake logo is supplied.

- Logo: `GET https://<worker>/logo.png`.
- KeyGate: submit the exact key to `POST https://<worker>/v1/validate`. Accept only HTTP 200 with `valid === true`, a recognized `plan`, and an ISO expiry or `false`. Fail closed on all network, parsing, or non-200 responses. Do not pass an admin token to clients.
- Runtime content: use `POST https://<worker>/v1/script` with the same JSON key body. HTTP 200 returns the staged Luau source as text; other responses must not be executed. The server revalidates the key on every script request.
- Both public POST routes share eight attempts per Cloudflare IP per fixed UTC minute. A validate-then-script sequence consumes two attempts. Do not put the key in a URL or repeatedly poll validation.
- `assets.run_worker_first` must remain `true`. Direct requests to `/Criminality.luau` and all other unlisted asset paths return 404 without contacting ASSETS. No unauthenticated script route exists.
- No CORS is enabled. The admin page is same-origin. A browser-based client on another origin would need a separately reviewed integration; native HTTP clients are not restricted by browser CORS.

No main-project license blocking is implemented in this folder. Existing public GitHub source remains publicly downloadable. This is access control for the hosted endpoint, **not DRM**: a client can tamper with its KeyGate, share a bearer key, or redistribute downloaded source. Client-only secrets cannot make public source unbypassable. No HWID, account binding, remote obfuscation, or claim of tamper-proof licensing is included.

## API Contract

Every JSON response has `Content-Type: application/json; charset=utf-8`, `Cache-Control: no-store`, and `X-Content-Type-Options: nosniff`. Keys match exactly `END-0000-0000-0000-0000`, with 16 CSPRNG decimal digits, rejection sampling, uppercase prefix, no whitespace normalization. Finite expiry is set at creation using server time: weekly = 7 days, monthly = 30 days, `60days` = 60 days. Permanent expiry is SQL NULL. Expiry is inclusive (`now >= expiry` is invalid) and never slides on use.

### Public

`POST /v1/validate`, `Content-Type: application/json`:

```json
{"key":"END-0000-0000-0000-0000"}
```

HTTP 200 for an active finite key:

```json
{"valid":true,"expiresAt":"2026-10-19T12:00:00.000Z","plan":"weekly"}
```

HTTP 200 for an active permanent key:

```json
{"valid":true,"expiresAt":false,"plan":"permanent"}
```

HTTP 403 for a missing, incorrectly formatted, unknown, expired, or revoked key in a JSON object (same generic message for all):

```json
{"valid":false,"message":"Invalid or unavailable key."}
```

`POST /v1/script` has the same body, key checks, invalid response, and rate bucket. HTTP 200 returns `text/plain; charset=utf-8` Luau with `Cache-Control: private, no-store`. A missing staged asset returns JSON 404; service/database/binding failure returns 503. No key in ASSETS headers, body, URL, or query is forwarded.

Both POST routes return 429 after eight attempts in one UTC minute:

```json
{"valid":false,"message":"Too many attempts. Try again later."}
```

`Retry-After` is the integer seconds until the next minute, minimum 1. Malformed JSON and malformed keys consume attempts once a bounded UTF-8 JSON-media-type body is read. Invalid JSON/non-object bodies return 400. Unsupported media types return 415. Oversized bodies return 413 before any D1 access, checking declared Content-Length and actual streamed bytes (maximum 4096); neither `request.text()` nor an unbounded body buffer is used. Invalid UTF-8 returns 400 before D1. Non-POST requests return 405. 503 always means fail closed, never activation.

### Administration

`GET /admin` serves the responsive English panel without asking for a URL credential. Enter `ADMIN_TOKEN` in the password field. The page keeps it in memory only, clears the input after login, and sends `Authorization: Bearer <ADMIN_TOKEN>` in fetch headers. Lock/refresh/close clears access; Lock also clears generated keys and metadata from the UI. Keys are readonly text with Copy/Clear buttons. The panel supports plan/count selection, metadata pagination, revocation, and bounded rate-counter cleanup. No external resources, localStorage, sessionStorage, cookies, inline event handlers, or HTML injection are used. A per-response nonce authorizes only the embedded CSS/JS under a restrictive CSP.

All `/admin/*` API calls require that Bearer header. Unauthorized calls return 401 `{"message":"Unauthorized."}` before body reads or D1 access. Authentication compares all bytes of equal-length SHA-256 digests using WebCrypto, not early-return plaintext string comparison. Requests must arrive over HTTPS in production.

`POST /admin/keys`:

```json
{"plan":"weekly","count":1}
```

`plan` is exactly `weekly`, `monthly`, `60days`, or `permanent`; `count` is an integer from 1 through 20. Invalid input returns 400. HTTP 201 returns:

```json
{"keys":[{"key":"END-0000-0000-0000-0000","id":"00000000-0000-0000-0000-000000000000","last4":"0000","plan":"weekly","expiresAt":"2026-10-19T12:00:00.000Z","status":"active"}]}
```

Full plaintext keys are returned **only in this creation response**. The examples above are illustrative, not issued keys. The database stores HMAC-SHA256 hashes under the Worker-only `KEY_PEPPER`, UUID IDs, last4, plan, creation/expiry/revocation timestamps. Hash uniqueness is indexed; SQL is always prepared and bound. Creation uses transactional `INSERT OR IGNORE` batches, with a five-round collision retry budget. On exhaustion, successful keys from that request are removed and a generic 503 is returned. In an ambiguous network/database failure, unreachable hashes may need administrative revocation; no plaintext recovery endpoint exists.

`GET /admin/keys[?cursor=<last-id>]` returns at most 100 entries, ordered by ID, with metadata only:

```json
{"keys":[{"id":"00000000-0000-0000-0000-000000000000","last4":"0000","plan":"permanent","expiresAt":false,"status":"active"}],"nextCursor":null}
```

Status is `active`, `expired`, or `revoked`, computed using server time (revoked takes precedence). `nextCursor` is the last returned ID if another page exists, otherwise null. No raw key or hash is exposed by listing. Newly inserted keys can sort before a cursor; Refresh starts a new listing.

`POST /admin/revoke {"id":"<uuid>"}` returns 200 `{"revoked":true}`. Revocation is idempotent and uses the metadata ID, never a raw key. Invalid ID returns 400; unknown ID returns 404.

`DELETE /admin/rate-limits` returns 200 `{"deleted":256}` (actual number deleted, from 0 to 256). It deletes only expired counters in one indexed bounded chunk; repeat to clear a backlog. Other methods return 405 with `Allow`. Unknown routes return 404.

## Quotas And Operations

Free-tier compatibility is not unlimited availability. Cloudflare Workers, D1 reads/writes/storage, and asset quotas still apply; no paid plan is automatically required by this configuration. Each admitted body uses an atomic D1 UPSERT to track attempts, including attempts returning 429. Counters saturate at nine, share one row per HMAC-hashed IP, reset at minute boundaries, and have an indexed expiry timestamp. Every 100 public rate checks per Worker isolate schedules one cleanup chunk (maximum 256 rows); cleanup failures do not bypass authorization. Low traffic or bursts from many unique IPs can still leave a backlog. Use the authenticated cleanup endpoint as needed. This is not a global DDoS defense, and distributed IPs can consume free quotas.

There is no scheduled cron, audit logging of secrets, key logging, HWID collection, or automatically removed key history. Retain/revoke metadata deliberately; list pagination bounds response size. Worker observability is disabled in the provided config, and application code never logs requests, plaintext keys, credentials, or exception details. Do not enable third-party request-body tracing for these endpoints. An admin can create and revoke keys; protect the token like a database administrator credential. A leaked key remains usable until expiry/revocation. The service trusts Cloudflare's injected `CF-Connecting-IP` in production, never client-supplied forwarding headers; local callers can spoof that header and local mode is not a public security boundary.
