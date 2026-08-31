local Transmog = _G.ChromieTransmog

Transmog.CHROMIE_MAX_SETS = 10
Transmog.CHROMIE_MANAGE_SET_ROW_H = 24
Transmog.CHROMIE_MANAGE_SET_ROW_GAP = 2
-- Max row widgets; visible count is measured from the scroll frame height.
Transmog.CHROMIE_MANAGE_SET_ROWS = 12
Transmog.CHROMIE_SETS_DROPDOWN_LABEL = "Quick apply sets"

function Transmog:ChromieManageSetsVisibleRows()
    local f = self.manageSetsFrame
    local step = (self.CHROMIE_MANAGE_SET_ROW_H or 24) + (self.CHROMIE_MANAGE_SET_ROW_GAP or 0)
    local maxRows = self.CHROMIE_MANAGE_SET_ROWS or 12
    local n = 4
    if f and f.scroll then
        local h = f.scroll:GetHeight()
        if h and h > 0 then
            n = math.floor((h + (self.CHROMIE_MANAGE_SET_ROW_GAP or 0)) / step)
        end
    end
    if n < 1 then
        n = 1
    end
    if n > maxRows then
        n = maxRows
    end
    return n
end

-- Populates the sets dropdown from ChromieCraft server presets.
function OutfitsDropDown_Initialize()
    local names = Transmog.chromieSets or {}
    local i = 1
    while names[i] do
        local name = names[i]
        local info = {}
        info.text = name
        info.value = 1
        info.arg1 = name
        info.checked = nil
        info.func = Transmog_LoadOutfit
        info.tooltipTitle = name
        info.tooltipText = "Apply this set immediately. Applying a saved set is free."
        UIDropDownMenu_AddButton(info)
        i = i + 1
    end
end

function Transmog:ChromieSetsDropdownLabel()
    return self.CHROMIE_SETS_DROPDOWN_LABEL or "Quick apply sets"
end

function Transmog:ChromieRefreshSetsDropdown()
    if not ChromieTransmogFrameOutfits then
        return
    end
    UIDropDownMenu_SetText(ChromieTransmogFrameOutfits, self:ChromieSetsDropdownLabel())
end

function Transmog:ChromieHideSetCreate()
    if self.setCreateFrame then
        self.setCreateFrame:Hide()
        if self.setCreateFrame.edit then
            self.setCreateFrame.edit:ClearFocus()
            self.setCreateFrame.edit:SetText("")
        end
    end
    if self.manageSetsFrame and self.manageSetsFrame.edit then
        self.manageSetsFrame.edit:ClearFocus()
        self.manageSetsFrame.edit:SetText("")
    end
end

function Transmog:ChromieClearPendingSet()
    self.chromiePendingSet = nil
end

function Transmog:ChromieDeselectSet()
    self.chromiePendingSet = nil
    self.currentOutfit = nil
    ChromieTransmogFrameSaveOutfit:Hide()
    ChromieTransmogFrameSaveOutfit:Disable()
    if ChromieTransmogFrameOutfits then
        UIDropDownMenu_SetText(ChromieTransmogFrameOutfits, self:ChromieSetsDropdownLabel())
    end
end

function Transmog:ChromieHasSetName(name)
    if not name then
        return false
    end
    local names = self.chromieSets or {}
    local i = 1
    while names[i] do
        if names[i] == name then
            return true
        end
        i = i + 1
    end
    local char = self.ChromiePersistChar and self:ChromiePersistChar()
    names = char and char.sets and char.sets.names
    i = 1
    while names and names[i] do
        if names[i] == name then
            return true
        end
        i = i + 1
    end
    return false
end

function Transmog:ChromieAddSetName(name)
    if not name or name == "" or self:ChromieHasSetName(name) then
        return
    end
    if not self.chromieSets then
        self.chromieSets = {}
    end
    table.insert(self.chromieSets, name)
end

function Transmog:ChromieRemoveSetName(name)
    local names = self.chromieSets or {}
    local i = 1
    while names[i] do
        if names[i] == name then
            table.remove(names, i)
            if self.ChromiePersistDropSet then
                self:ChromiePersistDropSet(name)
            elseif self.chromieSetItems then
                self.chromieSetItems[name] = nil
            end
            return
        end
        i = i + 1
    end
