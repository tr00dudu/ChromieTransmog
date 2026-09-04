local Transmog = _G.ChromieTransmog

local COLLECT_MSG = "has been added to your appearance collection"
local MISSING_LINE = "You haven't collected this appearance"
local TIP_R, TIP_G, TIP_B = 0.2, 0.8, 1

-- Body-armor rank (1=cloth … 4=plate). Cloaks are not ranked; everyone can wear them.
local ARMOR_RANK = {
    Cloth = 1, Leather = 2, Mail = 3, Plate = 4,
    Tela = 1, Cuero = 2, Malla = 3, Placas = 4,
}
local CLASS_ARMOR_RANK = {
    mage = 1, priest = 1, warlock = 1,
    rogue = 2, druid = 2,
    hunter = 3, shaman = 3,
    warrior = 4, paladin = 4, deathknight = 4,
}
local BODY_ARMOR_INV = {
    INVTYPE_HEAD = true, INVTYPE_SHOULDER = true, INVTYPE_CHEST = true,
    INVTYPE_ROBE = true, INVTYPE_WRIST = true, INVTYPE_HAND = true,
    INVTYPE_WAIST = true, INVTYPE_LEGS = true, INVTYPE_FEET = true,
}
local FLAG_DEFAULTS = {
    showUncollectedTip = true,
    showUncollectedPoor = false,
    showUncollectedLower = true,
    showUncollectedHigher = true,
    showUncollectedHigherBoe = true,
    showUncollectedHigherBop = false,
}

local CLASS_WEAPONS = {
    mage = { ["Staves"] = true, ["Daggers"] = true, ["One-Handed Swords"] = true, ["Wands"] = true },
    priest = { ["Staves"] = true, ["Daggers"] = true, ["One-Handed Maces"] = true, ["Wands"] = true },
    warlock = { ["Staves"] = true, ["Daggers"] = true, ["One-Handed Swords"] = true, ["Wands"] = true },
    rogue = {
        ["Daggers"] = true, ["Fist Weapons"] = true, ["One-Handed Swords"] = true, ["One-Handed Maces"] = true,
        ["One-Handed Axes"] = true, ["Bows"] = true, ["Guns"] = true, ["Crossbows"] = true, ["Thrown"] = true,
    },
    druid = { ["Staves"] = true, ["Daggers"] = true, ["Fist Weapons"] = true, ["One-Handed Maces"] = true, ["Two-Handed Maces"] = true, ["Polearms"] = true },
    hunter = {
        ["Bows"] = true, ["Guns"] = true, ["Crossbows"] = true, ["Staves"] = true, ["Daggers"] = true,
        ["Fist Weapons"] = true, ["One-Handed Axes"] = true, ["Two-Handed Axes"] = true, ["One-Handed Swords"] = true,
        ["Two-Handed Swords"] = true, ["Polearms"] = true, ["Thrown"] = true,
    },
    shaman = {
        ["Staves"] = true, ["Daggers"] = true, ["Fist Weapons"] = true, ["One-Handed Maces"] = true,
        ["Two-Handed Maces"] = true, ["One-Handed Axes"] = true, ["Two-Handed Axes"] = true, ["Shields"] = true,
    },
    paladin = {
        ["One-Handed Swords"] = true, ["Two-Handed Swords"] = true, ["One-Handed Maces"] = true, ["Two-Handed Maces"] = true,
        ["One-Handed Axes"] = true, ["Two-Handed Axes"] = true, ["Polearms"] = true, ["Shields"] = true,
    },
    warrior = {
        ["Daggers"] = true, ["Fist Weapons"] = true, ["Staves"] = true, ["Polearms"] = true, ["Thrown"] = true,
        ["One-Handed Swords"] = true, ["Two-Handed Swords"] = true, ["One-Handed Maces"] = true, ["Two-Handed Maces"] = true,
        ["One-Handed Axes"] = true, ["Two-Handed Axes"] = true, ["Bows"] = true, ["Guns"] = true, ["Crossbows"] = true,
        ["Shields"] = true,
    },
    deathknight = {
        ["One-Handed Swords"] = true, ["Two-Handed Swords"] = true, ["One-Handed Maces"] = true, ["Two-Handed Maces"] = true,
        ["One-Handed Axes"] = true, ["Two-Handed Axes"] = true, ["Polearms"] = true,
    },
}

