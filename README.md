# Meow for Criminality

Meow is a customized version of the original Criminality script by IchMagDichNicht.

## Run

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/superstandarts/Meow-Criminality/main/Criminality.luau"))()
```

The URL loads the version published on the `main` branch. No GitHub login is required to download the public script.

## Features

- Customizable ESP colors, opacity, text styles, health colors, and tracer lines.
- Drawing-free ESP mode with native highlights, names, and tracer lines.
- Magic Bullet with a separate toggle and keybind, sharing the Silent Aim settings.
- Optional instant delivery of the projectiles already present in a single shot.
- WalkSpeed and JumpPower controls, applied on toggle, slider changes, and respawn rather than every render frame.
- Auto Allowance with configurable ATM interaction distance.
- Cached visual updates and cleanup when unloading or rerunning Meow.
- Themes and presets stored under `Meow`.

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

Instant Pellet Delivery applies to Silent Aim / Magic Bullet. It removes Meow's artificial spacing between reports for projectiles already belonging to one shot. It does not fire a whole magazine, create extra bullets, increase weapon damage, or guarantee a kill. The normal delivery mode remains the default.

No immortality option is provided: this client script has no established server-side invulnerability or healing interface. Changing a local health display would not prove protection from damage.

## Requirements

This script requires a Roblox client environment exposing `loadstring` and the executor-specific APIs used by its features. It is not a standalone Luau program or a standard Roblox LocalScript.

The interface uses Obsidian, as in the earlier versions. Its `Library.lua`, SaveManager, and the original custom ThemeManager are downloaded at startup. The current gameplay features remain in this repository; WindUI and its adapters are no longer included.

## Validation

Validation uses Luau compilation and mock regressions for feature behavior, control ownership, movement cleanup, and delayed world containers. These tests do not verify live Obsidian rendering, Roblox behavior, executor support, server acceptance, or real FPS performance.

## Publishing Updates

Edit `Features.luau`, then run `node build.mjs` to produce `Criminality.luau`. The builder validates the Obsidian loader, rejects Luau comments, and verifies identical output bytes. Use `node build.mjs --output-copy original` to also update the local `Documentos\Criminality.luau` copy. Push the intended changes to `main` to publish them; the execution URL stays the same.

## Attribution

Original Criminality script: [IchMagDichNicht / Pastel.wtf](https://github.com/lchMagDichNicht/Pastel.wtf-Script).

Original author credit remains in the menu. The interface library is [Obsidian](https://github.com/deividcomsono/Obsidian) by deividcomsono. The custom ThemeManager is loaded from [placeholder14331/dependencies](https://github.com/placeholder14331/dependencies). Upstream dependencies retain their authorship and applicable terms; this repository does not assign a new license to their code.
