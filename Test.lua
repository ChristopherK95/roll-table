local _, ns = ...

-- /rolltable test plays a few made-up rolls through the same chat parsing real rolls use.

local PLAYERS = {
    Thrall = "SHAMAN", Jaina = "MAGE", Uther = "PALADIN", Sylvanas = "HUNTER", Valeera = "ROGUE",
}

local function Link(itemID, color, name)
    return ("|cff%s|Hitem:%d::::::::60:::::|h[%s]|h|r"):format(color, itemID, name)
end

-- The game's strings carry extra placeholders (like the loot history number), so they are
-- filled the same way the parser reads them rather than with string.format.
local function Say(at, format, roll, ...)
    if not format then return end
    local message = ns.FillLootFormat(format, roll, ...)
    C_Timer.After(at, function() ns.HandleLootMessage(message) end)
end

function ns.RunTest()
    ns.testClasses = PLAYERS
    local me = UnitName("player")
    local helm = Link(12640, "a335ee", "Lionheart Helm")
    local blade = Link(18832, "a335ee", "Brutality Blade")
    local cape = Link(13340, "0070dd", "Cape of the Black Baron")

    -- Need beats a higher Greed roll.
    ns.NewDrop(helm, 30)
    Say(0.4, LOOT_ROLL_NEED, nil, "Thrall", helm)
    Say(0.8, LOOT_ROLL_GREED, nil, "Jaina", helm)
    Say(1.2, LOOT_ROLL_NEED, nil, "Uther", helm)
    Say(1.6, LOOT_ROLL_PASSED, nil, "Sylvanas", helm)
    Say(2.0, LOOT_ROLL_GREED_SELF, nil, helm)
    Say(4.0, LOOT_ROLL_ROLLED_NEED, 87, helm, "Thrall")
    Say(4.0, LOOT_ROLL_ROLLED_NEED, 42, helm, "Uther")
    Say(4.0, LOOT_ROLL_ROLLED_GREED, 91, helm, "Jaina")
    Say(4.0, LOOT_ROLL_ROLLED_GREED, 12, helm, me)
    Say(4.5, LOOT_ROLL_WON, nil, "Thrall", helm)

    -- Nobody wants it.
    C_Timer.After(1, function() ns.NewDrop(blade, 30) end)
    Say(1.5, LOOT_ROLL_PASSED, nil, "Thrall", blade)
    Say(1.8, LOOT_ROLL_PASSED, nil, "Valeera", blade)
    Say(2.1, LOOT_ROLL_PASSED_SELF, nil, blade)
    Say(3.0, LOOT_ROLL_ALL_PASSED, nil, blade)

    -- Stays open for a while so the countdown shows, then you win it.
    C_Timer.After(5, function() ns.NewDrop(cape, 20) end)
    Say(6, LOOT_ROLL_GREED, nil, "Valeera", cape)
    Say(7, LOOT_ROLL_GREED_SELF, nil, cape)
    Say(8, LOOT_ROLL_PASSED, nil, "Uther", cape)
    Say(12, LOOT_ROLL_ROLLED_GREED, 33, cape, "Valeera")
    Say(12, LOOT_ROLL_ROLLED_GREED, 76, cape, me)
    Say(12.5, LOOT_ROLL_YOU_WON, nil, cape)
end
