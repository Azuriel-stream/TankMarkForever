local ADDON_NAME, TMF = ...

-- Mob database window (/tmf mobs): what the player taught, per zone. Paged list (no scroll templates), zones
-- switched with arrows (no dropdowns: they crashed the beta, kb/gotchas.md#menu-crash). Created on first open.
local MobsUI = TMF:RegisterModule("MobsUI")
local L, Utils = TMF.L, TMF.Utils

local panel
local ROWS = 10
-- Row contents live in a plain table (not on the frames); an empty row's buttons do nothing.
local rowData = {}
local NONE = { entry = {}, key = "", kind = "" }
local function D(i) return rowData[i] or NONE end
local ROW_HEIGHT = 30

local function CreateButton(parent, text, width, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width, 22)
    btn:SetText(text)
    btn:SetScript("OnClick", onClick)
    return btn
end

local function Tooltip(widget, title, body)
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        GameTooltip:AddLine(body, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function CreateRow(parent, i)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(560, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 10, -40 - (i - 1) * ROW_HEIGHT)

    row.kind = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    row.kind:SetPoint("LEFT", 2, 0)
    row.kind:SetWidth(30)

    -- Name entries: plain text. Signature entries: an edit box for the player's label.
    row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.label:SetPoint("LEFT", 34, 0)
    row.label:SetWidth(190)
    row.label:SetJustifyH("LEFT")
    row.note = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    row.note:SetSize(184, 20)
    row.note:SetPoint("LEFT", 40, 0)
    row.note:SetAutoFocus(false)
    row.note:SetMaxLetters(40)
    row.note:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        if text == TMF.MobDB.DescribeSig(D(i).key) then text = "" end   -- unchanged default: no label
        TMF.MobDB:SetNote(D(i).entry, text)
        self:ClearFocus()
    end)
    row.note:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        MobsUI:Refresh()
    end)
    Tooltip(row.note, L["MOBS_KIND_SIG"], L["MOBS_NOTE_DESC"])

    row.type = CreateButton(row, "", 64, function() TMF.MobDB:CycleType(D(i).entry) end)
    row.type:SetPoint("LEFT", 230, 0)
    Tooltip(row.type, L["SETUP_ROLE"], L["MOBS_TYPE_DESC"])

    row.minus = CreateButton(row, "-", 22, function() TMF.MobDB:StepPrio(D(i).entry, -1) end)
    row.minus:SetPoint("LEFT", row.type, "RIGHT", 6, 0)
    row.prio = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.prio:SetPoint("LEFT", row.minus, "RIGHT", 2, 0)
    row.prio:SetWidth(18)
    row.plus = CreateButton(row, "+", 22, function() TMF.MobDB:StepPrio(D(i).entry, 1) end)
    row.plus:SetPoint("LEFT", row.prio, "RIGHT", 2, 0)
    Tooltip(row.plus, "+", L["MOBS_PRIO_DESC"])

    row.icon = CreateButton(row, "", 48, function(_, button)
        if button == "RightButton" then TMF.MobDB:ClearIcon(D(i).entry) else TMF.MobDB:CycleIcon(D(i).entry) end
    end)
    row.icon:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.icon:SetPoint("LEFT", row.plus, "RIGHT", 6, 0)
    row.iconTex = row.icon:CreateTexture(nil, "OVERLAY")
    row.iconTex:SetSize(18, 18)
    row.iconTex:SetPoint("CENTER")
    row.iconTex:SetTexture(Utils.ICON_TEXTURE)
    Tooltip(row.icon, L["MOBS_AUTO"], L["MOBS_ICON_DESC"])

    row.class = CreateButton(row, "", 72, function() TMF.MobDB:CycleClass(D(i).entry) end)
    row.class:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    Tooltip(row.class, L["TYPE_CC"], L["MOBS_CLASS_DESC"])

    row.delete = CreateButton(row, "X", 24, function()
        if rowData[i] then TMF.MobDB:Delete(panel.zone, D(i).kind, D(i).key) end
    end)
    row.delete:SetPoint("LEFT", row.class, "RIGHT", 6, 0)
    return row
end

local function ClassLabel(class)
    if not class then return L["MOBS_ANY"] end
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    local name = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class
    if color and color.colorStr then return "|c" .. color.colorStr .. name .. "|r" end
    return name
end

