-- config.lua — file-based config (reads CharacterLight.cfg)
local M = {}

local PATH = "ue4ss/Mods/CharacterLightControl/CharacterLight.cfg"

M.MAX_INTENSITY = 10
M.GAME_DEFAULT_INTENSITY = 0.5
M.MIN_TEMPERATURE = 1700
M.MAX_TEMPERATURE = 12000
M.MAX_SPECULAR = 5
M.MAX_ANGLE_PITCH = 89
M.MAX_ANGLE_YAW = 180

local DEFAULTS = {
    Enabled = false,  -- false = light off (intensity 0), true = light at Intensity
    Intensity = 0.5,  -- brightness used while enabled (game default is 0.5)
    Step = 0.5,       -- how much Page Up / Page Down change Intensity
    Temperature = 6500,  -- color temperature in Kelvin: lower = warmer, 6500 = neutral white
    TempStep = 250,      -- how much [ / ] change Temperature
    Specular = 1,        -- strength of this light's shiny highlights (game default 1, 0 = none)
    SpecularStep = 0.1,  -- how much ; / ' change Specular
    AnglePitch = 0,      -- degrees to move the light up/down from the game's angle (0 = game default)
    AngleYaw = 0,        -- degrees to move the light left/right from the game's angle (0 = game default)
    AngleStep = 5,       -- how much the numpad keys change the angle
    TintHue = 0,         -- tint color on the color wheel in degrees (0 red, 120 green, 240 blue)
    TintStrength = 0,    -- how strong the tint is, 0-1 (0 = the game's own color)
    TintStep = 15,       -- how much { / } change TintHue
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
        elseif key == "Temperature" then
            into.Temperature = parse_number(key, value, M.MIN_TEMPERATURE, M.MAX_TEMPERATURE) or into.Temperature
        elseif key == "TempStep" then
            into.TempStep = parse_number(key, value, 1, M.MAX_TEMPERATURE) or into.TempStep
        elseif key == "Specular" then
            into.Specular = parse_number(key, value, 0, M.MAX_SPECULAR) or into.Specular
        elseif key == "SpecularStep" then
            into.SpecularStep = parse_number(key, value, 0.01, M.MAX_SPECULAR) or into.SpecularStep
        elseif key == "AnglePitch" then
            into.AnglePitch = parse_number(key, value, -M.MAX_ANGLE_PITCH, M.MAX_ANGLE_PITCH) or into.AnglePitch
        elseif key == "AngleYaw" then
            into.AngleYaw = parse_number(key, value, -M.MAX_ANGLE_YAW, M.MAX_ANGLE_YAW) or into.AngleYaw
        elseif key == "AngleStep" then
            into.AngleStep = parse_number(key, value, 0.1, 90) or into.AngleStep
        elseif key == "TintHue" then
            into.TintHue = parse_number(key, value, 0, 360) or into.TintHue
        elseif key == "TintStrength" then
            into.TintStrength = parse_number(key, value, 0, 1) or into.TintStrength
        elseif key == "TintStep" then
            into.TintStep = parse_number(key, value, 1, 180) or into.TintStep
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
    return string.format("Enabled=%d Intensity=%g Step=%g Temperature=%g TempStep=%g Specular=%g SpecularStep=%g AnglePitch=%g AngleYaw=%g AngleStep=%g TintHue=%g TintStrength=%g TintStep=%g",
        c.Enabled and 1 or 0, c.Intensity, c.Step, c.Temperature, c.TempStep,
        c.Specular, c.SpecularStep, c.AnglePitch, c.AngleYaw, c.AngleStep,
        c.TintHue, c.TintStrength, c.TintStep)
end

function M.get()
    if not CURRENT then
        local c = {}
        for k, v in pairs(DEFAULTS) do c[k] = v end
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
    f:write(string.format("Temperature=%g\n", c.Temperature))
    f:write(string.format("TempStep=%g\n", c.TempStep))
    f:write(string.format("Specular=%g\n", c.Specular))
    f:write(string.format("SpecularStep=%g\n", c.SpecularStep))
    f:write(string.format("AnglePitch=%g\n", c.AnglePitch))
    f:write(string.format("AngleYaw=%g\n", c.AngleYaw))
    f:write(string.format("AngleStep=%g\n", c.AngleStep))
    f:write(string.format("TintHue=%g\n", c.TintHue))
    f:write(string.format("TintStrength=%g\n", c.TintStrength))
    f:write(string.format("TintStep=%g\n", c.TintStep))
    f:close()
    print("[CharLight] Config saved: " .. describe(c))
    return true
end

return M
