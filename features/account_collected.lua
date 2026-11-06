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

function Transmog:ChromieAccountCollectedEnsure()
    if self.ChromieEnsurePersistDB then
        self:ChromieEnsurePersistDB()
    elseif not ChromieTransmogDB then
        ChromieTransmogDB = { chars = {} }
    end
    if not ChromieTransmogDB.accountCollected then
        ChromieTransmogDB.accountCollected = {}
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

function Transmog:ChromieAccountUncollectedTipColor()
    self:ChromieAccountCollectedEnsure()
    local c = ChromieTransmogDB.uncollectedTipColor
    if type(c) == "table" then
        return c.r or TIP_R, c.g or TIP_G, c.b or TIP_B
    end
    return TIP_R, TIP_G, TIP_B
end

function Transmog:ChromieAccountSetUncollectedTipColor(r, g, b)
    self:ChromieAccountCollectedEnsure()
    ChromieTransmogDB.uncollectedTipColor = {
        r = tonumber(r) or TIP_R,
        g = tonumber(g) or TIP_G,
        b = tonumber(b) or TIP_B,
    }
end

function Transmog:ChromieAccountResetUncollectedTipColor()
    self:ChromieAccountCollectedEnsure()
    ChromieTransmogDB.uncollectedTipColor = nil
end

function Transmog:ChromieAccountInvalidateCollectedGroups()
    self.accountCollectedGroups = nil
end

function Transmog:ChromieAccountCollectedGroups()
    if self.accountCollectedGroups then
        return self.accountCollectedGroups
    end
    self:ChromieAccountCollectedEnsure()
    local groups = {}
    local collected = ChromieTransmogDB.accountCollected
    local id, on
    for id, on in pairs(collected) do
        if on then
            local group = self:ChromieAppearanceGroup(id)
            if group then
                groups[group] = true
            end
        end
    end
    self.accountCollectedGroups = groups
    return groups
end

-- Gossip scrape: copy live ids into the account set. Never shrink or wipe.
function Transmog:ChromieAccountNoteScan(key, liveSet)
    self:ChromieAccountInvalidateCollectedGroups()
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
    self:ChromieAccountInvalidateCollectedGroups()
end

function Transmog:ChromieAccountNoteSystemMessage(msg)
    if not msg or type(msg) ~= "string" then
        return
    end
    if self.ChromieSyncNoteLine and self:ChromieSyncNoteLine(msg) then
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
    self:ChromieAccountInvalidateCollectedGroups()
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
    local group = self:ChromieAppearanceGroup(itemId)
    if group and self:ChromieAccountCollectedGroups()[group] then
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
        local r, g, b = self:ChromieAccountUncollectedTipColor()
        tip:AddLine(MISSING_LINE, r, g, b)
        tip:Show()
    end
end

function Transmog:ChromieAccountScanStatusLines()
    self:ChromieAccountCollectedEnsure()
    local n = 0
    local collected = ChromieTransmogDB.accountCollected
    if collected then
        local id
        for id in pairs(collected) do
            n = n + 1
        end
    end
    local lines = {}
    if self.chromieSyncFailed then
        table.insert(lines, "Status: last sync failed")
    end
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
            local self = this or tip
            if orig then
                orig(self)
            end
            Transmog:ChromieAccountAttachUncollected(self)
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

local SYNC_QUIET_SEC = 1
local SYNC_FAIL_SEC = 5

function Transmog:ChromieAccountCollectionEmpty()
    self:ChromieAccountCollectedEnsure()
    local collected = ChromieTransmogDB.accountCollected
    if not collected then
        return true
    end
    local id, on
    for id, on in pairs(collected) do
        id = tonumber(id)
        if on and id and id > 1 then
            return false
        end
    end
    return true
end

function Transmog:ChromieSyncEnsureTicker()
    if self.chromieSyncTicker then
        return
    end
    local f = CreateFrame("Frame")
    f:Hide()
    f:SetScript("OnUpdate", function()
        local dt = arg1 or 0
        if Transmog.chromieSyncQuietLeft then
            Transmog.chromieSyncQuietLeft = Transmog.chromieSyncQuietLeft - dt
            if Transmog.chromieSyncQuietLeft <= 0 then
                Transmog.chromieSyncQuietLeft = nil
                Transmog:ChromieSyncCommit()
            end
        end
        if Transmog.chromieSyncFailLeft then
            Transmog.chromieSyncFailLeft = Transmog.chromieSyncFailLeft - dt
            if Transmog.chromieSyncFailLeft <= 0 then
                Transmog.chromieSyncFailLeft = nil
                if not Transmog.chromieSyncGotLine then
                    Transmog:ChromieSyncFail()
                end
            end
        end
        if not Transmog.chromieSyncQuietLeft and not Transmog.chromieSyncFailLeft then
            f:Hide()
        end
    end)
    self.chromieSyncTicker = f
end

function Transmog:ChromieSyncArmQuiet()
    self.chromieSyncQuietLeft = SYNC_QUIET_SEC
    self:ChromieSyncEnsureTicker()
    self.chromieSyncTicker:Show()