-- Armor slots that use cloth/leather/mail/plate (Back/cloak is cloth only).
local ARMOR_BODY_SLOTS = { 1, 3, 5, 6, 7, 8, 9, 10 }
local ARMOR_GROUPS = {
    { name = "Cloth", classNum = 5, extraSlots = { 15 } },
    { name = "Leather", classNum = 6 },
    { name = "Mail", classNum = 7 },
    { name = "Plate", classNum = 8 },
}

-- Weapon-type cache keys (EN + ES). One scrape key per type, not per slot.
local WEAPON_GROUPS = {
    { name = "One-Handed Axes", keys = { "w:Weapon:One-Handed Axes", "w:Arma:Hachas de una mano" } },
    { name = "Two-Handed Axes", keys = { "w:Weapon:Two-Handed Axes", "w:Arma:Hachas de dos manos" } },
    { name = "Bows", keys = { "w:Weapon:Bows", "w:Arma:Arcos" } },
    { name = "Guns", keys = { "w:Weapon:Guns", "w:Arma:Armas de fuego" } },
    { name = "One-Handed Maces", keys = { "w:Weapon:One-Handed Maces", "w:Arma:Mazas de una mano" } },
    { name = "Two-Handed Maces", keys = { "w:Weapon:Two-Handed Maces", "w:Arma:Mazas de dos manos" } },
    { name = "Polearms", keys = { "w:Weapon:Polearms", "w:Arma:Armas de asta" } },
    { name = "One-Handed Swords", keys = { "w:Weapon:One-Handed Swords", "w:Arma:Espadas de una mano" } },
    { name = "Two-Handed Swords", keys = { "w:Weapon:Two-Handed Swords", "w:Arma:Espadas de dos manos" } },
    { name = "Staves", keys = { "w:Weapon:Staves", "w:Arma:Bastones" } },
    { name = "Fist Weapons", keys = { "w:Weapon:Fist Weapons", "w:Arma:Armas de puño" } },
    { name = "Daggers", keys = { "w:Weapon:Daggers", "w:Arma:Dagas" } },
    { name = "Thrown", keys = { "w:Weapon:Thrown" } },
    { name = "Crossbows", keys = { "w:Weapon:Crossbows", "w:Arma:Ballestas" } },
    { name = "Wands", keys = { "w:Weapon:Wands", "w:Arma:Varitas" } },
    { name = "Shields", keys = { "w:Armor:Shields", "w:Armadura:Escudos" } },
    { name = "Off-hands", keys = { "w:Armor:Miscellaneous", "w:Armadura:Misceláneo" } },
}

local function scrapedOkHas(okSet, keys)
    local i = 1
    while keys and keys[i] do
        if okSet[keys[i]] then
            return true
        end
        i = i + 1
    end
    return false
end

local function armorSlotsForGroup(group)
    local slots = {}
    local i = 1
    while ARMOR_BODY_SLOTS[i] do
        table.insert(slots, ARMOR_BODY_SLOTS[i])
        i = i + 1
    end
    i = 1
    while group.extraSlots and group.extraSlots[i] do
        table.insert(slots, group.extraSlots[i])
        i = i + 1
    end
    return slots
end

function Transmog:ChromieAccountCollectedEnsure()
    if self.ChromieEnsurePersistDB then
        self:ChromieEnsurePersistDB()
    elseif not ChromieTransmogDB then
        ChromieTransmogDB = { chars = {} }
    end
    if not ChromieTransmogDB.accountCollected then
        ChromieTransmogDB.accountCollected = {}
    end
    if not ChromieTransmogDB.accountScrapedOk then
        ChromieTransmogDB.accountScrapedOk = {}
    end
    local k
    for k in pairs(FLAG_DEFAULTS) do
        if ChromieTransmogDB[k] == nil then
            ChromieTransmogDB[k] = FLAG_DEFAULTS[k]
        end
    end
