local ADDON_NAME, TMF = ...

-- The team setup: kill order and CC assignments for the run (one active setup), the group roster, and the
-- announcement that tells the group the order. Group members' names/classes are never secret (kb/restrictions.md §2b).
local Team = TMF:RegisterModule("Team")
local L, Utils = TMF.L, TMF.Utils

-- Class -> the CC it brings (announcement text)
Team.CC_SPELL = {
    MAGE = "CC_MAGE", ROGUE = "CC_ROGUE", WARLOCK = "CC_WARLOCK", HUNTER = "CC_HUNTER",
    PRIEST = "CC_PRIEST", DRUID = "CC_DRUID",
}

local function Separator()
    local c = Constants and Constants.CharacterNameSeparatorConsts
    local sep = c and c.CHARACTERNAME_SURNAME_SEPARATOR
    return type(sep) == "string" and sep or " "
end

-- Forever: UnitName's second return is the surname; a full name is "First Last" (kb/api-migration.md).
function Team.FullName(unit)
    local first, surname = UnitName(unit)
    first = Utils.Safe(first, "string", nil)
    if not first then return nil end
    surname = Utils.Safe(surname, "string", nil)
    if surname and surname ~= "" then return first .. Separator() .. surname end
    return first
end

-- Group members including the player: { unit, name, short, class, race, alive }
function Team:Members()
    local units = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do table.insert(units, "raid" .. i) end
    else
        table.insert(units, "player")
        for i = 1, GetNumSubgroupMembers() do table.insert(units, "party" .. i) end
    end
    local list = {}
    for _, unit in ipairs(units) do
        local name = Team.FullName(unit)
        if name then
            local _, class = UnitClass(unit)
            local _, race = UnitRace(unit)
            table.insert(list, {
                unit = unit, name = name, short = (UnitName(unit)), class = class, race = race,
                alive = not UnitIsDeadOrGhost(unit) and UnitIsConnected(unit) ~= false,
            })
        end
    end
    return list
end

function Team:FindMember(name)
    if not name then return nil end
    for _, m in ipairs(Team:Members()) do
        if m.name == name then return m end
    end
    return nil
end

function Team:Rows()
    return TMF.db.setup.rows
end

-- Kill icons in kill order. A row owned by a tank is skipped while that tank is dead, offline or gone.
function Team:GetLadder()
    local ladder = {}
    for _, row in ipairs(Team:Rows()) do
        if row.role == "KILL" then
            local owner = row.player and Team:FindMember(row.player)
            if not row.player or (owner and owner.alive) then table.insert(ladder, row.icon) end
        end
    end
    return ladder
end

-- All kill icons (for the next-free-icon key), regardless of owners.
function Team:KillIcons()
    local icons = {}
    for _, row in ipairs(Team:Rows()) do
        if row.role == "KILL" then table.insert(icons, row.icon) end
    end
    return icons
end

-- CC rows whose player is in the group: { mark, class, race, alive } (Rules.SelectCCSlot input)
function Team:GetCCSlots()
    local slots = {}
    for _, row in ipairs(Team:Rows()) do
        if row.role == "CC" and row.player then
            local m = Team:FindMember(row.player)
            if m and TMF.Rules.HasCC(m.class) then   -- a Shaman's row stays empty (no CC on Forever)
                table.insert(slots, { mark = row.icon, class = m.class, race = m.race, alive = m.alive })
            end
        end
    end
    return slots
end

-- =========================================================================
-- Editing (setup window)
-- =========================================================================
local ROLE_CYCLE = { KILL = "CC", CC = "OFF", OFF = "KILL" }

local function Changed()
    TMF:Fire("SETUP_CHANGED")
    if TMF.Plates then TMF.Plates.Changed() end
end

function Team:CycleRole(i)
    local row = Team:Rows()[i]
    row.role = ROLE_CYCLE[row.role] or "KILL"
    Changed()
end

-- Cycle the row's player through the group members, then back to none.
function Team:CyclePlayer(i)
    local row = Team:Rows()[i]
    local members = Team:Members()
    local nextName
    if not row.player then
        nextName = members[1] and members[1].name
    else
        for k, m in ipairs(members) do
            if m.name == row.player then
                nextName = members[k + 1] and members[k + 1].name
                break
            end
        end
    end
    row.player = nextName
    Changed()
end

function Team:ClearPlayer(i)
    Team:Rows()[i].player = nil
    Changed()
end

function Team:MoveRow(i, delta)
    local rows = Team:Rows()
    local j = i + delta
    if j < 1 or j > #rows then return end
    rows[i], rows[j] = rows[j], rows[i]
    Changed()
end

function Team:Reset()
    TMF.db.setup = TMF.CopyTable(TMF.DefaultConfig.setup)
    Changed()
end

-- =========================================================================
-- Announcement, two lines: "[TankMark] Kill order: {rt8} Tankard > {rt7} > {rt6}" and
-- "[TankMark] CC: {rt5} Lumen (Polymorph)"
-- =========================================================================
local function ShortName(full)
    local m = Team:FindMember(full)
    return (m and m.short) or (full and full:match("^(%S+)")) or full
end

function Team:BuildAnnouncement()
    local kill, cc = {}, {}
    for _, row in ipairs(Team:Rows()) do
        local icon = "{rt" .. row.icon .. "}"
        if row.role == "KILL" then
            table.insert(kill, row.player and (icon .. " " .. ShortName(row.player)) or icon)
        elseif row.role == "CC" and row.player then
            local m = Team:FindMember(row.player)
            local spell = m and Team.CC_SPELL[m.class]
            table.insert(cc, icon .. " " .. ShortName(row.player) .. (spell and (" (" .. L[spell] .. ")") or ""))
        end
    end
    -- One line per list, each with its own label (player chat can't carry custom colours).
    -- Never a bare "|" in chat: it starts an escape sequence and the client rejects the message.
    local lines = { L["ANNOUNCE_PREFIX"] .. " " .. L["ANNOUNCE_KILL"] .. " " .. table.concat(kill, " > ") }
    if #cc > 0 then
        table.insert(lines, L["ANNOUNCE_PREFIX"] .. " " .. L["ANNOUNCE_CC"] .. " " .. table.concat(cc, ", "))
    end
    return lines
end

function Team:Announce()
    local channel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY") or nil
    for _, msg in ipairs(Team:BuildAnnouncement()) do
        if not channel then
            TMF:Print(L["ANNOUNCE_SOLO"], msg)
        else
            local ok, err = pcall(C_ChatInfo.SendChatMessage, msg, channel)
            if not ok then TMF:Print(L["ANNOUNCE_FAILED"], tostring(err), msg) end
        end
    end
end

-- The roster changes who owns which icon: re-plan.
local frame = CreateFrame("Frame", "TMF_TeamFrame")
frame:SetScript("OnEvent", function()
    Changed()
end)

function Team:OnEnable()
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
end

function Team:OnDisable()
    frame:UnregisterAllEvents()
end
