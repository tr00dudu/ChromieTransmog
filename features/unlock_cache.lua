local Transmog = _G.ChromieTransmog

function Transmog:ChromieSlotIsMogged(slot)
    if not slot then
        return false
    end
    local have = self.transmogStatusFromServer and self.transmogStatusFromServer[slot]
    if have == self.HIDDEN_ITEM_ID then
        return false
    end
    local gossip = self.transmogGossipIcon and self.transmogGossipIcon[slot]
    if gossip then
        return true
    end
    if have == self.UNKNOWN_MOG_ID or (have and have > 1) then
        return true
    end
    local link = GetInventoryItemLink("player", slot)
    if link then
        local visTex = GetInventoryItemTexture("player", slot)
        local visKey = self:ChromieNormIcon(visTex)
        if visKey and (string.find(visKey, "paperdoll", 1, true) or string.find(visKey, "wowunknownitem", 1, true)) then
            return false
        end
        local origTex = select(10, GetItemInfo(link))
        local origKey = self:ChromieNormIcon(origTex)
        if visKey and origKey and visKey ~= origKey then
            return true
        end
    end
    return false
end

function Transmog:ChromieLiveIdSet(slot)
    local set = {}
    local ids = self.chromieCache and self.chromieCache[slot]
    if ids then
        local i = 1
        while ids[i] do
            set[ids[i]] = true
            i = i + 1
        end
    end
    return set
end

function Transmog:ChromieDiffCacheMinusLive(key, liveSet)
    local entry = self:ChromieUnlockEntry(key)
    if not entry or not entry.ids then
        return {}
    end
    local missing = {}
    for id in pairs(entry.ids) do
        if not liveSet[id] then
            table.insert(missing, id)
        end
    end
    table.sort(missing)
    return missing
end

function Transmog:ChromieMergeLiveIntoPersist(key, slot, liveSet, iconById)
    if not key then
        return
    end
    for id in pairs(liveSet or {}) do
        local icon = iconById and iconById[id]
        self:ChromieUnlockMergeId(key, id, icon)
    end
    self:ChromieUnlockScanMeta(key, slot)
end

function Transmog:ChromieEquippedItemId(slot)
    local link = GetInventoryItemLink("player", slot)
    return link and self:IDFromLink(link)
end

function Transmog:ChromieCountUnlockIds(entry)
    local n = 0
    if entry and entry.ids then
        for _ in pairs(entry.ids) do
            n = n + 1
        end
    end
    return n
end

-- When mogged, gossip omits the worn mog and the equipped base item (2 vs full cache).
function Transmog:ChromieInferMogFromMissing(slot, missing, nMissing)
    if not missing or not nMissing or nMissing <= 0 then
        return nil
    end
    local eqId = self:ChromieEquippedItemId(slot)
    eqId = eqId and tonumber(eqId)

    if nMissing == 1 then
        local id = tonumber(missing[1])
        if id and id > 1 and id ~= eqId then
            return id
        end
        return nil
    end

    if nMissing == 2 and eqId then
        local mogId = nil
        local i = 1
        while missing[i] do
            local id = tonumber(missing[i])
            if id and id > 1 then
                if id == eqId then
                    -- equipped base item — not the worn mog
                elseif mogId then
                    return nil
                else
                    mogId = id
                end
            end
            i = i + 1
        end
        return mogId
    end

    return nil
end

function Transmog:ChromieSlotNeedsMogResolve(slot)
    if not self:ChromieSlotSupportsTransmog(slot) then
        return false
    end
    if not self:ChromieSlotIsMogged(slot) then
        return false
    end
    return not self:ChromieResolveAppliedMogId(slot)
end

function Transmog:ChromieSlotLabelShort(slot)
    return string.gsub(self:ChromieSlotLabel(slot) or ("slot " .. tostring(slot)), " Slot", "")
end

function Transmog:ChromieItemName(id)
    id = id and tonumber(id)
    if not id or id <= 1 then
        return nil
    end
    if self.cacheItem then
        self:cacheItem(id)
    end
    return GetItemInfo(id)
