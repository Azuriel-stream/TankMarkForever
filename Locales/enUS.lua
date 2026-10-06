local ADDON_NAME, TMF = ...
local L = TMF:NewLocale("enUS")
if not L then return end

-- Key bindings (Key Bindings > AddOns)
BINDING_HEADER_TANKMARKFOREVER = "TankMark Forever"
_G["BINDING_NAME_CLICK TMF_PackButton:LeftButton"] = "Mark planned pack"
_G["BINDING_NAME_CLICK TMF_SkullButton:LeftButton"] = "Next skull on target"
_G["BINDING_NAME_CLICK TMF_CycleButton:LeftButton"] = "Next free icon on target"
_G["BINDING_NAME_CLICK TMF_ClearButton:LeftButton"] = "Clear all marks"

L["ADDON_LOADED"] = "v%s loaded. Bind the keys under Key Bindings > AddOns, or type /tmf."
L["ADDON_ENABLED"] = "Enabled."
L["ADDON_DISABLED"] = "Disabled."

L["ICON_1"] = "Star"
L["ICON_2"] = "Circle"
L["ICON_3"] = "Diamond"
L["ICON_4"] = "Triangle"
L["ICON_5"] = "Moon"
L["ICON_6"] = "Square"
L["ICON_7"] = "Cross"
L["ICON_8"] = "Skull"

L["ROLE_CASTER"] = "caster"
L["ROLE_HEALER"] = "healer"
L["ROLE_MELEE"] = "melee"

L["PLAN_EMPTY"] = "No hostile mobs to plan."
L["PLAN_HEADER"] = "Pack plan (%d):"
L["PLAN_LINE"] = "  %s %s"
L["PLAN_OVERFLOW"] = "  %d more without an icon."
L["PLAN_FROZEN"] = "In combat: the plan is frozen until combat ends."
L["SELECT_ADDED"] = "Added to the pack (%d selected). Clear key or /tmf select clear resets."
L["SELECT_CLEARED"] = "Pack selection cleared."

L["LEARN_USAGE"] = "Usage: /tmf learn <1-9|ignore|cc> [icon 1-8]  (hover or target the mob)"
L["LEARN_NO_UNIT"] = "Hover or target a hostile mob first."
L["LEARN_SAVED"] = "Learned %s: %s"
L["LEARN_FORGOT"] = "Forgot %s."
L["LEARN_NOT_FOUND"] = "Nothing learned for %s."

L["KEY_UNBOUND"] = "|cffff6060not bound|r"
L["COMBAT_LOCKED"] = "Leave combat first."

L["STATUS_HEADER"] = "Status:"
L["STATUS_ENABLED"] = "  Enabled: %s, overlay: %s, Shift-hover selects: %s"
L["STATUS_KEYS"] = "  Keys: pack %s, skull %s, cycle %s, clear %s"
L["STATUS_ZONE"] = "  Zone: %s (%s), learned here: %d by name, %d by signature"

L["DEBUG_NONE"] = "No blocked actions recorded."
L["DEBUG_LAST"] = "Last %s: %s"

L["HELP"] = {
    "/tmf - this help",
    "/tmf plan - print the current pack plan",
    "/tmf select clear - clear the Shift-hover pack selection",
    "/tmf learn <1-9|ignore|cc> [icon] - teach the hovered/targeted mob (kill priority 1 = first)",
    "/tmf forget - forget the hovered/targeted mob",
    "/tmf overlay - toggle the planned-icon preview above nameplates",
    "/tmf on | off - enable or disable",
    "/tmf status | debug - status / last blocked action",
    "/tmf debug on | off - trace key presses and plate changes (saved for review after /reload)",
}
