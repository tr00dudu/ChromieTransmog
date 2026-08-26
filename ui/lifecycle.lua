local Transmog = _G.ChromieTransmog

-- Initializes the transmog addon on load: sets up UI, hooks, and pre-caches items.
function Transmog_OnLoad()

	twfdebug("Transmog_OnLoad start")

    local bmLoaded, bmReason = LoadAddOn("Blizzard_BattlefieldMinimap")

    if not BattlefieldMinimapOptions.transmog then
        BattlefieldMinimapOptions.transmog = {}
    end

    Transmog:cacheItem(51217)

    ChromieTransmogFrameInstructions:SetText("Are you tired of wearing the same armor every day?\nSelect the item you wish to change and enjoy your new stylish look.")
    ChromieTransmogFrameNoTransmogs:SetText("You have yet to uncover any kind of appearance for this item. \nThe appearance will unlock after you equip the item.")

    if not ChromieTransmogOutfits then
        ChromieTransmogOutfits = {}
    end

    UIDropDownMenu_Initialize(ChromieTransmogFrameOutfits, OutfitsDropDown_Initialize);
    UIDropDownMenu_SetWidth(ChromieTransmogFrameOutfits, 120);
    ChromieTransmogFrameSaveOutfit:Hide()
    ChromieTransmogFrameSaveOutfit:Disable()
    ChromieTransmogFrameManageSets:Enable()
    UIDropDownMenu_SetText(ChromieTransmogFrameOutfits, Transmog:ChromieSetsDropdownLabel())

    Transmog:CacheEquippedGear()

    Transmog:CacheOutfitsItems()

    Transmog.newTransmogAlert:HideAnchor()

    Transmog.delayedLoad:Show()

    if Transmog.class == 'druid' or Transmog.class == 'paladin' or Transmog.class == 'shaman' then
        RangedSlot:Hide()
    end

    local TWFHookSetInventoryItem = GameTooltip.SetInventoryItem
    function GameTooltip.SetInventoryItem(self, unit, slot)
        GameTooltip.itemLink = GetInventoryItemLink(unit, slot)
        local ok = TWFHookSetInventoryItem(self, unit, slot)
        if Transmog.ChromieAttachTransmogTooltip then
            Transmog:ChromieAttachTransmogTooltip(self, unit, slot)
        end
        return ok
    end

    local TWFHookSetBagItem = GameTooltip.SetBagItem
    function GameTooltip.SetBagItem(self, container, slot)
        GameTooltip.itemLink = GetContainerItemLink(container, slot)
        _, GameTooltip.itemCount = GetContainerItemInfo(container, slot)
        local ok = TWFHookSetBagItem(self, container, slot)
        if Transmog.ChromieAttachTransmogTooltip then
            Transmog:ChromieAttachTransmogTooltip(self, nil, nil, GameTooltip.itemLink)
        end
        return ok
    end

	twfdebug("Transmog_OnLoad end")
end

-- Sends initial data requests to the server after the delayed load timer fires.
function Transmog:LoadOnce()

	twfdebug("LoadOnce")
    self:ChromieInitStatus()
end

