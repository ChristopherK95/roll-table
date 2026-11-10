local _, ns = ...

-- Every item being rolled on, oldest first. Finished items stay as history.
local drops = {}
ns.drops = drops
ns.events = {}

local HISTORY_SIZE = 10
-- How long an item without a known timer stays open if its result never shows up.
local DEFAULT_ROLL_SECONDS = 180
-- How long to wait for the result message once the game says a roll is over.
local END_GRACE = 5
-- Results can arrive just after a roll times out; they still belong to that item.
local LATE_RESULT_SECONDS = 10
-- How far apart the loot history and the chat can report the same item.
local MATCH_SECONDS = 300

local ticker

local function ItemID(link)
    return link and tonumber(link:match("item:(%d+)"))
end

local function ShortName(name)
    name = name:gsub("|Hplayer:.-|h%[?(.-)%]?|h", "%1")
    return Ambiguate(name, "none")
end

-- Forever characters can have a surname. The loot history gives the full "Mokkan Rainleaf" while
-- the chat and UnitName give just "Mokkan", so players are told apart by their first name.
local function NameKey(name)
    return name:match("^%S+") or name
end

local function UnitIs(unit, name)
    return UnitExists(unit) and NameKey(ShortName(GetUnitName(unit, true))) == NameKey(name)
end

local function ClassOf(name)
    local test = ns.testClasses and ns.testClasses[NameKey(name)]
    if test then return test end
    if UnitIs("player", name) then return select(2, UnitClass("player")) end
    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, GetNumGroupMembers() do
        local unit = prefix .. i
        if UnitIs(unit, name) then return select(2, UnitClass(unit)) end
    end
end

local function FindAny(test)
    for _, drop in ipairs(drops) do
        if test(drop) then return drop end
    end
end

-- The oldest item of this kind that passes the test.
local function Find(itemID, test)
    return FindAny(function(drop) return drop.itemID == itemID and test(drop) end)
end

-- Like Find, but falls back to an item that finished a moment ago.
local function FindOpen(itemID, test)
    local now = GetTime()
    return Find(itemID, function(drop) return not drop.ended and test(drop) end)
        or Find(itemID, function(drop)
            return drop.ended and now - drop.endedAt < LATE_RESULT_SECONDS and test(drop)
        end)
end

local function Always() return true end

local function Trim()
    local ended = 0
    for i = #drops, 1, -1 do
        if drops[i].ended then
            ended = ended + 1
            if ended > HISTORY_SIZE then table.remove(drops, i) end
        end
    end
end

local function GetEntry(drop, name)
    return drop.rolls[NameKey(name)]
end

-- Shows the fullest name any source has given for the player.
local function Entry(drop, name)
    local entry = GetEntry(drop, name)
    if not entry then
        entry = { name = name, class = ClassOf(name) }
        drop.rolls[NameKey(name)] = entry
    elseif #name > #entry.name then
        entry.name = name
    end
    entry.class = entry.class or ClassOf(name)
    return entry
end

local function EndDrop(drop, allPassed)
    if drop.ended then return end
    drop.ended, drop.endedAt, drop.allPassed = true, GetTime(), allPassed or false
    Trim()
    ns.OnDropEnded(drop)
end

local function Tick()
    local now, active = GetTime(), false
    local historyNow = C_LootHistory and C_LootHistory.GetLootHistoryTime and C_LootHistory.GetLootHistoryTime()
    for _, drop in ipairs(drops) do
        if not drop.ended then
            if drop.historyEnd and historyNow and historyNow >= drop.historyEnd then
                drop.historyEnd = nil
                drop.expires = math.min(drop.expires, now + END_GRACE)
            end
            if now >= drop.expires then
                EndDrop(drop)
            else
                active = true
            end
        end
    end
    if not active and ticker then
        ticker:Cancel()
        ticker = nil
    end
    ns.Changed()
end

function ns.ActiveCount()
    local count = 0
    for _, drop in ipairs(drops) do
        if not drop.ended then count = count + 1 end
    end
    return count
end

