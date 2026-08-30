local Transmog = _G.ChromieTransmog

Transmog.CACHE_SCHEMA_VERSION = 3
Transmog.GEAR_CACHE_SLOTS = { 1, 3, 5, 6, 7, 8, 9, 10, 15 }

local WEAPON_SLOTS = { 16, 17, 18 }

function Transmog:ChromieNormIcon(path)
    if not path or path == "" then
        return nil
    end
    path = string.lower(tostring(path))
    path = string.gsub(path, "/", "\\")
    path = string.gsub(path, "%.blp$", "")
    path = string.gsub(path, "^.*\\", "")
    if path == "" then
        return nil
    end
    return path
end

function Transmog:ChromiePlayerGuid()
    if not UnitGUID then
        return nil
    end
    return UnitGUID("player")
end

function Transmog:ChromieEnsurePersistDB()
    if not ChromieTransmogDB then
        ChromieTransmogDB = { chars = {} }
    end
    if not ChromieTransmogDB.chars then
        ChromieTransmogDB.chars = {}
    end
end

function Transmog:ChromiePersistChar()
    self:ChromieEnsurePersistDB()
    local guid = self:ChromiePlayerGuid()
    if not guid then
        return nil
    end
    if not ChromieTransmogDB.chars[guid] then
        ChromieTransmogDB.chars[guid] = {
            version = self.CACHE_SCHEMA_VERSION,
            unlocks = {},
            owned = {},
            sets = {
                names = {},
                items = {},
                unknown = {},
                inferred = {},
            },
        }
    end
    local char = ChromieTransmogDB.chars[guid]
    if not char.unlocks then
        char.unlocks = {}
    end
    if not char.owned then
        char.owned = {}
    end
    -- Legacy slot-keyed applied[] mixed gear sets; drop it.
    if char.applied then
        char.applied = nil
    end
    -- v3 keys are o:itemId:icon; wipe older u:/i: owned entries.
    if char.version ~= self.CACHE_SCHEMA_VERSION then
        if char.version and char.version < 3 then
            char.owned = {}
        end
        char.version = self.CACHE_SCHEMA_VERSION
    end
    if not char.sets then
        char.sets = { names = {}, items = {}, unknown = {}, inferred = {} }
    end
    if not char.sets.names then
        char.sets.names = {}
    end
    if not char.sets.items then
        char.sets.items = {}
    end
    if not char.sets.unknown then
        char.sets.unknown = {}
    end
    if not char.sets.inferred then
        char.sets.inferred = {}
    end
    return char
end

function Transmog:ChromieIsWeaponSlot(slot)
    return slot == 16 or slot == 17 or slot == 18
end

function Transmog:ChromieWeaponTypeKey(link)
    if not link then
        return nil
    end
    local _, _, _, _, _, _, _, _, invType, _, subclass = GetItemInfo(link)
    if not invType then
        local itemId = self:IDFromLink(link)
        if itemId and self.cacheItem then
            self:cacheItem(itemId)
            _, _, _, _, _, _, _, _, invType, _, subclass = GetItemInfo(itemId)
        end
    end
    if not invType then
        return nil
    end
    subclass = subclass or "Unknown"
    return "w:" .. invType .. ":" .. subclass
end

function Transmog:ChromieItemClassNum(slot, link)
    link = link or (slot and GetInventoryItemLink("player", slot))
    if not link then
        return nil
    end
    local _, _, _, _, _, itemClassStr, itemSubclass = GetItemInfo(link)
    if not itemClassStr and self.cacheItem then
        local itemId = self:IDFromLink(link)
        if itemId then
            self:cacheItem(itemId)
            _, _, _, _, _, itemClassStr, itemSubclass = GetItemInfo(itemId)
        end
    end
    if not itemClassStr or not itemSubclass then
        return nil
    end
    if itemClassStr ~= "Armor" and itemClassStr ~= "Armadura"
        and itemClassStr ~= "Weapon" and itemClassStr ~= "Arma" then
        return nil
    end
    return self:ItemClassStrToNum(itemClassStr) + self:ItemSubclassStrToNum(itemSubclass)
end

function Transmog:ChromieCacheKeyForSlot(slot, link)
    if not slot then
        return nil
    end
    link = link or GetInventoryItemLink("player", slot)
    if self:ChromieIsWeaponSlot(slot) then
        return self:ChromieWeaponTypeKey(link)
    end
    local itemClass = self:ChromieItemClassNum(slot, link)
    if itemClass then
        return "s:" .. tostring(slot) .. ":" .. tostring(itemClass)
    end
    return "s:" .. tostring(slot)
