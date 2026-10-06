-- The setup window opens on the first /tmf and closes on the second.
local H = require("helpers")

return function(_, t)
    local sim = t.fresh(function(s) H.install(s) end)
    sim:Slash("/tmf")
    local panel = sim.env.TankMarkForeverSetupPanel
    t.ok(panel and panel:IsShown(), "first /tmf opens the window")
    sim:Slash("/tmf")
    t.ok(not panel:IsShown(), "second /tmf closes it")
end
