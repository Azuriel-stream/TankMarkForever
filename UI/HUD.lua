local ADDON_NAME, TMF = ...

-- HUD: the marks in use and a quick on/off per mark, so the leader can fit the marks to the pack in front of them
-- (legacy TankMark_HUD.lua). Always shown while TankMark is enabled; like the quest tracker, clicking the title bar
-- collapses and expands it. Position, collapsed state and every mark's on/off are saved.
-- A plain frame (not secure): it never marks anything, it only edits the setup, so it works in combat too.
local HUD = TMF:RegisterModule("HUD")
local L, Utils = TMF.L, TMF.Utils

local WIDTH, TITLE_H, ROW_H = 220, 20, 18
local hud
local rowIndex = {}   -- row frame -> setup row (plain table: unset frame fields aren't nil in wowsim)
local draggedAt

local function Tooltip(widget, title, bodyFn)
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(title(self), 1, 1, 1)
        GameTooltip:AddLine(bodyFn(self), nil, nil, nil, true)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function SavePosition()
    -- Anchor the top-left corner, so collapsing keeps the title bar where the player left it.
    local left, top = hud:GetLeft(), hud:GetTop()
    if type(left) ~= "number" or type(top) ~= "number" then return end
    TMF.db.hud.point = { x = left, y = top }
    hud:ClearAllPoints()
    hud:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
end

local function RestorePosition()
    local p = TMF.db.hud.point
    hud:ClearAllPoints()
    if p and tonumber(p.x) and tonumber(p.y) then
        hud:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.x, p.y)
    else
        hud:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -250, -200)
    end
end

local function CreateRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(WIDTH - 12, ROW_H)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    row.order = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.order:SetPoint("LEFT", 0, 0)
    row.order:SetWidth(14)
    row.order:SetJustifyH("RIGHT")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", 18, 0)
    row.icon:SetTexture(Utils.ICON_TEXTURE)

    row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
    row.text:SetPoint("RIGHT", 0, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)

    row:SetScript("OnClick", function(self, button)
        local index = rowIndex[self]
        if not index then return end
        if button == "RightButton" then
            TMF.Setup:Toggle()
        else
            TMF.Team:ToggleOff(index)
        end
    end)
    Tooltip(row, function(self)
        local data = rowIndex[self] and TMF.Team:Rows()[rowIndex[self]]
        return data and Utils.IconName(data.icon) or ""
    end, function()
        return L["HUD_ROW_DESC"] .. (InCombatLockdown() and ("\n" .. L["HUD_COMBAT"]) or "")
    end)
    return row
end

local function CreateHUD()
    local f = CreateFrame("Frame", "TankMarkForeverHUD", UIParent)
    f:SetSize(WIDTH, TITLE_H)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    if f.SetDontSavePosition then f:SetDontSavePosition(true) end   -- our own saved position, not layout-local.txt
    hud = f
    RestorePosition()

    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0, 0, 0, 0.35)

    -- Title bar: click collapses/expands, drag moves.
    local title = CreateFrame("Button", "TankMarkForeverHUDTitle", f)
    title:SetPoint("TOPLEFT")
    title:SetPoint("TOPRIGHT")
    title:SetHeight(TITLE_H)
    title:RegisterForClicks("LeftButtonUp")
    title:RegisterForDrag("LeftButton")
    title.toggle = title:CreateTexture(nil, "ARTWORK")
    title.toggle:SetSize(14, 14)
    title.toggle:SetPoint("LEFT", 4, 0)
    title.text = title:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title.text:SetPoint("LEFT", title.toggle, "RIGHT", 4, 0)
    title:SetScript("OnDragStart", function() f:StartMoving() end)
    title:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        SavePosition()
        draggedAt = GetTime()
    end)
    title:SetScript("OnClick", function()
        if draggedAt and GetTime() - draggedAt < 0.1 then return end   -- the mouse-up ending a drag
        TMF.db.hud.collapsed = not TMF.db.hud.collapsed
        HUD:Refresh()
    end)
    Tooltip(title, function() return L["HUD_TITLE"] end, function() return L["HUD_TITLE_DESC"] end)
    f.title = title

    local allOn = CreateFrame("Button", "TankMarkForeverHUDAllOn", title, "UIPanelButtonTemplate")
    allOn:SetSize(56, 18)
    allOn:SetPoint("RIGHT", -2, 0)
    allOn:SetText(L["HUD_ALL_ON"])
    allOn:SetScript("OnClick", function() TMF.Team:AllOn() end)
    Tooltip(allOn, function() return L["HUD_ALL_ON"] end, function() return L["HUD_ALL_ON_DESC"] end)
    f.allOn = allOn

    f.headers = {}
    for _, key in ipairs({ "TANK", "CC" }) do
        local h = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        h:SetText(L["HUD_" .. key])
        f.headers[key] = h
    end
    f.rows = {}
    for i = 1, 8 do f.rows[i] = CreateRow(f) end
    return f