end

function Transmog:ChromieAccountFlag(name)
    self:ChromieAccountCollectedEnsure()
    if ChromieTransmogDB[name] == nil then
        return FLAG_DEFAULTS[name] and true or false
    end
    return ChromieTransmogDB[name] and true or false
end

function Transmog:ChromieAccountSetFlag(name, on)
    self:ChromieAccountCollectedEnsure()
    ChromieTransmogDB[name] = not not on
end

-- Gossip scrape: copy live ids into the account set. Never shrink or wipe.
-- Empty scrapes must not clear a previous OK scrape flag.
function Transmog:ChromieAccountNoteScan(key, liveSet, liveN, scanOk)
    self:ChromieAccountCollectedEnsure()
    local function addId(id)
        id = tonumber(id)
        if id and id > 1 then
            ChromieTransmogDB.accountCollected[id] = true
        end
    end
    local id
    for id in pairs(liveSet or {}) do
        addId(id)
    end
    -- Persist entry is the real cache; liveSet keys can miss after a type swap.
    local char = self.ChromiePersistChar and self:ChromiePersistChar()
    local entry = key and char and char.unlocks and char.unlocks[key]
    if entry and entry.ids then
        for id in pairs(entry.ids) do
            addId(id)
        end
    end
    if scanOk and key then
        ChromieTransmogDB.accountScrapedOk[key] = true
    end
end

function Transmog:ChromieAccountNoteSystemMessage(msg)
    if not msg or type(msg) ~= "string" then
        return
    end
    if not string.find(string.lower(msg), COLLECT_MSG, 1, true) then
        return
    end
    local id = tonumber(string.match(msg, "|Hitem:(%d+)"))
    if not id or id <= 1 then
        return
    end
    self:ChromieAccountCollectedEnsure()
    ChromieTransmogDB.accountCollected[id] = true
end

function Transmog:ChromieAccountDropCollection()
    self:ChromieAccountCollectedEnsure()
    ChromieTransmogDB.accountCollected = {}
    ChromieTransmogDB.accountScrapedOk = {}
end

function Transmog:ChromieAccountItemIsCollected(itemId)
    itemId = tonumber(itemId)
    if not itemId or itemId <= 1 then
        return false
    end
    self:ChromieAccountCollectedEnsure()
    local collected = ChromieTransmogDB.accountCollected
    if collected[itemId] or collected[tostring(itemId)] then
        return true
    end
    return false
end

local bindTip
local bindCache = {}

local function itemBindKind(link, itemId)
    if itemId and bindCache[itemId] then
        return bindCache[itemId]
    end
    if not link then
        return "boe"
    end
    if not bindTip then
        bindTip = CreateFrame("GameTooltip", "ChromieTransmogBindScan", UIParent, "GameTooltipTemplate")
    end
    bindTip:SetOwner(UIParent, "ANCHOR_NONE")
    bindTip:ClearLines()
    bindTip:SetHyperlink(link)
    local kind = "boe"
    local i = 1
    local fs = getglobal("ChromieTransmogBindScanTextLeft" .. i)
    while fs do
        local t = fs:GetText()
        if t then
            if t == ITEM_BIND_ON_PICKUP or t == ITEM_SOULBOUND or t == ITEM_BIND_QUEST then
                kind = "bop"
                break
            elseif t == ITEM_BIND_ON_EQUIP or t == ITEM_BIND_ON_USE then
                kind = "boe"
                break
            end
        end
        i = i + 1
        fs = getglobal("ChromieTransmogBindScanTextLeft" .. i)
    end
    if itemId then
        bindCache[itemId] = kind
    end
    bindTip:Hide()
    return kind
end

local function classUsesHoldable(class)
    return class == "mage" or class == "priest" or class == "warlock" or class == "druid"
        or class == "rogue" or class == "shaman"
end

