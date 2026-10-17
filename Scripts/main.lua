local Config = require("config")
local UEHelpers = require("UEHelpers")

local RETRY_MS = 3000
local HOLD_DELAY_MS = 400  -- how long an adjust key must be held before repeating
local REPEAT_MS = 120      -- time between steps while held

local function log(msg) print("[CharLight] " .. msg) end

local cfg = Config.get()

-- Applies cfg.Temperature to a light (lower Kelvin = warmer)
local function apply_temperature(l)
    local ok = pcall(function()
        l:SetUseTemperature(true)
        l:SetTemperature(cfg.Temperature)
    end)
    if not ok then
        -- Fall back to writing the properties and recreating the render proxy
        local ok2, err = pcall(function()
            l.bUseTemperature = true
            l.Temperature = cfg.Temperature
            l:SetVisibility(false, false)
            l:SetVisibility(true, false)
        end)
        if not ok2 then log("Failed to set Temperature: " .. tostring(err)) end
    end
end

-- Applies cfg.Specular (strength of this light's shiny highlights; 1 = game default)
local function apply_specular(l)
    local ok = pcall(function() l:SetSpecularScale(cfg.Specular) end)
    if not ok then
        -- Fall back to writing the property and recreating the render proxy
        local ok2, err = pcall(function()
            l.SpecularScale = cfg.Specular
            l:SetVisibility(false, false)
            l:SetVisibility(true, false)
        end)
        if not ok2 then log("Failed to set Specular: " .. tostring(err)) end
    end
end

-- The game's own ViewDirToLightDirAdjustRot per light, captured before we first
-- change it, so the angle offsets are relative to the game's look
local original_rot = {}

-- Applies cfg.AnglePitch / cfg.AngleYaw as offsets to the light's angle. The light
-- follows the camera direction; this rotates it away from the camera's view
-- (e.g. from above or from the side). Only writes when the angle needs to change.
local function apply_angle(l, name)
    local orig = original_rot[name]
    if not orig then
        local ok, rot = pcall(function()
            local r = l.ViewDirToLightDirAdjustRot
            return { Pitch = r.Pitch, Yaw = r.Yaw, Roll = r.Roll }
        end)
        if not ok then
            log("Failed to read light angle: " .. tostring(rot))
            return
        end
        orig = rot
        original_rot[name] = orig
        log(string.format("Game light angle: Pitch=%g Yaw=%g Roll=%g", orig.Pitch, orig.Yaw, orig.Roll))
    end

    local target = { Pitch = orig.Pitch + cfg.AnglePitch, Yaw = orig.Yaw + cfg.AngleYaw, Roll = orig.Roll }
    local ok, cur = pcall(function() return l.ViewDirToLightDirAdjustRot end)
    if ok and math.abs(cur.Pitch - target.Pitch) < 0.01 and math.abs(cur.Yaw - target.Yaw) < 0.01 then return end

    local ok2, err = pcall(function()
        l.ViewDirToLightDirAdjustRot = target
        -- Recreate the render proxy so the renderer sees the change
        l:SetVisibility(false, false)
        l:SetVisibility(true, false)
    end)
    if not ok2 then log("Failed to set light angle: " .. tostring(err)) end
end

-- hue in degrees, s and v in 0-1 -> r, g, b in 0-1
local function hsv_to_rgb(hue, s, v)
    local c = v * s
    local h = (hue % 360) / 60
    local x = c * (1 - math.abs(h % 2 - 1))
    local r, g, b
    if h < 1 then r, g, b = c, x, 0
    elseif h < 2 then r, g, b = x, c, 0
    elseif h < 3 then r, g, b = 0, c, x
    elseif h < 4 then r, g, b = 0, x, c
    elseif h < 5 then r, g, b = x, 0, c
    else r, g, b = c, 0, x end
    local m = v - c
    return r + m, g + m, b + m
end

-- The game's own LightColor per light, captured before we first change it, so a
-- TintStrength of 0 restores it exactly
local original_color = {}

-- Applies cfg.TintHue / cfg.TintStrength as the light's color. Strength 0 means
-- the game's own color. Only writes when the color needs to change.
local function apply_tint(l, name)
    local orig = original_color[name]
    if not orig then
        local ok, col = pcall(function()
            local c = l.LightColor
            return { R = c.R, G = c.G, B = c.B, A = c.A }
        end)
        if not ok then
            log("Failed to read light color: " .. tostring(col))
            return
        end
        orig = col
        original_color[name] = orig
        log(string.format("Game light color: R=%d G=%d B=%d", orig.R, orig.G, orig.B))
    end

    local target
    if cfg.TintStrength > 0 then
        local r, g, b = hsv_to_rgb(cfg.TintHue, cfg.TintStrength, 1)
        target = { R = math.floor(r * 255 + 0.5), G = math.floor(g * 255 + 0.5), B = math.floor(b * 255 + 0.5), A = 255 }
    else
        target = orig
    end

    local ok, cur = pcall(function() return l.LightColor end)
    if ok and cur.R == target.R and cur.G == target.G and cur.B == target.B then return end

    local ok_set = pcall(function()
        l:SetLightColor({ R = target.R / 255, G = target.G / 255, B = target.B / 255, A = 1 }, true)
    end)
    if not ok_set then
        -- Fall back to writing the property and recreating the render proxy
        local ok2, err = pcall(function()
            l.LightColor = target
            l:SetVisibility(false, false)
            l:SetVisibility(true, false)
        end)
        if not ok2 then log("Failed to set tint: " .. tostring(err)) end
    end
end

-- Sets every CharacterLight to new_intensity. on_done(found) is called with the
-- number of lights matched. quiet suppresses logging when nothing is found.
local function set_char_light(new_intensity, on_done, quiet)
    ExecuteInGameThread(function()
        local lights = FindAllOf("DirectionalLightComponent")
        if not lights then
            if not quiet then
                log("FindAllOf returned nil, no DirectionalLightComponent objects loaded")
            end
            if on_done then on_done(0) end
            return
        end

        local found = 0
        for _, l in ipairs(lights) do
            if l:IsValid() then
                local ok_n, name = pcall(function() return l:GetFullName() end)
                if ok_n and name and name:find("CharacterLight", 1, true) then
                    found = found + 1
                    local before = l.Intensity
                    if l.bSBControl then
                        -- The game's light control overrides Intensity (only 0 gets through),
                        -- so turn it off and recreate the render proxy to pick up the change
                        local ok_sb, sb_err = pcall(function()
                            l.bSBControl = false
                            l:SetVisibility(false, false)
                            l:SetVisibility(true, false)
                        end)
                        if not ok_sb then log("Failed to disable bSBControl: " .. tostring(sb_err)) end
                    end
                    apply_temperature(l)
                    apply_specular(l)
                    apply_angle(l, name)
                    apply_tint(l, name)
                    local ok, err = pcall(function() l:SetIntensity(new_intensity) end)
                    if ok then
                        local ok_r, angle = pcall(function()
                            local r = l.ViewDirToLightDirAdjustRot
                            return string.format("%g/%g", r.Pitch, r.Yaw)
                        end)
                        local ok_c, color = pcall(function()
                            local c = l.LightColor
                            return string.format("%d,%d,%d", c.R, c.G, c.B)
                        end)
                        log(string.format("[%d] %s | SetIntensity(%s) OK | before=%s after=%s | Temperature=%s Specular=%s Angle(Pitch/Yaw)=%s Color(RGB)=%s",
                            found, name, tostring(new_intensity), tostring(before), tostring(l.Intensity),
                            tostring(l.Temperature), tostring(l.SpecularScale), ok_r and angle or "?",
                            ok_c and color or "?"))
                    else
                        log(string.format("[%d] %s | SetIntensity FAILED: %s", found, name, tostring(err)))
                    end
                end
            end
        end
        if found > 0 or not quiet then
            log(string.format("Done. Scanned %d lights, matched %d.", #lights, found))
        end
        if on_done then on_done(found) end
    end)
end

-- Intensity actually sent to the light: 0 when disabled
local function target_intensity()
    return cfg.Enabled and cfg.Intensity or 0
end

-- Retry every RETRY_MS until a CharacterLight exists, then apply the saved state.
-- Starting a new run cancels any run already in progress.
local apply_gen = 0
local function apply_until_found(reason)
    apply_gen = apply_gen + 1
    local gen = apply_gen
    local attempts = 0
    log(reason .. " -> waiting for CharacterLight to apply intensity " .. target_intensity())

    local function attempt()
        if gen ~= apply_gen then return end
        attempts = attempts + 1
        set_char_light(target_intensity(), function(found)
            if gen ~= apply_gen then return end
            if found > 0 then
                log(string.format("Applied saved setting after %d attempt(s).", attempts))
            else
                ExecuteWithDelay(RETRY_MS, attempt)
            end
        end, true)
    end

    ExecuteWithDelay(RETRY_MS, attempt)
end

apply_until_found("Script loaded")

-- Level loads spawn a fresh CharacterLight at the game's default intensity
local ok_hook, hook_err = pcall(function()
    RegisterHook("/Script/Engine.PlayerController:ClientRestart", function()
        apply_until_found("ClientRestart")
    end)
end)
if not ok_hook then
    log("Failed to hook ClientRestart: " .. tostring(hook_err))
end

-- F9: switch the light on or off and save it to CharacterLight.cfg
RegisterKeyBindAsync(Key.F9, {}, function()
    cfg.Enabled = not cfg.Enabled
    log("F9 pressed -> " .. (cfg.Enabled and "on" or "off") .. ", NewIntensity = " .. target_intensity())
    set_char_light(target_intensity())
    Config.save()
end)

-- Page Up / Page Down: change brightness by Step (turns the light on).
-- Returns false when Intensity is already at its limit.
local function adjust_intensity(direction, key_name)
    local v = cfg.Intensity + direction * cfg.Step
    v = math.floor(v * 1000 + 0.5) / 1000  -- avoid float drift like 0.30000000000000004
    v = math.max(0, math.min(Config.MAX_INTENSITY, v))
    local changed = v ~= cfg.Intensity or not cfg.Enabled
    cfg.Intensity = v
    cfg.Enabled = true
    if changed then
        log(string.format("%s -> NewIntensity = %g (game default %g)",
            key_name, cfg.Intensity, Config.GAME_DEFAULT_INTENSITY))
        set_char_light(target_intensity())
    end
    return changed
end

-- [ / ]: make the light warmer or cooler by TempStep (turns the light on).
-- direction is +1 for warmer (lower Kelvin). Returns false at the limit.
local function adjust_temperature(direction, key_name)
    local v = cfg.Temperature - direction * cfg.TempStep
    v = math.max(Config.MIN_TEMPERATURE, math.min(Config.MAX_TEMPERATURE, v))
    local changed = v ~= cfg.Temperature or not cfg.Enabled
    cfg.Temperature = v
    cfg.Enabled = true
    if changed then
        log(string.format("%s -> Temperature = %gK (6500K = neutral)", key_name, cfg.Temperature))
        set_char_light(target_intensity())
    end
    return changed
end

-- ; / ': make highlights weaker or stronger by SpecularStep (turns the light on).
-- Returns false at the limit.
local function adjust_specular(direction, key_name)
    local v = cfg.Specular + direction * cfg.SpecularStep
    v = math.floor(v * 1000 + 0.5) / 1000
    v = math.max(0, math.min(Config.MAX_SPECULAR, v))
    local changed = v ~= cfg.Specular or not cfg.Enabled
    cfg.Specular = v
    cfg.Enabled = true
    if changed then
        log(string.format("%s -> Specular = %g (game default 1)", key_name, cfg.Specular))
        set_char_light(target_intensity())
    end
    return changed
end

-- Shared by the angle keys: changes cfg[field] by AngleStep within +/-limit
-- (turns the light on). Returns false at the limit.
local function adjust_angle(field, limit, direction, key_name)
    local v = cfg[field] + direction * cfg.AngleStep
    v = math.max(-limit, math.min(limit, v))
    local changed = v ~= cfg[field] or not cfg.Enabled
    cfg[field] = v
    cfg.Enabled = true
    if changed then
        log(string.format("%s -> AnglePitch = %g, AngleYaw = %g (offsets from game angle)",
            key_name, cfg.AnglePitch, cfg.AngleYaw))
        set_char_light(target_intensity())
    end
    return changed
end

-- Num 8 / Num 2: move the light up or down. Num 4 / Num 6: move it left or right.
local function adjust_pitch(direction, key_name)
    return adjust_angle("AnglePitch", Config.MAX_ANGLE_PITCH, direction, key_name)
end
local function adjust_yaw(direction, key_name)
    return adjust_angle("AngleYaw", Config.MAX_ANGLE_YAW, direction, key_name)
end

-- { / }: rotate the tint's hue around the color wheel by TintStep. If no tint is
-- set yet, starts at TintStrength 0.5 so the change is visible. Hue wraps around,
-- so this never hits a limit.
local function adjust_tint(direction, key_name)
    cfg.TintHue = (cfg.TintHue + direction * cfg.TintStep) % 360
    if cfg.TintStrength <= 0 then cfg.TintStrength = 0.5 end
    cfg.Enabled = true
    log(string.format("%s -> TintHue = %g, TintStrength = %g", key_name, cfg.TintHue, cfg.TintStrength))
    set_char_light(target_intensity())
    return true
end

local function is_key_down(key_name)
    local pc = UEHelpers.GetPlayerController()
    if not pc or not pc:IsValid() then return false end
    return pc:IsInputKeyDown({ KeyName = FName(key_name) })
end

local function shift_down()
    local ok, down = pcall(function()
        return is_key_down("LeftShift") or is_key_down("RightShift")
    end)
    return ok and down
end

-- Calls adjust(direction, key_name) once, then keeps calling it every REPEAT_MS
-- while the key is held. Saves the config once the key is released. Pressing
-- any adjust key again cancels the previous hold.
local hold_gen = 0
local function press_and_hold(adjust, direction, key_name)
    hold_gen = hold_gen + 1
    local gen = hold_gen
    adjust(direction, key_name)

    local function tick()
        if gen ~= hold_gen then return end
        ExecuteInGameThread(function()
            if gen ~= hold_gen then return end
            local ok, down = pcall(is_key_down, key_name)
            if not ok then
                log("Press-and-hold unavailable: " .. tostring(down))
                down = false
            end
            if down and adjust(direction, key_name) then
                ExecuteWithDelay(REPEAT_MS, tick)
            else
                Config.save()
            end
        end)
    end

    ExecuteWithDelay(HOLD_DELAY_MS, tick)
end
RegisterKeyBindAsync(Key.PAGE_UP, {}, function() press_and_hold(adjust_intensity, 1, "PageUp") end)
RegisterKeyBindAsync(Key.PAGE_DOWN, {}, function() press_and_hold(adjust_intensity, -1, "PageDown") end)
-- [ / ] adjust temperature; with Shift held they are { / } and adjust tint instead.
-- The Shift check stops a { press from also changing temperature.
local function bracket_key(adjust, direction, key_name)
    ExecuteInGameThread(function()
        if not shift_down() then press_and_hold(adjust, direction, key_name) end
    end)
end
RegisterKeyBindAsync(Key.OEM_FOUR, {}, function() bracket_key(adjust_temperature, 1, "LeftBracket") end)
RegisterKeyBindAsync(Key.OEM_SIX, {}, function() bracket_key(adjust_temperature, -1, "RightBracket") end)
RegisterKeyBindAsync(Key.OEM_FOUR, {ModifierKey.SHIFT}, function() press_and_hold(adjust_tint, -1, "LeftBracket") end)
RegisterKeyBindAsync(Key.OEM_SIX, {ModifierKey.SHIFT}, function() press_and_hold(adjust_tint, 1, "RightBracket") end)
RegisterKeyBindAsync(Key.OEM_ONE, {}, function() press_and_hold(adjust_specular, -1, "Semicolon") end)
RegisterKeyBindAsync(Key.OEM_SEVEN, {}, function() press_and_hold(adjust_specular, 1, "Apostrophe") end)

RegisterKeyBindAsync(Key.NUM_EIGHT, {}, function() press_and_hold(adjust_pitch, 1, "NumPadEight") end)
RegisterKeyBindAsync(Key.NUM_TWO, {}, function() press_and_hold(adjust_pitch, -1, "NumPadTwo") end)
RegisterKeyBindAsync(Key.NUM_FOUR, {}, function() press_and_hold(adjust_yaw, -1, "NumPadFour") end)
RegisterKeyBindAsync(Key.NUM_SIX, {}, function() press_and_hold(adjust_yaw, 1, "NumPadSix") end)

-- Num 5: reset the light angle to the game's own and save it
RegisterKeyBindAsync(Key.NUM_FIVE, {}, function()
    cfg.AnglePitch, cfg.AngleYaw = 0, 0
    log("NumPad5 pressed -> light angle reset to game default")
    set_char_light(target_intensity())
    Config.save()
end)

-- F10: reload CharacterLight.cfg and apply it
RegisterKeyBindAsync(Key.F10, {}, function()
    cfg = Config.reload()
    log("F10 pressed -> config reloaded, NewIntensity = " .. target_intensity())
    set_char_light(target_intensity())
end)

log("Script loaded. F9 = on/off, PageUp/PageDown = brightness, [ / ] = warmer/cooler, { / } = tint hue,; / ' = less/more shine, Num8/Num2/Num4/Num6 = light angle, Num5 = reset angle, F10 = reload config.")
