local ADDON_NAME, TMF = ...

-- The learned-mob database: per zone, entries by name (open world) or by signature (instances, where names are
-- secret). entry = { type = "KILL"|"CC"|"IGNORE", prio = 1-9, icon = 1-8 or nil, class = CC class or nil,
-- note = player-given label for a signature }
local MobDB = TMF:RegisterModule("MobDB")
local L, Rules = TMF.L, TMF.Rules

MobDB.TYPES = { "KILL", "CC", "IGNORE" }
MobDB.CC_CLASSES = { "MAGE", "ROGUE", "WARLOCK", "HUNTER", "PRIEST", "DRUID", "SHAMAN" }

local function NextIn(list, current)
    for i, v in ipairs(list) do
        if v == current then return list[i + 1] end
    end
    return list[1]
end

-- "14|elite|MANA" -> level, tier, power
function MobDB.ParseSig(sig)
    local level, tier, power = string.match(sig or "", "^([^|]*)|([^|]*)|([^|]*)$")
    return tonumber(level), tier, power
end

-- Readable label for a signature: "lvl 14 elite caster"
function MobDB.DescribeSig(sig)
    local level, tier, power = MobDB.ParseSig(sig)
    local role = L["ROLE_" .. Rules.RoleFromPower(power)]
    local lvl = (not level or level == -1) and "??" or tostring(level)
    return string.format("lvl %s %s %s", lvl, tier or "?", role)
end

-- Zones that have entries, sorted, plus `include` (the current zone) even if empty.
function MobDB:Zones(include)
    local list, seen = {}, {}
    for zone, data in pairs(TMF.db.mobs) do
        if next(data.names) or next(data.sigs) then
            table.insert(list, zone)
            seen[zone] = true
        end
    end
    if include and include ~= "" and not seen[include] then table.insert(list, include) end
    table.sort(list)
    return list
end

-- Entries of a zone as rows { kind = "name"|"sig", key, entry, label }: names A-Z, then signatures by level (high first).
function MobDB:Entries(zone)
    local data = TMF.db.mobs[zone]
    local rows = {}
    if not data then return rows end
    for name, entry in pairs(data.names) do
        table.insert(rows, { kind = "name", key = name, entry = entry, label = name })
    end
    for sig, entry in pairs(data.sigs) do
        table.insert(rows, { kind = "sig", key = sig, entry = entry, label = entry.note or MobDB.DescribeSig(sig) })
    end
    table.sort(rows, function(a, b)
        if a.kind ~= b.kind then return a.kind == "name" end
        if a.kind == "name" then return a.key < b.key end
        local la, lb = MobDB.ParseSig(a.key), MobDB.ParseSig(b.key)
        if (la or 0) ~= (lb or 0) then return (la or 0) > (lb or 0) end
        return a.key < b.key
    end)
    return rows
end

local function Changed()
    TMF:Fire("MOBDB_CHANGED")
    if TMF.Plates then TMF.Plates.Changed() end
end

-- Learn a unit: by name where readable, by signature otherwise. Default priority from the rules (power x tier).
-- Returns the stored entry and a label, or nil if the unit isn't an attackable mob.
function MobDB:Learn(unit, entry)
    local ok, canAttack = pcall(UnitCanAttack, "player", unit)
    if not UnitExists(unit) or not ok or TMF.Utils.IsSecret(canAttack) or canAttack ~= true then return nil end
    local rec = TMF.Plates:Read(unit, {})
    local zone = TMF:GetZoneMobs(TMF.Plates.zone)
    if not entry then
        entry = { type = "KILL", prio = Rules.RoleTierPrio(Rules.RoleFromPower(rec.power), rec.tier) }
    end
    local label
    if rec.name then
        zone.names[rec.name] = entry
        label = rec.name
    else
        zone.sigs[rec.sig] = entry
        label = MobDB.DescribeSig(rec.sig)
    end
    Changed()
    return entry, label, rec
end

-- Forget the entry a unit would match. Returns its label or nil.
function MobDB:ForgetUnit(unit)
    if not UnitExists(unit) then return nil end
    local rec = TMF.Plates:Read(unit, {})
    local zone = TMF:GetZoneMobs(TMF.Plates.zone)
    if rec.name and zone.names[rec.name] then
        zone.names[rec.name] = nil
        Changed()
        return rec.name
    elseif not rec.name and zone.sigs[rec.sig] then
        zone.sigs[rec.sig] = nil
        Changed()
        return MobDB.DescribeSig(rec.sig)
    end
    return nil
end

-- =========================================================================
-- Editing one entry (mob database window)
-- =========================================================================
function MobDB:CycleType(entry)
    entry.type = NextIn(MobDB.TYPES, entry.type) or "KILL"
    if entry.type ~= "IGNORE" and not entry.prio then entry.prio = 5 end
    Changed()
end

function MobDB:StepPrio(entry, delta)
    entry.prio = math.max(1, math.min(9, (tonumber(entry.prio) or 5) + delta))
    Changed()
end

-- auto -> 8 (skull) -> 7 ... -> 1 -> auto
function MobDB:CycleIcon(entry)
    if not entry.icon then entry.icon = 8
    elseif entry.icon <= 1 then entry.icon = nil
    else entry.icon = entry.icon - 1 end
    Changed()
end

function MobDB:ClearIcon(entry)
    entry.icon = nil
    Changed()
end

-- any -> MAGE -> ... -> SHAMAN -> any
function MobDB:CycleClass(entry)
    if not entry.class then entry.class = MobDB.CC_CLASSES[1]
    else entry.class = NextIn(MobDB.CC_CLASSES, entry.class) end
    Changed()
end

function MobDB:SetNote(entry, note)
    note = note and strtrim(note) or ""
    entry.note = note ~= "" and note or nil
    Changed()
end

function MobDB:Delete(zone, kind, key)
    local data = TMF.db.mobs[zone]
    if not data then return end
    if kind == "name" then data.names[key] = nil else data.sigs[key] = nil end
    Changed()
end

-- The label shown in plans and overlays for a plate record: its name, the player's note on its signature, or the
-- generic description.
function MobDB:Label(rec, zone)
    if rec.name then return rec.name end
    local data = TMF.db and TMF.db.mobs[zone or TMF.Plates.zone]
    local entry = data and data.sigs[rec.sig]
    return (entry and entry.note) or MobDB.DescribeSig(rec.sig)
end