-- With the main setting on, this class's armor/weapons always qualify.
-- Lower = weaker body armor. Higher = stronger armor + unusable weapons (BoE/BoP).
function Transmog:ChromieAccountAllowsHigher(link, itemId)
    if not self:ChromieAccountFlag("showUncollectedHigher") then
        return false
    end
    local bind = itemBindKind(link, itemId)
    if bind == "bop" then
        return self:ChromieAccountFlag("showUncollectedHigherBop")
    end
    return self:ChromieAccountFlag("showUncollectedHigherBoe")
end

function Transmog:ChromieAccountFilterAllows(itemType, itemSubType, invType, link, itemId)
    local class = self.class
    if invType == "INVTYPE_CLOAK" then
        return true
    end
    if invType == "INVTYPE_HOLDABLE" then
        if classUsesHoldable(class) then
            return true
        end
        return self:ChromieAccountAllowsHigher(link, itemId)
    end
    if invType == "INVTYPE_SHIELD" then
        local w = CLASS_WEAPONS[class]
        if w and w["Shields"] then
            return true
        end
        return self:ChromieAccountAllowsHigher(link, itemId)
    end
    if BODY_ARMOR_INV[invType] and (itemType == "Armor" or itemType == "Armadura") then
        local itemRank = itemSubType and ARMOR_RANK[itemSubType]
        local classRank = CLASS_ARMOR_RANK[class]
        if not itemRank or not classRank then
            return false
        end
        if itemRank == classRank then
            return true
        end
        if itemRank < classRank then
            return self:ChromieAccountFlag("showUncollectedLower")
        end
        return self:ChromieAccountAllowsHigher(link, itemId)
    end
    local w = CLASS_WEAPONS[class]
    if w and itemSubType and w[itemSubType] then
        return true
    end
    return self:ChromieAccountAllowsHigher(link, itemId)
end

function Transmog:ChromieAccountShouldShowMissing(link)
    if not link or not self:ChromieAccountFlag("showUncollectedTip") then
        return false
    end
    local itemId = self:IDFromLink(link)
    if not itemId or itemId <= 1 then
        return false
    end
    local name, _, quality, _, _, itemType, itemSubType, _, invType = GetItemInfo(link)
    if not name or not invType then
        return false
    end
    quality = tonumber(quality) or 0
    if quality < 2 and not self:ChromieAccountFlag("showUncollectedPoor") then
        return false
    end
    if IsEquippableItem and not IsEquippableItem(link) then
        return false
    end
    if self.ChromieIsRelicLink and self:ChromieIsRelicLink(link) then
        return false
    end
    local frame = self.frameFromInvType and self:frameFromInvType(invType)
    if not frame then
        return false
    end
    local slot = self.inventorySlots and self.inventorySlots[frame:GetName()]
    if slot and self.ChromieSlotSupportsTransmog and not self:ChromieSlotSupportsTransmog(slot) then
        return false
    end
    if not self:ChromieAccountFilterAllows(itemType, itemSubType, invType, link, itemId) then
        return false
    end
    if self:ChromieAccountItemIsCollected(itemId) then
        return false
    end
    return true
end

local function tipHasMissingLine(tip)
    if not tip or not tip.GetName then
        return false
    end
    local name = tip:GetName()
    local i = 1
    local fs = getglobal(name .. "TextLeft" .. i)
    while fs do
        local t = fs:GetText()
        if t and string.find(t, MISSING_LINE, 1, true) then
            return true
        end
        i = i + 1
        fs = getglobal(name .. "TextLeft" .. i)
    end
    return false
end

function Transmog:ChromieAccountAttachUncollected(tip)
    if not tip or not tip.GetItem then
        return
    end
    -- cacheItem() uses GameTooltip:SetHyperlink with no owner; skip those.
    -- Must run before Ensure — Transmog_OnLoad calls cacheItem during XML OnLoad.
    if tip.GetOwner and not tip:GetOwner() then
        return
    end
    if not self:ChromieAccountFlag("showUncollectedTip") then
        return
    end
    if tipHasMissingLine(tip) then
        return
    end
    local _, link = tip:GetItem()
    if not self:ChromieAccountShouldShowMissing(link) then
        return
    end
    if tip.AddLine then
        tip:AddLine(MISSING_LINE, TIP_R, TIP_G, TIP_B)
        tip:Show()
    end
end

