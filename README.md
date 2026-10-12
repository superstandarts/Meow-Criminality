# EndHub for Criminality

EndHub is a customized version of the original Criminality script by IchMagDichNicht. The menu footer is **Powered by EndHub**.

## Key Service Setup

The script requires an online key check before loading feature dependencies. The service is deployed at `https://endhub-key-service.ragerdtkeys.workers.dev`; the configured URL is in `endhub.config.json`. There is no development bypass.

The Worker and D1 service target Cloudflare's free quotas. It supports **Weekly (7 days)**, **Monthly (30 days)**, **60 days**, and **Permanent** keys in `END-0000-0000-0000-0000` format. Expiry starts at generation time; permanent keys are still revocable. The admin panel and client messages are English. Only key hashes are stored; the full key is returned once when generated.

From `key-service`, authenticate with `npx.cmd wrangler login`, create `endhub-keys`, put the returned D1 ID in `wrangler.jsonc`, apply migrations, set separate `ADMIN_TOKEN` and `KEY_PEPPER` secrets, and deploy. See [key-service/README.md](key-service/README.md) for the exact commands. Never commit these secrets or send them in chat.

Put the resulting HTTPS Worker origin in `endhub.config.json`, rebuild with `node build.mjs`, then deploy again to update the staged script. Generate/revoke keys at `<worker-origin>/admin`. A running client revalidates every five minutes and unloads if validation fails.

The builder stages the supplied `Downloads/endhubbbb.png` as `key-service/public/logo.png`. The menu downloads that PNG into `EndHub/logo.png` and uses `getcustomasset`/`getsynasset`; executors without the required asset/filesystem APIs show a shield fallback. No Roblox asset ID is invented.

The hosted `/v1/script` endpoint requires a valid key. The GitHub source remains public and client code can be modified: this is access control for the hosted endpoint, **not tamper-proof DRM**.

## Run

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/superstandarts/Meow-Criminality/main/Criminality.luau"))()
```

The existing repository URL is retained rather than renaming the GitHub repository without permission. It loads the published version, not uncommitted local changes. The new local build also enforces the configured key service.

## Features

- Customizable ESP colors, opacity, text styles, health colors, and tracer lines.
- Drawing-free ESP mode with native highlights, names, and tracer lines.
- Magic Bullet with a separate toggle and keybind, sharing the Silent Aim settings.
- Optional instant delivery of the projectiles already present in a single shot.
- Independent WalkSpeed and JumpPower handlers, with coalesced slider updates, current/live Humanoid checks, and ownership-aware cleanup. Speed is capped at 80 and jump power at 120; invalid saved values are bounded.
- No Ragdoll (Humanoid): local `Ragdoll`/`FallingDown` state suppression, restored on disable, respawn, and unload. This does not disable custom constraints or server injury logic.
- Free Cam under **Visuals > Camera**: WASD movement, Q/E down/up, right-mouse look, Shift boost, configurable speed/sensitivity and a toggle keybind. It suppresses avatar movement inputs without changing character speed or position, and restores owned camera/input settings on disable/unload. Aimbot and spectate camera writes pause while Free Cam is enabled.
- Auto Allowance with configurable ATM interaction distance.
- Cached visual updates and cleanup when unloading or rerunning EndHub.
- Themes and presets stored under `EndHub`; old preset files are not deleted. Autoload is now an explicit Settings action, not a startup side effect.

The Obsidian menu key is `RightControl` by default. The window can be resized, and its search is enabled. The menu uses a high display order above game UI.

## Menu Layout

- **Home:** profile and session information.
- **Combat:** Weapons, Aim, Melee, Shot Assist, and melee Targets.
- **ESP:** Players and World controls, with separate Boxes/Chams, Text, Health, and Lines panels. All player and world ESP settings are here.
- **Visuals:** crosshair, weapon appearance, camera FOV, and lighting.
- **Automation:** loot/crates, doors, interactions, and lockpicking.
- **Player:** movement, stamina, and spectate.
- **Settings:** menu, themes, presets, and performance.

Magic Bullet and Instant Pellet Delivery are under **Combat > Shot Assist**. Existing option IDs are unchanged, so saved feature settings continue to use the same keys.

## Combat Limits

Hit redirection still depends on server validation; it does not animate curved bullets.

Instant Pellet Delivery applies to Silent Aim / Magic Bullet. It removes EndHub's artificial spacing between reports for projectiles already belonging to one shot. It does not fire a whole magazine, create extra bullets, increase weapon damage, or guarantee a kill. The normal delivery mode remains the default.

No immortality option is provided: this client script has no established server-side invulnerability or healing interface. Changing a local health display would not prove protection from damage.

**No Fall Damage remains disabled:** no verified Criminality fall-damage interface was found. Local Humanoid state changes do not prevent server-authoritative damage. Neither this control nor No Ragdoll is advertised as a guaranteed game-specific bypass.

## Requirements

This script requires a Roblox client environment exposing `loadstring` and the executor-specific APIs used by its features. It is not a standalone Luau program or a standard Roblox LocalScript.

The interface uses Obsidian, as in the earlier versions. Its `Library.lua`, SaveManager, and the original custom ThemeManager are downloaded at startup. The current gameplay features remain in this repository; WindUI and its adapters are no longer included.

## Validation

Validation uses Luau compilation and mock regressions for feature behavior, control ownership, movement cleanup, and delayed world containers. These tests do not verify live Obsidian rendering, Roblox behavior, executor support, server acceptance, or real FPS performance.

Run `node test-movement.mjs`, `node test-keygate.mjs`, `node test-freecam.mjs`, and `node --test "key-service/test/*.test.mjs"`. These changes reduce avoidable writes; mocked movement and camera tests cannot prove that a native Roblox/executor crash is resolved without a live test.

## Publishing Updates

Edit `Features.luau`, `Movement.luau`, or `KeyGate.luau`, then run `node build.mjs` to produce the gated `Criminality.luau` and stage Worker assets. The builder validates the entry gate and Obsidian loader, rejects Luau comments, and verifies output bytes. Use `node build.mjs --output-copy original` to also update the local `Documentos\Criminality.luau` copy. Publishing still requires an explicit push/deploy; the existing GitHub URL stays the same.

## Attribution

Original Criminality script: [IchMagDichNicht / Pastel.wtf](https://github.com/lchMagDichNicht/Pastel.wtf-Script).

Original author credit remains in the menu. The interface library is [Obsidian](https://github.com/deividcomsono/Obsidian) by deividcomsono. The custom ThemeManager is loaded from [placeholder14331/dependencies](https://github.com/placeholder14331/dependencies). Upstream dependencies retain their authorship and applicable terms; this repository does not assign a new license to their code.
