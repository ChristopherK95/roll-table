local _, ns = ...

local MAX_HEIGHT = 400

-- The two looks the window can take. Sizes are in pixels; fonts are the game's font objects.
local STYLES = {
    -- A plain dark box.
    minimal = {
        width = 280, top = 22, side = 6, bottom = 6, inset = 0, gap = 4,
        headerHeight = 20, rowHeight = 15, iconSize = 16, indent = 18, rollWidth = 28,
        headerFont = "GameFontHighlightSmall", rowFont = "GameFontHighlightSmall",
    },
    -- Like the game's own windows: stone border, rock background, portrait, boxed sections.
    blizzard = {
        -- minHeight is measured from the border when the window is made.
        width = 320, top = 60, side = 8, bottom = 8, inset = 6, gap = 4, minHeight = 0,
        headerHeight = 24, rowHeight = 18, iconSize = 20, indent = 24, rollWidth = 32,
        headerFont = "GameFontNormal", rowFont = "GameFontHighlight",
    },
}

local CHOICE_ORDER = { need = 1, greed = 2, pass = 3 }
local CHOICE_LABEL = {
    need = "|TInterface\\Buttons\\UI-GroupLoot-Dice-Up:14:14|t",
    greed = "|TInterface\\Buttons\\UI-GroupLoot-Coin-Up:14:14|t",
    pass = "|cff808080" .. (PASS or "Pass") .. "|r",
}
local WINNER_ICON = "Interface\\RaidFrame\\ReadyCheck-Ready"
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local PORTRAIT_ICON = "Interface\\Icons\\INV_Misc_Dice_02"

local frame, scroll, content, thumb, emptyText
local minimalChrome, blizzardChrome
local style = STYLES.minimal
local headers, rows, sections = {}, {}, {}
local autoOpened = false
local closeTimer

local function ColorName(entry)
    local color = entry.class and RAID_CLASS_COLORS[entry.class]
    return color and color:WrapTextInColorCode(entry.name) or entry.name
end

local function IsCollapsed(drop)
    if drop.collapsed ~= nil then return drop.collapsed end
    return drop.ended
end

local function Status(drop)
    if drop.allPassed then return "|cff808080All passed|r" end
    for _, entry in pairs(drop.rolls) do
        if entry.winner then
            local text = ColorName(entry)
            if entry.roll then
                text = text .. " " .. CHOICE_LABEL[entry.choice or "need"] .. " " .. entry.roll
            end
            return text
        end
    end
    if drop.ended then return "|cff808080Ended|r" end
    -- Past the countdown the roll is still open until its result arrives.
    local left = drop.deadline and math.ceil(drop.deadline - GetTime())
    if left and left > 0 then
        return ("|cffffffff%ds|r"):format(left)
    end
    return "|cffffffffRolling...|r"
end

local function SortedRolls(drop)
    local list = {}
    for _, entry in pairs(drop.rolls) do
        if entry.choice then list[#list + 1] = entry end
    end
    table.sort(list, function(a, b)
        local orderA, orderB = CHOICE_ORDER[a.choice], CHOICE_ORDER[b.choice]
        if orderA ~= orderB then return orderA < orderB end
        local rollA, rollB = a.roll or -1, b.roll or -1
        if rollA ~= rollB then return rollA > rollB end
        return a.name < b.name
    end)
    return list
end

local function UpdateThumb()
    local range = scroll:GetVerticalScrollRange()
    if range <= 0 then
        thumb:Hide()
        return
    end
    local visible = scroll:GetHeight()
    local height = math.max(16, visible * visible / (visible + range))
    local offset = (visible - height) * scroll:GetVerticalScroll() / range
    thumb:SetHeight(height)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", style.side - 2, -offset)
    thumb:Show()
end

local function GetHeader(index)
    local header = headers[index]
    if header then return header end

    header = CreateFrame("Button", nil, content)
    header:RegisterForClicks("LeftButtonUp")

    local highlight = header:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.06)

    header.toggle = header:CreateTexture(nil, "ARTWORK")
    header.toggle:SetSize(10, 10)
    header.toggle:SetPoint("LEFT", 1, 0)

    header.icon = header:CreateTexture(nil, "ARTWORK")
    header.icon:SetPoint("LEFT", header.toggle, "RIGHT", 4, 0)
    header.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    header.status = header:CreateFontString(nil, "OVERLAY")
    header.status:SetPoint("RIGHT", -2, 0)
    header.status:SetJustifyH("RIGHT")

    header.item = header:CreateFontString(nil, "OVERLAY")
    header.item:SetPoint("LEFT", header.icon, "RIGHT", 4, 0)
    header.item:SetPoint("RIGHT", header.status, "LEFT", -6, 0)
    header.item:SetJustifyH("LEFT")
    header.item:SetWordWrap(false)

    header:SetScript("OnClick", function(self)
        if IsModifiedClick() then
            HandleModifiedItemClick(self.drop.link)
        else
            self.drop.collapsed = not IsCollapsed(self.drop)
            ns.Refresh()
        end
    end)
    header:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetHyperlink(self.drop.link)
        GameTooltip:Show()
    end)
    header:SetScript("OnLeave", GameTooltip_Hide)

    headers[index] = header
    return header