function MobsUI:Refresh()
    if not panel or not panel:IsShown() then return end
    local zones = TMF.MobDB:Zones(TMF.Plates.zone)
    local found = false
    for _, z in ipairs(zones) do if z == panel.zone then found = true end end
    if not found then panel.zone = TMF.Plates.zone ~= "" and TMF.Plates.zone or zones[1] end
    local entries = panel.zone and TMF.MobDB:Entries(panel.zone) or {}
    panel.zoneText:SetText(string.format(L["MOBS_ZONE"], panel.zone or "?", #entries))
    panel.prevZone:SetEnabled(#zones > 1)
    panel.nextZone:SetEnabled(#zones > 1)

    local pages = math.max(1, math.ceil(#entries / ROWS))
    panel.page = math.max(1, math.min(panel.page or 1, pages))
    panel.pageText:SetText(string.format(L["MOBS_PAGE"], panel.page, pages))
    panel.prevPage:SetEnabled(panel.page > 1)
    panel.nextPage:SetEnabled(panel.page < pages)
    panel.empty:SetShown(#entries == 0)

    for i, row in ipairs(panel.rows) do
        local data = entries[(panel.page - 1) * ROWS + i]
        rowData[i] = data
        row:SetShown(data ~= nil)
        if data then
            local e = data.entry
            local isSig = data.kind == "sig"
            row.kind:SetText(isSig and L["MOBS_KIND_SIG"] or L["MOBS_KIND_NAME"])
            row.label:SetShown(not isSig)
            row.note:SetShown(isSig)
            if isSig then
                if not row.note:HasFocus() then row.note:SetText(e.note or TMF.MobDB.DescribeSig(data.key)) end
            else
                row.label:SetText(data.label)
            end
            row.type:SetText(L["TYPE_" .. (e.type or "KILL")])
            local killOrCC = e.type ~= "IGNORE"
            row.prio:SetText(killOrCC and tostring(e.prio or 5) or "-")
            row.minus:SetEnabled(killOrCC)
            row.plus:SetEnabled(killOrCC)
            row.icon:SetEnabled(killOrCC)
            if e.icon then
                row.icon:SetText("")
                row.iconTex:SetTexCoord(Utils.IconTexCoord(e.icon))
                row.iconTex:Show()
            else
                row.icon:SetText(L["MOBS_AUTO"])
                row.iconTex:Hide()
            end
            row.class:SetShown(e.type == "CC")
            row.class:SetText(ClassLabel(e.class))
        end
    end
end

local function StepZone(delta)
    local zones = TMF.MobDB:Zones(TMF.Plates.zone)
    if #zones == 0 then return end
    local idx = 1
    for i, z in ipairs(zones) do if z == panel.zone then idx = i end end
    idx = (idx - 1 + delta) % #zones + 1
    panel.zone, panel.page = zones[idx], 1
    MobsUI:Refresh()
end

local function CreatePanel()
    if panel then return panel end
    local f = CreateFrame("Frame", "TankMarkForeverMobsPanel", UIParent, "ButtonFrameTemplate")
    f:SetSize(600, 440)
    f:SetPoint("CENTER", 40, -20)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:SetTitle(L["MOBS_TITLE"])
    if f.SetPortraitToAsset then f:SetPortraitToAsset("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8") end

    local content = f.Inset
    f.prevZone = CreateButton(content, L["BTN_PREV"], 28, function() StepZone(-1) end)
    f.prevZone:SetPoint("TOPLEFT", 12, -10)
    f.zoneText = content:CreateFontString(nil, "ARTWORK", "GameFontNormalMed2")
    f.zoneText:SetPoint("LEFT", f.prevZone, "RIGHT", 10, 0)
    f.nextZone = CreateButton(content, L["BTN_NEXT"], 28, function() StepZone(1) end)
    f.nextZone:SetPoint("LEFT", f.zoneText, "RIGHT", 10, 0)

    f.empty = content:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    f.empty:SetPoint("TOPLEFT", 16, -50)
    f.empty:SetWidth(540)
    f.empty:SetJustifyH("LEFT")
    f.empty:SetText(L["MOBS_EMPTY"])

    f.rows = {}
    for i = 1, ROWS do f.rows[i] = CreateRow(content, i) end

    local learn = CreateButton(f, L["BTN_LEARN_TARGET"], 120, function()
        local _, label = TMF.MobDB:Learn("target")
        if label then TMF:Print(L["LEARN_SAVED"], label, L["TYPE_KILL"]) else TMF:Print(L["LEARN_NO_UNIT"]) end
        panel.zone = TMF.Plates.zone
    end)
    learn:SetPoint("BOTTOMLEFT", 8, 4)
    Tooltip(learn, L["BTN_LEARN_TARGET"], L["BTN_LEARN_TARGET_DESC"])

    f.nextPage = CreateButton(f, L["BTN_NEXT"], 28, function() panel.page = panel.page + 1 MobsUI:Refresh() end)
    f.nextPage:SetPoint("BOTTOMRIGHT", -8, 4)
    f.pageText = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    f.pageText:SetPoint("RIGHT", f.nextPage, "LEFT", -8, 0)
    f.prevPage = CreateButton(f, L["BTN_PREV"], 28, function() panel.page = panel.page - 1 MobsUI:Refresh() end)
    f.prevPage:SetPoint("RIGHT", f.pageText, "LEFT", -8, 0)

    f:SetScript("OnShow", function() MobsUI:Refresh() end)
    tinsert(UISpecialFrames, "TankMarkForeverMobsPanel")
    f:Hide()   -- frames are created shown; Toggle decides
    panel = f
    return f
end

function MobsUI:Toggle()
    local f = CreatePanel()
    if f:IsShown() then
        f:Hide()
    else
        f.zone, f.page = TMF.Plates.zone, 1
        f:Show()
    end
end

function MobsUI:OnInitialize()
    TMF:On("MOBDB_CHANGED", function() MobsUI:Refresh() end)
end