end

function Transmog:ChromieHasAnyMog()
    local _, slot
    for _, slot in pairs(self.inventorySlots) do
        local have = self.transmogStatusFromServer[slot]
        if have and have ~= 0 then
            return true
        end
    end
    return false
end

-- Warpweaver only offers save when at least one applied transmog exists on gear.
function Transmog:ChromieUpdateCanSaveSet(options)
    local can = false
    if self:tableSize(self.chromieSets or {}) < self.CHROMIE_MAX_SETS then
        if self:ChromieHasAnyMog() then
            can = true
        else
            options = options or self.chromieLastOptions
            if options and self.ChromieFindFlagIndex and self:ChromieFindFlagIndex(options, "saveSet") then
                can = true
            end
        end
    end
    self.chromieCanSaveSet = can
    if self.manageSetsOpen and self.ChromieRefreshManageSetList then
        self:ChromieRefreshManageSetList()
    end
end

function Transmog:ChromieHideManageSets()
    self.manageSetsOpen = nil
    self.chromieWantSetPrice = nil
    if self.manageSetsFrame then
        self.manageSetsFrame:Hide()
        if self.manageSetsFrame.edit then
            self.manageSetsFrame.edit:ClearFocus()
        end
    end
end

function Transmog:ChromieEnsureManageSetsFrame()
    if self.manageSetsFrame then
        return self.manageSetsFrame
    end

    local f = CreateFrame("Frame", "ChromieTransmogManageSets", ChromieTransmogFrame)
    f:SetWidth(455)
    f:SetHeight(370)
    f:SetPoint("TOPLEFT", ChromieTransmogFrame, "TOPLEFT", 255, -88)
    f:SetFrameLevel(ChromieTransmogFrame:GetFrameLevel() + 6)
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 8, -4)
    title:SetText("Manage Sets")

    local how = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    how:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    how:SetWidth(430)
    how:SetJustifyH("LEFT")
    how:SetText("A set stores the transmogs currently applied to your gear (It does not store the pending preview changes). Pick a set from the dropdown to quick apply it. Applying already saved sets from the dropdown is free. Saving a set costs gold.")

    local addLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    addLabel:SetPoint("TOPLEFT", how, "BOTTOMLEFT", 0, -14)
    addLabel:SetText("Save current transmogs as a new set")

    local edit = CreateFrame("EditBox", "ChromieTransmogManageSetName", f, "InputBoxTemplate")
    edit:SetWidth(220)
    edit:SetHeight(20)
    edit:SetPoint("TOPLEFT", addLabel, "BOTTOMLEFT", 6, -8)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(50)
    edit:SetScript("OnEnterPressed", function()
        Transmog_ConfirmNewSet()
    end)
    edit:SetScript("OnEscapePressed", function()
        this:ClearFocus()
        this:SetText("")
    end)
    edit:SetScript("OnTextChanged", function()
        Transmog:ChromieRefreshManageSetList()
    end)
    f.edit = edit

    local save = CreateFrame("Button", "ChromieTransmogManageSetSave", f, "UIPanelButtonTemplate")
    save:SetWidth(80)
    save:SetHeight(22)
    save:SetPoint("LEFT", edit, "RIGHT", 8, 0)
    save:SetText("Save")
    save:SetScript("OnClick", function()
        Transmog_ConfirmNewSet()
    end)
    f.save = save

    local cost = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cost:SetPoint("LEFT", save, "RIGHT", 8, 0)
    cost:SetText("")
    f.cost = cost

    local listLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listLabel:SetPoint("TOPLEFT", edit, "BOTTOMLEFT", -6, -14)
    listLabel:SetText("Saved sets")

    local ROW_H = self.CHROMIE_MANAGE_SET_ROW_H or 24
    local ROW_GAP = self.CHROMIE_MANAGE_SET_ROW_GAP or 0
    local function manageSetsWheel(delta)
        local bar = getglobal("ChromieTransmogManageSetScrollScrollBar")
        if not bar then
            return
        end
        delta = tonumber(delta) or arg1 or 0
        local minV, maxV = bar:GetMinMaxValues()
        local v = bar:GetValue() - (delta * ROW_H)
        if v < minV then
            v = minV
        end
        if v > maxV then
            v = maxV
        end
        bar:SetValue(v)
    end

    local scroll = CreateFrame("ScrollFrame", "ChromieTransmogManageSetScroll", f, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", listLabel, "BOTTOMLEFT", 0, -6)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 8)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        local frame = this
        local value = arg1
        if type(self) == "table" and type(offset) == "number" then
            frame = self
            value = offset
        end
        frame.offset = math.floor(((tonumber(value) or 0) / ROW_H) + 0.5)
        Transmog:ChromieRefreshManageSetList()
    end)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        manageSetsWheel(delta or arg1)
    end)
    f.scroll = scroll

    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(self, delta)
        manageSetsWheel(delta or arg1)
    end)
    f:SetScript("OnShow", function()
        this:SetScript("OnUpdate", function()
            this:SetScript("OnUpdate", nil)
            Transmog:ChromieRefreshManageSetList()
        end)
    end)

    f.rows = {}
    local i = 1
    while i <= self.CHROMIE_MANAGE_SET_ROWS do
        local row = CreateFrame("Frame", "ChromieTransmogManageSetRow" .. i, f)
        row:SetWidth(400)
        row:SetHeight(ROW_H)
        if i == 1 then
            row:SetPoint("TOPLEFT", listLabel, "BOTTOMLEFT", 0, -6)
        else
            row:SetPoint("TOPLEFT", f.rows[i - 1], "BOTTOMLEFT", 0, -ROW_GAP)
        end

        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        nameText:SetPoint("LEFT", 4, 0)
        nameText:SetWidth(300)
        nameText:SetJustifyH("LEFT")
        row.nameText = nameText

        local del = CreateFrame("Button", "ChromieTransmogManageSetRow" .. i .. "Delete", row, "UIPanelButtonTemplate")
        del:SetWidth(65)
        del:SetHeight(20)
        del:SetPoint("RIGHT", 18, 0)
        del:SetText("Delete")
        del:SetScript("OnClick", function()
            local setName = this:GetParent().setName
            if setName then
                Transmog.chromieDeleteSetName = setName
                StaticPopup_Show("CONFIRM_DELETE_OUTFIT", setName)
            end
        end)
        del:EnableMouseWheel(true)
        del:SetScript("OnMouseWheel", function(self, delta)
            manageSetsWheel(delta or arg1)
        end)
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", function(self, delta)
            manageSetsWheel(delta or arg1)
        end)
        row.del = del
        row:Hide()
        f.rows[i] = row
        i = i + 1
    end

    local empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    empty:SetPoint("TOPLEFT", listLabel, "BOTTOMLEFT", 4, -16)
    empty:SetText("No saved sets yet.")
    f.empty = empty

    self.manageSetsFrame = f
    return f
