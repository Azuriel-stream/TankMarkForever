local ADDON_NAME, TMF = ...

local L = TMF.L

local function OnOff(v)
    return v and "|cff00ff00on|r" or "|cffff6060off|r"
end

-- The mob to learn: mouseover first (the natural way in a dungeon), then the target.
local function LearnUnit()
    for _, unit in ipairs({ "mouseover", "target" }) do
        local ok, canAttack = pcall(UnitCanAttack, "player", unit)
        if UnitExists(unit) and ok and not TMF.Utils.IsSecret(canAttack) and canAttack == true then
            return TMF.Plates:Read(unit, {})
        end
    end
    return nil
end

-- Name where readable (open world), otherwise the signature (instances).
local function LearnKey(rec, zoneMobs)
    if rec.name then return zoneMobs.names, rec.name, rec.name end
    return zoneMobs.sigs, rec.sig, TMF.Planner.Describe(rec)
end

local function Learn(arg1, arg2)
    local rec = LearnUnit()
    if not rec then TMF:Print(L["LEARN_NO_UNIT"]) return end
    local entry
    local icon = tonumber(arg2)
    if arg1 == "ignore" then
        entry = { type = "IGNORE" }
    elseif arg1 == "cc" then
        entry = { type = "CC", prio = 9, icon = icon }
    elseif tonumber(arg1) and tonumber(arg1) >= 1 and tonumber(arg1) <= 9 then
        entry = { type = "KILL", prio = tonumber(arg1), icon = icon }
    else
        TMF:Print(L["LEARN_USAGE"])
        return
    end
    if entry.icon and (entry.icon < 1 or entry.icon > 8) then entry.icon = nil end
    local store, key, label = LearnKey(rec, TMF:GetZoneMobs(TMF.Plates.zone))
    store[key] = entry
    local what = entry.type == "IGNORE" and "ignore"
        or string.format("%s prio %d%s", entry.type, entry.prio, entry.icon and (" " .. TMF.Utils.IconText(entry.icon)) or "")
    TMF:Print(L["LEARN_SAVED"], label, what)
    TMF.Plates.Changed()
end

local function Forget()
    local rec = LearnUnit()
    if not rec then TMF:Print(L["LEARN_NO_UNIT"]) return end
    local store, key, label = LearnKey(rec, TMF:GetZoneMobs(TMF.Plates.zone))
    if store[key] then
        store[key] = nil
        TMF:Print(L["LEARN_FORGOT"], label)
        TMF.Plates.Changed()
    else
        TMF:Print(L["LEARN_NOT_FOUND"], label)
    end
end

local function Status()
    TMF:Print(L["STATUS_HEADER"])
    print(string.format(L["STATUS_ENABLED"], OnOff(TMF.isEnabled), OnOff(TMF:Get("overlay")), OnOff(TMF:Get("shiftSelect"))))
    local pack, skull, cycle, clear = TMF.Marker:GetKeys()
    print(string.format(L["STATUS_KEYS"], pack or L["KEY_UNBOUND"], skull or L["KEY_UNBOUND"],
        cycle or L["KEY_UNBOUND"], clear or L["KEY_UNBOUND"]))
    local zoneMobs = TMF.db.mobs[TMF.Plates.zone] or { names = {}, sigs = {} }
    local nNames, nSigs = 0, 0
    for _ in pairs(zoneMobs.names) do nNames = nNames + 1 end
    for _ in pairs(zoneMobs.sigs) do nSigs = nSigs + 1 end
    print(string.format(L["STATUS_ZONE"], TMF.Plates.zone, TMF.Plates.inInstance and "instance" or "open world",
        nNames, nSigs))
end

local function Debug()
    local db = TMF.db
    if not db._lastBlockedEvent then
        TMF:Print(L["DEBUG_NONE"])
        return
    end
    TMF:Print(L["DEBUG_LAST"], db._lastBlockedEvent, tostring(db._lastBlockedFunction))
    print(db._lastBlockedStack)
end

SLASH_TANKMARKFOREVER1 = "/tmf"
SLASH_TANKMARKFOREVER2 = "/tankmark"
SlashCmdList.TANKMARKFOREVER = function(msg)
    local cmd, arg1, arg2 = strsplit(" ", string.lower(strtrim(msg or "")))
    if cmd == "plan" then
        TMF.Planner:Report()
    elseif cmd == "select" and arg1 == "clear" then
        TMF.Plates:ClearSelection()
    elseif cmd == "learn" then
        Learn(arg1, arg2)
    elseif cmd == "forget" then
        Forget()
    elseif cmd == "overlay" then
        TMF:Set("overlay", not TMF:Get("overlay"))
        TMF.Overlay:Show(TMF.Planner.plan)
        TMF:Print("Overlay %s", OnOff(TMF:Get("overlay")))
    elseif cmd == "on" then
        TMF:Enable()
    elseif cmd == "off" then
        TMF:Disable()
    elseif cmd == "status" then
        Status()
    elseif cmd == "debug" and (arg1 == "on" or arg1 == "off") then
        TMF:Set("debug", arg1 == "on")
        if arg1 == "on" then wipe(TMF.db.debugLog) end
        TMF:Print("Debug trace %s", OnOff(TMF:Get("debug")))
    elseif cmd == "debug" then
        Debug()
    else
        for _, line in ipairs(L["HELP"]) do print(line) end
    end
end
