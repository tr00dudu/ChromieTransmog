local Transmog = _G.ChromieTransmog

local currencyTextLayoutConfigured = false

local function ConfigureCurrencyTextLayout()
    if currencyTextLayoutConfigured then
        return
    end

    ChromieTransmogFrameCurrencyText:ClearAllPoints()
    ChromieTransmogFrameCurrencyText:SetWidth(180)
    ChromieTransmogFrameCurrencyText:SetHeight(14)
    ChromieTransmogFrameCurrencyText:SetPoint("RIGHT", ChromieTransmogFrameApplyButton, "LEFT", -8, 0)
    ChromieTransmogFrameCurrencyText:SetJustifyH("RIGHT")

    currencyTextLayoutConfigured = true
end

-- Estimated ChromieCraft cost: hide and clear are free. A new appearance
-- costs the equipped item's vendor price, with a 1g minimum.
local MIN_MOG_COPPER = 10000

function Transmog:ChromieSlotVendorPrice(slot)
    local link = GetInventoryItemLink("player", slot)
    if not link then
        return 0
    end
    local price = select(11, GetItemInfo(link))
    return tonumber(price) or 0
end

function Transmog:ChromieSlotMogCost(slot)
    local price = self:ChromieSlotVendorPrice(slot)
    if price < MIN_MOG_COPPER then
        return MIN_MOG_COPPER
    end
    return price
end

function Transmog:ChromiePendingCost()
    local pending = 0
    local copper = 0
    local paid = 0
    local slotName, slot
    for slotName, slot in pairs(self.inventorySlots) do
        local want = self.transmogStatusToServer[slot]
        local have = self.transmogStatusFromServer[slot]
        if want ~= have and want ~= self.UNKNOWN_MOG_ID then
            pending = pending + 1
            if want and want ~= 0 and want ~= self.HIDDEN_ITEM_ID then
                local price = self:ChromieSlotMogCost(slot)
                copper = copper + price
                paid = paid + 1
            end
        end
    end
    return pending, copper, paid
end

function Transmog:ChromieSlotNeedsApply(slot)
    local have = self.transmogStatusFromServer[slot]
    local want = self.transmogStatusToServer[slot]
    if have == want or want == self.UNKNOWN_MOG_ID then
        return false
    end
    return true
end

function Transmog:ChromieNextPendingApply()
    local current = self.currentTransmogSlot
    if current and self:ChromieSlotNeedsApply(current) then
        return current, self.transmogStatusToServer[current]
    end
    local _, slot
    for _, slot in pairs(self.inventorySlots) do
        if self:ChromieSlotNeedsApply(slot) then
            return slot, self.transmogStatusToServer[slot]
        end
    end
    return nil
end

-- Sends a cost calculation request to the server when transmog changes are pending.
function Transmog:calculateCost(to)

	twfdebug("Transmog:calculateCost")

    if to == 0 and not self.chromieMultiActive then
        ChromieTransmogFrameApplyButton:Disable()
        ChromieTransmogFrameApplyButton:SetText("Change any Items")
        ChromieTransmogFrameCurrencyText:Hide()
        return
    end

    local pending, copper = self:ChromiePendingCost()
    if self.chromieMultiActive and pending > 0 then
        ChromieTransmogFrameApplyButton:Disable()
        ChromieTransmogFrameApplyButton:SetText("Talk to Warpweaver")
        if copper > 0 then
            local canBuy = 1
            if GetMoney() < copper then
                canBuy = 0
            end
            self:updateCost(copper, canBuy)
            ChromieTransmogFrameApplyButton:Disable()
            ChromieTransmogFrameApplyButton:SetText("Talk to Warpweaver")
        else
            ChromieTransmogFrameCurrencyText:Hide()
        end
        return
    end
    if pending == 0 then
        ChromieTransmogFrameApplyButton:Disable()
        ChromieTransmogFrameApplyButton:SetText("Change any Items")
        ChromieTransmogFrameCurrencyText:Hide()
        return
    end

    ChromieTransmogFrameApplyButton:SetText("Apply Transmog")
    if copper <= 0 then
        ChromieTransmogFrameApplyButton:Enable()
        ChromieTransmogFrameCurrencyText:Hide()
        return
    end

    local canBuy = 1
    if GetMoney() < copper then
        canBuy = 0
    end
    self:updateCost(copper, canBuy)
end

local function formatNumberWithCommas(amount)
    local formatted = tostring(amount)
    while true do
        local newFormatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        formatted = newFormatted
        if k == 0 then
            break
        end
    end
    return formatted
end

-- Converts a copper amount into gold, silver, and copper values.
function formatCurrency(amount)
    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount - gold * 10000) / 100)
    local copper = amount - gold * 10000 - silver * 100
    return copper, silver, gold
end

