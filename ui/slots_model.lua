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

-- Player dummy (DressUpModel):
--   open / set-apply / revert -> SetUnit("player") once
--   pending pick / reset to an item -> TryOn that slot only
--   pending hide -> Undress + TryOn cache (UndressSlot is a no-op on Chromie)
-- Grid thumbnails (TransmogLookN) stay a separate widget.

function Transmog:PreviewTryOn(itemId, slot, model)
    if self.ChromieDbg then
        local why
        if itemId == nil then
            why = "skip nil dressId (no mog item id in cache)"
        elseif itemId == 0 then
            why = "skip 0"
        elseif itemId == self.HIDDEN_ITEM_ID then
            why = "skip hidden sentinel"
        elseif itemId == self.UNKNOWN_MOG_ID then
            why = "skip UNKNOWN -1 (gossip never sent this mog's item id)"
        elseif slot == 1 and not self:PreviewShowsHelm() then
            why = "skip helm-cvar"
        elseif slot == 15 and not self:PreviewShowsCloak() then
            why = "skip cloak-cvar"
        else
            why = "TryOn " .. (self.ChromieItemLabel and self:ChromieItemLabel(itemId) or tostring(itemId))
        end
        self:ChromieDbg("dress " .. (self.ChromieSlotLabel and self:ChromieSlotLabel(slot) or tostring(slot))
            .. " " .. why
            .. " applied=" .. (self.ChromieItemLabel and self:ChromieItemLabel(self.applied and self.applied[slot]) or tostring(self.applied and self.applied[slot]))
            .. " saved=" .. (self.ChromieItemLabel and self:ChromieItemLabel(self.ChromiePersistGetApplied and self:ChromiePersistGetApplied(slot)) or "?")
            .. " shown=" .. (self.ChromieItemLabel and self:ChromieItemLabel(self.previewShown and self.previewShown[slot]) or "?")
            .. " want=" .. (self.ChromieItemLabel and self:ChromieItemLabel(self.transmogStatusToServer and self.transmogStatusToServer[slot]) or "?"))
    end
    if not itemId or itemId == 0 or itemId == self.HIDDEN_ITEM_ID or itemId == self.UNKNOWN_MOG_ID then
        return
    end
    if slot == 1 and not self:PreviewShowsHelm() then
        return
    end
    if slot == 15 and not self:PreviewShowsCloak() then
        return
    end
    model = model or ChromieTransmogFramePlayerModel
    if not model then
        return
    end
    if not pcall(function()
        model:TryOn(itemId)
    end) then
        pcall(function()
            model:TryOn("item:" .. itemId)
        end)
    elseif model ~= ChromieTransmogFramePlayerModel then
        -- Lua/home DressUpModels often no-op numeric TryOn without error.
        pcall(function()
            model:TryOn("item:" .. itemId)
        end)
    end
end

function Transmog:PreviewCacheIdFromServer(slot)
    local have = self.transmogStatusFromServer[slot]
    if have == self.HIDDEN_ITEM_ID then
        return self.HIDDEN_ITEM_ID
    end
    if have and have > 1 then
        return have
    end
    local applied = self.ChromiePersistGetApplied and self:ChromiePersistGetApplied(slot)
    if applied == self.HIDDEN_ITEM_ID then
        return self.HIDDEN_ITEM_ID
    end
    if applied and applied > 1 then
        return applied
    end
    if have == self.UNKNOWN_MOG_ID or applied == self.UNKNOWN_MOG_ID then
        return self.UNKNOWN_MOG_ID
    end
    return self.equippedItems[slot] or 0
end

function Transmog:PreviewCacheIdFromWant(slot)
    local want = self.transmogStatusToServer[slot]
    if want == self.HIDDEN_ITEM_ID then
        return self.HIDDEN_ITEM_ID
    end
    if want == 0 then
        return self.equippedItems[slot] or 0
    end
    if want and want > 1 then
        return want
    end
    return self:PreviewCacheIdFromServer(slot)
end

