local Transmog = _G.Transmog
local TransmogFrame_Find = string.find
local TransmogFrame_ToNumber = tonumber

-- Extracts item ID from an item link string.
function Transmog:IDFromLink(link)
    local itemSplit = TransmogFrame_Explode(link, ':')
    if itemSplit[2] and TransmogFrame_ToNumber(itemSplit[2]) then
        return TransmogFrame_ToNumber(itemSplit[2])
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
function TransmogFrame_Explode(str, delimiter)
    local result = {}
    local from = 1
    local delim_from, delim_to = TransmogFrame_Find(str, delimiter, from, 1, true)
    while delim_from do
        table.insert(result, string.sub(str, from, delim_from - 1))
        from = delim_to + 1
        delim_from, delim_to = TransmogFrame_Find(str, delimiter, from, true)
    end
    table.insert(result, string.sub(str, from))
    return result
end
