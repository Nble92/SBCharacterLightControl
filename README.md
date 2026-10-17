# Character Light Control

A [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) Lua mod for **Stellar Blade** that turns the game's character light on or off and lets you set how bright it is. This is the directional light that lights the player character separately from the rest of the scene.

**Download:** [Nexus Mods](https://www.nexusmods.com/stellarblade/mods/3972)

## Features

- Applies your saved setting automatically once you're in-game, and again after every level load
- **F9** switches the light on or off in-game and saves your choice
- **Page Up / Page Down** make the light brighter or dimmer (hold to keep changing it) and save the new level
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
Enabled=0
Intensity=0.5
Step=0.5
```

| Setting     | Values         | Effect |
|-------------|----------------|--------|
| `Enabled`   | `0` or `1`     | `0` turns the character light off (default), `1` turns it on |
| `Intensity` | `0` to `10`    | Brightness while the light is on. The game's own default is `0.5` |
| `Step`      | `0.01` to `10` | How much each Page Up / Page Down step changes `Intensity` (default `0.5`) |

Invalid values are ignored and the default is used instead. If you edit the file while the game is running, press **F10** to apply the change.

Config files from older versions (`CharacterLight=0` or `CharacterLight=1`) are still read and are converted to the new format the next time the mod saves.

## Controls

| Key       | Action |
|-----------|--------|
| F9        | Switch the light on or off and save the choice |
| Page Up   | Increase brightness by `Step` (turns the light on). Hold to keep increasing |
| Page Down | Decrease brightness by `Step` (turns the light on). Hold to keep decreasing |
| F10       | Reload `CharacterLight.cfg` and apply it |

## Troubleshooting

The mod writes log lines prefixed with `[CharLight]` to the UE4SS console and to `UE4SS.log`.

- **`Config not found ... using defaults`**: the folder isn't named `CharacterLightControl`, or `CharacterLight.cfg` is missing.
- **`Failed to save config`**: the mod couldn't write `CharacterLight.cfg`. Check that the file isn't read-only.
- **`waiting for CharacterLight` with no `Applied saved setting` after it**: the mod is still waiting for the light to load. This is normal on menus and loading screens. It applies the setting as soon as the light appears.
- **`matched 0`** after a key press: no character light is loaded yet. Try again once you're in-game.
- **`Press-and-hold unavailable`**: the game didn't report whether Page Up / Page Down is held, so each press changes brightness by one step only.
- **`Failed to disable bSBControl`**: the game's lighting system is still controlling the light, so brightness changes may not show. Please report this along with your `UE4SS.log`.

## How it works

The mod finds every `DirectionalLightComponent` whose full name contains `CharacterLight` and calls `SetIntensity()` on it with `Intensity` when the light is enabled, or `0` when it is disabled.

The game normally drives this light through its own lighting system (`bSBControl`), which ignores the `Intensity` value except for `0`. The mod turns `bSBControl` off on the character light so the brightness you set takes effect.

At startup, and after each `PlayerController:ClientRestart` (level load), it checks every 3 seconds until a character light exists, then applies the setting once.
