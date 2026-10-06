local ADDON_NAME, TMF = ...

-- Team setup window (ButtonFrameTemplate, TankAlertForever style), created on first open.
-- No dropdowns: every addon WowStyle1Dropdown menu crashed the beta client (kb/gotchas.md#menu-crash);
-- roles and players are click-to-cycle buttons instead.
local Setup = TMF:RegisterModule("Setup")
local L, Utils = TMF.L, TMF.Utils

local panel
local ROWS = 8
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

local function CreateCheckbox(parent, text, tooltip, onClick)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    cb.Text:SetFontObject("GameFontHighlight")
    cb.Text:SetText(text)
    cb:SetScript("OnClick", function(self) onClick(self:GetChecked()) end)
    Tooltip(cb, text, tooltip)
    return cb
end

local function ClassColored(name, class)
    local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if color and color.colorStr then return "|c" .. color.colorStr .. name .. "|r" end
    return name
end

local function CreateRow(parent, i)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(440, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 12, -36 - (i - 1) * ROW_HEIGHT)

    row.order = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.order:SetPoint("LEFT", 4, 0)
    row.order:SetWidth(18)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(22, 22)
    row.icon:SetPoint("LEFT", 26, 0)
    row.icon:SetTexture(Utils.ICON_TEXTURE)

    row.role = CreateButton(row, "", 70, function() TMF.Team:CycleRole(i) end)
    row.role:SetPoint("LEFT", 56, 0)
    Tooltip(row.role, L["SETUP_ROLE"], L["SETUP_ROLE_DESC"])

    row.player = CreateButton(row, "", 180, function(_, button)
        if button == "RightButton" then TMF.Team:ClearPlayer(i) else TMF.Team:CyclePlayer(i) end
    end)
    row.player:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.player:SetPoint("LEFT", row.role, "RIGHT", 6, 0)
    Tooltip(row.player, L["SETUP_PLAYER"], L["SETUP_PLAYER_DESC"])

    row.up = CreateButton(row, L["BTN_UP"], 48, function() TMF.Team:MoveRow(i, -1) end)
    row.up:SetPoint("LEFT", row.player, "RIGHT", 6, 0)
    row.down = CreateButton(row, L["BTN_DOWN"], 48, function() TMF.Team:MoveRow(i, 1) end)
    row.down:SetPoint("LEFT", row.up, "RIGHT", 2, 0)
    return row
end

function Setup:Refresh()
    if not panel or not panel:IsShown() then return end
    local rows = TMF.Team:Rows()
    local killN = 0
    for i, r in ipairs(panel.rows) do
        local data = rows[i]
        r.icon:SetTexCoord(Utils.IconTexCoord(data.icon))
        r.role:SetText(L["ROLE_" .. data.role])
        if data.role == "KILL" then
            killN = killN + 1
            r.order:SetText(tostring(killN))
        else
            r.order:SetText("")
        end
        local text
        if data.player then
            local m = TMF.Team:FindMember(data.player)
            text = m and ClassColored(m.short, m.class) or ("|cff888888" .. data.player .. "|r")
        else
            text = data.role == "CC" and ("|cffff6060" .. L["SETUP_NEEDS_PLAYER"] .. "|r") or L["SETUP_ANYONE"]
        end
        r.player:SetText(text)
        r.player:SetEnabled(data.role ~= "OFF")
        r.up:SetEnabled(i > 1)
        r.down:SetEnabled(i < #rows)
    end
    panel.widgets.enabled:SetChecked(TMF.isEnabled)
    panel.widgets.overlay:SetChecked(TMF:Get("overlay"))
    panel.widgets.shift:SetChecked(TMF:Get("shiftSelect"))
end

local function CreatePanel()
    if panel then return panel end
    local f = CreateFrame("Frame", "TankMarkForeverSetupPanel", UIParent, "ButtonFrameTemplate")
    f:SetSize(480, 420)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:SetTitle(L["SETUP_TITLE"] .. " |cff888888v" .. TMF.version .. "|r")
    if f.SetPortraitToAsset then f:SetPortraitToAsset("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8") end

    local widgets = {}
    f.widgets = widgets
    widgets.enabled = CreateCheckbox(f, L["OPT_ENABLED"], L["OPT_ENABLED_DESC"], function(checked)
        if checked then TMF:Enable() else TMF:Disable() end
        Setup:Refresh()
    end)
    widgets.enabled:SetPoint("TOPLEFT", 64, -28)

    local content = f.Inset
    local header = content:CreateFontString(nil, "ARTWORK", "GameFontNormalMed2")
    header:SetPoint("TOPLEFT", 16, -12)
    header:SetText(L["SETUP_HEADER"])

    f.rows = {}
    for i = 1, ROWS do f.rows[i] = CreateRow(content, i) end

    widgets.overlay = CreateCheckbox(content, L["OPT_OVERLAY"], L["OPT_OVERLAY_DESC"], function(checked)
        TMF:Set("overlay", checked)
        TMF.Overlay:Show(TMF.Planner.plan)
    end)
    widgets.overlay:SetPoint("TOPLEFT", 14, -36 - ROWS * ROW_HEIGHT - 6)
    widgets.shift = CreateCheckbox(content, L["OPT_SHIFT"], L["OPT_SHIFT_DESC"], function(checked)
        TMF:Set("shiftSelect", checked)
    end)
    widgets.shift:SetPoint("LEFT", widgets.overlay, "RIGHT", 170, 0)

    local announce = CreateButton(f, L["BTN_ANNOUNCE"], 110, function() TMF.Team:Announce() end)
    announce:SetPoint("BOTTOMLEFT", 8, 4)
    Tooltip(announce, L["BTN_ANNOUNCE"], L["BTN_ANNOUNCE_DESC"])
    local reset = CreateButton(f, L["BTN_RESET"], 90, function() TMF.Team:Reset() end)
    reset:SetPoint("LEFT", announce, "RIGHT", 6, 0)

    f:SetScript("OnShow", function() Setup:Refresh() end)
    tinsert(UISpecialFrames, "TankMarkForeverSetupPanel")
    f:Hide()   -- frames are created shown; Toggle decides
    panel = f
    return f
end

function Setup:Toggle()
    local f = CreatePanel()
    if f:IsShown() then f:Hide() else f:Show() end
end

function Setup:OnInitialize()
    TMF:On("SETUP_CHANGED", function() Setup:Refresh() end)
end
