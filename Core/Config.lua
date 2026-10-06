local ADDON_NAME, TMF = ...

TMF.DefaultConfig = {
    enabled = true,
    overlay = true,         -- planned icons above nameplates
    shiftSelect = true,     -- Shift-hover adds a mob to the pack selection (out of combat)

    -- Kill ladder until team profiles exist (milestone 3): kill order -> icon.
    ladder = { 8, 7, 6, 5, 4, 3, 2, 1 },

    -- Learned mobs, per zone. Names only work where they're readable (the open world); inside instances the
    -- client hides them, so mobs are learned by signature (level, classification, power type). See DESIGN.md.
    -- entry = { prio = 1-9, type = "KILL"|"CC"|"IGNORE", icon = 1-8 (optional fixed icon), role = optional }
    mobs = {},              -- [zone] = { names = { [name] = entry }, sigs = { [signature] = entry } }

    debug = false,          -- /tmf debug on: trace key presses and plate changes (also saved in debugLog)
    debugLog = {},
}

-- Deep Copy Table Helper
local function CopyTable(src)
    if type(src) ~= "table" then return src end
    local copy = {}
    for k, v in pairs(src) do
        copy[k] = type(v) == "table" and CopyTable(v) or v
    end
    return copy
end
TMF.CopyTable = CopyTable

-- Merge Defaults recursively without overwriting existing user values
local function MergeDefaults(target, source)
    for k, v in pairs(source) do
        if target[k] == nil then
            target[k] = type(v) == "table" and CopyTable(v) or v
        elseif type(target[k]) == "table" and type(v) == "table" then
            MergeDefaults(target[k], v)
        end
    end
end

function TMF:InitConfig()
    if type(TankMarkForeverDB) ~= "table" then
        TankMarkForeverDB = CopyTable(TMF.DefaultConfig)
    else
        MergeDefaults(TankMarkForeverDB, TMF.DefaultConfig)
    end
    TMF.db = TankMarkForeverDB
end

function TMF:Get(key)
    if TMF.db and TMF.db[key] ~= nil then
        return TMF.db[key]
    end
    return TMF.DefaultConfig[key]
end

function TMF:Set(key, value)
    if TMF.db then
        TMF.db[key] = value
    end
end

-- Learned mobs for one zone (created on demand).
function TMF:GetZoneMobs(zone)
    local all = TMF.db.mobs
    if not all[zone] then
        all[zone] = { names = {}, sigs = {} }
    end
    return all[zone]
end
