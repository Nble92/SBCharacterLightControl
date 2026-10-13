-- config.lua — file-based config (reads CharacterLight.cfg)
local M = {}

local DEFAULTS = {
    path = "ue4ss/Mods/CharacterLightControl/CharacterLight.cfg",
    CharacterLight = 0,   -- 0 = off, 1 = on (this is the NewIntensity value)
}

local function load_file(path, into)
    local f = io.open(path, "r")
    if not f then
        print("[CharLight] Config not found at " .. path .. ", using defaults")
        return into
    end
    for line in f:lines() do
        local key, value = line:match("^%s*(%w+)%s*=%s*(.-)%s*$")
        if key == "CharacterLight" then
            local n = tonumber(value)
            if n == 0 or n == 1 then
                into.CharacterLight = n
            else
                print("[CharLight] Ignoring invalid CharacterLight value: " .. tostring(value))
            end
        end
    end
    f:close()
    return into
end

local CURRENT = nil

function M.get()
    if not CURRENT then
        local c = { path = DEFAULTS.path, CharacterLight = DEFAULTS.CharacterLight }
        CURRENT = load_file(c.path, c)
        print("[CharLight] Config loaded: CharacterLight=" .. tostring(CURRENT.CharacterLight))
    end
    return CURRENT
end

function M.reload()
    CURRENT = nil
    return M.get()
end

function M.save(value)
    local c = M.get()
    local f, err = io.open(c.path, "w")
    if not f then
        print("[CharLight] Failed to save config to " .. c.path .. ": " .. tostring(err))
        return false
    end
    f:write("CharacterLight=" .. tostring(value) .. "\n")
    f:close()
    c.CharacterLight = value
    print("[CharLight] Config saved: CharacterLight=" .. tostring(value))
    return true
end

return M