end

-- Keys for gear slots currently worn (one per equipped slot).
function Transmog:ChromieActiveUnlockKeys()
    local active = {}
    local _, slot
    for _, slot in pairs(self.inventorySlots or {}) do
        if self:ChromieSlotSupportsTransmog(slot) then
            local link = GetInventoryItemLink("player", slot)
            if link then
                local key = self:ChromieCacheKeyForSlot(slot, link)
                if key then
                    active[key] = true
                end
            end
        end
    end
    return active
end

-- Old s:slot keys mixed armor types; drop them on load.
function Transmog:ChromiePruneLegacyUnlockKeys()
    local char = self:ChromiePersistChar()
    if not char or not char.unlocks then
        return
    end
    local key
    for key in pairs(char.unlocks) do
        if string.match(key, "^s:%d+$") then
            char.unlocks[key] = nil
        end
    end
end

function Transmog:ChromieUnlockEntry(key)
    local char = self:ChromiePersistChar()
    if not char or not key then
        return nil
    end
    if not char.unlocks[key] then
        char.unlocks[key] = {
            ids = {},
            status = "empty",
        }
    end
    if not char.unlocks[key].ids then
        char.unlocks[key].ids = {}
    end
    return char.unlocks[key]
end

function Transmog:ChromieUnlockHasId(entry, itemId)
    if not entry or not entry.ids or not itemId then
        return false
    end
    itemId = tonumber(itemId)
    if not itemId or itemId <= 1 then
        return false
    end
    if entry.ids[itemId] then
        return true
    end
    for id in pairs(entry.ids) do
        if tonumber(id) == itemId then
            return true
        end
    end
    return false
end

function Transmog:ChromieUnlockMergeId(key, itemId, iconPath)
    if not key or not itemId or itemId <= 1 then
        return
    end
    local entry = self:ChromieUnlockEntry(key)
    if not entry then
        return
    end
    local icon = self:ChromieNormIcon(iconPath)
    if not entry.ids[itemId] and icon then
        entry.ids[itemId] = icon
    elseif not entry.ids[itemId] then
        entry.ids[itemId] = icon or ""
    end
end

function Transmog:ChromieUnlockIdList(key)
    local entry = self:ChromieUnlockEntry(key)
    if not entry then
        return {}
    end
    local list = {}
    for id in pairs(entry.ids or {}) do
        table.insert(list, id)
    end
    table.sort(list)
    return list
end

function Transmog:ChromieUnlockScanMeta(key, slot)
    local entry = self:ChromieUnlockEntry(key)
    if not entry or not slot then
        return
    end
    local link = GetInventoryItemLink("player", slot)
    if not link then
        return
    end
    entry.scanEquippedId = self:IDFromLink(link)
    local tex
    if GetItemIcon and entry.scanEquippedId then
        tex = GetItemIcon(entry.scanEquippedId)
    end
    if not tex then
        tex = select(10, GetItemInfo(link))
    end
    entry.scanEquippedIcon = self:ChromieNormIcon(tex)
end

-- Worn-mog state for a specific owned look: originalItemId + visible icon.
function Transmog:ChromiePersistGetOwnedMog(link, iconPath)
    local char = self:ChromiePersistChar()
    local key = link and self:ChromieLinkOwnedKey(link, iconPath)
    if not char or not key then
        return nil
    end
    return char.owned[key]
end

function Transmog:ChromiePersistSetOwnedMog(link, mogId, iconPath)
    local char = self:ChromiePersistChar()
    local key = link and self:ChromieLinkOwnedKey(link, iconPath)
    if not char or not key then
        return
    end
    if mogId == nil or mogId == 0 then
        char.owned[key] = nil
    else
        char.owned[key] = mogId
    end
end

-- If exactly one owned mog exists for this base item id, return it (bag fallback).
function Transmog:ChromiePersistFindOwnedMogForItem(itemId)
    itemId = itemId and tonumber(itemId)
    local char = self:ChromiePersistChar()
    if not itemId or not char or not char.owned then
        return nil
    end
    local prefix = "o:" .. tostring(itemId) .. ":"
    local found = nil
    local key, mogId
    for key, mogId in pairs(char.owned) do
        if string.sub(key, 1, string.len(prefix)) == prefix then
            if found then
                return nil
            end
            found = mogId
        end
    end
    return found
