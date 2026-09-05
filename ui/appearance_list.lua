local Transmog = _G.ChromieTransmog
local ChromieTransmogFrame_Find = string.find
local ChromieTransmogFrame_ToNumber = tonumber

-- Updates the collection count label (text only).
function Transmog:setProgressBar(collected, possible)
    ChromieTransmogFrameCollectedText:SetText("Collected: " .. collected)
    ChromieTransmogFrameCollectedText:Show()
end

Transmog.availableTransmogsCacheDelay = CreateFrame("Frame")
Transmog.availableTransmogsCacheDelay:Hide()

Transmog.availableTransmogsCacheDelay.InventorySlotId = 0
Transmog.availableTransmogsCacheDelay.ItemClass = 0

Transmog.availableTransmogsCacheDelay:SetScript("OnShow", function()
    this.startTime = GetTime()
end)

Transmog.availableTransmogsCacheDelay:SetScript("OnUpdate", function()
    local plus = 0.1
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    if gt >= st then
        twfdebug("delay cache: " .. Transmog.availableTransmogsCacheDelay.InventorySlotId)
        Transmog:prepareAvailableTransmogs(Transmog.availableTransmogsCacheDelay.InventorySlotId, Transmog.availableTransmogsCacheDelay.ItemClass)
        Transmog.availableTransmogsCacheDelay:Hide()
    end
end)

-- Processes available transmog data for a slot and item class, building the display list.
function Transmog:prepareAvailableTransmogs(slot, itemClass)
    twfdebug("prepareAvailableTransmogs start slot: " .. slot .. " itemClass: " .. itemClass)

    if not Transmog.availableTransmogItems[slot] then
        Transmog.availableTransmogItems[slot] = {}
    end

    self.availableTransmogItems[slot][itemClass] = {}

    for i, itemID in ipairs(self.transmogDataFromServer[slot][itemClass]) do
        itemID = ChromieTransmogFrame_ToNumber(itemID)
        if not itemID or itemID <= 0 or itemID == self.UNKNOWN_MOG_ID then
            -- skip gossip-only placeholders
        else
            local name, link, quality, level, min_level, class, subclass, _, inv_type, tex = GetItemInfo(itemID)

            local eqItemLink = nil
            local inventoryItemLink = GetInventoryItemLink('player', slot)
            if inventoryItemLink then
                local _, _, eqItemLink2 = ChromieTransmogFrame_Find(inventoryItemLink, "(item:%d+:%d+:%d+:%d+)")
                eqItemLink = eqItemLink2
            end

            if not name then
                self:cacheItem(itemID)
                twfdebug("caching item " .. itemID)
                Transmog.availableTransmogsCacheDelay.InventorySlotId = slot
                Transmog.availableTransmogsCacheDelay.ItemClass = itemClass
                Transmog.availableTransmogsCacheDelay:Show()
                return
            end

            if name then
                local reset = false
                if eqItemLink then
                    reset = itemID == self:IDFromLink(eqItemLink)
                end
                table.insert(self.availableTransmogItems[slot][itemClass], {
                    ['id'] = itemID,
                    ['reset'] = reset,
                    ['name'] = name,
                    ['link'] = link,
                    ['quality'] = quality,
                    ['t1'] = class,
                    ['t2'] = subclass,
                    ['equip_slot'] = inv_type,
                    ['tex'] = tex,
                    ['itemLink'] = eqItemLink
                })
            end
        end
    end

    if Transmog.hideableSlots[slot] then
        local slotLabel = string.gsub(Transmog.inventorySlotNames[slot] or "", " Slot", "")
        table.insert(self.availableTransmogItems[slot][itemClass], 1, {
            ['id'] = Transmog.HIDDEN_ITEM_ID,
            ['reset'] = false,
            ['name'] = "Hidden " .. slotLabel,
            ['link'] = nil,
            ['quality'] = 0,
            ['t1'] = nil,
            ['t2'] = nil,
            ['equip_slot'] = nil,
            ['tex'] = nil,
            ['itemLink'] = nil
        })
    end

    -- Gossip omits the worn base item while mogged. Keep it next to Hide (or first
    -- if the slot cannot hide). reset=true shows the revert overlay; click always undoes.
    local eqId = self.equippedItems and tonumber(self.equippedItems[slot])
    local list = self.availableTransmogItems[slot][itemClass]
    if eqId and eqId > 1 and list then
        local eqEntry = nil
        local j = 1
        while list[j] do
            if list[j].id == eqId then
                eqEntry = table.remove(list, j)
                break
            end
            j = j + 1
        end
        if not eqEntry then
            local name, link, quality, _, _, class, subclass, _, inv_type, tex = GetItemInfo(eqId)
            if not name then
                self:cacheItem(eqId)
                Transmog.availableTransmogsCacheDelay.InventorySlotId = slot
                Transmog.availableTransmogsCacheDelay.ItemClass = itemClass
                Transmog.availableTransmogsCacheDelay:Show()
                return
            end
            local invLink = GetInventoryItemLink("player", slot)
            eqEntry = {
                ['id'] = eqId,
                ['name'] = name,
                ['link'] = link,
                ['quality'] = quality,
                ['t1'] = class,
                ['t2'] = subclass,
                ['equip_slot'] = inv_type,
                ['tex'] = tex,
                ['itemLink'] = invLink,
            }
        end
        eqEntry.reset = true
        local at = 1
        if list[1] and list[1].id == self.HIDDEN_ITEM_ID then
            at = 2
        end
        table.insert(list, at, eqEntry)
    end

    self:ChromieFavoritePinList(list, slot)

    twfdebug("prepareAvailableTransmogs end")
