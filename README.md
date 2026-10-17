# Character Light Control

A [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) Lua mod for **Stellar Blade** that turns the game's character light on or off and lets you set its brightness, warmth, color tint, highlight strength and angle. This is the directional light that lights the player character separately from the rest of the scene.

**Download:** [Nexus Mods](https://www.nexusmods.com/stellarblade/mods/3972)

## Features

- Applies your saved setting automatically once you're in-game, and again after every level load
- **F9** switches the light on or off in-game and saves your choice
- **Page Up / Page Down** make the light brighter or dimmer (hold to keep changing it) and save the new level
- **[ / ]** make the light warmer or cooler (hold to keep changing it) and save the new color
- **{ / }** tint the light any color by turning around the color wheel (hold to keep changing it)
- **; / '** make the light's shiny highlights weaker or stronger (hold to keep changing them)
- **Numpad 8 / 2 / 4 / 6** move the light up, down, left or right around Eve, and **Numpad 5** resets it
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
Temperature=6500
TempStep=250
Specular=1
SpecularStep=0.1
AnglePitch=0
AngleYaw=0
AngleStep=5
TintHue=0
TintStrength=0
TintStep=15
```

| Setting     | Values         | Effect |
|-------------|----------------|--------|
| `Enabled`   | `0` or `1`     | `0` turns the character light off (default), `1` turns it on |
| `Intensity` | `0` to `10`    | Brightness while the light is on. The game's own default is `0.5` |
| `Step`      | `0.01` to `10` | How much each Page Up / Page Down step changes `Intensity` (default `0.5`) |
| `Temperature` | `1700` to `12000` | Color temperature in Kelvin. `6500` is neutral white (default), lower is warmer (`4000` warm, `2700` candle-like), higher is cooler |
| `TempStep`  | `1` to `12000` | How much each `[` / `]` step changes `Temperature` (default `250`) |
| `Specular`  | `0` to `5`     | Strength of the shiny highlights this light creates on skin, hair and the suit. `1` is the game's default, `0` removes them |
| `SpecularStep` | `0.01` to `5` | How much each `;` / `'` step changes `Specular` (default `0.1`) |
| `AnglePitch` | `-89` to `89` | Degrees to move the light up (positive) or down (negative) from the game's angle. `0` is the game's default |
| `AngleYaw`  | `-180` to `180` | Degrees to move the light right (positive) or left (negative) from the game's angle. `0` is the game's default |
| `AngleStep` | `0.1` to `90`  | How many degrees each numpad step moves the light (default `5`) |
| `TintHue`   | `0` to `360`   | Tint color as a position on the color wheel: `0` red, `30` orange, `60` yellow, `120` green, `180` cyan, `240` blue, `300` pink |
| `TintStrength` | `0` to `1`  | How strong the tint is. `0` keeps the game's own color (default), `1` is fully saturated. The first `{` / `}` press sets it to `0.5` if it's `0` |
| `TintStep`  | `1` to `180`   | How many degrees each `{` / `}` step turns the hue (default `15`) |

Invalid values are ignored and the default is used instead. If you edit the file while the game is running, press **F10** to apply the change.

Config files from older versions (`CharacterLight=0` or `CharacterLight=1`) are still read and are converted to the new format the next time the mod saves.

## Controls

| Key       | Action |
|-----------|--------|
| F9        | Switch the light on or off and save the choice |
| Page Up   | Increase brightness by `Step` (turns the light on). Hold to keep increasing |
| Page Down | Decrease brightness by `Step` (turns the light on). Hold to keep decreasing |
| `[`       | Make the light warmer by `TempStep` (turns the light on). Hold to keep changing |
| `]`       | Make the light cooler by `TempStep` (turns the light on). Hold to keep changing |
| `;`       | Weaker highlights by `SpecularStep` (turns the light on). Hold to keep changing |
| `'`       | Stronger highlights by `SpecularStep` (turns the light on). Hold to keep changing |
| `{`       | Turn the tint hue back by `TintStep` (turns the light on). Hold to keep changing |
| `}`       | Turn the tint hue forward by `TintStep` (turns the light on). Hold to keep changing |
| Numpad 8 / 2 | Move the light up / down by `AngleStep` (turns the light on). Hold to keep moving |
| Numpad 4 / 6 | Move the light left / right by `AngleStep` (turns the light on). Hold to keep moving |
| Numpad 5  | Reset the light angle to the game's default |
| F10       | Reload `CharacterLight.cfg` and apply it |

## Troubleshooting

The mod writes log lines prefixed with `[CharLight]` to the UE4SS console and to `UE4SS.log`.

- **`Config not found ... using defaults`**: the folder isn't named `CharacterLightControl`, or `CharacterLight.cfg` is missing.
- **`Failed to save config`**: the mod couldn't write `CharacterLight.cfg`. Check that the file isn't read-only.
- **`waiting for CharacterLight` with no `Applied saved setting` after it**: the mod is still waiting for the light to load. This is normal on menus and loading screens. It applies the setting as soon as the light appears.
- **`matched 0`** after a key press: no character light is loaded yet. Try again once you're in-game.
- **`Press-and-hold unavailable`**: the game didn't report whether Page Up / Page Down is held, so each press changes brightness by one step only.
- **`Failed to set Temperature`**: the color change couldn't be applied. Brightness still works.
- **`Failed to set Specular`**: the highlight change couldn't be applied. Brightness and color still work.
- **`Failed to set tint`** or **`Failed to set light angle`**: that change couldn't be applied. The other settings still work.
- **`Failed to disable bSBControl`**: the game's lighting system is still controlling the light, so brightness changes may not show. Please report this along with your `UE4SS.log`.

## How it works

The mod finds every `DirectionalLightComponent` whose full name contains `CharacterLight` and calls `SetIntensity()` on it with `Intensity` when the light is enabled, or `0` when it is disabled. It also sets the light's color temperature with `SetTemperature()`, its tint with `SetLightColor()`, and its highlight strength with `SetSpecularScale()`.

The character light always points along the camera's view. The game offsets that direction with `ViewDirToLightDirAdjustRot`; the mod adds `AnglePitch` and `AngleYaw` to the game's own offset, so the light keeps following the camera but hits Eve from the angle you choose. The game's original angle and color are remembered, so setting the offsets or `TintStrength` back to `0` restores them exactly.

The game normally drives this light through its own lighting system (`bSBControl`), which ignores the `Intensity` value except for `0`. The mod turns `bSBControl` off on the character light so the brightness you set takes effect.

At startup, and after each `PlayerController:ClientRestart` (level load), it checks every 3 seconds until a character light exists, then applies the setting once.