end

function Transmog:ChromieDescribeMogScanResult(slot, key, entry)
    local liveSet = self:ChromieLiveIdSet(slot)
    local liveN = self:tableSize(liveSet)
    local missing = self:ChromieDiffCacheMinusLive(key, liveSet)
    local nMissing = self:tableSize(missing)
    local cached = self:ChromieCountUnlockIds(entry)
    local eqId = self:ChromieEquippedItemId(slot)
    local applied = self:ChromiePersistGetApplied(slot)
    applied = applied and tonumber(applied)

    if entry.status == "ok" and applied and applied > 1 then
        local name = self:ChromieItemName(applied)
        if name then
            return "Found transmog: " .. name .. "."
        end
        return "Found transmog (item " .. applied .. ")."
    end

    if not self:ChromieSlotIsMogged(slot) then
        return "Slot is not transmogged."
    end

    if cached == 0 or liveN == 0 then
        return "No appearances scraped — stay near Warpweaver and try again."
    end

    if nMissing == 0 then
        return "Cache matches live gossip but mog is still unknown — scan this slot while unmogged first to fill the cache."
    end

    if nMissing > 2 then
        return cached .. " cached vs " .. liveN .. " live (" .. nMissing .. " extra in cache) — gear may have changed; scan unmogged or drop cache for this slot."
    end

    if nMissing == 2 then
        return "Cache is 2 ahead of live (worn mog + equipped item). Could not pick the mog — drop cache and scan unmogged, then scan again while mogged."
    end

    if nMissing == 1 then
        local only = tonumber(missing[1])
        if only and eqId and only == eqId then
            return "Only your equipped item is missing from live — scan unmogged first to cache all appearances."
        end
        return "One cache entry missing from live but it is not the worn mog — scan unmogged first to fill the cache."
    end

    return "Could not determine transmog."
end

function Transmog:ChromieInferAppliedFromScan(slot, key)
    if not slot or not key then
        return
    end
    local entry = self:ChromieUnlockEntry(key)
    if not entry then
        return
    end
    local have = self.transmogStatusFromServer and self.transmogStatusFromServer[slot]
    if have == self.HIDDEN_ITEM_ID then
        entry.status = "ok"
        self:ChromiePersistSetApplied(slot, self.HIDDEN_ITEM_ID)
        return
    end

    local applied = self:ChromiePersistGetApplied(slot)
    if self:ChromieSlotIsMogged(slot) then
        if applied and applied > 1 then
            local icon = self.transmogGossipIcon and self.transmogGossipIcon[slot]
            self:ChromieUnlockMergeId(key, applied, icon)
        elseif have and have > 1 then
            applied = have
            local icon = self.transmogGossipIcon and self.transmogGossipIcon[slot]
            self:ChromieUnlockMergeId(key, applied, icon)
        end
    end

    local liveSet = self:ChromieLiveIdSet(slot)
    local liveN = self:tableSize(liveSet)
    local missing = self:ChromieDiffCacheMinusLive(key, liveSet)
    local nMissing = self:tableSize(missing)

    if liveN == 0 then
        entry.status = "needs_scan"
        return
    end

    if not self:ChromieSlotIsMogged(slot) then
        if have == 0 or have == nil then
            self:ChromiePersistSetApplied(slot, 0)
        end
        entry.status = "ok"
        return
    end

    -- Gossip omits the currently applied mog. OK if that id is already in cache.
    local applied = self:ChromiePersistGetApplied(slot)
    applied = applied and tonumber(applied)
    if applied and applied > 1 and self:ChromieUnlockHasId(entry, applied) and not liveSet[applied] then
        entry.status = "ok"
        return
    end
    local have = self.transmogStatusFromServer and self.transmogStatusFromServer[slot]
    have = have and tonumber(have)
    if have and have > 1 and self:ChromieUnlockHasId(entry, have) and not liveSet[have] then
        entry.status = "ok"
        self:ChromiePersistSetApplied(slot, have)
        return
    end

    local inferredMog = self:ChromieInferMogFromMissing(slot, missing, nMissing)

    if inferredMog then
        entry.status = "ok"
        self:ChromiePersistSetApplied(slot, inferredMog)
        if self.transmogStatusFromServer[slot] == self.UNKNOWN_MOG_ID then
            self.transmogStatusFromServer[slot] = inferredMog
        end
        local want = self.transmogStatusToServer[slot]
        if want == self.UNKNOWN_MOG_ID or want == nil then
            self.transmogStatusToServer[slot] = inferredMog
        end
        return
    end

    entry.status = "needs_scan"