end

-- Session mirror: mog on the item currently equipped in this slot (from owned[]).
function Transmog:ChromiePersistGetApplied(slot)
    if not slot then
        return nil
    end
    local link = GetInventoryItemLink("player", slot)
    if not link then
        return nil
    end
    return self:ChromiePersistGetOwnedMog(link, self:ChromieOwnedIconForSlot(slot))
end

function Transmog:ChromiePersistSetApplied(slot, mogId)
    if not slot then
        return
    end
    local link = GetInventoryItemLink("player", slot)
    local icon = self:ChromieOwnedIconForSlot(slot)
    if (not icon or icon == "hidden") and mogId and mogId > 1 then
        if GetItemIcon then
            icon = GetItemIcon(mogId)
        end
        if not icon then
            icon = select(10, GetItemInfo(mogId))
        end
    end
    if link then
        self:ChromiePersistSetOwnedMog(link, mogId, icon)
    end
    if not self.applied then
        self.applied = {}
    end
    self.applied[slot] = mogId
end

function Transmog:ChromieHydrateAppliedFromPersist()
    if not self.applied then
        self.applied = {}
    end
    local _, slot
    for _, slot in pairs(self.inventorySlots or {}) do
        local mog = self:ChromiePersistGetApplied(slot)
        self.applied[slot] = mog or 0
    end
end

-- After gear swap: rebuild slot mirror from owned[] for the newly equipped pieces.
function Transmog:ChromieOwnedOnGearChanged()
    local changedSlots = self.ChromieGetEquipSlotsChanged and self:ChromieGetEquipSlotsChanged()
    self:ChromieHydrateAppliedFromPersist()
    if not self.transmogStatusFromServer then
        self.transmogStatusFromServer = {}
    end
    if not self.transmogStatusToServer then
        self.transmogStatusToServer = {}
    end
    local overlayOpen = ChromieTransmogFrame and ChromieTransmogFrame:IsShown()
    local _, slot
    for _, slot in pairs(self.inventorySlots or {}) do
        local link = GetInventoryItemLink("player", slot)
        local mog = link and self:ChromiePersistGetOwnedMog(link, self:ChromieOwnedIconForSlot(slot))
        if not mog then
            mog = 0
        end
        self.applied[slot] = mog
        local have = self.transmogStatusFromServer[slot]
        local want = self.transmogStatusToServer[slot]
        local userPending = overlayOpen and want ~= nil and have ~= nil and want ~= have
        if not userPending then
            self.transmogStatusFromServer[slot] = mog
            self.transmogStatusToServer[slot] = mog
        end
        if mog == 0 and self.transmogGossipIcon then
            self.transmogGossipIcon[slot] = nil
        end
    end
    if self.mogByUniqueId then
        self.mogByUniqueId = {}
    end
    if overlayOpen and self.transmogStatus then
        self:transmogStatus()
    end
    if self.ChromieCacheTabRefresh then
        self:ChromieCacheTabRefresh()
    end
    if self.ChromieCacheTabOnEquipChanged then
        self:ChromieCacheTabOnEquipChanged(changedSlots)
    end
end

function Transmog:ChromiePersistDropSet(name)
    local char = self:ChromiePersistChar()
    if not char or not name then
        return
    end
    if char.sets.items then
        char.sets.items[name] = nil
    end
    if char.sets.inferred then
        char.sets.inferred[name] = nil
    end
    if char.sets.names then
        local nextNames = {}
        local n = 1
        while char.sets.names[n] do
            if char.sets.names[n] ~= name then
                table.insert(nextNames, char.sets.names[n])
            end
            n = n + 1
        end
        char.sets.names = nextNames
        self.chromieSets = nextNames
    end
    if char.sets.unknown then
        local next = {}
        local i = 1
        while char.sets.unknown[i] do
            if char.sets.unknown[i] ~= name then
                table.insert(next, char.sets.unknown[i])
            end
            i = i + 1
        end
        char.sets.unknown = next
    end
    if self.chromieSetItems then
        self.chromieSetItems[name] = nil
    end
end

function Transmog:ChromiePersistPruneStaleSets(liveNames)
    local char = self:ChromiePersistChar()
    if not char or not char.sets or not char.sets.items then
        return
    end
    local live = {}
    local i = 1
    while liveNames and liveNames[i] do
        live[liveNames[i]] = true
        i = i + 1
    end
    local dropped = {}
    for name in pairs(char.sets.items) do
        if not live[name] then
            table.insert(dropped, name)
            self:ChromiePersistDropSet(name)
        end
    end
    if dropped[1] and self.Chat then
        self:Chat("Removed stale cached set(s): " .. table.concat(dropped, ", "))
    end
