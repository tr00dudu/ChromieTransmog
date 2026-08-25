local Transmog = _G.Transmog
local TransmogFrame_Find = string.find
local TransmogFrame_ToNumber = tonumber

-- Updates the collection progress bar with collected count.
function Transmog:setProgressBar(collected, possible)
	TransmogFrameCollectedCollectedStatus:SetText("Collected: " .. collected)

	local fillBarWidth = 0;
    TransmogFrameCollectedFillBar:SetPoint("TOPRIGHT", TransmogFrameCollected, "TOPLEFT", fillBarWidth, 0);
    TransmogFrameCollectedFillBar:Show();

    TransmogFrameCollected:SetStatusBarColor(0.0, 0.0, 0.0, 0.5);
    TransmogFrameCollectedBackground:SetVertexColor(0.0, 0.0, 0.0, 0.5);
    TransmogFrameCollectedFillBar:SetVertexColor(0.0, 1.0, 0.0, 0.5);

    TransmogFrameCollected:Show()
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
        itemID = TransmogFrame_ToNumber(itemID)
        local name, link, quality, level, min_level, class, subclass, _, inv_type, tex = GetItemInfo(itemID)

		local eqItemLink = nil
		local inventoryItemLink = GetInventoryItemLink('player', slot)
		if inventoryItemLink then
			local _, _, eqItemLink2 = TransmogFrame_Find(inventoryItemLink, "(item:%d+:%d+:%d+:%d+)");
			eqItemLink = eqItemLink2;
		end

        if not name then
            self:cacheItem(itemID);
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

	twfdebug("prepareAvailableTransmogs end")
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
        TransmogFrameNoTransmogs:Show()
    end

    local index = 0
    local row = 0
    local col = 0
    local itemIndex = 1

    for _, item in ipairs(self.availableTransmogItems[slot][itemClass]) do

        if index >= (self.currentPage - 1) * self.ipp and index < self.currentPage * self.ipp then

            if not self.ItemButtons[itemIndex] then
                self.ItemButtons[itemIndex] = CreateFrame('Frame', 'TransmogLook' .. itemIndex, TransmogFrame, 'TransmogFrameLookTemplate')
            end

            self.ItemButtons[itemIndex]:SetPoint("TOPLEFT", TransmogFrame, "TOPLEFT", 263 + col * 90, -105 - 120 * row)

            self.ItemButtons[itemIndex].name = item.name
            self.ItemButtons[itemIndex].id = item.id

            getglobal('TransmogLook' .. itemIndex .. 'Button'):SetID(item.id)
            getglobal('TransmogLook' .. itemIndex .. 'ButtonRevert'):Hide()
            getglobal('TransmogLook' .. itemIndex .. 'ButtonCheck'):Hide()

            if item.id == self.transmogStatusToServer[slot] then
                getglobal('TransmogLook' .. itemIndex .. 'Button'):SetNormalTexture('Interface\\AddOns\\Transmog\\assets\\item_bg_selected')
            else
                getglobal('TransmogLook' .. itemIndex .. 'Button'):SetNormalTexture('Interface\\AddOns\\Transmog\\assets\\item_bg_normal')
            end

            local _, _, _, color = GetItemQualityColor(item.quality)
            AddButtonOnEnterTextTooltip(getglobal('TransmogLook' .. itemIndex .. 'Button'), color .. item.name)
            if item.reset then
                getglobal('TransmogLook' .. itemIndex .. 'ButtonRevert'):Show()
            end

            self.ItemButtons[itemIndex]:Show()

            local model = getglobal('TransmogLook' .. itemIndex .. 'ItemModel')

            model:SetUnit("player")
            model:SetRotation(0.61);
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
                    model:SetRotation(0.3);
                    X = X - 0.2
                    Y = Y + 0.2
                end
                if self.race == 'goblin' then
                    Y = Y + 1.5
                end
                if self.race == 'dwarf' then
                    Y = Y + 0.5
                end
                model:SetPosition(Z + 5.8, X, Y - 2.2)
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
                model:SetPosition(Z + 5.8, X + 0.5, Y - 1.7)
            end

            if self.currentTransmogSlot == self.inventorySlots['BackSlot'] then
                model:SetRotation(3.2);
                model:SetPosition(Z + 3.8, X, Y - 0.7)
            end

            if self.currentTransmogSlot == self.inventorySlots['ChestSlot'] then
                if self.race == 'tauren' then
                    model:SetRotation(0.3);
                    X = X - 0.2
                    Y = Y + 0.5
                end
                if self.race == 'goblin' then
                    Y = Y + 1.5
                    Z = Z - 0.5
                end
                model:SetRotation(0.61);
                model:SetPosition(Z + 5.8, X + 0.1, Y - 1.2)
            end

            if self.currentTransmogSlot == self.inventorySlots['WristSlot'] then
                model:SetRotation(1.5);
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
                model:SetPosition(Z + 5.8, X + 0.4, Y - 0.3)
            end

            if self.currentTransmogSlot == self.inventorySlots['HandsSlot'] then
                model:SetRotation(1.5);
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
                model:SetPosition(Z + 5.8, X + 0.4, Y - 0.3)
            end

            if self.currentTransmogSlot == self.inventorySlots['WaistSlot'] then
                model:SetRotation(0.31);
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
                model:SetPosition(Z + 5.8, X, Y - 0.4)
            end

            if self.currentTransmogSlot == self.inventorySlots['LegsSlot'] then
                model:SetRotation(0.31);
                if self.race == 'gnome' then
                    Z = Z + 2
                    Y = Y - 1.5
                end
                if self.race == 'dwarf' then
                    Y = Y - 0.9
                end
                model:SetPosition(Z + 3.8, X, Y + 0.9)
            end

            if self.currentTransmogSlot == self.inventorySlots['FeetSlot'] then
                model:SetRotation(0.61);
                if self.race == 'gnome' then
                    Z = Z + 2
                    Y = Y - 1.9
                end
                if self.race == 'dwarf' then
                    Y = Y - 0.6
                end
                model:SetPosition(Z + 4.8, X, Y + 1.5)
            end

            if self.currentTransmogSlot == self.inventorySlots['MainHandSlot'] then
                model:SetRotation(0.61);
                if self.race == 'gnome' then
                    Y = Y - 2
                end
                if self.race == 'dwarf' then
                    Y = Y - 1
                end
                model:SetPosition(Z + 3.8, X, Y + 0.4)
            end

            if self.currentTransmogSlot == self.inventorySlots['SecondaryHandSlot'] then
                model:SetRotation(-0.61);
                model:SetPosition(Z + 3.8, X, Y)
                if self.race == 'gnome' then
                    Y = Y - 1.5
                end
                if self.race == 'dwarf' then
                    Y = Y - 1
                end
            end

            if self.currentTransmogSlot == self.inventorySlots['RangedSlot'] then
                model:SetRotation(-0.61)
                if self.invTypes[item.equip_slot] == C_INVTYPE_RANGEDRIGHT then
                    model:SetRotation(0.61);
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
                model:SetPosition(Z + 3.8, X, Y)
            end

            model:Undress()

            if self.currentTransmogSlot == self.inventorySlots['SecondaryHandSlot'] then
                TransmogFramePlayerModel:TryOn(self.equippedItems[self.inventorySlots['MainHandSlot']])
            end

            if item.id ~= Transmog.HIDDEN_ITEM_ID then
                model:TryOn(item.id);
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

    TransmogFramePageText:SetText("Page " .. self.currentPage .. "/" .. self.totalPages)

    if self.currentPage == 1 then
        TransmogFrameLeftArrow:Disable()
    else
        TransmogFrameLeftArrow:Enable()
    end

    if self.currentPage == self.totalPages or self:tableSize(self.availableTransmogItems[slot][itemClass]) < self.ipp then
        TransmogFrameRightArrow:Disable()
    else
        TransmogFrameRightArrow:Enable()
    end

    if self.totalPages > 1 then
        self:showPagination()
    else
        self:hidePagination()
    end

    if self.currentTransmogSlotName then
        getglobal(self.currentTransmogSlotName .. 'BorderSelected'):Show()
    end

end
