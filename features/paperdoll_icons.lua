local Transmog = _G.ChromieTransmog

-- Character/inspect paperdoll use GetInventoryItemTexture, which follows the
-- visible transmog entry. Always paint slot buttons from the real item link.

local PAPERDOLL_SLOTS = { 1, 3, 5, 6, 7, 8, 9, 10, 15, 16, 17, 18 }

local PLAYER_SLOT_BUTTON = {
    [1] = "CharacterHeadSlot",
    [3] = "CharacterShoulderSlot",
    [5] = "CharacterChestSlot",
    [6] = "CharacterWaistSlot",
    [7] = "CharacterLegsSlot",
    [8] = "CharacterFeetSlot",
    [9] = "CharacterWristSlot",
    [10] = "CharacterHandsSlot",
    [15] = "CharacterBackSlot",
    [16] = "CharacterMainHandSlot",
    [17] = "CharacterSecondaryHandSlot",
    [18] = "CharacterRangedSlot",
}

local INSPECT_SLOT_BUTTON = {
    [1] = "InspectHeadSlot",
    [3] = "InspectShoulderSlot",
    [5] = "InspectChestSlot",
    [6] = "InspectWaistSlot",
    [7] = "InspectLegsSlot",
    [8] = "InspectFeetSlot",
    [9] = "InspectWristSlot",
    [10] = "InspectHandsSlot",
    [15] = "InspectBackSlot",
    [16] = "InspectMainHandSlot",
    [17] = "InspectSecondaryHandSlot",
    [18] = "InspectRangedSlot",
}

local function itemLinkFromInventory(unit, slot)
    local link = GetInventoryItemLink(unit, slot)
    if not link then
        return nil
    end
    local _, _, itemLink = string.find(link, "(item:%d+:%d+:%d+:%d+)")
    return itemLink or link
end

local function originalItemTexture(unit, slot)
    local itemLink = itemLinkFromInventory(unit, slot)
    if not itemLink then
        return nil
    end
    local itemId = Transmog:IDFromLink(itemLink)
    if itemId and Transmog.cacheItem then
        Transmog:cacheItem(itemId)
    end
    local _, _, _, _, _, _, _, _, _, tex = GetItemInfo(itemLink)
    return tex
end

function Transmog:ChromieRestoreSlotIcon(button, unit)
    if not button or not unit then
        return
    end
    local slot = button:GetID()
    if not slot or slot < 1 then
        return
    end
    local tex = originalItemTexture(unit, slot)
    if not tex then
        local itemId = Transmog:IDFromLink(GetInventoryItemLink(unit, slot))
        if itemId and Transmog.cacheItem then
            Transmog:cacheItem(itemId)
        end
        return
    end
    if SetItemButtonTexture then
        SetItemButtonTexture(button, tex)
    end
    local icon = getglobal(button:GetName() .. "IconTexture")
        or getglobal(button:GetName() .. "Icon")
    if icon and icon.SetTexture then
        icon:SetTexture(tex)
    end
    if button.icon and button.icon.SetTexture then
        button.icon:SetTexture(tex)
    end
    button.hasItem = 1
end

function Transmog:ChromieRefreshPaperdollIcons(unit)
    unit = unit or "player"
    local map = (unit == "player") and PLAYER_SLOT_BUTTON or INSPECT_SLOT_BUTTON
    local i = 1
    while PAPERDOLL_SLOTS[i] do
        local slot = PAPERDOLL_SLOTS[i]
        local name = map[slot]
        if name then
            local button = getglobal(name)
            if button then
                local link = GetInventoryItemLink(unit, slot)
                if link then
                    if self.cacheItem then
                        self:cacheItem(link)
                    end
                    self:ChromieRestoreSlotIcon(button, unit)
                end
            end
        end
        i = i + 1
    end
end

local TRANSMOG_PINK = "|cffff80ff"
local LABEL_MOGGED = TRANSMOG_PINK .. "Transmogrified|r"
local LABEL_HIDDEN = TRANSMOG_PINK .. "Transmogrified - Hidden|r"

local function normTex(tex)
    if not tex then
        return nil
    end
    tex = string.lower(tostring(tex))
    tex = string.gsub(tex, "/", "\\")
    tex = string.gsub(tex, "%.blp$", "")
    return tex
