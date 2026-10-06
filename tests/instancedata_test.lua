-- Offline instance data: (instance map, model file) -> creature type + CC immunities, so CC is legal and safe inside
-- instances where UnitCreatureType is secret. Variants are filtered by power type and level; disagreement = unknown.
local H = require("helpers")

local RFC = 389
local TROGG, WORM, ORC_HD = 126239, 126512, 917116

local function setup(s)
    H.install(s)
    s.env.IsInInstance = function() return true, "party" end
    s.env.GetInstanceInfo = function() return "Ragefire Chasm", "party", 1, "Normal", 5, 0, false, RFC, 5, nil, false end
    s.env.UnitRace = function(u) local x = s.units[u]; if x then return "Human", "Human" end end
    s.units.party1.class = "MAGE"
    local realName = s.env.UnitName
    s.env.UnitName = function(u)   -- names hidden inside instances
        if u:find("^nameplate") then return nil end
        return realName(u)
    end
    s.units.target = nil
    -- No ctype on the units: UnitCreatureType reads nil, as inside an instance.
    s.units.nameplate1 = { guid = "Creature-0-1-0-1-11319-1", friendly = false, level = 14, tier = "elite",
                           power = "MANA", model = TROGG }   -- Ragefire Shaman
    s.units.nameplate2 = { guid = "Creature-0-1-0-1-11319-2", friendly = false, level = 13, tier = "elite",
                           power = "MANA", model = TROGG }   -- Ragefire Shaman
    s.units.nameplate3 = { guid = "Creature-0-1-0-1-11318-3", friendly = false, level = 15, tier = "elite",
                           power = "RAGE", model = TROGG }   -- Ragefire Trogg
end

local function plannedIcons(TMF)
    local by = {}
    for _, e in ipairs(TMF.Planner.plan.entries) do by[e.rec.token] = e.icon end
    return by
end

