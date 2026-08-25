local Transmog = _G.ChromieTransmog
local ChromieTransmogFrame_Find = string.find
local ChromieTransmogFrame_ToNumber = tonumber

-- Maps an inventory type string to the corresponding slot frame.
function Transmog:frameFromInvType(invType, clientSlot)

    if invType == 'INVTYPE_WEAPON' and clientSlot == 17 then
        return SecondaryHandSlot
    end

    if invType == 'INVTYPE_HEAD' then
        return HeadSlot
    end
    if invType == 'INVTYPE_SHOULDER' then
        return ShoulderSlot
    end
    if invType == 'INVTYPE_CLOAK' then
        return BackSlot
    end
    if invType == 'INVTYPE_CHEST' or invType == 'INVTYPE_ROBE' then
        return ChestSlot
    end
    if invType == 'INVTYPE_WRIST' then
        return WristSlot
    end
    if invType == 'INVTYPE_HAND' then
        return HandsSlot
    end
    if invType == 'INVTYPE_WAIST' then
        return WaistSlot
    end
    if invType == 'INVTYPE_LEGS' then
        return LegsSlot
    end
    if invType == 'INVTYPE_FEET' then
        return FeetSlot
    end

    if invType == 'INVTYPE_WEAPONMAINHAND' or
            invType == 'INVTYPE_2HWEAPON' or
            invType == 'INVTYPE_WEAPON' or
            invType == 'INVTYPE_WEAPONMAINHAND'
    then
        return MainHandSlot
    end
    if invType == 'INVTYPE_WEAPONOFFHAND' or
            invType == 'INVTYPE_HOLDABLE' or
            invType == 'INVTYPE_SHIELD'
    then
        return SecondaryHandSlot
    end
    if invType == 'INVTYPE_RANGED' or
            invType == 'INVTYPE_RANGEDRIGHT' then
        return RangedSlot
    end
    return nil
end

function Transmog:PreviewShowsHelm()
    if ShowingHelm then
        return not not ShowingHelm()
    end
    return GetCVar("showHelm") == "1"
end

function Transmog:PreviewShowsCloak()
    if ShowingCloak then
        return not not ShowingCloak()
    end
    return GetCVar("showCloak") == "1"
end

function Transmog:PreviewTryOn(itemId, slot)
    if not itemId or itemId == 0 or itemId == self.HIDDEN_ITEM_ID or itemId == self.UNKNOWN_MOG_ID then
        return
    end
    if slot == 1 and not self:PreviewShowsHelm() then
        return
    end
    if slot == 15 and not self:PreviewShowsCloak() then
        return
    end
    ChromieTransmogFramePlayerModel:TryOn(itemId)
end

-- C methods often are not visible as a Lua field; always pcall.
function Transmog:PreviewHideSlot(model, slot)
    if not model or not slot then
        return false
    end
    local ok = pcall(function()
        model:UndressSlot(slot)
    end)
    return ok
end

function Transmog:PreviewVisibleItem(slot)
    local want = self.transmogStatusToServer[slot]
    local have = self.transmogStatusFromServer[slot]
    if want == self.HIDDEN_ITEM_ID then
        return nil
    end
    if want and want > 1 then
        return want
    end
    if have and have > 1 then
        return have
    end
    return self.equippedItems[slot]
end

function Transmog:PreviewDressVisibleSlots(hideSlots)
    local extra = { 4, 19 }
    local i
    for i = 1, 2 do
        local link = GetInventoryItemLink("player", extra[i])
        local id = link and self:IDFromLink(link)
        if id then
            ChromieTransmogFramePlayerModel:TryOn(id)
        end
    end
    local _, slot
    for _, slot in pairs(self.inventorySlots) do
        if not (hideSlots and hideSlots[slot]) then
            self:PreviewTryOn(self:PreviewVisibleItem(slot), slot)
        end
    end
end