end

function Transmog:ChromieRefreshManageSetList()
    local f = self.manageSetsFrame
    if not f or not f:IsShown() then
        return
    end
    local names = self.chromieSets or {}
    local n = self:tableSize(names)
    local vis = self:ChromieManageSetsVisibleRows()
    local maxRows = self.CHROMIE_MANAGE_SET_ROWS or 12
    FauxScrollFrame_Update(f.scroll, n, vis, self.CHROMIE_MANAGE_SET_ROW_H or 24)
    local offset = FauxScrollFrame_GetOffset(f.scroll) or 0
    if n == 0 then
        f.empty:Show()
    else
        f.empty:Hide()
    end
    local i = 1
    while i <= maxRows do
        local row = f.rows[i]
        local name = nil
        if i <= vis then
            name = names[offset + i]
        end
        if name then
            row.setName = name
            row.nameText:SetText(name)
            row.del:Enable()
            row:Show()
        else
            row.setName = nil
            row:Hide()
        end
        i = i + 1
    end
    if n >= self.CHROMIE_MAX_SETS or self.chromieJob == "sets-save" or self.chromieJob == "sets-price" or self.chromieWantSetPrice then
        f.save:Disable()
    elseif self.chromieCanSaveSet ~= true then
        f.save:Disable()
    elseif self.chromieSetSaveCopper and GetMoney() < self.chromieSetSaveCopper then
        f.save:Disable()
    else
        f.save:Enable()
    end
    self:ChromieUpdateManageSetPrice()