end

function Transmog:ChromieResolveAppliedMogId(slot, entry)
    if not slot then
        return nil
    end
    if not entry then
        local link = GetInventoryItemLink("player", slot)
        local key = self:ChromieCacheKeyForSlot(slot, link)
        entry = key and self:ChromieUnlockEntry(key)
    end
    if not entry or not entry.ids then
        return nil
    end
    local applied = self:ChromiePersistGetApplied(slot)
    applied = applied and tonumber(applied)
    if applied and applied > 1 and self:ChromieUnlockHasId(entry, applied) then
        return applied
    end
    local have = self.transmogStatusFromServer and self.transmogStatusFromServer[slot]
    have = have and tonumber(have)
    if have and have > 1 and self:ChromieUnlockHasId(entry, have) then
        return have
    end
    return nil
end

function Transmog:ChromieCacheSlotEffectiveStatus(slot, entry)
    local status = (entry and entry.status) or "empty"
    if status ~= "ok" then
        return status
    end
    if not self:ChromieSlotIsMogged(slot) then
        return status
    end
    local applied = self:ChromiePersistGetApplied(slot)
    if applied == self.HIDDEN_ITEM_ID then
        return "ok"
    end
    if self:ChromieResolveAppliedMogId(slot, entry) then
        return "ok"
    end
    return "needs_scan"
end

function Transmog:ChromieMarkSessionScanned(slot, key)
    if not self.chromieSessionScanned then
        self.chromieSessionScanned = {}
    end
    -- Track by cache key only so swapping item type can rescan the new key.
    if key then
        self.chromieSessionScanned[key] = true
    end
end

function Transmog:ChromieWasSessionScanned(slot)
    if not self.chromieSessionScanned or not slot then
        return false
    end
    local link = GetInventoryItemLink("player", slot)
    local key = self:ChromieCacheKeyForSlot(slot, link)
    return key and self.chromieSessionScanned[key] and true or false
end

function Transmog:ChromieFinishSlotScan(slot)
    if not slot then
        return
    end
    local link = GetInventoryItemLink("player", slot)
    local key = self:ChromieCacheKeyForSlot(slot, link)
    if not key then
        return
    end
    local announce = self.chromieScanAnnounce
    local purpose = self.chromieScanPurpose
    self.chromieScanAnnounce = nil
    self.chromieScanPurpose = nil

    local entry = self:ChromieUnlockEntry(key)
    local before = 0
    if entry and entry.ids then
        for _ in pairs(entry.ids) do
            before = before + 1
        end
    end

    local iconById = {}
    local ids = self.chromieCache and self.chromieCache[slot]
    if ids and self.chromieCacheIcon and self.chromieCacheIcon[slot] then
        local i = 1
        while ids[i] do
            iconById[ids[i]] = self.chromieCacheIcon[slot][ids[i]]
            i = i + 1
        end
    end
    local liveSet = self:ChromieLiveIdSet(slot)
    self:ChromieMergeLiveIntoPersist(key, slot, liveSet, iconById)
    self:ChromieInferAppliedFromScan(slot, key)
    entry = self:ChromieUnlockEntry(key)
    local total = 0
    if entry and entry.ids then
        for _ in pairs(entry.ids) do
            total = total + 1
        end
    end
    local added = total - before
    if added < 0 then
        added = 0
    end
    -- Only mark done when scrape produced usable data; failed scans can retry.
    if entry and entry.status == "ok" then
        self:ChromieMarkSessionScanned(slot, key)
    end
    if announce and self.Chat then
        local label = self:ChromieSlotLabelShort(slot)
        local liveN = self:tableSize(liveSet)
        if purpose == "mog_resolve" then
            local detail = self:ChromieDescribeMogScanResult(slot, key, entry)
            self:Chat(label .. ": scanned " .. liveN .. " appearances, cached " .. total .. ". " .. detail)
        else
            local msg = "Scanned " .. label .. ": added " .. added .. " to cache, total cached " .. total
            if entry and entry.status ~= "ok" then
                if self:ChromieSlotIsMogged(slot) then
                    msg = msg .. " — needs scan (mog id unknown)"
                else
                    msg = msg .. " — needs scan"
                end
            end
            self:Chat(msg)
        end
    end
    if self.ChromieCacheTabRefresh then
        self:ChromieCacheTabRefresh(true)
    end