function Transmog:PreviewApplyPending()
    local model = ChromieTransmogFramePlayerModel
    if not model then
        return
    end

    local hideSlots = {}
    local _, slot
    for _, slot in pairs(self.inventorySlots) do
        local want = self.transmogStatusToServer[slot]
        if want == self.HIDDEN_ITEM_ID then
            hideSlots[slot] = true
        end
    end

    local hid = false
    for slot in pairs(hideSlots) do
        if self:PreviewHideSlot(model, slot) then
            hid = true
        end
    end

    if not hid then
        model:Undress()
        self:PreviewDressVisibleSlots(hideSlots)
        return
    end

    for _, slot in pairs(self.inventorySlots) do
        if not hideSlots[slot] then
            local want = self.transmogStatusToServer[slot]
            local have = self.transmogStatusFromServer[slot]
            if want and have ~= want then
                if want == 0 then
                    self:PreviewTryOn(self.equippedItems[slot], slot)
                else
                    self:PreviewTryOn(want, slot)
                end
            end
        end
    end
end

-- SetUnit dresses asynchronously. UndressSlot in the same frame is discarded.
function Transmog:PreviewScheduleApply()
    if not self.previewApplyFrame then
        local f = CreateFrame("Frame")
        f:Hide()
        f:SetScript("OnUpdate", function()
            this.frames = (this.frames or 0) + 1
            if this.frames < 2 then
                return
            end
            this:Hide()
            Transmog:PreviewApplyPending()
        end)
        self.previewApplyFrame = f
    end
    self.previewApplyFrame.frames = 0
    self.previewApplyFrame:Hide()
    self.previewApplyFrame:Show()
end

function Transmog:RefreshPreviewModel()
    ChromieTransmogFramePlayerModel:SetUnit("player")
    self:PreviewScheduleApply()
end

-- Previews a transmog appearance on the selected equipment slot.
function Transmog_Try(itemId, slotName, newReset)
	twfdebug("Transmog_Try itemID: " .. itemId .. "slotName: " .. slotName)

    if newReset and getglobal(slotName .. "NoEquip"):IsVisible() then
        return false
    end

    Transmog:hideItemBorders()

    if newReset then
        local InventorySlotId = Transmog.inventorySlots[slotName]

        itemId = Transmog:IDFromLink(GetInventoryItemLink('player', InventorySlotId))

        Transmog.transmogStatusToServer[InventorySlotId] = 0

        getglobal(slotName .. 'AutoCast'):Hide()

        if Transmog.transmogStatusFromServer[InventorySlotId] ~= Transmog.transmogStatusToServer[InventorySlotId] then
            getglobal(slotName .. 'BorderHi'):Show()
            getglobal(slotName .. 'AutoCast'):SetAlpha(0.3)
        else
            getglobal(slotName .. 'BorderHi'):Hide()
        end
        Transmog:UpdateSlotGlow(slotName, InventorySlotId)

        Transmog:RefreshPreviewModel()

        Transmog:cacheItem(itemId)
        local _, _, _, _, _, _, _, _, _, tex = GetItemInfo(itemId)

        getglobal(slotName .. "ItemIcon"):SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")

        AddButtonOnEnterTooltipFashion(getglobal(slotName), GetInventoryItemLink('player', InventorySlotId))

        local _, _, eqItemLink = ChromieTransmogFrame_Find(GetInventoryItemLink('player', InventorySlotId), "(item:%d+:%d+:%d+:%d+)");
        local eName = GetItemInfo(eqItemLink)

        Transmog.equippedTransmogs[eName] = nil

        Transmog:calculateCost()
        Transmog:EnableOutfitSaveButton()

        return true
    end

    if itemId == Transmog:IDFromLink(GetInventoryItemLink('player', Transmog.currentTransmogSlot)) then
        getglobal(Transmog.currentTransmogSlotName .. 'BorderHi'):Hide()
        Transmog.transmogStatusToServer[Transmog.currentTransmogSlot] = 0
    else
        getglobal(Transmog.currentTransmogSlotName .. 'BorderHi'):Show()
        Transmog.transmogStatusToServer[Transmog.currentTransmogSlot] = itemId
    end

    Transmog:UpdateSlotGlow(Transmog.currentTransmogSlotName, Transmog.currentTransmogSlot)

    for itemIndex, data in ipairs(Transmog.ItemButtons) do
        getglobal('TransmogLook' .. itemIndex .. 'Button'):SetNormalTexture('Interface\\AddOns\\ChromieTransmog\\assets\\item_bg_normal')
        if data.id == itemId then
            getglobal('TransmogLook' .. itemIndex .. 'Button'):SetNormalTexture('Interface\\AddOns\\ChromieTransmog\\assets\\item_bg_selected')
        end
    end

    getglobal(Transmog.currentTransmogSlotName .. 'AutoCast'):Hide()

    if Transmog.transmogStatusFromServer[Transmog.currentTransmogSlot] ~= Transmog.transmogStatusToServer[Transmog.currentTransmogSlot] then
        getglobal(Transmog.currentTransmogSlotName .. 'AutoCast'):SetAlpha(0.3)
    end

    Transmog:RefreshPreviewModel()

    local tex
    if itemId == Transmog.HIDDEN_ITEM_ID then
        tex = nil
    else
        Transmog:cacheItem(itemId)
        local _
        _, _, _, _, _, _, _, _, _, tex = GetItemInfo(itemId)
    end

    twfdebug("Transmog_Try itemIcon target: [" .. tostring(Transmog.currentTransmogSlotName) .. "ItemIcon] tex: " .. tostring(tex))
    getglobal(Transmog.currentTransmogSlotName .. "ItemIcon"):SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
    twfdebug("Transmog_Try overlay check NoEquip: " .. tostring(getglobal(Transmog.currentTransmogSlotName .. "NoEquip"):IsVisible())
        .. " BorderHi: " .. tostring(getglobal(Transmog.currentTransmogSlotName .. "BorderHi"):IsVisible())
        .. " AutoCast: " .. tostring(getglobal(Transmog.currentTransmogSlotName .. "AutoCast"):IsVisible())
        .. " IconAlpha: " .. tostring(getglobal(Transmog.currentTransmogSlotName .. "ItemIcon"):GetAlpha()))

    Transmog:calculateCost()

    Transmog:EnableOutfitSaveButton()

