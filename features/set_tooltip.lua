local Transmog = _G.ChromieTransmog

-- C set matching uses the transmog fake item id, so piece/bonus lines stay grey.
-- Rewrite only the existing set block. Do not insert, delete, or rebuild lines.

local GREEN_R, GREEN_G, GREEN_B = 0.1, 1.0, 0.1
local GRAY_R, GRAY_G, GRAY_B = 0.5, 0.5, 0.5
if GREEN_FONT_COLOR then
    GREEN_R = GREEN_FONT_COLOR.r or GREEN_R
    GREEN_G = GREEN_FONT_COLOR.g or GREEN_G
    GREEN_B = GREEN_FONT_COLOR.b or GREEN_B
end
if GRAY_FONT_COLOR then
    GRAY_R = GRAY_FONT_COLOR.r or GRAY_R
    GRAY_G = GRAY_FONT_COLOR.g or GRAY_G
    GRAY_B = GRAY_FONT_COLOR.b or GRAY_B
end

local function stripCodes(text)
    if not text then
        return ""
    end
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    return text
end

local function normalizeName(text)
    text = string.lower(stripCodes(text or ""))
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local function namesMatch(a, b)
    if not a or not b or a == "" or b == "" then
        return false
    end
    if a == b then
        return true
    end
    if string.find(a, b, 1, true) then
        return true
    end
    if string.find(b, a, 1, true) then
        return true
    end
    return false
end

local function leftLine(tip, i)
    local name = tip and tip.GetName and tip:GetName()
    if not name then
        return nil
    end
    return getglobal(name .. "TextLeft" .. i)
end

local function equippedNames(unit)
    unit = unit or "player"
    local names = {}
    local slots = Transmog.inventorySlots
    if not slots then
        return names
    end
    local _, slot
    for _, slot in pairs(slots) do
        local link = GetInventoryItemLink(unit, slot)
        if link then
            local name = GetItemInfo(link)
            if name then
                table.insert(names, normalizeName(name))
            end
        end
    end
    return names
end

local function headerParts(stripped)
    local _, _, n, m = string.find(stripped, " %((%d+)/(%d+)%)$")
    if not n then
        return nil
    end
    return tonumber(n), tonumber(m)
end

local function bonusNeed(stripped)
    if not stripped or stripped == "" then
        return nil
    end
    local _, _, k = string.find(stripped, "^%(%s*(%d+)%s*%)%s*set")
    if k then
        return tonumber(k)
    end
    _, _, k = string.find(stripped, "^%(%s*(%d+)%s*%)")
    if k then
        return tonumber(k)
    end
    return nil
end

local function isPieceText(text, stripped)
    if not text or stripped == "" then
        return false
    end
    if string.find(text, "\n", 1, true) then
        return false
    end
    if headerParts(stripped) or bonusNeed(stripped) then
        return false
    end
    local first = string.sub(stripped, 1, 1)
    if first == "\"" or first == "'" then
        return false
    end
    if string.find(text, "Transmogrified", 1, true) then
        return false
    end
    if string.find(text, "You haven't collected this appearance", 1, true) then
        return false
    end
    return true
end

local function pieceMatches(piece, names)
    local p = 1
    while names[p] do
        if namesMatch(names[p], piece) then
            return true
        end
        p = p + 1
    end
    return false
end

local function countEquipped(pieceNorms, names)
    local count = 0
    local e = 1
    while names[e] do
        local p = 1
        while pieceNorms[p] do
            if namesMatch(names[e], pieceNorms[p]) then
                count = count + 1
                break
            end
            p = p + 1
        end
        e = e + 1
    end
    return count
end

local function paint(fs, on)
    if not fs or not fs.SetTextColor then
        return
    end
    if on then
        fs:SetTextColor(GREEN_R, GREEN_G, GREEN_B)
    else
        fs:SetTextColor(GRAY_R, GRAY_G, GRAY_B)
    end
end

local function rewriteHeader(fs, text, count)
    local newText = string.gsub(text, "%(%d+/(%d+)%)%s*$", "(" .. count .. "/%1)", 1)
    if newText ~= text then
        fs:SetText(newText)
    end
