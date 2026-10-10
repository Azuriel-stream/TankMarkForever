-- Follow marks: a group member wears a Follow row's mark; the pack key puts it on first, the clear key clears all
-- and puts it back; never planned on a mob; not on skull; announced; HUD lock.
local H = require("helpers")

return function(_, t)
    local sim = t.fresh(function(s)
        H.install(s)
        H.pack(s)
    end)
    local env = sim.env
    local TMF = env.TankMarkForever
    local Team = TMF.Team
    local rows = env.TankMarkForeverDB.setup.rows

    -- Role cycle: Tank -> CC -> Follow -> Tank, but skull skips Follow (the next-skull key would take it).
    Team:CycleRole(1)
    Team:CycleRole(1)
    t.eq(rows[1].role, "TANK", "skull can't be a Follow mark")
    Team:CycleRole(8)
    Team:CycleRole(8)
    t.eq(rows[8].role, "FOLLOW", "star becomes a Follow mark")
    t.eq(#Team:GetFollows(), 0, "no follow mark without a player")
    rows[8].player = "Tankard Stoneforge"
    t.eq(Team.Migrate(rows), nil)
    t.eq(rows[8].role, "FOLLOW", "migration keeps Follow rows")

    -- A mob taught to always wear star must not take it from the tank.
    TMF.Plates.zone = "Test Zone"
    TMF:GetZoneMobs("Test Zone").names["Ragefire Trogg"] = { type = "TANK", prio = 5, icon = 1 }
    TMF.Plates.Changed()
    sim:Advance(1)

    local follow = env.TMF_Follow1
    t.eq(follow:GetAttribute("unit"), "player", "you wear your own follow mark (token never changes)")
    t.eq(follow:GetAttribute("marker"), 1, "star")
    t.eq(follow:GetAttribute("action"), "set-unmarked", "never toggles a worn mark off")
    t.eq(follow:GetAttribute("useOnKeyDown"), false, "acts on /click (down=false)")
    t.eq(env.TMF_Follow2:GetAttribute("action"), "none", "unused follow buttons do nothing")
    local pack = env.TMF_PackButton:GetAttribute("macrotext")
    t.ok(pack:find("^/click TMF_Follow1\n/click TMF_Mark1"), "pack key puts the follow mark on first: " .. pack)
    t.eq(env.TMF_ClearButton:GetAttribute("type"), "macro", "clear key is a macro")
    t.eq(env.TMF_ClearButton:GetAttribute("macrotext"), "/click TMF_ClearAll\n/click TMF_Follow1",
        "clear key: clear all, then the follow mark")
    t.eq(env.TMF_ClearAll:GetAttribute("action"), "clear-all", "clear-all button")
    for _, e in ipairs(TMF.Planner.plan.entries) do
        t.ok(e.icon ~= 1, "star never planned on a mob (" .. e.rec.token .. ")")
    end
    for i = 1, 8 do
        t.ok(env.TMF_CycleButton:GetAttribute("cyc" .. i) ~= 1, "cycle key never hands out star")
    end
    t.ok(not table.concat(Team:GetLadder(), ","):find("1"), "star not in the kill ladder")

    -- Another group member: their party token.
    Team:CycleRole(7)
    Team:CycleRole(7)
    rows[7].player = "Lumen Brightwater"
    TMF.Plates.Changed()
    sim:Advance(1)
    -- Buttons follow the setup row order: circle (row 7) first, then star (row 8).
    t.eq(env.TMF_Follow1:GetAttribute("unit"), "party1", "a group member's follow mark")
    t.eq(env.TMF_Follow1:GetAttribute("marker"), 2, "circle")
    t.eq(env.TMF_Follow2:GetAttribute("unit"), "player", "yours next")
    t.eq(env.TMF_ClearButton:GetAttribute("macrotext"), "/click TMF_ClearAll\n/click TMF_Follow1\n/click TMF_Follow2",
        "clear key puts both back")
    local lines = Team:BuildAnnouncement()
    t.eq(lines[#lines], "[TankMark] Follow: {rt2} Lumen, {rt1} Tankard", "follow line")

    -- HUD: a Follow section; switching it off stops the re-marking.
    local hud = env.TankMarkForeverHUD
    t.ok(hud.headers.FOLLOW:IsShown(), "Follow header in the HUD")
    Team:ToggleOff(8)
    sim:Advance(1)
    t.eq(env.TMF_ClearButton:GetAttribute("macrotext"), "/click TMF_ClearAll\n/click TMF_Follow1",
        "only the follow mark that's on comes back")
    t.eq(env.TMF_Follow1:GetAttribute("unit"), "party1", "the remaining follow mark")
    lines = Team:BuildAnnouncement()
    t.eq(lines[#lines], "[TankMark] Follow: {rt2} Lumen", "an off follow mark isn't announced")
    Team:AllOn()

    -- Disabled: the clear key only clears.
    TMF:Disable()
    t.eq(env.TMF_ClearButton:GetAttribute("macrotext"), "/click TMF_ClearAll", "disabled: plain clear")
    t.eq(env.TMF_Follow1:GetAttribute("action"), "none", "disabled: no follow marks")
    TMF:Enable()

    -- Lock: the title bar stops dragging; the state is saved.
    local moved = 0
    rawset(hud, "StartMoving", function() moved = moved + 1 end)
    hud.lock:Click()
    t.eq(env.TankMarkForeverDB.hud.locked, true, "locked (saved)")
    hud.title:GetScript("OnDragStart")(hud.title)
    t.eq(moved, 0, "locked: no drag")
    hud.lock:Click()
    t.eq(env.TankMarkForeverDB.hud.locked, nil, "unlocked")
    hud.title:GetScript("OnDragStart")(hud.title)
    t.eq(moved, 1, "unlocked: drags")

    for _, line in ipairs(sim.output) do
        t.ok(not line:find("Error in"), "no handler error: " .. line)
    end
end