end

function Transmog:ChromieUpdateManageSetPrice()
    local f = self.manageSetsFrame
    if not f or not f.cost then
        return
    end
    if (self.chromieJob == "sets-price" and not self.chromieSetPriceCaptured) or self.chromieWantSetPrice then
        f.cost:SetText("...")
        return
    end
    if self.chromieSetSaveCopper then
        f.cost:SetText(self:ChromieCoinText(self.chromieSetSaveCopper))
        return
    end
    f.cost:SetText("")
end

function Transmog:ChromieRefreshManageSets()
    if self.manageSetsOpen then
        self:ChromieRefreshManageSetList()
    end
    if self.ChromieHomeTabRefresh then
        self:ChromieHomeTabRefresh()
    end
end

function Transmog:ChromieShowManageSets()
    if self.ChromieCacheSyncIsBlocking and self:ChromieCacheSyncIsBlocking() then
        return
    end
    self:hideItems(true)
    self:hidePagination()
    if self.ChromieHomeTabHide then
        self:ChromieHomeTabHide()
    end
    if self.ChromieAboutTabHide then
        self:ChromieAboutTabHide()
    end
    ChromieTransmogFrameSplash:Hide()
    ChromieTransmogFrameInstructions:Hide()
    ChromieTransmogFrameNoTransmogs:Hide()
    ChromieTransmogFrameCollectedText:Hide()
    self:ChromieHideSetCreate()
    local f = self:ChromieEnsureManageSetsFrame()
    self.manageSetsOpen = true
    f:Show()
    self:ChromieUpdateCanSaveSet()
    self:ChromieRefreshManageSetList()
    if self.ChromieStartSetPrice then
        self:ChromieStartSetPrice()
    end
end

function Transmog:ChromieCanApplySet()
    if not self.chromiePendingSet or not self.chromiePendingSet.name or not self.chromiePendingSet.items then
        return false
    end
    if self:ChromieHasPending() then
        return false
    end
    return true
end

-- Applies a server set immediately through Warpweaver. No confirm popup.
function Transmog_LoadOutfit(self, outfit)
    if not outfit then
        return
    end
    Transmog:Chat("Applying set \"" .. tostring(outfit) .. "\"...")
    if Transmog.ChromieLastUsedRecord then
        Transmog:ChromieLastUsedRecord(outfit)
    end
    if Transmog.ChromieHomeTabRefresh then
        Transmog:ChromieHomeTabRefresh()
    end
    Transmog.chromieQuickApplySetName = outfit
    Transmog:ChromieHideSetCreate()
    selectTransmogSlot(-1)
    UIDropDownMenu_SetText(ChromieTransmogFrameOutfits, Transmog:ChromieSetsDropdownLabel())
    ChromieTransmogFrameSaveOutfit:Hide()
    Transmog:hideItemBorders()
    Transmog.chromiePendingSet = {
        name = outfit,
        items = Transmog.chromieSetItems and Transmog.chromieSetItems[outfit] or nil,
    }
    if Transmog.ChromieStartSetUse then
        Transmog:ChromieStartSetUse(outfit)
    end
end

function Transmog_SaveOutfit()
    ChromieTransmogFrameSaveOutfit:Hide()
    ChromieTransmogFrameSaveOutfit:Disable()
end

function Transmog:EnableOutfitSaveButton()
    ChromieTransmogFrameSaveOutfit:Hide()
    ChromieTransmogFrameSaveOutfit:Disable()
    if self.chromieJob == "sets-use" then
        return
    end
    if (self.currentOutfit or self.chromiePendingSet) and self:ChromieHasPending() then
        self:ChromieDeselectSet()
    end
end

function Transmog_ShowManageSets()
    Transmog:ChromieShowManageSets()
end