end

local function iconKey(tex)
    local n = normTex(tex)
    if not n then
        return nil
    end
    return string.gsub(n, "^.*\\", "")
end

local function isHiddenTexture(tex)
    if not tex or tex == "" then
        return true
    end
    local n = normTex(tex)
    return string.find(n, "paperdoll", 1, true) or string.find(n, "wowunknownitem", 1, true)
end

local function mogStateFromTextures(unit, slot)
    local visTex = GetInventoryItemTexture(unit, slot)
    local origTex = originalItemTexture(unit, slot)
    if isHiddenTexture(visTex) then
        return "hidden"
    end
    local visKey = iconKey(visTex)
    local origKey = iconKey(origTex)
    if visKey and origKey and visKey ~= origKey then
        return "mogged"
    end
    return nil
end

function Transmog:ChromieRememberMog(link, hidden)
    local uid = self:ChromieLinkUniqueId(link)
    if not uid then
        return
    end
    if not self.mogByUniqueId then
        self.mogByUniqueId = {}
    end
    self.mogByUniqueId[uid] = hidden and "hidden" or "mogged"
end

function Transmog:ChromieForgetMog(link)
    local uid = self:ChromieLinkUniqueId(link)
    if uid and self.mogByUniqueId then
        self.mogByUniqueId[uid] = nil
    end
end

function Transmog:ChromieMogItemName(slot, unit)
    if unit ~= "player" or not slot then
        return nil
    end
    local link = GetInventoryItemLink("player", slot)
    local mogId = link and self.ChromiePersistGetOwnedMog
        and self:ChromiePersistGetOwnedMog(link, self:ChromieOwnedIconForSlot(slot))
    if not mogId or mogId <= 1 then
        local from = self.transmogStatusFromServer and self.transmogStatusFromServer[slot]
        from = from and tonumber(from)
        if from and from > 1 then
            mogId = from
        elseif self.ChromieResolveAppliedMogId then
            mogId = self:ChromieResolveAppliedMogId(slot)
        end
    end
    if not mogId or mogId <= 1 then
        return nil
    end
    if self.cacheItem then
        self:cacheItem(mogId)
    end
    return GetItemInfo(mogId)
end

function Transmog:ChromieFormatMogLabel(state, slot, unit)
    if state == "hidden" then
        return LABEL_HIDDEN
    end
    if state == "mogged" and unit == "player" and slot then
        local name = self:ChromieMogItemName(slot, unit)
        if name then
            return TRANSMOG_PINK .. "Transmogrified: " .. name .. "|r"
        end
    end
    if state == "mogged" then
        return LABEL_MOGGED
    end
    return nil
end

function Transmog:ChromieAppearanceLabel(unit, slot)
    local link = GetInventoryItemLink(unit, slot)
    if not link then
        return nil
    end

    -- Live textures decide if this equipped piece currently looks mogged.
    local state = mogStateFromTextures(unit, slot)

    if unit == "player" then
        local owned = self.ChromiePersistGetOwnedMog
            and self:ChromiePersistGetOwnedMog(link, self:ChromieOwnedIconForSlot(slot))
        local gossip = self.transmogGossipIcon and self.transmogGossipIcon[slot]
        if not state and gossip then
            local origKey = iconKey(originalItemTexture(unit, slot))
            if iconKey(gossip) ~= origKey and not isHiddenTexture(gossip) then
                state = "mogged"
            end
        end
        -- Owned map is per-item. Use it for names / hidden, never to override a
        -- clean (unmogged) texture for a different piece in the same slot.
        if state == "mogged" or state == "hidden" then
            if owned == self.HIDDEN_ITEM_ID then
                state = "hidden"
            end
        elseif owned == self.HIDDEN_ITEM_ID and isHiddenTexture(GetInventoryItemTexture(unit, slot)) then
            state = "hidden"
        end
    end

    if state == "hidden" then
        self:ChromieRememberMog(link, true)
        return LABEL_HIDDEN
    end
    if state == "mogged" then
        self:ChromieRememberMog(link, false)
        return self:ChromieFormatMogLabel("mogged", slot, unit)
    end
    self:ChromieForgetMog(link)
    return nil
end