end

local function GetRow(index)
    local row = rows[index]
    if row then return row end

    row = CreateFrame("Frame", nil, content)

    row.roll = row:CreateFontString(nil, "OVERLAY")
    row.roll:SetPoint("RIGHT", -2, 0)
    row.roll:SetJustifyH("RIGHT")

    row.winner = row:CreateTexture(nil, "ARTWORK")
    row.winner:SetSize(12, 12)
    row.winner:SetTexture(WINNER_ICON)

    row.choice = row:CreateFontString(nil, "OVERLAY")
    row.choice:SetJustifyH("RIGHT")

    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetPoint("RIGHT", row.choice, "LEFT", -4, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    rows[index] = row
    return row
end

-- The box drawn behind each item in the Blizzard look.
local function GetSection(index)
    local section = sections[index]
    if not section then
        section = CreateFrame("Frame", nil, content, "InsetFrameTemplate")
        sections[index] = section
    end
    return section
end

local function PlaceHeader(header, y, width)
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", style.inset, -y)
    header:SetSize(width, style.headerHeight)
    header.icon:SetSize(style.iconSize, style.iconSize)
    header.item:SetFontObject(style.headerFont)
    header.status:SetFontObject(style.rowFont)
end

local function PlaceRow(row, y, width)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", style.inset, -y)
    row:SetSize(width, style.rowHeight)
    row.roll:SetWidth(style.rollWidth)
    row.winner:ClearAllPoints()
    row.winner:SetPoint("RIGHT", -(style.rollWidth + 4), 0)
    row.choice:ClearAllPoints()
    row.choice:SetPoint("RIGHT", -(style.rollWidth + 20), 0)
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", style.indent, 0)
    row.name:SetPoint("RIGHT", row.choice, "LEFT", -4, 0)
    for _, text in ipairs({ row.roll, row.choice, row.name }) do
        text:SetFontObject(style.rowFont)
    end
end

function ns.Refresh()
    if not frame or not frame:IsShown() then return end
    local boxed = style.inset > 0
    local width = content:GetWidth() - style.inset * 2
    local y, headerCount, rowCount = 0, 0, 0

    for i = #ns.drops, 1, -1 do
        local drop = ns.drops[i]
        local collapsed = IsCollapsed(drop)
        local top = y
        y = y + style.inset / 2

        headerCount = headerCount + 1
        local header = GetHeader(headerCount)
        header.drop = drop
        PlaceHeader(header, y, width)
        header.toggle:SetTexture(collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
        header.icon:SetTexture(drop.itemID and C_Item.GetItemIconByID(drop.itemID) or UNKNOWN_ICON)
        header.item:SetText(drop.link)
        header.status:SetText(Status(drop))
        header:Show()
        y = y + style.headerHeight

        if not collapsed then
            local list = SortedRolls(drop)
            for _, entry in ipairs(list) do
                rowCount = rowCount + 1
                local row = GetRow(rowCount)
                PlaceRow(row, y, width)
                row.name:SetText(ColorName(entry))
                row.choice:SetText(CHOICE_LABEL[entry.choice])
                row.roll:SetText(entry.roll and (entry.winner and "|cffffd100" .. entry.roll .. "|r" or entry.roll) or "")
                row.winner:SetShown(entry.winner == true)
                row:Show()
                y = y + style.rowHeight
            end
            if #list == 0 then
                rowCount = rowCount + 1
                local row = GetRow(rowCount)
                PlaceRow(row, y, width)
                row.name:SetText("|cff808080Waiting for choices...|r")
                row.choice:SetText("")
                row.roll:SetText("")
                row.winner:Hide()
                row:Show()
                y = y + style.rowHeight
            end
        end

        y = y + style.inset / 2
        if boxed then
            local section = GetSection(headerCount)
            section:ClearAllPoints()
            section:SetPoint("TOPLEFT", 0, -top)
            section:SetPoint("TOPRIGHT", 0, -top)
            section:SetHeight(y - top)
            section:Show()
        end
        y = y + style.gap
    end

    for i = headerCount + 1, #headers do headers[i]:Hide() end
    for i = rowCount + 1, #rows do rows[i]:Hide() end
    for i = (boxed and headerCount or 0) + 1, #sections do sections[i]:Hide() end

    local active = ns.ActiveCount()
    blizzardChrome.summary:SetText(headerCount == 0 and "No rolls yet."
        or active == 0 and "No active rolls"
        or active == 1 and "1 active roll" or (active .. " active rolls"))

    -- The Blizzard look already says so beside the portrait.
    local empty = headerCount == 0 and not boxed
    emptyText:SetShown(empty)
    if empty then y = 20 end
    content:SetHeight(y)
    frame:SetHeight(math.max(style.minHeight or 0, math.min(style.top + y + style.bottom, MAX_HEIGHT)))
    UpdateThumb()
end

-- Several changes in one frame redraw the window once.
local refreshPending = false
function ns.Changed()
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(0, function()
        refreshPending = false
        ns.Refresh()
    end)
end

local function CancelClose()
    if closeTimer then
        closeTimer:Cancel()
        closeTimer = nil
    end
end

-- auto is true when a roll opened the window; only then does it close itself again.
function ns.ShowWindow(auto)
    CancelClose()
    if not frame:IsShown() then
        autoOpened = auto or false
        frame:Show()
    elseif not auto then
        autoOpened = false
    end
    ns.Refresh()
end

function ns.HideWindow()
    CancelClose()
    frame:Hide()
end

function ns.ToggleWindow()
    if frame:IsShown() then
        ns.HideWindow()
    else
        ns.ShowWindow(false)
    end
end

function ns.OnDropStarted()
    ns.ShowWindow(true)
end

function ns.OnDropEnded()
    if not autoOpened or not frame:IsShown() or ns.ActiveCount() > 0 or ns.db.closeDelay <= 0 then return end
    CancelClose()
    closeTimer = C_Timer.NewTimer(ns.db.closeDelay, function()
        closeTimer = nil
        if ns.ActiveCount() == 0 then frame:Hide() end
    end)
end

function ns.ApplySettings()
    style = STYLES[ns.db.style] or STYLES.minimal
    minimalChrome:SetShown(style == STYLES.minimal)
    blizzardChrome:SetShown(style == STYLES.blizzard)

    frame:SetWidth(style.width)
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", style.side, -style.top)
    scroll:SetPoint("BOTTOMRIGHT", -style.side, style.bottom)
    content:SetWidth(style.width - style.side * 2)
    emptyText:SetPoint("TOPLEFT", style.inset + 2, -4)

    frame:SetScale(ns.db.scale)
    frame:ClearAllPoints()
    local point = ns.db.point
    if point then
        frame:SetPoint(point[1], UIParent, point[2], point[3], point[4])
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 300, 100)
    end
    ns.Refresh()
end

local function CreateMinimalChrome()
    local chrome = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    chrome:SetAllPoints()
    chrome:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    chrome:SetBackdropColor(0.05, 0.05, 0.05, 0.85)
    chrome:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)

    local title = chrome:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", 8, -7)
    title:SetText("Roll Table")

    local close = CreateFrame("Button", nil, chrome, "UIPanelCloseButton")
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", -1, -1)
    close:SetScript("OnClick", ns.HideWindow)
    return chrome
