local ADDON_NAME, TMF = ...

-- Tracks hostile nameplates and what can be read about each mob. A nameplateN token stays bound to its mob while
-- the plate is shown, so a record read out of combat stays valid in combat until NAME_PLATE_UNIT_REMOVED.
local Plates = TMF:RegisterModule("Plates")
local Utils, Rules = TMF.Utils, TMF.Rules

Plates.records = {}    -- [token] = record (see Read)
Plates.selected = {}   -- [token] = true: Shift-hover pack selection
Plates.zone = ""
Plates.inInstance = false

local seq = 0
local changePending = false

-- Debounced: many plates arrive at once when you walk up to a pack.
local function Changed()
    if changePending then return end
    changePending = true
    C_Timer.After(0.1, function()
        changePending = false
        TMF:Fire("PLATES_CHANGED")
    end)
end
Plates.Changed = Changed

local function NpcID(guid)
    if not guid then return nil end
    local _, _, _, _, _, id = strsplit("-", guid)
    return tonumber(id)
end

-- Everything readable about a plate. In instances name/guid/creature type are secret (nil here);
-- level, classification, power type and the boss flags stay readable (kb/addons/TankMark.md, run 4).
function Plates:Read(token, rec)
    rec = rec or {}
    if not rec.seq then
        seq = seq + 1
        rec.seq = seq
    end
    rec.token = token
    rec.name = Utils.Safe(UnitName(token), "string", nil)
    local okG, guid = pcall(UnitGUID, token)
    rec.npcID = okG and NpcID(Utils.Safe(guid, "string", nil)) or nil
    rec.level = Utils.Safe(UnitLevel(token), "number", -1)
    rec.tier = Utils.Safe(UnitClassification(token), "string", "normal")
    if Utils.Flag(UnitIsBossMob, token) then rec.tier = "boss" end
    local okP, _, powerToken = pcall(UnitPowerType, token)
    rec.power = okP and Utils.Safe(powerToken, "string", nil) or nil
    local okT, ctype = pcall(UnitCreatureType, token)
    rec.ctype = okT and Utils.Safe(ctype, "string", nil) or nil
    rec.sigBase = Rules.Signature(rec.level, rec.tier, rec.power)
    rec.sig = Rules.Signature(rec.level, rec.tier, rec.power, rec.model)
    local okA, canAttack = pcall(UnitCanAttack, "player", token)
    rec.hostile = okA and not Utils.IsSecret(canAttack) and canAttack == true
    rec.player = Utils.Flag(UnitIsPlayer, token)
    rec.markable = Utils.Flag(CanBeRaidTarget, token)
    rec.dead = Utils.Flag(UnitIsDead, token)
    return rec
end

-- =========================================================================
-- Model identity. Forever: ModelSceneActor:SetModelByUnitCreatureDisplayID isn't guarded by
-- RequiresDeclassifiedUnitIdentity (its siblings are), and GetModelFileID is readable inside instances, so the model
-- file tells a worm from a trogg even where names are secret (kb/addons/TankMark.md, run 6). If Blizzard closes this,
-- rec.model stays nil and signatures fall back to level|tier|power.
-- =========================================================================
local modelScene
local actors = {}      -- [token] = actor (one per nameplate token, reused)
local requestSeq = 0

local function ActorFor(token)
    if not modelScene then
        modelScene = CreateFrame("ModelScene", "TMF_ModelScene", UIParent)
        modelScene:SetSize(4, 4)
        modelScene:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
        modelScene:SetAlpha(0.01)   -- effectively invisible; a hidden scene might not load models
    end
    if not actors[token] then
        local ok, actor = pcall(modelScene.CreateActor, modelScene, nil, "ModelSceneActorTemplate")
        if not ok or not actor then return nil end
        actors[token] = actor
    end
    return actors[token]
end

local function ApplyModel(token, rec, fileID)
    if Plates.records[token] ~= rec then return end            -- plate gone or reused meanwhile
    if Utils.IsSecret(fileID) or type(fileID) ~= "number" or fileID <= 0 or rec.model == fileID then return end
    rec.model = fileID
    rec.sig = Rules.Signature(rec.level, rec.tier, rec.power, fileID)
    Changed()
end

function Plates:LoadModel(token, rec)
    local actor = ActorFor(token)
    if not actor then return end
    requestSeq = requestSeq + 1
    local request = requestSeq
    actor.tmfRequest = request
    pcall(actor.ClearModel, actor)   -- never read a previous mob's model
    pcall(actor.SetOnModelLoadedCallback, actor, function(a)
        if a.tmfRequest == request then
            local ok, fileID = pcall(a.GetModelFileID, a)
            if ok then ApplyModel(token, rec, fileID) end
        end
    end)
    if not pcall(actor.SetModelByUnitCreatureDisplayID, actor, token) then return end
    C_Timer.After(1.5, function()   -- in case the loaded callback doesn't fire
        if actor.tmfRequest == request and not rec.model then
            local ok, fileID = pcall(actor.GetModelFileID, actor)
            if ok then ApplyModel(token, rec, fileID) end
        end
    end)