end

-- Queue equipped slots that still need a gossip scrape (new key / failed / never this session).
function Transmog:ChromieQueueUnscannedSessionSlots()
    if not self.chromieScanQueue then
        self.chromieScanQueue = {}
    end
    local slots = self.CACHE_TAB_SLOTS or { 1, 3, 5, 6, 7, 8, 9, 10, 15, 16, 17, 18 }
    local i = 1
    while slots[i] do
        local slot = slots[i]
        if self:ChromieSlotSupportsTransmog(slot) then
            local link = GetInventoryItemLink("player", slot)
            if link then
                local key = self:ChromieCacheKeyForSlot(slot, link)
                local char = self:ChromiePersistChar()
                local entry = key and char and char.unlocks and char.unlocks[key]
                local status = self:ChromieCacheSlotEffectiveStatus(slot, entry)
                local need = status ~= "ok"
                if need then
                    local found = false
                    local q = 1
                    while self.chromieScanQueue[q] do
                        if self.chromieScanQueue[q] == slot then
                            found = true
                            break
                        end
                        q = q + 1
                    end
                    if not found then
                        table.insert(self.chromieScanQueue, slot)
                    end
                end
            end
        end
        i = i + 1
    end
    if self.ChromieProcessScanQueue then
        self:ChromieProcessScanQueue()
    end
end

function Transmog:ChromiePublishFromPersist(slot)
    local link = GetInventoryItemLink("player", slot)
    local key = self:ChromieCacheKeyForSlot(slot, link)
    if not key then
        return false
    end
    local entry = self:ChromieUnlockEntry(key)
    if not entry or not entry.ids then
        return false
    end
    local n = 0
    for _ in pairs(entry.ids) do
        n = n + 1
    end
    if n == 0 then
        return false
    end
    if not self.chromieCache[slot] then
        self.chromieCache[slot] = {}
    end
    if not self.chromieCacheIcon then
        self.chromieCacheIcon = {}
    end
    if not self.chromieCacheIcon[slot] then
        self.chromieCacheIcon[slot] = {}
    end
    self.chromieCache[slot] = {}
    for id, icon in pairs(entry.ids) do
        table.insert(self.chromieCache[slot], id)
        if icon and icon ~= "" then
            self.chromieCacheIcon[slot][id] = icon
        end
    end
    return true
end

function Transmog:ChromieNeedsSlotScan(slot)
    if not slot then
        return false
    end
    local link = GetInventoryItemLink("player", slot)
    if not link then
        return false
    end
    local key = self:ChromieCacheKeyForSlot(slot, link)
    if not key then
        return false
    end
    local entry = self:ChromieUnlockEntry(key)
    if not entry or entry.status == "empty" then
        return true
    end
    local n = 0
    for _ in pairs(entry.ids or {}) do
        n = n + 1
    end
    if n == 0 then
        return true
    end
    if self:ChromieSlotIsMogged(slot) then
        if self:ChromieSlotNeedsMogResolve(slot) then
            return true
        end
    end
    return false
end

