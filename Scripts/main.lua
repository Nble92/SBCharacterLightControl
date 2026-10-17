local Config = require("config")
local UEHelpers = require("UEHelpers")

local RETRY_MS = 3000
local HOLD_DELAY_MS = 400  -- how long Page Up / Page Down must be held before repeating
local REPEAT_MS = 120      -- time between steps while held

local function log(msg) print("[CharLight] " .. msg) end

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
                    local ok, err = pcall(function() l:SetIntensity(new_intensity) end)
                    if ok then
                        log(string.format("[%d] %s | SetIntensity(%s) OK | before=%s after=%s",
                            found, name, tostring(new_intensity), tostring(before), tostring(l.Intensity)))
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

local cfg = Config.get()

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
local function adjust(direction, key_name)
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

local function is_key_down(key_name)
    local pc = UEHelpers.GetPlayerController()
    if not pc or not pc:IsValid() then return false end
    return pc:IsInputKeyDown({ KeyName = FName(key_name) })
end

-- Steps once, then keeps stepping every REPEAT_MS while the key is held.
-- Saves the config once the key is released. Pressing either key again
-- cancels the previous hold.
local hold_gen = 0
local function press_and_hold(direction, key_name)
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
RegisterKeyBindAsync(Key.PAGE_UP, {}, function() press_and_hold(1, "PageUp") end)
RegisterKeyBindAsync(Key.PAGE_DOWN, {}, function() press_and_hold(-1, "PageDown") end)

-- F10: reload CharacterLight.cfg and apply it
RegisterKeyBindAsync(Key.F10, {}, function()
    cfg = Config.reload()
    log("F10 pressed -> config reloaded, NewIntensity = " .. target_intensity())
    set_char_light(target_intensity())
end)

log("Script loaded. F9 = on/off, PageUp/PageDown (hold to repeat) = brightness, F10 = reload config.")