end

local function processSetBlock(tip, headerIndex, names, maxLine)
    local headerFs = leftLine(tip, headerIndex)
    if not headerFs then
        return headerIndex + 1
    end
    local pieceFs = {}
    local pieceNorms = {}
    local i = headerIndex + 1
    while i <= maxLine do
        local fs = leftLine(tip, i)
        if not fs then
            break
        end
        local text = fs:GetText()
        local stripped = normalizeName(text)
        if not isPieceText(text, stripped) then
            break
        end
        table.insert(pieceFs, fs)
        table.insert(pieceNorms, stripped)
        i = i + 1
    end

    local count = countEquipped(pieceNorms, names)
    rewriteHeader(headerFs, headerFs:GetText() or "", count)

    local p = 1
    while pieceFs[p] do
        paint(pieceFs[p], pieceMatches(pieceNorms[p], names))
        p = p + 1
    end

    -- C often inserts a blank FontString between the piece list and bonuses.
    -- Only recolor lines that are actually "(n) Set:"; do not touch flavor, price, etc.
    local seenBonus
    while i <= maxLine do
        local fs = leftLine(tip, i)
        if not fs then
            break
        end
        local stripped = normalizeName(fs:GetText())
        if stripped == "" then
            if seenBonus then
                break
            end
            i = i + 1
        else
            local need = bonusNeed(stripped)
            if not need then
                break
            end
            paint(fs, count >= need)
            seenBonus = true
            i = i + 1
        end
    end
    return i
end

function Transmog:ChromieFixSetTooltip(tip, unit)
    if not tip or not tip.GetName then
        return
    end
    if tip.GetOwner and not tip:GetOwner() then
        return
    end
    local maxLine = 0
    if tip.NumLines then
        maxLine = tip:NumLines() or 0
    end
    if maxLine < 1 then
        return
    end
    local names = equippedNames(unit or "player")
    local i = 1
    while i <= maxLine do
        local fs = leftLine(tip, i)
        if not fs then
            return
        end
        local text = fs:GetText()
        if text and not string.find(text, "\n", 1, true) then
            local stripped = normalizeName(text)
            if headerParts(stripped) then
                i = processSetBlock(tip, i, names, maxLine)
            else
                i = i + 1
            end
        else
            i = i + 1
        end
    end
end

local function hookTip(tip)
    if not tip or tip.chromieSetHooked then
        return
    end
    tip.chromieSetHooked = true

    if tip.SetInventoryItem then
        hooksecurefunc(tip, "SetInventoryItem", function(self, unit, slot)
            self = self or tip
            self.chromieSetUnit = unit
            Transmog:ChromieFixSetTooltip(self, unit)
        end)
    end

    local methods = { "SetBagItem", "SetLootItem", "SetLootRollItem", "SetAuctionItem", "SetMerchantItem", "SetHyperlink" }
    local m = 1
    while methods[m] do
        local method = methods[m]
        if tip[method] then
            hooksecurefunc(tip, method, function(self)
                self = self or tip
                self.chromieSetUnit = nil
                Transmog:ChromieFixSetTooltip(self, "player")
            end)
        end
        m = m + 1
    end

    if tip.GetScript and tip.SetScript then
        local origSet = tip:GetScript("OnTooltipSetItem")
        tip:SetScript("OnTooltipSetItem", function()
            if origSet then
                origSet()
            end
            local self = this or tip
            Transmog:ChromieFixSetTooltip(self, self.chromieSetUnit or "player")
        end)
        local origClear = tip:GetScript("OnTooltipCleared")
        tip:SetScript("OnTooltipCleared", function()
            local self = this or tip
            self.chromieSetUnit = nil
            if origClear then
                origClear()
            end
        end)
    end
end

function Transmog:ChromieInstallSetTooltipHooks()
    hookTip(GameTooltip)
    hookTip(ItemRefTooltip)
    hookTip(ShoppingTooltip1)
    hookTip(ShoppingTooltip2)
    hookTip(FashionTooltip)
end

Transmog:ChromieInstallSetTooltipHooks()

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    Transmog:ChromieInstallSetTooltipHooks()
end)
