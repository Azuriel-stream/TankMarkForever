local ADDON_NAME, TMF = ...

-- Pack planner: decides which icon each visible mob gets, out of combat. Port of legacy DecidePull
-- (Core/TankMark_Pull.lua v0.32): fixed icons, then the kill ladder by priority, then CC on the leftovers.
-- Knowledge per mob: learned by name (open world) > learned by signature (instances) > rules (power type x tier).
local Planner = TMF:RegisterModule("Planner")
local Rules, Utils = TMF.Rules, TMF.Utils

Planner.plan = { entries = {}, killOrder = {}, overflow = {}, reserved = {} }

-- =========================================================================
-- Pure part (no WoW API): tests drive these directly.
-- =========================================================================
function Planner.Knowledge(rec, zoneMobs)
    if zoneMobs then
        local e = rec.name and zoneMobs.names[rec.name]
        if e then return e, "name" end
        e = zoneMobs.sigs[rec.sig] or (rec.sigBase and zoneMobs.sigs[rec.sigBase])
        if e then return e, "sig" end
    end
    return nil, "rules"
end

-- recs: plate records; zoneMobs: { names, sigs } or nil
-- ctx: { ladder = {icons in kill order}, ccSlots = {...}, reserved = {[icon] = true} }
-- returns { entries = { {rec, icon, reason, role, prio, source} } in icon-assignment order,
--           killOrder = { token, ... } (kill-marked mobs, kill-first), overflow = { rec, ... } }
function Planner.Build(recs, zoneMobs, ctx)
    local used = {}
    for icon in pairs(ctx.reserved or {}) do used[icon] = true end
    local slots = {}
    for _, s in ipairs(ctx.ccSlots or {}) do
        table.insert(slots, { mark = s.mark, class = s.class, race = s.race, alive = s.alive,
                              used = s.used or used[s.mark], disabled = s.disabled })
    end
    local hasCC = #slots > 0

    local pack = {}
    for _, rec in ipairs(recs) do
        local k, source = Planner.Knowledge(rec, zoneMobs)
        if not (k and k.type == "IGNORE") then
            local role = (k and k.role) or Rules.RoleFromPower(rec.power)
            table.insert(pack, {
                rec = rec, role = role, source = source,
                prio = (k and tonumber(k.prio)) or Rules.RoleTierPrio(role, rec.tier),
                fixed = k and tonumber(k.icon),
                authoredCC = (k and k.type == "CC") or false,
                authoredClass = k and k.class,
            })
        end
    end

    local entries, killOrder, overflow = {}, {}, {}
    local function assign(c, icon, reason)
        c.icon, c.reason = icon, reason
        used[icon] = true
        table.insert(entries, { rec = c.rec, icon = icon, reason = reason, role = c.role, prio = c.prio,
                                source = c.source })
    end

    -- Kill-first order: priority, then higher level, then the order the plates appeared (deterministic).
    table.sort(pack, function(a, b)
        if a.prio ~= b.prio then return a.prio < b.prio end
        if a.rec.level ~= b.rec.level then return a.rec.level > b.rec.level end
        return a.rec.seq < b.rec.seq
    end)

    -- 0. Fixed icons the player taught ("this mob is always moon").
    for _, c in ipairs(pack) do
        if c.fixed and c.fixed >= 1 and c.fixed <= 8 and not used[c.fixed] then
            assign(c, c.fixed, c.authoredCC and "cc" or "fixed")
        end
    end

    -- 1. Kill pass down the ladder. Authored CC mobs wait for the CC pass when there are CC slots.
    local li = 1
    for _, c in ipairs(pack) do
        if not c.icon and not (c.authoredCC and hasCC) then
            local icon
            while li <= #ctx.ladder do
                local candidate = ctx.ladder[li]
                li = li + 1
                if not used[candidate] then icon = candidate break end
            end
            if not icon then break end
            assign(c, icon, "kill")
        end
    end
    for _, c in ipairs(pack) do
        if c.reason == "kill" or c.reason == "fixed" then table.insert(killOrder, c.rec.token) end
    end

    -- 2. CC pass on the leftovers, kill-last first (legacy ADR 0002: prio decides, CC the tail).
    local ccCands = {}
    for _, c in ipairs(pack) do
        if not c.icon and Rules.CCTierEligible(c.rec.tier)
            and (c.authoredCC or Rules.MeetsAutoCCFloor(c.role, c.rec.tier)) then
            table.insert(ccCands, c)
        end
    end
    for i = #ccCands, 1, -1 do
        local c = ccCands[i]
        local mark = Rules.SelectCCSlot(c.authoredClass, c.rec.ctype, slots, c.authoredCC)
        if mark and not used[mark] then
            for _, s in ipairs(slots) do
                if s.mark == mark then s.used = true end
            end
            assign(c, mark, "cc")
        end
    end

    -- 3. Never drop silently.
    for _, c in ipairs(pack) do
        if not c.icon then table.insert(overflow, c.rec) end
    end
    return { entries = entries, killOrder = killOrder, overflow = overflow, reserved = ctx.reserved or {} }