end

function Transmog:ChromieFavoritePinList(list, slot)
    if not list or not slot or not self.ChromieFavoriteSlotList then
        return
    end
    local faves = self:ChromieFavoriteSlotList(slot)
    if not faves or not faves[1] then
        return
    end
    local insertAt = 1
    if list[1] and list[1].id == self.HIDDEN_ITEM_ID then
        insertAt = 2
    end
    if list[insertAt] and list[insertAt].reset then
        insertAt = insertAt + 1
    end
    local placed = 0
    local f = 1
    while faves[f] do
        local want = tonumber(faves[f])
        f = f + 1
        if want and want > 1 then
            local j = 1
            local found = nil
            while list[j] do
                if tonumber(list[j].id) == want and not list[j].reset
                    and list[j].id ~= self.HIDDEN_ITEM_ID then
                    found = table.remove(list, j)
                    break
                end
                j = j + 1
            end
            if found then
                table.insert(list, insertAt + placed, found)
                placed = placed + 1
            end
        end
    end
end

function Transmog:ChromieFavoriteLookClick(itemId)
    local slot = self.currentTransmogSlot
    local itemClass = self.currentTransmogItemClass
    itemId = tonumber(itemId)
    if not slot or not itemClass or not itemId or itemId <= 1 or itemId == self.HIDDEN_ITEM_ID then
        return
    end
    local list = self.availableTransmogItems[slot] and self.availableTransmogItems[slot][itemClass]
    local k = 1
    while list and list[k] do
        if tonumber(list[k].id) == itemId and list[k].reset then
            return
        end
        k = k + 1
    end
    self:ChromieFavoriteToggle(slot, itemId)
    -- Rebuild from gossip/cache order, then pin remaining faves (same as reopen).
    self:prepareAvailableTransmogs(slot, itemClass)
    self:renderAvailableTransmogs(slot, itemClass)
end

function ChromieFavoriteLook_OnClick(itemId)
    if Transmog.ChromieFavoriteLookClick then
        Transmog:ChromieFavoriteLookClick(itemId)
    end
end