end

-- Hides the pagination arrow and page text controls.
function Transmog:hidePagination()
    ChromieTransmogFrameLeftArrow:Hide()
    ChromieTransmogFrameRightArrow:Hide()
    ChromieTransmogFramePageText:Hide()
end

-- Shows the pagination arrow and page text controls.
function Transmog:showPagination()
    ChromieTransmogFrameLeftArrow:Show()
    ChromieTransmogFrameRightArrow:Show()
    ChromieTransmogFramePageText:Show()
end

-- Hides all transmog item buttons, optionally using the button's own Hide method.
function Transmog:hideItems(hideButton)
    for index, button in ipairs(self.ItemButtons) do
		if hideButton then
			button:Hide()
		else
			getglobal('TransmogLook' .. index):Hide()
		end
    end
end

-- Resets all item button border textures to the normal state.
function Transmog:hideItemBorders()
    for index, _ in ipairs(self.ItemButtons) do
        getglobal('TransmogLook' .. index .. 'Button'):SetNormalTexture('Interface\\AddOns\\ChromieTransmog\\assets\\item_bg_normal')
	end
end

-- Selects a gear slot and displays available transmog options for it.
function selectTransmogSlot(InventorySlotId, slotName)

	twfdebug("selectTransmogSlot slot: " .. InventorySlotId)

    ChromieTransmogFrameNoTransmogs:Hide()

    if InventorySlotId == -1 then
        Transmog:hidePlayerItemsBorders()
        Transmog:HidePlayerItemsAnimation()
        Transmog:hideItems(true)
        Transmog:hideItemBorders()
        Transmog:hidePagination()
        ChromieTransmogFrameSplash:Show()
        ChromieTransmogFrameInstructions:Show()
        ChromieTransmogFrameCollected:Hide()
        Transmog.currentTransmogSlotName = nil
        Transmog.currentTransmogSlot = nil
		Transmog.currentTransmogItemClass = nil
        return true
    end

    if getglobal(slotName .. "NoEquip"):IsVisible() then
        return false
    end

    ChromieTransmogFrameSplash:Hide()
    ChromieTransmogFrameInstructions:Hide()

    Transmog.currentPage = 1
    Transmog.currentTransmogSlotName = slotName
    Transmog.currentTransmogSlot = InventorySlotId

    if not GetInventoryItemLink('player', Transmog.currentTransmogSlot) then
        selectTransmogSlot(-1)
        return
    end

    local _, _, eqItemLink = ChromieTransmogFrame_Find(GetInventoryItemLink('player', Transmog.currentTransmogSlot), "(item:%d+:%d+:%d+:%d+)");
    local itemName, _, _, _, _, itemClass, itemSubclass, _, invType = GetItemInfo(eqItemLink)

    local eqItemId = Transmog:IDFromLink(eqItemLink)

    Transmog:RefreshPreviewModel()

    Transmog:hideItems(false)
    Transmog:hidePlayerItemsBorders()

	Transmog.currentTransmogItemClass = Transmog:ItemClassStrToNum(itemClass) + Transmog:ItemSubclassStrToNum(itemSubclass)

    Transmog:ChromieEnsureSlot(Transmog.currentTransmogSlot)
