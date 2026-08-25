local Transmog = _G.ChromieTransmog

-- Character/inspect paperdoll use GetInventoryItemTexture, which follows the
-- visible transmog entry. Bags use the real item. Always paint equipped slots
-- from the actual item link so hidden mogs are not empty and mogged slots
-- keep their original icon.

local function originalItemTexture(unit, slot)
    local link = GetInventoryItemLink(unit, slot)
    if not link then
        return nil
    end
    local tex
    if GetItemIcon then
        local itemId = Transmog:IDFromLink(link)
        if itemId then
            tex = GetItemIcon(itemId)
        end
    end
    if not tex then
        tex = select(10, GetItemInfo(link))
    end
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
        return
    end
    SetItemButtonTexture(button, tex)
    button.hasItem = 1
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

-- GetInventoryItemTexture follows the visible fake entry on character and
-- inspect. Compare that to the real item icon: hidden slot vs different icon.
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

function Transmog:ChromieAppearanceLabel(unit, slot)
    local link = GetInventoryItemLink(unit, slot)
    if not link then
        return nil
    end

    local state = mogStateFromTextures(unit, slot)

    if unit == "player" then
        local from = self.transmogStatusFromServer and self.transmogStatusFromServer[slot]
        if from == self.HIDDEN_ITEM_ID then
            state = "hidden"
        elseif from == self.UNKNOWN_MOG_ID or (from and from > 1) then
            if state ~= "hidden" then
                state = "mogged"
            end
        end
        if not state then
            local gossip = self.transmogGossipIcon and self.transmogGossipIcon[slot]
            local origKey = iconKey(originalItemTexture(unit, slot))
            if gossip and iconKey(gossip) ~= origKey and not isHiddenTexture(gossip) then
                state = "mogged"
            end
        end
    end

    if state == "hidden" then
        self:ChromieRememberMog(link, true)
        return LABEL_HIDDEN
    end
    if state == "mogged" then
        self:ChromieRememberMog(link, false)
        return LABEL_MOGGED
    end
    self:ChromieForgetMog(link)
    return nil
end

function Transmog:ChromieAppearanceLabelForLink(link)
    local uid = self:ChromieLinkUniqueId(link)
    if not uid or not self.mogByUniqueId then
        return nil
    end
    local state = self.mogByUniqueId[uid]
    if state == "hidden" then
        return LABEL_HIDDEN
    end
    if state == "mogged" then
        return LABEL_MOGGED
    end
    return nil
end

function Transmog:ChromieAttachTransmogTooltip(tooltip, unit, slot, bagLink)
    if not tooltip then
        return
    end
    local label
    if unit and slot then
        label = self:ChromieAppearanceLabel(unit, slot)
    elseif bagLink then
        label = self:ChromieAppearanceLabelForLink(bagLink)
    end
    if not label then
        return
    end
    local left2 = getglobal(tooltip:GetName() .. "TextLeft2")
    if not left2 then
        return
    end
    local existing = left2:GetText() or ""
    if string.find(existing, "Transmogrified", 1, true) then
        return
    end
    if existing == "" then
        left2:SetText(label)
    else
        left2:SetText(label .. "\n|cffffffff" .. existing)
    end
    tooltip:Show()
end

local function hookPaperDoll()
    if Transmog.chromieHookedPaperDoll or not PaperDollItemSlotButton_Update then
        return
    end
    Transmog.chromieHookedPaperDoll = true
    hooksecurefunc("PaperDollItemSlotButton_Update", function(button)
        Transmog:ChromieRestoreSlotIcon(button, "player")
    end)
end

local function hookInspect()
    if Transmog.chromieHookedInspect or not InspectPaperDollItemSlotButton_Update then
        return
    end
    Transmog.chromieHookedInspect = true
    hooksecurefunc("InspectPaperDollItemSlotButton_Update", function(button)
        local unit = "target"
        if InspectFrame and InspectFrame.unit then
            unit = InspectFrame.unit
        end
        Transmog:ChromieRestoreSlotIcon(button, unit)
    end)
end

hookPaperDoll()
if IsAddOnLoaded("Blizzard_InspectUI") then
    hookInspect()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function()
    if arg1 == "Blizzard_InspectUI" then
        hookInspect()
    end
end)