function Transmog:ChromieEnqueueUnknownMogScans()
    if not self.chromieScanQueue then
        self.chromieScanQueue = {}
    end
    local _, slot
    for _, slot in pairs(self.inventorySlots) do
        if self:ChromieSlotSupportsTransmog(slot) and self:ChromieSlotNeedsMogResolve(slot) then
            local found = false
            local i = 1
            while self.chromieScanQueue[i] do
                if self.chromieScanQueue[i] == slot then
                    found = true
                    break
                end
                i = i + 1
            end
            if not found then
                table.insert(self.chromieScanQueue, slot)
            end
        end
    end
end

function Transmog:ChromieQueueUnknownMogScans()
    self:ChromieEnqueueUnknownMogScans()
    if self.ChromieDeferProcessScanQueue then
        self:ChromieDeferProcessScanQueue()
    elseif self.ChromieProcessScanQueue then
        self:ChromieProcessScanQueue()
    end
end

function Transmog:ChromieDeferProcessScanQueue()
    local frame = self.chromieScanKicker
    if not frame then
        frame = CreateFrame("Frame")
        self.chromieScanKicker = frame
    end
    if frame.chromieScanScheduled then
        return
    end
    frame.chromieScanScheduled = true
    frame:SetScript("OnUpdate", function(f)
        f:SetScript("OnUpdate", nil)
        f.chromieScanScheduled = nil
        if Transmog.ChromieProcessScanQueue then
            Transmog:ChromieProcessScanQueue()
        end
    end)
end

function Transmog:ChromieProcessScanQueue()
    if self.setCacheJob then
        return
    end
    if not ChromieTransmogFrame or not ChromieTransmogFrame:IsShown() then
        return
    end
    if self.chromieJob == "sets-list" or self.chromieJob == "sets-view" then
        self.chromieJob = "open"
    end
    if not self.chromieJob or self.chromieJob == "open" then
        if not self.chromieJob then
            self.chromieJob = "open"
        end
    elseif self.chromieJob ~= "load" then
        return
    end
    if self.chromieJob == "load" then
        return
    end
    if not self.chromieScanQueue or not self.chromieScanQueue[1] then
        return
    end
    if self.chromieVendorOpen then
        return
    end
    local slot = table.remove(self.chromieScanQueue, 1)
    if slot and self:ChromieSlotSupportsTransmog(slot) and self.ChromieScanSlot then
        self.chromieScanAnnounce = true
        if self:ChromieSlotNeedsMogResolve(slot) then
            self.chromieScanPurpose = "mog_resolve"
            if self.Chat then
                local link = GetInventoryItemLink("player", slot)
                local key = link and self:ChromieCacheKeyForSlot(slot, link)
                local entry = key and self:ChromieUnlockEntry(key)
                local cached = self:ChromieCountUnlockIds(entry)
                self:Chat("Attempting to find transmog for " .. self:ChromieSlotLabelShort(slot)
                    .. ": cache has " .. cached .. " appearances.")
            end
        else
            self.chromieScanPurpose = "cache"
        end
        self:ChromieScanSlot(slot, {
            force = true,
            announce = self.chromieScanAnnounce,
            purpose = self.chromieScanPurpose,
        })
    elseif slot and self.chromieScanQueue and self.chromieScanQueue[1] then
        self:ChromieProcessScanQueue()
    end
end

function Transmog:ChromieAppliedSet(slot, mogId)
    self:ChromiePersistSetApplied(slot, mogId)
end

function Transmog:ChromieCachedLookGet(slot)
    return self:ChromiePersistGetApplied(slot)
end

function Transmog:ChromieCachedLookSet(slot, mogId)
    self:ChromiePersistSetApplied(slot, mogId)
end

function Transmog:ChromieHydrateFromApplied()
    if self.ChromiePruneLegacyUnlockKeys then
        self:ChromiePruneLegacyUnlockKeys()
    end
    local char = self:ChromiePersistChar()
    if char and char.unlocks then
        local key, entry
        for key, entry in pairs(char.unlocks) do
            if entry.status == "stale" or entry.status == "missing_mog" then
                entry.status = "needs_scan"
            end
        end
    end
    self:ChromieHydrateAppliedFromPersist()
end
