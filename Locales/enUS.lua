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

L["LEARN_USAGE"] = "Usage: /tmf learn <1-9|ignore|cc> [icon 1-8 | cc class]  (hover or target the mob)"
L["LEARN_NO_UNIT"] = "Hover or target a hostile mob first."
L["LEARN_SAVED"] = "Learned %s: %s"
L["LEARN_FORGOT"] = "Forgot %s."
L["LEARN_NOT_FOUND"] = "Nothing learned for %s."

-- Team setup
L["SETUP_TITLE"] = "TankMark Forever"
L["SETUP_HEADER"] = "Team setup: kill order (top first) and CC"
L["ROLE_KILL"] = "Kill"
L["ROLE_CC"] = "CC"
L["ROLE_OFF"] = "Off"
L["SETUP_ROLE"] = "Role"
L["SETUP_ROLE_DESC"] = "Click to cycle: Kill (in the kill order shown on the left), CC (needs a player), Off (icon not used)."
L["SETUP_PLAYER"] = "Player"
L["SETUP_PLAYER_DESC"] = "Click to cycle through your group, right-click to clear. Kill: the tank who owns this icon (optional; skipped while dead). CC: who crowd-controls it."
L["SETUP_ANYONE"] = "anyone"
L["SETUP_NEEDS_PLAYER"] = "pick a player"
L["BTN_UP"] = "Up"
L["BTN_DOWN"] = "Down"
L["BTN_ANNOUNCE"] = "Announce"
L["BTN_ANNOUNCE_DESC"] = "Post the kill order and CC assignments to party/raid chat (/tmf announce)."
L["BTN_RESET"] = "Reset"
L["OPT_ENABLED"] = "Enable TankMark"
L["OPT_ENABLED_DESC"] = "Plan packs and arm the marking keys."
L["OPT_OVERLAY"] = "Show planned icons"
L["OPT_OVERLAY_DESC"] = "Faint icons above nameplates show what the pack key will mark."
L["OPT_SHIFT"] = "Shift-hover selects a pack"
L["OPT_SHIFT_DESC"] = "Out of combat, Shift + hover adds mobs to the pack; only selected mobs are planned. The clear key resets it."

-- Announcement ({rtN} turns into raid icons in chat)
L["ANNOUNCE_PREFIX"] = "[TankMark]"
L["ANNOUNCE_KILL"] = "Kill order:"
L["ANNOUNCE_CC"] = "CC:"
L["ANNOUNCE_SOLO"] = "Not in a group; the announcement would be: %s"
L["ANNOUNCE_FAILED"] = "Couldn't send the announcement (%s): %s"
L["CC_MAGE"] = "Polymorph"
L["CC_ROGUE"] = "Sap"
L["CC_WARLOCK"] = "Banish/Fear"
L["CC_HUNTER"] = "Trap"
L["CC_PRIEST"] = "Shackle"
L["CC_DRUID"] = "Hibernate"
L["CC_SHAMAN"] = "Hex"

L["KEY_UNBOUND"] = "|cffff6060not bound|r"
L["COMBAT_LOCKED"] = "Leave combat first."

L["STATUS_HEADER"] = "Status:"
L["STATUS_ENABLED"] = "  Enabled: %s, overlay: %s, Shift-hover selects: %s"
L["STATUS_KEYS"] = "  Keys: pack %s, skull %s, cycle %s, clear %s"
L["STATUS_ZONE"] = "  Zone: %s (%s), learned here: %d by name, %d by signature"

L["DEBUG_NONE"] = "No blocked actions recorded."
L["DEBUG_LAST"] = "Last %s: %s"

L["HELP"] = {
    "/tmf - open the team setup (kill order, CC)",
    "/tmf announce - post the kill order and CC to party/raid",
    "/tmf plan - print the current pack plan",
    "/tmf select clear - clear the Shift-hover pack selection",
    "/tmf learn <1-9|ignore|cc> [icon|class] - teach the hovered/targeted mob (kill priority 1 = first)",
    "/tmf forget - forget the hovered/targeted mob",
    "/tmf overlay - toggle the planned-icon preview above nameplates",
    "/tmf on | off - enable or disable",
    "/tmf help - this help",
    "/tmf status | debug - status / last blocked action",
    "/tmf debug on | off - trace key presses and plate changes (saved for review after /reload)",
}
