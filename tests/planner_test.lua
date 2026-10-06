-- Pure planner: knowledge layering (name > signature > rules), ladder, fixed icons, reserved icons, CC pass.
local H = require("helpers")

return function(sim, t)
    local P = sim.env.TankMarkForever.Planner
    local LADDER = { 8, 7, 6, 5, 4, 3, 2, 1 }
    local function icons(plan)
        local by = {}
        for _, e in ipairs(plan.entries) do by[e.rec.token] = e.icon end
        return by
    end

    -- Rules only (instance: names secret): the mana user is killed first, then higher level first.
    local melee14 = H.rec("nameplate1", { level = 14 })
    local caster13 = H.rec("nameplate2", { level = 13, power = "MANA" })
    local melee15 = H.rec("nameplate3", { level = 15 })
    local plan = P.Build({ melee14, caster13, melee15 }, nil, { ladder = LADDER })
    local by = icons(plan)
    t.eq(by.nameplate2, 8, "caster gets skull by rules")
    t.eq(by.nameplate3, 7, "higher-level melee next")
    t.eq(by.nameplate1, 6, "lower-level melee last")
    t.eq(table.concat(plan.killOrder, ","), "nameplate2,nameplate3,nameplate1", "kill order follows priority")

    -- Learned by signature beats rules; learned by name beats signature.
    local zone = { names = {}, sigs = { [melee14.sig] = { type = "KILL", prio = 1 } } }
    by = icons(P.Build({ melee14, caster13 }, zone, { ladder = LADDER }))
    t.eq(by.nameplate1, 8, "signature prio 1 beats the caster rule")
    local named = H.rec("nameplate4", { name = "Taragaman", level = 14 })
    zone.names["Taragaman"] = { type = "KILL", prio = 9 }
    by = icons(P.Build({ named, caster13 }, zone, { ladder = LADDER }))
    t.eq(by.nameplate2, 8, "name entry (prio 9) beats the signature entry (prio 1)")

    -- IGNORE, fixed icon, reserved icon.
    zone = { names = {}, sigs = { [melee14.sig] = { type = "IGNORE" }, [caster13.sig] = { type = "KILL", prio = 5, icon = 5 } } }
    plan = P.Build({ melee14, caster13, melee15 }, zone, { ladder = LADDER, reserved = { [8] = true } })
    by = icons(plan)
    t.eq(by.nameplate1, nil, "ignored mob gets no icon")
    t.eq(by.nameplate2, 5, "fixed icon honoured")
    t.eq(by.nameplate3, 7, "reserved skull skipped")
    t.ok(plan.reserved[8], "plan carries reserved icons")

    -- Short ladder: overflow, then CC on a legal slot (open world: creature type known).
    local slots = { { mark = 5, class = "MAGE", alive = true } }
    local a = H.rec("nameplate1", { level = 15, power = "MANA", ctype = "Humanoid" })
    local b = H.rec("nameplate2", { level = 14, power = "MANA", ctype = "Humanoid" })
    local m = H.rec("nameplate3", { level = 14 })
    plan = P.Build({ a, b, m }, nil, { ladder = { 8 }, ccSlots = slots })
    by = icons(plan)
    t.eq(by.nameplate1, 8, "first caster killed")
    t.eq(by.nameplate2, 5, "second caster sheeped (CC worthiness 70)")
    t.eq(#plan.overflow, 1, "melee overflow")
    -- Instances: unknown creature type, no authored class -> no CC.
    b.ctype = nil
    plan = P.Build({ a, b, m }, nil, { ladder = { 8 }, ccSlots = slots })
    t.eq(icons(plan).nameplate2, nil, "no CC without a creature type")
    t.eq(#plan.overflow, 2, "both leftovers reported")

    -- Describe without a name.
    t.eq(P.Describe(caster13), "lvl 13 elite caster", "secret-name description")
end