function Transmog:ChromieAccountScanStatusLines()
    self:ChromieAccountCollectedEnsure()
    local okSet = ChromieTransmogDB.accountScrapedOk
    if type(okSet) ~= "table" then
        okSet = {}
    end
    local lines = {}
    table.insert(lines, "|cffaaaaaaNot-collected tooltips can be wrong for a slot/type/proficiency until that type is scanned at a Warpweaver. See individual slot statuses below.|r")
    table.insert(lines, "")

    local g = 1
    while ARMOR_GROUPS[g] do
        local group = ARMOR_GROUPS[g]
        local slots = armorSlotsForGroup(group)
        local missing = {}
        local okN = 0
        local total = 0
        local s = 1
        while slots[s] do
            total = total + 1
            local key = "s:" .. tostring(slots[s]) .. ":" .. tostring(group.classNum)
            if okSet[key] then
                okN = okN + 1
            else
                local label
                if self.ChromieSlotLabelShort then
                    label = self:ChromieSlotLabelShort(slots[s])
                end
                table.insert(missing, label or ("slot " .. tostring(slots[s])))
            end
            s = s + 1
        end
        if okN == 0 then
            table.insert(lines, group.name .. ": missing")
        elseif okN == total then
            table.insert(lines, "|cff00ff00" .. group.name .. ": OK|r")
        else
            table.insert(lines, group.name .. ": Partial (" .. table.concat(missing, ", ") .. " missing)")
        end
        g = g + 1
    end

    table.insert(lines, "")

    g = 1
    while WEAPON_GROUPS[g] do
        local group = WEAPON_GROUPS[g]
        if scrapedOkHas(okSet, group.keys) then
            table.insert(lines, "|cff00ff00" .. group.name .. ": OK|r")
        else
            table.insert(lines, group.name .. ": missing")
        end
        g = g + 1
    end

    local n = 0
    local collected = ChromieTransmogDB.accountCollected
    if collected then
        local id
        for id in pairs(collected) do
            n = n + 1
        end
    end
    table.insert(lines, "")
    table.insert(lines, n .. " appearances collected")
    return lines
end

local function hookTip(tip)
    if not tip or tip.chromieAccountHooked then
        return
    end
    tip.chromieAccountHooked = true
    local methods = { "SetBagItem", "SetLootItem", "SetLootRollItem", "SetAuctionItem", "SetMerchantItem", "SetHyperlink" }
    local i = 1
    while methods[i] do
        local method = methods[i]
        if tip[method] then
            hooksecurefunc(tip, method, function(self)
                Transmog:ChromieAccountAttachUncollected(self or tip)
            end)
        end
        i = i + 1
    end
    if not tip.chromieAccountSetItemHooked and tip.GetScript and tip.SetScript then
        tip.chromieAccountSetItemHooked = true
        local orig = tip:GetScript("OnTooltipSetItem")
        tip:SetScript("OnTooltipSetItem", function()
            if orig then
                orig()
            end
            Transmog:ChromieAccountAttachUncollected(this or tip)
        end)
    end
end

function Transmog:ChromieAccountInstallTooltipHooks()
    if self.chromieAccountTipsHooked then
        return
    end
    self.chromieAccountTipsHooked = true
    hookTip(GameTooltip)
    hookTip(ItemRefTooltip)
end

StaticPopupDialogs["CHROMIE_TRANSMOG_DROP_COLLECTION"] = {
    text = "Drop the account-wide collection cache?\n\nThis does not clear this character's Chromie scrape cache or Warpweaver sets.\n\nOnly do this if collection data looks seriously wrong.",
    button1 = TEXT(YES),
    button2 = TEXT(NO),
    OnAccept = function()
        if Transmog.ChromieAccountDropCollection then
            Transmog:ChromieAccountDropCollection()
        end
        if Transmog.ChromieCacheTabRefresh then
            Transmog:ChromieCacheTabRefresh(true)
        end
        if Transmog.Chat then
            Transmog:Chat("Account collection cache cleared.")
        end
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    showAlert = 1,
}

Transmog:ChromieAccountInstallTooltipHooks()
