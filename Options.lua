local _, ns = ...

local category

function ns.CreateOptions()
    category = Settings.RegisterVerticalLayoutCategory("Roll Table")

    local function Proxy(key, varType, label, default, onChange)
        return Settings.RegisterProxySetting(category, "RollTable_" .. key, varType, label, default,
            function() return ns.db[key] end,
            function(value)
                ns.db[key] = value
                if onChange then onChange() end
            end)
    end

    local style = Proxy("style", Settings.VarType.String, "Style", "minimal", ns.ApplySettings)
    Settings.CreateDropdown(category, style, function()
        local container = Settings.CreateControlTextContainer()
        container:Add("minimal", "Minimal")
        container:Add("blizzard", "Blizzard")
        return container:GetData()
    end, "Minimal is a plain dark box. Blizzard looks like the game's own windows, such as Professions.")

    local delay = Proxy("closeDelay", Settings.VarType.Number, "Auto-close delay", 30)
    local delayOptions = Settings.CreateSliderOptions(0, 120, 5)
    delayOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
        return value == 0 and "Never" or (value .. " s")
    end)
    Settings.CreateSlider(category, delay, delayOptions,
        "How long the window stays open after the last roll ends. 0 keeps it open.")

    local locked = Proxy("locked", Settings.VarType.Boolean, "Lock position", false)
    Settings.CreateCheckbox(category, locked, "Stops the window from being dragged.")

    local scale = Proxy("scale", Settings.VarType.Number, "Scale", 1, ns.ApplySettings)
    local scaleOptions = Settings.CreateSliderOptions(0.5, 2, 0.05)
    scaleOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
        return math.floor(value * 100 + 0.5) .. "%"
    end)
    Settings.CreateSlider(category, scale, scaleOptions, "The size of the window.")

    -- The minimap button's setting is stored as "hidden", so the checkbox shows its opposite.
    local minimap = Settings.RegisterProxySetting(category, "RollTable_minimap", Settings.VarType.Boolean,
        "Show minimap button", true,
        function() return not ns.db.minimap.hide end,
        function(shown) ns.SetMinimapShown(shown) end)
    Settings.CreateCheckbox(category, minimap, "Shows the Roll Table button on the minimap.")

    Settings.RegisterAddOnCategory(category)
end

function ns.OpenOptions()
    Settings.OpenToCategory(category:GetID())
end

local function OnButtonClick(button)
    if button == "RightButton" then
        ns.OpenOptions()
    else
        ns.ToggleWindow()
    end
end

function ns.CreateMinimapButton()
    local broker = LibStub("LibDataBroker-1.1", true)
    local icon = LibStub("LibDBIcon-1.0", true)
    if not (broker and icon) then return end

    local launcher = broker:NewDataObject("RollTable", {
        type = "launcher",
        text = "Roll Table",
        icon = "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
        OnClick = function(_, button) OnButtonClick(button) end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("Roll Table")
            local active = ns.ActiveCount()
            tooltip:AddLine(active == 1 and "1 active roll" or (active .. " active rolls"), 1, 1, 1)
            tooltip:AddLine(" ")
            tooltip:AddLine("|cffffd100Left-click|r to show or hide the window", 0.8, 0.8, 0.8)
            tooltip:AddLine("|cffffd100Right-click|r to open settings", 0.8, 0.8, 0.8)
        end,
    })
    icon:Register("RollTable", launcher, ns.db.minimap)
end

function ns.SetMinimapShown(shown)
    ns.db.minimap.hide = not shown
    local icon = LibStub("LibDBIcon-1.0", true)
    if not icon then return end
    if shown then icon:Show("RollTable") else icon:Hide("RollTable") end
end

function RollTable_OnAddonCompartmentClick(_, button)
    OnButtonClick(button)
end