function Transmog:PreviewDressId(slot)
    local want = self.transmogStatusToServer and self.transmogStatusToServer[slot]
    local shown = self.previewShown and self.previewShown[slot]
    if want == self.HIDDEN_ITEM_ID or shown == self.HIDDEN_ITEM_ID then
        return nil
    end
    if want and want > 1 then
        return want
    end
    if want == 0 then
        return self.equippedItems[slot]
    end
    if shown and shown > 1 then
        local equipped = self.equippedItems and self.equippedItems[slot]
        if shown ~= equipped then
            return shown
        end
    end
    local applied = self.ChromiePersistGetApplied and self:ChromiePersistGetApplied(slot)
    if applied and applied > 1 then
        return applied
    end
    local have = self.transmogStatusFromServer and self.transmogStatusFromServer[slot]
    if have and have > 1 then
        return have
    end
    return self.equippedItems[slot]
end

function Transmog:PreviewFillShownFromApplied()
    if not self.previewShown then
        self:PreviewCacheInit()
        return
    end
    local _, slot
    for _, slot in pairs(self.inventorySlots) do
        local shown = self.previewShown[slot]
        local want = self.transmogStatusToServer and self.transmogStatusToServer[slot]
        if want == self.HIDDEN_ITEM_ID then
            self.previewShown[slot] = self.HIDDEN_ITEM_ID
        elseif shown == nil or shown == self.UNKNOWN_MOG_ID then
            self.previewShown[slot] = self:PreviewCacheIdFromWant(slot)
        else
            local applied = self.applied and self.applied[slot]
            local equipped = self.equippedItems and self.equippedItems[slot]
            if applied and applied > 1 and shown == equipped and want ~= 0 then
                self.previewShown[slot] = applied
            end
        end
    end
end

function Transmog:PreviewCacheInit()
    if not self.previewShown then
        self.previewShown = {}
    end
    if not self.previewBaseline then
        self.previewBaseline = {}
    end
    local _, slot
    for _, slot in pairs(self.inventorySlots) do
        self.previewBaseline[slot] = self:PreviewCacheIdFromServer(slot)
        self.previewShown[slot] = self:PreviewCacheIdFromWant(slot)
    end
end

function Transmog:PreviewCacheCommit(slot, itemId)
    if not slot then
        return
    end
    local id
    if itemId == 0 then
        id = self.equippedItems[slot] or 0
    else
        id = itemId
    end
    if not self.previewShown then
        self.previewShown = {}
    end
    if not self.previewBaseline then
        self.previewBaseline = {}
    end
    self.previewBaseline[slot] = id
    self.previewShown[slot] = id
    if self.ChromieAppliedSet then
        self:ChromieAppliedSet(slot, itemId)
    end
end

function Transmog:PreviewHasHidden()
    if not self.previewShown then
        return false
    end
    local _, slot
    for _, slot in pairs(self.inventorySlots) do
        if self.previewShown[slot] == self.HIDDEN_ITEM_ID then
            return true
        end
    end
    return false
end

function Transmog:PreviewShowPlayer(delay)
    delay = tonumber(delay) or 0
    if delay < 0 then
        delay = 0
    end
    if not ChromieTransmogFramePlayerModel then
        return
    end
    if self.previewRedressFrame then
        self.previewRedressFrame:Hide()
    end
    if delay == 0 then
        if self.ChromieDbg then
            self:ChromieDbg("dress SetUnit(player)")
        end
        ChromieTransmogFramePlayerModel:SetUnit("player")
        return
    end
    if not self.previewRedressFrame then
        local f = CreateFrame("Frame", nil, UIParent)
        f:Hide()
        f:SetScript("OnUpdate", function()
            this.n = (this.n or 0) + 1
            if this.n >= (this.delay or 0) + 1 then
                this:Hide()
                if ChromieTransmogFramePlayerModel then
                    if Transmog.ChromieDbg then
                        Transmog:ChromieDbg("dress SetUnit(player) delayed")
                    end
                    ChromieTransmogFramePlayerModel:SetUnit("player")
                end
            end
        end)
        self.previewRedressFrame = f
    end
    local f = self.previewRedressFrame
    f.delay = delay
    f.n = 0
    f:Show()
end

function Transmog:PreviewSlotHasPendingChange(slot)
    if not slot then
        return false
    end
    local want = self.transmogStatusToServer and self.transmogStatusToServer[slot]
    local have = self.transmogStatusFromServer and self.transmogStatusFromServer[slot]
    if want == nil then
        return false
    end
    return want ~= (have or 0)
end

function Transmog:PreviewShouldDressRanged()
    if not self.ChromieSlotSupportsTransmog or not self:ChromieSlotSupportsTransmog(18) then
        return false
    end
    return self:PreviewSlotHasPendingChange(18)
end