-- Starts tracking an item. With seconds, the roll's real length is known and is shown.
function ns.NewDrop(link, seconds)
    local drop = {
        link = link, itemID = ItemID(link), rolls = {},
        started = GetTime(), expires = GetTime() + (seconds or DEFAULT_ROLL_SECONDS),
        timed = seconds ~= nil,
    }
    drops[#drops + 1] = drop
    Trim()
    if not ticker then ticker = C_Timer.NewTicker(1, Tick) end
    ns.OnDropStarted(drop)
    return drop
end

function ns.HandleLootMessage(message)
    local m = ns.ParseLootMessage(message)
    local itemID = m and ItemID(m.item)
    if not itemID then return end
    local name = m.player and ShortName(m.player)

    -- A player choosing on an item that already has their choice means a second copy of the
    -- item, unless that item already shows exactly this: the loot history often reports a
    -- choice or roll before the chat repeats it.
    if m.kind == "choice" and name then
        local drop = FindOpen(itemID, function(d) return not (GetEntry(d, name) and GetEntry(d, name).choice) end)
            or FindOpen(itemID, function(d)
                local entry = GetEntry(d, name)
                return d.historyKey and entry and entry.choice == m.choice
            end)
            or ns.NewDrop(m.item)
        Entry(drop, name).choice = m.choice
    elseif m.kind == "roll" and name then
        local drop = FindOpen(itemID, function(d)
                local entry = GetEntry(d, name)
                return entry and entry.choice == m.choice and not entry.roll
            end)
            or FindOpen(itemID, function(d) return not GetEntry(d, name) end)
            or FindOpen(itemID, function(d)
                local entry = GetEntry(d, name)
                return d.historyKey and entry and entry.choice == m.choice and entry.roll == m.roll
            end)
            or ns.NewDrop(m.item)
        local entry = Entry(drop, name)
        entry.choice, entry.roll = m.choice, m.roll
    elseif m.kind == "won" and name then
        local drop = FindOpen(itemID, function(d) return GetEntry(d, name) end) or FindOpen(itemID, Always)
        if not drop then return end
        local entry = Entry(drop, name)
        entry.winner = true
        entry.choice = entry.choice or m.choice
        entry.roll = entry.roll or m.roll
        EndDrop(drop)
    elseif m.kind == "allpassed" then
        local drop = FindOpen(itemID, Always)
        if not drop then return end
        EndDrop(drop, true)
    end
    ns.Changed()
end

function ns.events.CHAT_MSG_LOOT(message)
    ns.HandleLootMessage(message)
end

-- A roll popup for us. This is the only source that knows the roll's real length.
function ns.events.START_LOOT_ROLL(rollID, rollTime)
    local link = GetLootRollItemLink(rollID)
    if not link or FindAny(function(d) return d.rollID == rollID end) then return end
    local seconds = rollTime / 1000
    local now = GetTime()
    -- Another source may have reported this item a moment earlier.
    local drop = Find(ItemID(link), function(d) return not d.ended and not d.rollID and now - d.started < 5 end)
    if drop then
        drop.expires, drop.timed = now + seconds, true
    else
        drop = ns.NewDrop(link, seconds)
    end
    drop.rollID = rollID
    ns.Changed()
end

-- The game closes the popup when the roll is over; the result message follows shortly.
function ns.events.CANCEL_LOOT_ROLL(rollID)
    local drop = FindAny(function(d) return d.rollID == rollID and not d.ended end)
    if drop then drop.expires = math.min(drop.expires, GetTime() + END_GRACE) end
end

local STATE_CHOICE = {}
if Enum.EncounterLootDropRollState then
    local state = Enum.EncounterLootDropRollState
    STATE_CHOICE = {
        [state.NeedMainSpec] = "need", [state.NeedOffSpec] = "need",
        [state.Greed] = "greed", [state.Transmog] = "greed",
        [state.Pass] = "pass",
    }
end

-- The game's loot history knows every choice, roll and winner exactly, where it covers an item.
function ns.events.LOOT_HISTORY_UPDATE_DROP(encounterID, lootListKey)
    local info = C_LootHistory and C_LootHistory.GetSortedInfoForDrop(encounterID, lootListKey)
    if not info or not info.itemHyperlink then return end
    local key = encounterID .. ":" .. lootListKey
    local now = GetTime()
    local drop = FindAny(function(d) return d.historyKey == key end)
        or Find(ItemID(info.itemHyperlink), function(d) return not d.historyKey and now - d.started < MATCH_SECONDS end)
        or ns.NewDrop(info.itemHyperlink)
    drop.historyKey = key
    if not drop.ended and info.duration and info.duration > 0 then
        drop.historyEnd = info.startTime + info.duration
    end
    for _, roll in ipairs(info.rollInfos or {}) do
        local choice = STATE_CHOICE[roll.state]
        if choice then
            local entry = Entry(drop, ShortName(roll.playerName))
            entry.class = roll.playerClass or entry.class
            entry.choice = choice
            entry.roll = roll.roll or entry.roll
            if roll.isWinner then entry.winner = true end
        end
    end
    if info.winner or info.allPassed then
        EndDrop(drop, info.allPassed)
    end
    ns.Changed()
end
