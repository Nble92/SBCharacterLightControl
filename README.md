# Character Light Control

A [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) Lua mod for **Stellar Blade** that turns the game's character light on or off. This is the directional light that lights the player character separately from the rest of the scene.

**Download:** [Nexus Mods](https://www.nexusmods.com/stellarblade/mods/3972)

## Features

- Applies your saved setting automatically once you're in-game, and again after every level load
- **F9** switches the light on or off in-game and saves your choice
- **F10** reloads the config file and applies it, so you can make changes without restarting

## Requirements

- Stellar Blade (PC)
- UE4SS installed in `SB/Binaries/Win64/ue4ss`

## Installation

1. Copy the `CharacterLightControl` folder into:
   ```
   SB/Binaries/Win64/ue4ss/Mods/
   ```
2. Make sure the folder has an `enabled.txt` file in it. UE4SS uses this file to load the mod.

The folder must be named exactly `CharacterLightControl` because the mod looks for its config file at that path.

The finished layout looks like this:

```
ue4ss/Mods/CharacterLightControl/
├── enabled.txt
├── CharacterLight.cfg
└── Scripts/
    ├── main.lua
    └── config.lua
```

## Configuration

Edit `CharacterLight.cfg`:

```
CharacterLight=0
```

| Value | Effect |
|-------|--------|
| `0`   | Character light off (default) |
| `1`   | Character light on |

Any other value is ignored and the mod falls back to `0`. If you edit the file while the game is running, press **F10** to apply the change.

## Controls

| Key | Action |
|-----|--------|
| F9  | Switch the light on or off and save the choice to `CharacterLight.cfg` |
| F10 | Reload `CharacterLight.cfg` and apply it |

## Troubleshooting

The mod writes log lines prefixed with `[CharLight]` to the UE4SS console and to `UE4SS.log`.

- **`Config not found ... using defaults`**: the folder isn't named `CharacterLightControl`, or `CharacterLight.cfg` is missing.
- **`Failed to save config`**: the mod couldn't write `CharacterLight.cfg`. Check that the file isn't read-only.
- **`waiting for CharacterLight` with no `Applied saved setting` after it**: the mod is still waiting for the light to load. This is normal on menus and loading screens. It applies the setting as soon as the light appears.
- **`matched 0`** after F9 or F10: no character light is loaded yet. Try again once you're in-game.

## How it works

The mod finds every `DirectionalLightComponent` whose full name contains `CharacterLight` and calls `SetIntensity()` on it with the configured value.

At startup, and after each `PlayerController:ClientRestart` (level load), it checks every 3 seconds until a character light exists, then applies the setting once.
