local ADDON_NAME, TMF = ...

_G["TankMarkForever"] = TMF

TMF.name = ADDON_NAME
TMF.version = "0.1.0"
TMF.modules = {}
TMF.moduleOrder = {}
TMF.isInitialized = false
TMF.isEnabled = false

local eventFrame = CreateFrame("Frame", "TMF_EventFrame")

-- Security Action Interceptor: records blocked/forbidden actions for /tmf debug
local securityFrame = CreateFrame("Frame", "TMF_SecurityFrame")
pcall(securityFrame.RegisterEvent, securityFrame, "ADDON_ACTION_BLOCKED")
pcall(securityFrame.RegisterEvent, securityFrame, "ADDON_ACTION_FORBIDDEN")
securityFrame:SetScript("OnEvent", function(self, event, addonName, functionName)
    if addonName ~= ADDON_NAME then return end
    local stack = (debugstack and debugstack(2, 8, 8)) or "No stack available"
    if TankMarkForeverDB then
        TankMarkForeverDB._lastBlockedEvent = event
        TankMarkForeverDB._lastBlockedFunction = functionName
        TankMarkForeverDB._lastBlockedStack = stack
    end
end)

function TMF:Print(msg, ...)
    if select("#", ...) > 0 then
        msg = string.format(msg, ...)
    end
    print("|cffFFD100[TankMark]|r " .. tostring(msg))
end

-- Debug trace: printed and kept in TankMarkForeverDB.debugLog (read it from SavedVariables after a /reload).
local DEBUG_LOG_MAX = 400
function TMF:Debug(msg, ...)
    if not (TMF.db and TMF.db.debug) then return end
    if select("#", ...) > 0 then
        msg = string.format(msg, ...)
    end
    print("|cff888888[TMF]|r " .. msg)
    local log = TMF.db.debugLog
    table.insert(log, date("%H:%M:%S") .. (InCombatLockdown() and " [combat] " or " ") .. msg)
    while #log > DEBUG_LOG_MAX do table.remove(log, 1) end
end

-- Internal messages between modules (e.g. Plates -> Planner -> Marker/Overlay)
local listeners = {}
function TMF:On(message, fn)
    listeners[message] = listeners[message] or {}
    table.insert(listeners[message], fn)
end

function TMF:Fire(message, ...)
    for _, fn in ipairs(listeners[message] or {}) do
        local ok, err = pcall(fn, ...)
        if not ok then
            TMF:Print("|cffFF4444Error in %s handler:|r %s", message, tostring(err))
        end
    end
end

-- Module Registration (initialized/enabled in registration order)
function TMF:RegisterModule(name)
    local module = { name = name }
    TMF.modules[name] = module
    TMF[name] = module
    table.insert(TMF.moduleOrder, name)
    return module
end

local function CallModules(method)
    for _, name in ipairs(TMF.moduleOrder) do
        local mod = TMF.modules[name]
        if type(mod[method]) == "function" then
            local ok, err = pcall(mod[method], mod)
            if not ok then
                TMF:Print("|cffFF4444Error in %s:%s:|r %s", name, method, tostring(err))
            end
        end
    end
end

-- Lifecycle Management
function TMF:Enable()
    if TMF.isEnabled then return end
    TMF.isEnabled = true
    TMF.db.enabled = true
    CallModules("OnEnable")
    TMF:Print(TMF.L["ADDON_ENABLED"])
end

function TMF:Disable()
    if not TMF.isEnabled then return end
    TMF.isEnabled = false
    TMF.db.enabled = false
    CallModules("OnDisable")
    TMF:Print(TMF.L["ADDON_DISABLED"])
end

local function OnEvent(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        if not TMF.isInitialized then
            TMF.isInitialized = true
            TMF:InitConfig()
            CallModules("OnInitialize")
        end
        eventFrame:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        eventFrame:UnregisterEvent("PLAYER_LOGIN")
        if TMF.db.enabled then
            TMF.isEnabled = true
            CallModules("OnEnable")
        end
        TMF:Print(TMF.L["ADDON_LOADED"], TMF.version)
    end
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", OnEvent)