function Transmog:ChromieAppearanceLabelForLink(link)
    if not link then
        return nil
    end
    local itemId = self:IDFromLink(link)
    local uid = self:ChromieLinkUniqueId(link)
    for _, slotId in pairs(self.inventorySlots or {}) do
        local eq = GetInventoryItemLink("player", slotId)
        if eq and self:IDFromLink(eq) == itemId then
            if uid and self:ChromieLinkUniqueId(eq) == uid then
                return self:ChromieAppearanceLabel("player", slotId)
            end
            if not uid then
                return self:ChromieAppearanceLabel("player", slotId)
            end
        end
    end
    local bagIcon = select(10, GetItemInfo(link))
    local owned = self.ChromiePersistGetOwnedMog and self:ChromiePersistGetOwnedMog(link, bagIcon)
    if not owned and self.ChromiePersistFindOwnedMogForItem then
        owned = self:ChromiePersistFindOwnedMogForItem(itemId)
    end
    if owned == self.HIDDEN_ITEM_ID then
        return LABEL_HIDDEN
    end
    if owned and owned > 1 then
        if self.cacheItem then
            self:cacheItem(owned)
        end
        local name = GetItemInfo(owned)
        if name then
            return TRANSMOG_PINK .. "Transmogrified: " .. name .. "|r"
        end
        return LABEL_MOGGED
    end
    if uid and self.mogByUniqueId then
        local state = self.mogByUniqueId[uid]
        if state == "hidden" then
            return LABEL_HIDDEN
        end
        if state == "mogged" then
            return LABEL_MOGGED
        end
    end
    return nil
end

local function inspectUnit()
    if InspectFrame and InspectFrame.unit then
        return InspectFrame.unit
    end
    return "target"
end

function Transmog:ChromieTooltipHasMogLine(tooltip)
    if not tooltip then
        return false
    end
    local i = 1
    local left = getglobal(tooltip:GetName() .. "TextLeft" .. i)
    while left and left:GetText() do
        if string.find(left:GetText(), "Transmogrified", 1, true) then
            return true
        end
        i = i + 1
        left = getglobal(tooltip:GetName() .. "TextLeft" .. i)
    end
    return false
end

function Transmog:ChromieIsTransmogGearSlot(slot)
    if not slot then
        return false
    end
    for _, slotId in pairs(self.inventorySlots or {}) do
        if slotId == slot then
            return true
        end
    end
    return false
end

function Transmog:ChromieShouldAttachTransmogTooltip(unit, slot)
    if not unit or not slot or not self:ChromieIsTransmogGearSlot(slot) then
        return false
    end
    if not self:ChromieSlotSupportsTransmog(slot) then
        return false
    end
    if unit == "player" then
        return true
    end
    if unit == "target" then
        return true
    end
    if InspectFrame and InspectFrame.unit and unit == InspectFrame.unit then
        return true
    end
    return false
end

function Transmog:ChromieAttachTransmogTooltip(tooltip, unit, slot)
    if not tooltip or not self:ChromieShouldAttachTransmogTooltip(unit, slot) then
        return
    end
    if self:ChromieTooltipHasMogLine(tooltip) then
        return
    end
    local label = self:ChromieAppearanceLabel(unit, slot)
    if not label then
        return
    end
    local left2 = getglobal(tooltip:GetName() .. "TextLeft2")
    if left2 then
        local existing = left2:GetText() or ""
        if existing == "" then
            left2:SetText(label)
        else
            left2:SetText(label .. "\n|cffffffff" .. existing)
        end
    elseif tooltip.AddLine then
        tooltip:AddLine(label)
    end
    tooltip:Show()
end

