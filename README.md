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
- Cached visual updates and cleanup when unloading or rerunning Meow.
- Themes and presets stored under `Meow`.

The menu key is `RightControl` by default. The window can be resized, and its search is enabled.

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

This script requires a Roblox client environment exposing `loadstring`, `game:HttpGet`, and the executor-specific APIs used by its features. It is not a standalone Luau program or a standard Roblox LocalScript.

The UI and configuration managers are downloaded from these upstream dependencies at startup:

- [Obsidian](https://github.com/deividcomsono/Obsidian)
- [ThemeManager](https://github.com/placeholder14331/dependencies)

## Validation

The published build passed Luau compilation and 497 deterministic mock regression tests, including category/control ownership and instant-projectile delivery. These tests do not verify live Roblox behavior, executor support, server acceptance, or real FPS performance.

## Publishing Updates

Update `Criminality.luau` in this repository and push the intended changes to `main`. Editing a separate local copy does not automatically update GitHub. The execution URL stays the same after new versions are published.

## Attribution

Original Criminality script: [IchMagDichNicht / Pastel.wtf](https://github.com/lchMagDichNicht/Pastel.wtf-Script).

Original author credit remains in the menu. Upstream dependencies retain their authorship and applicable terms; this repository does not assign a new license to their code.