end

function Transmog:ChromieSyncInstallFilter()
    if self.chromieSyncFilterOn or not ChatFrame_AddMessageEventFilter then
        return
    end
    self.chromieSyncFilterOn = true
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(...)
        local n = select("#", ...)
        local i = 1
        while i <= n do
            local v = select(i, ...)
            if type(v) == "string" and string.find(v, "TRANSMOG_SYNC:", 1, true) then
                return true
            end
            i = i + 1
        end
    end)
end

function Transmog:ChromieSyncNoteLine(msg)
    if not msg or not string.find(msg, "TRANSMOG_SYNC:", 1, true) then
        return false
    end
    local id = tonumber(string.match(msg, "TRANSMOG_SYNC:%s*(%d+)"))
    if id and id > 1 then
        if not self.chromieSyncBurst then
            self.chromieSyncIds = {}
            self.chromieSyncBurst = true
        end
        self.chromieSyncIds[id] = true
        self.chromieSyncGotLine = true
        self.chromieSyncFailLeft = nil
        self:ChromieSyncArmQuiet()
    end
    return true
end

function Transmog:ChromieSyncSend()
    if self.chromieSyncDone or self.chromieSyncInFlight then
        return
    end
    self:ChromieSyncInstallFilter()
    local box = ChatFrame1EditBox or (DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox)
    if not box or not ChatEdit_SendText then
        self:ChatAlways(".transmog sync could not be sent.")
        self.chromieSyncFailed = true
        if self.ChromieCacheTabRefresh then
            self:ChromieCacheTabRefresh(true)
        end
        return
    end
    local old = box:GetText() or ""
    box:SetText(".transmog sync")
    ChatEdit_SendText(box, 0)
    box:SetText(old)
    self.chromieSyncInFlight = true
    self.chromieSyncGotLine = nil
    self.chromieSyncFailLeft = SYNC_FAIL_SEC
    self:ChromieSyncEnsureTicker()
    self.chromieSyncTicker:Show()
end

function Transmog:ChromieSyncFollowOpen()
    if not self.chromieSyncOpenAfterFlight or self.chromieSyncDone then
        self.chromieSyncOpenAfterFlight = nil
        return
    end
    self.chromieSyncOpenAfterFlight = nil
    self.chromieSyncOpenChecked = true
    self:ChromieSyncSend()
end

function Transmog:ChromieSyncFail()
    self.chromieSyncInFlight = nil
    self.chromieSyncBurst = nil
    self.chromieSyncFailed = true
    self:ChatAlways(".transmog sync returned nothing. Collection cache is unchanged.")
    if self.ChromieCacheTabRefresh then
        self:ChromieCacheTabRefresh(true)
    end
    self:ChromieSyncFollowOpen()
end

function Transmog:ChromieSyncCommit()
    local fresh = {}
    local n = 0
    local id
    for id in pairs(self.chromieSyncIds or {}) do
        id = tonumber(id)
        if id and id > 1 then
            fresh[id] = true
            n = n + 1
        end
    end
    self.chromieSyncBurst = nil
    self.chromieSyncInFlight = nil
    if n == 0 then
        self.chromieSyncFailed = true
        self:ChatAlways(".transmog sync returned nothing. Collection cache is unchanged.")
        if self.ChromieCacheTabRefresh then
            self:ChromieCacheTabRefresh(true)
        end
        self:ChromieSyncFollowOpen()
        return
    end
    self:ChromieAccountCollectedEnsure()
    ChromieTransmogDB.accountCollected = fresh
    ChromieTransmogDB.accountSynced = true
    self.chromieSyncFailed = nil
    self:ChromieAccountInvalidateCollectedGroups()
    self.chromieSyncDone = true
    self.chromieSyncOpenAfterFlight = nil
    if self.ChromieCacheTabRefresh then
        self:ChromieCacheTabRefresh(true)
    end
end

function Transmog:ChromieSyncRequest(source)
    if self.chromieSyncDone then
        return
    end
    if source == "world" then
        if self.chromieSyncWorldChecked then
            return
        end
        self.chromieSyncWorldChecked = true
        if not self:ChromieAccountCollectionEmpty() then
            return
        end
    elseif source == "open" then
        if self.chromieSyncOpenChecked then
            return
        end
        if self.chromieSyncInFlight then
            self.chromieSyncOpenAfterFlight = true
            return
        end
        self.chromieSyncOpenChecked = true
    else
        return
    end
    if self.chromieSyncInFlight then
        return
    end
    self:ChromieSyncSend()
end

local syncWorld = CreateFrame("Frame")
syncWorld:RegisterEvent("PLAYER_ENTERING_WORLD")
syncWorld:SetScript("OnEvent", function()
    if Transmog.ChromieSyncRequest then
        Transmog:ChromieSyncRequest("world")
    end
end)

Transmog:ChromieAccountInstallTooltipHooks()
Transmog:ChromieSyncInstallFilter()