function Transmog:PreviewWeaponDressId(slot)
    local id = self:PreviewDressId(slot)
    if (not id or id <= 1) and self.previewShown and self.previewShown[slot] and self.previewShown[slot] > 1 then
        id = self.previewShown[slot]
    end
    -- Never fall back to equipped ranged during redress; TryOn relic/bow clears weapons.
    if slot == 18 then
        return id
    end
    if (not id or id <= 1) and self.equippedItems then
        id = self.equippedItems[slot]
    end
    return id
end

-- Weapons after Undress: offhand TryOn can drop main hand on Chromie DressUpModel.
function Transmog:PreviewTryOnWeapons(model, dressIdFn)
    local mh, oh, rg
    if dressIdFn then
        mh = dressIdFn(16)
        oh = dressIdFn(17)
        rg = dressIdFn(18)
    else
        mh = self:PreviewWeaponDressId(16)
        oh = self:PreviewWeaponDressId(17)
        rg = self:PreviewWeaponDressId(18)
    end
    if mh and mh > 1 then
        self:PreviewTryOn(mh, 16, model)
    end
    if oh and oh > 1 then
        self:PreviewTryOn(oh, 17, model)
    end
    if mh and mh > 1 then
        self:PreviewTryOn(mh, 16, model)
    end
    local dressRanged
    if dressIdFn then
        dressRanged = rg and rg > 1
    else
        dressRanged = self:PreviewShouldDressRanged()
    end
    if dressRanged and rg and rg > 1 then
        self:PreviewTryOn(rg, 18, model)
    end
end

-- Full undress + cache TryOn. Only for hide (or restack when a slot is hidden).
-- Optional model/dressIdFn dress a different DressUpModel from an id callback
-- without mutating the left dummy's previewShown cache.
function Transmog:PreviewRebuild(model, dressIdFn)
    model = model or ChromieTransmogFramePlayerModel
    if not model then
        return
    end
    if not dressIdFn then
        if not self.previewShown then
            self:PreviewCacheInit()
        else
            self:PreviewFillShownFromApplied()
        end
        if self.previewRedressFrame then
            self.previewRedressFrame:Hide()
        end
    end
    model:Undress()
    local extra = { 4, 19 }
    local i
    for i = 1, 2 do
        local link = GetInventoryItemLink("player", extra[i])
        local id = link and self:IDFromLink(link)
        if id then
            self:PreviewTryOn(id, extra[i], model)
        end
    end
    local order = self.previewArmorOrder or { 1, 3, 5, 6, 7, 8, 9, 10, 15 }
    i = 1
    while order[i] do
        local id
        if dressIdFn then
            id = dressIdFn(order[i])
        else
            id = self:PreviewDressId(order[i])
        end
        self:PreviewTryOn(id, order[i], model)
        i = i + 1
    end
    self:PreviewTryOnWeapons(model, dressIdFn)
end

function Transmog:PreviewRebuildFromCache()
    self:PreviewRebuild()
end

-- Live unit, then overlay pending known ids. Used when a slot must return to an
-- unknown applied mog (no item id) without dropping other pending TryOns.
function Transmog:PreviewRestack()
    if self:PreviewHasHidden() then
        self:PreviewRebuild()
        return
    end
    self:PreviewShowPlayer(0)
    if not self.previewShown then
        return
    end
    local order = self.previewArmorOrder or { 1, 3, 5, 6, 7, 8, 9, 10, 15 }
    local i = 1
    while order[i] do
        local slot = order[i]
        local id = self.previewShown[slot]
        if id and id > 1 then
            self:PreviewTryOn(id, slot)
        end
        i = i + 1
    end
    self:PreviewTryOnWeapons()
end

function Transmog:PreviewApplyResolvedMog(slot, mogId)
    if not slot or not mogId then
        return
    end
    if not ChromieTransmogFrame or not ChromieTransmogFrame:IsShown() then
        return
    end
    if mogId == self.HIDDEN_ITEM_ID then
        if not self.previewShown then
            self:PreviewCacheInit()
        end
        self.previewShown[slot] = mogId
        self:PreviewRebuild()
        return
    end
    if mogId <= 1 then
        return
    end
    if not self.previewShown then
        self:PreviewCacheInit()
    end
    self.previewShown[slot] = mogId
    if self.previewBaseline then
        self.previewBaseline[slot] = mogId
    end
    self:PreviewApplySlot(slot)