end

function Transmog:ChromiePersistSetNames(names)
    local char = self:ChromiePersistChar()
    if not char or not names then
        return
    end
    char.sets.names = names
    self.chromieSets = names
    if self.ChromiePersistPruneStaleSets then
        self:ChromiePersistPruneStaleSets(names)
    end
    self:ChromiePersistDiffSetUnknown(names)
end

function Transmog:ChromiePersistDiffSetUnknown(liveNames)
    local char = self:ChromiePersistChar()
    if not char then
        return
    end
    char.sets.unknown = {}
    local i = 1
    while liveNames and liveNames[i] do
        local name = liveNames[i]
        if not (char.sets.items and char.sets.items[name] and char.sets.inferred and char.sets.inferred[name]) then
            table.insert(char.sets.unknown, name)
        end
        i = i + 1
    end
end

function Transmog:ChromiePersistSetItems(name, items)
    local char = self:ChromiePersistChar()
    if not char or not name or not items then
        return
    end
    char.sets.items[name] = items
    char.sets.inferred[name] = true
    if char.sets.unknown then
        local next = {}
        local i = 1
        while char.sets.unknown[i] do
            if char.sets.unknown[i] ~= name then
                table.insert(next, char.sets.unknown[i])
            end
            i = i + 1
        end
        char.sets.unknown = next
    end
    if not self.chromieSetItems then
        self.chromieSetItems = {}
    end
    self.chromieSetItems[name] = items
end

function Transmog:ChromiePersistLoadSets()
    local char = self:ChromiePersistChar()
    if not char then
        return
    end
    self.chromieSets = char.sets.names or {}
    self.chromieSetItems = char.sets.items or {}
end

function Transmog:ChromiePersistDropUnlocks()
    local char = self:ChromiePersistChar()
    if not char then
        return
    end
    char.unlocks = {}
    char.owned = {}
    if self.applied then
        self.applied = {}
    end
end

function Transmog:ChromiePersistDropAll()
    local char = self:ChromiePersistChar()
    if not char then
        return
    end
    char.unlocks = {}
    char.owned = {}
    char.sets = { names = {}, items = {}, unknown = {}, inferred = {} }
    self.applied = {}
    self.chromieSets = {}
    self.chromieSetItems = {}
end

function Transmog:ChromieSlotLabel(slot)
    return (self.inventorySlotNames and self.inventorySlotNames[slot]) or ("slot " .. tostring(slot))
end

function Transmog:ChromieUnlockStatusLabel(status)
    if status == "ok" then
        return "ok"
    end
    if status == "needs_scan" then
        return "needs scan"
    end
    if status == "missing_mog" then
        return "needs scan"
    end
    if status == "stale" then
        return "needs scan"
    end
    if status == "empty" then
        return "not scanned"
    end
    return tostring(status or "?")
end

function Transmog:ChromieUnlockStatusReason(status)
    if status == "needs_scan" or status == "missing_mog" or status == "stale" then
        return "open slot in Items tab"
    end
    if status == "empty" then
        return "open slot in Items tab"
    end
    return nil
end

function Transmog:ChromieCacheKeyLabel(key)
    if not key then
        return "?"
    end
    if string.sub(key, 1, 2) == "s:" then
        local slot, classNum = string.match(key, "^s:(%d+):(%d+)$")
        if not slot then
            slot = string.match(key, "^s:(%d+)$")
        end
        slot = tonumber(slot)
        local name = self:ChromieSlotLabel(slot) or key
        name = string.gsub(name, " Slot", "")
        return name
    end
    if string.sub(key, 1, 2) == "w:" then
        local rest = string.sub(key, 3)
        rest = string.gsub(rest, "INVTYPE_", "")
        rest = string.gsub(rest, "WEAPON", "")
        rest = string.gsub(rest, "MAINHAND", "MH ")
        rest = string.gsub(rest, "OFFHAND", "OH ")
        rest = string.gsub(rest, "2H", "2H ")
        rest = string.gsub(rest, "RANGEDRIGHT", "Ranged ")
        rest = string.gsub(rest, "RANGED", "Ranged ")
        rest = string.gsub(rest, "^:", "")
        if rest == "" then
            return "Weapon"
        end
        return rest
    end
    return key
end