-- Renders the grid of transmog item buttons for the currently selected slot.
function Transmog:renderAvailableTransmogs(slot, itemClass)
    twfdebug("renderAvailableTransmogs slot: " .. slot .. " itemClass: " .. itemClass)

    if not self.transmogDataFromServer[slot] then
        return
    end

    self:hideItems(true)
    self:hideItemBorders()

    self:setProgressBar(self:tableSize(self.transmogDataFromServer[slot][itemClass]), self.numTransmogs[slot][itemClass])
    if self:tableSize(self.transmogDataFromServer[slot][itemClass]) == 0 then
        ChromieTransmogFrameNoTransmogs:SetText("You have yet to uncover any kind of appearance for this item. \nThe appearance will unlock after you equip the item.")
        ChromieTransmogFrameNoTransmogs:Show()
    else
        ChromieTransmogFrameNoTransmogs:Hide()
    end

    local index = 0
    local row = 0
    local col = 0
    local itemIndex = 1

    for _, item in ipairs(self.availableTransmogItems[slot][itemClass]) do
        if index >= (self.currentPage - 1) * self.ipp and index < self.currentPage * self.ipp then
            if not self.ItemButtons[itemIndex] then
                self.ItemButtons[itemIndex] = CreateFrame('Frame', 'TransmogLook' .. itemIndex, ChromieTransmogFrame, 'ChromieTransmogFrameLookTemplate')
            end

            self.ItemButtons[itemIndex]:SetPoint("TOPLEFT", ChromieTransmogFrame, "TOPLEFT", 263 + col * 90, -105 - 120 * row)

            self.ItemButtons[itemIndex].name = item.name
            self.ItemButtons[itemIndex].id = item.id

            getglobal('TransmogLook' .. itemIndex .. 'Button'):SetID(item.id)
            getglobal('TransmogLook' .. itemIndex .. 'Button'):RegisterForClicks("LeftButtonUp", "RightButtonUp")
            getglobal('TransmogLook' .. itemIndex .. 'ButtonRevert'):Hide()
            getglobal('TransmogLook' .. itemIndex .. 'ButtonCheck'):Hide()
            local faveTex = getglobal('TransmogLook' .. itemIndex .. 'ButtonFave')
            if faveTex then
                faveTex:Hide()
            end

            if item.id == self.transmogStatusToServer[slot]
                or (item.reset and (not self.transmogStatusToServer[slot] or self.transmogStatusToServer[slot] == 0)) then
                getglobal('TransmogLook' .. itemIndex .. 'Button'):SetNormalTexture('Interface\\AddOns\\ChromieTransmog\\assets\\item_bg_selected')
            else
                getglobal('TransmogLook' .. itemIndex .. 'Button'):SetNormalTexture('Interface\\AddOns\\ChromieTransmog\\assets\\item_bg_normal')
            end

            local _, _, _, color = GetItemQualityColor(item.quality)
            local fave = (not item.reset) and item.id ~= self.HIDDEN_ITEM_ID
                and self.ChromieFavoriteHas and self:ChromieFavoriteHas(slot, item.id)
            if item.reset then
                AddButtonOnEnterTextTooltip(getglobal('TransmogLook' .. itemIndex .. 'Button'), color .. item.name, "Original appearance")
            elseif item.id == self.HIDDEN_ITEM_ID then
                AddButtonOnEnterTextTooltip(getglobal('TransmogLook' .. itemIndex .. 'Button'), color .. item.name)
            elseif fave then
                AddButtonOnEnterTextTooltip(getglobal('TransmogLook' .. itemIndex .. 'Button'), color .. item.name, "Right-click to unfavorite")
            else
                AddButtonOnEnterTextTooltip(getglobal('TransmogLook' .. itemIndex .. 'Button'), color .. item.name, "Right-click to favorite")
            end
            if item.reset then
                getglobal('TransmogLook' .. itemIndex .. 'ButtonRevert'):Show()
            end
            if fave and faveTex then
                faveTex:Show()
            end

            self.ItemButtons[itemIndex]:Show()

            local model = getglobal('TransmogLook' .. itemIndex .. 'ItemModel')
            if model and model.EnableMouse then
                model:EnableMouse(false)
            end

            model:SetUnit("player")
            model:SetRotation(0.61)
            local Z, X, Y = model:GetPosition(Z, X, Y)

            if self.race == 'nightelf' then
                Z = Z + 3
            end
            if self.race == 'gnome' then
                Z = Z - 3
                Y = Y + 1.5
            end
            if self.race == 'dwarf' then
                Y = Y + 1
                Z = Z - 1
            end
            if self.race == 'troll' then
                Z = Z + 2
            end
            if self.race == 'goblin' then
                Z = Z - 0.5
            end

            if self.currentTransmogSlot == self.inventorySlots['HeadSlot'] then
                if self.race == 'tauren' then
                    model:SetRotation(0.3)
                    X = X - 0.2
                    Y = Y + 0.2
                end
                if self.race == 'goblin' then
                    Y = Y + 1.5
                end
                if self.race == 'dwarf' then
                    Y = Y + 0.5
                end
                self:ChromieLookSetPosition(model, Z + 5.8, X, Y - 2.2)
            end

            if self.currentTransmogSlot == self.inventorySlots['ShoulderSlot'] then
                if self.race == 'dwarf' then
                    Y = Y - 0.2
                end
                if self.race == 'goblin' then
                    Y = Y + 1.5
                    Z = Z - 0.5
                end
                if self.race == 'nightelf' then
                    Z = Z - 1
                end
                self:ChromieLookSetPosition(model, Z + 5.8, X + 0.5, Y - 1.7)
            end

            if self.currentTransmogSlot == self.inventorySlots['BackSlot'] then
                model:SetRotation(3.2)
                self:ChromieLookSetPosition(model, Z + 3.8, X, Y - 0.7)
            end

            if self.currentTransmogSlot == self.inventorySlots['ChestSlot'] then
                if self.race == 'tauren' then
                    model:SetRotation(0.3)
                    X = X - 0.2
                    Y = Y + 0.5
                end
                if self.race == 'goblin' then
                    Y = Y + 1.5
                    Z = Z - 0.5
                end
                model:SetRotation(0.61)
                self:ChromieLookSetPosition(model, Z + 5.8, X + 0.1, Y - 1.2)
            end

            if self.currentTransmogSlot == self.inventorySlots['WristSlot'] then
                model:SetRotation(1.5)
                if self.race == 'gnome' then
                    Y = Y - 1
                end
                if self.race == 'tauren' then
                    X = X - 0.2
                end
                if self.race == 'dwarf' then
                    X = X - 0.3
                    Y = Y - 0.4
                end
                if self.race == 'troll' then
                    Y = Y + 0.6
                end
                if self.race == 'goblin' then
                    Y = Y + 1.5
                    Z = Z - 0.5
                end
                self:ChromieLookSetPosition(model, Z + 5.8, X + 0.4, Y - 0.3)
            end

            if self.currentTransmogSlot == self.inventorySlots['HandsSlot'] then
                model:SetRotation(1.5)
                if self.race == 'gnome' then
                    Y = Y - 0.7
                end
                if self.race == 'tauren' then
                    X = X - 0.2
                end
                if self.race == 'dwarf' then
                    Z = Z - 0.2
                    X = X - 0.3
                    Y = Y - 0.1
                end
                if self.race == 'troll' then
                    Y = Y + 0.9
                end
                if self.race == 'goblin' then
                    Y = Y + 1.5
                    Z = Z - 0.5
                end
                self:ChromieLookSetPosition(model, Z + 5.8, X + 0.4, Y - 0.3)
            end

            if self.currentTransmogSlot == self.inventorySlots['WaistSlot'] then
                model:SetRotation(0.31)
                if self.race == 'gnome' then
                    Y = Y - 0.7
                end
                if self.race == 'tauren' then
                    Z = Z + 1
                    Y = Y + 0.3
                end
                if self.race == 'goblin' then
                    Y = Y + 1.5
                    Z = Z - 0.5
                end
                self:ChromieLookSetPosition(model, Z + 5.8, X, Y - 0.4)
            end

            if self.currentTransmogSlot == self.inventorySlots['LegsSlot'] then
                model:SetRotation(0.31)
                if self.race == 'gnome' then
                    Z = Z + 2
                    Y = Y - 1.5
                end
                if self.race == 'dwarf' then
                    Y = Y - 0.9
                end
                self:ChromieLookSetPosition(model, Z + 3.8, X, Y + 0.9)
            end

            if self.currentTransmogSlot == self.inventorySlots['FeetSlot'] then
                model:SetRotation(0.61)
                if self.race == 'gnome' then
                    Z = Z + 2
                    Y = Y - 1.9
                end
                if self.race == 'dwarf' then
                    Y = Y - 0.6
                end
                self:ChromieLookSetPosition(model, Z + 4.8, X, Y + 1.5)
            end

            if self.currentTransmogSlot == self.inventorySlots['MainHandSlot'] then
                model:SetRotation(0.61)
                if self.race == 'gnome' then
                    Y = Y - 2
                end
                if self.race == 'dwarf' then
                    Y = Y - 1
                end
                self:ChromieLookSetPosition(model, Z + 3.8, X, Y + 0.4)
            end

            if self.currentTransmogSlot == self.inventorySlots['SecondaryHandSlot'] then
                model:SetRotation(-0.61)
                if self.race == 'gnome' then
                    Y = Y - 1.5
                end
                if self.race == 'dwarf' then
                    Y = Y - 1
                end
                self:ChromieLookSetPosition(model, Z + 3.8, X, Y)
            end

            if self.currentTransmogSlot == self.inventorySlots['RangedSlot'] then
                model:SetRotation(-0.61)
                if self.invTypes[item.equip_slot] == C_INVTYPE_RANGEDRIGHT then
                    model:SetRotation(0.61)
                end
                if self.race == 'troll' then
                    Y = Y + 1.5
                end
                if self.race == 'goblin' then
                    Y = Y + 1
                end
                if self.race == 'gnome' then
                    Y = Y - 1.5
                end
                self:ChromieLookSetPosition(model, Z + 3.8, X, Y)
            end

            model:Undress()

            if self.currentTransmogSlot == self.inventorySlots['SecondaryHandSlot'] then
                local mh = self.equippedItems[self.inventorySlots['MainHandSlot']]
                if mh and mh > 1 then
                    model:TryOn(mh)
                end
            end

            if item.id ~= Transmog.HIDDEN_ITEM_ID then
                model:TryOn(item.id)
            end

            col = col + 1
            if col == 5 then
                row = row + 1
                col = 0
            end

            itemIndex = itemIndex + 1
        end
        index = index + 1
    end

    self.totalPages = self:ceil(self:tableSize(self.availableTransmogItems[slot][itemClass]) / self.ipp)

    ChromieTransmogFramePageText:SetText("Page " .. self.currentPage .. "/" .. self.totalPages)

    if self.currentPage == 1 then
        ChromieTransmogFrameLeftArrow:Disable()
    else
        ChromieTransmogFrameLeftArrow:Enable()
    end

    if self.currentPage == self.totalPages or self:tableSize(self.availableTransmogItems[slot][itemClass]) < self.ipp then
        ChromieTransmogFrameRightArrow:Disable()
    else
        ChromieTransmogFrameRightArrow:Enable()
    end

    if self.totalPages > 1 then
        self:showPagination()
    else
        self:hidePagination()
    end

    if self.currentTransmogSlotName then
        getglobal(self.currentTransmogSlotName .. 'BorderSelected'):Show()
    end
    if self.ChromieLookPreviewRefreshPanel then
        self:ChromieLookPreviewRefreshPanel()
    end
    if self.ChromieLookPreviewButtonShow then
        self:ChromieLookPreviewButtonShow()
    end
end