end

-- Redress only the slots that just changed. A full Rebuild would TryOn
-- equipped base items for incomplete (unknown) slots and unmog the dummy.
function Transmog:PreviewApplyChangedSlots(changed)
    if not changed or not ChromieTransmogFrame or not ChromieTransmogFrame:IsShown() then
        return
    end
    if not self.previewShown then
        self:PreviewCacheInit()
    end
    local hidden = false
    local weapons = false
    local slot
    for slot in pairs(changed) do
        local id = self:PreviewCacheIdFromWant(slot)
        self.previewShown[slot] = id
        if self.previewBaseline then
            self.previewBaseline[slot] = id
        end
        if id == self.HIDDEN_ITEM_ID then
            hidden = true
        elseif id == self.UNKNOWN_MOG_ID or not id then
            -- Incomplete slot: do not SetUnit/Rebuild the whole dummy.
        elseif slot == 16 or slot == 17 or slot == 18 then
            weapons = true
        else
            self:PreviewApplySlot(slot)
        end
    end
    if hidden then
        self:PreviewRebuild()
        return
    end
    if weapons then
        self:PreviewTryOnWeapons()
    end
end

function Transmog:PreviewApplySlot(slot)
    if not slot then
        return
    end
    if not self.previewShown then
        self:PreviewCacheInit()
    end
    local id = self.previewShown[slot]
    if id == self.HIDDEN_ITEM_ID then
        self:PreviewRebuild()
        return
    end
    if id == self.UNKNOWN_MOG_ID then
        self:PreviewRestack()
        return
    end
    if not id or id == 0 then
        id = self.equippedItems[slot] or 0
    end
    if id and id > 1 then
        self:PreviewTryOn(id, slot)
        return
    end
end

function Transmog:PreviewChangeSlot(slot)
    if not slot then
        return
    end
    if not self.previewShown then
        self:PreviewCacheInit()
    else
        self:PreviewFillShownFromApplied()
    end
    self.previewShown[slot] = self:PreviewCacheIdFromWant(slot)
    self:PreviewApplySlot(slot)
end

function Transmog:PreviewUndoOrResetSlot(slot)
    if not slot then
        return
    end
    if not self.previewShown then
        self:PreviewCacheInit()
    end
    local have = self.transmogStatusFromServer[slot] or 0
    local want = self.transmogStatusToServer[slot]
    if want ~= have then
        self.transmogStatusToServer[slot] = have
        self.previewShown[slot] = self.previewBaseline[slot] or self:PreviewCacheIdFromServer(slot)
    else
        self.transmogStatusToServer[slot] = 0
        self.previewShown[slot] = self.equippedItems[slot] or 0
    end
    self:PreviewApplySlot(slot)
end

-- Show the live character. Not a full Undress rebuild.
function Transmog:PreviewRedress(delay)
    self:PreviewShowPlayer(delay)
end

function Transmog:RefreshPreviewModel()
    self:PreviewShowPlayer(0)
end

function Transmog:PreviewSlotIcon(itemId, slot)
    if not itemId or itemId == 0 or itemId == self.HIDDEN_ITEM_ID then
        return nil
    end
    if itemId == self.UNKNOWN_MOG_ID then
        return self.transmogGossipIcon and self.transmogGossipIcon[slot]
    end
    self:cacheItem(itemId)
    local _, _, _, _, _, _, _, _, _, tex = GetItemInfo(itemId)
    return tex
end

