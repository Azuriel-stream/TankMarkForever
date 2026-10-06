local ADDON_NAME, TMF = ...

-- Pure marking rules, ported from legacy TankMark v0.32 (Core/TankMark_Assignment.lua). No WoW API.
local Rules = {}
TMF.Rules = Rules

-- creatureType -> the classes whose CC is legal on it (race-free).
Rules.CCMap = {
    Humanoid  = { "MAGE", "ROGUE", "WARLOCK", "SHAMAN" },  -- Sap/Polymorph/Fear/Hex
    Beast     = { "MAGE", "DRUID", "HUNTER", "SHAMAN" },   -- Polymorph/Hibernate/Trap/Hex
    Elemental = { "WARLOCK" },                              -- Banish
    Demon     = { "WARLOCK" },                              -- Banish
    Undead    = { "PRIEST" },                               -- Shackle
    Dragonkin = { "DRUID" },                                -- Hibernate
}

function Rules.IsLegalCC(class, creatureType)
    local list = Rules.CCMap[creatureType]
    if not list then return false end
    for _, c in ipairs(list) do
        if c == class then return true end
    end
    return false
end

-- Only non-Troll Shamans lack a CC (Hex).
function Rules.CCRaceEligible(class, race)
    return class ~= "SHAMAN" or race == "Troll"
end

-- Pick a CC mark from the CC slots ({ mark, class, race, alive, used, disabled }), or nil.
-- Pass 1 prefers the authored class if legal; pass 2 takes the first legal slot. Unknown creature type
-- (always the case inside instances) degrades to authored-class-only.
function Rules.SelectCCSlot(authoredClass, creatureType, slots)
    local function eligible(s)
        return s.alive and not s.used and not s.disabled and Rules.CCRaceEligible(s.class, s.race)
    end
    if creatureType and Rules.CCMap[creatureType] then
        if authoredClass and Rules.IsLegalCC(authoredClass, creatureType) then
            for _, s in ipairs(slots) do
                if s.class == authoredClass and eligible(s) then return s.mark end
            end
        end
        for _, s in ipairs(slots) do
            if eligible(s) and Rules.IsLegalCC(s.class, creatureType) then return s.mark end
        end
        return nil
    end
    if authoredClass then
        for _, s in ipairs(slots) do
            if s.class == authoredClass and eligible(s) then return s.mark end
        end
    end
    return nil
end

-- Mob role x tier -> default kill priority (lower = killed first). Legacy DATA-MODEL curve.
local ROLE_PRIO = {
    HEALER = { normal = 2, elite = 1, rare = 1, boss = 1 },
    CASTER = { normal = 3, elite = 2, rare = 2, boss = 1 },
    MELEE  = { normal = 5, elite = 4, rare = 3, boss = 1 },
}
local TIER_BUCKET = {
    normal = "normal", trivial = "normal", minus = "normal",
    elite = "elite",
    rare = "rare", rareelite = "rare",
    worldboss = "boss", boss = "boss",
}
function Rules.RoleTierPrio(role, tier)
    local row = ROLE_PRIO[role] or ROLE_PRIO.MELEE
    return row[TIER_BUCKET[tier] or "normal"]
end

-- How much a mob warrants a scarce CC slot (legacy CC_WORTH curve); 70+ = auto-CC candidate.
local CC_WORTH = {
    HEALER = { normal = 90, elite = 100, rare = 100, boss = 100 },
    CASTER = { normal = 40, elite = 70,  rare = 70,  boss = 80  },
    MELEE  = { normal = 10, elite = 30,  rare = 35,  boss = 40  },
}
function Rules.CCWorthiness(role, tier)
    local row = CC_WORTH[role] or CC_WORTH.MELEE
    return row[TIER_BUCKET[tier] or "normal"]
end

-- Rare and boss mobs are generally immune to player CC.
function Rules.CCTierEligible(tier)
    local bucket = TIER_BUCKET[tier] or "normal"
    return bucket == "normal" or bucket == "elite"
end

Rules.AUTO_CC_FLOOR = 70
function Rules.MeetsAutoCCFloor(role, tier)
    return Rules.CCWorthiness(role, tier) >= Rules.AUTO_CC_FLOOR
end

-- Forever: without a readable identity, a mana bar is the best role hint (casters and healers use mana).
function Rules.RoleFromPower(powerToken)
    if powerToken == "MANA" then return "CASTER" end
    return "MELEE"
end

-- Signature: the readable fingerprint used to learn mobs where names are secret.
function Rules.Signature(level, tier, powerToken)
    return string.format("%s|%s|%s", tostring(level or "?"), tier or "?", powerToken or "?")
end
