local Config = require("config")

local function log(msg) print("[CharLight] " .. msg) end

local function set_char_light(new_intensity)
    ExecuteInGameThread(function()
        local lights = FindAllOf("DirectionalLightComponent")
        if not lights then
            log("FindAllOf returned nil, no DirectionalLightComponent objects loaded")
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
        log(string.format("Done. Scanned %d lights, matched %d.", #lights, found))
    end)
end

local char_light = Config.get().CharacterLight

-- Apply the saved state a few seconds after the script loads
ExecuteWithDelay(5000, function() set_char_light(char_light) end)

-- F9: toggle between 0 and 1
RegisterKeyBindAsync(Key.F9, {}, function()
    char_light = (char_light == 1) and 0 or 1
    log("F9 pressed -> NewIntensity = " .. char_light)
    set_char_light(char_light)
end)

-- F10: reload CharacterLight.cfg and apply it
RegisterKeyBindAsync(Key.F10, {}, function()
    char_light = Config.reload().CharacterLight
    log("F10 pressed -> config reloaded, NewIntensity = " .. char_light)
    set_char_light(char_light)
end)

log("Script loaded. F9 = toggle, F10 = reload config.")