function Transmog:ChromieInstallTooltipHooks()
    if self.chromieTooltipHooksInstalled then
        return
    end
    self.chromieTooltipHooksInstalled = true

    if GameTooltip and GameTooltip.SetInventoryItem then
        hooksecurefunc(GameTooltip, "SetInventoryItem", function(tip, unit, slot)
            if not Transmog:ChromieShouldAttachTransmogTooltip(unit, slot) then
                return
            end
            tip.itemLink = GetInventoryItemLink(unit, slot)
            Transmog:ChromieAttachTransmogTooltip(tip, unit, slot)
        end)
    end

    -- Character/inspect call Show() after SetInventoryItem; attach again once that finishes.
    if PaperDollItemSlotButton_OnEnter then
        hooksecurefunc("PaperDollItemSlotButton_OnEnter", function()
            local button = this
            local slot = button and button:GetID()
            if button and GameTooltip and Transmog:ChromieShouldAttachTransmogTooltip("player", slot) then
                Transmog:ChromieAttachTransmogTooltip(GameTooltip, "player", slot)
            end
        end)
    end

    if InspectPaperDollItemSlotButton_OnEnter then
        hooksecurefunc("InspectPaperDollItemSlotButton_OnEnter", function()
            local button = this
            local unit = inspectUnit()
            local slot = button and button:GetID()
            if button and GameTooltip and Transmog:ChromieShouldAttachTransmogTooltip(unit, slot) then
                Transmog:ChromieAttachTransmogTooltip(GameTooltip, unit, slot)
            end
        end)
    end
end

local function hookPaperDoll()
    if Transmog.chromieHookedPaperDoll then
        return
    end
    if not PaperDollItemSlotButton_Update then
        return
    end
    Transmog.chromieHookedPaperDoll = true
    hooksecurefunc("PaperDollItemSlotButton_Update", function(button)
        Transmog:ChromieRestoreSlotIcon(button, "player")
    end)
    if PaperDollFrame_Update then
        hooksecurefunc("PaperDollFrame_Update", function()
            Transmog:ChromieRefreshPaperdollIcons("player")
        end)
    end
    if CharacterFrame then
        CharacterFrame:HookScript("OnShow", function()
            Transmog:ChromieRefreshPaperdollIcons("player")
        end)
    end
end

local inspectRetry = CreateFrame("Frame")
inspectRetry:Hide()
inspectRetry:SetScript("OnUpdate", function()
    if GetTime() < (inspectRetry.untilTime or 0) then
        return
    end
    inspectRetry.left = (inspectRetry.left or 0) - 1
    inspectRetry.untilTime = GetTime() + 0.15
    if Transmog.ChromieRefreshPaperdollIcons then
        Transmog:ChromieRefreshPaperdollIcons(inspectUnit())
    end
    if inspectRetry.left <= 0 then
        inspectRetry:Hide()
    end
end)

function Transmog:ChromieQueueInspectIconRefresh()
    inspectRetry.left = 8
    inspectRetry.untilTime = 0
    inspectRetry:Show()
end

local function hookInspect()
    if Transmog.chromieHookedInspect then
        return
    end
    -- 3.3.5 Inspect UI is LoadOnDemand; wait until its functions exist.
    if not InspectPaperDollItemSlotButton_Update and not InspectPaperDollFrame_OnShow and not InspectFrame then
        return
    end
    Transmog.chromieHookedInspect = true
    if InspectPaperDollItemSlotButton_Update then
        hooksecurefunc("InspectPaperDollItemSlotButton_Update", function(button)
            button = button or this
            Transmog:ChromieRestoreSlotIcon(button, inspectUnit())
        end)
    end
    -- 3.3.5 has OnShow, not InspectPaperDollFrame_Update.
    if InspectPaperDollFrame_OnShow then
        hooksecurefunc("InspectPaperDollFrame_OnShow", function()
            Transmog:ChromieRefreshPaperdollIcons(inspectUnit())
            Transmog:ChromieQueueInspectIconRefresh()
        end)
    end
    if InspectFrame then
        InspectFrame:HookScript("OnShow", function()
            Transmog:ChromieRefreshPaperdollIcons(inspectUnit())
            Transmog:ChromieQueueInspectIconRefresh()
        end)
    end
end

local function installHooks()
    hookPaperDoll()
    hookInspect()
end

installHooks()

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("UNIT_INVENTORY_CHANGED")
loader:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then
        installHooks()
        Transmog:ChromieInstallTooltipHooks()
        Transmog:ChromieRefreshPaperdollIcons("player")
    elseif event == "ADDON_LOADED" and arg1 == "Blizzard_InspectUI" then
        hookInspect()
    elseif event == "UNIT_INVENTORY_CHANGED" then
        if arg1 == "player" then
            Transmog:ChromieRefreshPaperdollIcons("player")
        elseif InspectFrame and InspectFrame:IsShown() and arg1 == inspectUnit() then
            Transmog:ChromieRefreshPaperdollIcons(arg1)
        end
    end
end)
