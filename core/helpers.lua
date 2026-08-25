local Transmog = _G.ChromieTransmog
local ChromieTransmogFrame_Find = string.find
local ChromieTransmogFrame_ToNumber = tonumber

-- Extracts item ID from an item link string.
function Transmog:IDFromLink(link)
    local itemSplit = ChromieTransmogFrame_Explode(link, ':')
    if itemSplit[2] and ChromieTransmogFrame_ToNumber(itemSplit[2]) then
        return ChromieTransmogFrame_ToNumber(itemSplit[2])
    end
    return nil
end

function Transmog:ChromieLinkUniqueId(link)
    if not link then
        return nil
    end
    local unique = string.match(link, "item:%d+:%d+:%d+:%d+:%d+:%d+:%d+:(%-?%d+)")
    if unique and unique ~= "0" then
        return unique
    end
    return nil
end

-- Returns the number of entries in a table.
function Transmog:tableSize(t)
    if type(t) ~= 'table' then
        twfdebug('t not table')
        return 0
    end
    local size = 0
    for _ in pairs(t) do
        size = size + 1
    end
    return size
end

-- Returns the ceiling of a number.
function Transmog:ceil(num)
    if num > math.floor(num) then
        return math.floor(num + 1)
    end
    return math.floor(num + 0.5)
end

-- Splits a string by delimiter, similar to string.split.
function ChromieTransmogFrame_Explode(str, delimiter)
    local result = {}
    local from = 1
    local delim_from, delim_to = ChromieTransmogFrame_Find(str, delimiter, from, 1, true)
    while delim_from do
        table.insert(result, string.sub(str, from, delim_from - 1))
        from = delim_to + 1
        delim_from, delim_to = ChromieTransmogFrame_Find(str, delimiter, from, true)
    end
    table.insert(result, string.sub(str, from))
    return result
end