end

-- =========================================================================
-- Shell: reads the world, rebuilds out of combat, tells Marker/Overlay.
-- =========================================================================

-- Icons already on some mob. GetNextAvailableRaidTargetMarkerIndex was readable in the open world and in a
-- dungeon (run 3); icons on dead mobs count as free. Plus: plates that visibly carry an icon keep it.
local function ReservedIcons()
    local reserved = {}
    if GetNextAvailableRaidTargetMarkerIndex then
        for icon = 1, 8 do
            local ok, nextFree = pcall(GetNextAvailableRaidTargetMarkerIndex, icon, false, false, true)
            if ok and not Utils.IsSecret(nextFree) and type(nextFree) == "number" and nextFree ~= icon then
                reserved[icon] = true
            end
        end
    end
    return reserved
end

function Planner:Rebuild()
    if InCombatLockdown() then return end
    local Plates = TMF.Plates
    local recs = {}
    for _, rec in ipairs(Plates:GetCandidates()) do
        if not Plates:IsMarked(rec.token) then table.insert(recs, rec) end
    end
    local zoneMobs = TMF.db.mobs[Plates.zone]
    Planner.plan = Planner.Build(recs, zoneMobs, {
        ladder = TMF.Team:GetLadder(),
        ccSlots = TMF.Team:GetCCSlots(),
        reserved = ReservedIcons(),
    })
    -- Remember the levels each learned model entry is seen at (shown in the mob database window).
    if zoneMobs then
        for _, rec in ipairs(recs) do
            local entry = rec.model and zoneMobs.sigs[rec.sig]
            if entry then TMF.MobDB.NoteLevel(entry, rec.level) end
        end
    end
    TMF:Fire("PLAN_CHANGED", Planner.plan)
end

-- Name, else the player's note on the signature, else "lvl 15 elite caster"
function Planner.Describe(entryOrRec)
    local rec = entryOrRec.rec or entryOrRec
    return TMF.MobDB:Label(rec)
end

function Planner:Report()
    local plan = Planner.plan
    if #plan.entries == 0 then
        TMF:Print(TMF.L["PLAN_EMPTY"])
        return
    end
    TMF:Print(TMF.L["PLAN_HEADER"], #plan.entries)
    local sorted = {}
    for _, e in ipairs(plan.entries) do table.insert(sorted, e) end
    table.sort(sorted, function(a, b) return a.icon > b.icon end)
    for _, e in ipairs(sorted) do
        local detail = string.format("%s (%s, prio %d, %s)", Planner.Describe(e), e.reason, e.prio, e.source)
        print(string.format(TMF.L["PLAN_LINE"], Utils.IconText(e.icon), detail))
    end
    if #plan.overflow > 0 then print(string.format(TMF.L["PLAN_OVERFLOW"], #plan.overflow)) end
    if InCombatLockdown() then TMF:Print(TMF.L["PLAN_FROZEN"]) end
end

function Planner:OnInitialize()
    TMF:On("PLATES_CHANGED", function() Planner:Rebuild() end)
end