-- Previews a transmog appearance on the selected equipment slot.
function Transmog_Try(itemId, slotName, newReset)
	twfdebug("Transmog_Try itemID: " .. itemId .. "slotName: " .. slotName)

    if Transmog.ChromieCacheSyncIsBlocking and Transmog:ChromieCacheSyncIsBlocking() then
        return
    end

    if newReset and getglobal(slotName .. "NoEquip"):IsVisible() then
        return false
    end

    Transmog:hideItemBorders()

    if newReset then
        local InventorySlotId = Transmog.inventorySlots[slotName]

        Transmog:PreviewUndoOrResetSlot(InventorySlotId)

        getglobal(slotName .. 'AutoCast'):Hide()

        if Transmog.transmogStatusFromServer[InventorySlotId] ~= Transmog.transmogStatusToServer[InventorySlotId] then
            getglobal(slotName .. 'BorderHi'):Show()
            getglobal(slotName .. 'AutoCast'):SetAlpha(0.3)
        else
            getglobal(slotName .. 'BorderHi'):Hide()
        end
        Transmog:UpdateSlotGlow(slotName, InventorySlotId)

        local shown = Transmog.previewShown[InventorySlotId]
        local tex = Transmog:PreviewSlotIcon(shown, InventorySlotId)
        getglobal(slotName .. "ItemIcon"):SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")

        AddButtonOnEnterTooltipFashion(getglobal(slotName), GetInventoryItemLink('player', InventorySlotId))

        Transmog:calculateCost()
        Transmog:EnableOutfitSaveButton()

        return true
    end

    local equippedId = Transmog:IDFromLink(GetInventoryItemLink('player', Transmog.currentTransmogSlot))
    if itemId == equippedId then
        Transmog:PreviewUndoOrResetSlot(Transmog.currentTransmogSlot)
        itemId = Transmog.previewShown[Transmog.currentTransmogSlot]
        if Transmog.transmogStatusToServer[Transmog.currentTransmogSlot] == Transmog.transmogStatusFromServer[Transmog.currentTransmogSlot] then
            getglobal(Transmog.currentTransmogSlotName .. 'BorderHi'):Hide()
        else
            getglobal(Transmog.currentTransmogSlotName .. 'BorderHi'):Show()
        end
    else
        getglobal(Transmog.currentTransmogSlotName .. 'BorderHi'):Show()
        Transmog.transmogStatusToServer[Transmog.currentTransmogSlot] = itemId
        if itemId and itemId > 1 and Transmog.ChromieCacheKeyForSlot and Transmog.ChromieUnlockMergeId then
            local key = Transmog:ChromieCacheKeyForSlot(Transmog.currentTransmogSlot)
            if key then
                Transmog:ChromieUnlockMergeId(key, itemId, nil)
            end
        end
        Transmog:PreviewChangeSlot(Transmog.currentTransmogSlot)
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

    local tex = Transmog:PreviewSlotIcon(itemId, Transmog.currentTransmogSlot)

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

    if Transmog.ChromieCacheSyncIsBlocking and Transmog:ChromieCacheSyncIsBlocking() then
        return
    end

    local overlay = Transmog.applyProgressFrame
    if overlay and overlay:IsShown() then
        if Transmog.chromieMultiActive then
            return
        end
        Transmog.chromiePromptOnYes = nil
        overlay:Hide()
        overlay.mode = nil
    end

    -- Slot click opens the appearance grid; no Items tab to highlight.
    if InventorySlotId ~= -1 and Transmog.tab ~= "items" then
        Transmog.tab = "items"
        if Transmog.ChromieHomeTabHide then
            Transmog:ChromieHomeTabHide()
        end
        if Transmog.ChromieCacheTabHide then
            Transmog:ChromieCacheTabHide()
        end
        if ChromieTransmogFrameItemsButton then
            ChromieTransmogFrameItemsButtonText:SetText(FONT_COLOR_CODE_CLOSE .. "Home")
        end
        if ChromieTransmogFrameSetsButton then
            ChromieTransmogFrameSetsButtonText:SetText(FONT_COLOR_CODE_CLOSE .. "Sets")
        end
        if ChromieTransmogFrameCacheButton then
            ChromieTransmogFrameCacheButtonText:SetText(FONT_COLOR_CODE_CLOSE .. "Cache")
        end
        if ChromieTransmogFrameAboutButton then
            ChromieTransmogFrameAboutButtonText:SetText(FONT_COLOR_CODE_CLOSE .. "About")
        end
        if Transmog.ChromieAboutTabHide then
            Transmog:ChromieAboutTabHide()
        end
    end

    ChromieTransmogFrameNoTransmogs:Hide()

    if Transmog.ChromieHideManageSets then
        Transmog:ChromieHideManageSets()
    end

    if InventorySlotId == -1 then
        Transmog:hidePlayerItemsBorders()
        Transmog:HidePlayerItemsAnimation()
        Transmog:hideItems(true)
        Transmog:hideItemBorders()
        Transmog:hidePagination()
        ChromieTransmogFrameCollectedText:Hide()
        Transmog.currentTransmogSlotName = nil
        Transmog.currentTransmogSlot = nil
		Transmog.currentTransmogItemClass = nil
        return true
    end

    if getglobal(slotName .. "NoEquip"):IsVisible() then
        return false
    end

    if Transmog.ChromieSlotSupportsTransmog and not Transmog:ChromieSlotSupportsTransmog(InventorySlotId) then
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
    if Transmog.ChromieCacheSyncIsBlocking and Transmog:ChromieCacheSyncIsBlocking() then
        return
    end
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

    Transmog.chromiePendingSet = nil
    Transmog.currentOutfit = nil
    Transmog.chromieSetSaveName = nil
    if Transmog.ChromieHideSetCreate then
        Transmog:ChromieHideSetCreate()
    end
    UIDropDownMenu_SetText(ChromieTransmogFrameOutfits, Transmog:ChromieSetsDropdownLabel())
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

