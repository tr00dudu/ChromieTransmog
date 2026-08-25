local Transmog = _G.Transmog
local TransmogFrame_Find = string.find
local TransmogFrame_ToNumber = tonumber

-- Checks whether the player's currently equipped items differ from last known state.
function Transmog:EquippedItemsChanged()
    for _, InventorySlotId in pairs(self.inventorySlots) do
        if GetInventoryItemLink('player', InventorySlotId) then
            local _, _, eqItemLink = TransmogFrame_Find(GetInventoryItemLink('player', InventorySlotId), "(item:%d+:%d+:%d+:%d+)");
            if self.equippedItems[InventorySlotId] ~= self:IDFromLink(eqItemLink) then
                return true
            end
        end
    end
    return false
end

-- Pre-caches all currently equipped items into the client item cache.
function Transmog:CacheEquippedGear()
    for _, InventorySlotId in pairs(self.inventorySlots) do
        if GetInventoryItemLink('player', InventorySlotId) then
            self:cacheItem(GetInventoryItemLink('player', InventorySlotId))
        end
    end
end

-- Pre-caches all items referenced in saved outfits.
function Transmog:CacheOutfitsItems()
    for _, data in pairs(transmogOutfits) do
        for _, itemId in data do
            self:cacheItem(itemId)
        end
    end
end

-- Loads item data into the client cache via GameTooltip, using an item link or raw ID.
function Transmog:cacheItem(linkOrID)

    if not linkOrID then
        twfdebug("cache item call with null " .. type(linkOrID))
    end

    if not linkOrID or linkOrID == 0 then
        twfdebug("cache item call with null2 " .. type(linkOrID))
        return
    end

    if TransmogFrame_ToNumber(linkOrID) then
        if GetItemInfo(linkOrID) then
            return true
        else
            local item = "item:" .. linkOrID .. ":0:0:0"
            local _, _, itemLink = TransmogFrame_Find(item, "(item:%d+:%d+:%d+:%d+)");
            linkOrID = itemLink
        end
    else
        if TransmogFrame_Find(linkOrID, "|", 1, true) then
            local _, _, itemLink = TransmogFrame_Find(linkOrID, "(item:%d+:%d+:%d+:%d+)");
            linkOrID = itemLink
            if GetItemInfo(self:IDFromLink(linkOrID)) then
                return true
            end
        end
    end

    GameTooltip:SetHyperlink(linkOrID)

end
