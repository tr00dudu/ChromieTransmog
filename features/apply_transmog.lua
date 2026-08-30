local Transmog = _G.ChromieTransmog
local ChromieTransmogFrame_Find = string.find

-- Updates the UI to reflect current transmog status from the server.
function Transmog:transmogStatus()
	twfdebug("TransmogStatus")

    -- add paperdoll textures
    for slotName, InventorySlotId in pairs(self.inventorySlots) do
        local frame = getglobal(slotName)
        if frame then

            local texture
            local texEx = ChromieTransmogFrame_Explode(frame:GetName(), 'Slot')
            texture = string.lower(texEx[1])

            if texture == 'wrist' then
                texture = texture .. 's'
            end
            if texture == 'back' then
                texture = 'chest'
            end

            getglobal(frame:GetName() .. 'ItemIcon'):SetTexture('Interface\\Paperdoll\\ui-paperdoll-slot-' .. texture)
            getglobal(frame:GetName() .. 'NoEquip'):Show()
            getglobal(frame:GetName() .. 'BorderHi'):Hide()

            AddButtonOnEnterTextTooltip(frame, self.inventorySlotNames[InventorySlotId], "There is no equipped item in this slot", true)
        end
    end

    -- add item textures
    for slotName, InventorySlotId in pairs(self.inventorySlots) do
        self.equippedItems[InventorySlotId] = 0
        if GetInventoryItemLink('player', InventorySlotId) then

            local _, _, eqItemLink = ChromieTransmogFrame_Find(GetInventoryItemLink('player', InventorySlotId), "(item:%d+:%d+:%d+:%d+)");
            local itemName, _, _, _, _, _, _, _, _, tex = GetItemInfo(eqItemLink)

            self.equippedItems[InventorySlotId] = self:IDFromLink(eqItemLink)

            local frame = getglobal(slotName)

            if frame then

                frame:Enable()
                frame:SetID(InventorySlotId)

                getglobal(frame:GetName() .. 'AutoCast'):Hide()
                getglobal(frame:GetName() .. 'AutoCast'):SetModel("Interface\\Buttons\\UI-AutoCastButton.mdx")
                getglobal(frame:GetName() .. 'AutoCast'):SetAlpha(0.3)

                getglobal(frame:GetName() .. 'NoEquip'):Hide()

                getglobal(frame:GetName() .. 'Revert'):Hide()

                if self.transmogStatusFromServer[InventorySlotId] and self.transmogStatusFromServer[InventorySlotId] ~= 0 then
                    getglobal(frame:GetName() .. 'BorderHi'):Show()
                    local mogLabel = self.ChromieAppearanceLabel and self:ChromieAppearanceLabel("player", InventorySlotId)

                    if self.transmogStatusFromServer[InventorySlotId] == Transmog.HIDDEN_ITEM_ID then
                        AddButtonOnEnterTooltipFashion(frame, eqItemLink, mogLabel or "(Hidden)", true)

                        local emptyTexture = string.lower(ChromieTransmogFrame_Explode(slotName, 'Slot')[1])
                        if emptyTexture == 'wrist' then
                            emptyTexture = emptyTexture .. 's'
                        end
                        if emptyTexture == 'back' then
                            emptyTexture = 'chest'
                        end
                        getglobal(frame:GetName() .. 'ItemIcon'):SetTexture('Interface\\Paperdoll\\ui-paperdoll-slot-' .. emptyTexture)
                    elseif self.transmogStatusFromServer[InventorySlotId] == Transmog.UNKNOWN_MOG_ID then
                        AddButtonOnEnterTooltipFashion(frame, eqItemLink, mogLabel or "(Transmogged)", true)
                        local gossipIcon = self.transmogGossipIcon and self.transmogGossipIcon[InventorySlotId]
                        getglobal(frame:GetName() .. 'ItemIcon'):SetTexture(gossipIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
                    else
                        AddButtonOnEnterTooltipFashion(frame, eqItemLink, mogLabel, true)

                        local _, _, _, _, _, _, _, _, _, TransmogTex = GetItemInfo(self.transmogStatusFromServer[InventorySlotId])
                        if not TransmogTex then
                            TransmogTex = self.transmogGossipIcon and self.transmogGossipIcon[InventorySlotId]
                        end

                        getglobal(frame:GetName() .. 'ItemIcon'):SetTexture(TransmogTex)
                    end

                    getglobal(frame:GetName() .. 'Revert'):Show()
                else
                    getglobal(frame:GetName() .. 'BorderHi'):Hide()
                    AddButtonOnEnterTooltipFashion(frame, eqItemLink)
                    getglobal(frame:GetName() .. 'ItemIcon'):SetTexture(tex)
                end
            end
        end
    end

    self:calculateCost()
end

function Transmog:ChromieCostText(copper)
    if not copper or copper <= 0 then
        return "free"
    end
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper - gold * 10000) / 100)
    local cop = copper - gold * 10000 - silver * 100
    local text = ""
    if gold > 0 then
        text = gold .. " gold"
    end
    if silver > 0 then
        if text ~= "" then
            text = text .. " "
        end
        text = text .. silver .. " silver"
    end
    if cop > 0 and gold == 0 then
        if text ~= "" then
            text = text .. " "
        end
        text = text .. cop .. " copper"
    end
    if text == "" then
        return "free"
    end
    return text
end