end

local function CreateBlizzardChrome()
    local chrome = CreateFrame("Frame", nil, frame, "PortraitFrameTemplate")
    chrome:SetAllPoints()
    chrome:SetTitle("Roll Table")
    chrome:SetPortraitToAsset(PORTRAIT_ICON)
    chrome.CloseButton:SetScript("OnClick", ns.HideWindow)

    -- The left and right border strips run between the top and bottom corner pieces. On a
    -- window shorter than both corners together they flip and draw over the portrait.
    -- The corners stick out 16 px above and 3 px below the window (see the game's
    -- PortraitFrameTemplate border layout).
    local corners = chrome.NineSlice
    local top = corners.TopLeftCorner and corners.TopLeftCorner:GetHeight() or 0
    local bottom = corners.BottomLeftCorner and corners.BottomLeftCorner:GetHeight() or 0
    STYLES.blizzard.minHeight = math.max(100, (top - 16) + (bottom - 3) + 4)

    -- The strip beside the portrait, under the title bar.
    chrome.summary = chrome:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    chrome.summary:SetPoint("TOPLEFT", 64, -32)
    return chrome
end

function ns.CreateWindow()
    frame = CreateFrame("Frame", "RollTableFrame", UIParent)
    frame:SetSize(STYLES.minimal.width, 100)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if not ns.db.locked then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetUserPlaced(false)
        local point, _, relativePoint, x, y = self:GetPoint()
        ns.db.point = { point, relativePoint, x, y }
    end)
    frame:Hide()

    minimalChrome = CreateMinimalChrome()
    blizzardChrome = CreateBlizzardChrome()

    -- The list sits above both looks' backgrounds.
    scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetFrameLevel(frame:GetFrameLevel() + 10)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local offset = self:GetVerticalScroll() - delta * style.rowHeight * 3
        self:SetVerticalScroll(math.max(0, math.min(offset, self:GetVerticalScrollRange())))
        UpdateThumb()
    end)
    scroll:SetScript("OnScrollRangeChanged", function(self, _, range)
        if self:GetVerticalScroll() > range then self:SetVerticalScroll(range) end
        UpdateThumb()
    end)

    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(STYLES.minimal.width, 1)
    scroll:SetScrollChild(content)

    -- Drawn just right of the list, outside the area the list clips to.
    local thumbHolder = CreateFrame("Frame", nil, frame)
    thumbHolder:SetAllPoints()
    thumbHolder:SetFrameLevel(scroll:GetFrameLevel() + 1)
    thumb = thumbHolder:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(1, 1, 1, 0.25)
    thumb:SetWidth(3)
    thumb:Hide()

    emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetText("No rolls yet.")

    ns.ApplySettings()
end
