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
    if not ChromieTransmogDB.lookPreview or type(ChromieTransmogDB.lookPreview.z) == "number" then
        -- Race -> slot -> {z,x,y}. Drop legacy global {z,x,y}.
        ChromieTransmogDB.lookPreview = {}
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
                lastUsed = {},
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
        char.sets = { names = {}, items = {}, unknown = {}, inferred = {}, lastUsed = {} }
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
    if not char.sets.lastUsed then
        char.sets.lastUsed = {}
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
    -- 3.3.5 GetItemInfo: 6 type, 7 subtype, 9 equipLoc. Do not use select(11)
    -- (sellPrice) — that split every item into its own cache key.
    local _, _, _, _, _, itemType, itemSubType, _, invType = GetItemInfo(link)
    if not itemType or not itemSubType then
        local itemId = self:IDFromLink(link)
        if itemId and self.cacheItem then
            self:cacheItem(itemId)
            _, _, _, _, _, itemType, itemSubType, _, invType = GetItemInfo(itemId)
        end
    end
    if itemType and itemSubType then
        return "w:" .. tostring(itemType) .. ":" .. tostring(itemSubType)
    end
    if invType then
        return "w:" .. tostring(invType)
    end
    return nil
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

function Transmog:ChromieSetItemsForName(name)
    if not name then
        return nil
    end
    local src
    local char = self.ChromiePersistChar and self:ChromiePersistChar()
    if char and char.sets and char.sets.inferred and char.sets.inferred[name]
        and char.sets.items then
        src = char.sets.items[name]
    end
    if not src then
        src = self.chromieSetItems and self.chromieSetItems[name]
    end
    if not src then
        return nil
    end
    local items = {}
    local k, v
    for k, v in pairs(src) do
        local slot = tonumber(k)
        local id = tonumber(v)
        if slot then
            items[slot] = id or 0
        end
    end
    return items
end

function Transmog:ChromiePersistDropOwnedForItem(itemId)
    itemId = itemId and tonumber(itemId)
    local char = self:ChromiePersistChar()
    if not itemId or itemId < 1 or not char or not char.owned then
        return
    end
    local prefix = "o:" .. tostring(itemId) .. ":"
    local drop = {}
    local key
    for key in pairs(char.owned) do
        if string.sub(key, 1, string.len(prefix)) == prefix then
            table.insert(drop, key)
        end
    end
    local i = 1
    while drop[i] do
        char.owned[drop[i]] = nil
        i = i + 1
    end
end

