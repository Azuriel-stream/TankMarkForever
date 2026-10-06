local ADDON_NAME, TMF = ...

local L = TMF.L

local function OnOff(v)
    return v and "|cff00ff00on|r" or "|cffff6060off|r"
end

-- The mob to learn: mouseover first (out of combat, deliberate), then the target.
local LEARN_UNITS = { "mouseover", "target" }

local function Learn(arg1, arg2)
    local entry
    local icon = tonumber(arg2)
    local class = not icon and arg2 and TMF.Team.CC_SPELL[string.upper(arg2)] and string.upper(arg2) or nil
    if arg1 == "ignore" then
        entry = { type = "IGNORE" }
    elseif arg1 == "cc" then
        entry = { type = "CC", prio = 9, icon = icon, class = class }
    elseif tonumber(arg1) and tonumber(arg1) >= 1 and tonumber(arg1) <= 9 then
        entry = { type = "KILL", prio = tonumber(arg1), icon = icon }
    else
        TMF:Print(L["LEARN_USAGE"])
        return
    end
    if entry.icon and (entry.icon < 1 or entry.icon > 8) then entry.icon = nil end
    for _, unit in ipairs(LEARN_UNITS) do
        local saved, label = TMF.MobDB:Learn(unit, entry)
        if saved then
            local what = saved.type == "IGNORE" and "ignore"
                or string.format("%s prio %d%s%s", saved.type, saved.prio,
                    saved.icon and (" " .. TMF.Utils.IconText(saved.icon)) or "", saved.class and (" " .. saved.class) or "")
            TMF:Print(L["LEARN_SAVED"], label, what)
            return
        end
    end
    TMF:Print(L["LEARN_NO_UNIT"])
end

local function Forget()
    for _, unit in ipairs(LEARN_UNITS) do
        if UnitExists(unit) then
            local label = TMF.MobDB:ForgetUnit(unit)
            if label then TMF:Print(L["LEARN_FORGOT"], label) else TMF:Print(L["LEARN_NOT_FOUND"], unit) end
            return
        end
    end
    TMF:Print(L["LEARN_NO_UNIT"])
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
    local id = TMF.Plates.instanceID
    print(string.format(L["STATUS_INSTANCE"], tostring(id),
        (id and TMF.InstanceMobs[id]) and L["STATUS_DATA_YES"] or L["STATUS_DATA_NO"]))
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
    if cmd == "" or cmd == "setup" then
        TMF.Setup:Toggle()
    elseif cmd == "mobs" then
        TMF.MobsUI:Toggle()
    elseif cmd == "announce" then
        TMF.Team:Announce()
    elseif cmd == "plan" then
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
