local _, ns = ...

-- Loot roll chat messages, by the name of the game's own format string. Several share their
-- wording with a shorter message further down, so the more specific ones must come first.
local MESSAGES = {
    { "LOOT_ROLL_YOU_WON_NO_SPAM_NEED", "won", "need", true },
    { "LOOT_ROLL_YOU_WON_NO_SPAM_GREED", "won", "greed", true },
    { "LOOT_ROLL_YOU_WON_NO_SPAM_TRANSMOG", "won", "greed", true },
    { "LOOT_ROLL_YOU_WON_NO_SPAM_DE", "won", "greed", true },
    { "LOOT_ROLL_WON_NO_SPAM_NEED", "won", "need" },
    { "LOOT_ROLL_WON_NO_SPAM_GREED", "won", "greed" },
    { "LOOT_ROLL_WON_NO_SPAM_TRANSMOG", "won", "greed" },
    { "LOOT_ROLL_WON_NO_SPAM_DE", "won", "greed" },
    { "LOOT_ROLL_YOU_WON", "won", nil, true },
    { "LOOT_ROLL_WON", "won" },
    { "LOOT_ROLL_ALL_PASSED", "allpassed" },

    { "LOOT_ROLL_ROLLED_NEED_ROLE_BONUS", "roll", "need" },
    { "LOOT_ROLL_ROLLED_NEED", "roll", "need" },
    { "LOOT_ROLL_ROLLED_GREED", "roll", "greed" },
    { "LOOT_ROLL_ROLLED_TRANSMOG", "roll", "greed" },
    { "LOOT_ROLL_ROLLED_DE", "roll", "greed" },

    { "LOOT_ROLL_NEED_SELF", "choice", "need", true },
    { "LOOT_ROLL_GREED_SELF", "choice", "greed", true },
    { "LOOT_ROLL_TRANSMOG_SELF", "choice", "greed", true },
    { "LOOT_ROLL_DISENCHANT_SELF", "choice", "greed", true },
    { "LOOT_ROLL_PASSED_SELF_AUTO", "choice", "pass", true },
    { "LOOT_ROLL_PASSED_SELF", "choice", "pass", true },
    { "LOOT_ROLL_NEED", "choice", "need" },
    { "LOOT_ROLL_GREED", "choice", "greed" },
    { "LOOT_ROLL_TRANSMOG", "choice", "greed" },
    { "LOOT_ROLL_DISENCHANT", "choice", "greed" },
    { "LOOT_ROLL_PASSED_AUTO", "choice", "pass" },
    { "LOOT_ROLL_PASSED_AUTO_FEMALE", "choice", "pass" },
    { "LOOT_ROLL_PASSED", "choice", "pass" },
}

-- Walks a format string, calling onText for each literal character and onValue for each
-- placeholder: "s", "d", or "id" for the loot history number the messages start with
-- ("|HlootHistory:%d|h[Loot]|h: %s has selected Need for: %s").
local function Walk(format, onText, onValue)
    local i, length = 1, #format
    while i <= length do
        if format:sub(i, i) == "%" then
            -- "%s", "%d", or the positional "%2$s".
            local kind, stop = format:match("^%d+%$([sd])()", i + 1)
            if not kind then
                kind, stop = format:match("^([sd])()", i + 1)
            end
            if kind then
                if kind == "d" and format:sub(1, i - 1):lower():find("history:$") then kind = "id" end
                onValue(kind)
                i = stop
            else
                onText("%")
                i = i + (format:sub(i + 1, i + 1) == "%" and 2 or 1)
            end
        else
            onText(format:sub(i, i))
            i = i + 1
        end
    end
end

-- Turns a format string into an anchored Lua pattern. Also returns the kind of each capture,
-- in the order the captures appear.
local function Compile(format)
    local parts, kinds = {}, {}
    Walk(format,
        function(c)
            parts[#parts + 1] = c:find("[%^%$%(%)%%%.%[%]%*%+%-%?]") and "%" .. c or c
        end,
        function(kind)
            kinds[#kinds + 1] = kind
            parts[#parts + 1] = kind == "s" and "(.+)" or "(%d+)"
        end)
    return "^" .. table.concat(parts) .. "$", kinds
end

-- Fills a format string the way the game would: strings in the order given, roll for the number.
function ns.FillLootFormat(format, roll, ...)
    local strings, parts = { ... }, {}
    Walk(format,
        function(c) parts[#parts + 1] = c end,
        function(kind)
            if kind == "id" then
                parts[#parts + 1] = "0"
            elseif kind == "d" then
                parts[#parts + 1] = tostring(roll or 0)
            else
                parts[#parts + 1] = table.remove(strings, 1) or ""
            end
        end)
    return table.concat(parts)
end

local compiled = {}
for _, message in ipairs(MESSAGES) do
    local format = _G[message[1]]
    if type(format) == "string" then
        local pattern, kinds = Compile(format)
        compiled[#compiled + 1] = {
            pattern = pattern, kinds = kinds,
            kind = message[2], choice = message[3], self = message[4],
        }
    end
end

-- Reads a loot chat message. Returns nil for anything that isn't about a Need/Greed roll, or a
-- table with kind ("choice", "roll", "won" or "allpassed"), item, and where present player,
-- choice and roll.
function ns.ParseLootMessage(message)
    for _, entry in ipairs(compiled) do
        local captures = { message:match(entry.pattern) }
        if captures[1] then
            local result = { kind = entry.kind, choice = entry.choice }
            -- Telling the arguments apart by their content copes with any argument order.
            for i, value in ipairs(captures) do
                local kind = entry.kinds[i]
                if kind == "d" then
                    result.roll = tonumber(value)
                elseif kind == "id" then
                    -- Not needed: items are matched by their link.
                elseif value:find("|Hitem:") then
                    result.item = value
                else
                    result.player = value
                end
            end
            if entry.self or (result.player and YOU and result.player:lower() == YOU:lower()) then
                result.player = UnitName("player")
            end
            return result
        end
    end
end
