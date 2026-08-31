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

-- Owned-mog key: original item id + visible (mog) icon filename.
-- Same base item with different mogs → different keys.
function Transmog:ChromieOwnedKey(itemId, iconPath)
    itemId = itemId and tonumber(itemId)
    local icon = self.ChromieNormIcon and self:ChromieNormIcon(iconPath)
    if not itemId or itemId < 1 or not icon then
        return nil
    end
    return "o:" .. tostring(itemId) .. ":" .. icon
end

function Transmog:ChromieLinkOwnedKey(link, iconPath)
    if not link then
        return nil
    end
    return self:ChromieOwnedKey(self:IDFromLink(link), iconPath)
end

-- Visible inventory texture only (no gossip). Use after a swap so the previous
-- item's gossip icon cannot poison the new item's owned[] key.
function Transmog:ChromieLiveSlotIcon(slot)
    if not slot then
        return nil
    end
    local vis = GetInventoryItemTexture("player", slot)
    if not vis or vis == "" then
        return "hidden"
    end
    local n = string.lower(tostring(vis))
    if string.find(n, "paperdoll", 1, true) or string.find(n, "wowunknownitem", 1, true) then
        return "hidden"
    end
    return vis
end

-- Visible icon for an equipped slot (mog texture, gossip icon, or hidden marker).
function Transmog:ChromieOwnedIconForSlot(slot)
    if not slot then
        return nil
    end
    local gossip = self.transmogGossipIcon and self.transmogGossipIcon[slot]
    if gossip then
        return gossip
    end
    return self:ChromieLiveSlotIcon(slot)
end

function Transmog:ChromieOwnedKeyForSlot(slot, link)
    link = link or (slot and GetInventoryItemLink("player", slot))
    if not link or not slot then
        return nil
    end
    return self:ChromieLinkOwnedKey(link, self:ChromieOwnedIconForSlot(slot))
end

-- Classes whose ranged slot is always a relic (totem/libram/idol/sigil), not transmoggable.
Transmog.relicRangedClasses = {
    druid = true,
    paladin = true,
    shaman = true,
    deathknight = true,
}

function Transmog:ChromieIsRelicLink(link)
    if not link then
        return false
    end
    local invType = select(9, GetItemInfo(link))
    if not invType then
        local itemId = self:IDFromLink(link)
        if itemId and self.cacheItem then
            self:cacheItem(itemId)
            invType = select(9, GetItemInfo(itemId))
        end
    end
    return invType == "INVTYPE_RELIC"
end

function Transmog:ChromieSlotSupportsTransmog(slot)
    if not slot then
        return false
    end
    if slot ~= 18 then
        return true
    end
    if self.relicRangedClasses and self.relicRangedClasses[self.class] then
        return false
    end
    local link = GetInventoryItemLink("player", slot)
    if link and self:ChromieIsRelicLink(link) then
        return false
    end
    return true
end

function Transmog:ChromieShouldHideDressupSlot(slotName)
    if slotName ~= "RangedSlot" then
        return false
    end
    return not self:ChromieSlotSupportsTransmog(18)
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