-- Updates the apply button text and cost display based on server response.
function Transmog:updateCost(cost, canPurchase)
    twfdebug("updateCost cost:" .. cost .. " canPurchase: " .. canPurchase)

    if canPurchase == 1 then
        ChromieTransmogFrameApplyButton:Enable()
        ChromieTransmogFrameApplyButton:SetText("Apply Transmog")
    else
        ChromieTransmogFrameApplyButton:Disable()
        ChromieTransmogFrameApplyButton:SetText("Not enough money")
    end

    if cost > 0 then
        ConfigureCurrencyTextLayout()
        ChromieTransmogFrameCurrencyText:Show()
        local copper, silver, gold = formatCurrency(cost)
        local costText = ""

        if gold > 0 then
            costText = formatNumberWithCommas(gold) .. "|TInterface\\MoneyFrame\\UI-GoldIcon:14:14:2:0|t"
        end

        if silver > 0 and gold < 10000 then
            if costText ~= "" then
                costText = costText .. " "
            end
            costText = costText .. silver .. "|TInterface\\MoneyFrame\\UI-SilverIcon:14:14:2:0|t"
        end

        if copper > 0 and gold < 100 then
            if costText ~= "" then
                costText = costText .. " "
            end
            costText = costText .. copper .. "|TInterface\\MoneyFrame\\UI-CopperIcon:14:14:2:0|t"
        end

        ChromieTransmogFrameCurrencyText:SetText(costText)
    end
end

-- Converts an item class string (e.g. "Weapon") to its numeric ID.
function Transmog:ItemClassStrToNum(itemClassStr)
	local itemClass = -1

	if itemClassStr then
		if itemClassStr == "Weapon" or itemClassStr == "Arma" then
			itemClass = 2
		elseif itemClassStr == "Armor" or itemClassStr == "Armadura" then
			itemClass = 4
		end
	end

	if itemClass == -1 then
		twferror("Invalid item class " .. itemClassStr)
	end

	return itemClass
end

-- Converts an item subclass string to its numeric ID, including localized names.
function Transmog:ItemSubclassStrToNum(itemSubclassStr)
	local itemSubclass = -1

	if itemSubclassStr then
		if itemSubclassStr == "One-Handed Axes" or itemSubclassStr == "Hachas de una mano" then
			itemSubclass = 0
		elseif itemSubclassStr == "Two-Handed Axes" or itemSubclassStr == "Hachas de dos manos" then
			itemSubclass = 1
		elseif itemSubclassStr == "Bows" or itemSubclassStr == "Arcos" then
			itemSubclass = 2
		elseif itemSubclassStr == "Guns" or itemSubclassStr == "Armas de fuego" then
			itemSubclass = 3
		elseif itemSubclassStr == "One-Handed Maces" or itemSubclassStr == "Mazas de una mano" then
			itemSubclass = 4
		elseif itemSubclassStr == "Two-Handed Maces" or itemSubclassStr == "Mazas de dos manos" then
			itemSubclass = 5
		elseif itemSubclassStr == "Polearms" or itemSubclassStr == "Armas de asta" then
			itemSubclass = 6
		elseif itemSubclassStr == "One-Handed Swords" or itemSubclassStr == "Espadas de una mano" then
			itemSubclass = 7
		elseif itemSubclassStr == "Two-Handed Swords" or itemSubclassStr == "Espadas de dos manos" then
			itemSubclass = 8
		elseif itemSubclassStr == "Staves" or itemSubclassStr == "Bastones" then
			itemSubclass = 10
		elseif itemSubclassStr == "Fist Weapons" or itemSubclassStr == "Armas de puño" then
			itemSubclass = 13
		elseif itemSubclassStr == "Daggers" or itemSubclassStr == "Dagas" then
			itemSubclass = 15
		elseif itemSubclassStr == "Crossbows" or itemSubclassStr == "Ballestas" then
			itemSubclass = 18
		elseif itemSubclassStr == "Wands" or itemSubclassStr == "Varitas" then
			itemSubclass = 19
		elseif itemSubclassStr == "Cloth" or itemSubclassStr == "Tela" then
			itemSubclass = 1
		elseif itemSubclassStr == "Leather" or itemSubclassStr == "Cuero" then
			itemSubclass = 2
		elseif itemSubclassStr == "Mail" or itemSubclassStr == "Malla" then
			itemSubclass = 3
		elseif itemSubclassStr == "Plate" or itemSubclassStr == "Placas" then
			itemSubclass = 4
		elseif itemSubclassStr == "Shields" or itemSubclassStr == "Escudos" then
			itemSubclass = 6
		elseif itemSubclassStr == "Miscellaneous" or itemSubclassStr == "Misceláneo" then
			itemSubclass = 0
		end
	end

	if itemSubclass == -1 then
		twferror("Invalid item subclass " .. itemSubclassStr)
	end

	return itemSubclass
end