function Transmog_deleteOutfit()
    local name = Transmog.chromieDeleteSetName or Transmog.currentOutfit
    Transmog.chromieDeleteSetName = nil
    if not name then
        return
    end
    if Transmog.ChromieStartSetDelete then
        Transmog:ChromieStartSetDelete(name)
        return
    end
    Transmog:ChromieRemoveSetName(name)
    if Transmog.currentOutfit == name then
        Transmog:ChromieDeselectSet()
        Transmog:PreviewRedress(0)
        Transmog:calculateCost()
    end
    Transmog:ChromieRefreshManageSets()
end

StaticPopupDialogs["CONFIRM_DELETE_OUTFIT"] = {
    text = "Delete set \"%s\"?",
    button1 = TEXT(YES),
    button2 = TEXT(NO),
    OnAccept = function()
        Transmog_deleteOutfit()
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

function Transmog_NewOutfitPopup()
    Transmog:ChromieShowManageSets()
end

function Transmog_CancelNewSet()
    Transmog:ChromieHideSetCreate()
end

function Transmog_ConfirmNewSet()
    local f = Transmog.manageSetsFrame
    if not f or not f:IsShown() then
        return
    end
    local name = f.edit:GetText() or ""
    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")
    if name == "" or string.find(name, '"', 1, true) or string.find(name, "\\", 1, true) then
        Transmog:Chat("Enter a valid set name (no quotes or backslashes).")
        return
    end
    if Transmog:ChromieHasSetName(name) then
        Transmog:Chat("A set with that name already exists.")
        return
    end
    if Transmog:tableSize(Transmog.chromieSets or {}) >= Transmog.CHROMIE_MAX_SETS then
        Transmog:Chat("Set limit reached.")
        return
    end
    if Transmog.chromieCanSaveSet ~= true then
        Transmog:Chat("Nothing to save. Transmogrify at least one item first.")
        return
    end
    if Transmog.ChromieStartSetSave then
        Transmog:ChromieStartSetSave(name)
    end
end

-- Set cache on quick-apply (merged from set_cache.lua; must live in a file that loads reliably)
function Transmog:ChromieSetCacheDbg(msg)
end

function Transmog:ChromieSetCacheSlotSummary(slot)
    local label = self.ChromieSlotLabelShort and self:ChromieSlotLabelShort(slot) or tostring(slot)
    local have = self.transmogStatusFromServer and self.transmogStatusFromServer[slot]
    local mogged = self:ChromieSlotIsMogged(slot) and "yes" or "no"
    local resolved = self.ChromieResolveAppliedMogId and self:ChromieResolveAppliedMogId(slot)
    return label .. " have=" .. tostring(have) .. " mogged=" .. mogged .. " resolved=" .. tostring(resolved)
end

function Transmog:ChromieUnlockCacheHealthyForSlots(slots)
    local char = self:ChromiePersistChar()
    if not char or not slots or not slots[1] then
        return true
    end
    local i = 1
    while slots[i] do
        local slot = slots[i]
        local link = GetInventoryItemLink("player", slot)
        if not link then
            self:ChromieSetCacheDbg("health fail " .. self:ChromieSetCacheSlotSummary(slot) .. " (no item link)")
            return false
        end
        local key = self:ChromieCacheKeyForSlot(slot, link)
        local entry = key and char.unlocks and char.unlocks[key]
        local status = self:ChromieCacheSlotEffectiveStatus(slot, entry)
        if status ~= "ok" then
            self:ChromieSetCacheDbg("health fail " .. self:ChromieSetCacheSlotSummary(slot)
                .. " key=" .. tostring(key) .. " status=" .. tostring(status))
            return false
        end
        i = i + 1
    end
    return true
end

function Transmog:ChromieSetIsCached(name)
    local char = self:ChromiePersistChar()
    if not char or not char.sets or not char.sets.items or not name then
        return false
    end
    if not char.sets.items[name] then
        return false
    end
    return char.sets.inferred and char.sets.inferred[name] and true or false
end

function Transmog:ChromieSetCacheCollectSlots()
    local scanSlots = {}
    local items = {}
    local _, slot
    for _, slot in pairs(self.inventorySlots or {}) do
        if not self:ChromieSlotSupportsTransmog(slot) then
            -- skip
        elseif not GetInventoryItemLink("player", slot) then
            -- skip
        elseif self.transmogStatusFromServer[slot] == self.HIDDEN_ITEM_ID then
            items[slot] = self.HIDDEN_ITEM_ID
            self:ChromieSetCacheDbg("collect hidden " .. self:ChromieSetCacheSlotSummary(slot))
        elseif self:ChromieSlotTextureIsMogged(slot) then
            -- Always re-scan. Resolve would reuse the previous look (same base gear).
            table.insert(scanSlots, slot)
            self:ChromieSetCacheDbg("collect needs scan " .. self:ChromieSetCacheSlotSummary(slot))
        end
    end
    return scanSlots, items
end

function Transmog:ChromieSetCacheRecordSlot(slot)
    local job = self.setCacheJob
    if not job or not slot then
        return
    end
    local mogId = 0
    if self.transmogStatusFromServer[slot] == self.HIDDEN_ITEM_ID then
        mogId = self.HIDDEN_ITEM_ID
    elseif self:ChromieSlotIsMogged(slot) then
        local inferred = self.chromieLastScanInferred and self.chromieLastScanInferred[slot]
        inferred = inferred and tonumber(inferred)
        if inferred and inferred > 1 then
            mogId = inferred
        else
            mogId = nil
        end
    end
    job.items[slot] = mogId or 0
    self:ChromieSetCacheDbg("record " .. self:ChromieSetCacheSlotSummary(slot) .. " -> " .. tostring(job.items[slot]))
end

function Transmog:ChromiePersistEnsureSetName(name)
    local char = self:ChromiePersistChar()
    if not char or not name then
        return
    end
    if not char.sets.names then
        char.sets.names = {}
    end
    local i = 1
    while char.sets.names[i] do
        if char.sets.names[i] == name then
            return
        end
        i = i + 1
    end
    table.insert(char.sets.names, name)
    self.chromieSets = char.sets.names
end

function Transmog:ChromieSetCacheFinish()
    local job = self.setCacheJob
    self.setCacheJob = nil
    if not job or not job.name then
        self:ChromieSetCacheDbg("finish: no job")
        return
    end
    self:ChromieSetCacheDbg("finish \"" .. tostring(job.name) .. "\"")
    local i = 1
    while job.scanSlots[i] do
        local slot = job.scanSlots[i]
        local id = job.items[slot]
        if not id or (id <= 1 and id ~= self.HIDDEN_ITEM_ID) then
            self:ChromieSetCacheDbg("finish abort: missing mog on " .. self:ChromieSetCacheSlotSummary(slot)
                .. " recorded=" .. tostring(id))
            return
        end
        i = i + 1
    end
    self:ChromiePersistEnsureSetName(job.name)
    if self.ChromiePersistSetItems then
        self:ChromiePersistSetItems(job.name, job.items)
    end
    self.lastAppliedSetName = job.name
    local parts = {}
    for slot, id in pairs(job.items) do
        if type(slot) == "number" then
            table.insert(parts, tostring(slot) .. "=" .. tostring(id))
        end
    end
    table.sort(parts)
    self:ChromieSetCacheDbg("persisted {" .. table.concat(parts, ", ") .. "}")
    if self.ChromieCacheTabRefresh then
        self:ChromieCacheTabRefresh(true)
    end
end

function Transmog:ChromieSetCacheScanNext()
    local job = self.setCacheJob
    if not job then
        self:ChromieSetCacheDbg("scanNext: no job")
        return
    end
    self:ChromieSetCacheDbg("scanNext job=\"" .. tostring(job.name) .. "\" job=" .. tostring(self.chromieJob))
    while job.scanSlots[job.index] do
        local slot = job.scanSlots[job.index]
        job.index = job.index + 1
        job.currentSlot = slot
        self:ChromieSetCacheDbg("scan slot " .. self:ChromieSetCacheSlotSummary(slot))
        if self:ChromieScanSlot(slot, { force = true, purpose = "set_cache", announce = false }) then
            self:ChromieSetCacheDbg("ChromieScanSlot started for slot " .. tostring(slot))
            return
        end
        self:ChromieSetCacheDbg("ChromieScanSlot refused slot " .. tostring(slot) .. " job=" .. tostring(self.chromieJob))
        self:ChromieSetCacheRecordSlot(slot)
        job.currentSlot = nil
    end
    self:ChromieSetCacheFinish()
end

function Transmog:ChromieSetCacheOnLoadDone(slot)
    local job = self.setCacheJob
    if not job or not slot or job.currentSlot ~= slot then
        if job and slot then
            self:ChromieSetCacheDbg("loadDone ignored slot=" .. tostring(slot)
                .. " current=" .. tostring(job.currentSlot))
        end
        return false
    end
    self:ChromieSetCacheDbg("loadDone slot " .. tostring(slot))
    self:ChromieSetCacheRecordSlot(slot)
    job.currentSlot = nil
    if job.scanSlots[job.index] then
        job.pendingNext = true
        self:ChromieSetCacheDbg("pending next scan after back to main")
    else
        self:ChromieSetCacheFinish()
    end
    return true
end

function Transmog:ChromieSetCacheResumeIfPending(onMainMenu)
    local job = self.setCacheJob
    if not job or not job.pendingNext or not onMainMenu then
        return false
    end
    job.pendingNext = nil
    self:ChromieSetCacheDbg("resume pending scan on main menu")
    self:ChromieDeferSetCacheScanNext()
    return true
end

function Transmog:ChromieDeferSetCacheScanNext()
    local frame = self.setCacheScanKicker
    if not frame then
        frame = CreateFrame("Frame")
        frame:Hide()
        frame:SetScript("OnUpdate", function(f)
            f:Hide()
            if Transmog.setCacheJob and Transmog.ChromieSetCacheScanNext then
                Transmog:ChromieSetCacheScanNext()
            end
        end)
        self.setCacheScanKicker = frame
    end
    frame:Show()
end

function Transmog:ChromieDeferSetCacheApply(name)
    if not name then
        return
    end
    local frame = self.setCacheApplyKicker
    if not frame then
        frame = CreateFrame("Frame")
        self.setCacheApplyKicker = frame
    end
    frame.pendingName = name
    frame.elapsed = 0
    frame:Show()
    frame:SetScript("OnUpdate", function(f)
        f.elapsed = (f.elapsed or 0) + arg1
        -- Wait for appearance packets after Use this set before snapshotting mogs.
        if f.elapsed < (Transmog.SET_CACHE_APPLY_DELAY or 0.4) then
            return
        end
        f:Hide()
        f:SetScript("OnUpdate", nil)
        local pending = f.pendingName
        f.pendingName = nil
        if pending then
            Transmog:ChromieMaybeCacheSetOnApply(pending)
        end
    end)
end

function Transmog:ChromieScheduleCacheSetOnApply(name)
    if not name then
        return
    end
    self:ChromieSetCacheDbg("schedule cache for \"" .. tostring(name) .. "\"")
    self:ChromieDeferSetCacheApply(name)
end

Transmog.SET_CACHE_APPLY_DELAY = 0.4

function Transmog:ChromieSetCacheItemsFromWorn()
    local scanSlots = {}
    local items = {}
    local _, slot
    for _, slot in pairs(self.inventorySlots or {}) do
        if not self:ChromieSlotSupportsTransmog(slot) then
            -- skip
        elseif not GetInventoryItemLink("player", slot) then
            -- skip
        elseif (self.transmogStatusFromServer and self.transmogStatusFromServer[slot] == self.HIDDEN_ITEM_ID)
            or (self.ChromieSlotTextureIsHidden and self:ChromieSlotTextureIsHidden(slot)) then
            items[slot] = self.HIDDEN_ITEM_ID
        elseif self:ChromieSlotIsMogged(slot) then
            local id = self.ChromieResolveAppliedMogId and self:ChromieResolveAppliedMogId(slot)
            if (not id or id <= 1) and self.ChromiePersistGetApplied then
                id = self:ChromiePersistGetApplied(slot)
            end
            id = id and tonumber(id)
            if (not id or id <= 1) and self.transmogStatusFromServer then
                local have = self.transmogStatusFromServer[slot]
                if have and have > 1 then
                    id = have
                end
            end
            if id and id > 1 then
                items[slot] = id
            else
                table.insert(scanSlots, slot)
            end
        end
    end
    return scanSlots, items
end

function Transmog:ChromieCacheSetFromWorn(name)
    if not name then
        return false
    end
    if self.ChromieSetIsCached and self:ChromieSetIsCached(name) then
        return false
    end
    local scanSlots, items = self:ChromieSetCacheItemsFromWorn()
    if scanSlots[1] then
        if ChromieTransmogFrame and ChromieTransmogFrame:IsShown()
            and self.chromieJob ~= "load" and self.chromieJob ~= "apply"
            and not self:ChromieIsSetJob() and not self.chromieWaitingForNpc then
            if self.ChromieMaybeCacheSetOnApply then
                self:ChromieMaybeCacheSetOnApply(name)
            end
        else
            self.chromiePendingSetCache = name
        end
        return true
    end
    if self.ChromiePersistEnsureSetName then
        self:ChromiePersistEnsureSetName(name)
    end
    if self.ChromiePersistSetItems then
        self:ChromiePersistSetItems(name, items)
    end
    if self.ChromieCacheTabRefresh then
        self:ChromieCacheTabRefresh(true)
    end
    if self.ChromieHomeTabRefresh then
        self:ChromieHomeTabRefresh()
    end
    return false
end

-- After name scrape / save: cache one uncached set from the worn look when possible.
function Transmog:ChromieTryCacheUnknownSets()
    if self.setCacheJob then
        return false
    end
    local name = self.chromiePendingSetCache
    self.chromiePendingSetCache = nil
    if not name then
        local char = self.ChromiePersistChar and self:ChromiePersistChar()
        local unknown = char and char.sets and char.sets.unknown
        if unknown and unknown[1] and not unknown[2] then
            name = unknown[1]
        end
    end
    if not name or (self.ChromieSetIsCached and self:ChromieSetIsCached(name)) then
        return false
    end
    self:ChromieCacheSetFromWorn(name)
    return self.setCacheJob and true or false
end

function Transmog:ChromieMaybeCacheSetOnApply(name)
    self:ChromieSetCacheDbg("maybeCache \"" .. tostring(name) .. "\" job=" .. tostring(self.chromieJob)
        .. " vendor=" .. tostring(self.chromieVendorOpen)
        .. " frame=" .. tostring(ChromieTransmogFrame and ChromieTransmogFrame:IsShown()))
    if not name then
        return
    end
    if self.setCacheJob then
        return
    end
    if self.chromieVendorOpen then
        return
    end
    if not ChromieTransmogFrame or not ChromieTransmogFrame:IsShown() then
        return
    end
    if self.chromieJob == "load" or self.chromieJob == "apply" then
        self:ChromieDeferSetCacheApply(name)
        return
    end
    if self:ChromieSetIsCached(name) then
        self.lastAppliedSetName = name
        if self.ChromieCacheTabRefresh then
            self:ChromieCacheTabRefresh(true)
        end
        return
    end
    local scanSlots, items = self:ChromieSetCacheCollectSlots()
    local scanList = {}
    local i = 1
    while scanSlots[i] do
        table.insert(scanList, tostring(scanSlots[i]))
        i = i + 1
    end
    self:ChromieSetCacheDbg("scan queue: [" .. table.concat(scanList, ", ") .. "]")
    self.setCacheJob = {
        name = name,
        scanSlots = scanSlots,
        index = 1,
        items = items,
    }
    self.lastAppliedSetName = name
    if scanSlots[1] then
        self:ChromieDeferSetCacheScanNext()
    else
        self:ChromieSetCacheDbg("no scans needed, persisting from resolved/hidden slots")
        self:ChromieSetCacheFinish()
    end
end

function Transmog:ChromieSetCacheAbort()
    if self.setCacheJob or (self.setCacheApplyKicker and self.setCacheApplyKicker.pendingName) then
        self:ChromieSetCacheDbg("abort")
    end
    self.setCacheJob = nil
    if self.setCacheApplyKicker then
        self.setCacheApplyKicker.pendingName = nil
        self.setCacheApplyKicker:Hide()
    end
end
