export function adminPage(nonce) {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>EndHub Key Administration</title>
<style nonce="${nonce}">
:root { color-scheme: dark; font: 16px/1.5 system-ui, sans-serif; background: #11151a; color: #e8edf2; }
* { box-sizing: border-box; }
body { margin: 0; }
main { max-width: 1050px; margin: 40px auto; padding: 0 20px; }
h1 { font-size: 1.8rem; margin-bottom: 4px; }
h2 { font-size: 1.2rem; }
p { color: #b8c4d0; }
section { background: #1a2129; border: 1px solid #35414f; border-radius: 10px; padding: 20px; margin: 20px 0; }
label { display: block; margin: 8px 0; }
input, select, textarea, button { font: inherit; border: 1px solid #566779; border-radius: 5px; padding: 9px 12px; }
input, select, textarea { background: #11151a; color: #e8edf2; max-width: 100%; }
input[type=password], textarea { width: 100%; }
textarea { min-height: 150px; }
button { background: #bddb9b; color: #14210a; cursor: pointer; margin: 8px 8px 8px 0; }
button:disabled { opacity: .5; cursor: wait; }
button.secondary { background: #263340; color: #e8edf2; }
.controls { display: flex; flex-wrap: wrap; gap: 12px; align-items: end; }
.controls label { flex: 1; min-width: 160px; }
.controls input, .controls select { width: 100%; }
.table-wrap { overflow-x: auto; }
table { width: 100%; border-collapse: collapse; font-size: .9rem; }
th, td { text-align: left; padding: 10px; border-bottom: 1px solid #35414f; white-space: nowrap; }
td:first-child { font-family: ui-monospace, monospace; }
#message { min-height: 1.5em; color: #e2d59b; }
[hidden] { display: none !important; }
@media (max-width: 600px) { main { margin-top: 20px; padding: 0 12px; } section { padding: 14px; } }
</style>
</head>
<body>
<main>
<h1>EndHub Key Administration</h1>
<p>Weekly, monthly, 60-day, and permanent keys. No accounts or third-party services.</p>
<section id="login-panel">
<h2>Administrator Login</h2>
<form id="login" autocomplete="off">
<label for="token">Administrator token</label>
<input id="token" type="password" minlength="32" maxlength="4096" autocomplete="off" required>
<button type="submit">Unlock Panel</button>
</form>
<p>The token is kept in memory only. Closing or refreshing this page clears it.</p>
</section>
<div id="panel" hidden>
<button id="logout" class="secondary" type="button">Lock Panel</button>
<section>
<h2>Generate Keys</h2>
<form id="generate">
<div class="controls">
<label>Plan <select id="plan"><option value="weekly">Weekly (7 days)</option><option value="monthly">Monthly (30 days)</option><option value="60days">60 days</option><option value="permanent">Permanent</option></select></label>
<label>Count <input id="count" type="number" min="1" max="20" step="1" value="1" required></label>
<button type="submit">Generate</button>
</div>
</form>
<div id="created-panel" hidden>
<p>Copy these keys now. Full keys cannot be retrieved again.</p>
<textarea id="created" readonly aria-label="New keys" spellcheck="false"></textarea>
<button id="copy" type="button">Copy Keys</button>
<button id="clear" type="button" class="secondary">Clear Keys</button>
</div>
</section>
<section>
<h2>Key Metadata</h2>
<button id="refresh" type="button" class="secondary">Refresh</button>
<button id="cleanup" type="button" class="secondary">Clean Expired Rate Counters</button>
<div class="table-wrap"><table><thead><tr><th>ID</th><th>Last 4</th><th>Plan</th><th>Expires (UTC)</th><th>Status</th><th>Action</th></tr></thead><tbody id="rows"></tbody></table></div>
<button id="more" type="button" class="secondary" hidden>Load More</button>
</section>
</div>
<p id="message" role="status" aria-live="polite"></p>
</main>
<script nonce="${nonce}">
const el = id => document.getElementById(id);
let token = '';
let cursor = null;
let session = 0;
let busy = false;
const say = text => { el('message').textContent = text; };
function lock() {
  session++;
  token = '';
  cursor = null;
  el('token').value = '';
  el('created').value = '';
  el('created-panel').hidden = true;
  el('rows').replaceChildren();
  el('panel').hidden = true;
  el('login-panel').hidden = false;
  el('more').hidden = true;
}
async function api(path, method = 'GET', body) {
  const current = session;
  const headers = { Authorization: 'Bearer ' + token };
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  const response = await fetch(path, { method, headers, credentials: 'omit', cache: 'no-store',
    body: body === undefined ? undefined : JSON.stringify(body) });
  if (current !== session) throw new Error('Session changed.');
  const data = await response.json();
  if (current !== session) throw new Error('Session changed.');
  if (response.status === 401) lock();
  if (!response.ok) throw new Error(data.message || 'Request failed.');
  return data;
}
async function action(task) {
  if (busy) return;
  busy = true;
  document.querySelectorAll('button:not(#logout)').forEach(button => { button.disabled = true; });
  say('Working...');
  try { await task(); } catch (error) { say(error.message || 'Request failed.'); }
  finally {
    busy = false;
    document.querySelectorAll('button').forEach(button => { button.disabled = false; });
  }
}
async function list(append = false) {
  const data = await api('/admin/keys' + (append && cursor ? '?cursor=' + encodeURIComponent(cursor) : ''));
  if (!append) el('rows').replaceChildren();
  for (const key of data.keys) {
    const row = document.createElement('tr');
    for (const value of [key.id, key.last4, key.plan, key.expiresAt || 'Never', key.status]) {
      const cell = document.createElement('td');
      cell.textContent = value;
      row.append(cell);
    }
    const cell = document.createElement('td');
    if (key.status !== 'revoked') {
      const button = document.createElement('button');
      button.type = 'button';
      button.textContent = 'Revoke';
      button.className = 'secondary';
      button.addEventListener('click', () => {
        if (!confirm('Revoke key ending in ' + key.last4 + '?')) return;
        action(async () => { await api('/admin/revoke', 'POST', { id: key.id }); await list(); say('Key revoked.'); });
      });
      cell.append(button);
    }
    row.append(cell);
    el('rows').append(row);
  }
  cursor = data.nextCursor;
  el('more').hidden = !cursor;
}
el('login').addEventListener('submit', event => {
  event.preventDefault();
  action(async () => {
    session++;
    token = el('token').value;
    el('token').value = '';
    try { await list(); } catch (error) { lock(); throw error; }
    el('login-panel').hidden = true;
    el('panel').hidden = false;
    say('Panel unlocked.');
  });
});
el('logout').addEventListener('click', () => { lock(); say('Panel locked.'); });
el('generate').addEventListener('submit', event => {
  event.preventDefault();
  action(async () => {
    el('created').value = '';
    el('created-panel').hidden = true;
    const data = await api('/admin/keys', 'POST', { plan: el('plan').value, count: Number(el('count').value) });
    el('created').value = data.keys.map(key => key.key).join('\\n');
    el('created-panel').hidden = false;
    say('Keys created. Copy them before leaving this page.');
    await list();
  });
});
el('copy').addEventListener('click', () => action(async () => {
  try { await navigator.clipboard.writeText(el('created').value); say('Keys copied.'); }
  catch { el('created').focus(); el('created').select(); say('Clipboard unavailable. The keys are selected for manual copying.'); }
}));
el('clear').addEventListener('click', () => { el('created').value = ''; el('created-panel').hidden = true; say('Keys cleared.'); });
el('refresh').addEventListener('click', () => action(async () => { await list(); say('Metadata refreshed.'); }));
el('more').addEventListener('click', () => action(async () => { await list(true); say('More metadata loaded.'); }));
el('cleanup').addEventListener('click', () => action(async () => {
  const data = await api('/admin/rate-limits', 'DELETE');
  say('Deleted ' + data.deleted + ' expired counters. Repeat if a backlog remains.');
}));
</script>
</body>
</html>`;
}