-- After Use this set: drop stale owned keys for those set slots only, then
-- write the new item+icon from the set cache. Other equipped slots are untouched.
function Transmog:ChromieAppliedCopyFromSet(name)
    local items = self:ChromieSetItemsForName(name)
    if not items then
        return
    end
    if not self.applied then
        self.applied = {}
    end
    local slot, id
    for slot, id in pairs(items) do
        slot = tonumber(slot)
        id = tonumber(id)
        if slot and self:ChromieSlotSupportsTransmog(slot) and id
            and (id > 1 or id == self.HIDDEN_ITEM_ID) then
            local have = self.transmogStatusFromServer and self.transmogStatusFromServer[slot]
            if have and have ~= 0 then
                local link = GetInventoryItemLink("player", slot)
                if link then
                    self:ChromiePersistDropOwnedForItem(self:IDFromLink(link))
                    if id == self.HIDDEN_ITEM_ID then
                        self:ChromiePersistSetOwnedMog(link, id, "hidden")
                        self.applied[slot] = id
                    else
                        if self.cacheItem then
                            self:cacheItem(id)
                        end
                        local icon
                        if GetItemIcon then
                            icon = GetItemIcon(id)
                        end
                        if not icon then
                            icon = select(10, GetItemInfo(id))
                        end
                        self:ChromiePersistSetOwnedMog(link, id, icon)
                        self.applied[slot] = id
                    end
                end
            end
        end
    end
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
    local changed = {}
    local i = 1
    while changedSlots and changedSlots[i] do
        changed[changedSlots[i]] = true
        i = i + 1
    end
    -- Gossip icons belong to the previous item; they must not key the new one.
    if self.transmogGossipIcon then
        local slot
        for slot in pairs(changed) do
            self.transmogGossipIcon[slot] = nil
        end
    end
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
        local icon
        if changed[slot] then
            icon = self:ChromieLiveSlotIcon(slot)
        else
            icon = self:ChromieOwnedIconForSlot(slot)
        end
        local mog = link and self:ChromiePersistGetOwnedMog(link, icon)
        if (not mog or mog == 0) and changed[slot] and link then
            local fromIcon = self.ChromieMogIdFromVisibleIcon and self:ChromieMogIdFromVisibleIcon(slot)
            if fromIcon == 0 then
                mog = 0
            elseif fromIcon and fromIcon > 1 then
                mog = fromIcon
                self:ChromiePersistSetOwnedMog(link, mog, icon)
            elseif fromIcon == self.HIDDEN_ITEM_ID then
                mog = self.HIDDEN_ITEM_ID
                self:ChromiePersistSetOwnedMog(link, mog, "hidden")
            else
                local unique = self.ChromiePersistFindOwnedMogForItem
                    and self:ChromiePersistFindOwnedMogForItem(self:IDFromLink(link))
                if unique and unique ~= 0 then
                    mog = unique
                end
            end
        end
        if not mog then
            mog = 0
        end
        self.applied[slot] = mog
        local have = self.transmogStatusFromServer[slot]
        local want = self.transmogStatusToServer[slot]
        local userPending = overlayOpen and want ~= nil and have ~= nil and want ~= have
        if not userPending then
            -- Owned lookup misses after set apply (new mog icon). Do not unmark
            -- overlay slots unless this equipped item actually changed.
            if mog ~= 0 or changed[slot] or not overlayOpen then
                self.transmogStatusFromServer[slot] = mog
                self.transmogStatusToServer[slot] = mog
            end
        end
    end
    if self.mogByUniqueId then
        self.mogByUniqueId = {}
    end
    if overlayOpen and self.transmogStatus then
        self:transmogStatus()
    end
    if overlayOpen and self.PreviewApplyChangedSlots then
        self:PreviewApplyChangedSlots(changed)
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
    self:ChromieLastUsedPrune(name)
    if self.ChromieHomeTabInvalidate then
        self:ChromieHomeTabInvalidate(name)
    end
end

function Transmog:ChromiePersistPruneStaleSets(liveNames)
    local char = self:ChromiePersistChar()
    if not char or not char.sets then
        return
    end
    local live = {}
    local i = 1
    while liveNames and liveNames[i] do
        live[liveNames[i]] = true
        i = i + 1
    end
    local dropped = {}
    if char.sets.items then
        for name in pairs(char.sets.items) do
            if not live[name] then
                table.insert(dropped, name)
                self:ChromiePersistDropSet(name)
            end
        end
    end
    if char.sets.lastUsed then
        local next = {}
        i = 1
        while char.sets.lastUsed[i] do
            local name = char.sets.lastUsed[i]
            if live[name] then
                table.insert(next, name)
            end
            i = i + 1
        end
        char.sets.lastUsed = next
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
    -- First gossip packet can be empty (Back only). Do not wipe persist names.
    if not names[1] then
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
    if self.ChromieHomeTabInvalidate then
        self:ChromieHomeTabInvalidate(name)
    end
end

function Transmog:ChromiePersistLoadSets()
    local char = self:ChromiePersistChar()
    if not char then
        return
    end
    if not (self.chromieSets and self.chromieSets[1]) then
        self.chromieSets = char.sets.names or {}
    end
    self.chromieSetItems = char.sets.items or self.chromieSetItems or {}
end

