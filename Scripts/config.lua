-- config.lua — file-based config (reads CharacterLight.cfg)
local M = {}

local PATH = "ue4ss/Mods/CharacterLightControl/CharacterLight.cfg"

M.MAX_INTENSITY = 10
M.GAME_DEFAULT_INTENSITY = 0.5

local DEFAULTS = {
    Enabled = false,  -- false = light off (intensity 0), true = light at Intensity
    Intensity = 0.5,  -- brightness used while enabled (game default is 0.5)
    Step = 0.5,       -- how much Page Up / Page Down change Intensity
}

local function parse_number(key, value, min, max)
    local n = tonumber(value)
    if n and n >= min and n <= max then return n end
    print(string.format("[CharLight] Ignoring invalid %s value: %s (allowed %s-%s)",
        key, tostring(value), tostring(min), tostring(max)))
    return nil
end

local function load_file(path, into)
    local f = io.open(path, "r")
    if not f then
        print("[CharLight] Config not found at " .. path .. ", using defaults")
        return into
    end
    local legacy = nil
    local has_enabled = false
    for line in f:lines() do
        local key, value = line:match("^%s*(%w+)%s*=%s*(.-)%s*$")
        if key == "Enabled" then
            if value == "0" or value == "1" then
                into.Enabled = (value == "1")
                has_enabled = true
            else
                print("[CharLight] Ignoring invalid Enabled value: " .. tostring(value))
            end
        elseif key == "Intensity" then
            into.Intensity = parse_number(key, value, 0, M.MAX_INTENSITY) or into.Intensity
        elseif key == "Step" then
            into.Step = parse_number(key, value, 0.01, M.MAX_INTENSITY) or into.Step
        elseif key == "CharacterLight" then
            -- Old format: CharacterLight=0/1 was the raw intensity
            legacy = tonumber(value)
        end
    end
    f:close()
    if legacy and not has_enabled then
        into.Enabled = legacy > 0
        if legacy > 0 and legacy <= M.MAX_INTENSITY then into.Intensity = legacy end
        print("[CharLight] Migrated old CharacterLight=" .. tostring(legacy) .. " setting")
    end
    return into
end

local CURRENT = nil

local function describe(c)
    return string.format("Enabled=%d Intensity=%g Step=%g", c.Enabled and 1 or 0, c.Intensity, c.Step)
end

function M.get()
    if not CURRENT then
        local c = { Enabled = DEFAULTS.Enabled, Intensity = DEFAULTS.Intensity, Step = DEFAULTS.Step }
        CURRENT = load_file(PATH, c)
        print("[CharLight] Config loaded: " .. describe(CURRENT))
    end
    return CURRENT
end

function M.reload()
    CURRENT = nil
    return M.get()
end

-- Writes the current in-memory config to disk
function M.save()
    local c = M.get()
    local f, err = io.open(PATH, "w")
    if not f then
        print("[CharLight] Failed to save config to " .. PATH .. ": " .. tostring(err))
        return false
    end
    f:write("Enabled=" .. (c.Enabled and 1 or 0) .. "\n")
    f:write(string.format("Intensity=%g\n", c.Intensity))
    f:write(string.format("Step=%g\n", c.Step))
    f:close()
    print("[CharLight] Config saved: " .. describe(c))
    return true
end

return M
