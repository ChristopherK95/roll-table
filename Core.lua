local ADDON, ns = ...

local DEFAULTS = {
    closeDelay = 30,
    locked = false,
    scale = 1,
    style = "minimal",
}

local events = CreateFrame("Frame")

local function OnLoad()
    RollTableDB = RollTableDB or {}
    for key, value in pairs(DEFAULTS) do
        if RollTableDB[key] == nil then RollTableDB[key] = value end
    end
    RollTableDB.minimap = RollTableDB.minimap or { hide = false }
    ns.db = RollTableDB

    ns.CreateWindow()
    ns.CreateOptions()
    ns.CreateMinimapButton()

    for event in pairs(ns.events) do
        events:RegisterEvent(event)
    end
end

events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... == ADDON then
            self:UnregisterEvent("ADDON_LOADED")
            OnLoad()
        end
    else
        ns.events[event](...)
    end
end)

local function Print(message)
    print("|cffffd100Roll Table:|r " .. message)
end

SLASH_ROLLTABLE1 = "/rolltable"
SlashCmdList.ROLLTABLE = function(input)
    local command = strtrim(input or ""):lower()
    if command == "" then
        ns.ToggleWindow()
    elseif command == "config" then
        ns.OpenOptions()
    elseif command == "minimap" then
        local shown = ns.db.minimap.hide
        ns.SetMinimapShown(shown)
        Print(shown and "minimap button shown." or "minimap button hidden.")
    elseif command == "style" then
        ns.db.style = ns.db.style == "blizzard" and "minimal" or "blizzard"
        ns.ApplySettings()
        Print(ns.db.style == "blizzard" and "Blizzard look." or "minimal look.")
    elseif command == "test" then
        ns.RunTest()
    else
        Print("/rolltable - show or hide the window")
        Print("/rolltable config - open settings")
        Print("/rolltable style - switch between the minimal and Blizzard look")
        Print("/rolltable minimap - show or hide the minimap button")
        Print("/rolltable test - fill the window with made-up rolls")
    end
end