end

-- Initializes the character preview model with default rotation.
function TransmogModel_OnLoad()
    ChromieTransmogFramePlayerModel.rotation = 0.61;
    ChromieTransmogFramePlayerModel:SetRotation(ChromieTransmogFramePlayerModel.rotation);
end

-- Navigates between pages of transmog options or outfit tabs.
function Transmog_ChangePage(dir)
    if Transmog.tab == 'items' then
        if not Transmog.currentTransmogSlot or not Transmog.currentTransmogItemClass then
            return
        end

        local totalPages = math.max(1, Transmog.totalPages or 1)
        local nextPage = math.max(1, math.min(Transmog.currentPage + dir, totalPages))
        if nextPage ~= Transmog.currentPage then
            PlaySound("igAbiliityPageTurn")
        end

        Transmog.currentPage = nextPage
        Transmog:renderAvailableTransmogs(Transmog.currentTransmogSlot, Transmog.currentTransmogItemClass)
    else
        Transmog_switchTab(Transmog.tab)
    end
end

-- Reverts all pending transmog edits, discarding un-applied changes.
-- Does not send gossip or clear applied mogs on the character.
function Transmog_revert()
    if Transmog.ChromieAbortMultiApply then
        Transmog:ChromieAbortMultiApply()
    end
    if Transmog.chromieJob == "apply" then
        Transmog.chromieJob = "open"
        Transmog.chromieApplyClicked = nil
        Transmog.chromieApplySlot = nil
        Transmog.chromieApplyItem = nil
        Transmog.chromieWaitingForNpc = nil
    end

    local _, slot
    for _, slot in pairs(Transmog.inventorySlots) do
        Transmog.transmogStatusToServer[slot] = Transmog.transmogStatusFromServer[slot] or 0
    end

    Transmog:HidePlayerItemsAnimation()
    if Transmog.RefreshPendingGlows then
        Transmog:RefreshPendingGlows()
    end
    Transmog:Reset()
    Transmog:calculateCost(0)
end

function Transmog_resetAllSlots()
    Transmog_revert()
end

-- Switches between the items and outfits tabs.
function Transmog_switchTab(to)

	twfdebug("Transmog_switchTab " .. to)

    Transmog.tab = to
    if to == 'items' then
        ChromieTransmogFrameItemsButton:SetNormalTexture('Interface\\AddOns\\ChromieTransmog\\assets\\tab_active')
        ChromieTransmogFrameItemsButton:SetPushedTexture('Interface\\AddOns\\ChromieTransmog\\assets\\tab_active')
        ChromieTransmogFrameItemsButtonText:SetText(HIGHLIGHT_FONT_COLOR_CODE .. 'Items')

        if Transmog.currentTransmogSlot ~= nil then
            selectTransmogSlot(Transmog.currentTransmogSlot, Transmog.currentTransmogSlotName)
        else
            selectTransmogSlot(-1)
        end
    end
end