end

-- The plate record of a unit (mouseover/target), so learning uses the loaded model. nil if it has no plate.
function Plates:RecordFor(unit)
    if Plates.records[unit] then return Plates.records[unit] end
    for token, rec in pairs(Plates.records) do
        local ok, same = pcall(UnitIsUnit, unit, token)
        if ok and not Utils.IsSecret(same) and same == true then return rec end
    end
    return nil
end

-- Whether Blizzard's nameplate shows a raid icon. The icon itself is secret, IsShown isn't (run 2).
function Plates:IsMarked(token)
    local ok, shown = pcall(function()
        local plate = C_NamePlate.GetNamePlateForUnit(token)
        local rt = plate and plate.UnitFrame and plate.UnitFrame.RaidTargetFrame
        return rt and rt:IsShown()
    end)
    return ok and not Utils.IsSecret(shown) and shown == true
end

function Plates:CountSelected()
    local n = 0
    for _ in pairs(Plates.selected) do n = n + 1 end
    return n
end

function Plates:ClearSelection(quiet)
    if next(Plates.selected) == nil then return end
    wipe(Plates.selected)
    if not quiet then TMF:Print(TMF.L["SELECT_CLEARED"]) end
    Changed()
end

-- Mobs the planner may use: hostile, alive, markable NPCs not already fighting; only the selection if any.
function Plates:GetCandidates()
    local useSelection = next(Plates.selected) ~= nil
    local list = {}
    for token, rec in pairs(Plates.records) do
        if rec.hostile and rec.markable and not rec.player and not rec.dead
            and (not useSelection or Plates.selected[token])
            and not Utils.Flag(UnitAffectingCombat, token) then
            table.insert(list, rec)
        end
    end
    table.sort(list, function(a, b) return a.seq < b.seq end)
    return list
end

local function RefreshZone()
    Plates.zone = GetRealZoneText() or ""
    Plates.inInstance = IsInInstance() == true
end

local function RereadAll()
    for token, rec in pairs(Plates.records) do
        if UnitExists(token) then Plates:Read(token, rec) else Plates.records[token] = nil end
    end
end

-- Shift-hover: add the mouseover mob to the pack selection (UnitIsUnit stays readable in dungeons, run 3).
local function OnMouseover()
    if not TMF:Get("shiftSelect") or not IsShiftKeyDown() or InCombatLockdown() then return end
    for token, rec in pairs(Plates.records) do
        local ok, same = pcall(UnitIsUnit, "mouseover", token)
        if ok and not Utils.IsSecret(same) and same == true then
            if rec.hostile and not Plates.selected[token] then
                Plates.selected[token] = true
                TMF:Print(TMF.L["SELECT_ADDED"], Plates:CountSelected())
                Changed()
            end
            return
        end
    end
end

local frame = CreateFrame("Frame", "TMF_PlatesFrame")
frame:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        Plates.records[unit] = Plates:Read(unit)
        Plates:LoadModel(unit, Plates.records[unit])
        if InCombatLockdown() then TMF:Debug("plate added %s (%s)", unit, TMF.Planner.Describe(Plates.records[unit])) end
        Changed()
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        if InCombatLockdown() then TMF:Debug("plate removed %s", unit) end
        Plates.records[unit] = nil
        Plates.selected[unit] = nil
        Changed()
    elseif event == "UNIT_HEALTH" then
        local rec = Plates.records[unit]
        if rec and not rec.dead and Utils.Flag(UnitIsDead, unit) then
            rec.dead = true
            TMF:Debug("died %s", unit)
            Changed()
        end
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        OnMouseover()
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Names hidden in combat may be readable again (open world).
        RereadAll()
        Changed()
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        RefreshZone()
        wipe(Plates.selected)
        Changed()
    end
end)

function Plates:OnEnable()
    RefreshZone()
    frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    frame:RegisterEvent("UNIT_HEALTH")
    frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    for i = 1, 40 do
        local token = "nameplate" .. i
        if UnitExists(token) then
            Plates.records[token] = Plates:Read(token)
            Plates:LoadModel(token, Plates.records[token])
        end
    end
    Changed()
end

function Plates:OnDisable()
    frame:UnregisterAllEvents()
    wipe(Plates.records)
    wipe(Plates.selected)
    Changed()
end
