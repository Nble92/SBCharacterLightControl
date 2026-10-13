local Config = require("config")

local RETRY_MS = 3000

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

local char_light = Config.get().CharacterLight

-- Retry every RETRY_MS until a CharacterLight exists, then apply the saved state.
-- Starting a new run cancels any run already in progress.
local apply_gen = 0
local function apply_until_found(reason)
    apply_gen = apply_gen + 1
    local gen = apply_gen
    local attempts = 0
    log(reason .. " -> waiting for CharacterLight to apply CharacterLight=" .. char_light)

    local function attempt()
        if gen ~= apply_gen then return end
        attempts = attempts + 1
        set_char_light(char_light, function(found)
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

-- F9: toggle between 0 and 1 and save it to CharacterLight.cfg
RegisterKeyBindAsync(Key.F9, {}, function()
    char_light = (char_light == 1) and 0 or 1
    log("F9 pressed -> NewIntensity = " .. char_light)
    set_char_light(char_light)
    Config.save(char_light)
end)

-- F10: reload CharacterLight.cfg and apply it
RegisterKeyBindAsync(Key.F10, {}, function()
    char_light = Config.reload().CharacterLight
    log("F10 pressed -> config reloaded, NewIntensity = " .. char_light)
    set_char_light(char_light)
end)

log("Script loaded. F9 = toggle, F10 = reload config.")