function Transmog:ChromieRestorePersistSession()
    if self.ChromiePersistLoadSets then
        self:ChromiePersistLoadSets()
    end
    if self.ChromieHydrateAppliedFromPersist then
        self:ChromieHydrateAppliedFromPersist()
    end
end

Transmog.CHROMIE_LAST_USED_MAX = 4

function Transmog:ChromieLastUsedRecord(name)
    if not name or name == "" then
        return
    end
    local char = self:ChromiePersistChar()
    if not char then
        return
    end
    if not char.sets.lastUsed then
        char.sets.lastUsed = {}
    end
    local list = char.sets.lastUsed
    local i = 1
    while list[i] do
        if list[i] == name then
            table.remove(list, i)
            break
        end
        i = i + 1
    end
    table.insert(list, 1, name)
    local max = self.CHROMIE_LAST_USED_MAX or 4
    while list[max + 1] do
        table.remove(list)
    end
end

function Transmog:ChromieLastUsedPrune(name)
    if not name then
        return
    end
    local char = self:ChromiePersistChar()
    if not char or not char.sets or not char.sets.lastUsed then
        return
    end
    local list = char.sets.lastUsed
    local i = 1
    while list[i] do
        if list[i] == name then
            table.remove(list, i)
        else
            i = i + 1
        end
    end
end

function Transmog:ChromieLastUsedList()
    local out = {}
    local seen = {}
    local n = 0
    local max = self.CHROMIE_LAST_USED_MAX or 4
    local char = self:ChromiePersistChar()
    local last = char and char.sets and char.sets.lastUsed
    local i = 1
    while last and last[i] and n < max do
        local name = last[i]
        if name and not seen[name] then
            -- Keep last-used even when set names were dropped (cache drop /
            -- before Warpweaver scrape). Live scrape prunes deleted names.
            n = n + 1
            out[n] = name
            seen[name] = true
        end
        i = i + 1
    end
    local names = self.chromieSets or {}
    i = 1
    while names[i] and n < max do
        local name = names[i]
        if name and not seen[name] then
            n = n + 1
            out[n] = name
            seen[name] = true
        end
        i = i + 1
    end
    return out
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
    if not char.sets then
        char.sets = { names = {}, items = {}, unknown = {}, inferred = {}, lastUsed = {} }
    else
        -- Drop names and piece cache. Keep last-used so Home still has cards
        -- until Warpweaver scrape fills the live list.
        char.sets.names = {}
        char.sets.items = {}
        char.sets.inferred = {}
        char.sets.unknown = {}
    end
    self.applied = {}
    self.appliedIcon = {}
    self.previewShown = {}
    self.previewBaseline = {}
    -- Session still held inferred mog ids after unlocks were wiped. The next
    -- mogged scan merged that id back into an empty cache (40 live + 1 stale
    -- = 41) and "inferred" it immediately.
    if self.transmogStatusFromServer and self.inventorySlots then
        local _, slot
        for _, slot in pairs(self.inventorySlots) do
            local have = self.transmogStatusFromServer[slot]
            if have and have > 1 then
                self.transmogStatusFromServer[slot] = self.UNKNOWN_MOG_ID
            end
            if self.transmogStatusToServer then
                local want = self.transmogStatusToServer[slot]
                if want and want > 1 then
                    self.transmogStatusToServer[slot] = self.UNKNOWN_MOG_ID
                end
            end
        end
    end
    self.chromieSetItems = {}
    self.chromieSets = {}
    self.lastAppliedSetName = nil
    self.chromieCache = {}
    self.chromieCacheIcon = {}
    self.chromieSessionScanned = {}
    self.chromieScanQueue = nil
    if self.mogByUniqueId then
        self.mogByUniqueId = {}
    end
    if self.ChromieSetCacheAbort then
        self:ChromieSetCacheAbort()
    else
        self.setCacheJob = nil
    end
    if self.ChromieHomeTabInvalidate then
        self:ChromieHomeTabInvalidate()
    end
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
        return "click a dress-up slot"
    end
    if status == "empty" then
        return "click a dress-up slot"
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