return function(_, t)
    -- Pure matching.
    local sim = t.fresh(setup)
    local TMF = sim.env.TankMarkForever
    local Rules, data = TMF.Rules, TMF.InstanceMobs
    t.ok(data[RFC] and data[RFC][TROGG], "RFC trogg model in the generated data")

    local id = Rules.IdentifyFromData(data[RFC][TROGG], "RAGE", 14)
    t.eq(id.ctype, "Humanoid", "rage trogg body: humanoid")
    t.eq(table.concat(id.names, ","), "Ragefire Trogg", "level 14 excludes the boss on the same body")
    t.eq(id.immune, "", "trash trogg has no CC immunity")
    id = Rules.IdentifyFromData(data[RFC][TROGG], "RAGE", 16)
    t.eq(id.names[1], "Oggleflint", "level 16 rage trogg = the boss")
    t.ok(id.immune:find("P", 1, true), "boss is polymorph-immune")
    id = Rules.IdentifyFromData(data[RFC][TROGG], "MANA", 14)
    t.eq(id.names[1], "Ragefire Shaman", "mana trogg = shaman")
    t.eq(Rules.IdentifyFromData(data[RFC][WORM], "RAGE", 14).ctype, "Beast", "worm: beast")
    t.eq(Rules.IdentifyFromData(data[RFC][TROGG], "ENERGY", 14), nil, "power type no NPC has: unknown")

    local mixed = { "H;M;10;12;;Cultist", "U;M;10;12;;Ghost", "U;R;10;12;FZ;Ghoul" }
    t.eq(Rules.IdentifyFromData(mixed, "MANA", 11).ctype, nil, "types disagree: unknown, never a guess")
    t.eq(Rules.IdentifyFromData(mixed, "RAGE", 11).ctype, "Undead", "power type separates them")
    id = Rules.IdentifyFromData(mixed, nil, 40)
    t.eq(id.ctype, nil, "no level match falls back to all variants (stricter)")
    t.eq(id.immune, "FZ", "immunities are the union")

    -- Immunity per class mechanic.
    t.ok(Rules.CCImmune("MAGE", "Humanoid", "FP"), "polymorph immunity blocks a mage")
    t.ok(not Rules.CCImmune("MAGE", "Humanoid", "F"), "fear immunity doesn't block a mage")
    t.ok(Rules.CCImmune("WARLOCK", "Elemental", "B"), "warlock on an elemental = banish")
    t.ok(not Rules.CCImmune("WARLOCK", "Humanoid", "B"), "warlock on a humanoid = fear")
    t.ok(Rules.CCImmune("ROGUE", "Humanoid", "K"), "sap blocked by knockout immunity")
    local slots = { { mark = 5, class = "MAGE", alive = true } }
    t.eq(Rules.SelectCCSlot(nil, "Humanoid", slots, false, "P"), nil, "no sheep on a polymorph-immune mob")
    t.eq(Rules.SelectCCSlot(nil, "Elemental", slots, false, nil), nil, "no sheep on an elemental")
    t.eq(Rules.SelectCCSlot("MAGE", nil, slots, true, "P"), nil, "taught CC still respects immunity")

    -- In the sim: kill ladder = skull only, moon = Lumen's sheep. The second shaman is a leftover caster (CC worth 70);
    -- its type comes from the data, so the sheep is legal.
    local rows = sim.env.TankMarkForeverDB.setup.rows
    for i = 2, 8 do rows[i].role = "OFF" end
    rows[4].role, rows[4].player = "CC", "Lumen Brightwater"
    TMF.Plates.Changed()
    sim:Advance(2)
    local recs = TMF.Plates.records
    t.eq(TMF.Plates.instanceID, RFC, "instance map ID read")
    t.eq(recs.nameplate1.ctype, "Humanoid", "type restored from the data")
    t.eq(recs.nameplate1.ctypeSource, "data", "source recorded")
    t.eq(TMF.MobDB:Label(recs.nameplate1), "Ragefire Shaman", "label uses the data name")
    local by = plannedIcons(TMF)
    t.eq(by.nameplate1, 8, "higher-level shaman killed first")
    t.eq(by.nameplate2, 5, "second shaman sheeped")
    t.eq(by.nameplate3, nil, "trogg (melee) overflows")
    local reported = false
    sim:Slash("/tmf plan")
    for _, line in ipairs(sim.output) do if line:find("Humanoid (data)", 1, true) then reported = true end end
    t.ok(reported, "/tmf plan shows the data type")
    local overflowLine = false
    for _, line in ipairs(sim.output) do
        if line:find("no icon: Ragefire Trogg (out of icons", 1, true) then overflowLine = true end
    end
    t.ok(overflowLine, "/tmf plan names the mob without an icon and why")

    -- Plates left out of the plan are reported with the reason.
    TMF.Plates.selected.nameplate1 = true
    TMF.Plates.Changed()
    sim:Advance(1)
    sim:Slash("/tmf plan")
    local selLine = false
    for _, line in ipairs(sim.output) do
        if line:find("no icon: Ragefire Shaman (not in your Shift-hover selection)", 1, true) then selLine = true end
    end
    t.ok(selLine, "/tmf plan explains a plate outside the selection")
    TMF.Plates:ClearSelection(true)

    -- A Shaman has no CC on Forever: the moon row with a Shaman gives no CC slot.
    sim.units.party1.class = "SHAMAN"
    t.eq(#TMF.Team:GetCCSlots(), 0, "shaman CC row: no slot")
    t.ok(not Rules.HasCC("SHAMAN") and Rules.HasCC("MAGE"), "HasCC")
    sim.units.party1.class = "MAGE"
    TMF.Plates.Changed()
    sim:Advance(1)

    -- Same pack, but the leftover caster is the polymorph-immune boss on an HD orc body (Jergosh).
    sim.units.nameplate2 = { guid = "Creature-0-1-0-1-11518-2", friendly = false, level = 16, tier = "elite",
                             power = "MANA", model = ORC_HD }
    sim.units.nameplate1.level = 17   -- keep the shaman first in the kill order
    sim:Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    sim:Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
    sim:Advance(2)
    t.eq(recs.nameplate2.dataName, "Jergosh the Invoker", "boss identified")
    t.eq(plannedIcons(TMF).nameplate2, nil, "immune boss not sheeped")

    -- Open world (no data): readable creature type wins, no immunities.
    local sim2 = t.fresh(function(s)
        setup(s)
        s.env.IsInInstance = function() return false, "none" end
        s.env.GetInstanceInfo = function() return "Kalimdor", "none", 0, "", 0, 0, false, 1, 0, nil, false end
        s.units.nameplate1.ctype = "Beast"
    end)
    local rec = sim2.env.TankMarkForever.Plates.records.nameplate1
    t.eq(rec.ctype, "Beast", "unit type kept")
    t.eq(rec.ctypeSource, "unit", "from the unit")
    t.eq(rec.immune, nil, "no data outside instances")
end
