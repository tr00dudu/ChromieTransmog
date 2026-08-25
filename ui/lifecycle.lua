local Transmog = _G.Transmog

-- Initializes the transmog addon on load: sets up UI, hooks, and pre-caches items.
function Transmog_OnLoad()

	twfdebug("Transmog_OnLoad start")

    local bmLoaded, bmReason = LoadAddOn("Blizzard_BattlefieldMinimap")

    if not BattlefieldMinimapOptions.transmog then
        BattlefieldMinimapOptions.transmog = {}
    end

    Transmog:cacheItem(51217)

    TransmogFrameInstructions:SetText("Are you tired of wearing the same armor every day?\nSelect the item you wish to change and enjoy your new stylish look.")
    TransmogFrameNoTransmogs:SetText("You have yet to uncover any kind of appearance for this item. \nThe appearance will unlock after you equip the item.")

    if not transmogOutfits then
        transmogOutfits = {}
    end

    UIDropDownMenu_Initialize(TransmogFrameOutfits, OutfitsDropDown_Initialize);
    UIDropDownMenu_SetWidth(TransmogFrameOutfits, 123);
    TransmogFrameSaveOutfit:Disable()
    TransmogFrameDeleteOutfit:Disable()
    UIDropDownMenu_SetText(TransmogFrameOutfits, "Outfits")

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
        return TWFHookSetInventoryItem(self, unit, slot)
    end

    local TWFHookSetBagItem = GameTooltip.SetBagItem
    function GameTooltip.SetBagItem(self, container, slot)
        GameTooltip.itemLink = GetContainerItemLink(container, slot)
        _, GameTooltip.itemCount = GetContainerItemInfo(container, slot)
        return TWFHookSetBagItem(self, container, slot)
    end

	twfdebug("Transmog_OnLoad end")
end

-- Sends initial data requests to the server after the delayed load timer fires.
function Transmog:LoadOnce()

	twfdebug("LoadOnce")
    self:aSend("GetTransmogStatus")
	self:aSend("GetAvailableTransmogs")
end

-- Sets up the transmog frame UI, model controls, and initial state when shown.
function TransmogFrame_OnShow()

	twfdebug("TransmogFrame_OnShow start")

    Transmog_switchTab('items')
    SetPortraitTexture(TransmogFramePortrait, "target");

    Transmog:Reset()

	Transmog:hideItems(false)

    TransmogFramePlayerModel:SetScript('OnMouseUp', function(self)
        TransmogFramePlayerModel:SetScript('OnUpdate', nil)
    end)

    TransmogFramePlayerModel:SetScript('OnMouseWheel', function(self, spining)
        local Z, X, Y = TransmogFramePlayerModel:GetPosition()
        Z = (arg1 > 0 and Z + 1 or Z - 1)

        TransmogFramePlayerModel:SetPosition(Z, X, Y)
    end)

    TransmogFramePlayerModel:SetScript('OnMouseDown', function()
        local StartX, StartY = GetCursorPosition()

        local EndX, EndY, Z, X, Y
        if arg1 == 'LeftButton' then
            TransmogFramePlayerModel:SetScript('OnUpdate', function(self)
                EndX, EndY = GetCursorPosition()

                TransmogFramePlayerModel.rotation = (EndX - StartX) / 34 + TransmogFramePlayerModel:GetFacing()

                TransmogFramePlayerModel:SetFacing(TransmogFramePlayerModel.rotation)

                StartX, StartY = GetCursorPosition()
            end)
        elseif arg1 == 'RightButton' then
            TransmogFramePlayerModel:SetScript('OnUpdate', function(self)
                EndX, EndY = GetCursorPosition()

                Z, X, Y = TransmogFramePlayerModel:GetPosition(Z, X, Y)
                X = (EndX - StartX) / 45 + X
                Y = (EndY - StartY) / 45 + Y

                TransmogFramePlayerModel:SetPosition(Z, X, Y)
                StartX, StartY = GetCursorPosition()
            end)
        end
    end)
end

-- Cleans up state when the transmog frame is hidden.
function Transmog_OnHide()
    CloseGossip()
    HideUIPanel(GossipFrame)
    GossipFrame:Hide()
	twfdebug("Transmog_OnHide")

    PlaySound("igCharacterInfoClose");
    Transmog.currentTransmogSlotName = nil
    Transmog.currentTransmogSlot = nil
    Transmog.currentOutfit = nil
    TransmogFrameSaveOutfit:Disable()
    TransmogFrameDeleteOutfit:Disable()
    UIDropDownMenu_SetText(TransmogFrameOutfits, "Outfits")
end

-- Resets the transmog UI to its default state, optionally without re-requesting server data.
function Transmog:Reset(once)

	twfdebug("Reset")

    if not once then
        self:aSend("GetTransmogStatus")
        self:aSend("GetAvailableTransmogs")
    end

    TransmogFrameRaceBackground:SetTexture("Interface\\AddOns\\Transmog\\assets\\transmogbackground" .. self.race)
    TransmogFrameSplash:Show()
    TransmogFrameInstructions:Show()
    TransmogFrameApplyButton:Disable()

    self.currentPage = 1

	TransmogFrameCurrencyText:Hide()

    TransmogFramePlayerModel:SetUnit("player")

    Transmog_switchTab(self.tab)
    AddButtonOnEnterTextTooltip(TransmogFrameRevert, "Reset")

end