function Transmog:ChromieEnsureApplyProgressFrame()
    if self.applyProgressFrame then
        return self.applyProgressFrame
    end
    local f = CreateFrame("Frame", "ChromieTransmogApplyProgress", UIParent)
    f:SetWidth(340)
    f:SetHeight(96)
    f:SetPoint("TOP", UIParent, "TOP", 0, -120)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(false)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOP", 0, -18)
    text:SetWidth(300)
    text:SetJustifyH("CENTER")
    f.text = text

    local bar = CreateFrame("StatusBar", "ChromieTransmogApplyProgressBar", f)
    bar:SetWidth(268)
    bar:SetHeight(16)
    bar:SetPoint("BOTTOM", 0, 20)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(1, 0.82, 0.1)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bg:SetVertexColor(0.2, 0.2, 0.2, 0.9)
    local barText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    barText:SetPoint("CENTER", 0, 0)
    f.bar = bar
    f.barText = barText
    f:Hide()
    self.applyProgressFrame = f
    return f
end

function Transmog:ChromieHideApplyProgress()
    if self.applyProgressFrame then
        self.applyProgressFrame:Hide()
    end
end

function Transmog:ChromieAbortMultiApply()
    self.chromieMultiActive = nil
    self.chromieMultiTotal = nil
    self.chromieMultiDone = nil
    self.chromieWaitingForNpc = nil
    self.chromieRemoveAll = nil
    self.chromieRemoveAllSlots = nil
    self:ChromieHideApplyProgress()
end

function Transmog:ChromieUpdateApplyProgress(applying)
    if not self.chromieMultiActive then
        self:ChromieHideApplyProgress()
        return
    end
    local f = self:ChromieEnsureApplyProgressFrame()
    local total = self.chromieMultiTotal or 1
    local done = self.chromieMultiDone or 0
    if done > total then
        done = total
    end
    local remain = total - done
    f.bar:SetMinMaxValues(0, total)
    f.bar:SetValue(done)
    f.barText:SetText(done .. " / " .. total)
    if remain <= 0 then
        f.text:SetText("All queued transmogs applied.")
        f:Show()
        return
    end
    if applying then
        f.text:SetText("Applying " .. (done + 1) .. " of " .. total .. "...")
    else
        local clicks = "click"
        if remain ~= 1 then
            clicks = "clicks"
        end
        f.text:SetText("Right-click Warpweaver to continue.\n" .. remain .. " more " .. clicks .. " needed.")
    end
    f:Show()
end

function Transmog:ChromieBeginQueuedApply()
    local slot, item = self:ChromieNextPendingApply()
    if not slot then
        return
    end
    local pending = select(1, self:ChromiePendingCost())
    if pending > 1 or self.chromieMultiActive then
        if not self.chromieMultiActive then
            self.chromieMultiActive = true
            self.chromieMultiTotal = pending
            self.chromieMultiDone = 0
        end
        self:ChromieUpdateApplyProgress(true)
    end
    self.pendingApplyCount = 1
    self:ChromieStartApply(slot, item)
end

StaticPopupDialogs["CHROMIE_TRANSMOG_APPLY_CONFIRM"] = {
    text = "%s",
    button1 = TEXT(YES),
    button2 = TEXT(NO),
    OnAccept = function()
        if Transmog.ChromieIsFullRemovePending and Transmog:ChromieIsFullRemovePending() then
            Transmog:ChromieStartRemoveAll()
        else
            Transmog:ChromieBeginQueuedApply()
        end
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    showAlert = 1,
}

StaticPopupDialogs["CHROMIE_TRANSMOG_VENDOR_MODE"] = {
    text = "Warpweaver is using the vendor item list (.t i on). ChromieTransmog needs the gossip list (.t i off).\n\nSwitch it off now? Then talk to Warpweaver again.",
    button1 = "Switch off",
    button2 = TEXT(CANCEL),
    OnAccept = function()
        if Transmog.ChromieSendInterfaceOff then
            Transmog:ChromieSendInterfaceOff()
        end
        if Transmog.ChromieForceCloseGossip then
            Transmog:ChromieForceCloseGossip()
        end
        if CloseMerchant then
            CloseMerchant()
        end
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    showAlert = 1,
}

-- Sends pending transmog changes through ChromieCraft gossip/vendor.
function Apply_OnClick()
    if Transmog.ChromieCacheSyncIsBlocking and Transmog:ChromieCacheSyncIsBlocking() then
        return
    end
    if Transmog.manageSetsOpen then
        selectTransmogSlot(-1)
    end
    local pending, copper = Transmog:ChromiePendingCost()
    if pending <= 0 then
        return
    end
    if Transmog.ChromieIsFullRemovePending and Transmog:ChromieIsFullRemovePending() then
        local msg = pending .. " transmogs queued. Remove all transmogrifications in one step?"
        StaticPopup_Show("CHROMIE_TRANSMOG_APPLY_CONFIRM", msg)
        return
    end
    if pending == 1 then
        Transmog:ChromieBeginQueuedApply()
        return
    end
    local costText = Transmog:ChromieCostText(copper)
    local msg = pending .. " transmogs queued. Estimated cost: " .. costText .. ".\nWarpweaver applies one slot per click. Continue?"
    StaticPopup_Show("CHROMIE_TRANSMOG_APPLY_CONFIRM", msg)
end