-- Sets up the transmog frame UI, model controls, and initial state when shown.
function ChromieTransmogFrame_OnShow()

	twfdebug("ChromieTransmogFrame_OnShow start")

    Transmog.currentTransmogSlot = nil
    Transmog.currentTransmogSlotName = nil
    Transmog.currentTransmogItemClass = nil
    Transmog_switchTab('items')
    SetPortraitTexture(ChromieTransmogFramePortrait, UnitExists("npc") and "npc" or "target");

    Transmog:Reset()

	Transmog:hideItems(false)

    ChromieTransmogFramePlayerModel:SetScript('OnMouseUp', function(self)
        ChromieTransmogFramePlayerModel:SetScript('OnUpdate', nil)
    end)

    ChromieTransmogFramePlayerModel:SetScript('OnMouseWheel', function(self, spining)
        local Z, X, Y = ChromieTransmogFramePlayerModel:GetPosition()
        Z = (arg1 > 0 and Z + 1 or Z - 1)

        ChromieTransmogFramePlayerModel:SetPosition(Z, X, Y)
    end)

    ChromieTransmogFramePlayerModel:SetScript('OnMouseDown', function()
        local StartX, StartY = GetCursorPosition()

        local EndX, EndY, Z, X, Y
        if arg1 == 'LeftButton' then
            ChromieTransmogFramePlayerModel:SetScript('OnUpdate', function(self)
                EndX, EndY = GetCursorPosition()

                ChromieTransmogFramePlayerModel.rotation = (EndX - StartX) / 34 + ChromieTransmogFramePlayerModel:GetFacing()

                ChromieTransmogFramePlayerModel:SetFacing(ChromieTransmogFramePlayerModel.rotation)

                StartX, StartY = GetCursorPosition()
            end)
        elseif arg1 == 'RightButton' then
            ChromieTransmogFramePlayerModel:SetScript('OnUpdate', function(self)
                EndX, EndY = GetCursorPosition()

                Z, X, Y = ChromieTransmogFramePlayerModel:GetPosition(Z, X, Y)
                X = (EndX - StartX) / 45 + X
                Y = (EndY - StartY) / 45 + Y

                ChromieTransmogFramePlayerModel:SetPosition(Z, X, Y)
                StartX, StartY = GetCursorPosition()
            end)
        end
    end)
end

-- Cleans up state when the transmog frame is hidden.
function Transmog_OnHide()
    if Transmog.ChromieAbortMultiApply then
        Transmog:ChromieAbortMultiApply()
    end
    Transmog.chromieJob = nil
    if Transmog.skipCloseOnHide then
        twfdebug("Transmog_OnHide skip close")
        PlaySound("igCharacterInfoClose");
        Transmog.currentTransmogSlotName = nil
        Transmog.currentTransmogSlot = nil
        Transmog.currentOutfit = nil
        Transmog.chromiePendingSet = nil
        if Transmog.ChromieHideSetCreate then
            Transmog:ChromieHideSetCreate()
        end
        ChromieTransmogFrameSaveOutfit:Hide()
        ChromieTransmogFrameSaveOutfit:Disable()
        if Transmog.ChromieHideManageSets then
            Transmog:ChromieHideManageSets()
        end
        UIDropDownMenu_SetText(ChromieTransmogFrameOutfits, Transmog:ChromieSetsDropdownLabel())
        return
    end
    Transmog.chromieVendorOpen = nil
    Transmog.chromieVendorPopupShown = nil
    -- CloseGossip is wrapped to keep the session alive while the overlay is
    -- shown; OnHide must actually end gossip so the next talk is a fresh menu.
    Transmog.allowGossipClose = true
    CloseGossip()
    Transmog.allowGossipClose = nil
    if CloseMerchant then
        CloseMerchant()
    end
    HideUIPanel(GossipFrame)
    GossipFrame:Hide()
	twfdebug("Transmog_OnHide")

    PlaySound("igCharacterInfoClose");
    Transmog.currentTransmogSlotName = nil
    Transmog.currentTransmogSlot = nil
    Transmog.currentOutfit = nil
    Transmog.chromiePendingSet = nil
    if Transmog.ChromieHideSetCreate then
        Transmog:ChromieHideSetCreate()
    end
    ChromieTransmogFrameSaveOutfit:Hide()
    ChromieTransmogFrameSaveOutfit:Disable()
    if Transmog.ChromieHideManageSets then
        Transmog:ChromieHideManageSets()
    end
    UIDropDownMenu_SetText(ChromieTransmogFrameOutfits, Transmog:ChromieSetsDropdownLabel())
end

-- Resets the transmog UI to its default state, optionally without re-requesting server data.
function Transmog:Reset(once)

	twfdebug("Reset")

    if not once then
        self:ChromieInitStatus()
        self:transmogStatus()
    end

    ChromieTransmogFrameRaceBackground:SetTexture("Interface\\AddOns\\ChromieTransmog\\assets\\transmogbackground" .. self.race)

    self.currentPage = 1
    self.currentTransmogSlot = nil
    self.currentTransmogSlotName = nil
    self.currentTransmogItemClass = nil

    self:PreviewRedress(0)

    Transmog_switchTab(self.tab ~= "" and self.tab or "items")
    AddButtonOnEnterTextTooltip(ChromieTransmogFrameRevert, "Reset")
    self:calculateCost()

end