end

-- Row text: the player who owns the mark (class colour) and the mob the current plan puts it on.
local function RowText(data, planned)
    local parts = {}
    if data.player then
        local m = TMF.Team:FindMember(data.player)
        table.insert(parts, m and Utils.ClassColored(m.short, m.class) or ("|cff888888" .. data.player .. "|r"))
    end
    if planned then table.insert(parts, planned) end
    local text = #parts > 0 and table.concat(parts, " - ") or ("|cff888888" .. L["HUD_FREE"] .. "|r")
    if data.off then
        -- Strip colours so the whole row reads as dimmed.
        local plain = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        text = "|cff666666" .. plain .. " " .. L["HUD_OFF"] .. "|r"
    end
    return text
end

function HUD:Refresh()
    if not hud then return end
    local collapsed = TMF.db.hud.collapsed
    local rows = TMF.Team:Rows()
    local nOff = 0
    for _, data in ipairs(rows) do
        if data.off then nOff = nOff + 1 end
    end

    hud.title.toggle:SetTexture(collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
    hud.title.text:SetText(L["HUD_TITLE"] .. (nOff > 0 and (" |cff888888" .. string.format(L["HUD_N_OFF"], nOff) .. "|r") or ""))
    hud.allOn:SetShown(nOff > 0 and not collapsed)

    local planned = {}
    for _, e in ipairs(TMF.Planner.plan.entries or {}) do
        planned[e.icon] = TMF.Planner.Describe(e)
    end

    for _, h in pairs(hud.headers) do h:Hide() end
    for _, r in ipairs(hud.rows) do r:Hide(); rowIndex[r] = nil end
    if collapsed then
        hud:SetHeight(TITLE_H)
        return
    end

    -- Tank rows first (kill order), then CC rows, each under its header.
    local y, used, killN = -TITLE_H - 2, 0, 0
    for _, role in ipairs({ "TANK", "CC" }) do
        local first = true
        for i, data in ipairs(rows) do
            if data.role == role then
                if first then
                    local h = hud.headers[role]
                    h:ClearAllPoints()
                    h:SetPoint("TOPLEFT", 8, y)
                    h:Show()
                    y, first = y - 14, false
                end
                used = used + 1
                local r = hud.rows[used]
                rowIndex[r] = i
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", 6, y)
                r.icon:SetTexCoord(Utils.IconTexCoord(data.icon))
                r.icon:SetDesaturated(data.off and true or false)
                r.icon:SetAlpha(data.off and 0.4 or 1)
                if role == "TANK" and not data.off then
                    killN = killN + 1
                    r.order:SetText(tostring(killN))
                else
                    r.order:SetText("")
                end
                r.text:SetText(RowText(data, not data.off and planned[data.icon] or nil))
                r:Show()
                y = y - ROW_H
            end
        end
        if not first then y = y - 4 end
    end
    hud:SetHeight(-y + 2)
end

function HUD:OnInitialize()
    TMF:On("SETUP_CHANGED", function() HUD:Refresh() end)
    TMF:On("PLAN_CHANGED", function() HUD:Refresh() end)
end

function HUD:OnEnable()
    if not hud then CreateHUD() end
    hud:Show()
    HUD:Refresh()
end

function HUD:OnDisable()
    if hud then hud:Hide() end
end