-- Switches between Home, Sets, Cache, About, and slot-browse (internal "items").
function Transmog_switchTab(to)

	twfdebug("Transmog_switchTab " .. to)

    local overlay = Transmog.applyProgressFrame
    local keepPrompt = Transmog.chromieMultiActive and overlay and overlay:IsShown() and overlay.mode == "progress"
    if overlay and overlay:IsShown() and not keepPrompt and not Transmog.chromiePromptRestoring then
        Transmog.chromiePromptOnYes = nil
        overlay:Hide()
        overlay.mode = nil
    end

    Transmog.tab = to

    if ChromieTransmogFrameItemsButton then
        ChromieTransmogFrameItemsButtonText:SetText(FONT_COLOR_CODE_CLOSE .. 'Home')
    end
    if ChromieTransmogFrameSetsButton then
        ChromieTransmogFrameSetsButtonText:SetText(FONT_COLOR_CODE_CLOSE .. 'Sets')
    end
    if ChromieTransmogFrameCacheButton then
        ChromieTransmogFrameCacheButtonText:SetText(FONT_COLOR_CODE_CLOSE .. 'Cache')
    end
    if ChromieTransmogFrameAboutButton then
        ChromieTransmogFrameAboutButtonText:SetText(FONT_COLOR_CODE_CLOSE .. 'About')
    end

    if Transmog.ChromieHomeTabHide then
        Transmog:ChromieHomeTabHide()
    end
    if Transmog.ChromieHideManageSets then
        Transmog:ChromieHideManageSets()
    end
    if Transmog.ChromieCacheTabHide then
        Transmog:ChromieCacheTabHide()
    end
    if Transmog.ChromieAboutTabHide then
        Transmog:ChromieAboutTabHide()
    end
    Transmog:hideItems(true)
    Transmog:hidePagination()
    ChromieTransmogFrameNoTransmogs:Hide()
    ChromieTransmogFrameCollectedText:Hide()

    if to == 'home' then
        if ChromieTransmogFrameItemsButton then
            ChromieTransmogFrameItemsButtonText:SetText(HIGHLIGHT_FONT_COLOR_CODE .. 'Home')
        end
        if Transmog.ChromieHomeTabShow then
            Transmog:ChromieHomeTabShow()
        end
    elseif to == 'items' then
        Transmog:hideItems(false)
        if Transmog.currentTransmogSlot ~= nil then
            selectTransmogSlot(Transmog.currentTransmogSlot, Transmog.currentTransmogSlotName)
        else
            selectTransmogSlot(-1)
        end
    elseif to == 'sets' then
        if ChromieTransmogFrameSetsButton then
            ChromieTransmogFrameSetsButtonText:SetText(HIGHLIGHT_FONT_COLOR_CODE .. 'Sets')
        end
        if Transmog.ChromieShowManageSets then
            Transmog:ChromieShowManageSets()
        end
    elseif to == 'cache' then
        if ChromieTransmogFrameCacheButton then
            ChromieTransmogFrameCacheButtonText:SetText(HIGHLIGHT_FONT_COLOR_CODE .. 'Cache')
        end
        if Transmog.ChromieCacheTabShow then
            Transmog:ChromieCacheTabShow()
        end
    elseif to == 'about' then
        if ChromieTransmogFrameAboutButton then
            ChromieTransmogFrameAboutButtonText:SetText(HIGHLIGHT_FONT_COLOR_CODE .. 'About')
        end
        if Transmog.ChromieAboutTabShow then
            Transmog:ChromieAboutTabShow()
        end
    end

    if keepPrompt and Transmog.ChromiePromptCoverRight then
        Transmog:ChromiePromptCoverRight()
        overlay:Show()
        overlay:Raise()
    end
end
