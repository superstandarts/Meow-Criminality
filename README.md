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
- Cached visual updates and cleanup when unloading or rerunning Meow.
- Themes and presets stored under `Meow`.

The menu key is `RightControl` by default. Magic Bullet is under the Aimbot tab, in the Silent Aim group. Hit redirection still depends on server validation; it does not animate curved bullets.

## Requirements

This script requires a Roblox client environment exposing `loadstring`, `game:HttpGet`, and the executor-specific APIs used by its features. It is not a standalone Luau program or a standard Roblox LocalScript.

The UI and configuration managers are downloaded from these upstream dependencies at startup:

- [Obsidian](https://github.com/deividcomsono/Obsidian)
- [ThemeManager](https://github.com/placeholder14331/dependencies)

## Validation

The published build passed Luau compilation and 299 deterministic mock regression tests. These tests do not verify live Roblox behavior, executor support, server acceptance, or real FPS performance.

## Publishing Updates

Update `Criminality.luau` in this repository and push the intended changes to `main`. Editing a separate local copy does not automatically update GitHub. The execution URL stays the same after new versions are published.

## Attribution

Original Criminality script: [IchMagDichNicht / Pastel.wtf](https://github.com/lchMagDichNicht/Pastel.wtf-Script).

Original author credit remains in the menu. Upstream dependencies retain their authorship and applicable terms; this repository does not assign a new license to their code.
