local Transmog = _G.ChromieTransmog

-- Stable display order for the Cache tab.
Transmog.CACHE_TAB_SLOTS = { 1, 3, 5, 6, 7, 8, 9, 10, 15, 16, 17, 18 }

function Transmog:ChromieCacheTabEnsure()
    if self.cacheTabFrame then
        return self.cacheTabFrame
    end
    local f = CreateFrame("Frame", "ChromieTransmogCacheTab", ChromieTransmogFrame)
    f:SetPoint("TOPLEFT", ChromieTransmogFrame, "TOPLEFT", 255, -88)
    f:SetPoint("BOTTOMRIGHT", ChromieTransmogFrame, "BOTTOMRIGHT", -20, 40)
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 8, -4)
    title:SetText("Character cache")
    f.title = title

    local intro = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    intro:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    intro:SetWidth(400)
    intro:SetJustifyH("LEFT")
    intro:SetNonSpaceWrap(true)
    intro:SetText("This addon needs to cache your collected appearances to work. Please follow instructions below.")
    f.intro = intro

    local summary = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    summary:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -8)
    summary:SetWidth(400)
    summary:SetJustifyH("LEFT")
    f.summary = summary

    local scroll = CreateFrame("ScrollFrame", "ChromieTransmogCacheScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -8)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 36)
    f.scroll = scroll

    local child = CreateFrame("Frame", "ChromieTransmogCacheScrollChild", scroll)
    child:SetWidth(390)
    child:SetHeight(1)
    scroll:SetScrollChild(child)
    f.scrollChild = child

    local report = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    report:SetPoint("TOPLEFT", 2, 0)
    report:SetWidth(370)
    report:SetJustifyH("LEFT")
    report:SetJustifyV("TOP")
    report:SetNonSpaceWrap(true)
    f.reportText = report

    local accountTitle = child:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    accountTitle:SetPoint("TOPLEFT", report, "BOTTOMLEFT", 0, -18)
    accountTitle:SetJustifyH("LEFT")
    accountTitle:SetText("Account collection")
    accountTitle:Hide()
    f.accountTitle = accountTitle

    local accountReport = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    accountReport:SetPoint("TOPLEFT", accountTitle, "BOTTOMLEFT", 0, -6)
    accountReport:SetWidth(370)
    accountReport:SetJustifyH("LEFT")
    accountReport:SetJustifyV("TOP")
    accountReport:SetNonSpaceWrap(true)
    accountReport:Hide()
    f.accountReport = accountReport

    local drop = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    drop:SetWidth(100)
    drop:SetHeight(22)
    drop:SetPoint("BOTTOMLEFT", 8, 8)
    drop:SetText("Drop cache")
    drop:SetScript("OnClick", function()
        if Transmog.ChromiePersistDropAll then
            Transmog:ChromiePersistDropAll()
        else
            Transmog:ChromiePersistDropUnlocks()
            Transmog.chromieCache = {}
            Transmog.chromieCacheIcon = {}
            Transmog.chromieSessionScanned = {}
            Transmog.chromieScanQueue = nil
        end
        Transmog:ChromieCacheTabRefresh(true)
        Transmog:Chat("Cache cleared (unlocks, owned mogs, and set piece cache). Warpweaver sets are unchanged. No reload needed.")
    end)
    drop:SetFrameLevel(f:GetFrameLevel() + 4)
    f.drop = drop

    local scanAll = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    scanAll:SetWidth(80)
    scanAll:SetHeight(22)
    scanAll:SetPoint("LEFT", drop, "RIGHT", 6, 0)
    scanAll:SetText("Scan all")
    scanAll:SetScript("OnClick", function()
        if Transmog.ChromieStartScanAll then
            Transmog:ChromieStartScanAll()
        else
            Transmog.chromieSessionScanned = {}
            Transmog.chromieScanQueue = {}
            if Transmog.ChromieQueueUnscannedSessionSlots then
                Transmog:ChromieQueueUnscannedSessionSlots()
            end
        end
    end)
    scanAll:SetFrameLevel(f:GetFrameLevel() + 4)
    f.scanAll = scanAll

    local dropCol = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    dropCol:SetWidth(120)
    dropCol:SetHeight(22)
    dropCol:SetPoint("BOTTOMRIGHT", -25, 8)
    dropCol:SetText("Drop collection")
    dropCol:SetScript("OnClick", function()
        StaticPopup_Show("CHROMIE_TRANSMOG_DROP_COLLECTION")
    end)
    dropCol:SetFrameLevel(f:GetFrameLevel() + 4)
    f.dropCollection = dropCol

    self.cacheTabFrame = f
    return f
end

function Transmog:ChromieCacheTabShow()
    local f = self:ChromieCacheTabEnsure()
    f:Show()
    -- Baseline for bag-equip detection (right-click equip from bags).
    if self.transmogStatus then
        self:transmogStatus()
    end
    self:ChromieCacheTabRefresh(true)
end

function Transmog:ChromieCacheTabHide()
    if self.cacheTabFrame then
        self.cacheTabFrame:Hide()
    end
end

function Transmog:ChromieCacheTabIsActive()
    if self.tab ~= "cache" then
        return false
    end
    local f = self.cacheTabFrame
    return f and f:IsShown() and true or false
end

-- Bag equips (right-click in bags) fire UNIT_INVENTORY_CHANGED before the slot
-- link is always ready; defer the diff until inventory settles.
function Transmog:ChromieDeferCacheTabEquipWatch()
    local frame = self.cacheTabEquipWatch
    if not frame then
        frame = CreateFrame("Frame")
        self.cacheTabEquipWatch = frame
    end
    frame.elapsed = 0
    frame:Show()
    frame:SetScript("OnUpdate", function(f)
        if not Transmog:ChromieCacheTabIsActive() then
            f:Hide()
            f:SetScript("OnUpdate", nil)
            return
        end
        f.elapsed = (f.elapsed or 0) + arg1
        if f.elapsed < 0.15 then
            return
        end
        f:Hide()
        f:SetScript("OnUpdate", nil)
        if Transmog.ChromieOwnedOnGearChanged then
            Transmog:ChromieOwnedOnGearChanged()
        end
    end)
end

-- While the Cache tab is open, force-scan slots whose equipped item changed.
function Transmog:ChromieCacheTabOnEquipChanged(changedSlots)
    if not self:ChromieCacheTabIsActive() or not changedSlots or not changedSlots[1] then
        return
    end
    if not self.chromieScanQueue then
        self.chromieScanQueue = {}
    end
    local queued = false
    local i = 1
    while changedSlots[i] do
        local slot = changedSlots[i]
        if self:ChromieSlotSupportsTransmog(slot) and GetInventoryItemLink("player", slot) then
            local q = 1
            while self.chromieScanQueue[q] do
                if self.chromieScanQueue[q] == slot then
                    table.remove(self.chromieScanQueue, q)
                    break
                end
                q = q + 1
            end
            table.insert(self.chromieScanQueue, 1, slot)
            queued = true
        end
        i = i + 1
    end
    if queued then
        self:ChromieCacheTabRefresh(true)
        if self.ChromieDeferProcessScanQueue then
            self:ChromieDeferProcessScanQueue()
        elseif self.ChromieProcessScanQueue then
            self:ChromieProcessScanQueue()
        end
    end
end

function Transmog:ChromieCacheSlotStatus(slot)
    local label = string.gsub(self:ChromieSlotLabel(slot) or ("slot " .. slot), " Slot", "")
    if not self:ChromieSlotSupportsTransmog(slot) then
        return label, "n/a", 0
    end
    local link = GetInventoryItemLink("player", slot)
    if not link then
        return label, "empty", 0
    end
    local key = self:ChromieCacheKeyForSlot(slot, link)
    if not key then
        return label, "empty", 0
    end
    local char = self:ChromiePersistChar()
    local entry = char and char.unlocks and char.unlocks[key]
    local status = self:ChromieCacheSlotEffectiveStatus(slot, entry)
    local n = 0
    if entry and entry.ids then
        for _ in pairs(entry.ids) do
            n = n + 1
        end
    end
    return label, status, n
end

function Transmog:ChromieCacheTabRefresh(force)
    if self.ChromieHomeTabRefresh then
        self:ChromieHomeTabRefresh()
    end
    local f = self.cacheTabFrame
    if not f then
        return
    end
    if not force and not f:IsShown() then
        return
    end
    local char = self:ChromiePersistChar()
    if not char then
        f.summary:SetText("No character data.")
        f.reportText:SetText("")
        if f.accountTitle then
            f.accountTitle:Hide()
        end
        if f.accountReport then
            f.accountReport:SetText("")
            f.accountReport:Hide()
        end
        self:ChromieCacheTabSetIntroVisible(true)
        return
    end

    local okLabels = {}
    local needLabels = {}
    local lines = {}
    local okCount = 0
    local issueCount = 0

    local i = 1
    while self.CACHE_TAB_SLOTS[i] do
        local slot = self.CACHE_TAB_SLOTS[i]
        local label, status, n = self:ChromieCacheSlotStatus(slot)
        local shown = label
        if n and n > 0 then
            shown = label .. " (" .. n .. ")"
        end
        if self:ChromieCacheSlotIsReportIssue(slot) then
            table.insert(needLabels, shown)
            issueCount = issueCount + 1
        elseif status == "ok" then
            table.insert(okLabels, shown)
            okCount = okCount + 1
        end
        i = i + 1
    end

    if okLabels[1] then
        table.insert(lines, "|cff00ff00" .. table.concat(okLabels, ", ") .. ": OK|r")
    end
    if needLabels[1] then
        table.insert(lines, table.concat(needLabels, ", ") .. ": needs scan")
        table.insert(lines, "")
        table.insert(lines, "|cffaaaaaaUnmog the slot and press Scan all, or scan twice with two differently transmogged items in that slot (this tab auto-scans on item equip).|r")
    end

    local setOk = {}
    local setNeed = {}
    local setsUncached = 0
    if char.sets and char.sets.items then
        local name, items
        for name, items in pairs(char.sets.items) do
            if char.sets.inferred and char.sets.inferred[name] then
                table.insert(setOk, "Set \"" .. tostring(name) .. "\"")
            end
        end
    end
    if char.sets and char.sets.unknown then
        local u = 1
        while char.sets.unknown[u] do
            table.insert(setNeed, "Set \"" .. char.sets.unknown[u] .. "\"")
            issueCount = issueCount + 1
            setsUncached = setsUncached + 1
            u = u + 1
        end
    end
    if self.lastAppliedSetName and not self:ChromieSetIsCached(self.lastAppliedSetName) then
        local found = false
        if char.sets and char.sets.unknown then
            local u = 1
            while char.sets.unknown[u] do
                if char.sets.unknown[u] == self.lastAppliedSetName then
                    found = true
                    break
                end
                u = u + 1
            end
        end
        if not found then
            table.insert(setNeed, "Set \"" .. tostring(self.lastAppliedSetName) .. "\"")
            issueCount = issueCount + 1
            setsUncached = setsUncached + 1
        end
    end
    if setOk[1] or setNeed[1] then
        if lines[1] then
            table.insert(lines, "")
        end
        if setOk[1] then
            table.insert(lines, "|cff00ff00" .. table.concat(setOk, ", ") .. ": cached|r")
        end
        if setNeed[1] then
            table.insert(lines, table.concat(setNeed, ", ") .. ": not cached")
        end
        if setsUncached > 0 then
            table.insert(lines, "")
            table.insert(lines, "|cffaaaaaaApply the set from this window (Quick Sets dropdown or Home tab) to cache it. Do that after the slots above are cached, or the snapshot can be wrong.|r")
        end
    end

    local showAccount = self.ChromieAccountFlag and self:ChromieAccountFlag("showUncollectedTip")
    if f.dropCollection then
        if showAccount then
            f.dropCollection:Show()
        else
            f.dropCollection:Hide()
        end
    end
    local accountLines
    if showAccount and self.ChromieAccountScanStatusLines then
        local ok, result = pcall(self.ChromieAccountScanStatusLines, self)
        if ok then
            accountLines = result
        end
    end
    if f.accountTitle and f.accountReport then
        if accountLines then
            f.accountTitle:Show()
            f.accountReport:SetText(table.concat(accountLines, "\n"))
            f.accountReport:Show()
        else
            f.accountTitle:Hide()
            f.accountReport:SetText("")
            f.accountReport:Hide()
        end
    end

    if issueCount > 0 and okCount == 0 then
        f.summary:SetText("All equipped slots need a scan.")
    elseif issueCount > 0 then
        f.summary:SetText(okCount .. " ok, " .. issueCount .. " need a scan")
    elseif okCount > 0 then
        f.summary:SetText("|cff00ff00" .. okCount .. " slots cached OK.|r")
    else
        f.summary:SetText("No equipped slots to cache.")
    end

    self:ChromieCacheTabSetIntroVisible(issueCount > 0)

    local body = table.concat(lines, "\n")
    f.reportText:SetText(body)
    local h = f.reportText:GetStringHeight()
    if not h or h < 1 then
        h = 20
    end
    if accountLines and f.accountTitle and f.accountReport then
        local th = f.accountTitle:GetStringHeight() or 0
        local ah = f.accountReport:GetStringHeight() or 0
        h = h + 18 + th + 6 + ah
    end
    f.scrollChild:SetHeight(h + 8)
    f.scroll:SetVerticalScroll(0)
    if f.scroll.UpdateScrollChildRect then
        f.scroll:UpdateScrollChildRect()
    end
end

function Transmog:ChromieCacheTabSetIntroVisible(show)
    local f = self.cacheTabFrame
    if not f or not f.intro or not f.summary then
        return
    end
    f.summary:ClearAllPoints()
    if show then
        f.intro:Show()
        f.summary:SetPoint("TOPLEFT", f.intro, "BOTTOMLEFT", 0, -8)
    else
        f.intro:Hide()
        if f.title then
            f.summary:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -6)
        else
            f.summary:SetPoint("TOPLEFT", 8, -28)
        end
    end
end

-- Same skip rules as the Cache tab report: ignore relics and empty slots.
function Transmog:ChromieCacheSlotIsReportIssue(slot)
    local _, status = self:ChromieCacheSlotStatus(slot)
    if status == "n/a" then
        return false
    end
    if not GetInventoryItemLink("player", slot) then
        return false
    end
    return status ~= "ok"
end

function Transmog:ChromieCacheHasUncachedSet()
    local char = self:ChromiePersistChar()
    if char and char.sets and char.sets.unknown and char.sets.unknown[1] then
        return true
    end
    if self.lastAppliedSetName and self.ChromieSetIsCached and not self:ChromieSetIsCached(self.lastAppliedSetName) then
        return true
    end
    return false
end

function Transmog:ChromieCacheTabNeedsAttention()
    local i = 1
    while self.CACHE_TAB_SLOTS[i] do
        if self:ChromieCacheSlotIsReportIssue(self.CACHE_TAB_SLOTS[i]) then
            return true
        end
        i = i + 1
    end
    return self:ChromieCacheHasUncachedSet()
end
